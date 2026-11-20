shader_type spatial;

uniform vec3 fur_tone : source_color = vec3(0.42, 0.29, 0.20);
uniform float model_opacity : hint_range(0.0, 1.0) = 1.0;
varying vec3 world_position;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Mask the same screen pixels on every body part during the fade.
	if (model_opacity < 1.0 && hash31(vec3(floor(FRAGCOORD.xy), 0.0)) >= model_opacity) {
		discard;
	}
	vec3 strand_cell = floor(vec3(world_position.x * 95.0, world_position.y * 28.0, world_position.z * 95.0));
	float strands = hash31(strand_cell);
	float undercoat = hash31(floor(world_position * 24.0));
	float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 3.0);
	ALBEDO = fur_tone * (0.70 + undercoat * 0.24 + strands * 0.10) + vec3(0.10, 0.075, 0.045) * rim;
	ROUGHNESS = 1.0;
	SPECULAR = 0.08;
}
