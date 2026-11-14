extends Node2D


func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			print("Sprite clicked!")


func _on_area_2d_mouse_entered() -> void:
	%Sprite2D.get_material().set_shader_parameter("width", 1)


func _on_area_2d_mouse_exited() -> void:
	%Sprite2D.get_material().set_shader_parameter("width", 0)
