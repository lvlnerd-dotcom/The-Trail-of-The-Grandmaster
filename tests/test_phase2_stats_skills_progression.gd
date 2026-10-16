@tool
extends McpTestSuite

## Phase 2 Test Suite: Dual Progression, Exact Attribute Formulas, Skills & Weight Limits

func suite_name() -> String:
    return "phase2_stats_skills_progression"

func test_attribute_strength_scaling() -> void:
    var attrs: AttributesData = track(AttributesData.new()) as AttributesData
    
    # 10 STR baseline
    attrs.strength = 10
    assert_eq(attrs.get_melee_damage_modifier(), 1.0, "10 STR = 100% Melee Damage")
    assert_eq(attrs.get_max_carry_weight_stones(), 100.0, "10 STR = 100 Stones carry capacity")
    
    # 20 STR: +25% damage, 200 stones
    attrs.strength = 20
    assert_eq(attrs.get_melee_damage_modifier(), 1.25, "20 STR = 125% Melee Damage")
    assert_eq(attrs.get_max_carry_weight_stones(), 200.0, "20 STR = 200 Stones carry capacity")
    
    # 50 STR: +100% damage (200%), 500 stones
    attrs.strength = 50
    assert_eq(attrs.get_melee_damage_modifier(), 2.0, "50 STR = 200% Melee Damage")
    assert_eq(attrs.get_max_carry_weight_stones(), 500.0, "50 STR = 500 Stones carry capacity")
    
    # Ranged weapon scaling at 20 STR (+25% bonus)
    attrs.strength = 20
    assert_eq(attrs.get_ranged_damage_modifier(AttributesData.WeaponType.THROWN), 1.25, "Thrown weapons receive 100% STR bonus")
    assert_eq(attrs.get_ranged_damage_modifier(AttributesData.WeaponType.SLING), 1.25, "Slings receive 100% STR bonus")
    assert_eq(attrs.get_ranged_damage_modifier(AttributesData.WeaponType.HIGH_TENSION_BOW), 1.125, "Recurve bow receives 50% STR bonus (12.5%)")
    assert_eq(attrs.get_ranged_damage_modifier(AttributesData.WeaponType.FIREARM), 1.0, "Firearms receive no STR bonus")

func test_constitution_and_intelligence_scaling() -> void:
    var attrs: AttributesData = track(AttributesData.new()) as AttributesData
    
    # CON Scaling
    attrs.constitution = 10
    assert_eq(attrs.get_max_health(), 100.0, "10 CON = 100 Base HP")
    attrs.constitution = 20
    assert_eq(attrs.get_max_health(), 125.0, "20 CON = 125 Base HP")
    attrs.constitution = 50
    assert_eq(attrs.get_max_health(), 200.0, "50 CON = 200 Base HP")
    
    # INT Scaling
    attrs.intelligence = 10
    assert_eq(attrs.get_max_mana(), 50.0, "10 INT = 50 Base Mana")
    assert_eq(attrs.get_skill_xp_multiplier(), 1.0, "10 INT = 100% Skill XP progression")
    
    # Under 10 INT: No penalty to skill XP
    attrs.intelligence = 5
    assert_eq(attrs.get_skill_xp_multiplier(), 1.0, "No skill XP penalty under 10 INT")
    
    attrs.intelligence = 20
    assert_eq(attrs.get_max_mana(), 62.5, "20 INT = 62.5 Base Mana")
    assert_eq(attrs.get_skill_xp_multiplier(), 1.25, "20 INT = 125% Skill XP progression")
    
    attrs.intelligence = 50
    assert_eq(attrs.get_max_mana(), 100.0, "50 INT = 100 Base Mana")
    assert_eq(attrs.get_skill_xp_multiplier(), 2.0, "50 INT = 200% Skill XP progression")

func test_wisdom_shrine_scaling() -> void:
    var attrs: AttributesData = track(AttributesData.new()) as AttributesData
    
    # 10 WIS
    attrs.wisdom = 10
    var res10 = attrs.get_shrine_multipliers()
    assert_eq(res10["bonus_mult"], 1.0, "10 WIS = 100% shrine bonus")
    assert_eq(res10["penalty_mult"], 1.0, "10 WIS = 100% shrine penalty")
    
    # 1 WIS: -90% bonus, +90% penalty
    attrs.wisdom = 1
    var res1 = attrs.get_shrine_multipliers()
    assert_true(is_equal_approx(res1["bonus_mult"], 0.10), "1 WIS = 10% shrine bonus (90% less)")
    assert_true(is_equal_approx(res1["penalty_mult"], 1.90), "1 WIS = 190% shrine penalty (90% more)")
    
    # 20 WIS: +25% bonus, -25% penalty
    attrs.wisdom = 20
    var res20 = attrs.get_shrine_multipliers()
    assert_eq(res20["bonus_mult"], 1.25, "20 WIS = 125% shrine bonus")
    assert_eq(res20["penalty_mult"], 0.75, "20 WIS = 75% shrine penalty (25% reduction)")
    
    # 50 WIS: +100% bonus, 0% penalty (completely removed!)
    attrs.wisdom = 50
    var res50 = attrs.get_shrine_multipliers()
    assert_eq(res50["bonus_mult"], 2.0, "50 WIS = 200% shrine bonus")
    assert_eq(res50["penalty_mult"], 0.0, "50 WIS = 0% shrine penalty (eliminated!)")

func test_charisma_scaling() -> void:
    var attrs: AttributesData = track(AttributesData.new()) as AttributesData
    
    attrs.charisma = 10
    assert_eq(attrs.get_mercantile_modifier(), 1.0, "10 CHA = 100% prices")
    assert_eq(attrs.get_companion_stat_modifier(), 1.0, "10 CHA = 100% companion stats")
    
    attrs.charisma = 20
    assert_true(is_equal_approx(attrs.get_mercantile_modifier(), 1.10), "20 CHA = 110% prices in player favor")
    assert_eq(attrs.get_companion_stat_modifier(), 1.25, "20 CHA = 125% companion stats")
    
    # 100 CHA: exactly 190% prices as specified in design doc!
    attrs.charisma = 100
    assert_true(is_equal_approx(attrs.get_mercantile_modifier(), 1.90), "100 CHA = 190% prices in player favor")

func test_dexterity_critical_hit_overflow() -> void:
    var attrs: AttributesData = track(AttributesData.new()) as AttributesData
    
    attrs.dexterity = 10
    assert_eq(attrs.get_critical_chance(), 0.15, "10 DEX = 15% Crit chance")
    
    # Past 100% crit chance
    attrs.dexterity = 70
    assert_gt(attrs.get_critical_chance(), 1.0, "70 DEX = 105% Crit chance (overflow active)")

func test_skill_progression_and_synergies() -> void:
    var skills_comp: SkillComponent = track(SkillComponent.new()) as SkillComponent
    var attrs: AttributesData = track(AttributesData.new()) as AttributesData
    attrs.strength = 10
    attrs.dexterity = 10
    attrs.intelligence = 10
    
    # Swordsmanship starts at 0.0
    var sword_skill = skills_comp.get_skill(SkillData.SkillId.SWORDSMANSHIP)
    assert_eq(sword_skill.level, 0.0, "Initial skill level is 0.0")
    
    # Effective level at 10 STR: 0.0 + 10 / 2 = 5.0
    var eff_lvl = skills_comp.get_effective_level(SkillData.SkillId.SWORDSMANSHIP, attrs)
    assert_eq(eff_lvl, 5.0, "Effective level with 10 attribute is +5.0")
    
    # Train skill with sweet spot difficulty
    skills_comp.train_skill(SkillData.SkillId.SWORDSMANSHIP, 5.0, attrs) # 10 XP
    skills_comp.train_skill(SkillData.SkillId.SWORDSMANSHIP, 5.0, attrs) # 20 XP -> crosses 20 XP threshold!
    assert_eq(sword_skill.level, 0.1, "Skill should advance by 0.1 after 20 XP")
    
    # Keystone synergy: Set Parry to 25.0
    var parry_skill = skills_comp.get_skill(SkillData.SkillId.PARRY)
    parry_skill.level = 25.0
    assert_true(parry_skill.unlocked_keystones.has(25), "25 milestone should be registered")
    
    # Check Dodge effective level gets +5 synergy bonus from Parry 25
    var dodge_eff = skills_comp.get_effective_level(SkillData.SkillId.DODGE, attrs)
    # Dodge level (0.0) + DEX bonus (5.0) + Parry keystone synergy (5.0) = 10.0
    assert_eq(dodge_eff, 10.0, "Dodge should receive +5 synergy bonus from Parry 25 keystone")

func test_inventory_weight_equipped_exemption() -> void:
    var inv: InventoryComponent = track(InventoryComponent.new()) as InventoryComponent
    var attrs: AttributesData = track(AttributesData.new()) as AttributesData
    attrs.strength = 10 # 100 Stones max
    
    var sword = track(ItemData.new("sword_test", "Heavy Blade", ItemData.ItemType.WEAPON, ItemData.EquipSlot.MAIN_HAND, 15.0)) as ItemData
    var armor = track(ItemData.new("armor_test", "Iron Plate", ItemData.ItemType.ARMOR, ItemData.EquipSlot.BODY, 25.0)) as ItemData
    
    # Add to carried inventory
    inv.add_item(sword)
    inv.add_item(armor)
    assert_eq(inv.get_carried_weight_stones(), 40.0, "Carried weight should be 40.0 stones")
    assert_false(inv.is_overburdened(attrs.get_max_carry_weight_stones()), "Not overburdened under 100 stones")
    
    # Equip sword & armor: Equipping must exempt them from carry weight!
    inv.equip_item(sword)
    assert_eq(inv.get_carried_weight_stones(), 25.0, "Carried weight should drop to 25.0 stones after equipping sword")
    
    inv.equip_item(armor)
    assert_eq(inv.get_carried_weight_stones(), 0.0, "Carried weight should drop to 0.0 stones with all gear equipped")
    
    # Unequip armor back to backpack
    inv.unequip_slot(ItemData.EquipSlot.BODY)
    assert_eq(inv.get_carried_weight_stones(), 25.0, "Carried weight should return to 25.0 stones after un-equipping armor")

func test_kill_exp_and_attribute_allocation() -> void:
    var attrs: AttributesData = track(AttributesData.new()) as AttributesData
    attrs.strength = 10
    attrs.constitution = 10
    
    assert_eq(attrs.character_level, 1, "Starts at Level 1")
    assert_eq(attrs.get_exp_required_for_next_level(), 100, "Level 1 -> 2 requires 100 EXP")
    
    # Award 100 kill EXP
    var leveled = attrs.add_kill_exp(100)
    assert_true(leveled, "Should level up after gaining 100 EXP")
    assert_eq(attrs.character_level, 2, "Character should now be Level 2")
    assert_eq(attrs.unallocated_attribute_points, 2, "Level 2 grants 2 attribute points")
    
    # Allocate 1 point to Constitution
    var alloc_con = attrs.allocate_attribute_point("constitution")
    assert_true(alloc_con, "Allocation should succeed")
    assert_eq(attrs.constitution, 11, "Constitution should now be 11")
    assert_eq(attrs.unallocated_attribute_points, 1, "1 point remaining")
    assert_true(is_equal_approx(attrs.get_max_health(), 102.5), "Max HP should immediately recalculate to 102.5")
    
    # Allocate 1 point to Strength
    var alloc_str = attrs.allocate_attribute_point("strength")
    assert_true(alloc_str, "Allocation should succeed")
    assert_eq(attrs.strength, 11, "Strength should now be 11")
    assert_eq(attrs.unallocated_attribute_points, 0, "0 points remaining")
    assert_eq(attrs.get_max_carry_weight_stones(), 110.0, "Carry capacity should immediately recalculate to 110 stones")
    
    # Attempting to allocate with 0 points left must fail
    var alloc_fail = attrs.allocate_attribute_point("strength")
    assert_false(alloc_fail, "Cannot allocate with 0 points remaining")

func test_character_creation_validation() -> void:
    var default_char = CharacterCreationData.create_default_character()
    var attrs = default_char["attributes"] as AttributesData
    
    var attr_dict = {
        "strength": attrs.strength,
        "dexterity": attrs.dexterity,
        "constitution": attrs.constitution,
        "intelligence": attrs.intelligence,
        "wisdom": attrs.wisdom,
        "charisma": attrs.charisma
    }
    
    var val_result = CharacterCreationData.validate_attribute_distribution(attr_dict)
    assert_true(val_result["is_valid"], "Default character build must be valid")
    
    # Test invalid distribution (exceeding starting cap of 10)
    var invalid_dict = attr_dict.duplicate()
    invalid_dict["strength"] = 12
    var val_invalid = CharacterCreationData.validate_attribute_distribution(invalid_dict)
    assert_false(val_invalid["is_valid"], "Cannot exceed starting cap of 10")
    
    # Test starter items package
    var starter_items = default_char["starting_items"] as Array[ItemData]
    assert_gt(starter_items.size(), 0, "Starting skills must generate starter equipment package")
