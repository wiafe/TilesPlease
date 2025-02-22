extends Node2D

@export var tiles_node: Node2D
@export var place_progress: ProgressBar
@export var place_timer: Timer
#@export var animation_player: AnimationPlayer
@export var round_timer_label: Label
@export var round_timer: Timer
@export var upgrade_container: Control
@export var clouds_node: Node2D

const AUDIO_COMPENSATION = 0.35
const PLANT_INTERVAL = 2.0
const ROUND_DURATION = 20  # Round duration in seconds
const UPGRADE_PANEL_OFFSET = Vector2(400, 0)  # Amount to slide the panel

const AGAVE_SCENE = preload("res://placeable_objects/plants/agave.tscn")
const BAMBOO_SCENE = preload("res://placeable_objects/plants/bamboo.tscn")
const RUBBLE_SCENE = preload("res://placeable_objects/trash/rubble.tscn")

var plant_scenes = [
	AGAVE_SCENE,
	BAMBOO_SCENE,
	RUBBLE_SCENE,
]

var currently_hovered_tile: Node = null
var unlockable_tiles: Array[Node] = []
var game_started := false
var round_objects := []  # Track objects placed in current round

func _ready():
	if not tiles_node:
		print("No tiles node assigned!")
		return
		
	# Collect unlockable tiles
	for tile in tiles_node.get_children():
		if tile.has_node("Unlockable"):
			unlockable_tiles.append(tile)
	
	# Setup round timer
	round_timer.wait_time = ROUND_DURATION
	round_timer.timeout.connect(_on_round_end)
	
	# Setup UI
	upgrade_container.get_node("UpgradePanel/VBoxContainer/VBoxContainer3/VBoxContainer/NewTileUpgrade/Button").pressed.connect(_on_new_tile_pressed)
	upgrade_container.get_node("UpgradePanel/VBoxContainer/VBoxContainer2/RestartButton").pressed.connect(_on_restart_pressed)
	
	# Initialize upgrade container position (offscreen)
	upgrade_container.modulate.a = 0
	var panel = upgrade_container.get_node("UpgradePanel")
	panel.position += UPGRADE_PANEL_OFFSET
	
	start_game()

func start_game() -> void:
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
	
	# Schedule initial animations only for available tiles
	_setup_initial_animations(original_positions, available_tiles)
	#animation_player.play("clouds_moving")

func _process(delta):
	if game_started:
		if place_timer.time_left > 0:
			place_progress.value = PLANT_INTERVAL - place_timer.time_left
		
		# Update round timer display
		round_timer_label.text = str(int(round_timer.time_left))

func _start_planting_system():
	# Start the game and round timer
	game_started = true
	round_timer.start()
	
	# Fade in progress bar
	var fade_tween = create_tween()
	fade_tween.tween_property(place_progress, "modulate:a", 1.0, 0.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)
	
	# Start the planting timer
	place_timer.wait_time = PLANT_INTERVAL
	place_timer.timeout.connect(_on_place_timer_timeout)
	place_timer.start()

func _on_round_end() -> void:
	game_started = false
	place_timer.stop()
	
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
	
	# Hide container after animation
	tween.chain().tween_callback(func(): upgrade_container.hide())
	
	# Reset and start new round
	round_timer.start()
	place_timer.start()
	game_started = true

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
		.set_trans(Tween.TRANS_BACK)\
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
	
	var startup_timer = Timer.new()
	add_child(startup_timer)
	startup_timer.one_shot = true
	startup_timer.timeout.connect(_start_planting_system)
	startup_timer.start(total_animation_time + 0.1)
	
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
