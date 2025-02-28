extends Sprite2D

@export var hover_color: Color = Color(0.984, 0.931, 0.77, 0.259)
@export var land_sound: AudioStreamPlayer

@onready var hover_polygon = $HoverArea2D/HoverPolygon2D
@onready var hover_area = $HoverArea2D

const LAND_SOUND_EFFECT = preload("res://assets/sfx/zapsplat_multimedia_ui_mallet_tone_turn_on_start_105005.mp3")
const LAND_SOUND_EFFECT_2 = preload("res://assets/sfx/esm_game_win_sound_fx_arcade_synth_musical_chord_bling_electronic_casino_kids_mobile_positive_achievement_score.mp3")
const LAND_SOUND_EFFECT_3 = preload("res://assets/sfx/zapsplat_leisure_toy_musical_xylophone_key_plastic_press_single_note_005_40974.mp3")

# Add signals for mouse events
signal mouse_entered
signal mouse_exited

var is_occupied := false

func _ready():
	hover_area.mouse_entered.connect(_on_area_2d_mouse_entered)
	hover_area.mouse_exited.connect(_on_area_2d_mouse_exited)

	hover_polygon.z_index = 2
	hover_polygon.visible = true  # Keep visible but start fully transparent
	hover_polygon.color = hover_color
	hover_polygon.modulate.a = 0  # Start fully transparent

	if land_sound:
		land_sound.stream = LAND_SOUND_EFFECT_3
		land_sound.pitch_scale = randf_range(1.0, 1.2)
		land_sound.volume_db = -20

func _on_area_2d_mouse_entered():
	if not is_occupied:
		var tween = create_tween()
		tween.tween_property(hover_polygon, "modulate:a", 1.0, 0.15)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)
		emit_signal("mouse_entered")

func _on_area_2d_mouse_exited():
	if not is_occupied:
		var tween = create_tween()
		tween.tween_property(hover_polygon, "modulate:a", 0.0, 0.15)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN)
		emit_signal("mouse_exited")

func set_occupied(occupied: bool) -> void:
	is_occupied = occupied

	if is_occupied:
		hover_polygon.scale = Vector2.ZERO
		hover_polygon.modulate.a = 0
	else:
		hover_polygon.scale = Vector2.ONE
		# Only show hover if mouse is currently over the tile
		if hover_area.has_overlapping_bodies() or hover_area.has_overlapping_areas():
			var tween = create_tween()
			tween.tween_property(hover_polygon, "modulate:a", 1.0, 0.15)\
				.set_trans(Tween.TRANS_SINE)\
				.set_ease(Tween.EASE_OUT)
