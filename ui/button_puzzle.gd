extends Button
class_name ButtonPuzzle

var count: int
var block: PackedScene
@onready var icon_display: TextureRect = $Content/Icon
@onready var count_label: Label = $Content/Count

var grid_manager: GridManager

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	if block != null:
		var component := block.instantiate()
		var sprite := component.get_node_or_null("Sprite2D") as Sprite2D
		if sprite != null:
			icon_display.texture = sprite.texture
		component.free()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	disabled = grid_manager.editing_locked or grid_manager.interaction_blocked or count <= 0
	var display_text = block.resource_path.get_file().get_basename() + ": " + str(count)
	count_label.text = display_text


func _on_pressed() -> void:
	if count <= 0:
		return
	grid_manager.select_block(self)
