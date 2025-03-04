extends Node2D

@export_category("Node references")
@export var tiles_node: Node2D
@export var place_progress: ProgressBar
@export var place_timer: Timer
@export var round_timer_label: Label
@export var round_timer: Timer
@export var upgrade_container: Control
@export var clouds_node: Node2D

@export_category("Camera references")
@export var main_camera: Camera2D
@export var upgrade_camera: Camera2D
@export var background_layer: CanvasLayer

@export_category("Animation player")
@export var star_animation_player: AnimationPlayer
@export var sunray_animation_player: AnimationPlayer
@export var rain_animation_player: AnimationPlayer

const AUDIO_COMPENSATION = 0.35
const PLANT_INTERVAL = 2.0
const ROUND_DURATION = 30  # Round duration in seconds
const UPGRADE_PANEL_OFFSET = Vector2(0, 0)  # Amount to slide the panel
const CAMERA_TRANSITION_DURATION = 1.0  # Duration of camera transition in seconds

const AGAVE_SCENE = preload("res://placeable_objects/plants/agave.tscn")
const BAMBOO_SCENE = preload("res://placeable_objects/plants/bamboo.tscn")
const RUBBLE_SCENE = preload("res://placeable_objects/trash/rubble.tscn")

var plant_scenes = [
	AGAVE_SCENE,
	BAMBOO_SCENE,
	#RUBBLE_SCENE,
]

var currently_hovered_tile: Node = null
var unlockable_tiles: Array[Node] = []
var game_started := false
var round_objects := []  # Track objects placed in current round
var active_camera: Camera2D = null  # Track the currently active camera
var camera_transition_in_progress := false  # Flag to prevent multiple transitions
var round_ended := false  # Flag to track if a round has ended
var animation_debug_count := 0  # Debug counter for animations
var round_timer_connected := false  # Track if round timer is connected

var weather_sequence_started := false
var weather_transition_timer: Timer = null

func _ready():

	#position_window_bottom_right()

	if not tiles_node:
		print("No tiles node assigned!")
		return

	# Collect unlockable tiles
	for tile in tiles_node.get_children():
		if tile.has_node("Unlockable"):
			unlockable_tiles.append(tile)
	
	tiles_node.visible = false
	
	# Setup round timer as one_shot
	round_timer.wait_time = ROUND_DURATION
	round_timer.one_shot = true  # Set to one_shot to prevent auto-repeating

	# Ensure we start with a clean signal connection state
	_disconnect_round_timer()

	# Setup UI
	upgrade_container.get_node("UpgradePanel/VBoxContainer/VBoxContainer3/VBoxContainer/NewTileUpgrade/Button").pressed.connect(_on_new_tile_pressed)
	upgrade_container.get_node("UpgradePanel/VBoxContainer/VBoxContainer2/RestartButton").pressed.connect(_on_restart_pressed)

	# Initialize upgrade container position (offscreen)
	upgrade_container.modulate.a = 0
	var panel = upgrade_container.get_node("UpgradePanel")
	panel.position += UPGRADE_PANEL_OFFSET

	# Configure background to not follow any camera initially
	if background_layer:
		background_layer.follow_viewport_enabled = false

	# Initialize camera setup
	main_camera.enabled = true
	upgrade_camera.enabled = false
	active_camera = main_camera
	await get_tree().create_timer(10.0).timeout  # Waits for 1 second
	start_game()

func position_window_bottom_right():
	# Get the screen size
	var screen_size = DisplayServer.screen_get_size()

	# Get the current window size
	var window_size = DisplayServer.window_get_size()

	# Calculate position for bottom-right placement with a small margin (10 pixels)
	var margin = 10
	var position_x = screen_size.x - window_size.x - margin
	var position_y = screen_size.y - window_size.y - margin

	# Set the window position
	DisplayServer.window_set_position(Vector2i(position_x, position_y))

	# Optionally log the positioning for debugging
	print("Screen size: ", screen_size)
	print("Window size: ", window_size)
	print("Positioned window at: ", Vector2i(position_x, position_y))

func _connect_round_timer() -> void:
	if not round_timer_connected:
		print("Connecting round timer signal")
		round_timer.timeout.connect(_on_round_end)
		round_timer_connected = true

func _disconnect_round_timer() -> void:
	if round_timer_connected:
		print("Disconnecting round timer signal")
		if round_timer.timeout.is_connected(_on_round_end):
			round_timer.timeout.disconnect(_on_round_end)
		round_timer_connected = false
	elif round_timer.timeout.is_connected(_on_round_end):
		print("Disconnecting round timer (unexpected connection)")
		round_timer.timeout.disconnect(_on_round_end)
		round_timer_connected = false

func start_game() -> void:
	tiles_node.visible = true
	var original_positions = {}
	var available_tiles = []

	# First, collect only available (non-unlockable) tiles
	for tile in tiles_node.get_children():
		if not tile.has_node("Unlockable"):
			available_tiles.append(tile)
			original_positions[tile] = tile.position
			tile.position.y -= 200
			tile.modulate.a = 0
			tile.mouse_entered.connect(_on_tile_mouse_entered.bind(tile))
			tile.mouse_exited.connect(_on_tile_mouse_exited.bind(tile))

	# Hide progress bar initially
	place_progress.modulate.a = 0
	place_progress.max_value = PLANT_INTERVAL
	place_progress.value = 0

	_setup_initial_animations(original_positions, available_tiles)

func _process(delta):
	if game_started:
		if place_timer.time_left > 0:
			place_progress.value = PLANT_INTERVAL - place_timer.time_left

		# Update round timer display
		round_timer_label.text = str(int(round_timer.time_left))

func _start_planting_system():
	# Reset the round ended flag
	round_ended = false
	animation_debug_count = 0
	weather_sequence_started = false
	
	# Start the game and round timer
	game_started = true
	
	# Connect and start the round timer
	_connect_round_timer()
	round_timer.start()
	
	# Set up the timer to start weather transition 10 seconds before round end
	_setup_weather_transition_timer()
	if ROUND_DURATION > 5:
		weather_transition_timer.start(ROUND_DURATION - 5)
	
	# Rest of your existing code...
	# Fade in progress bar
	var fade_tween = create_tween()
	fade_tween.tween_property(place_progress, "modulate:a", 1.0, 0.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)
	
	# Start the planting timer
	place_timer.wait_time = PLANT_INTERVAL
	
	# Disconnect any existing connections to prevent duplicates
	if place_timer.timeout.is_connected(_on_place_timer_timeout):
		place_timer.timeout.disconnect(_on_place_timer_timeout)
	
	place_timer.timeout.connect(_on_place_timer_timeout)
	place_timer.start()

func _on_round_end() -> void:
	print("Round end triggered! Current round_ended state: ", round_ended)
	
	# If round already ended, don't do anything
	if round_ended:
		print("Round already ended, ignoring duplicate call")
		return
	
	# Disconnect the timer to prevent any further calls
	_disconnect_round_timer()
	
	# Set the round ended flag
	round_ended = true
	animation_debug_count = 0
	game_started = false
	place_timer.stop()
	
	# Cancel the weather transition timer if it's still running
	if weather_transition_timer and weather_transition_timer.time_left > 0:
		weather_transition_timer.stop()
	
	# If the weather sequence hasn't started yet, start it now
	if not weather_sequence_started:
		# Start the end-of-round animation sequence
		if rain_animation_player:
			print("Playing rain_end animation at round end")
			rain_animation_player.play("rain_end")
			
			# Wait for rain_end animation to finish before playing sunray animation
			await rain_animation_player.animation_finished
		
		if sunray_animation_player:
			print("Playing ray_start animation")
			sunray_animation_player.play("ray_start")
			
			# Wait for sunray animation before playing stars
			await sunray_animation_player.animation_finished
	else:
		# If the weather sequence was already started, just wait for the sunray animation to finish
		if sunray_animation_player and sunray_animation_player.is_playing():
			await sunray_animation_player.animation_finished
	
	# Play the stars animation
	if star_animation_player:
		animation_debug_count += 1
		print("Playing stars_move_right animation (count: ", animation_debug_count, ")")
		star_animation_player.play("stars_move_right")
	
	# Show upgrade container with sliding animation
	upgrade_container.show()
	var panel = upgrade_container.get_node("UpgradePanel")
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Slide in from the right
	tween.tween_property(panel, "position", panel.position - UPGRADE_PANEL_OFFSET, 0.5)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	
	# Fade in
	tween.tween_property(upgrade_container, "modulate:a", 1.0, 0.3)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)
	
	# Transition to upgrade camera - this is needed only when the round ends
	transition_to_camera(upgrade_camera)

func transition_to_camera(target_camera: Camera2D) -> void:
	# Rest of the function remains the same...
	if active_camera == target_camera:
		print("Already using this camera, skipping transition")
		return  # Already using this camera

	if camera_transition_in_progress:
		print("Camera transition already in progress, skipping")
		return  # Don't start another transition if one is already happening

	camera_transition_in_progress = true
	print("Starting camera transition from ", active_camera.name, " to ", target_camera.name)

	# Get the global transforms
	var current_position = active_camera.global_position
	var target_position = target_camera.global_position
	var current_zoom = active_camera.zoom
	var target_zoom = target_camera.zoom

	# Ensure both cameras are properly set up
	if !is_instance_valid(target_camera):
		print("ERROR: Target camera is not valid")
		camera_transition_in_progress = false
		return

	if !is_instance_valid(active_camera):
		print("ERROR: Active camera is not valid")
		camera_transition_in_progress = false
		return

	# Create a temporary camera for the transition
	var temp_camera = Camera2D.new()
	add_child(temp_camera)
	temp_camera.global_position = current_position
	temp_camera.zoom = current_zoom

	# Disable both permanent cameras and enable the temp camera
	active_camera.enabled = false
	target_camera.enabled = false
	temp_camera.enabled = true

	# Create a helper to handle background positioning
	var camera_helper = CameraTransitionHelper.new()
	add_child(camera_helper)
	camera_helper.global_position = current_position

	# Make sure background_layer exists
	if background_layer:
		camera_helper.initialize(background_layer, current_position, target_position)
		print("Background layer found, initializing helper")

	# Create the tween for smooth transition
	var tween = create_tween()
	tween.set_parallel(true)

	# Tween position for both the camera and the helper
	tween.tween_property(temp_camera, "global_position", target_position, CAMERA_TRANSITION_DURATION)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera_helper, "global_position", target_position, CAMERA_TRANSITION_DURATION)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	# Tween zoom if needed
	tween.tween_property(temp_camera, "zoom", target_zoom, CAMERA_TRANSITION_DURATION)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)

	# Chain a callback to handle completion properly
	tween.chain().tween_callback(func():
		print("Camera transition complete")
		temp_camera.enabled = false
		target_camera.enabled = true
		active_camera = target_camera
		camera_transition_in_progress = false
		print("New active camera: ", active_camera.name, " (enabled: ", active_camera.enabled, ")")
		temp_camera.queue_free()
		camera_helper.queue_free()
	)

func _on_new_tile_pressed() -> void:
	if unlockable_tiles.size() > 0:
		# Randomly select an unlockable tile
		var random_index = randi() % unlockable_tiles.size()
		var tile_to_unlock = unlockable_tiles[random_index]

		# Remove Unlockable node and show tile
		tile_to_unlock.get_node("Unlockable").queue_free()
		tile_to_unlock.show()

		# Add mouse events
		tile_to_unlock.mouse_entered.connect(_on_tile_mouse_entered.bind(tile_to_unlock))
		tile_to_unlock.mouse_exited.connect(_on_tile_mouse_exited.bind(tile_to_unlock))

		# Remove from unlockable tiles array
		unlockable_tiles.erase(tile_to_unlock)

		# Animate tile entrance
		tile_to_unlock.position.y -= 200
		tile_to_unlock.modulate.a = 0

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(tile_to_unlock, "position:y", tile_to_unlock.position.y + 200, 0.6)\
			.set_trans(Tween.TRANS_QUINT)\
			.set_ease(Tween.EASE_OUT)
		tween.tween_property(tile_to_unlock, "modulate:a", 1.0, 0.3)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN)

func _on_restart_pressed() -> void:
	print("Restart button pressed")
	animation_debug_count = 0
	weather_sequence_started = false

	# Reset the round ended flag
	round_ended = false

	# Play stars_move_left animation when restart is pressed
	if star_animation_player:
		animation_debug_count += 1
		print("Playing stars_move_left animation")
		star_animation_player.play("stars_move_left")
		
	# Hide sunrays if they're visible
	if sunray_animation_player:
		print("Playing ray_end animation")
		sunray_animation_player.play("ray_end")

	# Clear objects from previous round
	for obj in round_objects:
		if is_instance_valid(obj):  # Check if object still exists
			var tile = obj.get_parent()
			if tile and tile.has_method("set_occupied"):
				tile.set_occupied(false)
			obj.queue_free()
	round_objects.clear()

	# Hide upgrade container with sliding animation
	var panel = upgrade_container.get_node("UpgradePanel")
	var tween = create_tween()
	tween.set_parallel(true)

	# Slide out to the right
	tween.tween_property(panel, "position", panel.position + UPGRADE_PANEL_OFFSET, 0.5)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_IN)

	# Fade out
	tween.tween_property(upgrade_container, "modulate:a", 0.0, 0.3)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

	# Hide container after animation and transition to main camera
	tween.chain().tween_callback(func():
		print("Panel animation complete, hiding container")
		upgrade_container.hide()
		# Transition back to main camera when UI elements are hidden
		transition_to_camera(main_camera)

		# Start rain again for the new round
		if rain_animation_player:
			print("Playing rain_start animation for new round")
			rain_animation_player.play("rain_start")

		# Reset and start new round
		print("Starting new round")

		# Connect the round timer signal for the new round
		_connect_round_timer()
		round_timer.start()
		place_timer.start()
		game_started = true
	)

# Rest of the code stays the same
func _on_tile_mouse_entered(tile: Node) -> void:
	if not tile.is_occupied:
		currently_hovered_tile = tile

func _on_tile_mouse_exited(tile: Node) -> void:
	if currently_hovered_tile == tile:
		currently_hovered_tile = null

func _on_place_timer_timeout() -> void:
	if currently_hovered_tile and not currently_hovered_tile.is_occupied:
		_place_random_plant(currently_hovered_tile)
	place_timer.start()

func _place_random_plant(tile: Node) -> void:
	var random_plant_scene = plant_scenes[randi() % plant_scenes.size()]
	var plant_instance = random_plant_scene.instantiate()

	tile.add_child(plant_instance)
	plant_instance.position = Vector2.ZERO

	tile.set_occupied(true)
	round_objects.append(plant_instance)  # Track the new object

	var tween = create_tween()
	tween.tween_property(plant_instance, "scale", Vector2.ONE, 0.3)\
		.from(Vector2.ZERO)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

	if plant_instance.has_method("play_placed_sound"):
		plant_instance.play_placed_sound()

func _setup_initial_animations(original_positions: Dictionary, available_tiles: Array) -> void:
	
	var total_tiles = available_tiles.size()
	var total_animation_time = (0.25 * (total_tiles - 1)) + 0.6

	# Create a single timer for managing sound scheduling
	var sound_scheduler = Timer.new()
	add_child(sound_scheduler)
	sound_scheduler.one_shot = true

	for i in total_tiles:
		var tile = available_tiles[i]
		var play_time = (0.25 * i) + 0.6 - AUDIO_COMPENSATION

		# Create a tween for sound timing instead of multiple timers
		var tween = create_tween()
		tween.tween_callback(func():
			if tile.land_sound:
				tile.land_sound.play()
		).set_delay(play_time)

	# Remove the sound scheduler after all sounds have played
	var cleanup_tween = create_tween()
	cleanup_tween.tween_callback(func():
		sound_scheduler.queue_free()
	).set_delay(total_animation_time + 0.2)

	var delay = 0.0
	for tile in available_tiles:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(tile, "position", original_positions[tile], 0.6)\
			.set_trans(Tween.TRANS_QUINT)\
			.set_ease(Tween.EASE_OUT)\
			.set_delay(delay)
		tween.tween_property(tile, "modulate:a", 1.0, 0.3)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN)\
			.set_delay(delay)
		delay += 0.25

	# Setup clouds animation
	clouds_node.show()

	# Hide all clouds and rain initially
	var clouds = clouds_node.get_children().filter(func(node): return node is Sprite2D)
	var rain = clouds_node.get_node("Rain")

	for cloud in clouds:
		cloud.modulate.a = 0
		cloud.position.y -= 50  # Start slightly higher

	rain.material.set_shader_parameter("rain_color", Color(1, 1, 1, 0))  # Start with transparent rain

	# Create cloud appear sequence
	var cloud_delay = total_animation_time  # Start after tiles are done
	for cloud in clouds:
		var cloud_tween = create_tween()
		cloud_tween.set_parallel(true)

		# Fade in and move down
		cloud_tween.tween_property(cloud, "modulate:a", 1.0, 0.5)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)\
			.set_delay(cloud_delay)
		cloud_tween.tween_property(cloud, "position:y", cloud.position.y + 50, 0.7)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)\
			.set_delay(cloud_delay)
		cloud_delay += 0.2  # Offset each cloud's appearance

	# Start rain after all clouds are in place
	var rain_tween = create_tween()
	rain_tween.tween_method(
		func(value: float): rain.material.set_shader_parameter("rain_color", Color(1, 1, 1, value)),
		0.0,
		1.0,
		1.0
	).set_delay(cloud_delay + 0.3)  # Start after last cloud appears
	
	# Play rain animation after a short delay
	var rain_animation_tween = create_tween()
	rain_animation_tween.tween_callback(func():
		if rain_animation_player:
			print("Playing rain_start animation")
			rain_animation_player.play("rain_start")
	).set_delay(cloud_delay + 0.6)  # Start rain animation after material effect begins
	
	# Calculate the final animation time to include cloud animations
	var final_delay = cloud_delay + 1.0  # Add extra time for rain animation to be visible

	# Start the planting system after all animations are complete
	var startup_timer = Timer.new()
	add_child(startup_timer)
	startup_timer.one_shot = true
	startup_timer.timeout.connect(_start_planting_system)
	startup_timer.start(final_delay)

# Add this function to initialize the weather transition timer
func _setup_weather_transition_timer():
	# Remove any existing timer
	if weather_transition_timer:
		weather_transition_timer.queue_free()
		
	# Create a new timer for weather transition
	weather_transition_timer = Timer.new()
	add_child(weather_transition_timer)
	weather_transition_timer.one_shot = true
	weather_transition_timer.timeout.connect(_start_weather_transition)

# Add this function to start the weather transition sequence
func _start_weather_transition():
	if weather_sequence_started:
		return
	
	weather_sequence_started = true
	print("Starting weather transition sequence")
	
	# Start rain end animation
	if rain_animation_player:
		print("Playing rain_end animation early")
		rain_animation_player.play("rain_end")
		
		# Wait for rain_end animation to finish before playing sunray animation
		await rain_animation_player.animation_finished
	
	# Then play sunray animation
	if sunray_animation_player:
		print("Playing ray_start animation")
		sunray_animation_player.play("ray_start")
