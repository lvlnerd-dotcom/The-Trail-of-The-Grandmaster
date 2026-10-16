class_name Merchant
extends BaseEntity

## Merchant: Peaceful NPC entity in dungeon safe rooms offering trade.

@export var shop_data: ShopData
@export var is_peaceful: bool = true

func _ready() -> void:
	super._ready()
	if not shop_data:
		shop_data = ShopData.create_default_shop()

func setup(p_shop_data: ShopData = null, p_grid: DungeonGrid = null, p_pos: Vector2i = Vector2i.ZERO, p_turn_manager: TurnManager = null) -> void:
	if p_shop_data:
		shop_data = p_shop_data
	elif not shop_data:
		shop_data = ShopData.create_default_shop()
		
	if p_grid:
		init_grid_position(p_grid, p_pos, p_turn_manager)

func _get_player_cha(player: Node2D) -> int:
	if not player:
		return 10
	var stats = player.get_node_or_null("StatsComponent") as StatsComponent
	if not stats:
		for child in player.get_children():
			if child is StatsComponent:
				stats = child
				break
	if stats and stats.attributes:
		return stats.attributes.charisma
	return 10

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

## Player purchases item from Merchant
func buy_item(player: Node2D, item: ItemData) -> Dictionary:
	if not shop_data or not item:
		return {"success": false, "reason": "Invalid item or shop"}
		
	var item_idx = shop_data.stock_items.find(item)
	if item_idx == -1:
		return {"success": false, "reason": "Item not in merchant stock"}
		
	var player_cha = _get_player_cha(player)
	var price = shop_data.get_buy_price(item, player_cha)
	var player_gold = get_player_gold(player)
	
	if player_gold < price:
		return {"success": false, "reason": "Insufficient gold (costs %d, have %d)" % [price, player_gold]}
		
	var inv = _get_player_inventory(player)
	if not inv:
		return {"success": false, "reason": "Player has no inventory"}
		
	# Check overburden warning
	var will_overburden = false
	var stats = player.get_node_or_null("StatsComponent") as StatsComponent
	if stats and stats.attributes:
		var max_weight = stats.attributes.get_max_carry_weight_stones()
		will_overburden = inv.get_carried_weight_stones() + item.weight_stones > max_weight
		
	# Transfer gold
	set_player_gold(player, player_gold - price)
	shop_data.merchant_gold += price
	
	# Transfer item
	shop_data.stock_items.remove_at(item_idx)
	inv.add_item(item)
	
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
	if not shop_data or not item:
		return {"success": false, "reason": "Invalid item or shop"}
		
	var inv = _get_player_inventory(player)
	if not inv or not inv.items.has(item):
		return {"success": false, "reason": "Item not in player inventory"}
		
	var player_cha = _get_player_cha(player)
	var price = shop_data.get_sell_price(item, player_cha)
	
	if shop_data.merchant_gold < price:
		return {"success": false, "reason": "Merchant does not have enough gold"}
		
	# Transfer gold
	var player_gold = get_player_gold(player)
	shop_data.merchant_gold -= price
	set_player_gold(player, player_gold + price)
	
	# Transfer item
	inv.remove_item(item)
	shop_data.stock_items.append(item)
	
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
	if not shop_data or not spell:
		return {"success": false, "reason": "Invalid spell or shop"}
		
	var spell_idx = shop_data.stock_spells.find(spell)
	if spell_idx == -1:
		return {"success": false, "reason": "Spell not in merchant stock"}
		
	var player_cha = _get_player_cha(player)
	var price = shop_data.get_spell_buy_price(spell, player_cha)
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
	
	return {
		"success": true,
		"price": price,
		"spell": spell,
		"remaining_gold": get_player_gold(player)
	}

func open_shop(player: Node2D) -> void:
	var bus = _get_event_bus()
	if bus:
		bus.emit_signal("shop_opened", self, shop_data)

func close_shop() -> void:
	var bus = _get_event_bus()
	if bus:
		bus.emit_signal("shop_closed")
