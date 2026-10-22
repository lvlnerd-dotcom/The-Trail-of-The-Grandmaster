class_name TurnManager
extends Node

## TurnManager: Deterministic turn-loop orchestrator and state machine.

enum TurnState {
    WAITING_FOR_INPUT,
    TARGETING,
    PLAYER_TURN,
    COMPANION_TURN,
    ENEMY_TURN,
    WORLD_TICK
}

signal state_changed(new_state: TurnState)
signal turn_advanced(turn_number: int)
signal floor_timer_ticked(remaining: int, total: int)

@export var floor_turn_budget_base: int = 800
@export var floor_turn_budget_per_floor: int = 15

var current_state: TurnState = TurnState.WAITING_FOR_INPUT
var turn_number: int = 1
var floor_total_turns: int = 785
var floor_turns_remaining: int = 785

var player: Node2D = null
var registered_enemies: Array[Node2D] = []
var registered_companions: Array[Node2D] = []

var enemies: Array[Node2D]:
    get:
        return registered_enemies

func _get_event_bus() -> Node:
    var loop = Engine.get_main_loop()
    if loop and loop is SceneTree:
        return (loop as SceneTree).root.get_node_or_null("EventBus")
    return null

func _ready() -> void:
    init_floor_timer(1)

func init_floor_timer(floor_num: int, walkable_tiles: int = -1) -> void:
    if walkable_tiles > 0:
        var dynamic_budget = 300 + int(walkable_tiles * 0.70) - (floor_num * 15)
        floor_total_turns = maxi(250, dynamic_budget)
    else:
        floor_total_turns = max(200, floor_turn_budget_base - (floor_num * floor_turn_budget_per_floor))
    floor_turns_remaining = floor_total_turns
    turn_number = 1
    current_state = TurnState.WAITING_FOR_INPUT
    emit_signal("floor_timer_ticked", floor_turns_remaining, floor_total_turns)
    var bus = _get_event_bus()
    if bus:
        bus.emit_signal("floor_turn_ticked", floor_turns_remaining, floor_total_turns)

func set_player(p_player: Node2D) -> void:
    player = p_player

func register_enemy(enemy: Node2D) -> void:
    if not registered_enemies.has(enemy):
        registered_enemies.append(enemy)

func unregister_enemy(enemy: Node2D) -> void:
    registered_enemies.erase(enemy)

func register_companion(companion: Node2D) -> void:
    if not registered_companions.has(companion):
        registered_companions.append(companion)

func unregister_companion(companion: Node2D) -> void:
    registered_companions.erase(companion)

func can_accept_player_input() -> bool:
    return current_state == TurnState.WAITING_FOR_INPUT

func is_targeting() -> bool:
    return current_state == TurnState.TARGETING

func begin_targeting() -> bool:
    if current_state != TurnState.WAITING_FOR_INPUT:
        return false
    _transition_to(TurnState.TARGETING)
    return true

func cancel_targeting() -> void:
    if current_state == TurnState.TARGETING:
        _transition_to(TurnState.WAITING_FOR_INPUT)

func submit_player_action(action_type: String, details: Dictionary = {}) -> void:
    if current_state != TurnState.WAITING_FOR_INPUT and current_state != TurnState.TARGETING:
        return
    
    _transition_to(TurnState.PLAYER_TURN)
    
    var bus = _get_event_bus()
    if bus:
        bus.emit_signal("player_acted", action_type, details)
    
    # After player action finishes animating/resolving, proceed through turn phases
    # In Phase 1, player movement notifies completion via on_player_action_finished
    if details.get("immediate_resolve", false):
        on_player_action_finished()


func on_player_action_finished() -> void:
    # Phase 2: Companions
    _transition_to(TurnState.COMPANION_TURN)
    _process_companion_turns()
    
    # Phase 3: Enemies
    _transition_to(TurnState.ENEMY_TURN)
    _process_enemy_turns()
    
    # Phase 4: World Tick (DoTs, Regen, Floor Clock)
    _transition_to(TurnState.WORLD_TICK)
    _process_world_tick()
    
    # Return to Waiting for input
    _transition_to(TurnState.WAITING_FOR_INPUT)

func _process_companion_turns() -> void:
    for companion in registered_companions:
        if is_instance_valid(companion) and companion.has_method("take_turn"):
            companion.take_turn()

func _process_enemy_turns() -> void:
    for enemy in registered_enemies:
        if is_instance_valid(enemy):
            if enemy.has_node("StatusEffectComponent"):
                var sec = enemy.get_node("StatusEffectComponent") as StatusEffectComponent
                if sec and sec.is_stunned():
                    continue
            if enemy.has_method("take_turn"):
                enemy.take_turn()

func _process_world_tick() -> void:
    turn_number += 1
    floor_turns_remaining -= 1
    
    # Tick Status Effects on Player and Registered Enemies
    if is_instance_valid(player) and player.has_node("StatusEffectComponent"):
        var p_sec = player.get_node("StatusEffectComponent") as StatusEffectComponent
        if p_sec:
            p_sec.tick_turn()

    for enemy in registered_enemies:
        if is_instance_valid(enemy) and enemy.has_node("StatusEffectComponent"):
            var e_sec = enemy.get_node("StatusEffectComponent") as StatusEffectComponent
            if e_sec:
                e_sec.tick_turn()

    emit_signal("turn_advanced", turn_number)
    emit_signal("floor_timer_ticked", floor_turns_remaining, floor_total_turns)
    
    var bus = _get_event_bus()
    if bus:
        bus.emit_signal("turn_started", turn_number)
        bus.emit_signal("floor_turn_ticked", floor_turns_remaining, floor_total_turns)
    
    if floor_turns_remaining <= 0:
        if bus:
            bus.emit_signal("floor_collapsed")

func _transition_to(next_state: TurnState) -> void:
    current_state = next_state
    emit_signal("state_changed", current_state)
    var bus = _get_event_bus()
    if bus:
        bus.emit_signal("state_changed", TurnState.keys()[current_state])
