class_name CombatComponent
extends Node

## CombatComponent: Resolves hit checks, multi-tier crits, armor soak, and skill training.

signal attack_resolved(result: Dictionary)
signal floating_text_requested(text: String, color: Color, world_pos: Vector2)

var parent_entity: Node2D = null

func get_entity() -> Node2D:
    if is_instance_valid(parent_entity):
        return parent_entity
    parent_entity = get_parent() as Node2D
    return parent_entity

func _get_event_bus() -> Node:
    var loop = Engine.get_main_loop()
    if loop and loop is SceneTree:
        return (loop as SceneTree).root.get_node_or_null("EventBus")
    return null

func get_stats() -> StatsComponent:
    var ent = get_entity()
    if not ent:
        return null
    var comp = ent.get_node_or_null("StatsComponent") as StatsComponent
    if comp:
        return comp
    for child in ent.get_children():
        if child is StatsComponent:
            return child
    return null

func get_skills() -> SkillComponent:
    var ent = get_entity()
    if not ent:
        return null
    var comp = ent.get_node_or_null("SkillComponent") as SkillComponent
    if comp:
        return comp
    for child in ent.get_children():
        if child is SkillComponent:
            return child
    return null

func get_inventory() -> InventoryComponent:
    var ent = get_entity()
    if not ent:
        return null
    var comp = ent.get_node_or_null("InventoryComponent") as InventoryComponent
    if comp:
        return comp
    for child in ent.get_children():
        if child is InventoryComponent:
            return child
    return null

## Calculates hit probability strictly per design document:
## P(Hit) = (Attacker Weapon Skill + 50) / ((Defender Defense Skill + 50) * 2) + AccBonuses - DefBonuses
## Defender Defense Skill = max(Defender Weapon Skill, Defender Active Defense Mode Skill)
func calculate_hit_chance(defender: Node2D, weapon: ItemData = null) -> Dictionary:
    var atk_skills = get_skills()
    var atk_stats = get_stats()
    var def_skills = defender.get_node_or_null("SkillComponent") as SkillComponent
    if not def_skills:
        for child in defender.get_children():
            if child is SkillComponent:
                def_skills = child
                break
    var def_stats = defender.get_node_or_null("StatsComponent") as StatsComponent
    if not def_stats:
        for child in defender.get_children():
            if child is StatsComponent:
                def_stats = child
                break
    
    # 1. Determine Attacker Weapon Skill
    var weapon_skill_id = SkillData.SkillId.SWORDSMANSHIP
    var weapon_type = AttributesData.WeaponType.MELEE
    var acc_bonus = 0.0
    
    if weapon:
        weapon_type = weapon.weapon_type
        acc_bonus = weapon.accuracy_bonus
        match weapon.weapon_type:
            AttributesData.WeaponType.MELEE:
                weapon_skill_id = SkillData.SkillId.SWORDSMANSHIP
            AttributesData.WeaponType.FIREARM:
                weapon_skill_id = SkillData.SkillId.MARKSMANSHIP
            AttributesData.WeaponType.BOW, AttributesData.WeaponType.HIGH_TENSION_BOW:
                weapon_skill_id = SkillData.SkillId.ARCHERY
            AttributesData.WeaponType.THROWN, AttributesData.WeaponType.SLING:
                weapon_skill_id = SkillData.SkillId.THROWING
            _:
                weapon_skill_id = SkillData.SkillId.BRAWLING
                
    var atk_skill_val = 10.0
    if atk_skills and atk_stats:
        atk_skill_val = atk_skills.get_effective_level(weapon_skill_id, atk_stats.attributes)
    
    # 2. Determine Defender Defensive Skill (higher of weapon skill or active stance skill)
    var def_weapon_val = 10.0
    var def_stance_val = 10.0
    var def_mode_name = "DODGE"
    
    if def_skills and def_stats:
        def_weapon_val = def_skills.get_effective_level(SkillData.SkillId.SWORDSMANSHIP, def_stats.attributes)
        var stance_id = def_skills.get_active_defensive_skill_id()
        def_mode_name = "PARRY" if stance_id == SkillData.SkillId.PARRY else "DODGE"
        def_stance_val = def_skills.get_effective_level(stance_id, def_stats.attributes)
        
    var def_chosen_val = maxf(def_weapon_val, def_stance_val)
    var defense_used = def_mode_name if def_stance_val >= def_weapon_val else "WEAPON_PARRY"
    
    # GDD Formula
    var numerator = atk_skill_val + 50.0
    var denominator = (def_chosen_val + 50.0) * 2.0
    var raw_chance = (numerator / denominator) + acc_bonus
    var final_chance = clampf(raw_chance, 0.05, 0.95) # 5% whiff minimum, 95% cap
    
    return {
        "hit_chance": final_chance,
        "atk_skill_id": weapon_skill_id,
        "atk_skill_val": atk_skill_val,
        "def_skill_val": def_chosen_val,
        "defense_used": defense_used,
        "weapon_type": weapon_type
    }

func execute_attack(defender: Node2D, weapon: ItemData = null) -> Dictionary:
    var hit_info = calculate_hit_chance(defender, weapon)
    var hit_chance = hit_info["hit_chance"] as float
    var roll = randf()
    var is_hit = roll <= hit_chance
    
    var atk_stats = get_stats()
    var atk_skills = get_skills()
    var def_stats = defender.get_node_or_null("StatsComponent") as StatsComponent
    var def_skills = defender.get_node_or_null("SkillComponent") as SkillComponent
    var def_inv = defender.get_node_or_null("InventoryComponent") as InventoryComponent
    
    var result = {
        "attacker": get_entity(),
        "defender": defender,
        "hit": is_hit,
        "damage": 0,
        "is_crit": false,
        "crit_multiplier": 1.0,
        "is_fatal": false,
        "defense_type": hit_info["defense_used"],
        "intimidation_triggered": false
    }
    
    if not is_hit:
        # Train defender's defensive skill on a successful dodge/parry
        if def_skills and def_stats:
            var def_skill_id = def_skills.get_active_defensive_skill_id()
            def_skills.train_skill(def_skill_id, hit_info["atk_skill_val"], def_stats.attributes)
            
        emit_signal("attack_resolved", result)
        var jitter = Vector2(randf_range(-14.0, 14.0), randf_range(-10.0, 10.0))
        emit_signal("floating_text_requested", hit_info["defense_used"] + "!", Color(0.4, 0.8, 1.0), defender.global_position + jitter)
        return result
    
    # --- HIT SUCCEEDED ---
    # 1. Base Weapon Damage Roll
    var min_dmg = weapon.base_damage_min if weapon else 2
    var max_dmg = weapon.base_damage_max if weapon else 5
    var base_damage = float(randi_range(min_dmg, max_dmg))
    
    # 2. Strength Scaling
    var str_modifier = 1.0
    if atk_stats:
        var w_type = hit_info["weapon_type"] as AttributesData.WeaponType
        if w_type == AttributesData.WeaponType.MELEE:
            str_modifier = atk_stats.attributes.get_melee_damage_modifier()
        else:
            str_modifier = atk_stats.attributes.get_ranged_damage_modifier(w_type)
            
    var scaled_damage = base_damage * str_modifier
    
    # 3. Multi-Tier Critical Hit
    var crit_mult = 1.0
    if atk_stats:
        crit_mult = atk_stats.attributes.evaluate_critical_multiplier()
    
    var is_crit = crit_mult > 1.0
    result["is_crit"] = is_crit
    result["crit_multiplier"] = crit_mult
    
    var damage_after_crit = scaled_damage * crit_mult
    
    # 4. Armor Soak
    var total_armor = def_inv.get_total_armor() if def_inv else 0
    var final_damage = max(1, int(round(damage_after_crit)) - total_armor)
    result["damage"] = final_damage
    
    # Apply damage to defender
    if def_stats:
        def_stats.take_damage(final_damage, get_entity())
        result["is_fatal"] = def_stats.current_hp <= 0.0
        
    # 5. Skill Training for Attacker
    if atk_skills and atk_stats:
        var weapon_skill_id = hit_info["atk_skill_id"] as SkillData.SkillId
        atk_skills.train_skill(weapon_skill_id, hit_info["def_skill_val"], atk_stats.attributes)
        
    # 6. Charisma Intimidation Morale Check (on Crit or Fatal Kill)
    if (is_crit or result["is_fatal"]) and atk_stats:
        _trigger_intimidation_check(defender, atk_stats.attributes)
        result["intimidation_triggered"] = true
        
    # Visual Feedback
    var text_color = Color(1.0, 0.8, 0.2) if not is_crit else Color(1.0, 0.2, 0.2)
    var label_text = str(final_damage)
    if is_crit:
        label_text = "CRIT! %s (%dx)" % [str(final_damage), int(crit_mult)]
    var hit_jitter = Vector2(randf_range(-14.0, 14.0), randf_range(-10.0, 10.0))
    emit_signal("floating_text_requested", label_text, text_color, defender.global_position + hit_jitter)
    
    emit_signal("attack_resolved", result)
    return result

func _trigger_intimidation_check(victim: Node2D, player_attrs: AttributesData) -> void:
    var dc = player_attrs.get_intimidation_difficulty_class()
    var victim_morale_roll = randi_range(1, 100)
    
    if victim_morale_roll < dc:
        var margin = dc - victim_morale_roll
        if victim.has_method("apply_intimidation"):
            if margin > 25:
                victim.apply_intimidation("TERRIFIED", randi_range(3, 5))
            else:
                victim.apply_intimidation("HESITANT", randi_range(1, 2))
