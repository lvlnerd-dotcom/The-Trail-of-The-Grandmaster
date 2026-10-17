class_name HotbarBar
extends PanelContainer

## HotbarBar: Bottom-centered 10-slot quick-action hotbar mapped to keys 1 through 0.
## Supports spells, consumables, and throwable weapons.

signal hotbar_action_executed(slot_index: int, action_type: String, details: Dictionary)

enum SlotType {
	EMPTY,
	SPELL,
	ITEM
}

class HotbarSlot:
	var slot_type: SlotType = SlotType.EMPTY
	var spell: SpellData = null
	var item: ItemData = null
	var key_number: int = 1 # 1 through 10 (10 = key 0)

@onready var slots_container: HBoxContainer = $Margin/HBoxSlots

const TOTAL_SLOTS: int = 10
var slots: Array[HotbarSlot] = []
var slot_buttons: Array[Button] = []
var player: Node2D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_apply_opaque_style()
	_init_slots()

func _apply_opaque_style() -> void:
	var flat = StyleBoxFlat.new()
	flat.bg_color = Color(0.06, 0.07, 0.09, 0.95)
	flat.border_width_left = 2
	flat.border_width_top = 2
	flat.border_width_right = 2
	flat.border_width_bottom = 2
	flat.border_color = Color(0.24, 0.28, 0.36, 1.0)
	flat.corner_radius_top_left = 6
	flat.corner_radius_top_right = 6
	flat.corner_radius_bottom_right = 6
	flat.corner_radius_bottom_left = 6
	flat.content_margin_left = 8.0
	flat.content_margin_top = 6.0
	flat.content_margin_right = 8.0
	flat.content_margin_bottom = 6.0
	flat.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	flat.shadow_size = 6
	add_theme_stylebox_override("panel", flat)

func _init_slots() -> void:
	if not slots_container:
		if slots.is_empty():
			for i in range(TOTAL_SLOTS):
				var s = HotbarSlot.new()
				s.key_number = (i + 1) % 10
				slots.append(s)
		return
	for c in slots_container.get_children():
		c.queue_free()
	slots.clear()
	slot_buttons.clear()

	for i in range(TOTAL_SLOTS):
		var s = HotbarSlot.new()
		s.key_number = (i + 1) % 10 # 1..9, 0
		slots.append(s)

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(56, 52)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(Callable(self, "_on_slot_button_pressed").bind(i))
		slots_container.add_child(btn)
		slot_buttons.append(btn)

	refresh_hotbar()

func setup(p_player: Node2D) -> void:
	player = p_player
	_auto_populate_defaults()
	refresh_hotbar()

func _auto_populate_defaults() -> void:
	if not player:
		return
	
	var spell_cast = player.get_node_or_null("SpellCastingComponent") as SpellCastingComponent
	var inv = player.get_node_or_null("InventoryComponent") as InventoryComponent
	
	var slot_idx = 0
	# Assign known spells first
	if spell_cast:
		for sp in spell_cast.known_spells:
			if slot_idx < TOTAL_SLOTS:
				set_slot_spell(slot_idx, sp)
				slot_idx += 1
				
	# Assign usable consumables/throwables from inventory
	if inv:
		for it in inv.items:
			if slot_idx < TOTAL_SLOTS:
				if it.item_type == ItemData.ItemType.CONSUMABLE or it.item_type == ItemData.ItemType.AMMO:
					set_slot_item(slot_idx, it)
					slot_idx += 1

func set_slot_spell(slot_idx: int, spell: SpellData) -> void:
	if slot_idx >= 0 and slot_idx < slots.size():
		slots[slot_idx].slot_type = SlotType.SPELL
		slots[slot_idx].spell = spell
		slots[slot_idx].item = null
		refresh_hotbar()

func set_slot_item(slot_idx: int, item: ItemData) -> void:
	if slot_idx >= 0 and slot_idx < slots.size():
		slots[slot_idx].slot_type = SlotType.ITEM
		slots[slot_idx].item = item
		slots[slot_idx].spell = null
		refresh_hotbar()

func clear_slot(slot_idx: int) -> void:
	if slot_idx >= 0 and slot_idx < slots.size():
		slots[slot_idx].slot_type = SlotType.EMPTY
		slots[slot_idx].spell = null
		slots[slot_idx].item = null
		refresh_hotbar()

func refresh_hotbar() -> void:
	for i in range(slots.size()):
		if i >= slot_buttons.size():
			continue
		var s = slots[i]
		var btn = slot_buttons[i]
		var key_str = str(s.key_number)
		
		match s.slot_type:
			SlotType.EMPTY:
				btn.text = "[%s]\n---" % key_str
				btn.modulate = Color(0.4, 0.4, 0.4, 0.7)
			SlotType.SPELL:
				if s.spell:
					var short_name = s.spell.spell_name.substr(0, 4).to_upper()
					btn.text = "[%s] %s\n%d MP" % [key_str, short_name, s.spell.mana_cost]
					btn.modulate = Color(0.4, 0.8, 1.0) if s.spell.school == SpellData.School.ARCANE else Color(1.0, 0.9, 0.4)
				else:
					btn.text = "[%s]\n---" % key_str
					btn.modulate = Color(0.4, 0.4, 0.4, 0.7)
			SlotType.ITEM:
				if s.item:
					var short_name = s.item.item_name.substr(0, 4).to_upper()
					var count_tag = "x%d" % s.item.quantity if s.item.quantity > 1 else "use"
					btn.text = "[%s] %s\n%s" % [key_str, short_name, count_tag]
					btn.modulate = Color(0.5, 1.0, 0.6) if s.item.item_type == ItemData.ItemType.CONSUMABLE else Color(1.0, 0.65, 0.5)
				else:
					btn.text = "[%s]\n---" % key_str
					btn.modulate = Color(0.4, 0.4, 0.4, 0.7)

func trigger_slot(slot_idx: int, target_cell: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	if slot_idx < 0 or slot_idx >= slots.size():
		return {"success": false, "message": "Invalid slot index"}
		
	var s = slots[slot_idx]
	if s.slot_type == SlotType.EMPTY:
		return {"success": false, "message": "Slot is empty"}

	if not player or not is_instance_valid(player):
		return {"success": false, "message": "No player available"}

	var world = player.get_parent().get_parent() if player.get_parent() else null
	var grid = world.get("grid") as DungeonGrid if world else null
	var enemies = world.get("enemies") as Array if world else []
	var fow = world.get("fow_system") as FogOfWarSystem if world else null

	if s.slot_type == SlotType.SPELL:
		var spell_cast = player.get_node_or_null("SpellCastingComponent") as SpellCastingComponent
		if not spell_cast or not s.spell:
			return {"success": false, "message": "Cannot cast spell"}

		# Check mana
		if player.stats.current_mana < s.spell.mana_cost:
			return {"success": false, "message": "Not enough mana! (Requires %d MP)" % s.spell.mana_cost}

		# Target determination: self spells target player, ranged spells target nearest visible hostile or target_cell
		var cast_target = player.grid_pos
		if s.spell.target_type != SpellData.TargetType.SELF:
			if target_cell != Vector2i(-1, -1):
				cast_target = target_cell
			else:
				# Find closest visible enemy in range
				var best_target = Vector2i(-1, -1)
				var best_dist = 999
				for e in enemies:
					if is_instance_valid(e) and (not fow or fow.is_visible(e.grid_pos)):
						var dist = abs(e.grid_pos.x - player.grid_pos.x) + abs(e.grid_pos.y - player.grid_pos.y)
						if dist <= s.spell.range_tiles and dist < best_dist:
							best_dist = dist
							best_target = e.grid_pos
				if best_target != Vector2i(-1, -1):
					cast_target = best_target
				else:
					return {"success": false, "message": "No visible hostile target in range for %s!" % s.spell.spell_name}

		var res = spell_cast.cast_spell(s.spell, cast_target, grid)
		refresh_hotbar()
		emit_signal("hotbar_action_executed", slot_idx, "spell", res)
		return res

	elif s.slot_type == SlotType.ITEM:
		var inv = player.get_node_or_null("InventoryComponent") as InventoryComponent
		if not inv or not s.item:
			return {"success": false, "message": "Item unavailable"}

		var item_ref = s.item
		var it_name = item_ref.item_name

		if item_ref.item_type == ItemData.ItemType.CONSUMABLE:
			# Use consumable: heal or cure
			var heal_amt = 25
			player.stats.current_hp = minf(player.stats.current_hp + heal_amt, player.stats.attributes.get_max_health())
			item_ref.quantity -= 1
			if item_ref.quantity <= 0:
				inv.remove_item(item_ref)
				clear_slot(slot_idx)
			refresh_hotbar()
			var msg = "Consumed %s (+%d HP restored)" % [it_name, heal_amt]
			emit_signal("hotbar_action_executed", slot_idx, "consumable", {"success": true, "message": msg})
			return {"success": true, "message": msg}

		elif item_ref.item_type == ItemData.ItemType.AMMO:
			# Throw dagger/knife at closest visible enemy
			var best_enemy: Node2D = null
			var best_dist = 999
			for e in enemies:
				if is_instance_valid(e) and (not fow or fow.is_visible(e.grid_pos)):
					var dist = abs(e.grid_pos.x - player.grid_pos.x) + abs(e.grid_pos.y - player.grid_pos.y)
					if dist <= 6 and dist < best_dist:
						best_dist = dist
						best_enemy = e
			if not best_enemy:
				return {"success": false, "message": "No enemy in range to throw %s at!" % it_name}

			var dmg = randi_range(6, 12)
			best_enemy.stats.take_damage(dmg)
			item_ref.quantity -= 1
			if item_ref.quantity <= 0:
				inv.remove_item(item_ref)
				clear_slot(slot_idx)
			refresh_hotbar()
			var def_name = best_enemy.get("enemy_name") if "enemy_name" in best_enemy else best_enemy.name
			var msg = "Threw %s at %s for %d damage!" % [it_name, def_name, dmg]
			emit_signal("hotbar_action_executed", slot_idx, "throw", {"success": true, "message": msg, "target": best_enemy})
			return {"success": true, "message": msg}

	return {"success": false, "message": "Unknown hotbar action"}

func _on_slot_button_pressed(slot_idx: int) -> void:
	trigger_slot(slot_idx)
