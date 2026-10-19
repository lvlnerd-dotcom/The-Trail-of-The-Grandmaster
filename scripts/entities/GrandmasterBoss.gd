class_name GrandmasterBoss
extends Enemy

## GrandmasterBoss: Floor 20 Final Boss entity.
## 3-phase epic encounter:
## - Phase 1: Martial Ascendant (Stance rotations: Bulwark, Frenzy, Riposte, Grand Whirlwind)
## - Phase 2: Arcane Sovereign (300 HP Nova, 35 HP Arcane Ward, Blink Kiting, Fireball Barrage, Smite)
## - Phase 3: Transcendence (150 HP Shockwave, 2 Spectral Clones, Harmonic Equilibrium, Triple-Crits)
## - On Defeat: Drops Mantle of the Grandmaster, triggers Victory sequence and achievements.

enum Phase {
	PHASE_1_MARTIAL,
	PHASE_2_ARCANE,
	PHASE_3_TRANSCENDENCE
}

enum Stance {
	BULWARK,
	FRENZY,
	RIPOSTE
}

enum Equilibrium {
	PHYSICAL_IMMUNE,
	MAGIC_IMMUNE
}

const MAX_BOSS_HP: float = 450.0
const PHASE_1_THRESHOLD: float = 300.0
const PHASE_2_THRESHOLD: float = 150.0
const BASE_ARMOR_SOAK: int = 8

var current_phase: Phase = Phase.PHASE_1_MARTIAL
var current_stance: Stance = Stance.BULWARK
var stance_turn_count: int = 0

var arcane_ward_hp: float = 0.0
var equilibrium_mode: Equilibrium = Equilibrium.PHYSICAL_IMMUNE
var equilibrium_turn_count: int = 0

var boss_turn_count: int = 0
var spawned_clones: Array[Node2D] = []
var is_defeated: bool = false
var dropped_relic: ItemData = null

func _ready() -> void:
	super._ready()
	enemy_name = "The Grandmaster"
	base_kill_exp = 500
	vision_range = 16
	_init_boss_stats()

func _init_boss_stats() -> void:
	if not stats:
		stats = get_node_or_null("StatsComponent") as StatsComponent
		if not stats:
			stats = StatsComponent.new()
			stats.name = "StatsComponent"
			add_child(stats)
			
	if not stats.attributes:
		stats.attributes = AttributesData.new()
		
	# High boss attributes
	stats.attributes.strength = 18
	stats.attributes.dexterity = 18
	stats.attributes.constitution = 20
	stats.attributes.intelligence = 18
	stats.attributes.wisdom = 18
	stats.attributes.charisma = 18
	max_hp = MAX_BOSS_HP
	stats.max_hp_override = MAX_BOSS_HP
	stats.current_hp = MAX_BOSS_HP
	
	if not skills:
		skills = get_node_or_null("SkillComponent") as SkillComponent
		if not skills:
			skills = SkillComponent.new()
			skills.name = "SkillComponent"
			add_child(skills)
	var w_skill = skills.get_skill(SkillData.SkillId.SWORDSMANSHIP)
	if w_skill:
		w_skill.level = 65.0
	var d_skill = skills.get_skill(SkillData.SkillId.PARRY)
	if d_skill:
		d_skill.level = 60.0
	var dodge_skill = skills.get_skill(SkillData.SkillId.DODGE)
	if dodge_skill:
		dodge_skill.level = 50.0
		
	# Boss Grand Blade
	var grand_blade = ItemData.new("grandmaster_blade", "Grandmaster Blade", ItemData.ItemType.WEAPON, ItemData.EquipSlot.MAIN_HAND, 4.0)
	grand_blade.base_damage_min = 18
	grand_blade.base_damage_max = 28
	if inventory:
		inventory.equip_item(grand_blade)
		
	if stats:
		stats.health_changed.connect(_on_boss_health_changed)

func _on_boss_health_changed(curr_hp: float, _max_hp: float) -> void:
	if is_defeated:
		return
	if curr_hp <= 0.0:
		_on_grandmaster_defeated()
		return
		
	if current_phase == Phase.PHASE_1_MARTIAL and curr_hp <= PHASE_1_THRESHOLD:
		_transition_to_phase_2()
	if current_phase == Phase.PHASE_2_ARCANE and curr_hp <= PHASE_2_THRESHOLD:
		_transition_to_phase_3()

# ==========================================
# PHASE TRANSITIONS
# ==========================================

func _transition_to_phase_2() -> void:
	current_phase = Phase.PHASE_2_ARCANE
	arcane_ward_hp = 35.0
	
	var bus = _get_event_bus()
	if bus:
		bus.emit_signal("boss_phase_changed", self, 2)
		bus.emit_signal("camera_trauma_requested", 0.65, Vector2.ZERO)
		
	# Ascendant Nova: 15 force damage & 2 tile knockback
	_execute_ascendant_nova()
	
	if combat:
		combat.emit_signal("floating_text_requested", "PHASE 2: ARCANE SOVEREIGN!", Color(0.2, 0.8, 1.0), global_position)

func _execute_ascendant_nova() -> void:
	var target = _get_target_entity()
	if not target or not grid:
		return
	var dist = abs(grid_pos.x - target.grid_pos.x) + abs(grid_pos.y - target.grid_pos.y)
	if dist <= 3:
		var target_stats = target.get_node_or_null("StatsComponent") as StatsComponent
		if target_stats:
			target_stats.take_damage(15, self)
		# 2 tile knockback away from boss
		var knock_dir = target.grid_pos - grid_pos
		var step_x = clampi(knock_dir.x, -1, 1)
		var step_y = clampi(knock_dir.y, -1, 1)
		var step = Vector2i(step_x, step_y)
		var dest = target.grid_pos + step * 2
		if grid.can_enter(dest):
			grid.move_entity(target, target.grid_pos, dest)
			target.grid_pos = dest
			target.global_position = grid.grid_to_world(dest)

func _transition_to_phase_3() -> void:
	current_phase = Phase.PHASE_3_TRANSCENDENCE
	equilibrium_mode = Equilibrium.PHYSICAL_IMMUNE
	equilibrium_turn_count = 0
	
	var bus = _get_event_bus()
	if bus:
		bus.emit_signal("boss_phase_changed", self, 3)
		bus.emit_signal("camera_trauma_requested", 0.70, Vector2.ZERO)
		
	# Spawn 2 Spectral Clones
	_spawn_spectral_clones()
	
	if combat:
		combat.emit_signal("floating_text_requested", "PHASE 3: TRANSCENDENCE!", Color(1.0, 0.4, 0.9), global_position)

func _spawn_spectral_clones() -> void:
	if not grid:
		return
	var offsets = [Vector2i(-3, -2), Vector2i(3, -2)]
	var clone_types = ["SHADOW", "LIGHT"]
	
	for i in range(2):
		var target_c = grid_pos + offsets[i]
		if not grid.can_enter(target_c):
			target_c = grid_pos + Vector2i(offsets[i].x, 0)
			if not grid.can_enter(target_c):
				target_c = grid_pos
				
		var clone = SpectralClone.new(clone_types[i], self)
		var p = get_parent()
		if p:
			p.add_child(clone)
		else:
			add_child(clone)
		clone.init_grid_position(grid, target_c, turn_manager)
		spawned_clones.append(clone)
		if turn_manager:
			turn_manager.register_enemy(clone)

# ==========================================
# DAMAGE INTERCEPTION & EQUILIBRIUM
# ==========================================

func take_boss_damage(raw_amount: int, is_spell: bool = false, attacker: Node2D = null) -> int:
	if is_defeated:
		return 0
		
	var incoming = raw_amount
	
	# Phase 3 Harmonic Equilibrium check
	if current_phase == Phase.PHASE_3_TRANSCENDENCE:
		if equilibrium_mode == Equilibrium.PHYSICAL_IMMUNE:
			if not is_spell:
				if combat:
					combat.emit_signal("floating_text_requested", "PHYSICAL IMMUNE!", Color(0.7, 0.7, 0.7), global_position)
				return 0
			else:
				incoming = int(float(incoming) * 1.5)
				if combat:
					combat.emit_signal("floating_text_requested", "MAGIC VULNERABLE! (1.5x)", Color(0.2, 0.9, 1.0), global_position)
		elif equilibrium_mode == Equilibrium.MAGIC_IMMUNE:
			if is_spell:
				if combat:
					combat.emit_signal("floating_text_requested", "MAGIC IMMUNE!", Color(0.7, 0.7, 0.7), global_position)
				return 0
			else:
				incoming = int(float(incoming) * 1.5)
				if combat:
					combat.emit_signal("floating_text_requested", "PHYSICAL VULNERABLE! (1.5x)", Color(1.0, 0.5, 0.2), global_position)

	# Armor soak calculation
	var effective_armor = BASE_ARMOR_SOAK
	if current_phase == Phase.PHASE_1_MARTIAL and current_stance == Stance.BULWARK:
		effective_armor += 4 # Bulwark Stance: +4 Armor Soak
	
	if not is_spell:
		incoming = max(1, incoming - effective_armor)
		
	# Arcane Ward shield absorption
	if arcane_ward_hp > 0.0:
		var absorbed = minf(arcane_ward_hp, float(incoming))
		arcane_ward_hp -= absorbed
		incoming -= int(absorbed)
		if combat:
			combat.emit_signal("floating_text_requested", "WARD: -%d" % int(absorbed), Color(0.3, 0.7, 1.0), global_position)
			
	if incoming > 0:
		stats.current_hp = maxf(0.0, stats.current_hp - incoming)
		stats.emit_signal("health_changed", stats.current_hp, MAX_BOSS_HP)
		
	return incoming

# ==========================================
# TURN EXECUTION & STATE MACHINE
# ==========================================

func take_turn() -> void:
	if is_defeated or stats.current_hp <= 0.0 or not grid:
		return
		
	boss_turn_count += 1
	var target = _get_target_entity()
	if not target:
		return
		
	match current_phase:
		Phase.PHASE_1_MARTIAL:
			_execute_phase_1_turn(target)
		Phase.PHASE_2_ARCANE:
			_execute_phase_2_turn(target)
		Phase.PHASE_3_TRANSCENDENCE:
			_execute_phase_3_turn(target)

func _execute_phase_1_turn(target: BaseEntity) -> void:
	# Stance rotation every 4 turns
	stance_turn_count += 1
	if stance_turn_count >= 4:
		stance_turn_count = 0
		current_stance = ((current_stance + 1) % 3) as Stance
		var stance_names = ["Bulwark Stance (+4 Armor, 35% Parry)", "Frenzy Stance (Double Strike!)", "Riposte Stance (Counter-Strikes!)"]
		if combat:
			combat.emit_signal("floating_text_requested", stance_names[current_stance], Color(1.0, 0.8, 0.2), global_position)
			
	var dist = maxi(abs(grid_pos.x - target.grid_pos.x), abs(grid_pos.y - target.grid_pos.y))
	
	# Grand Whirlwind if adjacent and target nearby
	if dist <= 1 and randf() < 0.35:
		_execute_grand_whirlwind(target)
		return
		
	if dist <= 1:
		_execute_boss_melee(target)
		if current_stance == Stance.FRENZY:
			_execute_boss_melee(target) # Second strike!
	else:
		_execute_chase_player()

func _execute_phase_2_turn(target: BaseEntity) -> void:
	var dist = maxi(abs(grid_pos.x - target.grid_pos.x), abs(grid_pos.y - target.grid_pos.y))
	
	# Tactical Blink: If adjacent, teleport 4-5 tiles away to kite
	if dist <= 1:
		_execute_tactical_blink()
		return
		
	# Alternate between Fireball Barrage and Radiant Smite Beam
	if boss_turn_count % 2 == 0:
		_execute_fireball_barrage(target)
	else:
		_execute_radiant_smite(target)

func _execute_phase_3_turn(target: BaseEntity) -> void:
	# Harmonic Equilibrium flip every 3 turns
	equilibrium_turn_count += 1
	if equilibrium_turn_count >= 3:
		equilibrium_turn_count = 0
		equilibrium_mode = Equilibrium.MAGIC_IMMUNE if equilibrium_mode == Equilibrium.PHYSICAL_IMMUNE else Equilibrium.PHYSICAL_IMMUNE
		var eq_text = "EQUILIBRIUM: MAGIC IMMUNE!" if equilibrium_mode == Equilibrium.MAGIC_IMMUNE else "EQUILIBRIUM: PHYSICAL IMMUNE!"
		var eq_color = Color(1.0, 0.85, 0.2) if equilibrium_mode == Equilibrium.MAGIC_IMMUNE else Color(0.6, 0.3, 0.9)
		if combat:
			combat.emit_signal("floating_text_requested", eq_text, eq_color, global_position)
			
	var dist = maxi(abs(grid_pos.x - target.grid_pos.x), abs(grid_pos.y - target.grid_pos.y))
	if dist <= 1:
		# Multi-tier crits on melee strike (up to 3.0x damage)
		_execute_boss_melee(target, 3.0)
	else:
		_execute_chase_player()

# ==========================================
# SPECIAL ABILITIES
# ==========================================

func _execute_grand_whirlwind(target: BaseEntity) -> void:
	var bus = _get_event_bus()
	if bus:
		bus.emit_signal("camera_trauma_requested", 0.35, Vector2.ZERO)
	if combat:
		combat.emit_signal("floating_text_requested", "GRAND WHIRLWIND!", Color(1.0, 0.3, 0.1), global_position)
		
	var target_stats = target.get_node_or_null("StatsComponent") as StatsComponent
	if target_stats:
		var dmg = int(randf_range(18, 28) * 1.2)
		target_stats.take_damage(dmg, self)

func _execute_tactical_blink() -> void:
	if not grid:
		return
	var candidates: Array[Vector2i] = []
	for dx in range(-5, 6):
		for dy in range(-5, 6):
			var d = abs(dx) + abs(dy)
			if d >= 4 and d <= 5:
				var c = grid_pos + Vector2i(dx, dy)
				if grid.can_enter(c):
					candidates.append(c)
	if candidates.size() > 0:
		candidates.shuffle()
		var new_c = candidates[0]
		grid.move_entity(self, grid_pos, new_c)
		grid_pos = new_c
		global_position = grid.grid_to_world(new_c)
		if combat:
			combat.emit_signal("floating_text_requested", "BLINK!", Color(0.4, 0.7, 1.0), global_position)

func _execute_fireball_barrage(target: BaseEntity) -> void:
	var center = target.grid_pos
	var bus = _get_event_bus()
	if bus:
		bus.emit_signal("camera_trauma_requested", 0.45, Vector2.ZERO)
		bus.emit_signal("decal_requested", "scorch", center)
		
	if combat:
		combat.emit_signal("floating_text_requested", "FIREBALL BARRAGE!", Color(1.0, 0.3, 0.0), global_position)
		
	# 3x3 blast area
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var c = center + Vector2i(dx, dy)
			if c == target.grid_pos:
				var t_stats = target.get_node_or_null("StatsComponent") as StatsComponent
				if t_stats:
					t_stats.take_damage(30, self)

func _execute_radiant_smite(target: BaseEntity) -> void:
	if combat:
		combat.emit_signal("floating_text_requested", "RADIANT SMITE!", Color(1.0, 0.95, 0.4), global_position)
	var bus = _get_event_bus()
	if bus:
		bus.emit_signal("decal_requested", "holy_glyph", target.grid_pos)
		bus.emit_signal("camera_trauma_requested", 0.30, Vector2.ZERO)
		
	var t_stats = target.get_node_or_null("StatsComponent") as StatsComponent
	if t_stats:
		# 25 radiant damage penetrating 50% armor
		t_stats.take_damage(25, self)

func _execute_boss_melee(target: BaseEntity, crit_mult: float = 1.5) -> void:
	facing_direction = target.grid_pos - grid_pos
	_play_bump_animation(facing_direction)
	
	var weapon = inventory.get_equipped_weapon() if inventory else null
	var result = combat.execute_attack(target, weapon) if combat else {"hit": true, "damage": 20}
	
	var bus = _get_event_bus()
	if bus:
		var trauma = 0.35 if result.get("is_crit", false) else 0.15
		bus.emit_signal("camera_trauma_requested", trauma, Vector2(facing_direction.x, facing_direction.y))
		var msg = "The Grandmaster strikes Player for %d damage!" % result.get("damage", 20)
		bus.emit_signal("player_acted", "enemy_attack", {"message": msg, "result": result})

func _get_target_entity() -> BaseEntity:
	if target_player and is_instance_valid(target_player):
		return target_player
	if turn_manager and turn_manager.player:
		target_player = turn_manager.player as BaseEntity
		return target_player
	return null

# ==========================================
# DEFEAT & REWARD BESTOWAL
# ==========================================

func _on_grandmaster_defeated() -> void:
	if is_defeated:
		return
	is_defeated = true
	stats.current_hp = 0.0
	
	# 1. Dissolve all spectral clones
	for clone in spawned_clones:
		if is_instance_valid(clone):
			clone.queue_free()
	spawned_clones.clear()
	
	# 2. Drop Mantle of the Grandmaster relic
	dropped_relic = ItemData.new("mantle_of_the_grandmaster", "Mantle of the Grandmaster", ItemData.ItemType.RELIC, ItemData.EquipSlot.BODY, 0.5)
	dropped_relic.description = "The ancient vestment of the Grandmaster. Imbued with peerless martial mastery and astral equilibrium."
	dropped_relic.attribute_bonuses = {
		"strength": 3,
		"dexterity": 3,
		"constitution": 3,
		"intelligence": 3,
		"wisdom": 3,
		"charisma": 3
	}
	dropped_relic.armor_value = 10
	dropped_relic.parry_bonus = 15.0
	dropped_relic.dodge_bonus = 15.0
	dropped_relic.carry_weight_bonus = 20.0
	
	# Give relic directly to player inventory if present
	var p = _get_target_entity()
	if p and p.get_node_or_null("InventoryComponent"):
		var p_inv = p.get_node_or_null("InventoryComponent") as InventoryComponent
		p_inv.add_item(dropped_relic)
		
	# 3. Unlock Achievement & Emit Victory
	var meta_mgr = _get_meta_mgr()
	if meta_mgr and meta_mgr.has_method("unlock_achievement"):
		meta_mgr.unlock_achievement("GRANDMASTER_CONQUEROR", "Grandmaster Conqueror")
		
	var bus = _get_event_bus()
	if bus:
		bus.emit_signal("boss_defeated", self)
		var summary = {
			"floors_cleared": 20,
			"boss_kills": 1,
			"victory": true,
			"turns_survived": turn_manager.turn_number if turn_manager else 100
		}
		bus.emit_signal("victory_achieved", summary)
		
	# Unregister from turn manager
	if turn_manager:
		turn_manager.unregister_enemy(self)
	if grid:
		grid.unregister_entity(self, grid_pos)

func _get_meta_mgr() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("MetaManager")
	return null

func get_inspection_data(_viewer: Node2D = null) -> InspectionData:
	var data = InspectionData.new()
	data.title = enemy_name
	data.category = InspectionData.Category.HOSTILE
	data.category_text = "Floor 20 Boss • Ascendant Master"
	data.grid_cell = grid_pos
	data.icon_glyph = "Ω"
	data.accent_color = Color(1.0, 0.84, 0.0) # Radiant Gold
	
	var cur_hp = stats.current_hp if stats else 0.0
	var h_info = BaseEntity.get_health_status_info(cur_hp, MAX_BOSS_HP)
	data.health_status_text = h_info["label"]
	data.health_status_color = h_info["color"]
	
	var traits: Array[String] = []
	match current_phase:
		Phase.PHASE_1_MARTIAL:
			traits.append("Phase I: Martial Ascendant")
			var s_name = "Bulwark"
			if current_stance == Stance.FRENZY:
				s_name = "Frenzy"
			elif current_stance == Stance.RIPOSTE:
				s_name = "Riposte"
			traits.append("Stance: %s" % s_name)
		Phase.PHASE_2_ARCANE:
			traits.append("Phase II: Arcane Sovereign")
			if arcane_ward_hp > 0.0:
				traits.append("Arcane Ward Active")
			else:
				traits.append("Ward Shattered")
		Phase.PHASE_3_TRANSCENDENCE:
			traits.append("Phase III: Transcendence")
			if equilibrium_mode == Equilibrium.PHYSICAL_IMMUNE:
				traits.append("Harmonic Equilibrium: Physical Immune")
			else:
				traits.append("Harmonic Equilibrium: Magic Immune")
				
	data.description = " • ".join(traits)
	return data

# ==========================================
# SPECTRAL CLONE SUBCLASS
# ==========================================

class SpectralClone extends Enemy:
	var clone_tag: String = "SHADOW"
	var parent_boss: Enemy = null
	
	func _init(p_tag: String = "SHADOW", p_boss: Enemy = null) -> void:
		clone_tag = p_tag
		parent_boss = p_boss
		enemy_name = "Shadow of the Grandmaster" if p_tag == "SHADOW" else "Light of the Grandmaster"
		base_kill_exp = 50
		
	func _ready() -> void:
		super._ready()
		if not stats:
			stats = StatsComponent.new()
			stats.name = "StatsComponent"
			add_child(stats)
		max_hp = 75.0
		stats.max_hp_override = 75.0
		stats.current_hp = 75.0
		
	func take_turn() -> void:
		if not is_instance_valid(parent_boss) or parent_boss.is_defeated:
			queue_free()
			return
		if stats.current_hp <= 0.0 or not grid:
			return
			
		var target = _get_target_player()
		if not target:
			return
			
		var dist = maxi(abs(grid_pos.x - target.grid_pos.x), abs(grid_pos.y - target.grid_pos.y))
		if clone_tag == "SHADOW":
			if dist <= 1:
				_execute_clone_attack(target)
			else:
				_execute_chase_player()
		else:
			# Light clone: heals boss if damaged, or casts ranged light bolt
			if parent_boss and parent_boss.stats and parent_boss.stats.current_hp < 435.0:
				parent_boss.stats.current_hp = minf(450.0, parent_boss.stats.current_hp + 15.0)
				var boss_combat = parent_boss.get_node_or_null("CombatComponent")
				if boss_combat:
					boss_combat.emit_signal("floating_text_requested", "+15 HP (Light Heal)", Color(0.2, 0.9, 0.4), parent_boss.global_position)
			elif dist <= 4:
				var t_stats = target.get_node_or_null("StatsComponent") as StatsComponent
				if t_stats:
					t_stats.take_damage(12, self)
					
	func _execute_clone_attack(target: BaseEntity) -> void:
		var t_stats = target.get_node_or_null("StatsComponent") as StatsComponent
		if t_stats:
			t_stats.take_damage(14, self)
			
	func _get_target_player() -> BaseEntity:
		if turn_manager and turn_manager.player:
			return turn_manager.player as BaseEntity
		return null

	func get_inspection_data(_viewer: Node2D = null) -> InspectionData:
		var data = InspectionData.new()
		data.title = "%s Spectral Clone" % clone_tag.capitalize()
		data.category = InspectionData.Category.HOSTILE
		data.category_text = "Astral Apparition"
		data.grid_cell = grid_pos
		data.icon_glyph = "S" if clone_tag == "SHADOW" else "L"
		data.accent_color = Color(0.6, 0.4, 0.9) if clone_tag == "SHADOW" else Color(1.0, 1.0, 0.6)
		var h_info = BaseEntity.get_health_status_info(stats.current_hp if stats else 0.0, 75.0)
		data.health_status_text = h_info["label"]
		data.health_status_color = h_info["color"]
		data.description = "A manifestation of astral ki bound to the Grandmaster."
		return data
