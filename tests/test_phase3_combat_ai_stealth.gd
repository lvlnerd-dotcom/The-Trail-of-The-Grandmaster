@tool
extends McpTestSuite

## Phase 3 Test Suite: Combat Resolution, GDD Hit Formula, Multi-Crits, Stealth & AI

func suite_name() -> String:
    return "phase3_combat_ai_stealth"

func test_gdd_hit_chance_formula() -> void:
    var player: Node2D = track(Node2D.new()) as Node2D
    var player_stats: StatsComponent = track(StatsComponent.new()) as StatsComponent
    player_stats.name = "StatsComponent"
    var player_skills: SkillComponent = track(SkillComponent.new()) as SkillComponent
    player_skills.name = "SkillComponent"
    var player_combat: CombatComponent = track(CombatComponent.new()) as CombatComponent
    player_combat.name = "CombatComponent"
    player.add_child(player_stats)
    player.add_child(player_skills)
    player.add_child(player_combat)
    player_stats.attributes.strength = 10
    player_stats.attributes.dexterity = 10
    
    var enemy: Node2D = track(Node2D.new()) as Node2D
    var enemy_stats: StatsComponent = track(StatsComponent.new()) as StatsComponent
    enemy_stats.name = "StatsComponent"
    var enemy_skills: SkillComponent = track(SkillComponent.new()) as SkillComponent
    enemy_skills.name = "SkillComponent"
    enemy.add_child(enemy_stats)
    enemy.add_child(enemy_skills)
    enemy_stats.attributes.strength = 10
    enemy_stats.attributes.dexterity = 10
    
    # 1. Equal skills: Attacker effective Swordsmanship = 10.0, Defender effective Dodge = 10.0
    # Formula: (10 + 50) / ((10 + 50) * 2) = 60 / 120 = 0.50 (50%)
    player_skills.get_skill(SkillData.SkillId.SWORDSMANSHIP).level = 5.0 # + 10 STR / 2 = 10.0
    enemy_skills.get_skill(SkillData.SkillId.DODGE).level = 5.0         # + 10 DEX / 2 = 10.0
    
    var hit_info_equal = player_combat.calculate_hit_chance(enemy)
    assert_true(is_equal_approx(hit_info_equal["hit_chance"], 0.50), "Equal 10.0 skills must yield exactly 50% hit chance")
    
    # 2. Attacker higher skill: Attacker effective = 50.0, Defender effective = 10.0
    # Formula: (50 + 50) / ((10 + 50) * 2) = 100 / 120 = 0.8333 (83.33%)
    player_skills.get_skill(SkillData.SkillId.SWORDSMANSHIP).level = 45.0 # + 5.0 attr = 50.0
    var hit_info_high = player_combat.calculate_hit_chance(enemy)
    var hit_val = hit_info_high["hit_chance"]
    var exp_val = 100.0 / 120.0
    assert_true(is_equal_approx(hit_val, exp_val), "Expected %f but got %f (atk_val=%f, def_val=%f)" % [exp_val, hit_val, hit_info_high["atk_skill_val"], hit_info_high["def_skill_val"]])
    
    # 3. Defender choice: Stance vs Weapon skill
    # Give enemy 20.0 Swordsmanship weapon skill and 10.0 Dodge stance skill
    # GDD rule: "only the higher effective value is considered"
    enemy_skills.get_skill(SkillData.SkillId.SWORDSMANSHIP).level = 15.0 # 15 + 5 = 20.0
    var hit_info_def_choice = player_combat.calculate_hit_chance(enemy)
    # Denominator must use 20.0: (50 + 50) / ((20 + 50) * 2) = 100 / 140 = 0.7143
    assert_true(is_equal_approx(hit_info_def_choice["hit_chance"], 100.0 / 140.0), "Must choose higher of defender weapon or stance skill")

func test_stealth_perception_detection_formula() -> void:
    var observer: Node2D = track(Node2D.new()) as Node2D
    var obs_stats: StatsComponent = track(StatsComponent.new()) as StatsComponent
    obs_stats.name = "StatsComponent"
    var obs_skills: SkillComponent = track(SkillComponent.new()) as SkillComponent
    obs_skills.name = "SkillComponent"
    observer.add_child(obs_stats)
    observer.add_child(obs_skills)
    obs_stats.attributes.wisdom = 10
    
    var target: Node2D = track(Node2D.new()) as Node2D
    var target_stats: StatsComponent = track(StatsComponent.new()) as StatsComponent
    target_stats.name = "StatsComponent"
    var target_skills: SkillComponent = track(SkillComponent.new()) as SkillComponent
    target_skills.name = "SkillComponent"
    target.add_child(target_stats)
    target.add_child(target_skills)
    target_stats.attributes.dexterity = 10
    
    # Equal skills (10.0 vs 10.0): (10 + 50) / ((10 + 50) * 2) = 60 / 120 = 50%
    obs_skills.get_skill(SkillData.SkillId.PERCEPTION).level = 5.0 # + 5.0 WIS bonus = 10.0
    target_skills.get_skill(SkillData.SkillId.STEALTH_HIDE).level = 5.0 # + 5.0 DEX bonus = 10.0
    
    var det_chance_equal = VisionComponent.calculate_detection_chance(observer, target)
    assert_true(is_equal_approx(det_chance_equal, 0.50), "Equal 10.0 Perception vs Hide must yield exactly 50% detection chance")
    
    # High Perception (50.0 vs 10.0): (50 + 50) / 120 = 83.33%
    obs_skills.get_skill(SkillData.SkillId.PERCEPTION).level = 45.0 # + 5.0 WIS = 50.0
    var det_chance_high = VisionComponent.calculate_detection_chance(observer, target)
    var exp_det = 100.0 / 120.0
    assert_true(is_equal_approx(det_chance_high, exp_det), "Expected %f but got %f" % [exp_det, det_chance_high])

func test_armor_soak_mitigation() -> void:
    var player: Node2D = track(Node2D.new()) as Node2D
    var player_stats: StatsComponent = track(StatsComponent.new()) as StatsComponent
    var player_skills: SkillComponent = track(SkillComponent.new()) as SkillComponent
    var player_combat: CombatComponent = track(CombatComponent.new()) as CombatComponent
    player.add_child(player_stats)
    player.add_child(player_skills)
    player.add_child(player_combat)
    
    var enemy: Node2D = track(Node2D.new()) as Node2D
    var enemy_stats: StatsComponent = track(StatsComponent.new()) as StatsComponent
    var enemy_skills: SkillComponent = track(SkillComponent.new()) as SkillComponent
    var enemy_inv: InventoryComponent = track(InventoryComponent.new()) as InventoryComponent
    enemy.add_child(enemy_stats)
    enemy.add_child(enemy_skills)
    enemy.add_child(enemy_inv)
    
    # Equip heavy shield on enemy with 4 armor
    var shield = track(ItemData.new("shield_heavy", "Tower Shield", ItemData.ItemType.SHIELD, ItemData.EquipSlot.OFF_HAND, 4.0)) as ItemData
    shield.armor_value = 4
    enemy_inv.equip_item(shield)
    assert_eq(enemy_inv.get_total_armor(), 4, "Total armor must be 4")
    
    # Enemy takes fixed 10 damage: after 4 armor soak, final damage should be 6
    var initial_hp = enemy_stats.current_hp
    var soaked_dmg = max(1, 10 - enemy_inv.get_total_armor())
    enemy_stats.take_damage(soaked_dmg)
    assert_eq(enemy_stats.current_hp, initial_hp - 6, "10 damage - 4 armor soak must deal 6 damage")

func test_enemy_intimidation_states() -> void:
    var grid: DungeonGrid = track(DungeonGrid.new()) as DungeonGrid
    grid.grid_width = 10
    grid.grid_height = 10
    for y in range(10):
        for x in range(10):
            grid.set_cell_walkable(Vector2i(x, y), true)
            
    var enemy_script = load("res://scripts/entities/Enemy.gd") as GDScript
    enemy_script.reload()
    var enemy = track(enemy_script.new())
    var stats: StatsComponent = track(StatsComponent.new()) as StatsComponent
    var skills: SkillComponent = track(SkillComponent.new()) as SkillComponent
    var combat: CombatComponent = track(CombatComponent.new()) as CombatComponent
    var inv: InventoryComponent = track(InventoryComponent.new()) as InventoryComponent
    var vision: VisionComponent = track(VisionComponent.new()) as VisionComponent
    enemy.add_child(stats)
    enemy.add_child(skills)
    enemy.add_child(combat)
    enemy.add_child(inv)
    enemy.add_child(vision)
    
    # Apply Terrified status (flee for 3 turns)
    enemy.apply_intimidation("TERRIFIED", 3)
    assert_eq(enemy.intimidation_status, "TERRIFIED", "Enemy status should be TERRIFIED")
    assert_eq(enemy.intimidation_turns_remaining, 3, "3 turns remaining")
    assert_eq(enemy.ai_state, Enemy.AIState.FLEE, "AI state should switch to FLEE")
