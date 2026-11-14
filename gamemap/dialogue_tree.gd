extends Node2D
class_name DialogueTree

@export_multiline var task_text: String
@export_range(1, 100, 1) var level_number: int = 1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func on_accept() -> void:
	pass
	
func on_decline() -> void:
	pass
