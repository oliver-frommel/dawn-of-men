class_name MapRenderer
extends RefCounted

const WorldMapScript := preload("res://world_map.gd")

var world: WorldMapScript


class MeshBuilder2D:
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	var indices := PackedInt32Array()
	var v_count := 0
	var i_count := 0
	var v_cap := 0
	var i_cap := 0

	func _init(initial_verts := 16384, initial_indices := 24576) -> void:
		v_cap = initial_verts
		i_cap = initial_indices
		verts.resize(v_cap)
		cols.resize(v_cap)
		indices.resize(i_cap)

	func _reserve(v_add: int, i_add: int) -> void:
		if v_count + v_add > v_cap:
			while v_count + v_add > v_cap:
				v_cap *= 2
			verts.resize(v_cap)
			cols.resize(v_cap)
		if i_count + i_add > i_cap:
			while i_count + i_add > i_cap:
				i_cap *= 2
			indices.resize(i_cap)

	func add_tri(a: Vector2, b: Vector2, c: Vector2, ca: Color, cb: Color, cc: Color) -> void:
		_reserve(3, 3)
		var base := v_count
		verts[base] = a
		verts[base + 1] = b
		verts[base + 2] = c
		cols[base] = ca
		cols[base + 1] = cb
		cols[base + 2] = cc
		indices[i_count] = base
		indices[i_count + 1] = base + 1
		indices[i_count + 2] = base + 2
		v_count += 3
		i_count += 3

	func add_quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
		_reserve(4, 6)
		var base := v_count
		verts[base] = a
		verts[base + 1] = b
		verts[base + 2] = c
		verts[base + 3] = d
		cols[base] = ca
		cols[base + 1] = cb
		cols[base + 2] = cc
		cols[base + 3] = cd
		indices[i_count] = base
		indices[i_count + 1] = base + 1
		indices[i_count + 2] = base + 2
		indices[i_count + 3] = base
		indices[i_count + 4] = base + 2
		indices[i_count + 5] = base + 3
		v_count += 4
		i_count += 6

	func add_quad_solid(a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
		add_quad(a, b, c, d, col, col, col, col)

	func add_poly_solid(pts: PackedVector2Array, col: Color) -> void:
		var n := pts.size()
		if n < 3:
			return
		var center := Vector2.ZERO
		for p in pts:
			center += p
		center /= float(n)
		_reserve(n + 1, n * 3)
		var c_idx := v_count
		verts[c_idx] = center
		cols[c_idx] = col
		for k in range(n):
			verts[c_idx + 1 + k] = pts[k]
			cols[c_idx + 1 + k] = col
		var ii := i_count
		for k in range(n):
			indices[ii] = c_idx
			indices[ii + 1] = c_idx + 1 + k
			indices[ii + 2] = c_idx + 1 + ((k + 1) % n)
			ii += 3
		v_count += n + 1
		i_count += n * 3

	func add_ellipse(center: Vector2, radii: Vector2, col: Color, segs := 10) -> void:
		_reserve(segs + 1, segs * 3)
		var c_idx := v_count
		verts[c_idx] = center
		cols[c_idx] = col
		var step := TAU / float(segs)
		for k in range(segs):
			var a := step * float(k)
			verts[c_idx + 1 + k] = Vector2(center.x + cos(a) * radii.x, center.y + sin(a) * radii.y)
			cols[c_idx + 1 + k] = col
		var ii := i_count
		for k in range(segs):
			indices[ii] = c_idx
			indices[ii + 1] = c_idx + 1 + k
			indices[ii + 2] = c_idx + 1 + ((k + 1) % segs)
			ii += 3
		v_count += segs + 1
		i_count += segs * 3

	func add_circle(center: Vector2, radius: float, col: Color, segs := 7) -> void:
		add_ellipse(center, Vector2(radius, radius), col, segs)

	func add_line(a: Vector2, b: Vector2, col: Color, width := 1.0) -> void:
		var d := b - a
		var len_sq := d.length_squared()
		if len_sq < 0.0001:
			return
		var inv_len := 1.0 / sqrt(len_sq)
		var half_w := width * 0.5
		var perp := Vector2(-d.y * inv_len * half_w, d.x * inv_len * half_w)
		add_quad_solid(a - perp, b - perp, b + perp, a + perp, col)

	func add_polyline(pts: PackedVector2Array, col: Color, width := 1.2) -> void:
		for k in range(pts.size() - 1):
			add_line(pts[k], pts[k + 1], col, width)

	func add_arc(center: Vector2, radius: float, a0: float, a1: float, segs: int, col: Color, width := 1.4) -> void:
		var prev := center + Vector2(cos(a0), sin(a0)) * radius
		for k in range(1, segs + 1):
			var a := lerpf(a0, a1, float(k) / float(segs))
			var cur := center + Vector2(cos(a), sin(a)) * radius
			add_line(prev, cur, col, width)
			prev = cur

	func commit() -> ArrayMesh:
		verts.resize(v_count)
		cols.resize(v_count)
		indices.resize(i_count)
		var mesh := ArrayMesh.new()
		if v_count == 0 or i_count == 0:
			return mesh
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_COLOR] = cols
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh


func _init(world_map: WorldMapScript) -> void:
	world = world_map


func draw_world(canvas: CanvasItem, width: float, height: float) -> void:
	canvas.draw_rect(Rect2(0, 0, width, height), Color("#182826"))
	for y in range(0, int(height), 64):
		var alpha := 0.025 if y % 128 == 0 else 0.012
		canvas.draw_line(Vector2(0, y), Vector2(width, y), Color(0.8, 0.76, 0.63, alpha), -1.0, false)


func build_ground_mesh(is_dry_season := false) -> ArrayMesh:
	var mb := MeshBuilder2D.new(65536, 98304)
	for y in range(WorldMapScript.WORLD_HEIGHT):
		for x in range(WorldMapScript.WORLD_WIDTH):
			var tile := Vector2i(x, y)
			var center := world.tile_center(x, y)
			var terrain := world.terrain_at(tile)
			_emit_terrain_ground(mb, center, tile, terrain, is_dry_season)
	return mb.commit()


func draw_shorelines(canvas: CanvasItem) -> void:
	for id in world.shoreline_tiles:
		var tile := Vector2i(int(id) % WorldMapScript.WORLD_WIDTH, floori(float(id) / WorldMapScript.WORLD_WIDTH))
		var center := world.tile_center(tile.x, tile.y)
		var corners := PackedVector2Array()
		for vertex in WorldMapScript.TILE_VERTICES:
			corners.append(center + world.project_tile_offset(vertex))
		canvas.draw_polygon(corners, PackedColorArray([Color.WHITE]), PackedVector2Array(WorldMapScript.SHORE_UVS), world.get_shoreline_texture(tile))
		var shore: Dictionary = world.shoreline_tiles[id]
		for ripple in shore["ripples"]:
			canvas.draw_line(center + ripple[0], center + ripple[1], Color("#b3d7c5", 0.20), -1.0, false)


func build_scenery_mesh(is_dry_season := false, x0 := 0, y0 := 0, x1 := WorldMapScript.WORLD_WIDTH, y1 := WorldMapScript.WORLD_HEIGHT) -> ArrayMesh:
	var mb := MeshBuilder2D.new(65536, 131072)
	var min_depth := x0 + y0
	var max_depth := (x1 - 1) + (y1 - 1)
	for depth in range(min_depth, max_depth + 1):
		var min_x := maxi(x0, depth - (y1 - 1))
		var max_x := mini(x1 - 1, depth - y0)
		for x in range(min_x, max_x + 1):
			var y := depth - x
			var tile := Vector2i(x, y)
			var center := world.tile_center(x, y)
			_emit_terrain_details(mb, center, world.terrain_at(tile), x, y, is_dry_season)
	return mb.commit()


func _emit_terrain_ground(mb: MeshBuilder2D, center: Vector2, tile: Vector2i, terrain: String, is_dry_season: bool) -> void:
	var color := Color("#a39b59")
	match terrain:
		"woodland": color = Color("#687d49")
		"wetland": color = Color("#829258")
		"dryland": color = Color("#b39662")
		"highland": color = Color("#817b58")
		"volcanic": color = Color("#8c7057")
		"river", "lake": color = Color("#93875a")
	if is_dry_season and terrain in ["savanna", "woodland", "wetland", "dryland"]:
		color = color.lerp(Color("#b69a62"), 0.20)
	var c0 := center + world.project_tile_offset(WorldMapScript.TILE_VERTICES[0])
	var c1 := center + world.project_tile_offset(WorldMapScript.TILE_VERTICES[1])
	var c2 := center + world.project_tile_offset(WorldMapScript.TILE_VERTICES[2])
	var c3 := center + world.project_tile_offset(WorldMapScript.TILE_VERTICES[3])
	var s0 := world.terrain_noise.get_noise_2dv(Vector2(tile) + WorldMapScript.TILE_VERTICES[0]) * 0.36
	var s1 := world.terrain_noise.get_noise_2dv(Vector2(tile) + WorldMapScript.TILE_VERTICES[1]) * 0.36
	var s2 := world.terrain_noise.get_noise_2dv(Vector2(tile) + WorldMapScript.TILE_VERTICES[2]) * 0.36
	var s3 := world.terrain_noise.get_noise_2dv(Vector2(tile) + WorldMapScript.TILE_VERTICES[3]) * 0.36
	var col0 := color.lightened(s0) if s0 >= 0.0 else color.darkened(-s0)
	var col1 := color.lightened(s1) if s1 >= 0.0 else color.darkened(-s1)
	var col2 := color.lightened(s2) if s2 >= 0.0 else color.darkened(-s2)
	var col3 := color.lightened(s3) if s3 >= 0.0 else color.darkened(-s3)
	mb.add_quad(c0, c1, c2, c3, col0, col1, col2, col3)
	if not world.get_shoreline(tile).is_empty():
		return
	var texture_color := Color("#d1bc76", 0.24)
	if terrain == "woodland":
		texture_color = Color("#354b35", 0.32)
	elif terrain == "dryland":
		texture_color = Color("#765d38", 0.28)
	elif terrain in ["highland", "volcanic"]:
		texture_color = Color("#c3b58d", 0.18)
	for i in range(6):
		var local_y := -10.0 + world.tile_noise(tile.x, tile.y, i + 2) * 20.0
		var half_width := 34.0 * (1.0 - absf(local_y) / 27.0)
		var local_x := (world.tile_noise(tile.x, tile.y, i + 12) * 2.0 - 1.0) * half_width
		var mark := center + Vector2(local_x, local_y)
		if i % 3 == 0:
			mb.add_quad_solid(mark + Vector2(-1, -1), mark + Vector2(1, -1), mark + Vector2(1, 1), mark + Vector2(-1, 1), texture_color)
		else:
			mb.add_line(mark, mark + Vector2(4.0 + float(i % 2) * 3.0, -1.0), texture_color, 0.9)


func _emit_terrain_details(mb: MeshBuilder2D, center: Vector2, terrain: String, x: int, y: int, is_dry_season: bool) -> void:
	var shore := world.get_shoreline(Vector2i(x, y))
	if not shore.is_empty():
		for i in range(6):
			var point := _vegetation_point(center, x, y, i, 6)
			var wet := false
			var bank := false
			for water in shore["water"]:
				if Geometry2D.is_point_in_polygon(point - center, water):
					wet = true
					break
			for bank_mask in shore["bank"]:
				if Geometry2D.is_point_in_polygon(point - center, bank_mask):
					bank = true
					break
			if wet:
				continue
			if bank and world.tile_noise(x, y, i + 91) > 0.58:
				_emit_reeds(mb, point)
			elif not bank:
				_emit_tall_grass(mb, point, 0.58, Color("#9b9358"))
			else:
				mb.add_circle(point, 0.95, Color("#665c44", 0.65), 5)
		return
	var variation := world.tile_noise(x, y, 202)
	match terrain:
		"highland":
			_emit_civ3_hills_tile(mb, center, x, y, variation, is_dry_season)
		"volcanic":
			_emit_volcanic_tile(mb, center, x, y, variation, is_dry_season)
		"dryland":
			mb.add_quad_solid(
				center + Vector2(-21, 8), center + Vector2(-5, -8),
				center + Vector2(16, 5), center + Vector2(7, 13),
				Color("#b59a64", 0.5)
			)
	_emit_tile_vegetation(mb, center, terrain, x, y, variation)
	var detail := posmod(x * 37 + y * 19, 7)
	if terrain not in ["river", "lake"]:
		if detail == 0:
			_emit_flower(mb, center + Vector2(-20, 8), Color("#d9a867"))
		elif detail == 1 or detail == 4:
			_emit_boulder(mb, center + Vector2(18, 7), 0.65 + variation * 0.4)
		elif detail == 3:
			_emit_grass(mb, center + Vector2(18, 7), Color("#857b4d", 0.8))
		elif detail == 5:
			var pc := Color("#756b47", 0.55)
			mb.add_circle(center + Vector2(12, 6), 1.1, pc, 5)
			mb.add_circle(center + Vector2(15, 8), 1.1, pc, 5)
			mb.add_circle(center + Vector2(20, 4), 1.1, pc, 5)
			mb.add_circle(center + Vector2(23, 6), 1.1, pc, 5)
	if terrain == "lake" and detail == 0:
		mb.add_circle(center + Vector2(-17, 7), 2.0, Color("#a8b879", 0.85), 6)


func _emit_civ3_hills_tile(mb: MeshBuilder2D, center: Vector2, x: int, y: int, variation: float, is_dry_season: bool) -> void:
	var relief := world.terrain_noise.get_noise_2d(x - 9, y + 15)
	var n_up: bool = world.terrain_at(Vector2i(x, y - 1)) == "highland"
	var n_right: bool = world.terrain_at(Vector2i(x + 1, y)) == "highland"
	var n_down: bool = world.terrain_at(Vector2i(x, y + 1)) == "highland"
	var n_left: bool = world.terrain_at(Vector2i(x - 1, y)) == "highland"
	var neighbors := int(n_up) + int(n_right) + int(n_down) + int(n_left)
	var lit := Color("#b7ad72") if not is_dry_season else Color("#c6ae73")
	var mid := Color("#888856") if not is_dry_season else Color("#9a8b5a")
	var shade := Color("#555c47") if not is_dry_season else Color("#655b48")
	var skirt := Color("#7d7c54") if not is_dry_season else Color("#8f8358")
	if n_up:
		_emit_hill_dome(mb, center + Vector2(20, -10), 26.0, 14.0, -2.0, lit.darkened(0.04), mid, shade, skirt, false)
	if n_left:
		_emit_hill_dome(mb, center + Vector2(-21, -9), 26.0, 14.0, 2.0, lit, mid, shade, skirt, false)
	var base_h := 20.0 + relief * 6.0 + variation * 7.0
	var lean := lerpf(-4.5, 4.5, world.tile_noise(x, y, 225))
	_emit_hill_dome(mb, center + Vector2(16, -4), 29.0, base_h * 0.86, -lean * 0.6, lit.darkened(0.03), mid, shade, skirt, false)
	if neighbors >= 3:
		var rock_lit := Color("#cec1a1") if not is_dry_season else Color("#d6c29d")
		_emit_hill_dome(mb, center + Vector2(-4, 2), 37.0, base_h + 14.0, lean * 0.7, rock_lit, Color("#998e77"), Color("#5c564f"), skirt, true)
		_emit_hill_dome(mb, center + Vector2(-17, 10), 24.0, base_h * 0.68, -2.0, lit, mid, shade, skirt, false)
	else:
		_emit_hill_dome(mb, center + Vector2(-7, 5), 35.0, base_h, lean, lit, mid, shade, skirt, false)
		if variation > 0.35:
			_emit_hill_dome(mb, center + Vector2(18, 10), 23.0, base_h * 0.62, lean * 0.4, lit, mid, shade, skirt, false)
	if n_right:
		_emit_hill_dome(mb, center + Vector2(22, 11), 24.0, 13.0, -1.5, lit, mid, shade, skirt, false)
	if n_down:
		_emit_hill_dome(mb, center + Vector2(-19, 12), 24.0, 13.0, 1.5, lit, mid, shade, skirt, false)
	if variation > 0.55:
		_emit_boulder(mb, center + Vector2(-13, 3), 0.55)
	_emit_grass(mb, center + Vector2(8, 8), Color("#6d7949", 0.72))


func _emit_hill_dome(mb: MeshBuilder2D, base: Vector2, radius_x: float, height: float, lean: float, lit: Color, mid: Color, shade: Color, skirt: Color, rocky: bool) -> void:
	mb.add_ellipse(base + Vector2(5.0, 3.0), Vector2(radius_x * 0.96, radius_x * 0.28), Color(0, 0, 0, 0.20), 8)
	var steps := 8
	var cols_n := steps + 1
	var ridge := PackedVector2Array()
	var lower := PackedVector2Array()
	ridge.resize(cols_n)
	lower.resize(cols_n)
	var exp_pow := 0.85 if rocky else 1.12
	# Emit shared-vertex 3-row strip (ridge, mid, skirt) for smooth NW->SE shading with minimal vertices.
	mb._reserve(cols_n * 3, steps * 12)
	var v_base := mb.v_count
	for i in range(cols_n):
		var t := float(i) / float(steps)
		var u := t * 2.0 - 1.0
		var bell := pow(0.5 * (1.0 + cos(u * PI)), exp_pow)
		var r_pt := Vector2(base.x + u * radius_x + lean * bell, base.y - height * bell)
		var l_pt := Vector2(base.x + u * radius_x, base.y + sin(t * PI) * (radius_x * 0.24))
		ridge[i] = r_pt
		lower[i] = l_pt
		var m_pt := r_pt.lerp(l_pt, 0.48)
		var ridge_col := lit.lerp(mid, smoothstep(0.18, 0.56, t)).lerp(shade, smoothstep(0.48, 0.90, t)).lightened(0.10 * (1.0 - smoothstep(0.25, 0.72, t)))
		var mid_col := lit.lerp(mid, smoothstep(0.15, 0.52, t)).lerp(shade, smoothstep(0.46, 0.88, t))
		var skirt_col := skirt.lerp(mid_col, 0.42)
		var idx := v_base + i * 3
		mb.verts[idx] = r_pt
		mb.verts[idx + 1] = m_pt
		mb.verts[idx + 2] = l_pt
		mb.cols[idx] = skirt_col if (i == 0 or i == steps) else ridge_col
		mb.cols[idx + 1] = skirt_col if (i == 0 or i == steps) else mid_col
		mb.cols[idx + 2] = skirt_col
	mb.v_count += cols_n * 3
	var ii := mb.i_count
	for i in range(steps):
		var a := v_base + i * 3
		var b := a + 3
		# Upper strip (ridge -> mid)
		mb.indices[ii] = a
		mb.indices[ii + 1] = b
		mb.indices[ii + 2] = b + 1
		mb.indices[ii + 3] = a
		mb.indices[ii + 4] = b + 1
		mb.indices[ii + 5] = a + 1
		# Lower strip (mid -> skirt)
		mb.indices[ii + 6] = a + 1
		mb.indices[ii + 7] = b + 1
		mb.indices[ii + 8] = b + 2
		mb.indices[ii + 9] = a + 1
		mb.indices[ii + 10] = b + 2
		mb.indices[ii + 11] = a + 2
		ii += 12
	mb.i_count = ii
	var brow := PackedVector2Array()
	for i in range(1, 5):
		brow.append(ridge[i].lerp(lower[i], 0.16))
	mb.add_polyline(brow, lit.lightened(0.24) * Color(1, 1, 1, 0.55), 1.4)
	var shadow_fold := PackedVector2Array()
	for i in range(5, steps):
		shadow_fold.append(ridge[i].lerp(lower[i], 0.34))
	mb.add_polyline(shadow_fold, shade.darkened(0.25) * Color(1, 1, 1, 0.45), 1.3)
	if rocky:
		var crown := ridge[steps / 2].lerp(lower[steps / 2], 0.28)
		mb.add_line(crown + Vector2(-8, 2), crown + Vector2(5, 5), Color("#ebe0c5", 0.42), 1.1)
		mb.add_line(crown + Vector2(-12, 8), crown + Vector2(2, 11), Color("#46403a", 0.36), 1.1)


func _emit_volcanic_tile(mb: MeshBuilder2D, center: Vector2, x: int, y: int, variation: float, is_dry_season: bool) -> void:
	var h := 18.0 + variation * 9.0
	var lean := lerpf(-3.0, 3.0, world.tile_noise(x, y, 311))
	var lit := Color("#a58869") if not is_dry_season else Color("#b3926d")
	var mid := Color("#766353")
	var shade := Color("#473f39")
	var skirt := Color("#7f6954")
	_emit_hill_dome(mb, center + Vector2(18, -3), 22.0, h * 0.65, -lean, lit.darkened(0.08), mid, shade, skirt, true)
	_emit_hill_dome(mb, center + Vector2(-4, 6), 31.0, h, lean, lit, mid, shade, skirt, true)
	var rim := center + Vector2(-4 + lean, 6 - h + 3.0)
	mb.add_arc(rim, 4.5, PI, TAU, 8, Color("#bf6b4a", 0.85), 1.5)


func _emit_tile_vegetation(mb: MeshBuilder2D, center: Vector2, terrain: String, x: int, y: int, variation: float) -> void:
	match terrain:
		"woodland":
			for i in range(7):
				var point := _vegetation_point(center, x, y, i, 7)
				if i in [1, 4]:
					_emit_shrub(mb, point + Vector2(0, 2), 0.65 + world.tile_noise(x, y, i + 90) * 0.35, Color("#52683f"))
				elif i % 3 == 0:
					_emit_acacia(mb, point, 0.72 + world.tile_noise(x, y, i + 80) * 0.28, Color("#3d593b"))
				else:
					_emit_tree(mb, point, world.tile_noise(x, y, i + 70))
		"savanna":
			for i in range(5):
				var grass_point := _vegetation_point(center, x, y, i, 5)
				_emit_tall_grass(mb, grass_point, 0.65 + world.tile_noise(x, y, i + 30) * 0.5, Color("#c5ad63"))
			var grove := world.terrain_noise.get_noise_2d(x + 19, y - 11)
			var tree_count := 2 if grove > 0.18 else int(grove > -0.04)
			for i in range(tree_count):
				_emit_acacia(mb, _vegetation_point(center, x, y, i + 6, tree_count + 7), 0.72 + world.tile_noise(x, y, i + 60) * 0.28, Color("#50663d"))
		"dryland":
			for i in range(4):
				var dry_point := _vegetation_point(center, x, y, i, 4)
				if i % 2 == 0:
					_emit_shrub(mb, dry_point, 0.55 + world.tile_noise(x, y, i + 20) * 0.35, Color("#766c43"))
				else:
					_emit_tall_grass(mb, dry_point, 0.65, Color("#8c7847"))
		"wetland":
			for i in range(3):
				_emit_reeds(mb, _vegetation_point(center, x, y, i, 3))
			if variation > 0.8:
				_emit_palm(mb, center + Vector2(18, 7), 0.78 + variation * 0.2)
		"highland":
			for i in range(3):
				var high_point := _vegetation_point(center, x, y, i, 3)
				_emit_shrub(mb, high_point, 0.48 + variation * 0.25, Color("#626a4d"))
		"volcanic":
			if variation > 0.45:
				_emit_shrub(mb, center + Vector2(-24, 9), 0.55, Color("#766a48"))


func _emit_tree(mb: MeshBuilder2D, point: Vector2, size: float) -> void:
	var scale := 0.68 + size * 0.38
	mb.add_ellipse(point + Vector2(1, 5), Vector2(12, 3) * scale, Color(0, 0, 0, 0.22), 6)
	mb.add_line(point + Vector2(0, 7 * scale), point + Vector2(0, -8 * scale), Color("#68563a"), 2.2 * scale)
	mb.add_line(point + Vector2(0, -5 * scale), point + Vector2(-7, -11) * scale, Color("#735f3e"), 1.4 * scale)
	mb.add_line(point + Vector2(1, -7 * scale), point + Vector2(8, -12) * scale, Color("#594a34"), 1.2 * scale)
	mb.add_poly_solid(PackedVector2Array([
		point + Vector2(-12 * scale, -5 * scale), point + Vector2(-8 * scale, -13 * scale),
		point + Vector2(-2 * scale, -12 * scale), point + Vector2(3 * scale, -17 * scale),
		point + Vector2(12 * scale, -11 * scale), point + Vector2(10 * scale, -4 * scale),
		point + Vector2(3 * scale, -2 * scale), point + Vector2(-5 * scale, -3 * scale)
	]), Color("#435d3e").lightened(size * 0.12))
	mb.add_circle(point + Vector2(-5 * scale, -9 * scale), 5.0 * scale, Color("#435d3e").darkened(0.08), 6)
	mb.add_circle(point + Vector2(3 * scale, -10 * scale), 6.0 * scale, Color("#435d3e").lightened(0.12), 6)
	mb.add_circle(point + Vector2(0, -14 * scale), 4.0 * scale, Color("#526c46").lightened(size * 0.12), 6)
	_emit_leaf_texture(mb, point + Vector2(-5, -10) * scale, Vector2(5.5, 3.3) * scale, Color("#56704a"), 4)
	_emit_leaf_texture(mb, point + Vector2(4, -10) * scale, Vector2(6.5, 4.5) * scale, Color("#607950"), 4)
	_emit_leaf_texture(mb, point + Vector2(1, -14) * scale, Vector2(4.0, 3.2) * scale, Color("#6c8051"), 3)


func _emit_acacia(mb: MeshBuilder2D, point: Vector2, scale: float, foliage: Color) -> void:
	mb.add_ellipse(point + Vector2(2, 4), Vector2(15, 3) * scale, Color(0, 0, 0, 0.22), 6)
	mb.add_line(point + Vector2(0, 5) * scale, point + Vector2(1, -11) * scale, Color("#665035"), 2.2 * scale)
	mb.add_line(point + Vector2(1, -6) * scale, point + Vector2(-9, -13) * scale, Color("#665035"), 1.4 * scale)
	mb.add_line(point + Vector2(1, -7) * scale, point + Vector2(10, -14) * scale, Color("#59462f"), 1.4 * scale)
	mb.add_poly_solid(PackedVector2Array([
		point + Vector2(-17, -12) * scale, point + Vector2(-12, -18) * scale,
		point + Vector2(-2, -19) * scale, point + Vector2(4, -22) * scale,
		point + Vector2(15, -18) * scale, point + Vector2(19, -12) * scale,
		point + Vector2(10, -9) * scale, point + Vector2(-10, -9) * scale
	]), foliage)
	mb.add_circle(point + Vector2(-8, -15) * scale, 5.2 * scale, foliage.darkened(0.08), 6)
	mb.add_circle(point + Vector2(5, -16) * scale, 6.0 * scale, foliage.lightened(0.09), 6)
	_emit_leaf_texture(mb, point + Vector2(-10, -13) * scale, Vector2(6.0, 3.5) * scale, foliage, 3)
	_emit_leaf_texture(mb, point + Vector2(-1, -16) * scale, Vector2(7.0, 3.1) * scale, foliage.lightened(0.07), 4)
	_emit_leaf_texture(mb, point + Vector2(8, -17) * scale, Vector2(6.5, 3.5) * scale, foliage.lightened(0.13), 4)
	_emit_leaf_texture(mb, point + Vector2(11, -12) * scale, Vector2(5.5, 2.1) * scale, foliage.darkened(0.07), 3)


func _emit_leaf_texture(mb: MeshBuilder2D, center: Vector2, radii: Vector2, foliage: Color, count: int) -> void:
	var rotation := fposmod(center.x * 0.71 + center.y * 0.37, TAU)
	for i in range(count):
		var angle := float(i) * 2.399963 + rotation
		var offset := Vector2.from_angle(angle) * sqrt((float(i) + 0.5) / float(count))
		var leaf := center + offset * radii
		var stroke := Vector2.from_angle(angle * 1.7) * lerpf(1.1, 1.9, absf(cos(angle * 2.0)))
		var perp := Vector2(-stroke.y, stroke.x) * 0.55
		var shade := sin(angle * 3.0) * 0.22 - offset.y * 0.22 - offset.x * 0.08
		var color := foliage.lerp(Color("#c2c77a"), shade + 0.12) if shade >= 0.0 else foliage.darkened(-shade)
		mb.add_tri(leaf - stroke, leaf + stroke, leaf + perp, color, color, color)


func _emit_shrub(mb: MeshBuilder2D, point: Vector2, scale: float, foliage: Color) -> void:
	mb.add_ellipse(point + Vector2(1, 2), Vector2(8, 2) * scale, Color(0, 0, 0, 0.22), 6)
	for branch in range(3):
		var offset := float(branch - 1) * 3.0
		mb.add_line(point + Vector2(offset, 2) * scale, point + Vector2(offset * 1.6, -7 - branch % 2) * scale, Color("#65553b"), 1.0)
	mb.add_circle(point + Vector2(-5, -5) * scale, 4.5 * scale, foliage.darkened(0.08), 5)
	mb.add_circle(point + Vector2(1, -7) * scale, 5.0 * scale, foliage, 5)
	mb.add_circle(point + Vector2(6, -4) * scale, 4.0 * scale, foliage.lightened(0.1), 5)


func _emit_tall_grass(mb: MeshBuilder2D, point: Vector2, scale: float, color: Color) -> void:
	for blade in range(4):
		var root := point + Vector2(float(blade) * 2.5 - 3.8, float(blade % 2))
		var tip := root + Vector2((float(blade) - 1.5) * 1.6, (-7.0 - float(blade % 3)) * scale)
		var col := color.lightened(float(blade) * 0.025)
		mb.add_tri(root + Vector2(-0.7, 0.0), root + Vector2(0.7, 0.0), tip, col, col, col)


func _emit_grass(mb: MeshBuilder2D, point: Vector2, color: Color) -> void:
	mb.add_tri(point + Vector2(-0.7, 0.0), point + Vector2(0.7, 0.0), point + Vector2(-3, -7), color, color, color)
	mb.add_tri(point + Vector2(1.3, 1.0), point + Vector2(2.7, 1.0), point + Vector2(5, -6), color, color, color)
	mb.add_tri(point + Vector2(5.3, 2.0), point + Vector2(6.7, 2.0), point + Vector2(9, -3), color, color, color)


func _emit_flower(mb: MeshBuilder2D, point: Vector2, color: Color) -> void:
	mb.add_line(point + Vector2(0, 3), point + Vector2(0, -2), Color("#667448"), 1.0)
	mb.add_circle(point + Vector2(-2, -3), 1.5, color.darkened(0.08), 5)
	mb.add_circle(point + Vector2(2, -3), 1.5, color.lightened(0.08), 5)
	mb.add_circle(point + Vector2(0, -4), 1.4, Color("#f0d38d"), 5)


func _emit_boulder(mb: MeshBuilder2D, point: Vector2, size: float) -> void:
	mb.add_poly_solid(PackedVector2Array([
		point + Vector2(-6 * size, 2 * size), point + Vector2(-4 * size, -3 * size),
		point + Vector2(1 * size, -5 * size), point + Vector2(6 * size, -2 * size),
		point + Vector2(5 * size, 3 * size)
	]), Color("#776f57"))
	mb.add_line(point + Vector2(-3 * size, -2 * size), point + Vector2(1 * size, -4 * size), Color("#b2a27a", 0.7), 1.0)


func _emit_reeds(mb: MeshBuilder2D, point: Vector2) -> void:
	var reed := Color("#9ba36a", 0.8)
	mb.add_line(point, point + Vector2(-3, -10), reed, 1.1)
	mb.add_line(point + Vector2(2, 1), point + Vector2(3, -12), reed, 1.1)
	mb.add_line(point + Vector2(5, 2), point + Vector2(9, -7), reed, 1.1)
	mb.add_line(point + Vector2(-2, 1), point + Vector2(-7, -6), reed.darkened(0.12), 1.0)
	mb.add_circle(point + Vector2(3, -12), 1.2, Color("#6f5e3e"), 5)
	mb.add_circle(point + Vector2(-3, -10), 1.0, Color("#796746"), 5)


func _emit_palm(mb: MeshBuilder2D, point: Vector2, scale: float) -> void:
	mb.add_ellipse(point + Vector2(3, 4), Vector2(12, 3) * scale, Color(0, 0, 0, 0.22), 8)
	mb.add_line(point + Vector2(0, 5) * scale, point + Vector2(2, -17) * scale, Color("#7c6038"), 2.6 * scale)
	mb.add_line(point + Vector2(1, -5) * scale, point + Vector2(3, -16) * scale, Color("#b08a50", 0.75), 0.9)
	var crown := point + Vector2(2, -17) * scale
	for direction in [Vector2(-14, -4), Vector2(-11, 3), Vector2(-4, -8), Vector2(7, -8), Vector2(14, -3), Vector2(11, 4)]:
		var tip: Vector2 = crown + direction * scale
		mb.add_line(crown, tip, Color("#4f7047"), 2.0 * scale)
		var axis := (tip - crown).normalized()
		for leaflet in range(1, 5):
			var fraction := float(leaflet) / 5.0
			var stem := crown.lerp(tip, fraction)
			var spread := sin(fraction * PI) * 3.2 * scale
			var sweep := axis * spread * 0.58
			mb.add_line(stem, stem + sweep + axis.orthogonal() * spread, Color("#8a9b60"), 0.9)
			mb.add_line(stem, stem + sweep - axis.orthogonal() * spread, Color("#496a43"), 0.9)
	mb.add_circle(crown + Vector2(-2, 2) * scale, 2.0 * scale, Color("#705436"), 5)
	mb.add_circle(crown + Vector2(2, 2) * scale, 2.0 * scale, Color("#705436"), 5)


func draw_baked_rect(
	canvas: CanvasItem,
	world_rect: Rect2,
	discovered_landmarks: Dictionary,
	is_dry_season := false,
	depleted_tiles: Dictionary = {},
	wildfire_tiles: Dictionary = {}
) -> void:
	canvas.draw_rect(world_rect, Color("#182826"))
	var pad := Vector2(WorldMapScript.TILE_W, WorldMapScript.TILE_H + 84.0)
	var first := (world_rect.position - pad) - WorldMapScript.MAP_ORIGIN
	var last := (world_rect.end + pad) - WorldMapScript.MAP_ORIGIN
	var min_depth := maxi(0, ceili(first.y / (WorldMapScript.TILE_H * 0.5)))
	var max_depth := mini(WorldMapScript.WORLD_WIDTH + WorldMapScript.WORLD_HEIGHT - 2, floori(last.y / (WorldMapScript.TILE_H * 0.5)))
	var min_diagonal := first.x / (WorldMapScript.TILE_W * 0.5)
	var max_diagonal := last.x / (WorldMapScript.TILE_W * 0.5)

	var tiles: Array[Vector2i] = []
	for depth in range(min_depth, max_depth + 1):
		var min_x := maxi(maxi(0, depth - WorldMapScript.WORLD_HEIGHT + 1), ceili((depth + min_diagonal) * 0.5))
		var max_x := mini(mini(depth, WorldMapScript.WORLD_WIDTH - 1), floori((depth + max_diagonal) * 0.5))
		for x in range(min_x, max_x + 1):
			var tile := Vector2i(x, depth - x)
			tiles.append(tile)
			var center := world.tile_center(tile.x, tile.y)
			var id := world.tile_id(tile)
			var fire_state := str(wildfire_tiles.get(id, {}).get("state", ""))
			_draw_terrain_ground(canvas, center, tile, world.terrain_at(tile), is_dry_season, depleted_tiles.has(id), fire_state)
	for tile in tiles:
		var center := world.tile_center(tile.x, tile.y)
		var id := world.tile_id(tile)
		var fire_info: Dictionary = wildfire_tiles.get(id, {})
		if fire_info.is_empty():
			_draw_terrain_details(canvas, center, world.terrain_at(tile), tile.x, tile.y, is_dry_season)
		else:
			_draw_wildfire_details(canvas, center, fire_info, tile.x, tile.y)
		if depleted_tiles.has(id):
			_draw_depleted_mark(canvas, center)
		var landmark := world.landmark_for_tile(tile)
		if not landmark.is_empty():
			_draw_landmark_icon(canvas, center, str(landmark["kind"]), is_dry_season, discovered_landmarks.has(id))


func draw_baked_chunk(
	canvas: CanvasItem,
	x0: int,
	y0: int,
	x1: int,
	y1: int,
	discovered_landmarks: Dictionary,
	is_dry_season := false,
	depleted_tiles: Dictionary = {},
	wildfire_tiles: Dictionary = {}
) -> void:
	draw_ground_chunk(canvas, x0, y0, x1, y1, is_dry_season, depleted_tiles, wildfire_tiles)
	draw_scenery_chunk(canvas, x0, y0, x1, y1, discovered_landmarks, is_dry_season, depleted_tiles, wildfire_tiles)


func draw_ground_chunk(
	canvas: CanvasItem,
	x0: int,
	y0: int,
	x1: int,
	y1: int,
	is_dry_season := false,
	depleted_tiles: Dictionary = {},
	wildfire_tiles: Dictionary = {}
) -> void:
	for y in range(y0, y1):
		for x in range(x0, x1):
			var tile := Vector2i(x, y)
			var center := world.tile_center(x, y)
			var id := world.tile_id(tile)
			var fire_state := str(wildfire_tiles.get(id, {}).get("state", ""))
			_draw_terrain_ground(canvas, center, tile, world.terrain_at(tile), is_dry_season, depleted_tiles.has(id), fire_state)


func draw_scenery_chunk(
	canvas: CanvasItem,
	x0: int,
	y0: int,
	x1: int,
	y1: int,
	discovered_landmarks: Dictionary,
	is_dry_season := false,
	depleted_tiles: Dictionary = {},
	wildfire_tiles: Dictionary = {}
) -> void:
	var min_depth := x0 + y0
	var max_depth := (x1 - 1) + (y1 - 1)
	for depth in range(min_depth, max_depth + 1):
		var min_x := maxi(x0, depth - (y1 - 1))
		var max_x := mini(x1 - 1, depth - y0)
		for x in range(min_x, max_x + 1):
			var y := depth - x
			var tile := Vector2i(x, y)
			var center := world.tile_center(x, y)
			var id := world.tile_id(tile)
			var fire_info: Dictionary = wildfire_tiles.get(id, {})
			if fire_info.is_empty():
				_draw_terrain_details(canvas, center, world.terrain_at(tile), x, y, is_dry_season)
			else:
				_draw_wildfire_details(canvas, center, fire_info, x, y)
			if depleted_tiles.has(id):
				_draw_depleted_mark(canvas, center)
			var landmark := world.landmark_for_tile(tile)
			if not landmark.is_empty():
				_draw_landmark_icon(canvas, center, str(landmark["kind"]), is_dry_season, discovered_landmarks.has(id))


func draw_dynamic_world(
	canvas: CanvasItem,
	map_view: Rect2,
	world_to_screen: Callable,
	collectibles: Dictionary,
	carcass_sites: Dictionary,
	player_actor: Dictionary,
	ai_bands: Array[Dictionary],
	wildlife: Array[Dictionary],
	discovered_landmarks: Dictionary = {},
	is_dry_season := false,
	depleted_tiles: Dictionary = {},
	wildfire_tiles: Dictionary = {}
) -> void:
	var padded := map_view.grow(80.0)
	for id in depleted_tiles:
		var tile := Vector2i(int(id) % WorldMapScript.WORLD_WIDTH, floori(float(id) / WorldMapScript.WORLD_WIDTH))
		var center := world.tile_center(tile.x, tile.y)
		if padded.has_point(world_to_screen.call(center)):
			var corners := PackedVector2Array()
			for vertex in WorldMapScript.TILE_VERTICES:
				corners.append(center + world.project_tile_offset(vertex))
			canvas.draw_colored_polygon(corners, Color(0.08, 0.07, 0.05, 0.22))
			_draw_depleted_mark(canvas, center)
	for id in wildfire_tiles:
		var tile := Vector2i(int(id) % WorldMapScript.WORLD_WIDTH, floori(float(id) / WorldMapScript.WORLD_WIDTH))
		var center := world.tile_center(tile.x, tile.y)
		if padded.has_point(world_to_screen.call(center)):
			var fire_info: Dictionary = wildfire_tiles[id]
			var state := str(fire_info.get("state", ""))
			var tint := Color("#3a271f", 0.78) if state == "burning" else (Color("#4a423a", 0.68) if state == "cooled" else Color("#597b45", 0.45))
			var corners := PackedVector2Array()
			for vertex in WorldMapScript.TILE_VERTICES:
				corners.append(center + world.project_tile_offset(vertex))
			canvas.draw_colored_polygon(corners, tint)
			_draw_wildfire_details(canvas, center, fire_info, tile.x, tile.y)
	for landmark in WorldMapScript.LANDMARKS:
		var tile: Vector2i = landmark["tile"]
		var center := world.tile_center(tile.x, tile.y)
		if padded.has_point(world_to_screen.call(center)):
			var id := world.tile_id(tile)
			_draw_landmark_icon(canvas, center, str(landmark["kind"]), is_dry_season, discovered_landmarks.has(id))
	for id in carcass_sites:
		var tile := Vector2i(int(id) % WorldMapScript.WORLD_WIDTH, floori(float(id) / WorldMapScript.WORLD_WIDTH))
		var center := world.tile_center(tile.x, tile.y)
		if padded.has_point(world_to_screen.call(center)):
			_draw_carcass_icon(canvas, center)
	for item in collectibles.values():
		if padded.has_point(world_to_screen.call(item["at"])):
			_draw_collectible(canvas, item)
	draw_actor_shadows(canvas, map_view, world_to_screen, player_actor, ai_bands, wildlife)


func draw_map(
	canvas: CanvasItem,
	map_view: Rect2,
	zoom_level: float,
	screen_to_world: Callable,
	explored_tiles: Dictionary,
	discovered_landmarks: Dictionary,
	is_dry_season := false,
	depleted_tiles: Dictionary = {},
	carcass_sites: Dictionary = {},
	wildfire_tiles: Dictionary = {},
	collectibles: Dictionary = {}
) -> void:
	var visible: Array[Vector2i] = []
	var extent := Vector2(WorldMapScript.TILE_W * 0.5, WorldMapScript.TILE_H * 0.5 + 72.0) * zoom_level
	var first: Vector2 = screen_to_world.call(map_view.position - extent) - WorldMapScript.MAP_ORIGIN
	var last: Vector2 = screen_to_world.call(map_view.end + extent) - WorldMapScript.MAP_ORIGIN
	var min_depth := maxi(0, ceili(first.y / (WorldMapScript.TILE_H * 0.5)))
	var max_depth := mini(WorldMapScript.WORLD_WIDTH + WorldMapScript.WORLD_HEIGHT - 2, floori(last.y / (WorldMapScript.TILE_H * 0.5)))
	var min_diagonal := first.x / (WorldMapScript.TILE_W * 0.5)
	var max_diagonal := last.x / (WorldMapScript.TILE_W * 0.5)

	# Paint every ground tile before its raised scenery, then draw scenery back to front.
	for depth in range(min_depth, max_depth + 1):
		var min_x := maxi(maxi(0, depth - WorldMapScript.WORLD_HEIGHT + 1), ceili((depth + min_diagonal) * 0.5))
		var max_x := mini(mini(depth, WorldMapScript.WORLD_WIDTH - 1), floori((depth + max_diagonal) * 0.5))
		for x in range(min_x, max_x + 1):
			var tile := Vector2i(x, depth - x)
			var center := world.tile_center(tile.x, tile.y)
			var id := world.tile_id(tile)
			if explored_tiles.has(id):
				visible.append(tile)
				var fire_state := str(wildfire_tiles.get(id, {}).get("state", ""))
				_draw_terrain_ground(canvas, center, tile, world.terrain_at(tile), is_dry_season, depleted_tiles.has(id), fire_state)
			else:
				_draw_unexplored_tile(canvas, center, tile.x, tile.y)
	for tile in visible:
		var center := world.tile_center(tile.x, tile.y)
		var id := world.tile_id(tile)
		_draw_exploration_frontier(canvas, center, tile, explored_tiles)
		var fire_info: Dictionary = wildfire_tiles.get(id, {})
		if fire_info.is_empty():
			_draw_terrain_details(canvas, center, world.terrain_at(tile), tile.x, tile.y)
		else:
			_draw_wildfire_details(canvas, center, fire_info, tile.x, tile.y)
		if depleted_tiles.has(id):
			_draw_depleted_mark(canvas, center)
		if carcass_sites.has(id):
			_draw_carcass_icon(canvas, center)
		if collectibles.has(id):
			_draw_collectible(canvas, collectibles[id])
	for tile in visible:
		var id := world.tile_id(tile)
		if discovered_landmarks.has(id):
			var landmark := world.landmark_for_tile(tile)
			if not landmark.is_empty():
				_draw_landmark_icon(canvas, world.tile_center(tile.x, tile.y), str(landmark["kind"]), is_dry_season)


func draw_actor_shadows(
	canvas: CanvasItem,
	map_view: Rect2,
	world_to_screen: Callable,
	player_actor: Dictionary,
	ai_bands: Array[Dictionary],
	wildlife: Array[Dictionary]
) -> void:
	var player_position: Vector2 = player_actor["position"]
	if map_view.grow(65.0).has_point(world_to_screen.call(player_position)):
		var family_size := int(player_actor.get("family_size", 1))
		var shadow_radii := Vector2(16.0, 5.0) if family_size <= 1 else (Vector2(28.0, 7.0) if family_size == 2 else Vector2(34.0, 8.5))
		draw_ellipse_shadow(canvas, player_position + Vector2(0.0, 4.0), shadow_radii)
	for band in ai_bands:
		var opacity: float = band["opacity"]
		if opacity <= 0.0:
			continue
		var position: Vector2 = band["position"]
		if map_view.grow(65.0).has_point(world_to_screen.call(position)):
			if str(band.get("attitude", "friendly")) == "hostile":
				var hring := PackedVector2Array()
				for i in range(20):
					var a := TAU * float(i) / 20.0
					hring.append(position + Vector2(cos(a) * 48.0, sin(a) * 26.0))
				hring.append(hring[0])
				var ring_alpha := 0.58 if bool(band.get("pursuing", false)) else 0.30
				canvas.draw_polyline(hring, Color(0.90, 0.30, 0.22, ring_alpha * opacity), 1.6 if bool(band.get("pursuing", false)) else 1.2, false)
			draw_ellipse_shadow(canvas, position + Vector2(0.0, 4.0), Vector2(44.0, 9.0), 0.22 * opacity)
	for animal in wildlife:
		var position: Vector2 = animal["at"]
		if animal["opacity"] > 0.0 and map_view.grow(65.0).has_point(world_to_screen.call(position)):
			if animal.get("is_predator", false):
				var stalking := bool(animal.get("stalking", false))
				var ring := PackedVector2Array()
				for i in range(20):
					var a := TAU * float(i) / 20.0
					ring.append(position + Vector2(cos(a) * 44.0, sin(a) * 24.0))
				ring.append(ring[0])
				canvas.draw_polyline(ring, Color(0.92, 0.28, 0.20, (0.62 if stalking else 0.30) * float(animal["opacity"])), 1.8 if stalking else 1.3, false)
				if stalking:
					canvas.draw_line(position + Vector2(0, -10), player_position + Vector2(0, -10), Color(0.92, 0.32, 0.24, 0.35), 1.2, false)
			draw_ellipse_shadow(canvas, position + Vector2(0, 4), animal["size"], 0.22 * animal["opacity"])


func draw_player_marker(
	canvas: CanvasItem,
	map_view: Rect2,
	world_to_screen: Callable,
	player_actor: Dictionary,
	ai_bands: Array[Dictionary],
	task_progress := -1.0
) -> void:
	var center: Vector2 = player_actor["position"]
	if not map_view.grow(70.0).has_point(world_to_screen.call(center)):
		return
	var target: Vector2 = player_actor["target"]
	if center.distance_to(target) > 2.0:
		var trail := PackedVector2Array([center, target])
		for waypoint in player_actor["route"]:
			trail.append(waypoint)
		canvas.draw_polyline(trail, Color(0.9, 0.72, 0.42, 0.55), 2.0, true)
		canvas.draw_arc(trail[-1], 10.0, 0, TAU, 20, Color("#f1cf92"), 1.6)
	var activity: String = player_actor["activity"]
	if activity != "idle":
		_draw_player_activity(canvas, center, activity, ai_bands, task_progress)


func draw_band_markers(
	canvas: CanvasItem,
	map_view: Rect2,
	zoom_level: float,
	world_to_screen: Callable,
	ai_bands: Array[Dictionary]
) -> void:
	var font := ThemeDB.fallback_font
	for band in ai_bands:
		var pos: Vector2 = band["position"]
		var ground: Vector2 = world_to_screen.call(pos)
		var label: String = band["label"]
		var attitude := str(band.get("attitude", "friendly"))
		var tint: Color = band["color"]
		if attitude == "hostile":
			label += " · hostile"
			tint = Color("#e36d57")
		elif attitude == "wary":
			label += " · wary"
		var anchor := ground + Vector2(0, -55.0 * zoom_level)
		var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		var badge := Rect2(anchor - Vector2(size.x * 0.5 + 5.0, size.y), size + Vector2(10, 4))
		if not map_view.encloses(badge):
			continue
		var bg := Color("#2e1817", 0.92) if attitude == "hostile" else Color("#172421", 0.9)
		canvas.draw_rect(badge, bg)
		if attitude == "hostile":
			canvas.draw_rect(badge, Color("#d95b45", 0.85), false, 1.0)
		canvas.draw_string(font, badge.position + Vector2(5.0, font.get_ascent(12) + 2.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tint.lightened(0.35))


func draw_combat_flashes(
	canvas: CanvasItem,
	map_view: Rect2,
	world_to_screen: Callable,
	flashes: Array[Dictionary]
) -> void:
	for flash in flashes:
		var age: float = flash["age"]
		var duration: float = flash["duration"]
		var t := clampf(age / duration, 0.0, 1.0)
		var alpha := 1.0 - t
		var screen: Vector2 = world_to_screen.call(flash["at"])
		if not map_view.grow(40.0).has_point(screen):
			continue
		var color: Color = flash["color"]
		var ring_col := Color(color.r, color.g, color.b, 0.85 * alpha)
		var radius := lerpf(12.0, 42.0, t)
		canvas.draw_arc(screen + Vector2(0, -14), radius, 0.0, TAU, 24, ring_col, 2.5 * (1.0 - t * 0.5), true)
		var slash := lerpf(10.0, 20.0, t)
		var slash_col := Color(1.0, 0.88, 0.72, 0.9 * alpha)
		canvas.draw_line(screen + Vector2(-slash, -14 - slash * 0.6), screen + Vector2(slash, -14 + slash * 0.6), slash_col, 2.2, true)
		canvas.draw_line(screen + Vector2(slash, -14 - slash * 0.6), screen + Vector2(-slash, -14 + slash * 0.6), slash_col, 2.2, true)


func draw_floating_texts(
	canvas: CanvasItem,
	map_view: Rect2,
	world_to_screen: Callable,
	floating_texts: Array[Dictionary]
) -> void:
	var font := ThemeDB.fallback_font
	for item in floating_texts:
		var age: float = item["age"]
		var duration: float = item["duration"]
		var t := clampf(age / duration, 0.0, 1.0)
		var alpha := 1.0 - smoothstep(0.55, 1.0, t)
		var screen: Vector2 = world_to_screen.call(item["at"]) + Vector2(0.0, -34.0 - t * 34.0)
		var text: String = item["text"]
		var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		var pos := screen - Vector2(size.x * 0.5, 0.0)
		if not map_view.has_point(screen):
			continue
		var color: Color = item["color"]
		color.a = alpha
		canvas.draw_rect(Rect2(pos.x - 6.0, pos.y - font.get_ascent(13) - 2.0, size.x + 12.0, size.y + 4.0), Color(0.08, 0.13, 0.12, 0.82 * alpha))
		canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)


func draw_ellipse_shadow(canvas: CanvasItem, center: Vector2, radius: Vector2, opacity := 0.22) -> void:
	var points := PackedVector2Array()
	for i in range(20):
		var angle := TAU * float(i) / 20.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	canvas.draw_colored_polygon(points, Color(0, 0, 0, opacity))


func _draw_unexplored_tile(canvas: CanvasItem, center: Vector2, x: int, y: int) -> void:
	var corners := PackedVector2Array([
		center + Vector2(0, -WorldMapScript.TILE_H * 0.5),
		center + Vector2(WorldMapScript.TILE_W * 0.5, 0),
		center + Vector2(0, WorldMapScript.TILE_H * 0.5),
		center + Vector2(-WorldMapScript.TILE_W * 0.5, 0)
	])
	var shade := 0.012 if (x + y) % 2 == 0 else 0.025
	canvas.draw_colored_polygon(corners, Color("#0b1211").lightened(shade))
	var outline := corners.duplicate()
	outline.append(corners[0])
	canvas.draw_polyline(outline, Color("#38443f", 0.12), 0.7, true)


func _draw_terrain_ground(canvas: CanvasItem, center: Vector2, tile: Vector2i, terrain: String, is_dry_season := false, is_depleted := false, fire_state := "") -> void:
	var color := Color("#a39b59")
	match terrain:
		"woodland": color = Color("#687d49")
		"wetland": color = Color("#829258")
		"dryland": color = Color("#b39662")
		"highland": color = Color("#817b58")
		"volcanic": color = Color("#8c7057")
		"river", "lake": color = Color("#93875a")
	if is_dry_season and terrain in ["savanna", "woodland", "wetland", "dryland"]:
		color = color.lerp(Color("#b69a62"), 0.20)
	if fire_state == "burning":
		color = Color("#3a271f")
	elif fire_state == "cooled":
		color = Color("#4a423a")
	elif fire_state == "regrowth":
		color = Color("#597b45")
	if is_depleted:
		color = color.darkened(0.14)
	var corners := PackedVector2Array()
	var colors := PackedColorArray()
	for vertex in WorldMapScript.TILE_VERTICES:
		corners.append(center + world.project_tile_offset(vertex))
		var sample: Vector2 = Vector2(tile) + vertex
		var shade := world.terrain_noise.get_noise_2dv(sample) * 0.36
		colors.append(color.lightened(shade) if shade >= 0.0 else color.darkened(-shade))
	canvas.draw_polygon(corners, colors)
	var shore := world.get_shoreline(tile)
	if shore.is_empty():
		_draw_ground_texture(canvas, center, terrain, tile.x, tile.y)
		return

	canvas.draw_polygon(corners, PackedColorArray([Color.WHITE]), PackedVector2Array(WorldMapScript.SHORE_UVS), world.get_shoreline_texture(tile))
	for ripple in shore["ripples"]:
		canvas.draw_line(center + ripple[0], center + ripple[1], Color("#b3d7c5", 0.20), -1.0, false)


func _draw_terrain_details(canvas: CanvasItem, center: Vector2, terrain: String, x: int, y: int, is_dry_season := false) -> void:
	var shore := world.get_shoreline(Vector2i(x, y))
	if not shore.is_empty():
		_draw_shoreline_details(canvas, center, shore, x, y)
		return
	var variation := world.tile_noise(x, y, 202)
	match terrain:
		"highland":
			_draw_civ3_hills_tile(canvas, center, x, y, variation, is_dry_season)
		"volcanic":
			_draw_volcanic_tile(canvas, center, x, y, variation, is_dry_season)
		"dryland":
			canvas.draw_colored_polygon(PackedVector2Array([
				center + Vector2(-21, 8), center + Vector2(-5, -8),
				center + Vector2(16, 5), center + Vector2(7, 13)
			]), Color("#b59a64", 0.5))
	_draw_tile_vegetation(canvas, center, terrain, x, y, variation)
	var detail := posmod(x * 37 + y * 19, 7)
	if terrain not in ["river", "lake"]:
		if detail == 0:
			_draw_flower(canvas, center + Vector2(-20, 8), Color("#d9a867"))
		elif detail == 1 or detail == 4:
			_draw_boulder(canvas, center + Vector2(18, 7), 0.65 + variation * 0.4)
		elif detail == 3:
			_draw_grass(canvas, center + Vector2(18, 7), Color("#857b4d", 0.8))
		elif detail == 5:
			canvas.draw_circle(center + Vector2(12, 6), 1.1, Color("#756b47", 0.55))
			canvas.draw_circle(center + Vector2(15, 8), 1.1, Color("#756b47", 0.55))
			canvas.draw_circle(center + Vector2(20, 4), 1.1, Color("#756b47", 0.55))
			canvas.draw_circle(center + Vector2(23, 6), 1.1, Color("#756b47", 0.55))
	if terrain == "lake" and detail == 0:
		canvas.draw_circle(center + Vector2(-17, 7), 2.0, Color("#a8b879", 0.85))


func _draw_shoreline_details(canvas: CanvasItem, center: Vector2, shore: Dictionary, x: int, y: int) -> void:
	for i in range(6):
		var point := _vegetation_point(center, x, y, i, 6)
		var wet := false
		var bank := false
		for water in shore["water"]:
			if Geometry2D.is_point_in_polygon(point - center, water):
				wet = true
				break
		for bank_mask in shore["bank"]:
			if Geometry2D.is_point_in_polygon(point - center, bank_mask):
				bank = true
				break
		if wet:
			continue
		if bank and world.tile_noise(x, y, i + 91) > 0.58:
			_draw_reeds(canvas, point)
		elif not bank:
			_draw_tall_grass(canvas, point, 0.58, Color("#9b9358"))
		else:
			canvas.draw_circle(point, 0.95, Color("#665c44", 0.65))


func _draw_exploration_frontier(canvas: CanvasItem, center: Vector2, tile: Vector2i, explored_tiles: Dictionary) -> void:
	var top := center + Vector2(0, -WorldMapScript.TILE_H * 0.5)
	var right := center + Vector2(WorldMapScript.TILE_W * 0.5, 0)
	var bottom := center + Vector2(0, WorldMapScript.TILE_H * 0.5)
	var left := center + Vector2(-WorldMapScript.TILE_W * 0.5, 0)
	var edges := [
		{"neighbor": tile + Vector2i(0, -1), "from": top, "to": right},
		{"neighbor": tile + Vector2i(1, 0), "from": right, "to": bottom},
		{"neighbor": tile + Vector2i(0, 1), "from": bottom, "to": left},
		{"neighbor": tile + Vector2i(-1, 0), "from": left, "to": top}
	]
	for edge in edges:
		var neighbor: Vector2i = edge["neighbor"]
		if neighbor.x < 0 or neighbor.x >= WorldMapScript.WORLD_WIDTH or neighbor.y < 0 or neighbor.y >= WorldMapScript.WORLD_HEIGHT:
			continue
		if explored_tiles.has(world.tile_id(neighbor)):
			continue
		canvas.draw_line(edge["from"], edge["to"], Color("#080d0c", 0.9), 4.0, true)
		canvas.draw_line(edge["from"], edge["to"], Color("#c8b77d", 0.34), 1.0, true)


func _draw_depleted_mark(canvas: CanvasItem, center: Vector2) -> void:
	var ring := PackedVector2Array()
	for i in range(12):
		var a := TAU * float(i) / 12.0
		ring.append(center + Vector2(cos(a) * 18.0, sin(a) * 9.0))
	ring.append(ring[0])
	canvas.draw_polyline(ring, Color("#8b7450", 0.55), -1.0, false)


func _draw_carcass_icon(canvas: CanvasItem, center: Vector2) -> void:
	var badge := center + Vector2(-18, -6)
	canvas.draw_circle(badge, 7.5, Color("#3a2722", 0.92))
	var bone := Color("#efe2c6")
	canvas.draw_line(badge + Vector2(-4, -2), badge + Vector2(4, 2), bone, 1.8, true)
	canvas.draw_line(badge + Vector2(-4, 2), badge + Vector2(4, -2), bone, 1.8, true)
	canvas.draw_circle(badge + Vector2(-4, -2), 1.4, bone)
	canvas.draw_circle(badge + Vector2(4, 2), 1.4, bone)


func _draw_wildfire_details(canvas: CanvasItem, center: Vector2, fire_info: Dictionary, x: int, y: int) -> void:
	var state: String = fire_info.get("state", "")
	if state == "burning":
		for i in range(4):
			var pt := _vegetation_point(center, x, y, i, 4)
			canvas.draw_circle(pt + Vector2(0, -3), 8.0, Color(0.95, 0.42, 0.14, 0.34))
			canvas.draw_colored_polygon(PackedVector2Array([
				pt + Vector2(-6, 3), pt + Vector2(-3, -8), pt + Vector2(0, -3),
				pt + Vector2(3, -11), pt + Vector2(6, 3)
			]), Color("#ef8a35"))
			canvas.draw_colored_polygon(PackedVector2Array([
				pt + Vector2(-3, 3), pt + Vector2(0, -5), pt + Vector2(3, 3)
			]), Color("#ffe08e"))
	elif state == "cooled":
		for i in range(5):
			var pt := _vegetation_point(center, x, y, i, 5)
			canvas.draw_circle(pt, 2.2, Color("#2c2825", 0.8))
			if i % 2 == 0 and not fire_info.get("ember_taken", false):
				canvas.draw_circle(pt + Vector2(1, -1), 1.4, Color("#e47a38", 0.85))
		if not fire_info.get("foraged", false):
			var badge := center + Vector2(-18, 6)
			canvas.draw_circle(badge, 6.5, Color("#2d2621", 0.9))
			canvas.draw_circle(badge, 3.0, Color("#e8b86b"))
	elif state == "regrowth":
		for i in range(6):
			var pt := _vegetation_point(center, x, y, i, 6)
			_draw_tall_grass(canvas, pt, 0.78, Color("#88bd65"))


func _draw_collectible(canvas: CanvasItem, item: Dictionary) -> void:
	var pt: Vector2 = item["at"]
	var kind: String = item["kind"]
	draw_ellipse_shadow(canvas, pt + Vector2(0, 4), Vector2(8.5, 3.2), 0.26)
	canvas.draw_circle(pt, 9.5, Color(0.95, 0.86, 0.56, 0.16))
	match kind:
		"berries":
			canvas.draw_line(pt + Vector2(-4, 2), pt + Vector2(3, -3), Color("#4f7343"), 1.6, false)
			canvas.draw_circle(pt + Vector2(-3, -1), 2.7, Color("#d85c49"))
			canvas.draw_circle(pt + Vector2(2, -3), 2.8, Color("#e89a4a"))
			canvas.draw_circle(pt + Vector2(3, 2), 2.5, Color("#cf4d42"))
			canvas.draw_circle(pt + Vector2(1, -4), 0.9, Color("#ffe3b8"))
		"stone":
			canvas.draw_colored_polygon(PackedVector2Array([
				pt + Vector2(-6, 3), pt + Vector2(-3, -5),
				pt + Vector2(3, -4), pt + Vector2(6, 2), pt + Vector2(1, 5)
			]), Color("#4d6b73"))
			canvas.draw_line(pt + Vector2(-2, -3), pt + Vector2(3, 1), Color("#c2ded6", 0.9), 1.3, false)
		"gourd":
			canvas.draw_circle(pt + Vector2(0, 1), 5.0, Color("#dec796"))
			canvas.draw_circle(pt + Vector2(0, -4), 2.4, Color("#c7ab76"))
			canvas.draw_arc(pt + Vector2(0, 1), 5.0, 0.0, TAU, 14, Color("#8f7245"), -1.0, false)
			canvas.draw_circle(pt + Vector2(-1.8, -0.5), 1.3, Color("#f7ecd0", 0.85))
		"ochre":
			canvas.draw_colored_polygon(PackedVector2Array([
				pt + Vector2(-5, 3), pt + Vector2(-4, -3),
				pt + Vector2(1, -5), pt + Vector2(6, -1), pt + Vector2(4, 4)
			]), Color("#c75338"))
			canvas.draw_circle(pt + Vector2(-1, -2), 1.8, Color("#ec8d67"))
			canvas.draw_circle(pt + Vector2(2, 1), 1.3, Color("#f3b88c"))
		"tinder":
			canvas.draw_line(pt + Vector2(-6, 3), pt + Vector2(5, -3), Color("#9d7340"), 2.0, false)
			canvas.draw_line(pt + Vector2(-5, -2), pt + Vector2(6, 3), Color("#b9894b"), 2.0, false)
			canvas.draw_circle(pt + Vector2(0, 0), 2.5, Color("#f0be5b"))
			canvas.draw_circle(pt + Vector2(-0.6, -0.8), 1.0, Color("#fff0b5"))


func _draw_landmark_icon(canvas: CanvasItem, center: Vector2, kind: String, is_dry_season := false, discovered := true) -> void:
	var badge := center + Vector2(23, -8)
	var bg := Color("#24342d", 0.94) if discovered else Color("#1c2623", 0.72)
	canvas.draw_circle(badge, 8.5, bg)
	if discovered:
		canvas.draw_arc(badge, 8.5, 0.0, TAU, 16, Color("#d8b674", 0.85), 1.2, false)
	else:
		canvas.draw_arc(badge, 8.5, 0.0, TAU, 16, Color("#9aa99b", 0.45), -1.0, false)
	var tint := Color("#f1d393") if discovered else Color("#c5b99c", 0.85)
	match kind:
		"fossil":
			canvas.draw_line(badge + Vector2(-4, 0), badge + Vector2(4, 0), tint, 2.0, false)
			canvas.draw_circle(badge + Vector2(-4, 0), 2.2, tint)
			canvas.draw_circle(badge + Vector2(4, 0), 2.2, tint)
		"spring":
			canvas.draw_arc(badge + Vector2(0, 2), 4.0, PI, TAU, 10, Color("#9dd2c4"), 1.3, false)
			canvas.draw_arc(badge + Vector2(0, 3), 7.0, PI, TAU, 10, Color("#79b9b2"), -1.0, false)
		"obsidian":
			canvas.draw_colored_polygon(PackedVector2Array([
				badge + Vector2(-5, 3), badge + Vector2(-2, -5),
				badge + Vector2(3, -4), badge + Vector2(5, 3)
			]), Color("#536b70"))
			canvas.draw_line(badge + Vector2(-2, -3), badge + Vector2(2, 2), Color("#9eb4ac", 0.8), -1.0, false)
		"shelter":
			canvas.draw_colored_polygon(PackedVector2Array([
				badge + Vector2(-7, 3), badge + Vector2(-3, -5),
				badge + Vector2(6, -3), badge + Vector2(7, 3)
			]), Color("#a18a67"))
			canvas.draw_arc(badge + Vector2(0, 4), 3.5, PI, TAU, 10, Color("#28302a"), 2.0, false)
		"waterhole":
			if is_dry_season:
				canvas.draw_arc(badge + Vector2(0, 1), 6.0, 0, TAU, 14, Color("#b09162"), 1.2, false)
				canvas.draw_line(badge + Vector2(-3, 0), badge + Vector2(3, 2), Color("#8c734b"), -1.0, false)
			else:
				canvas.draw_circle(badge + Vector2(0, 1), 5.0, Color("#4c8e94", 0.75))
				canvas.draw_arc(badge + Vector2(0, 1), 6.0, 0, TAU, 14, Color("#9dd2c4"), 1.2, false)
				_draw_reeds(canvas, badge + Vector2(4, -3))


func _draw_flower(canvas: CanvasItem, point: Vector2, color: Color) -> void:
	canvas.draw_line(point + Vector2(0, 3), point + Vector2(0, -2), Color("#667448"), -1.0, false)
	canvas.draw_circle(point + Vector2(-2, -3), 1.5, color.darkened(0.08))
	canvas.draw_circle(point + Vector2(2, -3), 1.5, color.lightened(0.08))
	canvas.draw_circle(point + Vector2(0, -4), 1.4, Color("#f0d38d"))


func _draw_boulder(canvas: CanvasItem, point: Vector2, size: float) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([
		point + Vector2(-6 * size, 2 * size), point + Vector2(-4 * size, -3 * size),
		point + Vector2(1 * size, -5 * size), point + Vector2(6 * size, -2 * size),
		point + Vector2(5 * size, 3 * size)
	]), Color("#776f57"))
	canvas.draw_line(point + Vector2(-3 * size, -2 * size), point + Vector2(1 * size, -4 * size), Color("#b2a27a", 0.7), -1.0, false)


func _draw_reeds(canvas: CanvasItem, point: Vector2) -> void:
	var reed := Color("#9ba36a", 0.8)
	canvas.draw_line(point, point + Vector2(-3, -10), reed, -1.0, false)
	canvas.draw_line(point + Vector2(2, 1), point + Vector2(3, -12), reed, -1.0, false)
	canvas.draw_line(point + Vector2(5, 2), point + Vector2(9, -7), reed, -1.0, false)
	canvas.draw_line(point + Vector2(-2, 1), point + Vector2(-7, -6), reed.darkened(0.12), -1.0, false)
	canvas.draw_circle(point + Vector2(3, -12), 1.2, Color("#6f5e3e"))
	canvas.draw_circle(point + Vector2(-3, -10), 1.0, Color("#796746"))


func _draw_tree(canvas: CanvasItem, point: Vector2, size: float) -> void:
	var scale := 0.68 + size * 0.38
	draw_ellipse_shadow(canvas, point + Vector2(1, 5), Vector2(12, 3) * scale)
	canvas.draw_line(point + Vector2(0, 7 * scale), point + Vector2(0, -8 * scale), Color("#68563a"), 2.2 * scale, false)
	canvas.draw_line(point + Vector2(0, -5 * scale), point + Vector2(-7, -11) * scale, Color("#735f3e"), 1.4 * scale, false)
	canvas.draw_line(point + Vector2(1, -7 * scale), point + Vector2(8, -12) * scale, Color("#594a34"), -1.0, false)
	canvas.draw_colored_polygon(PackedVector2Array([
		point + Vector2(-12 * scale, -5 * scale), point + Vector2(-8 * scale, -13 * scale),
		point + Vector2(-2 * scale, -12 * scale), point + Vector2(3 * scale, -17 * scale),
		point + Vector2(12 * scale, -11 * scale), point + Vector2(10 * scale, -4 * scale),
		point + Vector2(3 * scale, -2 * scale), point + Vector2(-5 * scale, -3 * scale)
	]), Color("#435d3e").lightened(size * 0.12))
	canvas.draw_circle(point + Vector2(-5 * scale, -9 * scale), 5.0 * scale, Color("#435d3e").darkened(0.08))
	canvas.draw_circle(point + Vector2(3 * scale, -10 * scale), 6.0 * scale, Color("#435d3e").lightened(0.12))
	canvas.draw_circle(point + Vector2(0, -14 * scale), 4.0 * scale, Color("#526c46").lightened(size * 0.12))
	_draw_leaf_texture(canvas, point + Vector2(-5, -10) * scale, Vector2(5.5, 3.3) * scale, Color("#56704a"), 14)
	_draw_leaf_texture(canvas, point + Vector2(4, -10) * scale, Vector2(6.5, 4.5) * scale, Color("#607950"), 17)
	_draw_leaf_texture(canvas, point + Vector2(1, -14) * scale, Vector2(4.0, 3.2) * scale, Color("#6c8051"), 10)


func _draw_civ3_hills_tile(canvas: CanvasItem, center: Vector2, x: int, y: int, variation: float, is_dry_season: bool) -> void:
	var relief := world.terrain_noise.get_noise_2d(x - 9, y + 15)
	var n_up: bool = world.terrain_at(Vector2i(x, y - 1)) == "highland"
	var n_right: bool = world.terrain_at(Vector2i(x + 1, y)) == "highland"
	var n_down: bool = world.terrain_at(Vector2i(x, y + 1)) == "highland"
	var n_left: bool = world.terrain_at(Vector2i(x - 1, y)) == "highland"
	var neighbors := int(n_up) + int(n_right) + int(n_down) + int(n_left)

	# Warm Civ-3 style sunlit olive-ochre hills shifting slightly golden in Dry seasons.
	var lit := Color("#b7ad72") if not is_dry_season else Color("#c6ae73")
	var mid := Color("#888856") if not is_dry_season else Color("#9a8b5a")
	var shade := Color("#555c47") if not is_dry_season else Color("#655b48")
	var skirt := Color("#7d7c54") if not is_dry_season else Color("#8f8358")

	# Connect seamlessly to adjacent highland tiles with low bridging saddles.
	if n_up:
		_draw_hill_dome(canvas, center + Vector2(20, -10), 26.0, 14.0, -2.0, lit.darkened(0.04), mid, shade, skirt, false)
	if n_left:
		_draw_hill_dome(canvas, center + Vector2(-21, -9), 26.0, 14.0, 2.0, lit, mid, shade, skirt, false)

	var base_h := 20.0 + relief * 6.0 + variation * 7.0
	var lean := lerpf(-4.5, 4.5, world.tile_noise(x, y, 225))
	# Back rolling swell (soft secondary hill behind the hero mound).
	_draw_hill_dome(canvas, center + Vector2(16, -4), 29.0, base_h * 0.86, -lean * 0.6, lit.darkened(0.03), mid, shade, skirt, false)

	if neighbors >= 3:
		# Inner escarpment crest: taller broad-shouldered weathered ridge rising above foothills.
		var rock_lit := Color("#cec1a1") if not is_dry_season else Color("#d6c29d")
		var rock_mid := Color("#998e77")
		var rock_shade := Color("#5c564f")
		_draw_hill_dome(canvas, center + Vector2(-4, 2), 37.0, base_h + 14.0, lean * 0.7, rock_lit, rock_mid, rock_shade, skirt, true)
		_draw_hill_dome(canvas, center + Vector2(-17, 10), 24.0, base_h * 0.68, -2.0, lit, mid, shade, skirt, false)
	else:
		# Classic Civ 3 rolling grassy hill: wide rounded dome with gentle front knoll.
		_draw_hill_dome(canvas, center + Vector2(-7, 5), 35.0, base_h, lean, lit, mid, shade, skirt, false)
		if variation > 0.35:
			_draw_hill_dome(canvas, center + Vector2(18, 10), 23.0, base_h * 0.62, lean * 0.4, lit, mid, shade, skirt, false)

	if n_right:
		_draw_hill_dome(canvas, center + Vector2(22, 11), 24.0, 13.0, -1.5, lit, mid, shade, skirt, false)
	if n_down:
		_draw_hill_dome(canvas, center + Vector2(-19, 12), 24.0, 13.0, 1.5, lit, mid, shade, skirt, false)

	# Small painterly limestone rock & slope grass details on the hill brow.
	if variation > 0.55:
		_draw_boulder(canvas, center + Vector2(-13, 3), 0.55)
	_draw_grass(canvas, center + Vector2(8, 8), Color("#6d7949", 0.72))


func _draw_hill_dome(
	canvas: CanvasItem,
	base: Vector2,
	radius_x: float,
	height: float,
	lean: float,
	lit: Color,
	mid: Color,
	shade: Color,
	skirt: Color,
	rocky: bool
) -> void:
	# Soft grounding shadow shifted toward the SE away from the NW sun.
	draw_ellipse_shadow(canvas, base + Vector2(5.0, 3.0), Vector2(radius_x * 0.96, radius_x * 0.28), 0.20)

	var steps := 14
	var ridge := PackedVector2Array()
	var lower := PackedVector2Array()

	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var u := t * 2.0 - 1.0 # -1 (left) .. +1 (right)
		# Smooth raised-cosine bell curve gives Civ 3's rounded rolling hill silhouette.
		var bell := pow(0.5 * (1.0 + cos(u * PI)), 0.85 if rocky else 1.12)
		var px := base.x + u * radius_x + lean * bell
		var py := base.y - height * bell
		ridge.append(Vector2(px, py))
		# Curved bottom apron tucks gently into the isometric diamond.
		var apron_y := base.y + sin(t * PI) * (radius_x * 0.24)
		lower.append(Vector2(base.x + u * radius_x, apron_y))

	# Paint smooth directional gradient across strictly convex vertical strips (NW sunlit -> SE shaded).
	for i in range(steps):
		var t0 := float(i) / float(steps)
		var t1 := float(i + 1) / float(steps)
		var ridge_col0 := lit.lerp(mid, smoothstep(0.18, 0.56, t0)).lerp(shade, smoothstep(0.48, 0.90, t0)).lightened(0.10 * (1.0 - smoothstep(0.25, 0.72, t0)))
		var ridge_col1 := lit.lerp(mid, smoothstep(0.18, 0.56, t1)).lerp(shade, smoothstep(0.48, 0.90, t1)).lightened(0.10 * (1.0 - smoothstep(0.25, 0.72, t1)))
		var mid_col0 := lit.lerp(mid, smoothstep(0.15, 0.52, t0)).lerp(shade, smoothstep(0.46, 0.88, t0))
		var mid_col1 := lit.lerp(mid, smoothstep(0.15, 0.52, t1)).lerp(shade, smoothstep(0.46, 0.88, t1))
		var skirt_col0 := skirt.lerp(mid_col0, 0.42)
		var skirt_col1 := skirt.lerp(mid_col1, 0.42)

		if i == 0:
			canvas.draw_polygon(
				PackedVector2Array([ridge[0], ridge[1], lower[1]]),
				PackedColorArray([skirt_col0, ridge_col1, skirt_col1])
			)
		elif i == steps - 1:
			canvas.draw_polygon(
				PackedVector2Array([ridge[i], ridge[i + 1], lower[i]]),
				PackedColorArray([ridge_col0, skirt_col1, skirt_col0])
			)
		else:
			var m0 := ridge[i].lerp(lower[i], 0.48)
			var m1 := ridge[i + 1].lerp(lower[i + 1], 0.48)
			canvas.draw_polygon(
				PackedVector2Array([ridge[i], ridge[i + 1], m1, m0]),
				PackedColorArray([ridge_col0, ridge_col1, mid_col1, mid_col0])
			)
			canvas.draw_polygon(
				PackedVector2Array([m0, m1, lower[i + 1], lower[i]]),
				PackedColorArray([mid_col0, mid_col1, skirt_col1, skirt_col0])
			)

	# Sunlit NW highlight arc along the brow & soft SE contour fold.
	var brow := PackedVector2Array()
	for i in range(2, 7):
		brow.append(ridge[i].lerp(lower[i], 0.16))
	if brow.size() >= 2:
		canvas.draw_polyline(brow, lit.lightened(0.24) * Color(1, 1, 1, 0.55), 1.4, false)
	var shadow_fold := PackedVector2Array()
	for i in range(8, steps):
		shadow_fold.append(ridge[i].lerp(lower[i], 0.34))
	if shadow_fold.size() >= 2:
		canvas.draw_polyline(shadow_fold, shade.darkened(0.25) * Color(1, 1, 1, 0.45), 1.3, false)
	if rocky:
		var crown := ridge[steps / 2].lerp(lower[steps / 2], 0.28)
		canvas.draw_line(crown + Vector2(-8, 2), crown + Vector2(5, 5), Color("#ebe0c5", 0.42), -1.0, false)
		canvas.draw_line(crown + Vector2(-12, 8), crown + Vector2(2, 11), Color("#46403a", 0.36), -1.0, false)


func _draw_volcanic_tile(canvas: CanvasItem, center: Vector2, x: int, y: int, variation: float, is_dry_season: bool) -> void:
	var h := 18.0 + variation * 9.0
	var lean := lerpf(-3.0, 3.0, world.tile_noise(x, y, 311))
	var lit := Color("#a58869") if not is_dry_season else Color("#b3926d")
	var mid := Color("#766353")
	var shade := Color("#473f39")
	var skirt := Color("#7f6954")
	_draw_hill_dome(canvas, center + Vector2(18, -3), 22.0, h * 0.65, -lean, lit.darkened(0.08), mid, shade, skirt, true)
	_draw_hill_dome(canvas, center + Vector2(-4, 6), 31.0, h, lean, lit, mid, shade, skirt, true)
	# Subtle weathered caldera rim at the summit.
	var rim := center + Vector2(-4 + lean, 6 - h + 3.0)
	canvas.draw_arc(rim, 4.5, PI, TAU, 10, Color("#bf6b4a", 0.85), 1.5, false)


func _draw_grass(canvas: CanvasItem, point: Vector2, color: Color) -> void:
	canvas.draw_line(point, point + Vector2(-3, -7), color, -1.0, false)
	canvas.draw_line(point + Vector2(2, 1), point + Vector2(5, -6), color, -1.0, false)
	canvas.draw_line(point + Vector2(6, 2), point + Vector2(9, -3), color, -1.0, false)


func _draw_ground_texture(canvas: CanvasItem, center: Vector2, terrain: String, x: int, y: int) -> void:
	var texture_color := Color("#d1bc76", 0.24)
	if terrain == "woodland":
		texture_color = Color("#354b35", 0.32)
	elif terrain == "dryland":
		texture_color = Color("#765d38", 0.28)
	elif terrain in ["highland", "volcanic"]:
		texture_color = Color("#c3b58d", 0.18)
	for i in range(6):
		var local_y := -10.0 + world.tile_noise(x, y, i + 2) * 20.0
		var half_width := 34.0 * (1.0 - absf(local_y) / 27.0)
		var local_x := (world.tile_noise(x, y, i + 12) * 2.0 - 1.0) * half_width
		var mark := center + Vector2(local_x, local_y)
		if i % 3 == 0:
			canvas.draw_circle(mark, 1.0, texture_color)
		else:
			canvas.draw_line(mark, mark + Vector2(4.0 + float(i % 2) * 3.0, -1.0), texture_color, -1.0, false)


func _draw_tile_vegetation(canvas: CanvasItem, center: Vector2, terrain: String, x: int, y: int, variation: float) -> void:
	match terrain:
		"woodland":
			for i in range(7):
				var point := _vegetation_point(center, x, y, i, 7)
				if i in [1, 4]:
					_draw_shrub(canvas, point + Vector2(0, 2), 0.65 + world.tile_noise(x, y, i + 90) * 0.35, Color("#52683f"))
				elif i % 3 == 0:
					_draw_acacia(canvas, point, 0.72 + world.tile_noise(x, y, i + 80) * 0.28, Color("#3d593b"))
				else:
					_draw_tree(canvas, point, world.tile_noise(x, y, i + 70))
		"savanna":
			for i in range(5):
				var grass_point := _vegetation_point(center, x, y, i, 5)
				_draw_tall_grass(canvas, grass_point, 0.65 + world.tile_noise(x, y, i + 30) * 0.5, Color("#c5ad63"))
			var grove := world.terrain_noise.get_noise_2d(x + 19, y - 11)
			var tree_count := 2 if grove > 0.18 else int(grove > -0.04)
			for i in range(tree_count):
				_draw_acacia(canvas, _vegetation_point(center, x, y, i + 6, tree_count + 7), 0.72 + world.tile_noise(x, y, i + 60) * 0.28, Color("#50663d"))
		"dryland":
			for i in range(4):
				var dry_point := _vegetation_point(center, x, y, i, 4)
				if i % 2 == 0:
					_draw_shrub(canvas, dry_point, 0.55 + world.tile_noise(x, y, i + 20) * 0.35, Color("#766c43"))
				else:
					_draw_tall_grass(canvas, dry_point, 0.65, Color("#8c7847"))
		"wetland":
			for i in range(3):
				_draw_reeds(canvas, _vegetation_point(center, x, y, i, 3))
			if variation > 0.8:
				_draw_palm(canvas, center + Vector2(18, 7), 0.78 + variation * 0.2)
		"highland":
			for i in range(3):
				var high_point := _vegetation_point(center, x, y, i, 3)
				_draw_shrub(canvas, high_point, 0.48 + variation * 0.25, Color("#626a4d"))
		"volcanic":
			if variation > 0.45:
				_draw_shrub(canvas, center + Vector2(-24, 9), 0.55, Color("#766a48"))


func _vegetation_point(center: Vector2, x: int, y: int, index: int, count: int) -> Vector2:
	var row := float(index + 1) / float(count + 1)
	var local_y := lerpf(-11.0, 12.0, row) + (world.tile_noise(x, y, index + 100) - 0.5) * 4.0
	var half_width := 35.0 * (1.0 - absf(local_y) / 28.0)
	var local_x := (world.tile_noise(x, y, index + 120) * 2.0 - 1.0) * half_width
	return center + Vector2(local_x, local_y)


func _draw_acacia(canvas: CanvasItem, point: Vector2, scale: float, foliage: Color) -> void:
	draw_ellipse_shadow(canvas, point + Vector2(2, 4), Vector2(15, 3) * scale)
	canvas.draw_line(point + Vector2(0, 5) * scale, point + Vector2(1, -11) * scale, Color("#665035"), 2.2 * scale, false)
	canvas.draw_line(point + Vector2(1, -6) * scale, point + Vector2(-9, -13) * scale, Color("#665035"), 1.4 * scale, false)
	canvas.draw_line(point + Vector2(1, -7) * scale, point + Vector2(10, -14) * scale, Color("#59462f"), 1.4 * scale, false)
	canvas.draw_colored_polygon(PackedVector2Array([
		point + Vector2(-17, -12) * scale, point + Vector2(-12, -18) * scale,
		point + Vector2(-2, -19) * scale, point + Vector2(4, -22) * scale,
		point + Vector2(15, -18) * scale, point + Vector2(19, -12) * scale,
		point + Vector2(10, -9) * scale, point + Vector2(-10, -9) * scale
	]), foliage)
	canvas.draw_circle(point + Vector2(-8, -15) * scale, 5.2 * scale, foliage.darkened(0.08))
	canvas.draw_circle(point + Vector2(5, -16) * scale, 6.0 * scale, foliage.lightened(0.09))
	_draw_leaf_texture(canvas, point + Vector2(-10, -13) * scale, Vector2(6.0, 3.5) * scale, foliage, 13)
	_draw_leaf_texture(canvas, point + Vector2(-1, -16) * scale, Vector2(7.0, 3.1) * scale, foliage.lightened(0.07), 15)
	_draw_leaf_texture(canvas, point + Vector2(8, -17) * scale, Vector2(6.5, 3.5) * scale, foliage.lightened(0.13), 15)
	_draw_leaf_texture(canvas, point + Vector2(11, -12) * scale, Vector2(5.5, 2.1) * scale, foliage.darkened(0.07), 10)


func _draw_leaf_texture(canvas: CanvasItem, center: Vector2, radii: Vector2, foliage: Color, count: int) -> void:
	var segments := PackedVector2Array()
	var colors := PackedColorArray()
	var rotation := fposmod(center.x * 0.71 + center.y * 0.37, TAU)
	for i in range(count):
		# Evenly scatter the marks over each lobe with a different rotation per tree.
		var angle := float(i) * 2.399963 + rotation
		var offset := Vector2.from_angle(angle) * sqrt((float(i) + 0.5) / float(count))
		var leaf := center + offset * radii
		var stroke := Vector2.from_angle(angle * 1.7) * lerpf(0.65, 1.45, absf(cos(angle * 2.0)))
		var shade := sin(angle * 3.0) * 0.22 - offset.y * 0.22 - offset.x * 0.08
		segments.append(leaf - stroke)
		segments.append(leaf + stroke)
		var color := foliage.lerp(Color("#c2c77a"), shade + 0.12) if shade >= 0.0 else foliage.darkened(-shade)
		colors.append(color)
	canvas.draw_multiline_colors(segments, colors, -1.0, false)


func _draw_shrub(canvas: CanvasItem, point: Vector2, scale: float, foliage: Color) -> void:
	draw_ellipse_shadow(canvas, point + Vector2(1, 2), Vector2(8, 2) * scale)
	for branch in range(3):
		var offset := float(branch - 1) * 3.0
		canvas.draw_line(point + Vector2(offset, 2) * scale, point + Vector2(offset * 1.6, -7 - branch % 2) * scale, Color("#65553b"), -1.0, false)
	canvas.draw_circle(point + Vector2(-5, -5) * scale, 4.5 * scale, foliage.darkened(0.08))
	canvas.draw_circle(point + Vector2(1, -7) * scale, 5.0 * scale, foliage)
	canvas.draw_circle(point + Vector2(6, -4) * scale, 4.0 * scale, foliage.lightened(0.1))
	canvas.draw_circle(point + Vector2(2, -9) * scale, 1.1 * scale, Color("#c8ad65", 0.8))


func _draw_tall_grass(canvas: CanvasItem, point: Vector2, scale: float, color: Color) -> void:
	for blade in range(5):
		var root := point + Vector2(float(blade) * 2.0 - 4.0, float(blade % 2))
		var lean := float(blade - 2) * 1.4
		canvas.draw_line(root, root + Vector2(lean, (-7.0 - float(blade % 3)) * scale), color.lightened(float(blade) * 0.025), -1.0, false)


func _draw_palm(canvas: CanvasItem, point: Vector2, scale: float) -> void:
	draw_ellipse_shadow(canvas, point + Vector2(3, 4), Vector2(12, 3) * scale)
	canvas.draw_line(point + Vector2(0, 5) * scale, point + Vector2(2, -17) * scale, Color("#7c6038"), 2.6 * scale, false)
	canvas.draw_line(point + Vector2(1, -5) * scale, point + Vector2(3, -16) * scale, Color("#b08a50", 0.75), -1.0, false)
	var crown := point + Vector2(2, -17) * scale
	for direction in [Vector2(-14, -4), Vector2(-11, 3), Vector2(-4, -8), Vector2(7, -8), Vector2(14, -3), Vector2(11, 4)]:
		var tip: Vector2 = crown + direction * scale
		canvas.draw_line(crown, tip, Color("#4f7047"), 2.0 * scale, false)
		var axis := (tip - crown).normalized()
		for leaflet in range(1, 6):
			var fraction := float(leaflet) / 6.0
			var stem := crown.lerp(tip, fraction)
			var spread := sin(fraction * PI) * 3.2 * scale
			var sweep := axis * spread * 0.58
			canvas.draw_line(stem, stem + sweep + axis.orthogonal() * spread, Color("#8a9b60"), -1.0, false)
			canvas.draw_line(stem, stem + sweep - axis.orthogonal() * spread, Color("#496a43"), -1.0, false)
	canvas.draw_circle(crown + Vector2(-2, 2) * scale, 2.0 * scale, Color("#705436"))
	canvas.draw_circle(crown + Vector2(2, 2) * scale, 2.0 * scale, Color("#705436"))


func _draw_player_activity(canvas: CanvasItem, center: Vector2, activity: String, ai_bands: Array[Dictionary], task_progress := -1.0) -> void:
	var label := "MOVING"
	var color := Color("#d9c596")
	match activity:
		"gathering":
			label = "GATHERING"
			color = Color("#acd081")
			var patch := center + Vector2(-54, -6)
			canvas.draw_line(patch, patch + Vector2(0, -13), Color("#7d9b55"), 2.0, true)
			canvas.draw_circle(patch + Vector2(-4, -11), 3.0, Color("#d2a95e"))
			canvas.draw_circle(patch + Vector2(4, -12), 3.0, Color("#c8754e"))
		"scavenging":
			label = "SCAVENGING"
			color = Color("#e3be84")
		"hunting":
			label = "HUNTING"
			color = Color("#e39f73")
		"fighting":
			label = "SKIRMISH"
			color = Color("#e86b58")
		"learning":
			label = "LEARNING"
			color = Color("#f0c77f")
		"learning_at_hearth":
			label = "LEARNING"
			color = Color("#f0c77f")
			var fire := center + Vector2(-48, 8)
			canvas.draw_circle(fire, 8.0, Color(0.9, 0.43, 0.16, 0.4))
			canvas.draw_colored_polygon(PackedVector2Array([
				fire + Vector2(-5, 4), fire + Vector2(-2, -5),
				fire + Vector2(0, -1), fire + Vector2(3, -8),
				fire + Vector2(5, 4)
			]), Color("#f0a24d"))
			canvas.draw_colored_polygon(PackedVector2Array([
				fire + Vector2(-2, 4), fire + Vector2(0, -2),
				fire + Vector2(3, 4)
			]), Color("#ffe1a0"))
		"scouting":
			label = "SCOUTING"
			color = Color("#a9d2cf")
		"pairing":
			label = "PAIRING"
			color = Color("#e4b3a9")
		"meeting":
			label = "KINSHIP"
			color = Color("#e4a6a0")
			if not ai_bands.is_empty():
				var nearest_position: Vector2 = ai_bands[0]["position"]
				for band in ai_bands:
					var band_position: Vector2 = band["position"]
					if center.distance_squared_to(band_position) < center.distance_squared_to(nearest_position):
						nearest_position = band_position
				canvas.draw_line(center + Vector2(0, -15), nearest_position + Vector2(0, -15), color, 3.0, true)
				canvas.draw_circle(nearest_position + Vector2(0, -15), 5.0, color)
				canvas.draw_arc(nearest_position + Vector2(0, -15), 34.0, 0, TAU, 32, color, 2.0, true)
	canvas.draw_rect(Rect2(center.x - 43, center.y - 101, 86, 18), Color("#1a2925"))
	canvas.draw_string(
		ThemeDB.fallback_font, center + Vector2(-41, -88), label,
		HORIZONTAL_ALIGNMENT_CENTER, 82, 10, color
	)
	if task_progress >= 0.0:
		var bar := Rect2(center.x - 43, center.y - 83, 86, 4)
		canvas.draw_rect(bar, Color("#121d1a"))
		canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(task_progress, 0.0, 1.0), bar.size.y)), color)
