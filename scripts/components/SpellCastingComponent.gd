class_name SpellCastingComponent
extends Node

## SpellCastingComponent: Manages spell learning, casting checks, fizzle calculations,
## spell resolution, and Ward Shield damage absorption.

signal spell_cast_success(spell: SpellData, target_cell: Vector2i)
signal spell_cast_failed(spell: SpellData, reason: String)
signal spell_fizzled(spell: SpellData)
signal ward_absorbed(amount: int, remaining_ward: float)
signal ward_expired()

@export var known_spells: Array[SpellData] = []
@export var quick_cast_slots: Dictionary = {} # int -> SpellData

# Ward Shield tracking
@export var active_ward_hp: float = 0.0
@export var ward_duration_turns: int = 0
@export var divine_aegis_turns: int = 0

func _get_event_bus() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("EventBus")
	return null

func _get_caster() -> Node2D:
	return get_parent() as Node2D

func _get_stats() -> StatsComponent:
	var caster = _get_caster()
	if not caster:
		return null
	var stats = caster.get_node_or_null("StatsComponent") as StatsComponent
	if not stats:
		for child in caster.get_children():
			if child is StatsComponent:
				return child
	return stats

func _get_skills() -> SkillComponent:
	var caster = _get_caster()
	if not caster:
		return null
	var skills = caster.get_node_or_null("SkillComponent") as SkillComponent
	if not skills:
		for child in caster.get_children():
			if child is SkillComponent:
				return child
	return skills

func _get_caster_cell() -> Vector2i:
	var caster = _get_caster()
	if caster and "grid_pos" in caster:
		return caster.grid_pos
	return Vector2i.ZERO

# --- Spell Book & Quick-Cast Management ---

func learn_spell(spell: SpellData) -> bool:
	if not spell:
		return false
	for s in known_spells:
		if s and s.spell_id == spell.spell_id:
			return false # Already known
	known_spells.append(spell)
	var bus = _get_event_bus()
	if bus:
		bus.emit_signal("spell_learned", spell)
	return true

func assign_quick_cast(slot: int, spell: SpellData) -> void:
	if spell and known_spells.has(spell):
		quick_cast_slots[slot] = spell
	elif quick_cast_slots.has(slot):
		quick_cast_slots.erase(slot)

func get_quick_cast(slot: int) -> SpellData:
	return quick_cast_slots.get(slot, null)

# --- Mathematical Formulations strictly per GDD ---

## EffectiveSkill = SkillLevel + (AttributeValue / 2.0)
func get_effective_skill(spell: SpellData) -> float:
	if not spell:
		return 0.0
	var skills = _get_skills()
	var stats = _get_stats()
	if not skills or not stats or not stats.attributes:
		return 0.0
	
	var skill_id = spell.get_associated_skill_id()
	var attr_name = spell.get_associated_attribute_name()
	var skill = skills.get_skill(skill_id)
	var skill_level = skill.level if skill else 0.0
	var attr_val = float(_get_attribute_value(stats.attributes, attr_name))
	
	return skill_level + (attr_val * 0.5)

func calculate_effective_skill(spell: SpellData) -> float:
	return get_effective_skill(spell)

## Fizzle chance formula:
## Deficit = max(0.0, RequiredSkill - EffectiveSkill)
## FizzleChance = clampf(Deficit * 0.05, 0.0, 0.75)
func calculate_fizzle_chance(spell: SpellData) -> float:
	if not spell:
		return 1.0
	var effective_skill = get_effective_skill(spell)
	var deficit = maxf(0.0, spell.required_skill_level - effective_skill)
	return clampf(deficit * 0.05, 0.0, 0.75)

## PowerMultiplier = 1.0 + (EffectiveSkill * 0.01) + (AttributeValue - 10) * 0.025
## ScaledBase = BaseValue * PowerMultiplier
func calculate_spell_potency(spell: SpellData, target: Node2D = null) -> Dictionary:
	if not spell:
		return {"power_multiplier": 1.0, "scaled_base": 0.0, "is_undead": false}
		
	var stats = _get_stats()
	var attr_name = spell.get_associated_attribute_name()
	var attr_val = _get_attribute_value(stats.attributes, attr_name) if (stats and stats.attributes) else 10
	var effective_skill = get_effective_skill(spell)
	
	var power_mult = 1.0 + (effective_skill * 0.01) + (float(attr_val - 10) * 0.025)
	
	# Check Ouros shrine blessing bonus (+25% spell potency)
	var caster = _get_caster()
	if caster:
		var covenant = caster.get("active_shrine_covenant") if "active_shrine_covenant" in caster else caster.get_meta("active_shrine_covenant", {})
		if covenant is Dictionary and covenant.has("blessing_modifiers"):
			var mods = covenant["blessing_modifiers"]
			if mods.has("spell_potency_pct"):
				power_mult += float(mods["spell_potency_pct"])
				
	var scaled_base = spell.base_potency * power_mult
	
	var is_undead: bool = false
	if target:
		var u_val = target.get("is_undead")
		if u_val != null and bool(u_val):
			is_undead = true
		elif target.has_meta("is_undead") and bool(target.get_meta("is_undead")):
			is_undead = true
		elif "is_undead_or_evil" in target and bool(target.get("is_undead_or_evil")):
			is_undead = true
			
		if is_undead and spell.damage_type == SpellData.DamageType.RADIANT:
			scaled_base *= spell.bonus_vs_undead_mult
			
	return {
		"power_multiplier": power_mult,
		"scaled_base": scaled_base,
		"is_undead": is_undead
	}

func calculate_potency(spell: SpellData) -> int:
	var info = calculate_spell_potency(spell)
	if spell and spell.base_potency <= 0.0:
		return 0
	return maxi(1, int(round(info["scaled_base"])))

func _get_mana_cost(spell: SpellData) -> float:
	var cost = spell.mana_cost
	var caster = _get_caster()
	if caster:
		var covenant = caster.get("active_shrine_covenant") if "active_shrine_covenant" in caster else caster.get_meta("active_shrine_covenant", {})
		if covenant is Dictionary and covenant.has("blessing_modifiers"):
			var mods = covenant["blessing_modifiers"]
			if mods.has("mana_cost_pct"):
				cost *= (1.0 + float(mods["mana_cost_pct"]))
	return maxf(1.0, cost)

# --- Casting Validation & Execution ---

func can_cast(spell: SpellData, target_cell: Vector2i, grid: DungeonGrid = null) -> Dictionary:
	if not spell:
		return {"can_cast": false, "reason": "No spell selected"}
		
	var stats = _get_stats()
	if not stats:
		return {"can_cast": false, "reason": "Caster has no stats"}
		
	var actual_cost = _get_mana_cost(spell)
	if stats.current_mana < actual_cost:
		return {"can_cast": false, "reason": "INSUFFICIENT_MANA"}
		
	var caster_cell = _get_caster_cell()
	var dist = maxi(abs(target_cell.x - caster_cell.x), abs(target_cell.y - caster_cell.y))
	
	if spell.target_type == SpellData.TargetType.SELF:
		if target_cell != caster_cell and dist != 0:
			return {"can_cast": false, "reason": "Self-cast spell must target caster's cell"}
	else:
		if dist > spell.range_tiles:
			return {"can_cast": false, "reason": "Target cell out of range"}
			
		# Line of Sight validation
		if grid:
			var los_cells = VisionComponent.get_line_cells(caster_cell, target_cell)
			for i in range(1, los_cells.size() - 1):
				var check_pt = los_cells[i]
				if grid.wall_cells.has(check_pt):
					return {"can_cast": false, "reason": "Line of sight blocked!"}
					
	# Teleportation destination check
	if spell.effect_type == SpellData.EffectType.TELEPORT:
		if grid:
			if not grid.can_enter(target_cell):
				return {"can_cast": false, "reason": "Destination cell is blocked or occupied"}
				
	return {"can_cast": true, "reason": ""}

func cast_spell(spell: SpellData, target_cell: Vector2i, grid: DungeonGrid = null, force_roll: float = -1.0) -> Dictionary:
	var check = can_cast(spell, target_cell, grid)
	if not check["can_cast"]:
		emit_signal("spell_cast_failed", spell, check["reason"])
		return {"success": false, "fizzled": false, "mana_spent": 0.0, "reason": check["reason"]}
		
	var stats = _get_stats()
	var skills = _get_skills()
	var caster = _get_caster()
	var bus = _get_event_bus()
	var actual_cost = _get_mana_cost(spell)
	
	# Fizzle evaluation
	var fizzle_chance = calculate_fizzle_chance(spell)
	var roll = force_roll if force_roll >= 0.0 else randf()
	if roll < fizzle_chance:
		# On Fizzle: spend half mana, expend turn, emit signal
		var spent = actual_cost * 0.5
		stats.spend_mana(spent)
		emit_signal("spell_fizzled", spell)
		if bus:
			bus.emit_signal("spell_fizzled", spell, caster)
		return {"success": false, "fizzled": true, "mana_spent": spent, "reason": "Spell fizzled!"}
		
	# Successful Cast: Deduct full mana
	stats.spend_mana(actual_cost)
	
	# Train skill in SkillComponent
	if skills and stats and stats.attributes:
		var skill_id = spell.get_associated_skill_id()
		skills.train_skill(skill_id, spell.required_skill_level, stats.attributes)
		
	var potency = calculate_potency(spell)
	var targets_hit: Array[Node2D] = []
	var caster_cell = _get_caster_cell()
	var effective_cell = target_cell
	var was_intercepted = false
	var lof_data: Dictionary = {}

	if grid and spell.target_type != SpellData.TargetType.SELF:
		lof_data = TargetingSystem.calculate_line_of_fire(
			caster_cell,
			target_cell,
			grid,
			spell.range_tiles,
			spell.area_radius,
			spell.target_type == SpellData.TargetType.BEAM,
			spell.effect_type == SpellData.EffectType.TELEPORT,
			caster
		)
		effective_cell = lof_data.get("effective_target_cell", target_cell)
		was_intercepted = (int(lof_data.get("blocker_type", 0)) == TargetingSystem.BlockerType.ENTITY)
	
	match spell.effect_type:
		SpellData.EffectType.DAMAGE:
			var candidate_cells: Array[Vector2i] = []
			if spell.target_type == SpellData.TargetType.BEAM and not lof_data.is_empty():
				for c in lof_data.get("clear_cells", []):
					candidate_cells.append(c as Vector2i)
			elif spell.target_type == SpellData.TargetType.AREA_EFFECT and spell.area_radius > 0:
				for dx in range(-spell.area_radius, spell.area_radius + 1):
					for dy in range(-spell.area_radius, spell.area_radius + 1):
						var blast_pt = effective_cell + Vector2i(dx, dy)
						if not grid or not grid.wall_cells.has(blast_pt):
							candidate_cells.append(blast_pt)
			else:
				candidate_cells.append(effective_cell)
				
			for cell in candidate_cells:
				var occupant: Node2D = null
				if grid:
					occupant = grid.get_occupant(cell)
				elif caster and caster.get_parent():
					for child in caster.get_parent().get_children():
						if child != caster and "grid_pos" in child and child.grid_pos == cell:
							occupant = child
							break
							
				if occupant and occupant != caster and is_instance_valid(occupant):
					var target_stats = occupant.get_node_or_null("StatsComponent") as StatsComponent
					if target_stats or occupant.has_method("take_damage"):
						targets_hit.append(occupant)
						
						# Critical Hit Resolution (Arcane)
						var is_crit = false
						var final_damage = float(potency)
						if spell.school == SpellData.School.ARCANE and stats.attributes:
							var crit_mult = stats.attributes.evaluate_critical_multiplier()
							if crit_mult > 1.0:
								is_crit = true
								final_damage *= crit_mult
								
						# Radiant holy strike vs Undead/Demonic
						if spell.damage_type == SpellData.DamageType.RADIANT:
							var is_und = occupant.get("is_undead") or occupant.has_meta("is_undead") or occupant.get("is_undead_or_evil")
							if is_und:
								final_damage *= spell.bonus_vs_undead_mult
								
						# Armor soak & penetration
						var target_armor = 0
						if occupant.has_method("get_total_armor"):
							target_armor = occupant.get_total_armor()
						elif "armor" in occupant:
							target_armor = occupant.armor
						elif occupant.has_node("InventoryComponent"):
							target_armor = occupant.get_node("InventoryComponent").get_total_armor()
							
						var effective_armor = float(target_armor) * (1.0 - spell.armor_penetration)
						var actual_damage = maxi(1, int(round(final_damage - effective_armor)))
						
						if occupant.has_method("take_damage"):
							occupant.take_damage(actual_damage, caster)
						elif target_stats:
							target_stats.take_damage(actual_damage, caster)
							
						if bus:
							bus.emit_signal("spell_hit", spell, occupant, actual_damage, is_crit)
							
		SpellData.EffectType.HEALING:
			var heal_target: Node2D = caster
			if effective_cell != caster_cell and grid:
				var occ = grid.get_occupant(effective_cell)
				if occ:
					heal_target = occ
					
			if heal_target:
				var target_stats = heal_target.get_node_or_null("StatsComponent") as StatsComponent
				if target_stats:
					target_stats.heal(float(potency))
				elif heal_target.has_method("heal"):
					heal_target.heal(float(potency))
				targets_hit.append(heal_target)
				if bus:
					bus.emit_signal("spell_hit", spell, heal_target, potency, false)
					
		SpellData.EffectType.WARD_SHIELD:
			active_ward_hp += float(potency)
			ward_duration_turns = spell.duration_turns
			if spell.spell_id == "divine_aegis":
				divine_aegis_turns = spell.duration_turns
			targets_hit.append(caster)
			if bus:
				bus.emit_signal("spell_hit", spell, caster, potency, false)
				
		SpellData.EffectType.TELEPORT:
			if grid and caster:
				var from_cell = _get_caster_cell()
				grid.move_entity(caster, from_cell, effective_cell)
				caster.grid_pos = effective_cell
				caster.global_position = grid.grid_to_world(effective_cell)
			targets_hit.append(caster)
			
		SpellData.EffectType.STATUS_CLEANSE:
			var cleanse_target: Node2D = caster
			if effective_cell != caster_cell and grid:
				var occ = grid.get_occupant(effective_cell)
				if occ:
					cleanse_target = occ
			targets_hit.append(cleanse_target)
			if bus:
				bus.emit_signal("spell_hit", spell, cleanse_target, 0, false)
				
	emit_signal("spell_cast_success", spell, effective_cell)
	if bus:
		bus.emit_signal("spell_cast", spell, caster, effective_cell)
		
	return {
		"success": true,
		"fizzled": false,
		"mana_spent": actual_cost,
		"potency": potency,
		"targets_hit": targets_hit,
		"effective_target_cell": effective_cell,
		"intercepted": was_intercepted,
		"effect": spell.effect_type
	}


# --- Ward Shield Mechanics ---

func absorb_damage(incoming_damage: int) -> int:
	if active_ward_hp <= 0.0:
		return incoming_damage
		
	var to_absorb = mini(incoming_damage, int(ceil(active_ward_hp)))
	active_ward_hp = maxf(0.0, active_ward_hp - float(to_absorb))
	emit_signal("ward_absorbed", to_absorb, active_ward_hp)
	
	if active_ward_hp <= 0.0:
		ward_duration_turns = 0
		emit_signal("ward_expired")
		
	return incoming_damage - to_absorb

func tick_ward_turns() -> void:
	if ward_duration_turns > 0:
		ward_duration_turns -= 1
		if ward_duration_turns <= 0 and active_ward_hp > 0.0:
			active_ward_hp = 0.0
			emit_signal("ward_expired")
			
	if divine_aegis_turns > 0:
		divine_aegis_turns -= 1

func _get_attribute_value(attributes: AttributesData, attr_name: String) -> int:
	match attr_name.to_lower():
		"strength": return attributes.strength
		"dexterity": return attributes.dexterity
		"constitution": return attributes.constitution
		"intelligence": return attributes.intelligence
		"wisdom": return attributes.wisdom
		"charisma": return attributes.charisma
		_: return 10
