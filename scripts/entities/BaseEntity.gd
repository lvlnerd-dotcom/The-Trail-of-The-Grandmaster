class_name BaseEntity
extends CharacterBody2D

## BaseEntity: Root class for all grid-based entities (Player, Enemies, Companions).

signal move_started(from_cell: Vector2i, to_cell: Vector2i)
signal move_finished(at_cell: Vector2i)
signal action_finished()

@export var move_duration: float = 0.12 # Snappy roguelike interpolation
@export var bump_duration: float = 0.08

var grid: DungeonGrid = null
var turn_manager: TurnManager = null
var grid_pos: Vector2i = Vector2i.ZERO
var facing_direction: Vector2i = Vector2i(0, 1)

var is_moving: bool = false
var move_tween: Tween = null

@onready var visual_sprite: CanvasItem = get_node_or_null("VisualSprite")

func _get_event_bus() -> Node:
    var loop = Engine.get_main_loop()
    if loop and loop is SceneTree:
        return (loop as SceneTree).root.get_node_or_null("EventBus")
    return null

func _ready() -> void:
    # Disable default Godot physics processing since movement is turn-based on a grid
    set_physics_process(false)

func init_grid_position(p_grid: DungeonGrid, p_pos: Vector2i, p_turn_manager: TurnManager = null) -> void:
    grid = p_grid
    turn_manager = p_turn_manager
    grid_pos = p_pos
    if grid:
        grid.register_entity(self, grid_pos)
        global_position = grid.grid_to_world(grid_pos)

func set_facing_direction(direction: Vector2i) -> void:
    if direction != Vector2i.ZERO:
        facing_direction = direction

func try_move(direction: Vector2i) -> bool:
    if is_moving or not grid:
        return false
    
    set_facing_direction(direction)
    var target_cell = grid_pos + direction
    
    if grid.can_enter(target_cell):
        _execute_move(target_cell)
        return true
    else:
        # Check if cell is an obstacle or wall
        _play_bump_animation(direction)
        var bus = _get_event_bus()
        if bus:
            bus.emit_signal("entity_bumped", self, target_cell)
        return false

func _execute_move(target_cell: Vector2i) -> void:
    is_moving = true
    var from_cell = grid_pos
    grid.move_entity(self, from_cell, target_cell)
    grid_pos = target_cell
    
    emit_signal("move_started", from_cell, target_cell)
    var bus = _get_event_bus()
    if bus:
        bus.emit_signal("entity_moved", self, from_cell, target_cell)
    
    var target_world_pos = grid.grid_to_world(target_cell)
    
    if move_tween and move_tween.is_valid():
        move_tween.kill()
    
    move_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    move_tween.tween_property(self, "global_position", target_world_pos, move_duration)
    move_tween.finished.connect(_on_move_tween_finished)

func _on_move_tween_finished() -> void:
    is_moving = false
    emit_signal("move_finished", grid_pos)
    emit_signal("action_finished")

func _play_bump_animation(direction: Vector2i) -> void:
    is_moving = true
    var start_pos = global_position
    var bump_offset = Vector2(direction.x, direction.y) * 8.0 # 8px bump
    
    if move_tween and move_tween.is_valid():
        move_tween.kill()
    
    move_tween = create_tween()
    move_tween.tween_property(self, "global_position", start_pos + bump_offset, bump_duration * 0.5)
    move_tween.tween_property(self, "global_position", start_pos, bump_duration * 0.5)
    move_tween.finished.connect(func():
        is_moving = false
        emit_signal("action_finished")
    )

## Returns a dictionary with "label": String and "color": Color along the qualitative health spectrum:
## Emerald Green (Full) -> Chartreuse -> Amber -> Orange-Red -> Crimson Red (Critical) -> Grey (Defeated)
static func get_health_status_info(current_hp: float, max_hp: float) -> Dictionary:
    if max_hp <= 0.0:
        return {"label": "Unknown", "color": Color(0.7, 0.7, 0.7)}
    var r = clampf(current_hp / max_hp, 0.0, 1.0)
    if r >= 0.95:
        return {"label": "Uninjured", "color": Color(0.20, 0.90, 0.40)} # Emerald Green (#33e666)
    elif r >= 0.70:
        return {"label": "Barely Scratched", "color": Color(0.65, 0.92, 0.30)} # Chartreuse (#a6eb4d)
    elif r >= 0.40:
        return {"label": "Wounded", "color": Color(1.00, 0.80, 0.20)} # Amber Gold (#ffcc33)
    elif r >= 0.15:
        return {"label": "Badly Wounded", "color": Color(0.95, 0.42, 0.18)} # Deep Orange-Red (#f26b2e)
    elif r > 0.0:
        return {"label": "Near Death", "color": Color(0.86, 0.08, 0.24)} # Crimson Red (#dc143c)
    else:
        return {"label": "Defeated", "color": Color(0.50, 0.50, 0.55)} # Ashen Grey (#80808c)

func get_inspection_data(_viewer: Node2D = null) -> InspectionData:
    var data = InspectionData.new()
    data.title = name
    data.category = InspectionData.Category.UNKNOWN
    data.category_text = "Entity"
    data.grid_cell = grid_pos
    return data
