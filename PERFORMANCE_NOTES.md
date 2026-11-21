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
- **Done**: Baked static terrain ground and raised scenery into lazy-allocated `4×4` `SubViewport` textures (`UPDATE_ONCE`, `16×12` tiles each) rendered as `Sprite2D` quads with frustum culling, replacing tens of thousands of per-frame vector primitives with `4–8` textured quads per frame.
- **Measured result**: Dynamic frame time at zoom `0.75` dropped from `103.8 ms` → **`~6.0 ms`**.

### 2. Reduce 3D draw calls, merge procedural meshes, and cull off-screen actors (Implemented)
- **Done**:
  - Disabled unused `DirectionalLight3D.shadow_enabled` and `SubViewport` MSAA in `main.gd`.
  - Batched rigid sub-meshes per animated pivot via `SurfaceTool` and trimmed sub-pixel sphere/cylinder subdivisions in `hominin_model.gd` and `wildlife_model.gd`.
  - Added screen-bounds visibility culling for off-screen 3D hominins and wildlife, and throttled per-frame HUD action label refreshes to `0.2s`.
- **Measured result**: Total 3D stage dropped from `798 instances / 215,980 tris` → **`320 instances / 71,418 tris`** (~2.5× fewer draw calls and ~3× fewer triangles, plus off-screen culling and single-pass rendering).

### 3. Larger-map scaling (Only needed if world size grows significantly beyond `128×96`)
- Replace CPU pixel-loop shoreline texture baking in `world_map.gd` with a 2D shoreline fragment shader (0 ms CPU bake, resolution-independent at any zoom).
- Consider chunked/hierarchical pathfinding if A\* graph exceeds ~15k–20k land nodes.
