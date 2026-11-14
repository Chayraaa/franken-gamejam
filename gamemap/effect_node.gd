extends Node2D
class_name EffectNode

@export var damage: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func trigger_effect() -> void:
	print("Damage dealt/healed: " + str(damage))
