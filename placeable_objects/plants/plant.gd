class_name Plant
extends Node

@export var harvest_audio: AudioStreamPlayer
@export var harvest_sounds: Array[AudioStream]

@onready var seed_form: Node2D = $"../SeedForm"
@onready var grown_form: Node2D = $"../GrownForm"
@onready var form_timer: Timer = $"../FormTimer"
@onready var pickable_area: Area2D = $"../GrownForm/PickableArea"

@export var min_growth_time: float = 4.0
@export var max_growth_time: float = 6.0

signal growth_completed
signal harvested

var is_grown := false
var parent_tile: Node

func _ready() -> void:
	# Get reference to parent tile
	parent_tile = get_parent().get_parent()

	# Ensure initial state
	seed_form.visible = true
	grown_form.visible = false

	# Setup timer
	form_timer.wait_time = randf_range(min_growth_time, max_growth_time)
	form_timer.one_shot = true
	form_timer.timeout.connect(_on_growth_complete)

	# Setup harvest click detection
	pickable_area.input_event.connect(_on_pickable_area_input_event)

	# Start growing
	start_growing()

func start_growing() -> void:
	form_timer.start()

func _on_growth_complete() -> void:
	# Create transition effect
	var tween = create_tween()
	tween.set_parallel(true)

	# Fade out seed form
	tween.tween_property(seed_form, "modulate:a", 0.0, 0.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)

	# Show and scale up grown form
	grown_form.visible = true
	grown_form.scale = Vector2.ZERO
	grown_form.modulate.a = 0

	tween.tween_property(grown_form, "scale", Vector2.ONE, 0.5)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	tween.tween_property(grown_form, "modulate:a", 1.0, 0.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

	# Cleanup after transition
	tween.chain().tween_callback(func():
		seed_form.visible = false
		is_grown = true
		emit_signal("growth_completed")
	)

func _on_pickable_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if is_grown and event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			harvest()

func harvest() -> void:
	print("Plant harvested!")
	emit_signal("harvested")

	# Play random harvest sound if both audio player and sounds are available
	if harvest_audio and not harvest_sounds.is_empty():
		harvest_audio.stream = harvest_sounds.pick_random()
		harvest_audio.play()

	# Clear parent tile's occupied state
	if parent_tile and parent_tile.has_method("set_occupied"):
		parent_tile.set_occupied(false)

	# Create harvest effect
	var tween = create_tween()
	tween.tween_property(grown_form, "scale", Vector2.ZERO, 0.3)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_IN)

	# Remove the plant after animation
	tween.chain().tween_callback(queue_free)
