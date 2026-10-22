class_name WorldItem
extends Node2D

## WorldItem: Dropped item or floor loot entity on the dungeon grid,
## supporting single items or stacked multi-item piles.

@export var item_data: ItemData
@export var grid_pos: Vector2i = Vector2i.ZERO
var items: Array[ItemData] = []
var grid: DungeonGrid = null

func setup(p_grid: DungeonGrid, p_pos: Vector2i, p_item_or_items: Variant) -> void:
	grid = p_grid
	grid_pos = p_pos
	items.clear()
	if p_item_or_items is Array:
		for it in p_item_or_items:
			if it is ItemData:
				items.append(it)
	elif p_item_or_items is ItemData:
		items.append(p_item_or_items)
	
	item_data = get_top_item()
	if grid:
		position = Vector2(grid.grid_to_world(grid_pos))
	queue_redraw()

func get_top_item() -> ItemData:
	if not items.is_empty():
		return items[0]
	return item_data

func add_item(item: ItemData) -> void:
	if item:
		items.append(item)
		item_data = get_top_item()
		queue_redraw()

func remove_item(item: ItemData) -> bool:
	var idx = items.find(item)
	if idx != -1:
		items.remove_at(idx)
		item_data = get_top_item()
		queue_redraw()
		return true
	return false

func get_inspection_data(_viewer: Node2D = null) -> InspectionData:
	if items.size() > 1:
		var pile_data = InspectionData.new()
		pile_data.title = "Loot Pile (%d items)" % items.size()
		pile_data.category = InspectionData.Category.ITEM_OR_OBJECT
		pile_data.grid_cell = grid_pos
		pile_data.category_text = "Floor Loot Pile"
		var names: Array[String] = []
		for it in items:
			names.append(it.item_name)
		pile_data.description = "A pile of %d items: %s. Press [G] to inspect/take." % [items.size(), ", ".join(names)]
		return pile_data
	elif item_data:
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
	
	if items.size() > 1:
		# Draw stacked diamond silhouettes to represent a multi-item pile
		var offset1 = Vector2(-3, -3)
		var pts_bg = PackedVector2Array([
			offset1 + Vector2(0, -half * 0.35),
			offset1 + Vector2(half * 0.35, 0),
			offset1 + Vector2(0, half * 0.35),
			offset1 + Vector2(-half * 0.35, 0)
		])
		draw_colored_polygon(pts_bg, Color(0.3, 0.3, 0.3, 0.5))
		draw_polyline(pts_bg, Color(0.6, 0.6, 0.6, 0.8), 1.0)
		draw_line(pts_bg[3], pts_bg[0], Color(0.6, 0.6, 0.6, 0.8), 1.0)

	# Main diamond
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
