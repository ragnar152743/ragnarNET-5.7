shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_always, diffuse_burley, specular_schlick_ggx;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D normal_roughness_texture : hint_normal_roughness_texture, repeat_disable, filter_linear;

uniform vec4 shallow_color : source_color = vec4(0.12, 0.44, 0.56, 1.0);
uniform vec4 deep_color : source_color = vec4(0.03, 0.11, 0.19, 1.0);
uniform vec4 foam_color : source_color = vec4(0.82, 0.96, 1.0, 1.0);
uniform float wave_height = 0.18;
uniform float wave_speed = 0.55;
uniform float reflection_strength = 0.64;
uniform float distortion_strength = 0.024;
uniform float metallic = 0.08;
uniform float roughness = 0.08;

varying vec3 world_pos;

float wave(vec2 p, float t) {
	float large_wave = sin(p.x * 0.16 + t) * 0.55 + cos(p.y * 0.2 - t * 1.25) * 0.45;
	float detail_wave = sin((p.x + p.y) * 0.42 - t * 1.7) * 0.18 + cos((p.x - p.y) * 0.34 + t * 1.2) * 0.14;
	return large_wave + detail_wave;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = wave(world_pos.xz, TIME * wave_speed);
	VERTEX.y += w * wave_height;
}

void fragment() {
	float w = wave(world_pos.xz, TIME * wave_speed);
	float detail = sin(world_pos.x * 0.8 + TIME * 0.8) * cos(world_pos.z * 0.7 - TIME * 0.6);
	float depth_mix = clamp(0.45 + w * 0.24 + detail * 0.08, 0.0, 1.0);
	float fresnel = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 4.2);
	float foam = smoothstep(0.18, 0.62, abs(w) + detail * 0.2);
	vec2 distortion = vec2(
		sin(world_pos.x * 0.08 + TIME * 0.65) + cos(world_pos.z * 0.06 - TIME * 0.58),
		cos(world_pos.z * 0.1 - TIME * 0.54) + sin(world_pos.x * 0.07 + TIME * 0.42)
	) * distortion_strength;
	vec2 reflected_uv = clamp(SCREEN_UV + distortion, vec2(0.002), vec2(0.998));
	vec3 reflected_scene = textureLod(screen_texture, reflected_uv, 0.0).rgb;
	vec4 scene_nr = textureLod(normal_roughness_texture, reflected_uv, 0.0);
	float reflected_roughness = clamp(scene_nr.w, 0.0, 1.0);
	vec3 water_color = mix(shallow_color.rgb, deep_color.rgb, depth_mix);
	water_color = mix(water_color, foam_color.rgb, foam * 0.16 + fresnel * 0.08);
	water_color = mix(water_color, reflected_scene, reflection_strength * fresnel * (1.0 - reflected_roughness * 0.38));

	ALBEDO = water_color;
	ROUGHNESS = mix(roughness, roughness * 1.95, fresnel);
	METALLIC = metallic;
	SPECULAR = 0.92;
	EMISSION = vec3(0.01, 0.04, 0.05) + foam_color.rgb * foam * 0.06 + vec3(0.08, 0.12, 0.14) * fresnel;
	ALPHA = 0.95;
}
