class_name CharacterCreationData
extends RefCounted

const SkillData = preload("res://scripts/resources/SkillData.gd")
const ItemData = preload("res://scripts/resources/ItemData.gd")

## CharacterCreationData: Validates starting attributes, skills, and assigns initial equipment packages.
## Backgrounds are 100% eliminated; characters are defined by attribute allocation and 4 chosen starting skills.

const STARTING_ATTRIBUTE_POINTS: int = 20
const MIN_ATTRIBUTE_VALUE: int = 1
const MAX_STARTING_ATTRIBUTE_CAP: int = 10
const REQUIRED_STARTING_SKILLS_COUNT: int = 4
const STARTING_SKILL_INITIAL_LEVEL: float = 5.0

static func _get_meta_manager() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("MetaManager")
	return null

static func get_available_starting_skills(meta_profile: MetaProfileData = null) -> Array[SkillData.SkillId]:
	var result: Array[SkillData.SkillId] = []
	for s in SkillData.get_skills_by_tier(SkillData.SkillTier.STARTING):
		result.append(s)
		
	var prof = meta_profile
	if not prof:
		var meta = _get_meta_manager()
		if meta and "profile" in meta and meta.profile:
			prof = meta.profile
			
	if prof:
		for meta_skill in SkillData.get_skills_by_tier(SkillData.SkillTier.META):
			if prof.is_skill_unlocked(meta_skill):
				result.append(meta_skill)
				
	return result

static func get_starting_skills_pool() -> Array[int]:
	var available = get_available_starting_skills()
	var pool: Array[int] = []
	for s in available:
		pool.append(int(s))
	return pool

static func create_default_character() -> Dictionary:
	var attributes = AttributesData.new()
	attributes.strength = 5
	attributes.dexterity = 5
	attributes.constitution = 5
	attributes.intelligence = 4
	attributes.wisdom = 4
	attributes.charisma = 3
	
	var starting_skills: Array[SkillData.SkillId] = [
		SkillData.SkillId.SWORDSMANSHIP,
		SkillData.SkillId.DODGE,
		SkillData.SkillId.PERCEPTION,
		SkillData.SkillId.ALCHEMY
	]
	
	return {
		"attributes": attributes,
		"selected_skills": starting_skills,
		"starting_items": get_starting_items_for_skills(starting_skills)
	}

static func validate_attribute_distribution(attrs: Dictionary) -> Dictionary:
	var total_allocated = 0
	var attr_names = ["strength", "dexterity", "constitution", "intelligence", "wisdom", "charisma"]
	
	for attr in attr_names:
		var val = attrs.get(attr, MIN_ATTRIBUTE_VALUE)
		if val < MIN_ATTRIBUTE_VALUE:
			return {"is_valid": false, "error": "%s cannot be less than %d" % [attr.capitalize(), MIN_ATTRIBUTE_VALUE]}
		if val > MAX_STARTING_ATTRIBUTE_CAP:
			return {"is_valid": false, "error": "%s cannot exceed starting cap of %d" % [attr.capitalize(), MAX_STARTING_ATTRIBUTE_CAP]}
		total_allocated += (val - MIN_ATTRIBUTE_VALUE)
		
	if total_allocated != STARTING_ATTRIBUTE_POINTS:
		return {
			"is_valid": false,
			"error": "Must allocate exactly %d points (currently %d)" % [STARTING_ATTRIBUTE_POINTS, total_allocated]
		}
		
	return {"is_valid": true, "error": ""}

static func validate_character_creation(attrs: Dictionary, selected_skills: Array, meta_profile: MetaProfileData = null) -> Dictionary:
	var attr_val = validate_attribute_distribution(attrs)
	if not attr_val["is_valid"]:
		return attr_val
		
	if selected_skills.size() != REQUIRED_STARTING_SKILLS_COUNT:
		return {
			"is_valid": false,
			"error": "Must choose exactly %d starting skills (currently %d)" % [REQUIRED_STARTING_SKILLS_COUNT, selected_skills.size()]
		}
		
	var available = get_available_starting_skills(meta_profile)
	var seen: Array[int] = []
	for s in selected_skills:
		var s_id = int(s)
		if not available.has(s_id):
			return {
				"is_valid": false,
				"error": "Skill %s is not available for starting selection" % SkillData.get_skill_name(s_id)
			}
		if seen.has(s_id):
			return {
				"is_valid": false,
				"error": "Duplicate skill selected: %s" % SkillData.get_skill_name(s_id)
			}
		seen.append(s_id)
		
	return {"is_valid": true, "error": ""}

static func get_starting_items_for_skills(selected_skills: Array) -> Array[ItemData]:
	var items: Array[ItemData] = []
	for skill_id in selected_skills:
		var skill_items = get_items_for_skill(skill_id)
		items.append_array(skill_items)
	return items

static func resolve_starting_equipment(selected_skills: Array) -> Dictionary:
	var equipped_slots: Dictionary = {}
	var backpack_items: Array[ItemData] = []
	var all_items = get_starting_items_for_skills(selected_skills)
	
	for item in all_items:
		if item.equip_slot != ItemData.EquipSlot.NONE and not equipped_slots.has(item.equip_slot):
			equipped_slots[item.equip_slot] = item
		else:
			backpack_items.append(item)
			
	return {
		"all_items": all_items,
		"equipped_slots": equipped_slots,
		"backpack_items": backpack_items
	}

static func get_items_for_skill(skill_id: SkillData.SkillId) -> Array[ItemData]:
	match skill_id:
		SkillData.SkillId.SWORDSMANSHIP:
			var sword = ItemData.new("sword_iron", "Iron Shortsword", ItemData.ItemType.WEAPON, ItemData.EquipSlot.MAIN_HAND, 2.0)
			sword.weapon_type = AttributesData.WeaponType.MELEE
			sword.base_damage_min = 3
			sword.base_damage_max = 8
			sword.accuracy_bonus = 0.05
			return [sword]
			
		SkillData.SkillId.MACE_FIGHTING:
			var mace = ItemData.new("mace_iron", "Flanged Mace", ItemData.ItemType.WEAPON, ItemData.EquipSlot.MAIN_HAND, 3.0)
			mace.weapon_type = AttributesData.WeaponType.MELEE
			mace.base_damage_min = 2
			mace.base_damage_max = 9
			return [mace]
			
		SkillData.SkillId.POLEARMS:
			var spear = ItemData.new("spear_militia", "Militia Spear", ItemData.ItemType.WEAPON, ItemData.EquipSlot.MAIN_HAND, 2.5)
			spear.weapon_type = AttributesData.WeaponType.MELEE
			spear.base_damage_min = 3
			spear.base_damage_max = 7
			spear.range_tiles = 2
			return [spear]
			
		SkillData.SkillId.BRAWLING:
			var knuckles = ItemData.new("knuckles_spiked", "Spiked Knuckles", ItemData.ItemType.WEAPON, ItemData.EquipSlot.MAIN_HAND, 1.0)
			knuckles.weapon_type = AttributesData.WeaponType.MELEE
			knuckles.base_damage_min = 2
			knuckles.base_damage_max = 6
			return [knuckles]
			
		SkillData.SkillId.ARCHERY:
			var bow = ItemData.new("bow_recurve", "Recurve Bow", ItemData.ItemType.WEAPON, ItemData.EquipSlot.MAIN_HAND, 2.0)
			bow.weapon_type = AttributesData.WeaponType.HIGH_TENSION_BOW
			bow.base_damage_min = 3
			bow.base_damage_max = 8
			bow.range_tiles = 5
			
			var quiver = ItemData.new("ammo_arrows", "Quiver of Arrows", ItemData.ItemType.AMMO, ItemData.EquipSlot.AMMUNITION, 1.0, 20)
			return [bow, quiver]
			
		SkillData.SkillId.THROWING:
			var knives = ItemData.new("throwing_daggers", "Dagger Pouch (10 Knives)", ItemData.ItemType.AMMO, ItemData.EquipSlot.AMMUNITION, 1.5, 10)
			knives.weapon_type = AttributesData.WeaponType.THROWN
			knives.base_damage_min = 2
			knives.base_damage_max = 6
			knives.range_tiles = 4
			return [knives]
			
		SkillData.SkillId.DODGE:
			var boots = ItemData.new("boots_leather", "Lightweight Runners", ItemData.ItemType.ARMOR, ItemData.EquipSlot.ACCESSORY, 1.0)
			boots.armor_value = 1
			boots.dodge_bonus = 0.05
			return [boots]
			
		SkillData.SkillId.PARRY:
			var buckler = ItemData.new("shield_buckler", "Steel Buckler", ItemData.ItemType.SHIELD, ItemData.EquipSlot.OFF_HAND, 2.5)
			buckler.armor_value = 2
			buckler.block_chance_bonus = 0.15
			return [buckler]
			
		SkillData.SkillId.STEALTH_HIDE:
			var cloak = ItemData.new("cloak_shadow", "Chameleon Mantle", ItemData.ItemType.ARMOR, ItemData.EquipSlot.BODY, 1.0)
			cloak.armor_value = 1
			return [cloak]
			
		SkillData.SkillId.ARCANE_MAGIC:
			var focus = ItemData.new("arcane_catalyst", "Lapis Conduit Focus", ItemData.ItemType.WEAPON, ItemData.EquipSlot.MAIN_HAND, 1.0)
			focus.weapon_type = AttributesData.WeaponType.MAGIC_FOCUS
			var spellbook = ItemData.new("spellbook_magic_missile", "Spellbook of Magic Missile", ItemData.ItemType.CONSUMABLE, ItemData.EquipSlot.NONE, 1.5)
			spellbook.set_meta("teaches_spell", "magic_missile")
			return [focus, spellbook]
			
		SkillData.SkillId.ALCHEMY:
			var medpack = ItemData.new("medpack_combat", "Field Trauma Kit", ItemData.ItemType.CONSUMABLE, ItemData.EquipSlot.NONE, 1.5)
			var antidote = ItemData.new("potion_antidote", "Antidote Flask", ItemData.ItemType.CONSUMABLE, ItemData.EquipSlot.NONE, 0.5)
			return [medpack, antidote]
			
		SkillData.SkillId.SCHOLARSHIP:
			var grimoire = ItemData.new("scholars_tome", "Ancient Scholar's Grimoire", ItemData.ItemType.RELIC, ItemData.EquipSlot.ACCESSORY, 1.5)
			return [grimoire]
			
		SkillData.SkillId.DIVINE_MAGIC:
			var holy_symbol = ItemData.new("holy_symbol", "Radiant Holy Symbol", ItemData.ItemType.WEAPON, ItemData.EquipSlot.MAIN_HAND, 1.0)
			holy_symbol.weapon_type = AttributesData.WeaponType.MAGIC_FOCUS
			var spellbook_heal = ItemData.new("spellbook_minor_heal", "Spellbook of Minor Heal", ItemData.ItemType.CONSUMABLE, ItemData.EquipSlot.NONE, 1.5)
			spellbook_heal.set_meta("teaches_spell", "minor_heal")
			return [holy_symbol, spellbook_heal]
			
		SkillData.SkillId.PERCEPTION:
			var goggles = ItemData.new("scout_optics", "Scout Night Optics", ItemData.ItemType.RELIC, ItemData.EquipSlot.HEAD, 0.8)
			return [goggles]
			
		SkillData.SkillId.MEDITATION:
			var beads = ItemData.new("prayer_beads", "Beads of Serenity", ItemData.ItemType.RELIC, ItemData.EquipSlot.ACCESSORY, 0.5)
			return [beads]
			
		SkillData.SkillId.BEAST_MASTERY:
			var whistle = ItemData.new("beast_whistle", "Tamer's Bone Whistle", ItemData.ItemType.RELIC, ItemData.EquipSlot.ACCESSORY, 0.5)
			return [whistle]
			
		SkillData.SkillId.INTIMIDATION:
			var pendant = ItemData.new("dread_pendant", "Dread Sigil Pendant", ItemData.ItemType.RELIC, ItemData.EquipSlot.ACCESSORY, 0.5)
			return [pendant]
			
		SkillData.SkillId.LEADERSHIP:
			var badge = ItemData.new("command_badge", "Commander's Tactical Badge", ItemData.ItemType.RELIC, ItemData.EquipSlot.ACCESSORY, 0.5)
			return [badge]
			
		SkillData.SkillId.SURVIVALISM:
			var kit = ItemData.new("survival_kit", "Delver's Field Kit", ItemData.ItemType.CONSUMABLE, ItemData.EquipSlot.NONE, 1.5)
			return [kit]
			
		_:
			var basic_relic = ItemData.new("adventurer_token", "Survivor Token", ItemData.ItemType.RELIC, ItemData.EquipSlot.ACCESSORY, 0.5)
			return [basic_relic]
