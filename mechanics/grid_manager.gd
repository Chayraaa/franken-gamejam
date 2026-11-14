extends Node2D
class_name GridManager

var start_grid: Dictionary[Vector2i, BlockBase] = {}
var solution_grid: Dictionary[Vector2i, BlockBase] = {}
@export var display_grid: TileMapLayer
var placement_grid: TileMapLayer
@export var size: Vector2i
@export_range(0.0, 2.0, 0.05) var step_animation_duration: float = 0.3
var is_animating: bool = false
var step_tween: Tween
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
	cancel_step_animation()
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
	# Decorative controls are not interactive UI. Child labels/icons still count
	# as hovering their button even if their own mouse filter changes.
	var control := get_viewport().gui_get_hovered_control()
	while control != null:
		if control is BaseButton:
			return true
		control = control.get_parent_control()
	return false


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
	if is_animating or interaction_blocked or simulation_finished or not run_timer.is_stopped():
		return
	step()
	if not simulation_finished:
		run_timer.start()


func stop_running() -> void:
	if is_instance_valid(run_timer):
		run_timer.stop()


func step() -> void:
	if is_animating or interaction_blocked or simulation_finished:
		return
	editing_locked = true
	cancel_placement()
	solution.clear()
	solution_grid.clear()
	var blocks: Array[BlockBase] = []
	blocks.assign(start_grid.values())
	blocks.sort_custom(_comes_before)
	var previous_visuals: Dictionary = {}
	for block in blocks:
		previous_visuals[block] = {"position": block.position, "rotation": block.rotation}
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

	# A mover at a corner may vacate a cell only after its followers tried to
	# move. Retry blocked movers until no further cell can be freed. Successful
	# movers are excluded, so this never grants an extra movement in a tick.
	var pending_movers: Array[BlockBase] = []
	for block in blocks:
		if block is Mover and block.moved_directions.is_empty():
			pending_movers.append(block)
	while not pending_movers.is_empty():
		var made_progress := false
		for block in pending_movers.duplicate():
			if block.moved_directions.is_empty():
				block.step()
			if not block.moved_directions.is_empty():
				pending_movers.erase(block)
				made_progress = true
		if not made_progress:
			break

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
	_animate_step(solution.duplicate(), previous_visuals)


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


func cancel_step_animation() -> void:
	if step_tween != null:
		step_tween.kill()
	is_animating = false


func _animate_step(data: Array[Dictionary], previous_visuals: Dictionary) -> void:
	for entry in data:
		var block: BlockBase = entry["block"]
		entry["data"]["rotation_before"] = previous_visuals[block]["rotation"] if previous_visuals.has(block) else block.rotation
	if display_grid == null or step_animation_duration <= 0.0:
		_finish_animated_step(data)
		return
	is_animating = true
	step_tween = create_tween().set_parallel(true)
	step_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for entry in data:
		var block: BlockBase = entry["block"]
		var change: Dictionary = entry["data"]
		var destination := display_grid.map_to_local(change["to"])
		var final_rotation: float = change["rot"]
		if previous_visuals.has(block):
			# Simulation needs final rotations to calculate movement, but the
			# renderer starts from the previous pose. Never tween simulation state.
			block.position = previous_visuals[block]["position"]
			block.rotation = previous_visuals[block]["rotation"]
		else:
			block.position = destination
			block.rotation = final_rotation
			var final_alpha := block.modulate.a
			block.modulate.a = 0.0
			step_tween.tween_property(block, "modulate:a", final_alpha, step_animation_duration)
		step_tween.tween_property(block, "position", destination, step_animation_duration)
		step_tween.tween_property(block, "rotation", final_rotation, step_animation_duration)
	step_tween.chain().tween_callback(_finish_animated_step.bind(data))


func _finish_animated_step(data: Array[Dictionary]) -> void:
	# Restore exact end poses after interpolation (also handles duration = 0).
	if display_grid != null:
		for entry in data:
			var block: BlockBase = entry["block"]
			block.position = display_grid.map_to_local(entry["data"]["to"])
			block.rotation = entry["data"]["rot"]
	is_animating = false
	_update_goal_ticks(data)
	step_finished.emit(data)


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


func _update_goal_ticks(data: Array[Dictionary]) -> void:
	var all_still := true
	var goal_count := 0
	var changes: Dictionary = {}
	for entry in data:
		changes[entry["block"]] = entry["data"]
	if placement_grid != null and placement_grid.tile_set != null:
		if placement_grid.tile_set.get_custom_data_layer_by_name("goal") >= 0:
			for goal_cell in placement_grid.get_used_cells():
				var tile := placement_grid.get_cell_tile_data(goal_cell)
				if tile == null or tile.get_custom_data("goal") != true:
					continue
				goal_count += 1
				var world_position := placement_grid.to_global(placement_grid.map_to_local(goal_cell))
				var cell := display_grid.local_to_map(display_grid.to_local(world_position))
				var block := _get_block_at(cell)
				if block == null or not changes.has(block):
					all_still = false
					continue
				var change: Dictionary = changes[block]
				# Arrival, cloning, pushing and rotation all interrupt the hold.
				if change.get("spawned", false) or change["from"] != change["to"]:
					all_still = false
				if not block.moved_directions.is_empty():
					all_still = false
				if not is_equal_approx(float(change["rotation_before"]), float(change["rot"])):
					all_still = false
	goal_tick_count = goal_tick_count + 1 if goal_count > 0 and all_still else 0
	if goal_tick_count >= GOAL_TICKS_REQUIRED:
		simulation_finished = true
		stop_running()
	goal_tick_count_changed.emit(goal_tick_count)
