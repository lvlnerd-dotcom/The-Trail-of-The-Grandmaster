class_name VisionComponent
extends Node

## VisionComponent: Handles Line-of-Sight, Perception vs Stealth checks, and Secret/Trap detection.

signal target_detected(target: Node2D)
signal target_lost(target: Node2D)

@export var view_distance_tiles: int = 8
@export var peripheral_view_distance_tiles: int = 2
@onready var parent_entity: Node2D = get_parent() as Node2D

var visible_tiles: Array[Vector2i] = []

## Returns +1 vision cone tile for every 10 levels in the Perception skill.
func get_perception_vision_bonus(observer: Node2D = null) -> int:
    var ent = observer if observer else parent_entity
    if not ent and get_parent() is Node2D:
        ent = get_parent() as Node2D
    if not ent:
        return 0
    var obs_skills = ent.get_node_or_null("SkillComponent") as SkillComponent
    if not obs_skills:
        for c in ent.get_children():
            if c is SkillComponent:
                obs_skills = c
                break
    if obs_skills:
        var perc_skill = obs_skills.get_skill(SkillData.SkillId.PERCEPTION)
        if perc_skill:
            return maxi(0, int(floor(perc_skill.level / 10.0)))
    return 0

## Calculates effective maximum distance of the forward vision reveal cone:
## Base view_distance_tiles + (1 tile per 10 levels in Perception skill).
func get_effective_view_distance(observer: Node2D = null) -> int:
    var obs = observer if observer else get_parent() as Node2D
    if obs and obs.has_node("StatusEffectComponent"):
        var sec = obs.get_node("StatusEffectComponent") as StatusEffectComponent
        if sec and sec.is_blinded():
            return 1
    return view_distance_tiles + get_perception_vision_bonus(observer)

## Evaluates detection chance strictly per design document:
## P(Detection) = (Observer Perception + 50) / ((Target Hide + 50) * 2) + ObsBonuses - TargetBonuses
static func calculate_detection_chance(observer: Node2D, target: Node2D, obs_bonus: float = 0.0, target_bonus: float = 0.0) -> float:
    var obs_skills = observer.get_node_or_null("SkillComponent") as SkillComponent
    if not obs_skills:
        for c in observer.get_children():
            if c is SkillComponent:
                obs_skills = c
                break
    var obs_stats = observer.get_node_or_null("StatsComponent") as StatsComponent
    if not obs_stats:
        for c in observer.get_children():
            if c is StatsComponent:
                obs_stats = c
                break
    var target_skills = target.get_node_or_null("SkillComponent") as SkillComponent
    if not target_skills:
        for c in target.get_children():
            if c is SkillComponent:
                target_skills = c
                break
    var target_stats = target.get_node_or_null("StatsComponent") as StatsComponent
    if not target_stats:
        for c in target.get_children():
            if c is StatsComponent:
                target_stats = c
                break
    
    var obs_perception = 10.0
    if obs_skills and obs_stats:
        obs_perception = obs_skills.get_effective_level(SkillData.SkillId.PERCEPTION, obs_stats.attributes)
        
    var target_hide = 10.0
    if target_skills and target_stats:
        target_hide = target_skills.get_effective_level(SkillData.SkillId.STEALTH_HIDE, target_stats.attributes)
    elif target.has_meta("hide_rating"):
        target_hide = float(target.get_meta("hide_rating"))
        
    var numerator = obs_perception + 50.0
    var denominator = (target_hide + 50.0) * 2.0
    var raw_chance = (numerator / denominator) + obs_bonus - target_bonus
    return clampf(raw_chance, 0.05, 0.95)

func can_see_entity(grid: DungeonGrid, from_cell: Vector2i, target: Node2D) -> bool:
    if not target or not grid:
        return false
        
    var to_cell = target.get("grid_pos") as Vector2i
    var dist = abs(from_cell.x - to_cell.x) + abs(from_cell.y - to_cell.y)
    if dist > get_effective_view_distance():
        return false
        
    # Check Line of Sight on grid using Bresenham algorithm
    if not has_line_of_sight(grid, from_cell, to_cell):
        return false
        
    # If target is hiding, roll detection check
    var is_target_hidden = target.get("is_hidden") if "is_hidden" in target else false
    if is_target_hidden:
        var chance = calculate_detection_chance(parent_entity, target)
        var roll = randf()
        return roll <= chance
        
    return true

static func has_line_of_sight(grid: DungeonGrid, from_cell: Vector2i, to_cell: Vector2i) -> bool:
    var points = get_line_cells(from_cell, to_cell)
    # Check intermediate points (exclude start and end)
    for i in range(1, points.size() - 1):
        var pt = points[i]
        if grid.wall_cells.has(pt):
            return false
    return true

static func get_line_cells(p0: Vector2i, p1: Vector2i) -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    var dx = abs(p1.x - p0.x)
    var dy = -abs(p1.y - p0.y)
    var sx = 1 if p0.x < p1.x else -1
    var sy = 1 if p0.y < p1.y else -1
    var err = dx + dy
    var curr = p0
    
    while true:
        cells.append(curr)
        if curr == p1:
            break
        var e2 = 2 * err
        if e2 >= dy:
            err += dy
            curr.x += sx
        if e2 <= dx:
            err += dx
            curr.y += sy
    return cells
