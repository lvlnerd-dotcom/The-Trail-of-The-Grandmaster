class_name ItemTooltip
extends PanelContainer

## ItemTooltip: Floating contextual hover tooltip displaying comprehensive item statistics and lore.

@onready var label_name: Label = $VBox/LabelName
@onready var label_type: Label = $VBox/LabelType
@onready var label_stats: RichTextLabel = $VBox/TextStats
@onready var label_weight_value: Label = $VBox/LabelWeightValue
@onready var label_desc: Label = $VBox/LabelDesc

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_opaque_style()
	hide()

func _apply_opaque_style() -> void:
	var flat = StyleBoxFlat.new()
	flat.bg_color = Color(0.06, 0.07, 0.10, 0.98)
	flat.border_width_left = 2
	flat.border_width_top = 2
	flat.border_width_right = 2
	flat.border_width_bottom = 2
	flat.border_color = Color(0.35, 0.40, 0.55, 1.0)
	flat.corner_radius_top_left = 4
	flat.corner_radius_top_right = 4
	flat.corner_radius_bottom_right = 4
	flat.corner_radius_bottom_left = 4
	flat.content_margin_left = 10.0
	flat.content_margin_top = 8.0
	flat.content_margin_right = 10.0
	flat.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", flat)

func display_item(item: ItemData, global_pos: Vector2) -> void:
	if not item:
		hide()
		return
	
	if not label_name:
		_resolve_references()
		
	label_name.text = item.item_name
	
	# Color code title based on item type
	match item.item_type:
		ItemData.ItemType.WEAPON:
			label_name.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
		ItemData.ItemType.ARMOR, ItemData.ItemType.SHIELD:
			label_name.add_theme_color_override("font_color", Color(0.4, 0.75, 1.0))
		ItemData.ItemType.CONSUMABLE:
			label_name.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		ItemData.ItemType.RELIC:
			label_name.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		_:
			label_name.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))

	var slot_str = ItemData.get_slot_name(item.equip_slot) if item.equip_slot != ItemData.EquipSlot.NONE else "None"
	label_type.text = "Slot: %s  |  Type: %s" % [slot_str, ItemData.ItemType.keys()[item.item_type]]
	
	# Stats text
	var stats_lines: Array[String] = []
	if item.item_type == ItemData.ItemType.WEAPON:
		stats_lines.append("[color=#ff9988]Damage: %d - %d[/color]" % [item.base_damage_min, item.base_damage_max])
		if item.accuracy_bonus != 0.0:
			stats_lines.append("[color=#88ddff]Accuracy: %+.0f%%[/color]" % (item.accuracy_bonus * 100.0))
		if item.range_tiles > 1:
			stats_lines.append("[color=#ffffaa]Range: %d tiles[/color]" % item.range_tiles)
	elif item.item_type == ItemData.ItemType.ARMOR or item.item_type == ItemData.ItemType.SHIELD:
		if item.armor_value > 0:
			stats_lines.append("[color=#66ccff]Armor Soak: +%d[/color]" % item.armor_value)
		if item.block_chance_bonus != 0.0:
			stats_lines.append("[color=#88ffaa]Block Chance: %+.0f%%[/color]" % (item.block_chance_bonus * 100.0))
			
	for attr in item.attribute_bonuses.keys():
		var val = item.attribute_bonuses[attr]
		stats_lines.append("[color=#eebb44]+%d %s[/color]" % [val, str(attr).to_upper()])
		
	if item.parry_bonus != 0.0:
		stats_lines.append("[color=#88ffaa]Parry Bonus: %+.0f%%[/color]" % (item.parry_bonus * 100.0))
	if item.dodge_bonus != 0.0:
		stats_lines.append("[color=#88ffaa]Dodge Bonus: %+.0f%%[/color]" % (item.dodge_bonus * 100.0))
		
	label_stats.text = "\n".join(stats_lines) if stats_lines.size() > 0 else "[color=#888899]Standard Equipment[/color]"
	
	var qty_str = " (x%d)" % item.quantity if item.quantity > 1 else ""
	label_weight_value.text = "Weight: %.1f Stones%s  |  Value: %d GP" % [item.weight_stones, qty_str, item.base_value_gold]
	label_desc.text = item.description if item.description != "" else "A durable piece of delver equipment."
	
	# Position near mouse
	show()
	reset_size()
	global_position = global_pos + Vector2(16, 16)
	
	# Clamp to viewport boundaries
	var vp_size = get_viewport_rect().size
	if global_position.x + size.x > vp_size.x:
		global_position.x = vp_size.x - size.x - 8
	if global_position.y + size.y > vp_size.y:
		global_position.y = vp_size.y - size.y - 8

func _resolve_references() -> void:
	label_name = get_node_or_null("VBox/LabelName") as Label
	label_type = get_node_or_null("VBox/LabelType") as Label
	label_stats = get_node_or_null("VBox/TextStats") as RichTextLabel
	label_weight_value = get_node_or_null("VBox/LabelWeightValue") as Label
	label_desc = get_node_or_null("VBox/LabelDesc") as Label
