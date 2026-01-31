extends Control

@export var player_stats: EntityStats = null
@onready var health_ui: Control = find_child("HealthUI")

func _ready() -> void:
    assert(player_stats, "HUD: PlayerStats not found")
    
    health_ui.set_entity_stats(player_stats)