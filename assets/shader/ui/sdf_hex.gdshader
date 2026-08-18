shader_type canvas_item;
render_mode blend_mix;

// 0 = filled hex, 1 = outline ring
uniform float mode : hint_range(0.0, 1.0, 1.0) = 0.0;
uniform float stroke_width : hint_range(0.01, 0.4, 0.001) = 0.08;
uniform float roundness : hint_range(0.0, 0.3, 0.001) = 0.06;
uniform float smoothness : hint_range(0.0, 0.1, 0.001) = 0.012;
// Match 400x350 hex PNG aspect (width/height).
uniform float aspect : hint_range(0.5, 2.0, 0.001) = 1.142857;

float sd_hex(vec2 p) {
	const vec3 k = vec3(-0.866025404, 0.5, 0.577350269);
	p = abs(p);
	p -= 2.0 * min(dot(k.xy, p), 0.0) * k.xy;
	p -= vec2(clamp(p.x, -k.z, k.z), 1.0);
	return length(p) * sign(p.y);
}

void fragment() {
	// COLOR already includes CanvasItem modulate / self_modulate.
	float _tex = texture(TEXTURE, UV).a;
	vec2 uv = (UV * 2.0) - 1.0;
	uv.x *= aspect;

	float d = sd_hex(uv) - roundness;
	float outer = smoothstep(smoothness, -smoothness, d);
	float alpha = outer;

	if (mode > 0.5) {
		float inner = smoothstep(smoothness, -smoothness, d + stroke_width);
		alpha = clamp(outer - inner, 0.0, 1.0);
	}

	COLOR = vec4(COLOR.rgb, COLOR.a * alpha + _tex * 0.0);
}
