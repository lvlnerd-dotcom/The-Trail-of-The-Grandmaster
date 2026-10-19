class_name Trap
extends Node2D

## Trap: Hidden hazard placed on floor tiles, revealed by Perception or triggered on enter.

enum TrapType {
    SPIKE,
    POISON_DART,
    ALARM
}

signal trap_revealed(trap: Trap)
signal trap_triggered(trap: Trap, victim: Node2D)

@export var trap_type: TrapType = TrapType.SPIKE
@export var grid_pos: Vector2i = Vector2i.ZERO
@export var hide_rating: float = 18.0
@export var is_revealed: bool = false
@export var is_triggered: bool = false

var grid: DungeonGrid = null

func _ready() -> void:
    set_meta("hide_rating", hide_rating)

func setup(p_grid: DungeonGrid, p_pos: Vector2i, p_type: TrapType = TrapType.SPIKE, p_hide: float = 18.0) -> void:
    grid = p_grid
    grid_pos = p_pos
    trap_type = p_type
    hide_rating = p_hide
    set_meta("hide_rating", hide_rating)
    position = Vector2(grid.grid_to_world(grid_pos))
    queue_redraw()

func reveal() -> void:
    if is_revealed:
        return
    is_revealed = true
    emit_signal("trap_revealed", self)
    queue_redraw()

func trigger(victim: Node2D) -> Dictionary:
    is_revealed = true
    is_triggered = true
    emit_signal("trap_triggered", self, victim)
    queue_redraw()
    
    var damage_dealt = 0
    var effect_name = ""
    var stats = victim.get_node_or_null("StatsComponent") as StatsComponent
    var inv = victim.get_node_or_null("InventoryComponent") as InventoryComponent
    
    match trap_type:
        TrapType.SPIKE:
            effect_name = "Spike Trap"
            var raw_damage = randi_range(12, 18)
            var armor_soak = inv.get_total_armor() if inv else 0
            damage_dealt = maxi(1, raw_damage - armor_soak)
            if stats:
                stats.take_damage(damage_dealt)
        TrapType.POISON_DART:
            effect_name = "Poison Dart"
            damage_dealt = randi_range(8, 12)
            if stats:
                stats.take_damage(damage_dealt)
                stats.current_mana = maxf(0.0, stats.current_mana - 15.0)
        TrapType.ALARM:
            effect_name = "Alarm Trap"
            damage_dealt = 0
            
    return {
        "trap_type": trap_type,
        "effect_name": effect_name,
        "damage": damage_dealt,
        "victim": victim
    }

func _draw() -> void:
    if not grid or not is_revealed:
        # Invisible when hidden
        return
        
    var s = float(grid.tile_size.x)
    var half = s / 2.0
    
    if is_triggered:
        # Sprung / Disarmed trap (greyed out)
        draw_circle(Vector2.ZERO, half * 0.4, Color(0.4, 0.4, 0.4, 0.6))
        draw_line(Vector2(-half * 0.4, -half * 0.4), Vector2(half * 0.4, half * 0.4), Color(0.6, 0.6, 0.6, 0.8), 2.0)
        draw_line(Vector2(half * 0.4, -half * 0.4), Vector2(-half * 0.4, half * 0.4), Color(0.6, 0.6, 0.6, 0.8), 2.0)
        return
        
    # Active revealed trap marker
    match trap_type:
        TrapType.SPIKE:
            # Red hazard triangle with spikes
            var col = Color(1.0, 0.2, 0.2, 0.85)
            var points = PackedVector2Array([
                Vector2(0, -half * 0.6),
                Vector2(half * 0.6, half * 0.5),
                Vector2(-half * 0.6, half * 0.5)
            ])
            draw_colored_polygon(points, Color(0.8, 0.1, 0.1, 0.4))
            draw_polyline(points, col, 2.0)
            draw_line(points[2], points[0], col, 2.0)
            # Spikes
            draw_line(Vector2(-half * 0.2, 0), Vector2(-half * 0.2, -half * 0.4), col, 1.5)
            draw_line(Vector2(0, half * 0.2), Vector2(0, -half * 0.5), col, 1.5)
            draw_line(Vector2(half * 0.2, 0), Vector2(half * 0.2, -half * 0.4), col, 1.5)
        TrapType.POISON_DART:
            # Green skull/cross hazard
            var g_col = Color(0.2, 0.9, 0.3, 0.85)
            draw_circle(Vector2.ZERO, half * 0.45, Color(0.1, 0.5, 0.2, 0.3))
            draw_circle(Vector2.ZERO, half * 0.35, g_col)
            draw_line(Vector2(-half * 0.5, 0), Vector2(half * 0.5, 0), g_col, 2.0)
            draw_line(Vector2(0, -half * 0.5), Vector2(0, half * 0.5), g_col, 2.0)
        TrapType.ALARM:
            # Yellow alarm bell icon
            var y_col = Color(1.0, 0.85, 0.2, 0.9)
            draw_circle(Vector2.ZERO, half * 0.4, Color(0.8, 0.7, 0.1, 0.3))
            draw_arc(Vector2.ZERO, half * 0.45, 0, 2 * PI, 12, y_col, 2.0)
            draw_circle(Vector2.ZERO, half * 0.15, y_col)

func get_inspection_data(_viewer: Node2D = null) -> InspectionData:
    var data = InspectionData.new()
    data.category = InspectionData.Category.HAZARD
    data.grid_cell = grid_pos
    data.icon_glyph = "!"
    data.accent_color = Color(1.0, 0.6, 0.2)
    
    var state_tag = "Triggered / Spent" if is_triggered else "Armed Hazard"
    data.category_text = "Trap • %s" % state_tag
    
    match trap_type:
        TrapType.SPIKE:
            data.title = "Spike Trap"
            data.description = "Concealed floor spikes (12-18 physical damage, mitigated by armor)."
        TrapType.POISON_DART:
            data.title = "Poison Dart Trap"
            data.description = "Pressurized venom dart (8-12 damage + 15 MP drain)."
        TrapType.ALARM:
            data.title = "Alarm Trap"
            data.description = "Acoustic tripwire that alerts all nearby hostiles when stepped on."
            
    return data
