shader_type canvas_item;
render_mode blend_mix;

uniform vec2 rect_size = vec2(102.0, 176.0);
uniform float edge_pad_px : hint_range(0.0, 32.0, 0.1) = 8.0;
uniform float corner_radius_px : hint_range(0.0, 24.0, 0.1) = 2.0;
uniform float softness_px : hint_range(0.0, 32.0, 0.1) = 10.0;

float sd_rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * rect_size;
	float d = sd_rounded_box(p, rect_size * 0.5 - vec2(edge_pad_px), corner_radius_px);
	float w = max(fwidth(d), softness_px);
	float alpha = 1.0 - smoothstep(-w, w * 1.5, d);
	COLOR = vec4(COLOR.rgb, COLOR.a * alpha);
}
