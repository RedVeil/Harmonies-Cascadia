shader_type canvas_item;

uniform float current_value : hint_range(0.0, 1.0) = 1.0; // Instant/front
uniform float lerp_value : hint_range(0.0, 1.0) = 1.0;    // Smooth/middle
uniform float third_value : hint_range(0.0, 1.0) = 1.0;   // Slow/back

uniform vec4 front_color : source_color = vec4(1.0, 0.0, 0.0, 1.0); // bright red
uniform vec4 back_color : source_color = vec4(0.4, 0.0, 0.0, 1.0);  // dark red
uniform vec4 third_color : source_color = vec4(0.8, 0.5, 0.0, 1.0); // orange

void fragment() {
	vec2 uv = UV;

	// Fill bars, UV.x goes 0 → 1 across bar width.
	bool in_front = uv.x < current_value;
	bool in_back = uv.x < lerp_value;
	bool in_third = uv.x < third_value;

	if (in_third) {
		COLOR = third_color;
	} else {
		COLOR = vec4(0.0); // transparent background
	}

	if (in_back) {
		COLOR = back_color;
	}

	if (in_front) {
		COLOR = front_color;
	}
}