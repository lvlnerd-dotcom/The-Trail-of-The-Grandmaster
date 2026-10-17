class_name VictoryModal
extends PanelContainer

## VictoryModal: Displays the ultimate campaign victory screen, run statistics,
## bestowed titles, and meta-progression rewards.

signal main_menu_requested()
signal bestiary_requested()
signal closed()

@onready var label_title: Label = $VBox/LabelTitle
@onready var label_subtitle: Label = $VBox/LabelSubtitle
@onready var label_floors: Label = $VBox/StatsGrid/ValFloors
@onready var label_turns: Label = $VBox/StatsGrid/ValTurns
@onready var label_bosses: Label = $VBox/StatsGrid/ValBosses
@onready var label_kills: Label = $VBox/StatsGrid/ValKills
@onready var label_relic: Label = $VBox/StatsGrid/ValRelic
@onready var label_title_bestowed: Label = $VBox/StatsGrid/ValTitle
@onready var label_exp_gained: Label = $VBox/MetaVBox/LabelExpGained
@onready var label_rank: Label = $VBox/MetaVBox/LabelRank
@onready var progress_exp: ProgressBar = $VBox/MetaVBox/ProgressExp
@onready var label_progress_text: Label = $VBox/MetaVBox/LabelProgressText
@onready var btn_main_menu: Button = $VBox/ButtonContainer/BtnMainMenu
@onready var btn_bestiary: Button = $VBox/ButtonContainer/BtnBestiary

func _ready() -> void:
	BaseModal.apply_opaque_styling(self)
	visible = false
	if btn_main_menu:
		btn_main_menu.pressed.connect(_on_main_menu_pressed)
	if btn_bestiary:
		btn_bestiary.pressed.connect(_on_bestiary_pressed)

func _get_meta_mgr() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("MetaManager")
	return null

func open_modal(summary: Dictionary) -> void:
	visible = true
	
	label_title.text = "TRAIL CONQUERED — VICTORY!"
	label_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	label_subtitle.text = "\"You have vanquished The Grandmaster and achieved absolute mastery.\""
	
	var floors_cleared = int(summary.get("floors_cleared", 20))
	var turns_survived = int(summary.get("turns_survived", 0))
	var std_kills = int(summary.get("standard_kills", 0))
	var elite_kills = int(summary.get("elite_kills", 0))
	var boss_kills = int(summary.get("boss_kills", 1))
	var total_kills = std_kills + elite_kills + boss_kills
	
	label_floors.text = "%d (Grandmaster Sanctum Cleared)" % floors_cleared
	label_turns.text = str(turns_survived)
	label_bosses.text = "%d (The Grandmaster)" % boss_kills
	label_kills.text = "%d Total" % total_kills
	label_relic.text = "Mantle of the Grandmaster"
	label_title_bestowed.text = "Grandmaster of the Trail"
	
	# Meta progression details
	var meta_res: Dictionary = summary.get("meta_result", {})
	if meta_res.is_empty():
		var mm = _get_meta_mgr()
		if mm:
			meta_res = mm.record_run_completion(summary)
		
	var earned_exp = int(meta_res.get("earned_exp", 0))
	var old_rank = int(meta_res.get("old_rank", 1))
	var new_rank = int(meta_res.get("new_rank", old_rank))
	var cur_exp = int(meta_res.get("current_exp", 0))
	var req_exp = int(meta_res.get("req_exp", 200))
	
	label_exp_gained.text = "+%d Account Meta-EXP (+1000 Victory Bonus Included!)" % earned_exp
	
	if new_rank > old_rank:
		label_rank.text = "Account Rank: %d (PROMOTED from Rank %d!)" % [new_rank, old_rank]
		label_rank.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	else:
		label_rank.text = "Account Rank: %d" % new_rank
		label_rank.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
		
	if req_exp > 0:
		progress_exp.max_value = req_exp
		progress_exp.value = cur_exp
		label_progress_text.text = "%d / %d EXP to Rank %d" % [cur_exp, req_exp, new_rank + 1]
	else:
		progress_exp.value = progress_exp.max_value
		label_progress_text.text = "Maximum Rank Reached"

func close_modal() -> void:
	super.close_modal()
	emit_signal("closed")

func _on_main_menu_pressed() -> void:
	close_modal()
	emit_signal("main_menu_requested")
	var tree = get_tree()
	if tree:
		tree.change_scene_to_file("res://scenes/ui/menus/MainMenu.tscn")

func _on_bestiary_pressed() -> void:
	emit_signal("bestiary_requested")
