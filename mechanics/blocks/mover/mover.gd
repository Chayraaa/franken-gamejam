extends BlockBase
class_name Mover

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func step() -> Variant:
	var start: Vector2i = grid.start_grid.find_key(self)
	var success: bool = push(Vector2i(1, 0))
	if success:
		return {"from": start, "to": grid.solution_grid.find_key(self), "rot": rotation}
	else:
		return null

