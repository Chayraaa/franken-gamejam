extends Node2D
class_name LevelManager

@export var current_level: int = 1
@export var camera_padding: float = 48.0

@onready var level_camera: Camera2D = $Camera2D

@onready var levels: Node2D = %Levels
@onready var grid_manager: GridManager = %GridManager
@onready var button_container: HBoxContainer = %ButtonContainer
@onready var button_base: PackedScene = preload("res://ui/button-puzzle.tscn")

var initial_levels: Array[PackedScene] = []
var goal_tick_count: int = 0
var goal_title_tween: Tween
var completion_confirmed: bool = false
var resume_run_after_dialog: bool = false

@onready var step_button: Button = %StepButton
@onready var run_button: Button = %RunButton
@onready var reset_button: Button = %ResetButton
@onready var dialog_button: Button = %DialogButton
@onready var goal_tick_title: Label = %GoalTickTitle
@onready var completion_screen: ColorRect = %CompletionScreen
@onready var completion_reset_button: Button = %CompletionResetButton
@onready var continue_button: Button = %ContinueButton

signal level_finished()
signal goal_tick_count_changed(count: int)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for level: Level in levels.get_children():
		var snapshot := PackedScene.new()
		snapshot.pack(level)
		initial_levels.append(snapshot)
		level.visible = false
	
	grid_manager.goal_tick_count_changed.connect(_on_goal_tick_count_changed)
	step_button.pressed.connect(grid_manager.step)
	run_button.pressed.connect(grid_manager.start_running)
	reset_button.pressed.connect(reset_level)
	dialog_button.pressed.connect(show_instructions)
	completion_reset_button.pressed.connect(reset_level)
	continue_button.pressed.connect(_on_continue_pressed)
	for button in [step_button, run_button, reset_button, dialog_button, completion_reset_button, continue_button]:
		button.focus_mode = Control.FOCUS_NONE
	get_viewport().size_changed.connect(_fit_camera)
	load_level()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	var running := not grid_manager.run_timer.is_stopped()
	step_button.disabled = running or grid_manager.simulation_finished or grid_manager.interaction_blocked
	run_button.disabled = running or grid_manager.simulation_finished or grid_manager.interaction_blocked
	reset_button.disabled = grid_manager.interaction_blocked
	dialog_button.disabled = grid_manager.interaction_blocked or grid_manager.simulation_finished

func reset_level() -> void:
	grid_manager.stop_running()
	grid_manager.cancel_placement()
	var index := current_level - 1
	if index < 0 or index >= initial_levels.size():
		return
	var old_level := levels.get_child(index) as Level
	old_level.hide_dialog()
	levels.remove_child(old_level)
	old_level.queue_free()
	var restored := initial_levels[index].instantiate() as Level
	levels.add_child(restored)
	levels.move_child(restored, index)
	load_level(false)


func load_level(show_dialog: bool = true) -> void:
	completion_screen.hide()
	completion_confirmed = false
	resume_run_after_dialog = false
	if current_level > levels.get_child_count():
		return
	var to_load: Level = levels.get_child(current_level - 1)
	var grid_bounds := to_load.get_grid_bounds()
	grid_manager.size = grid_bounds.size
	grid_manager.grid_origin = grid_bounds.position
	grid_manager.load_grid(to_load.cell_grid, to_load.base_grid)
	for child in button_container.get_children():
		if child is ButtonPuzzle:
			button_container.remove_child(child)
			child.queue_free()
	for item in to_load.building_blocks:
		_spawn_button(item["block"], item["count"])
	for level: Level in levels.get_children():
		level.visible = level == to_load
		level.hide_dialog()
	if not to_load.dialog_finished.is_connected(_on_dialog_finished):
		to_load.dialog_finished.connect(_on_dialog_finished)
	if show_dialog:
		to_load.show_text()
	grid_manager.interaction_blocked = to_load.dialog_active
	_fit_camera()

func _spawn_button(block: PackedScene, count: int) -> void:
	var new_button: ButtonPuzzle = button_base.instantiate()
	new_button.block = block
	new_button.count = count
	new_button.grid_manager = grid_manager
	button_container.add_child(new_button)
	button_container.move_child(new_button, 1)
	


func _fit_camera() -> void:
	var index := current_level - 1
	if index < 0 or index >= levels.get_child_count():
		return
	var level := levels.get_child(index) as Level
	var bounds := level.get_world_bounds()
	if not bounds.has_area():
		return
	var viewport_size := get_viewport_rect().size
	var available := (viewport_size - Vector2.ONE * camera_padding * 2.0).max(Vector2.ONE)
	var fit_zoom := minf(available.x / bounds.size.x, available.y / bounds.size.y)
	# Whole-number enlargement keeps pixel art sharp; small windows can zoom out.
	if fit_zoom >= 1.0:
		fit_zoom = floorf(fit_zoom)
	level_camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	level_camera.global_position = bounds.get_center()
	level_camera.zoom = Vector2.ONE * fit_zoom
	level_camera.reset_smoothing()
	level_camera.force_update_scroll()


func _on_goal_tick_count_changed(count: int) -> void:
	goal_tick_count = count
	_animate_goal_title(count)
	goal_tick_count_changed.emit(count)


func _animate_goal_title(count: int) -> void:
	if goal_title_tween != null:
		goal_title_tween.kill()
	if count <= 0:
		goal_tick_title.hide()
		goal_tick_title.text = ""
		goal_tick_title.modulate.a = 0.0
		return
	goal_tick_title.text = str(count)
	goal_tick_title.modulate.a = 0.0
	goal_tick_title.show()
	goal_title_tween = create_tween()
	goal_title_tween.tween_property(goal_tick_title, "modulate:a", 1.0, 0.15)
	goal_title_tween.tween_interval(0.35)
	goal_title_tween.tween_property(goal_tick_title, "modulate:a", 0.0, 0.3)
	goal_title_tween.tween_callback(goal_tick_title.hide)
	if count == GridManager.GOAL_TICKS_REQUIRED:
		goal_title_tween.tween_callback(_show_completion_screen)


func _show_completion_screen() -> void:
	if grid_manager.simulation_finished and not completion_confirmed:
		completion_screen.show()


func _on_continue_pressed() -> void:
	if not completion_screen.visible or completion_confirmed:
		return
	completion_confirmed = true
	completion_screen.hide()
	for level: Level in levels.get_children():
		level.visible = false
	
	# temp:
	current_level += 1
	load_level(true)
	level_finished.emit()


func _input(event: InputEvent) -> void:
	if not grid_manager.interaction_blocked:
		return
	if event is InputEventMouseButton:
		# Consume the final click too, so it cannot place a block or press Step.
		get_viewport().set_input_as_handled()
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var level := levels.get_child(current_level - 1) as Level
			if level.skip_button.get_global_rect().has_point(level.skip_button.get_global_mouse_position()):
				level.skip_dialog()
			else:
				level.advance_dialog()


func _on_dialog_finished() -> void:
	grid_manager.interaction_blocked = false
	if resume_run_after_dialog:
		resume_run_after_dialog = false
		grid_manager.run_timer.start()


func show_instructions() -> void:
	if grid_manager.interaction_blocked or grid_manager.simulation_finished:
		return
	var level := levels.get_child(current_level - 1) as Level
	if level.display_text.is_empty():
		return
	resume_run_after_dialog = not grid_manager.run_timer.is_stopped()
	grid_manager.stop_running()
	grid_manager.cancel_placement()
	level.show_text()
	grid_manager.interaction_blocked = level.dialog_active
