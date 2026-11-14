extends Node2D
class_name DialogueManager

@export var current_task: int = 0

@onready var text_field: RichTextLabel = %TaskTextBody

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	load_dialogue()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func load_dialogue() -> void:
	print("loaded")
	if %DialogueRoot.get_child_count() <= current_task:
		return
	var to_load: DialogueTree = %DialogueRoot.get_child(current_task)
	print(to_load)
	text_field.text = to_load.task_text

func _on_task_accept_button_pressed() -> void:
	# Lade das level
	# Temp:
	if %DialogueRoot.get_child_count() <= current_task:
		return
	var to_load: DialogueTree = %DialogueRoot.get_child(current_task)
	print(to_load.get_children())
	to_load.get_child(0).trigger_effect()
	current_task += 1
	load_dialogue()
	


func _on_task_decline_button_pressed() -> void:
	if %DialogueRoot.get_child_count() <= current_task:
		return
	var to_load: DialogueTree = %DialogueRoot.get_child(current_task)
	to_load.get_child(1).trigger_effect()
	current_task += 1
	load_dialogue()
