class_name World
extends Node2D

## World: Orchestrates the procedural dungeon grid, turn loop, entities, hazards, and floor collapse clock.

@onready var grid: DungeonGrid = $DungeonGrid
@onready var turn_manager: TurnManager = $TurnManager
@onready var grid_visualizer: GridVisualizer = $GridVisualizer
@onready var collapse_manager: FloorCollapseManager = $FloorCollapseManager
@onready var dungeon_objects: Node2D = $DungeonObjects
@onready var entities_container: Node2D = $Entities
@onready var ui_layer: CanvasLayer = $UILayer

# UI References
@onready var label_title: Label = $UILayer/HUD/VBox/LabelTitle
@onready var label_status: Label = $UILayer/HUD/VBox/LabelStatus
@onready var label_vitals: Label = $UILayer/HUD/VBox/LabelVitals
@onready var label_log: Label = $UILayer/HUD/VBox/LabelLog
@onready var label_controls: Label = $UILayer/HUD/VBox/LabelControls
@onready var level_up_modal: LevelUpModal = $UILayer/LevelUpModal
@onready var class_selection_modal: ClassSelectionModal = $UILayer/ClassSelectionModal
@onready var game_over_modal: GameOverModal = $UILayer/GameOverModal
@onready var victory_modal: VictoryModal = get_node_or_null("UILayer/VictoryModal") as VictoryModal
@onready var bestiary_modal: BestiaryModal = get_node_or_null("UILayer/BestiaryModal") as BestiaryModal
@onready var decals_layer: DecalsLayer = get_node_or_null("DecalsLayer") as DecalsLayer

const PLAYER_SCENE = preload("res://scenes/entities/player/Player.tscn")
const ENEMY_SCENE = preload("res://scenes/entities/enemies/Enemy.tscn")
const BOSS_SCENE = preload("res://scenes/entities/enemies/GrandmasterBoss.tscn")
const FLOATING_TEXT_SCENE = preload("res://scenes/ui/components/FloatingCombatText.tscn")

var player: Player = null
var enemies: Array[Enemy] = []
var secret_doors: Array[SecretDoor] = []
var traps: Dictionary = {} # Vector2i -> Trap
var stairs_down: StairsDown = null

var current_floor: int = 1
var generator: DungeonGenerator = null
var enemies_killed_count: int = 0
var is_game_over: bool = false

func _ready() -> void:
	generator = DungeonGenerator.new(46, 32)
	_generate_and_setup_floor(current_floor)
	_connect_signals()
	if class_selection_modal:
		class_selection_modal.class_chosen.connect(_on_class_chosen)
	if game_over_modal:
		game_over_modal.restart_requested.connect(_on_restart_requested)
	if victory_modal:
		victory_modal.bestiary_requested.connect(func():
			if bestiary_modal:
				bestiary_modal.open_modal()
		)
	_update_hud()

func _generate_and_setup_floor(floor_num: int) -> void:
	current_floor = floor_num
	
	# 1. Clean up existing objects and enemies
	for c in dungeon_objects.get_children():
		c.queue_free()
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	secret_doors.clear()
	traps.clear()
	turn_manager.registered_enemies.clear()
	if decals_layer:
		decals_layer.clear_decals()
	
	# 2. Procedural Dungeon Generation
	var gen_result = generator.generate_dungeon(grid, floor_num)
	grid_visualizer.setup(grid)
	
	# 3. Setup or relocate Player
	if not player or not is_instance_valid(player):
		_spawn_player(gen_result["start_cell"])
	else:
		player.init_grid_position(grid, gen_result["start_cell"], turn_manager)
		
	# Hook camera to collapse manager
	if player and player.camera:
		collapse_manager.camera = player.camera
		
	# 4. Spawning based on Floor type (Floor 20 Boss vs Floor 1-19 Procedural)
	if floor_num == 20:
		_spawn_grandmaster_boss(gen_result.get("boss_spawn", Vector2i(16, 11)))
		label_title.text = "TRAIL OF THE GRANDMASTER  |  Floor 20: Grandmaster Sanctum  |  FINAL BATTLE"
		label_log.text = "You enter the Grandmaster Sanctum! Face the ultimate master of martial and astral arts!"
		var am = _get_audio_mgr()
		if am:
			am.play_music("music_boss_grandmaster")
	else:
		_spawn_stairs(gen_result["exit_cell"])
		
		for d_info in gen_result["secret_doors"]:
			_spawn_secret_door(d_info["cell"], d_info["hide_rating"])
			
		for t_info in gen_result["traps"]:
			_spawn_trap(t_info["cell"], t_info["trap_type"], t_info["hide_rating"])
			
		_spawn_procedural_enemies(gen_result["enemy_spawns"], floor_num)
		
		label_title.text = "TRAIL OF THE GRANDMASTER  |  Floor %d  |  Phase 7: End-Game" % floor_num
		label_log.text = "Floor %d entered! Find the exit stairs before the floor collapses!" % floor_num
		var am = _get_audio_mgr()
		if am:
			am.play_ambient("ambient_dungeon")
	
	# 5. Reset Floor Turn Timer
	turn_manager.init_floor_timer(floor_num)
	collapse_manager.current_stage = FloorCollapseManager.CollapseStage.STABLE

func _spawn_grandmaster_boss(spawn_cell: Vector2i) -> void:
	var boss = BOSS_SCENE.instantiate() as GrandmasterBoss
	entities_container.add_child(boss)
	boss.init_grid_position(grid, spawn_cell, turn_manager)
	turn_manager.register_enemy(boss)
	if boss.combat:
		boss.combat.floating_text_requested.connect(_on_floating_text_requested)
	if boss.stats:
		boss.stats.entity_died.connect(func(_victim):
			enemies_killed_count += 1
			var mm = _get_meta_mgr()
			if mm:
				mm.record_kill(boss.enemy_name)
		)
	enemies.append(boss)

func _spawn_player(spawn_cell: Vector2i) -> void:
	player = PLAYER_SCENE.instantiate() as Player
	entities_container.add_child(player)
	player.init_grid_position(grid, spawn_cell, turn_manager)
	turn_manager.set_player(player)
	
	var gm = _get_game_mgr()
	var start_data: Dictionary
	if gm and gm.pending_creation_data != null and not gm.pending_creation_data.is_empty():
		start_data = gm.pending_creation_data
	else:
		start_data = CharacterCreationData.create_default_character()
	player.setup_from_creation_data(start_data)
	
	if player.combat:
		player.combat.floating_text_requested.connect(_on_floating_text_requested)
	if player.stats:
		player.stats.entity_died.connect(_on_player_died)

func _spawn_stairs(exit_cell: Vector2i) -> void:
	stairs_down = StairsDown.new()
	dungeon_objects.add_child(stairs_down)
	stairs_down.setup(grid, exit_cell, current_floor)
	stairs_down.descent_requested.connect(_on_descent_requested)

func _spawn_secret_door(door_cell: Vector2i, hide_rating: float) -> void:
	var door = SecretDoor.new()
	dungeon_objects.add_child(door)
	door.setup(grid, door_cell, hide_rating)
	secret_doors.append(door)

func _spawn_trap(trap_cell: Vector2i, trap_type: int, hide_rating: float) -> void:
	var trap = Trap.new()
	dungeon_objects.add_child(trap)
	trap.setup(grid, trap_cell, trap_type as Trap.TrapType, hide_rating)
	traps[trap_cell] = trap

func _spawn_procedural_enemies(spawn_cells: Array[Vector2i], floor_num: int) -> void:
	for cell in spawn_cells:
		var enemy = ENEMY_SCENE.instantiate() as Enemy
		entities_container.add_child(enemy)
		enemy.init_grid_position(grid, cell, turn_manager)
		
		# Enemy variant based on floor
		var is_skeleton = randf() < 0.4
		if is_skeleton:
			var skel_hp = 22.0 + floor_num * 3.0
			enemy.setup_enemy("Skeleton Guard", skel_hp, 45 + floor_num * 5, 9 + floor_num, 7 + floor_num)
		else:
			var gob_hp = 16.0 + floor_num * 2.5
			enemy.setup_enemy("Dungeon Goblin", gob_hp, 35 + floor_num * 5, 7 + floor_num, 9 + floor_num)
			
		turn_manager.register_enemy(enemy)
		if enemy.combat:
			enemy.combat.floating_text_requested.connect(_on_floating_text_requested)
		if enemy.stats:
			enemy.stats.entity_died.connect(func(_victim):
				enemies_killed_count += 1
				var mm = _get_meta_mgr()
				if mm:
					mm.record_kill(enemy.enemy_name)
			)
		enemies.append(enemy)

func _on_descent_requested(next_floor: int) -> void:
	if is_game_over:
		return
		
	# Phase 6 Specialization Check: Intercept Floor 2 stairs descent if unspecialized
	if current_floor == 2 and next_floor == 3:
		var player_class = player.get_meta("class_id") if player and player.has_meta("class_id") else ""
		if str(player_class).is_empty():
			_spawn_floating_text("Floor 2 Conquered! Select Specialization!", Color(1.0, 0.9, 0.2), player.global_position)
			if class_selection_modal:
				class_selection_modal.open_modal(player)
			return
			
	_proceed_descent(next_floor)

func _on_class_chosen(chosen_class: ClassData) -> void:
	if not player or not chosen_class:
		return
	chosen_class.apply_to_player(player)
	
	var bus = _get_event_bus()
	if bus and bus.has_signal("class_selected"):
		bus.emit_signal("class_selected", chosen_class.class_id, chosen_class.class_title)
		
	_spawn_floating_text("Class Chosen: %s!" % chosen_class.class_title, Color(0.4, 1.0, 0.4), player.global_position)
	
	# Atomic save upon specialization
	var gm = _get_game_mgr()
	if gm:
		gm.save_run(self)
	
	# Continue descent to Floor 3
	_proceed_descent(3)

func _proceed_descent(next_floor: int) -> void:
	_spawn_floating_text("Descending to Floor %d..." % next_floor, Color(1.0, 0.85, 0.2), player.global_position)
	var bus = _get_event_bus()
	if bus:
		bus.emit_signal("floor_descended", next_floor)
	_generate_and_setup_floor(next_floor)
	var gm = _get_game_mgr()
	if gm:
		gm.save_run(self)
	_update_hud()

func _on_player_died(_victim: Node2D) -> void:
	if is_game_over:
		return
	_trigger_game_over(false, "Fell in battle against the denizens of the Trail.")

func _on_floor_collapsed() -> void:
	if is_game_over:
		return
	label_log.text = "CRITICAL: The dungeon has caved in! Crushed under falling boulders!"
	if player and player.stats:
		player.stats.take_damage(999)
	_trigger_game_over(false, "Crushed beneath collapsing dungeon stone as the floor caved in.")

func _trigger_game_over(is_victory: bool, cause: String) -> void:
	is_game_over = true
	
	# 1. Roguelike Permadeath Save Wipe
	var gm = _get_game_mgr()
	if gm:
		gm.wipe_run_save()
		gm.is_run_active = false
	
	# 2. Count player keystones
	var keystones_count = 0
	if player and player.skills:
		for s_id in player.skills.skills.keys():
			var s = player.skills.skills[s_id] as SkillData
			if s:
				keystones_count += s.unlocked_keystones.size()
				
	var player_gold = player.get_meta("gold") if player and player.has_meta("gold") else 0
	
	# 3. Compile run summary
	var summary: Dictionary = {
		"floors_cleared": current_floor - 1 if not is_victory else current_floor,
		"turns_survived": turn_manager.turn_number if turn_manager else 0,
		"standard_kills": enemies_killed_count,
		"elite_kills": 0,
		"boss_kills": 0,
		"keystones_unlocked": keystones_count,
		"gold_earned": player_gold,
		"victory": is_victory,
		"cause_of_death": cause
	}
	
	# 4. Award Account Meta-EXP and record statistics
	var mm = _get_meta_mgr()
	var meta_res = mm.record_run_completion(summary) if mm else {}
	summary["meta_result"] = meta_res
	
	# 5. Display Game Over Modal
	if game_over_modal:
		game_over_modal.open_modal(summary)
	_update_hud()

func _on_restart_requested() -> void:
	var gm = _get_game_mgr()
	if gm:
		gm.open_creation_on_main_menu = true
	var tree = get_tree()
	if tree:
		tree.change_scene_to_file("res://scenes/ui/menus/MainMenu.tscn")

func _on_floating_text_requested(text_content: String, color: Color, world_pos: Vector2) -> void:
	_spawn_floating_text(text_content, color, world_pos)

func _spawn_floating_text(text_content: String, color: Color, world_pos: Vector2) -> void:
	var popup = FLOATING_TEXT_SCENE.instantiate() as FloatingCombatText
	add_child(popup)
	popup.setup(text_content, color, world_pos)

func _get_event_bus() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("EventBus")
	return null

func _get_meta_mgr() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("MetaManager")
	return null

func _get_game_mgr() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("GameManager")
	return null

func _get_audio_mgr() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("AudioManager")
	return null

func _connect_signals() -> void:
	var bus = _get_event_bus()
	if bus:
		if bus.has_signal("turn_started"):
			bus.turn_started.connect(_on_turn_started)
		if bus.has_signal("floor_turn_ticked"):
			bus.floor_turn_ticked.connect(_on_floor_turn_ticked)
		if bus.has_signal("state_changed"):
			bus.state_changed.connect(_on_state_changed)
		if bus.has_signal("entity_moved"):
			bus.entity_moved.connect(_on_entity_moved)
		if bus.has_signal("entity_bumped"):
			bus.entity_bumped.connect(_on_entity_bumped)
		if bus.has_signal("player_acted"):
			bus.player_acted.connect(_on_player_acted)
		if bus.has_signal("player_leveled_up"):
			bus.player_leveled_up.connect(_on_player_leveled_up)
		if bus.has_signal("skill_xp_gained"):
			bus.skill_xp_gained.connect(_on_skill_xp_gained)
		if bus.has_signal("keystone_unlocked"):
			bus.keystone_unlocked.connect(_on_keystone_unlocked)
		if bus.has_signal("floor_collapsed"):
			bus.floor_collapsed.connect(_on_floor_collapsed)
		if bus.has_signal("victory_achieved"):
			bus.victory_achieved.connect(_on_victory_achieved)
		if bus.has_signal("entity_damaged"):
			bus.entity_damaged.connect(_on_entity_damaged_event)
			
	if player and player.stats:
		player.stats.health_changed.connect(func(_c, _m): _update_hud())
		player.stats.mana_changed.connect(func(_c, _m): _update_hud())
		if player.stats.attributes:
			player.stats.attributes.attribute_changed.connect(func(_n, _v): _update_hud())
			player.stats.attributes.leveled_up.connect(func(_lvl, _pts): _update_hud())

func _on_entity_damaged_event(target: Node2D, _attacker: Node2D, _amount: int) -> void:
	if decals_layer and is_instance_valid(target) and target.has_method("get") and target.get("grid_pos") != null:
		decals_layer.add_decal("blood", target.get("grid_pos"))

func _on_victory_achieved(summary: Dictionary) -> void:
	is_game_over = true
	var gm = _get_game_mgr()
	if gm:
		gm.wipe_run_save()
		gm.is_run_active = false
	
	var keystones_count = 0
	if player and player.skills:
		for s_id in player.skills.skills.keys():
			var s = player.skills.skills[s_id] as SkillData
			if s:
				keystones_count += s.unlocked_keystones.size()
				
	var player_gold = player.get_meta("gold") if player and player.has_meta("gold") else 0
	
	summary["floors_cleared"] = 20
	summary["turns_survived"] = turn_manager.turn_number if turn_manager else 0
	summary["standard_kills"] = enemies_killed_count
	summary["boss_kills"] = 1
	summary["keystones_unlocked"] = keystones_count
	summary["gold_earned"] = player_gold
	summary["victory"] = true
	
	var mm = _get_meta_mgr()
	var meta_res = mm.record_run_completion(summary) if mm else {}
	summary["meta_result"] = meta_res
	
	if victory_modal:
		victory_modal.open_modal(summary)
	_update_hud()

func _unhandled_key_input(event: InputEvent) -> void:
	if is_game_over:
		return
		
	if event is InputEventKey and event.pressed:
		var key_event = event as InputEventKey
		if key_event.keycode == KEY_TAB:
			get_viewport().set_input_as_handled()
			var new_mode = player.skills.toggle_defensive_mode()
			var mode_str = "DODGE" if new_mode == SkillComponent.DefensiveMode.DODGE_EVADE else "PARRY"
			label_log.text = "Defensive Stance switched to: %s" % mode_str
			_update_hud()
			return
			
		if key_event.keycode == KEY_L or key_event.keycode == KEY_C:
			get_viewport().set_input_as_handled()
			if level_up_modal.visible:
				level_up_modal.visible = false
			else:
				level_up_modal.open_modal(player.stats.attributes)
			return

		if key_event.keycode == KEY_B:
			get_viewport().set_input_as_handled()
			if bestiary_modal:
				if bestiary_modal.visible:
					bestiary_modal.close_modal()
				else:
					bestiary_modal.open_modal()
			return

func _update_hud() -> void:
	if not label_status or not player or not player.stats:
		return
		
	var stage_name = collapse_manager.get_stage_name()
	
	label_status.text = "Turn: %d | Floor: %d | Turns Left: %d/%d [%s] | State: %s" % [
		turn_manager.turn_number,
		current_floor,
		turn_manager.floor_turns_remaining,
		turn_manager.floor_total_turns,
		stage_name,
		TurnManager.TurnState.keys()[turn_manager.current_state]
	]
	
	var attrs = player.stats.attributes
	var stance_name = "DODGE" if player.skills.active_defensive_mode == SkillComponent.DefensiveMode.DODGE_EVADE else "PARRY"
	var pts_alert = " | [LEVEL UP AVAILABLE: %d pts! Press L]" % attrs.unallocated_attribute_points if attrs.unallocated_attribute_points > 0 else ""
	var class_tag = " | Class: %s" % player.get_meta("class_name") if player.has_meta("class_name") else ""
	
	label_vitals.text = "HP: %d/%d | Mana: %d/%d | Level: %d (%d/%d EXP) | Burden: %.1f/%.0f Stones | Stance: %s%s%s" % [
		int(player.stats.current_hp), int(attrs.get_max_health()),
		int(player.stats.current_mana), int(attrs.get_max_mana()),
		attrs.character_level, attrs.current_exp, attrs.get_exp_required_for_next_level(),
		player.inventory.get_carried_weight_stones(), attrs.get_max_carry_weight_stones(),
		stance_name,
		class_tag,
		pts_alert
	]

func _on_turn_started(_turn: int) -> void:
	if player and player.stats:
		player.stats.tick_turn_regeneration()
	_update_hud()

func _on_floor_turn_ticked(remaining: int, total: int) -> void:
	var result = collapse_manager.process_turn_tick(remaining, total)
	if result["message"] != "":
		label_log.text = result["message"]
	_update_hud()

func _on_state_changed(_new_state: String) -> void:
	_update_hud()

func _on_player_acted(action: String, details: Dictionary) -> void:
	if details.has("message"):
		if action == "enemy_attack":
			if label_log.text.begins_with("Enemy:") or label_log.text.begins_with("Enemies:"):
				label_log.text += " | " + details["message"]
			else:
				label_log.text = "Enemy: " + details["message"]
		else:
			label_log.text = details["message"]
	elif action == "wait":
		label_log.text = "Action: Player rested 1 turn (Regenerated vitals)."
	elif action == "move":
		label_log.text = "Action: Player moved %s" % str(details.get("direction", Vector2i.ZERO))

func _on_entity_moved(entity: Node2D, _from_cell: Vector2i, to_cell: Vector2i) -> void:
	if entity == player:
		# 1. Check if stepped on Stairs Down
		if stairs_down and stairs_down.can_descend(player):
			stairs_down.trigger_descent()
			return
			
		# 2. Check if stepped on a Trap
		if traps.has(to_cell):
			var trap = traps[to_cell]
			if not trap.is_triggered:
				var res = trap.trigger(player)
				var dmg_text = "-%d HP (%s)" % [res["damage"], res["effect_name"]] if res["damage"] > 0 else "Triggered: %s!" % res["effect_name"]
				_spawn_floating_text(dmg_text, Color(1.0, 0.3, 0.3), player.global_position)
				if player.camera:
					player.camera.add_trauma(0.4)
				var bus = _get_event_bus()
				if bus:
					bus.emit_signal("trap_triggered", to_cell, player)
					
		# 3. Perform Perception Scan on nearby hidden objects
		_scan_environment_with_perception()

func _scan_environment_with_perception() -> void:
	if not player or not player.vision or not player.skills:
		return
		
	var p_pos = player.grid_pos
	
	# Check hidden Secret Doors
	for door in secret_doors:
		if not door.is_revealed:
			var dist = abs(door.grid_pos.x - p_pos.x) + abs(door.grid_pos.y - p_pos.y)
			if dist <= player.vision.view_distance_tiles:
				if player.vision.has_line_of_sight(grid, p_pos, door.grid_pos):
					var det_chance = VisionComponent.calculate_detection_chance(player, door)
					if randf() <= det_chance:
						door.reveal()
						_spawn_floating_text("Secret Door Revealed!", Color(0.3, 0.8, 1.0), door.global_position)
						player.skills.train_skill(SkillData.SkillId.PERCEPTION, door.hide_rating, player.stats.attributes)
						var bus = _get_event_bus()
						if bus:
							bus.emit_signal("secret_discovered", door.grid_pos, "secret_door")
							
	# Check hidden Traps
	for t_pos in traps.keys():
		var trap = traps[t_pos]
		if not trap.is_revealed:
			var dist = abs(t_pos.x - p_pos.x) + abs(t_pos.y - p_pos.y)
			if dist <= player.vision.view_distance_tiles:
				if player.vision.has_line_of_sight(grid, p_pos, t_pos):
					var det_chance = VisionComponent.calculate_detection_chance(player, trap)
					if randf() <= det_chance:
						trap.reveal()
						_spawn_floating_text("Trap Detected!", Color(1.0, 0.7, 0.2), trap.global_position)
						player.skills.train_skill(SkillData.SkillId.PERCEPTION, trap.hide_rating, player.stats.attributes)

func _on_entity_bumped(entity: Node2D, target_cell: Vector2i) -> void:
	if entity == player:
		label_log.text = "Bump! Solid wall/obstacle at %s blocks movement." % str(target_cell)

func _on_player_leveled_up(new_level: int, pts: int) -> void:
	label_log.text = "Level Up! Reached Level %d! Awarded %d attribute points." % [new_level, pts]
	level_up_modal.open_modal(player.stats.attributes)
	_update_hud()

func _on_skill_xp_gained(s_name: String, _amt: float, cur_lvl: float) -> void:
	label_log.text = "Skill Trained: %s reached level %.1f" % [s_name, cur_lvl]

func _on_keystone_unlocked(s_name: String, milestone: int) -> void:
	label_log.text = "Keystone Unlocked! %s achieved milestone %d!" % [s_name, milestone]
