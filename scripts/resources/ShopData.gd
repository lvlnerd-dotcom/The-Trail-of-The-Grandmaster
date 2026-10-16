class_name ShopData
extends Resource

## ShopData: Catalog, inventory, and mercantile pricing formulas for dungeon merchants.

@export var merchant_name: String = "Wandering Broker"
@export var merchant_title: String = "Purveyor of Antiquities"
@export_multiline var greeting_dialogue: String = "Gold speaks louder than blades down here, stranger."
@export var portrait_texture: Texture2D

@export_group("Inventory Stock")
@export var stock_items: Array[ItemData] = []
@export var stock_spells: Array[SpellData] = []
@export var merchant_gold: int = 500

@export_group("Base Price Factors")
@export var base_buy_markup: float = 1.50   ## 150% base item value at 10 CHA
@export var base_sell_markdown: float = 0.40 ## 40% base item value at 10 CHA

## Mercantile buying formula:
## mercantile_mod = 1.0 + (player_cha - 10) * 0.01
## BuyPrice = max(1, round((BaseItemValue * base_buy_markup) / mercantile_mod))
func calculate_buy_price(item_or_base_val: Variant, attrs_or_cha: Variant) -> int:
	var base_val: float = 0.0
	if item_or_base_val is ItemData:
		base_val = float(item_or_base_val.base_value_gold)
	else:
		base_val = float(item_or_base_val)
		
	var player_cha: int = 10
	if attrs_or_cha is AttributesData:
		player_cha = attrs_or_cha.charisma
	elif attrs_or_cha is int:
		player_cha = attrs_or_cha
		
	var mercantile_mod: float = 1.0 + float(player_cha - 10) * 0.01
	return maxi(1, int(round((base_val * base_buy_markup) / mercantile_mod)))

## Mercantile selling formula:
## mercantile_mod = 1.0 + (player_cha - 10) * 0.01
## SellPrice = max(1, round(BaseItemValue * base_sell_markdown * mercantile_mod))
func calculate_sell_price(item_or_base_val: Variant, attrs_or_cha: Variant) -> int:
	var base_val: float = 0.0
	if item_or_base_val is ItemData:
		base_val = float(item_or_base_val.base_value_gold)
	else:
		base_val = float(item_or_base_val)
		
	var player_cha: int = 10
	if attrs_or_cha is AttributesData:
		player_cha = attrs_or_cha.charisma
	elif attrs_or_cha is int:
		player_cha = attrs_or_cha
		
	var mercantile_mod: float = 1.0 + float(player_cha - 10) * 0.01
	return maxi(1, int(round(base_val * base_sell_markdown * mercantile_mod)))

func get_buy_price(item: ItemData, player_cha: int) -> int:
	return calculate_buy_price(item, player_cha)

func get_sell_price(item: ItemData, player_cha: int) -> int:
	return calculate_sell_price(item, player_cha)

## Spell scroll / grimoire purchasing formula
func get_spell_buy_price(spell: SpellData, player_cha: int) -> int:
	if not spell:
		return 1
	var base_val = maxi(20, int(spell.mana_cost * 8.0))
	var mercantile_mod: float = 1.0 + float(player_cha - 10) * 0.01
	return maxi(1, int(round((float(base_val) * base_buy_markup) / mercantile_mod)))

static func create_default_shop() -> ShopData:
	var shop = ShopData.new()
	shop.merchant_name = "Grimnir the Trader"
	shop.merchant_title = "Underground Quartermaster"
	shop.merchant_gold = 600
	
	var iron_sword = ItemData.new("iron_sword", "Iron Broadsword", ItemData.ItemType.WEAPON, ItemData.EquipSlot.MAIN_HAND, 4.0)
	iron_sword.base_value_gold = 100
	iron_sword.base_damage_min = 6
	iron_sword.base_damage_max = 12
	shop.stock_items.append(iron_sword)
	
	var heater_shield = ItemData.new("heater_shield", "Heater Shield", ItemData.ItemType.SHIELD, ItemData.EquipSlot.OFF_HAND, 5.0)
	heater_shield.base_value_gold = 80
	heater_shield.armor_value = 4
	heater_shield.block_chance_bonus = 0.15
	shop.stock_items.append(heater_shield)
	
	var health_pot = ItemData.new("potion_health", "Health Elixir", ItemData.ItemType.CONSUMABLE, ItemData.EquipSlot.NONE, 0.5)
	health_pot.base_value_gold = 40
	shop.stock_items.append(health_pot)
	
	var mana_pot = ItemData.new("potion_mana", "Mana Draught", ItemData.ItemType.CONSUMABLE, ItemData.EquipSlot.NONE, 0.5)
	mana_pot.base_value_gold = 50
	shop.stock_items.append(mana_pot)
	
	shop.stock_spells.append(SpellData.create_magic_missile())
	shop.stock_spells.append(SpellData.create_minor_heal())
	
	return shop
