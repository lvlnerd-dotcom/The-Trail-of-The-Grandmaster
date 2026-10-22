@tool
extends McpTestSuite

## Milestone 3 Test Suite: Biomes, Bestiary & Tactical AI
## 20 Run-Locked Biomes (5 Brackets x 4 Biomes), Themed Bestiary Templates,
## Ranged Kiting & Sidearm Swap, 1-Turn Telegraphed AoE Spells,
## Cross-Faction Infighting, Stealth Ambushing, Intelligent Morale Fleeing,
## 2.0x Radiant/Silver Undead Vulnerability, Elite Affixes & Mini-Bosses.

const BiomeData = preload("res://scripts/resources/BiomeData.gd")
const BestiaryCatalog = preload("res://scripts/resources/BestiaryCatalog.gd")
const ItemData = preload("res://scripts/resources/ItemData.gd")
const WeaponManifest = preload("res://scripts/resources/WeaponManifest.gd")
const SkillData = preload("res://scripts/resources/SkillData.gd")
const SpellData = preload("res://scripts/resources/SpellData.gd")
const AttributesData = preload("res://scripts/resources/AttributesData.gd")

const StatsComponent = preload("res://scripts/components/StatsComponent.gd")
const SkillComponent = preload("res://scripts/components/SkillComponent.gd")
const InventoryComponent = preload("res://scripts/components/InventoryComponent.gd")
const CombatComponent = preload("res://scripts/components/CombatComponent.gd")
const VisionComponent = preload("res://scripts/components/VisionComponent.gd")
const SpellCastingComponent = preload("res://scripts/components/SpellCastingComponent.gd")

const DungeonGrid = preload("res://scripts/world/DungeonGrid.gd")
const DungeonGenerator = preload("res://scripts/world/DungeonGenerator.gd")
const TurnManager = preload("res://scripts/world/TurnManager.gd")
const Enemy = preload("res://scripts/entities/Enemy.gd")
const Player = preload("res://scripts/entities/Player.gd")

func suite_name() -> String:
	return "milestone3_biomes_bestiary_tactical_ai"

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

func _create_test_player(pos: Vector2i, grid: DungeonGrid, tm: TurnManager, perception_lvl: float = 10.0) -> Player:
	var player = track(Player.new()) as Player
	player.name = "TestPlayer"
	
	var stats = track(StatsComponent.new()) as StatsComponent
	stats.name = "StatsComponent"
	stats.attributes = track(AttributesData.new()) as AttributesData
	stats.attributes.strength = 12
	stats.attributes.dexterity = 12
	stats.attributes.constitution = 12
	stats.attributes.wisdom = 12
	stats.attributes.intelligence = 12
	stats.max_hp_override = 100.0
	stats.current_hp = 100.0
	
	var skills = track(SkillComponent.new()) as SkillComponent
	skills.name = "SkillComponent"
	var perc = skills.register_or_unlock_skill(SkillData.SkillId.PERCEPTION, perception_lvl)
	perc.level = perception_lvl
	
	var inv = track(InventoryComponent.new()) as InventoryComponent
	inv.name = "InventoryComponent"
	
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
	tm.set_player(player)
	return player

func _create_test_enemy(template_id: String, pos: Vector2i, grid: DungeonGrid, tm: TurnManager, is_elite: bool = false, affix: String = "") -> Enemy:
	var enemy = track(Enemy.new()) as Enemy
	enemy.name = "TestEnemy_" + template_id
	
	var stats = track(StatsComponent.new()) as StatsComponent
	stats.name = "StatsComponent"
	stats.attributes = track(AttributesData.new()) as AttributesData
	
	var skills = track(SkillComponent.new()) as SkillComponent
	skills.name = "SkillComponent"
	
	var inv = track(InventoryComponent.new()) as InventoryComponent
	inv.name = "InventoryComponent"
	
	var combat = track(CombatComponent.new()) as CombatComponent
	combat.name = "CombatComponent"
	
	var vision = track(VisionComponent.new()) as VisionComponent
	vision.name = "VisionComponent"
	
	enemy.add_child(stats)
	enemy.add_child(skills)
	enemy.add_child(inv)
	enemy.add_child(combat)
	enemy.add_child(vision)
	enemy.stats = stats
	enemy.skills = skills
	enemy.inventory = inv
	enemy.combat = combat
	enemy.vision = vision
	
	var template = BestiaryCatalog.get_monster_template(template_id)
	enemy.setup_from_template(template, 2, is_elite, affix)
	enemy.init_grid_position(grid, pos, tm)
	tm.register_enemy(enemy)
	return enemy

## Test 1: Run-Locked Biome Selection across 5 depth brackets
func test_run_locked_biome_selection() -> void:
	var all_biomes = BiomeData.get_all_biomes()
	assert_eq(all_biomes.size(), 20, "Must define exactly 20 biomes")
	
	for bracket in range(1, 6):
		var b_list = BiomeData.get_biomes_for_bracket(bracket)
		assert_eq(b_list.size(), 4, "Each depth bracket (1..5) must contain exactly 4 biomes (Bracket %d)" % bracket)
		
	# Test deterministic roll
	var run1 = BiomeData.roll_run_biomes(12345)
	var run2 = BiomeData.roll_run_biomes(12345)
	for i in range(5):
		assert_eq(run1[i].biome_id, run2[i].biome_id, "Identical seed must yield identical biome selections")

	# Test bracket consistency across floors via GameManager
	var gm_script = load("res://scripts/autoload/GameManager.gd")
	var gm = track(gm_script.new())
	gm.start_new_run(98765)
	var f1_biome = gm.get_biome_for_floor(1)
	var f2_biome = gm.get_biome_for_floor(2)
	var f4_biome = gm.get_biome_for_floor(4)
	assert_eq(f1_biome.biome_id, f2_biome.biome_id, "Floors 1 and 2 must share the same run-locked biome")
	assert_eq(f1_biome.biome_id, f4_biome.biome_id, "Floors 1 and 4 must share the same run-locked biome")
	
	var f5_biome = gm.get_biome_for_floor(5)
	var f8_biome = gm.get_biome_for_floor(8)
	assert_eq(f5_biome.biome_id, f8_biome.biome_id, "Floors 5 and 8 must share the bracket 2 biome")
	assert_true(f1_biome.biome_id != f5_biome.biome_id, "Bracket 1 and Bracket 2 biomes should differ")

## Test 2: Ranged Kiting and Dynamic Melee Sidearm Swap
func test_ranged_kiting_and_sidearm_swap() -> void:
	var grid = _create_test_grid(20, 20)
	var tm = track(TurnManager.new()) as TurnManager
	
	# Place player at (10, 10)
	var player = _create_test_player(Vector2i(10, 10), grid, tm)
	
	# Place Bone Archer (RANGED_ARCHER) at distance 2: (10, 8)
	var archer = _create_test_enemy("bone_archer", Vector2i(10, 8), grid, tm)
	assert_eq(archer.archetype, BestiaryCatalog.Archetype.RANGED_ARCHER, "Bone Archer is RANGED_ARCHER")
	assert_true(archer.ranged_weapon != null, "Archer has ranged weapon")
	assert_true(archer.sidearm_weapon != null, "Archer has sidearm weapon")
	
	# 1. Distance == 2: Archer should kite retreat away from player
	archer.take_turn()
	var dist_after_kite = maxi(abs(archer.grid_pos.x - player.grid_pos.x), abs(archer.grid_pos.y - player.grid_pos.y))
	assert_true(dist_after_kite >= 3, "Archer at distance 2 must kite retreat to distance >= 3 (now at dist %d)" % dist_after_kite)
	
	# 2. Player closes in to adjacent melee distance 1: place archer at (10, 9)
	grid.unregister_entity(archer, archer.grid_pos)
	archer.init_grid_position(grid, Vector2i(10, 9), tm)
	assert_eq(maxi(abs(archer.grid_pos.x - player.grid_pos.x), abs(archer.grid_pos.y - player.grid_pos.y)), 1, "Now adjacent at dist 1")
	
	archer.take_turn()
	var current_weapon = archer.inventory.get_equipped_weapon()
	assert_eq(current_weapon.item_id, archer.sidearm_weapon.item_id, "At distance 1, archer must dynamically swap to sidearm (dagger)")
	
	# 3. Player retreats to distance >= 3: place archer at (10, 5) (dist 5)
	grid.unregister_entity(archer, archer.grid_pos)
	archer.init_grid_position(grid, Vector2i(10, 5), tm)
	archer.take_turn()
	var swapped_back = archer.inventory.get_equipped_weapon()
	assert_eq(swapped_back.item_id, archer.ranged_weapon.item_id, "At distance >= 3, archer must swap back to ranged weapon")

## Test 3: 1-Turn Telegraphed AoE Spell Channels and Detonation
func test_one_turn_telegraphed_aoe_spell() -> void:
	var grid = _create_test_grid(20, 20)
	var tm = track(TurnManager.new()) as TurnManager
	
	# Place player at (10, 10)
	var player = _create_test_player(Vector2i(10, 10), grid, tm)
	
	# Place Dark Acolyte (SPELLCASTER with fireball) at (10, 7) (dist 3)
	var caster = _create_test_enemy("dark_acolyte", Vector2i(10, 7), grid, tm)
	assert_eq(caster.archetype, BestiaryCatalog.Archetype.SPELLCASTER, "Dark Acolyte is SPELLCASTER")
	assert_eq(caster.signature_spell_id, "fireball", "Signature spell is fireball")
	
	# Turn 1: Channel AoE Spell
	caster.take_turn()
	assert_false(caster.telegraphed_hazard.is_empty(), "Turn 1: Caster must initiate 1-turn telegraphed hazard")
	assert_eq(caster.telegraphed_hazard.get("target_cell"), player.grid_pos, "Telegraphed hazard targets player cell")
	var area_cells: Array = caster.telegraphed_hazard.get("area_cells", [])
	assert_true(area_cells.has(player.grid_pos), "Target cell must be inside affected hazard zone")
	
	# Player is still at 100 HP before detonation
	assert_eq(player.stats.current_hp, 100.0, "Player takes 0 damage during channel turn 1")
	
	# Turn 2: Spell Detonates!
	caster.take_turn()
	assert_true(caster.telegraphed_hazard.is_empty(), "Turn 2: Telegraphed hazard clears upon detonation")
	assert_true(player.stats.current_hp < 100.0, "Detonation must inflict damage on player in target zone")

## Test 4: Cross-Faction Infighting between Hostile Monster Factions
func test_monster_faction_matrix_and_infighting() -> void:
	var grid = _create_test_grid(20, 20)
	var tm = track(TurnManager.new()) as TurnManager
	
	# Place distant player at (18, 18)
	var _player = _create_test_player(Vector2i(18, 18), grid, tm)
	
	# Place Undead Skeleton Sentry at (5, 5) and Beast Mine Rat at (5, 6) (adjacent)
	var skeleton = _create_test_enemy("skeleton_sentry", Vector2i(5, 5), grid, tm)
	var rat = _create_test_enemy("mine_rat", Vector2i(5, 6), grid, tm)
	
	assert_eq(skeleton.faction, BestiaryCatalog.Faction.FACTION_UNDEAD, "Skeleton is UNDEAD")
	assert_eq(rat.faction, BestiaryCatalog.Faction.FACTION_BEAST, "Rat is BEAST")
	assert_true(skeleton.faction != rat.faction, "Factions must be rivals")
	
	var rat_initial_hp = rat.stats.current_hp
	for _i in range(5):
		skeleton.take_turn()
		if rat.stats.current_hp < rat_initial_hp:
			break
	assert_true(rat.stats.current_hp < rat_initial_hp, "Skeleton must target and attack adjacent rival faction monster instead of distant player")

## Test 5: Stealth Ambusher Concealment and Reveal
func test_stealth_ambusher_reveal() -> void:
	var grid = _create_test_grid(20, 20)
	var tm = track(TurnManager.new()) as TurnManager
	
	# Place player at (5, 5) with low perception (10.0)
	var player = _create_test_player(Vector2i(5, 5), grid, tm, 10.0)
	
	# Place Web Lurker (STEALTH_LURKER, is_ambusher=true) at (5, 8) (dist 3)
	var lurker = _create_test_enemy("web_lurker", Vector2i(5, 8), grid, tm)
	assert_true(lurker.is_ambusher, "Web Lurker is ambusher")
	assert_true(lurker.is_concealed, "Ambusher spawns concealed")
	assert_false(lurker.visible, "Ambusher is invisible on grid while concealed")
	
	# Far away with low perception: remains concealed
	lurker.take_turn()
	assert_true(lurker.is_concealed, "Remains concealed at dist 3 with low player perception")
	
	# Move player adjacent at (5, 7) (dist 1)
	grid.unregister_entity(player, player.grid_pos)
	player.init_grid_position(grid, Vector2i(5, 7), tm)
	lurker.take_turn()
	assert_false(lurker.is_concealed, "Lurker must reveal when player steps within attack range (dist <= 1)")
	assert_true(lurker.visible, "Lurker must be visible once revealed")

## Test 6: Intelligent Morale Fleeing at < 10% HP
func test_intelligent_morale_fleeing() -> void:
	var grid = _create_test_grid(20, 20)
	var tm = track(TurnManager.new()) as TurnManager
	
	# Place player at (10, 10)
	var _player = _create_test_player(Vector2i(10, 10), grid, tm)
	
	# Place intelligent Goblin Pickaxer at (10, 8)
	var goblin = _create_test_enemy("goblin_pickaxer", Vector2i(10, 8), grid, tm)
	assert_true(goblin.is_intelligent, "Goblin Pickaxer is intelligent")
	
	# Reduce HP to 5% (< 10%)
	var max_hp = goblin.stats.get_max_health()
	goblin.stats.current_hp = max_hp * 0.05
	
	goblin.take_turn()
	assert_eq(goblin.ai_state, Enemy.AIState.FLEE, "Intelligent enemy at < 10% HP must transition to AIState.FLEE")
	var dist_after_flee = maxi(abs(goblin.grid_pos.x - _player.grid_pos.x), abs(goblin.grid_pos.y - _player.grid_pos.y))
	assert_true(dist_after_flee >= 2, "Intelligent enemy must flee away from player threat")
	
	# Undead entity at < 10% HP does NOT flee
	var skeleton = _create_test_enemy("skeleton_sentry", Vector2i(10, 9), grid, tm)
	assert_false(skeleton.is_intelligent, "Skeleton is mindless undead")
	skeleton.stats.current_hp = 1.0
	skeleton.take_turn()
	assert_true(skeleton.ai_state != Enemy.AIState.FLEE, "Mindless undead must never flee from combat")

## Test 7: Undead 2.0x Vulnerability to Radiant Spells and Silver Weapons
func test_undead_radiant_and_silver_vulnerability() -> void:
	var grid = _create_test_grid(20, 20)
	var tm = track(TurnManager.new()) as TurnManager
	var player = _create_test_player(Vector2i(5, 5), grid, tm)
	
	var skeleton = _create_test_enemy("skeleton_sentry", Vector2i(5, 6), grid, tm)
	assert_true(skeleton.is_undead, "Skeleton Sentry has is_undead=true")
	
	# 1. Silver Weapon vulnerability in CombatComponent
	var regular_sword = WeaponManifest.create_weapon("sword_short")
	regular_sword.base_damage_min = 10
	regular_sword.base_damage_max = 10
	
	var silver_sword = ItemData.create_silver_sword()
	silver_sword.base_damage_min = 10
	silver_sword.base_damage_max = 10
	assert_true(silver_sword.is_silver, "Silver sword has is_silver=true")
	
	# Reset HP and attack with silver
	var res_silver: Dictionary = {}
	for _i in range(10):
		skeleton.stats.current_hp = 100.0
		res_silver = player.combat.execute_attack(skeleton, silver_sword)
		if res_silver.get("hit", false):
			break
	assert_true(res_silver.get("hit", false), "Attack hits")
	
	# Create living goblin defender with identical armor (2)
	var goblin = _create_test_enemy("bandit_cutthroat", Vector2i(5, 4), grid, tm)
	assert_false(goblin.is_undead, "Goblin is living entity")
	var res_regular_living: Dictionary = {}
	for _i in range(10):
		goblin.stats.current_hp = 100.0
		res_regular_living = player.combat.execute_attack(goblin, silver_sword)
		if res_regular_living.get("hit", false):
			break
	assert_true(res_regular_living.get("hit", false), "Attack hits living entity")
	
	# Undead must take approximately 2x the damage of living from silver weapon
	assert_true(res_silver["damage"] >= res_regular_living["damage"] * 1.8, "Undead must take 2.0x damage from silver weapon (undead %d vs living %d)" % [res_silver["damage"], res_regular_living["damage"]])

	# 2. Radiant Divine Spell vulnerability
	var scc = track(SpellCastingComponent.new()) as SpellCastingComponent
	player.add_child(scc)
	
	var radiant_spell = SpellData.new()
	radiant_spell.spell_id = "holy_smite"
	radiant_spell.damage_type = SpellData.DamageType.RADIANT
	radiant_spell.base_potency = 20.0
	
	var potency_undead = scc.calculate_spell_potency(radiant_spell, skeleton)
	var potency_living = scc.calculate_spell_potency(radiant_spell, goblin)
	assert_true(potency_undead["scaled_base"] >= potency_living["scaled_base"] * 1.9, "Radiant spell potency against undead must be 2.0x vs living entity")

## Test 8: Elite Affixes, Stat Boosts, and Guaranteed Loot
func test_elite_variants_affixes_and_loot() -> void:
	var grid = _create_test_grid(20, 20)
	var tm = track(TurnManager.new()) as TurnManager
	
	var regular = _create_test_enemy("skeleton_sentry", Vector2i(2, 2), grid, tm, false)
	var elite = _create_test_enemy("skeleton_sentry", Vector2i(4, 4), grid, tm, true, "Vampiric")
	
	# Stat scaling: +60% HP
	assert_true(elite.max_hp >= regular.max_hp * 1.55, "Elite must have +60% HP (regular %d, elite %d)" % [regular.max_hp, elite.max_hp])
	assert_true(elite.enemy_name.begins_with("[Elite]"), "Elite name must start with [Elite]")
	assert_eq(elite.elite_affix, "Vampiric", "Affix matches Vampiric")
	
	# Test Vampiric heal on attack
	var player = _create_test_player(Vector2i(4, 5), grid, tm)
	for _i in range(10):
		elite.stats.current_hp = 10.0 # damage elite to test healing
		var hit_res = elite.combat.execute_attack(player, elite.inventory.get_equipped_weapon())
		if hit_res.get("hit", false) and hit_res.get("damage", 0) > 0:
			break
	assert_true(elite.stats.current_hp > 10.0, "Vampiric elite must heal 30% of damage dealt upon hitting target")

	# Test Armored affix (+4 armor)
	var armored_elite = _create_test_enemy("skeleton_sentry", Vector2i(6, 6), grid, tm, true, "Armored")
	assert_eq(armored_elite.elite_affix, "Armored", "Affix is Armored")
	
	# Test Swift affix (+20 Dodge)
	var swift_elite = _create_test_enemy("skeleton_sentry", Vector2i(8, 8), grid, tm, true, "Swift")
	var hit_info = player.combat.calculate_hit_chance(swift_elite)
	assert_true(hit_info["def_skill_val"] >= 25.0, "Swift elite receives +20 dodge rating bonus")

## Test 9: Floor Milestone Mini-Boss Spawns on Floors 4, 8, 12, 16
func test_floor_milestone_mini_bosses() -> void:
	var gen = DungeonGenerator.new(40, 30)
	var grid = _create_test_grid(40, 30)
	
	for milestone_floor in [4, 8, 12, 16]:
		var res = gen.generate_dungeon(grid, milestone_floor, 42)
		var boss_cell = res.get("mini_boss_spawn", Vector2i.ZERO) as Vector2i
		assert_true(boss_cell != Vector2i.ZERO, "Milestone Floor %d must designate a mini-boss spawn cell in the exit room" % milestone_floor)
		
		# Verify chosen biome has a valid mini-boss
		var biome = BiomeData.get_all_biomes()[(milestone_floor / 4) * 4 - 4]
		assert_true(biome.mini_boss_id != "", "Biome for floor %d must define a mini-boss ID" % milestone_floor)
		var boss_template = BestiaryCatalog.get_monster_template(biome.mini_boss_id)
		assert_false(boss_template.is_empty(), "BestiaryCatalog must contain template for %s" % biome.mini_boss_id)
		assert_true(boss_template["is_mini_boss"], "Template must be flagged as mini-boss")
		assert_true(boss_template["hp_base"] >= 150.0, "Mini-boss must have high base HP (>= 150)")
