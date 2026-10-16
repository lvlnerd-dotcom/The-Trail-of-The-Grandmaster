class_name SpellData
extends Resource

## SpellData: Declarative definition for Arcane and Divine magic spells.

enum School {
	ARCANE,  ## Scales with Intelligence and Arcane Magic skill
	DIVINE   ## Scales with Wisdom and Divine Magic skill
}
const SpellSchool = School

enum TargetType {
	SELF,                  ## Cast directly on the caster
	SINGLE_TARGET_RANGED,  ## Targeted entity within range tiles
	AREA_EFFECT,           ## Centered tile with radius blast
	BEAM                   ## Straight line penetrating grid raycast
}

enum EffectType {
	DAMAGE,           ## Reduces target HP
	HEALING,          ## Restores target HP
	WARD_SHIELD,      ## Temporary damage absorption layer
	TELEPORT,         ## Instant spatial relocation
	STATUS_CLEANSE,   ## Removes active debuffs
	STATUS_APPLY      ## Applies buff or debuff
}
const SpellEffectType = EffectType

enum DamageType {
	FORCE,      ## Pure arcane magic (bypasses 50% physical armor soak)
	FIRE,       ## Thermal blast; burns and leaves scorch decals
	RADIANT,    ## Holy light; 2.0x multiplier vs Undead & Demonic
	PHYSICAL,   ## Kinetic impact
	COLD,       ## Cryogenic slowing effect
	LIGHTNING   ## Conductive chain damage
}

@export_group("Identity")
@export var spell_id: String = ""
@export var spell_name: String = ""
@export_multiline var description: String = ""
@export var icon_texture: Texture2D

@export_group("Magic School & Type")
@export var school: School = School.ARCANE
@export var target_type: TargetType = TargetType.SINGLE_TARGET_RANGED
@export var effect_type: EffectType = EffectType.DAMAGE
@export var damage_type: DamageType = DamageType.FORCE

@export_group("Costs & Requirements")
@export var mana_cost: float = 10.0
@export var required_skill_level: float = 0.0 ## Min effective skill level for 0% fizzle

@export_group("Range & Area")
@export var range_tiles: int = 5
@export var area_radius: int = 0:
	set(val):
		area_radius = val
		aoe_radius = val
@export var aoe_radius: int = 0:
	set(val):
		aoe_radius = val
		area_radius = val

@export_group("Potency & Duration")
@export var base_potency: float = 15.0:
	set(val):
		base_potency = val
		base_value = val
@export var base_value: float = 15.0:
	set(val):
		base_value = val
		base_potency = val

@export var duration_turns: int = 0
@export var bonus_vs_undead_mult: float = 1.0
@export var armor_penetration: float = 0.0:
	set(val):
		armor_penetration = val
		armor_penetration_ratio = val
@export var armor_penetration_ratio: float = 0.0:
	set(val):
		armor_penetration_ratio = val
		armor_penetration = val

@export_group("Visuals & Audio")
@export var vfx_color: Color = Color(0.4, 0.6, 1.0)
@export var cast_sfx: String = "spell_cast_arcane"
@export var hit_sfx: String = "spell_hit_magic"

func get_associated_attribute_name() -> String:
	match school:
		School.ARCANE:
			return "intelligence"
		School.DIVINE:
			return "wisdom"
		_:
			return "intelligence"

func get_associated_skill_id() -> SkillData.SkillId:
	match school:
		School.ARCANE:
			return SkillData.SkillId.ARCANE_MAGIC
		School.DIVINE:
			return SkillData.SkillId.DIVINE_MAGIC
		_:
			return SkillData.SkillId.ARCANE_MAGIC

# --- Initial Spell Library Factories ---

# 1. Magic Missile
static func create_magic_missile() -> SpellData:
	var spell = SpellData.new()
	spell.spell_id = "magic_missile"
	spell.spell_name = "Magic Missile"
	spell.school = School.ARCANE
	spell.target_type = TargetType.SINGLE_TARGET_RANGED
	spell.effect_type = EffectType.DAMAGE
	spell.damage_type = DamageType.FORCE
	spell.mana_cost = 8.0
	spell.range_tiles = 6
	spell.area_radius = 0
	spell.base_potency = 14.0
	spell.required_skill_level = 0.0
	spell.armor_penetration = 0.50
	spell.description = "Fires darts of raw arcane energy. Ignores 50% target armor soak."
	spell.vfx_color = Color(0.3, 0.7, 1.0)
	spell.cast_sfx = "spell_cast_arcane"
	spell.hit_sfx = "spell_hit_magic"
	return spell

# 2. Fireball
static func create_fireball() -> SpellData:
	var spell = SpellData.new()
	spell.spell_id = "fireball"
	spell.spell_name = "Fireball"
	spell.school = School.ARCANE
	spell.target_type = TargetType.AREA_EFFECT
	spell.effect_type = EffectType.DAMAGE
	spell.damage_type = DamageType.FIRE
	spell.mana_cost = 24.0
	spell.range_tiles = 7
	spell.area_radius = 1 # 3x3 blast area
	spell.base_potency = 32.0
	spell.required_skill_level = 25.0
	spell.armor_penetration = 0.0
	spell.description = "Launches an explosive sphere of flame detonating in a 3x3 area."
	spell.vfx_color = Color(1.0, 0.45, 0.1)
	spell.cast_sfx = "spell_cast_fire"
	spell.hit_sfx = "spell_hit_explosion"
	return spell

# 3. Blink
static func create_blink() -> SpellData:
	var spell = SpellData.new()
	spell.spell_id = "blink"
	spell.spell_name = "Blink"
	spell.school = School.ARCANE
	spell.target_type = TargetType.SINGLE_TARGET_RANGED
	spell.effect_type = EffectType.TELEPORT
	spell.damage_type = DamageType.FORCE
	spell.mana_cost = 15.0
	spell.range_tiles = 4
	spell.area_radius = 0
	spell.base_potency = 0.0
	spell.required_skill_level = 15.0
	spell.armor_penetration = 0.0
	spell.description = "Instantly relocates the caster to an unoccupied walkable tile within range."
	spell.vfx_color = Color(0.7, 0.3, 0.95)
	spell.cast_sfx = "spell_cast_teleport"
	spell.hit_sfx = "spell_teleport_land"
	return spell

# 4. Arcane Shield
static func create_arcane_shield() -> SpellData:
	var spell = SpellData.new()
	spell.spell_id = "arcane_shield"
	spell.spell_name = "Arcane Shield"
	spell.school = School.ARCANE
	spell.target_type = TargetType.SELF
	spell.effect_type = EffectType.WARD_SHIELD
	spell.damage_type = DamageType.FORCE
	spell.mana_cost = 18.0
	spell.range_tiles = 0
	spell.area_radius = 0
	spell.base_potency = 35.0 # 35 Ward HP
	spell.duration_turns = 10
	spell.required_skill_level = 10.0
	spell.armor_penetration = 0.0
	spell.description = "Creates a 35 HP protective ward absorbing all incoming damage before HP for 10 turns."
	spell.vfx_color = Color(0.2, 0.8, 1.0)
	spell.cast_sfx = "spell_cast_shield"
	spell.hit_sfx = "spell_ward_activate"
	return spell

# 5. Minor Heal
static func create_minor_heal() -> SpellData:
	var spell = SpellData.new()
	spell.spell_id = "minor_heal"
	spell.spell_name = "Minor Heal"
	spell.school = School.DIVINE
	spell.target_type = TargetType.SINGLE_TARGET_RANGED
	spell.effect_type = EffectType.HEALING
	spell.damage_type = DamageType.RADIANT
	spell.mana_cost = 12.0
	spell.range_tiles = 1 # Self or adjacent ally
	spell.area_radius = 0
	spell.base_potency = 25.0
	spell.required_skill_level = 0.0
	spell.armor_penetration = 0.0
	spell.description = "Restores 25 HP to self or an adjacent ally. Cannot exceed maximum HP."
	spell.vfx_color = Color(0.9, 0.9, 0.4)
	spell.cast_sfx = "spell_cast_divine"
	spell.hit_sfx = "spell_heal_impact"
	return spell

# 6. Smite
static func create_smite() -> SpellData:
	var spell = SpellData.new()
	spell.spell_id = "smite"
	spell.spell_name = "Smite"
	spell.school = School.DIVINE
	spell.target_type = TargetType.SINGLE_TARGET_RANGED
	spell.effect_type = EffectType.DAMAGE
	spell.damage_type = DamageType.RADIANT
	spell.mana_cost = 16.0
	spell.range_tiles = 4
	spell.area_radius = 0
	spell.base_potency = 22.0
	spell.bonus_vs_undead_mult = 2.0
	spell.required_skill_level = 15.0
	spell.armor_penetration = 0.0
	spell.description = "Calls down righteous radiance dealing 22 Holy damage (2.0x vs Undead and Demonic)."
	spell.vfx_color = Color(1.0, 0.95, 0.6)
	spell.cast_sfx = "spell_cast_smite"
	spell.hit_sfx = "spell_smite_impact"
	return spell

# 7. Purify
static func create_purify() -> SpellData:
	var spell = SpellData.new()
	spell.spell_id = "purify"
	spell.spell_name = "Purify"
	spell.school = School.DIVINE
	spell.target_type = TargetType.SINGLE_TARGET_RANGED
	spell.effect_type = EffectType.STATUS_CLEANSE
	spell.damage_type = DamageType.RADIANT
	spell.mana_cost = 10.0
	spell.range_tiles = 1
	spell.area_radius = 0
	spell.base_potency = 0.0
	spell.required_skill_level = 20.0
	spell.armor_penetration = 0.0
	spell.description = "Cleanses all Poison, Bleed, Weakness, Terror, and Confusion status effects."
	spell.vfx_color = Color(0.9, 1.0, 0.9)
	spell.cast_sfx = "spell_cast_cleanse"
	spell.hit_sfx = "spell_cleanse_impact"
	return spell

# 8. Divine Aegis
static func create_divine_aegis() -> SpellData:
	var spell = SpellData.new()
	spell.spell_id = "divine_aegis"
	spell.spell_name = "Divine Aegis"
	spell.school = School.DIVINE
	spell.target_type = TargetType.SELF
	spell.effect_type = EffectType.WARD_SHIELD
	spell.damage_type = DamageType.RADIANT
	spell.mana_cost = 26.0
	spell.range_tiles = 0
	spell.area_radius = 0
	spell.base_potency = 50.0 # 50 Ward HP
	spell.duration_turns = 5
	spell.required_skill_level = 30.0
	spell.armor_penetration = 0.0
	spell.description = "Grants +75% Armor soak, debuff immunity, and a 50 HP divine ward for 5 turns."
	spell.vfx_color = Color(1.0, 0.85, 0.3)
	spell.cast_sfx = "spell_cast_aegis"
	spell.hit_sfx = "spell_aegis_activate"
	return spell
