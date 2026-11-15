extends Node2D
class_name GameManager

@export var dialogue_manager: DialogueManager

var appeared_event: int = 0
@onready var locations: Array[Clickable] = [
	$waterpumps2D,
	$reactorroom2D,
	$generator2D,
	$fridge2D,
	$turbine2D,
	$coolingwaterres2D,
	$warmwaterres2D
]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	generate_event()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func generate_event() -> void:
	appeared_event = randi_range(0, locations.size() - 1)
	locations[appeared_event].display_event()

func apply_damage(damage: int) -> void:
	if damage > 0:
		%HealthBar.value = clampf(%HealthBar.value - damage, %HealthBar.min_value, %HealthBar.max_value)
	elif damage < 0:
		%RepairBar.value = clampf(%RepairBar.value - damage, %RepairBar.min_value, %RepairBar.max_value)

func set_visibility(b: bool) -> void:
	visible = b
	if b:
		%GameBG.show()
		%Bars.show()
	else:
		%GameBG.hide()
		%Bars.hide()
func _on_waterpumps_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	_event_clicked($waterpumps2D)

func _on_reactorroom_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	_event_clicked($reactorroom2D)

func _on_generator_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	_event_clicked($generator2D)


func _on_fridge_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	_event_clicked($fridge2D)


func _on_turbine_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	_event_clicked($turbine2D)


func _on_coolingwaterres_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	_event_clicked($coolingwaterres2D)


func _on_warmwaterres_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	_event_clicked($warmwaterres2D)

func _event_clicked(location: Clickable) -> void:
	if appeared_event == locations.find(location):
		locations[appeared_event].hide_event()
		set_visibility(false)
		dialogue_manager.load_dialogue()
