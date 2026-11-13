extends Node2D
class_name BlockBase

var grid: GridManager
var cell: Vector2i
@export var block_id: int


# Registers an existing scene instance with its grid.
func setup(pos: Vector2i, grid_manager: GridManager) -> void:
	self.grid = grid_manager
	self.cell = pos


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass  # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# Reserve a cell in the next state, leaving the current state unchanged.
func _spawn(pos: Vector2i) -> bool:
	if grid.solution_grid.has(pos):
		return false
	grid.solution_grid[pos] = self
	return true

# Moves the block to a pos on the grid if possible. Return shows success
func move(pos: Vector2i) -> bool:
	return false

# Pushes the block one field in the provided direction if possible. Return shows success
func collect_push(dir: Vector2i, chain: Array[BlockBase]) -> bool:
	var target := cell + dir
	if grid.solution_grid.find_key(self) != null:
		return grid.solution_grid.get(target) == self

	if not grid.is_inside(target):
		return false

	if grid.solution_grid.has(target):
		return false

	var other: BlockBase = grid.start_grid.get(target)
	if other != null:
		if not other.collect_push(dir, chain):
			return false

	chain.append(self)
	return true


func push(dir: Vector2i) -> bool:
	if abs(dir.x) + abs(dir.y) != 1:
		return false

	var chain: Array[BlockBase] = []
	if not collect_push(dir, chain):
		return false

	for block in chain:
		var target := block.cell + dir
		grid.solution_grid[target] = block
		grid.solution.append({
			"block": block,
			"data": {
				"from": block.cell,
				"to": target,
				"rot": block.rotation,
			},
		})

	return true

# When the block should be destroyed. Return shows success
func destroy() -> bool:
	return false

func step() -> Variant: return null
