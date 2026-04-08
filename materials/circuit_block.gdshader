shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.08, 0.14, 0.18, 1.0);
uniform vec4 line_color : source_color = vec4(0.42, 1.0, 0.86, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.2;
uniform float metallic : hint_range(0.0, 1.0) = 0.88;
uniform float emission_energy : hint_range(0.0, 12.0) = 2.8;
uniform float line_scale : hint_range(1.0, 16.0) = 6.2;
uniform float pulse_speed : hint_range(0.1, 6.0) = 1.7;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 scaled_pos = world_pos * line_scale;
	vec2 trace_uv = scaled_pos.xz;
	vec2 grid = abs(fract(trace_uv) - 0.5);
	float trace = 1.0 - smoothstep(0.04, 0.11, min(grid.x, grid.y));
	float node = 1.0 - smoothstep(0.12, 0.28, length(fract(trace_uv + 0.5) - 0.5));
	float pulse = 0.55 + 0.45 * sin(TIME * pulse_speed + (world_pos.x + world_pos.z) * 2.0);
	float glow = max(trace, node * 0.7) * pulse;

	ALBEDO = mix(base_color.rgb, line_color.rgb, trace * 0.55 + node * 0.18);
	ROUGHNESS = roughness;
	METALLIC = metallic;
	EMISSION = line_color.rgb * glow * emission_energy;
}
