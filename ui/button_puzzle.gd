extends Button
class_name ButtonPuzzle

var count: int
var block: PackedScene
var grid_manager: GridManager

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	focus_mode = Control.FOCUS_NONE


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	disabled = grid_manager.editing_locked or grid_manager.interaction_blocked or count <= 0
	var display_text = block.resource_path.get_file().get_basename() + ": " + str(count)
	text = display_text


func _on_pressed() -> void:
	if count <= 0:
		return
	grid_manager.select_block(self)
