extends Node2D
class_name GridManager

var start_grid: Dictionary[Vector2i, BlockBase] = {}
var solution_grid: Dictionary[Vector2i, BlockBase] = {}
@export var display_grid: TileMapLayer
@export var size: Vector2i
var solution: Array[Dictionary] = []

signal step_finished(data: Array[Dictionary])


func _ready() -> void:
	if display_grid == null:
		return
	display_grid.update_internals()
	for child in display_grid.get_children():
		if child is BlockBase:
			var cell := display_grid.local_to_map(child.position)
			child.setup(cell, self)
			start_grid[cell] = child

func step() -> void:
	solution.clear()
	solution_grid.clear()
	for cell in start_grid:
		var block: BlockBase = start_grid[cell]
		var entry: Variant = block.step()
		if entry != null:
			solution.append({"block": block, "data": entry})

	for cell in start_grid:
		var block: BlockBase = start_grid[cell]
		if not solution.any(func(entry): return entry["block"] == block):
			if not block._spawn(cell):
				push_error("Multiple blocks claim cell %s" % cell)
				return
			else:
				solution.append({"block": block, "data": {"from": cell, "to": cell, "rot": block.rotation}})

	start_grid = solution_grid.duplicate()
	for cell in start_grid:
		var block: BlockBase = start_grid[cell]
		block.cell = cell
	step_finished.emit(solution.duplicate())


func _get_block_at(cell: Vector2i) -> BlockBase:
	return start_grid.get(cell)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		step()


func _on_step_finished(data: Array[Dictionary]) -> void:
	if display_grid == null:
		return
	for entry in data:
		var block: BlockBase = entry["block"]
		var change: Dictionary = entry["data"]
		block.position = display_grid.map_to_local(change["to"])
		block.rotation = change["rot"]

# Checks if inside map bounds
func is_inside(pos: Vector2i) -> bool:
	return (
			pos.x >= 0 and pos.x < size.x
			and pos.y >= 0 and pos.y < size.y
	)