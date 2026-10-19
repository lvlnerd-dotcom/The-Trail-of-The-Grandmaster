class_name WorldItem
extends Node2D

## WorldItem: Dropped item or floor loot entity on the dungeon grid.

@export var item_data: ItemData
@export var grid_pos: Vector2i = Vector2i.ZERO

var grid: DungeonGrid = null

func setup(p_grid: DungeonGrid, p_pos: Vector2i, p_item: ItemData) -> void:
	grid = p_grid
	grid_pos = p_pos
	item_data = p_item
	if grid:
		position = Vector2(grid.grid_to_world(grid_pos))
	queue_redraw()

func get_inspection_data(_viewer: Node2D = null) -> InspectionData:
	if item_data:
		var data = item_data.get_inspection_data()
		data.grid_cell = grid_pos
		return data
	var fallback = InspectionData.new()
	fallback.title = "Dropped Item"
	fallback.category = InspectionData.Category.ITEM_OR_OBJECT
	fallback.grid_cell = grid_pos
	fallback.category_text = "Floor Loot"
	fallback.description = "An item lying on the dungeon floor."
	return fallback

func _draw() -> void:
	if not grid:
		return
	var s = float(grid.tile_size.x)
	var half = s / 2.0
	var col = Color(0.9, 0.8, 0.4, 0.9)
	if item_data:
		match item_data.item_type:
			ItemData.ItemType.WEAPON:
				col = Color(1.0, 0.45, 0.4, 0.9)
			ItemData.ItemType.ARMOR, ItemData.ItemType.SHIELD:
				col = Color(0.4, 0.75, 1.0, 0.9)
			ItemData.ItemType.CONSUMABLE:
				col = Color(0.4, 1.0, 0.5, 0.9)
			ItemData.ItemType.RELIC:
				col = Color(1.0, 0.85, 0.2, 0.9)
	
	# Small glimmering item diamond/bag
	var pts = PackedVector2Array([
		Vector2(0, -half * 0.4),
		Vector2(half * 0.4, 0),
		Vector2(0, half * 0.4),
		Vector2(-half * 0.4, 0)
	])
	draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.3))
	draw_polyline(pts, col, 1.5)
	draw_line(pts[3], pts[0], col, 1.5)
	draw_circle(Vector2.ZERO, half * 0.12, col)
