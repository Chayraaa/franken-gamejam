extends Node2D
class_name GridManager

var start_grid: Dictionary[Vector2i, BlockBase] = {}
var solution_grid: Dictionary[Vector2i, BlockBase] = {}
@export var display_grid: TileMapLayer
@export var size: Vector2i
var solution: Array[Dictionary] = []

# Priority list for the simulation
@export var step_order: Array[Script] = [
	preload("res://mechanics/blocks/pusher/pusher.gd"),
	preload("res://mechanics/blocks/mover/mover.gd"),
	preload("res://mechanics/blocks/box/box.gd"),
]

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
	var blocks: Array[BlockBase] = []
	blocks.assign(start_grid.values())
	blocks.sort_custom(_comes_before)
	for block in blocks:
		if solution.any(func(item): return item["block"] == block):
			continue
		var entry: Variant = block.step()
		if entry != null and not solution.any(func(item): return item["block"] == block):
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


func get_step_priority(block: BlockBase) -> int:
	for i in range(step_order.size()):
		if step_order[i] != null and is_instance_of(block, step_order[i]):
			return i
	return step_order.size()


func _comes_before(a: BlockBase, b: BlockBase) -> bool:
	var priority_a := get_step_priority(a)
	var priority_b := get_step_priority(b)
	if priority_a != priority_b:
		return priority_a < priority_b
	if a.cell.y != b.cell.y:
		return a.cell.y < b.cell.y
	return a.cell.x < b.cell.x


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
