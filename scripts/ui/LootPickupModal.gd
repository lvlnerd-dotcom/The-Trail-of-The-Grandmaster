@tool
class_name LootPickupModal
extends BaseModal

## LootPickupModal: Handles multi-item floor loot selection and treasure chest interaction
## (lockpicking, trap disarming, smashing, and item looting).

signal loot_collected(items_taken: Array[ItemData])

@onready var label_title: Label = $VBox/HeaderBar/LabelTitle
@onready var btn_close: Button = $VBox/HeaderBar/BtnClose
@onready var label_status: Label = $VBox/LabelStatus
@onready var chest_actions_box: HBoxContainer = $VBox/ChestActions
@onready var btn_disarm: Button = $VBox/ChestActions/BtnDisarm
@onready var btn_pick_lock: Button = $VBox/ChestActions/BtnPickLock
@onready var btn_smash: Button = $VBox/ChestActions/BtnSmash
@onready var items_container: VBoxContainer = $VBox/ScrollItems/ItemsList
@onready var footer_bar: HBoxContainer = $VBox/FooterBar
@onready var btn_take_all: Button = $VBox/FooterBar/BtnTakeAll
@onready var label_footer_info: Label = $VBox/FooterBar/LabelFooterInfo

var player: Node2D = null
var current_world_item: WorldItem = null
var current_chest: TreasureChest = null
var tooltip: ItemTooltip = null

func _ready() -> void:
	close_on_escape = true
	super._ready()
	_ensure_tooltip()
	
	if btn_close:
		btn_close.pressed.connect(close_modal)
	if btn_take_all:
		btn_take_all.pressed.connect(_on_take_all_pressed)
	if btn_disarm:
		btn_disarm.pressed.connect(_on_disarm_pressed)
	if btn_pick_lock:
		btn_pick_lock.pressed.connect(_on_pick_lock_pressed)
	if btn_smash:
		btn_smash.pressed.connect(_on_smash_pressed)

func _ensure_tooltip() -> void:
	if not tooltip:
		var scene = load("res://scenes/ui/components/ItemTooltip.tscn")
		if scene:
			tooltip = scene.instantiate() as ItemTooltip
			add_child(tooltip)

func close_modal() -> void:
	if tooltip:
		tooltip.cancel_hover()
	super.close_modal()

func open_modal_with_world_item(p_world_item: WorldItem, p_player: Node2D) -> void:
	current_world_item = p_world_item
	current_chest = null
	player = p_player
	super.open_modal()
	refresh_view()

func open_modal_with_chest(p_chest: TreasureChest, p_player: Node2D) -> void:
	current_chest = p_chest
	current_world_item = null
	player = p_player
	super.open_modal()
	refresh_view()

func refresh_view() -> void:
	if not is_instance_valid(player):
		close_modal()
		return
		
	# Clear previous item rows
	for child in items_container.get_children():
		child.queue_free()
		
	if current_chest:
		_refresh_chest_view()
	elif current_world_item:
		_refresh_world_item_view()
	else:
		close_modal()

func _refresh_world_item_view() -> void:
	chest_actions_box.visible = false
	label_title.text = "Floor Loot Pile"
	
	if not current_world_item or current_world_item.items.is_empty():
		close_modal()
		return
		
	label_status.text = "Items lying on the stone floor (%d items):" % current_world_item.items.size()
	btn_take_all.visible = true
	
	for i in range(current_world_item.items.size()):
		var item = current_world_item.items[i]
		_create_item_row(item, Callable(self, "_on_take_floor_item").bind(item))
		
	_update_footer_weight()

func _refresh_chest_view() -> void:
	if not current_chest:
		close_modal()
		return
		
	label_title.text = current_chest.chest_name
	
	if not current_chest.is_opened:
		chest_actions_box.visible = true
		btn_take_all.visible = false
		
		var status_lines: Array[String] = []
		if current_chest.is_trapped:
			if current_chest.is_trap_revealed:
				status_lines.append("[color=#ff4444]Trapped Mechanism Detected! Disarm recommended.[/color]")
			else:
				status_lines.append("Suspicious seams around the rim. Trap unconfirmed.")
		else:
			status_lines.append("No active trap detected.")
			
		if current_chest.is_locked:
			status_lines.append("Heavy iron padlock engaged (Difficulty %.0f)." % current_chest.lock_difficulty)
		else:
			status_lines.append("Unlocked.")
			
		status_lines.append("Structural Integrity: %d/%d HP (Hardness %d)" % [
			int(current_chest.structural_hp), int(current_chest.max_structural_hp), int(current_chest.hardness)
		])
		
		label_status.text = "\n".join(status_lines)
		btn_disarm.visible = current_chest.is_trapped and current_chest.is_trap_revealed
		btn_pick_lock.visible = current_chest.is_locked
		btn_smash.visible = true
	else:
		# Opened or Smashed coffer
		chest_actions_box.visible = false
		btn_take_all.visible = true
		
		if current_chest.contents.is_empty():
			label_status.text = "The coffer lies empty."
		else:
			label_status.text = "Coffer opened! Remaining spoils (%d items):" % current_chest.contents.size()
			for item in current_chest.contents:
				_create_item_row(item, Callable(self, "_on_take_chest_item").bind(item))
				
		_update_footer_weight()

func _create_item_row(item: ItemData, take_callback: Callable) -> void:
	if not item:
		return
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 36)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.mouse_entered.connect(func():
		if tooltip:
			var inv = player.get_node_or_null("InventoryComponent") as InventoryComponent if player else null
			var compare_gear = inv.equipped_slots.get(item.equip_slot) as ItemData if (inv and item.equip_slot != ItemData.EquipSlot.NONE) else null
			var skills = player.get_node_or_null("SkillComponent") as SkillComponent if player else null
			tooltip.request_hover_item(item, get_global_mouse_position(), compare_gear, skills)
	)
	row.mouse_exited.connect(func():
		if tooltip:
			tooltip.cancel_hover()
	)
	
	var lbl_name = Label.new()
	lbl_name.text = "  •  %s" % item.item_name
	lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var lbl_info = Label.new()
	var val_str = "%d GP" % item.base_value_gold if item.base_value_gold > 0 else "0 GP"
	lbl_info.text = "%.1f St.  |  %s  " % [item.weight_stones, val_str]
	lbl_info.modulate = Color(0.75, 0.75, 0.8)
	
	var btn_take = Button.new()
	btn_take.text = " Take "
	btn_take.custom_minimum_size = Vector2(65, 30)
	btn_take.pressed.connect(take_callback)
	
	row.add_child(lbl_name)
	row.add_child(lbl_info)
	row.add_child(btn_take)
	items_container.add_child(row)

func _update_footer_weight() -> void:
	if player and "inventory" in player and player.inventory and "stats" in player and player.stats and player.stats.attributes:
		var cur = player.inventory.get_carried_weight_stones()
		var max_wt = player.stats.attributes.get_max_carry_weight_stones()
		label_footer_info.text = "Current Burden: %.1f / %.0f Stones" % [cur, max_wt]

func _on_take_floor_item(item: ItemData) -> void:
	if tooltip:
		tooltip.cancel_hover()
	if not player or not current_world_item:
		return
	var inv = player.get_node_or_null("InventoryComponent") as InventoryComponent
	if inv:
		inv.add_item(item)
	current_world_item.remove_item(item)
	emit_signal("loot_collected", [item])
	if current_world_item.items.is_empty():
		current_world_item.queue_free()
		close_modal()
	else:
		refresh_view()

func _on_take_chest_item(item: ItemData) -> void:
	if tooltip:
		tooltip.cancel_hover()
	if not player or not current_chest:
		return
	var inv = player.get_node_or_null("InventoryComponent") as InventoryComponent
	if inv:
		inv.add_item(item)
	current_chest.contents.erase(item)
	emit_signal("loot_collected", [item])
	if current_chest.contents.is_empty():
		refresh_view()
	else:
		refresh_view()

func _on_take_all_pressed() -> void:
	if tooltip:
		tooltip.cancel_hover()
	if not player:
		return
	var inv = player.get_node_or_null("InventoryComponent") as InventoryComponent
	if not inv:
		return
		
	var taken: Array[ItemData] = []
	if current_world_item:
		for item in current_world_item.items.duplicate():
			inv.add_item(item)
			taken.append(item)
		current_world_item.items.clear()
		current_world_item.queue_free()
		emit_signal("loot_collected", taken)
		close_modal()
	elif current_chest:
		for item in current_chest.contents.duplicate():
			inv.add_item(item)
			taken.append(item)
		current_chest.contents.clear()
		emit_signal("loot_collected", taken)
		close_modal()

func _on_disarm_pressed() -> void:
	if not current_chest or not player:
		return
	var res = current_chest.disarm_trap(player)
	label_status.text = res.get("reason", "")
	refresh_view()

func _on_pick_lock_pressed() -> void:
	if not current_chest or not player:
		return
	var res = current_chest.pick_lock(player)
	label_status.text = res.get("reason", "")
	refresh_view()

func _on_smash_pressed() -> void:
	if not current_chest or not player:
		return
	var inv = player.get_node_or_null("InventoryComponent") as InventoryComponent
	var weapon = inv.get_equipped_weapon() if inv else null
	var raw_dmg = 15.0
	if player.has_node("StatsComponent"):
		var stats = player.get_node("StatsComponent") as StatsComponent
		if stats and stats.attributes:
			raw_dmg = 8.0 + float(stats.attributes.strength) * 1.5
	var res = current_chest.take_structural_damage(player, raw_dmg, weapon)
	if res.get("destroyed", false):
		label_status.text = "Chest Smashed Open! Structural damage dealt: %d. Shattered vials: %d." % [
			res["damage_dealt"], res.get("shattered_count", 0)
		]
	else:
		label_status.text = "Strike breached coffer for %d structural damage! (Remaining HP: %d)" % [
			res["damage_dealt"], int(res["remaining_hp"])
		]
	refresh_view()
