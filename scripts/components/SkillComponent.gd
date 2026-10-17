class_name SkillComponent
extends Node

const SkillData = preload("res://scripts/resources/SkillData.gd")

## SkillComponent: Manages an entity's skill collection, active training, and keystone synergies.

signal skill_advanced(skill: SkillData, new_level: float)
signal keystone_triggered(skill: SkillData, milestone: int)

enum DefensiveMode {
	DODGE_EVADE,
	PARRY_BLOCK
}

@export var active_defensive_mode: DefensiveMode = DefensiveMode.DODGE_EVADE

# Dictionary of SkillId -> SkillData
var skills: Dictionary = {}

func _get_event_bus() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("EventBus")
	return null

func _init() -> void:
	_init_default_skills()

func _ready() -> void:
	if skills.is_empty():
		_init_default_skills()

func _init_default_skills() -> void:
	# Initialize Tier 1 Starting skills (14 skills, Marksmanship removed)
	_register_skill(SkillData.SkillId.SWORDSMANSHIP, "Swordsmanship", "strength", 0.0)
	_register_skill(SkillData.SkillId.MACE_FIGHTING, "Mace Fighting", "strength", 0.0)
	_register_skill(SkillData.SkillId.POLEARMS, "Polearms", "strength", 0.0)
	_register_skill(SkillData.SkillId.BRAWLING, "Brawling", "strength", 0.0)
	
	_register_skill(SkillData.SkillId.ARCHERY, "Archery", "dexterity", 0.0)
	_register_skill(SkillData.SkillId.THROWING, "Throwing", "dexterity", 0.0)
	_register_skill(SkillData.SkillId.DODGE, "Dodge", "dexterity", 0.0)
	_register_skill(SkillData.SkillId.PARRY, "Parry", "dexterity", 0.0)
	_register_skill(SkillData.SkillId.STEALTH_HIDE, "Stealth", "dexterity", 0.0)
	
	_register_skill(SkillData.SkillId.ARCANE_MAGIC, "Arcane Magic", "intelligence", 0.0)
	_register_skill(SkillData.SkillId.ALCHEMY, "Alchemy", "intelligence", 0.0)
	_register_skill(SkillData.SkillId.SCHOLARSHIP, "Scholarship", "intelligence", 0.0)
	
	_register_skill(SkillData.SkillId.DIVINE_MAGIC, "Divine Magic", "wisdom", 0.0)
	_register_skill(SkillData.SkillId.PERCEPTION, "Perception", "wisdom", 0.0)
	
	# Initialize Tier 2 Meta skills (5 skills, available for in-run organic training from 0.0)
	_register_skill(SkillData.SkillId.MEDITATION, "Meditation", "wisdom", 0.0)
	_register_skill(SkillData.SkillId.BEAST_MASTERY, "Beast Mastery", "charisma", 0.0)
	_register_skill(SkillData.SkillId.INTIMIDATION, "Intimidation", "charisma", 0.0)
	_register_skill(SkillData.SkillId.LEADERSHIP, "Leadership", "charisma", 0.0)
	_register_skill(SkillData.SkillId.SURVIVALISM, "Survivalism", "constitution", 0.0)

func _register_skill(id: SkillData.SkillId, skill_name: String, attr: String, initial_level: float) -> SkillData:
	var data = SkillData.new(id, skill_name, attr, initial_level)
	data.keystone_reached.connect(func(_id, milestone):
		emit_signal("keystone_triggered", data, milestone)
		var bus = _get_event_bus()
		if bus:
			bus.emit_signal("keystone_unlocked", data.skill_name, milestone)
	)
	skills[id] = data
	return data

func get_skill(id: SkillData.SkillId) -> SkillData:
	if skills.has(id):
		return skills[id]
	return null

func unlock_class_exclusive_skill(p_id: SkillData.SkillId, starting_level: float = 5.0) -> SkillData:
	if skills.has(p_id):
		return skills[p_id] # Already unlocked
		
	var skill_name = SkillData.get_skill_name(p_id)
	var attr = SkillData.get_associated_attribute(p_id)
	var class_id = SkillData.get_exclusive_class_id(p_id)
	
	var data = SkillData.new(p_id, skill_name, attr, starting_level)
	data.tier = SkillData.SkillTier.CLASS_EXCLUSIVE
	data.exclusive_class_id = class_id
	
	data.keystone_reached.connect(func(_id, milestone):
		emit_signal("keystone_triggered", data, milestone)
		var bus = _get_event_bus()
		if bus:
			bus.emit_signal("keystone_unlocked", data.skill_name, milestone)
	)
	skills[p_id] = data
	emit_signal("skill_advanced", data, starting_level)
	
	var bus = _get_event_bus()
	if bus:
		bus.emit_signal("skill_unlocked", p_id, skill_name)
		
	return data

func register_or_unlock_skill(p_id: SkillData.SkillId, starting_level: float = 0.0) -> SkillData:
	if skills.has(p_id):
		return skills[p_id]
	var s_name = SkillData.get_skill_name(p_id)
	var attr = SkillData.get_associated_attribute(p_id)
	return _register_skill(p_id, s_name, attr, starting_level)

func get_effective_level(id: SkillData.SkillId, attributes: AttributesData) -> float:
	var skill = get_skill(id)
	if not skill or not attributes:
		return 0.0
	var attr_val = _get_attribute_value(attributes, skill.associated_attribute_name)
	var base_effective = skill.get_effective_level(attr_val)
	
	# Check keystone synergies (e.g. 25 Parry grants bonus to Dodge with shield, etc.)
	var synergy_bonus = _calculate_synergy_bonus(id)
	return base_effective + synergy_bonus

func _calculate_synergy_bonus(id: SkillData.SkillId) -> float:
	var bonus = 0.0
	if id == SkillData.SkillId.DODGE:
		var parry = get_skill(SkillData.SkillId.PARRY)
		if parry and parry.level >= 25.0:
			bonus += 5.0 # Synergy bonus from Parry keystone
	elif id == SkillData.SkillId.PARRY:
		var dodge = get_skill(SkillData.SkillId.DODGE)
		if dodge and dodge.level >= 25.0:
			bonus += 5.0 # Synergy bonus from Dodge keystone
	return bonus

func train_skill(id: SkillData.SkillId, task_difficulty: float, attributes: AttributesData) -> bool:
	var skill = get_skill(id)
	if not skill or not attributes:
		return false
	
	var attr_val = _get_attribute_value(attributes, skill.associated_attribute_name)
	var int_mult = attributes.get_skill_xp_multiplier()
	
	var leveled = skill.add_usage_attempt(task_difficulty, attr_val, int_mult)
	if leveled:
		emit_signal("skill_advanced", skill, skill.level)
		var bus = _get_event_bus()
		if bus:
			bus.emit_signal("skill_xp_gained", skill.skill_name, 0.1, skill.level)
	return leveled

func toggle_defensive_mode() -> DefensiveMode:
	if active_defensive_mode == DefensiveMode.DODGE_EVADE:
		active_defensive_mode = DefensiveMode.PARRY_BLOCK
	else:
		active_defensive_mode = DefensiveMode.DODGE_EVADE
	return active_defensive_mode

func get_active_defensive_skill_id() -> SkillData.SkillId:
	if active_defensive_mode == DefensiveMode.PARRY_BLOCK:
		return SkillData.SkillId.PARRY
	return SkillData.SkillId.DODGE

func _get_attribute_value(attributes: AttributesData, attr_name: String) -> int:
	match attr_name.to_lower():
		"strength": return attributes.strength
		"dexterity": return attributes.dexterity
		"constitution": return attributes.constitution
		"intelligence": return attributes.intelligence
		"wisdom": return attributes.wisdom
		"charisma": return attributes.charisma
		_: return 10
