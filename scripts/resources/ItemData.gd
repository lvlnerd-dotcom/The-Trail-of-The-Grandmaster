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

