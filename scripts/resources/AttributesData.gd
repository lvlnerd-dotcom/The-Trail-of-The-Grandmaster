class_name AttributesData
extends Resource

## AttributesData: Pure Godot 4 Resource defining core attributes and mathematical scaling.

signal attribute_changed(attr_name: String, new_val: int)
signal leveled_up(new_level: int, unallocated_points: int)
signal exp_gained(amount: int, current_exp: int, required_exp: int)

enum WeaponType {
	NONE,
	MELEE,
	THROWN,
	SLING,
	HIGH_TENSION_BOW,
	BOW,
	FIREARM,
	MAGIC_FOCUS
}

@export_range(1, 100) var strength: int = 1:
	set(value):
		strength = value
		emit_signal("attribute_changed", "strength", strength)

@export_range(1, 100) var dexterity: int = 1:
	set(value):
		dexterity = value
		emit_signal("attribute_changed", "dexterity", dexterity)

@export_range(1, 100) var constitution: int = 1:
	set(value):
		constitution = value
		emit_signal("attribute_changed", "constitution", constitution)

@export_range(1, 100) var intelligence: int = 1:
	set(value):
		intelligence = value
		emit_signal("attribute_changed", "intelligence", intelligence)

@export_range(1, 100) var wisdom: int = 1:
	set(value):
		wisdom = value
		emit_signal("attribute_changed", "wisdom", wisdom)

@export_range(1, 100) var charisma: int = 1:
	set(value):
		charisma = value
		emit_signal("attribute_changed", "charisma", charisma)

# Character Level & Combat Kill EXP
@export var character_level: int = 1
@export var current_exp: int = 0
@export var unallocated_attribute_points: int = 0

const BASE_HP: float = 100.0
const BASE_MANA: float = 50.0
const STONES_PER_STR: float = 10.0
const BASE_EXP_REQUIREMENT: float = 100.0
const EXP_EXPONENT: float = 1.5
const POINTS_PER_LEVEL: int = 2

# --- Strength Scaling ---
func get_melee_damage_modifier() -> float:
	# 10 STR = 1.0 (100%), +25% per 10 points (+2.5% per point)
	return 1.0 + (strength - 10) * 0.025

func get_ranged_damage_modifier(weapon_type: WeaponType) -> float:
	var full_str_bonus = (strength - 10) * 0.025
	match weapon_type:
		WeaponType.THROWN, WeaponType.SLING:
			return 1.0 + full_str_bonus
		WeaponType.HIGH_TENSION_BOW:
			return 1.0 + (full_str_bonus * 0.5)
		_:
			return 1.0 # Firearms and standard bows receive no STR damage bonus

func get_max_carry_weight_stones() -> float:
	# 100 Stones at 10 STR, 10 Stones per Strength scaling infinitely
	return strength * STONES_PER_STR

# --- Dexterity Scaling ---
func get_critical_chance() -> float:
	# 1.5% chance to critical hit per point of Dexterity
	return dexterity * 0.015

func get_critical_strike_chance() -> float:
	return get_critical_chance()

func evaluate_critical_multiplier() -> float:
	# Double damage (2.0x) on first crit.
	# When chance > 100%, the extra % is rolled on a second check for another 2x (4.0x total).
	var crit_chance = get_critical_chance()
	if crit_chance <= 0.0:
		return 1.0
	
	var roll_first = randf()
	if roll_first < min(1.0, crit_chance):
		var multiplier = 2.0
		if crit_chance > 1.0:
			var excess_chance = crit_chance - 1.0
			var roll_second = randf()
			if roll_second < excess_chance:
				multiplier = 4.0
		return multiplier
	return 1.0

# --- Constitution Scaling ---
func get_max_health() -> float:
	# 10 CON = 100% Base HP (100.0), +2.5% per point above/below 10
	var mult = 1.0 + (constitution - 10) * 0.025
	return max(10.0, BASE_HP * mult)

func get_health_regen_modifier() -> float:
	# 10 CON = 100% baseline, +2.5% per point above 10
	return 1.0 + (constitution - 10) * 0.025

func get_physical_status_resistance() -> float:
	# Reduces duration/potency of Poison, Bleed, Stun, Paralyze
	# Each point of CON grants 1.5% resistance
	return clampf(constitution * 0.015, 0.0, 0.85)

# --- Intelligence Scaling ---
func get_skill_xp_multiplier() -> float:
	# No penalty under 10 INT, but +2.5% per point above 10
	if intelligence <= 10:
		return 1.0
	return 1.0 + (intelligence - 10) * 0.025

func get_max_mana() -> float:
	# 10 INT = 100% Base Mana (50.0), +2.5% per point
	var mult = 1.0 + (intelligence - 10) * 0.025
	return max(0.0, BASE_MANA * mult)

func get_mana_regen_modifier() -> float:
	return 1.0 + (intelligence - 10) * 0.025

# --- Wisdom Scaling ---
func get_shrine_multipliers() -> Dictionary:
	# 10 WIS = 100% standard buffs and 100% penalties.
	# Below 10 WIS: each point below makes penalties 10% worse and buffs 10% less effective.
	# Above 10 WIS: +2.5% buffs per point, -2.5% penalties per point (0% penalty at 50 WIS).
	var bonus_mult: float
	var penalty_mult: float
	
	if wisdom < 10:
		var deficit = 10 - wisdom # 1 to 9 (or >= 10 if wisdom <= 0)
		bonus_mult = maxf(0.0, 1.0 - (deficit * 0.10))
		penalty_mult = 1.0 + (deficit * 0.10)
	else:
		var excess = wisdom - 10
		bonus_mult = 1.0 + (excess * 0.025)
		penalty_mult = maxf(0.0, 1.0 - (excess * 0.025))
		
	return { "bonus_mult": bonus_mult, "penalty_mult": penalty_mult }

func get_psychic_status_resistance() -> float:
	# Primary defense against mental attacks: Confuse, Mind Control, Terror, Charm
	return clampf(wisdom * 0.015, 0.0, 0.85)

# --- Charisma Scaling ---
func get_companion_stat_modifier() -> float:
	# Scales companion & pet base HP and Attack Damage: 10 CHA = 1.0, +2.5% per point
	return maxf(0.0, 1.0 + (charisma - 10) * 0.025)

func get_mercantile_modifier() -> float:
	# 10 CHA = 1.0 (100%), +1% price favor per point of Charisma (100 CHA = 1.90 / 190%)
	return maxf(0.01, 1.0 + (charisma - 10) * 0.01)

func get_intimidation_difficulty_class() -> int:
	return 50 + charisma + (character_level * 2)

# --- Leveling & EXP ---
func get_exp_required_for_next_level() -> int:
	return int(BASE_EXP_REQUIREMENT * pow(character_level, EXP_EXPONENT))

func add_kill_exp(amount: int) -> bool:
	current_exp += amount
	emit_signal("exp_gained", amount, current_exp, get_exp_required_for_next_level())
	
	var leveled_up_flag: bool = false
	while current_exp >= get_exp_required_for_next_level():
		current_exp -= get_exp_required_for_next_level()
		character_level += 1
		unallocated_attribute_points += POINTS_PER_LEVEL
		leveled_up_flag = true
		emit_signal("leveled_up", character_level, unallocated_attribute_points)
	
	return leveled_up_flag

func allocate_attribute_point(attr_name: String) -> bool:
	if unallocated_attribute_points <= 0:
		return false
	match attr_name.to_lower():
		"strength":
			strength += 1
		"dexterity":
			dexterity += 1
		"constitution":
			constitution += 1
		"intelligence":
			intelligence += 1
		"wisdom":
			wisdom += 1
		"charisma":
			charisma += 1
		_:
			return false
	unallocated_attribute_points -= 1
	return true
