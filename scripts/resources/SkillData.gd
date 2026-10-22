@tool
class_name SkillData
extends Resource

## SkillData: Data resource for individual use-based skills (0.0 to 100.0),
## Tri-Tier Skill Taxonomy (Starting, Meta, Class-Exclusive),
## and Level 50 Primary/Secondary Attribute Accuracy Scaling Shifts.

signal skill_level_changed(skill_id: SkillId, new_level: float)
signal keystone_reached(skill_id: SkillId, milestone: int)

enum SkillTier {
	STARTING,        ## Available at character creation from the first run (15 skills)
	META,            ## Unlocked via account rank / Meta EXP; added to starting pool (5 skills)
	CLASS_EXCLUSIVE  ## Unlocked exclusively upon Floor 2 Class Specialization (21 skills)
}

enum SkillId {
	# Tier 1: Starting Skills (15 skills, including all 7 Combat Weapon Skills)
	SWORDSMANSHIP = 0,
	BLUNT_WEAPON_FIGHTING = 1,
	MACE_FIGHTING = 1,          ## Alias for BLUNT_WEAPON_FIGHTING for backward compatibility
	POLEARMS = 2,
	BRAWLING = 3,
	ARCHERY = 4,
	THROWING = 5,
	DODGE = 6,
	PARRY = 7,
	STEALTH_HIDE = 8,
	ARCANE_MAGIC = 9,
	ALCHEMY = 10,
	SCHOLARSHIP = 11,
	DIVINE_MAGIC = 12,
	PERCEPTION = 13,
	
	# Tier 2: Meta Skills (5)
	MEDITATION = 14,
	BEAST_MASTERY = 15,
	INTIMIDATION = 16,
	LEADERSHIP = 17,
	SURVIVALISM = 18,
	
	# Tier 3: Class-Exclusive Skills (21)
	SHIELD_FORTIFICATION = 19,
	PAIN_HARNESSING = 20,
	RIPOSTE_FINESSE = 21,
	WEAPON_SYNTHESIS = 22,
	ASSASSINATION = 23,
	BALLISTICS = 24,
	GUN_KATA = 25,
	UMBRAL_PHASING = 26,
	PYROMANCY = 27,
	SPELL_FORGING = 28,
	TEMPORAL_WARPING = 29,
	NECROMANTIC_SIPHON = 30,
	HOLY_SMITING = 31,
	SACRED_BULWARK = 32,
	WITCH_PURGING = 33,
	DIVINE_MIRACLES = 34,
	ASTRAL_BLADE = 35,
	TOXICOLOGY = 36,
	KI_STRIKES = 37,
	GRANDMASTER_SYNTHESIS = 38,
	IMPROVISED_SURVIVAL = 39,
	
	# Legacy / Deprecated
	MARKSMANSHIP = 40,
	
	# Tier 1: Finesse Weapon Fighting (Added without shifting existing enum ordinals)
	FINESSE_WEAPON_FIGHTING = 41,
	
	# Tier 1: Living Dungeon Ecosystem & Economy
	LOCKPICKING = 42,
	DISABLE_DEVICE = 43,
	BARTERING = 44
}

const STEALTH: SkillId = SkillId.STEALTH_HIDE
const FINESSE: SkillId = SkillId.FINESSE_WEAPON_FIGHTING

## Level 50 Accuracy Scaling Shift Configuration for the 7 Combat Weapon Skills:
## - 00.0 to 49.9: Scales strictly off Primary Attribute (+0.5 per point).
## - 50.0 to 100.0: Unlocks Secondary Attribute (+0.5 * Primary + 0.5 * Secondary)
##   OR doubles Primary Attribute (+1.0 * Primary) if doubles_primary_at_50 is true.
const COMBAT_SKILL_SCALING: Dictionary = {
	SkillId.SWORDSMANSHIP: {
		"primary": "strength",
		"secondary": "dexterity",
		"doubles_primary_at_50": false
	},
	SkillId.BLUNT_WEAPON_FIGHTING: {
		"primary": "strength",
		"secondary": "",
		"doubles_primary_at_50": true
	},
	SkillId.FINESSE_WEAPON_FIGHTING: {
		"primary": "dexterity",
		"secondary": "",
		"doubles_primary_at_50": true
	},
	SkillId.POLEARMS: {
		"primary": "constitution",
		"secondary": "strength",
		"doubles_primary_at_50": false
	},
	SkillId.BRAWLING: {
		"primary": "strength",
		"secondary": "dexterity",
		"doubles_primary_at_50": false
	},
	SkillId.ARCHERY: {
		"primary": "dexterity",
		"secondary": "",
		"doubles_primary_at_50": true
	},
	SkillId.THROWING: {
		"primary": "dexterity",
		"secondary": "strength",
		"doubles_primary_at_50": false
	}
}

@export var skill_id: SkillId = SkillId.SWORDSMANSHIP
@export var skill_name: String = ""
@export var tier: SkillTier = SkillTier.STARTING
@export var associated_attribute_name: String = "strength" # Primary attribute ("strength", "dexterity", "constitution", etc.)
@export var secondary_attribute_name: String = ""          # Secondary attribute unlocked at Level 50.0+
@export var doubles_primary_at_50: bool = false            # True if Primary Attribute effectiveness doubles at Level 50.0+
@export var exclusive_class_id: String = ""

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

func _init(
	p_id: SkillId = SkillId.SWORDSMANSHIP,
	p_name: String = "",
	p_attr: String = "",
	p_lvl: float = 0.0
) -> void:
	skill_id = p_id
	skill_name = p_name if not p_name.is_empty() else get_skill_name(p_id)
	associated_attribute_name = p_attr if not p_attr.is_empty() else get_associated_attribute(p_id)
	secondary_attribute_name = get_secondary_attribute(p_id)
	doubles_primary_at_50 = does_skill_double_primary_at_50(p_id)
	tier = get_tier_for_skill(p_id)
	exclusive_class_id = get_exclusive_class_id(p_id)
	level = p_lvl

## Single-attribute effective level calculation (used when only primary attribute integer is passed).
## Respects Level 50 primary-doubling for single-attribute combat skills.
func get_effective_level(attribute_val: int, secondary_attr_val: int = 0) -> float:
	var pri_bonus = float(attribute_val) * 0.5
	if level >= 50.0 and COMBAT_SKILL_SCALING.has(skill_id):
		var cfg = COMBAT_SKILL_SCALING[skill_id]
		if bool(cfg["doubles_primary_at_50"]):
			return level + (float(attribute_val) * 1.0)
		elif not String(cfg["secondary"]).is_empty() and secondary_attr_val > 0:
			return level + pri_bonus + (float(secondary_attr_val) * 0.5)
	return level + pri_bonus

## Computes the attribute bonus to weapon accuracy / effective skill based on current skill level (00.0-49.9 vs 50.0+).
func get_accuracy_attribute_bonus(attributes: AttributesData) -> float:
	if not attributes:
		return 0.0
	if COMBAT_SKILL_SCALING.has(skill_id):
		var cfg = COMBAT_SKILL_SCALING[skill_id]
		var pri_val = float(_read_attribute(attributes, String(cfg["primary"])))
		var bonus = pri_val * 0.5
		if level >= 50.0:
			if bool(cfg["doubles_primary_at_50"]):
				bonus = pri_val * 1.0
			elif not String(cfg["secondary"]).is_empty():
				var sec_val = float(_read_attribute(attributes, String(cfg["secondary"])))
				bonus += sec_val * 0.5
		return bonus
	var std_val = float(_read_attribute(attributes, associated_attribute_name))
	return std_val * 0.5

## Full effective skill level evaluation incorporating the Level 50 Accuracy Scaling Shift.
func get_effective_level_with_attributes(attributes: AttributesData) -> float:
	return level + get_accuracy_attribute_bonus(attributes)

static func _read_attribute(attributes: AttributesData, attr_name: String) -> int:
	if not attributes:
		return 10
	match attr_name.to_lower():
		"strength": return attributes.strength
		"dexterity": return attributes.dexterity
		"constitution": return attributes.constitution
		"intelligence": return attributes.intelligence
		"wisdom": return attributes.wisdom
		"charisma": return attributes.charisma
		_: return 10

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

# --- Static Taxonomy & Scaling Query Helpers ---

static func is_combat_weapon_skill(p_id: SkillId) -> bool:
	return COMBAT_SKILL_SCALING.has(p_id)

static func get_secondary_attribute(p_id: SkillId) -> String:
	if COMBAT_SKILL_SCALING.has(p_id):
		return String(COMBAT_SKILL_SCALING[p_id].get("secondary", ""))
	return ""

static func does_skill_double_primary_at_50(p_id: SkillId) -> bool:
	if COMBAT_SKILL_SCALING.has(p_id):
		return bool(COMBAT_SKILL_SCALING[p_id].get("doubles_primary_at_50", false))
	return false

static func get_skills_by_tier(p_tier: SkillTier) -> Array[SkillId]:
	match p_tier:
		SkillTier.STARTING:
			var starting: Array[SkillId] = [
				SkillId.SWORDSMANSHIP,
				SkillId.BLUNT_WEAPON_FIGHTING,
				SkillId.FINESSE_WEAPON_FIGHTING,
				SkillId.POLEARMS,
				SkillId.BRAWLING,
				SkillId.ARCHERY,
				SkillId.THROWING,
				SkillId.DODGE,
				SkillId.PARRY,
				SkillId.STEALTH_HIDE,
				SkillId.ARCANE_MAGIC,
				SkillId.ALCHEMY,
				SkillId.SCHOLARSHIP,
				SkillId.DIVINE_MAGIC,
				SkillId.PERCEPTION,
				SkillId.LOCKPICKING,
				SkillId.DISABLE_DEVICE,
				SkillId.BARTERING
			]
			return starting
		SkillTier.META:
			var meta: Array[SkillId] = [
				SkillId.MEDITATION,
				SkillId.BEAST_MASTERY,
				SkillId.INTIMIDATION,
				SkillId.LEADERSHIP,
				SkillId.SURVIVALISM
			]
			return meta
		SkillTier.CLASS_EXCLUSIVE:
			var exclusive: Array[SkillId] = [
				SkillId.SHIELD_FORTIFICATION,
				SkillId.PAIN_HARNESSING,
				SkillId.RIPOSTE_FINESSE,
				SkillId.WEAPON_SYNTHESIS,
				SkillId.ASSASSINATION,
				SkillId.BALLISTICS,
				SkillId.GUN_KATA,
				SkillId.UMBRAL_PHASING,
				SkillId.PYROMANCY,
				SkillId.SPELL_FORGING,
				SkillId.TEMPORAL_WARPING,
				SkillId.NECROMANTIC_SIPHON,
				SkillId.HOLY_SMITING,
				SkillId.SACRED_BULWARK,
				SkillId.WITCH_PURGING,
				SkillId.DIVINE_MIRACLES,
				SkillId.ASTRAL_BLADE,
				SkillId.TOXICOLOGY,
				SkillId.KI_STRIKES,
				SkillId.GRANDMASTER_SYNTHESIS,
				SkillId.IMPROVISED_SURVIVAL
			]
			return exclusive
		_:
			return []

static func get_tier_for_skill(p_id: SkillId) -> SkillTier:
	if get_skills_by_tier(SkillTier.STARTING).has(p_id):
		return SkillTier.STARTING
	if get_skills_by_tier(SkillTier.META).has(p_id):
		return SkillTier.META
	if get_skills_by_tier(SkillTier.CLASS_EXCLUSIVE).has(p_id):
		return SkillTier.CLASS_EXCLUSIVE
	return SkillTier.STARTING

static func get_associated_attribute(p_id: SkillId) -> String:
	if COMBAT_SKILL_SCALING.has(p_id):
		return String(COMBAT_SKILL_SCALING[p_id]["primary"])
	match p_id:
		# Tier 1 Starting
		SkillId.DODGE, SkillId.PARRY, SkillId.STEALTH_HIDE, SkillId.LOCKPICKING, SkillId.DISABLE_DEVICE:
			return "dexterity"
		SkillId.BARTERING:
			return "charisma"
		SkillId.ARCANE_MAGIC, SkillId.ALCHEMY, SkillId.SCHOLARSHIP:
			return "intelligence"
		SkillId.DIVINE_MAGIC, SkillId.PERCEPTION:
			return "wisdom"
		# Tier 2 Meta
		SkillId.MEDITATION:
			return "wisdom"
		SkillId.BEAST_MASTERY, SkillId.INTIMIDATION, SkillId.LEADERSHIP:
			return "charisma"
		SkillId.SURVIVALISM:
			return "constitution"
		# Tier 3 Class Exclusive
		SkillId.SHIELD_FORTIFICATION, SkillId.PAIN_HARNESSING, SkillId.WEAPON_SYNTHESIS:
			return "strength"
		SkillId.RIPOSTE_FINESSE, SkillId.ASSASSINATION, SkillId.BALLISTICS, SkillId.GUN_KATA, SkillId.UMBRAL_PHASING, SkillId.KI_STRIKES:
			return "dexterity"
		SkillId.PYROMANCY, SkillId.SPELL_FORGING, SkillId.TEMPORAL_WARPING, SkillId.NECROMANTIC_SIPHON, SkillId.TOXICOLOGY:
			return "intelligence"
		SkillId.HOLY_SMITING:
			return "strength"
		SkillId.SACRED_BULWARK, SkillId.IMPROVISED_SURVIVAL:
			return "constitution"
		SkillId.WITCH_PURGING, SkillId.DIVINE_MIRACLES:
			return "wisdom"
		SkillId.ASTRAL_BLADE:
			return "dexterity"
		SkillId.GRANDMASTER_SYNTHESIS:
			return "strength"
		SkillId.MARKSMANSHIP:
			return "dexterity"
		_:
			return "strength"

static func get_exclusive_class_id(p_id: SkillId) -> String:
	match p_id:
		SkillId.SHIELD_FORTIFICATION: return "knight"
		SkillId.PAIN_HARNESSING: return "berserker"
		SkillId.RIPOSTE_FINESSE: return "duelist"
		SkillId.WEAPON_SYNTHESIS: return "weapon_master"
		SkillId.ASSASSINATION: return "assassin"
		SkillId.BALLISTICS: return "ranger"
		SkillId.GUN_KATA: return "gunslinger"
		SkillId.UMBRAL_PHASING: return "shadow_stalker"
		SkillId.PYROMANCY: return "elementalist"
		SkillId.SPELL_FORGING: return "battlemage"
		SkillId.TEMPORAL_WARPING: return "chronomancer"
		SkillId.NECROMANTIC_SIPHON: return "necromancer"
		SkillId.HOLY_SMITING: return "paladin"
		SkillId.SACRED_BULWARK: return "templar"
		SkillId.WITCH_PURGING: return "inquisitor"
		SkillId.DIVINE_MIRACLES: return "high_priest"
		SkillId.ASTRAL_BLADE: return "spellblade"
		SkillId.TOXICOLOGY: return "witch_hunter"
		SkillId.KI_STRIKES: return "monk"
		SkillId.GRANDMASTER_SYNTHESIS: return "grandmaster_initiate"
		SkillId.IMPROVISED_SURVIVAL: return "vagabond"
		_: return ""

static func get_skill_name(p_id: SkillId) -> String:
	match p_id:
		SkillId.SWORDSMANSHIP: return "Swordsmanship"
		SkillId.BLUNT_WEAPON_FIGHTING: return "Blunt Weapon Fighting"
		SkillId.FINESSE_WEAPON_FIGHTING: return "Finesse Weapon Fighting"
		SkillId.POLEARMS: return "Polearms"
		SkillId.BRAWLING: return "Brawling"
		SkillId.ARCHERY: return "Archery"
		SkillId.THROWING: return "Throwing"
		SkillId.DODGE: return "Dodge"
		SkillId.PARRY: return "Parry"
		SkillId.STEALTH_HIDE: return "Stealth"
		SkillId.ARCANE_MAGIC: return "Arcane Magic"
		SkillId.ALCHEMY: return "Alchemy"
		SkillId.SCHOLARSHIP: return "Scholarship"
		SkillId.DIVINE_MAGIC: return "Divine Magic"
		SkillId.PERCEPTION: return "Perception"
		SkillId.MEDITATION: return "Meditation"
		SkillId.BEAST_MASTERY: return "Beast Mastery"
		SkillId.INTIMIDATION: return "Intimidation"
		SkillId.LEADERSHIP: return "Leadership"
		SkillId.SURVIVALISM: return "Survivalism"
		SkillId.SHIELD_FORTIFICATION: return "Shield Fortification"
		SkillId.PAIN_HARNESSING: return "Pain Harnessing"
		SkillId.RIPOSTE_FINESSE: return "Riposte Finesse"
		SkillId.WEAPON_SYNTHESIS: return "Weapon Synthesis"
		SkillId.ASSASSINATION: return "Assassination"
		SkillId.BALLISTICS: return "Ballistics"
		SkillId.GUN_KATA: return "Gun Kata"
		SkillId.UMBRAL_PHASING: return "Umbral Phasing"
		SkillId.PYROMANCY: return "Pyromancy"
		SkillId.SPELL_FORGING: return "Spell Forging"
		SkillId.TEMPORAL_WARPING: return "Temporal Warping"
		SkillId.NECROMANTIC_SIPHON: return "Necromantic Siphon"
		SkillId.HOLY_SMITING: return "Holy Smiting"
		SkillId.SACRED_BULWARK: return "Sacred Bulwark"
		SkillId.WITCH_PURGING: return "Witch Purging"
		SkillId.DIVINE_MIRACLES: return "Divine Miracles"
		SkillId.ASTRAL_BLADE: return "Astral Blade"
		SkillId.TOXICOLOGY: return "Toxicology"
		SkillId.KI_STRIKES: return "Ki Strikes"
		SkillId.GRANDMASTER_SYNTHESIS: return "Grandmaster Synthesis"
		SkillId.IMPROVISED_SURVIVAL: return "Improvised Survival"
		SkillId.MARKSMANSHIP: return "Marksmanship"
		SkillId.LOCKPICKING: return "Lockpicking"
		SkillId.DISABLE_DEVICE: return "Disable Device"
		SkillId.BARTERING: return "Bartering"
		_: return "Unknown Skill"

static func get_skill_key(p_id: SkillId) -> String:
	match p_id:
		SkillId.SWORDSMANSHIP: return "SWORDSMANSHIP"
		SkillId.BLUNT_WEAPON_FIGHTING: return "BLUNT_WEAPON_FIGHTING"
		SkillId.FINESSE_WEAPON_FIGHTING: return "FINESSE_WEAPON_FIGHTING"
		SkillId.POLEARMS: return "POLEARMS"
		SkillId.BRAWLING: return "BRAWLING"
		SkillId.ARCHERY: return "ARCHERY"
		SkillId.THROWING: return "THROWING"
		SkillId.DODGE: return "DODGE"
		SkillId.PARRY: return "PARRY"
		SkillId.STEALTH_HIDE: return "STEALTH_HIDE"
		SkillId.ARCANE_MAGIC: return "ARCANE_MAGIC"
		SkillId.ALCHEMY: return "ALCHEMY"
		SkillId.SCHOLARSHIP: return "SCHOLARSHIP"
		SkillId.DIVINE_MAGIC: return "DIVINE_MAGIC"
		SkillId.PERCEPTION: return "PERCEPTION"
		SkillId.MEDITATION: return "MEDITATION"
		SkillId.BEAST_MASTERY: return "BEAST_MASTERY"
		SkillId.INTIMIDATION: return "INTIMIDATION"
		SkillId.LEADERSHIP: return "LEADERSHIP"
		SkillId.SURVIVALISM: return "SURVIVALISM"
		SkillId.SHIELD_FORTIFICATION: return "SHIELD_FORTIFICATION"
		SkillId.PAIN_HARNESSING: return "PAIN_HARNESSING"
		SkillId.RIPOSTE_FINESSE: return "RIPOSTE_FINESSE"
		SkillId.WEAPON_SYNTHESIS: return "WEAPON_SYNTHESIS"
		SkillId.ASSASSINATION: return "ASSASSINATION"
		SkillId.BALLISTICS: return "BALLISTICS"
		SkillId.GUN_KATA: return "GUN_KATA"
		SkillId.UMBRAL_PHASING: return "UMBRAL_PHASING"
		SkillId.PYROMANCY: return "PYROMANCY"
		SkillId.SPELL_FORGING: return "SPELL_FORGING"
		SkillId.TEMPORAL_WARPING: return "TEMPORAL_WARPING"
		SkillId.NECROMANTIC_SIPHON: return "NECROMANTIC_SIPHON"
		SkillId.HOLY_SMITING: return "HOLY_SMITING"
		SkillId.SACRED_BULWARK: return "SACRED_BULWARK"
		SkillId.WITCH_PURGING: return "WITCH_PURGING"
		SkillId.DIVINE_MIRACLES: return "DIVINE_MIRACLES"
		SkillId.ASTRAL_BLADE: return "ASTRAL_BLADE"
		SkillId.TOXICOLOGY: return "TOXICOLOGY"
		SkillId.KI_STRIKES: return "KI_STRIKES"
		SkillId.GRANDMASTER_SYNTHESIS: return "GRANDMASTER_SYNTHESIS"
		SkillId.IMPROVISED_SURVIVAL: return "IMPROVISED_SURVIVAL"
		SkillId.MARKSMANSHIP: return "MARKSMANSHIP"
		SkillId.LOCKPICKING: return "LOCKPICKING"
		SkillId.DISABLE_DEVICE: return "DISABLE_DEVICE"
		SkillId.BARTERING: return "BARTERING"
		_: return ""

static func get_skill_description(p_id: SkillId) -> String:
	match p_id:
		SkillId.SWORDSMANSHIP: return "Mastery of one-handed, versatile, and two-handed swords. Scales with STR (0-49.9) and unlocks DEX accuracy scaling at Level 50."
		SkillId.BLUNT_WEAPON_FIGHTING: return "Crushing impact with clubs, maces, warhammers, staves, and mauls. Scales with STR and doubles STR accuracy scaling at Level 50."
		SkillId.FINESSE_WEAPON_FIGHTING: return "Precision bladework with daggers, stilettos, main-gauches, and kris blades. Scales with DEX and doubles DEX accuracy scaling at Level 50."
		SkillId.POLEARMS: return "Reach combat with spears, halberds, glaives, and tridents. Scales with CON (0-49.9) and unlocks STR accuracy scaling at Level 50."
		SkillId.BRAWLING: return "Close-quarters martial arts with cestus, knuckles, wraps, claws, and plate gauntlets. Scales with STR and unlocks DEX scaling at Level 50."
		SkillId.ARCHERY: return "Ranged marksmanship with bows and crossbows. Scales with DEX and doubles DEX accuracy scaling at Level 50."
		SkillId.THROWING: return "Ballistic precision with throwing daggers, javelins, axes, chakrams, and fire vials. Scales with DEX and unlocks STR scaling at Level 50."
		SkillId.DODGE: return "Acrobatic footwork, sidesteps, and evasion to completely negate incoming attacks."
		SkillId.PARRY: return "Deflection of hostile strikes using blades or shields, turning force into ripostes."
		SkillId.STEALTH_HIDE: return "Concealment in shadows, silent movement, and ambush evasion."
		SkillId.ARCANE_MAGIC: return "Manipulation of raw astral ether to weave spells of force, flame, and blinking."
		SkillId.ALCHEMY: return "Transmutation of herbs and reagents into potent healing drafts and explosive vials."
		SkillId.SCHOLARSHIP: return "Ancient lore deciphering, spellbook deciphering, and tactical weakness discovery."
		SkillId.DIVINE_MAGIC: return "Holy devotion channeling sacred radiant energy to mend wounds and smite abominations."
		SkillId.PERCEPTION: return "Detection of hidden pressure plates, concealed pitfalls, and secret doorway seams."
		SkillId.MEDITATION: return "Astral focus channeling passive mana regeneration and mental tranquility."
		SkillId.BEAST_MASTERY: return "Taming, commanding, and fortifying animal companions and hounds."
		SkillId.INTIMIDATION: return "Martial presence causing weak-willed adversaries to falter or flee."
		SkillId.LEADERSHIP: return "Tactical rallying boosting companion combat accuracy and resilience."
		SkillId.SURVIVALISM: return "Dungeon foraging, hazard mitigation, and endurance against floor cave-ins."
		SkillId.LOCKPICKING: return "Picking physical locks and padlocks on doors and chests using thieves' tools."
		SkillId.DISABLE_DEVICE: return "Disarming trapped chests and floor mechanisms detected by Perception."
		SkillId.BARTERING: return "Negotiating favorable trade margins with dungeon merchants and hawkers."
		_: return "Specialized master technique honed through deep dungeon delve experience."

static func get_milestone_info(p_id: SkillId, milestone: int) -> Dictionary:
	var s_name = get_skill_name(p_id)
	match milestone:
		25:
			if is_combat_weapon_skill(p_id):
				return {
					"title": "Novice Keystone: %s Active Technique" % s_name,
					"benefit": "Unlocks the weapon-unique secondary Active Attack for all %s weapons (equippable to Hotbar)." % s_name
				}
			return {
				"title": "Novice Keystone: %s Focus" % s_name,
				"benefit": "+10% Action Efficiency and +5% Critical Strike Chance when utilizing this discipline."
			}
		50:
			if COMBAT_SKILL_SCALING.has(p_id):
				var cfg = COMBAT_SKILL_SCALING[p_id]
				var pri = String(cfg["primary"]).capitalize()
				if bool(cfg["doubles_primary_at_50"]):
					return {
						"title": "Journeyman Keystone: %s Accuracy Doubling" % s_name,
						"benefit": "Accuracy Scaling Shift: Doubles the effectiveness of Primary Attribute (%s) on weapon hit chance." % pri
					}
				else:
					var sec = String(cfg["secondary"]).capitalize()
					return {
						"title": "Journeyman Keystone: %s Dual-Attribute Flow" % s_name,
						"benefit": "Accuracy Scaling Shift: Unlocks Secondary Attribute (%s) accuracy scaling alongside Primary (%s)." % [sec, pri]
					}
			return {
				"title": "Journeyman Keystone: %s Flow" % s_name,
				"benefit": "+20% Action Efficiency and secondary trait synergy with governing attribute."
			}
		75:
			return {
				"title": "Expert Keystone: %s Mastery" % s_name,
				"benefit": "+35% Action Efficiency, stamina/mana cost reduced by 25%."
			}
		100:
			return {
				"title": "Grandmaster Capstone: Ascendant %s" % s_name,
				"benefit": "Ultimate Grandmaster Ascension: Max potency, zero fumble/fizzle chance, lethal execution strikes."
			}
		_:
			return {
				"title": "Milestone %d" % milestone,
				"benefit": "Unlocks deepened prowess in %s." % s_name
			}
