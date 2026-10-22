class_name MetaProfileData
extends Resource

const SkillData = preload("res://scripts/resources/SkillData.gd")

## MetaProfileData: Persistent cross-run account progression resource saved to user://meta/profile.json.

signal rank_increased(new_rank: int, unlocked_perks: Array[String])
signal achievement_unlocked(achievement_id: String, achievement_title: String)
signal bestiary_tier_unlocked(creature_id: String, new_tier: int)

@export var account_rank: int = 1
@export var current_meta_exp: int = 0

@export var total_runs_played: int = 0
@export var total_victories: int = 0
@export var deepest_floor_reached: int = 1
@export var total_enemies_slain: int = 0
@export var total_turns_survived: int = 0

# Unlocked Meta Skills added to starting character creation pool
@export var unlocked_meta_skills: Array[String] = []

# Bestiary records: creature_id -> {"kills": int, "tier": int}
@export var bestiary_records: Dictionary = {}

# Achievements registry: Array of achievement IDs
@export var unlocked_achievements: Array[String] = []

# Persistent cross-run grudges from unforgiving deities
@export var betrayed_deities: Array[String] = []

## Required Meta EXP strictly per GDD formula: floor(200 * Rank^1.5)
func get_required_exp_for_rank(rank_num: int = account_rank) -> int:
	return int(floor(200.0 * pow(float(rank_num), 1.5)))

## Awards meta-EXP from a completed/perished run and triggers rank promotions
func add_meta_exp(amount: int) -> Array[int]:
	current_meta_exp += amount
	var promoted_ranks: Array[int] = []
	
	while current_meta_exp >= get_required_exp_for_rank(account_rank):
		current_meta_exp -= get_required_exp_for_rank(account_rank)
		account_rank += 1
		promoted_ranks.append(account_rank)
		var perks = _apply_rank_rewards(account_rank)
		emit_signal("rank_increased", account_rank, perks)
		
	return promoted_ranks

func _apply_rank_rewards(rank_num: int) -> Array[String]:
	var perks_unlocked: Array[String] = []
	match rank_num:
		2:
			unlock_meta_skill("MEDITATION")
			perks_unlocked.append("Unlocked Meta Skill: Meditation (WIS)")
		3:
			unlock_meta_skill("BEAST_MASTERY")
			perks_unlocked.append("Unlocked Meta Skill: Beast Mastery (CHA)")
		4:
			perks_unlocked.append("Class Specialization Reroll Token")
		5:
			unlock_meta_skill("INTIMIDATION")
			perks_unlocked.append("Unlocked Meta Skill: Intimidation (CHA)")
		6:
			unlock_meta_skill("LEADERSHIP")
			perks_unlocked.append("Unlocked Meta Skill: Leadership (CHA)")
		7:
			perks_unlocked.append("Expedition Treasury Boost: All new runs start with +50 Gold")
		8:
			unlock_meta_skill("SURVIVALISM")
			perks_unlocked.append("Unlocked Meta Skill: Survivalism (CON)")
		9:
			perks_unlocked.append("Field Medicine Mastery: Field Trauma Kits heal +20% HP")
		10:
			perks_unlocked.append("Grandmaster's Blessing & Title: +1 to ALL 6 Core Attributes")
	return perks_unlocked

func unlock_meta_skill(skill_key: String) -> void:
	var key = skill_key.to_upper()
	if not unlocked_meta_skills.has(key):
		unlocked_meta_skills.append(key)

func is_meta_skill_unlocked(skill_key: String) -> bool:
	return unlocked_meta_skills.has(skill_key.to_upper())

func is_skill_unlocked(p_id: SkillData.SkillId) -> bool:
	var tier = SkillData.get_tier_for_skill(p_id)
	if tier == SkillData.SkillTier.STARTING:
		return true
	if tier == SkillData.SkillTier.META:
		var key = SkillData.get_skill_key(p_id)
		return is_meta_skill_unlocked(key)
	return false

func sync_meta_skills_for_rank(rank_num: int) -> void:
	if rank_num >= 2:
		unlock_meta_skill("MEDITATION")
	if rank_num >= 3:
		unlock_meta_skill("BEAST_MASTERY")
	if rank_num >= 5:
		unlock_meta_skill("INTIMIDATION")
	if rank_num >= 6:
		unlock_meta_skill("LEADERSHIP")
	if rank_num >= 8:
		unlock_meta_skill("SURVIVALISM")

## Records a creature kill and updates knowledge tier (Tier 1: 1 kill, Tier 2: 5 kills, Tier 3: 15 kills)
func record_creature_kill(creature_id: String) -> int:
	total_enemies_slain += 1
	if not bestiary_records.has(creature_id):
		bestiary_records[creature_id] = {"kills": 0, "tier": 0}
		
	var rec = bestiary_records[creature_id]
	rec["kills"] = int(rec["kills"]) + 1
	var kills = rec["kills"]
	var old_tier = int(rec["tier"])
	var new_tier = old_tier
	
	if kills >= 15:
		new_tier = 3
	elif kills >= 5:
		new_tier = 2
	elif kills >= 1:
		new_tier = 1
		
	if new_tier > old_tier:
		rec["tier"] = new_tier
		emit_signal("bestiary_tier_unlocked", creature_id, new_tier)
		
	return new_tier

## Unlocks an achievement if not already obtained
func unlock_achievement(achievement_id: String, achievement_title: String) -> bool:
	if unlocked_achievements.has(achievement_id):
		return false
	unlocked_achievements.append(achievement_id)
	emit_signal("achievement_unlocked", achievement_id, achievement_title)
	return true

func record_betrayed_deity(deity_id: String) -> void:
	var key = deity_id.to_lower()
	if not betrayed_deities.has(key):
		betrayed_deities.append(key)

func is_deity_betrayed(deity_id: String) -> bool:
	return betrayed_deities.has(deity_id.to_lower())

## Serializes profile to JSON-compatible Dictionary
func to_dict() -> Dictionary:
	return {
		"account_rank": account_rank,
		"current_meta_exp": current_meta_exp,
		"total_runs_played": total_runs_played,
		"total_victories": total_victories,
		"deepest_floor_reached": deepest_floor_reached,
		"total_enemies_slain": total_enemies_slain,
		"total_turns_survived": total_turns_survived,
		"unlocked_meta_skills": unlocked_meta_skills,
		"bestiary_records": bestiary_records,
		"unlocked_achievements": unlocked_achievements,
		"betrayed_deities": betrayed_deities
	}

## Deserializes profile from Dictionary with backward-compatible migration
func from_dict(dict: Dictionary) -> void:
	account_rank = int(dict.get("account_rank", 1))
	current_meta_exp = int(dict.get("current_meta_exp", 0))
	total_runs_played = int(dict.get("total_runs_played", 0))
	total_victories = int(dict.get("total_victories", 0))
	deepest_floor_reached = int(dict.get("deepest_floor_reached", 1))
	total_enemies_slain = int(dict.get("total_enemies_slain", 0))
	total_turns_survived = int(dict.get("total_turns_survived", 0))
	
	unlocked_meta_skills.clear()
	var ms = dict.get("unlocked_meta_skills", [])
	if ms is Array:
		for s in ms:
			var s_str = str(s).to_upper()
			if not unlocked_meta_skills.has(s_str):
				unlocked_meta_skills.append(s_str)
				
	# Reconstruct unlocked meta skills per rank schedule (cleanses deprecated backgrounds)
	sync_meta_skills_for_rank(account_rank)
	
	bestiary_records = dict.get("bestiary_records", {})
	var achs = dict.get("unlocked_achievements", [])
	if achs is Array:
		unlocked_achievements.clear()
		for a in achs:
			unlocked_achievements.append(str(a))
			
	var b_deities = dict.get("betrayed_deities", [])
	if b_deities is Array:
		betrayed_deities.clear()
		for d in b_deities:
			betrayed_deities.append(str(d).to_lower())
