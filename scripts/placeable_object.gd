class_name PlaceableObject
extends Node

@export var placed_plant_audio: AudioStreamPlayer
@export var placed_trash_audio: AudioStreamPlayer

# Called when the node enters the scene tree for the first time.
func _ready():
	add_to_group("placeableObject")
