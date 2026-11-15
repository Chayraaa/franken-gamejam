extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_play_pressed() -> void:
	visible = false
	%MenuUI.hide()
	get_tree().change_scene_to_file("res://main.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()

func set_visibility(b: bool) -> void:
	visible = b
	if b:
		%MenuUI.show()
	else:
		%MenuUI.hide()
