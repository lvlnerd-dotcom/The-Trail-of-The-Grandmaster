@tool
class_name GameOverModal
extends PanelContainer

## GameOverModal: Displays run summary, cause of death/victory, and account meta-progression.

signal restart_requested()
signal closed()

@onready var label_title: Label = $VBox/LabelTitle
@onready var label_epitaph: Label = $VBox/LabelEpitaph
@onready var label_floors: Label = $VBox/StatsGrid/ValFloors
@onready var label_turns: Label = $VBox/StatsGrid/ValTurns
@onready var label_kills: Label = $VBox/StatsGrid/ValKills
@onready var label_gold: Label = $VBox/StatsGrid/ValGold
@onready var label_exp_gained: Label = $VBox/MetaVBox/LabelExpGained
@onready var label_rank: Label = $VBox/MetaVBox/LabelRank
@onready var progress_exp: ProgressBar = $VBox/MetaVBox/ProgressExp
@onready var label_progress_text: Label = $VBox/MetaVBox/LabelProgressText
@onready var text_unlocks: RichTextLabel = $VBox/MetaVBox/TextUnlocks
@onready var btn_restart: Button = $VBox/ButtonContainer/BtnRestart

func _ready() -> void:
    BaseModal.apply_opaque_styling(self)
    visible = false
    if btn_restart:
        btn_restart.pressed.connect(_on_restart_pressed)

func open_modal(summary: Dictionary) -> void:
    visible = true
    
    var is_victory = bool(summary.get("victory", false))
    if is_victory:
        label_title.text = "VICTORY ACHIEVED!"
        label_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
    else:
        label_title.text = "EXPEDITION TERMINATED"
        label_title.add_theme_color_override("font_color", Color(0.9, 0.25, 0.25))
        
    var cause = str(summary.get("cause_of_death", "Perished in the treacherous depths of the Trail."))
    label_epitaph.text = "\"%s\"" % cause
    
    var floors_cleared = int(summary.get("floors_cleared", 0))
    var turns_survived = int(summary.get("turns_survived", 0))
    var std_kills = int(summary.get("standard_kills", 0))
    var elite_kills = int(summary.get("elite_kills", 0))
    var boss_kills = int(summary.get("boss_kills", 0))
    var total_kills = std_kills + elite_kills + boss_kills
    var gold = int(summary.get("gold_earned", 0))
    
    label_floors.text = str(floors_cleared)
    label_turns.text = str(turns_survived)
    label_kills.text = "%d (Std: %d, Elite: %d, Boss: %d)" % [total_kills, std_kills, elite_kills, boss_kills]
    label_gold.text = "%d GP" % gold
    
    # Meta progression details
    var meta_res: Dictionary = summary.get("meta_result", {})
    var earned_exp = int(meta_res.get("earned_exp", 0))
    var old_rank = int(meta_res.get("old_rank", 1))
    var new_rank = int(meta_res.get("new_rank", old_rank))
    var promoted: Array = meta_res.get("promoted_ranks", [])
    var cur_exp = int(meta_res.get("current_exp", 0))
    var req_exp = int(meta_res.get("req_exp", 200))
    
    label_exp_gained.text = "+%d Account Meta-EXP Earned" % earned_exp
    
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
        label_progress_text.text = "Max Rank Reached"
        
    # Unlocks notice
    if not promoted.is_empty():
        var unlock_msg = "[color=lime][b]Rank Advancement Rewards Unlocked![/b][/color]\n"
        for r in promoted:
            unlock_msg += "• Reached Rank %d: New background / skill pool perks unlocked!\n" % r
        text_unlocks.text = unlock_msg
        text_unlocks.visible = true
    else:
        text_unlocks.visible = false

func _get_game_mgr() -> Node:
    var loop = Engine.get_main_loop()
    if loop and loop is SceneTree:
        return (loop as SceneTree).root.get_node_or_null("GameManager")
    return null

func close_modal() -> void:
    visible = false
    emit_signal("closed")

func _on_restart_pressed() -> void:
    close_modal()
    emit_signal("restart_requested")
    var gm = _get_game_mgr()
    if gm:
        gm.open_creation_on_main_menu = true
    var tree = get_tree()
    if tree:
        tree.change_scene_to_file("res://scenes/ui/menus/MainMenu.tscn")

