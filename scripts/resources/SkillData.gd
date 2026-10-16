class_name SkillData
extends Resource

## SkillData: Data resource for individual use-based skills (0.0 to 100.0).

signal skill_level_changed(skill_id: SkillId, new_level: float)
signal keystone_reached(skill_id: SkillId, milestone: int)

enum SkillId {
    # Melee (STR)
    SWORDSMANSHIP,
    MACE_FIGHTING,
    POLEARMS,
    BRAWLING,
    
    # Ranged & Agility (DEX)
    MARKSMANSHIP,
    ARCHERY,
    THROWING,
    DODGE,
    PARRY,
    STEALTH_HIDE,
    
    # Intellectual & Arcane (INT)
    ARCANE_MAGIC,
    ALCHEMY,
    SCHOLARSHIP,
    
    # Spiritual & Perception (WIS)
    DIVINE_MAGIC,
    PERCEPTION,
    MEDITATION,
    
    # Social & Leadership (CHA)
    INTIMIDATION,
    LEADERSHIP,
    BEAST_MASTERY
}

@export var skill_id: SkillId
@export var skill_name: String
@export var associated_attribute_name: String = "strength" # "strength", "dexterity", etc.
@export_range(0.0, 100.0) var level: float = 0.0:
    set(value):
        level = clampf(value, 0.0, 100.0)
        emit_signal("skill_level_changed", skill_id, level)
        _check_keystones()

@export var current_xp: float = 0.0

# Internal constants
const XP_PER_TENTH_LEVEL: float = 20.0
const KEYSTONE_MILESTONES: Array[int] = [25, 50, 75, 100]

var unlocked_keystones: Array[int] = []

func _init(p_id: SkillId = SkillId.SWORDSMANSHIP, p_name: String = "", p_attr: String = "strength", p_lvl: float = 0.0) -> void:
    skill_id = p_id
    skill_name = p_name if not p_name.is_empty() else SkillId.keys()[p_id].capitalize()
    associated_attribute_name = p_attr
    level = p_lvl

func get_effective_level(attribute_val: int) -> float:
    # 2 points in attribute contributes +1 extra effective skill level (at 10 attr = +5)
    var attr_bonus = float(attribute_val) / 2.0
    return level + attr_bonus

func add_usage_attempt(task_difficulty: float, attribute_val: int, int_xp_multiplier: float = 1.0) -> bool:
    if level >= 100.0:
        return false # Already Grandmaster
    
    var effective_lvl = get_effective_level(attribute_val)
    var delta = task_difficulty - effective_lvl
    
    # Difficulty sweet-spot weighting
    # Tasks close to skill level grant the best learning; trivial or impossible grant minimal
    var difficulty_weight: float
    var abs_delta = absf(delta)
    if abs_delta <= 15.0:
        difficulty_weight = 1.0 # Sweet spot
    elif abs_delta <= 30.0:
        difficulty_weight = 0.5
    else:
        difficulty_weight = 0.1 # Trivial or near-impossible
        
    var base_xp_gain = 10.0
    var awarded_xp = base_xp_gain * difficulty_weight * int_xp_multiplier
    current_xp += awarded_xp
    
    var leveled_up: bool = false
    while current_xp >= XP_PER_TENTH_LEVEL and level < 100.0:
        current_xp -= XP_PER_TENTH_LEVEL
        # Increment by 0.1 at a time (snapped to 1 decimal place to prevent float drift)
        level = snappedf(level + 0.1, 0.1)
        leveled_up = true
        
    return leveled_up

func _check_keystones() -> void:
    for milestone in KEYSTONE_MILESTONES:
        if level >= float(milestone) and not unlocked_keystones.has(milestone):
            unlocked_keystones.append(milestone)
            emit_signal("keystone_reached", skill_id, milestone)
