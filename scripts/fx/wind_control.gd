class_name WindControl
extends RefCounted
## Central control for foliage sway (wind_amount) and grass cloud shadows
## (cloud_shadow_amount). Independently toggleable.

const WIND_PARAM := &"wind_amount"
const CLOUD_PARAM := &"cloud_shadow_amount"
const DEFAULT_AMOUNT := 1.0


static func set_wind_amount(amount: float) -> void:
	RenderingServer.global_shader_parameter_set(WIND_PARAM, amount)


static func get_wind_amount() -> float:
	return float(RenderingServer.global_shader_parameter_get(WIND_PARAM))


static func set_wind_enabled(enabled: bool) -> void:
	set_wind_amount(DEFAULT_AMOUNT if enabled else 0.0)


static func set_cloud_amount(amount: float) -> void:
	RenderingServer.global_shader_parameter_set(CLOUD_PARAM, amount)


static func get_cloud_amount() -> float:
	return float(RenderingServer.global_shader_parameter_get(CLOUD_PARAM))


static func set_cloud_enabled(enabled: bool) -> void:
	set_cloud_amount(DEFAULT_AMOUNT if enabled else 0.0)


## Back-compat aliases for wind.
static func set_amount(amount: float) -> void:
	set_wind_amount(amount)


static func get_amount() -> float:
	return get_wind_amount()


static func set_enabled(enabled: bool) -> void:
	set_wind_enabled(enabled)
