extends VBoxContainer

const WeaponControl = preload("res://ui/weapon_control.gd")
#var weapon_control_template: Control = preload("res://ui/weapon_control.tscn")

var last_weapon_selected: int = 0

func _ready() -> void:
    await get_tree().process_frame
    var player: = Util.get_player_ref()
    update_weapon_list(player.weapon_manager)
    player.weapon_manager.weapon_changed.connect(current_weapon_changed.bind(player.weapon_manager))

func current_weapon_changed(_weapon_idx: int, _weapon_data: WeaponData, weapon_manager: WeaponManager) -> void:
    print("current_weapon_changed: ", _weapon_idx)
    update_selected_weapon(weapon_manager)

func update_selected_weapon(weapon_manager: WeaponManager, force_set: bool = false) -> void:
    if last_weapon_selected == weapon_manager.current_weapon_index and not force_set:
        return
    last_weapon_selected = weapon_manager.current_weapon_index

    var weapon_idx: int = 0
    for weapon_control in get_children():
        if not weapon_control is WeaponControl:
            continue
        weapon_control.set_is_selected(weapon_idx == weapon_manager.current_weapon_index)
        weapon_idx += 1
        if weapon_idx >= weapon_manager.weapons.size():
            return

func update_weapon_list(weapon_manager: WeaponManager) -> void:
    var weapon_idx: int = 0
    for weapon_control in get_children():
        if not weapon_control is WeaponControl:
            continue
        if weapon_idx >= weapon_manager.weapons.size():
            weapon_control.visible = false
            continue
        weapon_control.visible = true
        weapon_control.set_weapon_data(weapon_manager.weapons[weapon_idx])
        weapon_idx += 1
    update_selected_weapon(weapon_manager, true)