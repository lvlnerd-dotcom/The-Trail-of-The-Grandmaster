class_name GridVisualizer
extends Node2D

## GridVisualizer: Renders floor tiles, walls, grid lines, and hover highlights with Fog of War shading.

@export var floor_color: Color = Color(0.12, 0.14, 0.18, 1.0)
@export var floor_alt_color: Color = Color(0.14, 0.16, 0.20, 1.0)
@export var wall_color: Color = Color(0.28, 0.30, 0.36, 1.0)
@export var grid_line_color: Color = Color(0.08, 0.09, 0.12, 0.6)
@export var hover_color: Color = Color(0.2, 0.8, 0.6, 0.3)
@export var path_color: Color = Color(0.3, 0.7, 1.0, 0.4)

# Memory / Explored tints
@export var explored_floor_color: Color = Color(0.06, 0.07, 0.09, 1.0)
@export var explored_wall_color: Color = Color(0.14, 0.15, 0.18, 1.0)

var grid: DungeonGrid = null
var fow: FogOfWarSystem = null
var hovered_cell: Vector2i = Vector2i(-1, -1)
var active_path: Array[Vector2i] = []

func setup(p_grid: DungeonGrid, p_fow: FogOfWarSystem = null) -> void:
	grid = p_grid
	fow = p_fow
	queue_redraw()

func _process(_delta: float) -> void:
	if not grid:
		return
	var mouse_cell = grid.world_to_grid(get_global_mouse_position())
	if mouse_cell != hovered_cell:
		hovered_cell = mouse_cell
		queue_redraw()

func _draw() -> void:
	if not grid:
		return
	
	var ts = Vector2(grid.tile_size)
	
	# Draw floor and walls
	for y in range(grid.grid_height):
		for x in range(grid.grid_width):
			var cell = Vector2i(x, y)
			var vis = fow.get_visibility(cell) if fow else FogOfWarSystem.TileVisibility.VISIBLE
			
			if vis == FogOfWarSystem.TileVisibility.HIDDEN:
				continue # Hidden in darkness
				
			var rect = Rect2(Vector2(x * ts.x, y * ts.y), ts)
			
			if grid.wall_cells.has(cell):
				if vis == FogOfWarSystem.TileVisibility.VISIBLE:
					draw_rect(rect, wall_color)
					# Bevel outline
					draw_rect(rect, Color(0.38, 0.40, 0.48), false, 1.5)
				else: # EXPLORED memory
					draw_rect(rect, explored_wall_color)
					draw_rect(rect, Color(0.20, 0.22, 0.26), false, 1.0)
			elif grid.walkable_cells.has(cell):
				if vis == FogOfWarSystem.TileVisibility.VISIBLE:
					var bg = floor_color if (x + y) % 2 == 0 else floor_alt_color
					draw_rect(rect, bg)
					draw_rect(rect, grid_line_color, false, 0.5)
				else: # EXPLORED memory
					draw_rect(rect, explored_floor_color)
	
	# Draw active path (only for visible or explored cells)
	for cell in active_path:
		if not fow or fow.is_explored(cell):
			var path_rect = Rect2(Vector2(cell.x * ts.x + 4, cell.y * ts.y + 4), ts - Vector2(8, 8))
			draw_rect(path_rect, path_color)
	
	# Draw hover highlight (only in visible or explored cells)
	if grid.is_walkable(hovered_cell) and (not fow or fow.is_explored(hovered_cell)):
		var h_rect = Rect2(Vector2(hovered_cell.x * ts.x, hovered_cell.y * ts.y), ts)
		draw_rect(h_rect, hover_color)
		draw_rect(h_rect, Color(0.3, 1.0, 0.7, 0.8), false, 1.5)
