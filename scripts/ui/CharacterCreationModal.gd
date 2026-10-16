@tool
class_name CharacterCreationModal
extends PanelContainer

## CharacterCreationModal: Allows distributing starting core attributes and selecting unlocked backgrounds.

signal character_created(creation_data: Dictionary)
signal cancelled()

const TOTAL_BUDGET: int = 20
const MIN_STAT: int = 1
const MAX_STAT: int = 10

var attributes: Dictionary = {
	"strength": 1,
	"dexterity": 1,
	"constitution": 1,
	"intelligence": 1,
	"wisdom": 1,
	"charisma": 1
}

var unlocked_backgrounds: Array[Dictionary] = []
var selected_background_id: String = "novice_adventurer"

# Node references
@onready var label_points: Label = $VBox/HeaderBox/LabelPointsRemaining
@onready var bg_option_button: OptionButton = $VBox/BackgroundBox/OptionBackground
@onready var label_bg_desc: Label = $VBox/BackgroundBox/LabelBgDescription

# Stat Labels
@onready var val_str: Label = $VBox/StatsGrid/ValStr
@onready var val_dex: Label = $VBox/StatsGrid/ValDex
@onready var val_con: Label = $VBox/StatsGrid/ValCon
@onready var val_int: Label = $VBox/StatsGrid/ValInt
@onready var val_wis: Label = $VBox/StatsGrid/ValWis
@onready var val_cha: Label = $VBox/StatsGrid/ValCha

# Stat Buttons
@onready var btn_str_minus: Button = $VBox/StatsGrid/BtnStrMinus
@onready var btn_str_plus: Button = $VBox/StatsGrid/BtnStrPlus
@onready var btn_dex_minus: Button = $VBox/StatsGrid/BtnDexMinus
@onready var btn_dex_plus: Button = $VBox/StatsGrid/BtnDexPlus
@onready var btn_con_minus: Button = $VBox/StatsGrid/BtnConMinus
@onready var btn_con_plus: Button = $VBox/StatsGrid/BtnConPlus
@onready var btn_int_minus: Button = $VBox/StatsGrid/BtnIntMinus
@onready var btn_int_plus: Button = $VBox/StatsGrid/BtnIntPlus
@onready var btn_wis_minus: Button = $VBox/StatsGrid/BtnWisMinus
@onready var btn_wis_plus: Button = $VBox/StatsGrid/BtnWisPlus
@onready var btn_cha_minus: Button = $VBox/StatsGrid/BtnChaMinus
@onready var btn_cha_plus: Button = $VBox/StatsGrid/BtnChaPlus

# Derived preview labels
@onready var label_derived_hp: Label = $VBox/DerivedBox/GridDerived/ValHP
@onready var label_derived_mana: Label = $VBox/DerivedBox/GridDerived/ValMana
@onready var label_derived_carry: Label = $VBox/DerivedBox/GridDerived/ValCarry
@onready var label_derived_melee: Label = $VBox/DerivedBox/GridDerived/ValMelee
@onready var label_derived_crit: Label = $VBox/DerivedBox/GridDerived/ValCrit

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

func _ready() -> void:
	visible = false
	_connect_signals()

func _connect_signals() -> void:
	btn_str_minus.pressed.connect(func(): _modify_stat("strength", -1))
	btn_str_plus.pressed.connect(func(): _modify_stat("strength", 1))
	
	btn_dex_minus.pressed.connect(func(): _modify_stat("dexterity", -1))
	btn_dex_plus.pressed.connect(func(): _modify_stat("dexterity", 1))
	
	btn_con_minus.pressed.connect(func(): _modify_stat("constitution", -1))
	btn_con_plus.pressed.connect(func(): _modify_stat("constitution", 1))
	
	btn_int_minus.pressed.connect(func(): _modify_stat("intelligence", -1))
	btn_int_plus.pressed.connect(func(): _modify_stat("intelligence", 1))
	
	btn_wis_minus.pressed.connect(func(): _modify_stat("wisdom", -1))
	btn_wis_plus.pressed.connect(func(): _modify_stat("wisdom", 1))
	
	btn_cha_minus.pressed.connect(func(): _modify_stat("charisma", -1))
	btn_cha_plus.pressed.connect(func(): _modify_stat("charisma", 1))
	
	if bg_option_button:
		bg_option_button.item_selected.connect(_on_background_selected)
		
	if btn_embark:
		btn_embark.pressed.connect(_on_embark_pressed)
	if btn_reset:
		btn_reset.pressed.connect(_on_reset_pressed)
	if btn_cancel:
		btn_cancel.pressed.connect(_on_cancel_pressed)

func open_modal() -> void:
	visible = true
	_reset_to_defaults()
	_populate_backgrounds()
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
	_update_ui()

func _populate_backgrounds() -> void:
	if not bg_option_button:
		return
	bg_option_button.clear()
	unlocked_backgrounds = CharacterCreationData.get_unlocked_backgrounds()
	for i in range(unlocked_backgrounds.size()):
		var bg = unlocked_backgrounds[i]
		bg_option_button.add_item(bg.get("name", "Unknown Background"), i)
		if bg.get("id") == selected_background_id:
			bg_option_button.select(i)
	if bg_option_button.item_count > 0 and bg_option_button.selected < 0:
		bg_option_button.select(0)
	_on_background_selected(bg_option_button.selected)

func _on_background_selected(index: int) -> void:
	if index >= 0 and index < unlocked_backgrounds.size():
		var bg = unlocked_backgrounds[index]
		selected_background_id = bg.get("id", "novice_adventurer")
		if label_bg_desc:
			label_bg_desc.text = bg.get("description", "")
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
	
	# Points label
	if label_points:
		label_points.text = "Attribute Points Remaining: %d" % remaining
		if remaining == 0:
			label_points.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		else:
			label_points.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			
	# Stat values
	if val_str: val_str.text = str(attributes["strength"])
	if val_dex: val_dex.text = str(attributes["dexterity"])
	if val_con: val_con.text = str(attributes["constitution"])
	if val_int: val_int.text = str(attributes["intelligence"])
	if val_wis: val_wis.text = str(attributes["wisdom"])
	if val_cha: val_cha.text = str(attributes["charisma"])
	
	# Plus/Minus Button states
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
	
	# Derived stats preview (using temporary AttributesData for exact formulas)
	var preview_attrs = AttributesData.new()
	preview_attrs.strength = attributes["strength"]
	preview_attrs.dexterity = attributes["dexterity"]
	preview_attrs.constitution = attributes["constitution"]
	preview_attrs.intelligence = attributes["intelligence"]
	preview_attrs.wisdom = attributes["wisdom"]
	preview_attrs.charisma = attributes["charisma"]
	
	# Factor background bonuses into derived preview if chosen
	if CharacterCreationData.BACKGROUNDS.has(selected_background_id):
		var bg_data = CharacterCreationData.BACKGROUNDS[selected_background_id]
		var b_bonuses = bg_data.get("attribute_bonuses", {})
		for b_attr in b_bonuses.keys():
			var b_val = int(b_bonuses[b_attr])
			match b_attr:
				"strength": preview_attrs.strength += b_val
				"dexterity": preview_attrs.dexterity += b_val
				"constitution": preview_attrs.constitution += b_val
				"intelligence": preview_attrs.intelligence += b_val
				"wisdom": preview_attrs.wisdom += b_val
				"charisma": preview_attrs.charisma += b_val
				
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
		
	# Embark button only enabled if all points are allocated
	if btn_embark:
		btn_embark.disabled = (remaining != 0)

func _on_embark_pressed() -> void:
	if get_remaining_points() != 0:
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
	
	var default_skills: Array[SkillData.SkillId] = [
		SkillData.SkillId.SWORDSMANSHIP,
		SkillData.SkillId.DODGE,
		SkillData.SkillId.PERCEPTION,
		SkillData.SkillId.ALCHEMY
	]
	
	var creation_dict = {
		"attributes": final_attrs,
		"selected_skills": default_skills,
		"starting_items": CharacterCreationData.get_starting_items_for_skills(default_skills),
		"background": selected_background_id
	}
	
	# Apply background package attribute and item bonuses
	creation_dict = CharacterCreationData.apply_background(creation_dict, selected_background_id)
	
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
