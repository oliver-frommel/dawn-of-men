extends Node2D

const W := 1440.0
const H := 900.0
const TILE_W := 92.0
const TILE_H := 50.0
const WORLD_WIDTH := 64
const WORLD_HEIGHT := 48
const PLAYER_SPEED := 56.0
const TRAVEL_ACCELERATION := 240.0
const PLAYER_COUNT := 1
const NEIGHBOR_BAND_SIZE := 3
const BAND_FADE_IN := 0.5
const BAND_FADE_OUT := 0.85
const CHRONICLE_TURNS := 32
const POSSIBLE_FIRE_USE_KA := 2000
const HEARTH_KEEPING_KA := 1000
const WET_SEASON_FOOD_COST := 6
const DRY_SEASON_WATER_FOOD_COST := 4
const DRY_SEASON_FOOD_COST := 10
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
const MATING_FOOD_COST := 8
const MATE_RANGE := 76.0
const SUCCESSION_SEASONS := 2
const SUCCESSION_COHESION := 8
const SCOUT_RADIUS := 4
const FORAGE_KNOWLEDGE_THRESHOLD := 45
const FORAGE_KNOWLEDGE_BONUS := 4
const WET_FORAGE_YIELDS := {
	"woodland": 18, "wetland": 22, "savanna": 13, "river": 0,
	"highland": 9, "dryland": 6, "volcanic": 6, "lake": 0
}
const DRY_FORAGE_YIELDS := {
	"woodland": 10, "wetland": 10, "savanna": 8, "river": 0,
	"highland": 6, "dryland": 4, "volcanic": 4, "lake": 0
}
const DRY_SPRING_FORAGE := 18
const WORLD_START := Vector2i(16,12)
const MAP_VIEW := Rect2(0.0, 70.0, 1190.0, 760.0)
const MAP_ORIGIN := Vector2(411.0, -250.0)
const SPECIES := [
	{"name":"Australopithecus afarensis", "short":"A. afarensis", "date":4200, "color":Color("#e4a958"), "trait":"Upright walking", "kind":"ancestor"},
	{"name":"Paranthropus boisei", "short":"Paranthropus", "date":2300, "color":Color("#c78754"), "trait":"Robust jaw", "kind":"cousin"},
	{"name":"Homo habilis", "short":"H. habilis", "date":2400, "color":Color("#dc805e"), "trait":"Stone tools", "kind":"ancestor"},
	{"name":"Homo erectus", "short":"H. erectus", "date":1900, "color":Color("#d87063"), "trait":"Long-distance travel", "kind":"ancestor"},
	{"name":"Homo heidelbergensis", "short":"Heidelbergensis", "date":700, "color":Color("#a96778"), "trait":"Cooperative hunting", "kind":"ancestor"},
	{"name":"Neanderthals", "short":"Neanderthals", "date":400, "color":Color("#857cb1"), "trait":"Cold adaptation", "kind":"sister"},
	{"name":"Denisovans", "short":"Denisovans", "date":350, "color":Color("#6194b3"), "trait":"Highland adaptation", "kind":"sister"},
	{"name":"Homo sapiens", "short":"H. sapiens", "date":300, "color":Color("#55b69e"), "trait":"Symbolic culture", "kind":"ancestor"}
]
const LANDMARKS := [
	{"tile":Vector2i(15,9), "name":"Hominin Fossil Beds", "kind":"fossil", "food":0, "knowledge":10, "cohesion":0},
	{"tile":SPRING_TILE, "name":"Spring-Fed Riverbank", "kind":"spring", "food":10, "knowledge":0, "cohesion":0},
	{"tile":Vector2i(8,18), "name":"Obsidian Outcrop", "kind":"obsidian", "food":0, "knowledge":7, "cohesion":0},
	{"tile":Vector2i(28,6), "name":"Sheltered Cliff", "kind":"shelter", "food":0, "knowledge":0, "cohesion":6},
	{"tile":Vector2i(21,17), "name":"Seasonal Waterhole", "kind":"waterhole", "food":12, "knowledge":0, "cohesion":0},
	{"tile":EASTERN_SPRING_TILE, "name":"Eastern Spring", "kind":"spring", "food":10, "knowledge":0, "cohesion":0},
	{"tile":Vector2i(50, 34), "name":"Escarpment Overhang", "kind":"shelter", "food":0, "knowledge":0, "cohesion":6},
	{"tile":Vector2i(33, 39), "name":"Southern Stone Beds", "kind":"fossil", "food":0, "knowledge":10, "cohesion":0}
]

const TILE_EDGES := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const TILE_VERTICES := [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]

const HOMININ_MODEL_SCRIPT := preload("res://hominin_model.gd")
const WILDLIFE_MODEL_SCRIPT := preload("res://wildlife_model.gd")

var turn := 0
var generation := 1
var succession_turn := -1
var season_action_used := false
var kinship_recorded := false
var year_bp := 3200
var food := 68
var knowledge := 12
var cohesion := 57
var discovered: Array[int] = [0, 2]
var event_log: Array[String] = ["The Rift Valley opens before your ancestors. Travel permanently charts the land.", "Afarensis bands learn the old paths."]
var map_names := ["Laetoli", "Olduvai", "Turkana", "Afar", "Awash", "Omo", "Tugen Hills", "Lomekwi"]
var toast := ""
var toast_timer := 0.0
var hide_wrap_unlocked := false
var ui_layer: CanvasLayer
var stats_label: Label
var age_label: Label
var period_label: Label
var species_label: Label
var event_label: Label
var action_label: Label
var forage_button: Button
var scout_button: Button
var learn_button: Button
var kinship_button: Button
var mate_button: Button
var advance_button: Button
var toast_label: Label
var player_actor: Dictionary = {}
var ai_bands: Array[Dictionary] = []
var camera_offset := Vector2.ZERO
var camera_dragging := false
var ai_rng := RandomNumberGenerator.new()
var movement_key := KEY_NONE
var keyboard_step := Vector2i.ZERO
var hominin_viewport: SubViewport
var hominin_stage: Node3D
var hominin_models: Array[Node3D] = []
var wildlife: Array[Dictionary] = []
var wildlife_epoch := -1
var explored_tiles: Dictionary = {}
var visible_tiles: Dictionary = {}
var discovered_landmarks: Dictionary = {}
var met_bands: Dictionary = {}
var visibility_center := Vector2i(-1, -1)
var visibility_radius := 0
var zoom_level := 1.0
var terrain_noise := FastNoiseLite.new()
var terrain_tiles: Array[String] = []
var shoreline_tiles: Dictionary = {}
var land_routes := AStar2D.new()


func _ready() -> void:
	terrain_noise.seed = 3217
	terrain_noise.frequency = 0.19
	for y in range(WORLD_HEIGHT):
		for x in range(WORLD_WIDTH):
			terrain_tiles.append(_classify_terrain(x, y))
	_build_shoreline()
	_build_land_routes()
	player_actor = _make_actor(WORLD_START)
	player_actor["is_player"] = true
	ai_bands = [
		_make_ai_band("Western roamers", Vector2i(12,15), [Vector2i(12,15),Vector2i(7,18),Vector2i(10,21),Vector2i(15,17),Vector2i(12,15)], Color("#d78166"), 0.8),
		_make_ai_band("Northern roamers", Vector2i(21,9), [Vector2i(21,9),Vector2i(25,4),Vector2i(29,10),Vector2i(26,17),Vector2i(21,9)], Color("#7799b9"), 1.6),
		_make_ai_band("Eastern Spring camp", EASTERN_SPRING_TILE, [], Color("#a68cb4"), 0.0)
	]
	_build_hominin_viewport()
	_sync_hominin_models()
	_sync_wildlife()
	ai_rng.randomize()
	_build_ui()
	_reveal_around(WORLD_START, 2)
	_clamp_camera_offset()
	_sync_hominin_models()
	_position_wildlife_models()
	queue_redraw()
	_check_band_encounters()

func _process(delta: float) -> void:
	_continue_keyboard_movement(delta)
	var moved := _update_actor(player_actor, delta, PLAYER_SPEED)
	var previous_camera_offset := camera_offset
	if moved and not camera_dragging:
		_follow_player_camera()
	if camera_offset != previous_camera_offset:
		_position_wildlife_models()
		moved = true
	if moved:
		var player_tile := _tile_from_world(player_actor["position"])
		if player_tile != visibility_center:
			_reveal_around(player_tile, 2)
			_position_wildlife_models()
	var bands_moved := false
	var bands_need_redraw := false
	for band in ai_bands:
		var band_moved := _update_ai_band(band, delta)
		bands_moved = bands_moved or band_moved
		var presence_changed := _update_band_presence(band, delta)
		if presence_changed or (band_moved and band["on_charted_land"]):
			if MAP_VIEW.grow(70.0 * zoom_level).has_point(_world_to_screen(band["last_seen"])):
				bands_need_redraw = true
	_check_band_encounters()
	if moved or bands_moved:
		_refresh_mate_button(_season_action_blocker())
	_sync_hominin_models(delta)
	if _update_wildlife_visibility(delta) or moved or bands_need_redraw:
		queue_redraw()
	if toast_timer > 0:
		toast_timer -= delta
		if toast_timer <= 0 and is_instance_valid(toast_label): toast_label.hide()
	var action_time := float(player_actor.get("action_time", 0.0))
	if action_time > 0.0:
		action_time = maxf(0.0, action_time - delta)
		player_actor["action_time"] = action_time
		if action_time == 0.0 and player_actor["activity"] not in ["idle", "walking"]:
			player_actor["activity"] = "idle"
			_refresh_action_label()
			queue_redraw()

func _tile_id(tile: Vector2i) -> int:
	return tile.y * WORLD_WIDTH + tile.x

func _tile_from_world(point: Vector2) -> Vector2i:
	var tile := _map_coordinates(point).round()
	return Vector2i(tile).clamp(Vector2i.ZERO, Vector2i(WORLD_WIDTH - 1, WORLD_HEIGHT - 1))

func _map_coordinates(point: Vector2) -> Vector2:
	var local := point - MAP_ORIGIN
	var diagonal := local.x / (TILE_W * 0.5)
	var depth := local.y / (TILE_H * 0.5)
	return Vector2(diagonal + depth, depth - diagonal) * 0.5

func _reveal_around(center: Vector2i, radius: int) -> bool:
	if center == visibility_center and radius <= visibility_radius:
		return false
	visible_tiles.clear()
	visibility_center = center
	visibility_radius = radius
	for tile in _tiles_in_radius(center, radius):
		var id := _tile_id(tile)
		visible_tiles[id] = true
		if not explored_tiles.has(id):
			explored_tiles[id] = true
			_discover_landmark(tile)
	_refresh_action_label()
	queue_redraw()
	return true

func _tiles_in_radius(center: Vector2i, radius: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for y in range(maxi(0, center.y - radius), mini(WORLD_HEIGHT - 1, center.y + radius) + 1):
		for x in range(maxi(0, center.x - radius), mini(WORLD_WIDTH - 1, center.x + radius) + 1):
			var tile := Vector2i(x, y)
			if tile.distance_squared_to(center) <= radius * radius:
				tiles.append(tile)
	return tiles

func _landmark_for_tile(tile: Vector2i) -> Dictionary:
	for landmark in LANDMARKS:
		if landmark["tile"] == tile:
			return landmark
	return {}

func _discover_landmark(tile: Vector2i) -> void:
	var landmark := _landmark_for_tile(tile)
	if landmark.is_empty():
		return
	var id := _tile_id(tile)
	if discovered_landmarks.has(id):
		return
	discovered_landmarks[id] = true
	var rewards: Array[String] = []
	var food_gain := int(landmark["food"])
	var knowledge_gain := int(landmark["knowledge"])
	var cohesion_gain := int(landmark["cohesion"])
	food = mini(100, food + food_gain)
	knowledge = mini(99, knowledge + knowledge_gain)
	cohesion = mini(100, cohesion + cohesion_gain)
	if food_gain > 0: rewards.append("food +%d" % food_gain)
	if knowledge_gain > 0: rewards.append("knowledge +%d" % knowledge_gain)
	if cohesion_gain > 0: rewards.append("cohesion +%d" % cohesion_gain)
	_event("DISCOVERY  /  %s. You gain %s." % [landmark["name"], ", ".join(rewards)])
	_refresh_ui()

func _check_band_encounters() -> void:
	for i in range(ai_bands.size()):
		if met_bands.has(i):
			continue
		var band: Dictionary = ai_bands[i]
		if not _world_tile_visible(band["position"]):
			continue
		met_bands[i] = true
		knowledge = mini(99, knowledge + 4)
		cohesion = mini(100, cohesion + 3)
		var neighbors := "a neighboring foraging band"
		if _is_paranthropus_band(i):
			neighbors = "Paranthropus neighbors"
		elif i == 1 and turn >= 8:
			neighbors = "Homo habilis travelers"
		_event("FIRST CONTACT  /  You meet %s. Shared trails and tool ideas spread; knowledge +4, cohesion +3." % neighbors)
		_refresh_ui()

func _make_actor(tile: Vector2i) -> Dictionary:
	var position := _tile_center(tile.x, tile.y)
	return {
		"position":position, "target":position, "heading":Vector2(1,0),
		"gait_phase":0.0, "moving":false, "speed":PLAYER_SPEED, "travel_speed":0.0,
		"activity":"idle", "action_time":0.0, "is_player":false, "route":[]
	}

func _make_ai_band(label: String, start: Vector2i, goals: Array, color: Color, pause: float) -> Dictionary:
	var actor := _make_actor(_nearest_land_tile(start))
	actor["label"] = label
	actor["color"] = color
	actor["on_charted_land"] = false
	actor["last_seen"] = null
	var land_goals: Array[Vector2i] = []
	for goal in goals:
		land_goals.append(_nearest_land_tile(goal))
	actor["goals"] = land_goals
	actor["goal_index"] = 0
	actor["pause"] = pause
	actor["speed"] = 39.0
	actor["opacity"] = 0.0
	return actor

func _update_actor(actor: Dictionary, delta: float, speed: float) -> bool:
	var position: Vector2 = actor["position"]
	var target: Vector2 = actor["target"]
	var remaining := target - position
	var distance := remaining.length()
	var was_moving: bool = actor["moving"]
	var route: Array = actor["route"]
	if distance > 0.001:
		var direction := remaining / distance
		var previous_heading: Vector2 = actor["heading"]
		var forward_speed := float(actor["travel_speed"]) * maxf(0.0, previous_heading.dot(direction))
		var desired_speed := minf(speed, sqrt(2.0 * TRAVEL_ACCELERATION * distance)) if route.is_empty() else speed
		var travel_speed := move_toward(forward_speed, desired_speed, TRAVEL_ACCELERATION * delta)
		var step := minf(distance, travel_speed * delta)
		actor["gait_phase"] = fposmod(float(actor["gait_phase"]) + step * 0.19, TAU)
		actor["heading"] = direction
		actor["travel_speed"] = travel_speed
		if step < distance:
			actor["position"] = position + direction * step
			actor["moving"] = true
			return step > 0.0
	actor["position"] = target
	if not route.is_empty():
		actor["target"] = route.pop_front()
		actor["moving"] = true
		return true
	actor["moving"] = false
	actor["travel_speed"] = 0.0
	if actor["is_player"] and actor["activity"] == "walking":
		actor["activity"] = "idle"
		actor["action_time"] = 0.0
		_refresh_action_label()
		queue_redraw()
	return distance > 0.0 or was_moving

func _update_ai_band(actor: Dictionary, delta: float) -> bool:
	var goals: Array = actor["goals"]
	if goals.is_empty():
		return false
	if float(actor["pause"]) > 0.0:
		actor["pause"] = maxf(0.0, float(actor["pause"]) - delta)
		actor["moving"] = false
		return false
	var position: Vector2 = actor["position"]
	var target: Vector2 = actor["target"]
	if position == target:
		actor["position"] = target
		actor["moving"] = false
		actor["pause"] = ai_rng.randf_range(0.7, 1.8)
		var next_index := (int(actor["goal_index"]) + 1) % goals.size()
		var next_tile: Vector2i = goals[next_index]
		actor["goal_index"] = next_index
		_route_actor_to(actor, next_tile)
		return true
	return _update_actor(actor, delta, float(actor["speed"]))
func _update_band_presence(band: Dictionary, delta: float) -> bool:
	var position: Vector2 = band["position"]
	var mapped := explored_tiles.has(_tile_id(_tile_from_world(position)))
	var was_mapped: bool = band["on_charted_land"]
	band["on_charted_land"] = mapped
	if mapped:
		band["last_seen"] = position
	var opacity: float = band["opacity"]
	var target := 1.0 if mapped else 0.0
	var duration := BAND_FADE_IN if mapped else BAND_FADE_OUT
	var next := move_toward(opacity, target, delta / duration)
	band["opacity"] = next
	return mapped != was_mapped or next != opacity

func _build_hominin_viewport() -> void:
	hominin_viewport = SubViewport.new()
	hominin_viewport.name = "HomininRenderViewport"
	hominin_viewport.size = Vector2i(roundi(MAP_VIEW.size.x), roundi(MAP_VIEW.size.y))
	hominin_viewport.transparent_bg = true
	hominin_viewport.own_world_3d = true
	hominin_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	hominin_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(hominin_viewport)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#ddc9a8")
	environment.ambient_light_energy = 0.72
	environment_node.environment = environment
	hominin_viewport.add_child(environment_node)

	hominin_stage = Node3D.new()
	hominin_stage.name = "HomininStage"
	hominin_viewport.add_child(hominin_stage)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-34.0, -28.0, 0.0)
	sun.light_color = Color("#ffe5bf")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	hominin_stage.add_child(sun)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = MAP_VIEW.size.y / 45.0
	camera.position = Vector3(MAP_VIEW.size.x / 90.0, MAP_VIEW.size.y / 90.0, 18.0)
	camera.near = 0.1
	camera.far = 40.0
	hominin_stage.add_child(camera)
	camera.look_at(Vector3(MAP_VIEW.size.x / 90.0, MAP_VIEW.size.y / 90.0, 0.0), Vector3.UP)
	camera.make_current()

func _is_paranthropus_band(band_index: int) -> bool:
	return band_index == 0 and turn >= 9 and turn <= 20

func _sync_hominin_models(delta := 0.0) -> void:
	_sync_hominin_band(player_actor, -1, true, delta)
	for i in range(ai_bands.size()):
		_sync_hominin_band(ai_bands[i], i, false, delta)

func _sync_hominin_band(actor: Dictionary, band_index: int, player_controlled: bool, delta: float) -> void:
	var model_offset := 0 if player_controlled else PLAYER_COUNT + band_index * NEIGHBOR_BAND_SIZE
	var model_count := PLAYER_COUNT if player_controlled else NEIGHBOR_BAND_SIZE
	var current_stage := 0 if turn < 8 else 2
	var robust := _is_paranthropus_band(band_index)
	if robust:
		current_stage = 1
	var group_color: Color = Color("#e5b267") if player_controlled else actor["color"]
	var opacity: float = 1.0 if player_controlled else actor["opacity"]
	for slot in range(model_count):
		var model_index := model_offset + slot
		var person := 1 if player_controlled else slot
		var wrapping := hide_wrap_unlocked and (person + band_index) % 2 == 0
		var variant := generation % 3 if player_controlled else person
		var signature := "%d:%d:%d:%s" % [current_stage, variant, int(robust), str(wrapping)]
		var model: Node3D
		if model_index >= hominin_models.size():
			model = HOMININ_MODEL_SCRIPT.new() as Node3D
			model.call("configure", current_stage, variant, robust, wrapping, group_color)
			model.set_meta("model_signature", signature)
			hominin_models.append(model)
			hominin_stage.add_child(model)
		else:
			model = hominin_models[model_index]
			if str(model.get_meta("model_signature", "")) != signature:
				model.queue_free()
				model = HOMININ_MODEL_SCRIPT.new() as Node3D
				model.call("configure", current_stage, variant, robust, wrapping, group_color)
				model.set_meta("model_signature", signature)
				hominin_models[model_index] = model
				hominin_stage.add_child(model)
		model.call("set_opacity", opacity)
		if opacity <= 0.0:
			continue
		var live_position: bool = player_controlled or actor["on_charted_land"]
		var center: Vector2 = actor["position"] if live_position else actor["last_seen"]
		var ground := center + Vector2((person - 1) * 25, -3 + (person % 2) * 3)
		if not player_controlled:
			while not _land_segment_clear(center, ground):
				if ground.distance_squared_to(center) <= 1.0:
					ground = center
					break
				ground = center.lerp(ground, 0.5)
		var screen := _world_to_screen(ground)
		var local := screen - MAP_VIEW.position
		model.position = Vector3(local.x / 45.0, (MAP_VIEW.size.y - local.y) / 45.0, screen.y / MAP_VIEW.size.y * 0.02)
		model.scale = Vector3.ONE * 0.55 * zoom_level
		if live_position:
			model.call("set_pose", actor["moving"], float(actor["gait_phase"]) + float(person) * TAU / 3.0, actor["heading"], delta)
func _wildlife_epoch() -> int:
	if turn < 8: return 0
	if turn < 13: return 1
	if turn < 25: return 2
	if turn < 29: return 3
	return 4

func _wildlife_roster() -> Array[Dictionary]:
	var home := _tile_center(WORLD_START.x, WORLD_START.y)
	match _wildlife_epoch():
		0:
			return [
				{"species":"Hipparion", "at":home + Vector2(-82,-58), "phase":0.2},
				{"species":"Sivatherium", "at":home + Vector2(80,-70), "phase":1.7},
				{"species":"Deinotherium", "at":home + Vector2(42,90), "phase":3.1},
				{"species":"Dinofelis", "at":home + Vector2(-110,25), "phase":4.3}
			]
		1:
			return [
				{"species":"Hipparion", "at":home + Vector2(-82,-58), "phase":0.6},
				{"species":"Antelope", "at":home + Vector2(80,-70), "phase":2.0},
				{"species":"Deinotherium", "at":home + Vector2(42,90), "phase":3.7},
				{"species":"Dinofelis", "at":home + Vector2(-110,25), "phase":5.0}
			]
		2:
			return [
				{"species":"Zebra", "at":home + Vector2(-82,-58), "phase":0.2},
				{"species":"Gazelle", "at":home + Vector2(80,-70), "phase":1.9},
				{"species":"Elephant", "at":home + Vector2(42,90), "phase":3.3},
				{"species":"Lion", "at":home + Vector2(-110,25), "phase":4.8}
			]
		3:
			return [
				{"species":"Zebra", "at":home + Vector2(-82,-58), "phase":0.4},
				{"species":"Wildebeest", "at":home + Vector2(80,-70), "phase":2.1},
				{"species":"Elephant", "at":home + Vector2(42,90), "phase":3.7},
				{"species":"Lion", "at":home + Vector2(-110,25), "phase":5.2}
			]
		_:
			return [
				{"species":"Giraffe", "at":home + Vector2(-82,-58), "phase":0.4},
				{"species":"Zebra", "at":home + Vector2(80,-70), "phase":2.1},
				{"species":"Elephant", "at":home + Vector2(42,90), "phase":3.7},
				{"species":"Lion", "at":home + Vector2(-110,25), "phase":5.2}
			]

func _sync_wildlife() -> void:
	var epoch := _wildlife_epoch()
	if epoch == wildlife_epoch or not is_instance_valid(hominin_stage):
		return
	wildlife_epoch = epoch
	var roster := _wildlife_roster()
	for i in range(roster.size()):
		var entry: Dictionary = roster[i]
		if i == wildlife.size():
			wildlife.append(_make_wildlife(entry))
		else:
			var animal := wildlife[i]
			if animal["species"] == entry["species"]:
				animal["replacement"] = {}
			else:
				animal["replacement"] = entry
	_position_wildlife_models()

func _make_wildlife(entry: Dictionary) -> Dictionary:
	var species_name: String = entry["species"]
	var shadow_size := Vector2(17, 5)
	if species_name in ["Deinotherium", "Elephant"]:
		shadow_size = Vector2(25, 7)
	elif species_name in ["Sivatherium", "Giraffe"]:
		shadow_size = Vector2(20, 6)
	elif species_name in ["Dinofelis", "Lion"]:
		shadow_size = Vector2(16, 5)
	var model := WILDLIFE_MODEL_SCRIPT.new()
	model.configure(species_name, float(entry["phase"]))
	model.hide()
	hominin_stage.add_child(model)
	var position: Vector2 = entry["at"]
	if not _land_position(position):
		var tile := _nearest_land_tile(_tile_from_world(position))
		position = _tile_center(tile.x, tile.y)
	return {
		"at": position, "size": shadow_size, "species": species_name,
		"model": model, "opacity": 0.0, "replacement": {}
	}

func _update_wildlife_visibility(delta: float) -> bool:
	var changed := false
	for i in range(wildlife.size()):
		var animal := wildlife[i]
		var model = animal["model"]
		var replacement: Dictionary = animal["replacement"]
		var position: Vector2 = animal["at"]
		var on_screen := MAP_VIEW.grow(52.0 * zoom_level).has_point(_world_to_screen(position))
		var mapped := explored_tiles.has(_tile_id(_tile_from_world(position)))
		var opacity: float = animal["opacity"]
		if not replacement.is_empty() and (opacity <= 0.0 or not on_screen):
			model.hide()
			model.queue_free()
			wildlife[i] = _make_wildlife(replacement)
			_position_wildlife_models()
			changed = true
			continue
		var target := 1.0 if mapped and replacement.is_empty() else 0.0
		var next := move_toward(opacity, target, delta / 0.65) if on_screen else target
		if next != opacity:
			animal["opacity"] = next
			model.set_opacity(next)
			changed = true
	return changed

func _position_wildlife_models() -> void:
	for animal in wildlife:
		var screen := _world_to_screen(animal["at"])
		var local := screen - MAP_VIEW.position
		var model: Node3D = animal["model"]
		model.position = Vector3(local.x / 45.0, (MAP_VIEW.size.y - local.y) / 45.0, screen.y / MAP_VIEW.size.y * 0.02)
		model.scale = Vector3.ONE * 0.68 * zoom_level

func _wildlife_caption() -> String:
	var names: Array[String] = []
	for animal in wildlife:
		if animal["opacity"] > 0.1 and MAP_VIEW.has_point(_world_to_screen(animal["at"])):
			names.append(animal["species"])
	if names.is_empty():
		return "LOCAL WILDLIFE  ·  no tracks in sight"
	return "LOCAL WILDLIFE  ·  " + " /  ".join(names)



func _draw() -> void:
	_draw_world()
	draw_set_transform(_map_draw_origin(), 0.0, Vector2.ONE * zoom_level)
	_draw_map()
	_draw_actor_shadows()
	draw_set_transform(Vector2.ZERO)
	if is_instance_valid(hominin_viewport):
		draw_texture_rect(hominin_viewport.get_texture(), MAP_VIEW, false)
	draw_set_transform(_map_draw_origin(), 0.0, Vector2.ONE * zoom_level)
	_draw_player_marker()
	draw_set_transform(Vector2.ZERO)
	_draw_band_markers()
	draw_string(ThemeDB.fallback_font, Vector2(18.0, 94.0), _wildlife_caption(), HORIZONTAL_ALIGNMENT_LEFT, 790.0, 12, Color("#f0dfb8"))

func _draw_actor_shadows() -> void:
	var player_position: Vector2 = player_actor["position"]
	if MAP_VIEW.grow(65.0).has_point(_world_to_screen(player_position)):
		draw_ellipse_shadow(player_position + Vector2(0.0, 4.0), Vector2(16.0, 5.0))
	for band in ai_bands:
		var opacity: float = band["opacity"]
		if opacity <= 0.0:
			continue
		var position: Vector2 = band["last_seen"]
		if MAP_VIEW.grow(65.0).has_point(_world_to_screen(position)):
			draw_ellipse_shadow(position + Vector2(0.0, 4.0), Vector2(44.0, 9.0), 0.22 * opacity)
	for animal in wildlife:
		var position: Vector2 = animal["at"]
		if animal["opacity"] > 0.0 and MAP_VIEW.grow(65.0).has_point(_world_to_screen(position)):
			draw_ellipse_shadow(position + Vector2(0, 4), animal["size"], 0.22 * animal["opacity"])

func _clamp_camera_offset() -> void:
	var view_center := MAP_VIEW.get_center()
	var world_min_x := _tile_center(0, WORLD_HEIGHT - 1).x - TILE_W * 0.5
	var world_max_x := _tile_center(WORLD_WIDTH - 1, 0).x + TILE_W * 0.5
	var world_min_y := _tile_center(0, 0).y - TILE_H * 0.5
	var world_max_y := _tile_center(WORLD_WIDTH - 1, WORLD_HEIGHT - 1).y + TILE_H * 0.5
	var min_x := world_min_x - view_center.x + MAP_VIEW.size.x / (2.0 * zoom_level)
	var max_x := world_max_x - view_center.x - MAP_VIEW.size.x / (2.0 * zoom_level)
	var min_y := world_min_y - view_center.y + MAP_VIEW.size.y / (2.0 * zoom_level)
	var max_y := world_max_y - view_center.y - MAP_VIEW.size.y / (2.0 * zoom_level)
	camera_offset.x = clampf(camera_offset.x, min_x, max_x)
	camera_offset.y = clampf(camera_offset.y, min_y, max_y)

func _follow_player_camera() -> void:
	var screen_position := _world_to_screen(player_actor["position"])
	var desired := screen_position
	var margin := 120.0
	if screen_position.x < MAP_VIEW.position.x + margin:
		desired.x = MAP_VIEW.position.x + margin
	elif screen_position.x > MAP_VIEW.end.x - margin:
		desired.x = MAP_VIEW.end.x - margin
	if screen_position.y < MAP_VIEW.position.y + margin:
		desired.y = MAP_VIEW.position.y + margin
	elif screen_position.y > MAP_VIEW.end.y - margin:
		desired.y = MAP_VIEW.end.y - margin
	camera_offset += (screen_position - desired) / zoom_level
	_clamp_camera_offset()

func _map_draw_origin() -> Vector2:
	var view_center := MAP_VIEW.get_center()
	return view_center * (1.0 - zoom_level) - camera_offset * zoom_level

func _world_to_screen(point: Vector2) -> Vector2:
	var view_center := MAP_VIEW.get_center()
	return view_center + (point - camera_offset - view_center) * zoom_level

func _screen_to_world(point: Vector2) -> Vector2:
	var view_center := MAP_VIEW.get_center()
	return camera_offset + view_center + (point - view_center) / zoom_level

func _set_zoom(value: float, focus: Vector2) -> void:
	var world_focus := _screen_to_world(focus)
	zoom_level = clampf(value, 0.75, 2.25)
	var view_center := MAP_VIEW.get_center()
	camera_offset = world_focus - view_center - (focus - view_center) / zoom_level
	_clamp_camera_offset()
	_sync_hominin_models()
	_position_wildlife_models()
	queue_redraw()
	_refresh_action_label()

func _world_tile_visible(point: Vector2) -> bool:
	return visible_tiles.has(_tile_id(_tile_from_world(point)))
func _draw_world() -> void:
	draw_rect(Rect2(0, 0, W, H), Color("#182826"))
	for y in range(0, 900, 64):
		var alpha := 0.025 if y % 128 == 0 else 0.012
		draw_line(Vector2(0, y), Vector2(W, y), Color(0.8, 0.76, 0.63, alpha), 1)

func _tile_center(x: int, y: int) -> Vector2:
	return MAP_ORIGIN + Vector2((x - y) * TILE_W / 2.0, (x + y) * TILE_H / 2.0)


func _river_center(y: float) -> float:
	return 12.0 + sin((y - 10.0) * 0.32) * 1.55 + sin((y - 10.0) * 0.61) * 0.35

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

func _terrain_at(tile: Vector2i) -> String:
	if not Rect2i(0, 0, WORLD_WIDTH, WORLD_HEIGHT).has_point(tile):
		return ""
	return terrain_tiles[_tile_id(tile)]

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
		var shore: Dictionary = shoreline_tiles[id]
		shore["texture"] = _make_shoreline_texture(tile)
		_cache_shoreline_ripples(tile, shore)

func _river_half_width(y: float) -> float:
	return smoothstep(RIVER_SOURCE_Y, RIVER_SOURCE_Y + 1.0, y) * (RIVER_HALF_WIDTH + sin(y * 0.91) * 0.06)

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
					points.append(_project_tile_offset(offset))
				var id := _tile_id(tile)
				if not shoreline_tiles.has(id):
					shoreline_tiles[id] = {"bank": [], "water": [], "ripples": []}
				var shore: Dictionary = shoreline_tiles[id]
				shore["water" if waterline else "bank"].append(points)

func _make_shoreline_texture(tile: Vector2i) -> ImageTexture:
	var width := int(TILE_W)
	var height := int(TILE_H)
	var raster := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	var near_lake := absf(tile.x - LAKE_CENTER.x) <= LAKE_RADII.x + 1.5
	var shore_depth := 0.48 if near_lake else 0.22
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
			raster.set_pixel(x, y, _shoreline_color(distance, shore_depth))
	return ImageTexture.create_from_image(raster)

func _shoreline_color(distance: float, depth: float) -> Color:
	if distance <= 0.0:
		return SHORE_COLOR.lerp(SHORE_DEEP, smoothstep(0.0, depth, -distance))
	var bank := SHORE_COLOR.lerp(SHORE_SAND, smoothstep(0.0, SHORE_BANK_MARGIN * 0.65, distance))
	bank.a = 1.0 - smoothstep(0.0, SHORE_BANK_MARGIN, distance)
	return bank

func _cache_shoreline_ripples(tile: Vector2i, shore: Dictionary) -> void:
	for i in range(6):
		var y := lerpf(-15.0, 15.0, _tile_noise(tile.x, tile.y, i + 51))
		var half_width := TILE_W * 0.5 * (1.0 - absf(y) / (TILE_H * 0.5))
		var x := lerpf(-half_width, half_width * 0.6, _tile_noise(tile.x, tile.y, i + 71))
		var ripple := PackedVector2Array([Vector2(x, y), Vector2(x + 12.0, y)])
		for water in shore["water"]:
			shore["ripples"].append_array(Geometry2D.intersect_polyline_with_polygon(ripple, water))

func _land_position(position: Vector2) -> bool:
	var tile := _tile_from_world(position)
	if _terrain_at(tile) in ["river", "lake"]:
		return false
	var shore: Dictionary = shoreline_tiles.get(_tile_id(tile), {})
	var offset := position - _tile_center(tile.x, tile.y)
	for water in shore.get("water", []):
		if Geometry2D.is_point_in_polygon(offset, water):
			return false
	return true

func _land_segment_clear(from: Vector2, to: Vector2) -> bool:
	if not _land_position(to):
		return false
	var first := _tile_from_world(from)
	var last := _tile_from_world(to)
	for y in range(mini(first.y, last.y), maxi(first.y, last.y) + 1):
		for x in range(mini(first.x, last.x), maxi(first.x, last.x) + 1):
			var shore: Dictionary = shoreline_tiles.get(_tile_id(Vector2i(x, y)), {})
			if shore.is_empty():
				continue
			var center := _tile_center(x, y)
			var segment := PackedVector2Array([from - center, to - center])
			for water in shore["water"]:
				if not Geometry2D.intersect_polyline_with_polygon(segment, water).is_empty():
					return false
	return true

func _build_land_routes() -> void:
	for y in range(WORLD_HEIGHT):
		for x in range(WORLD_WIDTH):
			var center := _tile_center(x, y)
			if _land_position(center):
				land_routes.add_point(_tile_id(Vector2i(x, y)), center)
	for y in range(WORLD_HEIGHT):
		for x in range(WORLD_WIDTH):
			var tile := Vector2i(x, y)
			var id := _tile_id(tile)
			if not land_routes.has_point(id):
				continue
			for step: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i(1, 1), Vector2i(-1, 1)]:
				var neighbor := tile + step
				if _terrain_at(neighbor).is_empty() or not land_routes.has_point(_tile_id(neighbor)):
					continue
				if step.x != 0 and step.y != 0:
					# A diagonal must leave room on both sides of the shared corner.
					if not land_routes.has_point(_tile_id(tile + Vector2i(step.x, 0))) or not land_routes.has_point(_tile_id(tile + Vector2i(0, step.y))):
						continue
				if _land_segment_clear(_tile_center(x, y), _tile_center(neighbor.x, neighbor.y)):
					land_routes.connect_points(id, _tile_id(neighbor))

func _nearest_land_tile(tile: Vector2i) -> Vector2i:
	if land_routes.has_point(_tile_id(tile)):
		return tile
	var id := land_routes.get_closest_point(_tile_center(tile.x, tile.y))
	return _tile_from_world(land_routes.get_point_position(id))

func _route_actor_to(actor: Dictionary, tile: Vector2i, direct := false) -> bool:
	var origin: Vector2 = actor["target"]
	var origin_id := _tile_id(_tile_from_world(origin))
	var destination_id := _tile_id(tile)
	if _terrain_at(tile).is_empty() or not land_routes.has_point(destination_id):
		return false
	var route: Array[Vector2] = []
	if direct:
		if not land_routes.are_points_connected(origin_id, destination_id):
			return false
		route.append(_tile_center(tile.x, tile.y))
	else:
		var path := land_routes.get_point_path(origin_id, destination_id)
		if path.is_empty():
			return false
		for i in range(1, path.size()):
			route.append(path[i])
	actor["route"] = route
	if actor["position"] == origin and not route.is_empty():
		actor["target"] = route.pop_front()
	return true

func _project_tile_offset(offset: Vector2) -> Vector2:
	return Vector2((offset.x - offset.y) * TILE_W, (offset.x + offset.y) * TILE_H) * 0.5

func _draw_map() -> void:
	var visible: Array[Vector2i] = []
	var extent := Vector2(TILE_W * 0.5, TILE_H * 0.5 + 72.0) * zoom_level
	var first := _screen_to_world(MAP_VIEW.position - extent) - MAP_ORIGIN
	var last := _screen_to_world(MAP_VIEW.end + extent) - MAP_ORIGIN
	var min_depth := maxi(0, ceili(first.y / (TILE_H * 0.5)))
	var max_depth := mini(WORLD_WIDTH + WORLD_HEIGHT - 2, floori(last.y / (TILE_H * 0.5)))
	var min_diagonal := first.x / (TILE_W * 0.5)
	var max_diagonal := last.x / (TILE_W * 0.5)

	# Paint every ground tile before its raised scenery, then draw scenery back to front.
	for depth in range(min_depth, max_depth + 1):
		var min_x := maxi(maxi(0, depth - WORLD_HEIGHT + 1), ceili((depth + min_diagonal) * 0.5))
		var max_x := mini(mini(depth, WORLD_WIDTH - 1), floori((depth + max_diagonal) * 0.5))
		for x in range(min_x, max_x + 1):
			var tile := Vector2i(x, depth - x)
			var center := _tile_center(tile.x, tile.y)
			if explored_tiles.has(_tile_id(tile)):
				visible.append(tile)
				_draw_terrain_ground(center, tile, _terrain_at(tile))
			else:
				_draw_unexplored_tile(center, tile.x, tile.y)
	for tile in visible:
		var center := _tile_center(tile.x, tile.y)
		_draw_exploration_frontier(center, tile)
		_draw_terrain_details(center, _terrain_at(tile), tile.x, tile.y)
	for tile in visible:
		var id := _tile_id(tile)
		if discovered_landmarks.has(id):
			var landmark := _landmark_for_tile(tile)
			_draw_landmark_icon(_tile_center(tile.x, tile.y), str(landmark["kind"]))

func _draw_unexplored_tile(center: Vector2, x: int, y: int) -> void:
	var corners := PackedVector2Array([
		center + Vector2(0, -TILE_H * 0.5),
		center + Vector2(TILE_W * 0.5, 0),
		center + Vector2(0, TILE_H * 0.5),
		center + Vector2(-TILE_W * 0.5, 0)
	])
	var shade := 0.012 if (x + y) % 2 == 0 else 0.025
	draw_colored_polygon(corners, Color("#0b1211").lightened(shade))
	var outline := corners.duplicate()
	outline.append(corners[0])
	draw_polyline(outline, Color("#38443f", 0.12), 0.7, true)

func _draw_terrain_ground(center: Vector2, tile: Vector2i, terrain: String) -> void:
	var color := Color("#a39b59")
	match terrain:
		"woodland": color = Color("#687d49")
		"wetland": color = Color("#829258")
		"dryland": color = Color("#b39662")
		"highland": color = Color("#817b58")
		"volcanic": color = Color("#8c7057")
		"river", "lake": color = Color("#93875a")
	var corners := PackedVector2Array()
	var colors := PackedColorArray()
	for vertex in TILE_VERTICES:
		corners.append(center + _project_tile_offset(vertex))
		var sample: Vector2 = Vector2(tile) + vertex
		var shade := terrain_noise.get_noise_2dv(sample) * 0.36
		colors.append(color.lightened(shade) if shade >= 0.0 else color.darkened(-shade))
	draw_polygon(corners, colors)
	var shore: Dictionary = shoreline_tiles.get(_tile_id(tile), {})
	if shore.is_empty():
		_draw_ground_texture(center, terrain, tile.x, tile.y)
		return

	draw_polygon(corners, PackedColorArray([Color.WHITE]), PackedVector2Array(SHORE_UVS), shore["texture"])
	for ripple in shore["ripples"]:
		draw_line(center + ripple[0], center + ripple[1], Color("#b3d7c5", 0.20), 0.8, true)

func _draw_terrain_details(center: Vector2, terrain: String, x: int, y: int) -> void:
	var id := _tile_id(Vector2i(x, y))
	if shoreline_tiles.has(id):
		_draw_shoreline_details(center, shoreline_tiles[id], x, y)
		return
	var variation := _tile_noise(x, y, 202)
	match terrain:
		"highland":
			_draw_mountain_tile(center, x, y, variation)
		"volcanic":
			_draw_volcanic_tile(center, variation)
		"dryland":
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(-21, 8), center + Vector2(-5, -8),
				center + Vector2(16, 5), center + Vector2(7, 13)
			]), Color("#b59a64", 0.5))
	_draw_tile_vegetation(center, terrain, x, y, variation)
	var detail := posmod(x * 37 + y * 19, 7)
	if terrain not in ["river", "lake"]:
		if detail == 0:
			_draw_flower(center + Vector2(-20, 8), Color("#d9a867"))
		elif detail == 1 or detail == 4:
			_draw_boulder(center + Vector2(18, 7), 0.65 + variation * 0.4)
		elif detail == 3:
			_draw_grass(center + Vector2(18, 7), Color("#857b4d", 0.8))
		elif detail == 5:
			draw_circle(center + Vector2(12, 6), 1.1, Color("#756b47", 0.55))
			draw_circle(center + Vector2(15, 8), 1.1, Color("#756b47", 0.55))
			draw_circle(center + Vector2(20, 4), 1.1, Color("#756b47", 0.55))
			draw_circle(center + Vector2(23, 6), 1.1, Color("#756b47", 0.55))
	if terrain == "lake" and detail == 0:
		draw_circle(center + Vector2(-17, 7), 2.0, Color("#a8b879", 0.85))
func _draw_shoreline_details(center: Vector2, shore: Dictionary, x: int, y: int) -> void:
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
		if bank and _tile_noise(x, y, i + 91) > 0.58:
			_draw_reeds(point)
		elif not bank:
			_draw_tall_grass(point, 0.58, Color("#9b9358"))
		else:
			draw_circle(point, 0.95, Color("#665c44", 0.65), true, -1.0, true)

func _draw_exploration_frontier(center: Vector2, tile: Vector2i) -> void:
	var top := center + Vector2(0, -TILE_H * 0.5)
	var right := center + Vector2(TILE_W * 0.5, 0)
	var bottom := center + Vector2(0, TILE_H * 0.5)
	var left := center + Vector2(-TILE_W * 0.5, 0)
	var edges := [
		{"neighbor": tile + Vector2i(0, -1), "from": top, "to": right},
		{"neighbor": tile + Vector2i(1, 0), "from": right, "to": bottom},
		{"neighbor": tile + Vector2i(0, 1), "from": bottom, "to": left},
		{"neighbor": tile + Vector2i(-1, 0), "from": left, "to": top}
	]
	for edge in edges:
		var neighbor: Vector2i = edge["neighbor"]
		if neighbor.x < 0 or neighbor.x >= WORLD_WIDTH or neighbor.y < 0 or neighbor.y >= WORLD_HEIGHT:
			continue
		if explored_tiles.has(_tile_id(neighbor)):
			continue
		draw_line(edge["from"], edge["to"], Color("#080d0c", 0.9), 4.0, true)
		draw_line(edge["from"], edge["to"], Color("#c8b77d", 0.34), 1.0, true)

func _draw_landmark_icon(center: Vector2, kind: String) -> void:
	var badge := center + Vector2(23, -8)
	draw_circle(badge, 8.0, Color("#24342d", 0.92))
	var tint := Color("#f1d393")
	match kind:
		"fossil":
			draw_line(badge + Vector2(-4, 0), badge + Vector2(4, 0), tint, 2.0, true)
			draw_circle(badge + Vector2(-4, 0), 2.2, tint)
			draw_circle(badge + Vector2(4, 0), 2.2, tint)
		"spring":
			draw_arc(badge + Vector2(0, 2), 4.0, PI, TAU, 12, Color("#9dd2c4"), 1.3, true)
			draw_arc(badge + Vector2(0, 3), 7.0, PI, TAU, 12, Color("#79b9b2"), 1.0, true)
		"obsidian":
			draw_colored_polygon(PackedVector2Array([
				badge + Vector2(-5, 3), badge + Vector2(-2, -5),
				badge + Vector2(3, -4), badge + Vector2(5, 3)
			]), Color("#536b70"))
			draw_line(badge + Vector2(-2, -3), badge + Vector2(2, 2), Color("#9eb4ac", 0.8), 1.0, true)
		"shelter":
			draw_colored_polygon(PackedVector2Array([
				badge + Vector2(-7, 3), badge + Vector2(-3, -5),
				badge + Vector2(6, -3), badge + Vector2(7, 3)
			]), Color("#a18a67"))
			draw_arc(badge + Vector2(0, 4), 3.5, PI, TAU, 12, Color("#28302a"), 2.0, true)
		"waterhole":
			draw_arc(badge + Vector2(0, 1), 6.0, 0, TAU, 16, Color("#9dd2c4"), 1.2, true)
			_draw_reeds(badge + Vector2(4, -3))

func _draw_flower(point: Vector2, color: Color) -> void:
	draw_line(point + Vector2(0, 3), point + Vector2(0, -2), Color("#667448"), 1.0, true)
	draw_circle(point + Vector2(-2, -3), 1.5, color.darkened(0.08))
	draw_circle(point + Vector2(2, -3), 1.5, color.lightened(0.08))
	draw_circle(point + Vector2(0, -4), 1.4, Color("#f0d38d"))

func _draw_boulder(point: Vector2, size: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		point + Vector2(-6 * size, 2 * size), point + Vector2(-4 * size, -3 * size),
		point + Vector2(1 * size, -5 * size), point + Vector2(6 * size, -2 * size),
		point + Vector2(5 * size, 3 * size)
	]), Color("#776f57"))
	draw_line(point + Vector2(-3 * size, -2 * size), point + Vector2(1 * size, -4 * size), Color("#b2a27a", 0.7), 1.0, true)

func _draw_reeds(point: Vector2) -> void:
	var reed := Color("#9ba36a", 0.8)
	draw_line(point, point + Vector2(-3, -10), reed, 1.2, true)
	draw_line(point + Vector2(2, 1), point + Vector2(3, -12), reed, 1.2, true)
	draw_line(point + Vector2(5, 2), point + Vector2(9, -7), reed, 1.2, true)
	draw_line(point + Vector2(-2, 1), point + Vector2(-7, -6), reed.darkened(0.12), 1.0, true)
	draw_circle(point + Vector2(3, -12), 1.2, Color("#6f5e3e"))
	draw_circle(point + Vector2(-3, -10), 1.0, Color("#796746"))

func _draw_tree(point: Vector2, size: float) -> void:
	var scale := 0.68 + size * 0.38
	draw_ellipse_shadow(point + Vector2(1, 5), Vector2(12, 3) * scale)
	draw_line(point + Vector2(0, 7 * scale), point + Vector2(0, -8 * scale), Color("#68563a"), 2.2 * scale, true)
	draw_line(point + Vector2(0, -5 * scale), point + Vector2(-7, -11) * scale, Color("#735f3e"), 1.4 * scale, true)
	draw_line(point + Vector2(1, -7 * scale), point + Vector2(8, -12) * scale, Color("#594a34"), 1.2 * scale, true)
	draw_colored_polygon(PackedVector2Array([
		point + Vector2(-12 * scale, -5 * scale), point + Vector2(-8 * scale, -13 * scale),
		point + Vector2(-2 * scale, -12 * scale), point + Vector2(3 * scale, -17 * scale),
		point + Vector2(12 * scale, -11 * scale), point + Vector2(10 * scale, -4 * scale),
		point + Vector2(3 * scale, -2 * scale), point + Vector2(-5 * scale, -3 * scale)
	]), Color("#435d3e").lightened(size * 0.12))
	draw_circle(point + Vector2(-5 * scale, -9 * scale), 5.0 * scale, Color("#435d3e").darkened(0.08))
	draw_circle(point + Vector2(3 * scale, -10 * scale), 6.0 * scale, Color("#435d3e").lightened(0.12))
	draw_circle(point + Vector2(0, -14 * scale), 4.0 * scale, Color("#526c46").lightened(size * 0.12))
	_draw_leaf_texture(point + Vector2(-5, -10) * scale, Vector2(5.5, 3.3) * scale, Color("#56704a"), 14)
	_draw_leaf_texture(point + Vector2(4, -10) * scale, Vector2(6.5, 4.5) * scale, Color("#607950"), 17)
	_draw_leaf_texture(point + Vector2(1, -14) * scale, Vector2(4.0, 3.2) * scale, Color("#6c8051"), 10)


func _draw_mountain_tile(center: Vector2, x: int, y: int, variation: float) -> void:
	var relief := terrain_noise.get_noise_2d(x - 9, y + 15)
	var height := 38.0 + relief * 15.0 + variation * 18.0
	var lean := lerpf(-6.0, 7.0, _tile_noise(x, y, 225))
	_draw_mountain_peak(center + Vector2(16, -6), 23.0, height * 0.72, -lean, x, y, 0)
	_draw_mountain_peak(center + Vector2(-9, 4), 32.0, height, lean, x, y, 1)
	if variation > 0.45:
		_draw_mountain_peak(center + Vector2(21, 12), 19.0, height * 0.57, lean * 0.5, x, y, 2)

func _draw_mountain_peak(base: Vector2, width: float, height: float, lean: float, x: int, y: int, peak_index: int) -> void:
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
		var depth := lerpf(0.42, 0.68, _tile_noise(x, y, salt + i))
		var shoulder := summit.lerp(feet[i], depth)
		shoulder.x += lerpf(-3.0, 3.0, _tile_noise(x, y, salt + 6 + i))
		shoulders.append(shoulder)

	for i in range(rock_colors.size()):
		var rock: Color = rock_colors[i]
		var left := shoulders[i]
		var right := shoulders[i + 1]
		draw_polygon(
			PackedVector2Array([summit, left, right]),
			PackedColorArray([rock.lightened(0.26), rock, rock.darkened(0.08)])
		)
		# Split each lower face to keep the ridges angular as they meet the scree.
		var foot_color := Color("#817b58").lerp(rock, 0.22)
		draw_polygon(
			PackedVector2Array([left, feet[i], right]),
			PackedColorArray([rock, foot_color, rock.darkened(0.11)])
		)
		draw_polygon(
			PackedVector2Array([right, feet[i], feet[i + 1]]),
			PackedColorArray([rock.darkened(0.11), foot_color, foot_color.darkened(0.08)])
		)
		for j in range(6):
			var grain := salt + 12 + i * 12 + j * 2
			var depth := lerpf(0.27, 0.94, _tile_noise(x, y, grain))
			var across := lerpf(0.15, 0.75, _tile_noise(x, y, grain + 1))
			var start := left.lerp(right, across)
			var end := feet[i].lerp(feet[i + 1], across)
			var point := summit.lerp(start, depth * 2.0) if depth < 0.5 else start.lerp(end, depth * 2.0 - 1.0)
			var ink := Color("#eee1c7", 0.42) if (i + j) % 3 == 0 else Color("#352f2b", 0.32)
			draw_line(point, point + Vector2(1.5, 2.0), ink, 0.85, true)

func _draw_volcanic_tile(center: Vector2, variation: float) -> void:
	var peak_height := 15.0 + variation * 8.0
	var peak := center + Vector2(-2, -peak_height)
	var distant_peak := center + Vector2(22, -peak_height * 0.58)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(2, 10), distant_peak, center + Vector2(34, 11)
	]), Color("#796952"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-30, 10), peak, center + Vector2(10, 11)
	]), Color("#96795e"))
	draw_colored_polygon(PackedVector2Array([
		peak, center + Vector2(25, 9), center + Vector2(10, 11)
	]), Color("#554d43"))
	draw_line(peak, center + Vector2(-8, 3), Color("#d4c6a1", 0.8), 1.5, true)
	draw_arc(center + Vector2(0, -peak_height + 4), 4.0, PI, TAU, 10, Color("#bd6848"), 1.6)

func _draw_grass(point: Vector2, color: Color) -> void:
	draw_line(point, point + Vector2(-3, -7), color, 1.0, true)
	draw_line(point + Vector2(2, 1), point + Vector2(5, -6), color, 1.0, true)
	draw_line(point + Vector2(6, 2), point + Vector2(9, -3), color, 1.0, true)

func _tile_noise(x: int, y: int, salt: int) -> float:
	return absf(sin(float(x * 127 + y * 311 + salt * 74) * 0.17317))

func _draw_ground_texture(center: Vector2, terrain: String, x: int, y: int) -> void:

	var texture_color := Color("#d1bc76", 0.24)
	if terrain == "woodland": texture_color = Color("#354b35", 0.32)
	elif terrain == "dryland": texture_color = Color("#765d38", 0.28)
	elif terrain in ["highland", "volcanic"]: texture_color = Color("#c3b58d", 0.18)
	for i in range(6):
		var local_y := -10.0 + _tile_noise(x, y, i + 2) * 20.0
		var half_width := 34.0 * (1.0 - absf(local_y) / 27.0)
		var local_x := (_tile_noise(x, y, i + 12) * 2.0 - 1.0) * half_width
		var mark := center + Vector2(local_x, local_y)
		if i % 3 == 0:
			draw_circle(mark, 1.0, texture_color)
		else:
			draw_line(mark, mark + Vector2(4.0 + float(i % 2) * 3.0, -1.0), texture_color, 0.8, true)

func _draw_tile_vegetation(center: Vector2, terrain: String, x: int, y: int, variation: float) -> void:
	match terrain:
		"woodland":
			for i in range(7):
				var point := _vegetation_point(center, x, y, i, 7)
				if i in [1, 4]:
					_draw_shrub(point + Vector2(0, 2), 0.65 + _tile_noise(x, y, i + 90) * 0.35, Color("#52683f"))
				elif i % 3 == 0:
					_draw_acacia(point, 0.72 + _tile_noise(x, y, i + 80) * 0.28, Color("#3d593b"))
				else:
					_draw_tree(point, _tile_noise(x, y, i + 70))
		"savanna":
			for i in range(5):
				var grass_point := _vegetation_point(center, x, y, i, 5)
				_draw_tall_grass(grass_point, 0.65 + _tile_noise(x, y, i + 30) * 0.5, Color("#c5ad63"))
			var grove := terrain_noise.get_noise_2d(x + 19, y - 11)
			var tree_count := 2 if grove > 0.18 else int(grove > -0.04)
			for i in range(tree_count):
				_draw_acacia(_vegetation_point(center, x, y, i + 6, tree_count + 7), 0.72 + _tile_noise(x, y, i + 60) * 0.28, Color("#50663d"))
		"dryland":
			for i in range(4):
				var dry_point := _vegetation_point(center, x, y, i, 4)
				if i % 2 == 0:
					_draw_shrub(dry_point, 0.55 + _tile_noise(x, y, i + 20) * 0.35, Color("#766c43"))
				else:
					_draw_tall_grass(dry_point, 0.65, Color("#8c7847"))
		"wetland":
			for i in range(3):
				_draw_reeds(_vegetation_point(center, x, y, i, 3))
			if variation > 0.8:
				_draw_palm(center + Vector2(18, 7), 0.78 + variation * 0.2)
		"highland":
			for i in range(3):
				var high_point := _vegetation_point(center, x, y, i, 3)
				_draw_shrub(high_point, 0.48 + variation * 0.25, Color("#626a4d"))
		"volcanic":
			if variation > 0.45:
				_draw_shrub(center + Vector2(-24, 9), 0.55, Color("#766a48"))

func _vegetation_point(center: Vector2, x: int, y: int, index: int, count: int) -> Vector2:
	var row := float(index + 1) / float(count + 1)
	var local_y := lerpf(-11.0, 12.0, row) + (_tile_noise(x, y, index + 100) - 0.5) * 4.0
	var half_width := 35.0 * (1.0 - absf(local_y) / 28.0)
	var local_x := (_tile_noise(x, y, index + 120) * 2.0 - 1.0) * half_width
	return center + Vector2(local_x, local_y)

func _draw_acacia(point: Vector2, scale: float, foliage: Color) -> void:
	draw_ellipse_shadow(point + Vector2(2, 4), Vector2(15, 3) * scale)
	draw_line(point + Vector2(0, 5) * scale, point + Vector2(1, -11) * scale, Color("#665035"), 2.2 * scale, true)
	draw_line(point + Vector2(1, -6) * scale, point + Vector2(-9, -13) * scale, Color("#665035"), 1.4 * scale, true)
	draw_line(point + Vector2(1, -7) * scale, point + Vector2(10, -14) * scale, Color("#59462f"), 1.4 * scale, true)
	draw_colored_polygon(PackedVector2Array([
		point + Vector2(-17, -12) * scale, point + Vector2(-12, -18) * scale,
		point + Vector2(-2, -19) * scale, point + Vector2(4, -22) * scale,
		point + Vector2(15, -18) * scale, point + Vector2(19, -12) * scale,
		point + Vector2(10, -9) * scale, point + Vector2(-10, -9) * scale
	]), foliage)
	draw_circle(point + Vector2(-8, -15) * scale, 5.2 * scale, foliage.darkened(0.08))
	draw_circle(point + Vector2(5, -16) * scale, 6.0 * scale, foliage.lightened(0.09))
	_draw_leaf_texture(point + Vector2(-10, -13) * scale, Vector2(6.0, 3.5) * scale, foliage, 13)
	_draw_leaf_texture(point + Vector2(-1, -16) * scale, Vector2(7.0, 3.1) * scale, foliage.lightened(0.07), 15)
	_draw_leaf_texture(point + Vector2(8, -17) * scale, Vector2(6.5, 3.5) * scale, foliage.lightened(0.13), 15)
	_draw_leaf_texture(point + Vector2(11, -12) * scale, Vector2(5.5, 2.1) * scale, foliage.darkened(0.07), 10)

func _draw_leaf_texture(center: Vector2, radii: Vector2, foliage: Color, count: int) -> void:
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
	draw_multiline_colors(segments, colors, 1.0, true)


func _draw_shrub(point: Vector2, scale: float, foliage: Color) -> void:
	draw_ellipse_shadow(point + Vector2(1, 2), Vector2(8, 2) * scale)
	for branch in range(3):
		var offset := float(branch - 1) * 3.0
		draw_line(point + Vector2(offset, 2) * scale, point + Vector2(offset * 1.6, -7 - branch % 2) * scale, Color("#65553b"), 1.0, true)
	draw_circle(point + Vector2(-5, -5) * scale, 4.5 * scale, foliage.darkened(0.08))
	draw_circle(point + Vector2(1, -7) * scale, 5.0 * scale, foliage)
	draw_circle(point + Vector2(6, -4) * scale, 4.0 * scale, foliage.lightened(0.1))
	draw_circle(point + Vector2(2, -9) * scale, 1.1 * scale, Color("#c8ad65", 0.8))

func _draw_tall_grass(point: Vector2, scale: float, color: Color) -> void:
	for blade in range(5):
		var root := point + Vector2(float(blade) * 2.0 - 4.0, float(blade % 2))
		var lean := float(blade - 2) * 1.4
		draw_line(root, root + Vector2(lean, (-7.0 - float(blade % 3)) * scale), color.lightened(float(blade) * 0.025), 0.9, true)

func _draw_palm(point: Vector2, scale: float) -> void:
	draw_ellipse_shadow(point + Vector2(3, 4), Vector2(12, 3) * scale)
	draw_line(point + Vector2(0, 5) * scale, point + Vector2(2, -17) * scale, Color("#7c6038"), 2.6 * scale, true)
	draw_line(point + Vector2(1, -5) * scale, point + Vector2(3, -16) * scale, Color("#b08a50", 0.75), 0.9, true)
	var crown := point + Vector2(2, -17) * scale
	for direction in [Vector2(-14,-4), Vector2(-11,3), Vector2(-4,-8), Vector2(7,-8), Vector2(14,-3), Vector2(11,4)]:
		var tip: Vector2 = crown + direction * scale
		draw_line(crown, tip, Color("#4f7047"), 2.0 * scale, true)
		var axis := (tip - crown).normalized()
		for leaflet in range(1, 6):
			var fraction := float(leaflet) / 6.0
			var stem := crown.lerp(tip, fraction)
			var spread := sin(fraction * PI) * 3.2 * scale
			var sweep := axis * spread * 0.58
			draw_line(stem, stem + sweep + axis.orthogonal() * spread, Color("#8a9b60"), 0.8, true)
			draw_line(stem, stem + sweep - axis.orthogonal() * spread, Color("#496a43"), 0.8, true)
	draw_circle(crown + Vector2(-2, 2) * scale, 2.0 * scale, Color("#705436"))
	draw_circle(crown + Vector2(2, 2) * scale, 2.0 * scale, Color("#705436"))

func _draw_player_marker() -> void:
	var center: Vector2 = player_actor["position"]
	if not MAP_VIEW.grow(70.0).has_point(_world_to_screen(center)):
		return
	var target: Vector2 = player_actor["target"]
	if center.distance_to(target) > 2.0:
		var trail := PackedVector2Array([center, target])
		for waypoint in player_actor["route"]:
			trail.append(waypoint)
		draw_polyline(trail, Color(0.9,0.72,0.42,0.55), 2.0, true)
		draw_arc(trail[-1], 10.0, 0, TAU, 20, Color("#f1cf92"), 1.6)
	var activity: String = player_actor["activity"]
	if activity != "idle":
		_draw_player_activity(center, activity)

func _draw_band_markers() -> void:
	var font := ThemeDB.fallback_font
	for band in ai_bands:
		if band["last_seen"] == null:
			continue
		var ground := _world_to_screen(band["last_seen"])
		var label: String = band["label"]
		var tint: Color = band["color"]
		if not band["on_charted_land"]:
			label += " · last seen"
			if MAP_VIEW.has_point(ground):
				draw_arc(ground, 7.0, 0.0, TAU, 16, tint, 1.4, true)
		var anchor := ground + Vector2(0, -55.0 * zoom_level)
		var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		var badge := Rect2(anchor - Vector2(size.x * 0.5 + 5.0, size.y), size + Vector2(10, 4))
		if not MAP_VIEW.encloses(badge):
			continue
		draw_rect(badge, Color("#172421", 0.9))
		draw_string(font, badge.position + Vector2(5.0, font.get_ascent(12) + 2.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tint.lightened(0.4))

func _draw_player_activity(center: Vector2, activity: String) -> void:
	var label := "MOVING"
	var color := Color("#d9c596")
	match activity:
		"gathering":
			label = "GATHERING"
			color = Color("#acd081")
			var patch := center + Vector2(-54, -6)
			draw_line(patch, patch + Vector2(0,-13), Color("#7d9b55"), 2.0, true)
			draw_circle(patch + Vector2(-4,-11), 3.0, Color("#d2a95e"))
			draw_circle(patch + Vector2(4,-12), 3.0, Color("#c8754e"))
		"learning":
			label = "LEARNING"
			color = Color("#f0c77f")
		"learning_at_hearth":
			label = "LEARNING"
			color = Color("#f0c77f")
			var fire := center + Vector2(-48, 8)
			draw_circle(fire, 8.0, Color(0.9,0.43,0.16,0.4))
			draw_colored_polygon(PackedVector2Array([
				fire + Vector2(-5,4), fire + Vector2(-2,-5),
				fire + Vector2(0,-1), fire + Vector2(3,-8),
				fire + Vector2(5,4)
			]), Color("#f0a24d"))
			draw_colored_polygon(PackedVector2Array([
				fire + Vector2(-2,4), fire + Vector2(0,-2),
				fire + Vector2(3,4)
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
			var nearest_position: Vector2 = ai_bands[0]["position"]
			for band in ai_bands:
				var band_position: Vector2 = band["position"]
				if center.distance_squared_to(band_position) < center.distance_squared_to(nearest_position):
					nearest_position = band_position
			draw_line(center + Vector2(0,-15), nearest_position + Vector2(0,-15), color, 3.0, true)
			draw_circle(nearest_position + Vector2(0,-15), 5.0, color)
			draw_arc(nearest_position + Vector2(0,-15), 34.0, 0, TAU, 32, color, 2.0, true)
	draw_rect(Rect2(center.x - 43, center.y - 101, 86, 18), Color("#1a2925"))
	draw_string(
		ThemeDB.fallback_font, center + Vector2(-41,-88), label,
		HORIZONTAL_ALIGNMENT_CENTER, 82, 10, color
	)

func draw_ellipse_shadow(center: Vector2, radius: Vector2, opacity := 0.22) -> void:
	var points := PackedVector2Array()
	for i in range(20):
		var angle := TAU * float(i) / 20.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, Color(0,0,0,opacity))


func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root)
	_panel(root, Rect2(0,0,W,70), Color("#172421"))
	_panel(root, Rect2(0,68,W,2), Color("#b99561"))
	_label(root, "DEEP TIME", Rect2(18,8,190,28), 20, Color("#e3c58d"), true)
	_label(root, "HOMININ PATHS  /  EAST AFRICA", Rect2(19,39,250,16), 8, Color("#93a29a"), true)
	age_label = _label(root, "3.2 Ma", Rect2(278,8,142,30), 22, Color("#f0e6d1"), true)
	period_label = _label(root, "THE LATE PLIOCENE", Rect2(280,42,190,15), 8, Color("#92a197"), true)
	species_label = _label(root, "", Rect2(470,9,260,48), 10, Color("#efe2ca"), true)
	stats_label = _label(root, "", Rect2(748,21,670,32), 11, Color("#e8dfce"), false)

	# One fixed chronicle is the only sidebar; the rest of the surface belongs to the map.
	_panel(root, Rect2(1190,70,250,830), Color("#172421"))
	_panel(root, Rect2(1190,70,2,830), Color("#b99561"))
	_label(root, "CAMPFIRE CHRONICLE", Rect2(1210,90,210,20), 10, Color("#b99561"), true)
	event_label = _label(root, "", Rect2(1210,126,210,730), 9, Color("#d4d2c6"), false)

	# Commands sit in a shallow strip over the bottom edge instead of occupying another panel.
	_panel(root, Rect2(0,830,1190,70), Color(0.07,0.12,0.11,0.96))
	_panel(root, Rect2(0,830,1190,2), Color("#b99561"))
	action_label = _label(root, "", Rect2(16,839,310,53), 9, Color("#e9e0ce"), false)
	forage_button = _button(root, "Forage", Rect2(340,841,124,46), Color("#3b554b"), _on_gather)
	scout_button = _button(root, "Scout", Rect2(474,841,112,46), Color("#3b554b"), _on_explore)
	learn_button = _button(root, "Learn −8", Rect2(596,841,112,46), Color("#3b554b"), _on_learn)
	kinship_button = _button(root, "Meet kin", Rect2(718,841,100,46), Color("#684d54"), _on_encounter)
	mate_button = _button(root, "Find mate", Rect2(828,841,96,46), Color("#684d54"), _on_mate)
	advance_button = _button(root, "PASS THE SEASON  ›", Rect2(934,841,238,46), Color("#b88d56"), _on_advance)
	toast_label = _label(root, "", Rect2(260,80,670,42), 12, Color("#f1d7a5"), true)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.hide()
	_refresh_ui()

func _panel(parent: Control, rect: Rect2, color: Color, border := Color(0,0,0,0)) -> ColorRect:
	var panel := ColorRect.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.color = color
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	if border.a > 0:
		var outline := ReferenceRect.new()
		outline.position = rect.position
		outline.size = rect.size
		outline.border_color = border
		outline.border_width = 1
		outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(outline)
	return panel

func _label(parent: Control, text: String, rect: Rect2, font_size: int, color: Color, bold: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", font_size + 4)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0,0,0,0.18))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Control, text: String, rect: Rect2, color: Color, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Color("#f1e8d6"))
	b.add_theme_color_override("font_hover_color", Color("#fff3d8"))
	b.add_theme_color_override("font_pressed_color", Color("#fff3d8"))
	b.add_theme_stylebox_override("normal", _style(color, Color("#657767")))
	b.add_theme_stylebox_override("hover", _style(color.lightened(0.13), Color("#bd9b68")))
	b.add_theme_stylebox_override("pressed", _style(color.darkened(0.15), Color("#d3b780")))
	b.add_theme_stylebox_override("disabled", _style(Color("#26332e"), Color("#43544b")))
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func _style(fill: Color, stroke: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = stroke
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.content_margin_left = 8
	s.content_margin_right = 8
	return s

func _season_name(season_turn: int) -> String:
	return "Dry" if season_turn % 2 == 1 else "Wet"

func _near_permanent_water(tile: Vector2i) -> bool:
	if tile in SPRING_TILES:
		return true
	if _terrain_at(tile) in ["river", "lake"]:
		return true
	for edge in TILE_EDGES:
		var neighbor: Vector2i = tile + edge
		if neighbor in SPRING_TILES or _terrain_at(neighbor) in ["river", "lake"]:
			return true
	return false

func _season_food_cost(tile: Vector2i, next_turn: int) -> int:
	if next_turn % 2 == 0:
		return WET_SEASON_FOOD_COST
	return DRY_SEASON_WATER_FOOD_COST if _near_permanent_water(tile) else DRY_SEASON_FOOD_COST

func _on_advance() -> void:
	if turn >= CHRONICLE_TURNS or player_actor["position"] != player_actor["target"]:
		return
	var tile := _tile_from_world(player_actor["position"])
	var food_cost := _season_food_cost(tile, turn + 1)
	turn += 1
	season_action_used = false
	year_bp = max(0, year_bp - 100)
	food = maxi(0, food - food_cost)
	cohesion = clampi(cohesion + (2 if food > 25 else -3), 0, 100)
	if turn == 1: _event("Dry season tests your range. Tracks lead toward a river.")
	if turn == 2: _event("Stone flakes outlast the meal. A new way of making tools spreads.")
	if turn == 3: _event("A distant band follows the water north. The family tree branches.")
	if turn == 8 and not discovered.has(1):
		discovered.append(1)
		_event("Paranthropus boisei appears beside Homo habilis: a robust-jawed cousin, not a direct ancestor.")
	if turn == 8 and not discovered.has(2):
		discovered.append(2)
		_event("Homo habilis appears in the Rift Valley. Stone tools become part of the story.")
	if turn == 13 and not discovered.has(3):
		discovered.append(3)
		_event("Homo erectus emerges. Longer legs carry one human lineage beyond Africa.")
	if year_bp == POSSIBLE_FIRE_USE_KA:
		_event("POSSIBLE EARLY FIRE USE  /  Early humans may have used fire around this time. The evidence is uncertain.")
	if year_bp == HEARTH_KEEPING_KA:
		_event("HEARTH KEEPING  /  In the age of Homo erectus, you can now tend a hearth. Ash and burned bone at Wonderwerk Cave mark fire use around this time.")
	if turn == 25 and not discovered.has(4):
		discovered.append(4)
		_event("Homo heidelbergensis populations spread across continents; later branches include Neanderthals and Denisovans.")
	if turn == 28 and not discovered.has(5):
		discovered.append(5)
		_event("Neanderthals adapt to the colder north. Their path will cross ours far in the future.")
	if turn == 28 and not discovered.has(6):
		discovered.append(6)
		_event("Denisovan populations take shape in Asia. Deep time holds room for many human worlds.")
	if turn == 29 and not discovered.has(7):
		discovered.append(7)
		_event("Homo sapiens appears in Africa. Distinct human lineages now share a wider world.")
	if turn == 30:
		_event("Across Eurasia, human groups meet repeatedly. Shared ancestry carries between branches.")
	_complete_succession()
	if turn == CHRONICLE_TURNS: _event("The chronicle reaches the present. Many branches end; traces of kinship remain.")
	_check_hide_wrap_unlock()
	_refresh_ui()
	queue_redraw()
	_sync_wildlife()

func _season_action_blocker() -> String:
	if turn >= CHRONICLE_TURNS:
		return "The chronicle is complete."
	if season_action_used:
		return "You have acted. Pass the season to act again."
	if player_actor["position"] != player_actor["target"]:
		return "Wait until you reach your destination."
	return ""

func _unmapped_scout_tiles(tile: Vector2i) -> int:
	var count := 0
	for nearby in _tiles_in_radius(tile, SCOUT_RADIUS):
		if not explored_tiles.has(_tile_id(nearby)):
			count += 1
	return count

func _forage_food_gain(tile: Vector2i) -> int:
	var terrain := _terrain_at(tile)
	var yield_on_terrain: int = WET_FORAGE_YIELDS[terrain]
	if turn % 2 == 1:
		yield_on_terrain = DRY_SPRING_FORAGE if tile in SPRING_TILES else DRY_FORAGE_YIELDS[terrain]
	if yield_on_terrain > 0 and knowledge >= FORAGE_KNOWLEDGE_THRESHOLD:
		yield_on_terrain += FORAGE_KNOWLEDGE_BONUS
	return mini(yield_on_terrain, 100 - food)

func _on_gather() -> void:
	if not _season_action_blocker().is_empty():
		return
	var tile := _tile_from_world(player_actor["position"])
	var food_gain := _forage_food_gain(tile)
	if food_gain == 0:
		return
	var cohesion_gain := mini(2, 100 - cohesion)
	season_action_used = true
	_start_player_activity("gathering", 3.0)
	food += food_gain
	cohesion += cohesion_gain
	var site := "at the spring" if tile in SPRING_TILES else "in %s" % _terrain_at(tile)
	_event("You forage %s. Food +%d, cohesion +%d." % [site, food_gain, cohesion_gain])
	_refresh_ui()

func _on_explore() -> void:
	if not _season_action_blocker().is_empty():
		return
	var tile := _tile_from_world(player_actor["position"])
	var new_tiles := _unmapped_scout_tiles(tile)
	if new_tiles == 0:
		return
	season_action_used = true
	_start_player_activity("scouting", 3.0)
	_reveal_around(tile, SCOUT_RADIUS)
	_position_wildlife_models()
	var knowledge_gain := mini(9, 99 - knowledge)
	knowledge += knowledge_gain
	_event("You chart %d new tiles. Knowledge +%d." % [new_tiles, knowledge_gain])
	_check_hide_wrap_unlock()
	_refresh_ui()

func _on_learn() -> void:
	if not _season_action_blocker().is_empty() or food < 8 or knowledge >= 99:
		return
	season_action_used = true
	var at_hearth := year_bp <= HEARTH_KEEPING_KA
	_start_player_activity("learning_at_hearth" if at_hearth else "learning", 3.0)
	var knowledge_gain := mini(15, 99 - knowledge)
	food -= 8
	knowledge += knowledge_gain
	var practice := "You practice skills by the hearth." if at_hearth else "You practice skills."
	_event("%s Food −8, knowledge +%d." % [practice, knowledge_gain])
	_check_hide_wrap_unlock()
	_refresh_ui()

func _on_encounter() -> void:
	if not _season_action_blocker().is_empty() or not _kinship_blocker().is_empty():
		return
	season_action_used = true
	kinship_recorded = true
	_start_player_activity("meeting", 4.0)
	var cohesion_gain := mini(6, 100 - cohesion)
	food -= 5
	cohesion += cohesion_gain
	_event("NEANDERTHAL MEETING  /  Two human groups share a refuge. Food −5, cohesion +%d. Shared descendants recorded." % cohesion_gain)
	_refresh_ui()

func _kinship_blocker() -> String:
	if kinship_recorded:
		return "Kinship has already been recorded."
	if turn < 31:
		return "This encounter becomes available one season before the present."
	if food < 5:
		return "The encounter requires 5 food."
	return ""

func _has_nearby_mate() -> bool:
	var position: Vector2 = player_actor["position"]
	for i in range(ai_bands.size()):
		if _is_paranthropus_band(i):
			continue
		var band_position: Vector2 = ai_bands[i]["position"]
		if position.distance_squared_to(band_position) <= MATE_RANGE * MATE_RANGE and _world_tile_visible(band_position):
			if _land_segment_clear(position, band_position):
				return true
	return false

func _mating_blocker() -> String:
	if succession_turn >= 0:
		return "Succession in %d season(s)." % (succession_turn - turn)
	if turn + SUCCESSION_SEASONS > CHRONICLE_TURNS:
		return "There are too few seasons left for succession."
	if not _has_nearby_mate():
		return "Approach an eligible neighboring band to find a mate."
	if food < MATING_FOOD_COST:
		return "Pairing requires %d food." % MATING_FOOD_COST
	return ""

func _on_mate() -> void:
	if not _season_action_blocker().is_empty() or not _mating_blocker().is_empty():
		return
	season_action_used = true
	food -= MATING_FOOD_COST
	succession_turn = turn + SUCCESSION_SEASONS
	_start_player_activity("pairing", 3.0)
	_event("PAIRING  /  You form a pair with an adult from a neighboring band. Food −%d. Your offspring takes over in %d seasons." % [MATING_FOOD_COST, SUCCESSION_SEASONS])
	_refresh_ui()

func _complete_succession() -> void:
	if turn != succession_turn:
		return
	succession_turn = -1
	generation += 1
	var cohesion_gain := mini(SUCCESSION_COHESION, 100 - cohesion)
	cohesion += cohesion_gain
	_event("SUCCESSION  /  You continue as your grown offspring. Generation %d, cohesion +%d." % [generation, cohesion_gain])

func _check_hide_wrap_unlock() -> void:
	if hide_wrap_unlocked or turn < 24 or knowledge < 30: return
	hide_wrap_unlocked = true
	cohesion = mini(100, cohesion + 4)
	_event("HIDE-WRAP CRAFT  /  Hide working becomes a cultural advantage. Some later-generation adults wear simple wraps; cohesion +4.")

func _event(text: String) -> void:
	event_log.push_front(text)
	if event_log.size() > 6: event_log.resize(6)
	_show_toast(text)

func _show_toast(text: String) -> void:
	toast = text
	toast_timer = 4.2
	if is_instance_valid(toast_label):
		toast_label.text = text
		toast_label.show()

func _format_year(value: int) -> String:
	if value >= 1000: return "%.1f Ma" % (float(value) / 1000.0)
	return "%d ka" % value

func _period_name() -> String:
	if year_bp >= 2580: return "THE LATE PLIOCENE"
	if year_bp >= 774: return "THE EARLY PLEISTOCENE"
	if year_bp >= 129: return "THE MIDDLE PLEISTOCENE"
	if year_bp > 0: return "THE LATE PLEISTOCENE"
	return "THE PRESENT"

func _refresh_ui() -> void:
	if not is_instance_valid(stats_label): return
	age_label.text = _format_year(year_bp)
	period_label.text = _period_name()
	stats_label.text = "FOOD   %d   ◇       KNOWLEDGE   %d   ◇       COHESION   %d   ◇       GEN   %d   ◇       HOMININS   %d" % [food, knowledge, cohesion, generation, PLAYER_COUNT]
	var current := int(discovered[0])
	if turn >= 29: current = 7
	elif turn >= 25: current = 4
	elif turn >= 13: current = 3
	elif turn >= 8: current = 2
	var sp: Dictionary = SPECIES[current]
	species_label.text = str(sp.name) + "\n" + str(sp.trait)
	event_label.text = ""
	for i in range(mini(6, event_log.size())):
		event_label.text += "• " + event_log[i] + "\n\n"
	_refresh_action_label()

func _start_player_activity(activity: String, duration: float) -> void:
	movement_key = KEY_NONE
	player_actor["activity"] = activity
	player_actor["action_time"] = duration
	queue_redraw()

func _refresh_action_label() -> void:
	if not is_instance_valid(action_label):
		return
	var tile := _tile_from_world(player_actor["position"])
	var terrain := _terrain_at(tile)
	var status := "Action available"
	if turn >= CHRONICLE_TURNS:
		status = "Chronicle complete"
	elif season_action_used:
		status = "Action used"
	elif player_actor["position"] != player_actor["target"]:
		status = "Traveling"
	var location := "Spring" if tile in SPRING_TILES else terrain.capitalize()
	action_label.text = "%s season  ·  %s  ·  %s\nMove: click or WASD  ·  Pan: drag  ·  Zoom: wheel\nMapped: %d / %d" % [_season_name(turn), location, status, explored_tiles.size(), WORLD_WIDTH * WORLD_HEIGHT]
	_refresh_season_button(tile)

	var blocker := _season_action_blocker()
	var forage_yield := _forage_food_gain(tile)
	forage_button.text = "Forage +%d" % forage_yield
	forage_button.disabled = not blocker.is_empty() or forage_yield == 0
	forage_button.tooltip_text = blocker
	if blocker.is_empty():
		if food == 100:
			forage_button.tooltip_text = "Food stores are full."
		elif forage_yield == 0:
			forage_button.tooltip_text = "Find land to forage."
		else:
			forage_button.tooltip_text = "Gather %d food here and gain up to 2 cohesion." % forage_yield
			if knowledge >= FORAGE_KNOWLEDGE_THRESHOLD:
				forage_button.tooltip_text += " Includes up to %d extra food from knowledge." % FORAGE_KNOWLEDGE_BONUS

	var new_tiles := _unmapped_scout_tiles(tile) if blocker.is_empty() else 0
	scout_button.disabled = not blocker.is_empty() or new_tiles == 0
	scout_button.tooltip_text = blocker
	if blocker.is_empty():
		scout_button.tooltip_text = "Chart %d new tiles and gain up to 9 knowledge." % new_tiles if new_tiles > 0 else "Move closer to unmapped terrain to scout."

	learn_button.disabled = not blocker.is_empty() or food < 8 or knowledge >= 99
	learn_button.tooltip_text = blocker
	if blocker.is_empty():
		if knowledge >= 99:
			learn_button.tooltip_text = "Knowledge is at its maximum."
		elif food < 8:
			learn_button.tooltip_text = "Learning requires 8 food."
		else:
			learn_button.tooltip_text = "Spend 8 food to gain up to 15 knowledge."
			if knowledge < FORAGE_KNOWLEDGE_THRESHOLD:
				learn_button.tooltip_text += " At %d knowledge, forage yields rise by %d." % [FORAGE_KNOWLEDGE_THRESHOLD, FORAGE_KNOWLEDGE_BONUS]

	var kinship_blocker := _kinship_blocker()
	kinship_button.disabled = not blocker.is_empty() or not kinship_blocker.is_empty()
	kinship_button.tooltip_text = blocker if not blocker.is_empty() else kinship_blocker
	if kinship_button.tooltip_text.is_empty():
		kinship_button.tooltip_text = "Spend 5 food to record shared descendants and gain up to 6 cohesion."

	_refresh_mate_button(blocker)

func _refresh_mate_button(action_blocker: String) -> void:
	mate_button.text = "Heir in %d" % (succession_turn - turn) if succession_turn >= 0 else "Find mate"
	var blocker := action_blocker
	if succession_turn >= 0 or blocker.is_empty():
		blocker = _mating_blocker()
	mate_button.disabled = not blocker.is_empty()
	mate_button.tooltip_text = blocker if mate_button.disabled else "Spend %d food and this season's action. Continue as your offspring in %d seasons." % [MATING_FOOD_COST, SUCCESSION_SEASONS]

func _refresh_season_button(tile: Vector2i) -> void:
	var complete := turn >= CHRONICLE_TURNS
	var traveling: bool = player_actor["position"] != player_actor["target"]
	advance_button.disabled = complete or traveling
	if complete:
		advance_button.text = "CHRONICLE COMPLETE"
		advance_button.tooltip_text = ""
		return
	if traveling:
		advance_button.text = "TRAVELING"
		advance_button.tooltip_text = "Reach your destination to pass the season."
		return
	var next_turn := turn + 1
	var season := _season_name(next_turn)
	var cost := _season_food_cost(tile, next_turn)
	advance_button.text = "ENTER %s  ·  −%d FOOD  ›" % [season.to_upper(), cost]
	advance_button.tooltip_text = "Spend %d food here and open a new action in the %s season." % [cost, season.to_lower()]
	if next_turn % 2 == 1:
		advance_button.tooltip_text += " End next to a river, lake, or spring to pay %d food." % DRY_SEASON_WATER_FOOD_COST

func _set_player_destination(tile: Vector2i, announce := true, direct := false) -> void:
	if announce:
		movement_key = KEY_NONE
	if not _route_actor_to(player_actor, tile, direct):
		if announce:
			var id := _tile_id(tile)
			var message := "Pick a destination on land." if not land_routes.has_point(id) else "No land route leads there."
			_show_toast(message)
		return
	player_actor["activity"] = "walking"
	player_actor["action_time"] = 0.0
	_refresh_action_label()
	if announce:
		var location: String = map_names[(tile.x + tile.y * 2) % map_names.size()]
		_show_toast("You travel toward %s." % location)
	queue_redraw()

func _continue_keyboard_movement(delta: float) -> void:
	if movement_key == KEY_NONE:
		return
	if not Input.is_key_pressed(movement_key):
		movement_key = KEY_NONE
		return
	var position: Vector2 = player_actor["position"]
	var target: Vector2 = player_actor["target"]
	var braking_distance := PLAYER_SPEED * PLAYER_SPEED / (2.0 * TRAVEL_ACCELERATION)
	if player_actor["route"].is_empty() and position.distance_to(target) <= braking_distance + PLAYER_SPEED * delta:
		_set_player_destination(_tile_from_world(target) + keyboard_step, false, true)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if MAP_VIEW.has_point(event.position):
			var factor := 1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15
			_set_zoom(zoom_level * factor, event.position)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
		camera_dragging = event.pressed and MAP_VIEW.has_point(event.position)
		if camera_dragging or not event.pressed:
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and camera_dragging:
		camera_offset -= event.relative / zoom_level
		_clamp_camera_offset()
		_position_wildlife_models()
		_sync_hominin_models()
		queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_EQUAL, KEY_KP_ADD]:
			_set_zoom(zoom_level * 1.15, MAP_VIEW.get_center())
			get_viewport().set_input_as_handled()
			return
		if event.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
			_set_zoom(zoom_level / 1.15, MAP_VIEW.get_center())
			get_viewport().set_input_as_handled()
			return
		var step := Vector2i.ZERO
		# Pair isometric axes so keyboard input follows screen directions.
		if event.keycode == KEY_W or event.keycode == KEY_UP: step = Vector2i(-1,-1)
		elif event.keycode == KEY_S or event.keycode == KEY_DOWN: step = Vector2i(1,1)
		elif event.keycode == KEY_A or event.keycode == KEY_LEFT: step = Vector2i(-1,1)
		elif event.keycode == KEY_D or event.keycode == KEY_RIGHT: step = Vector2i(1,-1)
		if step != Vector2i.ZERO:
			movement_key = event.keycode
			keyboard_step = step
			var target: Vector2 = player_actor["target"]
			_set_player_destination(_tile_from_world(target) + step, false, true)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not MAP_VIEW.has_point(event.position):
			return
		var world_point := _screen_to_world(event.position)
		var tile := Vector2i(_map_coordinates(world_point).round())
		if Rect2i(0, 0, WORLD_WIDTH, WORLD_HEIGHT).has_point(tile):
			if _land_position(world_point):
				_set_player_destination(tile)
			else:
				movement_key = KEY_NONE
				_show_toast("Pick a destination on land.")
			get_viewport().set_input_as_handled()
