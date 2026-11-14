extends Node2D
class_name Level

@export var building_blocks: Array[Dictionary]
@export_multiline var display_text: Array[String]
@export_range(1.0, 120.0, 1.0) var dialog_letters_per_second: float = 30.0
@onready var cell_grid: TileMapLayer = $CellLayer
@onready var base_grid: TileMapLayer = $GridLayer
@onready var text_display: RichTextLabel = %TextDisplay
@onready var skip_button: Button = %SkipButton
@onready var dialog_box: Control = text_display.get_parent()

var dialog_index: int = -1
var dialog_active: bool = false
var dialog_reveal_tween: Tween
signal dialog_finished()


func show_text() -> void:
	dialog_index = 0
	dialog_active = not display_text.is_empty()
	dialog_box.visible = dialog_active
	text_display.visible = dialog_active
	if dialog_active:
		var ancestor := text_display.get_parent()
		while ancestor != null and ancestor != self:
			if ancestor is CanvasItem or ancestor is CanvasLayer:
				ancestor.show()
			ancestor = ancestor.get_parent()
		_reveal_dialog_text()


func advance_dialog() -> void:
	if not dialog_active:
		return
	if dialog_reveal_tween != null and dialog_reveal_tween.is_running():
		dialog_reveal_tween.kill()
		text_display.visible_characters = -1
		return
	dialog_index += 1
	if dialog_index < display_text.size():
		_reveal_dialog_text()
	else:
		hide_dialog()
		dialog_finished.emit()


func skip_dialog() -> void:
	if not dialog_active:
		return
	hide_dialog()
	dialog_finished.emit()


func hide_dialog() -> void:
	if dialog_reveal_tween != null:
		dialog_reveal_tween.kill()
	dialog_active = false
	text_display.hide()
	dialog_box.hide()


func _reveal_dialog_text() -> void:
	if dialog_reveal_tween != null:
		dialog_reveal_tween.kill()
	text_display.bbcode_enabled = true
	text_display.text = display_text[dialog_index]
	text_display.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	text_display.visible_characters = 0
	var letters := text_display.get_total_character_count()
	if letters == 0:
		text_display.visible_characters = -1
		return
	dialog_reveal_tween = create_tween()
	dialog_reveal_tween.tween_property(
		text_display, "visible_characters", letters,
		float(letters) / dialog_letters_per_second
	)
	dialog_reveal_tween.tween_callback(func(): text_display.visible_characters = -1)


func _ready() -> void:
	_add_board_backing()
	skip_button.pressed.connect(skip_dialog)
	# The fullscreen layout should not block puzzle clicks after the dialog.
	text_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var control := text_display.get_parent()
	while control is Control:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		control = control.get_parent()
	hide_dialog()


# Include both floor tiles and preplaced blocks, including transformed layers.
func get_world_bounds() -> Rect2:
	var bounds := Rect2()
	var has_bounds := false
	for layer: TileMapLayer in [base_grid, cell_grid]:
		var used := layer.get_used_rect()
		if not used.has_area() or layer.tile_set == null:
			continue
		var half_tile := Vector2(layer.tile_set.tile_size) / 2.0
		var first := layer.map_to_local(used.position) - half_tile
		var last := layer.map_to_local(used.end - Vector2i.ONE) + half_tile
		for corner in [first, Vector2(last.x, first.y), last, Vector2(first.x, last.y)]:
			var point := layer.to_global(corner)
			if not has_bounds:
				bounds = Rect2(point, Vector2.ZERO)
				has_bounds = true
			else:
				bounds = bounds.expand(point)
	return bounds


# Bounds in CellLayer coordinates, including tiles left/above the origin.
func get_grid_bounds() -> Rect2i:
	var bounds := Rect2i()
	var has_cells := false
	for layer: TileMapLayer in [base_grid, cell_grid]:
		for tile_cell in layer.get_used_cells():
			var world_position := layer.to_global(layer.map_to_local(tile_cell))
			var cell := cell_grid.local_to_map(cell_grid.to_local(world_position))
			var cell_rect := Rect2i(cell, Vector2i.ONE)
			bounds = bounds.merge(cell_rect) if has_cells else cell_rect
			has_cells = true
	return bounds


# Floor textures contain alpha; keep the screen background from showing through.
func _add_board_backing() -> void:
	var bounds := get_world_bounds()
	if not bounds.has_area():
		return
	var backing := Polygon2D.new()
	backing.name = "BoardBacking"
	backing.z_index = mini(base_grid.z_index, cell_grid.z_index) - 1
	backing.color = Color(0.29, 0.29, 0.29, 1.0)
	backing.polygon = PackedVector2Array([
		to_local(bounds.position),
		to_local(Vector2(bounds.end.x, bounds.position.y)),
		to_local(bounds.end),
		to_local(Vector2(bounds.position.x, bounds.end.y)),
	])
	add_child(backing)

func set_visibility(b: bool) -> void:
	get_child(2).visible = b
	visible = b
