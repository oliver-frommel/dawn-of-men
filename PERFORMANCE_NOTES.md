# Performance Notes

Baseline measurements captured in Godot 4.7.2 (`GL Compatibility`) on the `64×48` Rift Valley map (3,072 tiles, 10 hominins + 7 roaming wildlife).

## Measured Baseline

- **World setup (`WorldMap.setup`)**: `43.7 ms` (2,985 A\* nodes, 156 shoreline tiles).
- **Shoreline texture baking (`world_map.gd`)**: `~3.0 ms/tile` (`467 ms` total for 156 tiles; lazily amortized to `~12 ms` at startup).
- **Full explored 2D map redraw (`MapRenderer.draw_map`)**:
  - Zoom `1.00` (511 visible tiles): `72.4 ms/frame` (~13 FPS native; ~2–4× slower in Web/WASM).
  - Zoom `0.75` (801 visible tiles): `103.8 ms/frame` (~9.6 FPS native).
- **3D stage (`hominin_stage`)**: `798 MeshInstance3D` nodes, `798` unique `Mesh` resources, `215,980` triangles (~1,600 draw calls/frame with directional shadows enabled).
  - Single hominin: `52` instances / `16,220` tris.
  - Single wildlife: `33` instances / `6,108` tris (Hipparion) up to `54` instances / `9,684` tris (Elephant).

## Planned Optimizations (Priority Order)

### 1. Decouple and raster-cache the static 2D map layer (Implemented)
- **Done**: Baked static terrain ground, Civ 3-style shaded hills, and raised scenery into lazy-allocated opaque axis-aligned `1024×1024` `SubViewport` chunks (`UPDATE_ONCE`, with `2 px` overscan + `Sprite2D.region_rect` inset to prevent seam fringing) rendered with frustum culling, replacing tens of thousands of per-frame vector primitives with `4–6` textured quads per frame.
- **Measured result**: Dynamic frame time at zoom `0.75` dropped from `103.8 ms` → **`~6 ms`** uncapped (paced at `16.6 ms` / 60 FPS).

### 2. Reduce 3D draw calls, merge procedural meshes, and cull off-screen actors (Implemented)
- **Done**:
  - Disabled unused `DirectionalLight3D.shadow_enabled` and `SubViewport` MSAA in `main.gd`.
  - Batched rigid sub-meshes per animated pivot via `SurfaceTool`, trimmed sub-pixel sphere/cylinder subdivisions, and unified materials via vertex colors (`COLOR` in `hominin_skin.gdshader` and `vertex_color_use_as_albedo` in `hominin_model.gd` & `wildlife_model.gd`).
  - Added early band-level frustum culling before path/IK checks in `_sync_hominin_band()`, stationary IK skip in `hominin_model.gd`, and off-screen skip in `wildlife_model.gd`.
- **Measured result**: Total 3D stage dropped from `798 instances / 215,980 tris` → **`236 instances / 71,418 tris`** (~3.4× fewer draw calls and ~3× fewer triangles; single hominin `52 → 18` instances, single wildlife `33–54 → 8` instances). `_sync_hominin_models()` dropped to `~39 us/frame`.

### 3. Live CPU throttling, memory reduction & idle power reduction (Implemented)
- **Done**:
  - Capped engine tick/render rate to **`60 FPS`** (`application/run/max_fps=60` in `project.godot`) to halve macOS OpenGL-over-Metal (`gl_compatibility`) CPU load on 120 Hz ProMotion displays.
  - Switched `hominin_viewport` from `UPDATE_ALWAYS` to on-demand `UPDATE_ONCE`: renders at **30 Hz** during ambient simulation (in lockstep with ambient 2D dynamic redraws), **60 Hz** only while the player is actively moving or panning/zooming, and **0 Hz** (`UPDATE_DISABLED`) while paused or viewing Skills/Summary overlays.
  - Enabled `OS.low_processor_usage_mode = true` automatically whenever paused or in modal overlays so idle CPU usage drops near zero.
  - Throttled season progress bar updates to `4 Hz` (`0.25s`) and HUD action label refreshes to `5 Hz` (`0.20s`).
  - Eliminated massive `CanvasItem` polygon VBO bloat in `map_renderer.gd` by switching thin baked terrain lines and `_draw_leaf_texture` `draw_multiline_colors()` calls from positive-width antialiased lines (`width=0.8..1.2, antialiased=true`) to native 1px lines (`width=-1.0, antialiased=false`), and freeing each chunk's temporary `LayerNode` immediately after its `SubViewport` finishes baking (`RenderingServer.frame_post_draw`).
- **Measured result**: Static memory after full-map pan + 10 seasons dropped from **`683.2 MB` peak (`678.5 MB` steady) → `~45–63 MB`** (~15× lower CPU RAM, and eliminating hundreds of thousands of retained OpenGL-over-Metal VBO allocations).

### 4. Larger-map scaling (Only needed if world size grows significantly beyond `128×96`)
- Replace CPU pixel-loop shoreline texture baking in `world_map.gd` with a 2D shoreline fragment shader (0 ms CPU bake, resolution-independent at any zoom).
- Consider chunked/hierarchical pathfinding if A\* graph exceeds ~15k–20k land nodes.
