@tool
extends McpTestSuite

## Phase 8 Test Suite: Opaque UI, Fog of War, Expanded Floors, 12-Slot Paperdoll, Skills UI, and Hotbar Verification

const BaseModal = preload("res://scripts/ui/BaseModal.gd")
const FogOfWarSystem = preload("res://scripts/world/FogOfWarSystem.gd")
const DungeonGenerator = preload("res://scripts/world/DungeonGenerator.gd")
const DungeonGrid = preload("res://scripts/world/DungeonGrid.gd")
const FloorCollapseManager = preload("res://scripts/world/FloorCollapseManager.gd")
const TurnManager = preload("res://scripts/world/TurnManager.gd")
const ItemData = preload("res://scripts/resources/ItemData.gd")
const InventoryComponent = preload("res://scripts/components/InventoryComponent.gd")
const SkillData = preload("res://scripts/resources/SkillData.gd")
const SpellData = preload("res://scripts/resources/SpellData.gd")
const SpellCastingComponent = preload("res://scripts/components/SpellCastingComponent.gd")
const HotbarBar = preload("res://scripts/ui/HotbarBar.gd")

func _init() -> void:
	var scripts_to_reload = [
		"res://scripts/resources/ItemData.gd",
		"res://scripts/components/InventoryComponent.gd",
		"res://scripts/resources/SkillData.gd",
		"res://scripts/ui/BaseModal.gd",
		"res://scripts/ui/HotbarBar.gd"
	]
	for p in scripts_to_reload:
		var scr = load(p) as GDScript
		if scr:
			scr.reload()

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
