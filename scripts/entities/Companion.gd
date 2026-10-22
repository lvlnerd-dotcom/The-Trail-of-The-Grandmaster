class_name Companion
extends BaseEntity

## Companion: Allied AI entity fighting alongside the player, scaling with Master's Charisma & Depth Tier.
## Upgraded for Milestone 5: Permanent death at 0 HP, dynamic Charisma & Depth Tier scaling,
## tactical orders (ALL_FOLLOW, ALL_ATTACK, ALL_DEFEND), and mercenary recruitment.

enum TacticalOrder {
	ALL_FOLLOW,  ## Strictly follow player; never attacks any enemy
	ALL_ATTACK,  ## Pursue & attack player-designated target (and visible hostiles)
	ALL_DEFEND   ## Protect player; attack only enemies targeting or adjacent to player
}

signal companion_died(companion: Companion)
signal order_changed(new_order: TacticalOrder)

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
var is_dead: bool = false
var is_hired: bool = true

var current_order: TacticalOrder = TacticalOrder.ALL_DEFEND
var designated_target: Node2D = null

var stats: StatsComponent = null

func _ready() -> void:
	super._ready()
	_ensure_stats()

func _ensure_stats() -> void:
	if not stats:
		stats = get_node_or_null("StatsComponent") as StatsComponent
		if not stats:
			stats = StatsComponent.new()
			stats.name = "StatsComponent"
			add_child(stats)
		if not stats.entity_died.is_connected(_on_stats_entity_died):
			stats.entity_died.connect(_on_stats_entity_died)

func _on_stats_entity_died(_entity: Node2D) -> void:
	if not is_dead:
		_handle_permadeath()

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
		
	_ensure_stats()
	
	# Connect to Master's attribute changes for dynamic Charisma scaling
	if master:
		var master_stats = master.get_node_or_null("StatsComponent") as StatsComponent
		if not master_stats:
			for child in master.get_children():
				if child is StatsComponent:
					master_stats = child
					break
		if master_stats and master_stats.attributes:
			if not master_stats.attributes.attribute_changed.is_connected(_on_master_attribute_changed):
				master_stats.attributes.attribute_changed.connect(_on_master_attribute_changed)
				
	recalculate_charisma_scaling()
	
	if is_hired and turn_manager:
		turn_manager.register_companion(self)
		
	var bus = _get_event_bus()
	if bus and is_hired:
		bus.emit_signal("companion_registered", self)

func _on_master_attribute_changed(attr_name: String, _new_val: int) -> void:
	if attr_name.to_lower() == "charisma":
		recalculate_charisma_scaling()

func recalculate_charisma_scaling() -> void:
	if not companion_data:
		return
		
	var cha_val: int = 10
	if master:
		var master_stats = master.get_node_or_null("StatsComponent") as StatsComponent
		if not master_stats:
			for child in master.get_children():
				if child is StatsComponent:
					master_stats = child
					break
		if master_stats and master_stats.attributes:
			cha_val = master_stats.attributes.charisma
			
	var tier = companion_data.depth_tier
	var tier_mult = CompanionData.get_tier_multiplier(tier)
	var cha_mod = maxf(0.10, 1.0 + float(cha_val - 10) * 0.025)
	cha_multiplier = cha_mod
	
	var old_max = max_hp
	max_hp = round(companion_data.base_hp * tier_mult * cha_mod)
	if old_max > 0.0 and current_hp > 0.0:
		var hp_ratio = current_hp / old_max
		current_hp = clampf(round(max_hp * hp_ratio), 1.0, max_hp)
	else:
		current_hp = max_hp
		
	damage_min = int(round(float(companion_data.base_damage_min) * tier_mult * cha_mod))
	damage_max = int(round(float(companion_data.base_damage_max) * tier_mult * cha_mod))
	armor = int(round(float(companion_data.base_armor) * tier_mult * cha_mod))
	dodge = companion_data.base_dodge
	
	_ensure_stats()
	stats.max_hp_override = max_hp
	stats.current_hp = current_hp

func unregister() -> void:
	if turn_manager:
		turn_manager.unregister_companion(self)
	var bus = _get_event_bus()
	if bus:
		bus.emit_signal("companion_unregistered", self)

# --- Vital & Damage Management with Permadeath ---

func take_damage(amount: int, attacker: Node2D = null) -> int:
	var actual_damage = maxi(1, amount - armor)
	current_hp = maxf(0.0, current_hp - float(actual_damage))
	if stats:
		stats.current_hp = current_hp
		
	var bus = _get_event_bus()
	if bus:
		bus.emit_signal("entity_damaged", self, attacker, actual_damage)
		
	if current_hp <= 0.0:
		_handle_permadeath()
			
	return actual_damage

func _handle_permadeath() -> void:
	is_dead = true
	is_downed = true
	if turn_manager:
		turn_manager.unregister_companion(self)
	if grid:
		grid.unregister_entity(self, grid_pos)
		
	var bus = _get_event_bus()
	var c_name = companion_data.companion_name if companion_data else "Companion"
	if bus:
		if bus.has_signal("companion_died"):
			bus.emit_signal("companion_died", self)
		if bus.has_signal("companion_downed"):
			bus.emit_signal("companion_downed", self)
		bus.emit_signal("floating_text_requested", "%s has died!" % c_name, Color(0.86, 0.08, 0.24), global_position)
		
	emit_signal("companion_died", self)
	queue_free()

func heal(amount: float) -> float:
	var healed = minf(amount, max_hp - current_hp)
	current_hp += healed
	if is_downed and current_hp > 0.0:
		is_downed = false
		is_dead = false
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

# --- Tactical AI & Turn Execution ---

func set_tactical_order(order: TacticalOrder) -> void:
	current_order = order
	emit_signal("order_changed", current_order)
	var bus = _get_event_bus()
	if bus and bus.has_signal("companion_order_changed"):
		bus.emit_signal("companion_order_changed", int(current_order))

func take_turn() -> void:
	if is_dead or is_downed or is_moving or not grid or not is_hired:
		return
		
	var bus = _get_event_bus()
	
	# Priority 0: Flee if critical health (< 20% max HP)
	if current_hp < (max_hp * 0.20):
		if _retreat_to_safety():
			if bus:
				bus.emit_signal("companion_acted", self, "flee")
			return

	match current_order:
		TacticalOrder.ALL_FOLLOW:
			_execute_order_follow(bus)
		TacticalOrder.ALL_ATTACK:
			_execute_order_attack(bus)
		TacticalOrder.ALL_DEFEND:
			_execute_order_defend(bus)

func _execute_order_follow(bus: Node) -> void:
	# ALL_FOLLOW: Strictly follows player within 1-2 tiles; NEVER attacks any enemy
	if master and "grid_pos" in master:
		var dist_to_master = maxi(abs(grid_pos.x - master.grid_pos.x), abs(grid_pos.y - master.grid_pos.y))
		if dist_to_master > 1:
			_step_toward(master.grid_pos)
			if bus:
				bus.emit_signal("companion_acted", self, "follow_master")
		else:
			if bus:
				bus.emit_signal("companion_acted", self, "wait_in_formation")

func _execute_order_attack(bus: Node) -> void:
	# ALL_ATTACK: Pursues & attacks designated focus target (or nearest hostile in LOS)
	var target_to_attack: Node2D = null
	if is_instance_valid(designated_target) and "grid_pos" in designated_target:
		target_to_attack = designated_target
	else:
		designated_target = null
		target_to_attack = _find_nearest_enemy_in_los()
		
	if target_to_attack:
		if _can_attack_target(target_to_attack):
			_attack(target_to_attack)
			if bus:
				bus.emit_signal("companion_acted", self, "attack_enemy")
		else:
			_step_toward(target_to_attack.grid_pos)
			if bus:
				bus.emit_signal("companion_acted", self, "engage_enemy")
	else:
		# Fallback: Follow master
		_execute_order_follow(bus)

func _execute_order_defend(bus: Node) -> void:
	# ALL_DEFEND: Protects player; attacks enemies targeting or adjacent to master
	var threat = _find_threat_to_master()
	if threat:
		if _can_attack_target(threat):
			_attack(threat)
			if bus:
				bus.emit_signal("companion_acted", self, "defend_master")
		else:
			_step_toward(threat.grid_pos)
			if bus:
				bus.emit_signal("companion_acted", self, "defend_master")
	else:
		# Follow master in close formation
		_execute_order_follow(bus)

func _can_attack_target(target: Node2D) -> bool:
	if not target or not ("grid_pos" in target):
		return false
	var dist = maxi(abs(grid_pos.x - target.grid_pos.x), abs(grid_pos.y - target.grid_pos.y))
	var max_r = companion_data.attack_range if companion_data else 1
	if max_r > 1:
		return dist <= max_r and VisionComponent.has_line_of_sight(grid, grid_pos, target.grid_pos)
	return dist <= 1

func _find_threat_to_master() -> Node2D:
	if not master or not ("grid_pos" in master):
		return null
	# 1. Adjacent to master
	var adj_enemy = _find_adjacent_enemy_to(master.grid_pos)
	if adj_enemy:
		return adj_enemy
	# 2. Hostiles targeting master
	if turn_manager:
		for enemy in turn_manager.registered_enemies:
			if is_instance_valid(enemy) and "grid_pos" in enemy:
				var is_targeting = false
				if "target_player" in enemy and enemy.target_player == master:
					is_targeting = true
				elif "current_target" in enemy and enemy.current_target == master:
					is_targeting = true
				elif "last_attacked_target" in enemy and enemy.last_attacked_target == master:
					is_targeting = true
				if is_targeting:
					var p_range = companion_data.perception_range if companion_data else 6
					var dist = maxi(abs(enemy.grid_pos.x - grid_pos.x), abs(enemy.grid_pos.y - grid_pos.y))
					if dist <= p_range:
						return enemy
	return null

func _attack(target: Node2D) -> int:
	var roll = randi_range(damage_min, damage_max)
	# Check undead bonus for Sun-Sworn Acolyte
	if companion_data and companion_data.subtype == "sun_sworn_acolyte":
		if target.get("is_undead") or target.has_meta("is_undead"):
			roll = int(round(float(roll) * 1.5))
			
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
			return false
		var dir = next_cell - grid_pos
		return try_move(dir)
	else:
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
			if occ and occ != self and occ != master and not (occ is Companion and occ.is_hired):
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

# --- Mercenary Hiring Interaction ---

func get_hire_cost(buyer: Node2D = null) -> int:
	var merc_mod = 1.0
	if buyer:
		var b_stats = buyer.get_node_or_null("StatsComponent") as StatsComponent
		if b_stats and b_stats.attributes:
			merc_mod = b_stats.attributes.get_mercantile_modifier()
	var tier = companion_data.depth_tier if companion_data else 1
	return CompanionData.calculate_hire_cost(tier, merc_mod)

func attempt_hire(buyer: Node2D) -> Dictionary:
	if is_hired:
		return {"success": false, "reason": "Already hired."}
		
	var b_stats = buyer.get_node_or_null("StatsComponent") as StatsComponent
	var attrs = b_stats.attributes if b_stats else null
	var max_comp = attrs.get_max_companions() if attrs and attrs.has_method("get_max_companions") else 1
	
	var active_count = 0
	if turn_manager:
		active_count = turn_manager.registered_companions.size()
		
	if active_count >= max_comp:
		return {"success": false, "reason": "Squad capacity full! (Max %d based on Charisma)" % max_comp}
		
	var cost = get_hire_cost(buyer)
	var cur_gold = 0
	var b_inv = buyer.get_node_or_null("InventoryComponent")
	if b_inv and "gold" in b_inv:
		cur_gold = b_inv.gold
	elif buyer.has_meta("gold"):
		cur_gold = int(buyer.get_meta("gold"))
	elif "gold" in buyer:
		cur_gold = int(buyer.gold)
		
	if cur_gold < cost:
		return {"success": false, "reason": "Not enough gold! Requires %d GP (You have %d GP)" % [cost, cur_gold]}
		
	# Deduct gold
	var nxt_gold = cur_gold - cost
	if b_inv and "gold" in b_inv:
		b_inv.gold = nxt_gold
	if buyer.has_meta("gold"):
		buyer.set_meta("gold", nxt_gold)
	if "gold" in buyer:
		buyer.gold = nxt_gold
		
	master = buyer
	is_hired = true
	recalculate_charisma_scaling()
	
	if turn_manager:
		turn_manager.register_companion(self)
		
	var bus = _get_event_bus()
	if bus:
		bus.emit_signal("companion_registered", self)
		bus.emit_signal("floating_text_requested", "Hired for %d GP!" % cost, Color(1.0, 0.85, 0.2), global_position)
		
	return {
		"success": true,
		"cost": cost,
		"message": "Hired %s for %d GP!" % [(companion_data.companion_name if companion_data else "Mercenary"), cost]
	}

# --- Inspection ---

func get_inspection_data(_viewer: Node2D = null) -> InspectionData:
	var data = InspectionData.new()
	var c_name = companion_data.companion_name if companion_data else "Faithful Companion"
	data.title = c_name
	data.category = InspectionData.Category.ALLY_OR_NPC
	data.grid_cell = grid_pos
	data.icon_glyph = "C"
	data.accent_color = Color(0.4, 0.9, 0.6)
	
	if not is_hired:
		data.category_text = "Hireable Mercenary"
		data.health_status_text = "Ready to Hire"
		data.health_status_color = Color(1.0, 0.85, 0.2)
		data.description = "Hire Cost: %d GP • Dmg: %d-%d • Armor: %d • Dodge: %.0f%%" % [get_hire_cost(master), damage_min, damage_max, armor, dodge]
	elif is_downed or is_dead:
		data.health_status_text = "Dead"
		data.health_status_color = Color(0.86, 0.08, 0.24)
		data.description = "Fallen in battle. Permanent death."
	else:
		var order_str = "Defend"
		match current_order:
			TacticalOrder.ALL_FOLLOW: order_str = "Follow"
			TacticalOrder.ALL_ATTACK: order_str = "Attack"
			TacticalOrder.ALL_DEFEND: order_str = "Defend"
		data.category_text = "Squad [%s]" % order_str
		var h_info = BaseEntity.get_health_status_info(current_hp, max_hp)
		data.health_status_text = h_info["label"]
		data.health_status_color = h_info["color"]
		data.description = "Dmg: %d-%d • Armor Soak: %d • Dodge: %.0f%% • HP: %d/%d" % [damage_min, damage_max, armor, dodge, int(current_hp), int(max_hp)]
	return data
