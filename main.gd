extends Node2D

func _ready() -> void:
	%LevelManager.set_visibility(false)
	%Dialogues.set_visibility(false)

	start_game_loop()


func start_game_loop() -> void:
	# 5 Sekunden warten
	await get_tree().create_timer(5.0).timeout

	# Gamemap ausblenden
	%Gamemap.set_visibility(false)

	# Dialogues einblenden
	%Dialogues.set_visibility(true)
