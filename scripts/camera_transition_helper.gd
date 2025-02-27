extends Node2D
class_name CameraTransitionHelper

var background_layer: CanvasLayer
var start_pos: Vector2
var end_pos: Vector2
var progress: float = 0.0
var debug_mode: bool = true  # Set to true for debug output

func initialize(bg_layer: CanvasLayer, from_pos: Vector2, to_pos: Vector2) -> void:
	background_layer = bg_layer
	start_pos = from_pos
	end_pos = to_pos
	
	if debug_mode:
		print("CameraTransitionHelper initialized")
		print("  Start position: ", start_pos)
		print("  End position: ", end_pos)
		print("  Distance: ", start_pos.distance_to(end_pos))

func _process(delta: float) -> void:
	if !is_instance_valid(background_layer):
		if debug_mode:
			print("Background layer not valid, skipping update")
		return
		
	# Calculate relative progress from our position
	var total_distance = start_pos.distance_to(end_pos)
	if total_distance > 0:
		var current_distance = global_position.distance_to(start_pos)
		progress = clamp(current_distance / total_distance, 0.0, 1.0)
		
		if debug_mode and Engine.get_frames_drawn() % 10 == 0:  # Only print every 10 frames to reduce spam
			print("Progress: ", progress, " (", current_distance, "/", total_distance, ")")
	else:
		if debug_mode:
			print("Warning: Start and end positions are identical, no transition needed")
	
	# Apply position offset to background elements
	var offset = (end_pos - start_pos) * progress
	background_layer.offset = offset
