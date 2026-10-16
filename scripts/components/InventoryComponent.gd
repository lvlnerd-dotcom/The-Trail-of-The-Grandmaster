class_name InventoryComponent
extends Node

## InventoryComponent: Manages inventory items, equipment slots, and Stone weight limits.

signal item_added(item: ItemData)
signal item_removed(item: ItemData)
signal item_equipped(slot: ItemData.EquipSlot, item: ItemData)
signal item_unequipped(slot: ItemData.EquipSlot, item: ItemData)
signal weight_changed(current_stones: float, max_stones: float)

var items: Array[ItemData] = []
var backpack_items: Array[ItemData]:
	get:
		return items
var equipped_slots: Dictionary = {} # ItemData.EquipSlot -> ItemData
@export var gold: int = 0

func get_carried_weight_stones() -> float:
	# Strictly implements GDD rule: Equipment worn does NOT contribute to carry weight.
	var total_weight: float = 0.0
	for item in items:
		if is_instance_valid(item):
			total_weight += item.weight_stones
	return snappedf(total_weight, 0.1)

func is_overburdened(max_stones: float) -> bool:
	return get_carried_weight_stones() > max_stones

func add_item(item: ItemData) -> void:
	if item:
		items.append(item)
		emit_signal("item_added", item)

func remove_item(item: ItemData) -> bool:
	var idx = items.find(item)
	if idx != -1:
		items.remove_at(idx)
		emit_signal("item_removed", item)
		return true
	return false

func equip_item(item: ItemData) -> bool:
	if not item or item.equip_slot == ItemData.EquipSlot.NONE:
		return false
	
	var slot = item.equip_slot
	
	# If something already equipped in this slot, unequip it first
	if equipped_slots.has(slot):
		unequip_slot(slot)
	
	# Remove from carried backpack into equipped slot (now exempt from carry weight)
	remove_item(item)
	equipped_slots[slot] = item
	emit_signal("item_equipped", slot, item)
	return true

func unequip_slot(slot: ItemData.EquipSlot) -> ItemData:
	if not equipped_slots.has(slot):
		return null
	
	var item = equipped_slots[slot] as ItemData
	equipped_slots.erase(slot)
	# Return to backpack (counts toward weight limit again)
	add_item(item)
	emit_signal("item_unequipped", slot, item)
	return item

func get_equipped_weapon() -> ItemData:
	if equipped_slots.has(ItemData.EquipSlot.MAIN_HAND):
		return equipped_slots[ItemData.EquipSlot.MAIN_HAND]
	return null

func get_total_armor() -> int:
	var total_armor = 0
	for slot in equipped_slots.keys():
		var item = equipped_slots[slot] as ItemData
		if item:
			total_armor += item.armor_value
	return total_armor
