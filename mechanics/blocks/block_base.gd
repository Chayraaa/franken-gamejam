extends Node
class_name BlockBase

var grid: TileMapLayer


# Inits a block at a pos in a grid - not added to the scene yet
func _init(pos: Vector2i, grid_container: TileMapLayer) -> void:
	self.grid = grid_container

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# Moves the block to a pos on the grid if possible. Return shows success
func move(pos: Vector2i) -> bool:
	return false

# Pushes the block one field in the provided direction if possible. Return shows success
func push(dir: Vector2i) -> bool:
	return false

# When the block should be destroyed. Return shows success
func destroy() -> bool:
	return false