@tool
extends Control

func _ready() -> void:
    child_order_changed.connect(_on_child_list_changed)
    _on_child_list_changed()

func _on_child_list_changed() -> void:
    watch_child_signals()
    recalc_minimum_size()

func _on_main_child_minimum_size_changed() -> void:
    recalc_minimum_size()

func watch_child_signals() -> void:
    var is_main_child: = true
    for c in get_children():
        if c is Control:
            if not c.visibility_changed.is_connected(_on_child_list_changed):
                c.visibility_changed.connect(_on_child_list_changed)
            if c.visible:
                if is_main_child:
                    is_main_child = false
                    if not c.minimum_size_changed.is_connected(_on_main_child_minimum_size_changed):
                        c.minimum_size_changed.connect(_on_main_child_minimum_size_changed)
                elif c.minimum_size_changed.is_connected(_on_main_child_minimum_size_changed):
                    c.minimum_size_changed.disconnect(_on_main_child_minimum_size_changed)

func recalc_minimum_size() -> void:
    var main_child: Control
    for c in get_children():
        if c is Control and c.visible:
            main_child = c
            break
    
    if not main_child:
        custom_minimum_size = Vector2.ZERO
        return
    
    var old_min: = custom_minimum_size
    custom_minimum_size = main_child.get_minimum_size()
    if old_min != custom_minimum_size:
        minimum_size_changed.emit()
