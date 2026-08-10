shader_type canvas_item;

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.45);
uniform float blur_size = 2.0;
uniform float radius : hint_range(0.0, 1.0, 0.001) = 0.85;

void fragment()
{
	vec2 uv = (UV * 2.0) - 1.0;
	float softness = clamp(blur_size * 0.02, 0.02, 0.45);
	float alpha = smoothstep(radius + softness, radius - softness, length(uv));

	COLOR = vec4(shadow_color.rgb, alpha * shadow_color.a);
}
