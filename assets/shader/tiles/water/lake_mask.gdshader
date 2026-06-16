shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, depth_prepass_alpha;

group_uniforms Mask;
uniform sampler2D mask_texture : source_color, filter_linear_mipmap;
uniform float alpha_cutoff : hint_range(0.0, 0.5, 0.01) = 0.08;
uniform float water_threshold_low : hint_range(0.0, 1.0, 0.01) = 0.68;
uniform float water_threshold_high : hint_range(0.0, 1.0, 0.01) = 0.88;

group_uniforms Water;
uniform sampler2D noise_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 water_color_deep : source_color = vec4(0.22, 0.48, 0.78, 1.0);
uniform vec4 water_color_shallow : source_color = vec4(0.35, 0.58, 0.92, 1.0);
uniform vec4 water_highlight : source_color = vec4(0.72, 0.88, 1.0, 1.0);
uniform float water_flow_speed : hint_range(0.0, 1.0, 0.01) = 0.12;
uniform vec2 water_flow_direction = vec2(0.35, 0.65);
uniform float water_noise_scale : hint_range(0.05, 2.0, 0.01) = 0.35;
uniform float water_roughness : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform float water_fresnel_strength : hint_range(0.0, 1.0, 0.01) = 0.35;

group_uniforms Shore;
uniform vec4 shore_color_dry : source_color = vec4(0.62, 0.54, 0.38, 1.0);
uniform vec4 shore_color_wet : source_color = vec4(0.42, 0.38, 0.30, 1.0);
uniform float shore_noise_scale : hint_range(0.05, 2.0, 0.01) = 0.45;
uniform float shore_roughness : hint_range(0.0, 1.0, 0.01) = 0.82;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec2 flow_uv(vec2 direction, float speed, float scale, float time_offset) {
	vec2 dir = normalize(direction + vec2(0.0001));
	return world_pos.xz * scale + dir * (TIME + time_offset) * speed;
}

float sample_flow_noise(vec2 uv_a, vec2 uv_b) {
	float n1 = texture(noise_texture, uv_a).r;
	float n2 = texture(noise_texture, uv_b).r;
	return mix(n1, n2, 0.5);
}

void fragment() {
	float mask = texture(mask_texture, UV).r;
	if (mask < alpha_cutoff) {
		discard;
	}

	float water_mask = smoothstep(water_threshold_low, water_threshold_high, mask);
	float shore_mask = 1.0 - water_mask;

	vec2 flow_a = flow_uv(water_flow_direction, water_flow_speed, water_noise_scale, 0.0);
	vec2 flow_b = flow_uv(
		vec2(-water_flow_direction.y, water_flow_direction.x),
		water_flow_speed * 0.75,
		water_noise_scale * 1.35,
		1.7
	);
	float waves = sample_flow_noise(flow_a, flow_b);
	float ripple = sample_flow_noise(flow_a * 2.1 + vec2(TIME * 0.04), flow_b * 1.8 - vec2(TIME * 0.03));
	waves = mix(waves, ripple, 0.35);

	vec3 water = mix(water_color_deep.rgb, water_color_shallow.rgb, waves);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	water += water_highlight.rgb * fresnel * water_fresnel_strength;
	water += water_highlight.rgb * smoothstep(0.72, 0.95, waves) * 0.08;

	float shore_noise = texture(noise_texture, world_pos.xz * shore_noise_scale).r;
	vec3 shore = mix(shore_color_dry.rgb, shore_color_wet.rgb, shore_noise);
	float wet_edge = smoothstep(water_threshold_low - 0.12, water_threshold_low + 0.04, mask);
	shore = mix(shore, shore_color_wet.rgb, wet_edge * 0.65);

	ALBEDO = mix(shore, water, water_mask);
	ROUGHNESS = mix(shore_roughness, water_roughness, water_mask);
	METALLIC = 0.0;
	SPECULAR = mix(0.2, 0.55, water_mask);
	ALPHA = 1.0;
}
