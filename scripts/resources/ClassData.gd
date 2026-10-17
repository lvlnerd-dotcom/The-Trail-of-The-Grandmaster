class_name ClassData
extends Resource

## ClassData: Resource defining post-Floor 2 specialized classes, prerequisites, and passive perks.

enum Archetype {
    MARTIAL,
    ROGUE_RANGED,
    ARCANE,
    DIVINE,
    HYBRID,
    GENERAL
}

@export_group("Identity")
@export var class_id: String = ""
@export var class_title: String = ""
@export var archetype: Archetype = Archetype.GENERAL
@export_multiline var description: String = ""
@export var icon_path: String = ""

@export_group("Prerequisites")
## e.g. {"strength": 14, "constitution": 12}
@export var required_attributes: Dictionary = {}
## e.g. {SkillData.SkillId.SWORDSMANSHIP: 15.0}
@export var required_skills: Dictionary = {}
## Secondary requirements count (e.g. at least 2 weapon skills >= 12.0)
@export var min_weapon_skills_count: int = 0
@export var min_weapon_skills_level: float = 0.0

@export_group("Bonuses & Perks")
## Attribute bonuses applied on specialization: {"strength": 2, ...}
@export var attribute_bonuses: Dictionary = {}
@export var passive_title: String = ""
@export_multiline var passive_description: String = ""
@export var passive_type: String = "" # e.g. "damage_mult", "crit_mult", "armor_soak", "mana_drain"
@export var passive_values: Dictionary = {}

@export_group("Active Signature Ability")
@export var signature_ability_name: String = ""
@export_multiline var signature_ability_description: String = ""
@export var signature_ability_mana_cost: int = 0

@export_group("Class Exclusive Skill")
@export var exclusive_skill_id: SkillData.SkillId = SkillData.SkillId.IMPROVISED_SURVIVAL

func _init(
    p_id: String = "",
    p_name: String = "",
    p_archetype: Archetype = Archetype.GENERAL,
    p_desc: String = ""
) -> void:
    class_id = p_id
    class_title = p_name
    archetype = p_archetype
    description = p_desc

## Evaluates whether the player satisfies prerequisites for this class.
func is_eligible(attrs: AttributesData, skills: SkillComponent) -> bool:
    if archetype == Archetype.GENERAL or class_id == "vagabond":
        return true # Universal fallback class is always eligible
        
    if not attrs or not skills:
        return false
        
    # 1. Hard Prerequisite Checks
    var hard_passed = true
    for attr_name in required_attributes.keys():
        var req_val = int(required_attributes[attr_name])
        var cur_val = _get_attr_value(attrs, attr_name)
        if cur_val < req_val:
            hard_passed = false
            break
            
    if hard_passed:
        for s_id in required_skills.keys():
            var req_lvl = float(required_skills[s_id])
            var skill_data = skills.get_skill(s_id)
            var cur_lvl = skill_data.level if skill_data else 0.0
            if cur_lvl < req_lvl:
                hard_passed = false
                break
                
    if hard_passed and min_weapon_skills_count > 0:
        var weapon_skills = [
            SkillData.SkillId.SWORDSMANSHIP,
            SkillData.SkillId.MACE_FIGHTING,
            SkillData.SkillId.POLEARMS,
            SkillData.SkillId.BRAWLING,
            SkillData.SkillId.ARCHERY,
            SkillData.SkillId.MARKSMANSHIP,
            SkillData.SkillId.THROWING
        ]
        var qualified_count = 0
        for ws in weapon_skills:
            var s = skills.get_skill(ws)
            if s and s.level >= min_weapon_skills_level:
                qualified_count += 1
        if qualified_count < min_weapon_skills_count:
            hard_passed = false
            
    if hard_passed:
        return true
        
    # 2. Dynamic Aptitude Scoring Check (GDD Formula)
    # AptitudeScore = sum(max(0, Attr - 4) * 2.5) + sum((Skill / Req) * 15.0)
    # Unlocks if AptitudeScore >= 25.0 and primary attribute meets 80% baseline
    var aptitude = calculate_aptitude(attrs, skills)
    if aptitude >= 25.0:
        # Verify primary attribute meets at least 80% of requirement
        var meets_primary_ratio = true
        for attr_name in required_attributes.keys():
            var req_val = float(required_attributes[attr_name])
            var cur_val = float(_get_attr_value(attrs, attr_name))
            if cur_val < (req_val * 0.80):
                meets_primary_ratio = false
                break
        return meets_primary_ratio
        
    return false

## Computes aptitude score strictly per GDD formula
func calculate_aptitude(attrs: AttributesData, skills: SkillComponent) -> float:
    if not attrs or not skills:
        return 0.0
        
    var score: float = 0.0
    for attr_name in required_attributes.keys():
        var cur_val = _get_attr_value(attrs, attr_name)
        score += maxf(0.0, float(cur_val - 4)) * 2.5
        
    for s_id in required_skills.keys():
        var req_lvl = float(required_skills[s_id])
        if req_lvl > 0.0:
            var s = skills.get_skill(s_id)
            var cur_lvl = s.level if s else 0.0
            score += (cur_lvl / req_lvl) * 15.0
            
    return score

## Applies permanent class attribute bonuses and attaches passive properties
func apply_to_player(player: Node2D) -> Dictionary:
    var applied_changes: Dictionary = {}
    var stats = player.get_node_or_null("StatsComponent") as StatsComponent
    if not stats and is_instance_valid(player):
        for child in player.get_children():
            if child is StatsComponent:
                stats = child
                break
    if stats and stats.attributes:
        for attr_name in attribute_bonuses.keys():
            var bonus = int(attribute_bonuses[attr_name])
            match attr_name.to_lower():
                "strength":
                    stats.attributes.strength += bonus
                "dexterity":
                    stats.attributes.dexterity += bonus
                "constitution":
                    stats.attributes.constitution += bonus
                "intelligence":
                    stats.attributes.intelligence += bonus
                "wisdom":
                    stats.attributes.wisdom += bonus
                "charisma":
                    stats.attributes.charisma += bonus
            applied_changes[attr_name] = bonus
        stats._recalculate_max_vitals(false)
        
    # Store class metadata on player
    player.set_meta("class_id", class_id)
    player.set_meta("class_name", class_title)
    player.set_meta("class_passive_type", passive_type)
    player.set_meta("class_passive_values", passive_values)
    
    # Unlock and register the class-exclusive skill
    var skills = player.get_node_or_null("SkillComponent") as SkillComponent
    if not skills and is_instance_valid(player):
        for child in player.get_children():
            if child is SkillComponent:
                skills = child
                break
    if skills:
        skills.unlock_class_exclusive_skill(exclusive_skill_id, 5.0)
    
    return applied_changes

func _get_attr_value(attrs: AttributesData, attr_name: String) -> int:
    match attr_name.to_lower():
        "strength":
            return attrs.strength
        "dexterity":
            return attrs.dexterity
        "constitution":
            return attrs.constitution
        "intelligence":
            return attrs.intelligence
        "wisdom":
            return attrs.wisdom
        "charisma":
            return attrs.charisma
        _:
            return 10
