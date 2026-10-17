class_name InventoryModal
extends BaseModal

## InventoryModal: Grid-based inventory management with 12-slot anatomical paperdoll,
## drag-and-drop equipping, right-click auto-swap, and hover item statistics.

signal item_action_completed()

@onready var grid_container: GridContainer = $VBox/MainSplit/BackpackPane/ScrollBackpack/GridSlots
@onready var paperdoll_container: Control = $VBox/MainSplit/PaperdollPane/SilhouetteBox
@onready var label_weight: Label = $VBox/FooterBar/LabelWeight
@onready var label_gold: Label = $VBox/FooterBar/LabelGold
@onready var label_armor: Label = $VBox/FooterBar/LabelArmor
@onready var btn_close: Button = $VBox/HeaderBar/BtnClose
@onready var tooltip: ItemTooltip = $ItemTooltip

const TOTAL_BACKPACK_SLOTS: int = 40
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

var player: Node2D = null
var inventory: InventoryComponent = null
var attributes: AttributesData = null
var backpack_buttons: Array[Button] = []
var paperdoll_buttons: Dictionary = {} # EquipSlot -> Button

func _ready() -> void:
	close_on_escape = true
	super._ready()
	if btn_close:
		btn_close.pressed.connect(close_modal)
	_build_ui_slots()

func open_modal_with_player(p_player: Node2D) -> void:
	player = p_player
	if player:
		inventory = player.get_node_or_null("InventoryComponent") as InventoryComponent
		var stats = player.get_node_or_null("StatsComponent") as StatsComponent
		if stats:
			attributes = stats.attributes
	super.open_modal()
	refresh_inventory()

func _build_ui_slots() -> void:
	if not grid_container:
		return
		
	# Clean existing if any
	for c in grid_container.get_children():
		c.queue_free()
	backpack_buttons.clear()
	
	# Build 40 backpack slots (8 cols x 5 rows)
	for i in range(TOTAL_BACKPACK_SLOTS):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(48, 48)
		btn.focus_mode = Control.FOCUS_NONE
		btn.text = ""
		btn.gui_input.connect(Callable(self, "_on_backpack_slot_gui_input").bind(i))
		btn.mouse_entered.connect(Callable(self, "_on_backpack_slot_mouse_entered").bind(i))
		btn.mouse_exited.connect(_on_slot_mouse_exited)
		
		# Drag and drop scripts attached directly to buttons
		btn.set_meta("slot_index", i)
		btn.set_meta("slot_type", "backpack")
		
		grid_container.add_child(btn)
		backpack_buttons.append(btn)
		
	# Find or map paperdoll slot buttons
	if paperdoll_container:
		for slot in PAPERDOLL_SLOTS:
			var slot_name = ItemData.EquipSlot.keys()[slot]
			var btn = paperdoll_container.get_node_or_null("Slot_" + slot_name) as Button
			if btn:
				btn.focus_mode = Control.FOCUS_NONE
				btn.gui_input.connect(Callable(self, "_on_paperdoll_slot_gui_input").bind(slot))
				btn.mouse_entered.connect(Callable(self, "_on_paperdoll_slot_mouse_entered").bind(slot))
				btn.mouse_exited.connect(_on_slot_mouse_exited)
				paperdoll_buttons[slot] = btn

func refresh_inventory() -> void:
	if not inventory:
		return
		
	# 1. Refresh Backpack Grid
	for i in range(backpack_buttons.size()):
		var btn = backpack_buttons[i]
		if i < inventory.items.size():
			var item = inventory.items[i]
			var count_tag = " (%d)" % item.quantity if item.quantity > 1 else ""
			btn.text = item.item_name.substr(0, 3).to_upper() + count_tag
			btn.modulate = _get_item_color(item)
			btn.tooltip_text = "" # Use custom tooltip instead
		else:
			btn.text = ""
			btn.modulate = Color(0.4, 0.4, 0.4, 0.6)
			
	# 2. Refresh Paperdoll Slots
	for slot in PAPERDOLL_SLOTS:
		if paperdoll_buttons.has(slot):
			var btn = paperdoll_buttons[slot]
			if inventory.equipped_slots.has(slot):
				var item = inventory.equipped_slots[slot] as ItemData
				btn.text = item.item_name.substr(0, 4).to_upper()
				btn.modulate = _get_item_color(item)
			else:
				btn.text = ItemData.get_slot_name(slot).substr(0, 4)
				btn.modulate = Color(0.3, 0.35, 0.45, 0.6)
				
	# 3. Refresh Status Footer
	var cur_w = inventory.get_carried_weight_stones()
	var max_w = attributes.get_max_carry_weight_stones() if attributes else 20.0
	label_weight.text = "Weight: %.1f / %.0f Stones" % [cur_w, max_w]
	if cur_w > max_w:
		label_weight.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		label_weight.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
		
	var player_gold = player.get_meta("gold") if player and player.has_meta("gold") else inventory.gold
	label_gold.text = "Gold: %d GP" % player_gold
	label_armor.text = "Total Armor: +%d Soak" % inventory.get_total_armor()

func _get_item_color(item: ItemData) -> Color:
	if not item:
		return Color.WHITE
	match item.item_type:
		ItemData.ItemType.WEAPON: return Color(1.0, 0.65, 0.6)
		ItemData.ItemType.ARMOR, ItemData.ItemType.SHIELD: return Color(0.6, 0.85, 1.0)
		ItemData.ItemType.CONSUMABLE: return Color(0.5, 1.0, 0.6)
		ItemData.ItemType.RELIC: return Color(1.0, 0.85, 0.3)
		ItemData.ItemType.AMMO: return Color(0.9, 0.8, 0.5)
		_: return Color(0.9, 0.9, 0.9)

func _on_backpack_slot_gui_input(event: InputEvent, slot_idx: int) -> void:
	if not inventory:
		return
	if event is InputEventMouseButton and event.pressed:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			# Right-click: Auto-equip to appropriate paperdoll slot with auto-swapping
			if slot_idx < inventory.items.size():
				var item = inventory.items[slot_idx]
				if item.equip_slot != ItemData.EquipSlot.NONE:
					inventory.equip_item(item)
					refresh_inventory()
					_on_slot_mouse_exited()
					emit_signal("item_action_completed")

func _on_paperdoll_slot_gui_input(event: InputEvent, slot: ItemData.EquipSlot) -> void:
	if not inventory:
		return
	if event is InputEventMouseButton and event.pressed:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			# Right-click: Unequip back to backpack
			if inventory.equipped_slots.has(slot):
				inventory.unequip_slot(slot)
				refresh_inventory()
				_on_slot_mouse_exited()
				emit_signal("item_action_completed")

func _on_backpack_slot_mouse_entered(slot_idx: int) -> void:
	if not inventory or not tooltip:
		return
	if slot_idx < inventory.items.size():
		var item = inventory.items[slot_idx]
		tooltip.display_item(item, get_global_mouse_position())

func _on_paperdoll_slot_mouse_entered(slot: ItemData.EquipSlot) -> void:
	if not inventory or not tooltip:
		return
	if inventory.equipped_slots.has(slot):
		var item = inventory.equipped_slots[slot]
		tooltip.display_item(item, get_global_mouse_position())

func _on_slot_mouse_exited() -> void:
	if tooltip:
		tooltip.hide()
