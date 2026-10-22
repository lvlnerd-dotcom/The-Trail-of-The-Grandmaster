@tool
class_name InventoryModal
extends BaseModal

## InventoryModal: Grid-based inventory management with 12-slot anatomical paperdoll,
## item action context menu, category filter tabs, sorting, auto-stacking,
## drag-and-drop equipping/reordering, and responsive hover statistics.

signal item_action_completed()
signal item_dropped(item: ItemData)
signal item_thrown_requested(item: ItemData)
signal item_used(item: ItemData, result: Dictionary)
signal crafting_modal_requested()

const MIN_BACKPACK_SLOTS: int = 40
const PAPERDOLL_SLOTS = [
	ItemData.EquipSlot.HEAD,
	ItemData.EquipSlot.BACK,
	ItemData.EquipSlot.MAIN_HAND,
	ItemData.EquipSlot.OFF_HAND,
	ItemData.EquipSlot.BODY,
	ItemData.EquipSlot.BELT,
	ItemData.EquipSlot.LEGS,
	ItemData.EquipSlot.FEET,
	ItemData.EquipSlot.RING_1,
	ItemData.EquipSlot.RING_2,
	ItemData.EquipSlot.ACCESSORY,
	ItemData.EquipSlot.AMMUNITION
]

@onready var grid_container: GridContainer = get_node_or_null("VBox/MainSplit/BackpackPane/ScrollBackpack/GridSlots")
@onready var paperdoll_container: Control = get_node_or_null("VBox/MainSplit/PaperdollPane/SilhouetteBox")
@onready var label_weight: Label = get_node_or_null("VBox/FooterBar/WeightBarContainer/LabelWeight")
@onready var weight_bar: ProgressBar = get_node_or_null("VBox/FooterBar/WeightBarContainer/WeightProgressBar")
@onready var label_gold: Label = get_node_or_null("VBox/FooterBar/LabelGold")
@onready var label_armor: Label = get_node_or_null("VBox/FooterBar/LabelArmor")
@onready var btn_close: Button = get_node_or_null("VBox/HeaderBar/BtnClose")
@onready var tooltip: ItemTooltip = get_node_or_null("ItemTooltip")

@onready var filter_toolbar: HBoxContainer = get_node_or_null("VBox/MainSplit/BackpackPane/FilterToolbar")
@onready var btn_sort: Button = get_node_or_null("VBox/MainSplit/BackpackPane/FilterToolbar/BtnSort")
@onready var btn_stack: Button = get_node_or_null("VBox/MainSplit/BackpackPane/FilterToolbar/BtnStack")

var player: Node2D = null
var inventory: InventoryComponent = null
var attributes: AttributesData = null
var backpack_buttons: Array[Button] = []
var paperdoll_buttons: Dictionary = {} # EquipSlot -> Button

var selected_slot: ItemSlot = null
var active_filter: String = "ALL"
var sort_modes: Array[String] = ["Type", "Weight", "Value", "Name"]
var current_sort_index: int = 0

# Action Context Menu
var context_menu_panel: PanelContainer = null
var active_context_item: ItemData = null
var active_context_slot: ItemSlot = null

func _ready() -> void:
	close_on_escape = true
	super._ready()
	_resolve_modal_nodes()
	
	if btn_close and not btn_close.pressed.is_connected(close_modal):
		btn_close.pressed.connect(close_modal)
		
	_setup_toolbar_controls()
	_setup_weight_bar_events()
	_build_ui_slots()
	_build_context_menu()

func _resolve_modal_nodes() -> void:
	if not grid_container:
		grid_container = get_node_or_null("VBox/MainSplit/BackpackPane/ScrollBackpack/GridSlots") as GridContainer
	if not paperdoll_container:
		paperdoll_container = get_node_or_null("VBox/MainSplit/PaperdollPane/SilhouetteBox") as Control
	if not label_weight:
		label_weight = get_node_or_null("VBox/FooterBar/WeightBarContainer/LabelWeight") as Label
		if not label_weight:
			label_weight = get_node_or_null("VBox/FooterBar/LabelWeight") as Label
	if not weight_bar:
		weight_bar = get_node_or_null("VBox/FooterBar/WeightBarContainer/WeightProgressBar") as ProgressBar
	if not label_gold:
		label_gold = get_node_or_null("VBox/FooterBar/LabelGold") as Label
	if not label_armor:
		label_armor = get_node_or_null("VBox/FooterBar/LabelArmor") as Label
	if not btn_close:
		btn_close = get_node_or_null("VBox/HeaderBar/BtnClose") as Button
	if not tooltip:
		tooltip = get_node_or_null("ItemTooltip") as ItemTooltip
	if not filter_toolbar:
		filter_toolbar = get_node_or_null("VBox/MainSplit/BackpackPane/FilterToolbar") as HBoxContainer
	if not btn_sort:
		btn_sort = get_node_or_null("VBox/MainSplit/BackpackPane/FilterToolbar/BtnSort") as Button
	if not btn_stack:
		btn_stack = get_node_or_null("VBox/MainSplit/BackpackPane/FilterToolbar/BtnStack") as Button

func _setup_toolbar_controls() -> void:
	if filter_toolbar:
		for child in filter_toolbar.get_children():
			if child is Button and child != btn_sort and child != btn_stack:
				var f_btn = child as Button
				var filter_name = f_btn.text.to_upper().strip_edges()
				if not f_btn.pressed.is_connected(set_filter.bind(filter_name)):
					f_btn.pressed.connect(set_filter.bind(filter_name))

	if btn_sort and not btn_sort.pressed.is_connected(_on_sort_pressed):
		btn_sort.pressed.connect(_on_sort_pressed)

	if btn_stack and not btn_stack.pressed.is_connected(_on_stack_pressed):
		btn_stack.pressed.connect(_on_stack_pressed)

func _setup_weight_bar_events() -> void:
	if weight_bar:
		weight_bar.mouse_filter = Control.MOUSE_FILTER_STOP
		if not weight_bar.mouse_entered.is_connected(_on_weight_bar_mouse_entered):
			weight_bar.mouse_entered.connect(_on_weight_bar_mouse_entered)
		if not weight_bar.mouse_exited.is_connected(_on_weight_bar_mouse_exited):
			weight_bar.mouse_exited.connect(_on_weight_bar_mouse_exited)

func set_filter(filter_name: String) -> void:
	active_filter = filter_name
	refresh_inventory()

func _on_sort_pressed() -> void:
	current_sort_index = (current_sort_index + 1) % sort_modes.size()
	var mode = sort_modes[current_sort_index]
	if btn_sort:
		btn_sort.text = "Sort: %s" % mode
	if inventory:
		inventory.sort_backpack(mode.to_lower())
		refresh_inventory()

func _on_stack_pressed() -> void:
	if inventory:
		inventory.auto_stack_backpack()
		refresh_inventory()

func open_modal_with_player(p_player: Node2D) -> void:
	player = p_player
	if player:
		inventory = player.get_node_or_null("InventoryComponent") as InventoryComponent
		var stats = player.get_node_or_null("StatsComponent") as StatsComponent
		if stats:
			attributes = stats.attributes
	super.open_modal()
	close_context_menu()
	if tooltip:
		tooltip.cancel_hover()
	refresh_inventory()

func close_modal() -> void:
	close_context_menu()
	if tooltip:
		tooltip.cancel_hover()
	super.close_modal()

func _build_ui_slots() -> void:
	_resolve_modal_nodes()
	if not grid_container:
		return
		
	# Clean existing backpack slots
	for c in grid_container.get_children():
		c.queue_free()
	backpack_buttons.clear()
	
	# Instantiate default 40 backpack ItemSlot controls
	for i in range(MIN_BACKPACK_SLOTS):
		var slot = _create_backpack_slot(i)
		grid_container.add_child(slot)
		backpack_buttons.append(slot)
		
	# Build / upgrade paperdoll slot buttons to ItemSlot
	if paperdoll_container:
		for slot in PAPERDOLL_SLOTS:
			var slot_name = ItemData.EquipSlot.keys()[slot]
			var existing = paperdoll_container.get_node_or_null("Slot_" + slot_name)
			var p_slot: ItemSlot = null
			if existing is ItemSlot:
				p_slot = existing
			else:
				var idx = existing.get_index() if existing else -1
				if existing:
					existing.queue_free()
				p_slot = ItemSlot.new()
				p_slot.name = "Slot_" + slot_name
				if idx >= 0:
					paperdoll_container.add_child(p_slot)
					paperdoll_container.move_child(p_slot, idx)
				else:
					paperdoll_container.add_child(p_slot)

			p_slot.is_paperdoll = true
			p_slot.equip_slot = slot
			p_slot.slot_title = ItemData.get_slot_name(slot)
			p_slot.custom_minimum_size = Vector2(52, 52)
			p_slot.clear_slot()

			if not p_slot.slot_left_clicked.is_connected(_on_slot_left_clicked):
				p_slot.slot_left_clicked.connect(_on_slot_left_clicked)
			if not p_slot.slot_double_clicked.is_connected(_on_slot_double_clicked):
				p_slot.slot_double_clicked.connect(_on_slot_double_clicked)
			if not p_slot.slot_right_clicked.is_connected(_on_slot_right_clicked):
				p_slot.slot_right_clicked.connect(_on_slot_right_clicked)
			if not p_slot.slot_item_dropped.is_connected(_on_slot_item_dropped):
				p_slot.slot_item_dropped.connect(_on_slot_item_dropped)
			if not p_slot.mouse_entered.is_connected(_on_paperdoll_slot_mouse_entered.bind(p_slot)):
				p_slot.mouse_entered.connect(_on_paperdoll_slot_mouse_entered.bind(p_slot))
			if not p_slot.mouse_exited.is_connected(_on_slot_mouse_exited):
				p_slot.mouse_exited.connect(_on_slot_mouse_exited)

			paperdoll_buttons[slot] = p_slot

func _create_backpack_slot(idx: int) -> ItemSlot:
	var slot = ItemSlot.new()
	slot.custom_minimum_size = Vector2(52, 52)
	slot.slot_index = idx
	slot.is_paperdoll = false
	slot.clear_slot()

	slot.slot_left_clicked.connect(_on_slot_left_clicked)
	slot.slot_double_clicked.connect(_on_slot_double_clicked)
	slot.slot_right_clicked.connect(_on_slot_right_clicked)
	slot.slot_item_dropped.connect(_on_slot_item_dropped)
	slot.mouse_entered.connect(_on_backpack_slot_mouse_entered.bind(slot))
	slot.mouse_exited.connect(_on_slot_mouse_exited)
	return slot

func _build_context_menu() -> void:
	if context_menu_panel:
		return
	context_menu_panel = PanelContainer.new()
	context_menu_panel.name = "ContextMenuPanel"
	context_menu_panel.visible = false
	context_menu_panel.top_level = true
	context_menu_panel.z_index = 100
	
	var flat = StyleBoxFlat.new()
	flat.bg_color = Color(0.08, 0.10, 0.14, 0.98)
	flat.border_width_left = 2
	flat.border_width_top = 2
	flat.border_width_right = 2
	flat.border_width_bottom = 2
	flat.border_color = Color(0.3, 0.38, 0.5, 1.0)
	flat.corner_radius_top_left = 4
	flat.corner_radius_top_right = 4
	flat.corner_radius_bottom_right = 4
	flat.corner_radius_bottom_left = 4
	flat.content_margin_left = 6.0
	flat.content_margin_top = 6.0
	flat.content_margin_right = 6.0
	flat.content_margin_bottom = 6.0
	context_menu_panel.add_theme_stylebox_override("panel", flat)
	
	var vbox = VBoxContainer.new()
	vbox.name = "MenuButtons"
	vbox.add_theme_constant_override("separation", 4)
	context_menu_panel.add_child(vbox)
	
	add_child(context_menu_panel)

func _get_filtered_indices() -> Array[int]:
	var indices: Array[int] = []
	if not inventory:
		return indices

	for i in range(inventory.items.size()):
		var item = inventory.items[i]
		if not is_instance_valid(item):
			continue
		if _item_matches_filter(item):
			indices.append(i)
	return indices

func _item_matches_filter(item: ItemData) -> bool:
	if active_filter == "ALL":
		return true
	match active_filter:
		"WEAPONS":
			return item.item_type == ItemData.ItemType.WEAPON
		"ARMOR":
			return item.item_type == ItemData.ItemType.ARMOR or item.item_type == ItemData.ItemType.SHIELD
		"CONSUMABLES":
			return item.item_type == ItemData.ItemType.CONSUMABLE
		"AMMO":
			return item.item_type == ItemData.ItemType.AMMO
		"OTHER":
			return item.item_type == ItemData.ItemType.RELIC or item.item_type == ItemData.ItemType.VALUABLE
		_:
			return true

func refresh_inventory() -> void:
	if not inventory:
		return
		
	var filtered_indices = _get_filtered_indices()

	# Dynamic backpack slot count calculation (P2-B)
	var needed_slots = maxi(MIN_BACKPACK_SLOTS, int(ceil(float(filtered_indices.size() + 1) / 8.0)) * 8)

	while backpack_buttons.size() < needed_slots:
		var new_idx = backpack_buttons.size()
		var slot = _create_backpack_slot(new_idx)
		if grid_container:
			grid_container.add_child(slot)
		backpack_buttons.append(slot)

	while backpack_buttons.size() > needed_slots:
		var last = backpack_buttons.pop_back()
		if is_instance_valid(last):
			last.queue_free()

	# 1. Refresh Backpack Grid
	for i in range(backpack_buttons.size()):
		var btn = backpack_buttons[i]
		if btn is ItemSlot:
			var slot = btn as ItemSlot
			if i < filtered_indices.size():
				var real_idx = filtered_indices[i]
				var item = inventory.items[real_idx]
				slot.slot_index = real_idx
				slot.set_item(item)
			else:
				slot.slot_index = -1
				slot.clear_slot()
			slot.set_selected(slot == selected_slot)
			
	# 2. Refresh Paperdoll Slots
	for slot in PAPERDOLL_SLOTS:
		if paperdoll_buttons.has(slot):
			var btn = paperdoll_buttons[slot]
			if btn is ItemSlot:
				var p_slot = btn as ItemSlot
				if inventory.equipped_slots.has(slot):
					var item = inventory.equipped_slots[slot] as ItemData
					p_slot.set_item(item)
				else:
					p_slot.clear_slot()
				p_slot.set_selected(p_slot == selected_slot)
				
	# 3. Refresh Status Footer & Weight Bar (P2-H)
	_refresh_footer_and_weight()

func _refresh_footer_and_weight() -> void:
	var cur_w = inventory.get_carried_weight_stones() if inventory else 0.0
	var max_w = attributes.get_max_carry_weight_stones() if attributes else 20.0
	var ratio = cur_w / max_w if max_w > 0 else 0.0

	if label_weight:
		label_weight.text = "Weight: %.1f / %.0f Stones" % [cur_w, max_w]
		if cur_w > max_w:
			label_weight.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		elif ratio >= 0.75:
			label_weight.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
		else:
			label_weight.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))

	if weight_bar:
		weight_bar.value = clampf(ratio, 0.0, 1.0)
		var fill_flat = StyleBoxFlat.new()
		fill_flat.corner_radius_top_left = 2
		fill_flat.corner_radius_top_right = 2
		fill_flat.corner_radius_bottom_right = 2
		fill_flat.corner_radius_bottom_left = 2

		if ratio > 1.0:
			fill_flat.bg_color = Color(0.9, 0.2, 0.2, 0.95) # Red (Overburdened)
		elif ratio >= 0.75:
			fill_flat.bg_color = Color(0.95, 0.75, 0.2, 0.95) # Amber
		else:
			fill_flat.bg_color = Color(0.25, 0.8, 0.35, 0.95) # Green
		weight_bar.add_theme_stylebox_override("fill", fill_flat)
		
	if label_gold:
		var player_gold = player.get_meta("gold") if player and player.has_meta("gold") else (inventory.gold if inventory else 0)
		label_gold.text = "Gold: %d GP" % player_gold
	if label_armor:
		var total_arm = inventory.get_total_armor() if inventory else 0
		label_armor.text = "Total Armor: +%d Soak" % total_arm

func _on_weight_bar_mouse_entered() -> void:
	if not tooltip:
		return
	var cur_w = inventory.get_carried_weight_stones() if inventory else 0.0
	var max_w = attributes.get_max_carry_weight_stones() if attributes else 20.0
	var ratio_pct = int(round((cur_w / max_w) * 100.0)) if max_w > 0 else 0
	
	var text_title = "Carried Burden (%d%%)" % ratio_pct
	if cur_w > max_w:
		text_title = "OVERBURDENED (%d%%)" % ratio_pct
		
	tooltip.display_empty_slot(text_title, get_global_mouse_position())
	if tooltip.label_name:
		tooltip.label_name.text = text_title
		tooltip.label_name.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3) if cur_w > max_w else Color(0.8, 0.9, 1.0))
	if tooltip.label_type:
		tooltip.label_type.text = "Capacity: %.1f / %.0f Stones" % [cur_w, max_w]
	if tooltip.label_stats:
		var pen_text = "[color=#77ff88]Normal Movement & Agility[/color]"
		if cur_w > max_w:
			pen_text = "[color=#ff5555]Active Penalties:\n• Movement costs 2 turns\n• -20% Evasion Stance\n• -15% DEX Ranged Accuracy[/color]"
		tooltip.label_stats.text = pen_text
	if tooltip.label_weight_value:
		tooltip.label_weight_value.text = "Equipment worn is weight-exempt."
	if tooltip.label_desc:
		tooltip.label_desc.text = "Delvers carrying more than their maximum strength limit suffer heavy tactical fatigue."

func _on_weight_bar_mouse_exited() -> void:
	if tooltip:
		tooltip.cancel_hover()

# --- Slot Click & Interaction Handlers ---
func _on_slot_left_clicked(slot: ItemSlot) -> void:
	close_context_menu()
	selected_slot = slot
	for btn in backpack_buttons:
		if btn is ItemSlot:
			(btn as ItemSlot).set_selected(btn == selected_slot)
	for p_btn in paperdoll_buttons.values():
		if p_btn is ItemSlot:
			(p_btn as ItemSlot).set_selected(p_btn == selected_slot)

func _on_slot_double_clicked(slot: ItemSlot) -> void:
	close_context_menu()
	if not slot or not slot.item_data or not inventory:
		return

	if slot.is_paperdoll:
		# Unequip back to backpack
		inventory.unequip_slot(slot.equip_slot)
		refresh_inventory()
		_on_slot_mouse_exited()
		emit_signal("item_action_completed")
	else:
		# Double-click default action
		var it = slot.item_data
		if it.item_id == "mortar_and_pestle":
			execute_item_action(it, "Use (Craft)")
		elif it.equip_slot != ItemData.EquipSlot.NONE:
			execute_item_action(it, "Equip")
		elif it.item_type == ItemData.ItemType.CONSUMABLE or it.item_type == ItemData.ItemType.AMMO:
			execute_item_action(it, "Use (1 Turn)")

func _on_slot_right_clicked(slot: ItemSlot, global_pos: Vector2) -> void:
	if not slot or not slot.item_data:
		return
	if tooltip:
		tooltip.cancel_hover()
	active_context_item = slot.item_data
	active_context_slot = slot
	open_context_menu(slot.item_data, global_pos)

func _on_backpack_slot_mouse_entered(slot: ItemSlot) -> void:
	if not inventory or not tooltip:
		return
	if context_menu_panel and context_menu_panel.visible:
		return
	if slot.item_data:
		var compare_gear: ItemData = null
		if slot.item_data.equip_slot != ItemData.EquipSlot.NONE:
			compare_gear = inventory.equipped_slots.get(slot.item_data.equip_slot) as ItemData
		var player_skills = player.get_node_or_null("SkillComponent") as SkillComponent if player else null
		tooltip.request_hover_item(slot.item_data, get_global_mouse_position(), compare_gear, player_skills)

func _on_paperdoll_slot_mouse_entered(slot: ItemSlot) -> void:
	if not inventory or not tooltip:
		return
	if context_menu_panel and context_menu_panel.visible:
		return
	if slot.item_data:
		var player_skills = player.get_node_or_null("SkillComponent") as SkillComponent if player else null
		tooltip.request_hover_item(slot.item_data, get_global_mouse_position(), null, player_skills)
	else:
		tooltip.request_hover_empty_slot(slot.slot_title, get_global_mouse_position())

func _on_slot_mouse_exited() -> void:
	if tooltip:
		tooltip.cancel_hover()

# --- Drag and Drop State Machine (P2-D) ---
func notify_drag_started(data: Dictionary) -> void:
	if tooltip:
		tooltip.cancel_hover()
	close_context_menu()

	for slot in PAPERDOLL_SLOTS:
		if paperdoll_buttons.has(slot):
			var p_btn = paperdoll_buttons[slot]
			if p_btn is ItemSlot:
				var p_slot = p_btn as ItemSlot
				if p_slot._can_drop_data(Vector2.ZERO, data):
					p_slot.set_drag_highlight(1) # Valid Drop (Green)
				else:
					p_slot.set_drag_highlight(2) # Invalid Drop (Red)

func notify_drag_ended() -> void:
	for p_btn in paperdoll_buttons.values():
		if p_btn is ItemSlot:
			(p_btn as ItemSlot).set_drag_highlight(0)
	for b_btn in backpack_buttons:
		if b_btn is ItemSlot:
			(b_btn as ItemSlot).set_drag_highlight(0)

func _on_slot_item_dropped(source_slot: ItemSlot, target_slot: ItemSlot, data: Dictionary) -> void:
	notify_drag_ended()
	var it = data.get("item") as ItemData
	if not it or not inventory:
		return

	if target_slot.is_paperdoll:
		inventory.equip_item(it, target_slot.equip_slot)
	elif source_slot.is_paperdoll:
		inventory.unequip_slot(source_slot.equip_slot)
	else:
		# Backpack-to-backpack swap / reorder
		if source_slot.slot_index >= 0 and target_slot.slot_index >= 0:
			inventory.swap_backpack_items(source_slot.slot_index, target_slot.slot_index)

	refresh_inventory()
	emit_signal("item_action_completed")

# Allow dragging items outside modal or onto backdrop to drop on floor
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("item")

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	notify_drag_ended()
	if typeof(data) == TYPE_DICTIONARY and data.has("item"):
		var it = data["item"] as ItemData
		if it:
			if data.get("is_paperdoll", false):
				var eq_slot = data.get("equip_slot", ItemData.EquipSlot.NONE) as ItemData.EquipSlot
				inventory.unequip_slot(eq_slot)
			drop_item(it)

# --- Context Actions Specification ---
func get_item_context_actions(item: ItemData) -> Array[String]:
	if not item:
		return []

	if active_context_slot and active_context_slot.is_paperdoll:
		return ["Unequip", "Inspect", "Drop"]

	if item.item_id == "mortar_and_pestle":
		return ["Use (Craft)", "Equip", "Inspect", "Drop"]

	# Potions / Alchemical Vials
	if item.has_meta("is_potion") or item.tags.has("potion") or item.item_id.begins_with("potion_"):
		return ["Use (1 Turn)", "Throw", "Identify", "Inspect", "Drop"]

	# Scrolls / Books / Bandages / Medkits
	if item.item_type == ItemData.ItemType.CONSUMABLE:
		return ["Use (1 Turn)", "Inspect", "Drop"]

	# Equipment
	if item.equip_slot != ItemData.EquipSlot.NONE:
		return ["Equip", "Inspect", "Drop"]

	return ["Inspect", "Drop"]

func open_context_menu(item: ItemData, mouse_pos: Vector2) -> void:
	active_context_item = item
	if not context_menu_panel:
		_build_context_menu()
		
	var vbox = context_menu_panel.get_node_or_null("MenuButtons") as VBoxContainer
	if not vbox:
		return

	for c in vbox.get_children():
		c.queue_free()

	var actions = get_item_context_actions(item)
	for act in actions:
		var btn = Button.new()
		btn.text = act
		btn.custom_minimum_size = Vector2(130, 28)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(Callable(self, "_on_context_action_pressed").bind(act))
		vbox.add_child(btn)

	context_menu_panel.reset_size()
	var vp = get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	if vp.x <= 0 or vp.y <= 0:
		vp = Vector2(1280, 720)
		
	var m_size = context_menu_panel.size
	if mouse_pos.x + m_size.x > vp.x - 8.0:
		mouse_pos.x = vp.x - m_size.x - 8.0
	if mouse_pos.y + m_size.y > vp.y - 8.0:
		mouse_pos.y = vp.y - m_size.y - 8.0
	mouse_pos.x = maxf(8.0, mouse_pos.x)
	mouse_pos.y = maxf(8.0, mouse_pos.y)

	context_menu_panel.global_position = mouse_pos
	context_menu_panel.visible = true

func close_context_menu() -> void:
	if context_menu_panel:
		context_menu_panel.visible = false
	active_context_item = null
	active_context_slot = null

func _on_context_action_pressed(action_name: String) -> void:
	var it = active_context_item
	close_context_menu()
	if it:
		execute_item_action(it, action_name)

func drop_item(item: ItemData) -> bool:
	if not inventory or not item:
		return false
	if inventory.remove_item(item):
		refresh_inventory()
		_on_slot_mouse_exited()
		emit_signal("item_dropped", item)
		emit_signal("item_action_completed")
		return true
	return false

func drop_slot(slot_idx: int) -> bool:
	if not inventory or slot_idx < 0 or slot_idx >= inventory.items.size():
		return false
	return drop_item(inventory.items[slot_idx])

func execute_item_action(item: ItemData, action_name: String) -> Dictionary:
	if not item or not inventory:
		return {"success": false, "message": "Invalid item or inventory"}

	match action_name:
		"Use (1 Turn)":
			return _execute_use_item(item)
		"Use (Craft)", "Craft":
			close_modal()
			emit_signal("crafting_modal_requested")
			return {"success": true, "message": "Opened portable alchemy crafting."}
		"Throw":
			close_modal()
			emit_signal("item_thrown_requested", item)
			return {"success": true, "message": "Select throw target for %s." % item.item_name}
		"Identify":
			var res = AlchemyCatalog.attempt_identify_with_skill(player, item)
			if player and player.turn_manager:
				player.turn_manager.submit_player_action("identify_item", {"immediate_resolve": true, "message": res.get("message", "")})
			refresh_inventory()
			emit_signal("item_action_completed")
			return res
		"Inspect":
			if tooltip:
				var player_skills = player.get_node_or_null("SkillComponent") as SkillComponent if player else null
				tooltip.display_item(item, get_global_mouse_position(), null, player_skills)
			return {"success": true, "message": "Inspecting %s" % item.item_name}
		"Equip":
			var ok = inventory.equip_item(item)
			refresh_inventory()
			emit_signal("item_action_completed")
			return {"success": ok, "message": "Equipped %s" % item.item_name}
		"Unequip":
			if active_context_slot and active_context_slot.is_paperdoll:
				inventory.unequip_slot(active_context_slot.equip_slot)
			else:
				# Search equipped slots for item
				for s in inventory.equipped_slots.keys():
					if inventory.equipped_slots[s] == item:
						inventory.unequip_slot(s)
						break
			refresh_inventory()
			emit_signal("item_action_completed")
			return {"success": true, "message": "Unequipped %s" % item.item_name}
		"Drop":
			var ok = drop_item(item)
			return {"success": ok, "message": "Dropped %s" % item.item_name}
		_:
			return {"success": false, "message": "Unknown action: %s" % action_name}

func _execute_use_item(item: ItemData) -> Dictionary:
	# 1. Potions
	if item.has_meta("is_potion") or item.tags.has("potion") or item.item_id.begins_with("potion_"):
		var p_id = item.get_meta("potion_id") as String if item.has_meta("potion_id") else item.item_id
		var res = AlchemyCatalog.apply_potion_effect(player, p_id, true)
		item.quantity -= 1
		if item.quantity <= 0:
			inventory.remove_item(item)
		if player and player.turn_manager:
			player.turn_manager.submit_player_action("use_item", {"immediate_resolve": true, "message": res.get("message", "")})
		refresh_inventory()
		emit_signal("item_used", item, res)
		emit_signal("item_action_completed")
		return res

	# 2. Bandages and Medkits
	var is_bandage_or_medkit = (
		item.item_id.contains("bandage") or
		item.item_id.contains("trauma") or
		item.item_id.contains("medpack") or
		item.item_id.contains("survival_kit")
	)
	if is_bandage_or_medkit:
		var heal_amt = 40 if (item.item_id.contains("trauma") or item.item_id.contains("medpack") or item.item_id.contains("survival_kit")) else 20
		if player and player.stats:
			player.stats.heal(float(heal_amt))
		if player and player.status_effects:
			player.status_effects.cure_bleed()
		item.quantity -= 1
		if item.quantity <= 0:
			inventory.remove_item(item)
		var msg = "Applied %s (+%d HP restored, Bleed cured)!" % [item.item_name, heal_amt]
		if player and player.turn_manager:
			player.turn_manager.submit_player_action("use_item", {"immediate_resolve": true, "message": msg})
		refresh_inventory()
		var res = {"success": true, "message": msg, "healed": heal_amt}
		emit_signal("item_used", item, res)
		emit_signal("item_action_completed")
		return res

	# 3. Scroll of Identification
	if item.item_id == "scroll_identify" or item.item_id.contains("scroll"):
		var id_names: Array[String] = []
		for it in inventory.items:
			if it.has_meta("is_potion"):
				var pid = it.get_meta("potion_id") as String
				AlchemyCatalog.identify_potion(pid)
				it.item_name = AlchemyCatalog.get_potion_display_name(pid)
				it.description = AlchemyCatalog.get_potion_display_description(pid)
				id_names.append(it.item_name)
		item.quantity -= 1
		if item.quantity <= 0:
			inventory.remove_item(item)
		var msg = "Read %s! Revealed: %s" % [item.item_name, ", ".join(id_names) if not id_names.is_empty() else "All potions known."]
		if player and player.turn_manager:
			player.turn_manager.submit_player_action("use_item", {"immediate_resolve": true, "message": msg})
		refresh_inventory()
		var res = {"success": true, "message": msg}
		emit_signal("item_used", item, res)
		emit_signal("item_action_completed")
		return res

	# 4. Spellbook
	if item.has_meta("teaches_spell"):
		var sp_id = item.get_meta("teaches_spell") as String
		var spc = player.get_node_or_null("SpellCastingComponent") as SpellCastingComponent if player else null
		if spc:
			var sp = SpellData.create_spell_by_id(sp_id)
			spc.learn_spell(sp)
		item.quantity -= 1
		if item.quantity <= 0:
			inventory.remove_item(item)
		var msg = "Read %s and mastered the incantation!" % item.item_name
		if player and player.turn_manager:
			player.turn_manager.submit_player_action("use_item", {"immediate_resolve": true, "message": msg})
		refresh_inventory()
		var res = {"success": true, "message": msg}
		emit_signal("item_used", item, res)
		emit_signal("item_action_completed")
		return res

	# 5. Generic consumable
	item.quantity -= 1
	if item.quantity <= 0:
		inventory.remove_item(item)
	var generic_msg = "Used %s." % item.item_name
	if player and player.turn_manager:
		player.turn_manager.submit_player_action("use_item", {"immediate_resolve": true, "message": generic_msg})
	refresh_inventory()
	var g_res = {"success": true, "message": generic_msg}
	emit_signal("item_used", item, g_res)
	emit_signal("item_action_completed")
	return g_res
