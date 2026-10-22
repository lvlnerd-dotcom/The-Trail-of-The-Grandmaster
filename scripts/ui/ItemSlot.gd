@tool
class_name ItemSlot
extends Button

## ItemSlot: Uniform 52x52 inventory slot button with category-colored borders,
## stack and status badges, double-click dispatching, and drag-and-drop equipping/reordering.

signal slot_left_clicked(slot: ItemSlot)
signal slot_double_clicked(slot: ItemSlot)
signal slot_right_clicked(slot: ItemSlot, global_pos: Vector2)
signal slot_item_dropped(source_slot: ItemSlot, target_slot: ItemSlot, data: Dictionary)

const SLOT_SIZE: Vector2 = Vector2(52, 52)

# Category Border Colors
const COLOR_WEAPON = Color(0.36, 0.53, 0.85, 1.0)       # Steel Blue
const COLOR_ARMOR = Color(0.72, 0.45, 0.20, 1.0)        # Bronze / Brown
const COLOR_CONSUMABLE = Color(0.31, 0.78, 0.47, 1.0)   # Emerald Green
const COLOR_SCROLL_BOOK = Color(0.61, 0.35, 0.71, 1.0)  # Arcane Purple
const COLOR_AMMO = Color(0.90, 0.49, 0.13, 1.0)         # Amber / Orange
const COLOR_RELIC = Color(0.95, 0.77, 0.06, 1.0)        # Gold
const COLOR_EMPTY_BACKPACK = Color(0.18, 0.20, 0.26, 0.8)
const COLOR_EMPTY_PAPERDOLL = Color(0.25, 0.32, 0.42, 0.9)
const COLOR_SELECTED = Color(1.0, 0.90, 0.35, 1.0)
const COLOR_VALID_DROP = Color(0.25, 1.0, 0.45, 1.0)
const COLOR_INVALID_DROP = Color(1.0, 0.25, 0.25, 1.0)

var slot_index: int = -1
var is_paperdoll: bool = false
var equip_slot: ItemData.EquipSlot = ItemData.EquipSlot.NONE
var slot_title: String = ""
var item_data: ItemData = null
var is_selected: bool = false
var drag_highlight_state: int = 0 # 0 = None, 1 = Valid Drop, 2 = Invalid Drop

var _badge_stack: Label = null
var _badge_unidentified: Label = null
var _badge_ability: Label = null

func _init() -> void:
	custom_minimum_size = SLOT_SIZE
	clip_text = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE

func _ready() -> void:
	custom_minimum_size = SLOT_SIZE
	clip_text = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	_build_badges()
	_update_style()

func _build_badges() -> void:
	if _badge_stack:
		return

	# Bottom-right Stack Badge (e.g. x20)
	_badge_stack = Label.new()
	_badge_stack.name = "BadgeStack"
	_badge_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_stack.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_badge_stack.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_badge_stack.add_theme_font_size_override("font_size", 9)
	_badge_stack.add_theme_color_override("font_color", Color(1.0, 1.0, 0.8))
	_badge_stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	_badge_stack.offset_left = 2.0
	_badge_stack.offset_top = 2.0
	_badge_stack.offset_right = -4.0
	_badge_stack.offset_bottom = -2.0
	add_child(_badge_stack)

	# Top-left Unidentified Badge (?)
	_badge_unidentified = Label.new()
	_badge_unidentified.name = "BadgeUnidentified"
	_badge_unidentified.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_unidentified.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_badge_unidentified.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_badge_unidentified.text = "?"
	_badge_unidentified.add_theme_font_size_override("font_size", 10)
	_badge_unidentified.add_theme_color_override("font_color", Color(0.9, 0.4, 0.9))
	_badge_unidentified.set_anchors_preset(Control.PRESET_FULL_RECT)
	_badge_unidentified.offset_left = 4.0
	_badge_unidentified.offset_top = 2.0
	_badge_unidentified.offset_right = -2.0
	_badge_unidentified.offset_bottom = -2.0
	_badge_unidentified.visible = false
	add_child(_badge_unidentified)

	# Top-right Level 25 Ability Badge (★)
	_badge_ability = Label.new()
	_badge_ability.name = "BadgeAbility"
	_badge_ability.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_ability.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_badge_ability.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_badge_ability.text = "★"
	_badge_ability.add_theme_font_size_override("font_size", 10)
	_badge_ability.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_badge_ability.set_anchors_preset(Control.PRESET_FULL_RECT)
	_badge_ability.offset_left = 2.0
	_badge_ability.offset_top = 2.0
	_badge_ability.offset_right = -4.0
	_badge_ability.offset_bottom = -2.0
	_badge_ability.visible = false
	add_child(_badge_ability)

func set_item(item: ItemData) -> void:
	item_data = item
	if not _badge_stack:
		_build_badges()

	if item:
		var d_name = item.get_display_name() if item.has_method("get_display_name") else item.item_name
		text = d_name.substr(0, 3).to_upper()
		
		# Quantity Badge
		if item.quantity > 1:
			_badge_stack.text = "x%d" % item.quantity
			_badge_stack.visible = true
		else:
			_badge_stack.text = ""
			_badge_stack.visible = false
			
		# Unidentified Badge
		var is_ident = item.is_identified if "is_identified" in item else true
		if item.has_meta("is_potion") and item.has_meta("potion_id"):
			var ac = load("res://scripts/resources/AlchemyCatalog.gd")
			if ac and ac.has_method("is_potion_identified"):
				is_ident = ac.is_potion_identified(item.get_meta("potion_id") as String)
		_badge_unidentified.visible = not is_ident

		# Ability Badge
		var has_ab = false
		if "unlocked_ability_name" in item and item.unlocked_ability_name != "":
			has_ab = true
		elif "active_ability" in item and item.active_ability != null:
			has_ab = true
		_badge_ability.visible = has_ab
	else:
		clear_slot()

	_update_style()

func clear_slot() -> void:
	item_data = null
	if not _badge_stack:
		_build_badges()
	_badge_stack.visible = false
	_badge_unidentified.visible = false
	_badge_ability.visible = false
	
	if is_paperdoll:
		text = slot_title.substr(0, 4) if slot_title != "" else ItemData.get_slot_name(equip_slot).substr(0, 4)
	else:
		text = ""
	_update_style()

func set_selected(selected: bool) -> void:
	is_selected = selected
	_update_style()

func set_drag_highlight(state: int) -> void:
	drag_highlight_state = state
	_update_style()

func _update_style() -> void:
	var flat = StyleBoxFlat.new()
	flat.corner_radius_top_left = 4
	flat.corner_radius_top_right = 4
	flat.corner_radius_bottom_right = 4
	flat.corner_radius_bottom_left = 4
	flat.border_width_left = 2
	flat.border_width_top = 2
	flat.border_width_right = 2
	flat.border_width_bottom = 2

	if drag_highlight_state == 1:
		flat.border_color = COLOR_VALID_DROP
		flat.bg_color = Color(0.1, 0.25, 0.12, 0.95)
	elif drag_highlight_state == 2:
		flat.border_color = COLOR_INVALID_DROP
		flat.bg_color = Color(0.25, 0.1, 0.1, 0.95)
	elif is_selected:
		flat.border_color = COLOR_SELECTED
		flat.bg_color = Color(0.18, 0.18, 0.25, 0.95)
	elif item_data:
		flat.border_color = _get_item_border_color(item_data)
		flat.bg_color = Color(0.10, 0.12, 0.16, 0.95)
	else:
		flat.border_color = COLOR_EMPTY_PAPERDOLL if is_paperdoll else COLOR_EMPTY_BACKPACK
		flat.bg_color = Color(0.06, 0.07, 0.09, 0.8)

	add_theme_stylebox_override("normal", flat)
	
	# Hover style
	var hover_flat = flat.duplicate() as StyleBoxFlat
	if not is_selected and drag_highlight_state == 0:
		hover_flat.border_color = flat.border_color.lightened(0.25)
		hover_flat.bg_color = flat.bg_color.lightened(0.1)
	add_theme_stylebox_override("hover", hover_flat)
	add_theme_stylebox_override("pressed", flat)

func _get_item_border_color(item: ItemData) -> Color:
	if not item:
		return COLOR_EMPTY_BACKPACK
	if item.item_id.contains("scroll") or item.item_id.contains("book") or item.item_id.contains("grimoire"):
		return COLOR_SCROLL_BOOK
	match item.item_type:
		ItemData.ItemType.WEAPON: return COLOR_WEAPON
		ItemData.ItemType.ARMOR, ItemData.ItemType.SHIELD: return COLOR_ARMOR
		ItemData.ItemType.CONSUMABLE: return COLOR_CONSUMABLE
		ItemData.ItemType.AMMO: return COLOR_AMMO
		ItemData.ItemType.RELIC, ItemData.ItemType.VALUABLE: return COLOR_RELIC
		_: return Color(0.65, 0.70, 0.80)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			emit_signal("slot_right_clicked", self, get_global_mouse_position())
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.double_click:
				emit_signal("slot_double_clicked", self)
				accept_event()
			else:
				emit_signal("slot_left_clicked", self)
				accept_event()

# Drag and Drop Implementation (P2-D)
func _get_drag_data(_at_position: Vector2) -> Variant:
	if not item_data:
		return null

	var data = {
		"source_slot": self,
		"item": item_data,
		"is_paperdoll": is_paperdoll,
		"slot_index": slot_index,
		"equip_slot": equip_slot
	}

	# Create drag preview control
	var preview = PanelContainer.new()
	preview.custom_minimum_size = Vector2(44, 44)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.20, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = _get_item_border_color(item_data)
	preview.add_theme_stylebox_override("panel", style)

	var lbl = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview.add_child(lbl)

	set_drag_preview(preview)

	# Notify modal parent to highlight valid targets
	var parent_modal = _find_parent_modal()
	if parent_modal and parent_modal.has_method("notify_drag_started"):
		parent_modal.notify_drag_started(data)

	return data

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not data.has("item"):
		return false
	var it = data["item"] as ItemData
	if not it:
		return false

	if is_paperdoll:
		# Gear must match slot or off-hand compatibility
		if it.equip_slot == equip_slot:
			return true
		if equip_slot == ItemData.EquipSlot.OFF_HAND and it.can_equip_offhand:
			return true
		if equip_slot == ItemData.EquipSlot.OFF_HAND and it.item_type == ItemData.ItemType.WEAPON and it.handedness == ItemData.Handedness.ONE_HANDED:
			return true
		if (equip_slot == ItemData.EquipSlot.RING_1 or equip_slot == ItemData.EquipSlot.RING_2) and (it.equip_slot == ItemData.EquipSlot.RING_1 or it.equip_slot == ItemData.EquipSlot.RING_2):
			return true
		return false
	else:
		# Backpack accepts any item
		return true

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if typeof(data) == TYPE_DICTIONARY and data.has("source_slot"):
		var source = data["source_slot"] as ItemSlot
		emit_signal("slot_item_dropped", source, self, data)

	var parent_modal = _find_parent_modal()
	if parent_modal and parent_modal.has_method("notify_drag_ended"):
		parent_modal.notify_drag_ended()

func _find_parent_modal() -> Node:
	var curr: Node = get_parent()
	while curr:
		if curr is InventoryModal or (curr.has_method("notify_drag_started") and curr.has_method("notify_drag_ended")):
			return curr
		curr = curr.get_parent()
	return null
