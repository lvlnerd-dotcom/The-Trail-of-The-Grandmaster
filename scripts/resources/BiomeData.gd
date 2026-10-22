class_name BiomeData
extends Resource

## BiomeData: Defines floor biomes, atmospheric tints, monster spawn pools, and environmental rules.

@export var biome_id: String = ""
@export var biome_name: String = ""
@export var depth_bracket: int = 1 # 1 to 5
@export var floor_min: int = 1
@export var floor_max: int = 4
@export var wall_color: Color = Color(0.28, 0.30, 0.36, 1.0)
@export var floor_color: Color = Color(0.12, 0.14, 0.18, 1.0)
@export var environmental_rule_name: String = ""
@export var environmental_rule_desc: String = ""
@export var monster_spawn_pool: Array[Dictionary] = [] # Array of monster template definitions or monster_ids
@export var trap_pool: Array[int] = [0, 1] # Trap.TrapType indices
@export var mini_boss_id: String = ""

func _init(
	p_id: String = "",
	p_name: String = "",
	p_bracket: int = 1,
	p_min_fl: int = 1,
	p_max_fl: int = 4,
	p_wall: Color = Color(0.28, 0.30, 0.36),
	p_floor: Color = Color(0.12, 0.14, 0.18),
	p_rule_name: String = "",
	p_rule_desc: String = "",
	p_spawns: Array[Dictionary] = [],
	p_traps: Array[int] = [0, 1],
	p_boss_id: String = ""
) -> void:
	biome_id = p_id
	biome_name = p_name
	depth_bracket = p_bracket
	floor_min = p_min_fl
	floor_max = p_max_fl
	wall_color = p_wall
	floor_color = p_floor
	environmental_rule_name = p_rule_name
	environmental_rule_desc = p_rule_desc
	monster_spawn_pool = p_spawns
	trap_pool = p_traps
	mini_boss_id = p_boss_id

static var _cached_biomes: Array[BiomeData] = []

static func get_all_biomes() -> Array[BiomeData]:
	if not _cached_biomes.is_empty():
		return _cached_biomes
		
	var list: Array[BiomeData] = []
	
	# Bracket 1: Floors 1-4
	list.append(BiomeData.new(
		"sunken_crypts", "Sunken Crypts", 1, 1, 4,
		Color(0.22, 0.24, 0.28), Color(0.11, 0.12, 0.15),
		"Undead Fortitude", "+10% armor for all skeletal sentries and crypt ghouls.",
		[{"id": "skeleton_sentry", "weight": 40}, {"id": "crypt_ghoul", "weight": 35}, {"id": "bone_archer", "weight": 25}],
		[0, 1], "crypt_lord_malgok"
	))
	list.append(BiomeData.new(
		"fungal_caverns", "Fungal Caverns", 1, 1, 4,
		Color(0.20, 0.28, 0.22), Color(0.12, 0.16, 0.13),
		"Spore Cloud", "Slain fungal beasts release obscuring spore bursts.",
		[{"id": "spore_crawler", "weight": 45}, {"id": "myconid_brute", "weight": 30}, {"id": "shrieker", "weight": 25}],
		[1], "spore_goliath"
	))
	list.append(BiomeData.new(
		"abandoned_mineshafts", "Abandoned Mineshafts", 1, 1, 4,
		Color(0.32, 0.26, 0.20), Color(0.16, 0.13, 0.10),
		"Ore Veins", "Abundant mineral caches and supply coffers.",
		[{"id": "kobold_sapper", "weight": 40}, {"id": "mine_rat", "weight": 35}, {"id": "goblin_pickaxer", "weight": 25}],
		[0, 2], "mine_overseer"
	))
	list.append(BiomeData.new(
		"cobwebbed_cellars", "Cobwebbed Cellars", 1, 1, 4,
		Color(0.25, 0.25, 0.25), Color(0.14, 0.14, 0.15),
		"Silk Snares", "Hidden web tripwires ensnare careless intruders.",
		[{"id": "giant_cellar_spider", "weight": 45}, {"id": "web_lurker", "weight": 30}, {"id": "bandit_cutthroat", "weight": 25}],
		[0, 1, 2], "brood_mother"
	))

	# Bracket 2: Floors 5-8
	list.append(BiomeData.new(
		"crystalline_caves", "Crystalline Caves", 2, 5, 8,
		Color(0.20, 0.32, 0.40), Color(0.10, 0.18, 0.24),
		"Prismatic Refraction", "Crystalline surfaces deflect beam attacks.",
		[{"id": "crystal_golem", "weight": 35}, {"id": "prism_elemental", "weight": 35}, {"id": "gem_stalker", "weight": 30}],
		[0, 1], "crystal_colossus"
	))
	list.append(BiomeData.new(
		"cultist_sanctum", "Cultist Sanctum", 2, 5, 8,
		Color(0.36, 0.18, 0.22), Color(0.18, 0.08, 0.10),
		"Sacrificial Altars", "Unholy chants bolster dark acolytes.",
		[{"id": "blood_cultist", "weight": 40}, {"id": "dark_acolyte", "weight": 35}, {"id": "fanatic_blade", "weight": 25}],
		[0, 2], "high_inquisitor_vane"
	))
	list.append(BiomeData.new(
		"frozen_grottos", "Frozen Grottos", 2, 5, 8,
		Color(0.25, 0.35, 0.42), Color(0.15, 0.22, 0.28),
		"Sub-Zero Chill", "Frigid air slows recovery.",
		[{"id": "frost_wolf", "weight": 40}, {"id": "ice_wraith", "weight": 35}, {"id": "yeti_crusher", "weight": 25}],
		[0, 1], "frost_reaver"
	))
	list.append(BiomeData.new(
		"insectoid_hive", "Insectoid Hive", 2, 5, 8,
		Color(0.30, 0.28, 0.16), Color(0.16, 0.15, 0.08),
		"Swarm Pheromones", "Chitinous defenders surge in unison.",
		[{"id": "chitin_warrior", "weight": 40}, {"id": "acid_spitter", "weight": 35}, {"id": "hive_assassin", "weight": 25}],
		[1, 2], "hive_queen"
	))

	# Bracket 3: Floors 9-12
	list.append(BiomeData.new(
		"clockwork_foundry", "Clockwork Foundry", 3, 9, 12,
		Color(0.38, 0.30, 0.18), Color(0.20, 0.16, 0.10),
		"Mechanical Hardening", "Metallic constructs are immune to Bleed and Poison.",
		[{"id": "brass_automaton", "weight": 40}, {"id": "steam_cannon", "weight": 30}, {"id": "clockwork_warden", "weight": 30}],
		[0, 2], "clockwork_juggernaut"
	))
	list.append(BiomeData.new(
		"toxic_bogs", "Toxic Bogs", 3, 9, 12,
		Color(0.18, 0.30, 0.18), Color(0.08, 0.16, 0.08),
		"Miasmic Sludge", "Noxious vapors inflict creeping toxins.",
		[{"id": "bog_hydra", "weight": 35}, {"id": "plague_toad", "weight": 40}, {"id": "mire_shambler", "weight": 25}],
		[1], "swamp_abomination"
	))
	list.append(BiomeData.new(
		"necromancers_ziggurat", "Necromancer's Ziggurat", 3, 9, 12,
		Color(0.28, 0.18, 0.35), Color(0.14, 0.08, 0.18),
		"Dark Resurgence", "Necrotic resonance sustains ancient wights.",
		[{"id": "lich_acolyte", "weight": 35}, {"id": "wight_champion", "weight": 35}, {"id": "shadow_wraith", "weight": 30}],
		[0, 1, 2], "arch_necromancer_morbious"
	))
	list.append(BiomeData.new(
		"abyssal_chasm", "Abyssal Chasm", 3, 9, 12,
		Color(0.14, 0.15, 0.26), Color(0.06, 0.07, 0.14),
		"Void Distortion", "Reality fractures allowing shadow blinks.",
		[{"id": "void_stalker", "weight": 40}, {"id": "chaos_hound", "weight": 35}, {"id": "eye_of_the_deep", "weight": 25}],
		[0, 1], "void_behemoth"
	))

	# Bracket 4: Floors 13-16
	list.append(BiomeData.new(
		"demonic_citadels", "Demonic Citadels", 4, 13, 16,
		Color(0.40, 0.14, 0.14), Color(0.20, 0.06, 0.06),
		"Brimstone Heat", "Hellfire scalds all who linger.",
		[{"id": "hellknight", "weight": 40}, {"id": "brimstone_fiend", "weight": 35}, {"id": "succubus_hexer", "weight": 25}],
		[0, 1], "pit_fiend_malgath"
	))
	list.append(BiomeData.new(
		"dragon_graveyards", "Dragon Graveyards", 4, 13, 16,
		Color(0.30, 0.28, 0.28), Color(0.15, 0.14, 0.14),
		"Ancient Scales", "Dense bone dust provides natural armor soak.",
		[{"id": "skeletal_wyvern", "weight": 35}, {"id": "drakescale_reaver", "weight": 35}, {"id": "wyrm_cultist", "weight": 30}],
		[0, 2], "dracolich_ossius"
	))
	list.append(BiomeData.new(
		"illusionary_labyrinths", "Illusionary Labyrinths", 4, 13, 16,
		Color(0.32, 0.24, 0.38), Color(0.16, 0.11, 0.20),
		"Phantasmal Mirage", "Shifting walls and phantoms conceal doorways.",
		[{"id": "mirror_phantom", "weight": 35}, {"id": "mind_flayer", "weight": 35}, {"id": "phase_assassin", "weight": 30}],
		[1, 2], "phantasm_archon"
	))
	list.append(BiomeData.new(
		"blighted_sanctuaries", "Blighted Sanctuaries", 4, 13, 16,
		Color(0.26, 0.28, 0.20), Color(0.13, 0.14, 0.09),
		"Corrupted Grace", "Fallen clergy channels inverted restoration.",
		[{"id": "fallen_paladin", "weight": 40}, {"id": "corrupted_seraph", "weight": 35}, {"id": "plague_priest", "weight": 25}],
		[0, 1], "corrupted_seraph_boss"
	))

	# Bracket 5: Floors 17-20
	list.append(BiomeData.new(
		"pandemonium_vaults", "Pandemonium Vaults", 5, 17, 20,
		Color(0.42, 0.16, 0.20), Color(0.22, 0.08, 0.10),
		"Pure Chaos", "Unstable magical fluctuations.",
		[{"id": "arch_fiend", "weight": 40}, {"id": "chaos_overlord", "weight": 35}, {"id": "doomguard", "weight": 25}],
		[0, 1, 2], ""
	))
	list.append(BiomeData.new(
		"grave_forgotten_gods", "Grave of the Forgotten Gods", 5, 17, 20,
		Color(0.24, 0.24, 0.36), Color(0.12, 0.12, 0.18),
		"Deicide Echo", "Dying astral energies empower divine defiance.",
		[{"id": "titan_remnant", "weight": 35}, {"id": "astral_lich", "weight": 35}, {"id": "avatar_of_ruin", "weight": 30}],
		[0, 1], ""
	))
	list.append(BiomeData.new(
		"grandmasters_gauntlet", "The Grandmaster's Gauntlet", 5, 17, 20,
		Color(0.35, 0.30, 0.25), Color(0.18, 0.15, 0.12),
		"Master's Trial", "High combat precision and discipline required.",
		[{"id": "weapon_master_disciple", "weight": 40}, {"id": "astral_monk", "weight": 35}, {"id": "shadow_grandmaster", "weight": 25}],
		[0, 2], ""
	))
	list.append(BiomeData.new(
		"time_fractured_ruins", "Time-Fractured Ruins", 5, 17, 20,
		Color(0.20, 0.34, 0.36), Color(0.10, 0.17, 0.18),
		"Temporal Dilation", "Anomalies cause temporal shifts in turn recovery.",
		[{"id": "chronos_anomaly", "weight": 35}, {"id": "paradox_knight", "weight": 35}, {"id": "temporal_weaver", "weight": 30}],
		[0, 1, 2], ""
	))

	_cached_biomes = list
	return _cached_biomes

static func get_biomes_for_bracket(bracket: int) -> Array[BiomeData]:
	var all = get_all_biomes()
	var res: Array[BiomeData] = []
	for b in all:
		if b.depth_bracket == bracket:
			res.append(b)
	return res

static func get_biome_by_id(p_id: String) -> BiomeData:
	for b in get_all_biomes():
		if b.biome_id == p_id:
			return b
	return null

## Selects 1 biome for each 4-floor bracket deterministically using seed_val
## Returns a Dictionary mapping bracket index (0..4) to the selected BiomeData.
static func roll_run_biomes(seed_val: int = -1) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	if seed_val >= 0:
		rng.seed = seed_val
	else:
		rng.randomize()
		
	var result: Dictionary = {}
	for bracket_idx in range(5):
		var bracket_num = bracket_idx + 1
		var candidates = get_biomes_for_bracket(bracket_num)
		if candidates.size() > 0:
			var picked_idx = rng.randi() % candidates.size()
			result[bracket_idx] = candidates[picked_idx]
			# Also populate with 1-based index for convenience
			result[bracket_num] = candidates[picked_idx]
	return result
