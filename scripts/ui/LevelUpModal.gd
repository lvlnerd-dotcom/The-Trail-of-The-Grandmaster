class_name LevelUpModal
extends PanelContainer

## LevelUpModal: Interactive dialog for distributing attribute points on level up.

signal points_allocated()

@onready var label_title: Label = $VBox/LabelTitle
@onready var label_points: Label = $VBox/LabelPoints
@onready var grid_attrs: GridContainer = $VBox/AttrGrid
@onready var btn_close: Button = $VBox/BtnClose

var player_attributes: AttributesData = null

func _ready() -> void:
    visible = false
    if btn_close:
        btn_close.pressed.connect(_on_close_pressed)

func open_modal(attrs: AttributesData) -> void:
    player_attributes = attrs
    visible = true
    refresh_ui()

func refresh_ui() -> void:
    if not player_attributes:
        return
    
    label_title.text = "LEVEL UP! Level %d" % player_attributes.character_level
    label_points.text = "Unallocated Attribute Points: %d" % player_attributes.unallocated_attribute_points
    
    # Update attribute labels & buttons
    _update_attr_row("STR", player_attributes.strength, "+25%% Melee dmg / 10 STR, %d Stones carry" % int(player_attributes.get_max_carry_weight_stones()))
    _update_attr_row("DEX", player_attributes.dexterity, "%.1f%% Crit chance, Agility bonus" % (player_attributes.get_critical_chance() * 100.0))
    _update_attr_row("CON", player_attributes.constitution, "Max HP: %d, Passive turn healing" % int(player_attributes.get_max_health()))
    _update_attr_row("INT", player_attributes.intelligence, "Max Mana: %d, Skill XP rate: %.0f%%" % [int(player_attributes.get_max_mana()), player_attributes.get_skill_xp_multiplier() * 100.0])
    _update_attr_row("WIS", player_attributes.wisdom, "Shrine & Taboo efficiency, Trap Perception")
    _update_attr_row("CHA", player_attributes.charisma, "Prices: %.0f%%, Companion stat boost" % (player_attributes.get_mercantile_modifier() * 100.0))

func _update_attr_row(attr_key: String, current_val: int, description: String) -> void:
    var lbl_val = grid_attrs.get_node_or_null("Val_" + attr_key) as Label
    var btn_add = grid_attrs.get_node_or_null("Btn_" + attr_key) as Button
    var lbl_desc = grid_attrs.get_node_or_null("Desc_" + attr_key) as Label
    
    if lbl_val:
        lbl_val.text = str(current_val)
    if lbl_desc:
        lbl_desc.text = description
    if btn_add:
        btn_add.disabled = (player_attributes.unallocated_attribute_points <= 0)
        # Disconnect existing before reconnecting
        if not btn_add.is_connected("pressed", Callable(self, "_on_add_pressed").bind(attr_key)):
            btn_add.pressed.connect(Callable(self, "_on_add_pressed").bind(attr_key))

func _on_add_pressed(attr_key: String) -> void:
    if not player_attributes or player_attributes.unallocated_attribute_points <= 0:
        return
    
    var full_name = ""
    match attr_key:
        "STR": full_name = "strength"
        "DEX": full_name = "dexterity"
        "CON": full_name = "constitution"
        "INT": full_name = "intelligence"
        "WIS": full_name = "wisdom"
        "CHA": full_name = "charisma"
        
    var ok = player_attributes.allocate_attribute_point(full_name)
    if ok:
        refresh_ui()
        emit_signal("points_allocated")

func _on_close_pressed() -> void:
    visible = false
