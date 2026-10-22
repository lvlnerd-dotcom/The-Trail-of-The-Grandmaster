@tool
class_name WeaponAbilityData
extends Resource

## WeaponAbilityData: Defines a weapon-unique secondary active attack unlocked at Skill Level 25.0.
## Equippable to the 10-slot bottom HotbarBar.

enum ExecutionType {
	MELEE_ADJACENT,     ## Adjacent 1-tile melee target
	MELEE_REACH,        ## Up to 2-tile reach melee target (Polearms)
	MELEE_CLEAVE_ARC,   ## Sweeps target and adjacent frontal arc tiles
	RANGED_SINGLE,      ## Manual Line-of-Fire single-target ranged attack
	RANGED_AOE,         ## Manual Line-of-Fire AoE ranged attack
	MELEE_TARGET,       ## Alias
	RANGED_TARGET,      ## Alias
	SELF_CLEAVE_AOE,    ## Alias
	LINE_PIERCE         ## Alias
}

@export var ability_id: String = ""
@export var ability_name: String = ""
@export var required_skill_id: int = 0 # SkillData.SkillId
@export var required_skill_level: float = 25.0
@export var execution_type: ExecutionType = ExecutionType.MELEE_ADJACENT
@export var damage_multiplier: float = 1.35
@export var accuracy_bonus: float = 0.10
@export var armor_penetration: float = 0.0
@export var guaranteed_crit: bool = false
@export var strike_count: int = 1
@export var range_override: int = 0
@export var area_radius: int = 0
@export var status_effect_id: String = ""
@export var status_chance: float = 0.0
@export var status_duration: int = 2
@export var self_defense_buff: float = 0.0
@export var cooldown_turns: int = 3
@export_multiline var description: String = ""

func _init(
	p_id: String = "",
	p_name: String = "",
	p_skill_id: int = 0,
	p_exec_type: ExecutionType = ExecutionType.MELEE_ADJACENT,
	p_dmg_mult: float = 1.35,
	p_acc_bonus: float = 0.10,
	p_desc: String = ""
) -> void:
	ability_id = p_id
	ability_name = p_name
	required_skill_id = p_skill_id
	execution_type = p_exec_type
	damage_multiplier = p_dmg_mult
	accuracy_bonus = p_acc_bonus
	description = p_desc

func requires_ranged_targeting() -> bool:
	return execution_type == ExecutionType.RANGED_SINGLE or execution_type == ExecutionType.RANGED_AOE or execution_type == ExecutionType.RANGED_TARGET
