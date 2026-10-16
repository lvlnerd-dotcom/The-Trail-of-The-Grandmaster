class_name MetaProfileData
extends Resource

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

# Unlocked Starter Backgrounds for Character Creation
@export var unlocked_background_ids: Array[String] = ["novice_adventurer"]

# Expanded starting skill pool (SkillData.SkillId as ints)
@export var unlocked_starting_skills: Array[int] = [
    SkillData.SkillId.SWORDSMANSHIP,
    SkillData.SkillId.MACE_FIGHTING,
    SkillData.SkillId.POLEARMS,
    SkillData.SkillId.BRAWLING,
    SkillData.SkillId.MARKSMANSHIP,
    SkillData.SkillId.ARCHERY,
    SkillData.SkillId.THROWING,
    SkillData.SkillId.DODGE,
    SkillData.SkillId.PARRY,
    SkillData.SkillId.STEALTH_HIDE,
    SkillData.SkillId.ARCANE_MAGIC,
    SkillData.SkillId.ALCHEMY,
    SkillData.SkillId.SCHOLARSHIP,
    SkillData.SkillId.DIVINE_MAGIC,
    SkillData.SkillId.PERCEPTION
]

# Bestiary records: creature_id -> {"kills": int, "tier": int}
@export var bestiary_records: Dictionary = {}

# Achievements registry: Array of achievement IDs
@export var unlocked_achievements: Array[String] = []

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
            if not unlocked_background_ids.has("veteran_mercenary"):
                unlocked_background_ids.append("veteran_mercenary")
                perks_unlocked.append("Unlocked Background: Veteran Mercenary (+2 STR, +2 CON, Broadsword)")
        3:
            if not unlocked_background_ids.has("shadow_syndicate"):
                unlocked_background_ids.append("shadow_syndicate")
                perks_unlocked.append("Unlocked Background: Shadow Syndicate (+3 DEX, Throwing Daggers)")
        4:
            if not unlocked_starting_skills.has(SkillData.SkillId.BEAST_MASTERY):
                unlocked_starting_skills.append(SkillData.SkillId.BEAST_MASTERY)
            if not unlocked_starting_skills.has(SkillData.SkillId.MEDITATION):
                unlocked_starting_skills.append(SkillData.SkillId.MEDITATION)
            perks_unlocked.append("Character Creation Pool: Added Beast Mastery and Meditation")
        5:
            if not unlocked_background_ids.has("royal_arcanist"):
                unlocked_background_ids.append("royal_arcanist")
                perks_unlocked.append("Unlocked Background: Royal Arcanist (+3 INT, Arcane Wand)")
        6:
            if not unlocked_background_ids.has("temple_inquisitor"):
                unlocked_background_ids.append("temple_inquisitor")
                perks_unlocked.append("Unlocked Background: Temple Inquisitor (+2 WIS, +1 DEX, Pistol & Smite)")
        7:
            if not unlocked_starting_skills.has(SkillData.SkillId.INTIMIDATION):
                unlocked_starting_skills.append(SkillData.SkillId.INTIMIDATION)
            if not unlocked_starting_skills.has(SkillData.SkillId.LEADERSHIP):
                unlocked_starting_skills.append(SkillData.SkillId.LEADERSHIP)
            perks_unlocked.append("Character Creation Pool: Added Intimidation and Leadership")
        8:
            perks_unlocked.append("Dungeon Expeditioner: All new characters start with +50 Gold")
        10:
            if not unlocked_background_ids.has("grandmaster_initiate"):
                unlocked_background_ids.append("grandmaster_initiate")
                perks_unlocked.append("Unlocked Background: Grandmaster Initiate (Omni +1 all attributes)")
    return perks_unlocked

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
        "unlocked_background_ids": unlocked_background_ids,
        "unlocked_starting_skills": unlocked_starting_skills,
        "bestiary_records": bestiary_records,
        "unlocked_achievements": unlocked_achievements
    }

## Deserializes profile from Dictionary
func from_dict(dict: Dictionary) -> void:
    account_rank = int(dict.get("account_rank", 1))
    current_meta_exp = int(dict.get("current_meta_exp", 0))
    total_runs_played = int(dict.get("total_runs_played", 0))
    total_victories = int(dict.get("total_victories", 0))
    deepest_floor_reached = int(dict.get("deepest_floor_reached", 1))
    total_enemies_slain = int(dict.get("total_enemies_slain", 0))
    total_turns_survived = int(dict.get("total_turns_survived", 0))
    
    var bgs = dict.get("unlocked_background_ids", [])
    if bgs is Array:
        unlocked_background_ids.clear()
        for b in bgs:
            unlocked_background_ids.append(str(b))
            
    var sks = dict.get("unlocked_starting_skills", [])
    if sks is Array:
        unlocked_starting_skills.clear()
        for s in sks:
            unlocked_starting_skills.append(int(s))
            
    bestiary_records = dict.get("bestiary_records", {})
    var achs = dict.get("unlocked_achievements", [])
    if achs is Array:
        unlocked_achievements.clear()
        for a in achs:
            unlocked_achievements.append(str(a))
