extends Resource
class_name GameFeedbackSettings

## Hex placement (see GameFeedback.run_hex_placement_reward)
@export_group("Hex Placement")
@export var score_pop_rise: float = 1.35
@export var score_pop_peak_scale: float = 0.58
@export var score_pop_up_duration: float = 0.18
@export var score_pop_float_duration: float = 0.85
@export var score_pop_fade_duration: float = 0.55
@export var score_pop_fade_delay: float = 0.35
@export var outline_flash_color: Color = Color(1.0, 0.9, 0.45, 1.0)
@export var outline_flash_fade_duration: float = 0.45
@export var contributor_stagger: float = 0.06

@export_subgroup("Contributor Celebrate")
@export var contributor_lift: float = 0.09
@export var contributor_scale_peak: float = 1.022
@export var contributor_glow: float = 0.14
@export var contributor_rise_duration: float = 0.2
@export var contributor_settle_duration: float = 0.26

@export_subgroup("Placed Tile Celebrate")
@export var placed_lift: float = 0.15
@export var placed_scale_peak: float = 1.04
@export var placed_glow: float = 0.24
@export var placed_rise_duration: float = 0.24
@export var placed_settle_duration: float = 0.3

## Hand cards (see GameFeedback.run_hand_card_spawn / run_hand_card_redraw)
@export_group("Hand Cards")
@export var card_spawn_duration: float = 0.35
@export var card_spawn_origin: Vector2 = Vector2.ZERO
@export var card_redraw_duration: float = 0.22
@export var card_redraw_peak_scale: float = 1.12

## Point counter (see GameFeedback.run_point_counter_reward)
@export_group("Point Counter")
@export var point_count_duration: float = 0.55
@export var point_punch_scale: float = 1.14
@export var point_punch_up_duration: float = 0.12
@export var point_punch_settle_duration: float = 0.2
@export var point_hex_base_scale: Vector2 = Vector2(0.3, 0.3)
@export var point_hex_peak_scale: Vector2 = Vector2(0.34, 0.34)
@export var point_gain_popup_start: Vector2 = Vector2(72.0, 0.0)
@export var point_gain_popup_end: Vector2 = Vector2(90.0, -14.0)
@export var point_gain_popup_scale_in_duration: float = 0.2
@export var point_gain_popup_float_duration: float = 0.75
@export var point_gain_popup_fade_duration: float = 0.45
@export var point_gain_popup_fade_delay: float = 0.35

## Booster meter (see GameFeedback.run_booster_reward)
@export_group("Booster Meter")
@export var booster_punch_scale: float = 1.14
@export var booster_punch_up_duration: float = 0.12
@export var booster_punch_settle_duration: float = 0.2
@export var booster_progress_base_scale: Vector2 = Vector2(0.15, 0.15)
@export var booster_progress_peak_scale: Vector2 = Vector2(0.165, 0.165)
