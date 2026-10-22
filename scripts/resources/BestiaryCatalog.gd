class_name BestiaryCatalog
extends RefCounted

## BestiaryCatalog: Monster templates, archetypes, factions, and elite affixes.

# Monster Archetypes
enum Archetype {
	MELEE_BRUTE,
	RANGED_ARCHER,
	SPELLCASTER,
	STEALTH_LURKER,
	TANK_SHIELDBEARER
}

# Monster Factions
enum Faction {
	FACTION_RAIDER,
	FACTION_UNDEAD,
	FACTION_BEAST,
	FACTION_DEMONIC,
	FACTION_CONSTRUCT,
	FACTION_ASTRAL
}

# Inflicted Status Effects
const STATUS_NONE: String = "NONE"
const STATUS_POISON: String = "POISON"
const STATUS_BLEED: String = "BLEED"
const STATUS_STUN: String = "STUN"
const STATUS_BLINDNESS: String = "BLINDNESS"
const STATUS_CHILL: String = "CHILL"

# Elite Affixes
const ELITE_AFFIXES: Array[String] = [
	"Vampiric",
	"Swift",
	"Flame-Touched",
	"Venomous",
	"Armored"
]

static var _catalog: Dictionary = {}

static func get_all_templates() -> Dictionary:
	if not _catalog.is_empty():
		return _catalog
		
	var c: Dictionary = {}
	
	# Helper lambda to add template
	var add = func(
		m_id: String, name: String, hp: float, hp_scale: float,
		atk: int, acc: float, armor: int, dodge: float,
		w_id: String, s_id: String,
		arch: Archetype, fac: Faction,
		undead: bool, intel: bool, ambusher: bool,
		spell: String, status: String, exp: int,
		is_boss: bool = false
	):
		c[m_id] = {
			"monster_id": m_id,
			"display_name": name,
			"hp_base": hp,
			"hp_scale_per_floor": hp_scale,
			"attack_power": atk,
			"accuracy": acc,
			"armor_soak": armor,
			"dodge_rating": dodge,
			"weapon_id": w_id,
			"sidearm_id": s_id,
			"archetype": arch,
			"faction": fac,
			"is_undead": undead,
			"is_intelligent": intel,
			"is_ambusher": ambusher,
			"signature_spell_id": spell,
			"inflicted_status": status,
			"kill_exp": exp,
			"is_mini_boss": is_boss
		}

	# --- BRACKET 1: FLOORS 1-4 ---
	# Sunken Crypts
	add.call("skeleton_sentry", "Skeleton Sentry", 22.0, 3.0, 5, 0.0, 2, 0.05, "sword_short", "dagger_iron", Archetype.MELEE_BRUTE, Faction.FACTION_UNDEAD, true, false, false, "", STATUS_NONE, 40, false)
	add.call("crypt_ghoul", "Crypt Ghoul", 26.0, 3.5, 6, 0.05, 1, 0.10, "unarmed_strikes", "dagger_iron", Archetype.MELEE_BRUTE, Faction.FACTION_UNDEAD, true, false, false, "", STATUS_BLEED, 45, false)
	add.call("bone_archer", "Bone Archer", 18.0, 2.5, 4, 0.10, 1, 0.15, "bow_hunting", "dagger_iron", Archetype.RANGED_ARCHER, Faction.FACTION_UNDEAD, true, false, false, "", STATUS_NONE, 45, false)
	add.call("crypt_lord_malgok", "Crypt Lord Malgok", 160.0, 10.0, 12, 0.15, 6, 0.05, "sword_broad", "mace_flanged", Archetype.MELEE_BRUTE, Faction.FACTION_UNDEAD, true, true, false, "fireball", STATUS_BLEED, 250, true)

	# Fungal Caverns
	add.call("spore_crawler", "Spore Crawler", 20.0, 2.5, 4, 0.0, 1, 0.10, "unarmed_strikes", "dagger_iron", Archetype.MELEE_BRUTE, Faction.FACTION_BEAST, false, false, false, "", STATUS_POISON, 35, false)
	add.call("myconid_brute", "Myconid Brute", 32.0, 4.0, 7, -0.05, 3, 0.0, "mace_flanged", "dagger_iron", Archetype.TANK_SHIELDBEARER, Faction.FACTION_BEAST, false, false, false, "", STATUS_STUN, 50, false)
	add.call("shrieker", "Fungal Shrieker", 15.0, 2.0, 3, 0.10, 0, 0.15, "staff_oak", "dagger_iron", Archetype.SPELLCASTER, Faction.FACTION_BEAST, false, false, false, "fireball", STATUS_BLINDNESS, 40, false)
	add.call("spore_goliath", "Spore Goliath", 170.0, 12.0, 14, 0.05, 5, 0.05, "mace_flanged", "sword_short", Archetype.MELEE_BRUTE, Faction.FACTION_BEAST, false, false, false, "fireball", STATUS_POISON, 260, true)

	# Abandoned Mineshafts
	add.call("kobold_sapper", "Kobold Sapper", 16.0, 2.0, 4, 0.10, 1, 0.20, "dagger_iron", "dagger_iron", Archetype.STEALTH_LURKER, Faction.FACTION_RAIDER, false, true, true, "", STATUS_BLEED, 35, false)
	add.call("mine_rat", "Plague Mine Rat", 14.0, 2.0, 3, 0.05, 0, 0.25, "unarmed_strikes", "dagger_iron", Archetype.MELEE_BRUTE, Faction.FACTION_BEAST, false, false, false, "", STATUS_POISON, 30, false)
	add.call("goblin_pickaxer", "Goblin Pickaxer", 22.0, 2.8, 6, 0.0, 2, 0.10, "axe_hand", "dagger_iron", Archetype.MELEE_BRUTE, Faction.FACTION_RAIDER, false, true, false, "", STATUS_STUN, 42, false)
	add.call("mine_overseer", "Mine Overseer", 150.0, 10.0, 13, 0.15, 6, 0.10, "axe_hand", "sword_short", Archetype.TANK_SHIELDBEARER, Faction.FACTION_RAIDER, false, true, false, "", STATUS_STUN, 240, true)

	# Cobwebbed Cellars
	add.call("giant_cellar_spider", "Giant Cellar Spider", 24.0, 3.0, 5, 0.10, 2, 0.15, "unarmed_strikes", "dagger_iron", Archetype.MELEE_BRUTE, Faction.FACTION_BEAST, false, false, false, "", STATUS_POISON, 45, false)
	add.call("web_lurker", "Web Lurker", 18.0, 2.5, 6, 0.15, 1, 0.25, "dagger_stiletto", "dagger_iron", Archetype.STEALTH_LURKER, Faction.FACTION_BEAST, false, false, true, "", STATUS_POISON, 48, false)
	add.call("bandit_cutthroat", "Bandit Cutthroat", 22.0, 3.0, 5, 0.10, 2, 0.15, "sword_short", "dagger_iron", Archetype.MELEE_BRUTE, Faction.FACTION_RAIDER, false, true, false, "", STATUS_BLEED, 45, false)
	add.call("brood_mother", "Brood Mother", 155.0, 11.0, 12, 0.15, 4, 0.15, "unarmed_strikes", "dagger_stiletto", Archetype.MELEE_BRUTE, Faction.FACTION_BEAST, false, false, false, "", STATUS_POISON, 250, true)

	# --- BRACKET 2: FLOORS 5-8 ---
	# Crystalline Caves
	add.call("crystal_golem", "Crystal Golem", 45.0, 5.0, 9, -0.05, 6, 0.0, "mace_flanged", "dagger_iron", Archetype.TANK_SHIELDBEARER, Faction.FACTION_CONSTRUCT, false, false, false, "", STATUS_STUN, 70, false)
	add.call("prism_elemental", "Prism Elemental", 30.0, 4.0, 8, 0.10, 2, 0.20, "staff_oak", "dagger_iron", Archetype.SPELLCASTER, Faction.FACTION_ASTRAL, false, false, false, "fireball", STATUS_BLINDNESS, 75, false)
	add.call("gem_stalker", "Gem Stalker", 32.0, 4.0, 8, 0.15, 3, 0.25, "dagger_stiletto", "dagger_iron", Archetype.STEALTH_LURKER, Faction.FACTION_BEAST, false, false, true, "", STATUS_BLEED, 72, false)
	add.call("crystal_colossus", "Crystal Colossus", 240.0, 15.0, 18, 0.10, 10, 0.05, "mace_flanged", "sword_broad", Archetype.TANK_SHIELDBEARER, Faction.FACTION_CONSTRUCT, false, false, false, "", STATUS_STUN, 380, true)

	# Cultist Sanctum
	add.call("blood_cultist", "Blood Cultist", 35.0, 4.5, 8, 0.10, 3, 0.15, "dagger_stiletto", "dagger_iron", Archetype.MELEE_BRUTE, Faction.FACTION_RAIDER, false, true, false, "", STATUS_BLEED, 65, false)
	add.call("dark_acolyte", "Dark Acolyte", 28.0, 3.5, 7, 0.15, 1, 0.15, "staff_oak", "dagger_iron", Archetype.SPELLCASTER, Faction.FACTION_RAIDER, false, true, false, "fireball", STATUS_BLINDNESS, 70, false)
	add.call("fanatic_blade", "Fanatic Blade", 32.0, 4.0, 9, 0.20, 2, 0.20, "sword_scimitar", "dagger_stiletto", Archetype.MELEE_BRUTE, Faction.FACTION_RAIDER, false, true, false, "", STATUS_BLEED, 75, false)
	add.call("high_inquisitor_vane", "High Inquisitor Vane", 210.0, 14.0, 16, 0.20, 7, 0.15, "sword_broad", "dagger_stiletto", Archetype.SPELLCASTER, Faction.FACTION_RAIDER, false, true, false, "fireball", STATUS_BLEED, 370, true)

	# Frozen Grottos
	add.call("frost_wolf", "Frost Wolf", 34.0, 4.0, 8, 0.15, 2, 0.25, "unarmed_strikes", "dagger_iron", Archetype.MELEE_BRUTE, Faction.FACTION_BEAST, false, false, false, "", STATUS_CHILL, 65, false)
	add.call("ice_wraith", "Ice Wraith", 30.0, 3.8, 8, 0.10, 3, 0.30, "staff_oak", "dagger_iron", Archetype.SPELLCASTER, Faction.FACTION_UNDEAD, true, false, true, "fireball", STATUS_CHILL, 70, false)
	add.call("yeti_crusher", "Yeti Crusher", 50.0, 6.0, 11, -0.05, 5, 0.05, "mace_flanged", "sword_short", Archetype.TANK_SHIELDBEARER, Faction.FACTION_BEAST, false, false, false, "", STATUS_STUN, 85, false)
	add.call("frost_reaver", "Frost Reaver", 230.0, 16.0, 18, 0.15, 8, 0.10, "axe_hand", "sword_short", Archetype.MELEE_BRUTE, Faction.FACTION_BEAST, false, false, false, "", STATUS_CHILL, 390, true)

	# Insectoid Hive
	add.call("chitin_warrior", "Chitin Warrior", 40.0, 4.5, 9, 0.10, 5, 0.10, "spear_hunting", "dagger_iron", Archetype.TANK_SHIELDBEARER, Faction.FACTION_BEAST, false, false, false, "", STATUS_POISON, 75, false)
	add.call("acid_spitter", "Acid Spitter", 28.0, 3.5, 8, 0.15, 2, 0.20, "bow_hunting", "dagger_iron", Archetype.RANGED_ARCHER, Faction.FACTION_BEAST, false, false, false, "", STATUS_POISON, 70, false)
	add.call("hive_assassin", "Hive Assassin", 32.0, 4.0, 10, 0.20, 2, 0.30, "dagger_stiletto", "dagger_iron", Archetype.STEALTH_LURKER, Faction.FACTION_BEAST, false, false, true, "", STATUS_POISON, 80, false)
	add.call("hive_queen", "Hive Queen", 220.0, 15.0, 17, 0.15, 7, 0.15, "spear_hunting", "dagger_stiletto", Archetype.MELEE_BRUTE, Faction.FACTION_BEAST, false, false, false, "fireball", STATUS_POISON, 380, true)

	# --- BRACKET 3: FLOORS 9-12 ---
	# Clockwork Foundry
	add.call("brass_automaton", "Brass Automaton", 55.0, 6.0, 11, 0.05, 8, 0.05, "sword_broad", "mace_flanged", Archetype.TANK_SHIELDBEARER, Faction.FACTION_CONSTRUCT, false, false, false, "", STATUS_STUN, 110, false)
	add.call("steam_cannon", "Steam Cannon", 45.0, 5.0, 12, 0.15, 5, 0.05, "bow_hunting", "mace_flanged", Archetype.RANGED_ARCHER, Faction.FACTION_CONSTRUCT, false, false, false, "", STATUS_STUN, 115, false)
	add.call("clockwork_warden", "Clockwork Warden", 50.0, 5.5, 12, 0.10, 7, 0.10, "spear_hunting", "sword_short", Archetype.MELEE_BRUTE, Faction.FACTION_CONSTRUCT, false, false, false, "", STATUS_NONE, 120, false)
	add.call("clockwork_juggernaut", "Clockwork Juggernaut", 320.0, 20.0, 24, 0.15, 12, 0.05, "mace_flanged", "sword_broad", Archetype.TANK_SHIELDBEARER, Faction.FACTION_CONSTRUCT, false, false, false, "", STATUS_STUN, 520, true)

	# Toxic Bogs
	add.call("bog_hydra", "Bog Hydra", 60.0, 7.0, 13, 0.05, 5, 0.10, "unarmed_strikes", "dagger_iron", Archetype.MELEE_BRUTE, Faction.FACTION_BEAST, false, false, false, "", STATUS_POISON, 115, false)
	add.call("plague_toad", "Plague Toad", 40.0, 5.0, 10, 0.10, 3, 0.20, "unarmed_strikes", "dagger_iron", Archetype.MELEE_BRUTE, Faction.FACTION_BEAST, false, false, false, "", STATUS_POISON, 100, false)
	add.call("mire_shambler", "Mire Shambler", 50.0, 6.0, 11, 0.0, 6, 0.05, "mace_flanged", "dagger_iron", Archetype.TANK_SHIELDBEARER, Faction.FACTION_BEAST, false, false, false, "", STATUS_BLEED, 110, false)
	add.call("swamp_abomination", "Swamp Abomination", 310.0, 19.0, 22, 0.10, 8, 0.10, "mace_flanged", "dagger_stiletto", Archetype.MELEE_BRUTE, Faction.FACTION_BEAST, false, false, false, "fireball", STATUS_POISON, 500, true)

	# Necromancer's Ziggurat
	add.call("lich_acolyte", "Lich Acolyte", 42.0, 5.0, 11, 0.15, 3, 0.15, "staff_oak", "dagger_stiletto", Archetype.SPELLCASTER, Faction.FACTION_UNDEAD, true, true, false, "fireball", STATUS_BLINDNESS, 125, false)
	add.call("wight_champion", "Wight Champion", 58.0, 6.5, 13, 0.10, 7, 0.10, "sword_broad", "sword_short", Archetype.MELEE_BRUTE, Faction.FACTION_UNDEAD, true, true, false, "", STATUS_BLEED, 130, false)
	add.call("shadow_wraith", "Shadow Wraith", 38.0, 4.5, 12, 0.20, 2, 0.35, "dagger_stiletto", "dagger_stiletto", Archetype.STEALTH_LURKER, Faction.FACTION_UNDEAD, true, false, true, "", STATUS_CHILL, 120, false)
	add.call("arch_necromancer_morbious", "Arch-Necromancer Morbious", 280.0, 18.0, 20, 0.20, 6, 0.20, "staff_oak", "dagger_stiletto", Archetype.SPELLCASTER, Faction.FACTION_UNDEAD, true, true, false, "fireball", STATUS_BLINDNESS, 530, true)

	# Abyssal Chasm
	add.call("void_stalker", "Void Stalker", 48.0, 5.5, 12, 0.20, 4, 0.25, "dagger_stiletto", "dagger_stiletto", Archetype.STEALTH_LURKER, Faction.FACTION_ASTRAL, false, false, true, "", STATUS_BLINDNESS, 120, false)
	add.call("chaos_hound", "Chaos Hound", 45.0, 5.0, 12, 0.15, 3, 0.20, "unarmed_strikes", "dagger_iron", Archetype.MELEE_BRUTE, Faction.FACTION_ASTRAL, false, false, false, "", STATUS_BLEED, 115, false)
	add.call("eye_of_the_deep", "Eye of the Deep", 38.0, 4.5, 11, 0.20, 2, 0.20, "staff_oak", "dagger_iron", Archetype.SPELLCASTER, Faction.FACTION_ASTRAL, false, true, false, "fireball", STATUS_STUN, 125, false)
	add.call("void_behemoth", "Void Behemoth", 330.0, 21.0, 23, 0.15, 9, 0.10, "mace_flanged", "sword_broad", Archetype.MELEE_BRUTE, Faction.FACTION_ASTRAL, false, false, false, "fireball", STATUS_BLINDNESS, 540, true)

	# --- BRACKET 4: FLOORS 13-16 ---
	# Demonic Citadels
	add.call("hellknight", "Hellknight", 75.0, 7.5, 16, 0.15, 9, 0.10, "sword_broad", "sword_short", Archetype.TANK_SHIELDBEARER, Faction.FACTION_DEMONIC, false, true, false, "", STATUS_BLEED, 170, false)
	add.call("brimstone_fiend", "Brimstone Fiend", 65.0, 7.0, 15, 0.15, 6, 0.15, "axe_hand", "dagger_iron", Archetype.MELEE_BRUTE, Faction.FACTION_DEMONIC, false, false, false, "", STATUS_STUN, 160, false)
	add.call("succubus_hexer", "Succubus Hexer", 55.0, 6.0, 14, 0.20, 4, 0.25, "staff_oak", "dagger_stiletto", Archetype.SPELLCASTER, Faction.FACTION_DEMONIC, false, true, false, "fireball", STATUS_BLINDNESS, 175, false)
	add.call("pit_fiend_malgath", "Pit Fiend Malgath", 420.0, 24.0, 28, 0.20, 12, 0.10, "sword_broad", "axe_hand", Archetype.MELEE_BRUTE, Faction.FACTION_DEMONIC, false, true, false, "fireball", STATUS_BLEED, 750, true)

	# Dragon Graveyards
	add.call("skeletal_wyvern", "Skeletal Wyvern", 70.0, 7.0, 16, 0.15, 8, 0.15, "unarmed_strikes", "dagger_iron", Archetype.MELEE_BRUTE, Faction.FACTION_UNDEAD, true, false, false, "", STATUS_BLEED, 180, false)
	add.call("drakescale_reaver", "Drakescale Reaver", 80.0, 8.0, 17, 0.10, 11, 0.05, "axe_hand", "sword_short", Archetype.TANK_SHIELDBEARER, Faction.FACTION_RAIDER, false, true, false, "", STATUS_STUN, 185, false)
	add.call("wyrm_cultist", "Wyrm Cultist", 58.0, 6.0, 14, 0.15, 5, 0.20, "staff_oak", "dagger_stiletto", Archetype.SPELLCASTER, Faction.FACTION_RAIDER, false, true, false, "fireball", STATUS_BLINDNESS, 170, false)
	add.call("dracolich_ossius", "Dracolich Ossius", 440.0, 25.0, 30, 0.20, 13, 0.10, "sword_broad", "mace_flanged", Archetype.MELEE_BRUTE, Faction.FACTION_UNDEAD, true, true, false, "fireball", STATUS_CHILL, 780, true)

	# Illusionary Labyrinths
	add.call("mirror_phantom", "Mirror Phantom", 52.0, 5.5, 14, 0.20, 3, 0.35, "dagger_stiletto", "dagger_stiletto", Archetype.STEALTH_LURKER, Faction.FACTION_ASTRAL, false, false, true, "", STATUS_BLINDNESS, 165, false)
	add.call("mind_flayer", "Mind Flayer", 56.0, 6.0, 15, 0.20, 4, 0.20, "staff_oak", "dagger_stiletto", Archetype.SPELLCASTER, Faction.FACTION_ASTRAL, false, true, false, "fireball", STATUS_STUN, 180, false)
	add.call("phase_assassin", "Phase Assassin", 60.0, 6.5, 16, 0.25, 5, 0.30, "sword_scimitar", "dagger_stiletto", Archetype.STEALTH_LURKER, Faction.FACTION_RAIDER, false, true, true, "", STATUS_BLEED, 185, false)
	add.call("phantasm_archon", "Phantasm Archon", 380.0, 22.0, 26, 0.25, 8, 0.25, "staff_oak", "sword_scimitar", Archetype.SPELLCASTER, Faction.FACTION_ASTRAL, false, true, false, "fireball", STATUS_BLINDNESS, 720, true)

	# Blighted Sanctuaries
	add.call("fallen_paladin", "Fallen Paladin", 78.0, 8.0, 16, 0.15, 10, 0.10, "sword_broad", "mace_flanged", Archetype.TANK_SHIELDBEARER, Faction.FACTION_DEMONIC, false, true, false, "", STATUS_BLEED, 180, false)
	add.call("corrupted_seraph", "Corrupted Seraph", 65.0, 7.0, 16, 0.20, 6, 0.20, "spear_hunting", "sword_short", Archetype.MELEE_BRUTE, Faction.FACTION_DEMONIC, false, true, false, "fireball", STATUS_BLINDNESS, 185, false)
	add.call("plague_priest", "Plague Priest", 54.0, 5.5, 14, 0.15, 5, 0.15, "staff_oak", "dagger_iron", Archetype.SPELLCASTER, Faction.FACTION_DEMONIC, false, true, false, "fireball", STATUS_POISON, 175, false)
	add.call("corrupted_seraph_boss", "Corrupted Seraph", 400.0, 23.0, 27, 0.20, 11, 0.15, "spear_hunting", "sword_broad", Archetype.SPELLCASTER, Faction.FACTION_DEMONIC, false, true, false, "fireball", STATUS_BLINDNESS, 740, true)

	# --- BRACKET 5: FLOORS 17-20 ---
	# Pandemonium Vaults
	add.call("arch_fiend", "Arch-Fiend", 95.0, 9.0, 20, 0.20, 10, 0.15, "sword_broad", "axe_hand", Archetype.MELEE_BRUTE, Faction.FACTION_DEMONIC, false, true, false, "fireball", STATUS_BLEED, 240, false)
	add.call("chaos_overlord", "Chaos Overlord", 88.0, 8.5, 19, 0.20, 8, 0.20, "staff_oak", "sword_short", Archetype.SPELLCASTER, Faction.FACTION_DEMONIC, false, true, false, "fireball", STATUS_BLINDNESS, 250, false)
	add.call("doomguard", "Doomguard", 110.0, 10.0, 20, 0.10, 12, 0.05, "mace_flanged", "sword_broad", Archetype.TANK_SHIELDBEARER, Faction.FACTION_DEMONIC, false, true, false, "", STATUS_STUN, 260, false)

	# Grave of the Forgotten Gods
	add.call("titan_remnant", "Titan Remnant", 120.0, 11.0, 22, 0.10, 12, 0.05, "mace_flanged", "sword_broad", Archetype.TANK_SHIELDBEARER, Faction.FACTION_CONSTRUCT, false, false, false, "", STATUS_STUN, 270, false)
	add.call("astral_lich", "Astral Lich", 85.0, 8.0, 20, 0.25, 6, 0.25, "staff_oak", "dagger_stiletto", Archetype.SPELLCASTER, Faction.FACTION_UNDEAD, true, true, false, "fireball", STATUS_BLINDNESS, 260, false)
	add.call("avatar_of_ruin", "Avatar of Ruin", 100.0, 9.5, 21, 0.20, 9, 0.15, "sword_broad", "spear_hunting", Archetype.MELEE_BRUTE, Faction.FACTION_ASTRAL, false, true, false, "fireball", STATUS_BLEED, 280, false)

	# The Grandmaster's Gauntlet
	add.call("weapon_master_disciple", "Weapon Master Disciple", 90.0, 8.5, 20, 0.25, 8, 0.20, "sword_scimitar", "sword_short", Archetype.MELEE_BRUTE, Faction.FACTION_RAIDER, false, true, false, "", STATUS_BLEED, 250, false)
	add.call("astral_monk", "Astral Monk", 85.0, 8.0, 19, 0.25, 7, 0.30, "unarmed_strikes", "dagger_stiletto", Archetype.MELEE_BRUTE, Faction.FACTION_ASTRAL, false, true, false, "", STATUS_STUN, 255, false)
	add.call("shadow_grandmaster", "Shadow Grandmaster Disciple", 80.0, 7.5, 21, 0.30, 6, 0.35, "dagger_stiletto", "dagger_stiletto", Archetype.STEALTH_LURKER, Faction.FACTION_RAIDER, false, true, true, "", STATUS_POISON, 270, false)

	# Time-Fractured Ruins
	add.call("chronos_anomaly", "Chronos Anomaly", 88.0, 8.5, 19, 0.20, 7, 0.25, "unarmed_strikes", "dagger_iron", Archetype.MELEE_BRUTE, Faction.FACTION_ASTRAL, false, false, false, "", STATUS_CHILL, 250, false)
	add.call("paradox_knight", "Paradox Knight", 105.0, 9.5, 21, 0.15, 11, 0.10, "sword_broad", "sword_short", Archetype.TANK_SHIELDBEARER, Faction.FACTION_CONSTRUCT, false, true, false, "", STATUS_STUN, 265, false)
	add.call("temporal_weaver", "Temporal Weaver", 80.0, 7.5, 19, 0.25, 6, 0.25, "staff_oak", "dagger_stiletto", Archetype.SPELLCASTER, Faction.FACTION_ASTRAL, false, true, false, "fireball", STATUS_CHILL, 260, false)

	_catalog = c
	return _catalog

static func get_monster_template(m_id: String) -> Dictionary:
	var cat = get_all_templates()
	return cat.get(m_id, {})

static func roll_elite_affix(rng: RandomNumberGenerator = null) -> String:
	if rng:
		return ELITE_AFFIXES[rng.randi() % ELITE_AFFIXES.size()]
	return ELITE_AFFIXES[randi() % ELITE_AFFIXES.size()]

static func get_random_monster_for_biome(biome: BiomeData, rng: RandomNumberGenerator = null) -> Dictionary:
	if not biome or biome.monster_spawn_pool.is_empty():
		return get_monster_template("dungeon_goblin")
		
	var pool = biome.monster_spawn_pool
	var total_weight: int = 0
	for entry in pool:
		total_weight += int(entry.get("weight", 10))
		
	var roll = (rng.randi() % total_weight) if rng else (randi() % total_weight)
	var accum = 0
	for entry in pool:
		accum += int(entry.get("weight", 10))
		if roll < accum:
			return get_monster_template(str(entry.get("id", "")))
			
	return get_monster_template(str(pool[0].get("id", "")))
