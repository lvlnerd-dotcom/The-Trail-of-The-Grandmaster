class_name Merchant
extends BaseEntity

## Merchant: Peaceful NPC entity in dungeon safe rooms and corridors offering specialized trade.
## Can convert into a deadly Boss-Tier Hostile NPC if attacked.

const ShopData = preload("res://scripts/resources/ShopData.gd")
const MerchantCatalog = preload("res://scripts/resources/MerchantCatalog.gd")
const StatsComponent = preload("res://scripts/components/StatsComponent.gd")
const CombatComponent = preload("res://scripts/components/CombatComponent.gd")
const InventoryComponent = preload("res://scripts/components/InventoryComponent.gd")
const WorldItem = preload("res://scripts/world/WorldItem.gd")

@export var shop_data: ShopData
@export var is_peaceful: bool = true
@export var merchant_id: String = ""
@export var display_name: String = "Travelling Merchant"
@export var depth_tier: int = 1
@export var is_boss: bool = false

var stats: StatsComponent = null
var combat: CombatComponent = null
var inventory: InventoryComponent = null
var current_floor_num: int = 1

func _ready() -> void:
	super._ready()
	_ensure_components()
	if not shop_data:
		shop_data = ShopData.create_default_shop()
	var gm = _get_game_mgr()
	if gm and gm.merchants_hostile_this_run and is_peaceful:
		become_hostile(null, current_floor_num)

func _ensure_components() -> void:
	stats = get_node_or_null("StatsComponent") as StatsComponent
	if not stats:
		stats = StatsComponent.new()
		stats.name = "StatsComponent"
		add_child(stats)
		
	combat = get_node_or_null("CombatComponent") as CombatComponent
	if not combat:
		combat = CombatComponent.new()
		combat.name = "CombatComponent"
		add_child(combat)
		
	inventory = get_node_or_null("InventoryComponent") as InventoryComponent
	if not inventory:
		inventory = InventoryComponent.new()
		inventory.name = "InventoryComponent"
		add_child(inventory)

func _get_game_mgr() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("GameManager")
	return null

func get_merchant_name() -> String:
	if shop_data and shop_data.merchant_name != "":
		return shop_data.merchant_name
	return display_name

func setup(p_shop_data: ShopData = null, p_grid: DungeonGrid = null, p_pos: Vector2i = Vector2i.ZERO, p_turn_manager: TurnManager = null, p_info: Dictionary = {}, p_tier: int = 1, p_floor: int = 1) -> void:
	current_floor_num = p_floor
	depth_tier = p_tier
	_ensure_components()
	
	if not p_info.is_empty():
		merchant_id = p_info.get("merchant_id", "")
		display_name = p_info.get("display_name", "Travelling Merchant")
		
	if p_shop_data:
		shop_data = p_shop_data
	elif not shop_data:
		var specialty_val = int(p_info.get("shop_type", 0))
		shop_data = ShopData.generate_stock_for_specialty(specialty_val, depth_tier, p_info)
		
	if shop_data and shop_data.merchant_name != "":
		display_name = shop_data.merchant_name
		
	if p_grid:
		init_grid_position(p_grid, p_pos, p_turn_manager)
		
	var gm = _get_game_mgr()
	if gm and gm.merchants_hostile_this_run:
		become_hostile(null, current_floor_num)

func _get_current_turn() -> int:
	if turn_manager:
		return turn_manager.turn_number
	return 0

func _get_player_cha(player: Node2D) -> int:
	if not player:
		return 10
	var p_stats = player.get_node_or_null("StatsComponent") as StatsComponent
	if not p_stats:
		for child in player.get_children():
			if child is StatsComponent:
				p_stats = child
				break
	if p_stats and p_stats.attributes:
		return p_stats.attributes.charisma
	return 10

func _get_player_bartering(player: Node2D) -> float:
	if not player:
		return 0.0
	var p_skills = player.get_node_or_null("SkillComponent") as SkillComponent
	if not p_skills:
		for child in player.get_children():
			if child is SkillComponent:
				p_skills = child
				break
	if p_skills:
		var s = p_skills.get_skill(SkillData.SkillId.BARTERING)
		if s:
			return s.level
	return 0.0

func _get_player_inventory(player: Node2D) -> InventoryComponent:
	if not player:
		return null
	var inv = player.get_node_or_null("InventoryComponent") as InventoryComponent
	if not inv:
		for child in player.get_children():
			if child is InventoryComponent:
				inv = child
				break
	return inv

func get_player_gold(player: Node2D) -> int:
	if not player:
		return 0
	if "gold" in player:
		return player.gold
	var inv = _get_player_inventory(player)
	if inv and "gold" in inv:
		return inv.gold
	if player.has_meta("gold"):
		return player.get_meta("gold")
	return 0

func set_player_gold(player: Node2D, amount: int) -> void:
	if not player:
		return
	if "gold" in player:
		player.gold = amount
	var inv = _get_player_inventory(player)
	if inv and "gold" in inv:
		inv.gold = amount
	if player.has_meta("gold") or not ("gold" in player or (inv and "gold" in inv)):
		player.set_meta("gold", amount)

func _train_bartering_xp(player: Node2D, transaction_gold_val: int) -> void:
	if not player or transaction_gold_val <= 0:
		return
	var skills = player.get_node_or_null("SkillComponent") as SkillComponent
	var p_stats = player.get_node_or_null("StatsComponent") as StatsComponent
	if not skills:
		for child in player.get_children():
			if child is SkillComponent:
				skills = child
				break
	if not p_stats:
		for child in player.get_children():
			if child is StatsComponent:
				p_stats = child
				break
	if skills and p_stats and p_stats.attributes:
		var task_difficulty = ShopData.calculate_bartering_task_difficulty(transaction_gold_val)
		skills.train_skill(SkillData.SkillId.BARTERING, task_difficulty, p_stats.attributes)

## Player purchases item from Merchant
func buy_item(player: Node2D, item: ItemData) -> Dictionary:
	if not is_peaceful:
		return {"success": false, "reason": "Merchant is hostile!"}
	if not shop_data or not item:
		return {"success": false, "reason": "Invalid item or shop"}
		
	var item_idx = shop_data.stock_items.find(item)
	if item_idx == -1:
		return {"success": false, "reason": "Item not in merchant stock"}
		
	var player_cha = _get_player_cha(player)
	var bartering_lvl = _get_player_bartering(player)
	var cur_turn = _get_current_turn()
	var price = shop_data.get_buy_price(item, player_cha, bartering_lvl, cur_turn)
	var player_gold = get_player_gold(player)
	
	if player_gold < price:
		return {"success": false, "reason": "Insufficient gold (costs %d, have %d)" % [price, player_gold]}
		
	var inv = _get_player_inventory(player)
	if not inv:
		return {"success": false, "reason": "Player has no inventory"}
		
	# Check overburden warning
	var will_overburden = false
	var p_stats = player.get_node_or_null("StatsComponent") as StatsComponent
	if p_stats and p_stats.attributes:
		var max_weight = p_stats.attributes.get_max_carry_weight_stones()
		will_overburden = inv.get_carried_weight_stones() + item.weight_stones > max_weight
		
	# Transfer gold
	set_player_gold(player, player_gold - price)
	shop_data.merchant_gold += price
	
	# Clear buyback meta if present
	if item.has_meta("buyback_turn"):
		item.remove_meta("buyback_turn")
	if item.has_meta("buyback_price"):
		item.remove_meta("buyback_price")
		
	# Transfer item
	shop_data.stock_items.remove_at(item_idx)
	inv.add_item(item)
	
	# Train Bartering skill
	_train_bartering_xp(player, price)
	
	var bus = _get_event_bus()
	if bus:
		bus.emit_signal("item_purchased", item, price)
		
	return {
		"success": true,
		"price": price,
		"item": item,
		"overburdened": will_overburden,
		"remaining_gold": get_player_gold(player)
	}

## Player sells item to Merchant
func sell_item(player: Node2D, item: ItemData) -> Dictionary:
	if not is_peaceful:
		return {"success": false, "reason": "Merchant is hostile!"}
	if not shop_data or not item:
		return {"success": false, "reason": "Invalid item or shop"}
		
	var inv = _get_player_inventory(player)
	if not inv or not inv.items.has(item):
		return {"success": false, "reason": "Item not in player inventory"}
		
	var player_cha = _get_player_cha(player)
	var bartering_lvl = _get_player_bartering(player)
	var price = shop_data.get_sell_price(item, player_cha, bartering_lvl)
	
	if shop_data.merchant_gold < price:
		return {"success": false, "reason": "Merchant does not have enough gold"}
		
	# Transfer gold
	var player_gold = get_player_gold(player)
	shop_data.merchant_gold -= price
	set_player_gold(player, player_gold + price)
	
	# Set 100-turn buyback window metadata
	var cur_turn = _get_current_turn()
	item.set_meta("buyback_turn", cur_turn)
	item.set_meta("buyback_price", price)
	
	# Transfer item
	inv.remove_item(item)
	shop_data.stock_items.append(item)
	
	# Train Bartering skill
	_train_bartering_xp(player, price)
	
	var bus = _get_event_bus()
	if bus:
		bus.emit_signal("item_sold", item, price)
		
	return {
		"success": true,
		"price": price,
		"item": item,
		"new_gold": get_player_gold(player)
	}

## Player purchases spell grimoire / scroll from Merchant
func buy_spell(player: Node2D, spell: SpellData) -> Dictionary:
	if not is_peaceful:
		return {"success": false, "reason": "Merchant is hostile!"}
	if not shop_data or not spell:
		return {"success": false, "reason": "Invalid spell or shop"}
		
	var spell_idx = shop_data.stock_spells.find(spell)
	if spell_idx == -1:
		return {"success": false, "reason": "Spell not in merchant stock"}
		
	var player_cha = _get_player_cha(player)
	var bartering_lvl = _get_player_bartering(player)
	var price = shop_data.get_spell_buy_price(spell, player_cha, bartering_lvl)
	var player_gold = get_player_gold(player)
	
	if player_gold < price:
		return {"success": false, "reason": "Insufficient gold (costs %d, have %d)" % [price, player_gold]}
		
	var caster = player.get_node_or_null("SpellCastingComponent") as SpellCastingComponent
	if not caster:
		for child in player.get_children():
			if child is SpellCastingComponent:
				caster = child
				break
				
	if not caster:
		return {"success": false, "reason": "Player has no spellcasting component"}
		
	# Transfer gold
	set_player_gold(player, player_gold - price)
	shop_data.merchant_gold += price
	
	# Learn spell & remove from stock
	shop_data.stock_spells.remove_at(spell_idx)
	caster.learn_spell(spell)
	
	# Train Bartering skill
	_train_bartering_xp(player, price)
	
	return {
		"success": true,
		"price": price,
		"spell": spell,
		"remaining_gold": get_player_gold(player)
	}

## Refills equipped ammunition from stock
func refill_equipped_ammo(player: Node2D) -> Dictionary:
	if not is_peaceful:
		return {"success": false, "reason": "Merchant is hostile!"}
	var inv = _get_player_inventory(player)
	if not inv:
		return {"success": false, "reason": "No player inventory"}
		
	var equipped_ammo = inv.get_equipped_ammo()
	var equipped_weapon = inv.get_equipped_weapon()
	
	var target_ammo_item: ItemData = null
	for it in shop_data.stock_items:
		if it.item_type == ItemData.ItemType.AMMO:
			if equipped_ammo and (it.item_id == equipped_ammo.item_id or it.weapon_type == equipped_ammo.weapon_type):
				target_ammo_item = it
				break
			elif equipped_weapon and equipped_weapon.requires_ammo and it.weapon_type == equipped_weapon.weapon_type:
				target_ammo_item = it
				break
				
	if not target_ammo_item:
		# Fallback: look for any ammo item
		for it in shop_data.stock_items:
			if it.item_type == ItemData.ItemType.AMMO:
				target_ammo_item = it
				break
				
	if not target_ammo_item:
		return {"success": false, "reason": "No compatible ammunition in merchant stock!"}
		
	return buy_item(player, target_ammo_item)

func open_shop(player: Node2D) -> void:
	if not is_peaceful:
		return
	var bus = _get_event_bus()
	if bus:
		bus.emit_signal("shop_opened", self, shop_data)

func close_shop() -> void:
	var bus = _get_event_bus()
	if bus:
		bus.emit_signal("shop_closed")

func get_attack_confirmation_prompt() -> String:
	return "Are you sure you want to attack %s? All merchants will become deadly enemies for the rest of this run!" % get_merchant_name()

## Converts this merchant into a deadly Boss-Tier Hostile NPC
func become_hostile(attacker: Node2D = null, floor_num: int = 1) -> void:
	is_peaceful = false
	is_boss = true
	current_floor_num = floor_num
	
	var gm = _get_game_mgr()
	if gm:
		gm.merchants_hostile_this_run = true
		
	_ensure_components()
	
	# Boss-tier HP: 180 + floor * 25
	var boss_hp = 180.0 + float(floor_num) * 25.0
	if stats:
		if not stats.attributes:
			stats.attributes = AttributesData.new()
		stats.attributes.constitution = 20 + floor_num * 2
		stats.attributes.strength = 18 + floor_num * 2
		stats.attributes.dexterity = 16 + floor_num
		stats.max_hp_override = boss_hp
		stats.current_hp = boss_hp
		
	var boss_blade = ItemData.new("boss_merchant_blade", "Enraged Merchant Blade", ItemData.ItemType.WEAPON, ItemData.EquipSlot.MAIN_HAND, 3.0)
	boss_blade.base_damage_min = 12 + floor_num * 2
	boss_blade.base_damage_max = 24 + floor_num * 3
	if inventory:
		inventory.equip_item(boss_blade)
		
	# Visual indication: Crimson tint
	var sprite = get_node_or_null("VisualSprite") as CanvasItem
	if sprite:
		sprite.modulate = Color(1.0, 0.25, 0.25)
		
	if turn_manager:
		turn_manager.register_enemy(self)
		
	close_shop()

## Hostile AI execution on enemy turn
func take_turn() -> void:
	if is_peaceful or not grid or not turn_manager:
		return
		
	var player = turn_manager.player
	if not player or not is_instance_valid(player):
		return
		
	var p_pos = player.grid_pos
	var dist = abs(grid_pos.x - p_pos.x) + abs(grid_pos.y - p_pos.y)
	
	if dist == 1:
		# Adjacent: Attack!
		_execute_melee_attack(player)
	else:
		# Step toward player
		var path = grid.find_path(grid_pos, p_pos)
		if path.size() >= 2:
			var next_cell = path[1]
			if grid.can_enter(next_cell):
				var dir = next_cell - grid_pos
				try_move(dir)

func _execute_melee_attack(target: Node2D) -> void:
	if not combat or not target:
		return
	var dir = target.grid_pos - grid_pos
	set_facing_direction(dir)
	_play_bump_animation(dir)
	var weapon = inventory.get_equipped_weapon() if inventory else null
	var result = combat.execute_attack(target, weapon)
	var bus = _get_event_bus()
	if bus:
		var msg = "%s viciously strikes Player for %d damage!" % [get_merchant_name(), result["damage"]] if result["hit"] else "%s strikes at Player, but misses!" % get_merchant_name()
		bus.emit_signal("player_acted", "enemy_attack", {"message": msg, "result": result})

## Drops all merchant wares and gold on death
func drop_inventory_loot() -> void:
	if not shop_data or not grid:
		return
		
	var parent_world = get_parent()
	if parent_world and "world_items" in parent_world:
		# Drop wares
		if not shop_data.stock_items.is_empty():
			var dropped_items = shop_data.stock_items.duplicate()
			if parent_world.has_method("_spawn_floor_item"):
				parent_world._spawn_floor_item(grid_pos, dropped_items)
				
		# Drop merchant gold as pouch
		if shop_data.merchant_gold > 0:
			var gold_pouch = ItemData.new("gold_pouch", "Merchant's Vault Pouch (%d Gold)" % shop_data.merchant_gold, ItemData.ItemType.VALUABLE, ItemData.EquipSlot.NONE, 1.0)
			gold_pouch.base_value_gold = shop_data.merchant_gold
			if parent_world.has_method("_spawn_floor_item"):
				parent_world._spawn_floor_item(grid_pos, [gold_pouch])

func get_inspection_data(_viewer: Node2D = null) -> InspectionData:
	var data = InspectionData.new()
	var m_name = get_merchant_name()
	data.title = m_name
	
	if is_peaceful:
		data.category = InspectionData.Category.ALLY_OR_NPC
		data.category_text = "Peaceful Merchant"
		data.icon_glyph = "$"
		data.accent_color = Color(1.0, 0.85, 0.2)
		data.health_status_text = "Uninjured"
		data.health_status_color = Color(0.20, 0.90, 0.40)
		var stock_count = shop_data.stock_items.size() + shop_data.stock_spells.size() if shop_data else 0
		var gold_val = shop_data.merchant_gold if shop_data else 0
		data.description = "Offers wares & trade • Stock: %d wares • Coffers: %d GP" % [stock_count, gold_val]
	else:
		data.category = InspectionData.Category.HOSTILE
		data.category_text = "Boss-Tier Hostile Merchant"
		data.icon_glyph = "M"
		data.accent_color = Color(1.0, 0.25, 0.25)
		var cur_hp = stats.current_hp if stats else 100
		var max_hp = stats.attributes.get_max_health() if stats and stats.attributes else 100
		data.health_status_text = "HP: %d/%d" % [int(cur_hp), int(max_hp)]
		data.health_status_color = Color(0.95, 0.2, 0.2)
		data.description = "Infuriated merchant fighting with deadly precision and vengeance!"
		
	data.grid_cell = grid_pos
	return data
