@tool
extends McpTestSuite

## Phase 7 Test Suite: The Grandmaster Encounter (Final Boss), End-Game Victory Loop,
## Procedural Audio Architecture, Polish & Complete Game Lifecycle.

func suite_name() -> String:
	return "phase7_boss_audio_lifecycle"

func _get_audio_mgr() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		var node = (loop as SceneTree).root.get_node_or_null("AudioManager")
		if node:
			return node
	var script = load("res://scripts/autoload/AudioManager.gd")
	if script:
		var node = track(script.new()) as Node
		node.name = "AudioManager"
		if loop and loop is SceneTree:
			(loop as SceneTree).root.add_child(node)
		return node
	return null

func _get_game_mgr() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		var root = (loop as SceneTree).root
		for child in root.get_children():
			if is_instance_valid(child) and child.name.contains("GameManager"):
				return child
	var script = load("res://scripts/autoload/GameManager.gd")
	if script:
		var node = track(script.new()) as Node
		node.name = "GameManager"
		if loop and loop is SceneTree:
			(loop as SceneTree).root.add_child(node)
		return node
	return null

func _get_meta_mgr() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		var node = (loop as SceneTree).root.get_node_or_null("MetaManager")
		if node:
			return node
	var script = load("res://scripts/autoload/MetaManager.gd")
	if script:
		var node = track(script.new()) as Node
		node.name = "MetaManager"
		if loop and loop is SceneTree:
			(loop as SceneTree).root.add_child(node)
		return node
	return null

# -----------------------------------------------------------------------------
# 1. PROCEDURAL 16-BIT PCM WAVE SYNTHESIS & AUDIO SETTINGS TESTS
# -----------------------------------------------------------------------------

func test_procedural_pcm_wave_synthesis() -> void:
	var audio_mgr = _get_audio_mgr()
	assert_true(audio_mgr != null, "AudioManager must be accessible")
	
	var stream = audio_mgr.get_or_synthesize_stream("bump") as AudioStreamWAV
	assert_true(stream != null, "Procedural wave generator must produce an AudioStreamWAV")
	assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS, "Synthesizer must output 16-bit linear PCM format")
	assert_eq(stream.mix_rate, 22050, "Synthesizer sample rate must be 22050 Hz")
	assert_true(stream.data.size() > 0, "Synthesized audio byte stream must contain PCM sample data")

func test_audio_sound_presets_coverage() -> void:
	var audio_mgr = _get_audio_mgr()
	assert_true(audio_mgr != null, "AudioManager must be accessible")
	
	var presets = [
		"bump", "footstep", "hit_flesh", "parry_clang", "dodge_whoosh",
		"potion_drink", "level_up", "explosion", "spell_cast", "spell_fizzle",
		"shrine_prayer", "door_reveal", "tremor", "boss_phase", "victory",
		"game_over", "ui_click", "item_pickup"
	]
	
	for p_name in presets:
		var s = audio_mgr.get_or_synthesize_stream(p_name) as AudioStreamWAV
		assert_true(s != null, "Preset '%s' must generate a valid audio stream" % p_name)
		assert_true(s.data.size() > 0, "Preset '%s' data stream must not be empty" % p_name)

func test_audio_looped_music_tracks_generation() -> void:
	var audio_mgr = _get_audio_mgr()
	assert_true(audio_mgr != null, "AudioManager must be accessible")
	
	var dungeon_music = audio_mgr.get_or_synthesize_stream("ambient_dungeon") as AudioStreamWAV
	assert_true(dungeon_music != null, "ambient_dungeon music track must synthesize properly")
	assert_eq(dungeon_music.loop_mode, AudioStreamWAV.LOOP_FORWARD, "ambient_dungeon must be configured with forward looping")
	
	var boss_music = audio_mgr.get_or_synthesize_stream("music_boss_grandmaster") as AudioStreamWAV
	assert_true(boss_music != null, "music_boss_grandmaster track must synthesize properly")
	assert_eq(boss_music.loop_mode, AudioStreamWAV.LOOP_FORWARD, "Boss music must be configured with forward looping")

func test_audio_bus_routing_and_volume_settings() -> void:
	var audio_mgr = _get_audio_mgr()
	assert_true(audio_mgr != null, "AudioManager must be accessible")
	
	audio_mgr.set_volume("Master", 0.65)
	audio_mgr.set_volume("Music", 0.50)
	audio_mgr.set_volume("SFX", 0.75)
	audio_mgr.set_volume("UI", 0.85)
	
	assert_true(abs(audio_mgr.get_volume("Master") - 0.65) < 0.01, "Master volume must update")
	assert_true(abs(audio_mgr.get_volume("Music") - 0.50) < 0.01, "Music volume must update")
	assert_true(abs(audio_mgr.get_volume("SFX") - 0.75) < 0.01, "SFX volume must update")
	assert_true(abs(audio_mgr.get_volume("UI") - 0.85) < 0.01, "UI volume must update")
	
	audio_mgr.save_settings()
	assert_true(FileAccess.file_exists("user://settings.json"), "Settings must persist to user://settings.json")
	
	# Reload and verify persistence
	audio_mgr.load_settings()
	assert_true(abs(audio_mgr.get_volume("Master") - 0.65) < 0.01, "Master volume must persist across load")

# -----------------------------------------------------------------------------
# 2. FLOOR 20 GRANDMASTER SANCTUM ARENA TESTS
# -----------------------------------------------------------------------------

func test_floor_20_sanctum_layout_and_pillars() -> void:
	var gen = track(DungeonGenerator.new(46, 32)) as DungeonGenerator
	var grid = track(DungeonGrid.new()) as DungeonGrid
	
	var result = gen.generate_dungeon(grid, 20)
	
	assert_eq(grid.grid_width, 32, "Floor 20 arena width must be 32")
	assert_eq(grid.grid_height, 24, "Floor 20 arena height must be 24")
	assert_eq(result["start_cell"], Vector2i(16, 20), "Player entrance must be located at (16, 20) on South wall")
	assert_eq(result["boss_spawn"], Vector2i(16, 11), "Grandmaster dais must be located at (16, 11) in center")
	assert_true(result["stairs_suppressed"], "Stairs must be suppressed during Floor 20 Boss encounter")
	assert_eq(result["exit_cell"], Vector2i(-1, -1), "Exit cell must be invalidated while boss is alive")
	
	# Verify 4 Indestructible Cover Pillars (2x2 wall clusters)
	var nw_pillar = [Vector2i(8, 6), Vector2i(9, 6), Vector2i(8, 7), Vector2i(9, 7)]
	for p_cell in nw_pillar:
		assert_false(grid.is_walkable(p_cell), "NW cover pillar cell %s must be impassable wall" % str(p_cell))
		
	var se_pillar = [Vector2i(22, 15), Vector2i(23, 15), Vector2i(22, 16), Vector2i(23, 16)]
	for p_cell in se_pillar:
		assert_false(grid.is_walkable(p_cell), "SE cover pillar cell %s must be impassable wall" % str(p_cell))
		
	# Verify open hall and center dais are walkable
	assert_true(grid.is_walkable(Vector2i(16, 11)), "Center dais (16, 11) must be walkable")
	assert_true(grid.is_walkable(Vector2i(16, 20)), "Entrance cell (16, 20) must be walkable")

# -----------------------------------------------------------------------------
# 3. GRANDMASTER BOSS 3-PHASE ENCOUNTER TESTS
# -----------------------------------------------------------------------------

func test_boss_phase_1_martial_ascendant_properties() -> void:
	var boss = track(GrandmasterBoss.new()) as GrandmasterBoss
	boss._ready()
	
	assert_eq(boss.enemy_name, "The Grandmaster", "Boss enemy name must be 'The Grandmaster'")
	assert_eq(boss.stats.current_hp, 450.0, "Grandmaster must possess 450 HP")
	assert_eq(boss.current_phase, GrandmasterBoss.Phase.PHASE_1_MARTIAL, "Boss must begin in Phase 1 (Martial)")
	assert_eq(boss.current_stance, GrandmasterBoss.Stance.BULWARK, "Phase 1 must begin in Bulwark stance")
	assert_eq(boss.BASE_ARMOR_SOAK, 8, "Base armor soak must be 8")

func test_boss_phase_2_arcane_sovereign_transition() -> void:
	var boss = track(GrandmasterBoss.new()) as GrandmasterBoss
	boss._ready()
	
	# Transition triggered when HP drops to or below 300
	boss.stats.current_hp = 300.0
	boss._on_boss_health_changed(300.0, 450.0)
	
	assert_eq(boss.current_phase, GrandmasterBoss.Phase.PHASE_2_ARCANE, "Boss must transition to Phase 2 at 300 HP")
	assert_eq(boss.arcane_ward_hp, 35.0, "Phase 2 transition must grant 35 HP Arcane Ward shield")

func test_boss_phase_3_transcendence_and_clones_spawn() -> void:
	var boss = track(GrandmasterBoss.new()) as GrandmasterBoss
	var grid = track(DungeonGrid.new()) as DungeonGrid
	grid.grid_width = 32
	grid.grid_height = 24
	for y in range(24):
		for x in range(32):
			grid.set_cell_walkable(Vector2i(x, y), true)
			
	boss._ready()
	boss.grid = grid
	boss.grid_pos = Vector2i(16, 11)
	
	# Transition triggered when HP drops to or below 150
	boss.stats.current_hp = 145.0
	boss._on_boss_health_changed(145.0, 450.0)
	
	assert_eq(boss.current_phase, GrandmasterBoss.Phase.PHASE_3_TRANSCENDENCE, "Boss must transition to Phase 3 at <= 150 HP")
	assert_eq(boss.spawned_clones.size(), 2, "Phase 3 must summon exactly 2 Spectral Clones (Shadow and Light)")
	assert_eq(boss.equilibrium_mode, GrandmasterBoss.Equilibrium.PHYSICAL_IMMUNE, "Phase 3 must initiate Harmonic Equilibrium with Physical Immunity")

func test_boss_defeat_and_relic_bestowal() -> void:
	var boss = track(GrandmasterBoss.new()) as GrandmasterBoss
	var grid = track(DungeonGrid.new()) as DungeonGrid
	grid.grid_width = 32
	grid.grid_height = 24
	for y in range(24):
		for x in range(32):
			grid.set_cell_walkable(Vector2i(x, y), true)
			
	var player = track(Player.new()) as Player
	var p_inv = track(InventoryComponent.new()) as InventoryComponent
	p_inv.name = "InventoryComponent"
	player.add_child(p_inv)
	player.inventory = p_inv
	
	boss._ready()
	boss.grid = grid
	boss.grid_pos = Vector2i(16, 11)
	boss.target_player = player
	
	# Trigger Boss Defeat
	boss.stats.current_hp = 0.0
	boss._on_boss_health_changed(0.0, 450.0)
	
	assert_true(boss.is_defeated, "Boss must be flagged as defeated")
	assert_true(boss.dropped_relic != null, "Boss must drop the legendary relic")
	assert_eq(boss.dropped_relic.item_id, "mantle_of_the_grandmaster", "Relic must be Mantle of the Grandmaster")
	assert_eq(boss.dropped_relic.armor_value, 10, "Mantle must provide 10 armor soak")
	assert_eq(boss.dropped_relic.parry_bonus, 15.0, "Mantle must grant +15% parry bonus")
	assert_eq(boss.dropped_relic.dodge_bonus, 15.0, "Mantle must grant +15% dodge bonus")
	assert_eq(boss.dropped_relic.carry_weight_bonus, 20.0, "Mantle must grant +20 Stones carry weight")
	assert_eq(boss.dropped_relic.attribute_bonuses["strength"], 3, "Mantle must grant +3 to all attributes")
	
	# Verify relic transferred into player inventory
	var has_mantle = false
	for item in p_inv.items:
		if item.item_id == "mantle_of_the_grandmaster":
			has_mantle = true
			break
	assert_true(has_mantle, "Player inventory must directly receive Mantle of the Grandmaster upon defeat")

# -----------------------------------------------------------------------------
# 4. POLISH: DECALS LAYER & CAMERA TRAUMA TESTS
# -----------------------------------------------------------------------------

func test_decals_layer_management() -> void:
	var decals = track(DecalsLayer.new()) as DecalsLayer
	decals._ready()
	
	decals.add_decal("blood", Vector2i(5, 5))
	decals.add_decal("scorch", Vector2i(6, 6))
	decals.add_decal("holy_glyph", Vector2i(7, 7))
	
	assert_eq(decals.decals.size(), 3, "DecalsLayer must register all added decals")
	assert_eq(decals.decals[0]["type"], "blood", "First decal must be blood")
	assert_eq(decals.decals[1]["type"], "scorch", "Second decal must be scorch")
	assert_eq(decals.decals[2]["type"], "holy_glyph", "Third decal must be holy_glyph")
	
	decals.clear_decals()
	assert_eq(decals.decals.size(), 0, "clear_decals must remove all decals on floor transition")

func test_dungeon_camera_directional_trauma() -> void:
	var cam = track(DungeonCamera.new()) as DungeonCamera
	cam._ready()
	
	cam.apply_trauma(0.5, Vector2(1, 0))
	assert_eq(cam.trauma, 0.5, "Camera trauma must be set to 0.5")
	assert_true(cam.kick_impulse.x > 0.0, "Directional trauma must apply positive X kick impulse")
	
	# Clamp check
	cam.apply_trauma(0.8, Vector2(0, 1))
	assert_eq(cam.trauma, 1.0, "Camera trauma must clamp to 1.0 maximum")

# -----------------------------------------------------------------------------
# 5. LIFECYCLE & VICTORY LOOP TESTS
# -----------------------------------------------------------------------------

func test_victory_loop_meta_exp_and_save_wipe() -> void:
	var game_mgr = _get_game_mgr()
	var meta_mgr = _get_meta_mgr()
	assert_true(game_mgr != null and meta_mgr != null, "Managers must be accessible")
	
	# Simulate active save
	game_mgr.start_new_run()
	assert_true(game_mgr.is_run_active, "New run must be marked active")
	
	var summary: Dictionary = {
		"floors_cleared": 20,
		"turns_survived": 120,
		"standard_kills": 25,
		"elite_kills": 4,
		"boss_kills": 1,
		"keystones_unlocked": 3,
		"gold_earned": 500,
		"victory": true
	}
	
	var meta_res = meta_mgr.record_run_completion(summary)
	
	# Mathematical Run EXP Formula strictly per GDD:
	# RunEXP = (Floors * 100) + (Std * 10) + (Elite * 30) + (Boss * 150) + (Keystones * 50) + floor(Gold * 0.10) + (Victory ? 1000 : 0)
	# (20 * 100) + (25 * 10) + (4 * 30) + (1 * 150) + (3 * 50) + (50) + 1000
	# = 2000 + 250 + 120 + 150 + 150 + 50 + 1000 = 3720
	assert_eq(meta_res["earned_exp"], 3720, "Victory run EXP must calculate to 3720 (including +1000 Victory Bonus)")
	
	# Verify save wipe on victory
	game_mgr.wipe_run_save()
	assert_false(game_mgr.has_active_save(), "Save file must be wiped from disk upon victory")

func test_bestiary_records_and_tiered_knowledge() -> void:
	var meta_mgr = _get_meta_mgr()
	assert_true(meta_mgr != null, "MetaManager must be accessible")
	
	var creature_id = "The Grandmaster"
	var t1 = meta_mgr.record_kill(creature_id)
	assert_true(t1 >= 1, "First kill must unlock knowledge Tier 1")
	
	for i in range(4):
		meta_mgr.record_kill(creature_id)
	var t2 = meta_mgr.profile.bestiary_records[creature_id]["tier"]
	assert_true(t2 >= 2, "5 kills must unlock knowledge Tier 2 (defenses)")
	
	for i in range(10):
		meta_mgr.record_kill(creature_id)
	var t3 = meta_mgr.profile.bestiary_records[creature_id]["tier"]
	assert_eq(t3, 3, "15 kills must unlock knowledge Tier 3 (full codex mastery & drops)")

# -----------------------------------------------------------------------------
# 5. USER FIXES: ATTRIBUTE SELECTION, GAME OVER CLOSE REMOVAL, MULTI-ATTACK
# -----------------------------------------------------------------------------

func test_character_creation_attribute_allocation() -> void:
	var modal_script = load("res://scripts/ui/CharacterCreationModal.gd")
	var modal = track(modal_script.new())
	
	# Default budget allocation: by default all attributes start at 1, 0 spent, 20 remaining
	assert_eq(modal.attributes["strength"], 1, "Strength should start at 1")
	assert_eq(modal.attributes["dexterity"], 1, "Dexterity should start at 1")
	assert_eq(modal.attributes["constitution"], 1, "Constitution should start at 1")
	assert_eq(modal.attributes["intelligence"], 1, "Intelligence should start at 1")
	assert_eq(modal.attributes["wisdom"], 1, "Wisdom should start at 1")
	assert_eq(modal.attributes["charisma"], 1, "Charisma should start at 1")
	assert_eq(modal.get_spent_points(), 0, "Default stats must spend 0 points")
	assert_eq(modal.get_remaining_points(), 20, "Default stats must have all 20 points remaining")
	
	# Cannot decrease below MIN_STAT (1)
	modal._modify_stat("strength", -1)
	assert_eq(modal.attributes["strength"], 1, "Strength cannot decrease below 1")
	assert_eq(modal.get_remaining_points(), 20, "Remaining points must stay at 20")
	
	# Distribute points: +4 STR (to 5), +4 DEX (to 5), +4 CON (to 5), +3 INT (to 4), +2 WIS (to 3), +3 CHA (to 4)
	for i in range(4): modal._modify_stat("strength", 1)
	for i in range(4): modal._modify_stat("dexterity", 1)
	for i in range(4): modal._modify_stat("constitution", 1)
	for i in range(3): modal._modify_stat("intelligence", 1)
	for i in range(2): modal._modify_stat("wisdom", 1)
	for i in range(3): modal._modify_stat("charisma", 1)
	
	assert_eq(modal.get_remaining_points(), 0, "All 20 points should now be spent")
	assert_eq(modal.get_spent_points(), 20, "Total spent points must equal 20")
	
	# Cannot increase above MAX_STAT or when remaining is 0
	modal._modify_stat("strength", 1)
	assert_eq(modal.attributes["strength"], 5, "Cannot increase when remaining points is 0")
	
	# Validate distribution via CharacterCreationData
	var validation = CharacterCreationData.validate_attribute_distribution(modal.attributes)
	assert_true(validation["is_valid"], "Fully allocated attribute distribution must be valid")

func test_character_creation_modal_scene_instantiation_and_open() -> void:
	var scene = load("res://scenes/ui/menus/CharacterCreationModal.tscn")
	assert_true(scene != null, "CharacterCreationModal.tscn must exist")
	var modal = track(scene.instantiate())
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		tree.root.add_child(modal)
	modal.call("open_modal")
	assert_true(modal.visible, "Modal must become visible upon open_modal()")
	assert_eq(modal.get_remaining_points(), 20, "Modal should open with 20 points remaining")
	assert_true(modal.btn_embark.disabled, "Embark button must be disabled when points remain to be distributed")
	assert_true(modal.btn_str_minus.disabled, "Minus button should be disabled when attribute is at minimum 1")
	assert_false(modal.btn_str_plus.disabled, "Plus button should be enabled when points are remaining")
	assert_true(modal.label_derived_crit != null, "Crit label must exist")
	assert_true(modal.label_derived_crit.text.length() > 0, "Crit label text must be populated without crash")
	assert_true(modal.label_derived_hp.text.length() > 0, "HP label text must be populated")

func test_game_over_modal_no_close_button() -> void:
	var scene = load("res://scenes/ui/menus/GameOverModal.tscn")
	assert_true(scene != null, "GameOverModal.tscn must load")
	var modal = track(scene.instantiate()) as GameOverModal
	
	var restart_btn = modal.get_node_or_null("VBox/ButtonContainer/BtnRestart")
	assert_true(restart_btn != null, "Try Again button must exist")
	
	var close_btn = modal.get_node_or_null("VBox/ButtonContainer/BtnClose")
	assert_true(close_btn == null, "Close button must NOT exist on GameOverModal (removed per user request)")

func test_game_over_try_again_routes_to_character_creation() -> void:
	var gm = _get_game_mgr()
	assert_true(gm != null, "GameManager must be accessible")
	gm.open_creation_on_main_menu = false
	
	var scene = load("res://scenes/ui/menus/GameOverModal.tscn")
	var modal = track(scene.instantiate()) as GameOverModal
	modal._ready()
	
	var flags = {"restart_emitted": false}
	modal.restart_requested.connect(func(): flags["restart_emitted"] = true)
	
	modal._on_restart_pressed()
	
	assert_true(flags["restart_emitted"], "restart_requested must be emitted on Try Again")
	assert_true(gm.open_creation_on_main_menu, "GameManager.open_creation_on_main_menu must be set to true on Try Again")
	
	# Verify MainMenu consumes this flag and opens character creation
	var menu_scene = load("res://scenes/ui/menus/MainMenu.tscn")
	var menu = track(menu_scene.instantiate()) as MainMenu
	menu._ready()
	
	assert_false(gm.open_creation_on_main_menu, "MainMenu must reset open_creation_on_main_menu to false")
	assert_true(menu.character_creation_modal.visible, "CharacterCreationModal must be opened and visible when navigating from Try Again")

func test_enemy_ai_simultaneous_attacks_and_chebyshev_range() -> void:
	seed(42)
	var grid: DungeonGrid = track(DungeonGrid.new()) as DungeonGrid
	grid.grid_width = 20
	grid.grid_height = 20
	var turn_mgr: TurnManager = track(TurnManager.new()) as TurnManager
	
	for x in range(5, 15):
		for y in range(5, 15):
			grid.set_cell_walkable(Vector2i(x, y), true)
			
	var player = track(Player.new()) as Player
	var p_stats = track(StatsComponent.new()) as StatsComponent
	p_stats.name = "StatsComponent"
	var p_skills = track(SkillComponent.new()) as SkillComponent
	p_skills.name = "SkillComponent"
	var p_combat = track(CombatComponent.new()) as CombatComponent
	p_combat.name = "CombatComponent"
	var p_inv = track(InventoryComponent.new()) as InventoryComponent
	p_inv.name = "InventoryComponent"
	var p_vis = track(VisionComponent.new()) as VisionComponent
	p_vis.name = "VisionComponent"
	player.add_child(p_stats)
	player.add_child(p_skills)
	player.add_child(p_combat)
	player.add_child(p_inv)
	player.add_child(p_vis)
	player.stats = p_stats
	player.skills = p_skills
	player.combat = p_combat
	player.inventory = p_inv
	player.vision = p_vis
	player.init_grid_position(grid, Vector2i(10, 10), turn_mgr)
	turn_mgr.set_player(player)
	player.stats.current_hp = 100.0
	
	# Helper to create active enemies with components
	var create_enemy = func(name: String, pos: Vector2i) -> Enemy:
		var enemy = track(Enemy.new()) as Enemy
		var e_stats = track(StatsComponent.new()) as StatsComponent
		e_stats.name = "StatsComponent"
		var e_skills = track(SkillComponent.new()) as SkillComponent
		e_skills.name = "SkillComponent"
		var e_combat = track(CombatComponent.new()) as CombatComponent
		e_combat.name = "CombatComponent"
		var e_inv = track(InventoryComponent.new()) as InventoryComponent
		e_inv.name = "InventoryComponent"
		var e_vis = track(VisionComponent.new()) as VisionComponent
		e_vis.name = "VisionComponent"
		enemy.add_child(e_stats)
		enemy.add_child(e_skills)
		enemy.add_child(e_combat)
		enemy.add_child(e_inv)
		enemy.add_child(e_vis)
		enemy.stats = e_stats
		enemy.skills = e_skills
		enemy.combat = e_combat
		enemy.inventory = e_inv
		enemy.vision = e_vis
		enemy.init_grid_position(grid, pos, turn_mgr)
		enemy.setup_enemy(name, 20.0, 10, 10, 10)
		turn_mgr.register_enemy(enemy)
		return enemy
	
	# Spawn 3 enemies around player: North (cardinal), South (cardinal), and North-West (diagonal)
	var e_north: Enemy = create_enemy.call("Goblin North", Vector2i(10, 9))
	var e_south: Enemy = create_enemy.call("Goblin South", Vector2i(10, 11))
	var e_diag: Enemy = create_enemy.call("Goblin Diag", Vector2i(9, 9))
	
	# Execute enemy turns
	e_north.take_turn()
	e_south.take_turn()
	e_diag.take_turn()
	
	# All 3 enemies must attack the player in the same turn
	assert_eq(e_north.ai_state, Enemy.AIState.ATTACK, "North enemy must attack player")
	assert_eq(e_south.ai_state, Enemy.AIState.ATTACK, "South enemy must attack player")
	assert_eq(e_diag.ai_state, Enemy.AIState.ATTACK, "Diagonal enemy must also attack player (Chebyshev range)")
	assert_true(player.stats.current_hp < 100.0, "Player must have taken damage from concurrent attacks")

