shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 color_a : source_color = vec4(0.24, 0.56, 0.27, 1.0);
uniform vec4 color_b : source_color = vec4(0.74, 0.94, 0.58, 1.0);
uniform float sway_strength = 0.08;
uniform float sway_speed = 1.6;

varying float height_mask;
varying vec3 world_pos;

void vertex() {
	height_mask = clamp(UV.y, 0.0, 1.0);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = TIME * sway_speed + (MODEL_MATRIX[3].x + MODEL_MATRIX[3].z) * 0.35;
	VERTEX.x += sin(phase + VERTEX.y * 1.4) * sway_strength * height_mask;
	VERTEX.z += cos(phase * 1.2 + VERTEX.x * 0.8) * sway_strength * 0.6 * height_mask;
}

void fragment() {
	float hue_noise = 0.5 + 0.5 * sin(world_pos.x * 0.9 + world_pos.z * 1.2);
	float fresnel = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 3.4);
	vec3 base_color = mix(color_a.rgb, color_b.rgb, height_mask);
	ALBEDO = mix(base_color, base_color * 1.08 + vec3(0.04, 0.05, 0.02), hue_noise * 0.12 + fresnel * 0.08);
	ROUGHNESS = 0.72;
	SPECULAR = 0.32;
	EMISSION = base_color * fresnel * 0.04;
}
