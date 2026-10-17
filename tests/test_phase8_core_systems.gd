@tool
extends McpTestSuite

## Phase 8 Test Suite: Opaque UI, Fog of War, Expanded Floors, 12-Slot Paperdoll, Skills UI, and Hotbar Verification

func suite_name() -> String:
	return "phase8_core_systems"

func test_opaque_ui_styling_and_base_modal() -> void:
	var modal = track(BaseModal.new()) as BaseModal
	modal._ready()
	
	var sb = modal.get_theme_stylebox("panel")
	assert_true(sb != null, "BaseModal must have a panel stylebox applied")
	if sb is StyleBoxFlat:
		assert_true(sb.bg_color.a >= 0.99, "BaseModal panel background must be 100% opaque")
		assert_eq(sb.border_width_left, 2, "BaseModal must have 2px border")
	
	var events = {"opened": false, "closed": false}
	modal.modal_opened.connect(func(): events["opened"] = true)
	modal.modal_closed.connect(func(): events["closed"] = true)
	
	modal.open_modal()
	assert_true(modal.visible, "Modal must be visible when opened")
	assert_true(events["opened"], "modal_opened signal must be emitted")
	
	modal.close_modal()
	assert_false(modal.visible, "Modal must be hidden when closed")
	assert_true(events["closed"], "modal_closed signal must be emitted")
	modal.queue_free()

func test_fog_of_war_three_tier_visibility_and_memory() -> void:
	var fow = track(FogOfWarSystem.new()) as FogOfWarSystem
	fow.init_fog(20, 20)
	
	# Initial state: all tiles HIDDEN
	assert_eq(fow.get_visibility(Vector2i(5, 5)), FogOfWarSystem.TileVisibility.HIDDEN, "Tiles start HIDDEN")
	assert_false(fow.is_visible(Vector2i(5, 5)), "Hidden tile is not visible")
	assert_false(fow.is_explored(Vector2i(5, 5)), "Hidden tile is not explored")
	
	# Create a mock grid with a wall obstacle
	var grid = track(DungeonGrid.new()) as DungeonGrid
	grid.grid_width = 20
	grid.grid_height = 20
	grid.clear_grid()
	for y in range(20):
		for x in range(20):
			grid.set_cell_walkable(Vector2i(x, y), true)
			
	# Place a wall at (7, 5)
	grid.set_cell_walkable(Vector2i(7, 5), false)
	
	# Update visibility from (5, 5) with sight radius 5
	fow.update_visibility(Vector2i(5, 5), 5, grid)
	
	# Origin and unobstructed line must be VISIBLE
	assert_true(fow.is_visible(Vector2i(5, 5)), "Origin (5,5) is VISIBLE")
	assert_true(fow.is_visible(Vector2i(6, 5)), "Cell (6,5) in front of wall is VISIBLE")
	assert_true(fow.is_visible(Vector2i(7, 5)), "Wall cell (7,5) is VISIBLE")
	assert_false(fow.is_visible(Vector2i(8, 5)), "Cell (8,5) behind wall is occluded and NOT VISIBLE")
	
	# Permanent Memory Retention: Move origin away to (15, 15)
	fow.update_visibility(Vector2i(15, 15), 4, grid)
	
	# Previous cells must now be EXPLORED (memory), not HIDDEN
	assert_eq(fow.get_visibility(Vector2i(5, 5)), FogOfWarSystem.TileVisibility.EXPLORED, "Previous cell demoted to EXPLORED")
	assert_true(fow.is_explored(Vector2i(5, 5)), "is_explored returns true for explored tiles")
	assert_false(fow.is_visible(Vector2i(5, 5)), "is_visible returns false for explored tiles out of sight")
	assert_true(fow.is_visible(Vector2i(15, 15)), "New origin (15,15) is VISIBLE")

func test_expanded_floor_scale_and_dynamic_turn_clock() -> void:
	var gen = DungeonGenerator.new()
	assert_eq(gen.width, 80, "Default dungeon width must be 80")
	assert_eq(gen.height, 60, "Default dungeon height must be 60")
	assert_eq(gen.max_rooms, 20, "Default room count must be 20")
	
	# Turn budget formula: BaseTurns(300) + (WalkableTiles * 0.70) - (FloorNumber * 15)
	var tm = track(TurnManager.new()) as TurnManager
	tm.init_floor_timer(1, 1000)
	# 300 + 700 - 15 = 985
	assert_eq(tm.floor_total_turns, 985, "Floor 1 with 1000 walkable tiles gets 985 turns")
	
	tm.init_floor_timer(10, 1200)
	# 300 + 840 - 150 = 990
	assert_eq(tm.floor_total_turns, 990, "Floor 10 with 1200 walkable tiles gets 990 turns")
	
	# Proportional stages in FloorCollapseManager
	var cm = track(FloorCollapseManager.new()) as FloorCollapseManager
	var total = 1000
	assert_eq(cm.get_stage_for_turns(900, total), FloorCollapseManager.CollapseStage.STABLE, ">50% is STABLE")
	assert_eq(cm.get_stage_for_turns(400, total), FloorCollapseManager.CollapseStage.TREMORS, "40% is TREMORS")
	assert_eq(cm.get_stage_for_turns(200, total), FloorCollapseManager.CollapseStage.COLLAPSING, "20% is COLLAPSING")
	assert_eq(cm.get_stage_for_turns(50, total), FloorCollapseManager.CollapseStage.IMMINENT, "5% is IMMINENT")
	assert_eq(cm.get_stage_for_turns(0, total), FloorCollapseManager.CollapseStage.COLLAPSED, "0 turns is COLLAPSED")

func test_twelve_slot_paperdoll_and_ring_swapping() -> void:
	# Verify all 12 slots exist in enum
	assert_eq(ItemData.EquipSlot.HEAD, 1)
	assert_eq(ItemData.EquipSlot.BACK, 2)
	assert_eq(ItemData.EquipSlot.MAIN_HAND, 3)
	assert_eq(ItemData.EquipSlot.OFF_HAND, 4)
	assert_eq(ItemData.EquipSlot.BODY, 5)
	assert_eq(ItemData.EquipSlot.BELT, 6)
	assert_eq(ItemData.EquipSlot.LEGS, 7)
	assert_eq(ItemData.EquipSlot.FEET, 8)
	assert_eq(ItemData.EquipSlot.RING_1, 9)
	assert_eq(ItemData.EquipSlot.RING_2, 10)
	assert_eq(ItemData.EquipSlot.ACCESSORY, 11)
	assert_eq(ItemData.EquipSlot.AMMUNITION, 12)
	
	var inv = track(InventoryComponent.new()) as InventoryComponent
	var ring_a = track(ItemData.new("ring_ruby", "Ruby Band", ItemData.ItemType.RELIC, ItemData.EquipSlot.RING_1, 0.1)) as ItemData
	var ring_b = track(ItemData.new("ring_sapphire", "Sapphire Band", ItemData.ItemType.RELIC, ItemData.EquipSlot.RING_1, 0.1)) as ItemData
	var ring_c = track(ItemData.new("ring_emerald", "Emerald Band", ItemData.ItemType.RELIC, ItemData.EquipSlot.RING_1, 0.1)) as ItemData
	
	inv.add_item(ring_a)
	inv.add_item(ring_b)
	inv.add_item(ring_c)
	
	# Equip first ring -> goes to RING_1
	var ok1 = inv.equip_item(ring_a)
	assert_true(ok1, "First ring equipped")
	assert_eq(inv.equipped_slots[ItemData.EquipSlot.RING_1].item_id, "ring_ruby", "First ring placed in RING_1")
	
	# Equip second ring -> goes to RING_2 automatically
	var ok2 = inv.equip_item(ring_b)
	assert_true(ok2, "Second ring equipped")
	assert_eq(inv.equipped_slots[ItemData.EquipSlot.RING_2].item_id, "ring_sapphire", "Second ring placed in RING_2")
	
	# Equip third ring -> swaps with RING_1
	var ok3 = inv.equip_item(ring_c)
	assert_true(ok3, "Third ring equipped")
	assert_eq(inv.equipped_slots[ItemData.EquipSlot.RING_1].item_id, "ring_emerald", "Third ring swapped into RING_1")
	assert_true(inv.items.has(ring_a), "Old ring returned to backpack")

func test_skills_milestone_queries_and_decimal_progression() -> void:
	var info_25 = SkillData.get_milestone_info(SkillData.SkillId.SWORDSMANSHIP, 25)
	assert_true(info_25["title"].contains("Novice Keystone"), "Milestone 25 returns Novice Keystone")
	
	var info_100 = SkillData.get_milestone_info(SkillData.SkillId.SWORDSMANSHIP, 100)
	assert_true(info_100["title"].contains("Grandmaster Capstone"), "Milestone 100 returns Grandmaster Capstone")
	
	var desc = SkillData.get_skill_description(SkillData.SkillId.ARCANE_MAGIC)
	assert_false(desc.is_empty(), "Skill description must not be empty")

func test_ten_slot_bottom_hotbar_execution() -> void:
	var hotbar = track(HotbarBar.new()) as HotbarBar
	hotbar._ready()
	
	assert_eq(hotbar.slots.size(), 10, "Hotbar must contain 10 slots")
	assert_eq(hotbar.slots[0].key_number, 1, "Slot 0 maps to key 1")
	assert_eq(hotbar.slots[8].key_number, 9, "Slot 8 maps to key 9")
	assert_eq(hotbar.slots[9].key_number, 0, "Slot 9 maps to key 0")
	
	# Set a spell in slot 0
	var heal_spell = SpellData.create_minor_heal()
	hotbar.set_slot_spell(0, heal_spell)
	assert_eq(hotbar.slots[0].slot_type, HotbarBar.SlotType.SPELL, "Slot 0 is SPELL")
	assert_eq(hotbar.slots[0].spell.spell_id, "minor_heal", "Slot 0 holds Minor Heal")
	
	# Set a consumable potion in slot 1
	var potion = track(ItemData.new("pot_hp", "Health Potion", ItemData.ItemType.CONSUMABLE, ItemData.EquipSlot.NONE, 0.5, 3)) as ItemData
	hotbar.set_slot_item(1, potion)
	assert_eq(hotbar.slots[1].slot_type, HotbarBar.SlotType.ITEM, "Slot 1 is ITEM")
	assert_eq(hotbar.slots[1].item.quantity, 3, "Slot 1 holds 3 potions")
	
	hotbar.queue_free()

func test_directional_vision_cone_and_peripheral_radius() -> void:
	var fow = track(FogOfWarSystem.new()) as FogOfWarSystem
	fow.init_fog(30, 30)
	
	var grid = track(DungeonGrid.new()) as DungeonGrid
	grid.grid_width = 30
	grid.grid_height = 30
	grid.clear_grid()
	for y in range(30):
		for x in range(30):
			grid.set_cell_walkable(Vector2i(x, y), true)
	
	var origin = Vector2i(10, 10)
	# Facing East (Vector2i.RIGHT), sight_radius = 8, peripheral_radius = 2
	fow.update_visibility(origin, 8, grid, Vector2i.RIGHT, 2)
	
	# Directly ahead (East) within 8 tiles is VISIBLE
	assert_true(fow.is_visible(Vector2i(18, 10)), "8 tiles directly East in 45-deg cone is VISIBLE")
	assert_true(fow.is_visible(Vector2i(16, 12)), "Tile (16,12) inside 45-deg forward arc is VISIBLE")
	assert_false(fow.is_visible(Vector2i(16, 15)), "Tile (16,15) outside 45-deg cone & beyond peripheral radius is NOT VISIBLE")
	
	# Behind (West) and to the sides (North/South): visible within peripheral radius 2, hidden at distance 3+
	assert_true(fow.is_visible(Vector2i(8, 10)), "2 tiles behind (West) is within peripheral radius and VISIBLE")
	assert_false(fow.is_visible(Vector2i(7, 10)), "3 tiles behind (West) exceeds peripheral radius and is NOT VISIBLE")
	assert_true(fow.is_visible(Vector2i(10, 8)), "2 tiles to side (North) is within peripheral radius and VISIBLE")
	assert_false(fow.is_visible(Vector2i(10, 7)), "3 tiles to side (North) exceeds peripheral radius and is NOT VISIBLE")
	
	# Turn to face West (Vector2i.LEFT): previous East cone tiles become EXPLORED, West cone becomes VISIBLE
	fow.update_visibility(origin, 8, grid, Vector2i.LEFT, 2)
	assert_false(fow.is_visible(Vector2i(18, 10)), "East tile (18,10) is no longer actively VISIBLE after turning West")
	assert_true(fow.is_explored(Vector2i(18, 10)), "East tile (18,10) remains permanently EXPLORED")
	assert_true(fow.is_visible(Vector2i(2, 10)), "8 tiles directly West is now VISIBLE")

func test_perception_skill_vision_scaling() -> void:
	var mock_player = track(Node2D.new()) as Node2D
	var skills_comp = track(SkillComponent.new()) as SkillComponent
	skills_comp.name = "SkillComponent"
	mock_player.add_child(skills_comp)
	skills_comp._ready()
	
	var vision = track(VisionComponent.new()) as VisionComponent
	vision.view_distance_tiles = 8
	mock_player.add_child(vision)
	
	var perc_skill: SkillData = skills_comp.get_skill(SkillData.SkillId.PERCEPTION)
	assert_true(perc_skill != null, "Perception skill exists in SkillComponent")
	
	# Level 0 -> +0 bonus (total 8)
	perc_skill.level = 0.0
	assert_eq(vision.get_perception_vision_bonus(mock_player), 0, "Level 0 Perception grants +0 vision")
	assert_eq(vision.get_effective_view_distance(mock_player), 8, "Base effective view distance is 8")
	
	# Level 9.9 -> +0 bonus (total 8)
	perc_skill.level = 9.9
	assert_eq(vision.get_perception_vision_bonus(mock_player), 0, "Level 9.9 Perception grants +0 vision")
	
	# Level 10.0 -> +1 bonus (total 9)
	perc_skill.level = 10.0
	assert_eq(vision.get_perception_vision_bonus(mock_player), 1, "Level 10 Perception grants +1 vision")
	assert_eq(vision.get_effective_view_distance(mock_player), 9, "Effective view distance at 10 Perception is 9")
	
	# Level 25.0 -> +2 bonus (total 10)
	perc_skill.level = 25.0
	assert_eq(vision.get_perception_vision_bonus(mock_player), 2, "Level 25 Perception grants +2 vision")
	assert_eq(vision.get_effective_view_distance(mock_player), 10, "Effective view distance at 25 Perception is 10")
	
	# Level 100.0 -> +10 bonus (total 18)
	perc_skill.level = 100.0
	assert_eq(vision.get_perception_vision_bonus(mock_player), 10, "Level 100 Perception grants +10 vision")
	assert_eq(vision.get_effective_view_distance(mock_player), 18, "Effective view distance at 100 Perception is 18")

func test_stairs_down_strict_line_of_sight_visibility() -> void:
	var fow = track(FogOfWarSystem.new()) as FogOfWarSystem
	fow.init_fog(30, 30)
	
	var grid = track(DungeonGrid.new()) as DungeonGrid
	grid.grid_width = 30
	grid.grid_height = 30
	grid.clear_grid()
	for y in range(30):
		for x in range(30):
			grid.set_cell_walkable(Vector2i(x, y), true)
	
	var stairs = track(StairsDown.new()) as StairsDown
	stairs.setup(grid, Vector2i(16, 10), 1)
	
	# 1. Hidden state: stairs must be strictly hidden
	assert_false(stairs.visible, "Stairs start hidden before player looks at them")
	stairs.update_visibility_from_fog(fow)
	assert_false(stairs.visible, "Stairs remain hidden while tile is HIDDEN")
	
	# 2. Player at (10, 10) facing East (Vector2i.RIGHT) with radius 8 -> stairs at (16, 10) is in active vision cone
	fow.update_visibility(Vector2i(10, 10), 8, grid, Vector2i.RIGHT, 2)
	stairs.update_visibility_from_fog(fow)
	assert_true(stairs.visible, "Stairs become visible when inside active vision cone")
	
	# 3. Player turns North (Vector2i.UP) -> (16, 10) is now EXPLORED memory, no longer in active vision cone
	fow.update_visibility(Vector2i(10, 10), 8, grid, Vector2i.UP, 2)
	assert_true(fow.is_explored(Vector2i(16, 10)), "Stairs tile is in EXPLORED memory state")
	assert_false(fow.is_visible(Vector2i(16, 10)), "Stairs tile is not actively VISIBLE")
	stairs.update_visibility_from_fog(fow)
	assert_false(stairs.visible, "Stairs must be hidden when tile is only in EXPLORED fog memory")

