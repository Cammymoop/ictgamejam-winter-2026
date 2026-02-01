extends Node
class_name TimerSet

@onready var parent: Node = get_parent()
var timers: Dictionary[String, Timer] = {}

func start_new_timer(t_name: String, wait_time: float, on_timeout: Callable = Callable(), repeat: bool = false) -> Timer:
    var t: = add_timer(t_name, wait_time, on_timeout, repeat)
    t.start()
    return t

func add_timer(t_name: String, wait_time: float, on_timeout: Callable = Callable(), repeat: bool = false) -> Timer:
    var timer: Timer = Timer.new()
    timer.name = t_name
    timer.wait_time = wait_time
    timer.one_shot = not repeat
    if on_timeout != Callable():
        timer.timeout.connect(on_timeout)
    add_child(timer, true)
    return timer

func get_timer(t_name: String) -> Timer:
    if not timers.has(t_name):
        push_warning("Timer %s not found: %s" % [t_name, get_path()])
        return null
    return timers[t_name]

func start(t_name: String, with_time: float = -1) -> void:
    if not timers.has(t_name):
        push_warning("Timer %s not found: %s" % [t_name, get_path()])
    var t: Timer = timers[t_name]
    if t.paused:
        t.paused = false
    t.start(with_time)

func stop(t_name: String) -> void:
    if not timers.has(t_name):
        push_warning("Timer %s not found: %s" % [t_name, get_path()])
    var t: Timer = timers[t_name]
    if not t.paused:
        t.paused = true
    t.stop()

func pause(t_name: String) -> void:
    if not timers.has(t_name):
        push_warning("Timer %s not found: %s" % [t_name, get_path()])
    var t: Timer = timers[t_name]
    if not t.is_stopped():
        t.paused = true

func resume(t_name: String) -> void:
    if not timers.has(t_name):
        push_warning("Timer %s not found: %s" % [t_name, get_path()])
    var t: Timer = timers[t_name]
    if not t.is_stopped():
        t.paused = false

func connect_timeout(t_name: String, callback: Callable, conn_flags: int = 0) -> void:
    if not timers.has(t_name):
        push_warning("Timer %s not found: %s" % [t_name, get_path()])
    timers[t_name].timeout.connect(callback, conn_flags)

func disconnect_timeout(t_name: String, callback: Callable) -> void:
    if not timers.has(t_name):
        push_warning("Timer %s not found: %s" % [t_name, get_path()])
    timers[t_name].timeout.disconnect(callback)

func is_running(t_name: String) -> bool:
    if not timers.has(t_name):
        push_warning("Timer %s not found: %s" % [t_name, get_path()])
        return false
    return not timers[t_name].is_stopped() and not timers[t_name].paused

func is_stopped(t_name: String) -> bool:
    if not timers.has(t_name):
        push_warning("Timer %s not found: %s" % [t_name, get_path()])
        return false
    return timers[t_name].is_stopped()

func remove(t_name: String, emit_timeout: bool = false) -> void:
    if not timers.has(t_name):
        return
    var t: Timer = timers[t_name]
    if emit_timeout:
        t.timeout.emit()
    remove_child(t)
    t.queue_free()
    timers.erase(t_name)

func time_left(t_name: String) -> float:
    if not timers.has(t_name):
        push_warning("Timer %s not found: %s" % [t_name, get_path()])
        return 0
    return timers[t_name].time_left
