extends Node

## EventBus: Central nervous system for decoupled inter-system signals

# Turn loop signals
signal turn_started(turn_number: int)
signal turn_ended(turn_number: int)
signal state_changed(new_state: String)

# Entity action signals
signal player_acted(action_name: String, details: Dictionary)
signal entity_moved(entity: Node2D, from_cell: Vector2i, to_cell: Vector2i)
signal entity_bumped(entity: Node2D, target_cell: Vector2i)
signal entity_damaged(target: Node2D, attacker: Node2D, amount: int)
signal entity_died(entity: Node2D)

# Progression signals
signal kill_exp_gained(amount: int, current_exp: int, required_exp: int)
signal player_leveled_up(new_level: int, unallocated_points: int)
signal skill_xp_gained(skill_name: String, amount: float, current_level: float)
signal keystone_unlocked(skill_name: String, milestone: int)

# Floor & Environment signals
signal floor_turn_ticked(remaining_turns: int, total_turns: int)
signal floor_collapsed()
signal collapse_stage_changed(stage: int)
signal floor_descended(next_floor: int)
signal secret_discovered(tile_cell: Vector2i, secret_type: String)
signal trap_triggered(trap_cell: Vector2i, victim: Node2D)
signal shrine_activated(shrine_name: String, player: Node2D)
signal shrine_covenant_formed(shrine_name: String, player: Node2D, bonus_mult: float, penalty_mult: float)
signal deity_covenant_broken(old_deity_name: String)

# Phase 5: Magic Signals
signal spell_cast(spell_data: Resource, caster: Node2D, target_cell: Vector2i)
signal spell_hit(spell_data: Resource, target: Node2D, final_value: int, is_crit: bool)
signal spell_fizzled(spell_data: Resource, caster: Node2D)
signal spell_learned(spell_data: Resource)

# Phase 5: Companion Signals
signal companion_registered(companion: Node2D)
signal companion_unregistered(companion: Node2D)
signal companion_acted(companion: Node2D, action_type: String)
signal companion_downed(companion: Node2D)

# Phase 5: Merchant & Economy Signals
signal shop_opened(merchant: Node2D, shop_data: Resource)
signal shop_closed()
signal item_purchased(item_data: Resource, price: int)
signal item_sold(item_data: Resource, price: int)

# Phase 6: Class Specialization & Persistence Signals
signal class_selected(class_id: String, selected_class_name: String)
signal class_unlocked(class_id: String)
signal run_saved(filepath: String)
signal run_loaded(filepath: String)
signal run_wiped()
signal save_corrupted(reason: String)
signal meta_profile_saved()
signal meta_achievement_unlocked(achievement_id: String, title: String)
signal bestiary_entry_updated(creature_id: String, tier: int)

# Phase 7: Boss, Audio, Polish & Victory Signals
signal boss_phase_changed(boss: Node2D, new_phase: int)
signal boss_defeated(boss: Node2D)
signal victory_achieved(summary: Dictionary)
signal camera_trauma_requested(amount: float, direction: Vector2)
signal decal_requested(decal_type: String, cell: Vector2i)
signal audio_play_requested(sound_name: String, bus_name: String)
