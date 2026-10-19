@tool
class_name StairsDown
extends Node2D

## StairsDown: Level exit portal leading deeper into the Trail of the Grandmaster.

signal descent_requested(next_floor: int)

@export var grid_pos: Vector2i = Vector2i.ZERO
@export var current_floor: int = 1

var grid: DungeonGrid = null

func setup(p_grid: DungeonGrid, p_pos: Vector2i, p_floor: int = 1) -> void:
    grid = p_grid
    grid_pos = p_pos
    current_floor = p_floor
    position = Vector2(grid.grid_to_world(grid_pos))
    visible = false
    queue_redraw()

## Updates stairs visibility strictly from active line-of-sight (TileVisibility.VISIBLE).
## Stairs remain hidden in both HIDDEN and EXPLORED (memory) states until actively looked at.
func update_visibility_from_fog(fow: FogOfWarSystem) -> void:
    if not fow:
        visible = false
        return
    visible = fow.is_visible(grid_pos)
    queue_redraw()

func can_descend(entity: Node2D) -> bool:
    var e_pos = entity.get("grid_pos") if "grid_pos" in entity else Vector2i(-1, -1)
    return e_pos == grid_pos

func trigger_descent() -> void:
    emit_signal("descent_requested", current_floor + 1)

func _draw() -> void:
    if not grid:
        return
    var s = float(grid.tile_size.x)
    var half = s / 2.0
    var rect = Rect2(-half, -half, s, s)
    
    # Outer stone frame
    draw_rect(rect, Color(0.15, 0.12, 0.08, 1.0))
    draw_rect(rect, Color(0.85, 0.70, 0.20, 0.9), false, 2.0)
    
    # Tiered descending stairs steps
    var step_color = Color(0.95, 0.80, 0.25, 0.9)
    for i in range(4):
        var inset = float(i) * (half * 0.22)
        var step_rect = Rect2(-half + inset, -half + inset, s - (inset * 2.0), s - (inset * 2.0))
        var shade = 1.0 - (float(i) * 0.2)
        draw_rect(step_rect, Color(0.6 * shade, 0.5 * shade, 0.15 * shade, 0.8))
        draw_rect(step_rect, step_color, false, 1.0)
        
    # Center dark pit
    draw_rect(Rect2(-half * 0.25, -half * 0.25, half * 0.5, half * 0.5), Color(0.02, 0.02, 0.04, 1.0))

func get_inspection_data(_viewer: Node2D = null) -> InspectionData:
    var data = InspectionData.new()
    data.category = InspectionData.Category.ITEM_OR_OBJECT
    data.grid_cell = grid_pos
    data.icon_glyph = ">"
    data.accent_color = Color(0.95, 0.80, 0.25)
    data.title = "Stairs Down"
    data.category_text = "Dungeon Exit"
    data.description = "Passageway leading down to Floor %d. Step here to descend." % (current_floor + 1)
    return data
