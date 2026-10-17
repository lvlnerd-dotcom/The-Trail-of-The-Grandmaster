class_name FogOfWarSystem
extends Node

## FogOfWarSystem: Manages 3-tier grid tile visibility:
## HIDDEN (unexplored pitch black), EXPLORED (memory/dimmed), VISIBLE (direct line of sight).

enum TileVisibility {
	HIDDEN = 0,
	EXPLORED = 1,
	VISIBLE = 2
}

signal visibility_updated(visible_cells: Array[Vector2i])

var grid_width: int = 80
var grid_height: int = 60
var visibility_buffer: PackedByteArray = PackedByteArray()
var current_visible_cells: Array[Vector2i] = []

func init_fog(p_width: int, p_height: int) -> void:
	grid_width = p_width
	grid_height = p_height
	var total = grid_width * grid_height
	visibility_buffer.resize(total)
	visibility_buffer.fill(TileVisibility.HIDDEN)
	current_visible_cells.clear()

func _cell_to_index(cell: Vector2i) -> int:
	if cell.x < 0 or cell.x >= grid_width or cell.y < 0 or cell.y >= grid_height:
		return -1
	return cell.y * grid_width + cell.x

func get_visibility(cell: Vector2i) -> TileVisibility:
	var idx = _cell_to_index(cell)
	if idx == -1 or idx >= visibility_buffer.size():
		return TileVisibility.HIDDEN
	return visibility_buffer[idx] as TileVisibility

func is_visible(cell: Vector2i) -> bool:
	return get_visibility(cell) == TileVisibility.VISIBLE

func is_explored(cell: Vector2i) -> bool:
	var vis = get_visibility(cell)
	return vis == TileVisibility.EXPLORED or vis == TileVisibility.VISIBLE

func set_visibility(cell: Vector2i, state: TileVisibility) -> void:
	var idx = _cell_to_index(cell)
	if idx != -1 and idx < visibility_buffer.size():
		visibility_buffer[idx] = state

## Updates the field-of-view from origin out to sight_radius.
## Demotes previously visible cells to EXPLORED, and raycasts to illuminate new cells.
func update_visibility(origin: Vector2i, sight_radius: int, grid: DungeonGrid) -> void:
	if visibility_buffer.size() < grid_width * grid_height:
		init_fog(grid.grid_width, grid.grid_height)
	
	# 1. Demote all currently visible cells to EXPLORED
	for cell in current_visible_cells:
		var idx = _cell_to_index(cell)
		if idx != -1:
			visibility_buffer[idx] = TileVisibility.EXPLORED
	current_visible_cells.clear()

	# 2. Origin cell is always VISIBLE
	set_visibility(origin, TileVisibility.VISIBLE)
	current_visible_cells.append(origin)

	# 3. Cast rays to the bounding perimeter of the sight circle
	var r = sight_radius
	var min_x = maxi(0, origin.x - r)
	var max_x = mini(grid_width - 1, origin.x + r)
	var min_y = maxi(0, origin.y - r)
	var max_y = mini(grid_height - 1, origin.y + r)

	# Collect perimeter cells to raycast to
	var targets: Array[Vector2i] = []
	for x in range(min_x, max_x + 1):
		targets.append(Vector2i(x, min_y))
		targets.append(Vector2i(x, max_y))
	for y in range(min_y + 1, max_y):
		targets.append(Vector2i(min_x, y))
		targets.append(Vector2i(max_x, y))

	for target in targets:
		_cast_ray(origin, target, r, grid)

	emit_signal("visibility_updated", current_visible_cells)

func _cast_ray(p0: Vector2i, p1: Vector2i, max_dist: int, grid: DungeonGrid) -> void:
	var dx = abs(p1.x - p0.x)
	var dy = -abs(p1.y - p0.y)
	var sx = 1 if p0.x < p1.x else -1
	var sy = 1 if p0.y < p1.y else -1
	var err = dx + dy
	var curr = p0

	while true:
		if curr != p0:
			var dist = abs(curr.x - p0.x) + abs(curr.y - p0.y)
			if dist > max_dist:
				break

			var idx = _cell_to_index(curr)
			if idx != -1:
				visibility_buffer[idx] = TileVisibility.VISIBLE
				if not current_visible_cells.has(curr):
					current_visible_cells.append(curr)

			# If this cell is a wall, vision stops here (the wall itself is revealed)
			if grid and grid.wall_cells.has(curr):
				break

		if curr == p1:
			break

		var e2 = 2 * err
		if e2 >= dy:
			err += dy
			curr.x += sx
		if e2 <= dx:
			err += dx
			curr.y += sy

## Reveals all cells (useful for debug or whole-floor clarity scrolls)
func reveal_all() -> void:
	for i in range(visibility_buffer.size()):
		visibility_buffer[i] = TileVisibility.VISIBLE
	current_visible_cells.clear()
	for y in range(grid_height):
		for x in range(grid_width):
			current_visible_cells.append(Vector2i(x, y))
	emit_signal("visibility_updated", current_visible_cells)
