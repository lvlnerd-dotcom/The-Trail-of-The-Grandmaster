class_name Enemy
extends BaseEntity

## Enemy: Turn-based AI entity with tactical states (Idle, Chase, Attack, Flee, Hesitant).

enum AIState {
    IDLE,
    PATROL,
    CHASE,
    ATTACK,
    FLEE
}

@export var enemy_name: String = "Dungeon Goblin"
@export var base_kill_exp: int = 35
@export var vision_range: int = 7
@export var is_undead: bool = false

@onready var stats: StatsComponent = $StatsComponent
@onready var skills: SkillComponent = $SkillComponent
@onready var combat: CombatComponent = $CombatComponent
@onready var inventory: InventoryComponent = $InventoryComponent
@onready var vision: VisionComponent = $VisionComponent

var ai_state: AIState = AIState.IDLE
var target_player: Player = null

# Intimidation debuff state from Charisma checks
var intimidation_status: String = "" # "TERRIFIED" or "HESITANT"
var intimidation_turns_remaining: int = 0

func _ready() -> void:
    super._ready()
    if stats:
        stats.entity_died.connect(_on_death)

func setup_enemy(p_name: String, p_hp: float, p_exp: int, p_str: int = 8, p_dex: int = 8) -> void:
    enemy_name = p_name
    base_kill_exp = p_exp
    
    if not stats:
        stats = get_node_or_null("StatsComponent") as StatsComponent
    if not inventory:
        inventory = get_node_or_null("InventoryComponent") as InventoryComponent
    if not skills:
        skills = get_node_or_null("SkillComponent") as SkillComponent
    if not combat:
        combat = get_node_or_null("CombatComponent") as CombatComponent
    if not vision:
        vision = get_node_or_null("VisionComponent") as VisionComponent
    
    if stats and stats.attributes:
        stats.attributes.strength = p_str
        stats.attributes.dexterity = p_dex
        stats.current_hp = p_hp
        
    # Give basic crude weapon
    var crude_blade = ItemData.new("crude_blade", "Crude Blade", ItemData.ItemType.WEAPON, ItemData.EquipSlot.MAIN_HAND, 2.0)
    crude_blade.base_damage_min = 2
    crude_blade.base_damage_max = 5
    if inventory:
        inventory.equip_item(crude_blade)

func apply_intimidation(status_type: String, duration_turns: int) -> void:
    intimidation_status = status_type
    intimidation_turns_remaining = duration_turns
    if status_type == "TERRIFIED":
        ai_state = AIState.FLEE
    
    var color = Color(0.9, 0.4, 1.0)
    if combat:
        combat.emit_signal("floating_text_requested", status_type + "!", color, global_position)

func take_turn() -> void:
    if not stats or stats.current_hp <= 0.0 or not grid:
        return
        
    # Ensure any ongoing tween is finalized so is_moving is never stale across turns
    if move_tween and move_tween.is_valid():
        move_tween.kill()
        global_position = grid.grid_to_world(grid_pos)
    is_moving = false
        
    # 1. Process Intimidation Debuff
    if intimidation_turns_remaining > 0:
        intimidation_turns_remaining -= 1
        if intimidation_status == "HESITANT":
            # Skip turn due to demoralization
            if combat:
                combat.emit_signal("floating_text_requested", "Hesitating...", Color(0.8, 0.8, 0.8), global_position)
            return
        elif intimidation_status == "TERRIFIED":
            _execute_flee_from_player()
            return
            
    intimidation_status = ""
    
    # 2. Acquire Player Reference
    if not target_player and turn_manager and turn_manager.player:
        target_player = turn_manager.player as Player
        
    if not target_player or target_player.stats.current_hp <= 0.0:
        ai_state = AIState.IDLE
        return
        
    # 3. Vision & Line-of-Sight Check
    var can_see = vision.can_see_entity(grid, grid_pos, target_player)
    if not can_see:
        ai_state = AIState.IDLE
        return
        
    # 4. Tactical Decisions: Chebyshev distance allows all 8 adjacent tiles (orthogonal & diagonal) to attack
    var dx = abs(grid_pos.x - target_player.grid_pos.x)
    var dy = abs(grid_pos.y - target_player.grid_pos.y)
    var chebyshev_dist = maxi(dx, dy)
    
    var weapon = inventory.get_equipped_weapon() if inventory else null
    var attack_range = weapon.range_tiles if (weapon and weapon.range_tiles > 1) else 1
    
    if chebyshev_dist <= attack_range:
        # Adjacent or in weapon range: Attack Player!
        ai_state = AIState.ATTACK
        _execute_melee_attack(target_player)
    else:
        # In range: Pursue Player
        ai_state = AIState.CHASE
        _execute_chase_player()

func _execute_melee_attack(player_entity: Player) -> void:
    facing_direction = player_entity.grid_pos - grid_pos
    _play_bump_animation(facing_direction)
    
    var weapon = inventory.get_equipped_weapon()
    var result = combat.execute_attack(player_entity, weapon)
    
    var bus = _get_event_bus()
    if bus:
        var msg = "%s attacks Player for %d damage!" % [enemy_name, result["damage"]] if result["hit"] else "%s attacks Player, but Player %s!" % [enemy_name, result["defense_type"]]
        bus.emit_signal("player_acted", "enemy_attack", {"message": msg, "result": result})

func _execute_chase_player() -> void:
    var path = grid.find_path(grid_pos, target_player.grid_pos)
    # path[0] is current pos, path[1] is next step
    if path.size() >= 2:
        var next_step = path[1]
        var dir = next_step - grid_pos
        if grid.can_enter(next_step):
            try_move(dir)
            return
            
    # Flanking fallback: If direct path is blocked by another enemy,
    # find an open neighbor step that moves closer to the player
    var cur_dist = maxi(abs(grid_pos.x - target_player.grid_pos.x), abs(grid_pos.y - target_player.grid_pos.y))
    var directions = [
        Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
        Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)
    ]
    var best_dir = Vector2i.ZERO
    var best_dist = cur_dist
    for d in directions:
        var cand = grid_pos + d
        if grid.can_enter(cand):
            var d_dist = maxi(abs(cand.x - target_player.grid_pos.x), abs(cand.y - target_player.grid_pos.y))
            if d_dist < best_dist:
                best_dist = d_dist
                best_dir = d
    if best_dir != Vector2i.ZERO:
        try_move(best_dir)

func _execute_flee_from_player() -> void:
    if not target_player:
        return
    # Flee in opposite direction from player
    var away_dir = grid_pos - target_player.grid_pos
    var step_x = clampi(away_dir.x, -1, 1)
    var step_y = clampi(away_dir.y, -1, 1)
    var step = Vector2i(step_x, step_y)
    
    if step != Vector2i.ZERO and grid.can_enter(grid_pos + step):
        try_move(step)
    else:
        # Try alternate escape neighbors
        var neighbors = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
        for n in neighbors:
            if grid.can_enter(grid_pos + n):
                try_move(n)
                break

func _on_death(_victim: Node2D) -> void:
    # Unregister from grid and turn loop
    if grid:
        grid.unregister_entity(self, grid_pos)
    if turn_manager:
        turn_manager.unregister_enemy(self)
        
    # Award kill EXP to player
    if turn_manager and turn_manager.player:
        var player_stats = turn_manager.player.get_node_or_null("StatsComponent") as StatsComponent
        if player_stats and player_stats.attributes:
            player_stats.attributes.add_kill_exp(base_kill_exp)
            
    # Visual fade out
    var tween = create_tween()
    tween.tween_property(self, "modulate:a", 0.0, 0.2)
    tween.finished.connect(queue_free)
