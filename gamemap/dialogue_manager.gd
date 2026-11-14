extends Node2D
class_name DialogueManager

const DialogueTreeResource = preload("res://gamemap/dialogue_tree.gd")

@export var current_task: int = 0
@export var level_manager: LevelManager
@onready var text_field: RichTextLabel = %TaskTextBody
var task_in_progress: bool = false


func _ready() -> void:
	%TaskAcceptButton.focus_mode = Control.FOCUS_NONE
	%TaskDeclineButton.focus_mode = Control.FOCUS_NONE
	load_dialogue()


func load_dialogue() -> void:
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
	if task_in_progress or current_task >= %DialogueRoot.get_child_count():
		return
	var task := %DialogueRoot.get_child(current_task) as DialogueTreeResource
	if level_manager == null or task.level_number > level_manager.levels.get_child_count():
		return
	task_in_progress = true
	visible = false
	%DialogueUI.hide()
	level_manager.current_level = task.level_number
	level_manager.set_visibility(true)
	level_manager.load_level(true)


func _on_task_decline_button_pressed() -> void:
	if task_in_progress or current_task >= %DialogueRoot.get_child_count():
		return
	var task := %DialogueRoot.get_child(current_task) as DialogueTreeResource
	if task.get_child_count() > 1:
		task.get_child(1).trigger_effect()
	current_task += 1
	load_dialogue()


func _on_level_manager_level_finished() -> void:
	if not task_in_progress:
		return
	task_in_progress = false
	level_manager.set_visibility(false)
	var task := %DialogueRoot.get_child(current_task) as DialogueTreeResource
	if task.get_child_count() > 0:
		task.get_child(0).trigger_effect()
	current_task += 1
	load_dialogue()
