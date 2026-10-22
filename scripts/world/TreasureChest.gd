class_name TreasureChest
extends Node2D

## TreasureChest: Interactive grid entity supporting lockpicking, trap disarming,
## and weapon-weighted structural smashing with fragility destruction.

signal chest_opened(chest: TreasureChest)
signal chest_trap_triggered(chest: TreasureChest, victim: Node2D, damage: int)
signal chest_smashed(chest: TreasureChest)

@export var chest_name: String = "Treasure Chest"
@export var grid_pos: Vector2i = Vector2i.ZERO
@export var is_locked: bool = false
@export var is_trapped: bool = false
@export var is_trap_revealed: bool = false
@export var is_opened: bool = false

@export var structural_hp: float = 30.0
@export var max_structural_hp: float = 30.0
@export var hardness: float = 3.0
@export var lock_difficulty: float = 20.0
@export var trap_difficulty: float = 20.0
@export var trap_damage: int = 15
@export var hide_rating: float = 18.0

var contents: Array[ItemData] = []
var grid: DungeonGrid = null

func setup(
	p_grid: DungeonGrid,
	p_pos: Vector2i,
	p_contents: Array[ItemData] = [],
	p_locked: bool = false,
	p_trapped: bool = false,
	p_hardness: float = 3.0,
	p_hp: float = 30.0
) -> void:
	grid = p_grid
	grid_pos = p_pos
	contents = p_contents.duplicate()
	is_locked = p_locked
	is_trapped = p_trapped
	is_trap_revealed = false
	is_opened = false
	hardness = p_hardness
	max_structural_hp = p_hp
	structural_hp = p_hp
	
	if grid:
		position = Vector2(grid.grid_to_world(grid_pos))
	queue_redraw()

func reveal_trap() -> void:
	if not is_trap_revealed:
		is_trap_revealed = true
		queue_redraw()

func _has_thieves_tools(player: Node2D) -> bool:
	if not player:
		return false
	var inv = player.get_node_or_null("InventoryComponent") as InventoryComponent
	if not inv:
		return false
	for it in inv.items:
		if is_instance_valid(it) and it.item_id == "thieves_tools":
			return true
	for slot in inv.equipped_slots.keys():
		var it = inv.equipped_slots[slot] as ItemData
		if is_instance_valid(it) and it.item_id == "thieves_tools":
			return true
	return false

func disarm_trap(player: Node2D) -> Dictionary:
	if not is_trapped:
		return {"success": true, "reason": "The chest is not trapped."}
		
	if not _has_thieves_tools(player):
		return {"success": false, "reason": "Requires Thieves' Tools in inventory to attempt disarming!"}
		
	var eff_skill = 10.0
	var skills_comp = player.get_node_or_null("SkillComponent") as SkillComponent
	var stats_comp = player.get_node_or_null("StatsComponent") as StatsComponent
	if skills_comp and stats_comp:
		eff_skill = skills_comp.get_effective_level(SkillData.SkillId.DISABLE_DEVICE, stats_comp.attributes)
		
	var disarm_chance = clampf((eff_skill + 50.0) / ((trap_difficulty + 50.0) * 1.5), 0.15, 0.95)
	var roll = randf()
	if roll <= disarm_chance:
		is_trapped = false
		is_trap_revealed = true
		if skills_comp and stats_comp:
			skills_comp.train_skill(SkillData.SkillId.DISABLE_DEVICE, trap_difficulty, stats_comp.attributes)
		queue_redraw()
		return {"success": true, "reason": "Trap disarmed successfully!"}
	else:
		# Critical failure: roll > 0.85 and low skill detonates trap
		if (1.0 - roll) < 0.15 and eff_skill < trap_difficulty:
			var res = trigger_trap(player)
			return {
				"success": false,
				"critical": true,
				"reason": "Critical Failure! The trap detonated!",
				"damage": res["damage"]
			}
		return {"success": false, "critical": false, "reason": "Failed to disarm trap (no detonation, retry allowed)."}

func pick_lock(player: Node2D) -> Dictionary:
	if not is_locked:
		is_opened = true
		emit_signal("chest_opened", self)
		queue_redraw()
		return {"success": true, "reason": "Chest is already unlocked."}
		
	if not _has_thieves_tools(player):
		return {"success": false, "reason": "Requires Thieves' Tools to attempt picking the lock!"}
		
	if is_trapped:
		var trap_res = trigger_trap(player)
		return {
			"success": false,
			"trap_triggered": true,
			"damage": trap_res["damage"],
			"reason": "Trapped mechanism sprung while tampering with the lock!"
		}
		
	var eff_skill = 10.0
	var skills_comp = player.get_node_or_null("SkillComponent") as SkillComponent
	var stats_comp = player.get_node_or_null("StatsComponent") as StatsComponent
	if skills_comp and stats_comp:
		eff_skill = skills_comp.get_effective_level(SkillData.SkillId.LOCKPICKING, stats_comp.attributes)
		
	var pick_chance = clampf((eff_skill + 50.0) / ((lock_difficulty + 50.0) * 1.5), 0.20, 0.95)
	if randf() <= pick_chance:
		is_locked = false
		is_opened = true
		if skills_comp and stats_comp:
			skills_comp.train_skill(SkillData.SkillId.LOCKPICKING, lock_difficulty, stats_comp.attributes)
		emit_signal("chest_opened", self)
		queue_redraw()
		return {"success": true, "reason": "Lock picked successfully! Chest opened."}
	else:
		return {"success": false, "reason": "Failed to pick lock."}

func trigger_trap(victim: Node2D) -> Dictionary:
	is_trapped = false
	is_trap_revealed = true
	var damage_dealt = trap_damage
	if victim and is_instance_valid(victim):
		var stats = victim.get_node_or_null("StatsComponent") as StatsComponent
		if stats:
			stats.take_damage(damage_dealt)
	emit_signal("chest_trap_triggered", self, victim, damage_dealt)
	queue_redraw()
	return {"damage": damage_dealt, "victim": victim}

func calculate_weapon_structural_multiplier(weapon: ItemData) -> float:
	if not weapon:
		return 1.15 # Unarmed / Brawling
	if weapon.handedness == ItemData.Handedness.TWO_HANDED:
		return 1.75
	match weapon.associated_skill_id:
		SkillData.SkillId.BLUNT_WEAPON_FIGHTING, SkillData.SkillId.SWORDSMANSHIP, SkillData.SkillId.BRAWLING, SkillData.SkillId.POLEARMS:
			return 1.15
		SkillData.SkillId.FINESSE_WEAPON_FIGHTING, SkillData.SkillId.ARCHERY, SkillData.SkillId.THROWING:
			return 0.50
		_:
			return 1.15

func take_structural_damage(attacker: Node2D, raw_damage: float, weapon: ItemData = null) -> Dictionary:
	var m = calculate_weapon_structural_multiplier(weapon)
	var scaled = floorf(raw_damage * m)
	var structural_damage = maxi(1, int(scaled - hardness))
	
	if is_trapped:
		trigger_trap(attacker)
		
	structural_hp -= structural_damage
	queue_redraw()
	
	if structural_hp <= 0.0:
		structural_hp = 0.0
		is_opened = true
		is_locked = false
		
		# 40% shatter chance per fragile item
		var shattered_count = 0
		for i in range(contents.size()):
			var it = contents[i]
			if it and (it.is_fragile or it.item_id.begins_with("potion_")):
				if randf() < 0.40:
					shattered_count += 1
					var shards = ItemData.new("broken_glass", "Broken Glass Shards", ItemData.ItemType.RELIC, ItemData.EquipSlot.NONE, 0.2)
					shards.description = "Shattered remains of an alchemical vial destroyed during a brute force breach."
					contents[i] = shards
					
		emit_signal("chest_smashed", self)
		emit_signal("chest_opened", self)
		return {
			"destroyed": true,
			"damage_dealt": structural_damage,
			"shattered_count": shattered_count,
			"remaining_hp": 0.0
		}
		
	return {
		"destroyed": false,
		"damage_dealt": structural_damage,
		"remaining_hp": structural_hp
	}

func get_inspection_data(_viewer: Node2D = null) -> InspectionData:
	var data = InspectionData.new()
	data.title = chest_name
	data.category = InspectionData.Category.ITEM_OR_OBJECT
	data.grid_cell = grid_pos
	data.icon_glyph = "▣"
	data.accent_color = Color(0.9, 0.7, 0.2)
	
	var status_parts: Array[String] = []
	if is_opened:
		status_parts.append("Opened (%d items)" % contents.size())
	else:
		status_parts.append("Locked" if is_locked else "Unlocked")
		if is_trap_revealed:
			status_parts.append("Trapped [REVEALED]")
		status_parts.append("HP: %d/%d (Hardness %d)" % [int(structural_hp), int(max_structural_hp), int(hardness)])
		
	data.category_text = " • ".join(status_parts)
	data.description = "A heavy dungeon coffer banded in iron. Press [G] to interact, unlock, or loot."
	return data

func _draw() -> void:
	if not grid:
		return
	var s = float(grid.tile_size.x)
	var half = s / 2.0
	
	var body_rect = Rect2(-half * 0.7, -half * 0.5, s * 0.7, s * 0.5)
	var col_wood = Color(0.45, 0.25, 0.1) if not is_opened else Color(0.35, 0.2, 0.08, 0.7)
	var col_trim = Color(0.85, 0.7, 0.2)
	
	draw_rect(body_rect, col_wood)
	draw_rect(body_rect, col_trim, false, 1.5)
	
	# Lock clasp
	if not is_opened:
		draw_rect(Rect2(-half * 0.15, -half * 0.2, s * 0.15, s * 0.2), Color(0.95, 0.8, 0.2))
	else:
		# Open lid line
		draw_line(Vector2(-half * 0.7, -half * 0.5), Vector2(-half * 0.5, -half * 0.8), col_trim, 2.0)
		draw_line(Vector2(half * 0.7, -half * 0.5), Vector2(half * 0.5, -half * 0.8), col_trim, 2.0)
		
	# Red trap symbol if revealed
	if is_trapped and is_trap_revealed:
		draw_circle(Vector2(0, -half * 0.6), half * 0.15, Color(1.0, 0.2, 0.2, 0.9))
