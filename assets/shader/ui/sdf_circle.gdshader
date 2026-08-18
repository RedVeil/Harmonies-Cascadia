shader_type canvas_item;
render_mode blend_mix;

uniform float radius : hint_range(0.0, 1.0, 0.001) = 0.98;
uniform float smoothness : hint_range(0.0, 0.1, 0.001) = 0.01;

void fragment() {
	// COLOR already includes CanvasItem modulate / self_modulate.
	float _tex = texture(TEXTURE, UV).a;
	vec2 uv = (UV * 2.0) - 1.0;
	float d = length(uv);
	float alpha = smoothstep(radius + smoothness, radius - smoothness, d);
	COLOR = vec4(COLOR.rgb, COLOR.a * alpha + _tex * 0.0);
}
