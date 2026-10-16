class_name Companion
extends BaseEntity

## Companion: Allied AI entity fighting alongside the player, scaling with Master's Charisma.

@export var companion_data: CompanionData
var master: Node2D = null

var current_hp: float = 70.0
var max_hp: float = 70.0
var damage_min: int = 8
var damage_max: int = 12
var armor: int = 2
var dodge: float = 25.0
var cha_multiplier: float = 1.0

var is_downed: bool = false
var stats: StatsComponent = null

func _ready() -> void:
	super._ready()
	if not stats:
		stats = get_node_or_null("StatsComponent") as StatsComponent
		if not stats:
			stats = StatsComponent.new()
			stats.name = "StatsComponent"
			add_child(stats)

func setup(
	p_data: CompanionData,
	p_master: Node2D,
	p_turn_manager: TurnManager = null,
	p_grid: DungeonGrid = null,
	p_pos: Vector2i = Vector2i.ZERO
) -> void:
	companion_data = p_data
	master = p_master
	
	if p_grid:
		init_grid_position(p_grid, p_pos, p_turn_manager)
	elif p_turn_manager:
		turn_manager = p_turn_manager
		
	# Apply Charisma scaling from Master
	var cha_mod: float = 1.0
	if master:
		var master_stats = master.get_node_or_null("StatsComponent") as StatsComponent
		if not master_stats:
			for child in master.get_children():
				if child is StatsComponent:
					master_stats = child
					break
		if master_stats and master_stats.attributes:
			cha_mod = master_stats.attributes.get_companion_stat_modifier()
			
	cha_multiplier = cha_mod
	max_hp = round(companion_data.base_hp * cha_mod)
	current_hp = max_hp
	damage_min = int(round(float(companion_data.base_damage_min) * cha_mod))
	damage_max = int(round(float(companion_data.base_damage_max) * cha_mod))
	armor = int(round(float(companion_data.base_armor) * cha_mod))
	dodge = companion_data.base_dodge
	is_downed = false
	
	if not stats:
		stats = get_node_or_null("StatsComponent") as StatsComponent
		if not stats:
			stats = StatsComponent.new()
			stats.name = "StatsComponent"
			add_child(stats)
	stats.current_hp = current_hp
	
	if turn_manager:
		turn_manager.register_companion(self)
		
	var bus = _get_event_bus()
	if bus:
		bus.emit_signal("companion_registered", self)

func unregister() -> void:
	if turn_manager:
		turn_manager.unregister_companion(self)
	var bus = _get_event_bus()
	if bus:
		bus.emit_signal("companion_unregistered", self)

# --- Vital & Damage Management ---

func take_damage(amount: int, attacker: Node2D = null) -> int:
	var actual_damage = maxi(1, amount - armor)
	current_hp = maxf(0.0, current_hp - float(actual_damage))
	if stats:
		stats.current_hp = current_hp
		
	var bus = _get_event_bus()
	if bus:
		bus.emit_signal("entity_damaged", self, attacker, actual_damage)
		
	if current_hp <= 0.0:
		is_downed = true
		if bus:
			bus.emit_signal("companion_downed", self)
			
	return actual_damage

func heal(amount: float) -> float:
	var healed = minf(amount, max_hp - current_hp)
	current_hp += healed
	if is_downed and current_hp > 0.0:
		is_downed = false
	if stats:
		stats.current_hp = current_hp
	return healed

# --- Archetype Traits ---

func is_in_bulwark_stance() -> bool:
	if not companion_data or companion_data.archetype != CompanionData.CompanionArchetype.HIRED_MERCENARY:
		return false
	if not master:
		return false
	var master_pos: Vector2i
	if "grid_pos" in master:
		master_pos = master.grid_pos
	elif master.has_meta("grid_pos"):
		master_pos = master.get_meta("grid_pos")
	else:
		return false
	var dist = maxi(abs(grid_pos.x - master_pos.x), abs(grid_pos.y - master_pos.y))
	return dist <= 1

func has_keen_senses() -> bool:
	return companion_data != null and companion_data.archetype == CompanionData.CompanionArchetype.TAMED_HOUND

# --- Turn Execution & Priority Behavior Machine ---

func take_turn() -> void:
	if is_downed or is_moving or not grid:
		return
		
	var bus = _get_event_bus()
	
	# Priority 1: Flee if critical health (< 20% max HP)
	if current_hp < (max_hp * 0.20):
		if _retreat_to_safety():
			if bus:
				bus.emit_signal("companion_acted", self, "flee")
			return
			
	# Priority 2: Defend Master (hostile adjacent to master)
	if master and "grid_pos" in master:
		var threatening_enemy = _find_adjacent_enemy_to(master.grid_pos)
		if threatening_enemy:
			if _is_adjacent(grid_pos, threatening_enemy.grid_pos):
				_attack(threatening_enemy)
			else:
				_step_toward(threatening_enemy.grid_pos)
			if bus:
				bus.emit_signal("companion_acted", self, "defend_master")
			return
			
	# Priority 3: Attack adjacent hostile
	var adjacent_enemy = _find_adjacent_enemy_to(grid_pos)
	if adjacent_enemy:
		_attack(adjacent_enemy)
		if bus:
			bus.emit_signal("companion_acted", self, "attack_enemy")
		return
		
	# Priority 4: Engage nearest enemy in perception range & LOS
	var nearest_enemy = _find_nearest_enemy_in_los()
	if nearest_enemy:
		_step_toward(nearest_enemy.grid_pos)
		if bus:
			bus.emit_signal("companion_acted", self, "engage_enemy")
		return
		
	# Priority 5: Follow master in formation
	if master and "grid_pos" in master:
		var dist_to_master = maxi(abs(grid_pos.x - master.grid_pos.x), abs(grid_pos.y - master.grid_pos.y))
		if dist_to_master > 1:
			_step_toward(master.grid_pos)
			if bus:
				bus.emit_signal("companion_acted", self, "follow_master")
			return
		else:
			if bus:
				bus.emit_signal("companion_acted", self, "wait_in_formation")
			return

func _attack(target: Node2D) -> int:
	var roll = randi_range(damage_min, damage_max)
	var dealt = roll
	if target.has_method("take_damage"):
		dealt = target.take_damage(roll, self)
	elif target.get_node_or_null("StatsComponent"):
		dealt = target.get_node("StatsComponent").take_damage(roll, self)
	return dealt

func _step_toward(target_pos: Vector2i) -> bool:
	if not grid:
		return false
	var path = grid.find_path(grid_pos, target_pos)
	if path.size() >= 2:
		var next_cell = path[1]
		if next_cell == target_pos:
			# If destination is occupied by master/enemy, try adjacent
			return false
		var dir = next_cell - grid_pos
		return try_move(dir)
	else:
		# Fallback direct orthogonal/diagonal step
		var dx = clampi(target_pos.x - grid_pos.x, -1, 1)
		var dy = clampi(target_pos.y - grid_pos.y, -1, 1)
		if dx != 0 or dy != 0:
			var dir = Vector2i(dx, dy)
			if grid.can_enter(grid_pos + dir):
				return try_move(dir)
	return false

func _retreat_to_safety() -> bool:
	if master and "grid_pos" in master:
		return _step_toward(master.grid_pos)
	return false

func _is_adjacent(pos_a: Vector2i, pos_b: Vector2i) -> bool:
	return maxi(abs(pos_a.x - pos_b.x), abs(pos_a.y - pos_b.y)) == 1

func _find_adjacent_enemy_to(pos: Vector2i) -> Node2D:
	if not grid:
		return null
	var dirs = [
		Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)
	]
	for d in dirs:
		var check = pos + d
		if grid.is_occupied(check):
			var occ = grid.get_occupant(check)
			if occ and occ != self and occ != master and not occ.has_method("is_in_bulwark_stance"):
				return occ
	return null

func _find_nearest_enemy_in_los() -> Node2D:
	if not turn_manager:
		return null
	var enemies = turn_manager.registered_enemies
	var p_range = companion_data.perception_range if companion_data else 6
	var closest_enemy: Node2D = null
	var closest_dist = 9999
	
	for enemy in enemies:
		if is_instance_valid(enemy) and "grid_pos" in enemy:
			var dist = maxi(abs(enemy.grid_pos.x - grid_pos.x), abs(enemy.grid_pos.y - grid_pos.y))
			if dist <= p_range and dist < closest_dist:
				if grid and VisionComponent.has_line_of_sight(grid, grid_pos, enemy.grid_pos):
					closest_dist = dist
					closest_enemy = enemy
	return closest_enemy
