class_name SecretDoor
extends Node2D

## SecretDoor: Wall-concealed door discovered via player Perception checks.

signal revealed(door: SecretDoor)

@export var grid_pos: Vector2i = Vector2i.ZERO
@export var hide_rating: float = 20.0
@export var is_revealed: bool = false
@export var is_open: bool = false

var grid: DungeonGrid = null

func _ready() -> void:
    set_meta("hide_rating", hide_rating)

func setup(p_grid: DungeonGrid, p_pos: Vector2i, p_hide: float = 20.0) -> void:
    grid = p_grid
    grid_pos = p_pos
    hide_rating = p_hide
    set_meta("hide_rating", hide_rating)
    position = Vector2(grid.grid_to_world(grid_pos))
    
    # Hidden door acts as solid wall initially
    if not is_revealed:
        grid.set_cell_walkable(grid_pos, false)
    queue_redraw()

func reveal() -> void:
    if is_revealed:
        return
    is_revealed = true
    is_open = true
    # Once revealed, the door is unlocked/walkable
    if grid:
        grid.set_cell_walkable(grid_pos, true)
        grid.rebuild_astar()
        
    emit_signal("revealed", self)
    queue_redraw()

func _draw() -> void:
    if not grid:
        return
    var s = float(grid.tile_size.x)
    var half = s / 2.0
    var rect = Rect2(-half, -half, s, s)
    
    if not is_revealed:
        # Concealed as wall
        draw_rect(rect, Color(0.28, 0.30, 0.36, 1.0))
        draw_rect(rect, Color(0.38, 0.40, 0.48, 1.0), false, 1.5)
    else:
        # Revealed stone doorframe with secret blue rune
        draw_rect(rect, Color(0.18, 0.22, 0.30, 1.0))
        draw_rect(rect, Color(0.3, 0.7, 1.0, 0.9), false, 2.0)
        # Glowing arch icon
        draw_arc(Vector2.ZERO, half * 0.6, PI, 2 * PI, 8, Color(0.4, 0.8, 1.0, 0.9), 2.0)
        draw_line(Vector2(-half * 0.6, 0), Vector2(-half * 0.6, half * 0.6), Color(0.4, 0.8, 1.0, 0.9), 2.0)
        draw_line(Vector2(half * 0.6, 0), Vector2(half * 0.6, half * 0.6), Color(0.4, 0.8, 1.0, 0.9), 2.0)
