class_name StatusEffectComponent
extends Node

## StatusEffectComponent: Turn-based buff and debuff engine attached to BaseEntity.
## Supports additive independent Bleed stacks, tier-promoting Poison with duration refresh,
## Stun, Blindness, Haste (+1 action/turn), Giant Strength, and Arcane Ward shields.

signal status_applied(status_name: String, details: Dictionary)
signal status_ticked(status_name: String, amount: int, turns_left: int)
signal status_expired(status_name: String)

enum PoisonTier {
	NONE = 0,
	MINOR = 1,
	STANDARD = 2,
	GREATER = 3
}

# --- State ---
var bleed_stacks: Array[Dictionary] = [] # Array of {"damage_per_turn": int, "turns_remaining": int}

var poison_tier: PoisonTier = PoisonTier.NONE
var poison_turns_remaining: int = 0

var stun_turns: int = 0
var blindness_turns: int = 0
var haste_turns: int = 0

var giant_strength_turns: int = 0
var giant_strength_bonus: int = 5
var giant_strength_applied: int = 0

var weakness_turns: int = 0
var weakness_penalty_applied: int = 0

var arcane_ward_hp: int = 0
var invisibility_turns: int = 0

func _get_parent_entity() -> Node:
	return get_parent()

func _get_stats() -> StatsComponent:
	var p = _get_parent_entity()
	if p:
		var st = p.get_node_or_null("StatsComponent") as StatsComponent
		if st:
			return st
		for child in p.get_children():
			if child is StatsComponent:
				return child as StatsComponent
	return null

# --- Bleed: Additive & Independent Stacking ---
## Each Bleed application tracks its own {damage_per_turn, turns_remaining}.
## Stacks sum their damage together on tick without refreshing older stack durations.
func apply_bleed(damage_per_turn: int, duration_turns: int) -> void:
	if damage_per_turn <= 0 or duration_turns <= 0:
		return
	bleed_stacks.append({
		"damage_per_turn": damage_per_turn,
		"turns_remaining": duration_turns
	})
	emit_signal("status_applied", "BLEED", {
		"damage_per_turn": damage_per_turn,
		"duration": duration_turns,
		"total_stacks": bleed_stacks.size()
	})

func is_bleeding() -> bool:
	return not bleed_stacks.is_empty()

func get_total_bleed_damage_per_turn() -> int:
	var total: int = 0
	for stack in bleed_stacks:
		total += int(stack.get("damage_per_turn", 0))
	return total

func get_max_bleed_turns_remaining() -> int:
	var max_t: int = 0
	for stack in bleed_stacks:
		max_t = maxi(max_t, int(stack.get("turns_remaining", 0)))
	return max_t

func cure_bleed() -> void:
	if not bleed_stacks.is_empty():
		bleed_stacks.clear()
		emit_signal("status_expired", "BLEED")

# --- Poison: Single-Track Refresh + Tier Promotion ---
## Adding Poison refreshes duration = max(current_remaining, new_duration).
## Rolls a promotion chance (base 50% + promotion_bonus):
## Minor (3 dmg/t) -> Standard (7 dmg/t) -> Greater (15 dmg/t).
func apply_poison(initial_tier: PoisonTier = PoisonTier.MINOR, duration_turns: int = 5, force_promote: bool = false, promotion_bonus: float = 0.0) -> bool:
	if initial_tier == PoisonTier.NONE or duration_turns <= 0:
		return false

	var was_promoted = false
	if poison_tier == PoisonTier.NONE:
		poison_tier = initial_tier
		poison_turns_remaining = duration_turns
	else:
		# Duration refresh
		poison_turns_remaining = maxi(poison_turns_remaining, duration_turns)
		# Tier Promotion check: Base 50% chance
		var roll = randf()
		if force_promote or roll < (0.50 + promotion_bonus):
			if poison_tier == PoisonTier.MINOR:
				poison_tier = PoisonTier.STANDARD
				was_promoted = true
			elif poison_tier == PoisonTier.STANDARD:
				poison_tier = PoisonTier.GREATER
				was_promoted = true

	emit_signal("status_applied", "POISON", {
		"tier": poison_tier,
		"damage_per_turn": get_poison_damage_per_turn(),
		"turns_remaining": poison_turns_remaining,
		"promoted": was_promoted
	})
	return was_promoted

func is_poisoned() -> bool:
	return poison_tier != PoisonTier.NONE and poison_turns_remaining > 0

func get_poison_damage_per_turn() -> int:
	match poison_tier:
		PoisonTier.MINOR: return 3
		PoisonTier.STANDARD: return 7
		PoisonTier.GREATER: return 15
		_: return 0

func get_poison_tier_string() -> String:
	match poison_tier:
		PoisonTier.MINOR: return "I"
		PoisonTier.STANDARD: return "II"
		PoisonTier.GREATER: return "III"
		_: return ""

func cure_poison() -> void:
	if is_poisoned():
		poison_tier = PoisonTier.NONE
		poison_turns_remaining = 0
		emit_signal("status_expired", "POISON")

# --- Stun ---
func apply_stun(duration_turns: int = 1) -> void:
	stun_turns = maxi(stun_turns, duration_turns)
	emit_signal("status_applied", "STUN", {"duration": stun_turns})

func is_stunned() -> bool:
	return stun_turns > 0

# --- Blindness ---
func apply_blindness(duration_turns: int = 3) -> void:
	blindness_turns = maxi(blindness_turns, duration_turns)
	emit_signal("status_applied", "BLINDNESS", {"duration": blindness_turns})

func is_blinded() -> bool:
	return blindness_turns > 0

# --- Haste ---
func apply_haste(duration_turns: int = 5) -> void:
	haste_turns = maxi(haste_turns, duration_turns)
	emit_signal("status_applied", "HASTE", {"duration": haste_turns})

func is_hasted() -> bool:
	return haste_turns > 0

# --- Giant Strength ---
func apply_giant_strength(duration_turns: int = 20, bonus_str: int = 5) -> void:
	giant_strength_turns = duration_turns
	if giant_strength_applied == 0:
		giant_strength_applied = bonus_str
		var stats = _get_stats()
		if stats and stats.attributes:
			stats.attributes.strength += bonus_str
	emit_signal("status_applied", "GIANT_STRENGTH", {"duration": giant_strength_turns, "bonus": giant_strength_applied})

func get_strength_bonus() -> int:
	return giant_strength_applied if giant_strength_turns > 0 else 0

func _revert_giant_strength() -> void:
	if giant_strength_applied > 0:
		var stats = _get_stats()
		if stats and stats.attributes:
			stats.attributes.strength = maxi(1, stats.attributes.strength - giant_strength_applied)
		giant_strength_applied = 0

# --- Weakness ---
func apply_weakness(duration_turns: int = 15, penalty_str: int = 5) -> void:
	weakness_turns = duration_turns
	if weakness_penalty_applied == 0:
		weakness_penalty_applied = penalty_str
		var stats = _get_stats()
		if stats and stats.attributes:
			stats.attributes.strength = maxi(1, stats.attributes.strength - penalty_str)
	emit_signal("status_applied", "WEAKNESS", {"duration": weakness_turns, "penalty": weakness_penalty_applied})

func _revert_weakness() -> void:
	if weakness_penalty_applied > 0:
		var stats = _get_stats()
		if stats and stats.attributes:
			stats.attributes.strength += weakness_penalty_applied
		weakness_penalty_applied = 0

# --- Invisibility ---
func apply_invisibility(duration_turns: int = 10) -> void:
	invisibility_turns = maxi(invisibility_turns, duration_turns)
	emit_signal("status_applied", "INVISIBILITY", {"duration": invisibility_turns})

func is_invisible() -> bool:
	return invisibility_turns > 0

# --- Arcane Ward ---
func apply_arcane_ward(shield_amount: int) -> void:
	arcane_ward_hp = maxi(arcane_ward_hp, shield_amount)
	emit_signal("status_applied", "ARCANE_WARD", {"shield": arcane_ward_hp})

func absorb_damage(incoming_damage: int) -> int:
	if arcane_ward_hp <= 0:
		return incoming_damage
	var absorbed = mini(incoming_damage, arcane_ward_hp)
	arcane_ward_hp -= absorbed
	if arcane_ward_hp <= 0:
		emit_signal("status_expired", "ARCANE_WARD")
	return incoming_damage - absorbed

# --- Universal Cleansing ---
func cure_all_negative() -> void:
	cure_poison()
	cure_bleed()
	if stun_turns > 0:
		stun_turns = 0
		emit_signal("status_expired", "STUN")
	if blindness_turns > 0:
		blindness_turns = 0
		emit_signal("status_expired", "BLINDNESS")
	if weakness_turns > 0:
		weakness_turns = 0
		_revert_weakness()
		emit_signal("status_expired", "WEAKNESS")

# --- Turn Tick Processing ---
func tick_turn() -> Dictionary:
	var tick_summary = {
		"bleed_damage": 0,
		"poison_damage": 0,
		"total_damage": 0,
		"expired": []
	}

	# 1. Bleed Stacks (Additive & Independent)
	var total_bleed_dmg: int = 0
	var remaining_stacks: Array[Dictionary] = []
	for stack in bleed_stacks:
		var d = int(stack.get("damage_per_turn", 0))
		total_bleed_dmg += d
		var rem = int(stack.get("turns_remaining", 0)) - 1
		if rem > 0:
			stack["turns_remaining"] = rem
			remaining_stacks.append(stack)
	bleed_stacks = remaining_stacks
	if total_bleed_dmg > 0:
		tick_summary["bleed_damage"] = total_bleed_dmg
		_deal_tick_damage(total_bleed_dmg, "Bleed")
		emit_signal("status_ticked", "BLEED", total_bleed_dmg, get_max_bleed_turns_remaining())
	elif bleed_stacks.is_empty() and total_bleed_dmg == 0:
		pass

	# 2. Poison (Tier-Based)
	if is_poisoned():
		var p_dmg = get_poison_damage_per_turn()
		tick_summary["poison_damage"] = p_dmg
		_deal_tick_damage(p_dmg, "Poison")
		poison_turns_remaining -= 1
		emit_signal("status_ticked", "POISON", p_dmg, poison_turns_remaining)
		if poison_turns_remaining <= 0:
			poison_tier = PoisonTier.NONE
			tick_summary["expired"].append("POISON")
			emit_signal("status_expired", "POISON")

	tick_summary["total_damage"] = tick_summary["bleed_damage"] + tick_summary["poison_damage"]

	# 3. Timed Debuffs / Buffs
	if stun_turns > 0:
		stun_turns -= 1
		if stun_turns <= 0:
			tick_summary["expired"].append("STUN")
			emit_signal("status_expired", "STUN")

	if blindness_turns > 0:
		blindness_turns -= 1
		if blindness_turns <= 0:
			tick_summary["expired"].append("BLINDNESS")
			emit_signal("status_expired", "BLINDNESS")

	if haste_turns > 0:
		haste_turns -= 1
		if haste_turns <= 0:
			tick_summary["expired"].append("HASTE")
			emit_signal("status_expired", "HASTE")

	if giant_strength_turns > 0:
		giant_strength_turns -= 1
		if giant_strength_turns <= 0:
			_revert_giant_strength()
			tick_summary["expired"].append("GIANT_STRENGTH")
			emit_signal("status_expired", "GIANT_STRENGTH")

	if weakness_turns > 0:
		weakness_turns -= 1
		if weakness_turns <= 0:
			_revert_weakness()
			tick_summary["expired"].append("WEAKNESS")
			emit_signal("status_expired", "WEAKNESS")

	if invisibility_turns > 0:
		invisibility_turns -= 1
		if invisibility_turns <= 0:
			tick_summary["expired"].append("INVISIBILITY")
			emit_signal("status_expired", "INVISIBILITY")

	return tick_summary

func _deal_tick_damage(amount: int, _source_name: String) -> void:
	var stats = _get_stats()
	if stats:
		stats.take_damage(amount)

# --- HUD Formatting ---
## Returns compact status badges formatted as requested:
## e.g., "[Bleed x2 (8/t): 3t]", "[Poison II (7/t): 5t]", "[Ward: 25]", "[Haste: 4t]", "[Blind: 2t]"
func get_hud_badges() -> Array[String]:
	var badges: Array[String] = []

	if is_bleeding():
		var stack_count = bleed_stacks.size()
		var dmg_rate = get_total_bleed_damage_per_turn()
		var max_t = get_max_bleed_turns_remaining()
		badges.append("[Bleed x%d (%d/t): %dt]" % [stack_count, dmg_rate, max_t])

	if is_poisoned():
		var tier_str = get_poison_tier_string()
		var dmg_rate = get_poison_damage_per_turn()
		badges.append("[Poison %s (%d/t): %dt]" % [tier_str, dmg_rate, poison_turns_remaining])

	if arcane_ward_hp > 0:
		badges.append("[Ward: %d]" % arcane_ward_hp)

	if is_hasted():
		badges.append("[Haste: %dt]" % haste_turns)

	if is_blinded():
		badges.append("[Blind: %dt]" % blindness_turns)

	if giant_strength_turns > 0:
		badges.append("[STR+: %dt]" % giant_strength_turns)

	if is_stunned():
		badges.append("[Stun: %dt]" % stun_turns)

	return badges

func get_hud_badge_string() -> String:
	var badges = get_hud_badges()
	return " ".join(badges)
