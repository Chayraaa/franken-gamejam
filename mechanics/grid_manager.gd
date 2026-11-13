extends Node2D
class_name GridManager

# Keys 1 through 6, in this order. Load scenes only when placing a block.
const BLOCK_SCENE_PATHS: Array[String] = [
	"res://mechanics/blocks/box/box.tscn",
	"res://mechanics/blocks/mover/mover.tscn",
	"res://mechanics/blocks/pusher/pusher.tscn",
	"res://mechanics/blocks/rotator/rotator.tscn",
	"res://mechanics/blocks/cloner/cloner.tscn",
	"res://mechanics/blocks/wall/wall.tscn",
]

var start_grid: Dictionary[Vector2i, BlockBase] = {}
var solution_grid: Dictionary[Vector2i, BlockBase] = {}
@export var display_grid: TileMapLayer
@export var size: Vector2i
var solution: Array[Dictionary] = []

# Priority list for the simulation
@export var step_order: Array[Script] = [
	preload("res://mechanics/blocks/pusher/pusher.gd"),
	preload("res://mechanics/blocks/mover/mover.gd"),
	preload("res://mechanics/blocks/cloner/cloner.gd"),
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
		block.moved_directions.clear()
	# Rotation must not reserve cells or mark blocks as already handled.
	for block in blocks:
		block.prepare_step()

	for block in blocks:
		# A movement reservation does not consume the block's own action.
		# push() counts an earlier push in the same direction as this move.
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
		# New blocks enter the scene only after all actions have finished.
		# They receive their first turn in the next step.
		if block.get_parent() == null:
			if display_grid != null:
				block.position = display_grid.map_to_local(cell)
				display_grid.add_child(block)
			else:
				add_child(block)
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


func get_planned_block_at(cell: Vector2i) -> BlockBase:
	if solution_grid.has(cell):
		return solution_grid[cell]
	var original: BlockBase = start_grid.get(cell)
	if original != null and solution_grid.find_key(original) == null:
		return original
	return null


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return
	if display_grid == null:
		return

	var cell := display_grid.local_to_map(display_grid.get_local_mouse_position())
	if event.keycode == KEY_DELETE:
		_remove_block(cell)
		get_viewport().set_input_as_handled()
		return
	var key_index: int = event.keycode - KEY_1
	if key_index >= 0 and key_index < BLOCK_SCENE_PATHS.size():
		_place_block(cell, key_index)
		get_viewport().set_input_as_handled()
		return
	if event.keycode != KEY_R:
		return
	var block := _get_block_at(cell)
	if block != null:
		block.rotation += PI / 2.0
		get_viewport().set_input_as_handled()


func _remove_block(cell: Vector2i) -> void:
	var block := _get_block_at(cell)
	if block == null:
		return
	start_grid.erase(cell)
	for planned_cell in solution_grid.keys():
		if solution_grid[planned_cell] == block:
			solution_grid.erase(planned_cell)
	for i in range(solution.size() - 1, -1, -1):
		if solution[i]["block"] == block:
			solution.remove_at(i)
	block.queue_free()


func _place_block(cell: Vector2i, block_index: int) -> void:
	if not is_inside(cell) or start_grid.has(cell):
		return
	var scene := load(BLOCK_SCENE_PATHS[block_index]) as PackedScene
	var block := scene.instantiate() as BlockBase
	block.setup(cell, self)
	block.position = display_grid.map_to_local(cell)
	start_grid[cell] = block
	display_grid.add_child(block)


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
