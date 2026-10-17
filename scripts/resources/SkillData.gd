class_name SkillData
extends Resource

## SkillData: Data resource for individual use-based skills (0.0 to 100.0)
## and Tri-Tier Skill Taxonomy (Starting, Meta, Class-Exclusive).

signal skill_level_changed(skill_id: SkillId, new_level: float)
signal keystone_reached(skill_id: SkillId, milestone: int)

enum SkillTier {
	STARTING,        ## Available at character creation from the first run (14 skills)
	META,            ## Unlocked via account rank / Meta EXP; added to starting pool (5 skills)
	CLASS_EXCLUSIVE  ## Unlocked exclusively upon Floor 2 Class Specialization (21 skills)
}

enum SkillId {
	# Tier 1: Starting Skills (14)
	SWORDSMANSHIP,
	MACE_FIGHTING,
	POLEARMS,
	BRAWLING,
	ARCHERY,
	THROWING,
	DODGE,
	PARRY,
	STEALTH_HIDE,
	ARCANE_MAGIC,
	ALCHEMY,
	SCHOLARSHIP,
	DIVINE_MAGIC,
	PERCEPTION,
	
	# Tier 2: Meta Skills (5)
	MEDITATION,
	BEAST_MASTERY,
	INTIMIDATION,
	LEADERSHIP,
	SURVIVALISM,
	
	# Tier 3: Class-Exclusive Skills (21)
	SHIELD_FORTIFICATION,
	PAIN_HARNESSING,
	RIPOSTE_FINESSE,
	WEAPON_SYNTHESIS,
	ASSASSINATION,
	BALLISTICS,
	GUN_KATA,
	UMBRAL_PHASING,
	PYROMANCY,
	SPELL_FORGING,
	TEMPORAL_WARPING,
	NECROMANTIC_SIPHON,
	HOLY_SMITING,
	SACRED_BULWARK,
	WITCH_PURGING,
	DIVINE_MIRACLES,
	ASTRAL_BLADE,
	TOXICOLOGY,
	KI_STRIKES,
	GRANDMASTER_SYNTHESIS,
	IMPROVISED_SURVIVAL,
	
	# Legacy / Deprecated
	MARKSMANSHIP
}

const STEALTH: SkillId = SkillId.STEALTH_HIDE

@export var skill_id: SkillId = SkillId.SWORDSMANSHIP
@export var skill_name: String = ""
@export var tier: SkillTier = SkillTier.STARTING
@export var associated_attribute_name: String = "strength" # "strength", "dexterity", etc.
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
	tier = get_tier_for_skill(p_id)
	exclusive_class_id = get_exclusive_class_id(p_id)
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

# --- Static Taxonomy Query Helpers ---

static func get_skills_by_tier(p_tier: SkillTier) -> Array[SkillId]:
	match p_tier:
		SkillTier.STARTING:
			var starting: Array[SkillId] = [
				SkillId.SWORDSMANSHIP,
				SkillId.MACE_FIGHTING,
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
				SkillId.PERCEPTION
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
	match p_id:
		# Tier 1 Starting
		SkillId.SWORDSMANSHIP, SkillId.MACE_FIGHTING, SkillId.POLEARMS, SkillId.BRAWLING:
			return "strength"
		SkillId.ARCHERY, SkillId.THROWING, SkillId.DODGE, SkillId.PARRY, SkillId.STEALTH_HIDE:
			return "dexterity"
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
		SkillId.MACE_FIGHTING: return "Mace Fighting"
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
		_: return "Unknown Skill"

static func get_skill_description(p_id: SkillId) -> String:
	match p_id:
		SkillId.SWORDSMANSHIP: return "Proficiency in one-handed and two-handed swords, edge alignment, and parry defense."
		SkillId.MACE_FIGHTING: return "Crushing blunt impact with maces, warhammers, and flails. Breaches heavy armor."
		SkillId.POLEARMS: return "Reach combat with spears, halberds, and staves. Keeps foes at a distance."
		SkillId.BRAWLING: return "Unarmed martial arts, fist strikes, and close-quarters grapples."
		SkillId.ARCHERY: return "Ranged precision with recurve, long, and compound bows. Critical eye for weak points."
		SkillId.THROWING: return "Lethal velocity with throwing knives, daggers, and javelins."
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
		_: return "Specialized master technique honed through deep dungeon delve experience."

static func get_milestone_info(p_id: SkillId, milestone: int) -> Dictionary:
	var s_name = get_skill_name(p_id)
	match milestone:
		25:
			return {
				"title": "Novice Keystone: %s Focus" % s_name,
				"benefit": "+10% Action Efficiency and +5% Critical Strike Chance when utilizing this discipline."
			}
		50:
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
