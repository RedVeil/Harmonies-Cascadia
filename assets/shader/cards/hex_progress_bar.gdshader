shader_type canvas_item;

#define TWO_PI 6.28318530718

uniform vec3 primary_color: source_color = vec3(1.0, 0.0, 0.0);
uniform vec3 secondary_color: source_color = vec3(0.4, 0.0, 0.0);
uniform vec3 third_color: source_color = vec3(0.8, 0.5, 0.0);

uniform vec3 unfilled_color: source_color = vec3(0.443);

uniform float current_value: hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float lerp_value: hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float third_value: hint_range(0.0, 1.0, 0.01) = 1.0;

// Rotation in radians.
// Example: 0.523599 = 30 degrees
uniform float rotation_offset = 0.0;

float progress_mask(vec2 uv, float value)
{
	vec2 p = uv * 2.0 - 1.0;

	// Starts at 12 o'clock and fills clockwise.
	float a = atan(p.x, -p.y);
	float theta = (a < 0.0) ? (a + TWO_PI) / TWO_PI : a / TWO_PI;

	// Rotate the progress sweep
	theta = fract(theta - rotation_offset / TWO_PI);

	return step(theta, value);
}

void fragment()
{
	vec4 tex = texture(TEXTURE, UV);

	// Use sprite alpha as the exact shape mask
	float sprite_mask = tex.a;

	float third_mask = sprite_mask * progress_mask(UV, third_value);
	float secondary_mask = sprite_mask * progress_mask(UV, lerp_value);
	float primary_mask = sprite_mask * progress_mask(UV, current_value);

	vec4 color = vec4(unfilled_color, sprite_mask);

	color = mix(color, vec4(third_color, sprite_mask), third_mask);
	color = mix(color, vec4(secondary_color, sprite_mask), secondary_mask);
	color = mix(color, vec4(primary_color, sprite_mask), primary_mask);

	COLOR = color;
}