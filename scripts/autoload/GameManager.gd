extends Node

## GameManager: Manages session lifecycle, run state, floor numbering, and seeds.

const MAX_FLOORS: int = 20

var current_floor: int = 1
var is_run_active: bool = false
var current_seed: int = 0
var total_turns_elapsed_run: int = 0
var pending_creation_data: Dictionary = {}
var open_creation_on_main_menu: bool = false

const SAVE_DIR = "user://saves"
const SAVE_PATH = "user://saves/current_run.json"
const SAVE_TMP_PATH = "user://saves/current_run.tmp"
const HMAC_SALT = "Grandmaster_Trail_v1_Salt_7749"

func _get_event_bus() -> Node:
    var loop = Engine.get_main_loop()
    if loop and loop is SceneTree:
        return (loop as SceneTree).root.get_node_or_null("EventBus")
    return null

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

func start_new_run(optional_seed: int = 0) -> void:
    if optional_seed != 0:
        current_seed = optional_seed
    else:
        current_seed = randi()
    seed(current_seed)
    current_floor = 1
    total_turns_elapsed_run = 0
    is_run_active = true

func end_current_run(is_victory: bool = false) -> void:
    is_run_active = false
    wipe_run_save()

func advance_to_next_floor() -> bool:
    if current_floor >= MAX_FLOORS:
        end_current_run(true)
        return false
    current_floor += 1
    return true

func calculate_hmac(json_str: String) -> String:
    return (json_str + HMAC_SALT).sha256_text()

func has_active_save() -> bool:
    return FileAccess.file_exists(SAVE_PATH)

## Serializes the active run state to user://saves/current_run.json atomically
func save_run(world: Node2D) -> bool:
    if not is_instance_valid(world):
        return false
        
    if not DirAccess.dir_exists_absolute(SAVE_DIR):
        DirAccess.make_dir_recursive_absolute(SAVE_DIR)
        
    var player = world.get("player") as Node2D
    var turn_mgr = world.get("turn_manager") as TurnManager
    var grid = world.get("grid") as DungeonGrid
    
    if not player or not turn_mgr or not grid:
        return false
        
    var p_stats = player.get_node_or_null("StatsComponent") as StatsComponent
    var p_skills = player.get_node_or_null("SkillComponent") as SkillComponent
    var p_inv = player.get_node_or_null("InventoryComponent") as InventoryComponent
    var p_magic = player.get_node_or_null("SpellCastingComponent") as SpellCastingComponent
    
    var attr_dict = {}
    if p_stats and p_stats.attributes:
        var a = p_stats.attributes
        attr_dict = {
            "strength": a.strength,
            "dexterity": a.dexterity,
            "constitution": a.constitution,
            "intelligence": a.intelligence,
            "wisdom": a.wisdom,
            "charisma": a.charisma,
            "level": a.character_level,
            "exp": a.current_exp,
            "unallocated_points": a.unallocated_attribute_points
        }
        
    var skill_dict = {}
    if p_skills:
        for s_id in p_skills.skills.keys():
            var s = p_skills.skills[s_id] as SkillData
            if s:
                skill_dict[str(s_id)] = s.level
                
    var known_spell_ids: Array[String] = []
    if p_magic:
        for sp in p_magic.known_spells:
            known_spell_ids.append(sp.spell_id)
            
    var equipped_dict = {}
    var backpack_array: Array[Dictionary] = []
    if p_inv:
        for slot in p_inv.equipped_slots.keys():
            var it = p_inv.equipped_slots[slot] as ItemData
            if it:
                equipped_dict[str(slot)] = {
                    "id": it.item_id,
                    "name": it.item_name,
                    "slot": it.equip_slot,
                    "weight": it.weight_stones,
                    "armor": it.armor_value,
                    "damage_min": it.base_damage_min,
                    "damage_max": it.base_damage_max
                }
        for it in p_inv.backpack_items:
            backpack_array.append({
                "id": it.item_id,
                "name": it.item_name,
                "slot": it.equip_slot,
                "weight": it.weight_stones,
                "armor": it.armor_value,
                "damage_min": it.base_damage_min,
                "damage_max": it.base_damage_max
            })
            
    var run_data: Dictionary = {
        "version": "1.0",
        "current_floor": current_floor,
        "seed": current_seed,
        "turns_remaining": turn_mgr.floor_turns_remaining,
        "total_floor_turns": turn_mgr.floor_total_turns,
        "turn_number": turn_mgr.turn_number,
        "player": {
            "grid_pos": [player.get("grid_pos").x, player.get("grid_pos").y] if "grid_pos" in player else [0, 0],
            "class_id": player.get_meta("class_id") if player.has_meta("class_id") else "",
            "class_name": player.get_meta("class_name") if player.has_meta("class_name") else "",
            "attributes": attr_dict,
            "skills": skill_dict,
            "current_hp": p_stats.current_hp if p_stats else 100.0,
            "current_mana": p_stats.current_mana if p_stats else 50.0,
            "spells": known_spell_ids,
            "equipped": equipped_dict,
            "backpack": backpack_array,
            "gold": player.get_meta("gold") if player.has_meta("gold") else 0
        }
    }
    
    var json_str = JSON.stringify(run_data, "  ")
    var hmac_val = calculate_hmac(json_str)
    run_data["hmac_sha256"] = hmac_val
    var final_str = JSON.stringify(run_data, "  ")
    
    # Atomic write: write to temp file then rename
    var tmp_file = FileAccess.open(SAVE_TMP_PATH, FileAccess.WRITE)
    if not tmp_file:
        push_error("Failed to write to temporary save file: " + SAVE_TMP_PATH)
        return false
    tmp_file.store_string(final_str)
    tmp_file.close()
    
    # Overwrite target file
    if FileAccess.file_exists(SAVE_PATH):
        DirAccess.remove_absolute(SAVE_PATH)
    var err = DirAccess.rename_absolute(SAVE_TMP_PATH, SAVE_PATH)
    if err != OK:
        push_error("Failed to rename temporary save file to: " + SAVE_PATH)
        return false
        
    var bus = _get_event_bus()
    if bus and bus.has_signal("run_saved"):
        bus.emit_signal("run_saved", SAVE_PATH)
    return true

## Loads and validates run save data from user://saves/current_run.json
func load_run_data() -> Dictionary:
    if not FileAccess.file_exists(SAVE_PATH):
        return {}
        
    var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
    if not file:
        return {}
    var text = file.get_as_text()
    file.close()
    
    var json = JSON.new()
    var err = json.parse(text)
    if err != OK or not (json.data is Dictionary):
        var bus = _get_event_bus()
        if bus and bus.has_signal("save_corrupted"):
            bus.emit_signal("save_corrupted", "Invalid JSON format")
        return {}
        
    var data: Dictionary = json.data
    var stored_hmac = str(data.get("hmac_sha256", ""))
    data.erase("hmac_sha256")
    
    var stripped_json = JSON.stringify(data, "  ")
    var expected_hmac = calculate_hmac(stripped_json)
    
    if stored_hmac != expected_hmac:
        var bus = _get_event_bus()
        if bus and bus.has_signal("save_corrupted"):
            bus.emit_signal("save_corrupted", "HMAC SHA-256 signature mismatch (corrupted or tampered)")
        return {}
        
    # Re-insert hmac for completeness
    data["hmac_sha256"] = stored_hmac
    var bus = _get_event_bus()
    if bus and bus.has_signal("run_loaded"):
        bus.emit_signal("run_loaded", SAVE_PATH)
    return data

## Strict Roguelike Permadeath Protocol: Immediately wipes save files from physical disk
func wipe_run_save() -> bool:
    var wiped = false
    if FileAccess.file_exists(SAVE_PATH):
        DirAccess.remove_absolute(SAVE_PATH)
        wiped = true
    if FileAccess.file_exists(SAVE_TMP_PATH):
        DirAccess.remove_absolute(SAVE_TMP_PATH)
        wiped = true
        
    var bus = _get_event_bus()
    if bus and bus.has_signal("run_wiped"):
        bus.emit_signal("run_wiped")
    return wiped
