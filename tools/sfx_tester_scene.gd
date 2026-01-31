extends Node3D

@onready var mesh_label: MeshInstance3D = $MeshLabel
@onready var text_mesh: TextMesh = mesh_label.mesh

var sound_names: Array[String] = [
    "zap", "charge_whine", "fanfare", "chime",
    "tick", "boom", "grunt", "thud",
    "whoosh",
]
var test_sounds: Array[AudioStream] = []
var sound_i: = -1

func _ready() -> void:
    for sound_name in sound_names:
        test_sounds.append(SFXManager.create_sound(sound_name))

func _process(_delta: float) -> void:
    if Input.is_action_just_pressed("shoot"):
        sound_i += 1
        if sound_i >= test_sounds.size():
            sound_i = 0
        play_sound(sound_i)
    elif Input.is_action_just_pressed("move_up"):
        play_sound(sound_i)

func play_sound(sound_idx: int) -> void:
    show_sound_name(sound_names[sound_idx])
    SFXManager.play_sfx(test_sounds[sound_idx])

func show_sound_name(sound_name: String) -> void:
    text_mesh.text = sound_name.capitalize()