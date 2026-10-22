class_name CompanionData
extends Resource

## CompanionData: Archetype templates, mercenary rosters, and base combat statistics for allied companions.

enum CompanionArchetype {
	HIRED_MERCENARY,  ## Humanoid warrior, shield block stance, high HP
	TAMED_HOUND       ## Beast ally, keen senses aura, fast, high dodge
}

@export var archetype: CompanionArchetype = CompanionArchetype.TAMED_HOUND
@export var companion_name: String = "Warhound"
@export var companion_id: String = ""
@export var subtype: String = ""
@export var sprite_frames: SpriteFrames
@export var depth_tier: int = 1
@export var hire_cost_gold: int = 60
@export var is_ranged: bool = false
@export var base_hp: float = 70.0
@export var base_damage_min: int = 8
@export var base_damage_max: int = 12
@export var base_armor: int = 2
@export var base_dodge: float = 25.0
@export var perception_range: int = 6
@export var attack_range: int = 1

static func get_tier_multiplier(tier: int) -> float:
	return 1.0 + (clampi(tier, 1, 5) - 1) * 0.35

static func calculate_hire_cost(tier: int, mercantile_mod: float) -> int:
	return maxi(25, int(round(60.0 * float(clampi(tier, 1, 5)) / maxf(0.01, mercantile_mod))))

func calculate_scaled_max_hp(attrs: AttributesData) -> int:
	var tier_mult = get_tier_multiplier(depth_tier)
	var cha_mod = attrs.get_companion_stat_modifier() if attrs else 1.0
	return int(round(base_hp * tier_mult * cha_mod))

func calculate_scaled_damage_min(attrs: AttributesData) -> int:
	var tier_mult = get_tier_multiplier(depth_tier)
	var cha_mod = attrs.get_companion_stat_modifier() if attrs else 1.0
	return int(round(float(base_damage_min) * tier_mult * cha_mod))

func calculate_scaled_damage_max(attrs: AttributesData) -> int:
	var tier_mult = get_tier_multiplier(depth_tier)
	var cha_mod = attrs.get_companion_stat_modifier() if attrs else 1.0
	return int(round(float(base_damage_max) * tier_mult * cha_mod))

func calculate_scaled_armor(attrs: AttributesData) -> int:
	var tier_mult = get_tier_multiplier(depth_tier)
	var cha_mod = attrs.get_companion_stat_modifier() if attrs else 1.0
	return int(round(float(base_armor) * tier_mult * cha_mod))

# --- Standard Baseline Templates ---

static func create_mercenary() -> CompanionData:
	var data = CompanionData.new()
	data.archetype = CompanionArchetype.HIRED_MERCENARY
	data.companion_name = "Hired Mercenary"
	data.companion_id = "mercenary_generic"
	data.depth_tier = 1
	data.base_hp = 100.0
	data.base_damage_min = 10
	data.base_damage_max = 15
	data.base_armor = 4
	data.base_dodge = 10.0
	data.perception_range = 5
	data.attack_range = 1
	data.hire_cost_gold = 60
	return data

static func create_hound() -> CompanionData:
	var data = CompanionData.new()
	data.archetype = CompanionArchetype.TAMED_HOUND
	data.companion_name = "Tamed Hound"
	data.companion_id = "hound_generic"
	data.depth_tier = 1
	data.base_hp = 70.0
	data.base_damage_min = 8
	data.base_damage_max = 12
	data.base_armor = 2
	data.base_dodge = 25.0
	data.perception_range = 6
	data.attack_range = 1
	return data

# --- Milestone 5: 5 Specialized Mercenary Templates ---

static func create_vanguard_shieldsman(tier: int = 1) -> CompanionData:
	var data = CompanionData.new()
	data.archetype = CompanionArchetype.HIRED_MERCENARY
	data.companion_id = "vanguard_shieldsman"
	data.subtype = "vanguard_shieldsman"
	data.companion_name = "Vanguard Shieldsman"
	data.depth_tier = clampi(tier, 1, 5)
	data.base_hp = 120.0
	data.base_damage_min = 10
	data.base_damage_max = 14
	data.base_armor = 6
	data.base_dodge = 10.0
	data.perception_range = 5
	data.attack_range = 1
	data.is_ranged = false
	data.hire_cost_gold = calculate_hire_cost(tier, 1.0)
	return data

static func create_ironwood_marksman(tier: int = 1) -> CompanionData:
	var data = CompanionData.new()
	data.archetype = CompanionArchetype.HIRED_MERCENARY
	data.companion_id = "ironwood_marksman"
	data.subtype = "ironwood_marksman"
	data.companion_name = "Ironwood Marksman"
	data.depth_tier = clampi(tier, 1, 5)
	data.base_hp = 80.0
	data.base_damage_min = 12
	data.base_damage_max = 16
	data.base_armor = 3
	data.base_dodge = 15.0
	data.perception_range = 7
	data.attack_range = 5
	data.is_ranged = true
	data.hire_cost_gold = calculate_hire_cost(tier, 1.0)
	return data

static func create_halberdier_veteran(tier: int = 1) -> CompanionData:
	var data = CompanionData.new()
	data.archetype = CompanionArchetype.HIRED_MERCENARY
	data.companion_id = "halberdier_veteran"
	data.subtype = "halberdier_veteran"
	data.companion_name = "Halberdier Veteran"
	data.depth_tier = clampi(tier, 1, 5)
	data.base_hp = 100.0
	data.base_damage_min = 14
	data.base_damage_max = 20
	data.base_armor = 4
	data.base_dodge = 15.0
	data.perception_range = 6
	data.attack_range = 1
	data.is_ranged = false
	data.hire_cost_gold = calculate_hire_cost(tier, 1.0)
	return data

static func create_sun_sworn_acolyte(tier: int = 1) -> CompanionData:
	var data = CompanionData.new()
	data.archetype = CompanionArchetype.HIRED_MERCENARY
	data.companion_id = "sun_sworn_acolyte"
	data.subtype = "sun_sworn_acolyte"
	data.companion_name = "Sun-Sworn Acolyte"
	data.depth_tier = clampi(tier, 1, 5)
	data.base_hp = 110.0
	data.base_damage_min = 10
	data.base_damage_max = 15
	data.base_armor = 5
	data.base_dodge = 10.0
	data.perception_range = 6
	data.attack_range = 1
	data.is_ranged = false
	data.hire_cost_gold = calculate_hire_cost(tier, 1.0)
	return data

static func create_duskblade_cutthroat(tier: int = 1) -> CompanionData:
	var data = CompanionData.new()
	data.archetype = CompanionArchetype.HIRED_MERCENARY
	data.companion_id = "duskblade_cutthroat"
	data.subtype = "duskblade_cutthroat"
	data.companion_name = "Duskblade Cutthroat"
	data.depth_tier = clampi(tier, 1, 5)
	data.base_hp = 75.0
	data.base_damage_min = 12
	data.base_damage_max = 18
	data.base_armor = 2
	data.base_dodge = 35.0
	data.perception_range = 6
	data.attack_range = 1
	data.is_ranged = false
	data.hire_cost_gold = calculate_hire_cost(tier, 1.0)
	return data

static func create_mercenary_for_tier(tier: int = 1, subtype: String = "") -> CompanionData:
	var sub = subtype.to_lower().strip_edges()
	match sub:
		"vanguard_shieldsman", "vanguard":
			return create_vanguard_shieldsman(tier)
		"ironwood_marksman", "marksman":
			return create_ironwood_marksman(tier)
		"halberdier_veteran", "halberdier":
			return create_halberdier_veteran(tier)
		"sun_sworn_acolyte", "acolyte":
			return create_sun_sworn_acolyte(tier)
		"duskblade_cutthroat", "cutthroat":
			return create_duskblade_cutthroat(tier)
		_:
			var options = ["vanguard_shieldsman", "ironwood_marksman", "halberdier_veteran", "sun_sworn_acolyte", "duskblade_cutthroat"]
			var picked = options[randi() % options.size()]
			return create_mercenary_for_tier(tier, picked)

static func create_tamed_beast_from_enemy(enemy: Node2D, floor_num: int = 1) -> CompanionData:
	var data = CompanionData.new()
	data.archetype = CompanionArchetype.TAMED_HOUND
	data.depth_tier = clampi(int(floor(float(floor_num - 1) / 4.0)) + 1, 1, 5)
	var e_name = enemy.get("enemy_name") if "enemy_name" in enemy else enemy.name
	data.companion_name = "Tamed %s" % e_name
	data.companion_id = "tamed_" + e_name.to_lower().replace(" ", "_")
	
	var e_hp = 60.0
	if enemy.has_node("StatsComponent"):
		var sc = enemy.get_node("StatsComponent") as StatsComponent
		e_hp = sc.get_max_health()
	elif "max_hp" in enemy and float(enemy.max_hp) > 0.0:
		e_hp = float(enemy.max_hp)
		
	data.base_hp = maxf(35.0, e_hp)
	data.base_damage_min = 8
	data.base_damage_max = 14
	data.base_armor = 2
	data.base_dodge = 20.0
	data.perception_range = 6
	data.attack_range = 1
	data.is_ranged = false
	return data
