@tool
class_name CharacterCreationModal
extends PanelContainer

## CharacterCreationModal: Allows distributing starting core attributes and drafting 4 starting skills.
## Backgrounds are eliminated in favor of pure attribute allocation and modular skill selection.

signal character_created(creation_data: Dictionary)
signal cancelled()

const TOTAL_BUDGET: int = 20
const MIN_STAT: int = 1
const MAX_STAT: int = 10
const REQUIRED_SKILLS_COUNT: int = 4

var attributes: Dictionary = {
	"strength": 1,
	"dexterity": 1,
	"constitution": 1,
	"intelligence": 1,
	"wisdom": 1,
	"charisma": 1
}

var selected_skills: Array[SkillData.SkillId] = []
var skill_buttons: Dictionary = {} # SkillData.SkillId -> Button

# Node references - Header
@onready var label_points: Label = $VBox/HeaderBox/LabelPointsRemaining

# Stat Labels
@onready var val_str: Label = $VBox/MainSplit/LeftPane/StatsGrid/ValStr
@onready var val_dex: Label = $VBox/MainSplit/LeftPane/StatsGrid/ValDex
@onready var val_con: Label = $VBox/MainSplit/LeftPane/StatsGrid/ValCon
@onready var val_int: Label = $VBox/MainSplit/LeftPane/StatsGrid/ValInt
@onready var val_wis: Label = $VBox/MainSplit/LeftPane/StatsGrid/ValWis
@onready var val_cha: Label = $VBox/MainSplit/LeftPane/StatsGrid/ValCha

# Stat Buttons
@onready var btn_str_minus: Button = $VBox/MainSplit/LeftPane/StatsGrid/BtnStrMinus
@onready var btn_str_plus: Button = $VBox/MainSplit/LeftPane/StatsGrid/BtnStrPlus
@onready var btn_dex_minus: Button = $VBox/MainSplit/LeftPane/StatsGrid/BtnDexMinus
@onready var btn_dex_plus: Button = $VBox/MainSplit/LeftPane/StatsGrid/BtnDexPlus
@onready var btn_con_minus: Button = $VBox/MainSplit/LeftPane/StatsGrid/BtnConMinus
@onready var btn_con_plus: Button = $VBox/MainSplit/LeftPane/StatsGrid/BtnConPlus
@onready var btn_int_minus: Button = $VBox/MainSplit/LeftPane/StatsGrid/BtnIntMinus
@onready var btn_int_plus: Button = $VBox/MainSplit/LeftPane/StatsGrid/BtnIntPlus
@onready var btn_wis_minus: Button = $VBox/MainSplit/LeftPane/StatsGrid/BtnWisMinus
@onready var btn_wis_plus: Button = $VBox/MainSplit/LeftPane/StatsGrid/BtnWisPlus
@onready var btn_cha_minus: Button = $VBox/MainSplit/LeftPane/StatsGrid/BtnChaMinus
@onready var btn_cha_plus: Button = $VBox/MainSplit/LeftPane/StatsGrid/BtnChaPlus

# Derived preview labels
@onready var label_derived_hp: Label = $VBox/MainSplit/LeftPane/DerivedBox/GridDerived/ValHP
@onready var label_derived_mana: Label = $VBox/MainSplit/LeftPane/DerivedBox/GridDerived/ValMana
@onready var label_derived_carry: Label = $VBox/MainSplit/LeftPane/DerivedBox/GridDerived/ValCarry
@onready var label_derived_melee: Label = $VBox/MainSplit/LeftPane/DerivedBox/GridDerived/ValMelee
@onready var label_derived_crit: Label = $VBox/MainSplit/LeftPane/DerivedBox/GridDerived/ValCrit

# Skills picker controls
@onready var label_skills_counter: Label = $VBox/MainSplit/RightPane/SkillHeaderHBox/LabelSkillsCounter
@onready var skill_chips_grid: GridContainer = $VBox/MainSplit/RightPane/ScrollSkillChips/SkillChipsGrid
@onready var label_loadout_items: Label = $VBox/MainSplit/RightPane/LoadoutPreviewBox/VBoxLoadout/LabelLoadoutItems

# Action buttons
@onready var btn_embark: Button = $VBox/ButtonsBox/BtnEmbark
@onready var btn_reset: Button = $VBox/ButtonsBox/BtnReset
@onready var btn_cancel: Button = $VBox/ButtonsBox/BtnCancel

func _get_audio_mgr() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("AudioManager")
	return null

func _get_game_mgr() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("GameManager")
	return null

func _resolve_node_references() -> void:
	if btn_str_minus:
		return
	label_points = get_node_or_null("VBox/HeaderBox/LabelPointsRemaining") as Label
	val_str = get_node_or_null("VBox/MainSplit/LeftPane/StatsGrid/ValStr") as Label
	val_dex = get_node_or_null("VBox/MainSplit/LeftPane/StatsGrid/ValDex") as Label
	val_con = get_node_or_null("VBox/MainSplit/LeftPane/StatsGrid/ValCon") as Label
	val_int = get_node_or_null("VBox/MainSplit/LeftPane/StatsGrid/ValInt") as Label
	val_wis = get_node_or_null("VBox/MainSplit/LeftPane/StatsGrid/ValWis") as Label
	val_cha = get_node_or_null("VBox/MainSplit/LeftPane/StatsGrid/ValCha") as Label

	btn_str_minus = get_node_or_null("VBox/MainSplit/LeftPane/StatsGrid/BtnStrMinus") as Button
	btn_str_plus = get_node_or_null("VBox/MainSplit/LeftPane/StatsGrid/BtnStrPlus") as Button
	btn_dex_minus = get_node_or_null("VBox/MainSplit/LeftPane/StatsGrid/BtnDexMinus") as Button
	btn_dex_plus = get_node_or_null("VBox/MainSplit/LeftPane/StatsGrid/BtnDexPlus") as Button
	btn_con_minus = get_node_or_null("VBox/MainSplit/LeftPane/StatsGrid/BtnConMinus") as Button
	btn_con_plus = get_node_or_null("VBox/MainSplit/LeftPane/StatsGrid/BtnConPlus") as Button
	btn_int_minus = get_node_or_null("VBox/MainSplit/LeftPane/StatsGrid/BtnIntMinus") as Button
	btn_int_plus = get_node_or_null("VBox/MainSplit/LeftPane/StatsGrid/BtnIntPlus") as Button
	btn_wis_minus = get_node_or_null("VBox/MainSplit/LeftPane/StatsGrid/BtnWisMinus") as Button
	btn_wis_plus = get_node_or_null("VBox/MainSplit/LeftPane/StatsGrid/BtnWisPlus") as Button
	btn_cha_minus = get_node_or_null("VBox/MainSplit/LeftPane/StatsGrid/BtnChaMinus") as Button
	btn_cha_plus = get_node_or_null("VBox/MainSplit/LeftPane/StatsGrid/BtnChaPlus") as Button

	label_derived_hp = get_node_or_null("VBox/MainSplit/LeftPane/DerivedBox/GridDerived/ValHP") as Label
	label_derived_mana = get_node_or_null("VBox/MainSplit/LeftPane/DerivedBox/GridDerived/ValMana") as Label
	label_derived_carry = get_node_or_null("VBox/MainSplit/LeftPane/DerivedBox/GridDerived/ValCarry") as Label
	label_derived_melee = get_node_or_null("VBox/MainSplit/LeftPane/DerivedBox/GridDerived/ValMelee") as Label
	label_derived_crit = get_node_or_null("VBox/MainSplit/LeftPane/DerivedBox/GridDerived/ValCrit") as Label

	label_skills_counter = get_node_or_null("VBox/MainSplit/RightPane/SkillHeaderHBox/LabelSkillsCounter") as Label
	skill_chips_grid = get_node_or_null("VBox/MainSplit/RightPane/ScrollSkillChips/SkillChipsGrid") as GridContainer
	label_loadout_items = get_node_or_null("VBox/MainSplit/RightPane/LoadoutPreviewBox/VBoxLoadout/LabelLoadoutItems") as Label

	btn_embark = get_node_or_null("VBox/ButtonsBox/BtnEmbark") as Button
	btn_reset = get_node_or_null("VBox/ButtonsBox/BtnReset") as Button
	btn_cancel = get_node_or_null("VBox/ButtonsBox/BtnCancel") as Button

func _ready() -> void:
	BaseModal.apply_opaque_styling(self)
	visible = false
	_resolve_node_references()
	_connect_signals()

func _connect_signals() -> void:
	if btn_str_minus:
		btn_str_minus.pressed.connect(func(): _modify_stat("strength", -1))
	if btn_str_plus:
		btn_str_plus.pressed.connect(func(): _modify_stat("strength", 1))
	
	if btn_dex_minus:
		btn_dex_minus.pressed.connect(func(): _modify_stat("dexterity", -1))
	if btn_dex_plus:
		btn_dex_plus.pressed.connect(func(): _modify_stat("dexterity", 1))
	
	if btn_con_minus:
		btn_con_minus.pressed.connect(func(): _modify_stat("constitution", -1))
	if btn_con_plus:
		btn_con_plus.pressed.connect(func(): _modify_stat("constitution", 1))
	
	if btn_int_minus:
		btn_int_minus.pressed.connect(func(): _modify_stat("intelligence", -1))
	if btn_int_plus:
		btn_int_plus.pressed.connect(func(): _modify_stat("intelligence", 1))
	
	if btn_wis_minus:
		btn_wis_minus.pressed.connect(func(): _modify_stat("wisdom", -1))
	if btn_wis_plus:
		btn_wis_plus.pressed.connect(func(): _modify_stat("wisdom", 1))
	
	if btn_cha_minus:
		btn_cha_minus.pressed.connect(func(): _modify_stat("charisma", -1))
	if btn_cha_plus:
		btn_cha_plus.pressed.connect(func(): _modify_stat("charisma", 1))
	
	if btn_embark:
		btn_embark.pressed.connect(_on_embark_pressed)
	if btn_reset:
		btn_reset.pressed.connect(_on_reset_pressed)
	if btn_cancel:
		btn_cancel.pressed.connect(_on_cancel_pressed)

func open_modal() -> void:
	visible = true
	_resolve_node_references()
	_reset_to_defaults()
	_populate_skill_chips()
	_update_ui()

func close_modal() -> void:
	visible = false
	emit_signal("cancelled")

func _reset_to_defaults() -> void:
	attributes = {
		"strength": 1,
		"dexterity": 1,
		"constitution": 1,
		"intelligence": 1,
		"wisdom": 1,
		"charisma": 1
	}
	selected_skills.clear()
	_update_ui()

func _populate_skill_chips() -> void:
	if not skill_chips_grid:
		return
		
	for child in skill_chips_grid.get_children():
		child.queue_free()
	skill_buttons.clear()
	
	var available_skills = CharacterCreationData.get_available_starting_skills()
	for s_id in available_skills:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(170, 36)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		var s_name = SkillData.get_skill_name(s_id)
		var attr_name = SkillData.get_associated_attribute(s_id)
		var attr_code = _get_attr_code(attr_name)
		var is_meta = (SkillData.get_tier_for_skill(s_id) == SkillData.SkillTier.META)
		
		var meta_badge = " [META]" if is_meta else ""
		btn.set_meta("base_label", "%s [%s]%s" % [s_name, attr_code, meta_badge])
		btn.text = "  %s" % btn.get_meta("base_label")
		
		# Build detailed tooltip
		var items_granted = CharacterCreationData.get_items_for_skill(s_id)
		var item_names: Array[String] = []
		for it in items_granted:
			var slot_str = _get_slot_name(it.equip_slot)
			item_names.append("%s (%s)" % [it.item_name, slot_str])
			
		btn.tooltip_text = "[%s]\nTier: %s\nAttribute: %s\nStarts at Level 5.0\nStarter Equipment: %s" % [
			s_name,
			"META" if is_meta else "STARTING",
			attr_name.capitalize(),
			", ".join(item_names) if not item_names.is_empty() else "None"
		]
		
		btn.pressed.connect(Callable(self, "_on_skill_chip_toggled").bind(s_id))
		skill_chips_grid.add_child(btn)
		skill_buttons[s_id] = btn

func _get_attr_code(attr_name: String) -> String:
	match attr_name.to_lower():
		"strength": return "STR"
		"dexterity": return "DEX"
		"constitution": return "CON"
		"intelligence": return "INT"
		"wisdom": return "WIS"
		"charisma": return "CHA"
		_: return "STR"

func _get_slot_name(slot: ItemData.EquipSlot) -> String:
	match slot:
		ItemData.EquipSlot.MAIN_HAND: return "Main Hand"
		ItemData.EquipSlot.OFF_HAND: return "Off Hand"
		ItemData.EquipSlot.BODY: return "Body"
		ItemData.EquipSlot.HEAD: return "Head"
		ItemData.EquipSlot.ACCESSORY: return "Accessory"
		ItemData.EquipSlot.AMMUNITION: return "Ammunition"
		_: return "Backpack"

func _on_skill_chip_toggled(s_id: SkillData.SkillId) -> void:
	var am = _get_audio_mgr()
	if selected_skills.has(s_id):
		selected_skills.erase(s_id)
		if am:
			am.play_sound("ui_click")
	else:
		if selected_skills.size() < REQUIRED_SKILLS_COUNT:
			selected_skills.append(s_id)
			if am:
				am.play_sound("ui_click")
		else:
			if am:
				am.play_sound("ui_error")
				
	_update_ui()

func get_spent_points() -> int:
	var total = 0
	for attr in attributes.keys():
		total += (attributes[attr] - MIN_STAT)
	return total

func get_remaining_points() -> int:
	return TOTAL_BUDGET - get_spent_points()

func _modify_stat(stat_name: String, delta: int) -> void:
	var cur = int(attributes.get(stat_name, MIN_STAT))
	var remaining = get_remaining_points()
	
	if delta > 0:
		if remaining <= 0 or cur >= MAX_STAT:
			return
	elif delta < 0:
		if cur <= MIN_STAT:
			return
			
	attributes[stat_name] = cur + delta
	
	var am = _get_audio_mgr()
	if am:
		am.play_sound("ui_click")
		
	_update_ui()

func _update_ui() -> void:
	var remaining = get_remaining_points()
	
	# 1. Points label
	if label_points:
		label_points.text = "Attribute Points Remaining: %d" % remaining
		if remaining == 0:
			label_points.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		else:
			label_points.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			
	# 2. Stat values
	if val_str: val_str.text = str(attributes["strength"])
	if val_dex: val_dex.text = str(attributes["dexterity"])
	if val_con: val_con.text = str(attributes["constitution"])
	if val_int: val_int.text = str(attributes["intelligence"])
	if val_wis: val_wis.text = str(attributes["wisdom"])
	if val_cha: val_cha.text = str(attributes["charisma"])
	
	# 3. Plus/Minus Button states
	if btn_str_minus: btn_str_minus.disabled = (attributes["strength"] <= MIN_STAT)
	if btn_str_plus: btn_str_plus.disabled = (attributes["strength"] >= MAX_STAT or remaining <= 0)
	
	if btn_dex_minus: btn_dex_minus.disabled = (attributes["dexterity"] <= MIN_STAT)
	if btn_dex_plus: btn_dex_plus.disabled = (attributes["dexterity"] >= MAX_STAT or remaining <= 0)
	
	if btn_con_minus: btn_con_minus.disabled = (attributes["constitution"] <= MIN_STAT)
	if btn_con_plus: btn_con_plus.disabled = (attributes["constitution"] >= MAX_STAT or remaining <= 0)
	
	if btn_int_minus: btn_int_minus.disabled = (attributes["intelligence"] <= MIN_STAT)
	if btn_int_plus: btn_int_plus.disabled = (attributes["intelligence"] >= MAX_STAT or remaining <= 0)
	
	if btn_wis_minus: btn_wis_minus.disabled = (attributes["wisdom"] <= MIN_STAT)
	if btn_wis_plus: btn_wis_plus.disabled = (attributes["wisdom"] >= MAX_STAT or remaining <= 0)
	
	if btn_cha_minus: btn_cha_minus.disabled = (attributes["charisma"] <= MIN_STAT)
	if btn_cha_plus: btn_cha_plus.disabled = (attributes["charisma"] >= MAX_STAT or remaining <= 0)
	
	# 4. Baseline Vitals Preview
	var preview_attrs = AttributesData.new()
	preview_attrs.strength = attributes["strength"]
	preview_attrs.dexterity = attributes["dexterity"]
	preview_attrs.constitution = attributes["constitution"]
	preview_attrs.intelligence = attributes["intelligence"]
	preview_attrs.wisdom = attributes["wisdom"]
	preview_attrs.charisma = attributes["charisma"]
	
	if label_derived_hp:
		label_derived_hp.text = "%d HP" % int(preview_attrs.get_max_health())
	if label_derived_mana:
		label_derived_mana.text = "%d MP" % int(preview_attrs.get_max_mana())
	if label_derived_carry:
		label_derived_carry.text = "%.0f Stones" % preview_attrs.get_max_carry_weight_stones()
	if label_derived_melee:
		var melee_pct = int(round((preview_attrs.get_melee_damage_modifier() - 1.0) * 100.0))
		label_derived_melee.text = "%+d%%" % melee_pct
	if label_derived_crit:
		var crit_pct = preview_attrs.get_critical_chance() * 100.0
		label_derived_crit.text = "%.1f%%" % crit_pct
		
	# 5. Skills Selection Counter
	var count = selected_skills.size()
	if label_skills_counter:
		if count < REQUIRED_SKILLS_COUNT:
			var need = REQUIRED_SKILLS_COUNT - count
			label_skills_counter.text = "Selected: %d / %d (Pick %d more)" % [count, REQUIRED_SKILLS_COUNT, need]
			label_skills_counter.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		else:
			label_skills_counter.text = "Selected: %d / %d [COMPLETE]" % [count, REQUIRED_SKILLS_COUNT]
			label_skills_counter.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
			
	# 6. Skill Chip Buttons state
	for s_id in skill_buttons.keys():
		var btn = skill_buttons[s_id] as Button
		if not is_instance_valid(btn):
			continue
		var base_label = btn.get_meta("base_label", "")
		var is_selected = selected_skills.has(s_id)
		
		if is_selected:
			btn.text = "✔ %s" % base_label
			btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		else:
			btn.text = "   %s" % base_label
			if count >= REQUIRED_SKILLS_COUNT:
				btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
			else:
				btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
				
	# 7. Live Loadout Preview
	if label_loadout_items:
		if selected_skills.is_empty():
			label_loadout_items.text = "(No starting skills selected. Select 4 skills to preview gear.)"
		else:
			var eq_res = CharacterCreationData.resolve_starting_equipment(selected_skills)
			var eq_strs: Array[String] = []
			for slot in eq_res["equipped_slots"].keys():
				var it = eq_res["equipped_slots"][slot] as ItemData
				if it:
					eq_strs.append("%s (%s)" % [it.item_name, _get_slot_name(slot)])
					
			var bp_strs: Array[String] = []
			var bp_weight = 0.0
			for it in eq_res["backpack_items"]:
				if it:
					bp_strs.append(it.item_name)
					bp_weight += it.weight_stones
					
			var preview_text = "Equipped: " + (", ".join(eq_strs) if not eq_strs.is_empty() else "None")
			preview_text += "\nBackpack: " + (", ".join(bp_strs) if not bp_strs.is_empty() else "None")
			preview_text += " [Burden: %.1f Stones]" % bp_weight
			label_loadout_items.text = preview_text
			
	# 8. Embark button activation check
	var can_embark: bool = (remaining == 0) and (count == REQUIRED_SKILLS_COUNT)
	if btn_embark:
		btn_embark.disabled = not can_embark

func _on_embark_pressed() -> void:
	if get_remaining_points() != 0 or selected_skills.size() != REQUIRED_SKILLS_COUNT:
		return
		
	var am = _get_audio_mgr()
	if am:
		am.play_sound("ui_click")
		
	var final_attrs = AttributesData.new()
	final_attrs.strength = attributes["strength"]
	final_attrs.dexterity = attributes["dexterity"]
	final_attrs.constitution = attributes["constitution"]
	final_attrs.intelligence = attributes["intelligence"]
	final_attrs.wisdom = attributes["wisdom"]
	final_attrs.charisma = attributes["charisma"]
	
	var creation_dict = {
		"attributes": final_attrs,
		"selected_skills": selected_skills.duplicate(),
		"starting_items": CharacterCreationData.get_starting_items_for_skills(selected_skills)
	}
	
	emit_signal("character_created", creation_dict)
	
	var gm = _get_game_mgr()
	if gm:
		gm.pending_creation_data = creation_dict
		gm.start_new_run()
		
	visible = false
	var tree = get_tree()
	if tree:
		tree.change_scene_to_file("res://scenes/world/World.tscn")

func _on_reset_pressed() -> void:
	var am = _get_audio_mgr()
	if am:
		am.play_sound("ui_click")
	_reset_to_defaults()

func _on_cancel_pressed() -> void:
	var am = _get_audio_mgr()
	if am:
		am.play_sound("ui_click")
	close_modal()
