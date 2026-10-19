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

## Resolves a manual ranged attack (Bow, Firearm, Thrown Weapon, or Alchemical AoE Bomb) along a Line-of-Fire ray.
## Enforces the Pass-Through / Obstacle Targeting Rule: if an intermediate entity stands on the line of fire,
## that blocking entity intercepts and absorbs the attack (or centers the AoE detonation).
func execute_ranged_attack(
    origin_cell: Vector2i,
    target_cell: Vector2i,
    grid: DungeonGrid,
    weapon: ItemData = null,
    ammo: ItemData = null
) -> Dictionary:
    var active_item = weapon if weapon else ammo
    var max_range = active_item.range_tiles if (active_item and active_item.range_tiles > 1) else 6
    var area_radius = active_item.area_radius if active_item else 0
    if ammo and ammo.area_radius > area_radius:
        area_radius = ammo.area_radius

    var lof = TargetingSystem.calculate_line_of_fire(
        origin_cell,
        target_cell,
        grid,
        max_range,
        area_radius,
        false,
        false,
        get_entity()
    )

    if not lof.get("is_valid", false):
        return {
            "success": false,
            "hit": false,
            "damage": 0,
            "reason": lof.get("status_text", "Invalid ranged target"),
            "lof": lof
        }

    var eff_cell: Vector2i = lof.get("effective_target_cell", target_cell)
    var was_intercepted: bool = (int(lof.get("blocker_type", 0)) == TargetingSystem.BlockerType.ENTITY)

    # Consume 1 unit of ammunition if applicable
    if ammo:
        ammo.quantity -= 1
        var inv = get_inventory()
        if ammo.quantity <= 0 and inv:
            if inv.equipped_slots.get(ItemData.EquipSlot.AMMUNITION) == ammo:
                inv.equipped_slots.erase(ItemData.EquipSlot.AMMUNITION)
                inv.emit_signal("item_unequipped", ItemData.EquipSlot.AMMUNITION, ammo)
            else:
                inv.remove_item(ammo)

    # 1. AoE Explosive / Alchemical Bomb Resolution
    if area_radius > 0:
        var targets_hit: Array[Node2D] = []
        var total_dmg_dealt: int = 0
        var aoe_cells: Array = lof.get("aoe_cells", [eff_cell])
        var atk_stats = get_stats()
        var atk_skills = get_skills()

        for c in aoe_cells:
            var cell_v = c as Vector2i
            if grid and grid.is_occupied(cell_v):
                var occ = grid.get_occupant(cell_v)
                if is_instance_valid(occ) and occ != get_entity():
                    var def_stats = occ.get_node_or_null("StatsComponent") as StatsComponent
                    if def_stats:
                        var min_d = active_item.base_damage_min if active_item else 10
                        var max_d = active_item.base_damage_max if active_item else 18
                        var dmg = randi_range(min_d, max_d)
                        def_stats.take_damage(dmg, get_entity())
                        targets_hit.append(occ)
                        total_dmg_dealt += dmg
                        var jitter = Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
                        emit_signal("floating_text_requested", "BOOM! %d" % dmg, Color(1.0, 0.45, 0.1), occ.global_position + jitter)

        if atk_skills and atk_stats:
            atk_skills.train_skill(SkillData.SkillId.THROWING, 15.0, atk_stats.attributes)

        var item_label = active_item.item_name if active_item else "Explosive"
        var msg = "%s detonated at (%d, %d) hitting %d target(s)!" % [item_label, eff_cell.x, eff_cell.y, targets_hit.size()]
        return {
            "success": true,
            "hit": not targets_hit.is_empty(),
            "damage": total_dmg_dealt,
            "targets_hit": targets_hit,
            "effective_target_cell": eff_cell,
            "intercepted": was_intercepted,
            "message": msg,
            "lof": lof
        }

    # 2. Single-Target Projectile Resolution (Bow, Firearm, Throwing Knife)
    var defender: Node2D = lof.get("target_entity", null)
    if not defender and grid and grid.is_occupied(eff_cell):
        defender = grid.get_occupant(eff_cell)

    if defender and is_instance_valid(defender) and defender != get_entity():
        var atk_res = execute_attack(defender, active_item)
        atk_res["success"] = true
        atk_res["effective_target_cell"] = eff_cell
        atk_res["intercepted"] = was_intercepted
        atk_res["lof"] = lof
        var def_name = defender.get("enemy_name") if "enemy_name" in defender else defender.name
        var prefix = "[INTERCEPTED] " if was_intercepted else ""
        if atk_res["hit"]:
            atk_res["message"] = "%sRanged shot hits %s for %d damage!" % [prefix, def_name, atk_res["damage"]]
        else:
            atk_res["message"] = "%sRanged shot at %s missed (%s)!" % [prefix, def_name, atk_res["defense_type"]]
        return atk_res

    # Shot landed on an empty floor tile
    if grid:
        emit_signal("floating_text_requested", "Thud!", Color(0.7, 0.7, 0.7), grid.grid_to_world(eff_cell))
    return {
        "success": true,
        "hit": false,
        "damage": 0,
        "defender": null,
        "effective_target_cell": eff_cell,
        "intercepted": was_intercepted,
        "message": "Shot landed on empty floor at (%d, %d)." % [eff_cell.x, eff_cell.y],
        "lof": lof
    }

