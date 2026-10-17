extends Node

const SkillData = preload("res://scripts/resources/SkillData.gd")
const MetaProfileData = preload("res://scripts/resources/MetaProfileData.gd")

## MetaManager: Autoload managing persistent cross-run account progression and unlocks.

const PROFILE_DIR = "user://meta"
const PROFILE_PATH = "user://meta/profile.json"

var profile: MetaProfileData = null

func _get_event_bus() -> Node:
    var loop = Engine.get_main_loop()
    if loop and loop is SceneTree:
        return (loop as SceneTree).root.get_node_or_null("EventBus")
    return null

func _ready() -> void:
    load_profile()

func load_profile() -> MetaProfileData:
    if not profile:
        profile = MetaProfileData.new()
        
    if not FileAccess.file_exists(PROFILE_PATH):
        save_profile()
        return profile
        
    var file = FileAccess.open(PROFILE_PATH, FileAccess.READ)
    if not file:
        return profile
        
    var text = file.get_as_text()
    file.close()
    
    var json = JSON.new()
    var parse_res = json.parse(text)
    if parse_res == OK and json.data is Dictionary:
        profile.from_dict(json.data)
    else:
        push_warning("Failed to parse meta profile JSON; initializing defaults.")
        save_profile()
        
    return profile

func save_profile() -> bool:
    if not profile:
        profile = MetaProfileData.new()
        
    if not DirAccess.dir_exists_absolute(PROFILE_DIR):
        DirAccess.make_dir_recursive_absolute(PROFILE_DIR)
        
    var dict = profile.to_dict()
    var json_str = JSON.stringify(dict, "  ")
    
    var file = FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
    if not file:
        push_error("Failed to write meta profile to: " + PROFILE_PATH)
        return false
        
    file.store_string(json_str)
    file.close()
    
    var bus = _get_event_bus()
    if bus and bus.has_signal("meta_profile_saved"):
        bus.emit_signal("meta_profile_saved")
        
    return true

## Processes a completed or perished run, awarding Account EXP and registering stats
func record_run_completion(summary: Dictionary) -> Dictionary:
    if not profile:
        load_profile()
        
    profile.total_runs_played += 1
    var floors_cleared = int(summary.get("floors_cleared", 0))
    var std_kills = int(summary.get("standard_kills", 0))
    var elite_kills = int(summary.get("elite_kills", 0))
    var boss_kills = int(summary.get("boss_kills", 0))
    var keystones = int(summary.get("keystones_unlocked", 0))
    var gold = int(summary.get("gold_earned", 0))
    var victory = bool(summary.get("victory", false))
    var turns = int(summary.get("turns_survived", 0))
    
    profile.total_turns_survived += turns
    if floors_cleared > profile.deepest_floor_reached:
        profile.deepest_floor_reached = floors_cleared
    if victory:
        profile.total_victories += 1
        
    # Mathematical Run EXP Formula strictly per GDD:
    # RunEXP = (Floors * 100) + (Std * 10) + (Elite * 30) + (Boss * 150) + (Keystones * 50) + floor(Gold * 0.10) + (Victory ? 1000 : 0)
    var earned_exp = (floors_cleared * 100) + (std_kills * 10) + (elite_kills * 30) + (boss_kills * 150) + (keystones * 50) + int(floor(float(gold) * 0.10))
    if victory:
        earned_exp += 1000
        
    var old_rank = profile.account_rank
    var promoted_ranks = profile.add_meta_exp(earned_exp)
    var new_rank = profile.account_rank
    
    save_profile()
    
    return {
        "earned_exp": earned_exp,
        "old_rank": old_rank,
        "new_rank": new_rank,
        "promoted_ranks": promoted_ranks,
        "current_exp": profile.current_meta_exp,
        "req_exp": profile.get_required_exp_for_rank(new_rank)
    }

func record_kill(creature_id: String) -> int:
    if not profile:
        load_profile()
    var new_tier = profile.record_creature_kill(creature_id)
    save_profile()
    var bus = _get_event_bus()
    if bus and bus.has_signal("bestiary_entry_updated"):
        bus.emit_signal("bestiary_entry_updated", creature_id, new_tier)
    return new_tier

func unlock_achievement(achievement_id: String, title: String) -> bool:
    if not profile:
        load_profile()
    var unlocked = profile.unlock_achievement(achievement_id, title)
    if unlocked:
        save_profile()
        var bus = _get_event_bus()
        if bus and bus.has_signal("meta_achievement_unlocked"):
            bus.emit_signal("meta_achievement_unlocked", achievement_id, title)
    return unlocked

func is_meta_skill_unlocked(skill_key: String) -> bool:
    if not profile:
        load_profile()
    return profile.is_meta_skill_unlocked(skill_key)

func get_unlocked_meta_skills() -> Array[String]:
    if not profile:
        load_profile()
    return profile.unlocked_meta_skills

func get_starting_skills_pool() -> Array[int]:
    if not profile:
        load_profile()
    var pool: Array[int] = []
    for s_id in SkillData.get_skills_by_tier(SkillData.SkillTier.STARTING):
        pool.append(int(s_id))
    for meta_id in SkillData.get_skills_by_tier(SkillData.SkillTier.META):
        if profile.is_skill_unlocked(meta_id):
            pool.append(int(meta_id))
    return pool
