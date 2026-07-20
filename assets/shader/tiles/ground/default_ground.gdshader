shader_type spatial;

group_uniforms textures;
uniform sampler2D albedo : source_color;
uniform sampler2D normal_map : hint_normal;
uniform sampler2D tile_noise : source_color;

group_uniforms texture_settings;
uniform vec4 modulate : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float normal_strength : hint_range(0.0, 4.0) = 1.0;

group_uniforms uv_settings;
uniform float global_uv_scale = 1.0;
uniform vec2 global_uv_offset = vec2(0.0, 0.0);


varying vec3 local_pos;
varying vec3 world_pos;

vec3 textureNoTile(sampler2D tex, vec2 uv) {
	float k = texture(tile_noise, 0.005 * uv).x;

	vec2 duvdx = dFdx(uv);
	vec2 duvdy = dFdy(uv);

	float l = k * 8.0;
	float f = fract(l);

	float ia = floor(l);
	float ib = ia + 1.0;

	vec2 offa = sin(vec2(3.0, 7.0) * ia);
	vec2 offb = sin(vec2(3.0, 7.0) * ib);

	vec3 cola = textureGrad(tex, uv + 1.0 * offa, duvdx, duvdy).xyz;
	vec3 colb = textureGrad(tex, uv + 1.0 * offb, duvdx, duvdy).xyz;

	vec3 ab = cola - colb;
	float sum_ab = ab.x + ab.y + ab.z;

	return mix(cola, colb, smoothstep(0.2, 0.8, f - 0.1 * sum_ab));
}

void vertex() {
	local_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz * global_uv_scale + global_uv_offset;

	vec3 base = textureNoTile(albedo, uv);

	ALBEDO.rgb = base * modulate.rgb;
	ALPHA = modulate.a;

	vec3 n = textureNoTile(normal_map, uv);
	NORMAL_MAP = n;
	NORMAL_MAP_DEPTH = normal_strength;

	ROUGHNESS = 0.9;
}