class_name Player
extends BaseEntity

## Player: Input-driven entity controller with Stats, Skills, Inventory, Combat, and Vision.

@export var click_to_move_enabled: bool = true

@onready var stats: StatsComponent = $StatsComponent
@onready var skills: SkillComponent = $SkillComponent
@onready var inventory: InventoryComponent = $InventoryComponent
@onready var combat: CombatComponent = $CombatComponent
@onready var vision: VisionComponent = $VisionComponent
@onready var camera: DungeonCamera = $Camera2D as DungeonCamera
@onready var spell_casting: SpellCastingComponent = get_node_or_null("SpellCastingComponent") as SpellCastingComponent

var active_shrine_covenant: Dictionary = {}

func _ready() -> void:
	super._ready()
	if not spell_casting:
		spell_casting = get_node_or_null("SpellCastingComponent") as SpellCastingComponent
		if not spell_casting:
			spell_casting = SpellCastingComponent.new()
			spell_casting.name = "SpellCastingComponent"
			add_child(spell_casting)
	action_finished.connect(_on_player_action_finished)

func setup_from_creation_data(data: Dictionary) -> void:
	if not stats:
		stats = get_node_or_null("StatsComponent") as StatsComponent
	if not skills:
		skills = get_node_or_null("SkillComponent") as SkillComponent
	if not inventory:
		inventory = get_node_or_null("InventoryComponent") as InventoryComponent
	if not spell_casting:
		spell_casting = get_node_or_null("SpellCastingComponent") as SpellCastingComponent
		
	if data.has("attributes") and stats:
		stats.attributes = data["attributes"]
	
	if data.has("selected_skills") and skills:
		# Reset all skills to 0.0 first to ensure only selected skills start at 5.0
		for s in skills.skills.values():
			if s is SkillData:
				s.level = 0.0
		for skill_id in data["selected_skills"]:
			var skill = skills.get_skill(skill_id)
			if not skill:
				skill = skills.register_or_unlock_skill(skill_id, CharacterCreationData.STARTING_SKILL_INITIAL_LEVEL)
			if skill:
				skill.level = CharacterCreationData.STARTING_SKILL_INITIAL_LEVEL
	
	if data.has("starting_items"):
		for item in data["starting_items"]:
			if inventory:
				if item.equip_slot != ItemData.EquipSlot.NONE and not inventory.equipped_slots.has(item.equip_slot):
					inventory.equip_item(item)
				else:
					inventory.add_item(item)
			
			# Spellbooks teach their spell into player.spell_casting
			if spell_casting:
				if item.item_id == "spellbook_magic_missile":
					spell_casting.learn_spell(SpellData.create_magic_missile())
				elif item.item_id == "spellbook_minor_heal":
					spell_casting.learn_spell(SpellData.create_minor_heal())

func _unhandled_input(event: InputEvent) -> void:
	if is_moving:
		return
	if not turn_manager or not turn_manager.can_accept_player_input():
		return
	
	# 1. Wait / Rest Turn
	if event.is_action_pressed("wait_turn"):
		get_viewport().set_input_as_handled()
		_execute_wait_turn()
		return
	
	# 2. Diagonal Movement (Numpad)
	var move_dir = Vector2i.ZERO
	if event.is_action_pressed("move_up_left"):
		move_dir = Vector2i(-1, -1)
	elif event.is_action_pressed("move_up_right"):
		move_dir = Vector2i(1, -1)
	elif event.is_action_pressed("move_down_left"):
		move_dir = Vector2i(-1, 1)
	elif event.is_action_pressed("move_down_right"):
		move_dir = Vector2i(1, 1)
	# 3. Orthogonal Movement (WASD / Arrows / Numpad)
	elif event.is_action_pressed("move_up"):
		move_dir = Vector2i(0, -1)
	elif event.is_action_pressed("move_down"):
		move_dir = Vector2i(0, 1)
	elif event.is_action_pressed("move_left"):
		move_dir = Vector2i(-1, 0)
	elif event.is_action_pressed("move_right"):
		move_dir = Vector2i(1, 0)
	
	if move_dir != Vector2i.ZERO:
		get_viewport().set_input_as_handled()
		_handle_move_input(move_dir)
		return
	
	# 4. Click-to-move mouse support
	if click_to_move_enabled and event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var target_cell = grid.world_to_grid(get_global_mouse_position())
			if target_cell != grid_pos:
				_handle_click_move(target_cell)

func _handle_move_input(direction: Vector2i) -> void:
	set_facing_direction(direction)
	var target_cell = grid_pos + direction
	
	# Check if target cell has a hostile occupant -> Melee bump attack!
	if grid.is_occupied(target_cell):
		var occupant = grid.get_occupant(target_cell)
		if occupant and occupant != self and occupant.has_node("StatsComponent"):
			turn_manager.submit_player_action("melee_attack", {"target": occupant})
			_execute_melee_attack(occupant, direction)
			return
			
	# Check if walkable -> Move
	if grid.can_enter(target_cell):
		turn_manager.submit_player_action("move", {"direction": direction})
		try_move(direction)
	else:
		# Check if hitting a solid wall (plays bump animation, does NOT consume turn)
		_play_bump_animation(direction)
		var bus = _get_event_bus()
		if bus:
			bus.emit_signal("entity_bumped", self, target_cell)

func _execute_melee_attack(target: Node2D, direction: Vector2i) -> void:
	set_facing_direction(direction)
	_play_bump_animation(direction)
	
	var weapon = inventory.get_equipped_weapon()
	var result = combat.execute_attack(target, weapon)
	
	var bus = _get_event_bus()
	if bus:
		var def_name = target.get("enemy_name") if "enemy_name" in target else target.name
		var msg = "Player strikes %s for %d damage!" % [def_name, result["damage"]] if result["hit"] else "Player strikes, but %s %s!" % [def_name, result["defense_type"]]
		bus.emit_signal("player_acted", "melee_attack", {"message": msg, "result": result})

func _execute_wait_turn() -> void:
	turn_manager.submit_player_action("wait", {"immediate_resolve": true})

func get_ranged_targeting_context() -> Dictionary:
	if not inventory:
		return {"can_target": false, "reason": "No inventory available"}
	var weapon = inventory.get_equipped_weapon()
	var ammo = inventory.get_equipped_ammo()

	# 1. Check equipped ranged weapon (Bow, High-Tension Bow, Firearm, Sling, Reach/Ranged Weapon)
	if weapon and (
		weapon.weapon_type == AttributesData.WeaponType.BOW or
		weapon.weapon_type == AttributesData.WeaponType.HIGH_TENSION_BOW or
		weapon.weapon_type == AttributesData.WeaponType.FIREARM or
		weapon.weapon_type == AttributesData.WeaponType.THROWN or
		weapon.weapon_type == AttributesData.WeaponType.SLING or
		weapon.range_tiles > 1
	):
		var needs_arrows = (weapon.weapon_type == AttributesData.WeaponType.BOW or weapon.weapon_type == AttributesData.WeaponType.HIGH_TENSION_BOW)
		if needs_arrows and (not ammo or ammo.quantity <= 0):
			return {"can_target": false, "reason": "No arrows equipped in Ammunition slot!"}
		var r_tiles = weapon.range_tiles if weapon.range_tiles > 1 else 6
		var a_rad = ammo.area_radius if (ammo and ammo.area_radius > weapon.area_radius) else weapon.area_radius
		return {
			"can_target": true,
			"mode": TargetingSystem.ActionMode.RANGED_WEAPON,
			"label": weapon.item_name,
			"max_range": r_tiles,
			"area_radius": a_rad,
			"is_beam": false,
			"is_teleport": false,
			"allow_self": false,
			"weapon": weapon,
			"ammo": ammo
		}

	# 2. Check equipped throwable / explosive ammunition (Throwing Knives, Alchemical Bombs)
	if ammo and ammo.quantity > 0:
		var r_tiles = ammo.range_tiles if ammo.range_tiles > 1 else 5
		return {
			"can_target": true,
			"mode": TargetingSystem.ActionMode.RANGED_WEAPON,
			"label": ammo.item_name,
			"max_range": r_tiles,
			"area_radius": ammo.area_radius,
			"is_beam": false,
			"is_teleport": false,
			"allow_self": false,
			"weapon": null,
			"ammo": ammo
		}

	return {"can_target": false, "reason": "No ranged weapon or throwing ammunition equipped!"}

func execute_ranged_weapon_attack(target_cell: Vector2i, p_weapon: ItemData = null, p_ammo: ItemData = null) -> Dictionary:
	if not combat or not grid:
		return {"success": false, "message": "Combat system unavailable"}
	var dir = target_cell - grid_pos
	if dir != Vector2i.ZERO:
		set_facing_direction(Vector2i(clampi(dir.x, -1, 1), clampi(dir.y, -1, 1)))
	var w = p_weapon if p_weapon else (inventory.get_equipped_weapon() if inventory else null)
	var a = p_ammo if p_ammo else (inventory.get_equipped_ammo() if inventory else null)
	return combat.execute_ranged_attack(grid_pos, target_cell, grid, w, a)

func _handle_click_move(target_cell: Vector2i) -> void:
	var path = grid.find_path(grid_pos, target_cell)
	if path.size() >= 2:
		var next_cell = path[1]
		var step_dir = next_cell - grid_pos
		_handle_move_input(step_dir)

func _on_player_action_finished() -> void:
	if turn_manager and turn_manager.current_state == TurnManager.TurnState.PLAYER_TURN:
		turn_manager.on_player_action_finished()


func get_inspection_data(_viewer: Node2D = null) -> InspectionData:
	var data = InspectionData.new()
	var c_name = get_meta("class_name") if has_meta("class_name") else "Initiate Delver"
	data.title = "%s (You)" % c_name
	data.category = InspectionData.Category.ALLY_OR_NPC
	data.category_text = "The Delver • Player"
	data.grid_cell = grid_pos
	data.icon_glyph = "@"
	data.accent_color = Color(0.3, 0.85, 1.0)
	
	if stats and stats.attributes:
		var max_hp = stats.attributes.get_max_health()
		var h_info = BaseEntity.get_health_status_info(stats.current_hp, max_hp)
		data.health_status_text = h_info["label"]
		data.health_status_color = h_info["color"]
	else:
		data.health_status_text = "Unknown"
		data.health_status_color = Color(0.7, 0.7, 0.7)
		
	var stance = "DODGE"
	if skills and skills.active_defensive_mode == SkillComponent.DefensiveMode.PARRY_BLOCK:
		stance = "PARRY"
	data.description = "Defensive Stance: %s • Ready for action." % stance
	return data
