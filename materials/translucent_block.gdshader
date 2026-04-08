shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D normal_roughness_texture : hint_normal_roughness_texture, repeat_disable, filter_linear;

uniform vec4 tint_color : source_color = vec4(0.8, 0.92, 0.98, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float alpha_strength = 0.42;
uniform float roughness = 0.06;
uniform float metallic = 0.0;
uniform float shimmer_speed = 0.8;
uniform float refraction_strength = 0.018;
uniform float reflection_strength = 0.52;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 normal_dir = normalize(NORMAL);
	vec3 view_dir = normalize(VIEW);
	float fresnel = pow(1.0 - max(dot(normal_dir, view_dir), 0.0), 3.8);
	float shimmer = 0.5 + 0.5 * sin(TIME * shimmer_speed + world_pos.x * 1.7 + world_pos.z * 1.3);
	vec2 distortion = vec2(
		sin(world_pos.x * 0.42 + TIME * 0.72),
		cos(world_pos.z * 0.38 - TIME * 0.66)
	) * refraction_strength;
	vec2 refracted_uv = clamp(SCREEN_UV + distortion, vec2(0.002), vec2(0.998));
	vec3 refracted_scene = textureLod(screen_texture, refracted_uv, 0.0).rgb;
	vec4 scene_nr = textureLod(normal_roughness_texture, refracted_uv, 0.0);
	float reflected_roughness = clamp(scene_nr.w, 0.0, 1.0);
	vec3 glass_color = mix(tint_color.rgb, refracted_scene * tint_color.rgb, 0.42 + shimmer * 0.08);
	glass_color = mix(glass_color, refracted_scene, reflection_strength * fresnel * (1.0 - reflected_roughness * 0.32));

	ALBEDO = mix(glass_color, rim_color.rgb, clamp(fresnel * 0.72 + shimmer * 0.1, 0.0, 1.0));
	ROUGHNESS = mix(roughness, roughness * 0.45, fresnel);
	METALLIC = metallic;
	SPECULAR = 0.95;
	EMISSION = rim_color.rgb * fresnel * 0.18;
	ALPHA = clamp(alpha_strength + fresnel * 0.16, 0.0, 1.0);
}
