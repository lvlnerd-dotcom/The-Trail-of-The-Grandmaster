class_name DecalsLayer
extends Node2D

## DecalsLayer: Persistent visual surface for combat blood splatters, scorch marks, and holy glyphs.

const MAX_DECALS: int = 250
const TILE_SIZE: float = 32.0

var decals: Array[Dictionary] = []

func _ready() -> void:
	z_index = 1 # Above floor tiles, below entities
	var bus = _get_event_bus()
	if bus and bus.has_signal("decal_requested"):
		bus.connect("decal_requested", _on_decal_requested)

func _exit_tree() -> void:
	var bus = _get_event_bus()
	if bus and bus.has_signal("decal_requested") and bus.is_connected("decal_requested", _on_decal_requested):
		bus.disconnect("decal_requested", _on_decal_requested)

func _get_event_bus() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("EventBus")
	return null

func _on_decal_requested(decal_type: String, cell: Vector2i) -> void:
	add_decal(decal_type, cell)

func add_decal(decal_type: String, cell: Vector2i) -> void:
	var base_world_pos = Vector2(cell.x * TILE_SIZE + TILE_SIZE * 0.5, cell.y * TILE_SIZE + TILE_SIZE * 0.5)
	
	var decal_data = {
		"type": decal_type.to_lower(),
		"cell": cell,
		"pos": base_world_pos,
		"seed": randi()
	}
	
	# Generate procedural splash dots for organic feel
	var sub_points: Array[Vector2] = []
	var dot_count = randi_range(3, 6)
	for i in range(dot_count):
		var offset = Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
		sub_points.append(offset)
	decal_data["dots"] = sub_points
	
	decals.append(decal_data)
	if decals.size() > MAX_DECALS:
		decals.pop_front()
		
	queue_redraw()

func clear_decals() -> void:
	decals.clear()
	queue_redraw()

func _draw() -> void:
	for d in decals:
		var pos = d["pos"] as Vector2
		var dtype = str(d["type"])
		var dots = d.get("dots", []) as Array
		
		if dtype.begins_with("scorch") or dtype == "fire":
			# Charcoal blast crater with burnt amber core
			draw_circle(pos, 13.0, Color(0.12, 0.1, 0.08, 0.65))
			draw_circle(pos, 8.0, Color(0.2, 0.12, 0.05, 0.75))
			draw_circle(pos, 3.5, Color(0.65, 0.25, 0.05, 0.5))
			for dot in dots:
				draw_circle(pos + dot, 2.0, Color(0.08, 0.08, 0.08, 0.6))
		elif dtype.begins_with("holy") or dtype == "radiant":
			# Golden divine seal
			draw_circle(pos, 11.0, Color(1.0, 0.9, 0.3, 0.2))
			draw_arc(pos, 10.0, 0.0, TAU, 16, Color(1.0, 0.85, 0.2, 0.7), 1.5)
			draw_line(pos + Vector2(-8, 0), pos + Vector2(8, 0), Color(1.0, 0.95, 0.5, 0.75), 1.5)
			draw_line(pos + Vector2(0, -8), pos + Vector2(0, 8), Color(1.0, 0.95, 0.5, 0.75), 1.5)
		else:
			# Blood splatter (crimson core with scattered droplets)
			draw_circle(pos, 7.0, Color(0.55, 0.06, 0.06, 0.7))
			draw_circle(pos + Vector2(2, -1), 4.5, Color(0.45, 0.03, 0.03, 0.75))
			for dot in dots:
				var dot_rad = randf_range(1.5, 3.0)
				draw_circle(pos + dot, dot_rad, Color(0.5, 0.05, 0.05, 0.65))
