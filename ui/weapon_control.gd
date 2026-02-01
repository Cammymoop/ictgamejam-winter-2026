extends MarginContainer

@onready var weapon_name_label: RichTextLabel = find_child("WeaponNameLabel")
@onready var panel_container: PanelContainer = find_child("PanelContainer")

@onready var anim_player: AnimationPlayer = find_child("AnimationPlayer")

@export var bg_border_width: int = 4
@export var weapon_data: WeaponData = null

func set_is_selected(new_is_selected: bool) -> void:
    anim_player.play_with_capture("select" if new_is_selected else "deselect", -1, -1, 1, false, Tween.TRANS_QUINT, Tween.EASE_IN)

func set_weapon_data(new_weapon_data: WeaponData) -> void:
    weapon_data = new_weapon_data
    update_visuals()

func update_visuals() -> void:
    if not weapon_data:
        weapon_name_label.text = ""
        set_bg_color(Color.GRAY)
        return
    weapon_name_label.text = "[b]" + weapon_data.name + "[/b]"
    weapon_name_label.add_theme_color_override("default_color", weapon_data.base_color.darkened(0.8))
    set_bg_color(weapon_data.projectile_color)


func set_bg_color(color: Color) -> void:
    var pc_stylebox: StyleBoxFlat = panel_container.get_theme_stylebox("panel")
    pc_stylebox.bg_color = color

#func set_bg_border_on(new_on: bool) -> void:
    #var pc_stylebox: StyleBoxFlat = panel_container.get_theme_stylebox("panel")

