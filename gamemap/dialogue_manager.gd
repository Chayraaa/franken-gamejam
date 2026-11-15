extends Node2D
class_name DialogueManager

const DialogueTreeResource = preload("res://gamemap/dialogue_tree.gd")

@export var current_task: int = 0
@export var current_level: int = 1
@export var level_manager: LevelManager
@export var game_manager: GameManager
@onready var text_field: RichTextLabel = %TaskTextBody
var task_in_progress: bool = false
var showing_effect: bool = false


func _ready() -> void:
	%TaskAcceptButton.focus_mode = Control.FOCUS_NONE
	%TaskDeclineButton.focus_mode = Control.FOCUS_NONE
	load_dialogue()


func load_dialogue() -> void:
	showing_effect = false
	%TaskAcceptButton.text = "Accept"
	%TaskDeclineButton.show()
	%TaskAcceptButton.get_parent().get_node("Control3").show()
	visible = true
	%DialogueUI.show()
	var has_task := current_task >= 0 and current_task < %DialogueRoot.get_child_count()
	%TaskAcceptButton.disabled = not has_task
	%TaskDeclineButton.disabled = not has_task
	if not has_task:
		text_field.text = "Alle Aufträge abgeschlossen."
		return
	var task := %DialogueRoot.get_child(current_task) as DialogueTreeResource
	text_field.text = task.task_text


func _on_task_accept_button_pressed() -> void:
	if showing_effect:
		showing_effect = false
		set_visibility(false)
		game_manager.generate_event()
		game_manager.set_visibility(true)
		return
	if task_in_progress or current_task >= %DialogueRoot.get_child_count():
		return
	var task := %DialogueRoot.get_child(current_task) as DialogueTreeResource
	if level_manager == null or task.level_number > level_manager.levels.get_child_count():
		return
	task_in_progress = true
	visible = false
	%DialogueUI.hide()
	if task.good:
		level_manager.current_level = current_level
		level_manager.set_visibility(true)
		level_manager.load_level(true)
	else:
		task_in_progress = false
		current_task += 1
		_show_effect(task.get_child(0) as EffectNode if task.get_child_count() > 0 else null)


func _on_task_decline_button_pressed() -> void:
	if showing_effect or task_in_progress or current_task >= %DialogueRoot.get_child_count():
		return
	var task := %DialogueRoot.get_child(current_task) as DialogueTreeResource
	current_task += 1
	_show_effect(task.get_child(1) as EffectNode if task.get_child_count() > 1 else null)


func _on_level_manager_level_finished() -> void:
	if not task_in_progress:
		return
	task_in_progress = false
	level_manager.set_visibility(false)
	var task := %DialogueRoot.get_child(current_task) as DialogueTreeResource
	current_task += 1
	current_level += 1
	_show_effect(task.get_child(0) as EffectNode if task.get_child_count() > 0 else null)


func _show_effect(effect: EffectNode) -> void:
	if effect != null:
		effect.trigger_effect()
		game_manager.apply_damage(effect.damage)
		if not effect.effect_text.strip_edges().is_empty():
			showing_effect = true
			text_field.text = effect.effect_text
			%TaskAcceptButton.text = "Understood"
			%TaskAcceptButton.disabled = false
			%TaskDeclineButton.hide()
			%TaskAcceptButton.get_parent().get_node("Control3").hide()
			game_manager.set_visibility(false)
			set_visibility(true)
			return
	set_visibility(false)
	game_manager.generate_event()
	game_manager.set_visibility(true)

func set_visibility(b: bool) -> void:
	visible = b
	if b:
		%DialogueUI.show()
	else:
		%DialogueUI.hide()
