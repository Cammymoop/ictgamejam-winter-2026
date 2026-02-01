extends RefCounted

var _util: Node = null

func test_layer_to_bit() -> bool:
	# layer_to_bit converts 1-indexed layer to bit value
	# Layer 1 -> bit 0 -> value 1
	# Layer 2 -> bit 1 -> value 2
	# Layer 3 -> bit 2 -> value 4
	_util = preload("res://static/util.gd").new()

	if _util.layer_to_bit(1) != 1:
		return false
	if _util.layer_to_bit(2) != 2:
		return false
	if _util.layer_to_bit(3) != 4:
		return false
	if _util.layer_to_bit(4) != 8:
		return false

	return true

func _cleanup() -> void:
	if _util:
		_util.free()
		_util = null
