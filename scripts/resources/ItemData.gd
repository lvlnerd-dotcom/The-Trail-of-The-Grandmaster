class_name ItemData
extends Resource

const AttributesData = preload("res://scripts/resources/AttributesData.gd")
const SkillData = preload("res://scripts/resources/SkillData.gd")
const WeaponAbilityData = preload("res://scripts/resources/WeaponAbilityData.gd")

## ItemData: Resource representing items, weapons, armor, ammo, and consumables.

enum ItemType {
    WEAPON,
    SHIELD,
    ARMOR,
    CONSUMABLE,
    AMMO,
    RELIC,
    VALUABLE
}

enum EquipSlot {
    NONE,
    HEAD,
    BACK,
    MAIN_HAND,
    OFF_HAND,
    BODY,
    BELT,
    LEGS,
    FEET,
    RING_1,
    RING_2,
    ACCESSORY,
    AMMUNITION
}

enum Handedness {
    ONE_HANDED,
    TWO_HANDED,
    VERSATILE
}

static func get_slot_name(slot: EquipSlot) -> String:
    match slot:
        EquipSlot.HEAD: return "Head"
        EquipSlot.BACK: return "Back"
        EquipSlot.MAIN_HAND: return "Main Hand"
        EquipSlot.OFF_HAND: return "Off Hand"
        EquipSlot.BODY: return "Body"
        EquipSlot.BELT: return "Belt"
        EquipSlot.LEGS: return "Legs"
        EquipSlot.FEET: return "Feet"
        EquipSlot.RING_1: return "Ring 1"
        EquipSlot.RING_2: return "Ring 2"
        EquipSlot.ACCESSORY: return "Accessory"
        EquipSlot.AMMUNITION: return "Ammunition"
        _: return "None"

@export var item_id: String = ""
@export var item_name: String = ""
@export var item_type: ItemType = ItemType.WEAPON
@export var equip_slot: EquipSlot = EquipSlot.NONE
@export var weight_stones: float = 1.0 # Weight in stones
@export var base_value_gold: int = 10
@export var description: String = ""
@export var quantity: int = 1
@export var max_stack: int = 1
@export var is_identified: bool = true
@export var unlocked_ability_name: String = ""

# Combat stats for weapons
@export var weapon_type: AttributesData.WeaponType = AttributesData.WeaponType.MELEE
@export var associated_skill_id: SkillData.SkillId = SkillData.SkillId.SWORDSMANSHIP
@export var handedness: Handedness = Handedness.ONE_HANDED
@export var base_damage_min: int = 2
@export var base_damage_max: int = 8
@export var accuracy_bonus: float = 0.0
@export var defense_bonus: float = 0.0
@export var armor_penetration: float = 0.0
@export var range_tiles: int = 1
@export var area_radius: int = 0

# Special Weapon Mechanics
@export var backstab_multiplier: float = 1.0
@export var poison_chance: float = 0.0
@export var bleed_chance: float = 0.0
@export var stun_chance: float = 0.0
@export var crit_chance_bonus: float = 0.0
@export var requires_ammo: bool = false
@export var is_returning: bool = false
@export var can_equip_offhand: bool = false
@export var uses_inventory_weight: bool = false
@export var is_fragile: bool = false
@export var is_silver: bool = false
@export var tags: Array = []

# Level 25 Active Weapon Ability
@export var active_ability: WeaponAbilityData = null

# Defense stats for armor / shields
@export var armor_value: int = 0
@export var block_chance_bonus: float = 0.0

# Relic and Accessory Modifiers
@export var attribute_bonuses: Dictionary = {}
@export var parry_bonus: float = 0.0
@export var dodge_bonus: float = 0.0
@export var carry_weight_bonus: float = 0.0

func _init(
    p_id: String = "",
    p_name: String = "",
    p_type: ItemType = ItemType.WEAPON,
    p_slot: EquipSlot = EquipSlot.NONE,
    p_weight: float = 1.0,
    p_quantity: int = 1
) -> void:
    item_id = p_id
    item_name = p_name
    item_type = p_type
    equip_slot = p_slot
    weight_stones = p_weight
    quantity = p_quantity

func get_is_identified() -> bool:
    if has_meta("is_potion") and has_meta("potion_id"):
        var ac = load("res://scripts/resources/AlchemyCatalog.gd")
        if ac and ac.has_method("is_potion_identified"):
            return ac.is_potion_identified(get_meta("potion_id") as String)
    return is_identified

func get_ability_name() -> String:
    if unlocked_ability_name != "":
        return unlocked_ability_name
    if active_ability:
        return active_ability.ability_name
    return ""

static func create_alchemical_bomb(qty: int = 3) -> ItemData:
    var bomb = ItemData.new("alchemical_bomb", "Alchemical Fire Bomb", ItemType.AMMO, EquipSlot.AMMUNITION, 0.5, qty)
    bomb.weapon_type = AttributesData.WeaponType.THROWN
    bomb.associated_skill_id = SkillData.SkillId.THROWING
    bomb.base_damage_min = 12
    bomb.base_damage_max = 20
    bomb.range_tiles = 5
    bomb.area_radius = 1 # 3x3 blast radius
    bomb.base_value_gold = 25
    bomb.description = "Volatile alchemical flask that shatters on impact, engulfing a 3x3 area in searing flame."
    return bomb

static func create_flintlock_pistol() -> ItemData:
    var pistol = ItemData.new("flintlock_pistol", "Dwarven Flintlock Pistol", ItemType.WEAPON, EquipSlot.MAIN_HAND, 2.0, 1)
    pistol.weapon_type = AttributesData.WeaponType.FIREARM
    pistol.associated_skill_id = SkillData.SkillId.MARKSMANSHIP
    pistol.base_damage_min = 6
    pistol.base_damage_max = 14
    pistol.accuracy_bonus = 0.10
    pistol.range_tiles = 6
    pistol.base_value_gold = 60
    pistol.description = "Precision black-powder sidearm with high armor-piercing velocity."
    return pistol

static func create_silver_sword() -> ItemData:
    var sword = ItemData.new("sword_silver", "Silver Longsword", ItemType.WEAPON, EquipSlot.MAIN_HAND, 2.5, 1)
    sword.weapon_type = AttributesData.WeaponType.MELEE
    sword.associated_skill_id = SkillData.SkillId.SWORDSMANSHIP
    sword.base_damage_min = 5
    sword.base_damage_max = 11
    sword.is_silver = true
    sword.tags = ["silver_weapon"]
    sword.base_value_gold = 75
    sword.description = "Blessed blade forged with pure silver inlay. Deadly against the undead."
    return sword

func get_display_name() -> String:
    if has_meta("is_potion") and has_meta("potion_id"):
        var ac = load("res://scripts/resources/AlchemyCatalog.gd")
        if ac and ac.has_method("get_potion_display_name"):
            return ac.get_potion_display_name(get_meta("potion_id") as String)
    return item_name

func get_inspection_data() -> InspectionData:
    var data = InspectionData.new()
    var d_title = get_display_name()
    data.title = d_title if d_title != "" else "Mysterious Object"
    data.category = InspectionData.Category.ITEM_OR_OBJECT
    
    var slot_str = get_slot_name(equip_slot)
    var type_str = ItemType.keys()[item_type]
    var qty_str = " (x%d)" % quantity if quantity > 1 else ""
    data.category_text = "%s • %s%s" % [type_str, slot_str if equip_slot != EquipSlot.NONE else "Loose", qty_str]
    
    match item_type:
        ItemType.WEAPON:
            data.icon_glyph = "/"
            data.accent_color = Color(1.0, 0.45, 0.4)
        ItemType.ARMOR, ItemType.SHIELD:
            data.icon_glyph = "["
            data.accent_color = Color(0.4, 0.75, 1.0)
        ItemType.CONSUMABLE:
            data.icon_glyph = "!"
            data.accent_color = Color(0.4, 1.0, 0.5)
        ItemType.RELIC:
            data.icon_glyph = "*"
            data.accent_color = Color(1.0, 0.85, 0.2)
        _:
            data.icon_glyph = "?"
            data.accent_color = Color(0.8, 0.85, 0.95)
            
    var traits: Array[String] = []
    if item_type == ItemType.WEAPON or item_type == ItemType.AMMO:
        if base_damage_max > 0:
            traits.append("Dmg: %d-%d" % [base_damage_min, base_damage_max])
        if range_tiles > 1:
            traits.append("Range: %d" % range_tiles)
        if area_radius > 0:
            var dim = area_radius * 2 + 1
            traits.append("AoE: %dx%d" % [dim, dim])
    elif item_type == ItemType.ARMOR or item_type == ItemType.SHIELD:
        if armor_value > 0:
            traits.append("Armor: +%d" % armor_value)
    traits.append("Weight: %.1f st" % (weight_stones * quantity))
    if base_value_gold > 0:
        traits.append("Val: %d GP" % base_value_gold)
    var d_desc = description
    if has_meta("is_potion") and has_meta("potion_id"):
        var ac = load("res://scripts/resources/AlchemyCatalog.gd")
        if ac and ac.has_method("get_potion_display_description"):
            d_desc = ac.get_potion_display_description(get_meta("potion_id") as String)
    if d_desc != "":
        traits.append(d_desc)
        
    data.description = " • ".join(traits)
    return data


