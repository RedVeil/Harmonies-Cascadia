shader_type canvas_item;

#define TWO_PI 6.28318530718

uniform vec3 primary_color: source_color = vec3(1.0, 0.0, 0.0);
uniform vec3 secondary_color: source_color = vec3(0.4, 0.0, 0.0);
uniform vec3 third_color: source_color = vec3(0.8, 0.5, 0.0);

uniform vec3 outline_color: source_color = vec3(0.0);
uniform vec3 unfilled_color: source_color = vec3(0.443);

uniform float current_value: hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float lerp_value: hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float third_value: hint_range(0.0, 1.0, 0.01) = 1.0;

uniform float smooth_ = 0.005;
uniform float width_in = 0.85;
uniform float width_out = 0.95;
uniform float border_width = 0.03;

float radial_progress(vec2 UV_, float VAL, float SMOOTH, float IR, float OR)
{
	vec2 uv = (UV_ * 2.0) - 1.0;
	vec2 origin = vec2(0.0, 0.0);

	float d = length(uv);

	float ring = smoothstep(OR + SMOOTH, OR - SMOOTH, d)
		- smoothstep(IR + SMOOTH, IR - SMOOTH, d);

	// Starts at 12 o'clock and fills clockwise.
	float a = atan(uv.x - origin.x, -(uv.y - origin.y));
	float theta = (a < 0.0) ? (a + TWO_PI) / TWO_PI : a / TWO_PI;

	float bar = step(theta, VAL);

	return ring * bar;
}

void fragment()
{
	float outline_mask = radial_progress(
		UV,
		1.0,
		smooth_,
		width_in - border_width,
		width_out + border_width
	);

	float unfilled_mask = radial_progress(
		UV,
		1.0,
		smooth_,
		width_in,
		width_out
	);

	float third_mask = radial_progress(
		UV,
		third_value,
		smooth_,
		width_in,
		width_out
	);

	float secondary_mask = radial_progress(
		UV,
		lerp_value,
		smooth_,
		width_in,
		width_out
	);

	float primary_mask = radial_progress(
		UV,
		current_value,
		smooth_,
		width_in,
		width_out
	);

	vec4 outline = vec4(outline_color, 1.0) * outline_mask;
	vec4 unfilled = vec4(unfilled_color, 1.0) * unfilled_mask;
	vec4 third = vec4(third_color, 1.0) * third_mask;
	vec4 secondary = vec4(secondary_color, 1.0) * secondary_mask;
	vec4 primary = vec4(primary_color, 1.0) * primary_mask;

	// Layer order:
	// outline -> unfilled -> third -> secondary -> primary
	COLOR = outline + unfilled;
	COLOR = mix(COLOR, third, third_mask);
	COLOR = mix(COLOR, secondary, secondary_mask);
	COLOR = mix(COLOR, primary, primary_mask);
}