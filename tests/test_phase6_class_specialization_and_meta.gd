@tool
extends McpTestSuite

## Phase 6 Test Suite: Post-Floor 2 Class Specialization, Persistence, and Meta-Progression

const ClassData = preload("res://scripts/resources/ClassData.gd")
const ClassCatalog = preload("res://scripts/resources/ClassCatalog.gd")

func suite_name() -> String:
    return "phase6_class_specialization_and_meta"

func _get_game_mgr() -> Node:
    var loop = Engine.get_main_loop()
    if loop and loop is SceneTree:
        var node = (loop as SceneTree).root.get_node_or_null("GameManager")
        if node:
            return node
    var script = load("res://scripts/autoload/GameManager.gd")
    if script:
        return track(script.new()) as Node
    return null

func _get_meta_mgr() -> Node:
    var loop = Engine.get_main_loop()
    if loop and loop is SceneTree:
        var node = (loop as SceneTree).root.get_node_or_null("MetaManager")
        if node:
            return node
    var script = load("res://scripts/autoload/MetaManager.gd")
    if script:
        return track(script.new()) as Node
    return null

# -----------------------------------------------------------------------------
# 1. CLASS CATALOG & PREREQUISITE ELIGIBILITY TESTS
# -----------------------------------------------------------------------------

func test_class_catalog_registration() -> void:
    var cc = load("res://scripts/resources/ClassCatalog.gd")
    assert_true(cc != null, "ClassCatalog must load")
    var vagabond = cc.get_class_by_id("vagabond")
    assert_true(vagabond != null, "Vagabond universal fallback class must exist")
    assert_eq(vagabond.archetype, ClassData.Archetype.GENERAL, "Vagabond must be GENERAL archetype")

func test_vagabond_universal_fallback_eligibility() -> void:
    var vagabond = ClassCatalog.get_class_by_id("vagabond")
    assert_true(vagabond != null, "Vagabond class must exist")
    
    var attrs: AttributesData = track(AttributesData.new()) as AttributesData
    var skills: SkillComponent = track(SkillComponent.new()) as SkillComponent
    
    # Low / zero stats: Vagabond must ALWAYS be eligible
    attrs.strength = 1
    attrs.dexterity = 1
    attrs.constitution = 1
    attrs.intelligence = 1
    attrs.wisdom = 1
    attrs.charisma = 1
    
    assert_true(vagabond.is_eligible(attrs, skills), "Vagabond must be unconditionally eligible (universal fallback)")
    assert_true(vagabond.is_eligible(null, null), "Vagabond must be eligible even with null attributes/skills")

func test_knight_hard_prerequisite_validation() -> void:
    var knight = ClassCatalog.get_class_by_id("knight")
    assert_true(knight != null, "Knight class must exist")
    
    var attrs: AttributesData = track(AttributesData.new()) as AttributesData
    var skills: SkillComponent = track(SkillComponent.new()) as SkillComponent
    
    # Below requirements (Knight requires STR 14, CON 12, Swordsmanship 15, Parry 12)
    attrs.strength = 10
    attrs.constitution = 10
    var sword = skills.get_skill(SkillData.SkillId.SWORDSMANSHIP)
    sword.level = 5.0
    var parry = skills.get_skill(SkillData.SkillId.PARRY)
    parry.level = 5.0
    
    assert_false(knight.is_eligible(attrs, skills), "Knight must be locked when prerequisites not met")
    
    # Meet exact requirements
    attrs.strength = 14
    attrs.constitution = 12
    sword.level = 15.0
    parry.level = 12.0
    assert_true(knight.is_eligible(attrs, skills), "Knight must be eligible when all prerequisites met")

func test_dynamic_aptitude_scoring_unlock() -> void:
    var knight = ClassCatalog.get_class_by_id("knight")
    assert_true(knight != null, "Knight class must exist")
    
    var attrs: AttributesData = track(AttributesData.new()) as AttributesData
    var skills: SkillComponent = track(SkillComponent.new()) as SkillComponent
    
    # Primary attributes meet 80% baseline (Knight req: STR 14, CON 12; 80% is 11.2 and 9.6 -> STR 12, CON 10)
    attrs.strength = 12
    attrs.constitution = 10
    
    # Skill levels high enough that AptitudeScore >= 25.0
    # AptitudeScore = sum(max(0, Attr - 4) * 2.5) + sum((Skill / Req) * 15.0)
    # Attr points: (12 - 4) * 2.5 = 20.0 + (10 - 4) * 2.5 = 15.0 -> Attr score alone = 35.0 >= 25.0!
    var sword = skills.get_skill(SkillData.SkillId.SWORDSMANSHIP)
    sword.level = 10.0 # Under 15.0 hard req
    var parry = skills.get_skill(SkillData.SkillId.PARRY)
    parry.level = 8.0  # Under 12.0 hard req
    
    var aptitude = knight.calculate_aptitude(attrs, skills)
    assert_gt(aptitude, 25.0, "Aptitude score must exceed 25.0 with strong relevant attributes")
    assert_true(knight.is_eligible(attrs, skills), "Class must unlock via Dynamic Aptitude Scoring when baseline is met")

# -----------------------------------------------------------------------------
# 2. CLASS BONUSES & APPLICATION
# -----------------------------------------------------------------------------

func test_class_application_to_player() -> void:
    var knight = ClassCatalog.get_class_by_id("knight")
    assert_true(knight != null, "Knight class must exist")
    
    var dummy_player: Node2D = track(Node2D.new()) as Node2D
    var stats: StatsComponent = track(StatsComponent.new()) as StatsComponent
    var skills: SkillComponent = track(SkillComponent.new()) as SkillComponent
    dummy_player.add_child(stats)
    dummy_player.add_child(skills)
    
    var initial_str = stats.attributes.strength
    var initial_con = stats.attributes.constitution
    var initial_hp = stats.attributes.get_max_health()
    
    var changes = knight.apply_to_player(dummy_player)
    assert_gt(changes.size(), 0, "Knight must apply attribute bonuses")
    assert_eq(stats.attributes.strength, initial_str + 2, "Knight grants +2 STR")
    assert_eq(stats.attributes.constitution, initial_con + 1, "Knight grants +1 CON")
    assert_gt(stats.attributes.get_max_health(), initial_hp, "Max HP should increase with Constitution bonus")
    
    # Check player metadata
    assert_eq(dummy_player.get_meta("class_id"), "knight", "Player class_id meta must be knight")
    assert_eq(dummy_player.get_meta("class_name"), "Knight", "Player class_name meta must be Knight")
    assert_eq(dummy_player.get_meta("class_passive_type"), "armor_soak_mult", "Passive type must be armor_soak_mult")

# -----------------------------------------------------------------------------
# 3. CHARACTER CREATION DATA & BACKGROUNDS
# -----------------------------------------------------------------------------

func test_character_creation_backgrounds_registry() -> void:
    var backgrounds = CharacterCreationData.BACKGROUNDS
    assert_true(backgrounds.has("novice_adventurer"), "novice_adventurer must be registered")
    assert_true(backgrounds.has("veteran_mercenary"), "veteran_mercenary must be registered")
    assert_true(backgrounds.has("shadow_syndicate"), "shadow_syndicate must be registered")
    assert_true(backgrounds.has("royal_arcanist"), "royal_arcanist must be registered")
    assert_true(backgrounds.has("temple_inquisitor"), "temple_inquisitor must be registered")
    assert_true(backgrounds.has("grandmaster_initiate"), "grandmaster_initiate must be registered")

func test_apply_background_bonuses() -> void:
    var char_data = CharacterCreationData.create_default_character()
    var attrs = char_data["attributes"] as AttributesData
    var base_str = attrs.strength
    var base_con = attrs.constitution
    
    var updated = CharacterCreationData.apply_background(char_data, "veteran_mercenary")
    assert_eq(updated["background"], "veteran_mercenary", "Background id must be updated")
    assert_eq(attrs.strength, base_str + 2, "Veteran Mercenary adds +2 STR")
    assert_eq(attrs.constitution, base_con + 2, "Veteran Mercenary adds +2 CON")

# -----------------------------------------------------------------------------
# 4. META PROGRESSION & ACCOUNT EXP FORMULAS
# -----------------------------------------------------------------------------

func test_meta_rank_exp_requirement_formula() -> void:
    var profile: MetaProfileData = track(MetaProfileData.new()) as MetaProfileData
    
    # Formula strictly per GDD: floor(200 * Rank^1.5)
    # Rank 1: floor(200 * 1.0) = 200
    assert_eq(profile.get_required_exp_for_rank(1), 200, "Rank 1 requires 200 Meta EXP")
    # Rank 2: floor(200 * 2^1.5) = floor(200 * 2.8284) = 565
    assert_eq(profile.get_required_exp_for_rank(2), 565, "Rank 2 requires 565 Meta EXP")
    # Rank 3: floor(200 * 3^1.5) = floor(200 * 5.1961) = 1039
    assert_eq(profile.get_required_exp_for_rank(3), 1039, "Rank 3 requires 1039 Meta EXP")

func test_meta_add_exp_and_rank_promotion() -> void:
    var profile: MetaProfileData = track(MetaProfileData.new()) as MetaProfileData
    profile.account_rank = 1
    profile.current_meta_exp = 0
    
    # Award 300 EXP -> Surpasses 200 required for Rank 1 -> Promotes to Rank 2, 100 EXP remaining
    var promoted = profile.add_meta_exp(300)
    assert_eq(promoted.size(), 1, "Should achieve 1 rank promotion")
    assert_eq(profile.account_rank, 2, "Account Rank must advance to 2")
    assert_eq(profile.current_meta_exp, 100, "Remaining EXP must be carried over")
    assert_true(profile.unlocked_background_ids.has("veteran_mercenary"), "Rank 2 must unlock Veteran Mercenary background")

func test_run_completion_exp_formula() -> void:
    # Mathematical Run EXP Formula strictly per GDD:
    # RunEXP = (Floors * 100) + (Std * 10) + (Elite * 30) + (Boss * 150) + (Keystones * 50) + floor(Gold * 0.10) + (Victory ? 1000 : 0)
    var summary: Dictionary = {
        "floors_cleared": 3,
        "standard_kills": 8,
        "elite_kills": 2,
        "boss_kills": 1,
        "keystones_unlocked": 2,
        "gold_earned": 250,
        "victory": false,
        "turns_survived": 120
    }
    
    var expected_exp = (3 * 100) + (8 * 10) + (2 * 30) + (1 * 150) + (2 * 50) + int(floor(250.0 * 0.10))
    # 300 + 80 + 60 + 150 + 100 + 25 = 715
    assert_eq(expected_exp, 715, "Expected Run EXP calculation check")
    
    var meta_mgr = _get_meta_mgr()
    var result = meta_mgr.record_run_completion(summary)
    assert_eq(result["earned_exp"], 715, "MetaManager must calculate exact Run EXP per GDD formula")

# -----------------------------------------------------------------------------
# 5. PERSISTENCE & HMAC SIGNATURE INTEGRITY
# -----------------------------------------------------------------------------

func test_game_manager_hmac_integrity() -> void:
    var game_mgr = _get_game_mgr()
    var test_payload = '{"player": "Hero", "floor": 2}'
    var hmac1 = game_mgr.calculate_hmac(test_payload)
    var hmac2 = game_mgr.calculate_hmac(test_payload)
    assert_eq(hmac1, hmac2, "HMAC must be deterministic for identical content")
    
    var tampered_payload = '{"player": "Hero", "floor": 99}'
    var hmac_tampered = game_mgr.calculate_hmac(tampered_payload)
    assert_false(hmac1 == hmac_tampered, "HMAC must change when payload is tampered")

func test_permadeath_save_wipe() -> void:
    var game_mgr = _get_game_mgr()
    # Ensure test files exist in user://saves/
    if not DirAccess.dir_exists_absolute("user://saves"):
        DirAccess.make_dir_recursive_absolute("user://saves")
        
    var save_path = "user://saves/current_run.json"
    var test_file = FileAccess.open(save_path, FileAccess.WRITE)
    if test_file:
        test_file.store_string('{"test": true}')
        test_file.close()
        
    assert_true(FileAccess.file_exists(save_path), "Save file must exist prior to wipe")
    
    # Execute permadeath wipe
    var wiped = game_mgr.wipe_run_save()
    assert_true(wiped, "wipe_run_save must report successful wipe")
    assert_false(FileAccess.file_exists(save_path), "Save file must be completely deleted from physical disk")

# -----------------------------------------------------------------------------
# 6. MODAL UNIT INTERACTION
# -----------------------------------------------------------------------------

func test_class_selection_modal_setup() -> void:
    var modal: ClassSelectionModal = track(ClassSelectionModal.new()) as ClassSelectionModal
    
    # Build minimal mock UI hierarchy
    var vbox = VBoxContainer.new()
    vbox.name = "VBox"
    modal.add_child(vbox)
    
    var filter_bar = HBoxContainer.new()
    filter_bar.name = "FilterBar"
    vbox.add_child(filter_bar)
    
    var split = HBoxContainer.new()
    split.name = "MainSplit"
    vbox.add_child(split)
    
    var left = VBoxContainer.new()
    left.name = "LeftPane"
    split.add_child(left)
    var scroll = ScrollContainer.new()
    scroll.name = "Scroll"
    left.add_child(scroll)
    var list = VBoxContainer.new()
    list.name = "ClassList"
    scroll.add_child(list)
    
    var right = ScrollContainer.new()
    right.name = "RightPane"
    split.add_child(right)
    var detail = VBoxContainer.new()
    detail.name = "DetailVBox"
    right.add_child(detail)
    
    var l_name = Label.new()
    l_name.name = "LabelClassName"
    detail.add_child(l_name)
    var l_arch = Label.new()
    l_arch.name = "LabelArchetype"
    detail.add_child(l_arch)
    var l_desc = Label.new()
    l_desc.name = "LabelDescription"
    detail.add_child(l_desc)
    var r_req = RichTextLabel.new()
    r_req.name = "TextPrereqs"
    detail.add_child(r_req)
    var r_perk = RichTextLabel.new()
    r_perk.name = "TextPerks"
    detail.add_child(r_perk)
    var l_status = Label.new()
    l_status.name = "LabelEligibilityStatus"
    detail.add_child(l_status)
    
    var b_bar = HBoxContainer.new()
    b_bar.name = "BottomBar"
    vbox.add_child(b_bar)
    var b_conf = Button.new()
    b_conf.name = "BtnConfirm"
    b_bar.add_child(b_conf)
    
    # Test open modal
    var dummy: Node2D = track(Node2D.new()) as Node2D
    var s_comp: StatsComponent = track(StatsComponent.new()) as StatsComponent
    var k_comp: SkillComponent = track(SkillComponent.new()) as SkillComponent
    dummy.add_child(s_comp)
    dummy.add_child(k_comp)
    
    modal.open_modal(dummy)
    assert_true(modal.visible, "Modal should be visible after open_modal")
    assert_true(modal.selected_class != null, "Modal should default select an eligible class or Vagabond")
    
    modal.close_modal()
    assert_false(modal.visible, "Modal should be hidden after close_modal")
