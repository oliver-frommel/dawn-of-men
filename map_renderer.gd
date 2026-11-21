class_name MapRenderer
extends RefCounted

const WorldMapScript := preload("res://world_map.gd")

var world: WorldMapScript


func _init(world_map: WorldMapScript) -> void:
	world = world_map


func draw_world(canvas: CanvasItem, width: float, height: float) -> void:
	canvas.draw_rect(Rect2(0, 0, width, height), Color("#182826"))
	for y in range(0, int(height), 64):
		var alpha := 0.025 if y % 128 == 0 else 0.012
		canvas.draw_line(Vector2(0, y), Vector2(width, y), Color(0.8, 0.76, 0.63, alpha), 1)


func draw_map(
	canvas: CanvasItem,
	map_view: Rect2,
	zoom_level: float,
	screen_to_world: Callable,
	explored_tiles: Dictionary,
	discovered_landmarks: Dictionary,
	is_dry_season := false,
	depleted_tiles: Dictionary = {}
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
				_draw_terrain_ground(canvas, center, tile, world.terrain_at(tile), is_dry_season, depleted_tiles.has(id))
			else:
				_draw_unexplored_tile(canvas, center, tile.x, tile.y)
	for tile in visible:
		var center := world.tile_center(tile.x, tile.y)
		_draw_exploration_frontier(canvas, center, tile, explored_tiles)
		_draw_terrain_details(canvas, center, world.terrain_at(tile), tile.x, tile.y)
		if depleted_tiles.has(world.tile_id(tile)):
			_draw_depleted_mark(canvas, center)
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
		draw_ellipse_shadow(canvas, player_position + Vector2(0.0, 4.0), Vector2(16.0, 5.0))
	for band in ai_bands:
		var opacity: float = band["opacity"]
		if opacity <= 0.0 or band["last_seen"] == null:
			continue
		var position: Vector2 = band["last_seen"]
		if map_view.grow(65.0).has_point(world_to_screen.call(position)):
			draw_ellipse_shadow(canvas, position + Vector2(0.0, 4.0), Vector2(44.0, 9.0), 0.22 * opacity)
	for animal in wildlife:
		var position: Vector2 = animal["at"]
		if animal["opacity"] > 0.0 and map_view.grow(65.0).has_point(world_to_screen.call(position)):
			draw_ellipse_shadow(canvas, position + Vector2(0, 4), animal["size"], 0.22 * animal["opacity"])


func draw_player_marker(
	canvas: CanvasItem,
	map_view: Rect2,
	world_to_screen: Callable,
	player_actor: Dictionary,
	ai_bands: Array[Dictionary]
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
		_draw_player_activity(canvas, center, activity, ai_bands)


func draw_band_markers(
	canvas: CanvasItem,
	map_view: Rect2,
	zoom_level: float,
	world_to_screen: Callable,
	ai_bands: Array[Dictionary]
) -> void:
	var font := ThemeDB.fallback_font
	for band in ai_bands:
		if band["last_seen"] == null:
			continue
		var ground: Vector2 = world_to_screen.call(band["last_seen"])
		var label: String = band["label"]
		var tint: Color = band["color"]
		if not band["on_charted_land"]:
			label += " · last seen"
			if map_view.has_point(ground):
				canvas.draw_arc(ground, 7.0, 0.0, TAU, 16, tint, 1.4, true)
		var anchor := ground + Vector2(0, -55.0 * zoom_level)
		var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		var badge := Rect2(anchor - Vector2(size.x * 0.5 + 5.0, size.y), size + Vector2(10, 4))
		if not map_view.encloses(badge):
			continue
		canvas.draw_rect(badge, Color("#172421", 0.9))
		canvas.draw_string(font, badge.position + Vector2(5.0, font.get_ascent(12) + 2.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tint.lightened(0.4))


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


func _draw_terrain_ground(canvas: CanvasItem, center: Vector2, tile: Vector2i, terrain: String, is_dry_season := false, is_depleted := false) -> void:
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
		canvas.draw_line(center + ripple[0], center + ripple[1], Color("#b3d7c5", 0.20), 0.8, true)


func _draw_terrain_details(canvas: CanvasItem, center: Vector2, terrain: String, x: int, y: int) -> void:
	var shore := world.get_shoreline(Vector2i(x, y))
	if not shore.is_empty():
		_draw_shoreline_details(canvas, center, shore, x, y)
		return
	var variation := world.tile_noise(x, y, 202)
	match terrain:
		"highland":
			_draw_mountain_tile(canvas, center, x, y, variation)
		"volcanic":
			_draw_volcanic_tile(canvas, center, variation)
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
			canvas.draw_circle(point, 0.95, Color("#665c44", 0.65), true, -1.0, true)


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
	canvas.draw_polyline(ring, Color("#8b7450", 0.55), 1.1, true)


func _draw_landmark_icon(canvas: CanvasItem, center: Vector2, kind: String, is_dry_season := false) -> void:
	var badge := center + Vector2(23, -8)
	canvas.draw_circle(badge, 8.0, Color("#24342d", 0.92))
	var tint := Color("#f1d393")
	match kind:
		"fossil":
			canvas.draw_line(badge + Vector2(-4, 0), badge + Vector2(4, 0), tint, 2.0, true)
			canvas.draw_circle(badge + Vector2(-4, 0), 2.2, tint)
			canvas.draw_circle(badge + Vector2(4, 0), 2.2, tint)
		"spring":
			canvas.draw_arc(badge + Vector2(0, 2), 4.0, PI, TAU, 12, Color("#9dd2c4"), 1.3, true)
			canvas.draw_arc(badge + Vector2(0, 3), 7.0, PI, TAU, 12, Color("#79b9b2"), 1.0, true)
		"obsidian":
			canvas.draw_colored_polygon(PackedVector2Array([
				badge + Vector2(-5, 3), badge + Vector2(-2, -5),
				badge + Vector2(3, -4), badge + Vector2(5, 3)
			]), Color("#536b70"))
			canvas.draw_line(badge + Vector2(-2, -3), badge + Vector2(2, 2), Color("#9eb4ac", 0.8), 1.0, true)
		"shelter":
			canvas.draw_colored_polygon(PackedVector2Array([
				badge + Vector2(-7, 3), badge + Vector2(-3, -5),
				badge + Vector2(6, -3), badge + Vector2(7, 3)
			]), Color("#a18a67"))
			canvas.draw_arc(badge + Vector2(0, 4), 3.5, PI, TAU, 12, Color("#28302a"), 2.0, true)
		"waterhole":
			if is_dry_season:
				canvas.draw_arc(badge + Vector2(0, 1), 6.0, 0, TAU, 16, Color("#b09162"), 1.2, true)
				canvas.draw_line(badge + Vector2(-3, 0), badge + Vector2(3, 2), Color("#8c734b"), 1.0, true)
			else:
				canvas.draw_circle(badge + Vector2(0, 1), 5.0, Color("#4c8e94", 0.75))
				canvas.draw_arc(badge + Vector2(0, 1), 6.0, 0, TAU, 16, Color("#9dd2c4"), 1.2, true)
				_draw_reeds(canvas, badge + Vector2(4, -3))


func _draw_flower(canvas: CanvasItem, point: Vector2, color: Color) -> void:
	canvas.draw_line(point + Vector2(0, 3), point + Vector2(0, -2), Color("#667448"), 1.0, true)
	canvas.draw_circle(point + Vector2(-2, -3), 1.5, color.darkened(0.08))
	canvas.draw_circle(point + Vector2(2, -3), 1.5, color.lightened(0.08))
	canvas.draw_circle(point + Vector2(0, -4), 1.4, Color("#f0d38d"))


func _draw_boulder(canvas: CanvasItem, point: Vector2, size: float) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([
		point + Vector2(-6 * size, 2 * size), point + Vector2(-4 * size, -3 * size),
		point + Vector2(1 * size, -5 * size), point + Vector2(6 * size, -2 * size),
		point + Vector2(5 * size, 3 * size)
	]), Color("#776f57"))
	canvas.draw_line(point + Vector2(-3 * size, -2 * size), point + Vector2(1 * size, -4 * size), Color("#b2a27a", 0.7), 1.0, true)


func _draw_reeds(canvas: CanvasItem, point: Vector2) -> void:
	var reed := Color("#9ba36a", 0.8)
	canvas.draw_line(point, point + Vector2(-3, -10), reed, 1.2, true)
	canvas.draw_line(point + Vector2(2, 1), point + Vector2(3, -12), reed, 1.2, true)
	canvas.draw_line(point + Vector2(5, 2), point + Vector2(9, -7), reed, 1.2, true)
	canvas.draw_line(point + Vector2(-2, 1), point + Vector2(-7, -6), reed.darkened(0.12), 1.0, true)
	canvas.draw_circle(point + Vector2(3, -12), 1.2, Color("#6f5e3e"))
	canvas.draw_circle(point + Vector2(-3, -10), 1.0, Color("#796746"))


func _draw_tree(canvas: CanvasItem, point: Vector2, size: float) -> void:
	var scale := 0.68 + size * 0.38
	draw_ellipse_shadow(canvas, point + Vector2(1, 5), Vector2(12, 3) * scale)
	canvas.draw_line(point + Vector2(0, 7 * scale), point + Vector2(0, -8 * scale), Color("#68563a"), 2.2 * scale, true)
	canvas.draw_line(point + Vector2(0, -5 * scale), point + Vector2(-7, -11) * scale, Color("#735f3e"), 1.4 * scale, true)
	canvas.draw_line(point + Vector2(1, -7 * scale), point + Vector2(8, -12) * scale, Color("#594a34"), 1.2 * scale, true)
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


func _draw_mountain_tile(canvas: CanvasItem, center: Vector2, x: int, y: int, variation: float) -> void:
	var relief := world.terrain_noise.get_noise_2d(x - 9, y + 15)
	var height := 38.0 + relief * 15.0 + variation * 18.0
	var lean := lerpf(-6.0, 7.0, world.tile_noise(x, y, 225))
	_draw_mountain_peak(canvas, center + Vector2(16, -6), 23.0, height * 0.72, -lean, x, y, 0)
	_draw_mountain_peak(canvas, center + Vector2(-9, 4), 32.0, height, lean, x, y, 1)
	if variation > 0.45:
		_draw_mountain_peak(canvas, center + Vector2(21, 12), 19.0, height * 0.57, lean * 0.5, x, y, 2)


func _draw_mountain_peak(canvas: CanvasItem, base: Vector2, width: float, height: float, lean: float, x: int, y: int, peak_index: int) -> void:
	var salt := 400 + peak_index * 80
	var summit := base + Vector2(lean, -height)
	var feet := PackedVector2Array([
		base + Vector2(-width, 0),
		base + Vector2(-width * 0.53, 5),
		base + Vector2(-width * 0.16, 2),
		base + Vector2(width * 0.14, 10),
		base + Vector2(width * 0.46, 4),
		base + Vector2(width, 0)
	])
	var rock_colors := [
		Color("#aaa18a"), Color("#d0c1a4"), Color("#857b70"),
		Color("#554e4c"), Color("#73675e")
	]
	var shoulders := PackedVector2Array()
	for i in range(feet.size()):
		var depth := lerpf(0.42, 0.68, world.tile_noise(x, y, salt + i))
		var shoulder := summit.lerp(feet[i], depth)
		shoulder.x += lerpf(-3.0, 3.0, world.tile_noise(x, y, salt + 6 + i))
		shoulders.append(shoulder)

	for i in range(rock_colors.size()):
		var rock: Color = rock_colors[i]
		var left := shoulders[i]
		var right := shoulders[i + 1]
		canvas.draw_polygon(
			PackedVector2Array([summit, left, right]),
			PackedColorArray([rock.lightened(0.26), rock, rock.darkened(0.08)])
		)
		# Split each lower face to keep the ridges angular as they meet the scree.
		var foot_color := Color("#817b58").lerp(rock, 0.22)
		canvas.draw_polygon(
			PackedVector2Array([left, feet[i], right]),
			PackedColorArray([rock, foot_color, rock.darkened(0.11)])
		)
		canvas.draw_polygon(
			PackedVector2Array([right, feet[i], feet[i + 1]]),
			PackedColorArray([rock.darkened(0.11), foot_color, foot_color.darkened(0.08)])
		)
		for j in range(6):
			var grain := salt + 12 + i * 12 + j * 2
			var depth := lerpf(0.27, 0.94, world.tile_noise(x, y, grain))
			var across := lerpf(0.15, 0.75, world.tile_noise(x, y, grain + 1))
			var start := left.lerp(right, across)
			var end := feet[i].lerp(feet[i + 1], across)
			var point := summit.lerp(start, depth * 2.0) if depth < 0.5 else start.lerp(end, depth * 2.0 - 1.0)
			var ink := Color("#eee1c7", 0.42) if (i + j) % 3 == 0 else Color("#352f2b", 0.32)
			canvas.draw_line(point, point + Vector2(1.5, 2.0), ink, 0.85, true)


func _draw_volcanic_tile(canvas: CanvasItem, center: Vector2, variation: float) -> void:
	var peak_height := 15.0 + variation * 8.0
	var peak := center + Vector2(-2, -peak_height)
	var distant_peak := center + Vector2(22, -peak_height * 0.58)
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(2, 10), distant_peak, center + Vector2(34, 11)
	]), Color("#796952"))
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-30, 10), peak, center + Vector2(10, 11)
	]), Color("#96795e"))
	canvas.draw_colored_polygon(PackedVector2Array([
		peak, center + Vector2(25, 9), center + Vector2(10, 11)
	]), Color("#554d43"))
	canvas.draw_line(peak, center + Vector2(-8, 3), Color("#d4c6a1", 0.8), 1.5, true)
	canvas.draw_arc(center + Vector2(0, -peak_height + 4), 4.0, PI, TAU, 10, Color("#bd6848"), 1.6)


func _draw_grass(canvas: CanvasItem, point: Vector2, color: Color) -> void:
	canvas.draw_line(point, point + Vector2(-3, -7), color, 1.0, true)
	canvas.draw_line(point + Vector2(2, 1), point + Vector2(5, -6), color, 1.0, true)
	canvas.draw_line(point + Vector2(6, 2), point + Vector2(9, -3), color, 1.0, true)


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
			canvas.draw_line(mark, mark + Vector2(4.0 + float(i % 2) * 3.0, -1.0), texture_color, 0.8, true)


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
	canvas.draw_line(point + Vector2(0, 5) * scale, point + Vector2(1, -11) * scale, Color("#665035"), 2.2 * scale, true)
	canvas.draw_line(point + Vector2(1, -6) * scale, point + Vector2(-9, -13) * scale, Color("#665035"), 1.4 * scale, true)
	canvas.draw_line(point + Vector2(1, -7) * scale, point + Vector2(10, -14) * scale, Color("#59462f"), 1.4 * scale, true)
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
	canvas.draw_multiline_colors(segments, colors, 1.0, true)


func _draw_shrub(canvas: CanvasItem, point: Vector2, scale: float, foliage: Color) -> void:
	draw_ellipse_shadow(canvas, point + Vector2(1, 2), Vector2(8, 2) * scale)
	for branch in range(3):
		var offset := float(branch - 1) * 3.0
		canvas.draw_line(point + Vector2(offset, 2) * scale, point + Vector2(offset * 1.6, -7 - branch % 2) * scale, Color("#65553b"), 1.0, true)
	canvas.draw_circle(point + Vector2(-5, -5) * scale, 4.5 * scale, foliage.darkened(0.08))
	canvas.draw_circle(point + Vector2(1, -7) * scale, 5.0 * scale, foliage)
	canvas.draw_circle(point + Vector2(6, -4) * scale, 4.0 * scale, foliage.lightened(0.1))
	canvas.draw_circle(point + Vector2(2, -9) * scale, 1.1 * scale, Color("#c8ad65", 0.8))


func _draw_tall_grass(canvas: CanvasItem, point: Vector2, scale: float, color: Color) -> void:
	for blade in range(5):
		var root := point + Vector2(float(blade) * 2.0 - 4.0, float(blade % 2))
		var lean := float(blade - 2) * 1.4
		canvas.draw_line(root, root + Vector2(lean, (-7.0 - float(blade % 3)) * scale), color.lightened(float(blade) * 0.025), 0.9, true)


func _draw_palm(canvas: CanvasItem, point: Vector2, scale: float) -> void:
	draw_ellipse_shadow(canvas, point + Vector2(3, 4), Vector2(12, 3) * scale)
	canvas.draw_line(point + Vector2(0, 5) * scale, point + Vector2(2, -17) * scale, Color("#7c6038"), 2.6 * scale, true)
	canvas.draw_line(point + Vector2(1, -5) * scale, point + Vector2(3, -16) * scale, Color("#b08a50", 0.75), 0.9, true)
	var crown := point + Vector2(2, -17) * scale
	for direction in [Vector2(-14, -4), Vector2(-11, 3), Vector2(-4, -8), Vector2(7, -8), Vector2(14, -3), Vector2(11, 4)]:
		var tip: Vector2 = crown + direction * scale
		canvas.draw_line(crown, tip, Color("#4f7047"), 2.0 * scale, true)
		var axis := (tip - crown).normalized()
		for leaflet in range(1, 6):
			var fraction := float(leaflet) / 6.0
			var stem := crown.lerp(tip, fraction)
			var spread := sin(fraction * PI) * 3.2 * scale
			var sweep := axis * spread * 0.58
			canvas.draw_line(stem, stem + sweep + axis.orthogonal() * spread, Color("#8a9b60"), 0.8, true)
			canvas.draw_line(stem, stem + sweep - axis.orthogonal() * spread, Color("#496a43"), 0.8, true)
	canvas.draw_circle(crown + Vector2(-2, 2) * scale, 2.0 * scale, Color("#705436"))
	canvas.draw_circle(crown + Vector2(2, 2) * scale, 2.0 * scale, Color("#705436"))


func _draw_player_activity(canvas: CanvasItem, center: Vector2, activity: String, ai_bands: Array[Dictionary]) -> void:
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
