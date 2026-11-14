extends BlockBase
class_name Cloner

# Direction of the output at zero root rotation.
@export var base_direction: Vector2 = Vector2.RIGHT


func step() -> Variant:
	var dir := Vector2i(base_direction.rotated(rotation).round())
	if abs(dir.x) + abs(dir.y) != 1:
		return null

	var planned_cell: Variant = grid.solution_grid.find_key(self)
	var origin: Vector2i = cell if planned_cell == null else planned_cell
	var target := origin + dir
	var source: BlockBase = grid.get_planned_block_at(origin - dir)
	if source == null or not grid.is_inside(target):
		return null
	var obstacle := grid.get_planned_block_at(target)
	if obstacle != null:
		if not obstacle.push(dir):
			return null
		# A block already moved in this direction may report success without
		# moving again. Only clone once the output cell is actually free.
		if grid.get_planned_block_at(target) != null:
			return null

	# Preserve the source's script, exported settings, children and rotation.
	# Do not copy signal connections to the original instance's listeners.
	var copy := source.duplicate(
		Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS | Node.DUPLICATE_USE_INSTANTIATION
	) as BlockBase
	if copy == null:
		return null
	copy.setup(target, grid)
	copy.moved_directions = []
	grid.solution_grid[target] = copy
	grid.solution.append({
		"block": copy,
		"data": {
			"from": target,
			"to": target,
			"rot": copy.rotation,
			"spawned": true,
		},
	})
	# Cloning does not change the cloner's planned movement.
	return null
