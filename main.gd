extends Node2D


class LayerNode extends Node2D:
	var draw_cb: Callable
	var did_draw := false

	func _draw() -> void:
		did_draw = true
		if draw_cb.is_valid():
			draw_cb.call(self)


const W := 1440.0
const H := 900.0
const CHUNK_PX := 1024
const CHUNK_PAD := 2
const PLAYER_SPEED := 64.0
const TRAIL_READING_SPEED_BONUS := 12.0
const ERECTUS_SPEED_BONUS := 16.0
const AGING_SPEED_PENALTY := 8.0
const TRAVEL_ACCELERATION := 260.0
const PLAYER_COUNT := 1
const NEIGHBOR_BAND_SIZE := 3
const BAND_FADE_IN := 0.5
const BAND_FADE_OUT := 0.85
const CHRONICLE_TURNS := 32
const SEASON_DURATION := 28.0
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
const AGING_RANGE_PENALTY_AGE := 8
const AGING_COHESION_AGE := 10
const SHARE_CAMP_FOOD_COST := 4
const SHARE_CAMP_COOLDOWN := 4
const BASE_SCOUT_RADIUS := 4
const TRAIL_READING_SCOUT_RADIUS := 5
const BASE_PRACTICE_FOOD_COST := 8
const HEARTH_PRACTICE_FOOD_COST := 4
const EMBER_PRACTICE_FOOD_COST := 6
const TASK_FORAGE_DURATION := 2.2
const TASK_SCAVENGE_DURATION := 2.2
const TASK_HUNT_DURATION := 2.6
const TASK_SCOUT_DURATION := 2.4
const TASK_PRACTICE_DURATION := 3.2
const TASK_EMBER_DURATION := 2.4
const TASK_SHARE_DURATION := 2.4
const TASK_MATE_DURATION := 2.6
const TASK_KINSHIP_DURATION := 3.0
const WET_WATERHOLE_FORAGE := 18
const PREDATOR_DANGER_RANGE := 50.0
const PREDATOR_STALK_RANGE := 155.0
const PREDATOR_STALK_SPEED := 36.0
const PREDATOR_COOLDOWN_SECS := 8.0
const PREDATOR_RESPAWN_SEASONS := 3
const BAND_PURSUE_RANGE := 160.0
const BAND_PURSUE_SPEED := 46.0
const BAND_SKIRMISH_RANGE := 54.0
const BAND_SKIRMISH_COOLDOWN := 18.0
const WOUNDED_SPEED_PENALTY := 10.0
const TASK_FIGHT_DURATION := 1.8
const PICKUP_RANGE := 34.0
const MAX_COLLECTIBLES := 64
const HUNT_RANGE := 86.0
const SCAVENGE_BASE_FOOD := 14
const SCAVENGE_FLAKING_FOOD := 20
const HUNT_BASE_FOOD := 22
const HUNT_COOPERATIVE_FOOD := 24
const PREDATOR_SPECIES := ["Dinofelis", "Lion"]
const PREY_SPECIES := ["Hipparion", "Antelope", "Gazelle", "Zebra", "Wildebeest", "Sivatherium", "Giraffe"]
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
var season_elapsed := 0.0
var paused := false
var time_scale := 1.0
var generation := 1
var adult_age := 0
var aging_warned := false
var succession_turn := -1
var kinship_recorded := false
var lineage_ended := false
var starvation_warned := false
var year_bp := 3200
var food := 68
var food_f := 68.0
var knowledge := 12
var cohesion := 57
var active_task: Dictionary = {}
var discovered: Array[int] = [0]
var learned_skills: Dictionary = {}
var discovered_landmark_names: Dictionary = {}
var depleted_tiles: Dictionary = {}
var carcass_sites: Dictionary = {}
var wildfire_tiles: Dictionary = {}
var collectibles: Dictionary = {}
var pack: Dictionary = {"stone": 0, "gourd": 0, "tinder": 0}
var items_collected := 0
var floating_texts: Array[Dictionary] = []
var combat_flashes: Array[Dictionary] = []
var wounded_seasons := 0
var clashes_won := 0
var clashes_lost := 0
var predators_slain := 0
var carried_ember_seasons := 0
var wildlife_sighted: Dictionary = {}
var band_share_ready_turn: Dictionary = {}
var hunts_completed := 0
var scavenges_completed := 0
var band_shares_completed := 0
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
var season_bar_bg: ColorRect
var season_bar_fill: ColorRect
var season_bar_label: Label
var pause_button: Button
var speed_button: Button
var toast_label: Label
var skills_overlay: Control
var skills_header_label: Label
var skill_cards: Dictionary = {}
var summary_overlay: Control
var summary_title_label: Label
var summary_epithet_label: Label
var summary_body_label: Label
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
var map_root: Node2D
var map_chunks: Array[Dictionary] = []
var chunk_bounds: Array[Rect2] = []
var baking_chunks: Array[int] = []
var dynamic_world_layer: LayerNode
var overlay_layer: LayerNode
var ui_refresh_timer := 0.0
var viewport_3d_timer := 0.0
var pending_3d_frames := 0
var season_bar_timer := 0.0
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
	_build_map_layers()
	_sync_hominin_models()
	_sync_wildlife()
	_spawn_initial_collectibles()
	_build_ui()
	_reveal_around(WORLD_MAP_SCRIPT.WORLD_START, 2)
	_clamp_camera_offset()
	_sync_map_transform()
	_sync_hominin_models()
	_position_wildlife_models()
	queue_redraw()
	_redraw_dynamic()
	_check_band_encounters()
	if not RenderingServer.frame_post_draw.is_connected(_on_frame_post_draw):
		RenderingServer.frame_post_draw.connect(_on_frame_post_draw)


func _exit_tree() -> void:
	OS.low_processor_usage_mode = false
	if RenderingServer.frame_post_draw.is_connected(_on_frame_post_draw):
		RenderingServer.frame_post_draw.disconnect(_on_frame_post_draw)


func _on_frame_post_draw() -> void:
	_cleanup_baked_canvases()


func _is_sim_paused() -> bool:
	if paused or _run_ended():
		return true
	if is_instance_valid(skills_overlay) and skills_overlay.visible:
		return true
	if is_instance_valid(summary_overlay) and summary_overlay.visible:
		return true
	return false


func _player_speed() -> float:
	var speed := PLAYER_SPEED
	if _has_skill("trail_reading"):
		speed += TRAIL_READING_SPEED_BONUS
	if turn >= 13:
		speed += ERECTUS_SPEED_BONUS
	if adult_age >= AGING_RANGE_PENALTY_AGE:
		speed = maxf(44.0, speed - AGING_SPEED_PENALTY)
	if wounded_seasons > 0:
		speed = maxf(38.0, speed - WOUNDED_SPEED_PENALTY)
	return speed


func _set_food(value: float) -> void:
	food_f = clampf(value, 0.0, 100.0)
	food = int(floorf(food_f + 0.0001))


func _change_food(delta_amount: float) -> void:
	if absf(food_f - float(food)) >= 1.0:
		food_f = float(food)
	_set_food(food_f + delta_amount)


func _process(delta: float) -> void:
	if DisplayServer.get_name() == "headless":
		_cleanup_baked_canvases()
	if toast_timer > 0:
		toast_timer -= delta
		if toast_timer <= 0 and is_instance_valid(toast_label):
			toast_label.hide()
	var texts_changed := _update_floating_texts(delta)
	var flashes_changed := _update_combat_flashes(delta)
	var sim_paused := _is_sim_paused()
	OS.low_processor_usage_mode = sim_paused
	for animal in wildlife:
		var model: Node = animal["model"]
		if is_instance_valid(model):
			var want_process := not sim_paused
			if model.is_processing() != want_process:
				model.set_process(want_process)
	if sim_paused:
		if pending_3d_frames > 0:
			pending_3d_frames -= 1
		elif is_instance_valid(hominin_viewport) and hominin_viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED:
			hominin_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		if texts_changed or flashes_changed:
			_redraw_dynamic()
		return
	var sim_delta := delta * time_scale
	_continue_keyboard_movement(sim_delta)
	var moved := _update_actor(player_actor, sim_delta, _player_speed())
	var previous_camera_offset := camera_offset
	if moved and not camera_dragging:
		_follow_player_camera()
	if camera_offset != previous_camera_offset:
		_sync_map_transform()
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
		var band_moved := _update_ai_band(band, sim_delta)
		bands_moved = bands_moved or band_moved
		var presence_changed := _update_band_presence(band, sim_delta)
		if presence_changed or band_moved:
			if MAP_VIEW.grow(70.0 * zoom_level).has_point(_world_to_screen(band["position"])):
				bands_need_redraw = true
	_check_band_encounters()
	_check_band_skirmishes()
	_sync_hominin_models(sim_delta)
	var wildlife_changed := _update_wildlife(sim_delta)
	_check_predator_encounters()
	var picked_up := _check_collectible_pickups()
	var task_changed := _update_active_task(sim_delta)
	_advance_clock(sim_delta, delta)
	ui_refresh_timer += delta
	if picked_up or ((moved or bands_moved or wildlife_changed) and ui_refresh_timer >= 0.20):
		ui_refresh_timer = 0.0
		_refresh_action_label()
	viewport_3d_timer += delta
	var ambient_tick := viewport_3d_timer >= (1.0 / 30.0)
	if moved or ambient_tick:
		_request_3d_update()
	var immediate_redraw := moved or task_changed or texts_changed or flashes_changed or picked_up
	if immediate_redraw or ((wildlife_changed or bands_need_redraw) and ambient_tick):
		_redraw_dynamic()
	var action_time := float(player_actor.get("action_time", 0.0))
	if action_time > 0.0 and active_task.is_empty():
		action_time = maxf(0.0, action_time - sim_delta)
		player_actor["action_time"] = action_time
		if action_time == 0.0 and player_actor["activity"] not in ["idle", "walking"]:
			player_actor["activity"] = "idle"
			_refresh_action_label()
			_redraw_dynamic()


func _advance_clock(sim_delta: float, real_delta := 0.25) -> void:
	if _run_ended():
		return
	var tile: Vector2i = world.tile_from_world(player_actor["position"])
	var prev_food := food
	var season_cost := float(_season_food_cost(tile, turn))
	_change_food(-season_cost * (sim_delta / SEASON_DURATION))
	if food == 0 and not starvation_warned:
		starvation_warned = true
		_event("STORES EMPTY  /  Without food, cohesion will drop rapidly (%d) at season's end. Forage soon!" % STARVATION_COHESION_PENALTY)
	elif food > 0:
		starvation_warned = false
	if food != prev_food:
		_refresh_stats_bar()
		_refresh_action_label()
	season_elapsed += sim_delta
	if season_elapsed >= SEASON_DURATION:
		season_elapsed -= SEASON_DURATION
		season_bar_timer = 0.0
		_advance_season()
	else:
		season_bar_timer += real_delta
		if season_bar_timer >= 0.25:
			season_bar_timer = 0.0
			_refresh_season_bar(tile)


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
	_redraw_dynamic()
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
	_mark_chunk_dirty(tile)
	var rewards: Array[String] = []
	var food_gain := int(landmark["food"])
	var knowledge_gain := int(landmark["knowledge"])
	var cohesion_gain := int(landmark["cohesion"])
	_change_food(float(food_gain))
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
	actor["on_charted_land"] = true
	actor["last_seen"] = actor["position"]
	var land_goals: Array[Vector2i] = []
	for goal in goals:
		land_goals.append(world.nearest_land_tile(goal))
	actor["goals"] = land_goals
	actor["goal_index"] = 0
	actor["pause"] = pause
	actor["speed"] = 39.0
	actor["opacity"] = 1.0
	actor["attitude"] = "friendly"
	actor["skirmish_cooldown"] = 0.0
	actor["pursuing"] = false
	actor["repath_timer"] = 0.0
	return actor


func _route_actor_to(actor: Dictionary, tile: Vector2i, direct := false) -> bool:
	var origin: Vector2 = actor["target"]
	var result: Dictionary = world.find_route(origin, tile, direct)
	if not result["ok"]:
		return false
	var route: Array = result["route"]
	actor["route"] = route
	if actor["position"] == origin and not route.is_empty():
		actor["target"] = route.pop_front()
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
		actor["target"] = route.pop_front()
		actor["moving"] = true
		return true
	actor["moving"] = false
	actor["travel_speed"] = 0.0
	if actor["is_player"] and actor["activity"] == "walking":
		actor["activity"] = "idle"
		actor["action_time"] = 0.0
		_refresh_action_label()
		_redraw_dynamic()
	return distance > 0.0 or was_moving


func _update_ai_band(actor: Dictionary, delta: float) -> bool:
	if float(actor.get("skirmish_cooldown", 0.0)) > 0.0:
		actor["skirmish_cooldown"] = maxf(0.0, float(actor["skirmish_cooldown"]) - delta)
	var player_pos: Vector2 = player_actor["position"]
	var position: Vector2 = actor["position"]
	var hostile: bool = str(actor.get("attitude", "friendly")) == "hostile" and float(actor.get("skirmish_cooldown", 0.0)) <= 0.0 and not _run_ended()
	if hostile and position.distance_squared_to(player_pos) <= BAND_PURSUE_RANGE * BAND_PURSUE_RANGE:
		actor["pursuing"] = true
		actor["pause"] = 0.0
		actor["repath_timer"] = float(actor.get("repath_timer", 0.0)) - delta
		if float(actor["repath_timer"]) <= 0.0 or (position == actor["target"] and actor["route"].is_empty()):
			actor["repath_timer"] = 0.75
			_route_actor_to(actor, world.tile_from_world(player_pos))
		return _update_actor(actor, delta, BAND_PURSUE_SPEED)
	actor["pursuing"] = false
	var goals: Array = actor["goals"]
	if goals.is_empty():
		return false
	if float(actor["pause"]) > 0.0:
		actor["pause"] = maxf(0.0, float(actor["pause"]) - delta)
		actor["moving"] = false
		return false
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


func _update_band_presence(band: Dictionary, _delta: float) -> bool:
	band["on_charted_land"] = true
	band["last_seen"] = band["position"]
	if float(band["opacity"]) != 1.0:
		band["opacity"] = 1.0
		return true
	return false


func _build_hominin_viewport() -> void:
	hominin_viewport = SubViewport.new()
	hominin_viewport.name = "HomininRenderViewport"
	hominin_viewport.size = Vector2i(roundi(MAP_VIEW.size.x), roundi(MAP_VIEW.size.y))
	hominin_viewport.transparent_bg = true
	hominin_viewport.own_world_3d = true
	hominin_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	hominin_viewport.msaa_3d = Viewport.MSAA_DISABLED
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
	sun.shadow_enabled = false
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


func _request_3d_update() -> void:
	if is_instance_valid(hominin_viewport):
		hominin_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport_3d_timer = 0.0
	pending_3d_frames = 1


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
	var live_position: bool = player_controlled or actor["on_charted_land"]
	var has_pos := opacity > 0.0 and (live_position or actor["last_seen"] != null)
	var center: Vector2 = (actor["position"] if live_position else actor["last_seen"]) if has_pos else Vector2.ZERO
	var band_on_screen := has_pos and MAP_VIEW.grow(150.0 * zoom_level).has_point(_world_to_screen(center))
	for slot in range(model_count):
		var model_index := model_offset + slot
		var person := 1 if player_controlled else slot
		var wrapping := hide_wrap_unlocked and (person + band_index) % 2 == 0
		var variant := generation % 3 if player_controlled else person
		var signature := "%d:%d:%d:%s" % [current_stage, variant, int(robust), str(wrapping)]
		var model: Node3D
		if model_index >= hominin_models.size():
			model = HOMININ_MODEL_SCRIPT.new() as Node3D
			model.configure(current_stage, variant, robust, wrapping, group_color)
			model.set_meta("model_signature", signature)
			hominin_models.append(model)
			hominin_stage.add_child(model)
			_request_3d_update()
		else:
			model = hominin_models[model_index]
			if str(model.get_meta("model_signature", "")) != signature:
				model.queue_free()
				model = HOMININ_MODEL_SCRIPT.new() as Node3D
				model.configure(current_stage, variant, robust, wrapping, group_color)
				model.set_meta("model_signature", signature)
				hominin_models[model_index] = model
				hominin_stage.add_child(model)
				_request_3d_update()
		if not band_on_screen:
			model.visible = false
			continue
		model.set_opacity(opacity)
		var ground := center + Vector2((person - 1) * 25, -3 + (person % 2) * 3)
		if not player_controlled:
			while not world.land_segment_clear(center, ground):
				if ground.distance_squared_to(center) <= 1.0:
					ground = center
					break
				ground = center.lerp(ground, 0.5)
		var screen := _world_to_screen(ground)
		var on_screen := MAP_VIEW.grow(110.0 * zoom_level).has_point(screen)
		model.visible = on_screen and opacity > 0.0
		if not model.visible:
			continue
		var local := screen - MAP_VIEW.position
		model.position = Vector3(local.x / 45.0, (MAP_VIEW.size.y - local.y) / 45.0, screen.y / MAP_VIEW.size.y * 0.02)
		model.scale = Vector3.ONE * 0.55 * zoom_level
		if live_position:
			model.set_pose(actor["moving"], float(actor["gait_phase"]) + float(person) * TAU / 3.0, actor["heading"], delta)


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
				{"species":"Dinofelis", "at":home + Vector2(-155, 40), "phase":4.3},
				{"species":"Hipparion", "at":central, "phase":1.1},
				{"species":"Sivatherium", "at":eastern, "phase":2.8},
				{"species":"Deinotherium", "at":southern, "phase":4.9}
			]
		1:
			return [
				{"species":"Hipparion", "at":home + Vector2(-82, -58), "phase":0.6},
				{"species":"Antelope", "at":home + Vector2(80, -70), "phase":2.0},
				{"species":"Deinotherium", "at":home + Vector2(42, 90), "phase":3.7},
				{"species":"Dinofelis", "at":home + Vector2(-155, 40), "phase":5.0},
				{"species":"Antelope", "at":central, "phase":1.4},
				{"species":"Hipparion", "at":eastern, "phase":3.1},
				{"species":"Dinofelis", "at":southern, "phase":4.2}
			]
		2:
			return [
				{"species":"Zebra", "at":home + Vector2(-82, -58), "phase":0.2},
				{"species":"Gazelle", "at":home + Vector2(80, -70), "phase":1.9},
				{"species":"Elephant", "at":home + Vector2(42, 90), "phase":3.3},
				{"species":"Lion", "at":home + Vector2(-155, 40), "phase":4.8},
				{"species":"Zebra", "at":central, "phase":0.9},
				{"species":"Gazelle", "at":eastern, "phase":2.4},
				{"species":"Elephant", "at":southern, "phase":3.9}
			]
		3:
			return [
				{"species":"Zebra", "at":home + Vector2(-82, -58), "phase":0.4},
				{"species":"Wildebeest", "at":home + Vector2(80, -70), "phase":2.1},
				{"species":"Elephant", "at":home + Vector2(42, 90), "phase":3.7},
				{"species":"Lion", "at":home + Vector2(-155, 40), "phase":5.2},
				{"species":"Wildebeest", "at":central, "phase":1.2},
				{"species":"Zebra", "at":eastern, "phase":2.9},
				{"species":"Lion", "at":southern, "phase":4.4}
			]
		_:
			return [
				{"species":"Giraffe", "at":home + Vector2(-82, -58), "phase":0.4},
				{"species":"Zebra", "at":home + Vector2(80, -70), "phase":2.1},
				{"species":"Elephant", "at":home + Vector2(42, 90), "phase":3.7},
				{"species":"Lion", "at":home + Vector2(-155, 40), "phase":5.2},
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
		"is_predator": species_name in PREDATOR_SPECIES,
		"is_prey": species_name in PREY_SPECIES,
		"encounter_cooldown": 6.0 if species_name in PREDATOR_SPECIES else 0.0,
		"stalking": false,
		"slain_seasons": 0,
		"repath_timer": 0.0,
		"model": model, "opacity": 1.0, "replacement": {}
	}


func _pick_wildlife_goal(animal: Dictionary) -> bool:
	var home_tile: Vector2i = animal["home_tile"]
	var current_tile: Vector2i = world.tile_from_world(animal["position"])
	var radius: int = int(animal["roam_radius"])
	if animal.get("is_prey", false) and not wildfire_tiles.is_empty():
		var regrowth_targets: Array[Vector2i] = []
		for id in wildfire_tiles:
			if wildfire_tiles[id].get("state", "") != "regrowth":
				continue
			var tile := Vector2i(int(id) % WORLD_MAP_SCRIPT.WORLD_WIDTH, floori(float(id) / WORLD_MAP_SCRIPT.WORLD_WIDTH))
			if tile != current_tile and tile.distance_squared_to(home_tile) <= (radius + 3) * (radius + 3) and world.has_land_route_point(tile):
				regrowth_targets.append(tile)
		if not regrowth_targets.is_empty() and ai_rng.randf() < 0.7:
			var target_tile: Vector2i = regrowth_targets[ai_rng.randi_range(0, regrowth_targets.size() - 1)]
			if _route_actor_to(animal, target_tile):
				return true
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
	if int(animal.get("slain_seasons", 0)) > 0:
		animal["stalking"] = false
		animal["moving"] = false
		return false
	var position: Vector2 = animal["position"]
	if animal.get("is_predator", false) and float(animal.get("encounter_cooldown", 0.0)) <= 0.0 and not _run_ended():
		var player_pos: Vector2 = player_actor["position"]
		if position.distance_squared_to(player_pos) <= PREDATOR_STALK_RANGE * PREDATOR_STALK_RANGE:
			animal["stalking"] = true
			animal["pause"] = 0.0
			animal["repath_timer"] = float(animal.get("repath_timer", 0.0)) - delta
			if float(animal["repath_timer"]) <= 0.0 or (position == animal["target"] and animal["route"].is_empty()):
				animal["repath_timer"] = 0.65
				_route_actor_to(animal, world.tile_from_world(player_pos))
			var stalk_moved := _update_actor(animal, delta, PREDATOR_STALK_SPEED)
			animal["at"] = animal["position"]
			return stalk_moved
	animal["stalking"] = false
	if float(animal["pause"]) > 0.0:
		animal["pause"] = maxf(0.0, float(animal["pause"]) - delta)
		animal["moving"] = false
		return false
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
		if float(animal.get("encounter_cooldown", 0.0)) > 0.0:
			animal["encounter_cooldown"] = maxf(0.0, float(animal["encounter_cooldown"]) - delta)
		var model = animal["model"]
		var replacement: Dictionary = animal["replacement"]
		var moved := _update_wildlife_roaming(animal, delta)
		var position: Vector2 = animal["at"]
		var on_screen := MAP_VIEW.grow(52.0 * zoom_level).has_point(_world_to_screen(position))
		var opacity: float = animal["opacity"]
		if not replacement.is_empty() and (opacity <= 0.0 or not on_screen):
			model.hide()
			model.queue_free()
			wildlife[i] = _make_wildlife(replacement)
			_position_wildlife_model(wildlife[i])
			changed = true
			continue
		var target := 1.0 if replacement.is_empty() and int(animal.get("slain_seasons", 0)) <= 0 else 0.0
		var next := move_toward(opacity, target, delta / 0.65) if on_screen else target
		if next != opacity:
			animal["opacity"] = next
			model.set_opacity(next)
			changed = true
		if next > 0.3 and on_screen:
			wildlife_sighted[animal["species"]] = true
		if moved:
			_position_wildlife_model(animal)
			if next > 0.0 and on_screen:
				changed = true
		if next > 0.0 and on_screen:
			model.set_motion(animal["moving"], animal["heading"], delta)
	return changed


func _spawn_combat_flash(at: Vector2, color: Color) -> void:
	combat_flashes.append({"at": at, "color": color, "age": 0.0, "duration": 0.65})


func _update_combat_flashes(delta: float) -> bool:
	if combat_flashes.is_empty():
		return false
	var keep: Array[Dictionary] = []
	for flash in combat_flashes:
		flash["age"] = float(flash["age"]) + delta
		if float(flash["age"]) < float(flash["duration"]):
			keep.append(flash)
	combat_flashes = keep
	return true


func _player_combat_strength(include_flint := true) -> int:
	var strength := 1
	if _has_skill("stone_flaking"):
		strength += 2
	if _has_skill("hide_working"):
		strength += 1
	if _has_skill("ember_carrying") or carried_ember_seasons > 0:
		strength += 1
	if turn >= 25:
		strength += 1
	if include_flint and int(pack["stone"]) > 0:
		strength += 1
	if wounded_seasons > 0:
		strength = maxi(1, strength - 1)
	return strength


func _band_combat_strength(band_index: int) -> int:
	if _is_paranthropus_band(band_index) or turn >= 18:
		return 4
	return 3


func _check_band_skirmishes() -> void:
	if _run_ended():
		return
	var player_pos: Vector2 = player_actor["position"]
	for i in range(ai_bands.size()):
		var band: Dictionary = ai_bands[i]
		if str(band.get("attitude", "friendly")) != "hostile":
			continue
		if float(band.get("skirmish_cooldown", 0.0)) > 0.0:
			continue
		var pos: Vector2 = band["position"]
		if player_pos.distance_squared_to(pos) > BAND_SKIRMISH_RANGE * BAND_SKIRMISH_RANGE:
			continue
		if not world.land_segment_clear(player_pos, pos):
			continue
		_resolve_band_skirmish(i, false)
		return


func _resolve_band_skirmish(band_index: int, initiated_by_player: bool) -> void:
	if band_index < 0 or band_index >= ai_bands.size():
		return
	var band: Dictionary = ai_bands[band_index]
	var band_name: String = band["label"]
	var player_pos: Vector2 = player_actor["position"]
	var used_flint := int(pack["stone"]) > 0
	var player_str := _player_combat_strength(true)
	if used_flint:
		pack["stone"] = int(pack["stone"]) - 1
	var enemy_str := _band_combat_strength(band_index)
	band["skirmish_cooldown"] = BAND_SKIRMISH_COOLDOWN
	band["pursuing"] = false
	band["pause"] = 0.0
	if not band["goals"].is_empty():
		var retreat_idx: int = (int(band["goal_index"]) + 2) % band["goals"].size()
		band["goal_index"] = retreat_idx
		_route_actor_to(band, band["goals"][retreat_idx])
	movement_key = KEY_NONE
	_cancel_active_task(true)
	if player_str >= enemy_str:
		clashes_won += 1
		var loot := 14 if initiated_by_player else 10
		var before_food := food
		_change_food(float(loot))
		var food_gain := food - before_food
		var cohesion_gain := mini(4, 100 - cohesion)
		var knowledge_gain := mini(3, 99 - knowledge)
		cohesion += cohesion_gain
		knowledge += knowledge_gain
		band["attitude"] = "wary"
		_spawn_combat_flash(player_pos.lerp(band["position"], 0.4), Color("#e8a84d"))
		_spawn_floating_text("SKIRMISH WON · +%d Food" % food_gain, player_pos, Color("#f2c872"))
		_start_player_activity("fighting", 1.2)
		var flint_note := " (Flint used)" if used_flint else ""
		_event("SKIRMISH WON  /  You drive back %s and seize stores%s. Food +%d, cohesion +%d, knowledge +%d." % [band_name, flint_note, food_gain, cohesion_gain, knowledge_gain])
	else:
		clashes_lost += 1
		_change_food(-10.0)
		cohesion = maxi(0, cohesion - 6)
		band["attitude"] = "hostile"
		var wounded_note := ""
		if not _has_skill("hide_working"):
			wounded_seasons = maxi(wounded_seasons, 2)
			wounded_note = " Wounded!"
		_spawn_combat_flash(player_pos, Color("#e04a3a"))
		_spawn_floating_text("RAIDED · −10 Food%s" % wounded_note, player_pos, Color("#f07664"))
		_event("TERRITORIAL RAID  /  %s overpower you in a sharp clash! Food −10, cohesion −6.%s" % [band_name, " You suffer a wound (slower travel)." if not wounded_note.is_empty() else " Hide wraps soften the blows."])
		if cohesion == 0:
			lineage_ended = true
			player_actor["route"] = []
			_event("LINEAGE LOST  /  Broken by territorial conflict, your band scatters across the valley.")
			_show_summary_overlay()
	_refresh_ui()
	_redraw_dynamic()


func _nearby_fightable_predator() -> Dictionary:
	var armed := _has_skill("stone_flaking") or _has_skill("ember_carrying") or carried_ember_seasons > 0 or int(pack["stone"]) > 0 or turn >= 25
	if not armed:
		return {}
	var player_pos: Vector2 = player_actor["position"]
	var best: Dictionary = {}
	var best_dist := HUNT_RANGE * HUNT_RANGE
	for animal in wildlife:
		if not animal.get("is_predator", false) or int(animal.get("slain_seasons", 0)) > 0:
			continue
		if float(animal["opacity"]) < 0.25:
			continue
		var pos: Vector2 = animal["at"]
		var d2 := player_pos.distance_squared_to(pos)
		if d2 <= best_dist and world.land_segment_clear(player_pos, pos):
			best_dist = d2
			best = animal
	return best


func _check_predator_encounters() -> void:
	if _run_ended():
		return
	var player_pos: Vector2 = player_actor["position"]
	for animal in wildlife:
		if not animal.get("is_predator", false) or int(animal.get("slain_seasons", 0)) > 0:
			continue
		if float(animal.get("encounter_cooldown", 0.0)) > 0.0 or float(animal["opacity"]) < 0.25:
			continue
		var pos: Vector2 = animal["at"]
		if player_pos.distance_squared_to(pos) > PREDATOR_DANGER_RANGE * PREDATOR_DANGER_RANGE:
			continue
		if not world.land_segment_clear(player_pos, pos):
			continue
		animal["encounter_cooldown"] = PREDATOR_COOLDOWN_SECS
		animal["stalking"] = false
		animal["pause"] = 0.0
		_pick_wildlife_goal(animal)
		movement_key = KEY_NONE
		var pred_name: String = animal["species"]
		if _has_skill("ember_carrying") or carried_ember_seasons > 0:
			cohesion = mini(100, cohesion + 2)
			_spawn_combat_flash(pos, Color("#f0a24d"))
			_spawn_floating_text("Embers repel %s!" % pred_name, player_pos, Color("#f2c872"))
			_event("PREDATOR DETERRED  /  Glowing embers drive off a stalking %s. Cohesion +2." % pred_name)
		elif _has_skill("stone_flaking"):
			_change_food(-2.0)
			cohesion = mini(100, cohesion + 1)
			_spawn_combat_flash(pos, Color("#d4b67c"))
			_spawn_floating_text("%s driven back" % pred_name, player_pos, Color("#e8d59b"))
			_event("PREDATOR HELD OFF  /  Flaked stones and shouts keep a %s at bay. Food −2, cohesion +1." % pred_name)
		elif int(pack["stone"]) > 0:
			pack["stone"] = int(pack["stone"]) - 1
			_change_food(-1.0)
			cohesion = mini(100, cohesion + 1)
			_spawn_combat_flash(pos, Color("#9dd2c4"))
			_spawn_floating_text("Flint thrown! Predator repelled", player_pos, Color("#9dd2c4"))
			_event("FLINT DEFENSE  /  You hurl a collected flint core to drive back a stalking %s. Food −1, cohesion +1." % pred_name)
		else:
			_cancel_active_task(true)
			_change_food(-6.0)
			cohesion = maxi(0, cohesion - 6)
			wounded_seasons = maxi(wounded_seasons, 2)
			_spawn_combat_flash(player_pos, Color("#e04a3a"))
			_spawn_floating_text("MAULED · −6 Food · Wounded!", player_pos, Color("#f07664"))
			_event("PREDATOR AMBUSH  /  A %s lunges from cover! You escape wounded. Food −6, cohesion −6." % pred_name)
			if cohesion == 0:
				lineage_ended = true
				player_actor["route"] = []
				_event("LINEAGE LOST  /  Shaken and scattered by predators, your band cannot hold together.")
				_show_summary_overlay()
		_refresh_ui()
		_redraw_dynamic()
		return


func _nearby_huntable_prey() -> Dictionary:
	if not (_has_skill("stone_flaking") or turn >= 13):
		return {}
	var player_pos: Vector2 = player_actor["position"]
	var best: Dictionary = {}
	var best_dist := HUNT_RANGE * HUNT_RANGE
	for animal in wildlife:
		if not animal.get("is_prey", false) or float(animal["opacity"]) < 0.25:
			continue
		var pos: Vector2 = animal["at"]
		var d2 := player_pos.distance_squared_to(pos)
		if d2 <= best_dist and world.land_segment_clear(player_pos, pos):
			best_dist = d2
			best = animal
	return best


func _tick_carcass_sites() -> void:
	var expired: Array = []
	for id in carcass_sites:
		var remaining := int(carcass_sites[id]) - 1
		if remaining <= 0:
			expired.append(id)
		else:
			carcass_sites[id] = remaining
	for id in expired:
		carcass_sites.erase(id)
	var player_tile: Vector2i = world.tile_from_world(player_actor["position"])
	for animal in wildlife:
		if carcass_sites.size() >= 2:
			break
		if not animal.get("is_predator", false):
			continue
		var tile: Vector2i = world.tile_from_world(animal["at"])
		if tile == player_tile:
			for edge in WORLD_MAP_SCRIPT.TILE_EDGES:
				var neighbor: Vector2i = tile + edge
				if neighbor != player_tile and world.has_land_route_point(neighbor):
					tile = neighbor
					break
		if tile == player_tile or not world.has_land_route_point(tile):
			continue
		var id: int = world.tile_id(tile)
		if not carcass_sites.has(id):
			carcass_sites[id] = 2


func _position_wildlife_model(animal: Dictionary) -> void:
	var screen := _world_to_screen(animal["at"])
	var model: Node3D = animal["model"]
	var on_screen := MAP_VIEW.grow(110.0 * zoom_level).has_point(screen)
	model.visible = on_screen and float(animal["opacity"]) > 0.0
	if not model.visible:
		return
	var local := screen - MAP_VIEW.position
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


func _pack_caption() -> String:
	return "PACK  ·  Flint %d  ·  Water Gourds %d  ·  Tinder %d  ·  Collected %d" % [
		int(pack["stone"]), int(pack["gourd"]), int(pack["tinder"]), items_collected
	]


func _spawn_floating_text(text: String, at: Vector2, color: Color) -> void:
	floating_texts.append({"text": text, "at": at, "color": color, "age": 0.0, "duration": 1.45})


func _update_floating_texts(delta: float) -> bool:
	if floating_texts.is_empty():
		return false
	var keep: Array[Dictionary] = []
	for item in floating_texts:
		item["age"] = float(item["age"]) + delta
		if float(item["age"]) < float(item["duration"]):
			keep.append(item)
	floating_texts = keep
	return true


func _collectible_kind_for_terrain(terrain: String, is_dry := false) -> String:
	match terrain:
		"woodland":
			if is_dry:
				return "tinder" if ai_rng.randf() < 0.65 else "berries"
			return "berries" if ai_rng.randf() < 0.65 else "tinder"
		"wetland":
			return "berries" if ai_rng.randf() < 0.72 else "ochre"
		"volcanic":
			return "stone" if ai_rng.randf() < 0.78 else "ochre"
		"highland":
			return "stone" if ai_rng.randf() < 0.55 else "ochre"
		"dryland":
			if is_dry:
				return "gourd" if ai_rng.randf() < 0.58 else "stone"
			return "gourd" if ai_rng.randf() < 0.48 else "stone"
		"savanna":
			var r := ai_rng.randf()
			if r < (0.48 if is_dry else 0.34):
				return "gourd"
			if r < 0.74:
				return "tinder"
			if r < 0.90:
				return "berries"
			return "ochre"
	return ""


func _place_collectible(tile: Vector2i, kind: String) -> bool:
	if kind.is_empty() or not world.has_land_route_point(tile):
		return false
	var id: int = world.tile_id(tile)
	if collectibles.has(id) or wildfire_tiles.get(id, {}).get("state", "") == "burning":
		return false
	var center: Vector2 = world.tile_center(tile.x, tile.y)
	var offset := Vector2(ai_rng.randf_range(-14.0, 14.0), ai_rng.randf_range(-7.0, 7.0))
	var pos := center + offset if world.land_position(center + offset) else center
	collectibles[id] = {"kind": kind, "at": pos, "tile": tile}
	return true


func _spawn_initial_collectibles() -> void:
	collectibles.clear()
	# Guarantee 3 varied starter collectibles within immediate sight of the starting camp.
	var starter_specs := [
		{"offset": Vector2i(1, 0), "kind": "berries"},
		{"offset": Vector2i(-1, 1), "kind": "stone"},
		{"offset": Vector2i(0, -1), "kind": "ochre"}
	]
	for spec in starter_specs:
		var tile: Vector2i = WORLD_MAP_SCRIPT.WORLD_START + (spec["offset"] as Vector2i)
		if not _place_collectible(tile, spec["kind"]):
			var fallback: Vector2i = world.nearest_land_tile(tile)
			if fallback != WORLD_MAP_SCRIPT.WORLD_START:
				_place_collectible(fallback, spec["kind"])
	_replenish_collectibles(false, 56)


func _replenish_collectibles(is_dry: bool, count := 5) -> void:
	var player_tile: Vector2i = world.tile_from_world(player_actor["position"])
	var placed := 0
	for _attempt in range(count * 12):
		if placed >= count or collectibles.size() >= MAX_COLLECTIBLES:
			break
		var tile := Vector2i(ai_rng.randi_range(1, WORLD_MAP_SCRIPT.WORLD_WIDTH - 2), ai_rng.randi_range(1, WORLD_MAP_SCRIPT.WORLD_HEIGHT - 2))
		if tile == player_tile or tile.distance_squared_to(player_tile) < 2:
			continue
		var kind := _collectible_kind_for_terrain(world.terrain_at(tile), is_dry)
		if _place_collectible(tile, kind):
			placed += 1


func _check_collectible_pickups() -> bool:
	if _run_ended() or collectibles.is_empty():
		return false
	var player_pos: Vector2 = player_actor["position"]
	var center_tile: Vector2i = world.tile_from_world(player_pos)
	var picked := false
	var check_tiles: Array[Vector2i] = [center_tile]
	for edge in WORLD_MAP_SCRIPT.TILE_EDGES:
		check_tiles.append(center_tile + edge)
	for tile in check_tiles:
		if not Rect2i(0, 0, WORLD_MAP_SCRIPT.WORLD_WIDTH, WORLD_MAP_SCRIPT.WORLD_HEIGHT).has_point(tile):
			continue
		var id: int = world.tile_id(tile)
		if not collectibles.has(id):
			continue
		var item: Dictionary = collectibles[id]
		if player_pos.distance_squared_to(item["at"]) > PICKUP_RANGE * PICKUP_RANGE:
			continue
		collectibles.erase(id)
		items_collected += 1
		picked = true
		var kind: String = item["kind"]
		var at: Vector2 = item["at"]
		match kind:
			"berries":
				var before_food := food
				_change_food(8.0)
				var gain := food - before_food
				if before_food < 45:
					cohesion = mini(100, cohesion + 1)
				var heal_note := ""
				if wounded_seasons > 0:
					wounded_seasons = maxi(0, wounded_seasons - 1)
					heal_note = " · Healing"
				_spawn_floating_text("+%d Food · Wild Figs%s" % [gain, heal_note], at, Color("#b6dc8b"))
				_show_toast("Collected wild figs (food +%d%s)." % [gain, ", eases wounds" if not heal_note.is_empty() else ""])
			"stone":
				pack["stone"] = int(pack["stone"]) + 1
				var k_gain := mini(2, 99 - knowledge)
				knowledge += k_gain
				_spawn_floating_text("+1 Flint · +%d K" % k_gain, at, Color("#9dd2c4"))
				_show_toast("Collected flint core (+%d knowledge; boosts hunts & repels predators)." % k_gain)
			"gourd":
				pack["gourd"] = int(pack["gourd"]) + 1
				_spawn_floating_text("+1 Water Gourd", at, Color("#efd69d"))
				_show_toast("Collected water gourd (cuts dry-season inland food drain by 2).")
			"ochre":
				var k_gain := mini(5, 99 - knowledge)
				var c_gain := mini(3, 100 - cohesion)
				knowledge += k_gain
				cohesion += c_gain
				_spawn_floating_text("+%d K · +%d Cohesion · Red Ochre" % [k_gain, c_gain], at, Color("#f29d79"))
				_event("RED OCHRE  /  You collect vivid mineral pigment. Knowledge +%d, cohesion +%d." % [k_gain, c_gain])
			"tinder":
				pack["tinder"] = int(pack["tinder"]) + 1
				_spawn_floating_text("+1 Dry Tinder", at, Color("#f4ca72"))
				_show_toast("Collected dry tinder (cuts Practice cost by 2 food & adds +3 knowledge).")
		_refresh_ui()
	return picked


func _build_map_layers() -> void:
	map_root = Node2D.new()
	map_root.name = "MapRoot"
	add_child(map_root)

	var chunk_root := Node2D.new()
	chunk_root.name = "BakedChunks"
	map_root.add_child(chunk_root)

	map_chunks.clear()
	chunk_bounds.clear()

	# Cover the entire world pixel bounds with an axis-aligned opaque grid (with 2px overscan
	# + region_rect inset) so neighboring chunks meet seamlessly with zero alpha fringing.
	var min_x := floorf(world.tile_center(0, WORLD_MAP_SCRIPT.WORLD_HEIGHT - 1).x - WORLD_MAP_SCRIPT.TILE_W)
	var max_x := ceilf(world.tile_center(WORLD_MAP_SCRIPT.WORLD_WIDTH - 1, 0).x + WORLD_MAP_SCRIPT.TILE_W)
	var min_y := floorf(world.tile_center(0, 0).y - WORLD_MAP_SCRIPT.TILE_H - 96.0)
	var max_y := ceilf(world.tile_center(WORLD_MAP_SCRIPT.WORLD_WIDTH - 1, WORLD_MAP_SCRIPT.WORLD_HEIGHT - 1).y + WORLD_MAP_SCRIPT.TILE_H)
	var cols := int(ceilf((max_x - min_x) / float(CHUNK_PX)))
	var rows := int(ceilf((max_y - min_y) / float(CHUNK_PX)))

	for cy in range(rows):
		for cx in range(cols):
			var rx := min_x + float(cx * CHUNK_PX)
			var ry := min_y + float(cy * CHUNK_PX)
			var rw := minf(float(CHUNK_PX), max_x - rx)
			var rh := minf(float(CHUNK_PX), max_y - ry)
			var bounds := Rect2(Vector2(rx, ry), Vector2(rw, rh))
			chunk_bounds.append(bounds)

			var sprite := Sprite2D.new()
			sprite.name = "Chunk_%d_%d" % [cx, cy]
			sprite.centered = false
			sprite.position = bounds.position
			sprite.region_enabled = true
			sprite.region_rect = Rect2(float(CHUNK_PAD), float(CHUNK_PAD), bounds.size.x, bounds.size.y)
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			sprite.visible = false
			chunk_root.add_child(sprite)

			map_chunks.append({
				"bounds": bounds, "sprite": sprite,
				"viewport": null, "canvas": null,
				"baked": false, "dirty": true
			})

	dynamic_world_layer = LayerNode.new()
	dynamic_world_layer.name = "DynamicWorld"
	dynamic_world_layer.draw_cb = _draw_dynamic_world
	map_root.add_child(dynamic_world_layer)

	overlay_layer = LayerNode.new()
	overlay_layer.name = "MapOverlay"
	overlay_layer.draw_cb = _draw_overlay
	add_child(overlay_layer)


func _ensure_chunk_baked(idx: int) -> void:
	var chunk: Dictionary = map_chunks[idx]
	if chunk["baked"] and not chunk["dirty"]:
		return
	var bounds: Rect2 = chunk["bounds"]
	var padded := bounds.grow(float(CHUNK_PAD))
	var vp: SubViewport = chunk["viewport"]
	if vp == null:
		vp = SubViewport.new()
		vp.name = "ChunkVP_%d" % idx
		vp.size = Vector2i(int(ceilf(padded.size.x)), int(ceilf(padded.size.y)))
		vp.transparent_bg = false
		vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		vp.msaa_2d = Viewport.MSAA_DISABLED
		vp.use_hdr_2d = false
		vp.disable_3d = true
		add_child(vp)
		var sprite: Sprite2D = chunk["sprite"]
		sprite.texture = vp.get_texture()
		chunk["viewport"] = vp

	var canvas: LayerNode = chunk["canvas"]
	if not is_instance_valid(canvas):
		canvas = LayerNode.new()
		canvas.position = -padded.position
		canvas.draw_cb = func(c: CanvasItem) -> void:
			map_renderer.draw_baked_rect(c, padded, discovered_landmarks, turn % 2 == 1, depleted_tiles, wildfire_tiles)
		vp.add_child(canvas)
		chunk["canvas"] = canvas
	else:
		canvas.did_draw = false
		canvas.queue_redraw()

	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	chunk["baked"] = true
	chunk["dirty"] = false
	chunk["bake_frames"] = 0
	if idx not in baking_chunks:
		baking_chunks.append(idx)


func _cleanup_baked_canvases() -> void:
	if baking_chunks.is_empty():
		return
	var remaining: Array[int] = []
	for idx in baking_chunks:
		if idx < 0 or idx >= map_chunks.size():
			continue
		var chunk: Dictionary = map_chunks[idx]
		var canvas: LayerNode = chunk["canvas"]
		var vp: SubViewport = chunk["viewport"]
		if not is_instance_valid(canvas):
			chunk["canvas"] = null
			if is_instance_valid(vp):
				vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
			continue
		if not canvas.did_draw:
			# Canvas has not executed _draw() yet; keep UPDATE_ONCE armed for the next frame.
			if is_instance_valid(vp):
				vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			remaining.append(idx)
			continue
		var frames: int = int(chunk.get("bake_frames", 0)) + 1
		chunk["bake_frames"] = frames
		# Allow 2 post-draw passes after _draw() so newly created SubViewports always commit their FBO.
		if frames >= 2:
			canvas.queue_free()
			chunk["canvas"] = null
			if is_instance_valid(vp):
				vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		else:
			if is_instance_valid(vp):
				vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			remaining.append(idx)
	baking_chunks = remaining


func _mark_chunk_dirty(tile: Vector2i) -> void:
	if map_chunks.is_empty():
		return
	var center: Vector2 = world.tile_center(tile.x, tile.y)
	var tile_rect := Rect2(center - Vector2(WORLD_MAP_SCRIPT.TILE_W, WORLD_MAP_SCRIPT.TILE_H + 84.0), Vector2(WORLD_MAP_SCRIPT.TILE_W * 2.0, WORLD_MAP_SCRIPT.TILE_H * 2.0 + 96.0))
	for idx in range(chunk_bounds.size()):
		if chunk_bounds[idx].intersects(tile_rect):
			var chunk: Dictionary = map_chunks[idx]
			chunk["dirty"] = true
			var sprite: Sprite2D = chunk["sprite"]
			if sprite.visible and chunk["baked"]:
				_ensure_chunk_baked(idx)


func _mark_all_chunks_dirty() -> void:
	for idx in range(map_chunks.size()):
		var chunk: Dictionary = map_chunks[idx]
		chunk["dirty"] = true
		var sprite: Sprite2D = chunk["sprite"]
		if sprite.visible and chunk["baked"]:
			_ensure_chunk_baked(idx)


func _sync_map_transform() -> void:
	if not is_instance_valid(map_root):
		return
	map_root.position = _map_draw_origin()
	map_root.scale = Vector2.ONE * zoom_level
	var world_tl := _screen_to_world(MAP_VIEW.position)
	var world_br := _screen_to_world(MAP_VIEW.end)
	var view_world := Rect2(world_tl, world_br - world_tl).grow(80.0)
	for idx in range(chunk_bounds.size()):
		var in_view := chunk_bounds[idx].intersects(view_world)
		var chunk: Dictionary = map_chunks[idx]
		var sprite: Sprite2D = chunk["sprite"]
		sprite.visible = in_view
		if in_view:
			_ensure_chunk_baked(idx)
	_request_3d_update()


func _redraw_dynamic() -> void:
	if is_instance_valid(dynamic_world_layer):
		dynamic_world_layer.queue_redraw()
	if is_instance_valid(overlay_layer):
		overlay_layer.queue_redraw()


func _draw() -> void:
	map_renderer.draw_world(self, W, H)


func _draw_dynamic_world(canvas: CanvasItem) -> void:
	map_renderer.draw_dynamic_world(canvas, MAP_VIEW, _world_to_screen, collectibles, carcass_sites, player_actor, ai_bands, wildlife)


func _draw_overlay(canvas: CanvasItem) -> void:
	if is_instance_valid(hominin_viewport):
		canvas.draw_texture_rect(hominin_viewport.get_texture(), MAP_VIEW, false)
	canvas.draw_set_transform(_map_draw_origin(), 0.0, Vector2.ONE * zoom_level)
	var task_progress := -1.0
	if not active_task.is_empty() and float(active_task["duration"]) > 0.0:
		task_progress = float(active_task["elapsed"]) / float(active_task["duration"])
	map_renderer.draw_player_marker(canvas, MAP_VIEW, _world_to_screen, player_actor, ai_bands, task_progress)
	canvas.draw_set_transform(Vector2.ZERO)
	map_renderer.draw_band_markers(canvas, MAP_VIEW, zoom_level, _world_to_screen, ai_bands)
	map_renderer.draw_combat_flashes(canvas, MAP_VIEW, _world_to_screen, combat_flashes)
	map_renderer.draw_floating_texts(canvas, MAP_VIEW, _world_to_screen, floating_texts)
	canvas.draw_string(ThemeDB.fallback_font, Vector2(18.0, 94.0), _wildlife_caption(), HORIZONTAL_ALIGNMENT_LEFT, 790.0, 12, Color("#f0dfb8"))
	canvas.draw_string(ThemeDB.fallback_font, Vector2(18.0, 112.0), _pack_caption(), HORIZONTAL_ALIGNMENT_LEFT, 790.0, 11, Color("#c8d7c6"))


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
	_sync_map_transform()
	_sync_hominin_models()
	_position_wildlife_models()
	_redraw_dynamic()
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
	season_bar_bg = _panel(root, Rect2(920, 839, 256, 20), Color("#131f1c"), Color("#657767"))
	season_bar_fill = _panel(root, Rect2(921, 840, 0, 18), Color("#4b8378"))
	season_bar_label = _label(root, "", Rect2(920, 838, 256, 22), 7, Color("#f4ecd8"), true)
	season_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_button = _button(root, "Pause (Space)", Rect2(920, 863, 152, 26), Color("#465662"), _on_toggle_pause)
	pause_button.add_theme_font_size_override("font_size", 13)
	speed_button = _button(root, "Speed 1×", Rect2(1078, 863, 98, 26), Color("#465662"), _on_toggle_speed)
	speed_button.add_theme_font_size_override("font_size", 13)
	advance_button = _button(root, "NEW CHRONICLE  ›", Rect2(920, 841, 256, 46), Color("#b88d56"), _on_restart_chronicle)
	advance_button.hide()
	toast_label = _label(root, "", Rect2(260, 80, 670, 42), 12, Color("#f1d7a5"), true)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.hide()
	_build_skills_overlay(root)
	_build_summary_overlay(root)
	_refresh_ui()


func _build_summary_overlay(root: Control) -> void:
	summary_overlay = Control.new()
	summary_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	summary_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	summary_overlay.hide()
	root.add_child(summary_overlay)

	var backdrop := ColorRect.new()
	backdrop.position = MAP_VIEW.position
	backdrop.size = MAP_VIEW.size
	backdrop.color = Color(0.04, 0.08, 0.08, 0.76)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	summary_overlay.add_child(backdrop)

	var box := Rect2(225, 146, 740, 588)
	_panel(summary_overlay, box, Color("#15221f"), Color("#b99561"))
	summary_title_label = _label(summary_overlay, "", Rect2(box.position.x + 28, box.position.y + 24, 684, 34), 16, Color("#e3c58d"), true)
	summary_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_epithet_label = _label(summary_overlay, "", Rect2(box.position.x + 28, box.position.y + 62, 684, 28), 11, Color("#9fd4a7"), true)
	summary_epithet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel(summary_overlay, Rect2(box.position.x + 40, box.position.y + 100, 660, 2), Color("#b99561", 0.5))
	summary_body_label = _label(summary_overlay, "", Rect2(box.position.x + 44, box.position.y + 118, 652, 390), 10, Color("#e8dfce"), false)
	_button(summary_overlay, "Inspect Valley", Rect2(box.position.x + 150, box.end.y - 64, 190, 42), Color("#465662"), _on_close_summary)
	_button(summary_overlay, "Begin New Chronicle  ›", Rect2(box.position.x + 360, box.end.y - 64, 230, 42), Color("#b88d56"), _on_restart_chronicle)


func _on_close_summary() -> void:
	if is_instance_valid(summary_overlay):
		summary_overlay.hide()


func _on_restart_chronicle() -> void:
	get_tree().reload_current_scene()


func _lineage_epithet() -> String:
	if clashes_won + predators_slain >= 3:
		return "Fierce Defenders of the Rift"
	if _has_skill("ember_carrying") or _has_skill("hearth_keeping"):
		return "Keepers of the Hearth"
	var charted_pct := float(explored_tiles.size()) / float(WORLD_MAP_SCRIPT.WORLD_WIDTH * WORLD_MAP_SCRIPT.WORLD_HEIGHT)
	if charted_pct >= 0.35 or discovered_landmark_names.size() >= 6:
		return "Rift Pathfinders"
	if hunts_completed >= 3 or (_has_skill("stone_flaking") and _has_skill("hide_working")):
		return "Stone-Age Hunters"
	if _has_skill("carry_water") or generation >= 3:
		return "Children of the Springs"
	return "Wanderers of the Rift"


func _show_summary_overlay() -> void:
	if not is_instance_valid(summary_overlay):
		return
	if is_instance_valid(skills_overlay):
		skills_overlay.hide()
	var total_tiles := WORLD_MAP_SCRIPT.WORLD_WIDTH * WORLD_MAP_SCRIPT.WORLD_HEIGHT
	var charted_pct := 100.0 * float(explored_tiles.size()) / float(total_tiles)
	var skill_names: Array[String] = []
	for skill in TECH_TREE_SCRIPT.SKILLS:
		if _has_skill(str(skill["id"])):
			skill_names.append(str(skill["name"]))
	var skills_text := ", ".join(skill_names) if not skill_names.is_empty() else "None"
	if lineage_ended:
		summary_title_label.text = "THE LINEAGE SCATTERS"
		summary_title_label.add_theme_color_override("font_color", Color("#e09b84"))
		summary_epithet_label.text = "%s  ·  Ended at %s (Turn %d / %d)" % [_lineage_epithet(), _format_year(year_bp), turn, CHRONICLE_TURNS]
	else:
		summary_title_label.text = "THE CHRONICLE REACHES THE PRESENT"
		summary_title_label.add_theme_color_override("font_color", Color("#e3c58d"))
		summary_epithet_label.text = "Legacy Title: %s" % _lineage_epithet()
	summary_body_label.text = (
		"Rift Valley charted:  %d / %d tiles (%.1f%%)\n"
		+ "Landmarks discovered:  %d / %d\n"
		+ "Generations lived:  %d\n"
		+ "Final stores:  Food %d  ·  Knowledge %d  ·  Cohesion %d\n\n"
		+ "Wildlife species sighted:  %d   ·   Items collected:  %d\n"
		+ "Hunts completed:  %d   ·   Scavenges:  %d   ·   Shared camps:  %d\n"
		+ "Skirmishes won / lost:  %d / %d   ·   Predators slain:  %d\n"
		+ "Neanderthal kinship:  %s\n\n"
		+ "Skills mastered (%d / %d):\n%s"
	) % [
		explored_tiles.size(), total_tiles, charted_pct,
		discovered_landmark_names.size(), WORLD_MAP_SCRIPT.LANDMARKS.size(),
		generation,
		food, knowledge, cohesion,
		wildlife_sighted.size(), items_collected,
		hunts_completed, scavenges_completed, band_shares_completed,
		clashes_won, clashes_lost, predators_slain,
		"Recorded" if kinship_recorded else "Unrecorded",
		learned_skills.size(), TECH_TREE_SCRIPT.SKILLS.size(), skills_text
	]
	summary_overlay.show()


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


func _practice_food_cost(tile: Vector2i) -> int:
	var cost := BASE_PRACTICE_FOOD_COST
	if _has_skill("hearth_keeping") and tile == WORLD_MAP_SCRIPT.SHELTERED_CLIFF_TILE:
		cost = HEARTH_PRACTICE_FOOD_COST
	elif _has_skill("ember_carrying"):
		cost = EMBER_PRACTICE_FOOD_COST
	if int(pack["tinder"]) > 0:
		cost = maxi(2, cost - 2)
	return cost


func _season_food_cost(tile: Vector2i, season_turn: int) -> int:
	if season_turn % 2 == 0:
		return WET_SEASON_FOOD_COST
	if world.near_permanent_water(tile):
		return DRY_SEASON_WATER_FOOD_COST
	var cost := DRY_SEASON_CARRY_WATER_FOOD_COST if _has_skill("carry_water") else DRY_SEASON_FOOD_COST
	if int(pack["gourd"]) > 0:
		cost = maxi(DRY_SEASON_WATER_FOOD_COST, cost - 2)
	return cost


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


func _tick_wildfires(entering_dry: bool) -> void:
	var to_remove: Array = []
	for id in wildfire_tiles:
		var info: Dictionary = wildfire_tiles[id]
		var tile := Vector2i(int(id) % WORLD_MAP_SCRIPT.WORLD_WIDTH, floori(float(id) / WORLD_MAP_SCRIPT.WORLD_WIDTH))
		var state: String = info["state"]
		if entering_dry:
			world.set_tile_blocked(tile, false)
			to_remove.append(id)
		else:
			if state == "burning":
				world.set_tile_blocked(tile, false)
			if state in ["burning", "cooled"]:
				info["state"] = "regrowth"
				info["foraged"] = false
	for id in to_remove:
		wildfire_tiles.erase(id)
	if not entering_dry:
		return
	var player_tile: Vector2i = world.tile_from_world(player_actor["position"])
	var candidates: Array[Vector2i] = []
	for tile in world.tiles_in_radius(player_tile, 14):
		if tile == player_tile or tile.distance_squared_to(player_tile) < 4:
			continue
		if tile in WORLD_MAP_SCRIPT.SPRING_TILES or not world.landmark_for_tile(tile).is_empty():
			continue
		if world.terrain_at(tile) in ["savanna", "dryland"] and world.has_land_route_point(tile):
			candidates.append(tile)
	if candidates.is_empty():
		return
	var origin: Vector2i = candidates[ai_rng.randi_range(0, candidates.size() - 1)]
	for _try in range(mini(8, candidates.size())):
		var candidate: Vector2i = candidates[ai_rng.randi_range(0, candidates.size() - 1)]
		var has_flammable_neighbor := false
		for edge in WORLD_MAP_SCRIPT.TILE_EDGES:
			var n: Vector2i = candidate + edge
			if n != player_tile and n not in WORLD_MAP_SCRIPT.SPRING_TILES and world.landmark_for_tile(n).is_empty() and world.terrain_at(n) in ["savanna", "dryland", "woodland"] and world.has_land_route_point(n):
				has_flammable_neighbor = true
				break
		if has_flammable_neighbor:
			origin = candidate
			break
	var origin_id: int = world.tile_id(origin)
	wildfire_tiles[origin_id] = {"state": "burning", "foraged": false, "ember_taken": false}
	world.set_tile_blocked(origin, true)
	var cooled_added := 0
	for edge in WORLD_MAP_SCRIPT.TILE_EDGES:
		if cooled_added >= 2:
			break
		var neighbor: Vector2i = origin + edge
		if neighbor == player_tile or neighbor in WORLD_MAP_SCRIPT.SPRING_TILES or not world.landmark_for_tile(neighbor).is_empty():
			continue
		if world.terrain_at(neighbor) in ["savanna", "dryland", "woodland"] and world.has_land_route_point(neighbor):
			wildfire_tiles[world.tile_id(neighbor)] = {"state": "cooled", "foraged": false, "ember_taken": false}
			cooled_added += 1
	_event("WILDFIRE  /  Dry-season flames ignite nearby %s. Avoid active fire; cooled burn scars expose rich roots and seeds." % world.terrain_at(origin))


func _can_recover_ember(tile: Vector2i) -> bool:
	if not _has_skill("hearth_keeping"):
		return false
	var info: Dictionary = wildfire_tiles.get(world.tile_id(tile), {})
	return info.get("state", "") == "cooled" and not info.get("ember_taken", false)


func _run_ended() -> bool:
	return lineage_ended or turn >= CHRONICLE_TURNS


func _on_toggle_pause() -> void:
	if _run_ended():
		return
	paused = not paused
	_refresh_action_label()


func _on_toggle_speed() -> void:
	if _run_ended():
		return
	time_scale = 2.0 if time_scale < 1.5 else 1.0
	_refresh_action_label()


func _set_speed(value: float) -> void:
	if _run_ended():
		return
	time_scale = value
	_refresh_action_label()


func _cancel_active_task(refund := true) -> void:
	if active_task.is_empty():
		return
	if refund:
		var paid := float(active_task.get("food_paid", 0.0))
		if paid > 0.0:
			_change_food(paid)
		if bool(active_task.get("extra", {}).get("used_tinder", false)):
			pack["tinder"] = int(pack["tinder"]) + 1
	active_task.clear()
	if player_actor["activity"] not in ["idle", "walking"]:
		player_actor["activity"] = "idle"
		player_actor["action_time"] = 0.0
	_refresh_ui()
	_redraw_dynamic()


func _start_task(kind: String, activity: String, duration: float, extra: Dictionary = {}) -> void:
	movement_key = KEY_NONE
	active_task = {
		"kind": kind,
		"activity": activity,
		"duration": duration,
		"elapsed": 0.0,
		"tile": world.tile_from_world(player_actor["position"]),
		"food_paid": float(extra.get("food_paid", 0.0)),
		"extra": extra
	}
	player_actor["activity"] = activity
	player_actor["action_time"] = duration
	_refresh_ui()
	_redraw_dynamic()


func _update_active_task(sim_delta: float) -> bool:
	if active_task.is_empty():
		return false
	active_task["elapsed"] = float(active_task["elapsed"]) + sim_delta
	if float(active_task["elapsed"]) >= float(active_task["duration"]):
		_complete_active_task()
	return true


func _complete_active_task() -> void:
	var task := active_task.duplicate(true)
	active_task.clear()
	player_actor["activity"] = "idle"
	player_actor["action_time"] = 0.0
	var tile: Vector2i = task["tile"]
	var tile_id: int = world.tile_id(tile)
	var extra: Dictionary = task["extra"]
	match str(task["kind"]):
		"scavenge":
			if carcass_sites.has(tile_id):
				var scavenge_gain := _scavenge_food_gain(tile)
				var cohesion_gain := mini(2, 100 - cohesion)
				carcass_sites.erase(tile_id)
				scavenges_completed += 1
				_change_food(float(scavenge_gain))
				cohesion += cohesion_gain
				if food > 0:
					starvation_warned = false
				var marrow := " and cracked marrow" if _has_skill("stone_flaking") else ""
				_event("SCAVENGE  /  You recover meat%s from a predator kill. Food +%d, cohesion +%d." % [marrow, scavenge_gain, cohesion_gain])
		"hunt":
			var prey := _nearby_huntable_prey()
			var species_name := str(extra.get("species", "prey"))
			var used_stone := int(pack["stone"]) > 0
			var hunt_gain := _hunt_food_gain()
			if hunt_gain > 0:
				if used_stone:
					pack["stone"] = int(pack["stone"]) - 1
				hunts_completed += 1
				_change_food(float(hunt_gain))
				var cooperative := turn >= 25
				var cohesion_delta := mini(3, 100 - cohesion) if cooperative else -1
				cohesion = clampi(cohesion + cohesion_delta, 0, 100)
				if food > 0:
					starvation_warned = false
				if not prey.is_empty():
					species_name = str(prey["species"])
					prey["pause"] = 0.0
					_pick_wildlife_goal(prey)
				var flint_note := " (Flint +6)" if used_stone else ""
				if cooperative:
					_event("COOPERATIVE HUNT  /  You coordinate to take a %s%s. Food +%d, cohesion +%d." % [species_name, flint_note, hunt_gain, cohesion_delta])
				else:
					_event("TRACK & HUNT  /  You bring down a %s on the plains%s. Food +%d, cohesion −1." % [species_name, flint_note, hunt_gain])
		"forage":
			var food_gain := _forage_food_gain(tile)
			if food_gain > 0:
				var cohesion_gain := mini(2, 100 - cohesion)
				var fire_info: Dictionary = wildfire_tiles.get(tile_id, {})
				var fire_state: String = fire_info.get("state", "")
				var burn_forage: bool = fire_state == "cooled" and not bool(fire_info.get("foraged", false))
				if burn_forage:
					fire_info["foraged"] = true
				depleted_tiles[tile_id] = 1 if tile in WORLD_MAP_SCRIPT.SPRING_TILES else 2
				_mark_chunk_dirty(tile)
				_change_food(float(food_gain))
				cohesion += cohesion_gain
				if food > 0:
					starvation_warned = false
				if burn_forage:
					_event("BURN SCAR FORAGE  /  You gather exposed roots, seeds, and insects from cooled ash. Food +%d, cohesion +%d." % [food_gain, cohesion_gain])
				elif fire_state == "regrowth":
					_event("REGROWTH FORAGE  /  Fresh green shoots rise from the ash. Food +%d, cohesion +%d." % [food_gain, cohesion_gain])
				else:
					var site := "at the spring" if tile in WORLD_MAP_SCRIPT.SPRING_TILES else ("at the waterhole" if tile == WORLD_MAP_SCRIPT.SEASONAL_WATERHOLE_TILE else "in %s" % world.terrain_at(tile))
					_event("You forage %s. Food +%d, cohesion +%d." % [site, food_gain, cohesion_gain])
		"scout":
			var new_tiles := _unmapped_scout_tiles(tile)
			_reveal_around(tile, _scout_radius())
			_position_wildlife_models()
			var knowledge_gain := mini(9, 99 - knowledge)
			knowledge += knowledge_gain
			_event("You chart %d new tiles. Knowledge +%d." % [new_tiles, knowledge_gain])
		"ember":
			if wildfire_tiles.has(tile_id):
				wildfire_tiles[tile_id]["ember_taken"] = true
				_mark_chunk_dirty(tile)
			var knowledge_gain := mini(12, 99 - knowledge)
			var cohesion_gain := mini(4 if _has_skill("ember_carrying") else 2, 100 - cohesion)
			knowledge += knowledge_gain
			cohesion += cohesion_gain
			if _has_skill("ember_carrying"):
				carried_ember_seasons = 4
			var carry_note := " You pack live coals to carry away from the burn." if _has_skill("ember_carrying") else " You tend a glowing coal from the ash."
			_event("EMBER RECOVERED  /%s Knowledge +%d, cohesion +%d." % [carry_note, knowledge_gain, cohesion_gain])
		"practice":
			var cost := int(task["food_paid"])
			var used_tinder := bool(extra.get("used_tinder", false))
			var base_k := 18 if used_tinder else 15
			var knowledge_gain := mini(base_k, 99 - knowledge)
			knowledge += knowledge_gain
			var practice := "You practice skills by the hearth." if str(task["activity"]) == "learning_at_hearth" else "You practice skills."
			var tinder_note := " (Tinder used)" if used_tinder else ""
			_event("%s%s Food −%d, knowledge +%d." % [practice, tinder_note, cost, knowledge_gain])
		"fight_predator":
			var pred := _nearby_fightable_predator()
			var species_name := str(extra.get("species", "predator"))
			var used_flint := int(pack["stone"]) > 0
			var player_str := _player_combat_strength(true)
			if used_flint:
				pack["stone"] = int(pack["stone"]) - 1
			var strike_at: Vector2 = pred["at"] if not pred.is_empty() else player_actor["position"]
			if player_str >= 3 and not pred.is_empty():
				predators_slain += 1
				pred["slain_seasons"] = PREDATOR_RESPAWN_SEASONS
				pred["stalking"] = false
				pred["opacity"] = 0.0
				pred["model"].set_opacity(0.0)
				var pred_tile: Vector2i = world.tile_from_world(pred["at"])
				if world.has_land_route_point(pred_tile):
					carcass_sites[world.tile_id(pred_tile)] = 3
				var c_gain := mini(5, 100 - cohesion)
				var k_gain := mini(4, 99 - knowledge)
				cohesion += c_gain
				knowledge += k_gain
				_spawn_combat_flash(strike_at, Color("#e8a84d"))
				_spawn_floating_text("%s SLAIN · Carcass left!" % species_name, strike_at, Color("#f2c872"))
				_event("PREDATOR SLAIN  /  You bring down a stalking %s! Its carcass can be scavenged; cohesion +%d, knowledge +%d." % [species_name, c_gain, k_gain])
			else:
				if not pred.is_empty():
					pred["encounter_cooldown"] = PREDATOR_COOLDOWN_SECS * 1.5
					pred["stalking"] = false
					pred["pause"] = 0.0
					_pick_wildlife_goal(pred)
				_change_food(-2.0)
				var c_gain := mini(3, 100 - cohesion)
				cohesion += c_gain
				_spawn_combat_flash(strike_at, Color("#d4b67c"))
				_spawn_floating_text("%s driven off!" % species_name, strike_at, Color("#e8d59b"))
				_event("PREDATOR DRIVEN OFF  /  You clash fiercely and drive off a %s. Food −2, cohesion +%d." % [species_name, c_gain])
		"share":
			var band_index := int(extra.get("band_index", 0))
			band_shares_completed += 1
			band_share_ready_turn[band_index] = turn + SHARE_CAMP_COOLDOWN
			if band_index >= 0 and band_index < ai_bands.size():
				ai_bands[band_index]["attitude"] = "friendly"
			var knowledge_gain := mini(6, 99 - knowledge)
			var cohesion_gain := mini(4, 100 - cohesion)
			knowledge += knowledge_gain
			cohesion += cohesion_gain
			var band_name: String = ai_bands[band_index]["label"] if band_index < ai_bands.size() else "Neighbors"
			_event("SHARED CAMP  /  %s trade trails and stories (now friendly). Food −%d, knowledge +%d, cohesion +%d. %s" % [band_name, SHARE_CAMP_FOOD_COST, knowledge_gain, cohesion_gain, _nearest_undiscovered_landmark_hint()])
		"kinship":
			kinship_recorded = true
			var cohesion_gain := mini(6, 100 - cohesion)
			cohesion += cohesion_gain
			_event("NEANDERTHAL MEETING  /  Two human groups share a refuge. Food −5, cohesion +%d. Shared descendants recorded." % cohesion_gain)
		"mate":
			succession_turn = turn + SUCCESSION_SEASONS
			_event("PAIRING  /  You form a pair with an adult from a neighboring band. Food −%d. Your offspring takes over in %d seasons." % [MATING_FOOD_COST, SUCCESSION_SEASONS])
	_refresh_ui()
	_redraw_dynamic()


func _tick_band_attitudes_and_wounds(entering_dry: bool) -> void:
	if wounded_seasons > 0:
		var heal := 2 if food > 55 else 1
		wounded_seasons = maxi(0, wounded_seasons - heal)
		if wounded_seasons == 0:
			_event("WOUNDS HEALED  /  Your injuries mend and your stride returns.")
	for animal in wildlife:
		if int(animal.get("slain_seasons", 0)) > 0:
			animal["slain_seasons"] = int(animal["slain_seasons"]) - 1
	var newly_hostile: Array[String] = []
	for i in range(ai_bands.size()):
		var band: Dictionary = ai_bands[i]
		if entering_dry:
			var recently_shared := int(band_share_ready_turn.get(i, 0)) > turn
			if _is_paranthropus_band(i):
				band["attitude"] = "hostile"
				newly_hostile.append(str(band["label"]))
			elif i < 2 and not recently_shared and ((turn + i) % 2 == 1):
				band["attitude"] = "hostile"
				newly_hostile.append(str(band["label"]))
			elif str(band.get("attitude", "friendly")) == "friendly" and i < 2 and not recently_shared:
				band["attitude"] = "wary"
		else:
			if str(band.get("attitude", "friendly")) == "hostile":
				band["attitude"] = "wary"
	if not newly_hostile.is_empty():
		_event("TERRITORIAL TENSION  /  Dry-season scarcity turns %s hostile. Evade them or arm with flint and stone flaking." % ", ".join(newly_hostile))


func _advance_season() -> void:
	if _run_ended():
		return
	var was_dry := turn % 2 == 1
	var tile: Vector2i = world.tile_from_world(player_actor["position"])
	var next_turn := turn + 1
	var entering_dry := next_turn % 2 == 1
	var inland := not world.near_permanent_water(tile)
	if was_dry and inland and int(pack["gourd"]) > 0:
		pack["gourd"] = int(pack["gourd"]) - 1
		_spawn_floating_text("Water Gourd emptied", player_actor["position"], Color("#efd69d"))
	turn = next_turn
	adult_age += 1
	if carried_ember_seasons > 0:
		carried_ember_seasons -= 1
	_tick_depleted_tiles(not entering_dry)
	_tick_carcass_sites()
	_tick_wildfires(entering_dry)
	_replenish_collectibles(entering_dry, 5)
	_tick_band_attitudes_and_wounds(entering_dry)
	year_bp = max(0, year_bp - 100)
	var low_food_penalty := LOW_FOOD_COHESION_PENALTY
	if _has_skill("windbreaks") and (world.terrain_at(tile) == "highland" or tile == WORLD_MAP_SCRIPT.SHELTERED_CLIFF_TILE):
		low_food_penalty = WINDBREAKS_LOW_FOOD_COHESION_PENALTY
	var cohesion_delta := 2 if food > 25 else (low_food_penalty if food > 0 else STARVATION_COHESION_PENALTY)
	cohesion = clampi(cohesion + cohesion_delta, 0, 100)
	if entering_dry and inland and _has_skill("hide_working"):
		cohesion = clampi(cohesion + 2, 0, 100)
	if carried_ember_seasons > 0:
		cohesion = clampi(cohesion + 1, 0, 100)
	_complete_succession()
	if adult_age >= AGING_COHESION_AGE and succession_turn < 0 and turn < CHRONICLE_TURNS:
		cohesion = maxi(0, cohesion - 2)
		if not aging_warned:
			aging_warned = true
			_event("AGING GENERATION  /  Without an heir stepping forward, your aging adult strains to hold the band together (−2 cohesion/season). Pair with a neighboring band.")
	if food > 0:
		starvation_warned = false
	if cohesion == 0:
		lineage_ended = true
		_cancel_active_task(false)
		movement_key = KEY_NONE
		player_actor["route"] = []
		_event("LINEAGE LOST  /  Without enough food and cohesion, your band scatters across the Rift Valley.")
		_refresh_ui()
		_show_summary_overlay()
		_mark_all_chunks_dirty()
		_redraw_dynamic()
		_sync_wildlife()
		return
	if food == 0 and not starvation_warned:
		starvation_warned = true
		_event("STORES EMPTY  /  Without food, cohesion drops rapidly (%d per season). Forage soon before your band scatters." % STARVATION_COHESION_PENALTY)
	if turn == 1:
		_event("Dry season arrives. Stay near rivers, lakes, or springs to conserve food.")
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
		_event("Homo erectus emerges. Longer legs carry one human lineage swiftly across the valley.")
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
	if turn == CHRONICLE_TURNS:
		_cancel_active_task(false)
		_event("The chronicle reaches the present. Many branches end; traces of kinship remain.")
	_refresh_ui()
	if turn == CHRONICLE_TURNS:
		_show_summary_overlay()
	_mark_all_chunks_dirty()
	_redraw_dynamic()
	_sync_wildlife()


func _season_action_blocker() -> String:
	if lineage_ended:
		return "Your lineage has scattered. Start a new chronicle."
	if turn >= CHRONICLE_TURNS:
		return "The chronicle is complete."
	if not active_task.is_empty():
		return "Busy — finish or move to cancel your current action."
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
	var fire_info: Dictionary = wildfire_tiles.get(world.tile_id(tile), {})
	var fire_state: String = fire_info.get("state", "")
	if fire_state == "burning":
		return 0
	if yield_on_terrain > 0:
		if not is_dry and _has_skill("plant_lore") and terrain in ["woodland", "wetland"]:
			yield_on_terrain += 4
		if is_dry and _has_skill("food_drying") and not world.near_permanent_water(tile):
			yield_on_terrain += 3
		if _has_skill("stone_flaking") and terrain in ["savanna", "dryland", "volcanic"]:
			yield_on_terrain += 4
		if fire_state == "cooled" and not fire_info.get("foraged", false):
			yield_on_terrain += 10
		elif fire_state == "regrowth":
			yield_on_terrain += 4
	return mini(yield_on_terrain, 100 - food)


func _scavenge_food_gain(tile: Vector2i) -> int:
	if not carcass_sites.has(world.tile_id(tile)):
		return 0
	var base := SCAVENGE_FLAKING_FOOD if _has_skill("stone_flaking") else SCAVENGE_BASE_FOOD
	return mini(base, 100 - food)


func _hunt_food_gain() -> int:
	var base := HUNT_COOPERATIVE_FOOD if turn >= 25 else HUNT_BASE_FOOD
	if int(pack["stone"]) > 0:
		base += 6
	return mini(base, 100 - food)


func _on_gather() -> void:
	if not _season_action_blocker().is_empty():
		return
	var tile: Vector2i = world.tile_from_world(player_actor["position"])
	var tile_id: int = world.tile_id(tile)
	var pred := _nearby_fightable_predator()
	if not pred.is_empty():
		_start_task("fight_predator", "fighting", TASK_FIGHT_DURATION, {"species": str(pred["species"])})
		return
	if carcass_sites.has(tile_id):
		if _scavenge_food_gain(tile) == 0:
			return
		_start_task("scavenge", "scavenging", TASK_SCAVENGE_DURATION)
		return
	var prey := _nearby_huntable_prey()
	if not prey.is_empty():
		if _hunt_food_gain() == 0:
			return
		_start_task("hunt", "hunting", TASK_HUNT_DURATION, {"species": str(prey["species"])})
		return
	if _forage_food_gain(tile) == 0:
		return
	_start_task("forage", "gathering", TASK_FORAGE_DURATION)


func _on_explore() -> void:
	if not _season_action_blocker().is_empty():
		return
	var tile: Vector2i = world.tile_from_world(player_actor["position"])
	if _unmapped_scout_tiles(tile) == 0:
		return
	_start_task("scout", "scouting", TASK_SCOUT_DURATION)


func _on_learn() -> void:
	var tile: Vector2i = world.tile_from_world(player_actor["position"])
	if _can_recover_ember(tile):
		if not _season_action_blocker().is_empty():
			return
		_start_task("ember", "learning_at_hearth", TASK_EMBER_DURATION)
		return
	var cost := _practice_food_cost(tile)
	if not _season_action_blocker().is_empty() or food < cost or knowledge >= 99:
		return
	var used_tinder := int(pack["tinder"]) > 0
	if used_tinder:
		pack["tinder"] = int(pack["tinder"]) - 1
	var at_hearth := _has_skill("ember_carrying") or (_has_skill("hearth_keeping") and tile == WORLD_MAP_SCRIPT.SHELTERED_CLIFF_TILE) or year_bp <= HEARTH_KEEPING_KA
	_change_food(-float(cost))
	_start_task("practice", "learning_at_hearth" if at_hearth else "learning", TASK_PRACTICE_DURATION, {"food_paid": float(cost), "used_tinder": used_tinder})


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
	knowledge -= int(skill["cost"])
	learned_skills[skill_id] = true
	if skill_id == "hide_working":
		hide_wrap_unlocked = true
	_start_player_activity("learning_at_hearth" if skill_id in ["hearth_keeping", "ember_carrying"] else "learning", 1.8)
	_event(str(skill["chronicle"]))
	_refresh_ui()
	_sync_hominin_models()
	_redraw_dynamic()


func _nearby_hostile_band() -> int:
	var position: Vector2 = player_actor["position"]
	for i in range(ai_bands.size()):
		if str(ai_bands[i].get("attitude", "friendly")) != "hostile":
			continue
		if float(ai_bands[i].get("skirmish_cooldown", 0.0)) > 0.0:
			continue
		var band_position: Vector2 = ai_bands[i]["position"]
		if position.distance_squared_to(band_position) <= MATE_RANGE * MATE_RANGE and world.land_segment_clear(position, band_position):
			return i
	return -1


func _nearby_shareable_band() -> int:
	var position: Vector2 = player_actor["position"]
	for i in range(ai_bands.size()):
		if _is_paranthropus_band(i) or str(ai_bands[i].get("attitude", "friendly")) == "hostile":
			continue
		var band_position: Vector2 = ai_bands[i]["position"]
		if position.distance_squared_to(band_position) <= MATE_RANGE * MATE_RANGE and world.land_segment_clear(position, band_position):
			return i
	return -1


func _nearest_undiscovered_landmark_hint() -> String:
	var player_tile: Vector2i = world.tile_from_world(player_actor["position"])
	var best: Dictionary = {}
	var best_dist := INF
	for landmark in WORLD_MAP_SCRIPT.LANDMARKS:
		if discovered_landmark_names.has(str(landmark["name"])):
			continue
		var d := player_tile.distance_squared_to(landmark["tile"])
		if d < best_dist:
			best_dist = d
			best = landmark
	if best.is_empty():
		return "They admire your knowledge of every landmark in the valley."
	var delta: Vector2 = world.tile_center(best["tile"].x, best["tile"].y) - player_actor["position"]
	var vertical := "north" if delta.y < -40.0 else ("south" if delta.y > 40.0 else "")
	var horizontal := "west" if delta.x < -40.0 else ("east" if delta.x > 40.0 else "")
	var compass := vertical + horizontal
	if compass.is_empty():
		compass = "nearby"
	return "They speak of %s to the %s." % [best["name"], compass]


func _on_encounter() -> void:
	if not _season_action_blocker().is_empty():
		return
	var hostile_idx := _nearby_hostile_band()
	if hostile_idx >= 0 and turn < 31:
		_resolve_band_skirmish(hostile_idx, true)
		return
	if turn < 31:
		if not _share_camp_blocker().is_empty():
			return
		var band_index := _nearby_shareable_band()
		_change_food(-float(SHARE_CAMP_FOOD_COST))
		_start_task("share", "meeting", TASK_SHARE_DURATION, {"food_paid": float(SHARE_CAMP_FOOD_COST), "band_index": band_index})
		return
	if not _kinship_blocker().is_empty():
		return
	_change_food(-5.0)
	_start_task("kinship", "meeting", TASK_KINSHIP_DURATION, {"food_paid": 5.0})


func _share_camp_blocker() -> String:
	var band_index := _nearby_shareable_band()
	if band_index < 0:
		return "Approach an eligible neighboring band to share camp."
	var ready_turn := int(band_share_ready_turn.get(band_index, 0))
	if turn < ready_turn:
		return "Shared recently — return in %d season(s)." % (ready_turn - turn)
	if food < SHARE_CAMP_FOOD_COST:
		return "Sharing camp requires %d food." % SHARE_CAMP_FOOD_COST
	return ""


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
		if _is_paranthropus_band(i) or str(ai_bands[i].get("attitude", "friendly")) == "hostile":
			continue
		var band_position: Vector2 = ai_bands[i]["position"]
		if position.distance_squared_to(band_position) <= MATE_RANGE * MATE_RANGE and world.land_segment_clear(position, band_position):
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
	_change_food(-float(MATING_FOOD_COST))
	_start_task("mate", "pairing", TASK_MATE_DURATION, {"food_paid": float(MATING_FOOD_COST)})


func _complete_succession() -> void:
	if turn != succession_turn:
		return
	succession_turn = -1
	generation += 1
	adult_age = 0
	aging_warned = false
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


func _refresh_stats_bar() -> void:
	if not is_instance_valid(stats_label):
		return
	var gen_text := "%d · aging" % generation if adult_age >= AGING_RANGE_PENALTY_AGE else str(generation)
	var wound_tag := "   ◇   WOUNDED" if wounded_seasons > 0 else ""
	stats_label.text = "FOOD   %d   ◇   KNOWLEDGE   %d   ◇   COHESION   %d   ◇   GEN   %s%s" % [food, knowledge, cohesion, gen_text, wound_tag]


func _refresh_ui() -> void:
	if not is_instance_valid(stats_label):
		return
	age_label.text = _format_year(year_bp)
	period_label.text = _period_name()
	_refresh_stats_bar()
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
	_redraw_dynamic()


func _refresh_action_label() -> void:
	if not is_instance_valid(action_label):
		return
	var tile: Vector2i = world.tile_from_world(player_actor["position"])
	var terrain: String = world.terrain_at(tile)
	var status := "Ready"
	if lineage_ended:
		status = "Lineage lost"
	elif turn >= CHRONICLE_TURNS:
		status = "Chronicle complete"
	elif paused:
		status = "Paused"
	elif not active_task.is_empty():
		status = str(active_task["kind"]).capitalize() + "…"
	elif player_actor["position"] != player_actor["target"]:
		status = "Traveling"
	var location := "Spring" if tile in WORLD_MAP_SCRIPT.SPRING_TILES else ("Waterhole" if tile == WORLD_MAP_SCRIPT.SEASONAL_WATERHOLE_TILE else terrain.capitalize())
	var upkeep := _season_food_cost(tile, turn)
	action_label.text = "%s  ·  %s  ·  %s\nFood drain: −%d/season  ·  Mapped: %d / %d\nF: Gather  ·  Q: Scout  ·  K: Skills  ·  Space: Pause" % [_season_name(turn), location, status, upkeep, explored_tiles.size(), WORLD_MAP_SCRIPT.WORLD_WIDTH * WORLD_MAP_SCRIPT.WORLD_HEIGHT]
	_refresh_season_bar(tile)

	var blocker := _season_action_blocker()
	var tile_id: int = world.tile_id(tile)
	var pred := _nearby_fightable_predator()
	var prey := _nearby_huntable_prey()
	if not pred.is_empty():
		var can_slay := _player_combat_strength(true) >= 3
		forage_button.text = "Slay %s" % pred["species"] if can_slay else "Fight %s" % pred["species"]
		forage_button.disabled = not blocker.is_empty()
		forage_button.tooltip_text = blocker if not blocker.is_empty() else ("Strike down this %s (leaves a rich carcass, +5 cohesion, +4 knowledge)." % pred["species"] if can_slay else "Clash to drive off this %s (−2 food, +3 cohesion)." % pred["species"])
	elif carcass_sites.has(tile_id):
		var scavenge_yield := _scavenge_food_gain(tile)
		forage_button.text = "Scavenge +%d" % scavenge_yield
		forage_button.disabled = not blocker.is_empty() or scavenge_yield == 0
		forage_button.tooltip_text = blocker if not blocker.is_empty() else ("Food stores are full." if food == 100 else "Scavenge %d food from a predator kill (+2 cohesion)." % scavenge_yield)
	elif not prey.is_empty():
		var hunt_yield := _hunt_food_gain()
		forage_button.text = "Hunt +%d" % hunt_yield
		forage_button.disabled = not blocker.is_empty() or hunt_yield == 0
		var hunt_note := "+3 cohesion" if turn >= 25 else "−1 cohesion"
		forage_button.tooltip_text = blocker if not blocker.is_empty() else ("Food stores are full." if food == 100 else "Hunt nearby %s for %d food (%s)." % [prey["species"], hunt_yield, hunt_note])
	else:
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

	var can_ember := _can_recover_ember(tile)
	if can_ember:
		learn_button.text = "Take ember"
		learn_button.disabled = not blocker.is_empty()
		learn_button.tooltip_text = blocker if not blocker.is_empty() else "Recover a live ember from this cooled burn scar (+12 knowledge, no food cost)."
	else:
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

	if turn < 31:
		var hostile_idx := _nearby_hostile_band()
		if hostile_idx >= 0:
			var p_str := _player_combat_strength(true)
			var e_str := _band_combat_strength(hostile_idx)
			kinship_button.text = "Clash (%dv%d)" % [p_str, e_str]
			kinship_button.disabled = not blocker.is_empty()
			kinship_button.tooltip_text = blocker if not blocker.is_empty() else "Engage %s in a skirmish (your strength %d vs %d). Victory seizes +14 food; defeat risks a raid & wound." % [ai_bands[hostile_idx]["label"], p_str, e_str]
		else:
			var share_blocker := _share_camp_blocker()
			kinship_button.text = "Share −%d" % SHARE_CAMP_FOOD_COST
			kinship_button.disabled = not blocker.is_empty() or not share_blocker.is_empty()
			kinship_button.tooltip_text = blocker if not blocker.is_empty() else share_blocker
			if kinship_button.tooltip_text.is_empty():
				kinship_button.tooltip_text = "Share %d food with a nearby band for +6 knowledge, +4 cohesion, calm tensions, and a landmark tip." % SHARE_CAMP_FOOD_COST
	else:
		var kinship_blocker := _kinship_blocker()
		kinship_button.text = "Meet kin"
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
		btn.tooltip_text = learn_blocker if btn.disabled else "Spend %d knowledge to learn %s immediately." % [int(skill["cost"]), skill["name"]]


func _refresh_mate_button(action_blocker: String) -> void:
	mate_button.text = "Heir in %d" % (succession_turn - turn) if succession_turn >= 0 else "Find mate"
	var blocker := action_blocker
	if not _run_ended() and (succession_turn >= 0 or blocker.is_empty()):
		blocker = _mating_blocker()
	mate_button.disabled = not blocker.is_empty()
	mate_button.tooltip_text = blocker if mate_button.disabled else "Spend %d food (%.1fs) to pair. Continue as your offspring in %d seasons." % [MATING_FOOD_COST, TASK_MATE_DURATION, SUCCESSION_SEASONS]


func _refresh_season_bar(tile: Vector2i) -> void:
	if not is_instance_valid(season_bar_fill):
		return
	var ended := _run_ended()
	season_bar_bg.visible = not ended
	season_bar_fill.visible = not ended
	season_bar_label.visible = not ended
	pause_button.visible = not ended
	speed_button.visible = not ended
	advance_button.visible = ended
	if ended:
		advance_button.disabled = false
		advance_button.text = "NEW CHRONICLE  ›"
		advance_button.tooltip_text = "Your band scattered. Begin a new chronicle from 3.2 Ma." if lineage_ended else "The chronicle is complete. Begin a new run from 3.2 Ma."
		return
	var fraction := clampf(season_elapsed / SEASON_DURATION, 0.0, 1.0)
	var secs_left := ceili(maxf(0.0, SEASON_DURATION - season_elapsed))
	var next_season := _season_name(turn + 1).to_upper()
	var is_dry := turn % 2 == 1
	var dry_warning := (not is_dry) and secs_left <= 6 and not world.near_permanent_water(tile)
	season_bar_fill.size.x = 254.0 * fraction
	if dry_warning:
		season_bar_fill.color = Color("#d46f3e")
	else:
		season_bar_fill.color = Color("#c28a48") if is_dry else Color("#4b8378")
	if paused:
		season_bar_label.text = "PAUSED  ·  %s IN %ds" % [next_season, secs_left]
	elif dry_warning:
		season_bar_label.text = "DRY IN %ds  ·  SEEK WATER" % secs_left
	else:
		season_bar_label.text = "%s  ·  %s IN %ds" % [_season_name(turn).to_upper(), next_season, secs_left]
	pause_button.text = "Resume (Space)" if paused else "Pause (Space)"
	speed_button.text = "Speed 2×" if time_scale > 1.5 else "Speed 1×"


func _set_player_destination(tile: Vector2i, announce := true, direct := false) -> void:
	if _run_ended():
		return
	if not active_task.is_empty():
		_cancel_active_task(true)
	if announce:
		movement_key = KEY_NONE
	if not _route_actor_to(player_actor, tile, direct):
		if announce:
			var tile_id: int = world.tile_id(tile)
			var message := "Active wildfire — wait until flames cool." if wildfire_tiles.get(tile_id, {}).get("state", "") == "burning" else ("Pick a destination on land." if not world.has_land_route_point(tile) else "No land route leads there.")
			_show_toast(message)
		return
	player_actor["activity"] = "walking"
	player_actor["action_time"] = 0.0
	_refresh_action_label()
	if announce:
		var location: String = map_names[(tile.x + tile.y * 2) % map_names.size()]
		_show_toast("You travel toward %s." % location)
	_redraw_dynamic()


func _continue_keyboard_movement(delta: float) -> void:
	if movement_key == KEY_NONE or _run_ended():
		movement_key = KEY_NONE
		return
	if not Input.is_key_pressed(movement_key):
		movement_key = KEY_NONE
		return
	var position: Vector2 = player_actor["position"]
	var target: Vector2 = player_actor["target"]
	var speed := _player_speed()
	var braking_distance := speed * speed / (2.0 * TRAVEL_ACCELERATION)
	if player_actor["route"].is_empty() and position.distance_to(target) <= braking_distance + speed * delta:
		_set_player_destination(world.tile_from_world(target) + keyboard_step, false, true)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if is_instance_valid(summary_overlay) and summary_overlay.visible:
				_on_close_summary()
				get_viewport().set_input_as_handled()
				return
			if is_instance_valid(skills_overlay) and skills_overlay.visible:
				_on_toggle_skills()
				get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_K and not (is_instance_valid(summary_overlay) and summary_overlay.visible):
			_on_toggle_skills()
			get_viewport().set_input_as_handled()
			return
	if (is_instance_valid(skills_overlay) and skills_overlay.visible) or (is_instance_valid(summary_overlay) and summary_overlay.visible):
		return
	if event is InputEventMagnifyGesture:
		if MAP_VIEW.has_point(event.position) and event.factor > 0.0:
			_set_zoom(zoom_level * event.factor, event.position)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventPanGesture:
		if MAP_VIEW.has_point(event.position) and absf(event.delta.y) > 0.0001:
			var step := exp(clampf(-event.delta.y * 0.14, -0.35, 0.35))
			_set_zoom(zoom_level * step, event.position)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if MAP_VIEW.has_point(event.position):
			var strength: float = event.factor if event.factor > 0.0 else 1.0
			var step := pow(1.15, clampf(strength, 0.15, 2.0))
			var factor := step if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / step
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
		_sync_map_transform()
		_position_wildlife_models()
		_sync_hominin_models()
		_redraw_dynamic()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_on_toggle_pause()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_1:
			_set_speed(1.0)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_2:
			_set_speed(2.0)
			get_viewport().set_input_as_handled()
			return
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
		if event.keycode in [KEY_F, KEY_E]:
			_on_gather()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_Q:
			_on_explore()
			get_viewport().set_input_as_handled()
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
