shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled;

uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float radius : hint_range(0.0, 1.0, 0.001) = 0.98;
uniform float smoothness : hint_range(0.0, 0.1, 0.001) = 0.01;

void fragment() {
	vec2 uv = (UV * 2.0) - 1.0;
	float d = length(uv);
	float alpha = smoothstep(radius + smoothness, radius - smoothness, d);
	ALBEDO = albedo.rgb * COLOR.rgb;
	ALPHA = alpha * albedo.a * COLOR.a;
}
