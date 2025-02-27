extends Sprite2D
@onready var animation_player = $AnimationPlayer

func _ready():
	# Start with zero scale
	scale = Vector2.ZERO
	
	# Create a tween for scaling up
	var scale_up_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	scale_up_tween.tween_property(self, "scale", Vector2(1, 1), 1.5)
	
	# Connect the tween's finished signal to play the animation
	scale_up_tween.finished.connect(func():
		animation_player.play("play_firework")
		
		# Create a timer for 5 seconds
		var timer = get_tree().create_timer(5.0)
		timer.timeout.connect(func():
			# Stop the animation
			animation_player.stop()
			
			# Create a tween for scaling down
			var scale_down_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			scale_down_tween.tween_property(self, "scale", Vector2.ZERO, 0.5)
			
			# Optional: queue_free when completely scaled down
			scale_down_tween.finished.connect(func():
				# Uncomment the next line if you want the firework to be removed from the scene
				# queue_free()
				pass
			)
		)
	)
