extends Control

func _ready() -> void:
	hide()
	%RestartButton.pressed.connect(_on_restart_pressed)

func show_screen() -> void:
	show()

func hide_screen() -> void:
	hide()

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
