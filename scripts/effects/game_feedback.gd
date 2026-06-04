## Central place for reward / placement animations.
## Entry points (add sound + extra effects in these functions):
##   run_hex_placement_reward   — placed tile + contributing hexes
##   run_hand_card_spawn        — new card in hand
##   run_hand_card_redraw       — duplicate card stack bump
##   run_point_counter_reward   — top-left score meter
##   run_booster_reward         — booster hex meter
extends Node

enum HexRewardRole { PLACED, CONTRIBUTOR }

const SCORE_POP_BASE_Y := 3.367

@export var settings: GameFeedbackSettings

@onready var audio: FeedbackAudio = $FeedbackAudio

func _ready() -> void:
	if settings == null:
		settings = load("res://data/game_feedback_settings.tres") as GameFeedbackSettings

func _cfg() -> GameFeedbackSettings:
	return settings

# ---------------------------------------------------------------------------
# Hex placement — called from HexTileContainer.play_placement_reward
# ---------------------------------------------------------------------------

func run_hex_placement_reward(
	tile: HexTile,
	role: HexRewardRole,
	points: int,
	element: int,
	delay: float = 0.0
) -> void:
	match role:
		HexRewardRole.PLACED:
			_play_hex_placed_audio(points)
			if points != 0:
				_hex_animate_score_popup(tile, points)
			_hex_animate_outline_flash(tile, 0.0)
			if element != GameEnums.ELEMENT.NONE:
				_hex_animate_celebrate(tile, true, 0.0)
		HexRewardRole.CONTRIBUTOR:
			_play_hex_contributor_audio()
			_hex_animate_outline_flash(tile, delay)
			if element != GameEnums.ELEMENT.NONE:
				_hex_animate_celebrate(tile, false, delay)

func _play_hex_placed_audio(_points: int) -> void:
	audio.play_place_tile()

func _play_hex_contributor_audio() -> void:
	audio.play_tile_contributor()

func _hex_animate_score_popup(tile: HexTile, points: int) -> void:
	var cfg := _cfg()
	var sprite: Sprite3D = tile.get_node("visuals/Sprite3D")
	var label: Label3D = tile.get_node("visuals/Sprite3D/Label3D")
	if points > 0:
		label.text = "+%d" % points
		sprite.modulate = Color(1.0, 0.88, 0.35, 1.0)
	else:
		label.text = "%d" % points
		sprite.modulate = Color(0.95, 0.35, 0.35, 1.0)

	sprite.visible = true
	sprite.position.y = SCORE_POP_BASE_Y
	sprite.scale = Vector3(0.2, 0.2, 0.2)

	var tween := tile.create_tween().set_parallel(true)
	tile.set_feedback_tween(&"score_pop", tween)
	tween.tween_property(sprite, "scale", Vector3.ONE * cfg.score_pop_peak_scale, cfg.score_pop_up_duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "position:y", SCORE_POP_BASE_Y + cfg.score_pop_rise, cfg.score_pop_float_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate:a", 0.0, cfg.score_pop_fade_duration)\
		.set_delay(cfg.score_pop_fade_delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		sprite.hide()
		sprite.modulate = Color.WHITE
		sprite.position.y = SCORE_POP_BASE_Y
		sprite.scale = Vector3(0.5, 0.5, 0.5)
	)

func _hex_animate_outline_flash(tile: HexTile, delay: float) -> void:
	var cfg := _cfg()
	var outline: Sprite3D = tile.get_node("visuals/MeshInstance3D/outline")
	outline.modulate = cfg.outline_flash_color
	outline.show()

	var tween := tile.create_tween()
	tile.set_feedback_tween(&"outline", tween)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(outline, "modulate:a", 0.0, cfg.outline_flash_fade_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		outline.hide()
		outline.modulate = Color.WHITE
	)

func _hex_animate_celebrate(tile: HexTile, strong: bool, delay: float) -> void:
	var cfg := _cfg()
	var tile_visuals: Node3D = tile.get_node("visuals")
	var mesh: MeshInstance3D = tile.get_node("visuals/StylizedHexTile")
	var material := mesh.material_override as StandardMaterial3D

	var lift := cfg.placed_lift if strong else cfg.contributor_lift
	var peak_scale := Vector3.ONE * (cfg.placed_scale_peak if strong else cfg.contributor_scale_peak)
	var glow_amount := cfg.placed_glow if strong else cfg.contributor_glow
	var rise_duration := cfg.placed_rise_duration if strong else cfg.contributor_rise_duration
	var settle_duration := cfg.placed_settle_duration if strong else cfg.contributor_settle_duration

	var base_color := tile.visuals.color
	var glow_color := base_color.lightened(glow_amount)

	var tween := tile.create_tween()
	tile.set_feedback_tween(&"celebrate", tween)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.tween_property(tile_visuals, "position:y", lift, rise_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(tile_visuals, "scale", peak_scale, rise_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color", glow_color, rise_duration * 0.7)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(tile_visuals, "position:y", 0.0, settle_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(tile_visuals, "scale", Vector3.ONE, settle_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(material, "albedo_color", base_color, settle_duration * 0.85)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		tile_visuals.position = Vector3.ZERO
		tile_visuals.scale = Vector3.ONE
		material.albedo_color = base_color
	)

# ---------------------------------------------------------------------------
# Hand cards — called from Card
# ---------------------------------------------------------------------------

func run_tile_hover_slide() -> void:
	audio.play_hover_tile()

func run_hand_card_spawn(
	card: Card,
	target_pos: Vector2,
	target_angle: float,
	z: int
) -> void:
	audio.play_draw_card()
	_run_hand_card_spawn_motion(card, target_pos, target_angle, z)

func play_undo() -> void:
	audio.play_undo()

func play_recycle() -> void:
	audio.play_recycle()

func play_click_button() -> void:
	audio.play_click_button()

func play_hover_card() -> void:
	audio.play_hover_card()

func play_click_card() -> void:
	audio.play_click_card()

func run_hand_card_redraw(card: Card) -> void:
	if card.is_spawn_feedback_active():
		return
	audio.play_draw_card()
	_run_hand_card_redraw_motion(card)

func _run_hand_card_spawn_motion(
	card: Card,
	target_pos: Vector2,
	target_angle: float,
	z: int
) -> void:
	var cfg := _cfg()
	card.begin_spawn_feedback()
	card.set_z(z)
	card.position = cfg.card_spawn_origin
	card.rotation_degrees = 0.0
	card.reset_spawn_visuals()

	var tween := card.create_tween().set_parallel(true)
	card.set_feedback_tween(&"spawn", tween)
	tween.tween_property(card.visuals, "scale", card.base_scale, cfg.card_spawn_duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card.visuals, "modulate", Color.WHITE, cfg.card_spawn_duration * 0.75)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "position", target_pos, cfg.card_spawn_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "rotation_degrees", target_angle, cfg.card_spawn_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void:
		card.end_spawn_feedback(target_pos, target_angle)
	)

func _run_hand_card_redraw_motion(card: Card) -> void:
	var cfg := _cfg()
	card.begin_redraw_feedback()
	var peak_scale := card.base_scale * cfg.card_redraw_peak_scale
	var tween := card.create_tween()
	card.set_feedback_tween(&"redraw", tween)
	tween.tween_property(card.visuals, "scale", peak_scale, cfg.card_redraw_duration * 0.35)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card.visuals, "scale", card.target_scale, cfg.card_redraw_duration * 0.65)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		card.end_redraw_feedback()
	)

# ---------------------------------------------------------------------------
# Point counter — called from PointCounter.apply_preview(animate_reward=true)
# ---------------------------------------------------------------------------

func run_point_counter_reward(
	counter: PointCounter,
	gained: int,
	from_score: int,
	to_score: int
) -> void:
	if gained != 0:
		audio.play_points_scored()
	_run_point_counter_reward_motion(counter, gained, from_score, to_score)

func _run_point_counter_reward_motion(
	counter: PointCounter,
	gained: int,
	from_score: int,
	to_score: int
) -> void:
	var cfg := _cfg()
	counter.kill_reward_tweens()
	counter.ensure_score_label_pivot()
	counter.setup_gain_popup_text(gained)

	var label := counter.score_label
	var progress := counter.progress_sprite
	var background := counter.background_sprite
	label.scale = Vector2.ONE
	progress.scale = cfg.point_hex_base_scale
	background.scale = cfg.point_hex_base_scale

	var punch := counter.create_tween()
	counter.set_reward_tween(&"punch", punch)
	punch.set_parallel(true)
	punch.tween_property(label, "scale", Vector2(cfg.point_punch_scale, cfg.point_punch_scale), cfg.point_punch_up_duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	punch.tween_property(progress, "scale", cfg.point_hex_peak_scale, cfg.point_punch_up_duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	punch.tween_property(background, "scale", cfg.point_hex_peak_scale, cfg.point_punch_up_duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	punch.chain().tween_property(label, "scale", Vector2.ONE, cfg.point_punch_settle_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	punch.parallel().tween_property(progress, "scale", cfg.point_hex_base_scale, cfg.point_punch_settle_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	punch.parallel().tween_property(background, "scale", cfg.point_hex_base_scale, cfg.point_punch_settle_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var popup := counter.gain_popup
	var gain_label := counter.gain_label
	popup.position = cfg.point_gain_popup_start
	popup.scale = Vector2(0.6, 0.6)
	popup.modulate = Color(1, 1, 1, 1)
	gain_label.visible = true

	var reward := counter.create_tween()
	counter.set_reward_tween(&"reward", reward)
	reward.set_parallel(true)
	reward.tween_method(
		counter.set_animated_score_display,
		float(from_score),
		float(to_score),
		cfg.point_count_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reward.tween_property(popup, "scale", Vector2.ONE, cfg.point_gain_popup_scale_in_duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reward.tween_property(popup, "position", cfg.point_gain_popup_end, cfg.point_gain_popup_float_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reward.tween_property(popup, "modulate:a", 0.0, cfg.point_gain_popup_fade_duration)\
		.set_delay(cfg.point_gain_popup_fade_delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	reward.chain().tween_callback(func() -> void:
		counter.finish_reward_popup()
		counter.apply_current_style()
	)

# ---------------------------------------------------------------------------
# Booster meter — called from BoosterManager.apply_booster_points(animate_reward=true)
# ---------------------------------------------------------------------------

func run_booster_reward(manager: BoosterManager) -> void:
	audio.play_points_scored()
	_run_booster_reward_motion(manager)

func _run_booster_reward_motion(manager: BoosterManager) -> void:
	var cfg := _cfg()
	manager.kill_reward_tween()
	manager.ensure_hex_label_pivot()

	var label := manager.booster_label
	var progress := manager.booster_progress_sprite
	label.scale = Vector2.ONE
	progress.scale = cfg.booster_progress_base_scale

	var tween := manager.create_tween()
	manager.set_reward_tween(tween)
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2(cfg.booster_punch_scale, cfg.booster_punch_scale), cfg.booster_punch_up_duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(progress, "scale", cfg.booster_progress_peak_scale, cfg.booster_punch_up_duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(label, "scale", Vector2.ONE, cfg.booster_punch_settle_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(progress, "scale", cfg.booster_progress_base_scale, cfg.booster_punch_settle_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
