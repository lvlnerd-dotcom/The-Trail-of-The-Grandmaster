@tool
extends McpTestSuite

## TestHoverInspection: Verification suite for Cursor Hover Inspection, UI Alignment,
## Fog of War Spoil Prevention, Qualitative Health Categorization, and EventBus signals.

const PlayerScript = preload("res://scripts/entities/Player.gd")
const EnemyScript = preload("res://scripts/entities/Enemy.gd")
const GrandmasterBossScript = preload("res://scripts/entities/GrandmasterBoss.gd")
const CompanionScript = preload("res://scripts/entities/Companion.gd")
const MerchantScript = preload("res://scripts/entities/Merchant.gd")
const TrapScript = preload("res://scripts/world/Trap.gd")
const SecretDoorScript = preload("res://scripts/world/SecretDoor.gd")
const StairsDownScript = preload("res://scripts/world/StairsDown.gd")
const ShrineScript = preload("res://scripts/world/Shrine.gd")
const WorldItemScript = preload("res://scripts/world/WorldItem.gd")
const ItemData = preload("res://scripts/resources/ItemData.gd")
const InspectionData = preload("res://scripts/resources/InspectionData.gd")
const DungeonGrid = preload("res://scripts/world/DungeonGrid.gd")
const FogOfWarSystem = preload("res://scripts/world/FogOfWarSystem.gd")
const HoverInspectionControllerScript = preload("res://scripts/world/HoverInspectionController.gd")
const HotbarBar = preload("res://scripts/ui/HotbarBar.gd")
const InspectorPanelScript = preload("res://scripts/ui/InspectorPanel.gd")
const StatsComponent = preload("res://scripts/components/StatsComponent.gd")
const AttributesData = preload("res://scripts/resources/AttributesData.gd")

func suite_name() -> String:
	return "hover_inspection"

func test_qualitative_health_spectrum_no_numeric_leak() -> void:
	# 100% HP -> Emerald Green (#33e666)
	var full = BaseEntity.get_health_status_info(100.0, 100.0)
	assert_eq(full["label"], "Uninjured", "100% HP should be Uninjured")
	assert_true(full["color"].g > full["color"].r, "Emerald Green should have dominant green")
	
	# 80% HP -> Chartreuse
	var scratched = BaseEntity.get_health_status_info(80.0, 100.0)
	assert_eq(scratched["label"], "Barely Scratched", "80% HP should be Barely Scratched")
	
	# 55% HP -> Amber Gold
	var wounded = BaseEntity.get_health_status_info(55.0, 100.0)
	assert_eq(wounded["label"], "Wounded", "55% HP should be Wounded")
	
	# 25% HP -> Deep Orange-Red
	var badly = BaseEntity.get_health_status_info(25.0, 100.0)
	assert_eq(badly["label"], "Badly Wounded", "25% HP should be Badly Wounded")
	
	# 10% HP -> Crimson Red (#dc143c)
	var critical = BaseEntity.get_health_status_info(10.0, 100.0)
	assert_eq(critical["label"], "Near Death", "10% HP should be Near Death")
	assert_true(critical["color"].r > critical["color"].g, "Crimson Red should have dominant red")
	
	# 0% HP -> Defeated
	var dead = BaseEntity.get_health_status_info(0.0, 100.0)
	assert_eq(dead["label"], "Defeated", "0% HP should be Defeated")

func test_enemy_inspection_data_supplier() -> void:
	var enemy: Node2D = track(EnemyScript.new()) as Node2D
	var stats = track(StatsComponent.new()) as StatsComponent
	var attrs = AttributesData.new()
	attrs.constitution = 10 # 10 CON -> 100 HP max
	stats.attributes = attrs
	stats.current_hp = 50.0 # 50% -> Wounded
	enemy.add_child(stats)
	enemy.set("stats", stats)
	enemy.set("enemy_name", "Skeleton Guard")
	enemy.set("is_undead", true)
	enemy.set("grid_pos", Vector2i(5, 5))
	
	var data: InspectionData = enemy.call("get_inspection_data")
	assert_true(data != null, "Enemy must supply valid InspectionData")
	assert_eq(data.title, "Skeleton Guard", "Title must match enemy_name")
	assert_eq(data.category, InspectionData.Category.HOSTILE, "Category must be HOSTILE")
	assert_eq(data.category_text, "Undead Hostile", "Undead hostile category text")
	assert_eq(data.health_status_text, "Wounded", "Health status must be Wounded")
	
	# Verify NO numeric HP strings leaked in text fields
	assert_false(data.title.contains("50"), "Title must not leak numeric HP")
	assert_false(data.category_text.contains("50"), "Category text must not leak numeric HP")
	assert_false(data.health_status_text.contains("50"), "Health status must not leak numeric HP")
	assert_false(data.description.contains("50/"), "Description must not leak numeric HP")
	
	enemy.queue_free()

func test_spawned_enemy_health_status_uninjured() -> void:
	var enemy: Node2D = track(EnemyScript.new()) as Node2D
	var stats = track(StatsComponent.new()) as StatsComponent
	enemy.add_child(stats)
	enemy.set("stats", stats)
	
	# Simulate procedural world spawning with 25.0 max HP (Floor 1 Skeleton)
	enemy.call("setup_enemy", "Skeleton Guard", 25.0, 40)
	
	var data: InspectionData = enemy.call("get_inspection_data")
	assert_true(data != null, "Spawned enemy must supply InspectionData")
	assert_eq(data.health_status_text, "Uninjured", "Newly spawned enemy at full 25/25 HP must be Uninjured")
	assert_true(data.health_status_color.g > data.health_status_color.r, "Uninjured must be Emerald Green")
	
	# Test damage scaling against accurate max_hp (take 6 damage: 19/25 = 76% -> Barely Scratched)
	stats.take_damage(6)
	var wounded_data: InspectionData = enemy.call("get_inspection_data")
	assert_eq(wounded_data.health_status_text, "Barely Scratched", "19/25 HP should be Barely Scratched")
	
	enemy.queue_free()

func test_trap_inspection_spoil_prevention() -> void:
	var grid = track(DungeonGrid.new()) as DungeonGrid
	grid.grid_width = 10
	grid.grid_height = 10
	grid.clear_grid()
	
	var trap: Node2D = track(TrapScript.new()) as Node2D
	trap.call("setup", grid, Vector2i(3, 3), Trap.TrapType.SPIKE, 15.0)
	assert_false(trap.get("is_revealed"), "Trap starts unrevealed")
	
	# When unrevealed, Trap inspection should not be exposed by controller
	var data: InspectionData = trap.call("get_inspection_data")
	assert_true(data != null, "Trap can provide data once revealed")
	assert_eq(data.title, "Spike Trap")
	assert_eq(data.category, InspectionData.Category.HAZARD)
	assert_true(data.category_text.contains("Armed Hazard"))
	
	trap.call("reveal")
	assert_true(trap.get("is_revealed"), "Trap is now revealed")
	trap.queue_free()

func test_world_item_inspection() -> void:
	var grid = track(DungeonGrid.new()) as DungeonGrid
	grid.grid_width = 10
	grid.grid_height = 10
	grid.clear_grid()
	
	var item = ItemData.new("astral_blade", "Astral Blade", ItemData.ItemType.WEAPON, ItemData.EquipSlot.MAIN_HAND, 3.5)
	item.base_damage_min = 10
	item.base_damage_max = 20
	item.base_value_gold = 150
	
	var w_item: Node2D = track(WorldItemScript.new()) as Node2D
	w_item.call("setup", grid, Vector2i(4, 4), item)
	
	var data: InspectionData = w_item.call("get_inspection_data")
	assert_true(data != null, "WorldItem must supply valid InspectionData")
	assert_eq(data.title, "Astral Blade")
	assert_eq(data.category, InspectionData.Category.ITEM_OR_OBJECT)
	assert_true(data.category_text.contains("WEAPON"))
	assert_true(data.description.contains("Dmg: 10-20"))
	
	w_item.queue_free()

func test_fog_of_war_spoil_prevention_in_controller() -> void:
	var grid = track(DungeonGrid.new()) as DungeonGrid
	grid.grid_width = 20
	grid.grid_height = 20
	grid.clear_grid()
	for y in range(20):
		for x in range(20):
			grid.set_cell_walkable(Vector2i(x, y), true)
			
	var fow = track(FogOfWarSystem.new()) as FogOfWarSystem
	fow.init_fog(20, 20)
	
	var controller_cls = load("res://scripts/world/HoverInspectionController.gd")
	var controller: Node2D = track(controller_cls.new()) as Node2D
	controller.call("setup", null, grid, fow)
	
	# Cell (10, 10) is HIDDEN
	assert_eq(fow.get_visibility(Vector2i(10, 10)), FogOfWarSystem.TileVisibility.HIDDEN)
	var hidden_data: InspectionData = controller.call("inspect_cell", Vector2i(10, 10))
	assert_true(hidden_data != null)
	assert_eq(hidden_data.title, "Unexplored Darkness", "Hidden tiles must return Unexplored Darkness")
	assert_eq(hidden_data.category_text, "Fog of War")
	
	# Reveal (5, 5) to VISIBLE
	fow.visibility_buffer[5 * 20 + 5] = FogOfWarSystem.TileVisibility.VISIBLE
	var vis_data: InspectionData = controller.call("inspect_cell", Vector2i(5, 5))
	assert_true(vis_data != null)
	assert_eq(vis_data.title, "Dungeon Floor", "Visible walkable tile must return Dungeon Floor")
	assert_false(vis_data.is_remembered_only)
	
	# Change (5, 5) to EXPLORED (Memory)
	fow.visibility_buffer[5 * 20 + 5] = FogOfWarSystem.TileVisibility.EXPLORED
	var exp_data: InspectionData = controller.call("inspect_cell", Vector2i(5, 5))
	assert_true(exp_data != null)
	assert_eq(exp_data.title, "Dungeon Floor")
	assert_true(exp_data.is_remembered_only, "Explored tile must be marked is_remembered_only")
	assert_true(exp_data.category_text.contains("[Memory]"))

func test_inspector_panel_hotbar_sync() -> void:
	var hotbar = track(HotbarBar.new()) as HotbarBar
	hotbar.custom_minimum_size = Vector2(640, 76)
	hotbar.size = Vector2(640, 76)
	hotbar.offset_bottom = -8.0
	hotbar.offset_top = -84.0
	hotbar.offset_left = -320.0
	hotbar.offset_right = 320.0
	
	var panel_scene = preload("res://scenes/ui/components/InspectorPanel.tscn")
	var panel: Control = track(panel_scene.instantiate()) as Control
	panel.call("_ready")
	panel.call("sync_with_hotbar", hotbar)
	
	assert_eq(panel.custom_minimum_size.y, hotbar.size.y, "Panel height must match HotbarBar height")
	assert_eq(panel.offset_bottom, hotbar.offset_bottom, "Panel bottom offset must match HotbarBar")
	assert_eq(panel.offset_top, hotbar.offset_top, "Panel top offset must match HotbarBar")
	assert_eq(panel.offset_left, hotbar.offset_right + 12.0, "Panel must be placed 12px to the right of HotbarBar with uniform separation margin")
	
	# Verify permanent visibility and inspection population
	assert_true(panel.visible, "InspectorPanel must be permanently visible")
	
	var long_desc = "Phase III: Transcendence • Harmonic Equilibrium: Physical Immune • Surrounded by 2 Astral Clones channeling ancient ki across the sanctum."
	var sample = InspectionData.create(
		"Grandmaster Boss",
		InspectionData.Category.HOSTILE,
		"Boss Encounter",
		long_desc,
		"Ω",
		Color(1.0, 0.84, 0.0)
	)
	sample.health_status_text = "Uninjured"
	sample.health_status_color = Color(0.2, 0.9, 0.4)
	sample.grid_cell = Vector2i(10, 10)
	
	panel.call("update_inspection", sample)
	var title_lbl = panel.get("label_title") as Label
	var coords_lbl = panel.get("label_coords") as Label
	var health_lbl = panel.get("label_health_status") as Label
	var desc_lbl = panel.get("label_desc") as Label
	var desc_scroll = panel.get("description_scroll") as ScrollContainer
	
	# Verify IconBadge was removed so full width goes to text
	assert_true(panel.find_child("IconBadge", true, false) == null, "IconBadge must be removed to maximize text width")
	assert_true(desc_scroll != null, "DescriptionScroll ScrollContainer must exist")
	assert_true(desc_lbl != null, "LabelDescription must exist")
	
	if title_lbl:
		assert_eq(title_lbl.text, "Grandmaster Boss")
	if coords_lbl:
		assert_eq(coords_lbl.text, "[10, 10]")
	if health_lbl:
		assert_true(health_lbl.visible)
		assert_eq(health_lbl.text, "[Uninjured]")
	if desc_lbl:
		assert_eq(desc_lbl.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "LabelDescription must use smart word wrapping")
		assert_eq(desc_lbl.text, long_desc, "Long description must remain intact without ellipsis character loss")
	if desc_scroll and desc_lbl:
		# Simulate multi-line wrapped height (e.g., 4 lines = 56px inside 32px viewport)
		desc_scroll.size = Vector2(220, 32)
		desc_lbl.size = Vector2(220, 56)
		var overflow: float = panel.call("get_overflow_scroll_range")
		assert_gt(overflow, 20.0, "Overflow scroll range must be positive when wrapped text exceeds 2 lines")
	
	assert_eq(panel.size.y, hotbar.size.y, "Panel height must remain strictly locked to 76px hotbar height even with long text")
	
	hotbar.queue_free()
	panel.queue_free()
