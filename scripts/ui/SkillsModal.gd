@tool
class_name SkillsModal
extends BaseModal

## SkillsModal: Comprehensive skills and masteries directory with decimal progression
## and keystone milestone unlocks (25, 50, 75, 100).

signal skill_selected(skill_id: SkillData.SkillId)

@onready var filter_bar: HBoxContainer = $VBox/MainSplit/LeftPane/FilterBar
@onready var skill_list_vbox: VBoxContainer = $VBox/MainSplit/LeftPane/ScrollSkills/SkillList
@onready var detail_name: Label = $VBox/MainSplit/RightPane/DetailVBox/LabelSkillName
@onready var detail_attr: Label = $VBox/MainSplit/RightPane/DetailVBox/LabelAttr
@onready var detail_level: Label = $VBox/MainSplit/RightPane/DetailVBox/LabelLevel
@onready var progress_bar: ProgressBar = $VBox/MainSplit/RightPane/DetailVBox/ProgressTenth
@onready var progress_text: Label = $VBox/MainSplit/RightPane/DetailVBox/LabelProgressText
@onready var detail_desc: Label = $VBox/MainSplit/RightPane/DetailVBox/LabelDescription
@onready var keystones_vbox: VBoxContainer = $VBox/MainSplit/RightPane/DetailVBox/KeystonesVBox
@onready var btn_close: Button = $VBox/HeaderBar/BtnClose

var player: Node2D = null
var skill_component: SkillComponent = null
var attributes: AttributesData = null
var current_filter: int = -1 # -1: ALL, 0: STARTING, 1: META, 2: CLASS
var selected_skill_id: SkillData.SkillId = SkillData.SkillId.SWORDSMANSHIP
var skill_buttons: Dictionary = {} # SkillId -> Button

func _ready() -> void:
	close_on_escape = true
	super._ready()
	if btn_close:
		btn_close.pressed.connect(close_modal)
	_setup_filter_buttons()

func open_modal_with_player(p_player: Node2D) -> void:
	player = p_player
	if player:
		skill_component = player.get_node_or_null("SkillComponent") as SkillComponent
		var stats = player.get_node_or_null("StatsComponent") as StatsComponent
		if stats:
			attributes = stats.attributes
	super.open_modal()
	_refresh_skills_list()
	_display_skill_detail(selected_skill_id)

func _setup_filter_buttons() -> void:
	if not filter_bar:
		return
	for c in filter_bar.get_children():
		c.queue_free()
		
	var filters = [
		{"label": "ALL", "val": -1},
		{"label": "STARTING", "val": SkillData.SkillTier.STARTING},
		{"label": "META", "val": SkillData.SkillTier.META},
		{"label": "CLASS", "val": SkillData.SkillTier.CLASS_EXCLUSIVE}
	]
	
	for f in filters:
		var btn = Button.new()
		btn.text = f["label"]
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(func():
			current_filter = f["val"]
			_refresh_skills_list()
		)
		filter_bar.add_child(btn)

func _refresh_skills_list() -> void:
	if not skill_list_vbox:
		return
	for c in skill_list_vbox.get_children():
		c.queue_free()
	skill_buttons.clear()
	
	# Collect all known skills from skill_component or static definitions
	var all_skills: Array[SkillData.SkillId] = []
	for s_id in SkillData.SkillId.values():
		all_skills.append(s_id)
		
	for s_id in all_skills:
		var s_tier = SkillData.get_tier_for_skill(s_id)
		if current_filter != -1 and s_tier != current_filter:
			continue
			
		var s_data: SkillData = null
		if skill_component and skill_component.skills.has(s_id):
			s_data = skill_component.skills[s_id]
			
		var lvl = s_data.level if s_data else 0.0
		var s_name = SkillData.get_skill_name(s_id)
		var attr_tag = "[%s]" % SkillData.get_associated_attribute(s_id).to_upper().substr(0, 3)
		var tier_tag = ""
		match s_tier:
			SkillData.SkillTier.STARTING: tier_tag = "[START]"
			SkillData.SkillTier.META: tier_tag = "[META]"
			SkillData.SkillTier.CLASS_EXCLUSIVE: tier_tag = "[CLASS]"
			
		var btn = Button.new()
		btn.text = "%-7s %-20s %04.1f / 100.0  %s" % [tier_tag, s_name, lvl, attr_tag]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.focus_mode = Control.FOCUS_NONE
		
		# Modulation styling based on skill state
		if s_data and s_data.level > 0.0:
			btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		elif s_tier == SkillData.SkillTier.CLASS_EXCLUSIVE:
			btn.add_theme_color_override("font_color", Color(0.6, 0.5, 0.6))
		else:
			btn.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
			
		btn.pressed.connect(func():
			selected_skill_id = s_id
			_display_skill_detail(s_id)
			emit_signal("skill_selected", s_id)
		)
		
		skill_list_vbox.add_child(btn)
		skill_buttons[s_id] = btn

func _display_skill_detail(s_id: SkillData.SkillId) -> void:
	var s_name = SkillData.get_skill_name(s_id)
	var s_tier = SkillData.get_tier_for_skill(s_id)
	var attr_name = SkillData.get_associated_attribute(s_id).capitalize()
	
	var s_data: SkillData = null
	if skill_component and skill_component.skills.has(s_id):
		s_data = skill_component.skills[s_id]
		
	var cur_lvl = s_data.level if s_data else 0.0
	var cur_xp = s_data.current_xp if s_data else 0.0
	
	detail_name.text = s_name.to_upper()
	detail_attr.text = "Governing Core Attribute: %s" % attr_name
	detail_level.text = "Current Level: %04.1f / 100.0" % cur_lvl
	
	# Progress towards next 0.1 decimal increase
	var next_tenth = snappedf(cur_lvl + 0.1, 0.1)
	var pct = (cur_xp / SkillData.XP_PER_TENTH_LEVEL) * 100.0
	progress_bar.value = clampf(pct, 0.0, 100.0)
	progress_text.text = "Progress to %04.1f: %.0f%% (%02.1f / %02.1f XP)" % [next_tenth, pct, cur_xp, SkillData.XP_PER_TENTH_LEVEL]
	
	detail_desc.text = SkillData.get_skill_description(s_id)
	
	# Populate Keystone Milestone cards (25, 50, 75, 100)
	for c in keystones_vbox.get_children():
		c.queue_free()
		
	for milestone in SkillData.KEYSTONE_MILESTONES:
		var info = SkillData.get_milestone_info(s_id, milestone)
		var is_unlocked = cur_lvl >= float(milestone)
		
		var card = PanelContainer.new()
		var flat = StyleBoxFlat.new()
		flat.corner_radius_top_left = 4
		flat.corner_radius_top_right = 4
		flat.corner_radius_bottom_right = 4
		flat.corner_radius_bottom_left = 4
		flat.content_margin_left = 8.0
		flat.content_margin_top = 6.0
		flat.content_margin_right = 8.0
		flat.content_margin_bottom = 6.0
		
		if is_unlocked:
			flat.bg_color = Color(0.12, 0.16, 0.12, 1.0)
			flat.border_color = Color(0.3, 0.8, 0.4, 1.0)
			flat.border_width_left = 2
			flat.border_width_top = 2
			flat.border_width_right = 2
			flat.border_width_bottom = 2
		else:
			flat.bg_color = Color(0.08, 0.09, 0.11, 1.0)
			flat.border_color = Color(0.20, 0.22, 0.26, 1.0)
			flat.border_width_left = 1
			flat.border_width_top = 1
			flat.border_width_right = 1
			flat.border_width_bottom = 1
		card.add_theme_stylebox_override("panel", flat)
		
		var vbox = VBoxContainer.new()
		var hbox = HBoxContainer.new()
		
		var lbl_title = Label.new()
		lbl_title.text = info["title"]
		lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if is_unlocked:
			lbl_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		else:
			lbl_title.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
		hbox.add_child(lbl_title)
		
		var lbl_badge = Label.new()
		if is_unlocked:
			lbl_badge.text = "[✓ UNLOCKED]"
			lbl_badge.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		else:
			lbl_badge.text = "[🔒 REQUIRES LVL %d.0]" % milestone
			lbl_badge.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
		hbox.add_child(lbl_badge)
		vbox.add_child(hbox)
		
		var lbl_benefit = Label.new()
		lbl_benefit.text = info["benefit"]
		lbl_benefit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl_benefit.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85) if is_unlocked else Color(0.5, 0.52, 0.56))
		vbox.add_child(lbl_benefit)
		
		card.add_child(vbox)
		keystones_vbox.add_child(card)
