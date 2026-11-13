extends BlockBase
class_name Wall


# Reject the entire push during validation, before any block moves.
func collect_push(_dir: Vector2i, _chain: Array[BlockBase]) -> bool:
	return false
