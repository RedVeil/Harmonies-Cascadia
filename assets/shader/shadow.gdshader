shader_type canvas_item;

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.45);
uniform float blur_size = 2.0;

void fragment()
{
	vec2 texel = TEXTURE_PIXEL_SIZE * blur_size;

	float alpha = 0.0;

	alpha += texture(TEXTURE, UV + vec2(-texel.x, -texel.y)).a;
	alpha += texture(TEXTURE, UV + vec2( 0.0,     -texel.y)).a;
	alpha += texture(TEXTURE, UV + vec2( texel.x, -texel.y)).a;

	alpha += texture(TEXTURE, UV + vec2(-texel.x, 0.0)).a;
	alpha += texture(TEXTURE, UV).a;
	alpha += texture(TEXTURE, UV + vec2( texel.x, 0.0)).a;

	alpha += texture(TEXTURE, UV + vec2(-texel.x, texel.y)).a;
	alpha += texture(TEXTURE, UV + vec2( 0.0,     texel.y)).a;
	alpha += texture(TEXTURE, UV + vec2( texel.x, texel.y)).a;

	alpha /= 9.0;

	COLOR = vec4(shadow_color.rgb, alpha * shadow_color.a);
}