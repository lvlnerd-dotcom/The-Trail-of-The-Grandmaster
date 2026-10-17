class_name ClassCatalog
extends RefCounted

## ClassCatalog: Master registry and factory for all 21 post-Floor 2 class specializations.

static var _cached_classes: Array[ClassData] = []

static func get_all_classes() -> Array[ClassData]:
	if not _cached_classes.is_empty():
		return _cached_classes
		
	var list: Array[ClassData] = []
	
	# -------------------------------------------------------------
	# 1. MARTIAL / WARRIOR ARCHETYPE
	# -------------------------------------------------------------
	var knight = ClassData.new("knight", "Knight", ClassData.Archetype.MARTIAL, "Heavy armor vanguard and unyielding bulwark.")
	knight.required_attributes = {"strength": 14, "constitution": 12}
	knight.required_skills = {SkillData.SkillId.SWORDSMANSHIP: 15.0, SkillData.SkillId.PARRY: 12.0}
	knight.attribute_bonuses = {"strength": 2, "constitution": 1}
	knight.passive_title = "Bulwark Aegis"
	knight.passive_description = "+25% Armor soak from all equipped armor; allies take 20% less damage."
	knight.passive_type = "armor_soak_mult"
	knight.passive_values = {"armor_mult": 1.25, "ally_protect": 0.20}
	knight.signature_ability_name = "Shield Bash"
	knight.signature_ability_description = "Strike with shield, dealing armor-based physical damage and stunning for 1 turn."
	knight.exclusive_skill_id = SkillData.SkillId.SHIELD_FORTIFICATION
	list.append(knight)
	
	var berserker = ClassData.new("berserker", "Berserker", ClassData.Archetype.MARTIAL, "Unrestrained fury converting wounds into lethal momentum.")
	berserker.required_attributes = {"strength": 16, "constitution": 10}
	berserker.required_skills = {SkillData.SkillId.MACE_FIGHTING: 15.0, SkillData.SkillId.BRAWLING: 10.0}
	berserker.attribute_bonuses = {"strength": 3}
	berserker.passive_title = "Blood Rage"
	berserker.passive_description = "+1% bonus damage for every 2% missing health; immune to pain stun."
	berserker.passive_type = "blood_rage"
	berserker.passive_values = {"dmg_per_missing_hp_pct": 0.50}
	berserker.signature_ability_name = "Frenzy Strike"
	berserker.signature_ability_description = "Unleash a flurry of 2 rapid strikes at the cost of 5% current HP."
	berserker.exclusive_skill_id = SkillData.SkillId.PAIN_HARNESSING
	list.append(berserker)
	
	var duelist = ClassData.new("duelist", "Duelist", ClassData.Archetype.MARTIAL, "Finesse blade master punishing missed hostile attacks.")
	duelist.required_attributes = {"dexterity": 14, "strength": 12}
	duelist.required_skills = {SkillData.SkillId.SWORDSMANSHIP: 15.0, SkillData.SkillId.DODGE: 15.0}
	duelist.attribute_bonuses = {"dexterity": 2, "strength": 1}
	duelist.passive_title = "Riposte"
	duelist.passive_description = "35% chance to immediately counter-attack for full damage upon dodging an attack."
	duelist.passive_type = "riposte"
	duelist.passive_values = {"riposte_chance": 0.35}
	duelist.signature_ability_name = "Flourish"
	duelist.signature_ability_description = "Execute a disorienting strike that forces defender into disadvantage."
	duelist.exclusive_skill_id = SkillData.SkillId.RIPOSTE_FINESSE
	list.append(duelist)
	
	var weapon_master = ClassData.new("weapon_master", "Weapon Master", ClassData.Archetype.MARTIAL, "Universal combatant proficient across all armaments.")
	weapon_master.required_attributes = {"strength": 14, "dexterity": 14}
	weapon_master.min_weapon_skills_count = 2
	weapon_master.min_weapon_skills_level = 12.0
	weapon_master.attribute_bonuses = {"strength": 1, "dexterity": 1, "constitution": 1}
	weapon_master.passive_title = "Arsenal Fluidity"
	weapon_master.passive_description = "+15% damage across all melee/ranged weapons; weapon swapping is free."
	weapon_master.passive_type = "all_weapon_bonus"
	weapon_master.passive_values = {"all_weapon_dmg_mult": 1.15}
	weapon_master.signature_ability_name = "Whirlwind"
	weapon_master.signature_ability_description = "Sweep your equipped weapon in a 360-degree arc around yourself."
	weapon_master.exclusive_skill_id = SkillData.SkillId.WEAPON_SYNTHESIS
	list.append(weapon_master)

	# -------------------------------------------------------------
	# 2. ROGUE / RANGED ARCHETYPE
	# -------------------------------------------------------------
	var assassin = ClassData.new("assassin", "Assassin", ClassData.Archetype.ROGUE_RANGED, "Lethal shadow stalker dealing devastating opening crits.")
	assassin.required_attributes = {"dexterity": 16, "intelligence": 10}
	assassin.required_skills = {SkillData.SkillId.STEALTH_HIDE: 18.0, SkillData.SkillId.SWORDSMANSHIP: 12.0}
	assassin.attribute_bonuses = {"dexterity": 3}
	assassin.passive_title = "Executioner"
	assassin.passive_description = "Attacking from stealth or behind guarantees multi-crit at 3.0x damage."
	assassin.passive_type = "stealth_crit_mult"
	assassin.passive_values = {"stealth_crit_multiplier": 3.0}
	assassin.signature_ability_name = "Smoke Vanish"
	assassin.signature_ability_description = "Instantly enter stealth mode and break line of sight."
	assassin.exclusive_skill_id = SkillData.SkillId.ASSASSINATION
	list.append(assassin)
	
	var ranger = ClassData.new("ranger", "Ranger", ClassData.Archetype.ROGUE_RANGED, "Wilderness archer dominating long-distance engagements.")
	ranger.required_attributes = {"dexterity": 15, "wisdom": 12}
	ranger.required_skills = {SkillData.SkillId.ARCHERY: 16.0, SkillData.SkillId.PERCEPTION: 14.0}
	ranger.attribute_bonuses = {"dexterity": 2, "wisdom": 1}
	ranger.passive_title = "Far Shot"
	ranger.passive_description = "+2 Maximum bow range; +20% bonus damage when target is > 4 tiles away."
	ranger.passive_type = "far_shot"
	ranger.passive_values = {"bonus_range": 2, "distance_dmg_bonus": 1.20}
	ranger.signature_ability_name = "Pinning Shot"
	ranger.signature_ability_description = "Fire an arrow pinning target to the ground, immobilizing them for 2 turns."
	ranger.exclusive_skill_id = SkillData.SkillId.BALLISTICS
	list.append(ranger)
	
	var gunslinger = ClassData.new("gunslinger", "Gunslinger", ClassData.Archetype.ROGUE_RANGED, "Frontier shootist with rapid firearm trigger dexterity.")
	gunslinger.required_attributes = {"dexterity": 16, "charisma": 10}
	gunslinger.required_skills = {SkillData.SkillId.ARCHERY: 16.0, SkillData.SkillId.DODGE: 10.0}
	gunslinger.attribute_bonuses = {"dexterity": 3}
	gunslinger.passive_title = "Quick Draw"
	gunslinger.passive_description = "+25% firearm critical strike chance; firearm crits intimidate nearby foes."
	gunslinger.passive_type = "firearm_crit_boost"
	gunslinger.passive_values = {"firearm_crit_bonus": 0.25}
	gunslinger.signature_ability_name = "Fan the Hammer"
	gunslinger.signature_ability_description = "Discharge 3 rapid shots at random targets in your frontal cone."
	gunslinger.exclusive_skill_id = SkillData.SkillId.GUN_KATA
	list.append(gunslinger)
	
	var shadow_stalker = ClassData.new("shadow_stalker", "Shadow Stalker", ClassData.Archetype.ROGUE_RANGED, "Infiltrator weaving between physical and planar shadows.")
	shadow_stalker.required_attributes = {"dexterity": 14, "intelligence": 12}
	shadow_stalker.required_skills = {SkillData.SkillId.STEALTH_HIDE: 16.0, SkillData.SkillId.ARCANE_MAGIC: 10.0}
	shadow_stalker.attribute_bonuses = {"dexterity": 2, "intelligence": 1}
	shadow_stalker.passive_title = "Shadow Step"
	shadow_stalker.passive_description = "Moving between darkened tiles takes 0 turns once every 8 turns."
	shadow_stalker.passive_type = "shadow_step"
	shadow_stalker.passive_values = {"cooldown_turns": 8}
	shadow_stalker.signature_ability_name = "Shadow Cloak"
	shadow_stalker.signature_ability_description = "Gain +50 Hide rating and move through occupied enemy tiles for 3 turns."
	shadow_stalker.exclusive_skill_id = SkillData.SkillId.UMBRAL_PHASING
	list.append(shadow_stalker)

	# -------------------------------------------------------------
	# 3. ARCANE ARCHETYPE
	# -------------------------------------------------------------
	var elementalist = ClassData.new("elementalist", "Elementalist", ClassData.Archetype.ARCANE, "Master of destructive planar fire, frost, and lightning.")
	elementalist.required_attributes = {"intelligence": 16, "wisdom": 10}
	elementalist.required_skills = {SkillData.SkillId.ARCANE_MAGIC: 18.0, SkillData.SkillId.SCHOLARSHIP: 12.0}
	elementalist.attribute_bonuses = {"intelligence": 3}
	elementalist.passive_title = "Prismatic Force"
	elementalist.passive_description = "Area of effect spells gain +1 radius; elemental damage increased by +25%."
	elementalist.passive_type = "aoe_radius_boost"
	elementalist.passive_values = {"aoe_bonus_radius": 1, "elemental_dmg_mult": 1.25}
	elementalist.signature_ability_name = "Elemental Nova"
	elementalist.signature_ability_description = "Detonate a ring of frost and fire around yourself dealing 40 damage."
	elementalist.exclusive_skill_id = SkillData.SkillId.PYROMANCY
	list.append(elementalist)
	
	var battlemage = ClassData.new("battlemage", "Battlemage", ClassData.Archetype.ARCANE, "Armored caster channeling arcane energy through martial steel.")
	battlemage.required_attributes = {"intelligence": 14, "strength": 14}
	battlemage.required_skills = {SkillData.SkillId.ARCANE_MAGIC: 15.0, SkillData.SkillId.SWORDSMANSHIP: 12.0}
	battlemage.attribute_bonuses = {"intelligence": 2, "strength": 1}
	battlemage.passive_title = "Arcane Conduit"
	battlemage.passive_description = "25% of all melee damage dealt is converted into restored Mana."
	battlemage.passive_type = "mana_leech_melee"
	battlemage.passive_values = {"mana_leech_ratio": 0.25}
	battlemage.signature_ability_name = "Arcane Cleave"
	battlemage.signature_ability_description = "Infuse blade with force energy, hitting all 3 tiles directly in front."
	battlemage.exclusive_skill_id = SkillData.SkillId.SPELL_FORGING
	list.append(battlemage)
	
	var chronomancer = ClassData.new("chronomancer", "Chronomancer", ClassData.Archetype.ARCANE, "Manipulator of temporal streams and spatial coordinates.")
	chronomancer.required_attributes = {"intelligence": 16, "wisdom": 12}
	chronomancer.required_skills = {SkillData.SkillId.ARCANE_MAGIC: 16.0, SkillData.SkillId.MEDITATION: 12.0}
	chronomancer.attribute_bonuses = {"intelligence": 2, "wisdom": 1}
	chronomancer.passive_title = "Temporal Slip"
	chronomancer.passive_description = "Once per floor, fatal damage is negated, rewinding position and HP 3 turns."
	chronomancer.passive_type = "cheat_death_rewind"
	chronomancer.passive_values = {"rewind_turns": 3}
	chronomancer.signature_ability_name = "Time Dilation"
	chronomancer.signature_ability_description = "Freeze all enemy actions on the floor for 2 full turns."
	chronomancer.exclusive_skill_id = SkillData.SkillId.TEMPORAL_WARPING
	list.append(chronomancer)
	
	var necromancer = ClassData.new("necromancer", "Necromancer", ClassData.Archetype.ARCANE, "Forbidden scholar raising slain foes as loyal undead thralls.")
	necromancer.required_attributes = {"intelligence": 15, "charisma": 12}
	necromancer.required_skills = {SkillData.SkillId.ARCANE_MAGIC: 16.0, SkillData.SkillId.BEAST_MASTERY: 10.0}
	necromancer.attribute_bonuses = {"intelligence": 2, "charisma": 1}
	necromancer.passive_title = "Soul Harvest"
	necromancer.passive_description = "Defeating biological enemies restores 10% max HP and summons a skeleton companion."
	necromancer.passive_type = "soul_harvest"
	necromancer.passive_values = {"hp_leech_on_kill": 0.10}
	necromancer.signature_ability_name = "Death Cloud"
	necromancer.signature_ability_description = "Spread noxious miasma dealing necrotic damage to all living entities."
	necromancer.exclusive_skill_id = SkillData.SkillId.NECROMANTIC_SIPHON
	list.append(necromancer)

	# -------------------------------------------------------------
	# 4. DIVINE / FAITH ARCHETYPE
	# -------------------------------------------------------------
	var paladin = ClassData.new("paladin", "Paladin", ClassData.Archetype.DIVINE, "Holy crusader smiting undead and guarding the righteous.")
	paladin.required_attributes = {"wisdom": 14, "strength": 14}
	paladin.required_skills = {SkillData.SkillId.DIVINE_MAGIC: 14.0, SkillData.SkillId.SWORDSMANSHIP: 12.0}
	paladin.attribute_bonuses = {"wisdom": 2, "strength": 1}
	paladin.passive_title = "Holy Retribution"
	paladin.passive_description = "Melee strikes deal +35% bonus Radiant damage (doubled to +70% vs Undead/Demons)."
	paladin.passive_type = "radiant_melee_infusion"
	paladin.passive_values = {"bonus_radiant_ratio": 0.35}
	paladin.signature_ability_name = "Lay on Hands"
	paladin.signature_ability_description = "Instantly restore 50% max HP to self or adjacent companion."
	paladin.exclusive_skill_id = SkillData.SkillId.HOLY_SMITING
	list.append(paladin)
	
	var templar = ClassData.new("templar", "Templar", ClassData.Archetype.DIVINE, "Shield-bearing champion immune to corruption and mental despair.")
	templar.required_attributes = {"wisdom": 14, "constitution": 14}
	templar.required_skills = {SkillData.SkillId.DIVINE_MAGIC: 12.0, SkillData.SkillId.PARRY: 15.0}
	templar.attribute_bonuses = {"wisdom": 2, "constitution": 1}
	templar.passive_title = "Incorruptible Shield"
	templar.passive_description = "Immune to Terror and Confusion debuffs; Divine Ward shields absorb +30% more."
	templar.passive_type = "ward_boost_debuff_immunity"
	templar.passive_values = {"ward_hp_mult": 1.30}
	templar.signature_ability_name = "Holy Bastion"
	templar.signature_ability_description = "Erect an impassable divine barrier for 4 turns."
	templar.exclusive_skill_id = SkillData.SkillId.SACRED_BULWARK
	list.append(templar)
	
	var inquisitor = ClassData.new("inquisitor", "Inquisitor", ClassData.Archetype.DIVINE, "Relentless hunter of heretics, occultists, and hidden perils.")
	inquisitor.required_attributes = {"wisdom": 15, "dexterity": 12}
	inquisitor.required_skills = {SkillData.SkillId.DIVINE_MAGIC: 14.0, SkillData.SkillId.PERCEPTION: 14.0}
	inquisitor.attribute_bonuses = {"wisdom": 2, "dexterity": 1}
	inquisitor.passive_title = "Brand of the Heretic"
	inquisitor.passive_description = "+30% damage against spellcasters; Perception checks reveal traps 2 tiles further."
	inquisitor.passive_type = "inquisitor_sense"
	inquisitor.passive_values = {"caster_bonus_dmg": 1.30, "bonus_perception_tiles": 2}
	inquisitor.signature_ability_name = "Silence Heresy"
	inquisitor.signature_ability_description = "Silence target spellcaster for 4 turns, preventing all mana expenditure."
	inquisitor.exclusive_skill_id = SkillData.SkillId.WITCH_PURGING
	list.append(inquisitor)
	
	var high_priest = ClassData.new("high_priest", "High Priest", ClassData.Archetype.DIVINE, "Supreme conduit of divine benevolence and healing miracles.")
	high_priest.required_attributes = {"wisdom": 16, "charisma": 12}
	high_priest.required_skills = {SkillData.SkillId.DIVINE_MAGIC: 18.0, SkillData.SkillId.MEDITATION: 15.0}
	high_priest.attribute_bonuses = {"wisdom": 3}
	high_priest.passive_title = "Divine Grace"
	high_priest.passive_description = "Healing spells overheal into temporary divine barrier shields; Mana cost -20%."
	high_priest.passive_type = "overheal_shield"
	high_priest.passive_values = {"mana_cost_reduction": 0.20}
	high_priest.signature_ability_name = "Sanctuary"
	high_priest.signature_ability_description = "Bless the current room, creating a consecrated zone where undead take holy damage."
	high_priest.exclusive_skill_id = SkillData.SkillId.DIVINE_MIRACLES
	list.append(high_priest)

	# -------------------------------------------------------------
	# 5. HYBRID / UNIQUE ARCHETYPE
	# -------------------------------------------------------------
	var spellblade = ClassData.new("spellblade", "Spellblade", ClassData.Archetype.HYBRID, "Acrobatic sword-mage weaving spells seamlessly into blade combos.")
	spellblade.required_attributes = {"intelligence": 14, "dexterity": 14}
	spellblade.required_skills = {SkillData.SkillId.ARCANE_MAGIC: 12.0, SkillData.SkillId.SWORDSMANSHIP: 14.0}
	spellblade.attribute_bonuses = {"intelligence": 2, "dexterity": 1}
	spellblade.passive_title = "Infused Steel"
	spellblade.passive_description = "Successful melee strikes launch a free Magic Missile at an adjacent target."
	spellblade.passive_type = "magic_missile_on_hit"
	spellblade.passive_values = {"proc_chance": 0.50}
	spellblade.signature_ability_name = "Blink Strike"
	spellblade.signature_ability_description = "Teleport behind target and strike immediately with critical advantage."
	spellblade.exclusive_skill_id = SkillData.SkillId.ASTRAL_BLADE
	list.append(spellblade)
	
	var witch_hunter = ClassData.new("witch_hunter", "Witch Hunter", ClassData.Archetype.HYBRID, "Alchemical tracker deploying silver ammo and cleansing decoctions.")
	witch_hunter.required_attributes = {"wisdom": 13, "dexterity": 13}
	witch_hunter.required_skills = {SkillData.SkillId.ALCHEMY: 15.0, SkillData.SkillId.THROWING: 12.0}
	witch_hunter.attribute_bonuses = {"wisdom": 1, "dexterity": 1, "constitution": 1}
	witch_hunter.passive_title = "Purifying Salt"
	witch_hunter.passive_description = "Thrown items and traps deal +50% damage against magical or demon foes."
	witch_hunter.passive_type = "anti_magic_items"
	witch_hunter.passive_values = {"item_dmg_bonus": 1.50}
	witch_hunter.signature_ability_name = "Holy Water Flask"
	witch_hunter.signature_ability_description = "Hurl an alchemical vial dealing radiant splash damage in a 3x3 tile area."
	witch_hunter.exclusive_skill_id = SkillData.SkillId.TOXICOLOGY
	list.append(witch_hunter)
	
	var monk = ClassData.new("monk", "Monk", ClassData.Archetype.HYBRID, "Disciplined martial artist channeling inner spiritual Ki.")
	monk.required_attributes = {"wisdom": 14, "dexterity": 14}
	monk.required_skills = {SkillData.SkillId.BRAWLING: 16.0, SkillData.SkillId.DODGE: 14.0}
	monk.attribute_bonuses = {"wisdom": 2, "dexterity": 1}
	monk.passive_title = "Flowing Water"
	monk.passive_description = "Gain +1 Armor per 2 WIS when unencumbered; unarmed brawling multi-crits at 2.5x."
	monk.passive_type = "unarmored_wisdom_defense"
	monk.passive_values = {"unarmed_crit_mult": 2.5}
	monk.signature_ability_name = "Ki Palm"
	monk.signature_ability_description = "Deliver a concussive shockwave knocking target back 3 tiles."
	monk.exclusive_skill_id = SkillData.SkillId.KI_STRIKES
	list.append(monk)
	
	var grandmaster_initiate = ClassData.new("grandmaster_initiate", "Grandmaster Initiate", ClassData.Archetype.HYBRID, "Aspiring avatar cultivating perfect harmony across all paths.")
	grandmaster_initiate.required_attributes = {"strength": 11, "dexterity": 11, "constitution": 11, "intelligence": 11, "wisdom": 11, "charisma": 11}
	grandmaster_initiate.attribute_bonuses = {"strength": 1, "dexterity": 1, "constitution": 1, "intelligence": 1, "wisdom": 1, "charisma": 1}
	grandmaster_initiate.passive_title = "Omni-Discipline"
	grandmaster_initiate.passive_description = "+35% skill training XP across all skills; +1 to all six core attributes."
	grandmaster_initiate.passive_type = "omni_discipline"
	grandmaster_initiate.passive_values = {"skill_xp_mult": 1.35}
	grandmaster_initiate.signature_ability_name = "Focus of the Grandmaster"
	grandmaster_initiate.signature_ability_description = "For 5 turns, all attacks multi-crit and all spells cost 0 mana."
	grandmaster_initiate.exclusive_skill_id = SkillData.SkillId.GRANDMASTER_SYNTHESIS
	list.append(grandmaster_initiate)

	# -------------------------------------------------------------
	# 6. GENERAL / FALLBACK CLASS
	# -------------------------------------------------------------
	var vagabond = ClassData.new("vagabond", "Vagabond / Adventurer", ClassData.Archetype.GENERAL, "Resilient explorer adaptable to the harsh depths of the Trail.")
	vagabond.attribute_bonuses = {"strength": 1, "constitution": 1, "dexterity": 1}
	vagabond.passive_title = "Scavenger's Resilience"
	vagabond.passive_description = "+20% Gold and consumable find; +15 Carry weight stones; always available."
	vagabond.passive_type = "scavenger"
	vagabond.passive_values = {"carry_capacity_stones": 15, "gold_find_bonus": 1.20}
	vagabond.signature_ability_name = "Second Wind"
	vagabond.signature_ability_description = "Recover 25% max HP and 25% max Mana; usable once per floor."
	vagabond.exclusive_skill_id = SkillData.SkillId.IMPROVISED_SURVIVAL
	list.append(vagabond)
	
	_cached_classes = list
	return _cached_classes

static func get_class_by_id(target_id: String) -> ClassData:
	var all = get_all_classes()
	for c in all:
		if c.class_id == target_id:
			return c
	return null

static func get_eligible_classes(attrs: AttributesData, skills: SkillComponent) -> Array[ClassData]:
	var eligible: Array[ClassData] = []
	var all = get_all_classes()
	for c in all:
		if c.is_eligible(attrs, skills):
			eligible.append(c)
	return eligible
