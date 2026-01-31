extends MeshInstance3D

@export var texture_variants: Array[Texture] = []

func _ready() -> void:
    var variant: = texture_variants.pick_random() as Texture
    assert(variant, "No texture variants found")
    material_override.albedo_texture = variant

