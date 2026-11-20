extends Node3D
const SKIN_SHADER: Shader = preload("res://assets/hominin_skin.gdshader")
const FUR_SHADER: Shader = preload("res://assets/hominin_fur.gdshader")

var species_stage := 0
var body_variant := 0
var is_robust := false
var wears_wrap := false
var clan_color := Color.WHITE
var figure: Node3D
var upper_body: Node3D
var head: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var left_forearm: Node3D
var right_forearm: Node3D
var left_shin: Node3D
var right_shin: Node3D
var left_ankle: Node3D
var right_ankle: Node3D
var gait_weight := 0.0
var model_opacity := 1.0
var textured_materials: Array[ShaderMaterial] = []
var detail_materials: Array[StandardMaterial3D] = []

const STANCE_FRACTION := 0.60
const FOOT_RADIUS := 0.05
const FOOT_CENTER := 0.07
const FOOT_HALF_SEGMENT := 0.06
const HEAD_PIVOT := Vector3(0.0, 1.35, -0.015)

func configure(stage: int, variant: int, robust: bool, wrap: bool, group_color: Color) -> void:
	species_stage = stage
	body_variant = variant
	is_robust = robust
	wears_wrap = wrap
	clan_color = group_color

func _ready() -> void:
	_build_body()

func set_opacity(opacity: float) -> void:
	if opacity == model_opacity:
		return
	model_opacity = opacity
	visible = opacity > 0.0
	if not visible:
		return
	for material in textured_materials:
		material.set_shader_parameter("model_opacity", opacity)
	var transparency := BaseMaterial3D.TRANSPARENCY_DISABLED if opacity >= 1.0 else BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
	for material in detail_materials:
		if material.transparency != transparency:
			material.transparency = transparency
		var tint := material.albedo_color
		tint.a = opacity
		material.albedo_color = tint

func set_pose(walking: bool, phase: float, heading: Vector2, delta: float) -> void:
	if not is_instance_valid(figure) or not is_instance_valid(upper_body):
		return
	var width_scale := 1.12
	var height_scale := 1.12
	if species_stage == 0:
		width_scale = 1.10
		height_scale = 1.10
	elif species_stage >= 2:
		width_scale = 1.08
		height_scale = 1.16
	if is_robust:
		width_scale = 1.13
		height_scale = 1.10
	var female := body_variant % 3 == 1
	if female:
		width_scale *= 0.94
		height_scale *= 0.96
	elif body_variant % 3 == 2:
		width_scale *= 1.035
		height_scale *= 1.025
	figure.scale = Vector3(width_scale, height_scale, 1.12)
	if heading.length_squared() > 0.0001:
		figure.rotation.y = lerp_angle(figure.rotation.y, atan2(heading.x, heading.y), 1.0 - exp(-14.0 * delta))

	var pose_blend := 1.0 - exp(-12.0 * delta)
	gait_weight = lerpf(gait_weight, float(walking), pose_blend)
	var stoop := 1.0 if species_stage == 0 else (0.6 if is_robust else 0.0)
	var extra_lean := stoop * lerpf(0.10, 0.29, gait_weight)
	var cycle := fposmod(phase / TAU, 1.0)
	var weight_shift := -sin(TAU * (cycle - 0.05)) * gait_weight
	var sideways := Vector3.RIGHT.rotated(Vector3.UP, figure.rotation.y)
	var hip_sway := weight_shift * 0.033
	var thigh_length := -left_shin.position.y
	var shin_length := -left_ankle.position.y
	var standing_height := thigh_length + shin_length - left_leg.position.y + FOOT_RADIUS - 0.035
	standing_height -= stoop * lerpf(0.01, 0.055, gait_weight)
	var rise := -cos(TAU * 2.0 * (cycle - 0.05)) * 0.016 * gait_weight
	figure.position = sideways * hip_sway * width_scale + Vector3.UP * (standing_height + rise) * height_scale

	_pose_leg(left_leg, left_shin, left_ankle, cycle, standing_height + rise, hip_sway, stoop)
	_pose_leg(right_leg, right_shin, right_ankle, fposmod(cycle + 0.5, 1.0), standing_height + rise, hip_sway, stoop)

	var arm_swing := cos(TAU * (cycle - 0.09)) * (0.24 + body_variant * 0.025) * gait_weight
	var arm_rest := 0.035 - extra_lean * 0.8
	left_arm.rotation.x = lerpf(left_arm.rotation.x, arm_rest + arm_swing, pose_blend)
	right_arm.rotation.x = lerpf(right_arm.rotation.x, arm_rest - arm_swing, pose_blend)
	left_forearm.rotation.x = -0.18 - maxf(0.0, -left_arm.rotation.x) * 0.6
	right_forearm.rotation.x = -0.15 - maxf(0.0, -right_arm.rotation.x) * 0.6

	var forward_lean := 0.11 if is_robust else (0.07 if species_stage == 0 else 0.0)
	upper_body.rotation.x = forward_lean + extra_lean + gait_weight * (0.055 + rise * 0.9)
	upper_body.rotation.y = -arm_swing * 0.4
	upper_body.rotation.z = weight_shift * 0.042
	var torso_pivot := Vector3(0.0, 0.69, 0.0)
	upper_body.position = torso_pivot - upper_body.basis * torso_pivot
	head.rotation.x = -extra_lean * 0.8
	head.position = HEAD_PIVOT - head.basis * HEAD_PIVOT


func _pose_leg(hip: Node3D, knee: Node3D, ankle: Node3D, cycle: float, height: float, sway: float, stoop: float) -> void:
	var half_stride := (0.225 + body_variant * 0.008) * gait_weight * (1.0 - stoop * 0.17)
	var forward: float
	var lift := 0.0
	var pitch: float
	if cycle < STANCE_FRACTION:
		var stance := cycle / STANCE_FRACTION
		forward = lerpf(half_stride, -half_stride, stance)
		# Roll from the heel to a flat foot, then push off the toes.
		pitch = -0.24 * (1.0 - smoothstep(0.0, 0.22, stance)) + 0.42 * smoothstep(0.72, 1.0, stance)
	else:
		var swing := (cycle - STANCE_FRACTION) / (1.0 - STANCE_FRACTION)
		forward = lerpf(-half_stride, half_stride, smoothstep(0.0, 1.0, swing))
		lift = sin(PI * swing) * 0.13 * gait_weight
		pitch = lerpf(0.42, -0.24, smoothstep(0.0, 0.83, swing))
	pitch *= gait_weight
	# Offset the ankle so the lowest point of the tilted sole meets the ground.
	var sole_clearance := FOOT_RADIUS + sin(pitch) * FOOT_CENTER + absf(sin(pitch)) * FOOT_HALF_SEGMENT
	var target := Vector3(-sway, sole_clearance + lift - height - hip.position.y, forward)

	# Solve the two leg segments toward the ankle, keeping the knee pointed forward.
	var thigh := -knee.position.y
	var shin := -ankle.position.y
	var reach := clampf(target.length(), absf(thigh - shin) + 0.001, thigh + shin - 0.001)
	var roll := atan2(target.x, -target.y)
	var aim := atan2(target.z, Vector2(target.x, target.y).length())
	var hip_bend := acos(clampf((thigh * thigh + reach * reach - shin * shin) / (2.0 * thigh * reach), -1.0, 1.0))
	var knee_bend := PI - acos(clampf((thigh * thigh + shin * shin - reach * reach) / (2.0 * thigh * shin), -1.0, 1.0))
	hip.basis = Basis(Vector3.BACK, roll) * Basis(Vector3.RIGHT, -aim - hip_bend)
	knee.rotation.x = knee_bend
	ankle.basis = (hip.basis * knee.basis).transposed() * Basis(Vector3.RIGHT, pitch)


func _build_body() -> void:
	figure = Node3D.new()
	figure.name = "AnatomicalFigure"
	add_child(figure)
	upper_body = Node3D.new()
	upper_body.name = "GaitSynchronizedTorso"
	figure.add_child(upper_body)

	var pigments := [Color("#503323"), Color("#633d2a"), Color("#714732")]
	var base_tone: Color = pigments[body_variant % pigments.size()]
	if species_stage == 0:
		base_tone = [Color("#3a2820"), Color("#432d23"), Color("#4b3226")][body_variant % 3]
	elif is_robust:
		base_tone = [Color("#30221c"), Color("#392720"), Color("#422d23")][body_variant % 3]
	var skin := ShaderMaterial.new()
	skin.shader = SKIN_SHADER
	skin.set_shader_parameter("skin_tone", base_tone)
	var face := ShaderMaterial.new()
	face.shader = SKIN_SHADER
	face.set_shader_parameter("skin_tone", base_tone.lightened(0.08))
	var shadow_skin := ShaderMaterial.new()
	shadow_skin.shader = SKIN_SHADER
	shadow_skin.set_shader_parameter("skin_tone", base_tone.darkened(0.23))
	textured_materials.assign([skin, face, shadow_skin])
	var body_surface: Material = skin
	if species_stage == 0:
		var fur := ShaderMaterial.new()
		fur.shader = FUR_SHADER
		var fur_tones := [Color("#765038"), Color("#825a3e"), Color("#6c4833")]
		fur.set_shader_parameter("fur_tone", fur_tones[body_variant % fur_tones.size()])
		textured_materials.append(fur)
		body_surface = fur
	var hair := StandardMaterial3D.new()
	hair.albedo_color = Color("#211711").lightened(float(body_variant) * 0.035)
	hair.roughness = 0.94
	var eye := StandardMaterial3D.new()
	eye.albedo_color = Color("#120f0d")
	eye.roughness = 0.45
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = clan_color.darkened(0.28)
	cloth.roughness = 1.0
	detail_materials.assign([hair, eye, cloth])

	var female := body_variant % 3 == 1
	var shoulder_width := 0.22 if species_stage < 2 else 0.20
	if species_stage == 0:
		shoulder_width = 0.235
	if is_robust:
		shoulder_width = 0.255
	shoulder_width *= 0.90 if female else 1.04
	var torso_profile := PackedVector4Array([
		Vector4(0.62, 0.115, 0.095, 0.000),
		Vector4(0.70, 0.145, 0.110, 0.000),
		Vector4(0.84, 0.150, 0.105, 0.005),
		Vector4(0.98, 0.185, 0.125, 0.000),
		Vector4(1.10, shoulder_width, 0.120, -0.015),
		Vector4(1.18, 0.090, 0.075, -0.020),
		Vector4(1.22, 0.070, 0.065, -0.020)
	])
	if species_stage == 0:
		torso_profile = PackedVector4Array([
			Vector4(0.62, 0.096, 0.084, 0.000),
			Vector4(0.70, 0.116, 0.096, 0.000),
			Vector4(0.84, 0.128, 0.100, 0.008),
			Vector4(0.98, 0.165, 0.116, 0.000),
			Vector4(1.10, shoulder_width, 0.120, -0.012),
			Vector4(1.18, 0.092, 0.076, -0.020),
			Vector4(1.22, 0.070, 0.064, -0.020)
		])
	if is_robust:
		torso_profile = PackedVector4Array([
			Vector4(0.62, 0.098, 0.086, 0.000),
			Vector4(0.70, 0.118, 0.098, 0.000),
			Vector4(0.84, 0.132, 0.102, 0.008),
			Vector4(0.98, 0.176, 0.122, 0.000),
			Vector4(1.10, shoulder_width, 0.126, -0.012),
			Vector4(1.18, 0.096, 0.078, -0.020),
			Vector4(1.22, 0.072, 0.066, -0.020)
		])
	_add_loft(upper_body, "Torso", torso_profile, body_surface, 18)
	if female:
		_add_ellipsoid(upper_body, "LeftBreast", Vector3(-0.076, 0.965, 0.104), Vector3(0.092, 0.105, 0.082), body_surface)
		_add_ellipsoid(upper_body, "RightBreast", Vector3(0.076, 0.965, 0.104), Vector3(0.092, 0.105, 0.082), body_surface)
	else:
		_add_ellipsoid(upper_body, "LeftPectoral", Vector3(-0.078, 0.99, 0.082), Vector3(0.096, 0.073, 0.052), body_surface)
		_add_ellipsoid(upper_body, "RightPectoral", Vector3(0.078, 0.99, 0.082), Vector3(0.096, 0.073, 0.052), body_surface)
	_add_ellipsoid(upper_body, "LeftDeltoid", Vector3(-shoulder_width * 0.92, 1.075, 0.005), Vector3(0.074, 0.105, 0.084), body_surface)
	_add_ellipsoid(upper_body, "RightDeltoid", Vector3(shoulder_width * 0.92, 1.075, 0.005), Vector3(0.074, 0.105, 0.084), body_surface)

	var hip_y := 0.69
	var hip_width := 0.096 if female else 0.082
	_add_ellipsoid(
		upper_body, "Pelvis", Vector3(0.0, hip_y, -0.002),
		Vector3(0.158 if female else 0.132, 0.105, 0.108), body_surface
	)
	var thigh_length := 0.39 if species_stage < 2 else 0.43
	if is_robust:
		thigh_length = 0.37
	left_leg = _make_pivot(figure, Vector3(-hip_width, hip_y, 0.0), "LeftLeg")
	right_leg = _make_pivot(figure, Vector3(hip_width, hip_y, 0.0), "RightLeg")
	left_shin = _make_pivot(left_leg, Vector3(0.0, -thigh_length, 0.0), "LeftShin")
	right_shin = _make_pivot(right_leg, Vector3(0.0, -thigh_length, 0.0), "RightShin")
	var upper_leg_radius := (0.075 if is_robust else 0.073) * (0.94 if female else 1.03)
	_add_segment(left_leg, Vector3.ZERO, Vector3(0.0, -thigh_length, 0.0), upper_leg_radius, upper_leg_radius * 0.72, body_surface)
	_add_segment(right_leg, Vector3.ZERO, Vector3(0.0, -thigh_length, 0.0), upper_leg_radius, upper_leg_radius * 0.72, body_surface)
	_add_ellipsoid(left_shin, "LeftKneecap", Vector3(0.0, 0.0, 0.022), Vector3(0.047, 0.055, 0.032), face)
	_add_ellipsoid(right_shin, "RightKneecap", Vector3(0.0, 0.0, 0.022), Vector3(0.047, 0.055, 0.032), face)
	_add_segment(left_shin, Vector3.ZERO, Vector3(0.0, -0.31, 0.0), upper_leg_radius * 0.68, 0.041, body_surface)
	_add_segment(right_shin, Vector3.ZERO, Vector3(0.0, -0.31, 0.0), upper_leg_radius * 0.68, 0.041, body_surface)
	left_ankle = _add_foot(left_shin, skin)
	right_ankle = _add_foot(right_shin, skin)

	left_arm = _make_pivot(upper_body, Vector3(-shoulder_width * 0.90, 1.10, 0.0), "LeftArm")
	right_arm = _make_pivot(upper_body, Vector3(shoulder_width * 0.90, 1.10, 0.0), "RightArm")
	var arm_length := 0.67 if species_stage == 0 else 0.59
	if species_stage == 0:
		arm_length = 0.72
	if is_robust:
		arm_length = 0.72
	var upper_arm_end := Vector3(0.0, -arm_length * 0.48, 0.015)
	left_forearm = _make_pivot(left_arm, upper_arm_end, "LeftForearm")
	right_forearm = _make_pivot(right_arm, upper_arm_end, "RightForearm")
	var arm_mass := 0.92 if female else 1.04
	_add_segment(left_arm, Vector3.ZERO, upper_arm_end, 0.060 * arm_mass, 0.050 * arm_mass, body_surface)
	_add_segment(right_arm, Vector3.ZERO, upper_arm_end, 0.060 * arm_mass, 0.050 * arm_mass, body_surface)
	var wrist := Vector3(0.0, -arm_length * 0.52, 0.025)
	_add_segment(left_forearm, Vector3.ZERO, wrist, 0.050 * arm_mass, 0.031 * arm_mass, body_surface)
	_add_segment(right_forearm, Vector3.ZERO, wrist, 0.050 * arm_mass, 0.031 * arm_mass, body_surface)
	_add_hand(left_forearm, wrist, skin)
	_add_hand(right_forearm, wrist, skin)

	var neck_width := 0.074 if species_stage < 2 else 0.068
	var neck_height := 0.145 if species_stage == 0 else 0.160
	if is_robust:
		neck_width = 0.088
		neck_height = 0.150
	if female:
		neck_width *= 0.88
	_add_ellipsoid(
		upper_body, "Trapezius", Vector3(0.0, 1.185, -0.012),
		Vector3(shoulder_width * 0.72, 0.085, 0.090), body_surface
	)
	_add_ellipsoid(
		upper_body, "Neck", Vector3(0.0, 1.285, -0.018),
		Vector3(neck_width, neck_height, neck_width * 0.92), skin
	)
	_add_ellipsoid(
		upper_body, "Throat", Vector3(0.0, 1.285, 0.046),
		Vector3(neck_width * 0.62, neck_height * 0.78, 0.032), face
	)
	head = _make_pivot(upper_body, Vector3.ZERO, "Head")
	_add_head(head, skin, face, shadow_skin, hair, eye)
	if wears_wrap:
		var loincloth_profile := PackedVector4Array([
			Vector4(0.48, 0.105, 0.098, 0.010),
			Vector4(0.59, 0.126, 0.104, 0.010),
			Vector4(0.66, 0.133, 0.105, 0.005)
		])
		_add_loft(upper_body, "WovenHideWrap", loincloth_profile, cloth, 12)

func _add_head(parent: Node3D, skin: Material, face: Material, shadow_skin: Material, hair: StandardMaterial3D, eye: StandardMaterial3D) -> void:
	var female := body_variant % 3 == 1
	var jaw_width := 0.092 if is_robust else 0.078
	if female:
		jaw_width *= 0.92
	var skull_width := 0.108
	if is_robust:
		skull_width = 0.118
	var head_profile := PackedVector4Array([
		Vector4(1.275, jaw_width * 0.74, 0.070, 0.035),
		Vector4(1.315, jaw_width, 0.088, 0.045),
		Vector4(1.375, jaw_width * 0.93, 0.102, 0.030),
		Vector4(1.445, skull_width * 0.88, 0.110, 0.005),
		Vector4(1.535, skull_width, 0.108, -0.015),
		Vector4(1.625, skull_width * 0.91, 0.098, -0.025),
		Vector4(1.695, skull_width * 0.68, 0.078, -0.030),
		Vector4(1.725, 0.018, 0.024, -0.030)
	])
	_add_loft(parent, "CraniumAndFace", head_profile, face, 20)

	var muzzle_depth := 0.075 if species_stage < 2 else 0.047
	if is_robust:
		muzzle_depth = 0.082
	_add_ellipsoid(parent, "PrognathicMuzzle", Vector3(0.0, 1.385, 0.112), Vector3(0.067 if is_robust else 0.058, 0.052, muzzle_depth), skin)
	_add_ellipsoid(parent, "NoseBridge", Vector3(0.0, 1.475, 0.113), Vector3(0.022, 0.064, 0.030), face)
	_add_ellipsoid(parent, "NoseTip", Vector3(0.0, 1.425, 0.150), Vector3(0.033, 0.026, 0.034), face)

	var eye_z := 0.090
	for side in [-1.0, 1.0]:
		_add_ellipsoid(parent, "EyeSocket", Vector3(side * 0.047, 1.493, eye_z), Vector3(0.031, 0.025, 0.014), shadow_skin)
		_add_ellipsoid(parent, "Eye", Vector3(side * 0.047, 1.493, eye_z + 0.012), Vector3(0.015, 0.014, 0.009), eye)
		_add_segment(parent, Vector3(side * 0.015, 1.531, 0.095), Vector3(side * 0.083, 1.528, 0.081), 0.018, 0.015, shadow_skin)
		_add_ellipsoid(parent, "Ear", Vector3(side * (skull_width + 0.006), 1.445, -0.004), Vector3(0.024, 0.045, 0.034), skin)
	var lip_radius := 0.011 if species_stage == 0 else 0.008
	_add_segment(parent, Vector3(-0.044, 1.338, 0.146), Vector3(0.044, 1.338, 0.146), lip_radius, lip_radius, shadow_skin)

	var cap_profile := PackedVector4Array([
		Vector4(1.625, skull_width * 0.90, 0.079, -0.030),
		Vector4(1.682, skull_width * 0.88, 0.078, -0.030),
		Vector4(1.723, skull_width * 0.68, 0.062, -0.031),
		Vector4(1.755, 0.012, 0.018, -0.032)
	])
	_add_loft(parent, "ShortCoarseHair", cap_profile, hair, 18)
	if species_stage == 0:
		for side in [-1.0, -0.55, 0.0, 0.55, 1.0]:
			var root := Vector3(side * skull_width * 0.72, 1.690 - absf(side) * 0.018, -0.055)
			var tip := root + Vector3(side * 0.018, 0.055 + (1.0 - absf(side)) * 0.018, -0.012)
			_add_segment(parent, root, tip, 0.006, 0.002, hair)
	if is_robust:
		_add_segment(parent, Vector3(0.0, 1.730, -0.040), Vector3(0.0, 1.800, -0.040), 0.025, 0.008, skin)
		_add_ellipsoid(parent, "SagittalCrest", Vector3(0.0, 1.775, -0.022), Vector3(0.018, 0.040, 0.090), hair)

func _add_loft(parent: Node3D, label: String, profile: PackedVector4Array, material: Material, sides: int) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(profile.size() - 1):
		var lower: Vector4 = profile[ring]
		var upper: Vector4 = profile[ring + 1]
		for side in range(sides):
			var a0 := TAU * float(side) / float(sides)
			var a1 := TAU * float(side + 1) / float(sides)
			var p00 := Vector3(cos(a0) * lower.y, lower.x, lower.w + sin(a0) * lower.z)
			var p01 := Vector3(cos(a0) * upper.y, upper.x, upper.w + sin(a0) * upper.z)
			var p10 := Vector3(cos(a1) * lower.y, lower.x, lower.w + sin(a1) * lower.z)
			var p11 := Vector3(cos(a1) * upper.y, upper.x, upper.w + sin(a1) * upper.z)
			surface.add_vertex(p00)
			surface.add_vertex(p01)
			surface.add_vertex(p10)
			surface.add_vertex(p10)
			surface.add_vertex(p01)
			surface.add_vertex(p11)
	surface.index()
	surface.generate_normals()
	var mesh := surface.commit()
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	parent.add_child(instance)

func _add_segment(parent: Node3D, start: Vector3, finish: Vector3, radius_start: float, radius_finish: float, material: Material) -> void:
	var direction := finish - start
	if direction.length_squared() < 0.000001:
		return
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius_start
	cylinder.bottom_radius = radius_finish
	cylinder.height = direction.length()
	cylinder.radial_segments = 12
	cylinder.rings = 1
	var instance := MeshInstance3D.new()
	instance.mesh = cylinder
	instance.material_override = material
	instance.position = (start + finish) * 0.5
	instance.quaternion = Quaternion(Vector3.UP, direction.normalized())
	parent.add_child(instance)

func _add_ellipsoid(parent: Node3D, label: String, center: Vector3, radii: Vector3, material: Material) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 16
	sphere.rings = 10
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = sphere
	instance.material_override = material
	instance.position = center
	instance.scale = radii
	parent.add_child(instance)

func _add_foot(parent: Node3D, material: Material) -> Node3D:
	var ankle := _make_pivot(parent, Vector3(0.0, -0.31, 0.0), "Ankle")
	var foot := CapsuleMesh.new()
	foot.radius = FOOT_RADIUS
	foot.height = 2.0 * (FOOT_RADIUS + FOOT_HALF_SEGMENT)
	var instance := MeshInstance3D.new()
	instance.mesh = foot
	instance.material_override = material
	instance.rotation.x = PI * 0.5
	instance.position = Vector3(0.0, 0.0, FOOT_CENTER)
	ankle.add_child(instance)
	return ankle
func _add_hand(parent: Node3D, wrist: Vector3, material: Material) -> void:
	var palm_end := wrist + Vector3(0.0, -0.050, 0.030)
	_add_segment(parent, wrist, palm_end, 0.030, 0.025, material)
	for finger in range(4):
		var spread := (float(finger) - 1.5) * 0.014
		var start := palm_end + Vector3(spread, -0.008, 0.0)
		var finish := start + Vector3(spread * 0.25, -0.061 + absf(spread) * 0.5, 0.009)
		_add_segment(parent, start, finish, 0.008, 0.005, material)
	var thumb_start := palm_end + Vector3(0.025, 0.010, 0.0)
	_add_segment(parent, thumb_start, thumb_start + Vector3(0.032, -0.032, 0.016), 0.010, 0.006, material)

func _make_pivot(parent: Node3D, local_position: Vector3, label: String) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = label
	pivot.position = local_position
	parent.add_child(pivot)
	return pivot
