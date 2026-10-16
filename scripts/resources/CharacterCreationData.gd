class_name CharacterCreationData
extends RefCounted

## CharacterCreationData: Validates starting attributes, skills, and assigns initial equipment packages & backgrounds.

const STARTING_ATTRIBUTE_POINTS: int = 20
const MIN_ATTRIBUTE_VALUE: int = 1
const MAX_STARTING_ATTRIBUTE_CAP: int = 10
const REQUIRED_STARTING_SKILLS_COUNT: int = 4
const STARTING_SKILL_INITIAL_LEVEL: float = 5.0

# Master Background Package Definitions
const BACKGROUNDS: Dictionary = {
	"novice_adventurer": {
		"id": "novice_adventurer",
		"name": "Novice Adventurer",
		"description": "A daring seeker of fortune with balanced starting traits.",
		"attribute_bonuses": {},
		"bonus_skills": [],
		"bonus_items": []
	},
	"veteran_mercenary": {
		"id": "veteran_mercenary",
		"name": "Veteran Mercenary",
		"description": "Hardened warrior seasoned in company warfare (+2 STR, +2 CON, Broadsword & Chainmail).",
		"attribute_bonuses": {"strength": 2, "constitution": 2},
		"bonus_skills": [SkillData.SkillId.SWORDSMANSHIP],
		"bonus_items": ["sword_iron", "boots_leather"]
	},
	"shadow_syndicate": {
		"id": "shadow_syndicate",
		"name": "Shadow Syndicate",
		"description": "Underworld operative trained in covert infiltration (+3 DEX, Throwing Daggers & Chameleon Mantle).",
		"attribute_bonuses": {"dexterity": 3},
		"bonus_skills": [SkillData.SkillId.STEALTH_HIDE],
		"bonus_items": ["throwing_daggers", "cloak_shadow"]
	},
	"royal_arcanist": {
		"id": "royal_arcanist",
		"name": "Royal Arcanist",
		"description": "Court scholar of the planar weave (+3 INT, Arcane Wand & Mana Potion).",
		"attribute_bonuses": {"intelligence": 3},
		"bonus_skills": [SkillData.SkillId.ARCANE_MAGIC],
		"bonus_items": ["arcane_catalyst"]
	},
	"temple_inquisitor": {
		"id": "temple_inquisitor",
		"name": "Temple Inquisitor",
		"description": "Dogmatic pursuer of heretics and undead (+2 WIS, +1 DEX, Pistol & Ammo).",
		"attribute_bonuses": {"wisdom": 2, "dexterity": 1},
		"bonus_skills": [SkillData.SkillId.DIVINE_MAGIC, SkillData.SkillId.MARKSMANSHIP],
		"bonus_items": ["pistol_9mm", "ammo_9mm"]
	},
	"grandmaster_initiate": {
		"id": "grandmaster_initiate",
		"name": "Grandmaster Initiate",
		"description": "Bearer of the sacred mantle (+1 to all 6 attributes).",
		"attribute_bonuses": {
			"strength": 1,
			"dexterity": 1,
			"constitution": 1,
			"intelligence": 1,
			"wisdom": 1,
			"charisma": 1
		},
		"bonus_skills": [],
		"bonus_items": []
	}
}

static func _get_meta_manager() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("MetaManager")
	return null

static func get_unlocked_backgrounds() -> Array[Dictionary]:
	var meta = _get_meta_manager()
	var unlocked_ids: Array[String] = ["novice_adventurer"]
	if meta and meta.has_method("get_unlocked_backgrounds"):
		unlocked_ids = meta.get_unlocked_backgrounds()
		
	var result: Array[Dictionary] = []
	for bg_id in unlocked_ids:
		if BACKGROUNDS.has(bg_id):
			result.append(BACKGROUNDS[bg_id])
	return result

static func get_starting_skills_pool() -> Array[int]:
	var meta = _get_meta_manager()
	if meta and meta.has_method("get_starting_skills_pool"):
		return meta.get_starting_skills_pool()
		
	# Fallback default starting skills
	return [
		SkillData.SkillId.SWORDSMANSHIP,
		SkillData.SkillId.MACE_FIGHTING,
		SkillData.SkillId.POLEARMS,
		SkillData.SkillId.BRAWLING,
		SkillData.SkillId.MARKSMANSHIP,
		SkillData.SkillId.ARCHERY,
		SkillData.SkillId.THROWING,
		SkillData.SkillId.DODGE,
		SkillData.SkillId.PARRY,
		SkillData.SkillId.STEALTH_HIDE,
		SkillData.SkillId.ARCANE_MAGIC,
		SkillData.SkillId.ALCHEMY,
		SkillData.SkillId.SCHOLARSHIP,
		SkillData.SkillId.DIVINE_MAGIC,
		SkillData.SkillId.PERCEPTION
	]

static func create_default_character() -> Dictionary:
	var attributes = AttributesData.new()
	attributes.strength = 5
	attributes.dexterity = 5
	attributes.constitution = 5
	attributes.intelligence = 4
	attributes.wisdom = 3
	attributes.charisma = 4
	
	var starting_skills: Array[SkillData.SkillId] = [
		SkillData.SkillId.SWORDSMANSHIP,
		SkillData.SkillId.DODGE,
		SkillData.SkillId.PERCEPTION,
		SkillData.SkillId.ALCHEMY
	]
	
	return {
		"attributes": attributes,
		"selected_skills": starting_skills,
		"starting_items": get_starting_items_for_skills(starting_skills),
		"background": "novice_adventurer"
	}

static func apply_background(char_data: Dictionary, bg_id: String) -> Dictionary:
	if not BACKGROUNDS.has(bg_id):
		return char_data
		
	var bg = BACKGROUNDS[bg_id]
	char_data["background"] = bg_id
	
	var attrs = char_data.get("attributes") as AttributesData
	if attrs:
		var bonuses = bg.get("attribute_bonuses", {})
		for attr in bonuses.keys():
			var b = int(bonuses[attr])
			match attr.to_lower():
				"strength": attrs.strength += b
				"dexterity": attrs.dexterity += b
				"constitution": attrs.constitution += b
				"intelligence": attrs.intelligence += b
				"wisdom": attrs.wisdom += b
				"charisma": attrs.charisma += b
				
	return char_data

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

static func get_starting_items_for_skills(selected_skills: Array) -> Array[ItemData]:
	var items: Array[ItemData] = []
	for skill_id in selected_skills:
		var skill_items = get_items_for_skill(skill_id)
		items.append_array(skill_items)
	return items

static func get_items_for_skill(skill_id: SkillData.SkillId) -> Array[ItemData]:
	match skill_id:
		SkillData.SkillId.SWORDSMANSHIP:
			var sword = ItemData.new("sword_iron", "Iron Shortsword", ItemData.ItemType.WEAPON, ItemData.EquipSlot.MAIN_HAND, 2.0)
			sword.weapon_type = AttributesData.WeaponType.MELEE
			sword.base_damage_min = 3
			sword.base_damage_max = 8
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
		SkillData.SkillId.MARKSMANSHIP:
			var gun = ItemData.new("pistol_9mm", "Service 9mm Pistol", ItemData.ItemType.WEAPON, ItemData.EquipSlot.MAIN_HAND, 2.0)
			gun.weapon_type = AttributesData.WeaponType.FIREARM
			gun.base_damage_min = 4
			gun.base_damage_max = 10
			gun.range_tiles = 6
			var ammo = ItemData.new("ammo_9mm", "9mm Ammo Box (12 Rounds)", ItemData.ItemType.AMMO, ItemData.EquipSlot.NONE, 0.5)
			return [gun, ammo]
		SkillData.SkillId.ARCHERY:
			var bow = ItemData.new("bow_recurve", "Recurve Bow", ItemData.ItemType.WEAPON, ItemData.EquipSlot.MAIN_HAND, 2.0)
			bow.weapon_type = AttributesData.WeaponType.HIGH_TENSION_BOW
			bow.base_damage_min = 3
			bow.base_damage_max = 8
			bow.range_tiles = 5
			return [bow]
		SkillData.SkillId.THROWING:
			var knives = ItemData.new("throwing_daggers", "Dagger Pouch (5 Knives)", ItemData.ItemType.WEAPON, ItemData.EquipSlot.MAIN_HAND, 1.5)
			knives.weapon_type = AttributesData.WeaponType.THROWN
			knives.base_damage_min = 2
			knives.base_damage_max = 6
			knives.range_tiles = 4
			return [knives]
		SkillData.SkillId.DODGE:
			var boots = ItemData.new("boots_leather", "Lightweight Runners", ItemData.ItemType.ARMOR, ItemData.EquipSlot.ACCESSORY, 1.0)
			boots.armor_value = 1
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
			return [focus]
		SkillData.SkillId.ALCHEMY:
			var medpack = ItemData.new("medpack_combat", "Field Trauma Medpack", ItemData.ItemType.CONSUMABLE, ItemData.EquipSlot.NONE, 1.5)
			return [medpack]
		SkillData.SkillId.PERCEPTION:
			var goggles = ItemData.new("scout_optics", "Scout Night Optics", ItemData.ItemType.RELIC, ItemData.EquipSlot.HEAD, 0.8)
			return [goggles]
		_:
			var basic_relic = ItemData.new("adventurer_token", "Survivor Token", ItemData.ItemType.RELIC, ItemData.EquipSlot.ACCESSORY, 0.5)
			return [basic_relic]
