class_name CompanionData
extends Resource

## CompanionData: Archetype templates and base vital/combat statistics for allied companions.

enum CompanionArchetype {
	HIRED_MERCENARY,  ## Humanoid warrior, shield block stance, high HP
	TAMED_HOUND       ## Beast ally, keen senses aura, fast, high dodge
}

@export var archetype: CompanionArchetype = CompanionArchetype.TAMED_HOUND
@export var companion_name: String = "Warhound"
@export var sprite_frames: SpriteFrames
@export var base_hp: float = 70.0
@export var base_damage_min: int = 8
@export var base_damage_max: int = 12
@export var base_armor: int = 2
@export var base_dodge: float = 25.0
@export var perception_range: int = 6
@export var attack_range: int = 1

func calculate_scaled_max_hp(attrs: AttributesData) -> int:
	var mod = attrs.get_companion_stat_modifier() if attrs else 1.0
	return int(round(base_hp * mod))

func calculate_scaled_damage_min(attrs: AttributesData) -> int:
	var mod = attrs.get_companion_stat_modifier() if attrs else 1.0
	return int(round(float(base_damage_min) * mod))

func calculate_scaled_damage_max(attrs: AttributesData) -> int:
	var mod = attrs.get_companion_stat_modifier() if attrs else 1.0
	return int(round(float(base_damage_max) * mod))

func calculate_scaled_armor(attrs: AttributesData) -> int:
	var mod = attrs.get_companion_stat_modifier() if attrs else 1.0
	return int(round(float(base_armor) * mod))

static func create_mercenary() -> CompanionData:
	var data = CompanionData.new()
	data.archetype = CompanionArchetype.HIRED_MERCENARY
	data.companion_name = "Hired Mercenary"
	data.base_hp = 100.0
	data.base_damage_min = 10
	data.base_damage_max = 15
	data.base_armor = 4
	data.base_dodge = 10.0
	data.perception_range = 5
	data.attack_range = 1
	return data

static func create_hound() -> CompanionData:
	var data = CompanionData.new()
	data.archetype = CompanionArchetype.TAMED_HOUND
	data.companion_name = "Tamed Hound"
	data.base_hp = 70.0
	data.base_damage_min = 8
	data.base_damage_max = 12
	data.base_armor = 2
	data.base_dodge = 25.0
	data.perception_range = 6
	data.attack_range = 1
	return data
