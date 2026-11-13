extends BlockBase
class_name Rotator

@export var clockwise: bool = true


func prepare_step() -> void:
	var angle := PI / 2.0 if clockwise else -PI / 2.0
	for dir in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var other: BlockBase = grid.start_grid.get(cell + dir)
		if other != null:
			# Multiple rotators add their rotations before actions begin.
			other.rotation += angle
