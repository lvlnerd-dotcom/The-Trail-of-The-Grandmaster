class_name Enemy
extends BaseEntity

## Enemy: Turn-based AI entity with tactical states (Idle, Chase, Attack, Flee).
## Upgraded for Milestone 3: Ranged kiting & sidearm swap, 1-turn AoE telegraphs,
## cross-faction infighting, stealth ambushing, morale fleeing, and elite affixes.

enum AIState {
	IDLE,
	PATROL,
	CHASE,
	ATTACK,
	FLEE
}

@export var enemy_name: String = "Dungeon Goblin"
@export var base_kill_exp: int = 35
@export var vision_range: int = 7
@export var is_undead: bool = false
@export var max_hp: float = 0.0

# Tactical AI & Bestiary Properties
@export var archetype: BestiaryCatalog.Archetype = BestiaryCatalog.Archetype.MELEE_BRUTE
@export var faction: BestiaryCatalog.Faction = BestiaryCatalog.Faction.FACTION_BEAST
@export var is_intelligent: bool = false
@export var is_ambusher: bool = false
@export var is_concealed: bool = false
@export var is_elite: bool = false
@export var is_mini_boss: bool = false
@export var elite_affix: String = ""
@export var signature_spell_id: String = ""
@export var inflicted_status: String = ""

@onready var stats: StatsComponent = $StatsComponent
@onready var skills: SkillComponent = $SkillComponent
@onready var combat: CombatComponent = $CombatComponent
@onready var inventory: InventoryComponent = $InventoryComponent
@onready var vision: VisionComponent = $VisionComponent

var ai_state: AIState = AIState.IDLE
var target_player: Player = null

# Weapons
var ranged_weapon: ItemData = null
var sidearm_weapon: ItemData = null

# 1-Turn Telegraphed Hazard State
var telegraphed_hazard: Dictionary = {}

# Intimidation debuff state from Charisma checks
var intimidation_status: String = "" # "TERRIFIED" or "HESITANT"
var intimidation_turns_remaining: int = 0

func _ready() -> void:
	super._ready()
	if stats:
		stats.entity_died.connect(_on_death)

func setup_enemy(p_name: String, p_hp: float, p_exp: int, p_str: int = 8, p_dex: int = 8) -> void:
	enemy_name = p_name
	base_kill_exp = p_exp
	max_hp = p_hp
	
	if not stats:
		stats = get_node_or_null("StatsComponent") as StatsComponent
	if not inventory:
		inventory = get_node_or_null("InventoryComponent") as InventoryComponent
	if not skills:
		skills = get_node_or_null("SkillComponent") as SkillComponent
	if not combat:
		combat = get_node_or_null("CombatComponent") as CombatComponent
	if not vision:
		vision = get_node_or_null("VisionComponent") as VisionComponent
	
	if stats:
		stats.max_hp_override = p_hp
		if stats.attributes:
			stats.attributes.strength = p_str
			stats.attributes.dexterity = p_dex
		stats.current_hp = p_hp
		
	# Give basic crude weapon
	var crude_blade = ItemData.new("crude_blade", "Crude Blade", ItemData.ItemType.WEAPON, ItemData.EquipSlot.MAIN_HAND, 2.0)
	crude_blade.base_damage_min = 2
	crude_blade.base_damage_max = 5
	if inventory:
		inventory.equip_item(crude_blade)

func setup_from_template(template: Dictionary, floor_num: int, p_is_elite: bool = false, affix: String = "") -> void:
	enemy_name = String(template.get("display_name", "Dungeon Hostile"))
	base_kill_exp = int(template.get("kill_exp", 40))
	var hp_base = float(template.get("hp_base", 20.0))
	var hp_scale = float(template.get("hp_scale_per_floor", 3.0))
	max_hp = hp_base + (float(floor_num) * hp_scale)
	
	archetype = template.get("archetype", BestiaryCatalog.Archetype.MELEE_BRUTE)
	faction = template.get("faction", BestiaryCatalog.Faction.FACTION_BEAST)
	is_undead = bool(template.get("is_undead", false))
	is_intelligent = bool(template.get("is_intelligent", false))
	is_ambusher = bool(template.get("is_ambusher", false))
	is_mini_boss = bool(template.get("is_mini_boss", false))
	signature_spell_id = String(template.get("signature_spell_id", ""))
	inflicted_status = String(template.get("inflicted_status", ""))
	
	is_elite = p_is_elite
	elite_affix = affix
	if is_elite:
		max_hp = round(max_hp * 1.6)
		base_kill_exp *= 2
		enemy_name = "[Elite] " + (affix + " " if affix != "" else "") + template.get("display_name", enemy_name)
		
	if is_ambusher:
		is_concealed = true
		visible = false
		
	if not stats:
		stats = get_node_or_null("StatsComponent") as StatsComponent
	if not inventory:
		inventory = get_node_or_null("InventoryComponent") as InventoryComponent
	if not skills:
		skills = get_node_or_null("SkillComponent") as SkillComponent
	if not combat:
		combat = get_node_or_null("CombatComponent") as CombatComponent
	if not vision:
		vision = get_node_or_null("VisionComponent") as VisionComponent
		
	if stats:
		stats.max_hp_override = max_hp
		stats.current_hp = max_hp
		if stats.attributes:
			var base_str = 8 + floor_num
			var base_dex = 8 + floor_num
			if is_elite:
				base_str = int(round(base_str * 1.25))
				base_dex = int(round(base_dex * 1.25))
			stats.attributes.strength = base_str
			stats.attributes.dexterity = base_dex
			
	var w_id = String(template.get("weapon_id", ""))
	var s_id = String(template.get("sidearm_id", ""))
	var w_item: ItemData = null
	if w_id != "":
		w_item = WeaponManifest.create_weapon(w_id)
	if not w_item:
		w_item = ItemData.new("crude_blade", "Crude Blade", ItemData.ItemType.WEAPON, ItemData.EquipSlot.MAIN_HAND, 2.0)
		w_item.base_damage_min = 2 + floor_num
		w_item.base_damage_max = 5 + floor_num
		
	if is_elite:
		w_item.base_damage_min = int(round(w_item.base_damage_min * 1.25))
		w_item.base_damage_max = int(round(w_item.base_damage_max * 1.25))
		
	if inventory:
		inventory.equip_item(w_item)
		
	if w_item.range_tiles > 1 or archetype == BestiaryCatalog.Archetype.RANGED_ARCHER or archetype == BestiaryCatalog.Archetype.SPELLCASTER:
		ranged_weapon = w_item
		
	if s_id != "":
		sidearm_weapon = WeaponManifest.create_weapon(s_id)
	if not sidearm_weapon:
		sidearm_weapon = ItemData.new("sidearm_dagger", "Sidearm Dagger", ItemData.ItemType.WEAPON, ItemData.EquipSlot.MAIN_HAND, 1.0)
		sidearm_weapon.base_damage_min = 2 + floor_num
		sidearm_weapon.base_damage_max = 4 + floor_num
		
	var sprite = get_node_or_null("VisualSprite") as Sprite2D
	if sprite:
		if is_mini_boss:
			sprite.modulate = Color(1.0, 0.2, 0.4)
			scale = Vector2(1.25, 1.25)
		elif is_elite:
			match elite_affix:
				"Vampiric": sprite.modulate = Color(0.85, 0.2, 0.85)
				"Flame-Touched": sprite.modulate = Color(1.0, 0.35, 0.1)
				"Venomous": sprite.modulate = Color(0.3, 0.9, 0.2)
				"Swift": sprite.modulate = Color(0.2, 0.8, 1.0)
				"Armored": sprite.modulate = Color(0.9, 0.85, 0.3)
				_: sprite.modulate = Color(1.0, 0.84, 0.0)

func apply_intimidation(status_type: String, duration_turns: int) -> void:
	intimidation_status = status_type
	intimidation_turns_remaining = duration_turns
	if status_type == "TERRIFIED":
		ai_state = AIState.FLEE
	
	var color = Color(0.9, 0.4, 1.0)
	if combat:
		combat.emit_signal("floating_text_requested", status_type + "!", color, global_position)

func take_turn() -> void:
	if not stats or stats.current_hp <= 0.0 or not grid:
		return
	if status_effects and status_effects.is_stunned():
		return
		
	# Ensure any ongoing tween is finalized
	if move_tween and move_tween.is_valid():
		move_tween.kill()
		global_position = grid.grid_to_world(grid_pos)
	is_moving = false
		
	# 1. Process Intimidation Debuff
	if intimidation_turns_remaining > 0:
		intimidation_turns_remaining -= 1
		if not telegraphed_hazard.is_empty():
			_clear_telegraphed_hazard()
		if intimidation_status == "HESITANT":
			if combat:
				combat.emit_signal("floating_text_requested", "Hesitating...", Color(0.8, 0.8, 0.8), global_position)
			return
		elif intimidation_status == "TERRIFIED":
			_execute_flee_from_player()
			return
			
	intimidation_status = ""
	
	# 2. Turn 2 Detonation of Telegraphed Hazard
	if not telegraphed_hazard.is_empty():
		_detonate_telegraphed_hazard()
		return
	
	# 3. Acquire Player Reference
	if not target_player and turn_manager and turn_manager.player:
		target_player = turn_manager.player as Player
		
	# 4. Intelligent Morale Check (< 10% HP)
	var max_health = stats.get_max_health() if stats.has_method("get_max_health") else (max_hp if max_hp > 0.0 else 100.0)
	if is_intelligent and max_health > 0.0:
		if (stats.current_hp / max_health) < 0.10:
			ai_state = AIState.FLEE
			var bus = _get_event_bus()
			if bus:
				bus.emit_signal("player_acted", "enemy_flee", {"message": "%s loses morale and flees in terror!" % enemy_name})
			if combat:
				combat.emit_signal("floating_text_requested", "Fleeing!", Color(1.0, 0.8, 0.2), global_position)
			_execute_flee_from_player()
			return

	# 5. Stealth Ambusher Reveal Check
	if is_ambusher and is_concealed:
		var p_dist = maxi(abs(grid_pos.x - target_player.grid_pos.x), abs(grid_pos.y - target_player.grid_pos.y)) if target_player else 99
		if p_dist <= 1:
			_reveal_ambush(false)
		elif target_player and target_player.skills and target_player.stats:
			var perc_skill = target_player.skills.get_effective_level(SkillData.SkillId.PERCEPTION, target_player.stats.attributes)
			if perc_skill >= 40.0:
				_reveal_ambush(true)
			else:
				return
		else:
			return

	# 6. Target Selection (Player or Rival Faction Monster)
	var current_target: BaseEntity = _select_combat_target()
	if not current_target or (current_target.stats and current_target.stats.current_hp <= 0.0):
		ai_state = AIState.IDLE
		return

	# 7. Chebyshev Distance to Current Target
	var dx = abs(grid_pos.x - current_target.grid_pos.x)
	var dy = abs(grid_pos.y - current_target.grid_pos.y)
	var chebyshev_dist = maxi(dx, dy)

	# 8. 1-Turn Telegraphed AoE Spell Channeling (Turn 1)
	if archetype == BestiaryCatalog.Archetype.SPELLCASTER and signature_spell_id != "":
		if chebyshev_dist >= 2 and chebyshev_dist <= 6:
			_start_telegraphed_hazard(current_target.grid_pos)
			return

	# 9. Ranged Kiting & Sidearm Swap
	if archetype == BestiaryCatalog.Archetype.RANGED_ARCHER or archetype == BestiaryCatalog.Archetype.SPELLCASTER:
		if chebyshev_dist == 2:
			var retreated = _execute_kite_retreat(current_target.grid_pos)
			if retreated:
				return
			else:
				# Cornered: swap to sidearm and attack
				_swap_to_sidearm()
				_execute_attack_entity(current_target)
				return
		elif chebyshev_dist == 1:
			# Adjacent melee: swap to sidearm and attack in melee
			_swap_to_sidearm()
			_execute_attack_entity(current_target)
			return
		elif chebyshev_dist >= 3:
			# Safe distance: swap back to ranged weapon
			_swap_to_ranged()

	# 10. Attack or Chase
	var weapon = inventory.get_equipped_weapon() if inventory else null
	var attack_range = weapon.range_tiles if (weapon and weapon.range_tiles > 1) else 1

	if chebyshev_dist <= attack_range:
		ai_state = AIState.ATTACK
		_execute_attack_entity(current_target)
	else:
		ai_state = AIState.CHASE
		_execute_chase_target(current_target.grid_pos)

		# Swift Elite Affix: take 2nd movement step if still out of range
		if is_elite and elite_affix == "Swift":
			var new_dist = maxi(abs(grid_pos.x - current_target.grid_pos.x), abs(grid_pos.y - current_target.grid_pos.y))
			if new_dist > attack_range:
				_execute_chase_target(current_target.grid_pos)

func _select_combat_target() -> BaseEntity:
	var best_target: BaseEntity = null
	var best_dist: int = 999
	
	if target_player and target_player.stats and target_player.stats.current_hp > 0.0:
		if vision and vision.can_see_entity(grid, grid_pos, target_player):
			best_target = target_player
			best_dist = maxi(abs(grid_pos.x - target_player.grid_pos.x), abs(grid_pos.y - target_player.grid_pos.y))
			
	var foe_list: Array = []
	if turn_manager:
		if "registered_enemies" in turn_manager:
			foe_list = turn_manager.registered_enemies
		elif "enemies" in turn_manager:
			foe_list = turn_manager.enemies
			
	for other_enemy in foe_list:
			if other_enemy == self or not is_instance_valid(other_enemy):
				continue
			if not (other_enemy is Enemy):
				continue
			var foe = other_enemy as Enemy
			if foe.stats and foe.stats.current_hp > 0.0 and foe.faction != faction:
				if vision and vision.can_see_entity(grid, grid_pos, foe):
					var d = maxi(abs(grid_pos.x - foe.grid_pos.x), abs(grid_pos.y - foe.grid_pos.y))
					if d < best_dist or best_target == null:
						best_dist = d
						best_target = foe
						
	return best_target

func _swap_to_sidearm() -> void:
	if inventory and sidearm_weapon:
		var current = inventory.get_equipped_weapon()
		if current != sidearm_weapon:
			inventory.equip_item(sidearm_weapon)

func _swap_to_ranged() -> void:
	if inventory and ranged_weapon:
		var current = inventory.get_equipped_weapon()
		if current != ranged_weapon:
			inventory.equip_item(ranged_weapon)

func _execute_kite_retreat(threat_cell: Vector2i) -> bool:
	var cur_dist = maxi(abs(grid_pos.x - threat_cell.x), abs(grid_pos.y - threat_cell.y))
	var directions = [
		Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)
	]
	var best_step = Vector2i.ZERO
	var best_dist = cur_dist
	for d in directions:
		var cand = grid_pos + d
		if grid and grid.can_enter(cand):
			var d_dist = maxi(abs(cand.x - threat_cell.x), abs(cand.y - threat_cell.y))
			if d_dist > best_dist:
				best_dist = d_dist
				best_step = d
	if best_step != Vector2i.ZERO:
		try_move(best_step)
		return true
	return false

func _start_telegraphed_hazard(target_cell: Vector2i) -> void:
	var cells: Array[Vector2i] = []
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var c = target_cell + Vector2i(ox, oy)
			if grid and grid.is_walkable(c):
				cells.append(c)
				
	var dmg = int(round(14.0 + (max_hp * 0.12)))
	telegraphed_hazard = {
		"spell_id": signature_spell_id,
		"target_cell": target_cell,
		"area_cells": cells,
		"damage": dmg
	}
	
	var bus = _get_event_bus()
	if bus:
		bus.emit_signal("player_acted", "enemy_teleguide", {
			"message": "[TELEGUIDE] %s begins channeling %s at (%d, %d)!" % [enemy_name, signature_spell_id.capitalize(), target_cell.x, target_cell.y]
		})
	if combat:
		combat.emit_signal("floating_text_requested", "[Channeling %s]" % signature_spell_id.capitalize(), Color(1.0, 0.3, 0.3), global_position)
		
	_register_danger_tiles(cells)

func _detonate_telegraphed_hazard() -> void:
	var cells: Array = telegraphed_hazard.get("area_cells", [])
	var dmg: int = int(telegraphed_hazard.get("damage", 15))
	var sp_id = String(telegraphed_hazard.get("spell_id", "Spell"))
	var t_cell: Vector2i = telegraphed_hazard.get("target_cell", grid_pos)

	for c in cells:
		var cv = c as Vector2i
		if grid and grid.is_occupied(cv):
			var occ = grid.get_occupant(cv)
			if is_instance_valid(occ) and occ != self and occ.has_node("StatsComponent"):
				var occ_stats = occ.get_node("StatsComponent") as StatsComponent
				occ_stats.take_damage(dmg, self)
				if combat:
					combat.emit_signal("floating_text_requested", "BLAST! %d" % dmg, Color(1.0, 0.2, 0.2), occ.global_position)

	var bus = _get_event_bus()
	if bus:
		bus.emit_signal("player_acted", "hazard_detonated", {
			"message": "%s's %s detonates at (%d, %d) dealing %d damage!" % [enemy_name, sp_id.capitalize(), t_cell.x, t_cell.y, dmg]
		})
	_clear_telegraphed_hazard()

func _register_danger_tiles(cells: Array[Vector2i]) -> void:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		var tree = loop as SceneTree
		var viz = tree.root.find_child("GridVisualizer", true, false) as GridVisualizer
		if viz:
			viz.set_hazard_zone(str(get_instance_id()), cells)

func _clear_telegraphed_hazard() -> void:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		var tree = loop as SceneTree
		var viz = tree.root.find_child("GridVisualizer", true, false) as GridVisualizer
		if viz:
			viz.remove_hazard_zone(str(get_instance_id()))
	telegraphed_hazard.clear()

func _reveal_ambush(from_perception: bool = false) -> void:
	is_concealed = false
	visible = true
	var bus = _get_event_bus()
	if bus:
		if from_perception:
			bus.emit_signal("player_acted", "ambush_detected", {"message": "[Perception] You detect a concealed %s lurking in the shadows!" % enemy_name})
		else:
			bus.emit_signal("player_acted", "ambush_sprung", {"message": "[Ambush] %s springs from the shadows!" % enemy_name})
	if combat:
		combat.emit_signal("floating_text_requested", "AMBUSH!", Color(1.0, 0.4, 0.2), global_position)

func _execute_attack_entity(target_ent: BaseEntity) -> void:
	facing_direction = target_ent.grid_pos - grid_pos
	_play_bump_animation(facing_direction)
	
	var weapon = inventory.get_equipped_weapon() if inventory else null
	var result = combat.execute_attack(target_ent, weapon)
	
	var bus = _get_event_bus()
	if bus:
		if target_ent is Player:
			var def_action = result.get("defense_verb", "defends")
			var msg = "%s attacks Player for %d damage!" % [enemy_name, result["damage"]] if result["hit"] else "%s attacks Player, but Player %s!" % [enemy_name, def_action]
			bus.emit_signal("player_acted", "enemy_attack", {"message": msg, "result": result})
		elif target_ent is Enemy:
			var foe_name = (target_ent as Enemy).enemy_name
			var msg = "[Infighting] %s attacks rival %s for %d damage!" % [enemy_name, foe_name, result["damage"]] if result["hit"] else "[Infighting] %s attacks rival %s, but misses!" % [enemy_name, foe_name]
			bus.emit_signal("player_acted", "infighting_attack", {"message": msg, "result": result})

func _execute_melee_attack(player_entity: Player) -> void:
	_execute_attack_entity(player_entity)

func _execute_chase_target(dest_cell: Vector2i) -> void:
	var path = grid.find_path(grid_pos, dest_cell)
	if path.size() >= 2:
		var next_step = path[1]
		var dir = next_step - grid_pos
		if grid.can_enter(next_step):
			try_move(dir)
			return
			
	var cur_dist = maxi(abs(grid_pos.x - dest_cell.x), abs(grid_pos.y - dest_cell.y))
	var directions = [
		Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)
	]
	var best_dir = Vector2i.ZERO
	var best_dist = cur_dist
	for d in directions:
		var cand = grid_pos + d
		if grid.can_enter(cand):
			var d_dist = maxi(abs(cand.x - dest_cell.x), abs(cand.y - dest_cell.y))
			if d_dist < best_dist:
				best_dist = d_dist
				best_dir = d
	if best_dir != Vector2i.ZERO:
		try_move(best_dir)

func _execute_chase_player() -> void:
	if target_player:
		_execute_chase_target(target_player.grid_pos)

func _execute_flee_from_player() -> void:
	var away_cell = target_player.grid_pos if target_player else (grid_pos + Vector2i(1, 0))
	var away_dir = grid_pos - away_cell
	var step_x = clampi(away_dir.x, -1, 1)
	var step_y = clampi(away_dir.y, -1, 1)
	var step = Vector2i(step_x, step_y)
	
	if step != Vector2i.ZERO and grid.can_enter(grid_pos + step):
		try_move(step)
	else:
		var neighbors = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		for n in neighbors:
			if grid.can_enter(grid_pos + n):
				try_move(n)
				break

func _on_death(_victim: Node2D) -> void:
	if not telegraphed_hazard.is_empty():
		_clear_telegraphed_hazard()
	if grid:
		grid.unregister_entity(self, grid_pos)
	if turn_manager:
		turn_manager.unregister_enemy(self)
		
	if turn_manager and turn_manager.player:
		var player_stats = turn_manager.player.get_node_or_null("StatsComponent") as StatsComponent
		if player_stats and player_stats.attributes:
			player_stats.attributes.add_kill_exp(base_kill_exp)
			
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.finished.connect(queue_free)

func get_inspection_data(_viewer: Node2D = null) -> InspectionData:
	var data = InspectionData.new()
	data.title = enemy_name
	data.category = InspectionData.Category.HOSTILE
	data.category_text = "Undead Hostile" if is_undead else ("Elite Hostile" if is_elite else "Hostile Creature")
	data.grid_cell = grid_pos
	data.icon_glyph = "U" if is_undead else ("★" if is_elite else "E")
	data.accent_color = Color(1.0, 0.84, 0.0) if is_elite else Color(1.0, 0.38, 0.38)
	
	if stats:
		var max_health = stats.get_max_health() if stats.has_method("get_max_health") else (max_hp if max_hp > 0.0 else (stats.attributes.get_max_health() if stats.attributes else 100.0))
		var h_info = BaseEntity.get_health_status_info(stats.current_hp, max_health)
		data.health_status_text = h_info["label"]
		data.health_status_color = h_info["color"]
	else:
		data.health_status_text = "Unknown"
		data.health_status_color = Color(0.7, 0.7, 0.7)
	
	var traits: Array[String] = []
	match ai_state:
		AIState.IDLE: traits.append("Posture: Guarding / Idle")
		AIState.PATROL: traits.append("Posture: Patrolling")
		AIState.CHASE: traits.append("Posture: Stalking Prey")
		AIState.ATTACK: traits.append("Posture: Engaging in Combat")
		AIState.FLEE: traits.append("Posture: Retreating / Fleeing")
			
	if is_elite and elite_affix != "":
		traits.append("Affix: %s" % elite_affix)
	if is_mini_boss:
		traits.append("Classification: Biome Mini-Boss")
	if intimidation_status != "":
		traits.append("[%s - %d turns]" % [intimidation_status, intimidation_turns_remaining])
	if not telegraphed_hazard.is_empty():
		traits.append("Channeling: %s" % String(telegraphed_hazard.get("spell_id", "")).capitalize())
		
	if inventory:
		var w = inventory.get_equipped_weapon()
		if w:
			traits.append("Armed with %s" % w.item_name)
		var arm = inventory.get_total_armor()
		if arm > 0:
			traits.append("Armor: %d" % arm)
			
	data.description = " • ".join(traits) if traits.size() > 0 else "A dangerous dungeon hostile."
	return data
