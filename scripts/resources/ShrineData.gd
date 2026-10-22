class_name ShrineData
extends Resource

## ShrineData: Defines deity lore, blessing buffs, taboo penalties, and apostasy temperaments.

enum ApostasyTemperament {
	JEALOUS_UNFORGIVING, # 50-turn Wrath/Shadow Mark; permanent cross-run refusal in MetaProfileData
	VENGEFUL_GRUDGE,     # 40-turn Mind Fog/Fading Grace; refuses re-entry this run
	INDIFFERENT          # Zero penalty on switch; welcomes player back anytime
}

@export var deity_id: String = ""
@export var deity_name: String = ""
@export var title: String = ""
@export_multiline var lore_description: String = ""
@export var altar_glow_color: Color = Color.GOLD

@export_group("Blessing")
@export var blessing_name: String = ""
@export_multiline var blessing_description: String = ""
@export var blessing_modifiers: Dictionary = {} 

@export_group("Taboo / Curse")
@export var taboo_name: String = ""
@export_multiline var taboo_description: String = ""
@export var taboo_modifiers: Dictionary = {}
@export var special_taboo_flags: Array[String] = [] 

@export_group("Apostasy")
@export var apostasy_temperament: ApostasyTemperament = ApostasyTemperament.INDIFFERENT
@export var apostasy_debuff_name: String = ""
@export var apostasy_debuff_turns: int = 0
@export var apostasy_debuff_description: String = ""

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

static func get_pantheon_deities() -> Array[String]:
	return ["valthor", "ouros", "solaria", "tyche", "malakar", "sylvana"]

static func create_by_deity_id(id: String) -> ShrineData:
	match id.to_lower():
		"valthor": return create_valthor()
		"ouros": return create_ouros()
		"solaria": return create_solaria()
		"tyche": return create_tyche()
		"malakar": return create_malakar()
		"sylvana": return create_sylvana()
		_: return create_valthor()

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
	shrine.apostasy_temperament = ApostasyTemperament.JEALOUS_UNFORGIVING
	shrine.apostasy_debuff_name = "Wrath of the Conqueror"
	shrine.apostasy_debuff_turns = 50
	shrine.apostasy_debuff_description = "-25% Physical Damage and -25% Physical Armor soak."
	return shrine

## 2. Ouros, Sage of the Arcane (God of Knowledge)
static func create_ouros() -> ShrineData:
	var shrine = ShrineData.new()
	shrine.deity_id = "ouros"
	shrine.deity_name = "Ouros"
	shrine.title = "Sage of the Arcane"
	shrine.lore_description = "Sage of unfettered planar intellect and mana weave manipulation."
	shrine.altar_glow_color = Color(0.2, 0.55, 1.0)
	
	shrine.blessing_name = "Weave Attunement"
	shrine.blessing_description = "+35% Skill XP Gain Rate, +25% Spell Potency, +30 Max Mana."
	shrine.blessing_modifiers = {
		"skill_xp_pct": 0.35,
		"spell_potency_pct": 0.25,
		"max_mana_add": 30.0,
		"mana_cost_pct": -0.25
	}
	
	shrine.taboo_name = "Martial Atrophy"
	shrine.taboo_description = "-30% Melee physical attack damage, -15 max stones carrying capacity."
	shrine.taboo_modifiers = {
		"melee_damage_pct": -0.30,
		"max_carry_stones_add": -15.0
	}
	shrine.apostasy_temperament = ApostasyTemperament.VENGEFUL_GRUDGE
	shrine.apostasy_debuff_name = "Mind Fog"
	shrine.apostasy_debuff_turns = 40
	shrine.apostasy_debuff_description = "-30% Skill XP gain rate and Mana Regeneration."
	return shrine

## 3. Solaria, Goddess of Positive Energy
static func create_solaria() -> ShrineData:
	var shrine = ShrineData.new()
	shrine.deity_id = "solaria"
	shrine.deity_name = "Solaria"
	shrine.title = "Goddess of Positive Energy"
	shrine.lore_description = "Goddess of radiant celestial dawn, boundless healing grace, and purging luminescence."
	shrine.altar_glow_color = Color(1.0, 0.95, 0.6)
	
	shrine.blessing_name = "Dawn's Embrace"
	shrine.blessing_description = "+45% All Healing Restored/Received, +3 HP Regen/turn, +25% vs Undead."
	shrine.blessing_modifiers = {
		"healing_pct": 0.45,
		"hp_regen_turn": 3.0,
		"damage_vs_undead_pct": 0.25
	}
	
	shrine.taboo_name = "Shadow Vulnerability"
	shrine.taboo_description = "-20% Critical Strike Damage, -15% Necrotic/Poison Resistance."
	shrine.taboo_modifiers = {
		"crit_damage_pct": -0.20,
		"poison_resist_pct": -0.15
	}
	shrine.apostasy_temperament = ApostasyTemperament.VENGEFUL_GRUDGE
	shrine.apostasy_debuff_name = "Fading Grace"
	shrine.apostasy_debuff_turns = 40
	shrine.apostasy_debuff_description = "-25% Healing restored/received."
	return shrine

## 4. Tyche, Lady of Fortune
static func create_tyche() -> ShrineData:
	var shrine = ShrineData.new()
	shrine.deity_id = "tyche"
	shrine.deity_name = "Tyche"
	shrine.title = "Lady of Fortune"
	shrine.lore_description = "Goddess of luck, wealth, and razor-thin evasion."
	shrine.altar_glow_color = Color(1.0, 0.85, 0.2)
	
	shrine.blessing_name = "Golden Serendipity"
	shrine.blessing_description = "+50% Gold Found, +15% Dodge Bonus, +15% Loot Rarity."
	shrine.blessing_modifiers = {
		"gold_drop_pct": 0.50,
		"dodge_add": 15.0,
		"rarity_upgrade_chance": 0.15
	}
	
	shrine.taboo_name = "Fickle Favor"
	shrine.taboo_description = "-25% Physical Armor soak, 10% chance per turn to drop 1 gold coin."
	shrine.taboo_modifiers = {
		"armor_pct": -0.25,
		"gold_drop_chance_per_turn": 0.10
	}
	shrine.apostasy_temperament = ApostasyTemperament.INDIFFERENT
	shrine.apostasy_debuff_name = ""
	shrine.apostasy_debuff_turns = 0
	shrine.apostasy_debuff_description = ""
	return shrine

## 5. Malakar, Lord of Shadows
static func create_malakar() -> ShrineData:
	var shrine = ShrineData.new()
	shrine.deity_id = "malakar"
	shrine.deity_name = "Malakar"
	shrine.title = "Lord of Shadows"
	shrine.lore_description = "God of deception, assassination, and unseen movements."
	shrine.altar_glow_color = Color(0.45, 0.1, 0.75)
	
	shrine.blessing_name = "Shrouded Step"
	shrine.blessing_description = "+40 Stealth, +100% Backstab Multi, +20% Poison/Bleed Dmg."
	shrine.blessing_modifiers = {
		"stealth_add": 40.0,
		"backstab_multiplier": 1.0,
		"poison_bleed_damage_pct": 0.20,
		"los_track_decay": 1.0
	}
	
	shrine.taboo_name = "Sunless Frailty"
	shrine.taboo_description = "-35% Healing Received, Disallows Heavy Plate Armor."
	shrine.taboo_modifiers = {
		"heal_received_pct": -0.35
	}
	var flags: Array[String] = ["disallow_heavy_armor"]
	shrine.special_taboo_flags = flags
	shrine.apostasy_temperament = ApostasyTemperament.JEALOUS_UNFORGIVING
	shrine.apostasy_debuff_name = "Shadow Mark"
	shrine.apostasy_debuff_turns = 50
	shrine.apostasy_debuff_description = "+25% extra Damage Taken from all sources."
	return shrine

## 6. Sylvana, Goddess of Nature & Alchemy
static func create_sylvana() -> ShrineData:
	var shrine = ShrineData.new()
	shrine.deity_id = "sylvana"
	shrine.deity_name = "Sylvana"
	shrine.title = "Goddess of Nature & Alchemy"
	shrine.lore_description = "Wild mother of untamed forests, root-woven vitality, and herbal alchemical transmutations."
	shrine.altar_glow_color = Color(0.2, 0.9, 0.4)
	
	shrine.blessing_name = "Verdant Synthesis"
	shrine.blessing_description = "+35% Alchemy & Bandage Potency, +20 Alchemy & Disable Device skills."
	shrine.blessing_modifiers = {
		"alchemy_potency_pct": 0.35,
		"skill_alchemy_add": 20.0,
		"skill_disable_device_add": 20.0
	}
	
	shrine.taboo_name = "Blighted Flame"
	shrine.taboo_description = "-20% Arcane Spell Damage, -15% Fire Resistance."
	shrine.taboo_modifiers = {
		"arcane_damage_pct": -0.20,
		"fire_resist_pct": -0.15
	}
	shrine.apostasy_temperament = ApostasyTemperament.INDIFFERENT
	shrine.apostasy_debuff_name = ""
	shrine.apostasy_debuff_turns = 0
	shrine.apostasy_debuff_description = ""
	return shrine
