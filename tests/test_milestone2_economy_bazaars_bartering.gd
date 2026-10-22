@tool
extends McpTestSuite

## Milestone 2 Test Suite: Dynamic Economy & Travelling Merchants
## Grand Bazaar Safe Rooms, 25 Merchant Personalities & Dialogue,
## Combined Charisma + Bartering Pricing, 100-Turn Buyback,
## Hostile Boss NPC Conversion, Ammunition Stacks & Wares Drop.

const SkillData = preload("res://scripts/resources/SkillData.gd")
const ItemData = preload("res://scripts/resources/ItemData.gd")
const AttributesData = preload("res://scripts/resources/AttributesData.gd")
const SpellData = preload("res://scripts/resources/SpellData.gd")
const ShopData = preload("res://scripts/resources/ShopData.gd")
const MerchantCatalog = preload("res://scripts/resources/MerchantCatalog.gd")

const StatsComponent = preload("res://scripts/components/StatsComponent.gd")
const SkillComponent = preload("res://scripts/components/SkillComponent.gd")
const InventoryComponent = preload("res://scripts/components/InventoryComponent.gd")
const CombatComponent = preload("res://scripts/components/CombatComponent.gd")

const DungeonGrid = preload("res://scripts/world/DungeonGrid.gd")
const DungeonGenerator = preload("res://scripts/world/DungeonGenerator.gd")
const TurnManager = preload("res://scripts/world/TurnManager.gd")
const Merchant = preload("res://scripts/entities/Merchant.gd")
const WorldItem = preload("res://scripts/world/WorldItem.gd")

func suite_name() -> String:
	return "milestone2_economy_bazaars_bartering"

func _create_test_player(cha: int = 10, bartering_lvl: float = 0.0) -> Node2D:
	var player = track(Node2D.new()) as Node2D
	player.name = "TestPlayer"
	
	var stats = track(StatsComponent.new()) as StatsComponent
	stats.name = "StatsComponent"
	stats.attributes = track(AttributesData.new()) as AttributesData
	stats.attributes.strength = 10
	stats.attributes.dexterity = 10
	stats.attributes.constitution = 10
	stats.attributes.intelligence = 10
	stats.attributes.wisdom = 10
	stats.attributes.charisma = cha
	
	var skills = track(SkillComponent.new()) as SkillComponent
	skills.name = "SkillComponent"
	var barter_skill = skills.get_skill(SkillData.SkillId.BARTERING)
	if not barter_skill:
		barter_skill = skills.register_or_unlock_skill(SkillData.SkillId.BARTERING, bartering_lvl)
	barter_skill.level = bartering_lvl
	
	var inv = track(InventoryComponent.new()) as InventoryComponent
	inv.name = "InventoryComponent"
	inv.gold = 1000
	
	var combat = track(CombatComponent.new()) as CombatComponent
	combat.name = "CombatComponent"
	
	player.add_child(stats)
	player.add_child(skills)
	player.add_child(inv)
	player.add_child(combat)
	return player

# -----------------------------------------------------------------------------
# 1. BAZAAR SAFE ROOM GENERATION & WANDERING MERCHANTS
# -----------------------------------------------------------------------------
func test_bazaar_safe_room_generation_floors() -> void:
	var generator = DungeonGenerator.new(80, 60)
	var grid = track(DungeonGrid.new()) as DungeonGrid
	grid.grid_width = 80
	grid.grid_height = 60
	
	# Test Floors 4, 8, 12, 16 generate Grand Bazaar Sanctuary Rooms with 3-4 stalls
	var bazaar_floors = [4, 8, 12, 16]
	for floor_num in bazaar_floors:
		var result = generator.generate_dungeon(grid, floor_num, 4200 + floor_num)
		var spawns: Array = result.get("merchant_spawns", [])
		assert_true(spawns.size() >= 3 and spawns.size() <= 4, "Floor %d Bazaar must spawn 3 to 4 stalls (got %d)" % [floor_num, spawns.size()])
		
		# Verify stalls have distinct specialist categories
		var distinct_categories: Dictionary = {}
		for s in spawns:
			var spec = int(s.get("specialty", -1))
			assert_true(spec >= 0 and spec <= 4, "Stall specialty must be in 0..4 range")
			distinct_categories[spec] = true
		assert_eq(distinct_categories.size(), spawns.size(), "Floor %d Bazaar stalls must all have distinct specialties" % floor_num)
		
		# Verify bazaar safe room has no enemy spawns or traps
		var bazaar_room: DungeonGenerator.Room = null
		for r in result["rooms"]:
			if r.is_bazaar:
				bazaar_room = r
				break
		assert_true(bazaar_room != null, "Floor %d must have a designated is_bazaar room" % floor_num)
		if bazaar_room:
			var br = bazaar_room.rect
			for e_cell in result["enemy_spawns"]:
				var inside = br.has_point(e_cell)
				assert_false(inside, "Bazaar safe room must have 0 enemy spawns!")
			for t_data in result["traps"]:
				var t_cell = t_data["cell"]
				var inside = br.has_point(t_cell)
				assert_false(inside, "Bazaar safe room must have 0 traps!")

func test_wandering_merchant_rate_on_non_bazaar_floors() -> void:
	var generator = DungeonGenerator.new(80, 60)
	var grid = track(DungeonGrid.new()) as DungeonGrid
	grid.grid_width = 80
	grid.grid_height = 60
	
	# Sample 100 non-bazaar floor generations (Floor 1, 2, 3, 5, etc.)
	var spawn_count = 0
	var sample_size = 120
	for seed_idx in range(sample_size):
		var floor_num = 1 + (seed_idx % 3) # Floors 1, 2, 3 (non-bazaar)
		var res = generator.generate_dungeon(grid, floor_num, 10000 + seed_idx)
		var spawns: Array = res.get("merchant_spawns", [])
		if not spawns.is_empty():
			assert_eq(spawns.size(), 1, "Wandering merchant spawn must be exactly 1 merchant")
			spawn_count += 1
			
	var empirical_rate = float(spawn_count) / float(sample_size)
	# 10% target rate should fall comfortably between 3% and 25% over 120 iterations
	assert_true(empirical_rate >= 0.03 and empirical_rate <= 0.25, "Wandering merchant rate must hover around 10 percent (empirical: " + str(snappedf(empirical_rate * 100.0, 0.1)) + " percent)")

# -----------------------------------------------------------------------------
# 2. 25 MERCHANT PERSONALITIES & DIALOGUE CATALOG
# -----------------------------------------------------------------------------
func test_merchant_catalog_completeness() -> void:
	var cat = MerchantCatalog.get_catalog()
	assert_eq(cat.size(), 25, "MerchantCatalog must define exactly 25 persistent merchant personalities")
	
	var specialties = [
		MerchantCatalog.Specialty.POTION_APOTHECARY,
		MerchantCatalog.Specialty.WEAPON_ARMORY,
		MerchantCatalog.Specialty.MAGIC_SCRIBES,
		MerchantCatalog.Specialty.UNIQUE_CURIOS,
		MerchantCatalog.Specialty.GENERAL_OUTFITTER
	]
	
	for spec in specialties:
		var merchants = MerchantCatalog.get_merchants_by_specialty(spec)
		assert_eq(merchants.size(), 5, "Specialty %d must have exactly 5 merchants" % spec)
		
		for m in merchants:
			assert_true(m.has("merchant_id") and m["merchant_id"] != "", "Merchant must have merchant_id")
			assert_true(m.has("display_name") and m["display_name"] != "", "Merchant must have display_name")
			assert_true(m.has("title") and m["title"] != "", "Merchant must have title")
			assert_true(m.has("dialogue_pool"), "Merchant must have dialogue_pool")
			var pool: Array = m["dialogue_pool"]
			assert_true(pool.size() >= 10, "Merchant '%s' must have at least 10 dialogue lines (has %d)" % [m["display_name"], pool.size()])
			
			# Test random dialogue accessor
			var rand_line = MerchantCatalog.get_random_dialogue(m["merchant_id"])
			assert_true(rand_line != "", "Merchant random dialogue must return non-empty text")
			assert_true(pool.has(rand_line), "Returned line must belong to merchant dialogue pool")

# -----------------------------------------------------------------------------
# 3. CHARISMA + BARTERING PRICING FORMULAS
# -----------------------------------------------------------------------------
func test_charisma_and_bartering_pricing_formulas() -> void:
	var shop = track(ShopData.new()) as ShopData
	var base_val = 100
	
	# Baseline: 10 CHA, 0 Bartering -> Mod = 1.00
	# BuyPrice = round(100 * 1.50 / 1.00) = 150
	# SellPrice = round(100 * 0.40 * 1.00) = 40
	var mod_10_0 = ShopData.calculate_mercantile_modifier(10, 0.0)
	assert_true(is_equal_approx(mod_10_0, 1.00), "10 CHA, 0 Barter -> mod 1.00")
	assert_eq(shop.calculate_buy_price(base_val, 10, 0.0), 150)
	assert_eq(shop.calculate_sell_price(base_val, 10, 0.0), 40)
	
	# 10 CHA, 20 Bartering -> Mod = 1.0 + 0 + 20*0.005 = 1.10
	# BuyPrice = round(150 / 1.10) = 136
	# SellPrice = round(40 * 1.10) = 44
	var mod_10_20 = ShopData.calculate_mercantile_modifier(10, 20.0)
	assert_true(is_equal_approx(mod_10_20, 1.10), "10 CHA, 20 Barter -> mod 1.10")
	assert_eq(shop.calculate_buy_price(base_val, 10, 20.0), 136)
	assert_eq(shop.calculate_sell_price(base_val, 10, 20.0), 44)
	
	# 20 CHA, 20 Bartering -> Mod = 1.0 + 0.10 + 0.10 = 1.20
	# BuyPrice = round(150 / 1.20) = 125
	# SellPrice = round(40 * 1.20) = 48
	var mod_20_20 = ShopData.calculate_mercantile_modifier(20, 20.0)
	assert_true(is_equal_approx(mod_20_20, 1.20), "20 CHA, 20 Barter -> mod 1.20")
	assert_eq(shop.calculate_buy_price(base_val, 20, 20.0), 125)
	assert_eq(shop.calculate_sell_price(base_val, 20, 20.0), 48)
	
	# Minimum 1 gold floor on transactions
	assert_eq(shop.calculate_buy_price(0, 10, 0.0), 1, "0 base buy price must floor at 1 gold")
	assert_eq(shop.calculate_sell_price(0, 10, 0.0), 1, "0 base sell price must floor at 1 gold")

# -----------------------------------------------------------------------------
# 4. 100-TURN EXACT BUYBACK WINDOW
# -----------------------------------------------------------------------------
func test_100_turn_exact_buyback_window() -> void:
	var merchant = track(Merchant.new()) as Merchant
	var shop = track(ShopData.new()) as ShopData
	merchant.shop_data = shop
	
	var player = _create_test_player(10, 0.0)
	var sword = ItemData.new("iron_sword", "Iron Sword", ItemData.ItemType.WEAPON, ItemData.EquipSlot.MAIN_HAND, 3.0)
	sword.base_value_gold = 100
	player.get_node("InventoryComponent").add_item(sword)
	
	# Player sells sword at Turn 50
	# At 10 CHA, sell price is 40 gold
	var turn_mgr = track(TurnManager.new()) as TurnManager
	turn_mgr.turn_number = 50
	merchant.turn_manager = turn_mgr
	
	var sell_res = merchant.sell_item(player, sword)
	assert_true(sell_res["success"], "Item sale must succeed")
	assert_eq(sell_res["price"], 40, "Sold for 40 gold")
	assert_true(sword.has_meta("buyback_turn"), "Sold item must record buyback_turn")
	assert_eq(int(sword.get_meta("buyback_turn")), 50, "buyback_turn must be 50")
	assert_eq(int(sword.get_meta("buyback_price")), 40, "buyback_price must be 40")
	
	# Turn 80 (delta 30 <= 100 turns): Exact buyback price (40 gold)
	turn_mgr.turn_number = 80
	var buyback_p80 = shop.get_buy_price(sword, 10, 0.0, turn_mgr.turn_number)
	assert_eq(buyback_p80, 40, "Within 100 turns: Buyback price must be exact sold price (40 GP)")
	
	# Turn 150 (delta 100 == 100 turns): Still exact buyback price (40 gold)
	turn_mgr.turn_number = 150
	var buyback_p150 = shop.get_buy_price(sword, 10, 0.0, turn_mgr.turn_number)
	assert_eq(buyback_p150, 40, "At exactly 100 turns: Buyback price remains 40 GP")
	
	# Turn 151 (delta 101 > 100 turns): Standard markup applies (150 gold)
	turn_mgr.turn_number = 151
	var standard_p151 = shop.get_buy_price(sword, 10, 0.0, turn_mgr.turn_number)
	assert_eq(standard_p151, 150, "After 100 turns: Standard markup applies (150 GP)")
	
	# Re-purchasing clears buyback metadata
	turn_mgr.turn_number = 80
	var buy_res = merchant.buy_item(player, sword)
	assert_true(buy_res["success"], "Repurchase must succeed")
	assert_false(sword.has_meta("buyback_turn"), "Repurchased item must clear buyback_turn meta")

# -----------------------------------------------------------------------------
# 5. VOLUME & VALUE-WEIGHTED BARTERING XP
# -----------------------------------------------------------------------------
func test_volume_and_value_weighted_bartering_xp() -> void:
	# Task difficulty formula: clamp(5.0 + TransactionGold / 8.0, 5.0, 100.0)
	var diff_small = ShopData.calculate_bartering_task_difficulty(1)
	assert_true(is_equal_approx(diff_small, 5.125), "1 GP transaction -> diff 5.125")
	
	var diff_med = ShopData.calculate_bartering_task_difficulty(40)
	assert_true(is_equal_approx(diff_med, 10.0), "40 GP transaction -> diff 10.0")
	
	var diff_large = ShopData.calculate_bartering_task_difficulty(200)
	assert_true(is_equal_approx(diff_large, 30.0), "200 GP transaction -> diff 30.0")
	
	var diff_huge = ShopData.calculate_bartering_task_difficulty(1000)
	assert_true(is_equal_approx(diff_huge, 100.0), "1000 GP transaction caps at 100.0")
	
	# Verify transaction trains player's Bartering skill
	var player = _create_test_player(10, 5.0)
	var barter_skill = player.get_node("SkillComponent").get_skill(SkillData.SkillId.BARTERING)
	var initial_xp = barter_skill.current_xp
	var initial_lvl = barter_skill.level
	
	var merchant = track(Merchant.new()) as Merchant
	var shop = track(ShopData.new()) as ShopData
	merchant.shop_data = shop
	
	var item = ItemData.new("test_relic", "Gold Urn", ItemData.ItemType.VALUABLE, ItemData.EquipSlot.NONE, 2.0)
	item.base_value_gold = 100
	shop.stock_items.append(item)
	
	var res = merchant.buy_item(player, item)
	assert_true(res["success"], "Item purchase must succeed")
	assert_true(barter_skill.current_xp > initial_xp or barter_skill.level > initial_lvl, "Bartering skill XP or level must increase after transaction")

# -----------------------------------------------------------------------------
# 6. ATTACK CONFIRMATION & HOSTILE BOSS NPC CONVERSION
# -----------------------------------------------------------------------------
func test_merchant_attack_and_boss_conversion() -> void:
	var merchant = track(Merchant.new()) as Merchant
	merchant.display_name = "Master Thorin"
	var shop = track(ShopData.new()) as ShopData
	shop.merchant_name = "Master Thorin"
	merchant.shop_data = shop
	
	# Verify attack confirmation prompt
	var prompt = merchant.get_attack_confirmation_prompt()
	assert_true(prompt.contains("Master Thorin"), "Prompt must include merchant name")
	assert_true(prompt.contains("deadly enemies"), "Prompt must warn of run-wide merchant hostility")
	
	# Execute conversion to hostile boss on Floor 4
	# Boss HP formula: 180 + floor * 25
	# On Floor 4: 180 + 4 * 25 = 280 HP
	merchant.become_hostile(null, 4)
	assert_false(merchant.is_peaceful, "Merchant must no longer be peaceful")
	assert_true(merchant.is_boss, "Merchant must become boss-tier")
	assert_eq(merchant.stats.current_hp, 280.0, "Floor 4 Hostile Merchant HP must be 280.0 (180 + 4*25)")
	var wep = merchant.inventory.get_equipped_weapon() if merchant.inventory else null
	assert_true(wep != null and wep.base_damage_max >= 24, "Hostile Merchant must have high boss-tier damage weapon")
	
	# Trade interactions must be locked out
	var player = _create_test_player(10, 0.0)
	var dummy_item = ItemData.new("potion", "Potion", ItemData.ItemType.CONSUMABLE, ItemData.EquipSlot.NONE, 0.5)
	shop.stock_items.append(dummy_item)
	var buy_res = merchant.buy_item(player, dummy_item)
	assert_false(buy_res["success"], "Hostile merchant must refuse trade")
	assert_true(buy_res["reason"].contains("hostile"), "Reason must specify merchant is hostile")
	
	# Verify GameManager run-wide hostility flag
	var gm = merchant._get_game_mgr()
	if gm:
		assert_true(gm.merchants_hostile_this_run, "GameManager.merchants_hostile_this_run must be true")
		gm.merchants_hostile_this_run = false

# -----------------------------------------------------------------------------
# 7. AMMUNITION STACKS & REFILL EQUIPPED AMMO
# -----------------------------------------------------------------------------
func test_ammunition_stacks_and_refill() -> void:
	var outfitter_shop = ShopData.generate_stock_for_specialty(MerchantCatalog.Specialty.GENERAL_OUTFITTER, 1)
	
	# Verify ammo items are in stacks (quantity > 1)
	var has_arrows = false
	var has_bolts = false
	for it in outfitter_shop.stock_items:
		if it.item_type == ItemData.ItemType.AMMO:
			if it.item_id == "ammo_arrows":
				has_arrows = true
				assert_true(it.quantity >= 20, "Arrows must be sold in stacks of 20+")
			elif it.item_id == "ammo_bolts":
				has_bolts = true
				assert_true(it.quantity >= 15, "Crossbow bolts must be sold in stacks of 15+")
	assert_true(has_arrows, "General outfitter must stock arrows in stacks")
	assert_true(has_bolts, "General outfitter must stock bolts in stacks")
	
	# Test refill equipped ammo helper
	var merchant = track(Merchant.new()) as Merchant
	merchant.shop_data = outfitter_shop
	var player = _create_test_player(10, 0.0)
	
	# Equip a bow requiring ammo
	var bow = ItemData.new("hunting_bow", "Hunting Bow", ItemData.ItemType.WEAPON, ItemData.EquipSlot.MAIN_HAND, 3.0)
	bow.weapon_type = AttributesData.WeaponType.BOW
	bow.requires_ammo = true
	player.get_node("InventoryComponent").equip_item(bow)
	
	var refill_res = merchant.refill_equipped_ammo(player)
	assert_true(refill_res["success"], "Ammo refill must succeed when compatible ammo is stocked")
	assert_eq(refill_res["item"].item_id, "ammo_arrows", "Refill must purchase matching bow arrows")
