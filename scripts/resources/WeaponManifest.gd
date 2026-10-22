class_name WeaponManifest
extends RefCounted

## WeaponManifest: Authoritative database of all 50 base weapons across the 7 weapon skills.
## Every weapon is strictly bound to its parent SkillData.SkillId and has a unique Level 25 WeaponAbilityData.

const ItemData = preload("res://scripts/resources/ItemData.gd")
const SkillData = preload("res://scripts/resources/SkillData.gd")
const WeaponAbilityData = preload("res://scripts/resources/WeaponAbilityData.gd")
const AttributesData = preload("res://scripts/resources/AttributesData.gd")

static var _registry_cache: Dictionary = {}

static func get_weapon_registry() -> Dictionary:
	if not _registry_cache.is_empty():
		return _registry_cache
	_registry_cache = {
	# =========================================================================
	# 1. SWORDSMANSHIP WEAPONS (7 Weapons) — Primary STR | Secondary DEX
	# =========================================================================
	"sword_short": {
		"name": "Shortsword",
		"skill_id": SkillData.SkillId.SWORDSMANSHIP,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.ONE_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"dmg_min": 3, "dmg_max": 8,
		"acc_bonus": 0.05,
		"weight": 2.0, "value": 25,
		"description": "Balanced one-handed blade favored by skirmishers.",
		"ability": {
			"id": "quick_thrust", "name": "Quick Thrust",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_ADJACENT,
			"dmg_mult": 1.30, "acc_bonus": 0.15, "armor_pen": 0.25, "cd": 3,
			"desc": "Precision lunge (+15% Accuracy, 1.3x Damage, ignores 25% Armor)."
		}
	},
	"sword_broad": {
		"name": "Broadsword",
		"skill_id": SkillData.SkillId.SWORDSMANSHIP,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.ONE_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"dmg_min": 4, "dmg_max": 10,
		"acc_bonus": 0.0,
		"weight": 2.5, "value": 40,
		"description": "Heavy military blade designed for slashing and cleaving.",
		"ability": {
			"id": "cleaving_slash", "name": "Cleaving Slash",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_CLEAVE_ARC,
			"dmg_mult": 1.35, "acc_bonus": 0.05, "cd": 4,
			"desc": "Wide horizontal slash (1.35x Damage, hits target and adjacent enemies in front arc)."
		}
	},
	"sword_scimitar": {
		"name": "Scimitar",
		"skill_id": SkillData.SkillId.SWORDSMANSHIP,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.ONE_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"dmg_min": 3, "dmg_max": 9,
		"acc_bonus": 0.03,
		"bleed_chance": 0.15,
		"weight": 2.2, "value": 45,
		"description": "Curved saber built for fluid, bleeding draw-cuts.",
		"ability": {
			"id": "dervish_cut", "name": "Dervish Cut",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_ADJACENT,
			"dmg_mult": 1.25, "acc_bonus": 0.10, "status": "BLEEDING", "status_chance": 1.0, "status_dur": 3, "cd": 4,
			"desc": "Spinning slash (1.25x Damage, inflicts Bleeding for 3 turns)."
		}
	},
	"sword_bastard": {
		"name": "Bastard Sword",
		"skill_id": SkillData.SkillId.SWORDSMANSHIP,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.VERSATILE,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"dmg_min": 5, "dmg_max": 11,
		"acc_bonus": 0.02,
		"weight": 3.2, "value": 65,
		"description": "Hand-and-a-half versatile sword adaptable to one or two hands.",
		"ability": {
			"id": "half_sword_mordhau", "name": "Half-Sword Strike",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_ADJACENT,
			"dmg_mult": 1.40, "acc_bonus": 0.10, "armor_pen": 0.50, "cd": 4,
			"desc": "Grip the blade to drive the point through plate (1.4x Damage, 50% Armor Penetration)."
		}
	},
	"sword_long": {
		"name": "Longsword",
		"skill_id": SkillData.SkillId.SWORDSMANSHIP,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.TWO_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"dmg_min": 6, "dmg_max": 13,
		"acc_bonus": 0.04,
		"defense_bonus": 0.03,
		"weight": 3.5, "value": 80,
		"description": "Two-handed knightly blade offering superior reach and parry leverage.",
		"ability": {
			"id": "pommel_riposte", "name": "Pommel Strike",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_ADJACENT,
			"dmg_mult": 1.30, "acc_bonus": 0.15, "self_def": 0.15, "status": "DAZED", "status_chance": 1.0, "status_dur": 1, "cd": 4,
			"desc": "Cruel crossguard bash (1.3x Damage, Dazes target 1 turn, +15% Defense Bonus)."
		}
	},
	"sword_great": {
		"name": "Greatsword",
		"skill_id": SkillData.SkillId.SWORDSMANSHIP,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.TWO_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"dmg_min": 8, "dmg_max": 16,
		"acc_bonus": -0.02,
		"weight": 5.0, "value": 120,
		"description": "Massive two-handed zweihander capable of cleaving ranks in twain.",
		"ability": {
			"id": "wide_arc_sweep", "name": "Wide Arc Sweep",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_CLEAVE_ARC,
			"dmg_mult": 1.50, "acc_bonus": 0.05, "cd": 5,
			"desc": "Colossal 3-tile frontal arc cleave (1.5x Damage)."
		}
	},
	"sword_executioner": {
		"name": "Executioner's Sword",
		"skill_id": SkillData.SkillId.SWORDSMANSHIP,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.TWO_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"dmg_min": 10, "dmg_max": 20,
		"acc_bonus": -0.05,
		"crit_bonus": 0.10,
		"weight": 6.0, "value": 160,
		"description": "Flat-tipped, heavy-weighted decapitation blade forged for final judgment.",
		"ability": {
			"id": "guillotine_drop", "name": "Guillotine Drop",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_ADJACENT,
			"dmg_mult": 1.75, "acc_bonus": 0.0, "guaranteed_crit": true, "cd": 6,
			"desc": "Merciless overhead execution (1.75x Damage, Guaranteed Critical Hit)."
		}
	},

	# =========================================================================
	# 2. BLUNT WEAPON FIGHTING WEAPONS (7 Weapons) — Primary STR | Doubles STR @ 50
	# =========================================================================
	"blunt_club": {
		"name": "Club",
		"skill_id": SkillData.SkillId.BLUNT_WEAPON_FIGHTING,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.ONE_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"dmg_min": 2, "dmg_max": 7,
		"acc_bonus": 0.02,
		"stun_chance": 0.10,
		"weight": 2.0, "value": 10,
		"description": "Heavy iron-shod wooden bludgeon.",
		"ability": {
			"id": "skull_thump", "name": "Skull Thump",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_ADJACENT,
			"dmg_mult": 1.25, "acc_bonus": 0.10, "status": "DAZED", "status_chance": 1.0, "status_dur": 2, "cd": 3,
			"desc": "Concussive blow (1.25x Damage, Dazes target for 2 turns)."
		}
	},
	"blunt_mace": {
		"name": "Mace",
		"skill_id": SkillData.SkillId.BLUNT_WEAPON_FIGHTING,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.ONE_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"dmg_min": 3, "dmg_max": 9,
		"acc_bonus": 0.0,
		"armor_pen": 0.20,
		"weight": 3.0, "value": 35,
		"description": "Flanged steel mace designed to dent and buckle armor.",
		"ability": {
			"id": "armor_dent", "name": "Armor Dent",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_ADJACENT,
			"dmg_mult": 1.35, "acc_bonus": 0.05, "armor_pen": 0.60, "status": "SUNDERED", "status_chance": 1.0, "status_dur": 4, "cd": 4,
			"desc": "Crushing strike (1.35x Damage, 60% Armor Pen, Sunders target armor)."
		}
	},
	"blunt_warhammer": {
		"name": "Warhammer",
		"skill_id": SkillData.SkillId.BLUNT_WEAPON_FIGHTING,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.ONE_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"dmg_min": 4, "dmg_max": 10,
		"acc_bonus": 0.0,
		"armor_pen": 0.35,
		"weight": 3.5, "value": 55,
		"description": "Military hammer with a rear spike for puncturing heavy plate.",
		"ability": {
			"id": "plate_cracker", "name": "Plate Cracker",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_ADJACENT,
			"dmg_mult": 1.45, "acc_bonus": 0.05, "armor_pen": 1.0, "cd": 4,
			"desc": "Spike-first blow (1.45x Damage, 100% Armor Penetration)."
		}
	},
	"blunt_flail": {
		"name": "Flail",
		"skill_id": SkillData.SkillId.BLUNT_WEAPON_FIGHTING,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.ONE_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"dmg_min": 3, "dmg_max": 12,
		"acc_bonus": 0.05,
		"weight": 3.2, "value": 50,
		"description": "Chain-linked spiked ball that wraps around enemy shields and parries.",
		"ability": {
			"id": "shield_wrap", "name": "Shield Wrap",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_ADJACENT,
			"dmg_mult": 1.35, "acc_bonus": 0.30, "armor_pen": 0.30, "cd": 4,
			"desc": "Lashes over shields (+30% Accuracy Bonus, 1.35x Damage)."
		}
	},
	"blunt_quarterstaff": {
		"name": "Quarterstaff",
		"skill_id": SkillData.SkillId.BLUNT_WEAPON_FIGHTING,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.TWO_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"dmg_min": 4, "dmg_max": 9,
		"acc_bonus": 0.08,
		"defense_bonus": 0.10,
		"weight": 2.5, "value": 30,
		"description": "Iron-ferruled hardwood staff granting +10% defensive parry leverage.",
		"ability": {
			"id": "vaulting_sweep", "name": "Vaulting Sweep",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_ADJACENT,
			"dmg_mult": 1.25, "acc_bonus": 0.15, "self_def": 0.15, "status": "STUNNED", "status_chance": 1.0, "status_dur": 1, "cd": 4,
			"desc": "Sweeps the target's legs (1.25x Damage, Stuns 1 turn, +15% Defense Bonus)."
		}
	},
	"blunt_iron_mace": {
		"name": "Iron Mace",
		"skill_id": SkillData.SkillId.BLUNT_WEAPON_FIGHTING,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.TWO_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"dmg_min": 7, "dmg_max": 15,
		"acc_bonus": -0.02,
		"armor_pen": 0.30,
		"weight": 5.5, "value": 95,
		"description": "Two-handed solid iron kanabo that shatters bones through mail.",
		"ability": {
			"id": "bone_breaker", "name": "Bone Breaker",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_ADJACENT,
			"dmg_mult": 1.55, "acc_bonus": 0.0, "armor_pen": 0.50, "status": "CRIPPLED", "status_chance": 1.0, "status_dur": 3, "cd": 5,
			"desc": "Devastating two-handed smash (1.55x Damage, 50% Armor Pen, Cripples target)."
		}
	},
	"blunt_great_maul": {
		"name": "Great Maul",
		"skill_id": SkillData.SkillId.BLUNT_WEAPON_FIGHTING,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.TWO_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"dmg_min": 10, "dmg_max": 22,
		"acc_bonus": -0.06,
		"armor_pen": 0.45,
		"stun_chance": 0.20,
		"weight": 7.5, "value": 150,
		"description": "Colossal lead-weighted siege hammer that turns stone and plate to dust.",
		"ability": {
			"id": "earthshaker_slam", "name": "Earthshaker Slam",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_ADJACENT,
			"dmg_mult": 1.60, "acc_bonus": 0.0, "armor_pen": 0.60, "area_radius": 1, "status": "STUNNED", "status_chance": 0.75, "status_dur": 1, "cd": 6,
			"desc": "Seismic ground slam (1.6x Damage in 3x3 area around target, 75% Stun)."
		}
	},

	# =========================================================================
	# 3. FINESSE WEAPON FIGHTING WEAPONS (7 Weapons) — Primary DEX | Doubles DEX @ 50
	# =========================================================================
	"finesse_dagger": {
		"name": "Dagger",
		"skill_id": SkillData.SkillId.FINESSE_WEAPON_FIGHTING,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.ONE_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"dmg_min": 2, "dmg_max": 6,
		"acc_bonus": 0.10,
		"backstab_mult": 2.5,
		"crit_bonus": 0.08,
		"weight": 0.8, "value": 20,
		"description": "Double-edged utility blade with a 2.5x backstab/ambush multiplier.",
		"ability": {
			"id": "artery_puncture", "name": "Artery Puncture",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_ADJACENT,
			"dmg_mult": 1.40, "acc_bonus": 0.20, "guaranteed_crit": true, "status": "BLEEDING", "status_chance": 1.0, "status_dur": 3, "cd": 4,
			"desc": "Surgical strike to vital arteries (1.4x Damage, Guaranteed Crit, Bleeds 3 turns)."
		}
	},
	"finesse_stiletto": {
		"name": "Stiletto",
		"skill_id": SkillData.SkillId.FINESSE_WEAPON_FIGHTING,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.ONE_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"dmg_min": 3, "dmg_max": 7,
		"acc_bonus": 0.08,
		"armor_pen": 0.50,
		"backstab_mult": 2.0,
		"weight": 0.7, "value": 45,
		"description": "Needle-thin cruciform thrusting dagger designed to slip through visor slits.",
		"ability": {
			"id": "heartseeker_needle", "name": "Heartseeker Needle",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_ADJACENT,
			"dmg_mult": 1.50, "acc_bonus": 0.15, "armor_pen": 1.0, "cd": 4,
			"desc": "Finds the gap in any armor (1.5x Damage, 100% Armor Penetration)."
		}
	},
	"finesse_kryss": {
		"name": "Kryss",
		"skill_id": SkillData.SkillId.FINESSE_WEAPON_FIGHTING,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.ONE_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"dmg_min": 3, "dmg_max": 8,
		"acc_bonus": 0.12,
		"crit_bonus": 0.10,
		"weight": 1.2, "value": 60,
		"description": "Lightning-fast wavy-bladed dueling rapier.",
		"ability": {
			"id": "viper_flurry", "name": "Viper Flurry",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_ADJACENT,
			"dmg_mult": 0.65, "acc_bonus": 0.15, "strike_count": 3, "cd": 4,
			"desc": "Blinding 3-hit rapid thrust combination (3x 0.65x Damage)."
		}
	},
	"finesse_main_gauche": {
		"name": "Main-Gauche",
		"skill_id": SkillData.SkillId.FINESSE_WEAPON_FIGHTING,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.ONE_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"can_equip_offhand": true,
		"dmg_min": 2, "dmg_max": 6,
		"acc_bonus": 0.08,
		"defense_bonus": 0.15,
		"parry_bonus": 0.15,
		"weight": 1.0, "value": 55,
		"description": "Sail-guarded parrying dagger that can be wielded in Main Hand or Offhand (+15% Defense).",
		"ability": {
			"id": "disarming_parry", "name": "Disarming Parry",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_ADJACENT,
			"dmg_mult": 1.25, "acc_bonus": 0.20, "self_def": 0.25, "status": "WEAKENED", "status_chance": 1.0, "status_dur": 2, "cd": 4,
			"desc": "Traps enemy blade and ripostes (1.25x Damage, +25% Defense, Weakens target)."
		}
	},
	"finesse_kukri": {
		"name": "Kukri",
		"skill_id": SkillData.SkillId.FINESSE_WEAPON_FIGHTING,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.ONE_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"dmg_min": 4, "dmg_max": 9,
		"acc_bonus": 0.05,
		"bleed_chance": 0.25,
		"weight": 1.4, "value": 50,
		"description": "Forward-angled chopping knife that inflicts deep, ragged wounds.",
		"ability": {
			"id": "tendon_slice", "name": "Tendon Slice",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_ADJACENT,
			"dmg_mult": 1.35, "acc_bonus": 0.10, "status": "BLEEDING", "status_chance": 1.0, "status_dur": 4, "cd": 4,
			"desc": "Hamstrings the enemy (1.35x Damage, heavy Bleed for 4 turns)."
		}
	},
	"finesse_assassins_blade": {
		"name": "Assassin's Blade",
		"skill_id": SkillData.SkillId.FINESSE_WEAPON_FIGHTING,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.ONE_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"dmg_min": 4, "dmg_max": 10,
		"acc_bonus": 0.10,
		"backstab_mult": 3.0,
		"crit_bonus": 0.15,
		"armor_pen": 0.25,
		"weight": 1.0, "value": 130,
		"description": "Blackened hollow-ground blade forged for silent, lethal executions (3.0x backstab).",
		"ability": {
			"id": "shadow_ambush", "name": "Shadow Ambush",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_ADJACENT,
			"dmg_mult": 2.0, "acc_bonus": 0.25, "armor_pen": 0.50, "guaranteed_crit": true, "cd": 5,
			"desc": "Lethal vital-point strike (2.0x Damage, Guaranteed Critical Hit, 50% Armor Pen)."
		}
	},
	"finesse_kris": {
		"name": "Kris",
		"skill_id": SkillData.SkillId.FINESSE_WEAPON_FIGHTING,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.ONE_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"dmg_min": 3, "dmg_max": 8,
		"acc_bonus": 0.08,
		"poison_chance": 0.35,
		"weight": 1.0, "value": 85,
		"description": "Asymmetrical serpentine dagger with venom-retaining grooves (35% Poison chance).",
		"ability": {
			"id": "envenomed_fang", "name": "Envenomed Fang",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_ADJACENT,
			"dmg_mult": 1.35, "acc_bonus": 0.15, "status": "POISONED", "status_chance": 1.0, "status_dur": 5, "cd": 4,
			"desc": "Injects concentrated neurotoxin (1.35x Damage, guaranteed Poison for 5 turns)."
		}
	},

	# =========================================================================
	# 4. POLEARMS WEAPONS (7 Weapons) — Primary CON | Secondary STR
	# =========================================================================
	"polearm_spear": {
		"name": "Spear",
		"skill_id": SkillData.SkillId.POLEARMS,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.VERSATILE,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"dmg_min": 3, "dmg_max": 8,
		"acc_bonus": 0.05,
		"range_tiles": 2,
		"weight": 2.5, "value": 25,
		"description": "Ash-shafted infantry spear with 2-tile reach.",
		"ability": {
			"id": "impaling_lunge", "name": "Impaling Lunge",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_REACH,
			"dmg_mult": 1.40, "acc_bonus": 0.15, "armor_pen": 0.30, "range_override": 2, "cd": 3,
			"desc": "2-tile reach thrust (1.4x Damage, +15% Accuracy, 30% Armor Pen)."
		}
	},
	"polearm_halberd": {
		"name": "Halberd",
		"skill_id": SkillData.SkillId.POLEARMS,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.TWO_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"dmg_min": 7, "dmg_max": 15,
		"acc_bonus": 0.0,
		"armor_pen": 0.25,
		"range_tiles": 2,
		"weight": 5.0, "value": 95,
		"description": "Axe-blade topped with a spear point and rear hook for total battlefield control.",
		"ability": {
			"id": "sentinel_chop", "name": "Sentinel Chop",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_REACH,
			"dmg_mult": 1.50, "acc_bonus": 0.10, "armor_pen": 0.50, "self_def": 0.10, "range_override": 2, "cd": 4,
			"desc": "Heavy overhead pole-axe chop (1.5x Damage, 50% Armor Pen, +10% Defense)."
		}
	},
	"polearm_glaive": {
		"name": "Glaive",
		"skill_id": SkillData.SkillId.POLEARMS,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.TWO_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"dmg_min": 6, "dmg_max": 14,
		"acc_bonus": 0.04,
		"range_tiles": 2,
		"weight": 4.2, "value": 85,
		"description": "Single-edged curved blade mounted on a long pole for sweeping arcs.",
		"ability": {
			"id": "crescent_reap", "name": "Crescent Reap",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_CLEAVE_ARC,
			"dmg_mult": 1.45, "acc_bonus": 0.10, "cd": 4,
			"desc": "Sweeping polearm arc hitting frontal enemies (1.45x Damage)."
		}
	},
	"polearm_trident": {
		"name": "Trident",
		"skill_id": SkillData.SkillId.POLEARMS,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.VERSATILE,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"dmg_min": 4, "dmg_max": 10,
		"acc_bonus": 0.06,
		"defense_bonus": 0.05,
		"bleed_chance": 0.20,
		"range_tiles": 2,
		"weight": 3.2, "value": 60,
		"description": "Three-pronged gladiatorial fork adept at catching blades and pinning foes.",
		"ability": {
			"id": "triple_prong_pin", "name": "Triple-Prong Pin",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_REACH,
			"dmg_mult": 1.35, "acc_bonus": 0.15, "range_override": 2, "status": "PINNED", "status_chance": 1.0, "status_dur": 2, "cd": 4,
			"desc": "Skewers and pins the target in place (1.35x Damage, Pinned for 2 turns)."
		}
	},
	"polearm_naginata": {
		"name": "Naginata",
		"skill_id": SkillData.SkillId.POLEARMS,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.TWO_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"dmg_min": 5, "dmg_max": 13,
		"acc_bonus": 0.07,
		"crit_bonus": 0.08,
		"bleed_chance": 0.20,
		"range_tiles": 2,
		"weight": 3.8, "value": 90,
		"description": "Graceful curved pole-sword balancing swift reach with razor-sharp precision.",
		"ability": {
			"id": "whirling_horizon", "name": "Whirling Horizon",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_CLEAVE_ARC,
			"dmg_mult": 1.35, "acc_bonus": 0.15, "self_def": 0.15, "status": "BLEEDING", "status_chance": 1.0, "status_dur": 3, "cd": 4,
			"desc": "Fluid spinning cut (1.35x Damage, Bleeds 3 turns, +15% Defense Bonus)."
		}
	},
	"polearm_voulge": {
		"name": "Voulge",
		"skill_id": SkillData.SkillId.POLEARMS,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.TWO_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"dmg_min": 8, "dmg_max": 17,
		"acc_bonus": -0.02,
		"armor_pen": 0.30,
		"range_tiles": 2,
		"weight": 5.5, "value": 105,
		"description": "Heavy cleaver-headed polearm built to hack through armor and shields.",
		"ability": {
			"id": "armor_rend_heave", "name": "Armor-Rend Heave",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_REACH,
			"dmg_mult": 1.55, "acc_bonus": 0.05, "armor_pen": 0.65, "range_override": 2, "cd": 5,
			"desc": "Brutal meat-cleaver chop (1.55x Damage, 65% Armor Penetration)."
		}
	},
	"polearm_billhook": {
		"name": "Billhook",
		"skill_id": SkillData.SkillId.POLEARMS,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.TWO_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"dmg_min": 5, "dmg_max": 12,
		"acc_bonus": 0.05,
		"armor_pen": 0.20,
		"bleed_chance": 0.15,
		"range_tiles": 2,
		"weight": 4.0, "value": 70,
		"description": "Hooked pole-blade designed to drag knights off balance and expose their joints.",
		"ability": {
			"id": "hook_and_trip", "name": "Hook & Trip",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_REACH,
			"dmg_mult": 1.30, "acc_bonus": 0.15, "armor_pen": 0.40, "range_override": 2, "status": "STUNNED", "status_chance": 1.0, "status_dur": 1, "cd": 4,
			"desc": "Hooks the target's legs (1.3x Damage, 40% Armor Pen, Stuns 1 turn)."
		}
	},

	# =========================================================================
	# 5. BRAWLING WEAPONS (7 Weapons) — Primary STR | Secondary DEX
	# =========================================================================
	"brawling_cestus": {
		"name": "Cestus",
		"skill_id": SkillData.SkillId.BRAWLING,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.ONE_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"dmg_min": 2, "dmg_max": 6,
		"acc_bonus": 0.08,
		"weight": 1.0, "value": 20,
		"description": "Weighted leather battle-glove reinforced with iron strips.",
		"ability": {
			"id": "pugilist_one_two", "name": "One-Two Combo",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_ADJACENT,
			"dmg_mult": 0.80, "acc_bonus": 0.15, "strike_count": 2, "cd": 3,
			"desc": "Rapid jab-cross combination (2 strikes at 0.80x Damage each)."
		}
	},
	"brawling_brass_knuckles": {
		"name": "Brass Knuckles",
		"skill_id": SkillData.SkillId.BRAWLING,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.ONE_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"dmg_min": 3, "dmg_max": 7,
		"acc_bonus": 0.08,
		"stun_chance": 0.15,
		"weight": 0.8, "value": 30,
		"description": "Solid cast-brass knuckle dusters that concentrate punch force.",
		"ability": {
			"id": "jawbreaker_hook", "name": "Jawbreaker Hook",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_ADJACENT,
			"dmg_mult": 1.35, "acc_bonus": 0.15, "status": "STUNNED", "status_chance": 1.0, "status_dur": 1, "cd": 4,
			"desc": "Chin-shattering hook (1.35x Damage, Stuns target for 1 turn)."
		}
	},
	"brawling_spiked_knuckles": {
		"name": "Iron Spiked Knuckles",
		"skill_id": SkillData.SkillId.BRAWLING,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.ONE_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"dmg_min": 3, "dmg_max": 8,
		"acc_bonus": 0.06,
		"armor_pen": 0.20,
		"bleed_chance": 0.25,
		"weight": 1.2, "value": 45,
		"description": "Cruel iron knuckles studded with pyramidal armor-piercing spikes.",
		"ability": {
			"id": "savage_pummel", "name": "Savage Pummel",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_ADJACENT,
			"dmg_mult": 0.85, "acc_bonus": 0.10, "armor_pen": 0.30, "strike_count": 2, "status": "BLEEDING", "status_chance": 1.0, "status_dur": 3, "cd": 4,
			"desc": "Two vicious spiked blows (2x 0.85x Damage, inflicts Bleeding)."
		}
	},
	"brawling_leather_wraps": {
		"name": "Leather Handwraps",
		"skill_id": SkillData.SkillId.BRAWLING,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.ONE_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"dmg_min": 2, "dmg_max": 5,
		"acc_bonus": 0.12,
		"defense_bonus": 0.08,
		"dodge_bonus": 0.05,
		"weight": 0.4, "value": 18,
		"description": "Tightly bound martial artist wraps that protect the metacarpals and boost evasion.",
		"ability": {
			"id": "flurry_of_blows", "name": "Flurry of Blows",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_ADJACENT,
			"dmg_mult": 0.60, "acc_bonus": 0.20, "self_def": 0.10, "strike_count": 3, "cd": 3,
			"desc": "Three lightning-fast palm and fist strikes (3x 0.60x Damage, +10% Defense)."
		}
	},
	"brawling_weighted_wraps": {
		"name": "Weighted Boxing Wraps",
		"skill_id": SkillData.SkillId.BRAWLING,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.ONE_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"dmg_min": 4, "dmg_max": 9,
		"acc_bonus": 0.08,
		"stun_chance": 0.20,
		"weight": 1.5, "value": 55,
		"description": "Lead-dust impregnated wraps that turn every punch into a battering ram.",
		"ability": {
			"id": "haymaker_ko", "name": "Haymaker",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_ADJACENT,
			"dmg_mult": 1.65, "acc_bonus": 0.05, "armor_pen": 0.35, "status": "STUNNED", "status_chance": 1.0, "status_dur": 1, "cd": 5,
			"desc": "All-out knockout punch (1.65x Damage, 35% Armor Pen, Stuns 1 turn)."
		}
	},
	"brawling_nagaraja_claws": {
		"name": "Nagaraja Claws",
		"skill_id": SkillData.SkillId.BRAWLING,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.ONE_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"dmg_min": 4, "dmg_max": 10,
		"acc_bonus": 0.10,
		"crit_bonus": 0.12,
		"bleed_chance": 0.25,
		"poison_chance": 0.25,
		"weight": 1.2, "value": 110,
		"description": "Exotic curved fist-talons steeped in serpent venom.",
		"ability": {
			"id": "serpent_fang_rend", "name": "Serpent Fang Rend",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_ADJACENT,
			"dmg_mult": 0.90, "acc_bonus": 0.15, "strike_count": 2, "status": "POISONED", "status_chance": 1.0, "status_dur": 4, "cd": 4,
			"desc": "Twin talon rip (2x 0.90x Damage, inflicts Poison and Bleed)."
		}
	},
	"brawling_plate_gauntlets": {
		"name": "Gauntlets (Plate)",
		"skill_id": SkillData.SkillId.BRAWLING,
		"weapon_type": AttributesData.WeaponType.MELEE,
		"handedness": ItemData.Handedness.ONE_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"dmg_min": 4, "dmg_max": 9,
		"acc_bonus": 0.05,
		"armor_value": 3,
		"defense_bonus": 0.08,
		"armor_pen": 0.25,
		"weight": 2.5, "value": 85,
		"description": "Articulated steel war-gauntlets that grant +3 Armor and +8% Defense while brawling.",
		"ability": {
			"id": "ironclad_backhand", "name": "Ironclad Backhand",
			"exec_type": WeaponAbilityData.ExecutionType.MELEE_ADJACENT,
			"dmg_mult": 1.45, "acc_bonus": 0.10, "armor_pen": 0.50, "self_def": 0.20, "cd": 4,
			"desc": "Steel-armored smash (1.45x Damage, 50% Armor Pen, +20% Defense Bonus)."
		}
	},

	# =========================================================================
	# 6. ARCHERY WEAPONS (7 Weapons — Requires Ammo Slot) — Primary DEX | Doubles DEX @ 50
	# =========================================================================
	"archery_short_bow": {
		"name": "Short Bow",
		"skill_id": SkillData.SkillId.ARCHERY,
		"weapon_type": AttributesData.WeaponType.BOW,
		"handedness": ItemData.Handedness.TWO_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"requires_ammo": true,
		"dmg_min": 3, "dmg_max": 7,
		"acc_bonus": 0.06,
		"range_tiles": 5,
		"weight": 1.5, "value": 30,
		"description": "Compact hunting bow suited for quick snap-shots in tight corridors.",
		"ability": {
			"id": "snap_shot", "name": "Snap Shot",
			"exec_type": WeaponAbilityData.ExecutionType.RANGED_SINGLE,
			"dmg_mult": 1.30, "acc_bonus": 0.20, "range_override": 5, "cd": 3,
			"desc": "Instinctive high-accuracy shot (1.3x Damage, +20% Accuracy Bonus)."
		}
	},
	"archery_longbow": {
		"name": "Longbow",
		"skill_id": SkillData.SkillId.ARCHERY,
		"weapon_type": AttributesData.WeaponType.HIGH_TENSION_BOW,
		"handedness": ItemData.Handedness.TWO_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"requires_ammo": true,
		"dmg_min": 5, "dmg_max": 12,
		"acc_bonus": 0.04,
		"armor_pen": 0.20,
		"range_tiles": 7,
		"weight": 2.5, "value": 75,
		"description": "Tall yew war-bow with 7-tile range and heavy draw weight.",
		"ability": {
			"id": "bodkin_piercer", "name": "Bodkin Piercer",
			"exec_type": WeaponAbilityData.ExecutionType.RANGED_SINGLE,
			"dmg_mult": 1.45, "acc_bonus": 0.10, "armor_pen": 0.75, "range_override": 8, "cd": 4,
			"desc": "Long-range armor-piercing shaft (1.45x Damage, 75% Armor Pen, Range 8)."
		}
	},
	"archery_composite_bow": {
		"name": "Composite Bow",
		"skill_id": SkillData.SkillId.ARCHERY,
		"weapon_type": AttributesData.WeaponType.HIGH_TENSION_BOW,
		"handedness": ItemData.Handedness.TWO_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"requires_ammo": true,
		"dmg_min": 5, "dmg_max": 11,
		"acc_bonus": 0.05,
		"range_tiles": 6,
		"weight": 2.2, "value": 85,
		"description": "Laminated horn, wood, and sinew bow packing immense tension into a compact frame.",
		"ability": {
			"id": "double_nock", "name": "Double Nock",
			"exec_type": WeaponAbilityData.ExecutionType.RANGED_SINGLE,
			"dmg_mult": 0.85, "acc_bonus": 0.05, "strike_count": 2, "range_override": 6, "cd": 4,
			"desc": "Fires two arrows simultaneously at the target (2x 0.85x Damage)."
		}
	},
	"archery_recurve_bow": {
		"name": "Recurve Bow",
		"skill_id": SkillData.SkillId.ARCHERY,
		"weapon_type": AttributesData.WeaponType.HIGH_TENSION_BOW,
		"handedness": ItemData.Handedness.TWO_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"requires_ammo": true,
		"dmg_min": 4, "dmg_max": 9,
		"acc_bonus": 0.08,
		"range_tiles": 6,
		"weight": 2.0, "value": 55,
		"description": "Gracefully curved limbs store extra kinetic energy for flat, accurate trajectories.",
		"ability": {
			"id": "pinning_arrow", "name": "Pinning Arrow",
			"exec_type": WeaponAbilityData.ExecutionType.RANGED_SINGLE,
			"dmg_mult": 1.35, "acc_bonus": 0.15, "range_override": 6, "status": "PINNED", "status_chance": 1.0, "status_dur": 2, "cd": 4,
			"desc": "Staples the target's foot to the floor (1.35x Damage, Pinned for 2 turns)."
		}
	},
	"archery_light_crossbow": {
		"name": "Light Crossbow",
		"skill_id": SkillData.SkillId.ARCHERY,
		"weapon_type": AttributesData.WeaponType.BOW,
		"handedness": ItemData.Handedness.TWO_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"requires_ammo": true,
		"dmg_min": 6, "dmg_max": 12,
		"acc_bonus": 0.10,
		"armor_pen": 0.25,
		"range_tiles": 6,
		"weight": 3.0, "value": 65,
		"description": "Lever-cocked crossbow offering steady aim and reliable armor penetration.",
		"ability": {
			"id": "vital_bolt", "name": "Vital Bolt",
			"exec_type": WeaponAbilityData.ExecutionType.RANGED_SINGLE,
			"dmg_mult": 1.40, "acc_bonus": 0.20, "armor_pen": 0.50, "range_override": 6, "cd": 4,
			"desc": "Carefully aimed quarrel (+20% Accuracy, 1.4x Damage, 50% Armor Pen)."
		}
	},
	"archery_heavy_crossbow": {
		"name": "Heavy Crossbow",
		"skill_id": SkillData.SkillId.ARCHERY,
		"weapon_type": AttributesData.WeaponType.HIGH_TENSION_BOW,
		"handedness": ItemData.Handedness.TWO_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"requires_ammo": true,
		"dmg_min": 9, "dmg_max": 18,
		"acc_bonus": 0.08,
		"armor_pen": 0.45,
		"range_tiles": 7,
		"weight": 5.0, "value": 135,
		"description": "Winch-spanned steel-prodded arbalest that punches straight through breastplates.",
		"ability": {
			"id": "siege_arbalest_shot", "name": "Siege Arbalest Shot",
			"exec_type": WeaponAbilityData.ExecutionType.RANGED_SINGLE,
			"dmg_mult": 1.70, "acc_bonus": 0.10, "armor_pen": 1.0, " guaranteed_crit": true, "range_override": 7, "cd": 5,
			"desc": "Devastating siege bolt (1.7x Damage, 100% Armor Pen, Guaranteed Crit)."
		}
	},
	"archery_hand_crossbow": {
		"name": "Hand Crossbow",
		"skill_id": SkillData.SkillId.ARCHERY,
		"weapon_type": AttributesData.WeaponType.BOW,
		"handedness": ItemData.Handedness.ONE_HANDED,
		"slot": ItemData.EquipSlot.MAIN_HAND,
		"item_type": ItemData.ItemType.WEAPON,
		"requires_ammo": true,
		"dmg_min": 3, "dmg_max": 8,
		"acc_bonus": 0.12,
		"crit_bonus": 0.10,
		"range_tiles": 4,
		"weight": 1.4, "value": 80,
		"description": "One-handed pistol crossbow favored by drow and subterranean ambushers.",
		"ability": {
			"id": "point_blank_bolt", "name": "Point-Blank Bolt",
			"exec_type": WeaponAbilityData.ExecutionType.RANGED_SINGLE,
			"dmg_mult": 1.45, "acc_bonus": 0.25, "armor_pen": 0.40, "guaranteed_crit": true, "range_override": 4, "cd": 3,
			"desc": "Snap-fired close-quarters bolt (1.45x Damage, Guaranteed Crit, +25% Accuracy)."
		}
	},

	# =========================================================================
	# 7. THROWING WEAPONS (8 Weapons — Uses Inventory Weight) — Primary DEX | Secondary STR
	# =========================================================================
	"throwing_knives": {
		"name": "Throwing Knives",
		"skill_id": SkillData.SkillId.THROWING,
		"weapon_type": AttributesData.WeaponType.THROWN,
		"handedness": ItemData.Handedness.ONE_HANDED,
		"slot": ItemData.EquipSlot.AMMUNITION,
		"item_type": ItemData.ItemType.AMMO,
		"uses_inventory_weight": true,
		"default_qty": 10,
		"dmg_min": 2, "dmg_max": 6,
		"acc_bonus": 0.10,
		"crit_bonus": 0.08,
		"range_tiles": 4,
		"weight": 0.15, "value": 25,
		"description": "Balanced steel throwing blades carried in a quick-draw bandolier.",
		"ability": {
			"id": "fan_of_knives", "name": "Fan of Knives",
			"exec_type": WeaponAbilityData.ExecutionType.RANGED_AOE,
			"dmg_mult": 1.25, "acc_bonus": 0.15, "range_override": 4, "area_radius": 1, "cd": 4,
			"desc": "Hurls a spread of blades hitting a 3x3 area (1.25x Damage)."
		}
	},
	"throwing_axes": {
		"name": "Throwing Axes",
		"skill_id": SkillData.SkillId.THROWING,
		"weapon_type": AttributesData.WeaponType.THROWN,
		"handedness": ItemData.Handedness.ONE_HANDED,
		"slot": ItemData.EquipSlot.AMMUNITION,
		"item_type": ItemData.ItemType.AMMO,
		"uses_inventory_weight": true,
		"default_qty": 6,
		"dmg_min": 4, "dmg_max": 10,
		"acc_bonus": 0.04,
		"armor_pen": 0.20,
		"bleed_chance": 0.20,
		"range_tiles": 4,
		"weight": 0.4, "value": 35,
		"description": "Top-heavy francisca hatchets that tumble end-over-end to split shields.",
		"ability": {
			"id": "rending_tomahawk", "name": "Rending Tomahawk",
			"exec_type": WeaponAbilityData.ExecutionType.RANGED_SINGLE,
			"dmg_mult": 1.50, "acc_bonus": 0.10, "armor_pen": 0.50, "range_override": 4, "status": "BLEEDING", "status_chance": 1.0, "status_dur": 3, "cd": 4,
			"desc": "Heavy spinning hatchet (1.5x Damage, 50% Armor Pen, Bleeds 3 turns)."
		}
	},
	"throwing_javelins": {
		"name": "Javelins",
		"skill_id": SkillData.SkillId.THROWING,
		"weapon_type": AttributesData.WeaponType.THROWN,
		"handedness": ItemData.Handedness.ONE_HANDED,
		"slot": ItemData.EquipSlot.AMMUNITION,
		"item_type": ItemData.ItemType.AMMO,
		"uses_inventory_weight": true,
		"default_qty": 5,
		"dmg_min": 5, "dmg_max": 12,
		"acc_bonus": 0.05,
		"armor_pen": 0.35,
		"range_tiles": 5,
		"weight": 0.6, "value": 40,
		"description": "Long iron-shanked pilum javelins designed to punch through shields and pin armor.",
		"ability": {
			"id": "pilum_impale", "name": "Pilum Impale",
			"exec_type": WeaponAbilityData.ExecutionType.RANGED_SINGLE,
			"dmg_mult": 1.55, "acc_bonus": 0.15, "armor_pen": 0.75, "range_override": 6, "status": "PINNED", "status_chance": 1.0, "status_dur": 2, "cd": 4,
			"desc": "High-velocity javelin hurl (1.55x Damage, 75% Armor Pen, Pins target 2 turns)."
		}
	},
	"throwing_shurikens": {
		"name": "Shurikens",
		"skill_id": SkillData.SkillId.THROWING,
		"weapon_type": AttributesData.WeaponType.THROWN,
		"handedness": ItemData.Handedness.ONE_HANDED,
		"slot": ItemData.EquipSlot.AMMUNITION,
		"item_type": ItemData.ItemType.AMMO,
		"uses_inventory_weight": true,
		"default_qty": 15,
		"dmg_min": 2, "dmg_max": 5,
		"acc_bonus": 0.14,
		"crit_bonus": 0.12,
		"bleed_chance": 0.15,
		"range_tiles": 5,
		"weight": 0.08, "value": 30,
		"description": "Razor-edged star blades that can be flicked with pinpoint accuracy.",
		"ability": {
			"id": "star_barrage", "name": "Star Barrage",
			"exec_type": WeaponAbilityData.ExecutionType.RANGED_SINGLE,
			"dmg_mult": 0.70, "acc_bonus": 0.20, "strike_count": 3, "range_override": 5, "cd": 3,
			"desc": "Throws 3 shurikens in rapid succession (3x 0.70x Damage)."
		}
	},
	"throwing_darts": {
		"name": "Darts",
		"skill_id": SkillData.SkillId.THROWING,
		"weapon_type": AttributesData.WeaponType.THROWN,
		"handedness": ItemData.Handedness.ONE_HANDED,
		"slot": ItemData.EquipSlot.AMMUNITION,
		"item_type": ItemData.ItemType.AMMO,
		"uses_inventory_weight": true,
		"default_qty": 12,
		"dmg_min": 1, "dmg_max": 5,
		"acc_bonus": 0.12,
		"poison_chance": 0.40,
		"range_tiles": 5,
		"weight": 0.08, "value": 28,
		"description": "Fletched lead-weighted plumbata darts coated with paralytic alchemical resin.",
		"ability": {
			"id": "neurotoxin_needle", "name": "Neurotoxin Needle",
			"exec_type": WeaponAbilityData.ExecutionType.RANGED_SINGLE,
			"dmg_mult": 1.25, "acc_bonus": 0.20, "range_override": 5, "status": "POISONED", "status_chance": 1.0, "status_dur": 5, "cd": 3,
			"desc": "Envenomed dart strike (1.25x Damage, guaranteed Poison for 5 turns)."
		}
	},
	"throwing_chakram": {
		"name": "Chakram",
		"skill_id": SkillData.SkillId.THROWING,
		"weapon_type": AttributesData.WeaponType.THROWN,
		"handedness": ItemData.Handedness.ONE_HANDED,
		"slot": ItemData.EquipSlot.AMMUNITION,
		"item_type": ItemData.ItemType.AMMO,
		"uses_inventory_weight": true,
		"is_returning": true,
		"default_qty": 2,
		"dmg_min": 5, "dmg_max": 11,
		"acc_bonus": 0.08,
		"bleed_chance": 0.25,
		"range_tiles": 5,
		"weight": 0.8, "value": 90,
		"description": "Aerodynamic sharpened steel war-quoit that ricochets back to the thrower's hand.",
		"ability": {
			"id": "ricochet_disc", "name": "Ricochet Disc",
			"exec_type": WeaponAbilityData.ExecutionType.RANGED_AOE,
			"dmg_mult": 1.35, "acc_bonus": 0.15, "range_override": 5, "area_radius": 1, "status": "BLEEDING", "status_chance": 1.0, "status_dur": 3, "cd": 4,
			"desc": "Spinning disc slices all targets in a 3x3 area and returns (1.35x Damage, Bleeds)."
		}
	},
	"throwing_bolas": {
		"name": "Bolas",
		"skill_id": SkillData.SkillId.THROWING,
		"weapon_type": AttributesData.WeaponType.THROWN,
		"handedness": ItemData.Handedness.ONE_HANDED,
		"slot": ItemData.EquipSlot.AMMUNITION,
		"item_type": ItemData.ItemType.AMMO,
		"uses_inventory_weight": true,
		"default_qty": 5,
		"dmg_min": 2, "dmg_max": 6,
		"acc_bonus": 0.10,
		"stun_chance": 0.35,
		"range_tiles": 5,
		"weight": 0.5, "value": 45,
		"description": "Corded iron weights designed to entangle legs and bring fleeing quarry crashing down.",
		"ability": {
			"id": "entangling_snare", "name": "Entangling Snare",
			"exec_type": WeaponAbilityData.ExecutionType.RANGED_SINGLE,
			"dmg_mult": 1.20, "acc_bonus": 0.20, "range_override": 5, "status": "PINNED", "status_chance": 1.0, "status_dur": 3, "cd": 4,
			"desc": "Wraps around the target (1.2x Damage, Pins target for 3 turns)."
		}
	},
	"throwing_boomerang": {
		"name": "Boomerang",
		"skill_id": SkillData.SkillId.THROWING,
		"weapon_type": AttributesData.WeaponType.THROWN,
		"handedness": ItemData.Handedness.ONE_HANDED,
		"slot": ItemData.EquipSlot.AMMUNITION,
		"item_type": ItemData.ItemType.AMMO,
		"uses_inventory_weight": true,
		"is_returning": true,
		"default_qty": 1,
		"dmg_min": 4, "dmg_max": 9,
		"acc_bonus": 0.10,
		"stun_chance": 0.20,
		"range_tiles": 5,
		"weight": 1.0, "value": 65,
		"description": "Curved ironwood hunting airfoil that strikes with concussive force and returns to the hand.",
		"ability": {
			"id": "returning_arc", "name": "Returning Arc",
			"exec_type": WeaponAbilityData.ExecutionType.RANGED_SINGLE,
			"dmg_mult": 0.85, "acc_bonus": 0.15, "strike_count": 2, "range_override": 5, "status": "DAZED", "status_chance": 1.0, "status_dur": 2, "cd": 3,
			"desc": "Hits on the outbound and return flight (2x 0.85x Damage, Dazes 2 turns)."
		}
	}
	}
	return _registry_cache

static func get_all_weapon_ids() -> Array[String]:
	var reg = get_weapon_registry()
	var ids: Array[String] = []
	for k in reg.keys():
		ids.append(String(k))
	return ids

static func create_weapon(item_id: String, override_qty: int = -1) -> ItemData:
	const ALIASES = {
		"dagger_iron": "finesse_dagger",
		"dagger_stiletto": "finesse_stiletto",
		"bow_hunting": "archery_short_bow",
		"bow_recurve": "archery_recurve_bow",
		"mace_flanged": "blunt_mace",
		"staff_oak": "blunt_quarterstaff",
		"axe_hand": "throwing_axes",
		"spear_hunting": "polearm_spear",
		"unarmed_strikes": "brawling_leather_wraps"
	}
	var lookup_id = ALIASES.get(item_id, item_id)
	var reg = get_weapon_registry()
	if not reg.has(lookup_id):
		var fallback_item = ItemData.new(item_id, item_id.capitalize(), ItemData.ItemType.WEAPON, ItemData.EquipSlot.MAIN_HAND, 1.5, 1)
		fallback_item.base_damage_min = 2
		fallback_item.base_damage_max = 6
		if item_id.contains("silver"):
			fallback_item.is_silver = true
			fallback_item.tags = ["silver_weapon"]
		return fallback_item
	var spec: Dictionary = reg[lookup_id]
	var qty: int = override_qty if override_qty > 0 else int(spec.get("default_qty", 1))
	var item = ItemData.new(
		item_id,
		String(spec.get("name", item_id)),
		spec.get("item_type", ItemData.ItemType.WEAPON),
		spec.get("slot", ItemData.EquipSlot.MAIN_HAND),
		float(spec.get("weight", 1.0)),
		qty
	)
	item.associated_skill_id = spec.get("skill_id", SkillData.SkillId.SWORDSMANSHIP)
	item.weapon_type = spec.get("weapon_type", AttributesData.WeaponType.MELEE)
	item.handedness = spec.get("handedness", ItemData.Handedness.ONE_HANDED)
	item.base_damage_min = int(spec.get("dmg_min", 2))
	item.base_damage_max = int(spec.get("dmg_max", 6))
	item.accuracy_bonus = float(spec.get("acc_bonus", 0.0))
	item.defense_bonus = float(spec.get("defense_bonus", 0.0))
	item.armor_penetration = float(spec.get("armor_pen", 0.0))
	item.range_tiles = int(spec.get("range_tiles", 1))
	item.area_radius = int(spec.get("area_radius", 0))
	item.backstab_multiplier = float(spec.get("backstab_mult", 1.0))
	item.poison_chance = float(spec.get("poison_chance", 0.0))
	item.bleed_chance = float(spec.get("bleed_chance", 0.0))
	item.stun_chance = float(spec.get("stun_chance", 0.0))
	item.crit_chance_bonus = float(spec.get("crit_bonus", 0.0))
	item.requires_ammo = bool(spec.get("requires_ammo", false))
	item.is_returning = bool(spec.get("is_returning", false))
	item.can_equip_offhand = bool(spec.get("can_equip_offhand", false))
	item.uses_inventory_weight = bool(spec.get("uses_inventory_weight", false))
	item.armor_value = int(spec.get("armor_value", 0))
	item.parry_bonus = float(spec.get("parry_bonus", 0.0))
	item.dodge_bonus = float(spec.get("dodge_bonus", 0.0))
	item.base_value_gold = int(spec.get("value", 25))
	item.description = String(spec.get("description", ""))

	if spec.has("ability"):
		var ab_spec: Dictionary = spec["ability"]
		var ab = WeaponAbilityData.new()
		ab.ability_id = String(ab_spec.get("id", item_id + "_ability"))
		ab.ability_name = String(ab_spec.get("name", item.item_name + " Technique"))
		ab.required_skill_id = item.associated_skill_id
		ab.required_skill_level = 25.0
		ab.execution_type = ab_spec.get("exec_type", WeaponAbilityData.ExecutionType.MELEE_ADJACENT)
		ab.damage_multiplier = float(ab_spec.get("dmg_mult", 1.35))
		ab.accuracy_bonus = float(ab_spec.get("acc_bonus", 0.10))
		ab.description = String(ab_spec.get("desc", ""))
		ab.armor_penetration = float(ab_spec.get("armor_pen", 0.0))
		ab.guaranteed_crit = bool(ab_spec.get("guaranteed_crit", ab_spec.get(" guaranteed_crit", false)))
		ab.strike_count = int(ab_spec.get("strike_count", 1))
		ab.range_override = int(ab_spec.get("range_override", 0))
		ab.area_radius = int(ab_spec.get("area_radius", 0))
		ab.status_effect_id = String(ab_spec.get("status", ""))
		ab.status_chance = float(ab_spec.get("status_chance", 0.0))
		ab.status_duration = int(ab_spec.get("status_dur", 2))
		ab.self_defense_buff = float(ab_spec.get("self_def", 0.0))
		ab.cooldown_turns = int(ab_spec.get("cd", 4))
		item.active_ability = ab

	return item

static func get_weapons_for_skill(skill_id: SkillData.SkillId) -> Array[ItemData]:
	var reg = get_weapon_registry()
	var result: Array[ItemData] = []
	for item_id in reg.keys():
		var spec: Dictionary = reg[item_id]
		if spec.get("skill_id") == skill_id:
			result.append(create_weapon(String(item_id)))
	return result
