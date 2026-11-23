shader_type spatial;

uniform vec3 skin_tone : source_color = vec3(0.3, 0.19, 0.12);
uniform float model_opacity : hint_range(0.0, 1.0) = 1.0;
varying vec3 world_position;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec3 p) {
	vec3 cell = floor(p);
	vec3 blend = fract(p);
	blend = blend * blend * (3.0 - 2.0 * blend);
	float c000 = hash31(cell + vec3(0.0, 0.0, 0.0));
	float c100 = hash31(cell + vec3(1.0, 0.0, 0.0));
	float c010 = hash31(cell + vec3(0.0, 1.0, 0.0));
	float c110 = hash31(cell + vec3(1.0, 1.0, 0.0));
	float c001 = hash31(cell + vec3(0.0, 0.0, 1.0));
	float c101 = hash31(cell + vec3(1.0, 0.0, 1.0));
	float c011 = hash31(cell + vec3(0.0, 1.0, 1.0));
	float c111 = hash31(cell + vec3(1.0, 1.0, 1.0));
	float z0 = mix(mix(c000, c100, blend.x), mix(c010, c110, blend.x), blend.y);
	float z1 = mix(mix(c001, c101, blend.x), mix(c011, c111, blend.x), blend.y);
	return mix(z0, z1, blend.z);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Mask the same screen pixels on every body part during the fade.
	if (model_opacity < 1.0 && hash31(vec3(floor(FRAGCOORD.xy), 0.0)) >= model_opacity) {
		discard;
	}
	float mottling = value_noise(world_position * 22.0);
	float pores = hash31(floor(world_position * 110.0));
	ALBEDO = skin_tone * COLOR.rgb * (0.90 + mottling * 0.14 + (pores - 0.5) * 0.025);
	ROUGHNESS = 0.86;
	SPECULAR = 0.22;
}
