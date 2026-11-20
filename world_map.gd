class_name WorldMap
extends RefCounted

const TILE_W := 92.0
const TILE_H := 50.0
const WORLD_WIDTH := 64
const WORLD_HEIGHT := 48
const MAP_ORIGIN := Vector2(411.0, -250.0)
const LAKE_CENTER := Vector2(20, 14)
const LAKE_RADII := Vector2(2.7, 3.2)
const RIVER_HALF_WIDTH := 0.34
const RIVER_SOURCE_Y := 5.5
const SHORE_BANK_MARGIN := 0.24
const SHORE_COLOR := Color("#679a8d")
const SHORE_SAND := Color("#a99467")
const SHORE_DEEP := Color("#397b86")
const SHORE_UVS := [Vector2(0.5, 0.0), Vector2(1.0, 0.5), Vector2(0.5, 1.0), Vector2(0.0, 0.5)]
const SPRING_TILE := Vector2i(13, 10)
const EASTERN_SPRING_TILE := Vector2i(43, 30)
const SPRING_TILES := [SPRING_TILE, EASTERN_SPRING_TILE]
const WORLD_START := Vector2i(16, 12)

const TILE_EDGES := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const TILE_VERTICES := [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]

const LANDMARKS := [
	{"tile":Vector2i(15, 9), "name":"Hominin Fossil Beds", "kind":"fossil", "food":0, "knowledge":10, "cohesion":0},
	{"tile":SPRING_TILE, "name":"Spring-Fed Riverbank", "kind":"spring", "food":10, "knowledge":0, "cohesion":0},
	{"tile":Vector2i(8, 18), "name":"Obsidian Outcrop", "kind":"obsidian", "food":0, "knowledge":7, "cohesion":0},
	{"tile":Vector2i(28, 6), "name":"Sheltered Cliff", "kind":"shelter", "food":0, "knowledge":0, "cohesion":6},
	{"tile":Vector2i(21, 17), "name":"Seasonal Waterhole", "kind":"waterhole", "food":12, "knowledge":0, "cohesion":0},
	{"tile":EASTERN_SPRING_TILE, "name":"Eastern Spring", "kind":"spring", "food":10, "knowledge":0, "cohesion":0},
	{"tile":Vector2i(50, 34), "name":"Escarpment Overhang", "kind":"shelter", "food":0, "knowledge":0, "cohesion":6},
	{"tile":Vector2i(33, 39), "name":"Southern Stone Beds", "kind":"fossil", "food":0, "knowledge":10, "cohesion":0}
]

var terrain_noise := FastNoiseLite.new()
var terrain_tiles: Array[String] = []
var shoreline_tiles: Dictionary = {}
var land_routes := AStar2D.new()


func setup() -> void:
	terrain_noise.seed = 3217
	terrain_noise.frequency = 0.19
	terrain_tiles.clear()
	shoreline_tiles.clear()
	land_routes.clear()
	for y in range(WORLD_HEIGHT):
		for x in range(WORLD_WIDTH):
			terrain_tiles.append(_classify_terrain(x, y))
	_build_shoreline()
	_build_land_routes()


func tile_id(tile: Vector2i) -> int:
	return tile.y * WORLD_WIDTH + tile.x


func tile_center(x: int, y: int) -> Vector2:
	return MAP_ORIGIN + Vector2((x - y) * TILE_W / 2.0, (x + y) * TILE_H / 2.0)


func map_coordinates(point: Vector2) -> Vector2:
	var local := point - MAP_ORIGIN
	var diagonal := local.x / (TILE_W * 0.5)
	var depth := local.y / (TILE_H * 0.5)
	return Vector2(diagonal + depth, depth - diagonal) * 0.5


func tile_from_world(point: Vector2) -> Vector2i:
	var tile := map_coordinates(point).round()
	return Vector2i(tile).clamp(Vector2i.ZERO, Vector2i(WORLD_WIDTH - 1, WORLD_HEIGHT - 1))


func project_tile_offset(offset: Vector2) -> Vector2:
	return Vector2((offset.x - offset.y) * TILE_W, (offset.x + offset.y) * TILE_H) * 0.5


func tiles_in_radius(center: Vector2i, radius: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for y in range(maxi(0, center.y - radius), mini(WORLD_HEIGHT - 1, center.y + radius) + 1):
		for x in range(maxi(0, center.x - radius), mini(WORLD_WIDTH - 1, center.x + radius) + 1):
			var tile := Vector2i(x, y)
			if tile.distance_squared_to(center) <= radius * radius:
				tiles.append(tile)
	return tiles


func terrain_at(tile: Vector2i) -> String:
	if not Rect2i(0, 0, WORLD_WIDTH, WORLD_HEIGHT).has_point(tile):
		return ""
	return terrain_tiles[tile_id(tile)]


func landmark_for_tile(tile: Vector2i) -> Dictionary:
	for landmark in LANDMARKS:
		if landmark["tile"] == tile:
			return landmark
	return {}


func near_permanent_water(tile: Vector2i) -> bool:
	if tile in SPRING_TILES:
		return true
	if terrain_at(tile) in ["river", "lake"]:
		return true
	for edge in TILE_EDGES:
		var neighbor: Vector2i = tile + edge
		if neighbor in SPRING_TILES or terrain_at(neighbor) in ["river", "lake"]:
			return true
	return false


func tile_noise(x: int, y: int, salt: int) -> float:
	return absf(sin(float(x * 127 + y * 311 + salt * 74) * 0.17317))


func get_shoreline(tile: Vector2i) -> Dictionary:
	return shoreline_tiles.get(tile_id(tile), {})


func get_shoreline_texture(tile: Vector2i) -> ImageTexture:
	var shore: Dictionary = shoreline_tiles.get(tile_id(tile), {})
	if shore.is_empty():
		return null
	if not shore.has("texture"):
		shore["texture"] = _make_shoreline_texture(tile)
	return shore["texture"]


func land_position(position: Vector2) -> bool:
	var tile := tile_from_world(position)
	if terrain_at(tile) in ["river", "lake"]:
		return false
	var shore: Dictionary = shoreline_tiles.get(tile_id(tile), {})
	var offset := position - tile_center(tile.x, tile.y)
	for water in shore.get("water", []):
		if Geometry2D.is_point_in_polygon(offset, water):
			return false
	return true


func land_segment_clear(from: Vector2, to: Vector2) -> bool:
	if not land_position(to):
		return false
	var first := tile_from_world(from)
	var last := tile_from_world(to)
	for y in range(mini(first.y, last.y), maxi(first.y, last.y) + 1):
		for x in range(mini(first.x, last.x), maxi(first.x, last.x) + 1):
			var shore: Dictionary = shoreline_tiles.get(tile_id(Vector2i(x, y)), {})
			if shore.is_empty():
				continue
			var center := tile_center(x, y)
			var segment := PackedVector2Array([from - center, to - center])
			for water in shore["water"]:
				if not Geometry2D.intersect_polyline_with_polygon(segment, water).is_empty():
					return false
	return true


func nearest_land_tile(tile: Vector2i) -> Vector2i:
	if land_routes.has_point(tile_id(tile)):
		return tile
	var id := land_routes.get_closest_point(tile_center(tile.x, tile.y))
	return tile_from_world(land_routes.get_point_position(id))


func has_land_route_point(tile: Vector2i) -> bool:
	return land_routes.has_point(tile_id(tile))


func find_route(origin: Vector2, tile: Vector2i, direct := false) -> Dictionary:
	var origin_id := tile_id(tile_from_world(origin))
	var destination_id := tile_id(tile)
	if terrain_at(tile).is_empty() or not land_routes.has_point(destination_id):
		return {"ok": false, "route": []}
	var route: Array[Vector2] = []
	if direct:
		if not land_routes.are_points_connected(origin_id, destination_id):
			return {"ok": false, "route": []}
		route.append(tile_center(tile.x, tile.y))
	else:
		var path := land_routes.get_point_path(origin_id, destination_id)
		if path.is_empty():
			return {"ok": false, "route": []}
		for i in range(1, path.size()):
			route.append(path[i])
	return {"ok": true, "route": route}


func _river_center(y: float) -> float:
	return 12.0 + sin((y - 10.0) * 0.32) * 1.55 + sin((y - 10.0) * 0.61) * 0.35


func _river_half_width(y: float) -> float:
	return smoothstep(RIVER_SOURCE_Y, RIVER_SOURCE_Y + 1.0, y) * (RIVER_HALF_WIDTH + sin(y * 0.91) * 0.06)


func _classify_terrain(x: int, y: int) -> String:
	var relief := terrain_noise.get_noise_2d(x, y)
	if Vector2i(x, y) == EASTERN_SPRING_TILE:
		return "wetland"
	var lake_distance := ((Vector2(x, y) - LAKE_CENTER) / LAKE_RADII).length_squared() + relief * 0.5
	if lake_distance < 1.0:
		return "lake"
	var river := roundi(_river_center(y))
	var previous := roundi(_river_center(maxi(0, y - 1)))
	if y > RIVER_SOURCE_Y and x >= mini(river, previous) and x <= maxi(river, previous):
		return "river"
	if absf(x - (26.0 + 2.4 * sin(y * 0.24))) < 2.7 + relief * 3.0 and y >= 1 and y <= 22:
		return "highland"
	if y >= 14 and y <= 44 and absf(x - (51.0 + 4.2 * sin(y * 0.18))) < 3.6 + relief * 3.0:
		return "highland"
	if y >= 14 and absf(x - (7.0 + sin(y * 0.38))) < 2.2 + relief * 2.0:
		return "volcanic"
	if (y > RIVER_SOURCE_Y and x == river + 1) or lake_distance < 1.35:
		return "wetland"
	if relief > 0.12:
		return "woodland"
	if (x < 10 and y > 9) or (y >= 28 and x >= 24 and relief < 0.06):
		return "dryland"
	return "savanna"


func _build_shoreline() -> void:
	for margin: float in [SHORE_BANK_MARGIN, 0.0]:
		var lake := PackedVector2Array()
		for i in range(64):
			var direction := Vector2.from_angle(float(i) * TAU / 64.0)
			var radius := direction * LAKE_RADII
			var variation := terrain_noise.get_noise_2dv(LAKE_CENTER + radius) * 0.23
			lake.append(LAKE_CENTER + radius * (1.0 + variation) + direction * margin)

		var river := PackedVector2Array()
		var right_bank := PackedVector2Array()
		var samples := int((WORLD_HEIGHT - 0.5 - RIVER_SOURCE_Y) * 4.0)
		for i in range(samples + 1):
			var y := lerpf(RIVER_SOURCE_Y - margin, WORLD_HEIGHT - 0.5, float(i) / samples)
			var center := _river_center(y)
			var width := _river_half_width(y) + margin
			river.append(Vector2(center - width, y))
			right_bank.append(Vector2(center + width, y))
		right_bank.reverse()
		river.append_array(right_bank)
		_cache_shoreline_mask(lake, margin == 0.0)
		_cache_shoreline_mask(river, margin == 0.0)
	for id in shoreline_tiles:
		var tile := Vector2i(id % WORLD_WIDTH, floori(float(id) / WORLD_WIDTH))
		_cache_shoreline_ripples(tile, shoreline_tiles[id])


func _cache_shoreline_mask(outline: PackedVector2Array, waterline: bool) -> void:
	var bounds := Rect2(outline[0], Vector2.ZERO)
	for point in outline:
		bounds = bounds.expand(point)
	bounds = bounds.grow(0.5)
	for y in range(maxi(0, ceili(bounds.position.y)), mini(WORLD_HEIGHT - 1, floori(bounds.end.y)) + 1):
		for x in range(maxi(0, ceili(bounds.position.x)), mini(WORLD_WIDTH - 1, floori(bounds.end.x)) + 1):
			var tile := Vector2i(x, y)
			var square := PackedVector2Array()
			for vertex in TILE_VERTICES:
				square.append(Vector2(tile) + vertex)
			for clipped in Geometry2D.intersect_polygons(square, outline):
				var points := PackedVector2Array()
				for vertex in clipped:
					var offset: Vector2 = vertex - Vector2(tile)
					points.append(project_tile_offset(offset))
				var id := tile_id(tile)
				if not shoreline_tiles.has(id):
					shoreline_tiles[id] = {"bank": [], "water": [], "ripples": []}
				var shore: Dictionary = shoreline_tiles[id]
				shore["water" if waterline else "bank"].append(points)


func _make_shoreline_texture(tile: Vector2i) -> ImageTexture:
	var width := int(TILE_W)
	var height := int(TILE_H)
	var pixels := PackedByteArray()
	pixels.resize(width * height * 4)
	var near_lake := absf(tile.x - LAKE_CENTER.x) <= LAKE_RADII.x + 1.5
	var shore_depth := 0.48 if near_lake else 0.22
	var idx := 0
	for y in range(height):
		var v := (float(y) + 0.5) / height - 0.5
		for x in range(width):
			var u := (float(x) + 0.5) / width - 0.5
			var point := Vector2(tile) + Vector2(v + u, v - u)
			var distance := maxf(RIVER_SOURCE_Y - point.y, absf(point.x - _river_center(point.y)) - _river_half_width(point.y))
			if near_lake:
				var delta := point - LAKE_CENTER
				var radius := (delta / LAKE_RADII).normalized() * LAKE_RADII
				var variation := terrain_noise.get_noise_2dv(LAKE_CENTER + radius) * 0.23
				var lake_distance := delta.length() - radius.length() * (1.0 + variation)
				if delta.is_zero_approx():
					lake_distance = -LAKE_RADII.x
				distance = minf(distance, lake_distance)
			var color := _shoreline_color(distance, shore_depth)
			pixels[idx] = clampi(int(roundf(color.r * 255.0)), 0, 255)
			pixels[idx + 1] = clampi(int(roundf(color.g * 255.0)), 0, 255)
			pixels[idx + 2] = clampi(int(roundf(color.b * 255.0)), 0, 255)
			pixels[idx + 3] = clampi(int(roundf(color.a * 255.0)), 0, 255)
			idx += 4
	var raster := Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, pixels)
	return ImageTexture.create_from_image(raster)


func _shoreline_color(distance: float, depth: float) -> Color:
	if distance <= 0.0:
		return SHORE_COLOR.lerp(SHORE_DEEP, smoothstep(0.0, depth, -distance))
	var bank := SHORE_COLOR.lerp(SHORE_SAND, smoothstep(0.0, SHORE_BANK_MARGIN * 0.65, distance))
	bank.a = 1.0 - smoothstep(0.0, SHORE_BANK_MARGIN, distance)
	return bank


func _cache_shoreline_ripples(tile: Vector2i, shore: Dictionary) -> void:
	for i in range(6):
		var y := lerpf(-15.0, 15.0, tile_noise(tile.x, tile.y, i + 51))
		var half_width := TILE_W * 0.5 * (1.0 - absf(y) / (TILE_H * 0.5))
		var x := lerpf(-half_width, half_width * 0.6, tile_noise(tile.x, tile.y, i + 71))
		var ripple := PackedVector2Array([Vector2(x, y), Vector2(x + 12.0, y)])
		for water in shore["water"]:
			shore["ripples"].append_array(Geometry2D.intersect_polyline_with_polygon(ripple, water))


func _build_land_routes() -> void:
	for y in range(WORLD_HEIGHT):
		for x in range(WORLD_WIDTH):
			var center := tile_center(x, y)
			if land_position(center):
				land_routes.add_point(tile_id(Vector2i(x, y)), center)
	for y in range(WORLD_HEIGHT):
		for x in range(WORLD_WIDTH):
			var tile := Vector2i(x, y)
			var id := tile_id(tile)
			if not land_routes.has_point(id):
				continue
			for step: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i(1, 1), Vector2i(-1, 1)]:
				var neighbor := tile + step
				if terrain_at(neighbor).is_empty() or not land_routes.has_point(tile_id(neighbor)):
					continue
				if step.x != 0 and step.y != 0:
					# A diagonal must leave room on both sides of the shared corner.
					if not land_routes.has_point(tile_id(tile + Vector2i(step.x, 0))) or not land_routes.has_point(tile_id(tile + Vector2i(0, step.y))):
						continue
				if land_segment_clear(tile_center(x, y), tile_center(neighbor.x, neighbor.y)):
					land_routes.connect_points(id, tile_id(neighbor))
