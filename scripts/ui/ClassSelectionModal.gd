class_name ClassSelectionModal
extends PanelContainer

## ClassSelectionModal: Interactive dialog for post-Floor 2 class specialization.

const ClassCatalog = preload("res://scripts/resources/ClassCatalog.gd")

signal class_chosen(class_data: ClassData)

@onready var filter_container: HBoxContainer = $VBox/FilterBar
@onready var class_list_vbox: VBoxContainer = $VBox/MainSplit/LeftPane/Scroll/ClassList
@onready var detail_title: Label = $VBox/MainSplit/RightPane/DetailVBox/LabelClassName
@onready var detail_archetype: Label = $VBox/MainSplit/RightPane/DetailVBox/LabelArchetype
@onready var detail_desc: Label = $VBox/MainSplit/RightPane/DetailVBox/LabelDescription
@onready var detail_reqs: RichTextLabel = $VBox/MainSplit/RightPane/DetailVBox/TextPrereqs
@onready var detail_perks: RichTextLabel = $VBox/MainSplit/RightPane/DetailVBox/TextPerks
@onready var label_status: Label = $VBox/MainSplit/RightPane/DetailVBox/LabelEligibilityStatus
@onready var btn_confirm: Button = $VBox/BottomBar/BtnConfirm

var player: Node2D = null
var current_filter: int = -1 # -1 = ALL, or ClassData.Archetype enum
var selected_class: ClassData = null

func _ready() -> void:
    BaseModal.apply_opaque_styling(self)
    visible = false
    if btn_confirm:
        btn_confirm.pressed.connect(_on_confirm_pressed)
    _setup_filter_buttons()

func open_modal(p_player: Node2D) -> void:
    player = p_player
    visible = true
    current_filter = -1
    _refresh_class_list()
    
    # Default selection: first eligible class or Vagabond
    var all_classes = ClassCatalog.get_all_classes()
    var default_selection: ClassData = null
    var p_stats = player.get_node_or_null("StatsComponent") as StatsComponent if player else null
    var p_skills = player.get_node_or_null("SkillComponent") as SkillComponent if player else null
    if p_stats and p_skills:
        for c in all_classes:
            if c.is_eligible(p_stats.attributes, p_skills):
                default_selection = c
                break
    if not default_selection:
        default_selection = ClassCatalog.get_class_by_id("vagabond")
    if not default_selection and not all_classes.is_empty():
        default_selection = all_classes[0]
        
    select_class(default_selection)

func close_modal() -> void:
    visible = false

func _setup_filter_buttons() -> void:
    if not filter_container:
        return
    for child in filter_container.get_children():
        if child is Button:
            child.pressed.connect(Callable(self, "_on_filter_button_pressed").bind(child))

func _on_filter_button_pressed(btn: Button) -> void:
    var btn_name = btn.name.to_upper()
    if btn_name.contains("ALL"):
        current_filter = -1
    elif btn_name.contains("MARTIAL"):
        current_filter = ClassData.Archetype.MARTIAL
    elif btn_name.contains("ROGUE") or btn_name.contains("RANGED"):
        current_filter = ClassData.Archetype.ROGUE_RANGED
    elif btn_name.contains("ARCANE"):
        current_filter = ClassData.Archetype.ARCANE
    elif btn_name.contains("DIVINE"):
        current_filter = ClassData.Archetype.DIVINE
    elif btn_name.contains("HYBRID"):
        current_filter = ClassData.Archetype.HYBRID
        
    _refresh_class_list()

func _refresh_class_list() -> void:
    if not class_list_vbox:
        return
        
    for child in class_list_vbox.get_children():
        child.queue_free()
        
    var all_classes = ClassCatalog.get_all_classes()
    var p_stats = player.get_node_or_null("StatsComponent") as StatsComponent if player else null
    var attrs = p_stats.attributes if p_stats else null
    var skills = player.get_node_or_null("SkillComponent") as SkillComponent if player else null
    
    for c in all_classes:
        if current_filter != -1 and c.archetype != current_filter and c.archetype != ClassData.Archetype.GENERAL:
            continue
            
        var is_elig = c.is_eligible(attrs, skills) if (attrs and skills) else (c.archetype == ClassData.Archetype.GENERAL)
        var btn = Button.new()
        btn.custom_minimum_size = Vector2(260, 36)
        btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
        
        var status_tag = "[✔ ELIGIBLE]" if is_elig else "[🔒 LOCKED]"
        btn.text = " %s  %s" % [status_tag, c.class_title]
        
        if is_elig:
            btn.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
            btn.add_theme_color_override("font_hover_color", Color(0.7, 1.0, 0.7))
        else:
            btn.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
            btn.add_theme_color_override("font_hover_color", Color(0.85, 0.85, 0.9))
            
        btn.pressed.connect(Callable(self, "select_class").bind(c))
        class_list_vbox.add_child(btn)

func select_class(class_data: ClassData) -> void:
    if not class_data:
        return
    selected_class = class_data
    
    if detail_title:
        detail_title.text = class_data.class_title
    if detail_archetype:
        detail_archetype.text = "Archetype: %s" % ClassData.Archetype.keys()[class_data.archetype]
    if detail_desc:
        detail_desc.text = class_data.description
    
    var p_stats = player.get_node_or_null("StatsComponent") as StatsComponent if player else null
    var attrs = p_stats.attributes if p_stats else null
    var skills = player.get_node_or_null("SkillComponent") as SkillComponent if player else null
    var is_elig = class_data.is_eligible(attrs, skills) if (attrs and skills) else true
    
    # Build Prerequisites display
    var req_text = "[b]Prerequisites & Requirements:[/b]\n"
    if class_data.archetype == ClassData.Archetype.GENERAL or class_data.class_id == "vagabond":
        req_text += "[color=lime]None (Universal Fallback - Always Available)[/color]\n"
    else:
        if class_data.required_attributes.is_empty() and class_data.required_skills.is_empty() and class_data.min_weapon_skills_count == 0:
            req_text += "[color=lime]No specific requirements[/color]\n"
        else:
            # Attributes
            for attr_name in class_data.required_attributes.keys():
                var req_v = int(class_data.required_attributes[attr_name])
                var cur_v = class_data._get_attr_value(attrs, attr_name) if attrs else 0
                var pass_attr = cur_v >= req_v
                var col = "lime" if pass_attr else "red"
                var mark = "✔" if pass_attr else "✖"
                req_text += "• %s: %d / %d [%color=%s]%s[/color]\n" % [attr_name.capitalize(), cur_v, req_v, col, mark]
                
            # Skills
            for s_id in class_data.required_skills.keys():
                var req_lvl = float(class_data.required_skills[s_id])
                var s = skills.get_skill(s_id) if skills else null
                var cur_lvl = s.level if s else 0.0
                var s_name = s.skill_name if s else SkillData.SkillId.keys()[s_id].capitalize()
                var pass_s = cur_lvl >= req_lvl
                var col = "lime" if pass_s else "red"
                var mark = "✔" if pass_s else "✖"
                req_text += "• %s: %.1f / %.1f [%color=%s]%s[/color]\n" % [s_name, cur_lvl, req_lvl, col, mark]
                
            # Weapon skills
            if class_data.min_weapon_skills_count > 0:
                req_text += "• Weapon Mastery: %d weapon skills >= %.1f\n" % [class_data.min_weapon_skills_count, class_data.min_weapon_skills_level]
                
        var aptitude = class_data.calculate_aptitude(attrs, skills) if (attrs and skills) else 0.0
        req_text += "\n[b]Aptitude Score:[/b] %.1f / 25.0 %s" % [aptitude, "([color=lime]Passed[/color])" if aptitude >= 25.0 else "([color=gray]Below[/color])"]
        
    if detail_reqs:
        detail_reqs.text = req_text
    
    # Build Perks & Bonuses display
    var perk_text = "[b]Attribute Bonuses:[/b]\n"
    if class_data.attribute_bonuses.is_empty():
        perk_text += "None\n"
    else:
        var bonus_strs: Array[String] = []
        for a_name in class_data.attribute_bonuses.keys():
            var b = int(class_data.attribute_bonuses[a_name])
            bonus_strs.append("+%d %s" % [b, a_name.capitalize()])
        perk_text += ", ".join(bonus_strs) + "\n"
        
    perk_text += "\n[b]Passive Perk: %s[/b]\n%s\n" % [class_data.passive_title, class_data.passive_description]
    if not class_data.signature_ability_name.is_empty():
        perk_text += "\n[b]Signature Ability: %s[/b]\n%s" % [class_data.signature_ability_name, class_data.signature_ability_description]
        
    if detail_perks:
        detail_perks.text = perk_text
    
    # Update eligibility status label and confirm button
    if label_status:
        if is_elig:
            label_status.text = "STATUS: ELIGIBLE FOR SPECIALIZATION"
            label_status.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
        else:
            label_status.text = "STATUS: LOCKED (Prerequisites Not Met)"
            label_status.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
    if btn_confirm:
        if is_elig:
            btn_confirm.disabled = false
            btn_confirm.text = "Confirm Specialization: %s" % class_data.class_title
        else:
            btn_confirm.disabled = true
            btn_confirm.text = "Locked (Requirements Not Met)"

func _on_confirm_pressed() -> void:
    if not selected_class or not player:
        return
    var p_stats = player.get_node_or_null("StatsComponent") as StatsComponent if player else null
    var attrs = p_stats.attributes if p_stats else null
    var skills = player.get_node_or_null("SkillComponent") as SkillComponent if player else null
    if not selected_class.is_eligible(attrs, skills):
        return
        
    emit_signal("class_chosen", selected_class)
    close_modal()
