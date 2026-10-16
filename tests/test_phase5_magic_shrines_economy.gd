@tool
extends McpTestSuite

## Phase 5 Test Suite: Magic, Deity Shrines, Companions & Merchant Economy

func suite_name() -> String:
	return "phase5_magic_shrines_economy"

## ----------------------------------------------------------------------
## 1. Wisdom Shrine Multiplier Formula (AttributesData.get_shrine_multipliers)
## ----------------------------------------------------------------------
func test_wisdom_shrine_multiplier_formula_benchmarks() -> void:
	var attrs: AttributesData = track(AttributesData.new()) as AttributesData

	# WIS = 1: Deficit 9 -> Bonus = 0.10 (-90%), Penalty = 1.90 (+90%)
	attrs.wisdom = 1
	var res1 = attrs.get_shrine_multipliers()
	assert_true(is_equal_approx(res1["bonus_mult"], 0.10), "WIS 1: bonus_mult must be 0.10 (-90%)")
	assert_true(is_equal_approx(res1["penalty_mult"], 1.90), "WIS 1: penalty_mult must be 1.90 (+90%)")

	# WIS = 5: Deficit 5 -> Bonus = 0.50 (-50%), Penalty = 1.50 (+50%)
	attrs.wisdom = 5
	var res5 = attrs.get_shrine_multipliers()
	assert_true(is_equal_approx(res5["bonus_mult"], 0.50), "WIS 5: bonus_mult must be 0.50 (-50%)")
	assert_true(is_equal_approx(res5["penalty_mult"], 1.50), "WIS 5: penalty_mult must be 1.50 (+50%)")

	# WIS = 10: Baseline -> Bonus = 1.00 (100%), Penalty = 1.00 (100%)
	attrs.wisdom = 10
	var res10 = attrs.get_shrine_multipliers()
	assert_true(is_equal_approx(res10["bonus_mult"], 1.00), "WIS 10: bonus_mult must be 1.00 (Neutral)")
	assert_true(is_equal_approx(res10["penalty_mult"], 1.00), "WIS 10: penalty_mult must be 1.00 (Neutral)")

	# WIS = 20: Excess 10 -> Bonus = 1.25 (+25%), Penalty = 0.75 (-25%)
	attrs.wisdom = 20
	var res20 = attrs.get_shrine_multipliers()
	assert_true(is_equal_approx(res20["bonus_mult"], 1.25), "WIS 20: bonus_mult must be 1.25 (+25%)")
	assert_true(is_equal_approx(res20["penalty_mult"], 0.75), "WIS 20: penalty_mult must be 0.75 (-25%)")

	# WIS = 30: Excess 20 -> Bonus = 1.50 (+50%), Penalty = 0.50 (-50%)
	attrs.wisdom = 30
	var res30 = attrs.get_shrine_multipliers()
	assert_true(is_equal_approx(res30["bonus_mult"], 1.50), "WIS 30: bonus_mult must be 1.50 (+50%)")
	assert_true(is_equal_approx(res30["penalty_mult"], 0.50), "WIS 30: penalty_mult must be 0.50 (-50%)")

	# WIS = 40: Excess 30 -> Bonus = 1.75 (+75%), Penalty = 0.25 (-75%)
	attrs.wisdom = 40
	var res40 = attrs.get_shrine_multipliers()
	assert_true(is_equal_approx(res40["bonus_mult"], 1.75), "WIS 40: bonus_mult must be 1.75 (+75%)")
	assert_true(is_equal_approx(res40["penalty_mult"], 0.25), "WIS 40: penalty_mult must be 0.25 (-75%)")

	# WIS = 50: Excess 40 -> Bonus = 2.00 (+100%), Penalty = 0.00 (Complete Penalty Immunity!)
	attrs.wisdom = 50
	var res50 = attrs.get_shrine_multipliers()
	assert_true(is_equal_approx(res50["bonus_mult"], 2.00), "WIS 50: bonus_mult must be 2.00 (+100%)")
	assert_true(is_equal_approx(res50["penalty_mult"], 0.00), "WIS 50: penalty_mult must be 0.00 (Immunity!)")

	# WIS = 70: Excess 60 -> Bonus = 2.50 (+150%), Penalty = 0.00 (Clamped at 0.0 min)
	attrs.wisdom = 70
	var res70 = attrs.get_shrine_multipliers()
	assert_true(is_equal_approx(res70["bonus_mult"], 2.50), "WIS 70: bonus_mult must be 2.50 (+150%)")
	assert_true(is_equal_approx(res70["penalty_mult"], 0.00), "WIS 70: penalty_mult must remain clamped at 0.00")

func test_wisdom_shrine_multiplier_edge_cases() -> void:
	var attrs: AttributesData = track(AttributesData.new()) as AttributesData

	# WIS = 0: Deficit 10 -> Bonus = 0.00, Penalty = 2.00 (+100% penalty)
	attrs.wisdom = 0
	var res0 = attrs.get_shrine_multipliers()
	assert_true(is_equal_approx(res0["bonus_mult"], 0.00), "WIS 0: bonus_mult must be 0.00")
	assert_true(is_equal_approx(res0["penalty_mult"], 2.00), "WIS 0: penalty_mult must be 2.00 (+100%)")

	# Negative WIS: e.g. WIS = -5 -> Deficit 15
	# Bonus must not become negative (clamped at 0.0), Penalty = 1.0 + 1.50 = 2.50
	attrs.wisdom = -5
	var res_neg = attrs.get_shrine_multipliers()
	assert_true(is_equal_approx(res_neg["bonus_mult"], 0.00), "Negative WIS: bonus_mult must clamp to 0.00 min")
	assert_true(is_equal_approx(res_neg["penalty_mult"], 2.50), "Negative WIS (-5): penalty_mult must be 2.50")

	# Verify with ShrineData: Valthor covenant (+30% damage, -20% HP)
	var valthor = ShrineData.create_valthor()
	attrs.wisdom = 10
	var base_bless = valthor.get_effective_blessing_modifier("physical_damage_pct", attrs)
	var base_taboo = valthor.get_effective_taboo_modifier("max_hp_pct", attrs)
	assert_true(is_equal_approx(base_bless, 0.30), "10 WIS: Valthor blessing is +30.0% damage")
	assert_true(is_equal_approx(base_taboo, -0.20), "10 WIS: Valthor taboo is -20.0% max HP")

	# At 50 WIS: blessing = +60%, taboo = 0.0%
	attrs.wisdom = 50
	var high_bless = valthor.get_effective_blessing_modifier("physical_damage_pct", attrs)
	var high_taboo = valthor.get_effective_taboo_modifier("max_hp_pct", attrs)
	assert_true(is_equal_approx(high_bless, 0.60), "50 WIS: Valthor blessing doubles to +60.0% damage")
	assert_true(is_equal_approx(high_taboo, 0.00), "50 WIS: Valthor taboo is nullified to 0.0% (Immune!)")

## ----------------------------------------------------------------------
## 2. Charisma Mercantile Buy & Sell Pricing (ShopData.gd / AttributesData.gd)
## ----------------------------------------------------------------------
func test_mercantile_buy_sell_pricing() -> void:
	var attrs: AttributesData = track(AttributesData.new()) as AttributesData
	var shop: ShopData = track(ShopData.new()) as ShopData
	var base_val: int = 100

	# 10 CHA: MercantileModifier = 1.00
	# BuyPrice = round(100 * 1.50 / 1.00) = 150 gold
	# SellPrice = round(100 * 0.40 * 1.00) = 40 gold
	attrs.charisma = 10
	assert_true(is_equal_approx(attrs.get_mercantile_modifier(), 1.00), "10 CHA: mod = 1.00")
	var buy_10 = shop.calculate_buy_price(base_val, attrs)
	var sell_10 = shop.calculate_sell_price(base_val, attrs)
	assert_eq(buy_10, 150, "10 CHA: Buy price must be 150 gold (1.50 * Base)")
	assert_eq(sell_10, 40, "10 CHA: Sell price must be 40 gold (0.40 * Base)")

	# 20 CHA: MercantileModifier = 1.10
	# BuyPrice = round(100 * 1.50 / 1.10) = round(136.3636) = 136 gold
	# SellPrice = round(100 * 0.40 * 1.10) = round(44.0) = 44 gold
	attrs.charisma = 20
	assert_true(is_equal_approx(attrs.get_mercantile_modifier(), 1.10), "20 CHA: mod = 1.10")
	var buy_20 = shop.calculate_buy_price(base_val, attrs)
	var sell_20 = shop.calculate_sell_price(base_val, attrs)
	assert_eq(buy_20, 136, "20 CHA: Buy price must be 136 gold (1.50 / 1.10 * Base)")
	assert_eq(sell_20, 44, "20 CHA: Sell price must be 44 gold (0.40 * 1.10 * Base)")

	# 50 CHA: MercantileModifier = 1.40
	# BuyPrice = round(100 * 1.50 / 1.40) = round(107.1428) = 107 gold
	# SellPrice = round(100 * 0.40 * 1.40) = round(56.0) = 56 gold
	attrs.charisma = 50
	assert_true(is_equal_approx(attrs.get_mercantile_modifier(), 1.40), "50 CHA: mod = 1.40")
	var buy_50 = shop.calculate_buy_price(base_val, attrs)
	var sell_50 = shop.calculate_sell_price(base_val, attrs)
	assert_eq(buy_50, 107, "50 CHA: Buy price must be 107 gold (1.50 / 1.40 * Base)")
	assert_eq(sell_50, 56, "50 CHA: Sell price must be 56 gold (0.40 * 1.40 * Base)")

	# 100 CHA: MercantileModifier = 1.90
	# BuyPrice = round(100 * 1.50 / 1.90) = round(78.947) = 79 gold (52.6% of base buy price)
	# SellPrice = round(100 * 0.40 * 1.90) = round(76.0) = 76 gold (190% of base sell payout)
	# Narrow spread: 79 - 76 = 3 gold spread!
	attrs.charisma = 100
	assert_true(is_equal_approx(attrs.get_mercantile_modifier(), 1.90), "100 CHA: mod = 1.90")
	var buy_100 = shop.calculate_buy_price(base_val, attrs)
	var sell_100 = shop.calculate_sell_price(base_val, attrs)
	assert_eq(buy_100, 79, "100 CHA: Buy price must be 79 gold (52.6% of baseline buy price)")
	assert_eq(sell_100, 76, "100 CHA: Sell price must be 76 gold (190% of baseline sell payout)")
	assert_eq(buy_100 - sell_100, 3, "100 CHA: Buy/Sell spread narrows to near parity (3 gold)")

	# Minimum 1 gold floor on all transactions
	assert_eq(shop.calculate_buy_price(0, attrs), 1, "0 base value buy price must have 1 gold floor")
	assert_eq(shop.calculate_sell_price(0, attrs), 1, "0 base value sell price must have 1 gold floor")
	attrs.charisma = 10
	assert_eq(shop.calculate_sell_price(1, attrs), 1, "1 gold base item with 0.40 markdown must floor at 1 gold")

## ----------------------------------------------------------------------
## 3. Charisma Companion Stat Scaling (CompanionData.gd / AttributesData.gd)
## ----------------------------------------------------------------------
func test_charisma_companion_stat_scaling() -> void:
	var attrs: AttributesData = track(AttributesData.new()) as AttributesData
	var merc = CompanionData.create_mercenary()
	var hound = CompanionData.create_hound()

	# 10 CHA: 1.00x (100%)
	attrs.charisma = 10
	assert_true(is_equal_approx(attrs.get_companion_stat_modifier(), 1.00), "10 CHA = 1.00x stat multiplier")
	assert_eq(merc.calculate_scaled_max_hp(attrs), 100, "10 CHA Mercenary HP = 100")
	assert_eq(merc.calculate_scaled_damage_min(attrs), 10, "10 CHA Mercenary Min Dmg = 10")
	assert_eq(merc.calculate_scaled_damage_max(attrs), 15, "10 CHA Mercenary Max Dmg = 15")
	assert_eq(merc.calculate_scaled_armor(attrs), 4, "10 CHA Mercenary Armor = 4")

	assert_eq(hound.calculate_scaled_max_hp(attrs), 70, "10 CHA Hound HP = 70")
	assert_eq(hound.calculate_scaled_damage_min(attrs), 8, "10 CHA Hound Min Dmg = 8")
	assert_eq(hound.calculate_scaled_damage_max(attrs), 12, "10 CHA Hound Max Dmg = 12")

	# 20 CHA: 1.25x (+25%)
	attrs.charisma = 20
	assert_true(is_equal_approx(attrs.get_companion_stat_modifier(), 1.25), "20 CHA = 1.25x stat multiplier")
	assert_eq(merc.calculate_scaled_max_hp(attrs), 125, "20 CHA Mercenary HP = 125 (100 * 1.25)")
	assert_eq(merc.calculate_scaled_damage_min(attrs), 13, "20 CHA Mercenary Min Dmg = 13 (round(10 * 1.25))")
	assert_eq(merc.calculate_scaled_damage_max(attrs), 19, "20 CHA Mercenary Max Dmg = 19 (round(15 * 1.25))")
	assert_eq(merc.calculate_scaled_armor(attrs), 5, "20 CHA Mercenary Armor = 5 (round(4 * 1.25))")

	assert_eq(hound.calculate_scaled_max_hp(attrs), 88, "20 CHA Hound HP = 88 (round(70 * 1.25))")
	assert_eq(hound.calculate_scaled_damage_min(attrs), 10, "20 CHA Hound Min Dmg = 10 (round(8 * 1.25))")
	assert_eq(hound.calculate_scaled_damage_max(attrs), 15, "20 CHA Hound Max Dmg = 15 (round(12 * 1.25))")

	# 50 CHA: 2.00x (+100%)
	attrs.charisma = 50
	assert_true(is_equal_approx(attrs.get_companion_stat_modifier(), 2.00), "50 CHA = 2.00x stat multiplier")
	assert_eq(merc.calculate_scaled_max_hp(attrs), 200, "50 CHA Mercenary HP = 200 (100 * 2.00)")
	assert_eq(merc.calculate_scaled_damage_min(attrs), 20, "50 CHA Mercenary Min Dmg = 20")
	assert_eq(merc.calculate_scaled_damage_max(attrs), 30, "50 CHA Mercenary Max Dmg = 30")
	assert_eq(merc.calculate_scaled_armor(attrs), 8, "50 CHA Mercenary Armor = 8 (4 * 2.00)")

	assert_eq(hound.calculate_scaled_max_hp(attrs), 140, "50 CHA Hound HP = 140 (70 * 2.00)")
	assert_eq(hound.calculate_scaled_damage_min(attrs), 16, "50 CHA Hound Min Dmg = 16")
	assert_eq(hound.calculate_scaled_damage_max(attrs), 24, "50 CHA Hound Max Dmg = 24")

## ----------------------------------------------------------------------
## 4. Spell Casting & Fizzle Mathematics (SpellCastingComponent & SpellData)
## ----------------------------------------------------------------------
func test_spell_fizzle_chance_formula() -> void:
	var caster: Node2D = track(Node2D.new()) as Node2D
	var stats: StatsComponent = StatsComponent.new()
	stats.name = "StatsComponent"
	var skills: SkillComponent = SkillComponent.new()
	skills.name = "SkillComponent"
	var caster_comp: SpellCastingComponent = SpellCastingComponent.new()
	caster_comp.name = "SpellCastingComponent"

	caster.add_child(stats)
	caster.add_child(skills)
	caster.add_child(caster_comp)

	# Fireball requires 25.0 Arcane Magic skill level
	var fireball = SpellData.create_fireball()
	assert_eq(fireball.required_skill_level, 25.0, "Fireball requires 25.0 skill")

	# 1. Deficit = 10.0 -> Fizzle = 50%
	# INT = 10 (attr bonus = 10 / 2 = 5.0). Skill level = 10.0 -> Effective = 15.0
	# Deficit = 25.0 - 15.0 = 10.0. FizzleChance = 10.0 * 0.05 = 0.50 (50%)
	stats.attributes.intelligence = 10
	skills.get_skill(SkillData.SkillId.ARCANE_MAGIC).level = 10.0
	var eff_skill = caster_comp.calculate_effective_skill(fireball)
	assert_true(is_equal_approx(eff_skill, 15.0), "Effective Arcane skill must be 15.0 (10 + 10/2)")
	var fizzle_10 = caster_comp.calculate_fizzle_chance(fireball)
	assert_true(is_equal_approx(fizzle_10, 0.50), "10.0 skill deficit must yield exactly 50% fizzle chance")

	# 2. Deficit = 0.0 -> Zero fizzle (Guaranteed cast)
	# INT = 14 (attr bonus = 7.0). Skill level = 20.0 -> Effective = 27.0 >= 25.0
	# Deficit = max(0.0, 25.0 - 27.0) = 0.0
	stats.attributes.intelligence = 14
	skills.get_skill(SkillData.SkillId.ARCANE_MAGIC).level = 20.0
	var eff_skill_zero = caster_comp.calculate_effective_skill(fireball)
	assert_true(is_equal_approx(eff_skill_zero, 27.0), "Effective skill is 27.0")
	var fizzle_zero = caster_comp.calculate_fizzle_chance(fireball)
	assert_true(is_equal_approx(fizzle_zero, 0.00), "EffectiveSkill >= RequiredSkill must have 0% fizzle chance")

	# 3. Large Deficit -> Clamped at 75% max
	# INT = 10 (attr bonus = 5.0). Skill level = 0.0 -> Effective = 5.0
	# Deficit = 25.0 - 5.0 = 20.0. Raw fizzle = 20.0 * 0.05 = 1.00 -> Clamped at 0.75
	stats.attributes.intelligence = 10
	skills.get_skill(SkillData.SkillId.ARCANE_MAGIC).level = 0.0
	var fizzle_cap = caster_comp.calculate_fizzle_chance(fireball)
	assert_true(is_equal_approx(fizzle_cap, 0.75), "Large deficit must clamp to 75% maximum fizzle chance")

func test_spell_mana_deduction_and_fizzle_consumption() -> void:
	var caster: Node2D = track(Node2D.new()) as Node2D
	var stats: StatsComponent = StatsComponent.new()
	stats.name = "StatsComponent"
	var skills: SkillComponent = SkillComponent.new()
	skills.name = "SkillComponent"
	var caster_comp: SpellCastingComponent = SpellCastingComponent.new()
	caster_comp.name = "SpellCastingComponent"

	caster.add_child(stats)
	caster.add_child(skills)
	caster.add_child(caster_comp)

	stats.attributes.intelligence = 10 # 50 max mana
	stats.current_mana = 50.0

	var fireball = SpellData.create_fireball() # mana_cost = 24.0, req_skill = 25.0
	skills.get_skill(SkillData.SkillId.ARCANE_MAGIC).level = 10.0 # Effective = 15.0 -> 50% fizzle

	# 1. Fizzle consumes 50% mana (half mana)
	# Force roll 0.10 (< 0.50 fizzle threshold)
	var fizzle_result = caster_comp.cast_spell(fireball, Vector2i(1, 1), null, 0.10)
	assert_false(fizzle_result["success"], "Spell cast must report failure on fizzle")
	assert_true(fizzle_result["fizzled"], "Spell cast must flag fizzled = true")
	assert_true(is_equal_approx(fizzle_result["mana_spent"], 12.0), "Fizzle must consume 50% of mana cost (12.0 of 24.0)")
	assert_true(is_equal_approx(stats.current_mana, 38.0), "Caster mana must drop from 50.0 to 38.0 after fizzle")

	# 2. Successful cast consumes 100% mana
	# Force roll 0.99 (>= 0.50 fizzle threshold)
	var success_result = caster_comp.cast_spell(fireball, Vector2i(1, 1), null, 0.99)
	assert_true(success_result["success"], "Spell cast must succeed when roll >= fizzle chance")
	assert_false(success_result["fizzled"], "Successful cast must not be flagged fizzled")
	assert_true(is_equal_approx(success_result["mana_spent"], 24.0), "Successful cast must deduct 100% mana cost (24.0)")
	assert_true(is_equal_approx(stats.current_mana, 14.0), "Caster mana must drop from 38.0 to 14.0 after success")

	# 3. Insufficient mana check
	var out_of_mana_result = caster_comp.cast_spell(fireball, Vector2i(1, 1), null, 0.99)
	assert_false(out_of_mana_result["success"], "Cannot cast spell when current mana (14) < mana cost (24)")
	assert_eq(out_of_mana_result["reason"], "INSUFFICIENT_MANA", "Reason must be INSUFFICIENT_MANA")
	assert_true(is_equal_approx(stats.current_mana, 14.0), "No mana spent on failed mana check")

func test_spell_potency_scaling_and_radiant_undead_multiplier() -> void:
	var caster: Node2D = track(Node2D.new()) as Node2D
	var stats: StatsComponent = StatsComponent.new()
	stats.name = "StatsComponent"
	var skills: SkillComponent = SkillComponent.new()
	skills.name = "SkillComponent"
	var caster_comp: SpellCastingComponent = SpellCastingComponent.new()
	caster_comp.name = "SpellCastingComponent"

	caster.add_child(stats)
	caster.add_child(skills)
	caster.add_child(caster_comp)

	# 1. GDD Potency Scaling verification:
	# Fireball (Base 32), Wizard with 30 Effective Skill and 18 INT:
	# PowerMultiplier = 1.0 + (30 * 0.01) + (18 - 10) * 0.025 = 1.0 + 0.30 + 0.20 = 1.50 (+50%)
	# ScaledBase = 32 * 1.50 = 48.0
	stats.attributes.intelligence = 18 # attr bonus = 9.0
	skills.get_skill(SkillData.SkillId.ARCANE_MAGIC).level = 21.0 # 21.0 + 9.0 = 30.0 effective
	var fireball = SpellData.create_fireball()
	var potency_info = caster_comp.calculate_spell_potency(fireball)
	assert_true(is_equal_approx(potency_info["power_multiplier"], 1.50), "PowerMultiplier must be exactly 1.50 (+50%)")
	assert_true(is_equal_approx(potency_info["scaled_base"], 48.0), "ScaledBase must be exactly 48.0 (32 * 1.50)")

	# 2. Radiant Damage vs. Undead (2.0x multiplier):
	# Smite: Base 22, School DIVINE, DamageType RADIANT, bonus_vs_undead_mult = 2.0
	# Priest with 10 WIS and 0 DIVINE_MAGIC skill:
	# EffectiveSkill = 0 + 10/2 = 5.0
	# PowerMultiplier = 1.0 + (5.0 * 0.01) + (10 - 10) * 0.025 = 1.05
	stats.attributes.wisdom = 10
	skills.get_skill(SkillData.SkillId.DIVINE_MAGIC).level = 0.0
	var smite = SpellData.create_smite()

	# Living enemy target (e.g. Goblin)
	var goblin: Enemy = track(Enemy.new()) as Enemy
	goblin.enemy_name = "Dungeon Goblin"
	goblin.is_undead = false

	var potency_goblin = caster_comp.calculate_spell_potency(smite, goblin)
	var expected_living = 22.0 * 1.05 # 23.1
	assert_false(potency_goblin["is_undead"], "Goblin is not undead")
	assert_true(is_equal_approx(potency_goblin["scaled_base"], expected_living), "Smite vs living = 23.1")

	# Undead enemy target (e.g. Skeleton Warrior)
	var skeleton: Enemy = track(Enemy.new()) as Enemy
	skeleton.enemy_name = "Skeleton Warrior"
	skeleton.is_undead = true

	var potency_skeleton = caster_comp.calculate_spell_potency(smite, skeleton)
	var expected_undead = expected_living * 2.0 # 46.2 (2.0x Holy strike)
	assert_true(potency_skeleton["is_undead"], "Skeleton is undead")
	assert_true(is_equal_approx(potency_skeleton["scaled_base"], expected_undead), "Smite vs undead must deal 2.0x radiant damage (46.2)")

## ----------------------------------------------------------------------
## 5. Initial Spell Library Validation (8 Spells)
## ----------------------------------------------------------------------
func test_initial_spells_factory_library() -> void:
	# Arcane Spells
	var mm = SpellData.create_magic_missile()
	assert_eq(mm.school, SpellData.School.ARCANE)
	assert_eq(mm.mana_cost, 8.0)
	assert_eq(mm.armor_penetration, 0.50)
	assert_eq(mm.damage_type, SpellData.DamageType.FORCE)

	var fb = SpellData.create_fireball()
	assert_eq(fb.school, SpellData.School.ARCANE)
	assert_eq(fb.mana_cost, 24.0)
	assert_eq(fb.area_radius, 1)
	assert_eq(fb.damage_type, SpellData.DamageType.FIRE)

	var blink = SpellData.create_blink()
	assert_eq(blink.school, SpellData.School.ARCANE)
	assert_eq(blink.effect_type, SpellData.EffectType.TELEPORT)
	assert_eq(blink.range_tiles, 4)

	var shield = SpellData.create_arcane_shield()
	assert_eq(shield.school, SpellData.School.ARCANE)
	assert_eq(shield.effect_type, SpellData.EffectType.WARD_SHIELD)
	assert_eq(shield.base_potency, 35.0)
	assert_eq(shield.duration_turns, 10)

	# Divine Spells
	var heal = SpellData.create_minor_heal()
	assert_eq(heal.school, SpellData.School.DIVINE)
	assert_eq(heal.effect_type, SpellData.EffectType.HEALING)
	assert_eq(heal.base_potency, 25.0)

	var smite = SpellData.create_smite()
	assert_eq(smite.school, SpellData.School.DIVINE)
	assert_eq(smite.effect_type, SpellData.EffectType.DAMAGE)
	assert_eq(smite.bonus_vs_undead_mult, 2.0)

	var purify = SpellData.create_purify()
	assert_eq(purify.school, SpellData.School.DIVINE)
	assert_eq(purify.effect_type, SpellData.EffectType.STATUS_CLEANSE)

	var aegis = SpellData.create_divine_aegis()
	assert_eq(aegis.school, SpellData.School.DIVINE)
	assert_eq(aegis.effect_type, SpellData.EffectType.WARD_SHIELD)
	assert_eq(aegis.duration_turns, 5)

## ----------------------------------------------------------------------
## 6. Ward Shield Damage Absorption & Turn Decay
## ----------------------------------------------------------------------
func test_ward_shield_absorption_and_decay() -> void:
	var player: Node2D = track(Node2D.new()) as Node2D
	var stats: StatsComponent = track(StatsComponent.new()) as StatsComponent
	stats.name = "StatsComponent"
	var skills: SkillComponent = track(SkillComponent.new()) as SkillComponent
	skills.name = "SkillComponent"
	var caster_comp: SpellCastingComponent = track(SpellCastingComponent.new()) as SpellCastingComponent
	caster_comp.name = "SpellCastingComponent"

	player.add_child(stats)
	player.add_child(skills)
	player.add_child(caster_comp)
	stats.current_hp = 100.0

	# Apply 35 HP ward shield
	caster_comp.active_ward_hp = 35.0
	caster_comp.ward_duration_turns = 10

	# 1. Incoming damage 20: completely absorbed by ward, 0 HP lost
	var dmg1 = stats.take_damage(20)
	assert_eq(dmg1, 0, "Ward absorbs all 20 damage")
	assert_true(is_equal_approx(stats.current_hp, 100.0), "HP remains 100.0")
	assert_true(is_equal_approx(caster_comp.active_ward_hp, 15.0), "Ward HP drops to 15.0")

	# 2. Incoming damage 25: 15 absorbed by ward, 10 penetrates to HP
	var dmg2 = stats.take_damage(25)
	assert_eq(dmg2, 10, "10 damage penetrates after 15 ward absorbed")
	assert_true(is_equal_approx(stats.current_hp, 90.0), "HP drops to 90.0")
	assert_true(is_equal_approx(caster_comp.active_ward_hp, 0.0), "Ward HP depleted to 0.0")

	# 3. Ward turn decay
	caster_comp.active_ward_hp = 20.0
	caster_comp.ward_duration_turns = 2
	caster_comp.tick_ward_turns()
	assert_eq(caster_comp.ward_duration_turns, 1, "Duration turns ticks down to 1")
	assert_true(is_equal_approx(caster_comp.active_ward_hp, 20.0), "Ward HP intact")
	caster_comp.tick_ward_turns()
	assert_eq(caster_comp.ward_duration_turns, 0, "Duration turns expired")
	assert_true(is_equal_approx(caster_comp.active_ward_hp, 0.0), "Ward HP expired to 0.0")

## ----------------------------------------------------------------------
## 7. Merchant Buying & Selling Transactions
## ----------------------------------------------------------------------
func test_merchant_trade_transactions() -> void:
	var player: Node2D = track(Node2D.new()) as Node2D
	var stats: StatsComponent = track(StatsComponent.new()) as StatsComponent
	stats.name = "StatsComponent"
	var inv: InventoryComponent = track(InventoryComponent.new()) as InventoryComponent
	inv.name = "InventoryComponent"
	player.add_child(stats)
	player.add_child(inv)
	stats.attributes.strength = 10 # 100 max stones carry weight
	stats.attributes.charisma = 10 # 1.00 mercantile mod
	inv.gold = 300

	var merchant: Merchant = track(Merchant.new()) as Merchant
	var shop = ShopData.new()
	shop.merchant_gold = 500

	var test_sword = track(ItemData.new("sword_01", "Gladius", ItemData.ItemType.WEAPON, ItemData.EquipSlot.MAIN_HAND, 5.0)) as ItemData
	test_sword.base_value_gold = 100
	shop.stock_items.append(test_sword)
	merchant.setup(shop)

	# 1. Player buys Gladius (Base 100, 10 CHA -> 150 gold)
	var buy_res = merchant.buy_item(player, test_sword)
	assert_true(buy_res["success"], "Purchase must succeed")
	assert_eq(buy_res["price"], 150, "Buy price is 150 gold")
	assert_eq(inv.gold, 150, "Player gold drops from 300 to 150")
	assert_eq(shop.merchant_gold, 650, "Merchant gold rises from 500 to 650")
	assert_true(inv.items.has(test_sword), "Player inventory now contains Gladius")
	assert_false(shop.stock_items.has(test_sword), "Merchant stock no longer contains Gladius")

	# 2. Player sells Gladius back (Base 100, 10 CHA -> 40 gold)
	var sell_res = merchant.sell_item(player, test_sword)
	assert_true(sell_res["success"], "Sale must succeed")
	assert_eq(sell_res["price"], 40, "Sell price is 40 gold")
	assert_eq(inv.gold, 190, "Player gold rises from 150 to 190")
	assert_eq(shop.merchant_gold, 610, "Merchant gold drops from 650 to 610")
	assert_false(inv.items.has(test_sword), "Player inventory no longer contains Gladius")
	assert_true(shop.stock_items.has(test_sword), "Merchant stock now contains Gladius")

## ----------------------------------------------------------------------
## 8. Shrine Altar Prayer & Covenant Lifecycle
## ----------------------------------------------------------------------
func test_shrine_activation_and_covenant_lifecycle() -> void:
	var player: Node2D = track(Node2D.new()) as Node2D
	var stats: StatsComponent = track(StatsComponent.new()) as StatsComponent
	stats.name = "StatsComponent"
	player.add_child(stats)
	stats.attributes.wisdom = 20 # 1.25 bonus mult, 0.75 penalty mult

	var shrine_valthor: Shrine = track(Shrine.new()) as Shrine
	shrine_valthor.setup(ShrineData.create_valthor())

	# 1. Pray at Valthor shrine
	var pray_res = shrine_valthor.pray(player)
	assert_true(pray_res["success"], "Prayer must succeed")
	assert_true(shrine_valthor.is_activated, "Shrine is marked activated")
	assert_true(is_equal_approx(pray_res["bonus_multiplier"], 1.25), "Bonus mult 1.25 at 20 WIS")
	assert_true(is_equal_approx(pray_res["penalty_multiplier"], 0.75), "Penalty mult 0.75 at 20 WIS")

	# Check covenant stored on player
	var cov = player.get_meta("active_shrine_covenant") as Dictionary
	assert_eq(cov["deity_id"], "valthor", "Active deity is Valthor")

	# 2. Cannot pray again at exhausted shrine
	var pray_exhausted = shrine_valthor.pray(player)
	assert_false(pray_exhausted["success"], "Exhausted shrine cannot be used again")

	# 3. Praying at a new shrine replaces covenant
	var shrine_ouros: Shrine = track(Shrine.new()) as Shrine
	shrine_ouros.setup(ShrineData.create_ouros())
	var pray_ouros = shrine_ouros.pray(player)
	assert_true(pray_ouros["success"], "Prayer at Ouros shrine must succeed")
	var new_cov = player.get_meta("active_shrine_covenant") as Dictionary
	assert_eq(new_cov["deity_id"], "ouros", "Active deity replaced with Ouros")

## ----------------------------------------------------------------------
## 9. Companion Lifecycle & Bulwark / Keen Senses Archetypes
## ----------------------------------------------------------------------
func test_companion_lifecycle_and_traits() -> void:
	var player: Node2D = track(Node2D.new()) as Node2D
	var player_stats: StatsComponent = track(StatsComponent.new()) as StatsComponent
	player_stats.name = "StatsComponent"
	player.add_child(player_stats)
	player_stats.attributes.charisma = 20 # 1.25x companion stat multiplier

	var grid: DungeonGrid = track(DungeonGrid.new()) as DungeonGrid
	grid.grid_width = 10
	grid.grid_height = 10
	for x in range(10):
		for y in range(10):
			grid.set_cell_walkable(Vector2i(x, y), true)

	var turn_mgr: TurnManager = track(TurnManager.new()) as TurnManager

	# 1. Hired Mercenary
	var merc: Companion = track(Companion.new()) as Companion
	player.set("grid_pos", Vector2i(2, 2))
	player.set_meta("grid_pos", Vector2i(2, 2))
	merc.setup(CompanionData.create_mercenary(), player, turn_mgr, grid, Vector2i(2, 3))

	assert_true(turn_mgr.registered_companions.has(merc), "Mercenary registered with TurnManager")
	assert_eq(merc.max_hp, 125.0, "Scaled max HP at 20 CHA is 125")
	assert_eq(merc.armor, 5, "Scaled armor at 20 CHA is 5 (round(4 * 1.25))")
	assert_true(merc.is_in_bulwark_stance(), "Mercenary adjacent to master has Bulwark Stance active")

	# 2. Tamed Hound Keen Senses
	var hound: Companion = track(Companion.new()) as Companion
	hound.setup(CompanionData.create_hound(), player, turn_mgr, grid, Vector2i(5, 5))
	assert_true(hound.has_keen_senses(), "Hound has keen senses trait")

	# 3. Companion Damage & Downed State
	merc.take_damage(200) # Exceeds HP -> Downed
	assert_true(merc.is_downed, "Companion is downed at 0 HP")

	# Healing revives companion
	merc.heal(50)
	assert_false(merc.is_downed, "Healing revives companion")
	assert_true(is_equal_approx(merc.current_hp, 50.0), "Companion current HP restored to 50.0")

