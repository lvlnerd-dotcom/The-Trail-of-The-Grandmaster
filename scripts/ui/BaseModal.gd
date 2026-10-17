@tool
class_name BaseModal
extends PanelContainer

## BaseModal: Base class for all popup menus ensuring 100% opaque styling,
## mouse input blocking, backdrop scrim, and ESC dismiss handling.

signal modal_opened()
signal modal_closed()

@export var close_on_escape: bool = true
@export var enable_backdrop: bool = true
@export var backdrop_color: Color = Color(0.02, 0.02, 0.04, 0.85)

var backdrop_rect: ColorRect = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_opaque_style()
	if enable_backdrop:
		_setup_backdrop()
	# Default to hidden
	visible = false

func _apply_opaque_style() -> void:
	apply_opaque_styling(self)

static func apply_opaque_styling(node: Control) -> void:
	if not node:
		return
	var existing = node.get_theme_stylebox("panel")
	if not existing or (existing is StyleBoxFlat and existing.bg_color.a < 0.99):
		var flat = StyleBoxFlat.new()
		flat.bg_color = Color(0.08, 0.09, 0.12, 1.0)
		flat.border_width_left = 2
		flat.border_width_top = 2
		flat.border_width_right = 2
		flat.border_width_bottom = 2
		flat.border_color = Color(0.24, 0.28, 0.36, 1.0)
		flat.corner_radius_top_left = 6
		flat.corner_radius_top_right = 6
		flat.corner_radius_bottom_right = 6
		flat.corner_radius_bottom_left = 6
		flat.content_margin_left = 16.0
		flat.content_margin_top = 16.0
		flat.content_margin_right = 16.0
		flat.content_margin_bottom = 16.0
		flat.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
		flat.shadow_size = 8
		node.add_theme_stylebox_override("panel", flat)

func _setup_backdrop() -> void:
	if backdrop_rect and is_instance_valid(backdrop_rect):
		return
	
	backdrop_rect = ColorRect.new()
	backdrop_rect.name = "BackdropScrim"
	backdrop_rect.color = backdrop_color
	backdrop_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop_rect.visible = false
	
	# Add backdrop as sibling right behind this modal if possible, or as child
	var p = get_parent()
	if p:
		p.call_deferred("add_child", backdrop_rect)
		p.call_deferred("move_child", backdrop_rect, max(0, get_index()))

func _get_event_bus() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("EventBus")
	return null

func open_modal() -> void:
	if backdrop_rect and is_instance_valid(backdrop_rect):
		backdrop_rect.show()
	show()
	move_to_front()
	emit_signal("modal_opened")
	var bus = _get_event_bus()
	if bus and bus.has_signal("modal_opened"):
		bus.emit_signal("modal_opened", self)

func close_modal() -> void:
	hide()
	if backdrop_rect and is_instance_valid(backdrop_rect):
		backdrop_rect.hide()
	emit_signal("modal_closed")
	var bus = _get_event_bus()
	if bus and bus.has_signal("modal_closed"):
		bus.emit_signal("modal_closed", self)

func is_modal_open() -> bool:
	return visible

func _unhandled_input(event: InputEvent) -> void:
	if visible and close_on_escape and event.is_action_pressed("ui_cancel"):
		close_modal()
		get_viewport().set_input_as_handled()
