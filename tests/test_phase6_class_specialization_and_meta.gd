@tool
extends McpTestSuite

## Phase 6 Test Suite: Post-Floor 2 Class Specialization, Persistence, Tri-Tier Taxonomy, and Meta-Progression

const ClassData = preload("res://scripts/resources/ClassData.gd")
const ClassCatalog = preload("res://scripts/resources/ClassCatalog.gd")
const CharacterCreationData = preload("res://scripts/resources/CharacterCreationData.gd")
const SkillData = preload("res://scripts/resources/SkillData.gd")
const ItemData = preload("res://scripts/resources/ItemData.gd")
const InventoryComponent = preload("res://scripts/components/InventoryComponent.gd")
const BaseEntity = preload("res://scripts/entities/BaseEntity.gd")
const Player = preload("res://scripts/entities/Player.gd")

func _init() -> void:
	var scripts_to_reload = [
		"res://scripts/entities/BaseEntity.gd",
		"res://scripts/entities/Player.gd",
		"res://scripts/resources/ItemData.gd",
		"res://scripts/components/InventoryComponent.gd",
		"res://scripts/resources/SkillData.gd",
		"res://scripts/components/SkillComponent.gd",
		"res://scripts/resources/MetaProfileData.gd",
		"res://scripts/resources/CharacterCreationData.gd",
		"res://scripts/resources/ClassData.gd",
		"res://scripts/resources/ClassCatalog.gd"
	]
	for p in scripts_to_reload:
		var scr = load(p) as GDScript
		if scr:
			scr.reload()

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
	assert_eq(vagabond.exclusive_skill_id, SkillData.SkillId.IMPROVISED_SURVIVAL, "Vagabond exclusive skill is IMPROVISED_SURVIVAL")

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
	
	var sword = skills.get_skill(SkillData.SkillId.SWORDSMANSHIP)
	sword.level = 10.0 # Under 15.0 hard req
	var parry = skills.get_skill(SkillData.SkillId.PARRY)
	parry.level = 8.0  # Under 12.0 hard req
	
	var aptitude = knight.calculate_aptitude(attrs, skills)
	assert_gt(aptitude, 25.0, "Aptitude score must exceed 25.0 with strong relevant attributes")
	assert_true(knight.is_eligible(attrs, skills), "Class must unlock via Dynamic Aptitude Scoring when baseline is met")

# -----------------------------------------------------------------------------
# 2. CLASS BONUSES & EXCLUSIVE SKILL APPLICATION
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
	
	# Check class exclusive skill unlocked automatically on application
	var shield_fort = skills.get_skill(SkillData.SkillId.SHIELD_FORTIFICATION)
	assert_true(shield_fort != null, "Knight application must unlock Shield Fortification")
	assert_eq(shield_fort.level, 5.0, "Shield Fortification must start at level 5.0")
	assert_eq(shield_fort.tier, SkillData.SkillTier.CLASS_EXCLUSIVE, "Shield Fortification is CLASS_EXCLUSIVE tier")

func test_class_exclusive_skill_unlock() -> void:
	var skills_comp: SkillComponent = track(SkillComponent.new()) as SkillComponent
	assert_true(skills_comp.get_skill(SkillData.SkillId.PAIN_HARNESSING) == null, "Class exclusive skill is uninitialized initially")
	
	var data = skills_comp.unlock_class_exclusive_skill(SkillData.SkillId.PAIN_HARNESSING, 5.0)
	assert_true(data != null, "Exclusive skill must unlock successfully")
	assert_eq(data.level, 5.0, "Starts at 5.0")
	assert_eq(data.tier, SkillData.SkillTier.CLASS_EXCLUSIVE, "Must be tagged CLASS_EXCLUSIVE")
	assert_eq(data.exclusive_class_id, "berserker", "Exclusive class id is berserker")
	assert_eq(skills_comp.get_skill(SkillData.SkillId.PAIN_HARNESSING), data, "Stored in skills registry")

# -----------------------------------------------------------------------------
# 3. TRI-TIER SKILL TAXONOMY & MARKSMANSHIP REMOVAL
# -----------------------------------------------------------------------------

func test_tri_tier_skill_taxonomy() -> void:
	var starting_skills = SkillData.get_skills_by_tier(SkillData.SkillTier.STARTING)
	assert_eq(starting_skills.size(), 14, "Tier 1 must have exactly 14 Starting skills (Marksmanship removed)")
	assert_false(starting_skills.has(SkillData.SkillId.MARKSMANSHIP), "Marksmanship must NOT be in Tier 1")
	assert_true(starting_skills.has(SkillData.SkillId.ARCHERY), "Tier 1 must include Archery")
	assert_true(starting_skills.has(SkillData.SkillId.THROWING), "Tier 1 must include Throwing")
	assert_true(starting_skills.has(SkillData.SkillId.DIVINE_MAGIC), "Tier 1 must include Divine Magic")
	assert_true(starting_skills.has(SkillData.SkillId.ARCANE_MAGIC), "Tier 1 must include Arcane Magic")
	
	var meta_skills = SkillData.get_skills_by_tier(SkillData.SkillTier.META)
	assert_eq(meta_skills.size(), 5, "Tier 2 must have exactly 5 Meta skills")
	assert_true(meta_skills.has(SkillData.SkillId.MEDITATION), "Tier 2 has Meditation")
	assert_true(meta_skills.has(SkillData.SkillId.BEAST_MASTERY), "Tier 2 has Beast Mastery")
	assert_true(meta_skills.has(SkillData.SkillId.INTIMIDATION), "Tier 2 has Intimidation")
	assert_true(meta_skills.has(SkillData.SkillId.LEADERSHIP), "Tier 2 has Leadership")
	assert_true(meta_skills.has(SkillData.SkillId.SURVIVALISM), "Tier 2 has Survivalism")
	
	var exclusive_skills = SkillData.get_skills_by_tier(SkillData.SkillTier.CLASS_EXCLUSIVE)
	assert_eq(exclusive_skills.size(), 21, "Tier 3 must have exactly 21 Class-Exclusive skills")
	assert_true(exclusive_skills.has(SkillData.SkillId.SHIELD_FORTIFICATION), "Tier 3 has Shield Fortification")
	assert_true(exclusive_skills.has(SkillData.SkillId.GUN_KATA), "Tier 3 has Gun Kata")
	assert_true(exclusive_skills.has(SkillData.SkillId.ASTRAL_BLADE), "Tier 3 has Astral Blade")
	assert_true(exclusive_skills.has(SkillData.SkillId.IMPROVISED_SURVIVAL), "Tier 3 has Improvised Survival")
	
	# Helper queries
	assert_eq(SkillData.get_tier_for_skill(SkillData.SkillId.SWORDSMANSHIP), SkillData.SkillTier.STARTING, "Swordsmanship is STARTING")
	assert_eq(SkillData.get_tier_for_skill(SkillData.SkillId.MEDITATION), SkillData.SkillTier.META, "Meditation is META")
	assert_eq(SkillData.get_tier_for_skill(SkillData.SkillId.PYROMANCY), SkillData.SkillTier.CLASS_EXCLUSIVE, "Pyromancy is CLASS_EXCLUSIVE")
	assert_eq(SkillData.get_associated_attribute(SkillData.SkillId.ARCHERY), "dexterity", "Archery associated with dexterity")
	assert_eq(SkillData.get_associated_attribute(SkillData.SkillId.MEDITATION), "wisdom", "Meditation associated with wisdom")
	assert_eq(SkillData.get_exclusive_class_id(SkillData.SkillId.PYROMANCY), "elementalist", "Pyromancy exclusive to elementalist")

# -----------------------------------------------------------------------------
# 4. STARTING SKILL DRAFTING & VALIDATION (NO BACKGROUNDS)
# -----------------------------------------------------------------------------

func test_starting_skill_drafting_and_validation() -> void:
	assert_eq(CharacterCreationData.REQUIRED_STARTING_SKILLS_COUNT, 4, "Must require exactly 4 starting skills")
	assert_eq(CharacterCreationData.STARTING_ATTRIBUTE_POINTS, 20, "Must require 20 attribute points")
	
	var available = CharacterCreationData.get_available_starting_skills()
	assert_eq(available.size(), 14, "Account Rank 1 gets exactly 14 starting skills")
	
	# Valid 20 attribute points
	var valid_attrs = {
		"strength": 5,      # 4 pts
		"dexterity": 5,     # 4 pts
		"constitution": 5,  # 4 pts
		"intelligence": 4,  # 3 pts
		"wisdom": 4,        # 3 pts
		"charisma": 3       # 2 pts -> sum 20 pts
	}
	
	var valid_skills: Array[SkillData.SkillId] = [
		SkillData.SkillId.SWORDSMANSHIP,
		SkillData.SkillId.ARCHERY,
		SkillData.SkillId.DODGE,
		SkillData.SkillId.DIVINE_MAGIC
	]
	
	var res = CharacterCreationData.validate_character_creation(valid_attrs, valid_skills)
	assert_true(res["is_valid"], "Valid attributes and 4 valid skills must pass validation")
	
	# Invalid: only 3 skills
	var three_skills = [SkillData.SkillId.SWORDSMANSHIP, SkillData.SkillId.ARCHERY, SkillData.SkillId.DODGE]
	var res_three = CharacterCreationData.validate_character_creation(valid_attrs, three_skills)
	assert_false(res_three["is_valid"], "Must fail when fewer than 4 skills chosen")
	
	# Invalid: 5 skills
	var five_skills = [
		SkillData.SkillId.SWORDSMANSHIP, SkillData.SkillId.ARCHERY,
		SkillData.SkillId.DODGE, SkillData.SkillId.DIVINE_MAGIC, SkillData.SkillId.PERCEPTION
	]
	var res_five = CharacterCreationData.validate_character_creation(valid_attrs, five_skills)
	assert_false(res_five["is_valid"], "Must fail when more than 4 skills chosen")
	
	# Invalid: duplicate skill
	var dup_skills = [
		SkillData.SkillId.SWORDSMANSHIP, SkillData.SkillId.ARCHERY,
		SkillData.SkillId.DODGE, SkillData.SkillId.SWORDSMANSHIP
	]
	var res_dup = CharacterCreationData.validate_character_creation(valid_attrs, dup_skills)
	assert_false(res_dup["is_valid"], "Must fail on duplicate skill selection")
	
	# Invalid: insufficient points (19 points)
	var invalid_attrs = valid_attrs.duplicate()
	invalid_attrs["strength"] = 4
	var res_pts = CharacterCreationData.validate_character_creation(invalid_attrs, valid_skills)
	assert_false(res_pts["is_valid"], "Must fail when attribute points != 20")

# -----------------------------------------------------------------------------
# 5. EQUIPMENT MAPPING, AMMUNITION SLOT & SPELLBOOKS
# -----------------------------------------------------------------------------

func test_equipment_mapping_and_ammunition_slot() -> void:
	# 1. Archery starter gear
	var archery_items = CharacterCreationData.get_items_for_skill(SkillData.SkillId.ARCHERY)
	assert_eq(archery_items.size(), 2, "Archery grants bow and ammo")
	assert_eq(archery_items[0].item_id, "bow_recurve", "Grants Recurve Bow")
	assert_eq(archery_items[0].equip_slot, ItemData.EquipSlot.MAIN_HAND, "Bow equips in MAIN_HAND")
	assert_eq(archery_items[0].weight_stones, 2.0, "Bow weight 2.0 stones")
	assert_eq(archery_items[1].item_id, "ammo_arrows", "Grants Quiver of Arrows")
	assert_eq(archery_items[1].equip_slot, ItemData.EquipSlot.AMMUNITION, "Arrows equip in AMMUNITION slot")
	assert_eq(archery_items[1].quantity, 20, "20 arrows granted")
	assert_eq(archery_items[1].weight_stones, 1.0, "Arrows weight 1.0 stone")
	
	# 2. Throwing starter gear
	var throwing_items = CharacterCreationData.get_items_for_skill(SkillData.SkillId.THROWING)
	assert_eq(throwing_items.size(), 1, "Throwing grants knife pouch")
	assert_eq(throwing_items[0].item_id, "throwing_daggers", "Grants throwing daggers")
	assert_eq(throwing_items[0].equip_slot, ItemData.EquipSlot.AMMUNITION, "Knives equip in AMMUNITION slot")
	assert_eq(throwing_items[0].quantity, 10, "10 knives granted")
	assert_eq(throwing_items[0].weight_stones, 1.5, "Knives weight 1.5 stones")
	
	# 3. Divine Magic starter gear & Spellbook
	var divine_items = CharacterCreationData.get_items_for_skill(SkillData.SkillId.DIVINE_MAGIC)
	assert_eq(divine_items.size(), 2, "Divine grants holy symbol and spellbook")
	assert_eq(divine_items[0].item_id, "holy_symbol", "Grants Holy Symbol")
	assert_eq(divine_items[0].equip_slot, ItemData.EquipSlot.MAIN_HAND, "Holy Symbol in MAIN_HAND")
	assert_eq(divine_items[0].weight_stones, 1.0, "Holy symbol weight 1.0")
	assert_eq(divine_items[1].item_id, "spellbook_minor_heal", "Grants Spellbook of Minor Heal")
	assert_eq(divine_items[1].equip_slot, ItemData.EquipSlot.NONE, "Spellbook stays in backpack")
	assert_eq(divine_items[1].weight_stones, 1.5, "Spellbook weight 1.5")
	
	# 4. Arcane Magic starter gear & Spellbook
	var arcane_items = CharacterCreationData.get_items_for_skill(SkillData.SkillId.ARCANE_MAGIC)
	assert_eq(arcane_items.size(), 2, "Arcane grants catalyst and spellbook")
	assert_eq(arcane_items[0].item_id, "arcane_catalyst", "Grants Lapis Conduit Focus")
	assert_eq(arcane_items[0].equip_slot, ItemData.EquipSlot.MAIN_HAND, "Catalyst in MAIN_HAND")
	assert_eq(arcane_items[0].weight_stones, 1.0, "Catalyst weight 1.0")
	assert_eq(arcane_items[1].item_id, "spellbook_magic_missile", "Grants Spellbook of Magic Missile")
	assert_eq(arcane_items[1].equip_slot, ItemData.EquipSlot.NONE, "Spellbook stays in backpack")
	assert_eq(arcane_items[1].weight_stones, 1.5, "Spellbook weight 1.5")
	
	# 5. InventoryComponent Ammunition Slot support
	var inv: InventoryComponent = track(InventoryComponent.new()) as InventoryComponent
	assert_true(inv.get_equipped_ammo() == null, "Ammo slot initially empty")
	inv.equip_item(archery_items[1])
	assert_eq(inv.get_equipped_ammo(), archery_items[1], "Ammunition item equipped in AMMUNITION slot")
	
	# 6. Equipment Conflict Resolution: Archery + Throwing
	# Both have items wanting AMMUNITION slot -> Archery equipped first, Throwing placed in backpack
	var draft_skills: Array[SkillData.SkillId] = [
		SkillData.SkillId.ARCHERY,
		SkillData.SkillId.THROWING,
		SkillData.SkillId.ARCANE_MAGIC,
		SkillData.SkillId.DIVINE_MAGIC
	]
	var resolved = CharacterCreationData.resolve_starting_equipment(draft_skills)
	var eq = resolved["equipped_slots"] as Dictionary
	var bp = resolved["backpack_items"] as Array[ItemData]
	assert_true(eq.has(ItemData.EquipSlot.MAIN_HAND), "Bow equipped in MAIN_HAND")
	assert_true(eq.has(ItemData.EquipSlot.AMMUNITION), "Arrows equipped in AMMUNITION")
	assert_eq(eq[ItemData.EquipSlot.AMMUNITION].item_id, "ammo_arrows", "Arrows got the ammo slot first")
	
	# Check Throwing Knives fell back to backpack due to slot conflict
	var found_knives_in_bp = false
	for it in bp:
		if it.item_id == "throwing_daggers":
			found_knives_in_bp = true
			break
	assert_true(found_knives_in_bp, "Throwing knives placed in backpack after AMMUNITION slot occupied")
	
	# 7. Player Integration: 4 Skills @ 5.0, others @ 0.0, and Spells learned from Spellbooks
	var player_entity: Player = track(Player.new()) as Player
	var p_stats: StatsComponent = track(StatsComponent.new()) as StatsComponent
	p_stats.name = "StatsComponent"
	player_entity.add_child(p_stats)
	var p_skills: SkillComponent = track(SkillComponent.new()) as SkillComponent
	p_skills.name = "SkillComponent"
	player_entity.add_child(p_skills)
	var p_inv: InventoryComponent = track(InventoryComponent.new()) as InventoryComponent
	p_inv.name = "InventoryComponent"
	player_entity.add_child(p_inv)
	var p_spellcasting: SpellCastingComponent = track(SpellCastingComponent.new()) as SpellCastingComponent
	p_spellcasting.name = "SpellCastingComponent"
	player_entity.add_child(p_spellcasting)
	
	var creation_package = {
		"attributes": AttributesData.new(),
		"selected_skills": draft_skills,
		"starting_items": CharacterCreationData.get_starting_items_for_skills(draft_skills)
	}
	player_entity.setup_from_creation_data(creation_package)
	
	# Verify selected 4 skills are at 5.0, unselected skills are at 0.0
	assert_eq(p_skills.get_skill(SkillData.SkillId.ARCHERY).level, 5.0, "Selected Archery is at 5.0")
	assert_eq(p_skills.get_skill(SkillData.SkillId.THROWING).level, 5.0, "Selected Throwing is at 5.0")
	assert_eq(p_skills.get_skill(SkillData.SkillId.ARCANE_MAGIC).level, 5.0, "Selected Arcane Magic is at 5.0")
	assert_eq(p_skills.get_skill(SkillData.SkillId.DIVINE_MAGIC).level, 5.0, "Selected Divine Magic is at 5.0")
	assert_eq(p_skills.get_skill(SkillData.SkillId.SWORDSMANSHIP).level, 0.0, "Unselected Swordsmanship is at 0.0")
	assert_eq(p_skills.get_skill(SkillData.SkillId.PERCEPTION).level, 0.0, "Unselected Perception is at 0.0")
	
	# Verify spellbooks taught their spells to player.spell_casting
	assert_eq(p_spellcasting.known_spells.size(), 2, "Both spells learned from spellbooks")
	var has_magic_missile = false
	var has_minor_heal = false
	for sp in p_spellcasting.known_spells:
		if sp.spell_id == "magic_missile":
			has_magic_missile = true
		if sp.spell_id == "minor_heal":
			has_minor_heal = true
	assert_true(has_magic_missile, "Magic Missile learned from Spellbook of Magic Missile")
	assert_true(has_minor_heal, "Minor Heal learned from Spellbook of Minor Heal")

# -----------------------------------------------------------------------------
# 6. META PROGRESSION & ACCOUNT EXP FORMULAS (NO BACKGROUNDS)
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
	
	# Rank 2 must unlock Meditation meta skill (NO backgrounds!)
	assert_true(profile.is_meta_skill_unlocked("MEDITATION"), "Rank 2 must unlock Meditation meta skill")
	assert_true(profile.is_skill_unlocked(SkillData.SkillId.MEDITATION), "is_skill_unlocked reports true for Meditation")
	
	# Award more EXP to reach Rank 3 (req: 565 -> need 465 more EXP)
	profile.add_meta_exp(500)
	assert_eq(profile.account_rank, 3, "Account Rank must advance to 3")
	assert_true(profile.is_meta_skill_unlocked("BEAST_MASTERY"), "Rank 3 must unlock Beast Mastery meta skill")
	
	# Profile serialization migration test
	var serialized = profile.to_dict()
	assert_false(serialized.has("unlocked_background_ids"), "Serialized dictionary must not contain background IDs")
	assert_true(serialized.has("unlocked_meta_skills"), "Serialized dictionary must contain unlocked_meta_skills")
	
	var fresh_profile: MetaProfileData = track(MetaProfileData.new()) as MetaProfileData
	# Simulate backward-compatible migration with legacy background key
	var legacy_dict = serialized.duplicate()
	legacy_dict["unlocked_background_ids"] = ["veteran_mercenary"]
	fresh_profile.from_dict(legacy_dict)
	assert_eq(fresh_profile.account_rank, 3, "Restores account rank 3")
	assert_true(fresh_profile.is_meta_skill_unlocked("MEDITATION"), "Reconstructed Meditation unlock")
	assert_true(fresh_profile.is_meta_skill_unlocked("BEAST_MASTERY"), "Reconstructed Beast Mastery unlock")

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
	assert_eq(expected_exp, 715, "Expected Run EXP calculation check")
	
	var meta_mgr = _get_meta_mgr()
	var result = meta_mgr.record_run_completion(summary)
	assert_eq(result["earned_exp"], 715, "MetaManager must calculate exact Run EXP per GDD formula")

# -----------------------------------------------------------------------------
# 7. PERSISTENCE & HMAC SIGNATURE INTEGRITY
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
	if not DirAccess.dir_exists_absolute("user://saves"):
		DirAccess.make_dir_recursive_absolute("user://saves")
		
	var save_path = "user://saves/current_run.json"
	var test_file = FileAccess.open(save_path, FileAccess.WRITE)
	if test_file:
		test_file.store_string('{"test": true}')
		test_file.close()
		
	assert_true(FileAccess.file_exists(save_path), "Save file must exist prior to wipe")
	
	var wiped = game_mgr.wipe_run_save()
	assert_true(wiped, "wipe_run_save must report successful wipe")
	assert_false(FileAccess.file_exists(save_path), "Save file must be completely deleted from physical disk")

# -----------------------------------------------------------------------------
# 8. MODAL UNIT INTERACTION
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
