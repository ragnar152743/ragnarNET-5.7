shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.08, 0.12, 0.2, 1.0);
uniform vec4 pulse_color : source_color = vec4(0.2, 0.95, 1.0, 1.0);
uniform float roughness = 0.18;
uniform float metallic = 0.22;
uniform float emission_energy = 2.5;
uniform float grid_scale = 8.0;
uniform float pulse_speed = 1.5;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 normal_dir = normalize(NORMAL);
	vec3 view_dir = normalize(VIEW);
	float fresnel = pow(1.0 - max(dot(normal_dir, view_dir), 0.0), 4.0);

	float line_x = abs(fract(UV.x * grid_scale) - 0.5);
	float line_y = abs(fract(UV.y * grid_scale) - 0.5);
	float grid = 1.0 - smoothstep(0.06, 0.18, min(line_x, line_y));

	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed + world_pos.x * 1.3 + world_pos.y * 0.8 + world_pos.z * 1.1);
	vec3 glow = mix(base_color.rgb, pulse_color.rgb, pulse);

	ALBEDO = mix(base_color.rgb, glow, grid * 0.45 + fresnel * 0.18);
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = 0.78;
	EMISSION = glow * (emission_energy * (0.18 + grid * 0.72 + fresnel * 0.36));
}
