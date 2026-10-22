class_name ShopData
extends Resource

## ShopData: Catalog, inventory, and mercantile pricing formulas for dungeon merchants.
## Incorporates depth-tier stock generation, ammunition stacks, 100-turn buyback, and Charisma + Bartering formulas.

const WeaponManifest = preload("res://scripts/resources/WeaponManifest.gd")

@export var merchant_id: String = ""
@export var merchant_name: String = "Wandering Broker"
@export var merchant_title: String = "Purveyor of Antiquities"
@export_multiline var greeting_dialogue: String = "Gold speaks louder than blades down here, stranger."
@export var portrait_texture: Texture2D
@export var specialty: int = 0
@export var depth_tier: int = 1
@export var attitude: int = 0

@export_group("Inventory Stock")
@export var stock_items: Array[ItemData] = []
@export var stock_spells: Array[SpellData] = []
@export var merchant_gold: int = 500

@export_group("Base Price Factors")
@export var base_buy_markup: float = 1.50   ## 150% base item value at 10 CHA
@export var base_sell_markdown: float = 0.40 ## 40% base item value at 10 CHA

## Mercantile modifier formula:
## MercantileMod = 1.0 + (CHA - 10) * 0.01 + (EffectiveBartering * 0.005)
static func calculate_mercantile_modifier(player_cha: int, bartering_level: float = 0.0) -> float:
	return 1.0 + float(player_cha - 10) * 0.01 + (bartering_level * 0.005)

## Volume and value-weighted task difficulty for Bartering skill training
static func calculate_bartering_task_difficulty(transaction_gold: int) -> float:
	return clampf(5.0 + float(transaction_gold) / 8.0, 5.0, 100.0)

static func calculate_bartering_volume_multiplier(transaction_gold: int) -> float:
	return clampf(float(transaction_gold) / 25.0, 0.20, 3.0)

## Mercantile buying formula:
## BuyPrice = max(1, round((BaseItemValue * 1.50) / MercantileMod))
## If sold within the last 100 turns, exact buyback price is honoured.
func calculate_buy_price(item_or_base_val: Variant, attrs_or_cha: Variant, bartering_level: float = 0.0, current_turn: int = -1) -> int:
	var base_val: float = 0.0
	var is_buyback: bool = false
	var buyback_price: int = 0
	
	if item_or_base_val is ItemData:
		base_val = float(item_or_base_val.base_value_gold)
		if current_turn >= 0 and item_or_base_val.has_meta("buyback_turn") and item_or_base_val.has_meta("buyback_price"):
			var sold_turn = int(item_or_base_val.get_meta("buyback_turn"))
			if current_turn - sold_turn <= 100:
				is_buyback = true
				buyback_price = int(item_or_base_val.get_meta("buyback_price"))
	else:
		base_val = float(item_or_base_val)
		
	if is_buyback:
		return buyback_price
		
	var player_cha: int = 10
	var eff_barter: float = bartering_level
	if attrs_or_cha is AttributesData:
		player_cha = attrs_or_cha.charisma
	elif attrs_or_cha is int:
		player_cha = attrs_or_cha
	elif attrs_or_cha != null and attrs_or_cha is Node:
		var node = attrs_or_cha as Node
		var stats = node.get_node_or_null("StatsComponent") as StatsComponent
		if stats and stats.attributes:
			player_cha = stats.attributes.charisma
		var skills = node.get_node_or_null("SkillComponent") as SkillComponent
		if skills:
			var s = skills.get_skill(SkillData.SkillId.BARTERING)
			if s:
				eff_barter = s.level
		
	var mercantile_mod: float = calculate_mercantile_modifier(player_cha, eff_barter)
	return maxi(1, int(round((base_val * base_buy_markup) / mercantile_mod)))

## Mercantile selling formula:
## SellPrice = max(1, round(BaseItemValue * 0.40 * MercantileMod))
func calculate_sell_price(item_or_base_val: Variant, attrs_or_cha: Variant, bartering_level: float = 0.0) -> int:
	var base_val: float = 0.0
	if item_or_base_val is ItemData:
		base_val = float(item_or_base_val.base_value_gold)
	else:
		base_val = float(item_or_base_val)
		
	var player_cha: int = 10
	var eff_barter: float = bartering_level
	if attrs_or_cha is AttributesData:
		player_cha = attrs_or_cha.charisma
	elif attrs_or_cha is int:
		player_cha = attrs_or_cha
	elif attrs_or_cha != null and attrs_or_cha is Node:
		var node = attrs_or_cha as Node
		var stats = node.get_node_or_null("StatsComponent") as StatsComponent
		if stats and stats.attributes:
			player_cha = stats.attributes.charisma
		var skills = node.get_node_or_null("SkillComponent") as SkillComponent
		if skills:
			var s = skills.get_skill(SkillData.SkillId.BARTERING)
			if s:
				eff_barter = s.level
		
	var mercantile_mod: float = calculate_mercantile_modifier(player_cha, eff_barter)
	return maxi(1, int(round(base_val * base_sell_markdown * mercantile_mod)))

func get_buy_price(item: ItemData, player_or_cha: Variant = 10, bartering_level: float = 0.0, current_turn: int = -1) -> int:
	return calculate_buy_price(item, player_or_cha, bartering_level, current_turn)

func get_sell_price(item: ItemData, player_or_cha: Variant = 10, bartering_level: float = 0.0) -> int:
	return calculate_sell_price(item, player_or_cha, bartering_level)

## Spell scroll / grimoire purchasing formula
func get_spell_buy_price(spell: SpellData, player_or_cha: Variant = 10, bartering_level: float = 0.0) -> int:
	if not spell:
		return 1
	var base_val = maxi(20, int(spell.mana_cost * 8.0))
	var player_cha: int = 10
	var eff_barter: float = bartering_level
	if player_or_cha is AttributesData:
		player_cha = player_or_cha.charisma
	elif player_or_cha is int:
		player_cha = player_or_cha
	elif player_or_cha != null and player_or_cha is Node:
		var node = player_or_cha as Node
		var stats = node.get_node_or_null("StatsComponent") as StatsComponent
		if stats and stats.attributes:
			player_cha = stats.attributes.charisma
		var skills = node.get_node_or_null("SkillComponent") as SkillComponent
		if skills and stats and stats.attributes:
			eff_barter = skills.get_effective_level(SkillData.SkillId.BARTERING, stats.attributes)
			
	var mercantile_mod: float = calculate_mercantile_modifier(player_cha, eff_barter)
	return maxi(1, int(round((float(base_val) * base_buy_markup) / mercantile_mod)))

## Creates the default shop
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

## Generates specialized stock for one of the 5 specialties and depth tiers (Tier 1..5)
static func generate_stock_for_specialty(p_specialty: int, p_tier: int, merchant_info: Dictionary = {}) -> ShopData:
	var shop = ShopData.new()
	shop.depth_tier = clampi(p_tier, 1, 5)
	shop.specialty = p_specialty
	
	if not merchant_info.is_empty():
		shop.merchant_id = merchant_info.get("merchant_id", "")
		shop.merchant_name = merchant_info.get("display_name", "Wandering Merchant")
		shop.merchant_title = merchant_info.get("title", "Purveyor of Goods")
		var pool = merchant_info.get("dialogue_pool", []) as Array
		if not pool.is_empty():
			shop.greeting_dialogue = pool[randi() % pool.size()]
		shop.attitude = int(merchant_info.get("attitude", 0))
	
	# Scale merchant gold with depth tier
	var tier_gold_bases = [0, 400, 700, 1100, 1600, 2400]
	shop.merchant_gold = tier_gold_bases[shop.depth_tier] + randi_range(-50, 100)
	
	match p_specialty:
		# 1. POTION_APOTHECARY
		0:
			_populate_apothecary_stock(shop)
		# 2. WEAPON_ARMORY
		1:
			_populate_armory_stock(shop)
		# 3. MAGIC_SCRIBES
		2:
			_populate_scribes_stock(shop)
		# 4. UNIQUE_CURIOS
		3:
			_populate_curios_stock(shop)
		# 5. GENERAL_OUTFITTER
		4:
			_populate_outfitter_stock(shop)
		_:
			_populate_outfitter_stock(shop)
			
	return shop

static func _populate_apothecary_stock(shop: ShopData) -> void:
	var t = shop.depth_tier
	
	# Minor / Standard / Greater Health Elixirs
	var hp_pot = ItemData.new("potion_health", "Health Elixir", ItemData.ItemType.CONSUMABLE, ItemData.EquipSlot.NONE, 0.5, randi_range(2, 4))
	hp_pot.base_value_gold = 35 + t * 15
	hp_pot.is_fragile = true
	hp_pot.description = "Restores %d health upon consumption." % (25 + t * 15)
	shop.stock_items.append(hp_pot)
	
	# Mana Draught
	var mana_pot = ItemData.new("potion_mana", "Mana Draught", ItemData.ItemType.CONSUMABLE, ItemData.EquipSlot.NONE, 0.5, randi_range(2, 3))
	mana_pot.base_value_gold = 40 + t * 15
	mana_pot.is_fragile = true
	mana_pot.description = "Restores %d mana upon consumption." % (20 + t * 12)
	shop.stock_items.append(mana_pot)
	
	# Antidote Flask
	var antidote = ItemData.new("antidote_flask", "Alchemical Antidote", ItemData.ItemType.CONSUMABLE, ItemData.EquipSlot.NONE, 0.4, randi_range(1, 3))
	antidote.base_value_gold = 30 + t * 10
	antidote.description = "Neutralizes all tiers of poison and venom."
	shop.stock_items.append(antidote)
	
	# Field Bandages / Trauma Kit
	var bandage = ItemData.new("trauma_kit", "Field Trauma Kit", ItemData.ItemType.CONSUMABLE, ItemData.EquipSlot.NONE, 0.8, randi_range(1, 2))
	bandage.base_value_gold = 45 + t * 10
	bandage.description = "Stanches bleeding and treats physical wounds."
	shop.stock_items.append(bandage)
	
	# Mortar and Pestle (Portable Crafting Tool)
	var mortar = ItemData.new("mortar_and_pestle", "Basalt Mortar & Pestle", ItemData.ItemType.VALUABLE, ItemData.EquipSlot.NONE, 2.0, 1)
	mortar.base_value_gold = 60 + t * 20
	mortar.description = "Precision basalt mortar and pestle for brewing potions anywhere in the dungeon."
	shop.stock_items.append(mortar)
	
	# Dungeon Alchemy Reagents
	var reagents = [
		{"id": "reagent_sunpetal", "name": "Golden Sunpetal", "val": 15},
		{"id": "reagent_nightshade", "name": "Venomous Nightshade", "val": 20},
		{"id": "reagent_bloodmoss", "name": "Crimson Bloodmoss", "val": 25},
		{"id": "reagent_crystalline_ash", "name": "Crystalline Ash", "val": 30},
		{"id": "reagent_venom_gland", "name": "Spider Venom Gland", "val": 35}
	]
	for r in reagents:
		var r_item = ItemData.new(r["id"], r["name"], ItemData.ItemType.VALUABLE, ItemData.EquipSlot.NONE, 0.2, randi_range(2, 5))
		r_item.base_value_gold = r["val"] + t * 5
		r_item.description = "Alchemical reagent for brewing elixirs."
		shop.stock_items.append(r_item)

static func _populate_armory_stock(shop: ShopData) -> void:
	var t = shop.depth_tier
	
	# Weapons from WeaponManifest
	var weapon_pool = ["sword_broad", "sword_short", "club_war", "dagger_stiletto", "axe_battle", "bow_hunting", "spear_hunting"]
	if t >= 2:
		weapon_pool.append_array(["sword_scimitar", "mace_morningstar", "crossbow_light", "rapier_dueling", "polearm_halberd"])
	if t >= 3:
		weapon_pool.append_array(["sword_claymore", "flail_heavy", "bow_long", "hammer_war"])
	if t >= 4:
		weapon_pool.append_array(["greatsword_zweihander", "crossbow_heavy", "war_scythe"])
		
	weapon_pool.shuffle()
	var pick_count = mini(randi_range(3, 5), weapon_pool.size())
	for i in range(pick_count):
		var w_id = weapon_pool[i]
		var w_item = WeaponManifest.create_weapon(w_id)
		if w_item:
			w_item.base_value_gold = int(w_item.base_value_gold * (1.0 + float(t - 1) * 0.25))
			shop.stock_items.append(w_item)
			
	# Shields
	var shield_type = "heater_shield" if t <= 2 else "tower_shield"
	var shield_name = "Reinforced Heater Shield" if t <= 2 else "Tower Fortress Shield"
	var shield = ItemData.new(shield_type, shield_name, ItemData.ItemType.SHIELD, ItemData.EquipSlot.OFF_HAND, 4.0 + t * 0.5)
	shield.armor_value = 3 + t * 2
	shield.block_chance_bonus = 0.15 + float(t) * 0.03
	shield.base_value_gold = 60 + t * 30
	shield.description = "Heavy defensive bulwark against melee and missile strikes."
	shop.stock_items.append(shield)
	
	# Armor
	var armor_names = ["", "Reinforced Leather Cuirass", "Riveted Chainmail", "Banded Splint Armor", "Tempered Half-Plate", "Dwarven Full Plate"]
	var armor_body = ItemData.new("armor_body_t%d" % t, armor_names[t], ItemData.ItemType.ARMOR, ItemData.EquipSlot.BODY, 6.0 + t * 3.0)
	armor_body.armor_value = 4 + t * 3
	armor_body.base_value_gold = 80 + t * 60
	armor_body.description = "Sturdy protective body armor crafted to withstand mortal blows."
	shop.stock_items.append(armor_body)
	
	# Helmets / Greaves
	var helm = ItemData.new("armor_head_t%d" % t, "Steel Armet Helmet", ItemData.ItemType.ARMOR, ItemData.EquipSlot.HEAD, 2.0 + t * 0.5)
	helm.armor_value = 2 + t
	helm.base_value_gold = 40 + t * 20
	helm.description = "Protects the skull from crushing strikes."
	shop.stock_items.append(helm)

static func _populate_scribes_stock(shop: ShopData) -> void:
	var t = shop.depth_tier
	
	# Spells
	var spell_pool = [SpellData.create_magic_missile(), SpellData.create_minor_heal()]
	if t >= 2:
		spell_pool.append(SpellData.create_blink())
		spell_pool.append(SpellData.create_arcane_shield())
	if t >= 3:
		spell_pool.append(SpellData.create_smite())
		spell_pool.append(SpellData.create_purify())
	if t >= 4:
		spell_pool.append(SpellData.create_divine_aegis())
		
	for sp in spell_pool:
		shop.stock_spells.append(sp)
		
	# Scrolls of Identification
	var id_scroll = ItemData.new("scroll_identify", "Scroll of Identification", ItemData.ItemType.CONSUMABLE, ItemData.EquipSlot.NONE, 0.3, randi_range(2, 4))
	id_scroll.base_value_gold = 35 + t * 10
	id_scroll.description = "Reveals the true mystical properties of any unidentified weapon, armor, or potion."
	shop.stock_items.append(id_scroll)
	
	# Arcane Focus / Wand
	var wand = ItemData.new("arcane_wand", "Carved Crystal Wand", ItemData.ItemType.WEAPON, ItemData.EquipSlot.MAIN_HAND, 1.5)
	wand.base_value_gold = 75 + t * 35
	wand.description = "Channeling focus granting +%d%% spell potency and reduced mana cost." % (10 + t * 5)
	shop.stock_items.append(wand)

static func _populate_curios_stock(shop: ShopData) -> void:
	var t = shop.depth_tier
	
	# Thieves' Tools
	var tools = ItemData.new("thieves_tools", "Masterwork Thieves' Tools", ItemData.ItemType.VALUABLE, ItemData.EquipSlot.NONE, 1.0, randi_range(2, 3))
	tools.base_value_gold = 50 + t * 15
	tools.description = "Delicate tension wrenches and lockpicks used to disarm traps and pick coffer locks."
	shop.stock_items.append(tools)
	
	# Magic Rings
	var rings = [
		{"id": "ring_protection", "name": "Ring of Ironward", "bonus": {"armor": 2 + t}, "val": 80},
		{"id": "ring_might", "name": "Band of Ogre Might", "bonus": {"strength": 2 + t}, "val": 90},
		{"id": "ring_haste", "name": "Signet of Quickness", "bonus": {"dexterity": 2 + t}, "val": 90},
		{"id": "ring_vitality", "name": "Garnet Life-Ring", "bonus": {"max_hp": 15 + t * 10}, "val": 85}
	]
	rings.shuffle()
	for i in range(mini(2, rings.size())):
		var r = rings[i]
		var ring_item = ItemData.new(r["id"], r["name"], ItemData.ItemType.RELIC, ItemData.EquipSlot.RING_1, 0.1)
		ring_item.base_value_gold = r["val"] + t * 25
		ring_item.attribute_bonuses = r["bonus"]
		ring_item.description = "Enchanted ring radiating subtle magical protection."
		shop.stock_items.append(ring_item)
		
	# Rare Relic / Artifact
	var relic = ItemData.new("relic_fortune", "Coin of Lady Tyche", ItemData.ItemType.RELIC, ItemData.EquipSlot.ACCESSORY, 0.5)
	relic.base_value_gold = 120 + t * 40
	relic.dodge_bonus = 0.05 + float(t) * 0.02
	relic.description = "Golden coin that wards off ill fortune and sharpens reflexes."
	shop.stock_items.append(relic)

static func _populate_outfitter_stock(shop: ShopData) -> void:
	var t = shop.depth_tier
	
	# Ammunition Stacks
	var arrows = ItemData.new("ammo_arrows", "Bundle of Broadhead Arrows (25)", ItemData.ItemType.AMMO, ItemData.EquipSlot.AMMUNITION, 1.5, 25)
	arrows.weapon_type = AttributesData.WeaponType.BOW
	arrows.associated_skill_id = SkillData.SkillId.ARCHERY
	arrows.base_damage_min = 2 + t
	arrows.base_damage_max = 5 + t * 2
	arrows.range_tiles = 8
	arrows.base_value_gold = 25 + t * 5
	arrows.description = "Steel-tipped arrows suited for standard and composite bows."
	shop.stock_items.append(arrows)
	
	var bolts = ItemData.new("ammo_bolts", "Case of Crossbow Quarrels (20)", ItemData.ItemType.AMMO, ItemData.EquipSlot.AMMUNITION, 1.5, 20)
	bolts.weapon_type = AttributesData.WeaponType.BOW
	bolts.associated_skill_id = SkillData.SkillId.ARCHERY
	bolts.base_damage_min = 3 + t
	bolts.base_damage_max = 7 + t * 2
	bolts.range_tiles = 7
	bolts.armor_penetration = 0.20
	bolts.base_value_gold = 25 + t * 5
	bolts.description = "Heavy crossbow bolts engineered to punch through hardened armor."
	shop.stock_items.append(bolts)
	
	var knives = ItemData.new("ammo_throwing_knives", "Set of Balanced Throwing Knives (10)", ItemData.ItemType.AMMO, ItemData.EquipSlot.AMMUNITION, 1.0, 10)
	knives.weapon_type = AttributesData.WeaponType.THROWN
	knives.associated_skill_id = SkillData.SkillId.THROWING
	knives.base_damage_min = 3 + t
	knives.base_damage_max = 6 + t * 2
	knives.range_tiles = 4
	knives.crit_chance_bonus = 0.10
	knives.base_value_gold = 30 + t * 5
	knives.description = "Balanced daggers weighted specifically for ranged throwing."
	shop.stock_items.append(knives)
	
	var axes = ItemData.new("ammo_throwing_axes", "Bundle of Francisca Throwing Axes (5)", ItemData.ItemType.AMMO, ItemData.EquipSlot.AMMUNITION, 2.5, 5)
	axes.weapon_type = AttributesData.WeaponType.THROWN
	axes.associated_skill_id = SkillData.SkillId.THROWING
	axes.base_damage_min = 6 + t * 2
	axes.base_damage_max = 12 + t * 2
	axes.range_tiles = 3
	axes.base_value_gold = 35 + t * 5
	axes.description = "Heavy throwing axes capable of breaking shields and splintering armor."
	shop.stock_items.append(axes)
	
	# Basic Consumables & Utility
	var rations = ItemData.new("iron_rations", "Pack of Hardtack Rations", ItemData.ItemType.CONSUMABLE, ItemData.EquipSlot.NONE, 1.0, randi_range(2, 4))
	rations.base_value_gold = 15
	rations.description = "Durable sustenance that sustains health recovery in deep descents."
	shop.stock_items.append(rations)
	
	var sidearm = WeaponManifest.create_weapon("dagger_stiletto")
	if sidearm:
		shop.stock_items.append(sidearm)
