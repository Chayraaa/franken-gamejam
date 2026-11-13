extends BlockBase
class_name Mover

@export var base_direction: Vector2 = Vector2.RIGHT

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func step() -> Variant:
	var dir := Vector2i(base_direction.rotated(rotation).round())
	push(dir)
	return null

