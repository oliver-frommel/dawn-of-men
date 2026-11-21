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

### 1. Decouple and cache the static 2D map layer (Implemented)
- **Done**: Split static terrain ground and raised scenery into `4×4` lazy-activated `LayerNode` chunks (`16×12` tiles each) under `MapRoot`, redrawing only dirty chunks on tile state changes or season transitions while panning/zooming via transform and keeping dynamic per-frame redraws to collectibles, shadows, trails, and overlays.
- **Measured result**: Dynamic frame time at zoom `0.75` dropped from `103.8 ms` → **`~6.0 ms`** (~17× faster).

### 2. Reduce 3D draw calls and share procedural meshes (Partially implemented)
- **Done**: Disabled unused `DirectionalLight3D.shadow_enabled` in `main.gd` (halved 3D draw calls; 2D ground shadows remain intact).
- **Remaining**:
  - Merge static sub-parts per animated pivot via `SurfaceTool` (e.g., head, torso, limbs/hands/feet) to reduce hominins from `52` → `~10` draw calls and elephants from `54` → `~8` draw calls.
  - Cache/share generated meshes by model signature / species and trim sphere/cylinder subdivisions on sub-pixel parts (eyes, ears, fingers) to cut triangle count by 3–5×.

### 3. Larger-map scaling (Only needed if world size grows significantly beyond `128×96`)
- Replace CPU pixel-loop shoreline texture baking in `world_map.gd` with a 2D shoreline fragment shader (0 ms CPU bake, resolution-independent at any zoom).
- Consider chunked/hierarchical pathfinding if A\* graph exceeds ~15k–20k land nodes.
