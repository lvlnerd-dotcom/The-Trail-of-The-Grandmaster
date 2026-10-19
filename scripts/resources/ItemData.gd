class_name ItemData
extends Resource

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

# Combat stats for weapons
@export var weapon_type: AttributesData.WeaponType = AttributesData.WeaponType.MELEE
@export var base_damage_min: int = 2
@export var base_damage_max: int = 8
@export var accuracy_bonus: float = 0.0
@export var range_tiles: int = 1
@export var area_radius: int = 0

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

static func create_alchemical_bomb(qty: int = 3) -> ItemData:
    var bomb = ItemData.new("alchemical_bomb", "Alchemical Fire Bomb", ItemType.AMMO, EquipSlot.AMMUNITION, 0.5, qty)
    bomb.weapon_type = AttributesData.WeaponType.THROWN
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
    pistol.base_damage_min = 6
    pistol.base_damage_max = 14
    pistol.accuracy_bonus = 0.10
    pistol.range_tiles = 6
    pistol.base_value_gold = 60
    pistol.description = "Precision black-powder sidearm with high armor-piercing velocity."
    return pistol

func get_inspection_data() -> InspectionData:
    var data = InspectionData.new()
    data.title = item_name if item_name != "" else "Mysterious Object"
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
    if description != "":
        traits.append(description)
        
    data.description = " • ".join(traits)
    return data


