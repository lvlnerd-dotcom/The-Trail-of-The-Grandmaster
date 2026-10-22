@tool
extends McpTestSuite

## TestInventoryUiUx: Verification suite for the Inventory UI/UX overhaul covering:
## - Compact, top-level, non-blocking 260px ItemTooltip
## - Delayed hover (0.15s) vs immediate inspect display
## - Viewport clamping & edge-flipping
## - Rich stats & equipped stat comparison (▲/▼)
## - Custom ItemSlot 52x52 hitboxes & dynamic overflow expansion (>40 slots)
## - Category filter tabs, auto-stacking, and sorting
## - Left-click selection, double-click equip/unequip, and paperdoll context actions
## - Weight progress bar and Shop/Loot modal tooltips

const ItemTooltip = preload("res://scripts/ui/ItemTooltip.gd")
const ItemSlot = preload("res://scripts/ui/ItemSlot.gd")
const InventoryModal = preload("res://scripts/ui/InventoryModal.gd")
const ItemData = preload("res://scripts/resources/ItemData.gd")
const SkillData = preload("res://scripts/resources/SkillData.gd")
const AttributesData = preload("res://scripts/resources/AttributesData.gd")
const InventoryComponent = preload("res://scripts/components/InventoryComponent.gd")
const SkillComponent = preload("res://scripts/components/SkillComponent.gd")
const StatsComponent = preload("res://scripts/components/StatsComponent.gd")
const ShopModal = preload("res://scripts/ui/ShopModal.gd")
const LootPickupModal = preload("res://scripts/ui/LootPickupModal.gd")
const BaseEntity = preload("res://scripts/entities/BaseEntity.gd")

func suite_name() -> String:
	return "inventory_ui_ux"

func _create_mock_player() -> Node2D:
	var ent = track(BaseEntity.new()) as BaseEntity
	ent.name = "TestPlayer"

	var stats = track(StatsComponent.new()) as StatsComponent
	stats.name = "StatsComponent"
	stats.attributes = AttributesData.new()
	ent.add_child(stats)
	stats._ready()

	var inv = track(InventoryComponent.new()) as InventoryComponent
	inv.name = "InventoryComponent"
	ent.add_child(inv)

	var skills = track(SkillComponent.new()) as SkillComponent
	skills.name = "SkillComponent"
	ent.add_child(skills)
	skills._ready()

	return ent

func test_tooltip_top_level_and_260px_width() -> void:
	var scene = load("res://scenes/ui/components/ItemTooltip.tscn")
	assert_true(scene != null, "ItemTooltip.tscn must load successfully")
	var tooltip = track(scene.instantiate()) as ItemTooltip
	assert_true(tooltip != null, "ItemTooltip instance must be valid")
	
	tooltip._ready()
	assert_true(tooltip.top_level, "ItemTooltip must be top_level to avoid container stretching")
	assert_eq(tooltip.z_index, 90, "ItemTooltip z_index must be 90")
	assert_eq(tooltip.custom_minimum_size.x, 260.0, "Tooltip custom_minimum_size width must be 260")

	var item = ItemData.new("test_sword", "Steel Longsword", ItemData.ItemType.WEAPON, ItemData.EquipSlot.MAIN_HAND, 3.0, 1)
	item.description = "A finely tempered blade forged by dwarven artisans. Long enough to keep foes at bay."
	
	tooltip.display_item(item, Vector2(100, 100))
	assert_true(tooltip.visible, "Tooltip must be visible after display_item")
	assert_eq(tooltip.size.x, 260.0, "Tooltip size.x must be locked to 260px")
	assert_true(tooltip.size.y < 350.0, "Tooltip height must fit content dynamically and remain under 350px")
	assert_eq(tooltip.label_desc.max_lines_visible, 4, "Item lore description must be capped at 4 lines")

func test_tooltip_descendants_ignore_mouse() -> void:
	var scene = load("res://scenes/ui/components/ItemTooltip.tscn")
	var tooltip = track(scene.instantiate()) as ItemTooltip
	tooltip._ready()

	assert_eq(tooltip.mouse_filter, Control.MOUSE_FILTER_IGNORE, "Root tooltip mouse_filter must be IGNORE")
	
	# Verify every single descendant Control ignores mouse events
	var stack: Array[Node] = [tooltip]
	while not stack.is_empty():
		var node = stack.pop_back()
		if node is Control:
			assert_eq(
				(node as Control).mouse_filter,
				Control.MOUSE_FILTER_IGNORE,
				"Descendant %s must have mouse_filter == MOUSE_FILTER_IGNORE" % node.name
			)
		for child in node.get_children():
			stack.append(child)

func test_tooltip_hover_delay_and_immediate_display() -> void:
	var scene = load("res://scenes/ui/components/ItemTooltip.tscn")
	var tooltip = track(scene.instantiate()) as ItemTooltip
	if Engine.get_main_loop() is SceneTree:
		(Engine.get_main_loop() as SceneTree).root.add_child(tooltip)
	tooltip._ready()

	var item = ItemData.new("potion_minor", "Minor Healing Draught", ItemData.ItemType.CONSUMABLE, ItemData.EquipSlot.NONE, 0.5, 1)

	# 1. request_hover_item: must not show immediately when tooltip was hidden
	tooltip.request_hover_item(item, Vector2(50, 50))
	assert_false(tooltip.visible, "request_hover_item must not show tooltip immediately")
	assert_true(tooltip._hover_timer != null and not tooltip._hover_timer.is_stopped(), "Hover timer must be ticking")

	# 2. Simulate timer expiry: displays item
	tooltip._on_hover_timeout()
	assert_true(tooltip.visible, "Tooltip must be visible once hover timer fires")

	# 3. Moving to another slot while already visible switches immediately
	var item2 = ItemData.new("potion_mana", "Mana Draught", ItemData.ItemType.CONSUMABLE, ItemData.EquipSlot.NONE, 0.5, 1)
	tooltip.request_hover_item(item2, Vector2(75, 75))
	assert_true(tooltip.visible, "Switching slots when already visible must update immediately")
	assert_eq(tooltip.label_name.text, "Mana Draught", "Tooltip must immediately display new item")

	# 4. cancel_hover hides tooltip and stops timer
	tooltip.cancel_hover()
	assert_false(tooltip.visible, "cancel_hover must hide tooltip")
	assert_true(tooltip._hover_timer.is_stopped(), "cancel_hover must stop hover timer")

func test_tooltip_viewport_clamp_and_flip() -> void:
	var scene = load("res://scenes/ui/components/ItemTooltip.tscn")
	var tooltip = track(scene.instantiate()) as ItemTooltip
	tooltip._ready()

	var item = ItemData.new("test_shield", "Bronze Buckler", ItemData.ItemType.SHIELD, ItemData.EquipSlot.OFF_HAND, 2.5, 1)
	
	# Place near bottom-right screen edge (e.g. 1270, 710 in a 1280x720 viewport)
	var cursor = Vector2(1270, 710)
	tooltip.display_item(item, cursor)

	# Tooltip must flip left of cursor and above cursor
	assert_true(tooltip.global_position.x < cursor.x, "Tooltip must flip to the left when cursor is near right edge")
	assert_true(tooltip.global_position.y < cursor.y, "Tooltip must flip upwards when cursor is near bottom edge")
	assert_true(tooltip.global_position.x >= ItemTooltip.SCREEN_MARGIN, "Tooltip must stay within left screen margin")
	assert_true(tooltip.global_position.y >= ItemTooltip.SCREEN_MARGIN, "Tooltip must stay within top screen margin")

func test_tooltip_equipped_stat_comparison_and_rich_stats() -> void:
	var scene = load("res://scenes/ui/components/ItemTooltip.tscn")
	var tooltip = track(scene.instantiate()) as ItemTooltip
	tooltip._ready()

	var player = _create_mock_player()
	var skills = player.get_node("SkillComponent") as SkillComponent
	var sword_skill = skills.get_skill(SkillData.SkillId.SWORDSMANSHIP)
	sword_skill.level = 25.0

	var equipped_sword = ItemData.new("sword_iron", "Iron Broadsword", ItemData.ItemType.WEAPON, ItemData.EquipSlot.MAIN_HAND, 2.0, 1)
	equipped_sword.base_damage_min = 2
	equipped_sword.base_damage_max = 6
	equipped_sword.accuracy_bonus = 0.0

	var hovered_claymore = ItemData.new("sword_silver", "Silver Claymore", ItemData.ItemType.WEAPON, ItemData.EquipSlot.MAIN_HAND, 4.0, 1)
	hovered_claymore.base_damage_min = 4
	hovered_claymore.base_damage_max = 12
	hovered_claymore.accuracy_bonus = 0.10
	hovered_claymore.is_silver = true
	hovered_claymore.unlocked_ability_name = "Whirlwind Cleave"

	tooltip.display_item(hovered_claymore, Vector2(100, 100), equipped_sword, skills)

	var text = tooltip.label_stats.text
	assert_true(text.contains("▲ +6 Damage"), "Tooltip comparison must show positive damage delta (+6)")
	assert_true(text.contains("▲ +10% Accuracy"), "Tooltip comparison must show positive accuracy delta (+10%)")
	assert_true(text.contains("Silver Weapon"), "Tooltip must display Silver Weapon trait")
	assert_true(text.contains("Whirlwind Cleave [Unlocked]"), "Level 25 ability must be displayed as [Unlocked] when skill >= 25")

func test_item_slot_hitboxes_and_dynamic_overflow() -> void:
	var scene = load("res://scenes/ui/menus/InventoryModal.tscn")
	var modal = track(scene.instantiate()) as InventoryModal
	modal._ready()

	var player = _create_mock_player()
	var inv = player.get_node("InventoryComponent") as InventoryComponent

	# Add 46 items to backpack (overflows default 40 slots)
	for i in range(46):
		var item = ItemData.new("dagger_%d" % i, "Dagger %d" % i, ItemData.ItemType.WEAPON, ItemData.EquipSlot.MAIN_HAND, 0.5, 1)
		inv.items.append(item)

	modal.open_modal_with_player(player)

	# Verify grid dynamically expanded beyond 40 slots into complete 8-column rows (ceil(47 / 8) * 8 = 48 slots)
	assert_true(modal.backpack_buttons.size() >= 48, "Backpack slots must expand dynamically to hold 46+ items (>= 48 slots)")
	
	# Verify uniform 52x52 hitboxes
	var slot0 = modal.backpack_buttons[0] as ItemSlot
	assert_true(slot0 != null, "Backpack button must be an ItemSlot")
	assert_eq(slot0.custom_minimum_size, Vector2(52, 52), "Backpack slot must have 52x52 custom_minimum_size")

	var paperdoll_main = modal.paperdoll_buttons[ItemData.EquipSlot.MAIN_HAND] as ItemSlot
	assert_true(paperdoll_main != null, "Paperdoll slot must be an ItemSlot")
	assert_eq(paperdoll_main.custom_minimum_size, Vector2(52, 52), "Paperdoll slot must have 52x52 custom_minimum_size")

func test_filter_tabs_sort_and_autostack() -> void:
	var scene = load("res://scenes/ui/menus/InventoryModal.tscn")
	var modal = track(scene.instantiate()) as InventoryModal
	modal._ready()

	var player = _create_mock_player()
	var inv = player.get_node("InventoryComponent") as InventoryComponent

	# Add 2 Weapons, 1 Consumable, 1 Armor
	inv.add_item(ItemData.new("sword", "Steel Sword", ItemData.ItemType.WEAPON, ItemData.EquipSlot.MAIN_HAND, 2.0, 1))
	inv.add_item(ItemData.new("bow", "Hunting Bow", ItemData.ItemType.WEAPON, ItemData.EquipSlot.MAIN_HAND, 1.5, 1))
	inv.add_item(ItemData.new("potion", "Healing Potion", ItemData.ItemType.CONSUMABLE, ItemData.EquipSlot.NONE, 0.5, 1))
	inv.add_item(ItemData.new("cuirass", "Iron Cuirass", ItemData.ItemType.ARMOR, ItemData.EquipSlot.BODY, 6.0, 1))

	modal.open_modal_with_player(player)

	# Test Filter: WEAPONS
	modal.set_filter("WEAPONS")
	var filtered = modal._get_filtered_indices()
	assert_eq(filtered.size(), 2, "Filtering by WEAPONS must return 2 items")

	# Test Sorting: Value
	inv.items[0].base_value_gold = 10
	inv.items[1].base_value_gold = 50
	inv.sort_backpack("value")
	assert_eq(inv.items[0].base_value_gold, 50, "Sorting by value must place highest value item first")

	# Test Auto-Stacking
	var potion_a = ItemData.new("pot_heal", "Health Potion", ItemData.ItemType.CONSUMABLE, ItemData.EquipSlot.NONE, 0.5, 3)
	potion_a.max_stack = 10
	var potion_b = ItemData.new("pot_heal", "Health Potion", ItemData.ItemType.CONSUMABLE, ItemData.EquipSlot.NONE, 0.5, 4)
	potion_b.max_stack = 10

	inv.items.clear()
	inv.items.append(potion_a)
	inv.items.append(potion_b)
	inv.auto_stack_backpack()

	assert_eq(inv.items.size(), 1, "Auto-stacking identical stackables must merge into a single slot")
	assert_eq(inv.items[0].quantity, 7, "Auto-stacked quantity must equal sum (3 + 4 = 7)")

func test_double_click_and_paperdoll_context_actions() -> void:
	var scene = load("res://scenes/ui/menus/InventoryModal.tscn")
	var modal = track(scene.instantiate()) as InventoryModal
	modal._ready()

	var player = _create_mock_player()
	var inv = player.get_node("InventoryComponent") as InventoryComponent
	var sword = ItemData.new("sword_duelist", "Rapier", ItemData.ItemType.WEAPON, ItemData.EquipSlot.MAIN_HAND, 1.5, 1)
	inv.add_item(sword)

	modal.open_modal_with_player(player)

	# 1. Double-click backpack equipment equips it to paperdoll
	var slot0 = modal.backpack_buttons[0] as ItemSlot
	modal._on_slot_double_clicked(slot0)
	assert_eq(inv.equipped_slots.get(ItemData.EquipSlot.MAIN_HAND), sword, "Double-clicking weapon must equip it to MAIN_HAND")

	# 2. Double-click equipped paperdoll slot unequips it back to backpack
	var main_hand_slot = modal.paperdoll_buttons[ItemData.EquipSlot.MAIN_HAND] as ItemSlot
	modal._on_slot_double_clicked(main_hand_slot)
	assert_false(inv.equipped_slots.has(ItemData.EquipSlot.MAIN_HAND), "Double-clicking paperdoll slot must unequip it")
	assert_true(inv.items.has(sword), "Unequipped sword must return to backpack")

	# 3. Paperdoll right-click context menu options
	inv.equip_item(sword)
	modal.refresh_inventory()
	modal._on_slot_right_clicked(main_hand_slot, Vector2(100, 100))
	var actions = modal.get_item_context_actions(sword)
	assert_true(actions.has("Unequip"), "Equipped paperdoll item context menu must contain Unequip")
	assert_true(actions.has("Inspect"), "Equipped paperdoll item context menu must contain Inspect")
	assert_true(actions.has("Drop"), "Equipped paperdoll item context menu must contain Drop")

func test_weight_progress_bar_and_shop_loot_tooltips() -> void:
	var inv_scene = load("res://scenes/ui/menus/InventoryModal.tscn")
	var modal = track(inv_scene.instantiate()) as InventoryModal
	modal._ready()

	var player = _create_mock_player()
	var stats = player.get_node("StatsComponent") as StatsComponent
	stats.attributes.strength = 2
	var inv = player.get_node("InventoryComponent") as InventoryComponent
	
	# Normal weight: 5 stones / 20 stones max = 25% ratio
	var light_item = ItemData.new("light_item", "Light Bundle", ItemData.ItemType.VALUABLE, ItemData.EquipSlot.NONE, 5.0, 1)
	inv.add_item(light_item)
	modal.open_modal_with_player(player)

	assert_true(modal.weight_bar != null, "WeightProgressBar must exist in InventoryModal")
	assert_eq(modal.weight_bar.value, 0.25, "WeightProgressBar ratio must be 0.25")

	# Overburdened state: 25 stones / 20 stones max = 125% ratio (clamped to 1.0)
	var heavy_item = ItemData.new("heavy_item", "Giant Boulder", ItemData.ItemType.VALUABLE, ItemData.EquipSlot.NONE, 20.0, 1)
	inv.add_item(heavy_item)
	modal.refresh_inventory()

	assert_eq(modal.weight_bar.value, 1.0, "WeightProgressBar value must be clamped to 1.0 when overburdened")

	# ShopModal tooltip instantiation
	var shop_scene = load("res://scenes/ui/menus/ShopModal.tscn")
	assert_true(shop_scene != null, "ShopModal scene must load")
	var shop = track(shop_scene.instantiate()) as ShopModal
	shop._ready()
	assert_true(shop.tooltip != null, "ShopModal must instantiate an ItemTooltip")

	# LootPickupModal tooltip instantiation
	var loot_scene = load("res://scenes/ui/menus/LootPickupModal.tscn")
	assert_true(loot_scene != null, "LootPickupModal scene must load")
	var loot = track(loot_scene.instantiate()) as LootPickupModal
	loot._ready()
	assert_true(loot.tooltip != null, "LootPickupModal must instantiate an ItemTooltip")
