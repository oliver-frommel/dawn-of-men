extends Node3D

var species := ""
var figure: Node3D
var legs: Array[Node3D] = []
var head: Node3D
var tail: Node3D
var gait_phase := 0.0
var gait_speed := 2.0
var is_predator := false
var is_moving := false
var opaque_materials: Dictionary[MeshInstance3D, StandardMaterial3D] = {}
var fade_materials: Dictionary[StandardMaterial3D, StandardMaterial3D] = {}

func configure(species_name: String, phase: float) -> void:
	species = species_name
	gait_phase = phase

func _ready() -> void:
	_build()
	set_process(true)

func set_opacity(opacity: float) -> void:
	visible = opacity > 0.0
	if opacity >= 1.0 or opacity <= 0.0:
		for mesh in opaque_materials:
			mesh.material_override = opaque_materials[mesh]
		opaque_materials.clear()
		fade_materials.clear()
		return
	if fade_materials.is_empty():
		for child in figure.find_children("*", "MeshInstance3D", true, false):
			var mesh := child as MeshInstance3D
			var original := mesh.material_override as StandardMaterial3D
			if not fade_materials.has(original):
				var material := original.duplicate() as StandardMaterial3D
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
				fade_materials[original] = material
			opaque_materials[mesh] = original
			mesh.material_override = fade_materials[original]
	for material in fade_materials.values():
		var tint: Color = material.albedo_color
		tint.a = opacity
		material.albedo_color = tint

func set_moving(moving: bool) -> void:
	is_moving = moving
	if not moving:
		_reset_pose()

func _process(delta: float) -> void:
	if not is_instance_valid(figure):
		return
	gait_phase = fposmod(gait_phase + delta * (gait_speed if is_moving else 0.76), TAU * 10.0)
	if not is_moving:
		head.rotation.x = sin(gait_phase) * 0.025
		head.rotation.y = sin(gait_phase * 0.7) * 0.055
		tail.rotation.y = sin(gait_phase * 1.4) * 0.12
		return
	var stride := sin(gait_phase) * 0.25
	for i in range(legs.size()):
		var side := 1.0 if i % 2 == 0 else -1.0
		var pair := 1.0 if i < 2 else -1.0
		legs[i].rotation.x = stride * side * pair
	figure.position.y = 0.012 * absf(sin(gait_phase * 2.0))
	if is_instance_valid(head):
		head.rotation.x = sin(gait_phase * 0.5) * 0.035
	if is_instance_valid(tail):
		tail.rotation.x = sin(gait_phase * 1.3) * 0.12

func _reset_pose() -> void:
	if not is_instance_valid(figure):
		return
	for leg in legs:
		leg.rotation.x = 0.0
	figure.position.y = 0.0
	if is_instance_valid(head):
		head.rotation.x = 0.0
	if is_instance_valid(tail):
		tail.rotation.x = 0.0

func _build() -> void:
	figure = Node3D.new()
	figure.rotation.y = 0.82
	add_child(figure)
	var coat_color := Color("#8d7048")
	var dark_color := Color("#493a2b")
	var mane_color := Color("#30251e")
	var cream_color := Color("#c4a87b")
	var hoof_color := Color("#382d25")
	var animal_scale := 1.0
	var body_length := 0.76
	var body_height := 0.28
	var leg_length := 0.76
	var head_size := Vector3(0.13, 0.13, 0.15)
	var neck_length := 0.30
	var long_neck := false
	var trunk := false
	var heavy := false
	var horns := false
	is_predator = species == "Dinofelis" or species == "Lion"
	match species:
		"Hipparion":
			coat_color = Color("#a57a4d")
			body_length = 0.79
			leg_length = 0.76
			neck_length = 0.35
			gait_speed = 2.7
		"Antelope", "Gazelle":
			coat_color = Color("#b08a56")
			body_length = 0.66
			leg_length = 0.78
			head_size = Vector3(0.105, 0.11, 0.12)
			horns = true
			gait_speed = 2.4
		"Zebra":
			coat_color = Color("#d7cfb5")
			body_length = 0.81
			leg_length = 0.78
			neck_length = 0.36
			gait_speed = 2.5
		"Wildebeest", "Buffalo":
			heavy = true
			coat_color = Color("#71604a")
			body_length = 0.83
			body_height = 0.34
			leg_length = 0.70
			head_size = Vector3(0.15, 0.15, 0.16)
			horns = true
		"Sivatherium":
			coat_color = Color("#8c7350")
			body_length = 0.92
			body_height = 0.38
			leg_length = 0.79
			neck_length = 0.46
			heavy = true
			horns = true
			animal_scale = 1.18
		"Giraffe":
			coat_color = Color("#b48d4b")
			body_length = 0.82
			leg_length = 0.92
			neck_length = 0.84
			long_neck = true
			animal_scale = 1.14
		"Deinotherium":
			coat_color = Color("#756952")
			body_length = 1.05
			body_height = 0.49
			leg_length = 0.70
			head_size = Vector3(0.24, 0.25, 0.23)
			trunk = true
			heavy = true
			animal_scale = 1.28
		"Elephant":
			coat_color = Color("#777567")
			body_length = 1.03
			body_height = 0.46
			leg_length = 0.70
			head_size = Vector3(0.23, 0.23, 0.23)
			trunk = true
			heavy = true
			animal_scale = 1.25
		"Dinofelis", "Lion":
			coat_color = Color("#a0804b") if species == "Dinofelis" else Color("#b38d50")
			dark_color = Color("#392b22")
			body_length = 0.88
			body_height = 0.27
			leg_length = 0.51
			head_size = Vector3(0.126, 0.118, 0.14)
			neck_length = 0.10
			animal_scale = 0.90
			is_predator = true
	var coat := _material(coat_color)
	var dark := _material(dark_color)
	var mane := _material(mane_color)
	var cream := _material(cream_color)
	var hoof := _material(hoof_color)
	var hip := leg_length
	var shoulder := hip + body_height * 0.46
	var width := 0.29 if trunk else (0.23 if heavy else 0.18)
	var torso_center := hip + body_height * 0.34
	_build_torso(body_length, body_height, width, torso_center, coat_color)
	for i in range(4):
		var front := i % 2 == 0
		var side := -1.0 if i < 2 else 1.0
		var z := body_length * (0.36 if front else -0.36)
		var y := shoulder if front else hip + body_height * 0.27
		var leg := _pivot(figure, Vector3(side * width * 0.67, y, z), "Leg%d" % i)
		legs.append(leg)
		var joint := Vector3(0, -y * 0.47, -0.02 if front else 0.09)
		var hock := Vector3(0, -y * 0.74, -0.025 if front else -0.065)
		var foot := Vector3(0, -y + 0.045, 0.015)
		var upper_width := 0.108 if trunk else (0.079 if heavy or is_predator else 0.065)
		var lower_width := 0.066 if trunk else (0.038 if is_predator or heavy else 0.027)
		_add_ellipsoid(leg, "UpperMuscle", joint * 0.32, Vector3(upper_width, y * 0.22, upper_width * 1.30), coat)
		_add_segment(leg, Vector3.ZERO, joint, upper_width, lower_width * 1.2, coat)
		_add_segment(leg, joint, hock, lower_width * 1.2, lower_width, coat)
		_add_segment(leg, hock, foot, lower_width, lower_width * 0.83, coat)
		var foot_length := lower_width * (1.6 if is_predator else 1.3)
		_add_ellipsoid(leg, "Foot", foot + Vector3(0, -0.014, 0.021), Vector3(lower_width * 1.15, 0.031, foot_length), coat if is_predator else hoof)

	var neck_base := Vector3(0, shoulder + body_height * 0.27, body_length * 0.36)
	var neck_end := neck_base + Vector3(0, neck_length, 0.14 if long_neck else 0.20)
	if is_predator or trunk:
		neck_end = neck_base + Vector3(0, body_height * 0.25, 0.19)
	_add_segment(figure, neck_base, neck_end, width * 0.86, head_size.x * 0.77, coat)
	if species in ["Hipparion", "Zebra", "Wildebeest"]:
		var crest_base := neck_base + Vector3(0, 0.09, -0.124)
		var crest_top := neck_end + Vector3(0, 0.082, -0.079)
		_add_segment(figure, crest_base, crest_top, 0.061, 0.040, mane)
	head = _pivot(figure, neck_end, "HeadPivot")
	if species == "Lion":
		_add_ellipsoid(head, "Mane", Vector3(0, -0.025, -0.055), Vector3(0.174, 0.177, 0.177), mane)
	_add_ellipsoid(head, "Skull", Vector3(0, 0, 0.041), head_size, coat)
	var muzzle := Vector3(0, -head_size.y * 0.59, head_size.z * 0.93)
	if not trunk:
		var muzzle_length := head_size.z * (0.64 if is_predator else 0.82)
		_add_ellipsoid(head, "Jaw", muzzle, Vector3(head_size.x * 0.67, head_size.y * 0.47, muzzle_length), coat)
		_add_ellipsoid(head, "Nose", muzzle + Vector3(0, 0.018, muzzle_length * 0.76), Vector3(head_size.x * 0.48, 0.028, 0.023), dark)

	for side in [-1.0, 1.0]:
		var eye := Vector3(side * head_size.x * 0.89, head_size.y * 0.26, head_size.z * 0.51)
		_add_ellipsoid(head, "Eye", eye, Vector3(0.010, 0.014, 0.017), dark)
		if trunk:
			_add_ellipsoid(head, "Ear", Vector3(side * 0.19, -0.015, -0.07), Vector3(0.12, 0.22, 0.039), coat)
		elif is_predator:
			_add_ellipsoid(head, "Ear", Vector3(side * 0.082, 0.093, 0.01), Vector3(0.036, 0.039, 0.024), coat)
		else:
			_add_segment(head, Vector3(side * head_size.x * 0.67, 0.075, -0.015), Vector3(side * head_size.x * 1.28, 0.177, -0.04), 0.041, 0.009, coat)
		if horns or long_neck:
			var root := Vector3(side * head_size.x * 0.49, head_size.y * 0.79, 0.009)
			var bend := root + Vector3(side * (0.19 if heavy else 0.027), 0.048, -0.035)
			var tip := bend + Vector3(side * (0.018 if heavy else 0.013), 0.19 if species == "Sivatherium" else (0.06 if long_neck or heavy else 0.13), -0.044)
			_add_segment(head, root, bend, 0.043 if heavy else 0.025, 0.020, hoof)
			_add_segment(head, bend, tip, 0.020, 0.007, hoof)
	if trunk:
		_build_trunk(coat, cream)

	var tail_root := Vector3(0, torso_center + body_height * 0.45, -body_length * 0.49)
	tail = _pivot(figure, tail_root, "Tail")
	var tail_joint := Vector3(0, -0.06, -0.23)
	var tail_tip := Vector3(0, -0.32, -0.28)
	if is_predator:
		tail_joint = Vector3(0, -0.12, -0.29)
		tail_tip = Vector3(0.09, -0.09, -0.57)
	_add_segment(tail, Vector3.ZERO, tail_joint, 0.028, 0.023, coat)
	_add_segment(tail, tail_joint, tail_tip, 0.023, 0.013, coat)
	_add_ellipsoid(tail, "TailTip", tail_tip, Vector3(0.031, 0.042, 0.035), dark)
	figure.scale = Vector3.ONE * animal_scale

func _build_trunk(coat: Material, ivory: Material) -> void:
	var previous := Vector3(0, -0.04, 0.21)
	for i in range(1, 10):
		var t := float(i) / 9.0
		var point := Vector3(0, -0.04 - 0.56 * t, 0.21 + 0.03 * sin(PI * t) + 0.18 * pow(t, 4.0))
		var radius := lerpf(0.087, 0.030, t)
		_add_segment(head, previous, point, radius + 0.006, radius, coat)
		_add_ellipsoid(head, "TrunkJoint", point, Vector3.ONE * radius, coat)
		previous = point
	for side in [-1.0, 1.0]:
		var root := Vector3(side * 0.11, -0.08, 0.17)
		var bend := root + (Vector3(side * 0.018, -0.14, 0.06) if species == "Deinotherium" else Vector3(side * 0.034, -0.10, 0.17))
		var tip := bend + (Vector3(0.0, -0.17, -0.045) if species == "Deinotherium" else Vector3(side * 0.018, 0.035, 0.16))
		_add_segment(head, root, bend, 0.034, 0.022, ivory)
		_add_ellipsoid(head, "TuskCurve", bend, Vector3.ONE * 0.022, ivory)
		_add_segment(head, bend, tip, 0.022, 0.003, ivory)

func _build_torso(length: float, depth: float, width: float, center: float, coat_color: Color) -> void:
	# Cross-sections follow the rump, waist, ribs and shoulder in one surface.
	var sections := [
		Vector3(-0.60, 0.02, 0.02), Vector3(-0.51, 0.67, 0.67),
		Vector3(-0.36, 0.94, 0.89), Vector3(-0.17, 0.80, 0.81),
		Vector3(0.06, 1.0, 0.96), Vector3(0.30, 0.94, 1.0),
		Vector3(0.46, 0.70, 0.81), Vector3(0.57, 0.03, 0.04)
	]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 22
	var patterned := species == "Giraffe" or species == "Sivatherium"
	var subdivisions := 8 if species == "Zebra" or patterned else 3
	var rows := (sections.size() - 1) * subdivisions + 1
	for row in range(rows):
		var section_index := mini(floori(float(row) / subdivisions), sections.size() - 2)
		var from: Vector3 = sections[section_index]
		var to: Vector3 = sections[section_index + 1]
		var progress := clampf(float(row - section_index * subdivisions) / subdivisions, 0.0, 1.0)
		var section := from.lerp(to, progress)
		for side in range(sides + 1):
			var u := float(side) / float(sides)
			var angle := u * TAU
			var x := cos(angle)
			var y := sin(angle)
			var warm := coat_color.lerp(Color("#b8a37d"), 0.14 + y * 0.11)
			var z := section.x * length
			var stripes := sin(51.0 * z + 3.2 * y + 2.6 * sin(12.0 * z + y * 3.2))
			if species == "Zebra" and stripes > 0.10:
				warm = Color("#3c3832").lightened(maxf(0.0, y) * 0.10)
			elif patterned:
				var patches := sin(17.0 * z + cos(angle * 3.0)) * cos(angle * 5.0 + z * 4.0)
				if patches > 0.16:
					warm = warm.darkened(0.33)
			surface.set_color(warm)
			surface.add_vertex(Vector3(x * section.y * width, center + depth * section.z * y + z * 0.05, z))
	for row in range(rows - 1):
		for side in range(sides):
			var a := row * (sides + 1) + side
			var b := a + sides + 1
			for index in [a, b, a + 1, b, b + 1, a + 1]:
				surface.add_index(index)
	surface.generate_normals()
	var material := _material(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	var body := MeshInstance3D.new()
	body.name = "Torso"
	body.mesh = surface.commit()
	body.material_override = material
	figure.add_child(body)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.94
	return material

func _pivot(parent: Node3D, point: Vector3, label: String) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.position = point
	parent.add_child(node)
	return node

func _add_segment(parent: Node3D, start: Vector3, finish: Vector3, radius_start: float, radius_end: float, material: Material) -> void:
	var direction := finish - start
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius_end
	mesh.bottom_radius = radius_start
	mesh.height = direction.length()
	mesh.radial_segments = 10
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = (start + finish) * 0.5
	instance.quaternion = Quaternion(Vector3.UP, direction.normalized())
	parent.add_child(instance)

func _add_ellipsoid(parent: Node3D, label: String, center: Vector3, radii: Vector3, material: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 8
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = material
	instance.position = center
	instance.scale = radii
	parent.add_child(instance)
