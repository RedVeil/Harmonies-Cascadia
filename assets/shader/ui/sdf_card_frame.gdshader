shader_type canvas_item;
render_mode blend_mix;

// Full card chrome: white rim, dark inner border, body fill, name plate.
// Pixel-space SDF + fwidth AA stays smooth under slight Node2D rotation.

uniform vec4 frame_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 border_color : source_color = vec4(0.04, 0.04, 0.03, 1.0);
uniform vec4 body_color : source_color = vec4(0.0, 0.44, 0.45, 1.0);
uniform vec4 name_color : source_color = vec4(0.16, 0.17, 0.253, 1.0);

// TextureRect size in local pixels (must match scene offsets).
uniform vec2 rect_size = vec2(100.0, 174.0);
// Inset of hard card edge from TextureRect bounds (AA fringe).
uniform float edge_pad_px : hint_range(0.0, 16.0, 0.1) = 3.0;
uniform float white_rim_px : hint_range(0.0, 16.0, 0.1) = 5.5;
uniform float border_width_px : hint_range(0.0, 8.0, 0.1) = 2.0;
uniform float corner_radius_px : hint_range(0.0, 16.0, 0.1) = 1.5;
// Local Y of name plate top, relative to TextureRect top (0 = top).
uniform float name_split_px : hint_range(0.0, 256.0, 0.1) = 150.0;
uniform float smoothness_px : hint_range(0.0, 4.0, 0.05) = 0.75;

float sd_rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float aa_cover(float d, float soft) {
	float w = max(fwidth(d), soft);
	return 1.0 - smoothstep(-w, w, d);
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * rect_size;
	vec2 half_rect = rect_size * 0.5;
	float r = corner_radius_px;

	float d_outer = sd_rounded_box(p, half_rect - vec2(edge_pad_px), r);

	float inset_white = edge_pad_px + white_rim_px;
	float d_after_white = sd_rounded_box(p, half_rect - vec2(inset_white), max(r - white_rim_px, 0.0));

	float inset_border = inset_white + border_width_px;
	float d_content = sd_rounded_box(p, half_rect - vec2(inset_border), max(r - white_rim_px - border_width_px, 0.0));

	float a_outer = aa_cover(d_outer, smoothness_px);
	float a_past_white = aa_cover(d_after_white, smoothness_px);
	float a_content = aa_cover(d_content, smoothness_px);

	float y_px = UV.y * rect_size.y;
	float name_w = max(fwidth(y_px), smoothness_px);
	float is_name = smoothstep(name_split_px - name_w, name_split_px + name_w, y_px);
	vec3 fill = mix(body_color.rgb, name_color.rgb, is_name);

	// Black divider between body and name plate (same width as outer border).
	float d_name_div = abs(y_px - name_split_px) - border_width_px * 0.5;
	float a_name_div = aa_cover(d_name_div, smoothness_px);

	vec3 rgb = frame_color.rgb;
	rgb = mix(rgb, border_color.rgb, a_past_white);
	rgb = mix(rgb, fill, a_content);
	rgb = mix(rgb, border_color.rgb, a_content * a_name_div);

	COLOR = vec4(rgb, a_outer * COLOR.a);
}
