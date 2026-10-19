class_name HotbarBar
extends PanelContainer

## HotbarBar: Bottom-centered 10-slot quick-action hotbar mapped to keys 1 through 0.
## Supports spells, consumables, and throwable weapons.

signal hotbar_action_executed(slot_index: int, action_type: String, details: Dictionary)
signal targeting_requested(slot_index: int, context: Dictionary)


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
				
	# Assign equipped throwable ammo if present
	if inv:
		var eq_ammo = inv.get_equipped_ammo()
		if eq_ammo and slot_idx < TOTAL_SLOTS:
			set_slot_item(slot_idx, eq_ammo)
			slot_idx += 1

		# Assign usable consumables/throwables from inventory
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

func requires_manual_targeting(slot_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= slots.size():
		return false
	var s = slots[slot_idx]
	if s.slot_type == SlotType.SPELL and s.spell:
		if s.spell.target_type == SpellData.TargetType.SELF:
			return false
		if s.spell.effect_type == SpellData.EffectType.HEALING and s.spell.range_tiles <= 1:
			return false
		if s.spell.effect_type == SpellData.EffectType.STATUS_CLEANSE and s.spell.range_tiles <= 1:
			return false
		return true
	elif s.slot_type == SlotType.ITEM and s.item:
		if s.item.item_type == ItemData.ItemType.AMMO or s.item.item_type == ItemData.ItemType.WEAPON or s.item.area_radius > 0:
			return true
	return false

func get_slot_targeting_context(slot_idx: int) -> Dictionary:
	if slot_idx < 0 or slot_idx >= slots.size():
		return {}
	var s = slots[slot_idx]
	if s.slot_type == SlotType.SPELL and s.spell:
		return {
			"mode": TargetingSystem.ActionMode.SPELL,
			"label": s.spell.spell_name,
			"max_range": s.spell.range_tiles,
			"area_radius": s.spell.area_radius,
			"is_beam": s.spell.target_type == SpellData.TargetType.BEAM,
			"is_teleport": s.spell.effect_type == SpellData.EffectType.TELEPORT,
			"allow_self": s.spell.effect_type == SpellData.EffectType.HEALING or s.spell.effect_type == SpellData.EffectType.STATUS_CLEANSE,
			"slot_index": slot_idx,
			"spell": s.spell,
			"color": s.spell.vfx_color
		}
	elif s.slot_type == SlotType.ITEM and s.item:
		var r_tiles = s.item.range_tiles if s.item.range_tiles > 1 else 6
		return {
			"mode": TargetingSystem.ActionMode.THROWN_ITEM,
			"label": s.item.item_name,
			"max_range": r_tiles,
			"area_radius": s.item.area_radius,
			"is_beam": false,
			"is_teleport": false,
			"allow_self": false,
			"slot_index": slot_idx,
			"item": s.item
		}
	return {}

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

	var p_stats = player.get("stats") as StatsComponent if "stats" in player else (player.get_node_or_null("StatsComponent") as StatsComponent)

	if s.slot_type == SlotType.SPELL:
		var spell_cast = player.get_node_or_null("SpellCastingComponent") as SpellCastingComponent
		if not spell_cast or not s.spell:
			return {"success": false, "message": "Cannot cast spell"}

		# Check mana before entering targeting or casting
		if p_stats and p_stats.current_mana < s.spell.mana_cost:
			return {"success": false, "message": "Not enough mana! (Requires %d MP)" % s.spell.mana_cost}

		if target_cell == Vector2i(-1, -1) and requires_manual_targeting(slot_idx):
			var ctx = get_slot_targeting_context(slot_idx)
			emit_signal("targeting_requested", slot_idx, ctx)
			return {
				"success": false,
				"requires_targeting": true,
				"slot_index": slot_idx,
				"context": ctx,
				"message": "Targeting %s (Range %d) — Select a tile [LMB/Enter to confirm, RMB/Esc to cancel]." % [s.spell.spell_name, s.spell.range_tiles]
			}

		var cast_target = target_cell if target_cell != Vector2i(-1, -1) else player.grid_pos
		var res = spell_cast.cast_spell(s.spell, cast_target, grid)
		if res.get("success", false):
			var eff_pt: Vector2i = res.get("effective_target_cell", cast_target)
			var intercept_tag = " [INTERCEPTED]" if res.get("intercepted", false) else ""
			res["message"] = "Cast %s at (%d, %d)%s!" % [s.spell.spell_name, eff_pt.x, eff_pt.y, intercept_tag]
		else:
			res["message"] = res.get("reason", "Failed to cast %s" % s.spell.spell_name)
		refresh_hotbar()
		emit_signal("hotbar_action_executed", slot_idx, "spell", res)
		return res

	elif s.slot_type == SlotType.ITEM:
		var inv = player.get_node_or_null("InventoryComponent") as InventoryComponent
		if not inv or not s.item:
			return {"success": false, "message": "Item unavailable"}

		var item_ref = s.item
		var it_name = item_ref.item_name

		if item_ref.item_type == ItemData.ItemType.CONSUMABLE and item_ref.area_radius <= 0:
			# Use self consumable: heal or cure
			var heal_amt = 25
			if p_stats:
				p_stats.current_hp = minf(p_stats.current_hp + heal_amt, p_stats.attributes.get_max_health())
			item_ref.quantity -= 1
			if item_ref.quantity <= 0:
				inv.remove_item(item_ref)
				clear_slot(slot_idx)
			refresh_hotbar()
			var msg = "Consumed %s (+%d HP restored)" % [it_name, heal_amt]
			emit_signal("hotbar_action_executed", slot_idx, "consumable", {"success": true, "message": msg})
			return {"success": true, "message": msg}


		elif requires_manual_targeting(slot_idx):
			if item_ref.quantity <= 0:
				clear_slot(slot_idx)
				return {"success": false, "message": "Out of %s!" % it_name}

			if target_cell == Vector2i(-1, -1):
				var ctx = get_slot_targeting_context(slot_idx)
				emit_signal("targeting_requested", slot_idx, ctx)
				return {
					"success": false,
					"requires_targeting": true,
					"slot_index": slot_idx,
					"context": ctx,
					"message": "Aiming %s — Select a tile [LMB/Enter to confirm, RMB/Esc to cancel]." % it_name
				}

			var combat_comp = player.get_node_or_null("CombatComponent") as CombatComponent
			if combat_comp:
				var r_res = combat_comp.execute_ranged_attack(player.grid_pos, target_cell, grid, null, item_ref)
				if item_ref.quantity <= 0:
					clear_slot(slot_idx)
				refresh_hotbar()
				emit_signal("hotbar_action_executed", slot_idx, "throw", r_res)
				return r_res

	return {"success": false, "message": "Unknown hotbar action"}

func _on_slot_button_pressed(slot_idx: int) -> void:
	if player and player.get_parent() and player.get_parent().get_parent():
		var world = player.get_parent().get_parent()
		if world.has_method("trigger_hotbar_slot"):
			world.trigger_hotbar_slot(slot_idx)
			return
	trigger_slot(slot_idx)

