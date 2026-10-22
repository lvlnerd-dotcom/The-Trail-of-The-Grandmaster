class_name InventoryComponent
extends Node

## InventoryComponent: Manages inventory items, equipment slots, and Stone weight limits.

signal item_added(item: ItemData)
signal item_removed(item: ItemData)
signal item_equipped(slot: ItemData.EquipSlot, item: ItemData)
signal item_unequipped(slot: ItemData.EquipSlot, item: ItemData)
signal weight_changed(current_stones: float, max_stones: float)
signal inventory_updated()

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
	if not item:
		return
	if item.max_stack > 1:
		var ident = item.is_identified if "is_identified" in item else true
		for existing in items:
			if is_instance_valid(existing) and existing.item_id == item.item_id and existing.max_stack > 1:
				var ex_ident = existing.is_identified if "is_identified" in existing else true
				if ex_ident == ident and existing.quantity < existing.max_stack:
					var space = existing.max_stack - existing.quantity
					if item.quantity <= space:
						existing.quantity += item.quantity
						item.quantity = 0
						emit_signal("item_added", existing)
						emit_signal("inventory_updated")
						return
					else:
						existing.quantity += space
						item.quantity -= space
	items.append(item)
	emit_signal("item_added", item)
	emit_signal("inventory_updated")

func remove_item(item: ItemData) -> bool:
	var idx = items.find(item)
	if idx != -1:
		items.remove_at(idx)
		emit_signal("item_removed", item)
		return true
	return false

func get_item_count(p_item_id: String) -> int:
	var count = 0
	for it in items:
		if is_instance_valid(it) and it.item_id == p_item_id:
			count += it.quantity
	return count

func consume_item_by_id(p_item_id: String, amount: int = 1) -> bool:
	var remaining_needed = amount
	var to_remove: Array[ItemData] = []
	for it in items:
		if is_instance_valid(it) and it.item_id == p_item_id:
			if it.quantity > remaining_needed:
				it.quantity -= remaining_needed
				remaining_needed = 0
				break
			else:
				remaining_needed -= it.quantity
				to_remove.append(it)
				if remaining_needed <= 0:
					break
	for it in to_remove:
		remove_item(it)
	return remaining_needed <= 0

func equip_item(item: ItemData, target_slot: ItemData.EquipSlot = ItemData.EquipSlot.NONE) -> bool:
	if not item or item.equip_slot == ItemData.EquipSlot.NONE:
		return false
	
	var slot = target_slot if target_slot != ItemData.EquipSlot.NONE else item.equip_slot
	
	# Allow offhand-capable weapons (e.g. Main-Gauche) to equip in OFF_HAND if MAIN_HAND is occupied
	if item.can_equip_offhand and target_slot == ItemData.EquipSlot.NONE:
		var mh = equipped_slots.get(ItemData.EquipSlot.MAIN_HAND) as ItemData
		if mh and mh.handedness != ItemData.Handedness.TWO_HANDED and not equipped_slots.has(ItemData.EquipSlot.OFF_HAND):
			slot = ItemData.EquipSlot.OFF_HAND
	
	# Automatic fallback for rings (RING_1 and RING_2)
	if slot == ItemData.EquipSlot.RING_1 or slot == ItemData.EquipSlot.RING_2:
		if target_slot == ItemData.EquipSlot.NONE:
			if not equipped_slots.has(ItemData.EquipSlot.RING_1):
				slot = ItemData.EquipSlot.RING_1
			elif not equipped_slots.has(ItemData.EquipSlot.RING_2):
				slot = ItemData.EquipSlot.RING_2
			else:
				slot = ItemData.EquipSlot.RING_1

	# Enforce 2H vs Offhand mutual exclusion
	if slot == ItemData.EquipSlot.MAIN_HAND and item.handedness == ItemData.Handedness.TWO_HANDED:
		if equipped_slots.has(ItemData.EquipSlot.OFF_HAND):
			unequip_slot(ItemData.EquipSlot.OFF_HAND)
	elif slot == ItemData.EquipSlot.OFF_HAND:
		var current_mh = equipped_slots.get(ItemData.EquipSlot.MAIN_HAND) as ItemData
		if current_mh and current_mh.handedness == ItemData.Handedness.TWO_HANDED:
			unequip_slot(ItemData.EquipSlot.MAIN_HAND)

	# If something already equipped in this slot, unequip it first
	if equipped_slots.has(slot):
		unequip_slot(slot)
	
	# Remove from carried backpack into equipped slot (now exempt from carry weight)
	remove_item(item)
	equipped_slots[slot] = item
	emit_signal("item_equipped", slot, item)
	return true

func swap_backpack_items(idx_a: int, idx_b: int) -> bool:
	if idx_a < 0 or idx_a >= items.size() or idx_b < 0 or idx_b >= items.size():
		return false
	var temp = items[idx_a]
	items[idx_a] = items[idx_b]
	items[idx_b] = temp
	emit_signal("inventory_updated")
	return true

func auto_stack_backpack() -> void:
	var to_remove: Array[ItemData] = []
	for i in range(items.size()):
		var base_item = items[i]
		if not is_instance_valid(base_item) or to_remove.has(base_item):
			continue
		if base_item.max_stack <= 1:
			continue
		var base_ident = base_item.is_identified if "is_identified" in base_item else true
		for j in range(i + 1, items.size()):
			var candidate = items[j]
			if not is_instance_valid(candidate) or to_remove.has(candidate):
				continue
			if candidate.item_id == base_item.item_id and candidate.max_stack > 1:
				var cand_ident = candidate.is_identified if "is_identified" in candidate else true
				if cand_ident == base_ident:
					var space = base_item.max_stack - base_item.quantity
					if space > 0:
						if candidate.quantity <= space:
							base_item.quantity += candidate.quantity
							candidate.quantity = 0
							to_remove.append(candidate)
						else:
							base_item.quantity += space
							candidate.quantity -= space
					if base_item.quantity >= base_item.max_stack:
						break
	for rem in to_remove:
		items.erase(rem)
		emit_signal("item_removed", rem)
	emit_signal("inventory_updated")

func sort_backpack(mode: String = "type") -> void:
	match mode.to_lower():
		"type":
			items.sort_custom(func(a: ItemData, b: ItemData) -> bool:
				if a.item_type != b.item_type:
					return a.item_type < b.item_type
				var name_a = a.get_display_name() if a.has_method("get_display_name") else a.item_name
				var name_b = b.get_display_name() if b.has_method("get_display_name") else b.item_name
				return name_a.naturalnocasecmp_to(name_b) < 0
			)
		"weight":
			items.sort_custom(func(a: ItemData, b: ItemData) -> bool:
				if not is_equal_approx(a.weight_stones, b.weight_stones):
					return a.weight_stones > b.weight_stones # Heaviest first
				var name_a = a.get_display_name() if a.has_method("get_display_name") else a.item_name
				var name_b = b.get_display_name() if b.has_method("get_display_name") else b.item_name
				return name_a.naturalnocasecmp_to(name_b) < 0
			)
		"value":
			items.sort_custom(func(a: ItemData, b: ItemData) -> bool:
				if a.base_value_gold != b.base_value_gold:
					return a.base_value_gold > b.base_value_gold # Most valuable first
				var name_a = a.get_display_name() if a.has_method("get_display_name") else a.item_name
				var name_b = b.get_display_name() if b.has_method("get_display_name") else b.item_name
				return name_a.naturalnocasecmp_to(name_b) < 0
			)
		"name":
			items.sort_custom(func(a: ItemData, b: ItemData) -> bool:
				var name_a = a.get_display_name() if a.has_method("get_display_name") else a.item_name
				var name_b = b.get_display_name() if b.has_method("get_display_name") else b.item_name
				return name_a.naturalnocasecmp_to(name_b) < 0
			)
	emit_signal("inventory_updated")

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

func get_equipped_offhand() -> ItemData:
	if equipped_slots.has(ItemData.EquipSlot.OFF_HAND):
		return equipped_slots[ItemData.EquipSlot.OFF_HAND]
	return null

func get_equipped_shield() -> ItemData:
	var off = get_equipped_offhand()
	if off and off.item_type == ItemData.ItemType.SHIELD:
		return off
	return null

func has_shield_equipped() -> bool:
	return get_equipped_shield() != null

func get_equipped_ammo() -> ItemData:
	if equipped_slots.has(ItemData.EquipSlot.AMMUNITION):
		return equipped_slots[ItemData.EquipSlot.AMMUNITION]
	return null

func get_total_armor() -> int:
	var total_armor = 0
	for slot in equipped_slots.keys():
		var item = equipped_slots[slot] as ItemData
		if item:
			total_armor += item.armor_value
	return total_armor

func get_skills() -> Node:
	var ent = get_parent()
	if ent:
		var direct = ent.get_node_or_null("SkillComponent")
		if direct:
			return direct
		for child in ent.get_children():
			if child.get_class() == "SkillComponent" or (child.get_script() and child.get_script().get_global_name() == "SkillComponent"):
				return child
	return null

func get_total_defense_bonus(stance: Variant = null, skills_comp: Node = null) -> float:
	var skills = skills_comp if skills_comp else get_skills()
	var active_stance = stance
	if active_stance == null and skills and "active_defensive_mode" in skills:
		active_stance = skills.active_defensive_mode
		
	var parry_level: float = 0.0
	var dodge_level: float = 0.0
	if skills and skills.has_method("get_skill"):
		var p_skill = skills.get_skill(SkillData.SkillId.PARRY)
		if p_skill:
			parry_level = p_skill.level
		var d_skill = skills.get_skill(SkillData.SkillId.DODGE)
		if d_skill:
			dodge_level = d_skill.level

	var can_apply_parry_to_dodge: bool = (parry_level >= 25.0)
	var can_apply_dodge_to_parry: bool = (dodge_level >= 25.0)

	var total_def: float = 0.0
	for slot in equipped_slots.keys():
		var item = equipped_slots[slot] as ItemData
		if not item:
			continue
		
		# 1. Universal / stance-neutral defense (e.g. general ward enchantments)
		total_def += item.defense_bonus
		
		# 2. Block & Parry gear bonuses (Shields, Bucklers, Parrying Daggers)
		var parry_block_val = item.block_chance_bonus + item.parry_bonus
		if active_stance == SkillComponent.DefensiveMode.PARRY_BLOCK:
			total_def += parry_block_val
		elif active_stance == SkillComponent.DefensiveMode.DODGE_EVADE:
			if can_apply_parry_to_dodge:
				total_def += parry_block_val
		else:
			# If stance is unspecified (e.g. non-player entity / test mock without stance), apply all
			total_def += parry_block_val
			
		# 3. Dodge gear bonuses (Lightweight Runners, Agility Cloaks, Evasion Rings)
		var dodge_val = item.dodge_bonus
		if active_stance == SkillComponent.DefensiveMode.DODGE_EVADE:
			total_def += dodge_val
		elif active_stance == SkillComponent.DefensiveMode.PARRY_BLOCK:
			if can_apply_dodge_to_parry:
				total_def += dodge_val
		else:
			total_def += dodge_val
			
	return total_def
