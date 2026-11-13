extends Node2D
class_name BlockBase

var grid: GridManager
var cell: Vector2i
var moved_directions: Array[Vector2i] = []
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

# Current position after all actions already planned in this step.
func get_planned_cell() -> Vector2i:
	var planned: Variant = grid.solution_grid.find_key(self)
	return cell if planned == null else planned


# Validate the complete chain before changing any reservations.
func collect_push(dir: Vector2i, chain: Array[BlockBase]) -> bool:
	# This block already used its movement in this direction. It cannot
	# vacate another cell for a second push in the same step.
	if dir in moved_directions:
		return false
	var target := get_planned_cell() + dir
	if not grid.is_inside(target):
		return false

	var other: BlockBase = grid.get_planned_block_at(target)
	if other != null:
		if not other.collect_push(dir, chain):
			return false

	chain.append(self)
	return true


func push(dir: Vector2i) -> bool:
	if abs(dir.x) + abs(dir.y) != 1:
		return false
	# Being pushed in our own direction already fulfilled this action.
	if dir in moved_directions:
		return true

	var chain: Array[BlockBase] = []
	if not collect_push(dir, chain):
		return false

	# Capture destinations before updating any of the reservations.
	var destinations: Array[Vector2i] = []
	for block in chain:
		destinations.append(block.get_planned_cell() + dir)
	for block in chain:
		var old: Variant = grid.solution_grid.find_key(block)
		if old != null:
			grid.solution_grid.erase(old)

	for i in range(chain.size()):
		var block := chain[i]
		var target := destinations[i]
		grid.solution_grid[target] = block
		block.moved_directions.append(dir)
		var recorded := false
		for entry in grid.solution:
			if entry["block"] == block:
				entry["data"]["to"] = target
				recorded = true
				break
		if not recorded:
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
