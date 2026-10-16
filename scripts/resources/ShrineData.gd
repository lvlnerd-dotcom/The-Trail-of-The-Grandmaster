class_name ShrineData
extends Resource

## ShrineData: Defines deity lore, blessing buffs, and taboo penalties.

@export var deity_id: String = ""
@export var deity_name: String = ""
@export var title: String = ""
@export_multiline var lore_description: String = ""
@export var altar_glow_color: Color = Color.GOLD

@export_group("Blessing")
@export var blessing_name: String = ""
@export_multiline var blessing_description: String = ""
@export var blessing_modifiers: Dictionary = {} 
# e.g., {"physical_damage_pct": 0.30, "melee_damage_pct": 0.30, "crit_chance_add": 0.10}

@export_group("Taboo / Curse")
@export var taboo_name: String = ""
@export_multiline var taboo_description: String = ""
@export var taboo_modifiers: Dictionary = {}
# e.g., {"max_hp_pct": -0.20, "ranged_damage_taken_pct": 0.15}
@export var special_taboo_flags: Array[String] = [] 
# e.g., ["disallow_heavy_armor", "gold_drop_on_step"]

func get_scaled_blessing(bonus_mult: float) -> Dictionary:
	var scaled: Dictionary = {}
	for k in blessing_modifiers.keys():
		var val = blessing_modifiers[k]
		if val is float:
			scaled[k] = val * bonus_mult
		elif val is int:
			scaled[k] = int(round(float(val) * bonus_mult))
		else:
			scaled[k] = val
	return scaled

func get_scaled_taboo(penalty_mult: float) -> Dictionary:
	var scaled: Dictionary = {}
	for k in taboo_modifiers.keys():
		var val = taboo_modifiers[k]
		if val is float:
			scaled[k] = val * penalty_mult
		elif val is int:
			scaled[k] = int(round(float(val) * penalty_mult))
		else:
			scaled[k] = val
	return scaled

func get_effective_blessing_modifier(stat_key: String, attrs: AttributesData) -> float:
	var bonus_mult = 1.0
	if attrs:
		var mults = attrs.get_shrine_multipliers()
		bonus_mult = mults["bonus_mult"]
	return float(blessing_modifiers.get(stat_key, 0.0)) * bonus_mult

func get_effective_taboo_modifier(stat_key: String, attrs: AttributesData) -> float:
	var penalty_mult = 1.0
	if attrs:
		var mults = attrs.get_shrine_multipliers()
		penalty_mult = mults["penalty_mult"]
	return float(taboo_modifiers.get(stat_key, 0.0)) * penalty_mult

# --- Pantheon Factory Constructors ---

## 1. Valthor, The Iron Conqueror (God of War)
static func create_valthor() -> ShrineData:
	var shrine = ShrineData.new()
	shrine.deity_id = "valthor"
	shrine.deity_name = "Valthor"
	shrine.title = "The Iron Conqueror"
	shrine.lore_description = "God of war, direct martial domination, and relentless brutality."
	shrine.altar_glow_color = Color(0.95, 0.15, 0.15)
	
	shrine.blessing_name = "Blood of the Conqueror"
	shrine.blessing_description = "+30% Melee and Ranged Physical Damage, +10% Critical Strike Chance."
	shrine.blessing_modifiers = {
		"physical_damage_pct": 0.30,
		"melee_damage_pct": 0.30,
		"ranged_damage_pct": 0.30,
		"crit_chance_add": 0.10
	}
	
	shrine.taboo_name = "Pacifist's Torment"
	shrine.taboo_description = "-20% Max HP, +15% extra damage taken from ranged projectiles."
	shrine.taboo_modifiers = {
		"max_hp_pct": -0.20,
		"ranged_damage_taken_pct": 0.15
	}
	return shrine

## 2. Tyche, Lady of Fortune
static func create_tyche() -> ShrineData:
	var shrine = ShrineData.new()
	shrine.deity_id = "tyche"
	shrine.deity_name = "Tyche"
	shrine.title = "Lady of Fortune"
	shrine.lore_description = "Goddess of luck, wealth, and razor-thin evasion."
	shrine.altar_glow_color = Color(1.0, 0.85, 0.2)
	
	shrine.blessing_name = "Golden Serendipity"
	shrine.blessing_description = "+50% Gold drop quantity, +25% Dodge rating, +15% magic item rarity upgrade."
	shrine.blessing_modifiers = {
		"gold_drop_pct": 0.50,
		"dodge_add": 25.0,
		"rarity_upgrade_chance": 0.15
	}
	
	shrine.taboo_name = "Fickle Favor"
	shrine.taboo_description = "-25% Physical Armor soak, 10% chance per turn to drop 1 gold coin."
	shrine.taboo_modifiers = {
		"armor_pct": -0.25,
		"gold_drop_chance_per_turn": 0.10
	}
	return shrine

## 3. Malakar, Lord of Shadows
static func create_malakar() -> ShrineData:
	var shrine = ShrineData.new()
	shrine.deity_id = "malakar"
	shrine.deity_name = "Malakar"
	shrine.title = "Lord of Shadows"
	shrine.lore_description = "God of deception, assassination, and unseen movements."
	shrine.altar_glow_color = Color(0.45, 0.1, 0.75)
	
	shrine.blessing_name = "Shrouded Step"
	shrine.blessing_description = "+40.0 Stealth/Hide skill, +100% Backstab damage multiplier, faster LOS decay."
	shrine.blessing_modifiers = {
		"stealth_add": 40.0,
		"backstab_multiplier": 1.0,
		"los_track_decay": 1.0
	}
	
	shrine.taboo_name = "Sunless Frailty"
	shrine.taboo_description = "-35% Healing received from spells and potions, disallows equipping Heavy Armor."
	shrine.taboo_modifiers = {
		"heal_received_pct": -0.35
	}
	shrine.special_taboo_flags = ["disallow_heavy_armor"]
	return shrine

## 4. Ouros, Sage of the Arcane
static func create_ouros() -> ShrineData:
	var shrine = ShrineData.new()
	shrine.deity_id = "ouros"
	shrine.deity_name = "Ouros"
	shrine.title = "Sage of the Arcane"
	shrine.lore_description = "Sage of unfettered planar intellect and mana weave manipulation."
	shrine.altar_glow_color = Color(0.2, 0.55, 1.0)
	
	shrine.blessing_name = "Weave Attunement"
	shrine.blessing_description = "+30 Max Mana, -25% Mana cost on all spells, +25% Spell Potency."
	shrine.blessing_modifiers = {
		"max_mana_add": 30.0,
		"mana_cost_pct": -0.25,
		"spell_potency_pct": 0.25
	}
	
	shrine.taboo_name = "Martial Atrophy"
	shrine.taboo_description = "-30% Melee physical attack damage, -15 max stones carrying capacity."
	shrine.taboo_modifiers = {
		"melee_damage_pct": -0.30,
		"max_carry_stones_add": -15.0
	}
	return shrine
