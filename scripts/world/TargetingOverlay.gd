@tool
class_name TargetingOverlay
extends Node2D

## TargetingOverlay: World-space Node2D renderer for Manual Line-of-Fire targeting previews.
## Draws range perimeter, unobstructed raycast lines, wall/entity obstruction markers,
## occluded post-blocker segments, and Area-of-Effect (AoE) blast radius footprints.

@export var range_fill_color: Color = Color(0.2, 0.55, 0.9, 0.08)
@export var range_border_color: Color = Color(0.3, 0.7, 1.0, 0.28)
@export var clear_ray_fill_color: Color = Color(0.2, 0.9, 0.65, 0.24)
@export var clear_ray_line_color: Color = Color(0.3, 1.0, 0.75, 0.90)
@export var blocked_ray_fill_color: Color = Color(0.95, 0.2, 0.2, 0.18)
@export var blocked_ray_line_color: Color = Color(0.95, 0.25, 0.25, 0.55)
@export var intercept_color: Color = Color(1.0, 0.65, 0.1, 0.92)
@export var wall_block_color: Color = Color(1.0, 0.2, 0.2, 0.92)
@export var aoe_fill_color: Color = Color(1.0, 0.38, 0.12, 0.28)
@export var aoe_border_color: Color = Color(1.0, 0.55, 0.15, 0.85)
@export var cursor_valid_color: Color = Color(0.3, 1.0, 0.6, 0.95)
@export var cursor_invalid_color: Color = Color(1.0, 0.25, 0.25, 0.95)

var grid: DungeonGrid = null
var fow: FogOfWarSystem = null
var is_active: bool = false
var active_context: Dictionary = {}
var current_lof: Dictionary = {}
var cursor_cell: Vector2i = Vector2i(-1, -1)

func _ready() -> void:
	z_index = 15
	_connect_event_bus()

func setup(p_grid: DungeonGrid, p_fow: FogOfWarSystem = null) -> void:
	grid = p_grid
	fow = p_fow
	queue_redraw()

func _get_event_bus() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("EventBus")
	return null

func _connect_event_bus() -> void:
	var bus = _get_event_bus()
	if not bus:
		return
	if bus.has_signal("targeting_started"):
		bus.targeting_started.connect(_on_targeting_started)
	if bus.has_signal("targeting_cursor_updated"):
		bus.targeting_cursor_updated.connect(_on_targeting_cursor_updated)
	if bus.has_signal("targeting_confirmed"):
		bus.targeting_confirmed.connect(_on_targeting_ended)
	if bus.has_signal("targeting_canceled"):
		bus.targeting_canceled.connect(_on_targeting_canceled)

func _on_targeting_started(context: Dictionary) -> void:
	is_active = true
	active_context = context
	queue_redraw()

func _on_targeting_cursor_updated(p_cursor: Vector2i, lof_data: Dictionary) -> void:
	is_active = true
	cursor_cell = p_cursor
	current_lof = lof_data
	queue_redraw()

func _on_targeting_ended(_eff_cell: Vector2i, _lof_data: Dictionary) -> void:
	is_active = false
	current_lof.clear()
	queue_redraw()

func _on_targeting_canceled() -> void:
	is_active = false
	current_lof.clear()
	queue_redraw()

func _draw() -> void:
	if not is_active or not grid or current_lof.is_empty():
		return

	var ts = Vector2(grid.tile_size)
	var half_ts = ts * 0.5
	var origin: Vector2i = current_lof.get("origin_cell", Vector2i.ZERO)
	var eff_cell: Vector2i = current_lof.get("effective_target_cell", cursor_cell)
	var max_range: int = int(current_lof.get("max_range", 6))
	var blocker_type: int = int(current_lof.get("blocker_type", TargetingSystem.BlockerType.NONE))
	var blocker_cell: Vector2i = current_lof.get("blocker_cell", Vector2i(-1, -1))
	var is_valid: bool = bool(current_lof.get("is_valid", false))

	# 1. Draw Range Boundary Footprint
	for dy in range(-max_range, max_range + 1):
		for dx in range(-max_range, max_range + 1):
			var c = origin + Vector2i(dx, dy)
			if c.x < 0 or c.x >= grid.grid_width or c.y < 0 or c.y >= grid.grid_height:
				continue
			if grid.wall_cells.has(c):
				continue
			if fow and not fow.is_explored(c):
				continue
			var r_rect = Rect2(Vector2(c.x * ts.x, c.y * ts.y), ts)
			draw_rect(r_rect, range_fill_color)
			if abs(dx) == max_range or abs(dy) == max_range:
				draw_rect(r_rect, range_border_color, false, 1.0)

	# 2. Draw Clear Line-of-Fire Tiles
	var clear_cells: Array = current_lof.get("clear_cells", [])
	for c in clear_cells:
		var cell_v = c as Vector2i
		var c_rect = Rect2(Vector2(cell_v.x * ts.x + 3, cell_v.y * ts.y + 3), ts - Vector2(6, 6))
		draw_rect(c_rect, clear_ray_fill_color)

	# 3. Draw Blocked / Occluded Tail Tiles (beyond wall or intercepting entity)
	var blocked_cells: Array = current_lof.get("blocked_cells", [])
	for c in blocked_cells:
		var cell_v = c as Vector2i
		var b_rect = Rect2(Vector2(cell_v.x * ts.x + 5, cell_v.y * ts.y + 5), ts - Vector2(10, 10))
		draw_rect(b_rect, blocked_ray_fill_color)
		draw_rect(b_rect, blocked_ray_line_color, false, 1.0)

	# 4. Draw Area-of-Effect (AoE) Blast Radius Footprint
	var aoe_cells: Array = current_lof.get("aoe_cells", [])
	var area_radius: int = int(current_lof.get("area_radius", 0))
	if area_radius > 0 or bool(current_lof.get("is_beam", false)):
		for c in aoe_cells:
			var cell_v = c as Vector2i
			var a_rect = Rect2(Vector2(cell_v.x * ts.x + 1, cell_v.y * ts.y + 1), ts - Vector2(2, 2))
			draw_rect(a_rect, aoe_fill_color)
			draw_rect(a_rect, aoe_border_color, false, 1.5)

	# 5. Draw Center-to-Center Trajectory Beam Line
	var origin_world = Vector2(origin.x * ts.x, origin.y * ts.y) + half_ts
	var eff_world = Vector2(eff_cell.x * ts.x, eff_cell.y * ts.y) + half_ts
	var cursor_world = Vector2(cursor_cell.x * ts.x, cursor_cell.y * ts.y) + half_ts

	if eff_cell != origin:
		var ray_col = intercept_color if blocker_type == TargetingSystem.BlockerType.ENTITY else clear_ray_line_color
		draw_line(origin_world, eff_world, ray_col, 2.5)

	if eff_cell != cursor_cell:
		draw_line(eff_world, cursor_world, blocked_ray_line_color, 1.5)

	# 6. Draw Blocker / Interception Highlights
	if blocker_type == TargetingSystem.BlockerType.ENTITY and blocker_cell != Vector2i(-1, -1):
		var i_rect = Rect2(Vector2(blocker_cell.x * ts.x + 1, blocker_cell.y * ts.y + 1), ts - Vector2(2, 2))
		draw_rect(i_rect, Color(1.0, 0.65, 0.1, 0.25))
		draw_rect(i_rect, intercept_color, false, 2.5)
	elif blocker_type == TargetingSystem.BlockerType.WALL and blocker_cell != Vector2i(-1, -1):
		var w_pos = Vector2(blocker_cell.x * ts.x, blocker_cell.y * ts.y)
		var w_rect = Rect2(w_pos + Vector2(2, 2), ts - Vector2(4, 4))
		draw_rect(w_rect, wall_block_color, false, 2.0)
		draw_line(w_pos + Vector2(6, 6), w_pos + ts - Vector2(6, 6), wall_block_color, 2.5)
		draw_line(w_pos + Vector2(ts.x - 6, 6), w_pos + Vector2(6, ts.y - 6), wall_block_color, 2.5)

	# 7. Draw Cursor Reticle Brackets
	var reticle_col = cursor_valid_color if is_valid else cursor_invalid_color
	if blocker_type == TargetingSystem.BlockerType.ENTITY:
		reticle_col = intercept_color
	_draw_reticle_brackets(Rect2(Vector2(cursor_cell.x * ts.x, cursor_cell.y * ts.y), ts), reticle_col, 2.5)

func _draw_reticle_brackets(rect: Rect2, color: Color, width: float) -> void:
	var p = rect.position
	var s = rect.size
	var len_x = s.x * 0.28
	var len_y = s.y * 0.28

	# Top-Left
	draw_line(p, p + Vector2(len_x, 0), color, width)
	draw_line(p, p + Vector2(0, len_y), color, width)
	# Top-Right
	draw_line(p + Vector2(s.x, 0), p + Vector2(s.x - len_x, 0), color, width)
	draw_line(p + Vector2(s.x, 0), p + Vector2(s.x, len_y), color, width)
	# Bottom-Left
	draw_line(p + Vector2(0, s.y), p + Vector2(len_x, s.y), color, width)
	draw_line(p + Vector2(0, s.y), p + Vector2(0, s.y - len_y), color, width)
	# Bottom-Right
	draw_line(p + s, p + Vector2(s.x - len_x, s.y), color, width)
	draw_line(p + s, p + Vector2(s.x, s.y - len_y), color, width)
