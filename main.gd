extends Node2D

const W := 1440.0
const H := 900.0
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
const DRY_SEASON_CARRY_WATER_FOOD_COST := 8
const LOW_FOOD_COHESION_PENALTY := -3
const WINDBREAKS_LOW_FOOD_COHESION_PENALTY := -1
const STARVATION_COHESION_PENALTY := -6
const MATING_FOOD_COST := 8
const MATE_RANGE := 76.0
const SUCCESSION_SEASONS := 2
const SUCCESSION_COHESION := 8
const BASE_SCOUT_RADIUS := 4
const TRAIL_READING_SCOUT_RADIUS := 5
const BASE_TRAVEL_RANGE := 7
const TRAIL_READING_TRAVEL_BONUS := 2
const ERECTUS_TRAVEL_BONUS := 3
const BASE_PRACTICE_FOOD_COST := 8
const HEARTH_PRACTICE_FOOD_COST := 4
const EMBER_PRACTICE_FOOD_COST := 6
const WET_WATERHOLE_FORAGE := 18
const WET_FORAGE_YIELDS := {
	"woodland": 18, "wetland": 22, "savanna": 13, "river": 0,
	"highland": 9, "dryland": 6, "volcanic": 6, "lake": 0
}
const DRY_FORAGE_YIELDS := {
	"woodland": 10, "wetland": 10, "savanna": 8, "river": 0,
	"highland": 6, "dryland": 4, "volcanic": 4, "lake": 0
}
const DRY_SPRING_FORAGE := 18
const MAP_VIEW := Rect2(0.0, 70.0, 1190.0, 760.0)
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

const WORLD_MAP_SCRIPT := preload("res://world_map.gd")
const MAP_RENDERER_SCRIPT := preload("res://map_renderer.gd")
const TECH_TREE_SCRIPT := preload("res://tech_tree.gd")
const HOMININ_MODEL_SCRIPT := preload("res://hominin_model.gd")
const WILDLIFE_MODEL_SCRIPT := preload("res://wildlife_model.gd")

var world: WORLD_MAP_SCRIPT = WORLD_MAP_SCRIPT.new()
var map_renderer: MAP_RENDERER_SCRIPT

var turn := 0
var generation := 1
var succession_turn := -1
var season_action_used := false
var kinship_recorded := false
var lineage_ended := false
var starvation_warned := false
var year_bp := 3200
var food := 68
var knowledge := 12
var cohesion := 57
var moves_remaining := BASE_TRAVEL_RANGE
var discovered: Array[int] = [0]
var learned_skills: Dictionary = {}
var discovered_landmark_names: Dictionary = {}
var depleted_tiles: Dictionary = {}
var event_log: Array[String] = ["The Rift Valley opens before your ancestors. Travel permanently charts the land.", "Afarensis bands learn the old paths."]
var map_names := ["Laetoli", "Olduvai", "Turkana", "Afar", "Awash", "Omo", "Tugen Hills", "Lomekwi"]
var toast := ""
var toast_timer := 0.0
var hide_wrap_unlocked := false
var bold_font: FontVariation
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
var skills_button: Button
var kinship_button: Button
var mate_button: Button
var advance_button: Button
var toast_label: Label
var skills_overlay: Control
var skills_header_label: Label
var skill_cards: Dictionary = {}
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


func _ready() -> void:
	world.setup()
	map_renderer = MAP_RENDERER_SCRIPT.new(world)
	player_actor = _make_actor(WORLD_MAP_SCRIPT.WORLD_START)
	player_actor["is_player"] = true
	ai_bands = [
		_make_ai_band("Western roamers", Vector2i(12, 15), [Vector2i(12, 15), Vector2i(7, 18), Vector2i(10, 21), Vector2i(15, 17), Vector2i(12, 15)], Color("#d78166"), 0.8),
		_make_ai_band("Northern roamers", Vector2i(21, 9), [Vector2i(21, 9), Vector2i(25, 4), Vector2i(29, 10), Vector2i(26, 17), Vector2i(21, 9)], Color("#7799b9"), 1.6),
		_make_ai_band("Eastern Spring camp", WORLD_MAP_SCRIPT.EASTERN_SPRING_TILE, [], Color("#a68cb4"), 0.0)
	]
	ai_rng.randomize()
	_build_hominin_viewport()
	_sync_hominin_models()
	_sync_wildlife()
	_build_ui()
	_reveal_around(WORLD_MAP_SCRIPT.WORLD_START, 2)
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
		var player_tile: Vector2i = world.tile_from_world(player_actor["position"])
		if player_tile != visibility_center:
			_reveal_around(player_tile, 2)
			_position_wildlife_models()
	var bands_moved := false
	var bands_need_redraw := false
	for band in ai_bands:
		var band_moved := _update_ai_band(band, delta)
		bands_moved = bands_moved or band_moved
		var presence_changed := _update_band_presence(band, delta)
		if (presence_changed or (band_moved and band["on_charted_land"])) and band["last_seen"] != null:
			if MAP_VIEW.grow(70.0 * zoom_level).has_point(_world_to_screen(band["last_seen"])):
				bands_need_redraw = true
	_check_band_encounters()
	if moved or bands_moved:
		_refresh_mate_button(_season_action_blocker())
	_sync_hominin_models(delta)
	if _update_wildlife(delta) or moved or bands_need_redraw:
		queue_redraw()
	if toast_timer > 0:
		toast_timer -= delta
		if toast_timer <= 0 and is_instance_valid(toast_label):
			toast_label.hide()
	var action_time := float(player_actor.get("action_time", 0.0))
	if action_time > 0.0:
		action_time = maxf(0.0, action_time - delta)
		player_actor["action_time"] = action_time
		if action_time == 0.0 and player_actor["activity"] not in ["idle", "walking"]:
			player_actor["activity"] = "idle"
			_refresh_action_label()
			queue_redraw()


func _reveal_around(center: Vector2i, radius: int) -> bool:
	if center == visibility_center and radius <= visibility_radius:
		return false
	visible_tiles.clear()
	visibility_center = center
	visibility_radius = radius
	for tile in world.tiles_in_radius(center, radius):
		var id: int = world.tile_id(tile)
		visible_tiles[id] = true
		if not explored_tiles.has(id):
			explored_tiles[id] = true
			_discover_landmark(tile)
	_refresh_action_label()
	queue_redraw()
	return true


func _discover_landmark(tile: Vector2i) -> void:
	var landmark: Dictionary = world.landmark_for_tile(tile)
	if landmark.is_empty():
		return
	var id: int = world.tile_id(tile)
	if discovered_landmarks.has(id):
		return
	discovered_landmarks[id] = true
	discovered_landmark_names[str(landmark["name"])] = true
	var rewards: Array[String] = []
	var food_gain := int(landmark["food"])
	var knowledge_gain := int(landmark["knowledge"])
	var cohesion_gain := int(landmark["cohesion"])
	food = mini(100, food + food_gain)
	knowledge = mini(99, knowledge + knowledge_gain)
	cohesion = mini(100, cohesion + cohesion_gain)
	if food_gain > 0:
		rewards.append("food +%d" % food_gain)
	if knowledge_gain > 0:
		rewards.append("knowledge +%d" % knowledge_gain)
	if cohesion_gain > 0:
		rewards.append("cohesion +%d" % cohesion_gain)
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
	var position: Vector2 = world.tile_center(tile.x, tile.y)
	return {
		"position": position, "target": position, "heading": Vector2(1, 0),
		"gait_phase": 0.0, "moving": false, "speed": PLAYER_SPEED, "travel_speed": 0.0,
		"activity": "idle", "action_time": 0.0, "is_player": false, "route": []
	}


func _make_ai_band(label: String, start: Vector2i, goals: Array, color: Color, pause: float) -> Dictionary:
	var actor := _make_actor(world.nearest_land_tile(start))
	actor["label"] = label
	actor["color"] = color
	actor["on_charted_land"] = false
	actor["last_seen"] = null
	var land_goals: Array[Vector2i] = []
	for goal in goals:
		land_goals.append(world.nearest_land_tile(goal))
	actor["goals"] = land_goals
	actor["goal_index"] = 0
	actor["pause"] = pause
	actor["speed"] = 39.0
	actor["opacity"] = 0.0
	return actor


func _route_actor_to(actor: Dictionary, tile: Vector2i, direct := false, max_steps := -1) -> bool:
	var origin: Vector2 = actor["target"]
	var result: Dictionary = world.find_route(origin, tile, direct)
	if not result["ok"]:
		return false
	var route: Array = result["route"]
	if max_steps >= 0:
		if max_steps == 0 or route.is_empty():
			return false
		if route.size() > max_steps:
			route.resize(max_steps)
	actor["route"] = route
	if actor["position"] == origin and not route.is_empty():
		actor["target"] = route.pop_front()
		if actor["is_player"]:
			moves_remaining = maxi(0, moves_remaining - 1)
	return true


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
		if actor["is_player"]:
			if moves_remaining <= 0:
				route.clear()
			else:
				actor["target"] = route.pop_front()
				moves_remaining = maxi(0, moves_remaining - 1)
				actor["moving"] = true
				_refresh_action_label()
				return true
		else:
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
	var mapped := explored_tiles.has(world.tile_id(world.tile_from_world(position)))
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
		if not live_position and actor["last_seen"] == null:
			continue
		var center: Vector2 = actor["position"] if live_position else actor["last_seen"]
		var ground := center + Vector2((person - 1) * 25, -3 + (person % 2) * 3)
		if not player_controlled:
			while not world.land_segment_clear(center, ground):
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
	var home: Vector2 = world.tile_center(WORLD_MAP_SCRIPT.WORLD_START.x, WORLD_MAP_SCRIPT.WORLD_START.y)
	var central: Vector2 = world.tile_center(23, 21)
	var eastern: Vector2 = world.tile_center(40, 29)
	var southern: Vector2 = world.tile_center(31, 36)
	match _wildlife_epoch():
		0:
			return [
				{"species":"Hipparion", "at":home + Vector2(-82, -58), "phase":0.2},
				{"species":"Sivatherium", "at":home + Vector2(80, -70), "phase":1.7},
				{"species":"Deinotherium", "at":home + Vector2(42, 90), "phase":3.1},
				{"species":"Dinofelis", "at":home + Vector2(-110, 25), "phase":4.3},
				{"species":"Hipparion", "at":central, "phase":1.1},
				{"species":"Sivatherium", "at":eastern, "phase":2.8},
				{"species":"Deinotherium", "at":southern, "phase":4.9}
			]
		1:
			return [
				{"species":"Hipparion", "at":home + Vector2(-82, -58), "phase":0.6},
				{"species":"Antelope", "at":home + Vector2(80, -70), "phase":2.0},
				{"species":"Deinotherium", "at":home + Vector2(42, 90), "phase":3.7},
				{"species":"Dinofelis", "at":home + Vector2(-110, 25), "phase":5.0},
				{"species":"Antelope", "at":central, "phase":1.4},
				{"species":"Hipparion", "at":eastern, "phase":3.1},
				{"species":"Dinofelis", "at":southern, "phase":4.2}
			]
		2:
			return [
				{"species":"Zebra", "at":home + Vector2(-82, -58), "phase":0.2},
				{"species":"Gazelle", "at":home + Vector2(80, -70), "phase":1.9},
				{"species":"Elephant", "at":home + Vector2(42, 90), "phase":3.3},
				{"species":"Lion", "at":home + Vector2(-110, 25), "phase":4.8},
				{"species":"Zebra", "at":central, "phase":0.9},
				{"species":"Gazelle", "at":eastern, "phase":2.4},
				{"species":"Elephant", "at":southern, "phase":3.9}
			]
		3:
			return [
				{"species":"Zebra", "at":home + Vector2(-82, -58), "phase":0.4},
				{"species":"Wildebeest", "at":home + Vector2(80, -70), "phase":2.1},
				{"species":"Elephant", "at":home + Vector2(42, 90), "phase":3.7},
				{"species":"Lion", "at":home + Vector2(-110, 25), "phase":5.2},
				{"species":"Wildebeest", "at":central, "phase":1.2},
				{"species":"Zebra", "at":eastern, "phase":2.9},
				{"species":"Lion", "at":southern, "phase":4.4}
			]
		_:
			return [
				{"species":"Giraffe", "at":home + Vector2(-82, -58), "phase":0.4},
				{"species":"Zebra", "at":home + Vector2(80, -70), "phase":2.1},
				{"species":"Elephant", "at":home + Vector2(42, 90), "phase":3.7},
				{"species":"Lion", "at":home + Vector2(-110, 25), "phase":5.2},
				{"species":"Giraffe", "at":central, "phase":1.5},
				{"species":"Zebra", "at":eastern, "phase":2.7},
				{"species":"Elephant", "at":southern, "phase":4.1}
			]


func _wildlife_profile(species_name: String) -> Dictionary:
	if species_name in ["Deinotherium", "Elephant"]:
		return {"size": Vector2(25, 7), "speed": 19.0, "roam_radius": 6, "pause_min": 3.0, "pause_max": 6.2}
	if species_name in ["Sivatherium", "Giraffe"]:
		return {"size": Vector2(20, 6), "speed": 23.0, "roam_radius": 7, "pause_min": 2.4, "pause_max": 5.0}
	if species_name in ["Dinofelis", "Lion"]:
		return {"size": Vector2(16, 5), "speed": 28.0, "roam_radius": 9, "pause_min": 1.8, "pause_max": 4.6}
	if species_name == "Wildebeest":
		return {"size": Vector2(17, 5), "speed": 25.0, "roam_radius": 8, "pause_min": 1.8, "pause_max": 4.2}
	return {"size": Vector2(17, 5), "speed": 31.0, "roam_radius": 8, "pause_min": 1.4, "pause_max": 3.8}


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
	var profile := _wildlife_profile(species_name)
	var position: Vector2 = entry["at"]
	var home_tile: Vector2i = world.nearest_land_tile(world.tile_from_world(position))
	if not world.land_position(position) or not world.has_land_route_point(world.tile_from_world(position)):
		position = world.tile_center(home_tile.x, home_tile.y)
	var heading := Vector2.from_angle(ai_rng.randf_range(0.0, TAU))
	var model := WILDLIFE_MODEL_SCRIPT.new()
	model.configure(species_name, float(entry["phase"]))
	model.set_motion(false, heading, 0.0)
	model.hide()
	hominin_stage.add_child(model)
	return {
		"at": position, "position": position, "target": position,
		"home_tile": home_tile, "heading": heading, "gait_phase": float(entry["phase"]),
		"moving": false, "speed": float(profile["speed"]), "travel_speed": 0.0,
		"is_player": false, "route": [],
		"pause": ai_rng.randf_range(0.4, 2.8),
		"pause_min": float(profile["pause_min"]), "pause_max": float(profile["pause_max"]),
		"roam_radius": int(profile["roam_radius"]),
		"size": profile["size"], "species": species_name,
		"model": model, "opacity": 0.0, "replacement": {}
	}


func _pick_wildlife_goal(animal: Dictionary) -> bool:
	var home_tile: Vector2i = animal["home_tile"]
	var current_tile: Vector2i = world.tile_from_world(animal["position"])
	var radius: int = int(animal["roam_radius"])
	var preferred: Array[Vector2i] = []
	var fallback: Array[Vector2i] = []
	for tile in world.tiles_in_radius(home_tile, radius):
		if tile == current_tile or tile.distance_squared_to(current_tile) < 4:
			continue
		if not world.has_land_route_point(tile):
			continue
		var terrain: String = world.terrain_at(tile)
		if terrain in ["highland", "volcanic"]:
			fallback.append(tile)
		else:
			preferred.append(tile)
	var pool: Array[Vector2i] = preferred if not preferred.is_empty() else fallback
	for _attempt in range(mini(8, pool.size())):
		var choice: Vector2i = pool[ai_rng.randi_range(0, pool.size() - 1)]
		if _route_actor_to(animal, choice):
			return true
	return false


func _update_wildlife_roaming(animal: Dictionary, delta: float) -> bool:
	if float(animal["pause"]) > 0.0:
		animal["pause"] = maxf(0.0, float(animal["pause"]) - delta)
		animal["moving"] = false
		return false
	var position: Vector2 = animal["position"]
	var target: Vector2 = animal["target"]
	if position == target and animal["route"].is_empty():
		animal["moving"] = false
		if _pick_wildlife_goal(animal):
			return true
		animal["pause"] = ai_rng.randf_range(float(animal["pause_min"]), float(animal["pause_max"]))
		return false
	var moved := _update_actor(animal, delta, float(animal["speed"]))
	animal["at"] = animal["position"]
	if not animal["moving"]:
		animal["pause"] = ai_rng.randf_range(float(animal["pause_min"]), float(animal["pause_max"]))
	return moved


func _update_wildlife(delta: float) -> bool:
	var changed := false
	for i in range(wildlife.size()):
		var animal := wildlife[i]
		var model = animal["model"]
		var replacement: Dictionary = animal["replacement"]
		var moved := _update_wildlife_roaming(animal, delta)
		var position: Vector2 = animal["at"]
		var on_screen := MAP_VIEW.grow(52.0 * zoom_level).has_point(_world_to_screen(position))
		var mapped := explored_tiles.has(world.tile_id(world.tile_from_world(position)))
		var opacity: float = animal["opacity"]
		if not replacement.is_empty() and (opacity <= 0.0 or not on_screen):
			model.hide()
			model.queue_free()
			wildlife[i] = _make_wildlife(replacement)
			_position_wildlife_model(wildlife[i])
			changed = true
			continue
		var target := 1.0 if mapped and replacement.is_empty() else 0.0
		var next := move_toward(opacity, target, delta / 0.65) if on_screen else target
		if next != opacity:
			animal["opacity"] = next
			model.set_opacity(next)
			changed = true
		if moved:
			_position_wildlife_model(animal)
			if next > 0.0 and on_screen:
				changed = true
		if next > 0.0:
			model.set_motion(animal["moving"], animal["heading"], delta)
	return changed


func _position_wildlife_model(animal: Dictionary) -> void:
	var screen := _world_to_screen(animal["at"])
	var local := screen - MAP_VIEW.position
	var model: Node3D = animal["model"]
	model.position = Vector3(local.x / 45.0, (MAP_VIEW.size.y - local.y) / 45.0, screen.y / MAP_VIEW.size.y * 0.02)
	model.scale = Vector3.ONE * 0.68 * zoom_level


func _position_wildlife_models() -> void:
	for animal in wildlife:
		_position_wildlife_model(animal)


func _wildlife_caption() -> String:
	var names: Array[String] = []
	for animal in wildlife:
		if animal["opacity"] > 0.1 and MAP_VIEW.has_point(_world_to_screen(animal["at"])):
			var species_name: String = animal["species"]
			if not names.has(species_name):
				names.append(species_name)
	if names.is_empty():
		return "LOCAL WILDLIFE  ·  no tracks in sight"
	return "LOCAL WILDLIFE  ·  " + " /  ".join(names)


func _draw() -> void:
	map_renderer.draw_world(self, W, H)
	draw_set_transform(_map_draw_origin(), 0.0, Vector2.ONE * zoom_level)
	map_renderer.draw_map(self, MAP_VIEW, zoom_level, _screen_to_world, explored_tiles, discovered_landmarks, turn % 2 == 1, depleted_tiles)
	map_renderer.draw_actor_shadows(self, MAP_VIEW, _world_to_screen, player_actor, ai_bands, wildlife)
	draw_set_transform(Vector2.ZERO)
	if is_instance_valid(hominin_viewport):
		draw_texture_rect(hominin_viewport.get_texture(), MAP_VIEW, false)
	draw_set_transform(_map_draw_origin(), 0.0, Vector2.ONE * zoom_level)
	map_renderer.draw_player_marker(self, MAP_VIEW, _world_to_screen, player_actor, ai_bands)
	draw_set_transform(Vector2.ZERO)
	map_renderer.draw_band_markers(self, MAP_VIEW, zoom_level, _world_to_screen, ai_bands)
	draw_string(ThemeDB.fallback_font, Vector2(18.0, 94.0), _wildlife_caption(), HORIZONTAL_ALIGNMENT_LEFT, 790.0, 12, Color("#f0dfb8"))


func _clamp_camera_offset() -> void:
	var view_center := MAP_VIEW.get_center()
	var world_min_x: float = world.tile_center(0, WORLD_MAP_SCRIPT.WORLD_HEIGHT - 1).x - WORLD_MAP_SCRIPT.TILE_W * 0.5
	var world_max_x: float = world.tile_center(WORLD_MAP_SCRIPT.WORLD_WIDTH - 1, 0).x + WORLD_MAP_SCRIPT.TILE_W * 0.5
	var world_min_y: float = world.tile_center(0, 0).y - WORLD_MAP_SCRIPT.TILE_H * 0.5
	var world_max_y: float = world.tile_center(WORLD_MAP_SCRIPT.WORLD_WIDTH - 1, WORLD_MAP_SCRIPT.WORLD_HEIGHT - 1).y + WORLD_MAP_SCRIPT.TILE_H * 0.5
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
	return visible_tiles.has(world.tile_id(world.tile_from_world(point)))


func _build_ui() -> void:
	bold_font = FontVariation.new()
	bold_font.base_font = ThemeDB.fallback_font
	bold_font.variation_embolden = 0.45

	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root)
	_panel(root, Rect2(0, 0, W, 70), Color("#172421"))
	_panel(root, Rect2(0, 68, W, 2), Color("#b99561"))
	_label(root, "DEEP TIME", Rect2(18, 8, 190, 28), 20, Color("#e3c58d"), true)
	_label(root, "HOMININ PATHS  /  EAST AFRICA", Rect2(19, 39, 250, 16), 8, Color("#93a29a"), true)
	age_label = _label(root, "3.2 Ma", Rect2(278, 8, 142, 30), 22, Color("#f0e6d1"), true)
	period_label = _label(root, "THE LATE PLIOCENE", Rect2(280, 42, 190, 15), 8, Color("#92a197"), true)
	species_label = _label(root, "", Rect2(470, 9, 260, 48), 10, Color("#efe2ca"), true)
	stats_label = _label(root, "", Rect2(748, 21, 670, 32), 11, Color("#e8dfce"), false)

	# One fixed chronicle is the only sidebar; the rest of the surface belongs to the map.
	_panel(root, Rect2(1190, 70, 250, 830), Color("#172421"))
	_panel(root, Rect2(1190, 70, 2, 830), Color("#b99561"))
	_label(root, "CAMPFIRE CHRONICLE", Rect2(1210, 90, 210, 20), 10, Color("#b99561"), true)
	event_label = _label(root, "", Rect2(1210, 126, 210, 730), 9, Color("#d4d2c6"), false)

	# Commands sit in a shallow strip over the bottom edge instead of occupying another panel.
	_panel(root, Rect2(0, 830, 1190, 70), Color(0.07, 0.12, 0.11, 0.96))
	_panel(root, Rect2(0, 830, 1190, 2), Color("#b99561"))
	action_label = _label(root, "", Rect2(14, 839, 264, 53), 8, Color("#e9e0ce"), false)
	forage_button = _button(root, "Forage", Rect2(284, 841, 118, 46), Color("#3b554b"), _on_gather)
	scout_button = _button(root, "Scout", Rect2(408, 841, 82, 46), Color("#3b554b"), _on_explore)
	learn_button = _button(root, "Practice −8", Rect2(496, 841, 112, 46), Color("#3b554b"), _on_learn)
	skills_button = _button(root, "Skills", Rect2(614, 841, 88, 46), Color("#465662"), _on_toggle_skills)
	kinship_button = _button(root, "Meet kin", Rect2(708, 841, 98, 46), Color("#684d54"), _on_encounter)
	mate_button = _button(root, "Find mate", Rect2(812, 841, 98, 46), Color("#684d54"), _on_mate)
	advance_button = _button(root, "PASS THE SEASON  ›", Rect2(920, 841, 256, 46), Color("#b88d56"), _on_advance)
	toast_label = _label(root, "", Rect2(260, 80, 670, 42), 12, Color("#f1d7a5"), true)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.hide()
	_build_skills_overlay(root)
	_refresh_ui()


func _build_skills_overlay(root: Control) -> void:
	skills_overlay = Control.new()
	skills_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skills_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	skills_overlay.hide()
	root.add_child(skills_overlay)

	var backdrop := ColorRect.new()
	backdrop.position = MAP_VIEW.position
	backdrop.size = MAP_VIEW.size
	backdrop.color = Color(0.04, 0.08, 0.08, 0.72)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	skills_overlay.add_child(backdrop)

	var box := Rect2(86, 108, 1018, 684)
	_panel(skills_overlay, box, Color("#15221f"), Color("#b99561"))
	_label(skills_overlay, "SKILLS  ·  HOMININ KNOWLEDGE", Rect2(box.position.x + 24, box.position.y + 16, 420, 28), 14, Color("#e3c58d"), true)
	skills_header_label = _label(skills_overlay, "", Rect2(box.position.x + 450, box.position.y + 18, 420, 24), 10, Color("#d9d1bf"), false)
	_button(skills_overlay, "Close", Rect2(box.end.x - 104, box.position.y + 14, 82, 32), Color("#4b5a53"), _on_toggle_skills)

	skill_cards.clear()
	for branch in range(3):
		var row_y := box.position.y + 64 + branch * 204
		_label(skills_overlay, TECH_TREE_SCRIPT.BRANCH_NAMES[branch], Rect2(box.position.x + 24, row_y, 320, 20), 9, Color("#b99561"), true)
		for tier in range(3):
			var card_x := box.position.x + 24 + tier * 328
			var card_y := row_y + 24
			if tier > 0:
				_label(skills_overlay, "→", Rect2(card_x - 22, card_y + 66, 20, 24), 14, Color("#b99561"), true)
			var skill: Dictionary = TECH_TREE_SCRIPT.SKILLS[branch * 3 + tier]
			var skill_id: String = skill["id"]
			var card_bg := _panel(skills_overlay, Rect2(card_x, card_y, 304, 166), Color("#1d2e29"), Color("#51665b"))
			var title := _label(skills_overlay, "%s  ·  %d K" % [skill["name"], int(skill["cost"])], Rect2(card_x + 12, card_y + 10, 280, 22), 10, Color("#f2e6cf"), true)
			var desc := _label(skills_overlay, skill["summary"], Rect2(card_x + 12, card_y + 36, 280, 62), 8, Color("#d4d0c2"), false)
			var req := _label(skills_overlay, "", Rect2(card_x + 12, card_y + 100, 280, 24), 7, Color("#c7a976"), false)
			var btn := _button(skills_overlay, "Learn skill", Rect2(card_x + 12, card_y + 126, 280, 30), Color("#3b554b"), _on_learn_skill.bind(skill_id))
			btn.add_theme_font_size_override("font_size", 14)
			skill_cards[skill_id] = {"bg": card_bg, "title": title, "desc": desc, "req": req, "button": btn}


func _panel(parent: Control, rect: Rect2, color: Color, border := Color(0, 0, 0, 0)) -> ColorRect:
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
	if bold and bold_font != null:
		label.add_theme_font_override("font", bold_font)
	label.add_theme_font_size_override("font_size", font_size + 4)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.18))
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


func _has_skill(skill_id: String) -> bool:
	return learned_skills.has(skill_id)


func _scout_radius() -> int:
	return TRAIL_READING_SCOUT_RADIUS if _has_skill("trail_reading") else BASE_SCOUT_RADIUS


func _max_travel_range() -> int:
	var limit := BASE_TRAVEL_RANGE
	if _has_skill("trail_reading"):
		limit += TRAIL_READING_TRAVEL_BONUS
	if turn >= 13:
		limit += ERECTUS_TRAVEL_BONUS
	return limit


func _practice_food_cost(tile: Vector2i) -> int:
	if _has_skill("hearth_keeping") and tile == WORLD_MAP_SCRIPT.SHELTERED_CLIFF_TILE:
		return HEARTH_PRACTICE_FOOD_COST
	if _has_skill("ember_carrying"):
		return EMBER_PRACTICE_FOOD_COST
	return BASE_PRACTICE_FOOD_COST


func _season_food_cost(tile: Vector2i, next_turn: int) -> int:
	if next_turn % 2 == 0:
		return WET_SEASON_FOOD_COST
	if world.near_permanent_water(tile):
		return DRY_SEASON_WATER_FOOD_COST
	return DRY_SEASON_CARRY_WATER_FOOD_COST if _has_skill("carry_water") else DRY_SEASON_FOOD_COST


func _tick_depleted_tiles(entering_wet: bool) -> void:
	var decay := 2 if entering_wet else 1
	var recovered: Array = []
	for id in depleted_tiles:
		var remaining := int(depleted_tiles[id]) - decay
		if remaining <= 0:
			recovered.append(id)
		else:
			depleted_tiles[id] = remaining
	for id in recovered:
		depleted_tiles.erase(id)


func _run_ended() -> bool:
	return lineage_ended or turn >= CHRONICLE_TURNS


func _on_advance() -> void:
	if _run_ended():
		get_tree().reload_current_scene()
		return
	if player_actor["position"] != player_actor["target"]:
		return
	var tile: Vector2i = world.tile_from_world(player_actor["position"])
	var next_turn := turn + 1
	var entering_dry := next_turn % 2 == 1
	var inland := not world.near_permanent_water(tile)
	var food_cost := _season_food_cost(tile, next_turn)
	turn = next_turn
	season_action_used = false
	moves_remaining = _max_travel_range()
	_tick_depleted_tiles(not entering_dry)
	year_bp = max(0, year_bp - 100)
	food = maxi(0, food - food_cost)
	var low_food_penalty := LOW_FOOD_COHESION_PENALTY
	if _has_skill("windbreaks") and (world.terrain_at(tile) == "highland" or tile == WORLD_MAP_SCRIPT.SHELTERED_CLIFF_TILE):
		low_food_penalty = WINDBREAKS_LOW_FOOD_COHESION_PENALTY
	var cohesion_delta := 2 if food > 25 else (low_food_penalty if food > 0 else STARVATION_COHESION_PENALTY)
	cohesion = clampi(cohesion + cohesion_delta, 0, 100)
	if entering_dry and inland and _has_skill("hide_working"):
		cohesion = clampi(cohesion + 2, 0, 100)
	if food > 0:
		starvation_warned = false
	if cohesion == 0:
		lineage_ended = true
		movement_key = KEY_NONE
		player_actor["route"] = []
		_event("LINEAGE LOST  /  Without enough food and cohesion, your band scatters across the Rift Valley.")
		_refresh_ui()
		queue_redraw()
		_sync_wildlife()
		return
	if food == 0 and not starvation_warned:
		starvation_warned = true
		_event("STORES EMPTY  /  Without food, cohesion drops rapidly (%d per season). Forage soon before your band scatters." % STARVATION_COHESION_PENALTY)
	if turn == 1:
		_event("Dry season tests your range. Tracks lead toward a river.")
	if turn == 2:
		_event("Stone flakes outlast the meal. A new way of making tools spreads.")
	if turn == 3:
		_event("A distant band follows the water north. The family tree branches.")
	if turn == 8 and not discovered.has(1):
		discovered.append(1)
		_event("Paranthropus boisei appears beside Homo habilis: a robust-jawed cousin, not a direct ancestor.")
	if turn == 8 and not discovered.has(2):
		discovered.append(2)
		_event("Homo habilis appears in the Rift Valley. Stone tools become part of the story.")
	if turn == 13 and not discovered.has(3):
		discovered.append(3)
		_event("Homo erectus emerges. Longer legs carry one human lineage beyond Africa (+3 seasonal travel range).")
	if year_bp == POSSIBLE_FIRE_USE_KA:
		_event("POSSIBLE EARLY FIRE USE  /  Early humans may have used fire around this time. The evidence is uncertain.")
	if year_bp == HEARTH_KEEPING_KA:
		_event("HEARTH KEEPING  /  In the age of Homo erectus, you can now learn to tend a hearth. Ash and burned bone at Wonderwerk Cave mark fire use around this time.")
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
	if turn == CHRONICLE_TURNS:
		_event("The chronicle reaches the present. Many branches end; traces of kinship remain.")
	_refresh_ui()
	queue_redraw()
	_sync_wildlife()


func _season_action_blocker() -> String:
	if lineage_ended:
		return "Your lineage has scattered. Start a new chronicle."
	if turn >= CHRONICLE_TURNS:
		return "The chronicle is complete."
	if season_action_used:
		return "You have acted. Pass the season to act again."
	if player_actor["position"] != player_actor["target"]:
		return "Wait until you reach your destination."
	return ""


func _unmapped_scout_tiles(tile: Vector2i) -> int:
	var count := 0
	for nearby in world.tiles_in_radius(tile, _scout_radius()):
		if not explored_tiles.has(world.tile_id(nearby)):
			count += 1
	return count


func _forage_food_gain(tile: Vector2i) -> int:
	var terrain: String = world.terrain_at(tile)
	if terrain.is_empty() or terrain in ["river", "lake"]:
		return 0
	if depleted_tiles.has(world.tile_id(tile)):
		return 0
	var is_dry := turn % 2 == 1
	var yield_on_terrain: int = WET_FORAGE_YIELDS.get(terrain, 0)
	if not is_dry and tile == WORLD_MAP_SCRIPT.SEASONAL_WATERHOLE_TILE:
		yield_on_terrain = maxi(yield_on_terrain, WET_WATERHOLE_FORAGE)
	elif is_dry:
		yield_on_terrain = DRY_SPRING_FORAGE if tile in WORLD_MAP_SCRIPT.SPRING_TILES else DRY_FORAGE_YIELDS.get(terrain, 0)
	if yield_on_terrain > 0:
		if not is_dry and _has_skill("plant_lore") and terrain in ["woodland", "wetland"]:
			yield_on_terrain += 4
		if is_dry and _has_skill("food_drying") and not world.near_permanent_water(tile):
			yield_on_terrain += 3
		if _has_skill("stone_flaking") and terrain in ["savanna", "dryland", "volcanic"]:
			yield_on_terrain += 4
	return mini(yield_on_terrain, 100 - food)


func _on_gather() -> void:
	if not _season_action_blocker().is_empty():
		return
	var tile: Vector2i = world.tile_from_world(player_actor["position"])
	var food_gain := _forage_food_gain(tile)
	if food_gain == 0:
		return
	var cohesion_gain := mini(2, 100 - cohesion)
	season_action_used = true
	depleted_tiles[world.tile_id(tile)] = 1 if tile in WORLD_MAP_SCRIPT.SPRING_TILES else 2
	_start_player_activity("gathering", 3.0)
	food += food_gain
	cohesion += cohesion_gain
	if food > 0:
		starvation_warned = false
	var site := "at the spring" if tile in WORLD_MAP_SCRIPT.SPRING_TILES else ("at the waterhole" if tile == WORLD_MAP_SCRIPT.SEASONAL_WATERHOLE_TILE else "in %s" % world.terrain_at(tile))
	_event("You forage %s. Food +%d, cohesion +%d." % [site, food_gain, cohesion_gain])
	_refresh_ui()
	queue_redraw()


func _on_explore() -> void:
	if not _season_action_blocker().is_empty():
		return
	var tile: Vector2i = world.tile_from_world(player_actor["position"])
	var new_tiles := _unmapped_scout_tiles(tile)
	if new_tiles == 0:
		return
	season_action_used = true
	_start_player_activity("scouting", 3.0)
	_reveal_around(tile, _scout_radius())
	_position_wildlife_models()
	var knowledge_gain := mini(9, 99 - knowledge)
	knowledge += knowledge_gain
	_event("You chart %d new tiles. Knowledge +%d." % [new_tiles, knowledge_gain])
	_refresh_ui()


func _on_learn() -> void:
	var tile: Vector2i = world.tile_from_world(player_actor["position"])
	var cost := _practice_food_cost(tile)
	if not _season_action_blocker().is_empty() or food < cost or knowledge >= 99:
		return
	season_action_used = true
	var at_hearth := _has_skill("ember_carrying") or (_has_skill("hearth_keeping") and tile == WORLD_MAP_SCRIPT.SHELTERED_CLIFF_TILE) or year_bp <= HEARTH_KEEPING_KA
	_start_player_activity("learning_at_hearth" if at_hearth else "learning", 3.0)
	var knowledge_gain := mini(15, 99 - knowledge)
	food -= cost
	knowledge += knowledge_gain
	var practice := "You practice skills by the hearth." if at_hearth else "You practice skills."
	_event("%s Food −%d, knowledge +%d." % [practice, cost, knowledge_gain])
	_refresh_ui()


func _on_toggle_skills() -> void:
	if not is_instance_valid(skills_overlay):
		return
	skills_overlay.visible = not skills_overlay.visible
	if skills_overlay.visible:
		movement_key = KEY_NONE
		_refresh_skills_panel()


func _on_learn_skill(skill_id: String) -> void:
	var skill: Dictionary = TECH_TREE_SCRIPT.get_skill(skill_id)
	if skill.is_empty():
		return
	var blocker: String = TECH_TREE_SCRIPT.can_learn(skill, learned_skills, discovered_landmark_names, turn, knowledge, _season_action_blocker())
	if not blocker.is_empty():
		return
	season_action_used = true
	knowledge -= int(skill["cost"])
	learned_skills[skill_id] = true
	if skill_id == "hide_working":
		hide_wrap_unlocked = true
	elif skill_id == "trail_reading":
		moves_remaining += TRAIL_READING_TRAVEL_BONUS
	_start_player_activity("learning_at_hearth" if skill_id in ["hearth_keeping", "ember_carrying"] else "learning", 3.0)
	_event(str(skill["chronicle"]))
	_refresh_ui()
	_sync_hominin_models()
	queue_redraw()


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
			if world.land_segment_clear(position, band_position):
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


func _event(text: String) -> void:
	event_log.push_front(text)
	if event_log.size() > 6:
		event_log.resize(6)
	_show_toast(text)


func _show_toast(text: String) -> void:
	toast = text
	toast_timer = 4.2
	if is_instance_valid(toast_label):
		toast_label.text = text
		toast_label.show()


func _format_year(value: int) -> String:
	if value >= 1000:
		return "%.1f Ma" % (float(value) / 1000.0)
	return "%d ka" % value


func _period_name() -> String:
	if year_bp >= 2580: return "THE LATE PLIOCENE"
	if year_bp >= 774: return "THE EARLY PLEISTOCENE"
	if year_bp >= 129: return "THE MIDDLE PLEISTOCENE"
	if year_bp > 0: return "THE LATE PLEISTOCENE"
	return "THE PRESENT"


func _refresh_ui() -> void:
	if not is_instance_valid(stats_label):
		return
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
	var tile: Vector2i = world.tile_from_world(player_actor["position"])
	var terrain: String = world.terrain_at(tile)
	var status := "Action available"
	if lineage_ended:
		status = "Lineage lost"
	elif turn >= CHRONICLE_TURNS:
		status = "Chronicle complete"
	elif season_action_used:
		status = "Action used"
	elif player_actor["position"] != player_actor["target"]:
		status = "Traveling"
	var location := "Spring" if tile in WORLD_MAP_SCRIPT.SPRING_TILES else ("Waterhole" if tile == WORLD_MAP_SCRIPT.SEASONAL_WATERHOLE_TILE else terrain.capitalize())
	action_label.text = "%s  ·  %s  ·  %s\nRange: %d / %d tiles  ·  Mapped: %d / %d\nMove: click/WASD  ·  Pan: drag  ·  Zoom: wheel" % [_season_name(turn), location, status, moves_remaining, _max_travel_range(), explored_tiles.size(), WORLD_MAP_SCRIPT.WORLD_WIDTH * WORLD_MAP_SCRIPT.WORLD_HEIGHT]
	_refresh_season_button(tile)

	var blocker := _season_action_blocker()
	var tile_id: int = world.tile_id(tile)
	var forage_yield := _forage_food_gain(tile)
	forage_button.text = "Forage +%d" % forage_yield
	forage_button.disabled = not blocker.is_empty() or forage_yield == 0
	forage_button.tooltip_text = blocker
	if blocker.is_empty():
		if food == 100:
			forage_button.tooltip_text = "Food stores are full."
		elif depleted_tiles.has(tile_id):
			forage_button.tooltip_text = "Foraged recently — recovers in %d season(s)." % int(depleted_tiles[tile_id])
		elif forage_yield == 0:
			forage_button.tooltip_text = "Find land to forage."
		else:
			forage_button.tooltip_text = "Gather %d food here and gain up to 2 cohesion. Patch rests after foraging." % forage_yield

	var new_tiles := _unmapped_scout_tiles(tile) if blocker.is_empty() else 0
	scout_button.disabled = not blocker.is_empty() or new_tiles == 0
	scout_button.tooltip_text = blocker
	if blocker.is_empty():
		scout_button.tooltip_text = "Chart %d new tiles (radius %d) and gain up to 9 knowledge." % [new_tiles, _scout_radius()] if new_tiles > 0 else "Move closer to unmapped terrain to scout."

	var practice_cost := _practice_food_cost(tile)
	learn_button.text = "Practice −%d" % practice_cost
	learn_button.disabled = not blocker.is_empty() or food < practice_cost or knowledge >= 99
	learn_button.tooltip_text = blocker
	if blocker.is_empty():
		if knowledge >= 99:
			learn_button.tooltip_text = "Knowledge is at its maximum."
		elif food < practice_cost:
			learn_button.tooltip_text = "Practicing requires %d food here." % practice_cost
		else:
			learn_button.tooltip_text = "Spend %d food to gain up to 15 knowledge for Skills." % practice_cost

	var ready_skills := 0
	for skill in TECH_TREE_SCRIPT.SKILLS:
		if TECH_TREE_SCRIPT.can_learn(skill, learned_skills, discovered_landmark_names, turn, knowledge, blocker).is_empty():
			ready_skills += 1
	skills_button.text = "Skills %d/9" % learned_skills.size() if ready_skills == 0 else "Skills •%d" % ready_skills
	skills_button.tooltip_text = "Inspect or learn skills with unspent knowledge (%d available)." % knowledge
	if is_instance_valid(skills_overlay) and skills_overlay.visible:
		_refresh_skills_panel()

	var kinship_blocker := _kinship_blocker()
	kinship_button.disabled = not blocker.is_empty() or not kinship_blocker.is_empty()
	kinship_button.tooltip_text = blocker if not blocker.is_empty() else kinship_blocker
	if kinship_button.tooltip_text.is_empty():
		kinship_button.tooltip_text = "Spend 5 food to record shared descendants and gain up to 6 cohesion."

	_refresh_mate_button(blocker)


func _refresh_skills_panel() -> void:
	if not is_instance_valid(skills_header_label):
		return
	var blocker := _season_action_blocker()
	skills_header_label.text = "Unspent Knowledge: %d   ◇   Learned: %d / %d" % [knowledge, learned_skills.size(), TECH_TREE_SCRIPT.SKILLS.size()]
	for skill in TECH_TREE_SCRIPT.SKILLS:
		var skill_id: String = skill["id"]
		var card: Dictionary = skill_cards[skill_id]
		var bg: ColorRect = card["bg"]
		var req_label: Label = card["req"]
		var btn: Button = card["button"]
		if _has_skill(skill_id):
			bg.color = Color("#243d34")
			req_label.text = "Learned"
			req_label.add_theme_color_override("font_color", Color("#9fd4a7"))
			btn.text = "Learned"
			btn.disabled = true
			btn.tooltip_text = "Active for the rest of this chronicle."
			continue
		var missing: Array[String] = TECH_TREE_SCRIPT.unmet_requirements(skill, learned_skills, discovered_landmark_names, turn)
		var learn_blocker: String = TECH_TREE_SCRIPT.can_learn(skill, learned_skills, discovered_landmark_names, turn, knowledge, blocker)
		if missing.is_empty():
			bg.color = Color("#1f332c") if learn_blocker.is_empty() else Color("#1d2e29")
			req_label.text = "Ready to learn" if knowledge >= int(skill["cost"]) else "Need %d knowledge" % int(skill["cost"])
			req_label.add_theme_color_override("font_color", Color("#e8c882") if knowledge >= int(skill["cost"]) else Color("#a7b3a8"))
		else:
			bg.color = Color("#182522")
			req_label.text = " · ".join(missing)
			req_label.add_theme_color_override("font_color", Color("#c79b70"))
		btn.text = "Learn (−%d K)" % int(skill["cost"])
		btn.disabled = not learn_blocker.is_empty()
		btn.tooltip_text = learn_blocker if btn.disabled else "Spend %d knowledge and this season's action to learn %s." % [int(skill["cost"]), skill["name"]]


func _refresh_mate_button(action_blocker: String) -> void:
	mate_button.text = "Heir in %d" % (succession_turn - turn) if succession_turn >= 0 else "Find mate"
	var blocker := action_blocker
	if not _run_ended() and (succession_turn >= 0 or blocker.is_empty()):
		blocker = _mating_blocker()
	mate_button.disabled = not blocker.is_empty()
	mate_button.tooltip_text = blocker if mate_button.disabled else "Spend %d food and this season's action. Continue as your offspring in %d seasons." % [MATING_FOOD_COST, SUCCESSION_SEASONS]


func _refresh_season_button(tile: Vector2i) -> void:
	if lineage_ended:
		advance_button.disabled = false
		advance_button.text = "NEW CHRONICLE  ›"
		advance_button.tooltip_text = "Your band scattered. Begin a new chronicle from 3.2 Ma."
		return
	var complete := turn >= CHRONICLE_TURNS
	if complete:
		advance_button.disabled = false
		advance_button.text = "NEW CHRONICLE  ›"
		advance_button.tooltip_text = "The chronicle is complete. Begin a new run from 3.2 Ma."
		return
	var traveling: bool = player_actor["position"] != player_actor["target"]
	advance_button.disabled = traveling
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
	if _run_ended():
		return
	if announce:
		movement_key = KEY_NONE
	if moves_remaining <= 0:
		if announce:
			_show_toast("Travel range spent for this season. Pass the season to rest.")
		return
	if not _route_actor_to(player_actor, tile, direct, moves_remaining):
		if announce:
			var message := "Pick a destination on land." if not world.has_land_route_point(tile) else "No land route leads there."
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
	if movement_key == KEY_NONE or _run_ended():
		movement_key = KEY_NONE
		return
	if not Input.is_key_pressed(movement_key):
		movement_key = KEY_NONE
		return
	var position: Vector2 = player_actor["position"]
	var target: Vector2 = player_actor["target"]
	var braking_distance := PLAYER_SPEED * PLAYER_SPEED / (2.0 * TRAVEL_ACCELERATION)
	if player_actor["route"].is_empty() and position.distance_to(target) <= braking_distance + PLAYER_SPEED * delta:
		_set_player_destination(world.tile_from_world(target) + keyboard_step, false, true)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if is_instance_valid(skills_overlay) and skills_overlay.visible:
			_on_toggle_skills()
			get_viewport().set_input_as_handled()
		return
	if is_instance_valid(skills_overlay) and skills_overlay.visible:
		return
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
		if _run_ended():
			return
		var step := Vector2i.ZERO
		# Pair isometric axes so keyboard input follows screen directions.
		if event.keycode == KEY_W or event.keycode == KEY_UP: step = Vector2i(-1, -1)
		elif event.keycode == KEY_S or event.keycode == KEY_DOWN: step = Vector2i(1, 1)
		elif event.keycode == KEY_A or event.keycode == KEY_LEFT: step = Vector2i(-1, 1)
		elif event.keycode == KEY_D or event.keycode == KEY_RIGHT: step = Vector2i(1, -1)
		if step != Vector2i.ZERO:
			movement_key = event.keycode
			keyboard_step = step
			var target: Vector2 = player_actor["target"]
			_set_player_destination(world.tile_from_world(target) + step, false, true)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not MAP_VIEW.has_point(event.position) or _run_ended():
			return
		var world_point := _screen_to_world(event.position)
		var tile := Vector2i(world.map_coordinates(world_point).round())
		if Rect2i(0, 0, WORLD_MAP_SCRIPT.WORLD_WIDTH, WORLD_MAP_SCRIPT.WORLD_HEIGHT).has_point(tile):
			if world.land_position(world_point):
				_set_player_destination(tile)
			else:
				movement_key = KEY_NONE
				_show_toast("Pick a destination on land.")
			get_viewport().set_input_as_handled()
