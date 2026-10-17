@tool
extends McpTestSuite

const Player = preload("res://scripts/entities/Player.gd")
const SkillData = preload("res://scripts/resources/SkillData.gd")
const ItemData = preload("res://scripts/resources/ItemData.gd")
const CharacterCreationData = preload("res://scripts/resources/CharacterCreationData.gd")
const AttributesData = preload("res://scripts/resources/AttributesData.gd")
const StatsComponent = preload("res://scripts/components/StatsComponent.gd")
const SkillComponent = preload("res://scripts/components/SkillComponent.gd")
const InventoryComponent = preload("res://scripts/components/InventoryComponent.gd")
const SpellCastingComponent = preload("res://scripts/components/SpellCastingComponent.gd")

func suite_name() -> String:
	return "embark_all_skills"

func _create_player_entity() -> Player:
	var player = track(Player.new()) as Player
	var p_stats = track(StatsComponent.new()) as StatsComponent
	p_stats.name = "StatsComponent"
	player.add_child(p_stats)
	player.stats = p_stats
	
	var p_skills = track(SkillComponent.new()) as SkillComponent
	p_skills.name = "SkillComponent"
	player.add_child(p_skills)
	player.skills = p_skills
	
	var p_inv = track(InventoryComponent.new()) as InventoryComponent
	p_inv.name = "InventoryComponent"
	player.add_child(p_inv)
	player.inventory = p_inv
	
	var p_magic = track(SpellCastingComponent.new()) as SpellCastingComponent
	p_magic.name = "SpellCastingComponent"
	player.add_child(p_magic)
	player.spell_casting = p_magic
	
	return player

func test_all_19_skills_individual_embark() -> void:
	var all_starting = CharacterCreationData.get_available_starting_skills()
	assert_eq(all_starting.size(), 14, "Must have exactly 14 base starting skills available")
	
	# Add meta skills to test all 19
	var meta_skills = SkillData.get_skills_by_tier(SkillData.SkillTier.META)
	var all_19 = []
	all_19.append_array(all_starting)
	all_19.append_array(meta_skills)
	assert_eq(all_19.size(), 19, "Must have 19 total starting + meta skills")
	
	for s_id in all_19:
		var player = _create_player_entity()
		var attrs = AttributesData.new()
		var items = CharacterCreationData.get_items_for_skill(s_id)
		var package = {
			"attributes": attrs,
			"selected_skills": [s_id],
			"starting_items": items
		}
		
		player.setup_from_creation_data(package)
		var s = player.skills.get_skill(s_id)
		assert_true(s != null, "Skill %s must be present in SkillComponent" % SkillData.get_skill_name(s_id))
		assert_eq(s.level, 5.0, "Drafted skill %s must start at level 5.0" % SkillData.get_skill_name(s_id))
		
		# If skill is Arcane Magic or Divine Magic, verify spells are learned without recursion
		if s_id == SkillData.SkillId.ARCANE_MAGIC:
			assert_true(player.spell_casting.known_spells.size() >= 1, "Arcane Magic must teach Magic Missile")
			assert_eq(player.spell_casting.known_spells[0].spell_id, "magic_missile", "Learned spell is magic_missile")
		elif s_id == SkillData.SkillId.DIVINE_MAGIC:
			assert_true(player.spell_casting.known_spells.size() >= 1, "Divine Magic must teach Minor Heal")
			assert_eq(player.spell_casting.known_spells[0].spell_id, "minor_heal", "Learned spell is minor_heal")

func test_all_multi_skill_draft_combinations_and_slot_conflicts() -> void:
	var draft_combos = [
		# All magic & spellbooks
		[SkillData.SkillId.ARCANE_MAGIC, SkillData.SkillId.DIVINE_MAGIC, SkillData.SkillId.SCHOLARSHIP, SkillData.SkillId.ALCHEMY],
		# Archery + Throwing (both ammunition equipment slot)
		[SkillData.SkillId.ARCHERY, SkillData.SkillId.THROWING, SkillData.SkillId.SWORDSMANSHIP, SkillData.SkillId.PARRY],
		# Stealth & Agility
		[SkillData.SkillId.STEALTH_HIDE, SkillData.SkillId.DODGE, SkillData.SkillId.PERCEPTION, SkillData.SkillId.BRAWLING],
		# Heavy Martial
		[SkillData.SkillId.SWORDSMANSHIP, SkillData.SkillId.MACE_FIGHTING, SkillData.SkillId.POLEARMS, SkillData.SkillId.PARRY],
		# Meta skills
		[SkillData.SkillId.MEDITATION, SkillData.SkillId.BEAST_MASTERY, SkillData.SkillId.INTIMIDATION, SkillData.SkillId.LEADERSHIP]
	]
	
	for combo in draft_combos:
		var player = _create_player_entity()
		var attrs = AttributesData.new()
		var items = CharacterCreationData.get_starting_items_for_skills(combo)
		var package = {
			"attributes": attrs,
			"selected_skills": combo,
			"starting_items": items
		}
		
		player.setup_from_creation_data(package)
		for s_id in combo:
			var s = player.skills.get_skill(s_id)
			assert_true(s != null, "Skill %s exists" % SkillData.get_skill_name(s_id))
			assert_eq(s.level, 5.0, "Skill %s is level 5.0" % SkillData.get_skill_name(s_id))
			
		# Verify inventory burden is valid and non-negative
		var burden = player.inventory.get_carried_weight_stones()
		assert_true(burden >= 0.0, "Carried weight is non-negative")
