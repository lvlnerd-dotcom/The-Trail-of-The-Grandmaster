@tool
extends McpTestSuite

## Milestone 5 Test Suite: Companion Recruitment & Pet Taming
## Tests:
## 1. Charisma squad cap formula and squad capacity enforcement (1 at 0-19, 2 at 20, 3 at 40, etc.).
## 2. Depth Tier stat scaling (Tiers 1-5), 5 mercenary archetypes, hire cost calculation, and gold hiring.
## 3. Beast Mastery taming probability math (skill vs difficulty + missing HP bonus up to +55%), and enemy conversion.
## 4. Tactical orders AI behavior: ALL_FOLLOW (passive), ALL_ATTACK (focus target), ALL_DEFEND (bodyguard).
## 5. Companion permadeath at 0 HP and friendly fire from player attacks.
## 6. Living companion persistence across floor descent.
## 7. Dynamic Charisma stat scaling recalculation on master attribute changes.

const Companion = preload("res://scripts/entities/Companion.gd")
const CompanionData = preload("res://scripts/resources/CompanionData.gd")
const AttributesData = preload("res://scripts/resources/AttributesData.gd")
const StatsComponent = preload("res://scripts/components/StatsComponent.gd")
const SkillComponent = preload("res://scripts/components/SkillComponent.gd")
const SkillData = preload("res://scripts/resources/SkillData.gd")
const InventoryComponent = preload("res://scripts/components/InventoryComponent.gd")
const CombatComponent = preload("res://scripts/components/CombatComponent.gd")
const VisionComponent = preload("res://scripts/components/VisionComponent.gd")
const DungeonGrid = preload("res://scripts/world/DungeonGrid.gd")
const TurnManager = preload("res://scripts/world/TurnManager.gd")
const Player = preload("res://scripts/entities/Player.gd")
const Enemy = preload("res://scripts/entities/Enemy.gd")
const BestiaryCatalog = preload("res://scripts/resources/BestiaryCatalog.gd")

func suite_name() -> String:
	return "milestone5_companions_and_taming"

func _create_test_grid(width: int = 20, height: int = 20) -> DungeonGrid:
	var g = track(DungeonGrid.new()) as DungeonGrid
	g.grid_width = width
	g.grid_height = height
	g.tile_size = Vector2i(32, 32)
	for y in range(height):
		for x in range(width):
			g.set_cell_walkable(Vector2i(x, y), true)
	g.rebuild_astar()
	return g

func _create_test_player(pos: Vector2i, grid: DungeonGrid, tm: TurnManager, cha: int = 10, gold: int = 300) -> Player:
	var player = track(Player.new()) as Player
	player.name = "TestPlayer"

	var stats = track(StatsComponent.new()) as StatsComponent
	stats.name = "StatsComponent"
	stats.attributes = track(AttributesData.new()) as AttributesData
	stats.attributes.strength = 12
	stats.attributes.dexterity = 12
	stats.attributes.constitution = 12
	stats.attributes.intelligence = 10
	stats.attributes.wisdom = 10
	stats.attributes.charisma = cha
	stats.max_hp_override = 100.0
	stats.current_hp = 100.0

	var skills = track(SkillComponent.new()) as SkillComponent
	skills.name = "SkillComponent"
	var bm = skills.register_or_unlock_skill(SkillData.SkillId.BEAST_MASTERY, 10.0)
	bm.level = 10.0

	var inv = track(InventoryComponent.new()) as InventoryComponent
	inv.name = "InventoryComponent"
	inv.gold = gold

	var combat = track(CombatComponent.new()) as CombatComponent
	combat.name = "CombatComponent"

	var vision = track(VisionComponent.new()) as VisionComponent
	vision.name = "VisionComponent"

	player.add_child(stats)
	player.add_child(skills)
	player.add_child(inv)
	player.add_child(combat)
	player.add_child(vision)

	player.stats = stats
	player.skills = skills
	player.inventory = inv
	player.combat = combat
	player.vision = vision

	player.init_grid_position(grid, pos, tm)
	return player

func _create_test_enemy(pos: Vector2i, grid: DungeonGrid, hp: float = 60.0, faction: int = 2) -> Enemy:
	var enemy = track(Enemy.new()) as Enemy
	enemy.name = "TestEnemy"
	enemy.enemy_name = "Cave Wolf"
	enemy.faction = faction
	enemy.set_meta("faction", faction)

	var stats = track(StatsComponent.new()) as StatsComponent
	stats.name = "StatsComponent"
	stats.attributes = track(AttributesData.new()) as AttributesData
	stats.max_hp_override = hp
	stats.current_hp = hp

	enemy.add_child(stats)
	enemy.stats = stats

	enemy.init_grid_position(grid, pos)
	return enemy

## ----------------------------------------------------------------------
## 1. Charisma Squad Cap Formula & Capacity Enforcement
## ----------------------------------------------------------------------
func test_charisma_companion_cap_formula() -> void:
	var attrs: AttributesData = track(AttributesData.new()) as AttributesData

	# Formula: 1 + floor(max(0, charisma) / 20)
	attrs.charisma = 0
	assert_eq(attrs.get_max_companions(), 1, "CHA 0 gives cap 1")

	attrs.charisma = 10
	assert_eq(attrs.get_max_companions(), 1, "CHA 10 gives cap 1")

	attrs.charisma = 19
	assert_eq(attrs.get_max_companions(), 1, "CHA 19 gives cap 1")

	attrs.charisma = 20
	assert_eq(attrs.get_max_companions(), 2, "CHA 20 gives cap 2")

	attrs.charisma = 39
	assert_eq(attrs.get_max_companions(), 2, "CHA 39 gives cap 2")

	attrs.charisma = 40
	assert_eq(attrs.get_max_companions(), 3, "CHA 40 gives cap 3")

	attrs.charisma = 60
	assert_eq(attrs.get_max_companions(), 4, "CHA 60 gives cap 4")

	attrs.charisma = 80
	assert_eq(attrs.get_max_companions(), 5, "CHA 80 gives cap 5")

	attrs.charisma = 100
	assert_eq(attrs.get_max_companions(), 6, "CHA 100 gives cap 6")

	# Capacity enforcement test
	var grid = _create_test_grid()
	var tm = track(TurnManager.new()) as TurnManager
	var player = _create_test_player(Vector2i(5, 5), grid, tm, 10, 500) # CHA 10 = Max 1 companion

	# Add 1 active companion to fill squad
	var c1 = track(Companion.new()) as Companion
	c1.setup(CompanionData.create_mercenary(), player, tm, grid, Vector2i(5, 6))
	assert_eq(tm.registered_companions.size(), 1, "1 companion registered")

	# Try hiring a 2nd companion -> rejected by capacity
	var c2 = track(Companion.new()) as Companion
	c2.is_hired = false
	c2.companion_data = CompanionData.create_mercenary()
	c2.turn_manager = tm
	var hire_res = c2.attempt_hire(player)
	assert_false(hire_res["success"], "Hiring must fail when squad is full")
	assert_true(hire_res["reason"].contains("capacity full"), "Reason mentions capacity full")
	assert_false(c2.is_hired, "c2 remains unhired")
	assert_eq(tm.registered_companions.size(), 1, "Squad count remains 1")

	# Increase Charisma to 20 -> capacity becomes 2 -> hiring succeeds
	player.stats.attributes.charisma = 20
	var hire_res2 = c2.attempt_hire(player)
	assert_true(hire_res2["success"], "Hiring succeeds after Charisma increased to 20")
	assert_true(c2.is_hired, "c2 is now hired")
	assert_eq(tm.registered_companions.size(), 2, "Squad count is now 2")

## ----------------------------------------------------------------------
## 2. Depth Tier Stat Scaling, Mercenary Archetypes & Gold Hiring
## ----------------------------------------------------------------------
func test_mercenary_tier_scaling_and_gold_hiring() -> void:
	# Tier multipliers: 1.0 + (T - 1) * 0.35
	assert_true(is_equal_approx(CompanionData.get_tier_multiplier(1), 1.00), "Tier 1 multiplier is 1.00")
	assert_true(is_equal_approx(CompanionData.get_tier_multiplier(2), 1.35), "Tier 2 multiplier is 1.35")
	assert_true(is_equal_approx(CompanionData.get_tier_multiplier(3), 1.70), "Tier 3 multiplier is 1.70")
	assert_true(is_equal_approx(CompanionData.get_tier_multiplier(4), 2.05), "Tier 4 multiplier is 2.05")
	assert_true(is_equal_approx(CompanionData.get_tier_multiplier(5), 2.40), "Tier 5 multiplier is 2.40")

	# Test 5 mercenary archetypes templates
	var vanguard = CompanionData.create_mercenary_for_tier(1, "vanguard_shieldsman")
	assert_eq(vanguard.companion_id, "vanguard_shieldsman")
	assert_eq(vanguard.base_hp, 120.0)
	assert_eq(vanguard.base_armor, 6)

	var marksman = CompanionData.create_mercenary_for_tier(2, "ironwood_marksman")
	assert_eq(marksman.companion_id, "ironwood_marksman")
	assert_eq(marksman.depth_tier, 2)
	assert_true(marksman.is_ranged)
	assert_eq(marksman.attack_range, 5)

	var halberdier = CompanionData.create_mercenary_for_tier(3, "halberdier_veteran")
	assert_eq(halberdier.companion_id, "halberdier_veteran")
	assert_eq(halberdier.base_damage_max, 20)

	var acolyte = CompanionData.create_mercenary_for_tier(4, "sun_sworn_acolyte")
	assert_eq(acolyte.companion_id, "sun_sworn_acolyte")
	assert_eq(acolyte.base_hp, 110.0)

	var cutthroat = CompanionData.create_mercenary_for_tier(5, "duskblade_cutthroat")
	assert_eq(cutthroat.companion_id, "duskblade_cutthroat")
	assert_true(cutthroat.base_dodge >= 35.0)

	# Hire cost formula: maxi(25, round(60 * T / MercantileMod))
	# Base MercantileMod = 1.0 at 10 CHA
	assert_eq(CompanionData.calculate_hire_cost(1, 1.0), 60, "Tier 1 cost is 60")
	assert_eq(CompanionData.calculate_hire_cost(2, 1.0), 120, "Tier 2 cost is 120")
	assert_eq(CompanionData.calculate_hire_cost(3, 1.0), 180, "Tier 3 cost is 180")
	assert_eq(CompanionData.calculate_hire_cost(4, 1.0), 240, "Tier 4 cost is 240")
	assert_eq(CompanionData.calculate_hire_cost(5, 1.0), 300, "Tier 5 cost is 300")

	# Test Mercantile discount at 20 CHA (mercantile_mod = 1.25 -> 60 / 1.25 = 48)
	var disc_cost = CompanionData.calculate_hire_cost(1, 1.25)
	assert_eq(disc_cost, 48, "Tier 1 cost with 1.25 mercantile mod is 48")

	# Gold deduction and hiring flow
	var grid = _create_test_grid()
	var tm = track(TurnManager.new()) as TurnManager
	var player = _create_test_player(Vector2i(2, 2), grid, tm, 10, 50) # 50 gold

	var merc = track(Companion.new()) as Companion
	merc.is_hired = false
	merc.companion_data = vanguard # Cost = 60 gold
	merc.turn_manager = tm

	# Fails due to insufficient gold (50 < 60)
	var fail_res = merc.attempt_hire(player)
	assert_false(fail_res["success"], "Hiring fails when gold is insufficient")
	assert_eq(player.inventory.gold, 50, "Player gold unchanged on failure")

	# Give player 100 gold -> succeeds
	player.inventory.gold = 100
	var ok_res = merc.attempt_hire(player)
	assert_true(ok_res["success"], "Hiring succeeds with sufficient gold")
	assert_eq(player.inventory.gold, 40, "100 - 60 = 40 gold remaining")
	assert_true(merc.is_hired, "Mercenary is now hired")
	assert_true(tm.registered_companions.has(merc), "Mercenary is registered in TurnManager")

## ----------------------------------------------------------------------
## 3. Beast Mastery Taming Math & Conversion
## ----------------------------------------------------------------------
func test_beast_mastery_taming_math_and_hp_scaling() -> void:
	var grid = _create_test_grid()
	var tm = track(TurnManager.new()) as TurnManager
	var player = _create_test_player(Vector2i(5, 5), grid, tm, 10, 100)
	var enemy = _create_test_enemy(Vector2i(5, 6), grid, 100.0, BestiaryCatalog.Faction.FACTION_BEAST)

	# Full HP (100/100): missing HP bonus is 0.0
	var chance_full = CombatComponent.calculate_tame_chance(player, enemy, 1)

	# Enemy damaged to 60/100 (40% missing HP): missing HP bonus is 0.40 * 0.55 = +0.22
	enemy.stats.current_hp = 60.0
	var chance_weak = CombatComponent.calculate_tame_chance(player, enemy, 1)

	assert_true(chance_weak > chance_full, "Weaker beast must have higher tame chance")
	var diff = chance_weak - chance_full
	assert_true(is_equal_approx(diff, 0.22), "Missing 40% HP adds exactly +0.22 (+22%) tame chance")

	# Critical HP (5/100 -> 95% missing HP): skill_ratio + 0.95*0.55 > 0.95 -> clamped at 0.95
	enemy.stats.current_hp = 5.0
	var chance_crit = CombatComponent.calculate_tame_chance(player, enemy, 1)
	assert_true(is_equal_approx(chance_crit, 0.95), "Clamped at 0.95 maximum tame chance")

	# Taming attempt with non-beast faction rejected
	var raider_enemy = _create_test_enemy(Vector2i(5, 7), grid, 100.0, BestiaryCatalog.Faction.FACTION_RAIDER)
	var tame_raider = player.combat.attempt_tame_beast(player, raider_enemy, 1)
	assert_false(tame_raider["success"], "Cannot tame non-beast faction")

	# Taming attempt with force_roll = 0.0 (guaranteed success)
	tm.register_enemy(enemy)
	var tame_res = player.combat.attempt_tame_beast(player, enemy, 1, 0.0)
	assert_true(tame_res["success"], "Taming succeeds with roll <= chance")
	assert_false(tm.registered_enemies.has(enemy), "Original enemy removed from registered_enemies")

	var companion = tame_res["companion"] as Companion
	assert_ne(companion, null, "Tamed companion node returned")
	assert_true(tm.registered_companions.has(companion), "Tamed companion registered with TurnManager")
	assert_true(companion.companion_data.companion_name.contains("Tamed"), "Name contains 'Tamed'")
	assert_eq(companion.grid_pos, Vector2i(5, 6), "Tamed companion occupies enemy grid pos")

## ----------------------------------------------------------------------
## 4. Tactical Orders AI Behavior (Follow, Attack, Defend)
## ----------------------------------------------------------------------
func test_companion_tactical_orders_follow_attack_defend() -> void:
	var grid = _create_test_grid()
	var tm = track(TurnManager.new()) as TurnManager
	var player = _create_test_player(Vector2i(5, 5), grid, tm, 20, 100)

	var companion = track(Companion.new()) as Companion
	companion.setup(CompanionData.create_mercenary(), player, tm, grid, Vector2i(5, 7))

	# 1. Order changed signal
	var order_state = {"order": -1}
	companion.order_changed.connect(func(new_order): order_state["order"] = int(new_order))
	companion.set_tactical_order(Companion.TacticalOrder.ALL_FOLLOW)
	assert_eq(order_state["order"], int(Companion.TacticalOrder.ALL_FOLLOW), "order_changed signal emitted")
	assert_eq(companion.current_order, Companion.TacticalOrder.ALL_FOLLOW)

	# 2. ALL_FOLLOW Behavior: Companions NEVER attack enemies, only follow
	var enemy = _create_test_enemy(Vector2i(5, 8), grid, 50.0) # Adjacent to companion at (5,7)
	tm.register_enemy(enemy)
	var initial_enemy_hp = enemy.stats.current_hp

	# Companion takes turn in ALL_FOLLOW mode: steps to (5,6) to follow player at (5,5)
	companion.take_turn()
	assert_eq(enemy.stats.current_hp, initial_enemy_hp, "ALL_FOLLOW: Companion does not attack adjacent enemy")
	assert_eq(companion.grid_pos, Vector2i(5, 6), "Companion stepped toward player")

	# 3. ALL_ATTACK Behavior: Attacks designated focus target
	companion.set_tactical_order(Companion.TacticalOrder.ALL_ATTACK)
	companion.is_moving = false
	# Place enemy adjacent to companion at (5,7)
	var focus_enemy = _create_test_enemy(Vector2i(5, 7), grid, 50.0)
	tm.register_enemy(focus_enemy)
	companion.designated_target = focus_enemy
	var hp_before_attack = focus_enemy.stats.current_hp
	companion.take_turn()
	assert_true(focus_enemy.stats.current_hp < hp_before_attack, "ALL_ATTACK: Companion attacks designated target")

	# 4. ALL_DEFEND Behavior: Attacks enemy threatening master
	companion.set_tactical_order(Companion.TacticalOrder.ALL_DEFEND)
	companion.is_moving = false
	var enemy_near_player = _create_test_enemy(Vector2i(4, 5), grid, 50.0) # Adjacent to player at (5,5)
	tm.register_enemy(enemy_near_player)
	# Reposition companion adjacent to this enemy
	companion.grid_pos = Vector2i(4, 6)
	grid.register_entity(companion, Vector2i(4, 6))
	var hp_before_defend = enemy_near_player.stats.current_hp
	companion.take_turn()
	assert_true(enemy_near_player.stats.current_hp < hp_before_defend, "ALL_DEFEND: Companion attacks enemy adjacent to master")

## ----------------------------------------------------------------------
## 5. Companion Permadeath & Friendly Fire
## ----------------------------------------------------------------------
func test_companion_permadeath_and_friendly_fire() -> void:
	var grid = _create_test_grid()
	var tm = track(TurnManager.new()) as TurnManager
	var player = _create_test_player(Vector2i(2, 2), grid, tm, 10, 100)

	var companion = track(Companion.new()) as Companion
	companion.setup(CompanionData.create_mercenary(), player, tm, grid, Vector2i(2, 3))
	assert_true(tm.registered_companions.has(companion), "Companion registered in TurnManager")

	# Friendly Fire from player attack
	var initial_hp = companion.current_hp
	player.combat.execute_attack(companion)
	assert_true(companion.current_hp < initial_hp, "Companion takes friendly fire damage from player attack")

	# Permadeath at 0 HP
	var loop = Engine.get_main_loop()
	var bus = (loop as SceneTree).root.get_node_or_null("EventBus") if loop and loop is SceneTree else null
	var death_state = {"died": false}
	companion.companion_died.connect(func(_c): death_state["died"] = true)

	companion.take_damage(500, player) # Massive overkill damage
	assert_true(companion.is_dead, "Companion is dead at 0 HP")
	assert_false(tm.registered_companions.has(companion), "Dead companion unregistered from TurnManager")
	assert_false(grid.is_occupied(Vector2i(2, 3)), "Dead companion unregistered from DungeonGrid")
	assert_true(death_state["died"], "companion_died signal fired")

## ----------------------------------------------------------------------
## 6. Living Companion Persistence Across Floor Descent
## ----------------------------------------------------------------------
func test_companion_floor_descent_persistence() -> void:
	var floor1_grid = _create_test_grid(15, 15)
	var tm = track(TurnManager.new()) as TurnManager
	var player = _create_test_player(Vector2i(3, 3), floor1_grid, tm, 20, 100)

	var comp_alive = track(Companion.new()) as Companion
	comp_alive.setup(CompanionData.create_mercenary(), player, tm, floor1_grid, Vector2i(3, 4))

	var comp_dead = track(Companion.new()) as Companion
	comp_dead.setup(CompanionData.create_hound(), player, tm, floor1_grid, Vector2i(4, 4))
	comp_dead.take_damage(500) # Permadeath

	# Verify only living companion is in registered_companions
	assert_true(tm.registered_companions.has(comp_alive), "comp_alive is in registered_companions")
	assert_false(tm.registered_companions.has(comp_dead), "comp_dead is NOT in registered_companions")

	# Simulate Floor 2 generation: New grid, new start cell
	var floor2_grid = _create_test_grid(15, 15)
	var new_start_cell = Vector2i(8, 8)
	player.init_grid_position(floor2_grid, new_start_cell, tm)

	# Preserved companions placed adjacent to start cell
	var surviving_companions = tm.registered_companions.duplicate()
	assert_eq(surviving_companions.size(), 1, "Exactly 1 surviving companion")

	var placed: bool = false
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var neighbor = new_start_cell + offset
		if floor2_grid.is_walkable(neighbor) and not floor2_grid.is_occupied(neighbor):
			var comp = surviving_companions[0] as Companion
			comp.grid = floor2_grid
			comp.grid_pos = neighbor
			floor2_grid.register_entity(comp, neighbor)
			placed = true
			break

	assert_true(placed, "Living companion repositioned on new floor")
	assert_true(floor2_grid.is_occupied(comp_alive.grid_pos), "Floor 2 grid has companion registered")
	assert_true(maxi(abs(comp_alive.grid_pos.x - new_start_cell.x), abs(comp_alive.grid_pos.y - new_start_cell.y)) == 1, "Companion is adjacent to player")

## ----------------------------------------------------------------------
## 7. Dynamic Charisma Stat Recalculation
## ----------------------------------------------------------------------
func test_dynamic_charisma_scaling_on_attribute_change() -> void:
	var grid = _create_test_grid()
	var tm = track(TurnManager.new()) as TurnManager
	var player = _create_test_player(Vector2i(5, 5), grid, tm, 10, 100) # Baseline 10 CHA (1.0x)

	var companion = track(Companion.new()) as Companion
	var data = CompanionData.create_vanguard_shieldsman(1) # Base HP 120, Armor 6, Dmg 10-14
	companion.setup(data, player, tm, grid, Vector2i(5, 6))

	assert_eq(companion.max_hp, 120.0, "At 10 CHA, max HP is 120")
	assert_eq(companion.armor, 6, "At 10 CHA, armor is 6")
	assert_eq(companion.damage_min, 10, "At 10 CHA, min dmg is 10")
	assert_eq(companion.damage_max, 14, "At 10 CHA, max dmg is 14")

	# Increase Charisma to 30 (+20 points -> ChaMod = 1.0 + 20 * 0.025 = 1.50x)
	player.stats.attributes.charisma = 30

	assert_eq(companion.max_hp, 180.0, "At 30 CHA (1.50x), max HP is 180")
	assert_eq(companion.armor, 9, "At 30 CHA (1.50x), armor is 9")
	assert_eq(companion.damage_min, 15, "At 30 CHA (1.50x), min dmg is 15")
	assert_eq(companion.damage_max, 21, "At 30 CHA (1.50x), max dmg is 21")
