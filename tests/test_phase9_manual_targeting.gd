@tool
extends McpTestSuite

## Phase 9 Test Suite: Manual Line-of-Fire Targeting, Obstruction Detection,
## Pass-Through Entity Interception, AoE Blast Footprints, and Targeting State Machine

func suite_name() -> String:
	return "phase9_manual_targeting"

func _create_test_grid(w: int = 25, h: int = 25) -> DungeonGrid:
	var grid = track(DungeonGrid.new()) as DungeonGrid
	grid.grid_width = w
	grid.grid_height = h
	grid.clear_grid()
	for y in range(h):
		for x in range(w):
			grid.set_cell_walkable(Vector2i(x, y), true)
	return grid

func _create_mock_combatant(p_name: String, cell: Vector2i, grid: DungeonGrid, hp: float = 50.0) -> BaseEntity:
	var ent = track(BaseEntity.new()) as BaseEntity
	ent.name = p_name
	ent.grid_pos = cell
	
	var stats = track(StatsComponent.new()) as StatsComponent
	stats.name = "StatsComponent"
	stats.attributes = AttributesData.new()
	ent.add_child(stats)
	stats._ready()
	stats.current_hp = hp
	stats.current_mana = 100.0
	
	var skills = track(SkillComponent.new()) as SkillComponent
	skills.name = "SkillComponent"
	ent.add_child(skills)
	skills._ready()
	
	var inv = track(InventoryComponent.new()) as InventoryComponent
	inv.name = "InventoryComponent"
	ent.add_child(inv)
	
	var combat = track(CombatComponent.new()) as CombatComponent
	combat.name = "CombatComponent"
	ent.add_child(combat)
	
	var spell_cast = track(SpellCastingComponent.new()) as SpellCastingComponent
	spell_cast.name = "SpellCastingComponent"
	ent.add_child(spell_cast)
	
	grid.register_entity(ent, cell)
	return ent

func test_line_of_fire_unobstructed_and_wall_obstruction() -> void:
	var grid = _create_test_grid(25, 25)
	var origin = Vector2i(5, 5)
	var target = Vector2i(10, 5)
	
	# 1. Clear unobstructed line of fire
	var lof_clear = TargetingSystem.calculate_line_of_fire(origin, target, grid, 6, 0)
	assert_true(lof_clear["is_valid"], "Unobstructed target within range must be valid")
	assert_eq(lof_clear["blocker_type"], TargetingSystem.BlockerType.NONE, "No blocker on open floor")
	assert_eq(lof_clear["effective_target_cell"], target, "Effective target cell equals cursor cell when unobstructed")
	assert_eq(lof_clear["clear_cells"].size(), 5, "5 clear cells from (6,5) to (10,5)")
	assert_eq(lof_clear["blocked_cells"].size(), 0, "0 blocked cells on clear ray")
	
	# 2. Place a solid wall at (8, 5) blocking the path to (10, 5)
	grid.set_cell_walkable(Vector2i(8, 5), false)
	var lof_wall = TargetingSystem.calculate_line_of_fire(origin, target, grid, 6, 0)
	assert_false(lof_wall["is_valid"], "Target behind a solid wall must be invalid")
	assert_eq(lof_wall["blocker_type"], TargetingSystem.BlockerType.WALL, "Blocker type must be WALL")
	assert_eq(lof_wall["blocker_cell"], Vector2i(8, 5), "Blocker cell is the wall at (8, 5)")
	assert_eq(lof_wall["effective_target_cell"], Vector2i(7, 5), "Effective stop cell is (7, 5) right before the wall")
	assert_true(lof_wall["blocked_cells"].has(Vector2i(8, 5)), "Wall cell is in blocked_cells")
	assert_true(lof_wall["blocked_cells"].has(Vector2i(10, 5)), "Target cell behind wall is in blocked_cells")
	
	# 3. Out of range check
	grid.set_cell_walkable(Vector2i(8, 5), true)
	var lof_oor = TargetingSystem.calculate_line_of_fire(origin, Vector2i(15, 5), grid, 6, 0)
	assert_false(lof_oor["is_valid"], "Target at distance 10 with max_range 6 must be invalid")
	assert_eq(lof_oor["blocker_type"], TargetingSystem.BlockerType.OUT_OF_RANGE, "Blocker type must be OUT_OF_RANGE")

func test_pass_through_obstacle_entity_interception_ranged_and_spells() -> void:
	var grid = _create_test_grid(25, 25)
	var player = _create_mock_combatant("Player", Vector2i(5, 5), grid, 100.0)
	var enemy_front = _create_mock_combatant("FrontGoblin", Vector2i(8, 5), grid, 50.0)
	var enemy_back = _create_mock_combatant("BackArcher", Vector2i(10, 5), grid, 50.0)
	
	# Give player high marksmanship/arcane skill so hits are deterministic
	var skills = player.get_node("SkillComponent") as SkillComponent
	skills.register_or_unlock_skill(SkillData.SkillId.MARKSMANSHIP, 100.0)
	skills.register_or_unlock_skill(SkillData.SkillId.ARCANE_MAGIC, 50.0)
	
	# 1. Verify Line-of-Fire raycast detects intermediate entity at (8, 5) when aiming at (10, 5)
	var lof = TargetingSystem.calculate_line_of_fire(Vector2i(5, 5), Vector2i(10, 5), grid, 6, 0, false, false, player)
	assert_true(lof["is_valid"], "Aiming past an intermediate entity within range is valid (intercepted)")
	assert_eq(lof["blocker_type"], TargetingSystem.BlockerType.ENTITY, "Blocker type must be ENTITY")
	assert_eq(lof["blocker_cell"], Vector2i(8, 5), "Blocker cell must be (8, 5)")
	assert_eq(lof["blocker_entity"], enemy_front, "Blocker entity must be enemy_front")
	assert_eq(lof["effective_target_cell"], Vector2i(8, 5), "Effective target cell redirects to front blocking entity (8, 5)")
	assert_true(lof["blocked_cells"].has(Vector2i(9, 5)), "(9, 5) behind blocker is marked occluded")
	assert_true(lof["blocked_cells"].has(Vector2i(10, 5)), "(10, 5) behind blocker is marked occluded")
	
	# 2. Confirm Ranged Weapon Attack aimed at BackArcher (10, 5) -> FrontGoblin (8, 5) absorbs the shot!
	var pistol = ItemData.create_flintlock_pistol()
	pistol.accuracy_bonus = 1.0 # Ensure 95% cap hit
	var combat = player.get_node("CombatComponent") as CombatComponent
	var r_res = combat.execute_ranged_attack(Vector2i(5, 5), Vector2i(10, 5), grid, pistol, null)
	assert_true(r_res["success"], "Ranged attack executed")
	assert_true(r_res["intercepted"], "Ranged attack flagged as intercepted")
	assert_eq(r_res["effective_target_cell"], Vector2i(8, 5), "Ranged attack impacted (8, 5)")
	assert_eq(r_res["defender"], enemy_front, "FrontGoblin became the defender and absorbed the shot")
	var back_stats = enemy_back.get_node("StatsComponent") as StatsComponent
	assert_eq(back_stats.current_hp, 50.0, "BackArcher took 0 damage because FrontGoblin blocked the line of fire")
	
	# 3. Confirm Single-Target Spell (Magic Missile) aimed at BackArcher (10, 5) -> FrontGoblin (8, 5) absorbs the spell!
	var front_stats = enemy_front.get_node("StatsComponent") as StatsComponent
	var hp_before_spell = front_stats.current_hp
	var spell_cast = player.get_node("SpellCastingComponent") as SpellCastingComponent
	var mm = SpellData.create_magic_missile()
	spell_cast.learn_spell(mm)
	var s_res = spell_cast.cast_spell(mm, Vector2i(10, 5), grid, 0.99)
	assert_true(s_res["success"], "Magic Missile cast succeeded")
	assert_true(s_res["intercepted"], "Magic Missile was intercepted by FrontGoblin")
	assert_eq(s_res["effective_target_cell"], Vector2i(8, 5), "Magic Missile impacted (8, 5)")
	assert_true(front_stats.current_hp < hp_before_spell, "FrontGoblin absorbed Magic Missile damage")
	assert_eq(back_stats.current_hp, 50.0, "BackArcher remained at full 50 HP")

func test_aoe_radius_preview_and_interception_shift() -> void:
	var grid = _create_test_grid(25, 25)
	var player = _create_mock_combatant("Player", Vector2i(5, 5), grid, 100.0)
	
	# 1. Unobstructed 3x3 AoE preview centered at (9, 5)
	var lof_aoe = TargetingSystem.calculate_line_of_fire(Vector2i(5, 5), Vector2i(9, 5), grid, 6, 1, false, false, player)
	assert_true(lof_aoe["is_valid"], "AoE target at (9, 5) is valid")
	assert_eq(lof_aoe["aoe_cells"].size(), 9, "Radius 1 AoE footprint has 9 tiles (3x3)")
	assert_true(lof_aoe["aoe_cells"].has(Vector2i(8, 4)), "Top-left corner of 3x3 AoE included")
	assert_true(lof_aoe["aoe_cells"].has(Vector2i(10, 6)), "Bottom-right corner of 3x3 AoE included")
	
	# 2. Place an intercepting enemy at (7, 5) and aim an Alchemical Fire Bomb at (10, 5)
	var blocker_enemy = _create_mock_combatant("BlockerOrc", Vector2i(7, 5), grid, 60.0)
	var flank_enemy = _create_mock_combatant("FlankOrc", Vector2i(7, 6), grid, 60.0)
	var distant_enemy = _create_mock_combatant("DistantOrc", Vector2i(10, 5), grid, 60.0)
	
	var bomb = ItemData.create_alchemical_bomb(2)
	var combat = player.get_node("CombatComponent") as CombatComponent
	var bomb_res = combat.execute_ranged_attack(Vector2i(5, 5), Vector2i(10, 5), grid, null, bomb)
	
	assert_true(bomb_res["success"], "Alchemical bomb throw succeeded")
	assert_true(bomb_res["intercepted"], "Bomb intercepted at (7, 5)")
	assert_eq(bomb_res["effective_target_cell"], Vector2i(7, 5), "Bomb detonated at blocker's tile (7, 5)")
	assert_eq(bomb.quantity, 1, "1 bomb consumed from stack")
	
	var blocker_hp = (blocker_enemy.get_node("StatsComponent") as StatsComponent).current_hp
	var flank_hp = (flank_enemy.get_node("StatsComponent") as StatsComponent).current_hp
	var distant_hp = (distant_enemy.get_node("StatsComponent") as StatsComponent).current_hp
	assert_true(blocker_hp < 60.0, "BlockerOrc at (7, 5) took AoE blast damage")
	assert_true(flank_hp < 60.0, "FlankOrc at (7, 6) adjacent to blocker took 3x3 AoE blast damage")
	assert_eq(distant_hp, 60.0, "DistantOrc at (10, 5) was spared because bomb was intercepted at (7, 5)")

func test_manual_targeting_state_machine_and_hotbar_integration() -> void:
	var grid = _create_test_grid(25, 25)
	var turn_mgr = track(TurnManager.new()) as TurnManager
	turn_mgr._ready()
	
	var player = _create_mock_combatant("Player", Vector2i(5, 5), grid, 100.0)
	var enemy = _create_mock_combatant("TargetGoblin", Vector2i(8, 5), grid, 40.0)
	turn_mgr.set_player(player)
	turn_mgr.register_enemy(enemy)
	
	var targeting = track(TargetingSystem.new()) as TargetingSystem
	targeting.setup(player, grid, turn_mgr)
	
	var hotbar = track(HotbarBar.new()) as HotbarBar
	hotbar._ready()
	hotbar.player = player
	
	var mm_spell = SpellData.create_magic_missile()
	(player.get_node("SpellCastingComponent") as SpellCastingComponent).learn_spell(mm_spell)
	hotbar.set_slot_spell(0, mm_spell)
	
	var knives = ItemData.new("throwing_daggers", "Dagger Pouch", ItemData.ItemType.AMMO, ItemData.EquipSlot.AMMUNITION, 1.5, 5)
	knives.weapon_type = AttributesData.WeaponType.THROWN
	knives.range_tiles = 4
	hotbar.set_slot_item(1, knives)
	
	# 1. Triggering hotbar slot without target_cell must NOT auto-fire; it must request manual targeting
	var slot0_trigger = hotbar.trigger_slot(0)
	assert_false(slot0_trigger["success"], "Triggering ranged spell without target_cell does not immediately resolve")
	assert_true(slot0_trigger.get("requires_targeting", false), "Ranged spell requests manual targeting mode")
	
	var slot1_trigger = hotbar.trigger_slot(1)
	assert_false(slot1_trigger["success"], "Triggering thrown ammo without target_cell does not immediately resolve")
	assert_true(slot1_trigger.get("requires_targeting", false), "Thrown ammo requests manual targeting mode")
	
	# 2. Start targeting -> TurnManager enters TurnState.TARGETING
	var start_ok = targeting.start_targeting(slot0_trigger["context"])
	assert_true(start_ok, "TargetingSystem started")
	assert_eq(turn_mgr.current_state, TurnManager.TurnState.TARGETING, "TurnManager transitioned to TARGETING")
	assert_eq(targeting.cursor_cell, Vector2i(8, 5), "Initial cursor snaps to visible enemy in range (8, 5)")
	
	# 3. Step cursor manually with keyboard directional input
	targeting.step_cursor(Vector2i(0, 1))
	assert_eq(targeting.cursor_cell, Vector2i(8, 6), "Cursor stepped South to (8, 6)")
	
	# 4. Cancel targeting -> returns to WAITING_FOR_INPUT with 0 turns and 0 mana spent
	var initial_turn = turn_mgr.turn_number
	targeting.cancel_targeting()
	assert_false(targeting.is_active, "TargetingSystem is no longer active after cancel")
	assert_eq(turn_mgr.current_state, TurnManager.TurnState.WAITING_FOR_INPUT, "TurnManager returned to WAITING_FOR_INPUT")
	assert_eq(turn_mgr.turn_number, initial_turn, "Canceling targeting does not consume a turn")
	
	# 5. Re-enter targeting and confirm on (8, 5)
	targeting.start_targeting(slot0_trigger["context"])
	targeting.update_cursor(Vector2i(8, 5))
	var conf = targeting.confirm_target()
	assert_true(conf["confirmed"], "Target confirmation succeeded")
	assert_eq(conf["effective_target_cell"], Vector2i(8, 5), "Confirmed effective cell is (8, 5)")
	
	hotbar.queue_free()
