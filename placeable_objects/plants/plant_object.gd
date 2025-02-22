extends Node2D

var placeable_object: PlaceableObject

func _ready():
	placeable_object = find_child("PlaceableObject") as PlaceableObject
	if not placeable_object:
		push_error("PlaceableObject node not found in plant!")

func play_placed_sound():
	if not placeable_object:
		return
		
	if has_node("Plant"):
		placeable_object.get_node("PlacedPlantAudio").play()
	elif has_node("Trash"):
		placeable_object.get_node("PlacedTrashAudio").play()
