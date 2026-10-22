@tool
class_name ItemTooltip
extends PanelContainer

## ItemTooltip: Floating contextual hover tooltip displaying comprehensive item statistics,
## stat comparison against equipped gear, delayed hover scheduling, and viewport-edge clamping.

const TOOLTIP_WIDTH: float = 260.0
const CURSOR_OFFSET: Vector2 = Vector2(18, 18)
const SCREEN_MARGIN: float = 8.0
const HOVER_DELAY_SEC: float = 0.15

@onready var label_name: Label = $VBox/LabelName
@onready var label_type: Label = $VBox/LabelType
@onready var label_stats: RichTextLabel = $VBox/TextStats
@onready var label_weight_value: Label = $VBox/LabelWeightValue
@onready var label_desc: Label = $VBox/LabelDesc

var _hover_timer: Timer = null
var _pending_item: ItemData = null
var _pending_compare: ItemData = null
var _pending_skills: SkillComponent = null
var _pending_pos: Vector2 = Vector2.ZERO
var _pending_is_empty_slot: bool = false
var _pending_slot_title: String = ""

func _ready() -> void:
	top_level = true
	z_index = 90
	custom_minimum_size = Vector2(TOOLTIP_WIDTH, 0)
	size.x = TOOLTIP_WIDTH
	
	_ignore_mouse_recursive(self)
	_apply_opaque_style()
	_setup_timer()
	hide()

func _setup_timer() -> void:
	if not _hover_timer:
		_hover_timer = Timer.new()
		_hover_timer.name = "HoverTimer"
		_hover_timer.wait_time = HOVER_DELAY_SEC
		_hover_timer.one_shot = true
		_hover_timer.timeout.connect(_on_hover_timeout)
		add_child(_hover_timer)

func _ignore_mouse_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse_recursive(child)

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

func request_hover_item(
	item: ItemData,
	global_pos: Vector2,
	equipped_compare: ItemData = null,
	player_skills: SkillComponent = null
) -> void:
	if not item:
		cancel_hover()
		return

	if not _hover_timer:
		_setup_timer()

	_pending_item = item
	_pending_compare = equipped_compare
	_pending_skills = player_skills
	_pending_pos = global_pos
	_pending_is_empty_slot = false

	if visible:
		# Already visible: switch instantly
		_hover_timer.stop()
		display_item(item, global_pos, equipped_compare, player_skills)
	else:
		_hover_timer.start(HOVER_DELAY_SEC)

func request_hover_empty_slot(slot_title: String, global_pos: Vector2) -> void:
	if not _hover_timer:
		_setup_timer()

	_pending_is_empty_slot = true
	_pending_slot_title = slot_title
	_pending_pos = global_pos
	_pending_item = null
	_pending_compare = null
	_pending_skills = null

	if visible:
		_hover_timer.stop()
		display_empty_slot(slot_title, global_pos)
	else:
		_hover_timer.start(HOVER_DELAY_SEC)

func cancel_hover() -> void:
	if _hover_timer:
		_hover_timer.stop()
	_pending_item = null
	_pending_compare = null
	_pending_skills = null
	_pending_is_empty_slot = false
	hide()

func _on_hover_timeout() -> void:
	if _pending_is_empty_slot:
		display_empty_slot(_pending_slot_title, _pending_pos)
	elif _pending_item:
		display_item(_pending_item, _pending_pos, _pending_compare, _pending_skills)

func display_empty_slot(slot_title: String, global_pos: Vector2) -> void:
	if not label_name:
		_resolve_references()

	label_name.text = "Empty — %s" % slot_title
	label_name.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	label_type.text = "Slot: %s" % slot_title
	label_stats.text = "[color=#778899]No equipment fitted.[/color]"
	label_weight_value.text = "Drag or double-click items to equip."
	label_desc.text = "Equip armor, weapons, or accessories to gain stat bonuses."

	show()
	place_near(global_pos)

func display_item(
	item: ItemData,
	global_pos: Vector2,
	equipped_compare: ItemData = null,
	player_skills: SkillComponent = null
) -> void:
	if not item:
		hide()
		return
	
	if not label_name:
		_resolve_references()
		
	var d_name = item.get_display_name() if item.has_method("get_display_name") else item.item_name
	label_name.text = d_name
	
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
		ItemData.ItemType.AMMO:
			label_name.add_theme_color_override("font_color", Color(0.95, 0.75, 0.35))
		_:
			label_name.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))

	var slot_str = ItemData.get_slot_name(item.equip_slot) if item.equip_slot != ItemData.EquipSlot.NONE else "None"
	label_type.text = "Slot: %s  |  Type: %s" % [slot_str, ItemData.ItemType.keys()[item.item_type]]
	
	# Stats text breakdown (P2-F)
	var stats_lines: Array[String] = []

	if item.item_type == ItemData.ItemType.WEAPON:
		var skill_name = SkillData.get_skill_name(item.associated_skill_id)
		stats_lines.append("[color=#88bbff]Skill: %s[/color]" % skill_name)

		var hand_str = "1H"
		match item.handedness:
			ItemData.Handedness.TWO_HANDED: hand_str = "2H"
			ItemData.Handedness.VERSATILE: hand_str = "Versatile (1H/2H)"
		if item.can_equip_offhand:
			hand_str += " • Off-Hand Capable"
		stats_lines.append("[color=#b0b8d0]Grip: %s[/color]" % hand_str)

		stats_lines.append("[color=#ff9988]Damage: %d - %d[/color]" % [item.base_damage_min, item.base_damage_max])

		if item.accuracy_bonus != 0.0:
			stats_lines.append("[color=#88ddff]Accuracy: %+.0f%%[/color]" % (item.accuracy_bonus * 100.0))
		if item.armor_penetration > 0.0:
			stats_lines.append("[color=#ffcc66]Armor Penetration: %.0f%%[/color]" % (item.armor_penetration * 100.0))
		if item.range_tiles > 1:
			stats_lines.append("[color=#ffffaa]Range: %d tiles[/color]" % item.range_tiles)
		if item.area_radius > 0:
			var dim = item.area_radius * 2 + 1
			stats_lines.append("[color=#ffaa66]Blast Area: %dx%d[/color]" % [dim, dim])
		if item.requires_ammo:
			stats_lines.append("[color=#eebb88]Requires Ammunition[/color]")
		if item.is_silver or item.tags.has("silver_weapon"):
			stats_lines.append("[color=#e0e0ff]Silver Weapon [Undead Slaying][/color]")
		if item.bleed_chance > 0.0:
			stats_lines.append("[color=#ff6666]Bleed Chance: %.0f%%[/color]" % (item.bleed_chance * 100.0))
		if item.poison_chance > 0.0:
			stats_lines.append("[color=#66ff66]Poison Chance: %.0f%%[/color]" % (item.poison_chance * 100.0))
		if item.stun_chance > 0.0:
			stats_lines.append("[color=#ffdd44]Stun Chance: %.0f%%[/color]" % (item.stun_chance * 100.0))
		if item.crit_chance_bonus > 0.0:
			stats_lines.append("[color=#ffaa22]Crit Bonus: %+.0f%%[/color]" % (item.crit_chance_bonus * 100.0))

		# Level 25 Weapon Ability check
		var ability_name = item.get_ability_name() if item.has_method("get_ability_name") else item.unlocked_ability_name
		if ability_name != "":
			var is_unlocked = false
			if player_skills and player_skills.has_method("get_skill"):
				var sk = player_skills.get_skill(item.associated_skill_id)
				if sk and sk.level >= 25.0:
					is_unlocked = true
			if is_unlocked:
				stats_lines.append("[color=#55ff55]Ability: %s [Unlocked][/color]" % ability_name)
			else:
				stats_lines.append("[color=#ffaa44]Ability: %s [Requires Lv.25][/color]" % ability_name)

	elif item.item_type == ItemData.ItemType.ARMOR or item.item_type == ItemData.ItemType.SHIELD:
		if item.armor_value > 0:
			stats_lines.append("[color=#66ccff]Armor Soak: +%d[/color]" % item.armor_value)
		if item.block_chance_bonus != 0.0:
			stats_lines.append("[color=#88ffaa]Block Chance: %+.0f%% [Parry Stance][/color]" % (item.block_chance_bonus * 100.0))

	# Common Attribute and Stance Bonuses
	for attr in item.attribute_bonuses.keys():
		var val = item.attribute_bonuses[attr]
		stats_lines.append("[color=#eebb44]+%d %s[/color]" % [val, str(attr).to_upper()])
		
	if item.defense_bonus != 0.0:
		stats_lines.append("[color=#88ffaa]Defense Bonus: %+.0f%%[/color]" % (item.defense_bonus * 100.0))
	if item.parry_bonus != 0.0:
		stats_lines.append("[color=#88ffaa]Parry Bonus: %+.0f%% [Parry Stance][/color]" % (item.parry_bonus * 100.0))
	if item.dodge_bonus != 0.0:
		stats_lines.append("[color=#88ffaa]Dodge Bonus: %+.0f%% [Dodge Stance][/color]" % (item.dodge_bonus * 100.0))
	if item.carry_weight_bonus > 0.0:
		stats_lines.append("[color=#88ddaa]Carry Capacity: +%.1f St.[/color]" % item.carry_weight_bonus)

	# Equipped Stat Comparison (P2-E)
	if equipped_compare and equipped_compare != item:
		var comp_lines: Array[String] = []
		if item.item_type == ItemData.ItemType.WEAPON and equipped_compare.item_type == ItemData.ItemType.WEAPON:
			var dmg_diff = item.base_damage_max - equipped_compare.base_damage_max
			if dmg_diff > 0:
				comp_lines.append("[color=#55ff55]▲ +%d Damage[/color]" % dmg_diff)
			elif dmg_diff < 0:
				comp_lines.append("[color=#ff5555]▼ %d Damage[/color]" % dmg_diff)

			var acc_diff = int(round((item.accuracy_bonus - equipped_compare.accuracy_bonus) * 100.0))
			if acc_diff > 0:
				comp_lines.append("[color=#55ff55]▲ +%d%% Accuracy[/color]" % acc_diff)
			elif acc_diff < 0:
				comp_lines.append("[color=#ff5555]▼ %d%% Accuracy[/color]" % acc_diff)

		if (item.item_type == ItemData.ItemType.ARMOR or item.item_type == ItemData.ItemType.SHIELD) and (equipped_compare.item_type == ItemData.ItemType.ARMOR or equipped_compare.item_type == ItemData.ItemType.SHIELD):
			var arm_diff = item.armor_value - equipped_compare.armor_value
			if arm_diff > 0:
				comp_lines.append("[color=#55ff55]▲ +%d Armor[/color]" % arm_diff)
			elif arm_diff < 0:
				comp_lines.append("[color=#ff5555]▼ %d Armor[/color]" % arm_diff)

		var def_diff = int(round((item.defense_bonus - equipped_compare.defense_bonus) * 100.0))
		if def_diff > 0:
			comp_lines.append("[color=#55ff55]▲ +%d%% Speed[/color]" % def_diff)
		elif def_diff < 0:
			comp_lines.append("[color=#ff5555]▼ %d%% Speed[/color]" % def_diff)

		if not comp_lines.is_empty():
			var eq_name = equipped_compare.get_display_name() if equipped_compare.has_method("get_display_name") else equipped_compare.item_name
			stats_lines.append("[color=#bbbbcc]vs. Equipped (%s):[/color]" % eq_name)
			stats_lines.append_array(comp_lines)

	label_stats.text = "\n".join(stats_lines) if stats_lines.size() > 0 else "[color=#888899]Standard Equipment[/color]"
	
	var qty_str = " (x%d)" % item.quantity if item.quantity > 1 else ""
	label_weight_value.text = "Weight: %.1f Stones%s  |  Value: %d GP" % [item.weight_stones, qty_str, item.base_value_gold]
	
	var d_desc = item.description
	if item.has_meta("is_potion") and item.has_meta("potion_id"):
		var ac = load("res://scripts/resources/AlchemyCatalog.gd")
		if ac and ac.has_method("get_potion_display_description"):
			d_desc = ac.get_potion_display_description(item.get_meta("potion_id") as String)
	label_desc.text = d_desc if d_desc != "" else "A durable piece of delver equipment."
	
	# Position near mouse
	show()
	place_near(global_pos)

func place_near(cursor: Vector2) -> void:
	custom_minimum_size = Vector2(TOOLTIP_WIDTH, 0)
	size.x = TOOLTIP_WIDTH
	reset_size()
	
	var vp_size = get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	if vp_size.x <= 0 or vp_size.y <= 0:
		vp_size = Vector2(1280, 720) # Headless fallback
		
	var target_pos = cursor + CURSOR_OFFSET
	var cur_w = maxf(TOOLTIP_WIDTH, size.x)
	var cur_h = size.y
	
	# Edge flipping
	if target_pos.x + cur_w > vp_size.x - SCREEN_MARGIN:
		target_pos.x = cursor.x - cur_w - CURSOR_OFFSET.x
	if target_pos.y + cur_h > vp_size.y - SCREEN_MARGIN:
		target_pos.y = cursor.y - cur_h - CURSOR_OFFSET.y
		
	# Viewport clamping
	target_pos.x = clampf(target_pos.x, SCREEN_MARGIN, maxf(SCREEN_MARGIN, vp_size.x - cur_w - SCREEN_MARGIN))
	target_pos.y = clampf(target_pos.y, SCREEN_MARGIN, maxf(SCREEN_MARGIN, vp_size.y - cur_h - SCREEN_MARGIN))
	
	global_position = target_pos

func _resolve_references() -> void:
	label_name = get_node_or_null("VBox/LabelName") as Label
	label_type = get_node_or_null("VBox/LabelType") as Label
	label_stats = get_node_or_null("VBox/TextStats") as RichTextLabel
	label_weight_value = get_node_or_null("VBox/LabelWeightValue") as Label
	label_desc = get_node_or_null("VBox/LabelDesc") as Label
