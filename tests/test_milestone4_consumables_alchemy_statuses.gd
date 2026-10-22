@tool
extends McpTestSuite

## Milestone 4 Test Suite: Consumables, Alchemy & Status Effects
## Tests:
## 1. Unidentified potion shuffling, Scholarship/Alchemy identification, and 1-turn consumption.
## 2. Throwing potions (beneficial or harmful) via Throwing skill with identity reveal.
## 3. Portable Mortar and Pestle crafting from reagents training Alchemy.
## 4. Independent additive Bleed stacks ticking concurrently without refreshing older stack durations.
## 5. Poison duration refresh and tier promotion (Minor -> Standard -> Greater).
## 6. Universal healing and bleed curing from bandages/medkits.
## 7. HUD status badges formatting and turn countdowns.

const AlchemyCatalog = preload("res://scripts/resources/AlchemyCatalog.gd")
const ItemData = preload("res://scripts/resources/ItemData.gd")
const SkillData = preload("res://scripts/resources/SkillData.gd")
const AttributesData = preload("res://scripts/resources/AttributesData.gd")

const StatusEffectComponent = preload("res://scripts/components/StatusEffectComponent.gd")
const StatsComponent = preload("res://scripts/components/StatsComponent.gd")
const SkillComponent = preload("res://scripts/components/SkillComponent.gd")
const InventoryComponent = preload("res://scripts/components/InventoryComponent.gd")
const CombatComponent = preload("res://scripts/components/CombatComponent.gd")
const VisionComponent = preload("res://scripts/components/VisionComponent.gd")

const DungeonGrid = preload("res://scripts/world/DungeonGrid.gd")
const TurnManager = preload("res://scripts/world/TurnManager.gd")
const Player = preload("res://scripts/entities/Player.gd")
const Enemy = preload("res://scripts/entities/Enemy.gd")
const InventoryModal = preload("res://scripts/ui/InventoryModal.gd")
const AlchemyCraftingModal = preload("res://scripts/ui/AlchemyCraftingModal.gd")

func suite_name() -> String:
	return "milestone4_consumables_alchemy_statuses"

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

func _create_test_player(pos: Vector2i, grid: DungeonGrid, tm: TurnManager, sch_lvl: float = 10.0, alc_lvl: float = 10.0) -> Player:
	var player = track(Player.new()) as Player
	player.name = "TestPlayer"

	var stats = track(StatsComponent.new()) as StatsComponent
	stats.name = "StatsComponent"
	stats.attributes = track(AttributesData.new()) as AttributesData
	stats.attributes.strength = 12
	stats.attributes.dexterity = 12
	stats.attributes.constitution = 12
	stats.attributes.intelligence = 14
	stats.attributes.wisdom = 12
	stats.max_hp_override = 100.0
	stats.current_hp = 100.0

	var skills = track(SkillComponent.new()) as SkillComponent
	skills.name = "SkillComponent"
	var sch = skills.register_or_unlock_skill(SkillData.SkillId.SCHOLARSHIP, sch_lvl)
	sch.level = sch_lvl
	var alc = skills.register_or_unlock_skill(SkillData.SkillId.ALCHEMY, alc_lvl)
	alc.level = alc_lvl
	var thr = skills.register_or_unlock_skill(SkillData.SkillId.THROWING, 10.0)
	thr.level = 10.0

	var inv = track(InventoryComponent.new()) as InventoryComponent
	inv.name = "InventoryComponent"

	var combat = track(CombatComponent.new()) as CombatComponent
	combat.name = "CombatComponent"

	var vision = track(VisionComponent.new()) as VisionComponent
	vision.name = "VisionComponent"

	var sec = track(StatusEffectComponent.new()) as StatusEffectComponent
	sec.name = "StatusEffectComponent"

	player.add_child(stats)
	player.add_child(skills)
	player.add_child(inv)
	player.add_child(combat)
	player.add_child(vision)
	player.add_child(sec)

	player.stats = stats
	player.skills = skills
	player.inventory = inv
	player.combat = combat
	player.vision = vision
	player.status_effects = sec

	player.init_grid_position(grid, pos, tm)
	return player

func _create_test_enemy(pos: Vector2i, grid: DungeonGrid, hp: float = 50.0) -> Enemy:
	var enemy = track(Enemy.new()) as Enemy
	enemy.name = "TestEnemy"
	enemy.enemy_name = "Goblin Target"

	var stats = track(StatsComponent.new()) as StatsComponent
	stats.name = "StatsComponent"
	stats.attributes = track(AttributesData.new()) as AttributesData
	stats.attributes.strength = 10
	stats.attributes.dexterity = 10
	stats.attributes.constitution = 10
	stats.max_hp_override = hp
	stats.current_hp = hp

	var sec = track(StatusEffectComponent.new()) as StatusEffectComponent
	sec.name = "StatusEffectComponent"

	enemy.add_child(stats)
	enemy.add_child(sec)
	enemy.stats = stats
	enemy.status_effects = sec

	enemy.init_grid_position(grid, pos)
	return enemy

# -----------------------------------------------------------------------------
# 1. Unidentified Potion Shuffling & Identification Checks
# -----------------------------------------------------------------------------
func test_unidentified_potion_shuffling_and_identification() -> void:
	AlchemyCatalog.init_run(12345)

	# Verify appearances are assigned across all potions
	for p_id in AlchemyCatalog.BENEFICIAL_POTIONS:
		var app = AlchemyCatalog.get_potion_appearance(p_id)
		assert_true(app != "", "Every beneficial potion must have an assigned appearance")
		assert_false(AlchemyCatalog.is_potion_identified(p_id), "Potions must start unidentified")

	for p_id in AlchemyCatalog.HARMFUL_POTIONS:
		var app = AlchemyCatalog.get_potion_appearance(p_id)
		assert_true(app != "", "Every harmful potion must have an assigned appearance")
		assert_false(AlchemyCatalog.is_potion_identified(p_id), "Harmful potions must start unidentified")

	var pot = AlchemyCatalog.create_potion("potion_heal_standard")
	var initial_name = pot.get_display_name()
	assert_true(initial_name != "Standard Healing Potion", "Unidentified potion should show appearance, not real name: %s" % initial_name)

	# Identification via Scholarship / Alchemy
	var grid = _create_test_grid()
	var tm = track(TurnManager.new()) as TurnManager
	var player = _create_test_player(Vector2i(2, 2), grid, tm, 50.0, 10.0)

	var id_res = AlchemyCatalog.attempt_identify_with_skill(player, pot)
	assert_true(id_res.get("success", false), "Scholarship check at level 50 should identify potion")
	assert_true(AlchemyCatalog.is_potion_identified("potion_heal_standard"), "Potion should now be marked identified")
	assert_eq(pot.get_display_name(), "Standard Healing Potion", "Display name should reveal true identity")

# -----------------------------------------------------------------------------
# 2. Direct 1-Turn Consumption & Identity Reveal
# -----------------------------------------------------------------------------
func test_direct_one_turn_consumption_and_identity_reveal() -> void:
	AlchemyCatalog.init_run(999)
	var grid = _create_test_grid()
	var tm = track(TurnManager.new()) as TurnManager
	tm.init_floor_timer(1)
	var player = _create_test_player(Vector2i(2, 2), grid, tm)

	var modal = track(InventoryModal.new()) as InventoryModal
	modal.inventory = player.inventory
	modal.player = player

	# Give player unidentified Giant Strength potion
	assert_false(AlchemyCatalog.is_potion_identified("potion_giant_strength"))
	var pot = AlchemyCatalog.create_potion("potion_giant_strength")
	player.inventory.add_item(pot)

	# Execute "Use (1 Turn)"
	var res = modal.execute_item_action(pot, "Use (1 Turn)")
	assert_true(res.get("success", false), "Potion usage should succeed")
	assert_true(AlchemyCatalog.is_potion_identified("potion_giant_strength"), "Drinking must identify potion for run")
	assert_eq(player.status_effects.get_strength_bonus(), 5, "Giant strength potion must grant +5 Strength")
	assert_true(player.inventory.items.is_empty(), "Consumed potion should be removed from inventory")

# -----------------------------------------------------------------------------
# 3. Throwing Potions via Throwing Skill with Identity Reveal
# -----------------------------------------------------------------------------
func test_throwing_potion_via_throwing_skill_and_identity_reveal() -> void:
	AlchemyCatalog.init_run(555)
	var grid = _create_test_grid()
	var tm = track(TurnManager.new()) as TurnManager
	var player = _create_test_player(Vector2i(2, 2), grid, tm)
	var enemy = _create_test_enemy(Vector2i(4, 2), grid, 50.0)

	assert_false(AlchemyCatalog.is_potion_identified("potion_poison_standard"))
	var poison_pot = AlchemyCatalog.create_potion("potion_poison_standard")
	player.inventory.add_item(poison_pot)

	# Apply throw impact to enemy
	var res = AlchemyCatalog.apply_potion_effect(enemy, poison_pot.item_id, false)
	assert_true(res.get("success", false), "Thrown potion should resolve effect")
	assert_true(enemy.status_effects.is_poisoned(), "Enemy struck by poison potion should gain Poison status")
	assert_eq(enemy.status_effects.poison_tier, StatusEffectComponent.PoisonTier.STANDARD, "Should inflict Standard Poison tier")
	assert_true(AlchemyCatalog.is_potion_identified("potion_poison_standard"), "Thrown potion must reveal identity")

# -----------------------------------------------------------------------------
# 4. Universal Healing from Bandages & Medkits
# -----------------------------------------------------------------------------
func test_universal_healing_from_bandages_and_medkits() -> void:
	var grid = _create_test_grid()
	var tm = track(TurnManager.new()) as TurnManager
	tm.init_floor_timer(1)
	var player = _create_test_player(Vector2i(2, 2), grid, tm)

	var modal = track(InventoryModal.new()) as InventoryModal
	modal.inventory = player.inventory
	modal.player = player

	# Injure player and apply Bleed
	player.stats.current_hp = 40.0
	player.status_effects.apply_bleed(4, 3)
	assert_true(player.status_effects.is_bleeding(), "Player should start bleeding")

	var kit = ItemData.new("medpack_combat", "Field Trauma Kit", ItemData.ItemType.CONSUMABLE, ItemData.EquipSlot.NONE, 1.0, 1)
	player.inventory.add_item(kit)

	var res = modal.execute_item_action(kit, "Use (1 Turn)")
	assert_true(res.get("success", false), "Medkit use should succeed")
	assert_eq(int(player.stats.current_hp), 80, "Trauma kit should restore 40 HP (from 40 to 80)")
	assert_false(player.status_effects.is_bleeding(), "Applying medkit should universally cure Bleed")

# -----------------------------------------------------------------------------
# 5. Portable Mortar and Pestle Crafting
# -----------------------------------------------------------------------------
func test_portable_mortar_and_pestle_crafting() -> void:
	AlchemyCatalog.init_run(777)
	var grid = _create_test_grid()
	var tm = track(TurnManager.new()) as TurnManager
	var player = _create_test_player(Vector2i(2, 2), grid, tm, 10.0, 25.0)

	# 1. Attempt crafting without Mortar & Pestle -> Fails
	var fail_res = AlchemyCatalog.craft_recipe(player, "craft_heal")
	assert_false(fail_res.get("success", false), "Crafting without Mortar & Pestle must fail")

	# 2. Add Mortar & Pestle and reagents
	var mortar = ItemData.new("mortar_and_pestle", "Mortar and Pestle", ItemData.ItemType.RELIC, ItemData.EquipSlot.ACCESSORY, 1.0)
	player.inventory.add_item(mortar)

	player.inventory.add_item(AlchemyCatalog.create_reagent("reagent_sunpetal", 1))
	player.inventory.add_item(AlchemyCatalog.create_reagent("reagent_bloodmoss", 1))

	var start_xp = player.skills.get_skill(SkillData.SkillId.ALCHEMY).current_xp

	var success_res = AlchemyCatalog.craft_recipe(player, "craft_heal")
	assert_true(success_res.get("success", false), "Crafting Healing Potion with reagents should succeed")
	assert_eq(player.inventory.get_item_count("reagent_sunpetal"), 0, "Sunpetal reagent should be consumed")
	assert_eq(player.inventory.get_item_count("reagent_bloodmoss"), 0, "Bloodmoss reagent should be consumed")
	assert_true(AlchemyCatalog.is_potion_identified("potion_heal_standard"), "Crafted potion must be automatically identified")

	var end_xp = player.skills.get_skill(SkillData.SkillId.ALCHEMY).current_xp
	assert_gt(end_xp, start_xp, "Crafting must train ALCHEMY skill XP")

# -----------------------------------------------------------------------------
# 6. Additive Independent Bleed Stacks Ticking
# -----------------------------------------------------------------------------
func test_independent_additive_bleed_stacks_ticking() -> void:
	var sec = track(StatusEffectComponent.new()) as StatusEffectComponent
	sec.name = "StatusEffectComponent"
	var stats = track(StatsComponent.new()) as StatsComponent
	stats.name = "StatsComponent"
	stats.attributes = track(AttributesData.new()) as AttributesData
	stats.max_hp_override = 100.0
	stats.current_hp = 100.0

	var dummy = track(Node2D.new()) as Node2D
	dummy.add_child(stats)
	dummy.add_child(sec)

	# Stack 1: 4 dmg/t for 3 turns
	sec.apply_bleed(4, 3)
	# Stack 2: 6 dmg/t for 2 turns
	sec.apply_bleed(6, 2)

	assert_eq(sec.bleed_stacks.size(), 2, "Should have 2 independent bleed stacks")
	assert_eq(sec.get_total_bleed_damage_per_turn(), 10, "Total bleed rate should sum: 4 + 6 = 10")

	# Turn 1 Tick: 10 dmg (100 -> 90). Stack 1 has 2t, Stack 2 has 1t
	var tick1 = sec.tick_turn()
	assert_eq(tick1["bleed_damage"], 10, "Turn 1 bleed damage should be 10")
	assert_eq(int(stats.current_hp), 90, "HP should be 90")
	assert_eq(sec.bleed_stacks.size(), 2, "Both stacks still active")

	# Turn 2 Tick: 10 dmg (90 -> 80). Stack 1 has 1t, Stack 2 has 0t (expires)
	var tick2 = sec.tick_turn()
	assert_eq(tick2["bleed_damage"], 10, "Turn 2 bleed damage should be 10")
	assert_eq(int(stats.current_hp), 80, "HP should be 80")
	assert_eq(sec.bleed_stacks.size(), 1, "Stack 2 expired on its own timer without refreshing stack 1")

	# Turn 3 Tick: Only Stack 1 ticks: 4 dmg (80 -> 76). Stack 1 expires
	var tick3 = sec.tick_turn()
	assert_eq(tick3["bleed_damage"], 4, "Turn 3 bleed damage should be 4 from remaining stack 1")
	assert_eq(int(stats.current_hp), 76, "HP should be 76")
	assert_false(sec.is_bleeding(), "All bleed stacks should now be expired")

# -----------------------------------------------------------------------------
# 7. Poison Duration Refresh & Tier Promotion (Minor -> Standard -> Greater)
# -----------------------------------------------------------------------------
func test_poison_duration_refresh_and_tier_promotion() -> void:
	var sec = track(StatusEffectComponent.new()) as StatusEffectComponent
	sec.name = "StatusEffectComponent"
	var stats = track(StatsComponent.new()) as StatsComponent
	stats.name = "StatsComponent"
	stats.attributes = track(AttributesData.new()) as AttributesData
	stats.max_hp_override = 100.0
	stats.current_hp = 100.0

	var dummy = track(Node2D.new()) as Node2D
	dummy.add_child(stats)
	dummy.add_child(sec)

	# 1. Apply Minor Poison (Tier 1, 3 dmg/t, 4 turns)
	sec.apply_poison(StatusEffectComponent.PoisonTier.MINOR, 4)
	assert_true(sec.is_poisoned(), "Should be poisoned")
	assert_eq(sec.poison_tier, StatusEffectComponent.PoisonTier.MINOR, "Tier 1 Minor")
	assert_eq(sec.get_poison_damage_per_turn(), 3, "Minor Poison deals 3 dmg/t")
	assert_eq(sec.poison_turns_remaining, 4, "4 turns remaining")

	# 2. Re-apply Poison with duration 7 and force_promote = true
	var promoted = sec.apply_poison(StatusEffectComponent.PoisonTier.MINOR, 7, true)
	assert_true(promoted, "Should promote tier")
	assert_eq(sec.poison_tier, StatusEffectComponent.PoisonTier.STANDARD, "Tier 2 Standard")
	assert_eq(sec.get_poison_damage_per_turn(), 7, "Standard Poison deals 7 dmg/t")
	assert_eq(sec.poison_turns_remaining, 7, "Duration refreshed to max(4, 7) = 7")

	# 3. Re-apply Poison with duration 3 and force_promote = true
	var promoted_greater = sec.apply_poison(StatusEffectComponent.PoisonTier.MINOR, 3, true)
	assert_true(promoted_greater, "Should promote to Greater")
	assert_eq(sec.poison_tier, StatusEffectComponent.PoisonTier.GREATER, "Tier 3 Greater")
	assert_eq(sec.get_poison_damage_per_turn(), 15, "Greater Poison deals 15 dmg/t")
	assert_eq(sec.poison_turns_remaining, 7, "Duration preserved as max(7, 3) = 7")

	# 4. Tick Turn: Deals 15 poison damage
	var tick = sec.tick_turn()
	assert_eq(tick["poison_damage"], 15, "Greater Poison should deal 15 damage on tick")
	assert_eq(int(stats.current_hp), 85, "HP should reduce by 15")
	assert_eq(sec.poison_turns_remaining, 6, "Turns remaining decrements to 6")

# -----------------------------------------------------------------------------
# 8. HUD Status Badges and Turn Countdowns
# -----------------------------------------------------------------------------
func test_status_hud_badges_and_turn_countdowns() -> void:
	var sec = track(StatusEffectComponent.new()) as StatusEffectComponent

	# Add Bleed: 2 stacks of 4 dmg (total 8 dmg/t), max duration 3t
	sec.apply_bleed(4, 3)
	sec.apply_bleed(4, 2)

	# Add Poison Standard: 7 dmg/t, 5 turns
	sec.apply_poison(StatusEffectComponent.PoisonTier.STANDARD, 5)

	# Add Ward: 25 hp
	sec.apply_arcane_ward(25)

	# Add Haste: 4t
	sec.apply_haste(4)

	# Add Blindness: 2t
	sec.apply_blindness(2)

	var badges_str = sec.get_hud_badge_string()

	assert_true(badges_str.contains("[Bleed x2 (8/t): 3t]"), "Badge for Bleed should match: %s" % badges_str)
	assert_true(badges_str.contains("[Poison II (7/t): 5t]"), "Badge for Poison should match: %s" % badges_str)
	assert_true(badges_str.contains("[Ward: 25]"), "Badge for Ward should match: %s" % badges_str)
	assert_true(badges_str.contains("[Haste: 4t]"), "Badge for Haste should match: %s" % badges_str)
	assert_true(badges_str.contains("[Blind: 2t]"), "Badge for Blindness should match: %s" % badges_str)
