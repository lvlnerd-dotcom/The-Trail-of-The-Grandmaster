class_name CombatComponent
extends Node

## CombatComponent: Resolves hit checks, multi-tier crits, armor soak, and skill training.

signal attack_resolved(result: Dictionary)
signal floating_text_requested(text: String, color: Color, world_pos: Vector2)

var parent_entity: Node2D = null
var ability_cooldowns: Dictionary = {} # ability_id -> int turns remaining
var active_defense_buff: float = 0.0
var active_defense_buff_turns: int = 0

func tick_cooldowns() -> void:
    var expired: Array[String] = []
    for ab_id in ability_cooldowns.keys():
        ability_cooldowns[ab_id] = maxi(0, int(ability_cooldowns[ab_id]) - 1)
        if ability_cooldowns[ab_id] <= 0:
            expired.append(String(ab_id))
    for ab_id in expired:
        ability_cooldowns.erase(ab_id)
    if active_defense_buff_turns > 0:
        active_defense_buff_turns -= 1
        if active_defense_buff_turns <= 0:
            active_defense_buff = 0.0

func get_ability_cooldown(ability_id: String) -> int:
    return int(ability_cooldowns.get(ability_id, 0))

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

func _find_component(entity: Node2D, type_name: String) -> Node:
    if not entity:
        return null
    var direct = entity.get_node_or_null(type_name)
    if direct:
        return direct
    for child in entity.get_children():
        if child.get_class() == type_name or (child.get_script() and child.get_script().get_global_name() == type_name):
            return child
    return null

## Resolves the exact weapon skill ID for a given weapon or entity.
## Strictly uses weapon.associated_skill_id when a weapon is provided or equipped.
func resolve_weapon_skill_id(weapon: ItemData, skills_comp: SkillComponent = null, inv_comp: InventoryComponent = null) -> SkillData.SkillId:
    if weapon:
        return weapon.associated_skill_id
    if inv_comp:
        var eq_weapon = inv_comp.get_equipped_weapon()
        if eq_weapon:
            return eq_weapon.associated_skill_id
    if skills_comp:
        var brawl = skills_comp.get_skill(SkillData.SkillId.BRAWLING)
        var sword = skills_comp.get_skill(SkillData.SkillId.SWORDSMANSHIP)
        if brawl and sword and brawl.level > sword.level:
            return SkillData.SkillId.BRAWLING
        elif sword and sword.level > 0.0:
            return SkillData.SkillId.SWORDSMANSHIP
    return SkillData.SkillId.SWORDSMANSHIP

## Calculates hit probability strictly per GDD formula:
## Hit Chance = (Attacker Weapon Skill + 50) / ((Defender Skill + 50) * 2) + Attacker Mods - Defender Mods
## Crucial Defensive Rule: Defender Skill = max(Defender Equipped Weapon Skill, Defender Dedicated Defensive Skill)
func calculate_hit_chance(defender: Node2D, weapon: ItemData = null, extra_attacker_mod: float = 0.0) -> Dictionary:
    var atk_skills = get_skills()
    var atk_stats = get_stats()
    var atk_inv = get_inventory()
    var def_skills = _find_component(defender, "SkillComponent") as SkillComponent
    var def_stats = _find_component(defender, "StatsComponent") as StatsComponent
    var def_inv = _find_component(defender, "InventoryComponent") as InventoryComponent
    var def_combat = _find_component(defender, "CombatComponent") as CombatComponent
    
    var active_weapon = weapon
    if not active_weapon and atk_inv:
        active_weapon = atk_inv.get_equipped_weapon()

    # 1. Determine Attacker Weapon Skill (strictly bound to weapon.associated_skill_id)
    var weapon_skill_id = resolve_weapon_skill_id(active_weapon, atk_skills, atk_inv)
    var weapon_type = active_weapon.weapon_type if active_weapon else AttributesData.WeaponType.MELEE
    var attacker_mods: float = (active_weapon.accuracy_bonus if active_weapon else 0.0) + extra_attacker_mod
    
    var atk_entity = get_entity()
    if atk_entity and atk_entity.has_node("StatusEffectComponent"):
        var a_sec = atk_entity.get_node("StatusEffectComponent") as StatusEffectComponent
        if a_sec and a_sec.is_blinded():
            attacker_mods -= 0.30
            
    var atk_skill_val = 10.0
    if atk_skills and atk_stats:
        atk_skill_val = atk_skills.get_effective_level(weapon_skill_id, atk_stats.attributes)
    
    # 2. Crucial Defensive Rule: Evaluate both Defender's Equipped Weapon Skill AND Dedicated Defensive Skill
    var def_weapon_skill_id = resolve_weapon_skill_id(null, def_skills, def_inv)
    var def_weapon_val = 10.0
    var def_stance_val = 10.0
    var stance_id = SkillData.SkillId.DODGE
    var has_shield: bool = def_inv != null and def_inv.has_shield_equipped()
    
    if def_skills and def_stats:
        def_weapon_val = def_skills.get_effective_level(def_weapon_skill_id, def_stats.attributes)
        stance_id = def_skills.get_active_defensive_skill_id()
        def_stance_val = def_skills.get_effective_level(stance_id, def_stats.attributes)
        
    var def_chosen_val = maxf(def_weapon_val, def_stance_val)
    
    # Resolve defense type, floating combat text, and log description
    var defense_used = "DODGE"
    var defense_floating = "DODGE!"
    var defense_verb = "dodges"
    
    if stance_id == SkillData.SkillId.PARRY:
        if has_shield:
            defense_used = "BLOCK"
            defense_floating = "BLOCK!"
            defense_verb = "blocks with shield"
        else:
            defense_used = "PARRY"
            defense_floating = "PARRY!"
            defense_verb = "parries"
    else: # DODGE stance: Always displays DODGE matching active stance and training focus
        defense_used = "DODGE"
        defense_floating = "DODGE!"
        defense_verb = "dodges"
    
    # 3. Defender Mods (Stance-specific gear defense, Lv 25 Keystone Cross-Synergies, buffs)
    var defender_mods: float = 0.0
    if def_inv:
        var def_stance_enum = def_skills.active_defensive_mode if def_skills else null
        defender_mods += def_inv.get_total_defense_bonus(def_stance_enum, def_skills)
    # Overburdened state penalties
    if atk_inv and atk_stats and atk_stats.attributes:
        if atk_inv.is_overburdened(atk_stats.attributes.get_max_carry_weight_stones()):
            var is_dex_weapon = false
            if weapon_skill_id in [SkillData.SkillId.FINESSE_WEAPON_FIGHTING, SkillData.SkillId.ARCHERY, SkillData.SkillId.THROWING]:
                is_dex_weapon = true
            elif SkillData.COMBAT_SKILL_SCALING.has(weapon_skill_id):
                var scaling = SkillData.COMBAT_SKILL_SCALING[weapon_skill_id]
                if scaling.get("primary") == "dexterity" or scaling.get("secondary") == "dexterity":
                    is_dex_weapon = true
            if is_dex_weapon:
                attacker_mods -= 0.15

    if def_inv and def_stats and def_stats.attributes:
        if def_inv.is_overburdened(def_stats.attributes.get_max_carry_weight_stones()):
            defender_mods -= 0.20

    if defender:
        var def_affix = str(defender.get("elite_affix")) if "elite_affix" in defender else ""
        if def_affix == "Swift":
            def_chosen_val += 20.0
    
    # Exact GDD Formula:
    # Hit Chance = (Attacker Weapon Skill + 50) / ((Defender Skill + 50) * 2) + Attacker Mods - Defender Mods
    var numerator = atk_skill_val + 50.0
    var denominator = (def_chosen_val + 50.0) * 2.0
    var raw_chance = (numerator / denominator) + attacker_mods - defender_mods
    var final_chance = clampf(raw_chance, 0.05, 0.95) # 5% whiff minimum, 95% cap
    
    return {
        "hit_chance": final_chance,
        "raw_chance": raw_chance,
        "atk_skill_id": weapon_skill_id,
        "atk_skill_val": atk_skill_val,
        "def_weapon_skill_id": def_weapon_skill_id,
        "def_weapon_val": def_weapon_val,
        "def_stance_val": def_stance_val,
        "def_skill_val": def_chosen_val,
        "attacker_mods": attacker_mods,
        "defender_mods": defender_mods,
        "defense_used": defense_used,
        "defense_floating": defense_floating,
        "defense_verb": defense_verb,
        "weapon_type": weapon_type
    }

func execute_attack(defender: Node2D, weapon: ItemData = null, ability: WeaponAbilityData = null) -> Dictionary:
    var atk_inv = get_inventory()
    var active_weapon = weapon
    if not active_weapon and atk_inv:
        active_weapon = atk_inv.get_equipped_weapon()

    var extra_acc = ability.accuracy_bonus if ability else 0.0
    var hit_info = calculate_hit_chance(defender, active_weapon, extra_acc)
    var hit_chance = hit_info["hit_chance"] as float
    var strike_count: int = maxi(1, ability.strike_count) if ability else 1
    
    var atk_stats = get_stats()
    var atk_skills = get_skills()
    var def_stats = _find_component(defender, "StatsComponent") as StatsComponent
    var def_skills = _find_component(defender, "SkillComponent") as SkillComponent
    var def_inv = _find_component(defender, "InventoryComponent") as InventoryComponent
    
    if ability and ability.self_defense_buff > 0.0:
        active_defense_buff = ability.self_defense_buff
        active_defense_buff_turns = 2

    var any_hit: bool = false
    var total_damage: int = 0
    var any_crit: bool = false
    var max_crit_mult: float = 1.0
    var is_fatal: bool = false
    var applied_statuses: Array[String] = []

    for _strike in range(strike_count):
        if is_fatal:
            break
        var roll = randf()
        var is_hit = roll <= hit_chance
        if not is_hit:
            if def_skills and def_stats:
                var def_skill_id = def_skills.get_active_defensive_skill_id()
                def_skills.train_skill(def_skill_id, hit_info["atk_skill_val"], def_stats.attributes)
            continue

        any_hit = true
        var min_dmg = active_weapon.base_damage_min if active_weapon else 2
        var max_dmg = active_weapon.base_damage_max if active_weapon else 5
        var base_damage = float(randi_range(min_dmg, max_dmg))
        if ability:
            base_damage *= ability.damage_multiplier

        # Attribute Damage Scaling
        var str_modifier = 1.0
        if atk_stats:
            var w_type = hit_info["weapon_type"] as AttributesData.WeaponType
            if w_type == AttributesData.WeaponType.MELEE:
                str_modifier = atk_stats.attributes.get_melee_damage_modifier()
            else:
                str_modifier = atk_stats.attributes.get_ranged_damage_modifier(w_type)

        var scaled_damage = base_damage * str_modifier

        # Backstab / Stealth Multiplier for Finesse Weapons (Dagger, Stiletto, Assassin's Blade)
        var ent = get_entity()
        if active_weapon and active_weapon.backstab_multiplier > 1.0 and ent and bool(ent.get_meta("is_hidden", false)):
            scaled_damage *= active_weapon.backstab_multiplier
            ent.set_meta("is_hidden", false)

        # Multi-Tier Critical Hit
        var crit_mult = 1.0
        if ability and ability.guaranteed_crit:
            crit_mult = maxf(2.0, atk_stats.attributes.evaluate_critical_multiplier() if atk_stats else 2.0)
        elif atk_stats:
            crit_mult = atk_stats.attributes.evaluate_critical_multiplier()
            if crit_mult <= 1.0 and active_weapon and active_weapon.crit_chance_bonus > 0.0:
                if randf() <= active_weapon.crit_chance_bonus:
                    crit_mult = 2.0

        if crit_mult > 1.0:
            any_crit = true
            max_crit_mult = maxf(max_crit_mult, crit_mult)

        var damage_after_crit = scaled_damage * crit_mult

        # Armor Soak & Armor Penetration
        var raw_armor = float(def_inv.get_total_armor()) if def_inv else 0.0
        if defender:
            var def_affix = str(defender.get("elite_affix")) if "elite_affix" in defender else ""
            if def_affix == "Armored":
                raw_armor += 4.0
        var armor_pen = active_weapon.armor_penetration if active_weapon else 0.0
        if ability:
            armor_pen = clampf(armor_pen + ability.armor_penetration, 0.0, 1.0)
        var effective_armor = int(round(raw_armor * (1.0 - clampf(armor_pen, 0.0, 1.0))))
        var strike_damage = max(1, int(round(damage_after_crit)) - effective_armor)

        # Undead vulnerability to Silver weapons (2.0x damage)
        var def_is_undead = false
        if defender:
            if "is_undead" in defender and bool(defender.get("is_undead")):
                def_is_undead = true
            elif defender.has_meta("is_undead") and bool(defender.get_meta("is_undead")):
                def_is_undead = true
        var is_silver_weapon = false
        if active_weapon:
            if bool(active_weapon.get("is_silver")):
                is_silver_weapon = true
            elif "tags" in active_weapon and active_weapon.tags.has("silver_weapon"):
                is_silver_weapon = true
            elif active_weapon.item_id.contains("silver"):
                is_silver_weapon = true

        if def_is_undead and is_silver_weapon:
            strike_damage = int(round(strike_damage * 2.0))

        # Elite Attacker affixes
        var atk_ent = get_entity()
        var atk_affix = str(atk_ent.get("elite_affix")) if (atk_ent and "elite_affix" in atk_ent) else ""
        if atk_affix == "Flame-Touched":
            var bonus_fire = maxi(1, int(round(strike_damage * 0.25)))
            strike_damage += bonus_fire

        total_damage += strike_damage

        if defender.has_method("take_damage"):
            defender.take_damage(strike_damage, get_entity())
            is_fatal = (defender.current_hp <= 0.0) if ("current_hp" in defender) else (def_stats != null and def_stats.current_hp <= 0.0)
        elif def_stats:
            def_stats.take_damage(strike_damage, get_entity())
            is_fatal = def_stats.current_hp <= 0.0

        if atk_affix == "Vampiric" and strike_damage > 0:
            var heal_amt = float(strike_damage) * 0.30
            if atk_stats:
                atk_stats.heal(heal_amt)

        if atk_affix == "Venomous":
            if defender.has_node("StatusEffectComponent"):
                var d_sec = defender.get_node("StatusEffectComponent") as StatusEffectComponent
                if d_sec:
                    d_sec.apply_poison(StatusEffectComponent.PoisonTier.STANDARD, 3)
            defender.set_meta("status_POISONED", 3)
            if not applied_statuses.has("POISONED"):
                applied_statuses.append("POISONED")

        # Apply Weapon Passive Status Effects (Poison, Bleed, Stun) & Ability Status Effects
        _apply_weapon_statuses(defender, active_weapon, ability, applied_statuses)

    var result = {
        "attacker": get_entity(),
        "defender": defender,
        "hit": any_hit,
        "damage": total_damage,
        "is_crit": any_crit,
        "crit_multiplier": max_crit_mult,
        "is_fatal": is_fatal,
        "defense_type": hit_info["defense_used"],
        "defense_verb": hit_info["defense_verb"],
        "defense_floating": hit_info["defense_floating"],
        "trained_skill_id": hit_info["atk_skill_id"],
        "statuses_applied": applied_statuses,
        "intimidation_triggered": false
    }

    if not any_hit:
        emit_signal("attack_resolved", result)
        var jitter = Vector2(randf_range(-14.0, 14.0), randf_range(-10.0, 10.0))
        emit_signal("floating_text_requested", hit_info["defense_floating"], Color(0.4, 0.8, 1.0), defender.global_position + jitter)
        return result

    # Strictly train ONLY the weapon's assigned skill (e.g. Mace -> BLUNT_WEAPON_FIGHTING)
    if atk_skills and atk_stats:
        var weapon_skill_id = hit_info["atk_skill_id"] as SkillData.SkillId
        atk_skills.train_skill(weapon_skill_id, hit_info["def_skill_val"], atk_stats.attributes)

    # Charisma Intimidation Morale Check (on Crit or Fatal Kill)
    if (any_crit or is_fatal) and atk_stats:
        _trigger_intimidation_check(defender, atk_stats.attributes)
        result["intimidation_triggered"] = true

    # Visual Feedback
    var text_color = Color(1.0, 0.8, 0.2) if not any_crit else Color(1.0, 0.2, 0.2)
    var label_text = str(total_damage)
    if ability:
        label_text = "%s! %d" % [ability.ability_name, total_damage]
    elif any_crit:
        label_text = "CRIT! %s (%dx)" % [str(total_damage), int(max_crit_mult)]
    var hit_jitter = Vector2(randf_range(-14.0, 14.0), randf_range(-10.0, 10.0))
    emit_signal("floating_text_requested", label_text, text_color, defender.global_position + hit_jitter)

    emit_signal("attack_resolved", result)
    return result

func _apply_weapon_statuses(defender: Node2D, weapon: ItemData, ability: WeaponAbilityData, out_statuses: Array[String]) -> void:
    if not is_instance_valid(defender):
        return
    var def_sec: StatusEffectComponent = null
    if defender.has_node("StatusEffectComponent"):
        def_sec = defender.get_node("StatusEffectComponent") as StatusEffectComponent

    if weapon:
        if weapon.poison_chance > 0.0 and randf() <= weapon.poison_chance:
            if def_sec:
                def_sec.apply_poison(StatusEffectComponent.PoisonTier.MINOR, 3)
            defender.set_meta("status_POISONED", 3)
            if not out_statuses.has("POISONED"):
                out_statuses.append("POISONED")
        if weapon.bleed_chance > 0.0 and randf() <= weapon.bleed_chance:
            if def_sec:
                def_sec.apply_bleed(4, 3)
            defender.set_meta("status_BLEEDING", 3)
            if not out_statuses.has("BLEEDING"):
                out_statuses.append("BLEEDING")
        if weapon.stun_chance > 0.0 and randf() <= weapon.stun_chance:
            if def_sec:
                def_sec.apply_stun(1)
            defender.set_meta("status_STUNNED", 1)
            if not out_statuses.has("STUNNED"):
                out_statuses.append("STUNNED")
    if ability and ability.status_effect_id != "" and ability.status_chance > 0.0:
        if randf() <= ability.status_chance:
            if def_sec:
                match ability.status_effect_id:
                    "POISONED", "POISON":
                        def_sec.apply_poison(StatusEffectComponent.PoisonTier.MINOR, ability.status_duration)
                    "BLEEDING", "BLEED":
                        def_sec.apply_bleed(4, ability.status_duration)
                    "STUNNED", "STUN":
                        def_sec.apply_stun(ability.status_duration)
                    "BLIND", "BLINDNESS":
                        def_sec.apply_blindness(ability.status_duration)
            defender.set_meta("status_" + ability.status_effect_id, ability.status_duration)
            if not out_statuses.has(ability.status_effect_id):
                out_statuses.append(ability.status_effect_id)

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

## Executes a Level 25 Weapon Active Ability.
func execute_weapon_ability(
    weapon: ItemData,
    origin_cell: Vector2i,
    target_cell: Vector2i,
    grid: DungeonGrid
) -> Dictionary:
    if not weapon or not weapon.active_ability:
        return {"success": false, "hit": false, "reason": "Weapon has no active ability"}

    var ability: WeaponAbilityData = weapon.active_ability
    var atk_skills = get_skills()
    if atk_skills and not atk_skills.is_weapon_ability_unlocked(weapon):
        var req_skill_name = SkillData.get_skill_name(weapon.associated_skill_id)
        return {
            "success": false,
            "hit": false,
            "reason": "Requires %s Level %.0f" % [req_skill_name, ability.required_skill_level]
        }

    var cd = get_ability_cooldown(ability.ability_id)
    if cd > 0:
        return {
            "success": false,
            "hit": false,
            "reason": "%s is on cooldown (%d turns remaining)" % [ability.ability_name, cd]
        }

    # Ranged weapon ability execution
    if ability.requires_ranged_targeting():
        var inv = get_inventory()
        var ammo: ItemData = null
        if weapon.requires_ammo and inv:
            ammo = inv.get_equipped_ammo()
            if not ammo or ammo.quantity <= 0:
                return {"success": false, "hit": false, "reason": "Out of ammunition!"}
        elif weapon.equip_slot == ItemData.EquipSlot.AMMUNITION:
            ammo = weapon
            if ammo.quantity <= 0:
                return {"success": false, "hit": false, "reason": "Out of %s!" % weapon.item_name}

        var max_r = ability.range_override if ability.range_override > 0 else (weapon.range_tiles if weapon.range_tiles > 1 else 5)
        var aoe_r = ability.area_radius if ability.area_radius > 0 else weapon.area_radius
        var lof = TargetingSystem.calculate_line_of_fire(origin_cell, target_cell, grid, max_r, aoe_r, false, false, get_entity())
        if not lof.get("is_valid", false):
            return {"success": false, "hit": false, "reason": lof.get("status_text", "Invalid target"), "lof": lof}

        if ammo and not ammo.is_returning and not weapon.is_returning:
            ammo.quantity -= 1

        ability_cooldowns[ability.ability_id] = ability.cooldown_turns
        var eff_cell: Vector2i = lof.get("effective_target_cell", target_cell)

        if aoe_r > 0:
            var aoe_cells: Array = lof.get("aoe_cells", [eff_cell])
            var targets_hit: Array[Node2D] = []
            var total_dmg: int = 0
            for c in aoe_cells:
                var cv = c as Vector2i
                if grid and grid.is_occupied(cv):
                    var occ = grid.get_occupant(cv)
                    if is_instance_valid(occ) and occ != get_entity():
                        var sub_res = execute_attack(occ, weapon, ability)
                        if sub_res.get("hit", false):
                            targets_hit.append(occ)
                            total_dmg += int(sub_res.get("damage", 0))
            return {
                "success": true,
                "hit": not targets_hit.is_empty(),
                "damage": total_dmg,
                "targets_hit": targets_hit,
                "ability_id": ability.ability_id,
                "message": "%s hit %d target(s) for %d total damage!" % [ability.ability_name, targets_hit.size(), total_dmg]
            }

        var defender: Node2D = lof.get("target_entity", null)
        if not defender and grid and grid.is_occupied(eff_cell):
            defender = grid.get_occupant(eff_cell)
        if defender and is_instance_valid(defender) and defender != get_entity():
            var atk_res = execute_attack(defender, weapon, ability)
            atk_res["success"] = true
            atk_res["ability_id"] = ability.ability_id
            atk_res["message"] = "Used %s on %s for %d damage!" % [ability.ability_name, defender.name, atk_res["damage"]]
            return atk_res
        return {"success": false, "hit": false, "reason": "No target at destination"}

    # Melee / Reach / Cleave execution
    var max_melee_range = ability.range_override if ability.range_override > 0 else maxi(1, weapon.range_tiles)
    var dist = maxi(absi(target_cell.x - origin_cell.x), absi(target_cell.y - origin_cell.y))
    if dist > max_melee_range or dist == 0:
        return {"success": false, "hit": false, "reason": "Target out of reach (Max %d)" % max_melee_range}

    var primary_defender: Node2D = grid.get_occupant(target_cell) if (grid and grid.is_occupied(target_cell)) else null
    if not primary_defender or primary_defender == get_entity():
        return {"success": false, "hit": false, "reason": "No enemy at target tile"}

    ability_cooldowns[ability.ability_id] = ability.cooldown_turns
    var primary_res = execute_attack(primary_defender, weapon, ability)
    primary_res["success"] = true
    primary_res["ability_id"] = ability.ability_id

    # Cleave Arc or Melee AoE (e.g. Earthshaker Slam / Wide Arc Sweep)
    var extra_targets: Array[Node2D] = []
    if grid and (ability.execution_type == WeaponAbilityData.ExecutionType.MELEE_CLEAVE_ARC or ability.area_radius > 0):
        for dy in range(-1, 2):
            for dx in range(-1, 2):
                var c = target_cell + Vector2i(dx, dy)
                if c == origin_cell or c == target_cell:
                    continue
                if ability.execution_type == WeaponAbilityData.ExecutionType.MELEE_CLEAVE_ARC:
                    var d_origin = maxi(absi(c.x - origin_cell.x), absi(c.y - origin_cell.y))
                    if d_origin > max_melee_range:
                        continue
                if grid.is_occupied(c):
                    var occ = grid.get_occupant(c)
                    if is_instance_valid(occ) and occ != get_entity():
                        var cleave_res = execute_attack(occ, weapon, ability)
                        if cleave_res.get("hit", false):
                            extra_targets.append(occ)
                            primary_res["damage"] = int(primary_res.get("damage", 0)) + int(cleave_res.get("damage", 0))

    primary_res["extra_targets_hit"] = extra_targets
    primary_res["message"] = "Used %s (%d damage)!" % [ability.ability_name, primary_res["damage"]]
    return primary_res

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

    # Consume 1 unit of ammunition unless it is a returning weapon (e.g. Chakram, Boomerang)
    var is_returning_weapon: bool = (ammo and ammo.is_returning) or (active_item and active_item.is_returning)
    if ammo and not is_returning_weapon:
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
                    var min_d = active_item.base_damage_min if active_item else 10
                    var max_d = active_item.base_damage_max if active_item else 18
                    var dmg = randi_range(min_d, max_d)
                    if occ.has_method("take_damage"):
                        occ.take_damage(dmg, get_entity())
                        targets_hit.append(occ)
                        total_dmg_dealt += dmg
                    else:
                        var def_stats = occ.get_node_or_null("StatsComponent") as StatsComponent
                        if def_stats:
                            def_stats.take_damage(dmg, get_entity())
                            targets_hit.append(occ)
                            total_dmg_dealt += dmg
                    var jitter = Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
                    emit_signal("floating_text_requested", "BOOM! %d" % dmg, Color(1.0, 0.45, 0.1), occ.global_position + jitter)

        var trained_skill = active_item.associated_skill_id if active_item else SkillData.SkillId.THROWING
        if atk_skills and atk_stats:
            atk_skills.train_skill(trained_skill, 15.0, atk_stats.attributes)

        var item_label = active_item.item_name if active_item else "Explosive"
        var msg = "%s detonated at (%d, %d) hitting %d target(s)!" % [item_label, eff_cell.x, eff_cell.y, targets_hit.size()]
        return {
            "success": true,
            "hit": not targets_hit.is_empty(),
            "damage": total_dmg_dealt,
            "targets_hit": targets_hit,
            "trained_skill_id": trained_skill,
            "effective_target_cell": eff_cell,
            "intercepted": was_intercepted,
            "message": msg,
            "lof": lof
        }

    # 2. Single-Target Projectile Resolution (Bow, Crossbow, Firearm, Thrown Weapon)
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
            var def_action = atk_res.get("defense_verb", atk_res.get("defense_type", "missed"))
            atk_res["message"] = "%sRanged shot at %s missed (%s)!" % [prefix, def_name, def_action]
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

# --- Milestone 5: Beast Mastery Taming ---

static func is_beast_eligible(target: Node2D) -> bool:
    if not is_instance_valid(target):
        return false
    if target.has_method("is_in_bulwark_stance") or target.has_method("set_tactical_order"):
        return false
    var fac = target.get("faction")
    if fac != null and int(fac) == int(BestiaryCatalog.Faction.FACTION_BEAST):
        return true
    if target.has_meta("faction") and int(target.get_meta("faction")) == int(BestiaryCatalog.Faction.FACTION_BEAST):
        return true
    return false

static func calculate_tame_chance(player: Node2D, target_enemy: Node2D, floor_num: int = 1) -> float:
    if not is_instance_valid(player) or not is_instance_valid(target_enemy):
        return 0.0
        
    var s_bm: float = 0.0
    var p_skills = player.get_node_or_null("SkillComponent") as SkillComponent
    if not p_skills:
        for child in player.get_children():
            if child is SkillComponent:
                p_skills = child
                break
    if p_skills:
        var bm_skill = p_skills.get_skill(SkillData.SkillId.BEAST_MASTERY)
        if bm_skill:
            s_bm = bm_skill.level
            
    var cha_val: float = 10.0
    var p_stats = player.get_node_or_null("StatsComponent") as StatsComponent
    if not p_stats:
        for child in player.get_children():
            if child is StatsComponent:
                p_stats = child
                break
    if p_stats and p_stats.attributes:
        cha_val = float(p_stats.attributes.charisma)
        
    var effective_bm = s_bm + (cha_val * 0.5)
    var l_enemy = 10.0 + (float(floor_num) * 4.0)
    var skill_ratio = (effective_bm + 25.0) / ((l_enemy + 25.0) * 2.0)
    
    var cur_hp = 10.0
    var max_hp = 10.0
    if target_enemy.has_node("StatsComponent"):
        var e_stats = target_enemy.get_node("StatsComponent") as StatsComponent
        cur_hp = e_stats.current_hp
        max_hp = e_stats.get_max_health()
    elif "current_hp" in target_enemy and "max_hp" in target_enemy:
        cur_hp = float(target_enemy.current_hp)
        max_hp = maxf(1.0, float(target_enemy.max_hp))
        
    var r_missing = clampf(1.0 - (cur_hp / maxf(1.0, max_hp)), 0.0, 1.0)
    var missing_hp_bonus = r_missing * 0.55
    
    return clampf(skill_ratio + missing_hp_bonus, 0.05, 0.95)

func attempt_tame_beast(player: Node2D, target_enemy: Node2D, floor_num: int = 1, force_roll: float = -1.0) -> Dictionary:
    if not is_instance_valid(player) or not is_instance_valid(target_enemy):
        return {"success": false, "reason": "Invalid target or player"}
        
    if not is_beast_eligible(target_enemy):
        return {"success": false, "reason": "Target is not an eligible wild beast!"}
        
    var p_stats = player.get_node_or_null("StatsComponent") as StatsComponent
    if not p_stats:
        for child in player.get_children():
            if child is StatsComponent:
                p_stats = child
                break
    var attrs = p_stats.attributes if p_stats else null
    var max_comp = attrs.get_max_companions() if attrs and attrs.has_method("get_max_companions") else 1
    
    var tm: TurnManager = null
    if "turn_manager" in player and player.turn_manager:
        tm = player.turn_manager
    elif player.has_node("TurnManager"):
        tm = player.get_node("TurnManager") as TurnManager
    else:
        var loop = Engine.get_main_loop()
        if loop and loop is SceneTree:
            tm = (loop as SceneTree).root.find_child("TurnManager", true, false) as TurnManager
            
    if tm and tm.registered_companions.size() >= max_comp:
        return {"success": false, "reason": "Squad capacity full! (Max %d based on Charisma)" % max_comp}
        
    var chance = calculate_tame_chance(player, target_enemy, floor_num)
    
    # Train Beast Mastery skill
    var p_skills = player.get_node_or_null("SkillComponent") as SkillComponent
    if not p_skills:
        for child in player.get_children():
            if child is SkillComponent:
                p_skills = child
                break
    var l_enemy = 10.0 + (float(floor_num) * 4.0)
    if p_skills and attrs:
        p_skills.train_skill(SkillData.SkillId.BEAST_MASTERY, l_enemy, attrs)
        
    var roll = force_roll if force_roll >= 0.0 else randf()
    var e_name = target_enemy.get("enemy_name") if "enemy_name" in target_enemy else target_enemy.name
    var bus = _get_event_bus()
    
    if roll <= chance:
        # Success: convert enemy into companion
        var grid: DungeonGrid = null
        if "grid" in player and player.grid:
            grid = player.grid
        elif target_enemy.get("grid"):
            grid = target_enemy.grid
            
        var comp_pos: Vector2i = target_enemy.get("grid_pos") if ("grid_pos" in target_enemy) else Vector2i.ZERO
        var comp_data = CompanionData.create_tamed_beast_from_enemy(target_enemy, floor_num)
        
        if tm:
            tm.unregister_enemy(target_enemy)
        if grid:
            grid.unregister_entity(target_enemy, comp_pos)
            
        var CompanionScript = load("res://scripts/entities/Companion.gd")
        var companion = CompanionScript.new()
        if target_enemy.get_parent():
            target_enemy.get_parent().add_child(companion)
        elif player.get_parent():
            player.get_parent().add_child(companion)
            
        companion.setup(comp_data, player, tm, grid, comp_pos)
        
        if bus:
            bus.emit_signal("floating_text_requested", "Tamed!", Color(0.2, 0.9, 0.3), target_enemy.global_position)
            
        target_enemy.queue_free()
        
        return {
            "success": true,
            "chance": chance,
            "companion": companion,
            "message": "Successfully tamed %s! It joins your squad." % e_name
        }
    else:
        if bus:
            bus.emit_signal("floating_text_requested", "Resisted!", Color(0.9, 0.3, 0.2), target_enemy.global_position)
        return {
            "success": false,
            "chance": chance,
            "message": "Taming failed! %s resists your bond." % e_name
        }


