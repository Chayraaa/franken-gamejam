extends Node2D

signal input_event(viewport: Node, event: InputEvent, shape_idx: int)

func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			print("Sprite clicked!")
			input_event.emit()


func _on_area_2d_mouse_entered() -> void:
#	%Sprite2D.get_material().set_shader_parameter("width", 1)
	pass


func _on_area_2d_mouse_exited() -> void:
	#%Sprite2D.get_material().set_shader_parameter("width", 0)
	pass
