extends Control
## Simple level select UI.
## Can be added to main menu or accessed via pause menu.

## Emitted when a level is selected
signal level_selected(level_path: String)

## Available levels with display names
var levels: Array[Dictionary] = [
	{"name": "Level 1 (Tutorial)", "path": "res://main_game_scene.tscn"},
	{"name": "Level 2 (Checkpoints)", "path": "res://main_game_scene_level2.tscn"}
]

@onready var level_list: VBoxContainer = $CenterContainer/VBoxContainer/LevelList

func _ready() -> void:
	_populate_level_list()


func _populate_level_list() -> void:
	# Clear existing buttons
	for child in level_list.get_children():
		child.queue_free()

	# Create button for each level
	for i in levels.size():
		var level_info: Dictionary = levels[i]
		var button := Button.new()
		button.text = level_info["name"]
		button.pressed.connect(_on_level_button_pressed.bind(level_info["path"]))
		level_list.add_child(button)


func _on_level_button_pressed(level_path: String) -> void:
	level_selected.emit(level_path)
	get_tree().change_scene_to_file(level_path)
