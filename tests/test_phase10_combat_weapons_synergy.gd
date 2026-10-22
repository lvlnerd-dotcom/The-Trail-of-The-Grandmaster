@tool
extends McpTestSuite

## Phase 10 Test Suite: Weapon & Skill Synergy System, 50-Weapon Manifest, Level 25 Active Abilities,
## Level 50 Attribute Scaling Shifts, and Exact Hit Chance / Defensive Skill Formula.

const SkillData = preload("res://scripts/resources/SkillData.gd")
const ItemData = preload("res://scripts/resources/ItemData.gd")
const WeaponAbilityData = preload("res://scripts/resources/WeaponAbilityData.gd")
const WeaponManifest = preload("res://scripts/resources/WeaponManifest.gd")
const AttributesData = preload("res://scripts/resources/AttributesData.gd")
const StatsComponent = preload("res://scripts/components/StatsComponent.gd")
const SkillComponent = preload("res://scripts/components/SkillComponent.gd")
const InventoryComponent = preload("res://scripts/components/InventoryComponent.gd")
const CombatComponent = preload("res://scripts/components/CombatComponent.gd")
const HotbarBar = preload("res://scripts/ui/HotbarBar.gd")
const DungeonGrid = preload("res://scripts/world/DungeonGrid.gd")
const Player = preload("res://scripts/entities/Player.gd")
const CharacterCreationData = preload("res://scripts/resources/CharacterCreationData.gd")

func suite_name() -> String:
	return "phase10_combat_weapons_synergy"

func _create_combat_actor(name_str: String = "Actor") -> Node2D:
	var actor = track(Node2D.new()) as Node2D
	actor.name = name_str
	var stats = track(StatsComponent.new()) as StatsComponent
	stats.name = "StatsComponent"
	stats.attributes.strength = 10
	stats.attributes.dexterity = 10
	stats.attributes.constitution = 10
	stats.attributes.intelligence = 10
	stats.attributes.wisdom = 10
	stats.attributes.charisma = 10
	var skills = track(SkillComponent.new()) as SkillComponent
	skills.name = "SkillComponent"
	var inv = track(InventoryComponent.new()) as InventoryComponent
	inv.name = "InventoryComponent"
	var combat = track(CombatComponent.new()) as CombatComponent
	combat.name = "CombatComponent"
	actor.add_child(stats)
	actor.add_child(skills)
	actor.add_child(inv)
	actor.add_child(combat)
	return actor

func test_weapon_manifest_all_50_weapons_and_categories() -> void:
	var all_ids = WeaponManifest.get_all_weapon_ids()
	assert_eq(all_ids.size(), 50, "WeaponManifest must contain all 50 base weapons across the 7 skills")

	var swords = WeaponManifest.get_weapons_for_skill(SkillData.SkillId.SWORDSMANSHIP)
	var blunts = WeaponManifest.get_weapons_for_skill(SkillData.SkillId.BLUNT_WEAPON_FIGHTING)
	var finesse = WeaponManifest.get_weapons_for_skill(SkillData.SkillId.FINESSE_WEAPON_FIGHTING)
	var polearms = WeaponManifest.get_weapons_for_skill(SkillData.SkillId.POLEARMS)
	var brawling = WeaponManifest.get_weapons_for_skill(SkillData.SkillId.BRAWLING)
	var archery = WeaponManifest.get_weapons_for_skill(SkillData.SkillId.ARCHERY)
	var throwing = WeaponManifest.get_weapons_for_skill(SkillData.SkillId.THROWING)

	assert_eq(swords.size(), 7, "Swordsmanship must have 7 weapons")
	assert_eq(blunts.size(), 7, "Blunt Weapon Fighting must have 7 weapons")
	assert_eq(finesse.size(), 7, "Finesse Weapon Fighting must have 7 weapons")
	assert_eq(polearms.size(), 7, "Polearms must have 7 weapons")
	assert_eq(brawling.size(), 7, "Brawling must have 7 weapons")
	assert_eq(archery.size(), 7, "Archery must have 7 weapons")
	assert_eq(throwing.size(), 8, "Throwing must have 8 weapons")

	var seen_abilities: Dictionary = {}
	for wid in all_ids:
		var w = WeaponManifest.create_weapon(wid)
		assert_true(w != null, "Weapon %s must instantiate" % wid)
		assert_true(w.active_ability != null, "Weapon %s must have a Level 25 active ability" % wid)
		assert_eq(w.active_ability.required_skill_id, w.associated_skill_id, "Ability skill ID must match weapon skill ID for %s" % wid)
		assert_eq(w.active_ability.required_skill_level, 25.0, "Ability unlock threshold must be 25.0 for %s" % wid)
		assert_false(seen_abilities.has(w.active_ability.ability_id), "Each weapon must have a unique ability_id (%s)" % w.active_ability.ability_id)
		seen_abilities[w.active_ability.ability_id] = true

func test_level_50_attribute_scaling_shift_all_7_skills() -> void:
	var skills_comp = track(SkillComponent.new()) as SkillComponent
	var attrs = track(AttributesData.new()) as AttributesData
	attrs.strength = 20       # +10.0 at 0.5x, +20.0 at 1.0x
	attrs.dexterity = 16      # +8.0 at 0.5x, +16.0 at 1.0x
	attrs.constitution = 14   # +7.0 at 0.5x

	# 1. Swordsmanship: Primary STR | Secondary DEX at 50+
	var sword = skills_comp.get_skill(SkillData.SkillId.SWORDSMANSHIP)
	sword.level = 40.0
	assert_true(is_equal_approx(skills_comp.get_effective_level(SkillData.SkillId.SWORDSMANSHIP, attrs), 40.0 + 10.0), "Swordsmanship <50 scales off STR only (40 + 10 = 50)")
	sword.level = 50.0
	assert_true(is_equal_approx(skills_comp.get_effective_level(SkillData.SkillId.SWORDSMANSHIP, attrs), 50.0 + 10.0 + 8.0), "Swordsmanship >=50 adds Secondary DEX (50 + 10 + 8 = 68)")

	# 2. Blunt Weapon Fighting: Primary STR | Doubles STR at 50+
	var blunt = skills_comp.get_skill(SkillData.SkillId.BLUNT_WEAPON_FIGHTING)
	blunt.level = 49.9
	assert_true(is_equal_approx(skills_comp.get_effective_level(SkillData.SkillId.BLUNT_WEAPON_FIGHTING, attrs), 49.9 + 10.0), "Blunt <50 scales 0.5x STR")
	blunt.level = 50.0
	assert_true(is_equal_approx(skills_comp.get_effective_level(SkillData.SkillId.BLUNT_WEAPON_FIGHTING, attrs), 50.0 + 20.0), "Blunt >=50 doubles STR scaling (50 + 20 = 70)")

	# 3. Finesse Weapon Fighting: Primary DEX | Doubles DEX at 50+
	var fin = skills_comp.get_skill(SkillData.SkillId.FINESSE_WEAPON_FIGHTING)
	fin.level = 30.0
	assert_true(is_equal_approx(skills_comp.get_effective_level(SkillData.SkillId.FINESSE_WEAPON_FIGHTING, attrs), 30.0 + 8.0), "Finesse <50 scales 0.5x DEX")
	fin.level = 50.0
	assert_true(is_equal_approx(skills_comp.get_effective_level(SkillData.SkillId.FINESSE_WEAPON_FIGHTING, attrs), 50.0 + 16.0), "Finesse >=50 doubles DEX scaling (50 + 16 = 66)")

	# 4. Polearms: Primary CON | Secondary STR at 50+
	var pole = skills_comp.get_skill(SkillData.SkillId.POLEARMS)
	pole.level = 25.0
	assert_true(is_equal_approx(skills_comp.get_effective_level(SkillData.SkillId.POLEARMS, attrs), 25.0 + 7.0), "Polearms <50 scales 0.5x CON (25 + 7 = 32)")
	pole.level = 50.0
	assert_true(is_equal_approx(skills_comp.get_effective_level(SkillData.SkillId.POLEARMS, attrs), 50.0 + 7.0 + 10.0), "Polearms >=50 adds Secondary STR (50 + 7 + 10 = 67)")

	# 5. Brawling: Primary STR | Secondary DEX at 50+
	var brawl = skills_comp.get_skill(SkillData.SkillId.BRAWLING)
	brawl.level = 20.0
	assert_true(is_equal_approx(skills_comp.get_effective_level(SkillData.SkillId.BRAWLING, attrs), 20.0 + 10.0), "Brawling <50 scales 0.5x STR")
	brawl.level = 50.0
	assert_true(is_equal_approx(skills_comp.get_effective_level(SkillData.SkillId.BRAWLING, attrs), 50.0 + 10.0 + 8.0), "Brawling >=50 adds Secondary DEX (50 + 10 + 8 = 68)")

	# 6. Archery: Primary DEX | Doubles DEX at 50+
	var arch = skills_comp.get_skill(SkillData.SkillId.ARCHERY)
	arch.level = 40.0
	assert_true(is_equal_approx(skills_comp.get_effective_level(SkillData.SkillId.ARCHERY, attrs), 40.0 + 8.0), "Archery <50 scales 0.5x DEX")
	arch.level = 50.0
	assert_true(is_equal_approx(skills_comp.get_effective_level(SkillData.SkillId.ARCHERY, attrs), 50.0 + 16.0), "Archery >=50 doubles DEX scaling (50 + 16 = 66)")

	# 7. Throwing: Primary DEX | Secondary STR at 50+
	var thr = skills_comp.get_skill(SkillData.SkillId.THROWING)
	thr.level = 40.0
	assert_true(is_equal_approx(skills_comp.get_effective_level(SkillData.SkillId.THROWING, attrs), 40.0 + 8.0), "Throwing <50 scales 0.5x DEX")
	thr.level = 50.0
	assert_true(is_equal_approx(skills_comp.get_effective_level(SkillData.SkillId.THROWING, attrs), 50.0 + 8.0 + 10.0), "Throwing >=50 adds Secondary STR (50 + 8 + 10 = 68)")

func test_strict_weapon_skill_training_isolation() -> void:
	var attacker = _create_combat_actor("Attacker")
	var defender = _create_combat_actor("Defender")
	var atk_skills = attacker.get_node("SkillComponent") as SkillComponent
	var atk_combat = attacker.get_node("CombatComponent") as CombatComponent
	var def_stats = defender.get_node("StatsComponent") as StatsComponent
	def_stats.current_hp = 5000.0

	# Give attacker high accuracy so hits land reliably
	atk_skills.get_skill(SkillData.SkillId.BLUNT_WEAPON_FIGHTING).level = 10.0
	atk_skills.get_skill(SkillData.SkillId.FINESSE_WEAPON_FIGHTING).level = 10.0
	var def_skills = defender.get_node("SkillComponent") as SkillComponent
	def_skills.get_skill(SkillData.SkillId.DODGE).level = 10.0

	var mace = WeaponManifest.create_weapon("blunt_mace")
	mace.accuracy_bonus = 0.50 # Guarantee 95% hit cap
	var sword_before = atk_skills.get_skill(SkillData.SkillId.SWORDSMANSHIP).level
	var blunt_before = atk_skills.get_skill(SkillData.SkillId.BLUNT_WEAPON_FIGHTING).level

	for _i in range(15):
		def_stats.current_hp = 5000.0
		atk_combat.execute_attack(defender, mace)

	assert_gt(atk_skills.get_skill(SkillData.SkillId.BLUNT_WEAPON_FIGHTING).level, blunt_before, "Attacking with Mace must increment Blunt Weapon Fighting")
	assert_eq(atk_skills.get_skill(SkillData.SkillId.SWORDSMANSHIP).level, sword_before, "Attacking with Mace must NEVER increment Swordsmanship")

func test_hit_chance_formula_and_crucial_defensive_rule() -> void:
	var attacker = _create_combat_actor("Attacker")
	var defender = _create_combat_actor("Defender")
	var atk_skills = attacker.get_node("SkillComponent") as SkillComponent
	var atk_inv = attacker.get_node("InventoryComponent") as InventoryComponent
	var atk_combat = attacker.get_node("CombatComponent") as CombatComponent
	var def_skills = defender.get_node("SkillComponent") as SkillComponent
	var def_inv = defender.get_node("InventoryComponent") as InventoryComponent

	# Equip Attacker with Warhammer (Blunt Weapon Fighting, 0.0 acc_bonus)
	var warhammer = WeaponManifest.create_weapon("blunt_warhammer")
	atk_inv.equip_item(warhammer)
	atk_skills.get_skill(SkillData.SkillId.BLUNT_WEAPON_FIGHTING).level = 25.0 # + 5.0 (10 STR) = 30.0 effective

	# Equip Defender with Halberd (Polearms) at 40.0 effective, while Dodge is only 15.0 effective
	var halberd = WeaponManifest.create_weapon("polearm_halberd")
	def_inv.equip_item(halberd)
	def_skills.get_skill(SkillData.SkillId.POLEARMS).level = 35.0 # + 5.0 (10 CON) = 40.0 effective
	def_skills.get_skill(SkillData.SkillId.DODGE).level = 10.0    # + 5.0 (10 DEX) = 15.0 effective

	var hit_info = atk_combat.calculate_hit_chance(defender, warhammer)
	assert_eq(hit_info["atk_skill_id"], SkillData.SkillId.BLUNT_WEAPON_FIGHTING, "Uses Blunt Weapon Fighting for Warhammer")
	assert_eq(hit_info["def_weapon_skill_id"], SkillData.SkillId.POLEARMS, "Evaluates defender's equipped Polearms skill")
	assert_true(is_equal_approx(hit_info["def_skill_val"], 40.0), "Crucial Defensive Rule: picks higher Polearms (40.0) over Dodge (15.0)")

	var expected_hit = (30.0 + 50.0) / ((40.0 + 50.0) * 2.0) # 80 / 180 = 0.444444
	assert_true(is_equal_approx(hit_info["hit_chance"], expected_hit), "Hit chance must match (Atk+50)/((Def+50)*2)")

	# Now equip Main-Gauche in Defender's Off-Hand (after switching Defender main hand to 1H Shortsword)
	var def_sword = WeaponManifest.create_weapon("sword_short")
	var main_gauche = WeaponManifest.create_weapon("finesse_main_gauche")
	def_inv.equip_item(def_sword, ItemData.EquipSlot.MAIN_HAND)
	def_inv.equip_item(main_gauche, ItemData.EquipSlot.OFF_HAND)
	assert_eq(def_inv.get_equipped_offhand(), main_gauche, "Main-Gauche equipped in OFF_HAND")
	assert_gt(def_inv.get_total_defense_bonus(), 0.14, "Main-Gauche grants offhand defense bonus")

func test_level_25_weapon_ability_unlock_and_hotbar_execution() -> void:
	var grid = track(DungeonGrid.new()) as DungeonGrid
	grid.grid_width = 12
	grid.grid_height = 12
	for y in range(12):
		for x in range(12):
			grid.set_cell_walkable(Vector2i(x, y), true)

	var player = _create_combat_actor("Player")
	var enemy = _create_combat_actor("Enemy")
	var p_skills = player.get_node("SkillComponent") as SkillComponent
	var p_inv = player.get_node("InventoryComponent") as InventoryComponent
	var p_combat = player.get_node("CombatComponent") as CombatComponent

	grid.register_entity(player, Vector2i(5, 5))
	grid.register_entity(enemy, Vector2i(5, 6))

	var exec_sword = WeaponManifest.create_weapon("sword_executioner")
	p_inv.equip_item(exec_sword)

	# At Swordsmanship 10.0 (< 25.0), ability is locked
	p_skills.get_skill(SkillData.SkillId.SWORDSMANSHIP).level = 10.0
	assert_false(p_skills.is_weapon_ability_unlocked(exec_sword), "Ability locked below Level 25.0")

	var hotbar = track(HotbarBar.new()) as HotbarBar
	hotbar.setup(player)
	assert_false(hotbar.set_slot_weapon_ability(0, exec_sword), "Hotbar rejects weapon ability below Level 25.0")

	# Advance Swordsmanship to Level 25.0 -> Unlocks Guillotine Drop!
	p_skills.get_skill(SkillData.SkillId.SWORDSMANSHIP).level = 25.0
	assert_true(p_skills.is_weapon_ability_unlocked(exec_sword), "Ability unlocked at Level 25.0")
	assert_true(hotbar.set_slot_weapon_ability(0, exec_sword), "Hotbar equips unlocked Level 25 weapon ability")
	assert_eq(hotbar.slots[0].slot_type, HotbarBar.SlotType.WEAPON_ABILITY, "Slot 0 is WEAPON_ABILITY")

	# Execute ability via CombatComponent
	exec_sword.accuracy_bonus = 0.60 # Ensure hit
	var res = p_combat.execute_weapon_ability(exec_sword, Vector2i(5, 5), Vector2i(5, 6), grid)
	assert_true(res.get("success", false), "Guillotine Drop executed successfully")
	assert_true(res.get("is_crit", false), "Guillotine Drop guarantees a critical hit")
	assert_gt(p_combat.get_ability_cooldown("guillotine_drop"), 0, "Ability placed on cooldown after use")

func test_shield_and_parry_context_aware_defense_resolution() -> void:
	var attacker = _create_combat_actor("Attacker")
	var defender = _create_combat_actor("Defender")
	var atk_combat = attacker.get_node("CombatComponent") as CombatComponent
	var def_skills = defender.get_node("SkillComponent") as SkillComponent
	var def_inv = defender.get_node("InventoryComponent") as InventoryComponent

	var sword = WeaponManifest.create_weapon("sword_short")
	def_inv.equip_item(sword, ItemData.EquipSlot.MAIN_HAND)
	def_skills.get_skill(SkillData.SkillId.SWORDSMANSHIP).level = 20.0 # High weapon skill (25.0 effective with 10 STR)
	def_skills.get_skill(SkillData.SkillId.PARRY).level = 5.0        # Lower parry skill (10.0 effective with 10 DEX)
	def_skills.get_skill(SkillData.SkillId.DODGE).level = 5.0        # Lower dodge skill (10.0 effective with 10 DEX)

	# 1. Equip Shield in Parry stance (Parry < 25)
	var buckler = ItemData.new("shield_buckler", "Steel Buckler", ItemData.ItemType.SHIELD, ItemData.EquipSlot.OFF_HAND, 2.5)
	buckler.block_chance_bonus = 0.15
	buckler.armor_value = 2
	def_inv.equip_item(buckler, ItemData.EquipSlot.OFF_HAND)
	assert_true(def_inv.has_shield_equipped(), "Inventory detects equipped shield")
	def_skills.active_defensive_mode = SkillComponent.DefensiveMode.PARRY_BLOCK

	var hit_shield_parry = atk_combat.calculate_hit_chance(defender)
	# Crucial Defensive Rule still picks higher Swordsmanship (25.0) over Parry (10.0)
	assert_true(is_equal_approx(hit_shield_parry["def_skill_val"], 25.0), "Crucial Defensive Rule still uses higher weapon skill")
	# In Parry stance with shield, defense labeling is BLOCK
	assert_eq(hit_shield_parry["defense_used"], "BLOCK", "Shield in Parry stance is classified as BLOCK")
	assert_eq(hit_shield_parry["defense_floating"], "BLOCK!", "Floating text is BLOCK!")
	assert_eq(hit_shield_parry["defense_verb"], "blocks with shield", "Log verb is 'blocks with shield'")
	assert_gt(hit_shield_parry["defender_mods"], 0.14, "Shield block chance bonus is applied in Parry stance")

	# 2. Defensive miss in Parry stance trains PARRY, never trains Swordsmanship!
	def_skills.get_skill(SkillData.SkillId.PARRY).current_xp = 15.0
	var parry_before = def_skills.get_skill(SkillData.SkillId.PARRY).level
	var sword_before = def_skills.get_skill(SkillData.SkillId.SWORDSMANSHIP).level
	var res_parry = atk_combat.execute_attack(defender)
	if not res_parry["hit"]:
		assert_gt(def_skills.get_skill(SkillData.SkillId.PARRY).level, parry_before, "Shield block in Parry stance trains Parry skill")
		assert_eq(def_skills.get_skill(SkillData.SkillId.SWORDSMANSHIP).level, sword_before, "Shield block NEVER trains Swordsmanship")
		assert_eq(res_parry["defense_verb"], "blocks with shield", "Attack result carries defense_verb")

	# 3. Switch to Dodge stance with Shield (Parry < 25):
	# Shield bonus must NOT apply in Dodge stance before Level 25 Parry!
	def_skills.active_defensive_mode = SkillComponent.DefensiveMode.DODGE_EVADE
	var hit_dodge_no_keystone = atk_combat.calculate_hit_chance(defender)
	assert_eq(hit_dodge_no_keystone["defense_used"], "DODGE", "Dodge stance always displays DODGE")
	assert_eq(hit_dodge_no_keystone["defense_floating"], "DODGE!", "Floating text is DODGE!")
	assert_eq(hit_dodge_no_keystone["defense_verb"], "dodges", "Log verb is 'dodges'")
	assert_true(is_equal_approx(hit_dodge_no_keystone["defender_mods"], 0.0), "Shield block bonus is INACTIVE in Dodge stance when Parry < 25.0")

	# Defensive miss in Dodge stance trains DODGE, never Parry!
	def_skills.get_skill(SkillData.SkillId.DODGE).current_xp = 15.0
	var dodge_before = def_skills.get_skill(SkillData.SkillId.DODGE).level
	var parry_check = def_skills.get_skill(SkillData.SkillId.PARRY).level
	var res_dodge = atk_combat.execute_attack(defender)
	if not res_dodge["hit"]:
		assert_gt(def_skills.get_skill(SkillData.SkillId.DODGE).level, dodge_before, "Dodge stance miss trains Dodge skill")
		assert_eq(def_skills.get_skill(SkillData.SkillId.PARRY).level, parry_check, "Dodge stance miss does NOT train Parry")

	# 4. Level 25 Parry Keystone: Shielded Evasion (Parry >= 25.0 unlocks shield bonus in Dodge stance!)
	def_skills.get_skill(SkillData.SkillId.PARRY).level = 25.0
	var hit_dodge_with_keystone = atk_combat.calculate_hit_chance(defender)
	assert_gt(hit_dodge_with_keystone["defender_mods"], 0.14, "Parry >= 25.0 unlocks shield block bonus while in Dodge stance!")
	assert_eq(hit_dodge_with_keystone["defense_used"], "DODGE", "Action identity remains DODGE even with shield cross-synergy")

	# 5. Level 25 Dodge Keystone: Nimble Guard (Dodge gear in Parry stance)
	var runners = ItemData.new("boots_runners", "Lightweight Runners", ItemData.ItemType.ARMOR, ItemData.EquipSlot.ACCESSORY, 1.0)
	runners.dodge_bonus = 0.08
	def_inv.equip_item(runners, ItemData.EquipSlot.ACCESSORY)
	def_inv.unequip_slot(ItemData.EquipSlot.OFF_HAND) # Remove shield for clear testing
	def_skills.active_defensive_mode = SkillComponent.DefensiveMode.PARRY_BLOCK

	# With Dodge < 25.0, runners' dodge bonus is inactive in Parry stance
	def_skills.get_skill(SkillData.SkillId.DODGE).level = 10.0
	var hit_parry_dodge_gear_low = atk_combat.calculate_hit_chance(defender)
	assert_true(is_equal_approx(hit_parry_dodge_gear_low["defender_mods"], 0.0), "Dodge gear inactive in Parry stance when Dodge < 25.0")

	# With Dodge >= 25.0, runners' dodge bonus unlocks in Parry stance!
	def_skills.get_skill(SkillData.SkillId.DODGE).level = 25.0
	var hit_parry_dodge_gear_high = atk_combat.calculate_hit_chance(defender)
	assert_gt(hit_parry_dodge_gear_high["defender_mods"], 0.07, "Dodge >= 25.0 unlocks dodge gear bonus while in Parry stance!")

func test_auto_optimal_stance_on_creation_and_equipment_change() -> void:
	var player = track(Player.new()) as Player
	var stats = track(StatsComponent.new()) as StatsComponent
	stats.name = "StatsComponent"
	var skills = track(SkillComponent.new()) as SkillComponent
	skills.name = "SkillComponent"
	var inv = track(InventoryComponent.new()) as InventoryComponent
	inv.name = "InventoryComponent"
	var combat = track(CombatComponent.new()) as CombatComponent
	combat.name = "CombatComponent"
	player.add_child(stats)
	player.add_child(skills)
	player.add_child(inv)
	player.add_child(combat)

	# 1. Player with Parry and Buckler in Character Creation
	var buckler = ItemData.new("shield_buckler", "Steel Buckler", ItemData.ItemType.SHIELD, ItemData.EquipSlot.OFF_HAND, 2.5)
	buckler.block_chance_bonus = 0.15
	buckler.armor_value = 2

	var sword = WeaponManifest.create_weapon("sword_short")

	var creation_pkg = {
		"attributes": AttributesData.new(),
		"selected_skills": [SkillData.SkillId.SWORDSMANSHIP, SkillData.SkillId.PARRY, SkillData.SkillId.PERCEPTION, SkillData.SkillId.STEALTH_HIDE],
		"starting_items": [sword, buckler]
	}
	player.setup_from_creation_data(creation_pkg)

	# Parry + Buckler equipped: Avoidance score for Parry (with 0.15 block bonus) > Dodge (0.0 bonus)
	assert_eq(player.skills.active_defensive_mode, SkillComponent.DefensiveMode.PARRY_BLOCK, "Auto-selects PARRY_BLOCK on creation when equipped with shield")

	# 2. Unequip Buckler and equip Lightweight Runners with dodge bonus
	var runners = ItemData.new("boots_runners", "Lightweight Runners", ItemData.ItemType.ARMOR, ItemData.EquipSlot.ACCESSORY, 1.0)
	runners.dodge_bonus = 0.08
	inv.unequip_slot(ItemData.EquipSlot.OFF_HAND)

	# Equipping runners triggers auto-evaluation:
	# Avoidance score with Dodge bonus (0.08) > Parry (0.0 bonus)
	inv.equip_item(runners, ItemData.EquipSlot.ACCESSORY)
	assert_eq(player.skills.active_defensive_mode, SkillComponent.DefensiveMode.DODGE_EVADE, "Auto-switches to DODGE_EVADE when dodge gear provides higher avoidance score")

	# 3. Re-equip Buckler:
	# Buckler block_chance_bonus (0.15) > runners dodge_bonus (0.08)
	inv.equip_item(buckler, ItemData.EquipSlot.OFF_HAND)
	assert_eq(player.skills.active_defensive_mode, SkillComponent.DefensiveMode.PARRY_BLOCK, "Auto-switches back to PARRY_BLOCK when shield provides higher defense")

	# 4. Manual Override via Tab / toggle_defensive_mode
	var manual_mode = player.skills.toggle_defensive_mode()
	assert_eq(manual_mode, SkillComponent.DefensiveMode.DODGE_EVADE, "Manual Tab toggles stance to DODGE_EVADE")
	assert_eq(player.skills.active_defensive_mode, SkillComponent.DefensiveMode.DODGE_EVADE, "Manual stance override is respected")

	# Mode stays overridden when player trains skills or performs actions (no equip change)
	player.skills.train_skill(SkillData.SkillId.DODGE, 10.0, stats.attributes)
	assert_eq(player.skills.active_defensive_mode, SkillComponent.DefensiveMode.DODGE_EVADE, "Manual override persists during normal gameplay without equipment changes")

	# 5. Next equip change re-evaluates optimal stance:
	# Unequipping runners leaves Buckler alone -> score_parry > score_dodge -> switches back to PARRY_BLOCK
	inv.unequip_slot(ItemData.EquipSlot.ACCESSORY)
	assert_eq(player.skills.active_defensive_mode, SkillComponent.DefensiveMode.PARRY_BLOCK, "Subsequent equipment change re-evaluates to optimal stance")

