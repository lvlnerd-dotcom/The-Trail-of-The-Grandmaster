@tool
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

const DEFAULT_CONE_ANGLE_DEG: float = 45.0
const DEFAULT_PERIPHERAL_RADIUS: int = 2

@export var cone_angle_degrees: float = DEFAULT_CONE_ANGLE_DEG
@export var peripheral_radius: int = DEFAULT_PERIPHERAL_RADIUS

## Checks whether a target cell falls within the forward directional vision cone (default 45-degree arc).
func is_in_vision_cone(origin: Vector2i, target: Vector2i, facing_direction: Vector2i, cone_angle_deg: float = DEFAULT_CONE_ANGLE_DEG) -> bool:
	if target == origin or facing_direction == Vector2i.ZERO:
		return true
	var f_vec = Vector2(facing_direction).normalized()
	var t_vec = Vector2(target - origin).normalized()
	var half_angle_rad = deg_to_rad(cone_angle_deg * 0.5)
	var angle_diff = absf(f_vec.angle_to(t_vec))
	return angle_diff <= (half_angle_rad + 0.001)

## Updates the field-of-view from origin.
## If facing_direction is non-zero, applies full sight_radius within the 45-degree forward vision cone
## and reduced p_peripheral_radius behind and to the sides.
## Demotes previously visible cells to EXPLORED (permanent memory), and illuminates visible cells.
func update_visibility(
	origin: Vector2i,
	sight_radius: int,
	grid: DungeonGrid,
	facing_direction: Vector2i = Vector2i.ZERO,
	p_peripheral_radius: int = DEFAULT_PERIPHERAL_RADIUS
) -> void:
	if visibility_buffer.size() < grid_width * grid_height:
		init_fog(grid.grid_width if grid else grid_width, grid.grid_height if grid else grid_height)
	
	# 1. Demote all currently visible cells to EXPLORED (permanent memory state)
	for cell in current_visible_cells:
		var idx = _cell_to_index(cell)
		if idx != -1:
			visibility_buffer[idx] = TileVisibility.EXPLORED
	current_visible_cells.clear()

	# 2. Origin cell is always VISIBLE
	set_visibility(origin, TileVisibility.VISIBLE)
	current_visible_cells.append(origin)

	# 3. Evaluate cells within the bounding box of sight_radius (+1 buffer for wall reveals)
	var r = maxi(sight_radius, p_peripheral_radius) + 1
	var min_x = maxi(0, origin.x - r)
	var max_x = mini(grid_width - 1, origin.x + r)
	var min_y = maxi(0, origin.y - r)
	var max_y = mini(grid_height - 1, origin.y + r)

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var target = Vector2i(x, y)
			if target == origin:
				continue
			
			var dist = Vector2(target - origin).length()
			var in_cone = is_in_vision_cone(origin, target, facing_direction, cone_angle_degrees)
			var is_wall = grid != null and grid.wall_cells.has(target)
			
			# Wall Reveal Buffer: Walls flanking or along the edge receive a +1 tile distance buffer
			var base_sight = float(sight_radius) + (1.0 if is_wall else 0.0)
			var base_periph = float(p_peripheral_radius) + (1.0 if is_wall else 0.0)
			var allowed_dist = base_sight + 0.001 if in_cone else base_periph + 0.25
			
			if dist > allowed_dist:
				continue
				
			if _has_clear_line_of_sight(origin, target, grid):
				var idx = _cell_to_index(target)
				if idx != -1:
					visibility_buffer[idx] = TileVisibility.VISIBLE
					current_visible_cells.append(target)

	# 4. Structural Wall Buffer: Any wall tile directly adjacent (8-directional) to an
	# actively visible floor tile within sight range is illuminated so hallways are properly flanked
	if grid != null:
		var visible_floor_cells: Array[Vector2i] = []
		for cell in current_visible_cells:
			if not grid.wall_cells.has(cell):
				visible_floor_cells.append(cell)
				
		var max_wall_dist = float(sight_radius + 1) + 0.5
		for f_cell in visible_floor_cells:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var adj_cell = f_cell + Vector2i(dx, dy)
					if grid.wall_cells.has(adj_cell):
						var d_from_origin = Vector2(adj_cell - origin).length()
						if d_from_origin <= max_wall_dist:
							var w_idx = _cell_to_index(adj_cell)
							if w_idx != -1 and visibility_buffer[w_idx] != TileVisibility.VISIBLE:
								visibility_buffer[w_idx] = TileVisibility.VISIBLE
								current_visible_cells.append(adj_cell)

	emit_signal("visibility_updated", current_visible_cells)

func _has_clear_line_of_sight(p0: Vector2i, p1: Vector2i, grid: DungeonGrid) -> bool:
	if not grid:
		return true
	var dx = abs(p1.x - p0.x)
	var dy = -abs(p1.y - p0.y)
	var sx = 1 if p0.x < p1.x else -1
	var sy = 1 if p0.y < p1.y else -1
	var err = dx + dy
	var curr = p0

	while true:
		if curr == p1:
			return true
		if curr != p0 and grid.wall_cells.has(curr):
			return false

		var e2 = 2 * err
		if e2 >= dy:
			err += dy
			curr.x += sx
		if e2 <= dx:
			err += dx
			curr.y += sy
	return true

## Reveals all cells (useful for debug or whole-floor clarity scrolls)
func reveal_all() -> void:
	for i in range(visibility_buffer.size()):
		visibility_buffer[i] = TileVisibility.VISIBLE
	current_visible_cells.clear()
	for y in range(grid_height):
		for x in range(grid_width):
			current_visible_cells.append(Vector2i(x, y))
	emit_signal("visibility_updated", current_visible_cells)
