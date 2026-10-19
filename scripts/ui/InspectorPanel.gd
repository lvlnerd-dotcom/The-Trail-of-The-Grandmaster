@tool
class_name InspectorPanel
extends PanelContainer

## InspectorPanel: HUD element positioned directly to the right of HotbarBar.
## Displays real-time tactical data for hovered tiles, creatures, hazards, and objects.
## Uses full horizontal width (no icon badge), multi-line smart word wrapping,
## and an automatic vertical scroll ticker when descriptions exceed visible lines.

@onready var label_title: Label = get_node_or_null("Margin/VBoxInfo/HBoxHeader/LabelTitle") as Label
@onready var label_coords: Label = get_node_or_null("Margin/VBoxInfo/HBoxHeader/LabelCoords") as Label
@onready var label_category: Label = get_node_or_null("Margin/VBoxInfo/HBoxStatus/LabelCategory") as Label
@onready var label_health_status: Label = get_node_or_null("Margin/VBoxInfo/HBoxStatus/LabelHealthStatus") as Label
@onready var description_scroll: ScrollContainer = get_node_or_null("Margin/VBoxInfo/DescriptionScroll") as ScrollContainer
@onready var label_desc: Label = get_node_or_null("Margin/VBoxInfo/DescriptionScroll/LabelDescription") as Label

var target_hotbar: Control = null
var _scroll_tween: Tween = null

const SCROLL_PAUSE_SECONDS: float = 1.2
const SCROLL_PIXELS_PER_SECOND: float = 18.0
const SCROLL_RESET_SECONDS: float = 0.35

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_opaque_style()
	_connect_event_bus()

func _apply_opaque_style() -> void:
	var flat = StyleBoxFlat.new()
	flat.bg_color = Color(0.06, 0.07, 0.09, 0.95)
	flat.border_width_left = 2
	flat.border_width_top = 2
	flat.border_width_right = 2
	flat.border_width_bottom = 2
	flat.border_color = Color(0.24, 0.28, 0.36, 1.0)
	flat.corner_radius_top_left = 6
	flat.corner_radius_top_right = 6
	flat.corner_radius_bottom_right = 6
	flat.corner_radius_bottom_left = 6
	flat.content_margin_left = 5.0
	flat.content_margin_top = 4.0
	flat.content_margin_right = 5.0
	flat.content_margin_bottom = 4.0
	flat.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	flat.shadow_size = 6
	add_theme_stylebox_override("panel", flat)

func _get_event_bus() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("EventBus")
	return null

func _connect_event_bus() -> void:
	var bus = _get_event_bus()
	if bus:
		if bus.has_signal("tile_hovered"):
			bus.tile_hovered.connect(_on_tile_hovered)
		if bus.has_signal("tile_hover_cleared"):
			bus.tile_hover_cleared.connect(_on_tile_hover_cleared)

## Synchronizes layout, height, and horizontal placement directly to the right of HotbarBar
func sync_with_hotbar(hotbar: Control, separation: float = 12.0) -> void:
	target_hotbar = hotbar
	if not hotbar:
		return
	set_meta("separation_margin", separation)
	if not hotbar.resized.is_connected(_on_hotbar_resized):
		hotbar.resized.connect(_on_hotbar_resized)
	_apply_sync()
	call_deferred("_apply_sync")

func _on_hotbar_resized() -> void:
	_apply_sync()

func _apply_sync() -> void:
	if not target_hotbar:
		return
	# Enforce strictly identical height
	custom_minimum_size.y = target_hotbar.size.y
	size.y = target_hotbar.size.y
	
	# Match vertical alignment
	offset_bottom = target_hotbar.offset_bottom
	offset_top = target_hotbar.offset_top
	
	# Position directly to the right with a clean, uniform separation margin
	var sep: float = get_meta("separation_margin", 12.0)
	var hotbar_actual_width = target_hotbar.size.x
	var hotbar_right_edge = target_hotbar.offset_right
	if target_hotbar.size.x > 0:
		var current_span = target_hotbar.offset_right - target_hotbar.offset_left
		if hotbar_actual_width > current_span:
			hotbar_right_edge = target_hotbar.offset_left + hotbar_actual_width
	offset_left = hotbar_right_edge + sep
	offset_right = offset_left + 240.0

func _on_tile_hovered(_cell: Vector2i, data: Resource) -> void:
	if data is InspectionData:
		update_inspection(data as InspectionData)

func _on_tile_hover_cleared() -> void:
	var standby = InspectionData.new()
	standby.title = "Unexplored Darkness"
	standby.category = InspectionData.Category.UNKNOWN
	standby.category_text = "Fog of War"
	standby.description = "Move cursor over a tile to inspect."
	standby.icon_glyph = "?"
	standby.accent_color = Color(0.55, 0.60, 0.68, 1.0)
	update_inspection(standby)

func update_inspection(data: InspectionData) -> void:
	if not label_title:
		_resolve_references()
		
	if not data:
		_on_tile_hover_cleared()
		return
		
	label_title.text = data.title
	label_title.add_theme_color_override("font_color", data.accent_color)
	
	if data.grid_cell != Vector2i(-1, -1):
		label_coords.text = "[%d, %d]" % [data.grid_cell.x, data.grid_cell.y]
	else:
		label_coords.text = "[--,--]"
		
	label_category.text = data.category_text
	
	if data.health_status_text != "":
		label_health_status.text = "[%s]" % data.health_status_text
		label_health_status.add_theme_color_override("font_color", data.health_status_color)
		label_health_status.visible = true
	else:
		label_health_status.visible = false
		
	label_desc.text = data.description
	_reset_description_scroll()
	if is_inside_tree():
		call_deferred("_evaluate_and_start_scroll")

func _reset_description_scroll() -> void:
	if _scroll_tween and _scroll_tween.is_valid():
		_scroll_tween.kill()
	_scroll_tween = null
	if description_scroll:
		description_scroll.scroll_vertical = 0

## Computes the vertical pixel overflow of LabelDescription inside DescriptionScroll.
func get_overflow_scroll_range() -> float:
	if not label_desc or not description_scroll:
		return 0.0
	var content_height: float = maxf(label_desc.size.y, label_desc.get_combined_minimum_size().y)
	var viewport_height: float = description_scroll.size.y if description_scroll.size.y > 0.0 else 32.0
	return maxf(0.0, content_height - viewport_height)

func _evaluate_and_start_scroll() -> void:
	if not is_inside_tree() or not description_scroll or not label_desc:
		return
	var max_scroll: float = get_overflow_scroll_range()
	if max_scroll <= 2.0:
		return
	var target_scroll: int = int(ceil(max_scroll))
	var travel_duration: float = maxf(1.2, max_scroll / SCROLL_PIXELS_PER_SECOND)
	
	_scroll_tween = create_tween().set_loops()
	_scroll_tween.tween_interval(SCROLL_PAUSE_SECONDS)
	_scroll_tween.tween_property(description_scroll, "scroll_vertical", target_scroll, travel_duration)
	_scroll_tween.tween_interval(SCROLL_PAUSE_SECONDS)
	_scroll_tween.tween_property(description_scroll, "scroll_vertical", 0, SCROLL_RESET_SECONDS)

func _resolve_references() -> void:
	label_title = get_node_or_null("Margin/VBoxInfo/HBoxHeader/LabelTitle") as Label
	label_coords = get_node_or_null("Margin/VBoxInfo/HBoxHeader/LabelCoords") as Label
	label_category = get_node_or_null("Margin/VBoxInfo/HBoxStatus/LabelCategory") as Label
	label_health_status = get_node_or_null("Margin/VBoxInfo/HBoxStatus/LabelHealthStatus") as Label
	description_scroll = get_node_or_null("Margin/VBoxInfo/DescriptionScroll") as ScrollContainer
	label_desc = get_node_or_null("Margin/VBoxInfo/DescriptionScroll/LabelDescription") as Label

	# Programmatic fallback when instantiated in code without loading packed scene
	if not label_title:
		_build_programmatic_hierarchy()

func _build_programmatic_hierarchy() -> void:
	var margin = MarginContainer.new()
	margin.name = "Margin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 3)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 3)
	margin.add_theme_constant_override("margin_bottom", 2)
	add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxInfo"
	vbox.clip_contents = true
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 1)
	margin.add_child(vbox)
	
	var header = HBoxContainer.new()
	header.name = "HBoxHeader"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 4)
	vbox.add_child(header)
	
	label_title = Label.new()
	label_title.name = "LabelTitle"
	label_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label_title.add_theme_font_size_override("font_size", 12)
	header.add_child(label_title)
	
	label_coords = Label.new()
	label_coords.name = "LabelCoords"
	label_coords.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_coords.add_theme_font_size_override("font_size", 10)
	header.add_child(label_coords)
	
	var status_box = HBoxContainer.new()
	status_box.name = "HBoxStatus"
	status_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_box.add_theme_constant_override("separation", 4)
	vbox.add_child(status_box)
	
	label_category = Label.new()
	label_category.name = "LabelCategory"
	label_category.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_category.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_category.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label_category.add_theme_font_size_override("font_size", 10)
	status_box.add_child(label_category)
	
	label_health_status = Label.new()
	label_health_status.name = "LabelHealthStatus"
	label_health_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_health_status.visible = false
	label_health_status.add_theme_font_size_override("font_size", 10)
	status_box.add_child(label_health_status)
	
	description_scroll = ScrollContainer.new()
	description_scroll.name = "DescriptionScroll"
	description_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	description_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	vbox.add_child(description_scroll)
	
	label_desc = Label.new()
	label_desc.name = "LabelDescription"
	label_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_desc.add_theme_font_size_override("font_size", 10)
	description_scroll.add_child(label_desc)
