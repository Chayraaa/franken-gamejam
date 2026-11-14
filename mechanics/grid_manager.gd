extends Node2D
class_name GridManager

var start_grid: Dictionary[Vector2i, BlockBase] = {}
var solution_grid: Dictionary[Vector2i, BlockBase] = {}
@export var display_grid: TileMapLayer
var placement_grid: TileMapLayer
@export var size: Vector2i
var grid_origin: Vector2i = Vector2i.ZERO
var solution: Array[Dictionary] = []
var selected_button: ButtonPuzzle
var preview: BlockBase
var editing_locked: bool = false
var interaction_blocked: bool = false
var goal_tick_count: int = 0
var simulation_finished: bool = false
const GOAL_TICKS_REQUIRED: int = 3
var run_timer: Timer
# Only blocks placed by the player have an inventory owner.
var placed_buttons: Dictionary[BlockBase, ButtonPuzzle] = {}

# Priority list for the simulation
@export var step_order: Array[Script] = [
	preload("res://mechanics/blocks/pusher/pusher.gd"),
	preload("res://mechanics/blocks/mover/mover.gd"),
	preload("res://mechanics/blocks/cloner/cloner.gd"),
	preload("res://mechanics/blocks/box/box.gd"),
]

signal step_finished(data: Array[Dictionary])
signal goal_tick_count_changed(count: int)


func _ready() -> void:
	run_timer = Timer.new()
	run_timer.wait_time = 0.5
	run_timer.timeout.connect(step)
	add_child(run_timer)
	if display_grid != null:
		load_grid(display_grid)


func load_grid(layer: TileMapLayer, build_layer: TileMapLayer = null) -> void:
	stop_running()
	editing_locked = false
	simulation_finished = false
	goal_tick_count = 0
	goal_tick_count_changed.emit(goal_tick_count)
	cancel_placement()
	placed_buttons.clear()
	start_grid.clear()
	solution_grid.clear()
	solution.clear()
	display_grid = layer
	placement_grid = build_layer
	display_grid.update_internals()
	for child in display_grid.get_children():
		if child is BlockBase and not child.is_queued_for_deletion():
			var cell := display_grid.local_to_map(child.position)
			child.setup(cell, self)
			start_grid[cell] = child


func select_block(button: ButtonPuzzle) -> void:
	if editing_locked or interaction_blocked:
		return
	cancel_placement()
	if button.count <= 0 or display_grid == null:
		return
	selected_button = button
	preview = button.block.instantiate() as BlockBase
	preview.setup(Vector2i.ZERO, self)
	preview.process_mode = Node.PROCESS_MODE_DISABLED
	display_grid.add_child(preview)
	preview.z_index = 100
	_update_preview()


func cancel_placement() -> void:
	if is_instance_valid(preview):
		preview.queue_free()
	preview = null
	selected_button = null


func _update_preview() -> void:
	if not is_instance_valid(preview):
		return
	var cell := display_grid.local_to_map(display_grid.get_local_mouse_position())
	preview.position = display_grid.map_to_local(cell)
	preview.visible = is_inside(cell) and not _mouse_over_ui()
	preview.modulate = Color(1, 1, 1, 0.5) if can_place_at(cell) else Color(1, 0.3, 0.3, 0.5)


func _mouse_over_ui() -> bool:
	return get_viewport().gui_get_hovered_control() != null


func _input(event: InputEvent) -> void:
	# Cancellation also works when the cursor is over the UI.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if selected_button != null:
			cancel_placement()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if editing_locked or interaction_blocked or display_grid == null or not event is InputEventMouseButton or not event.pressed:
		return
	var cell := display_grid.local_to_map(display_grid.get_local_mouse_position())
	if event.button_index == MOUSE_BUTTON_LEFT and is_instance_valid(selected_button):
		_place_selected_block(cell)
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_remove_block(cell)
		get_viewport().set_input_as_handled()


func _place_selected_block(cell: Vector2i) -> void:
	if editing_locked or interaction_blocked or not is_instance_valid(selected_button):
		return
	if not can_place_at(cell) or selected_button.count <= 0:
		return
	var button := selected_button
	var block := button.block.instantiate() as BlockBase
	block.setup(cell, self)
	block.position = display_grid.map_to_local(cell)
	block.rotation = preview.rotation
	if block is Rotator and preview is Rotator:
		block.clockwise = preview.clockwise
	start_grid[cell] = block
	placed_buttons[block] = button
	display_grid.add_child(block)
	button.count -= 1
	if button.count <= 0:
		cancel_placement()
	else:
		_update_preview()

func start_running() -> void:
	if interaction_blocked or simulation_finished or not run_timer.is_stopped():
		return
	step()
	if not simulation_finished:
		run_timer.start()


func stop_running() -> void:
	if is_instance_valid(run_timer):
		run_timer.stop()


func step() -> void:
	if interaction_blocked or simulation_finished:
		return
	editing_locked = true
	cancel_placement()
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
	_update_goal_ticks()


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
	if editing_locked or interaction_blocked:
		return
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
	if event.keycode != KEY_R:
		return
	if is_instance_valid(preview):
		_rotate_by_player(preview)
		get_viewport().set_input_as_handled()
		return
	var block := _get_block_at(cell)
	if block != null:
		_rotate_by_player(block)
		get_viewport().set_input_as_handled()


# Player input changes a rotator's direction; simulation rotation stays geometric.
func _rotate_by_player(block: BlockBase) -> void:
	if block is Rotator:
		block.clockwise = not block.clockwise
	else:
		block.rotation += PI / 2.0


func _remove_block(cell: Vector2i) -> void:
	if editing_locked or interaction_blocked:
		return
	var block := _get_block_at(cell)
	if block == null or not placed_buttons.has(block):
		return
	var button := placed_buttons[block]
	if is_instance_valid(button):
		button.count += 1
	placed_buttons.erase(block)
	start_grid.erase(cell)
	for planned_cell in solution_grid.keys():
		if solution_grid[planned_cell] == block:
			solution_grid.erase(planned_cell)
	for i in range(solution.size() - 1, -1, -1):
		if solution[i]["block"] == block:
			solution.remove_at(i)
	block.queue_free()



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	_update_preview()
	if Input.is_action_just_pressed("step") and run_timer.is_stopped():
		step()


func _on_step_finished(data: Array[Dictionary]) -> void:
	if display_grid == null:
		return
	for entry in data:
		var block: BlockBase = entry["block"]
		var change: Dictionary = entry["data"]
		block.position = display_grid.map_to_local(change["to"])
		block.rotation = change["rot"]

# Building restrictions apply only to player placement, not simulation movement.
func can_place_at(cell: Vector2i) -> bool:
	if not is_inside(cell) or start_grid.has(cell) or placement_grid == null:
		return false
	var world_position := display_grid.to_global(display_grid.map_to_local(cell))
	var build_cell := placement_grid.local_to_map(placement_grid.to_local(world_position))
	var tile := placement_grid.get_cell_tile_data(build_cell)
	if tile == null or placement_grid.tile_set.get_custom_data_layer_by_name("buildable") < 0:
		return false
	return tile.get_custom_data("buildable") == true


# Checks if inside map bounds
func is_inside(pos: Vector2i) -> bool:
	return Rect2i(grid_origin, size).has_point(pos)


func _update_goal_ticks() -> void:
	var occupied := false
	if placement_grid != null and placement_grid.tile_set != null:
		if placement_grid.tile_set.get_custom_data_layer_by_name("goal") >= 0:
			for cell: Vector2i in start_grid:
				var world_position := display_grid.to_global(display_grid.map_to_local(cell))
				var goal_cell := placement_grid.local_to_map(placement_grid.to_local(world_position))
				var tile := placement_grid.get_cell_tile_data(goal_cell)
				if tile != null and tile.get_custom_data("goal") == true:
					occupied = true
					break
	goal_tick_count = goal_tick_count + 1 if occupied else 0
	if goal_tick_count >= GOAL_TICKS_REQUIRED:
		simulation_finished = true
		stop_running()
	goal_tick_count_changed.emit(goal_tick_count)
