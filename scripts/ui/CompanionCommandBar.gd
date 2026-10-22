class_name CompanionCommandBar
extends PanelContainer

## CompanionCommandBar: Tactical Command Window anchored directly above InspectorPanel.
## Provides quick command toggles: [All Follow], [All Attack], [All Defend], and displays squad capacity.

signal order_selected(order: Companion.TacticalOrder)
signal attack_target_requested()

var turn_manager: TurnManager = null
var player: Node2D = null
var targeting_system: TargetingSystem = null

var current_order: Companion.TacticalOrder = Companion.TacticalOrder.ALL_DEFEND

@onready var label_squad: Label = $Margin/HBox/LabelSquad
@onready var btn_follow: Button = $Margin/HBox/BtnFollow
@onready var btn_defend: Button = $Margin/HBox/BtnDefend
@onready var btn_attack: Button = $Margin/HBox/BtnAttack

func _get_event_bus() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("EventBus")
	return null

func _ready() -> void:
	if btn_follow:
		btn_follow.pressed.connect(func(): set_order(Companion.TacticalOrder.ALL_FOLLOW))
	if btn_defend:
		btn_defend.pressed.connect(func(): set_order(Companion.TacticalOrder.ALL_DEFEND))
	if btn_attack:
		btn_attack.pressed.connect(func(): _on_attack_button_pressed())
		
	var bus = _get_event_bus()
	if bus:
		if bus.has_signal("companion_registered"):
			bus.companion_registered.connect(func(_c): refresh())
		if bus.has_signal("companion_unregistered"):
			bus.companion_unregistered.connect(func(_c): refresh())
		if bus.has_signal("companion_died"):
			bus.companion_died.connect(func(_c): refresh())
		if bus.has_signal("companion_downed"):
			bus.companion_downed.connect(func(_c): refresh())
		if bus.has_signal("companion_order_changed"):
			bus.companion_order_changed.connect(_on_bus_order_changed)

func setup(p_turn_manager: TurnManager, p_player: Node2D, p_targeting_system: TargetingSystem = null) -> void:
	turn_manager = p_turn_manager
	player = p_player
	targeting_system = p_targeting_system
	refresh()

func _on_bus_order_changed(new_order: int) -> void:
	current_order = new_order as Companion.TacticalOrder
	_update_buttons()

func cycle_order() -> Companion.TacticalOrder:
	var next_order: Companion.TacticalOrder
	match current_order:
		Companion.TacticalOrder.ALL_FOLLOW:
			next_order = Companion.TacticalOrder.ALL_DEFEND
		Companion.TacticalOrder.ALL_DEFEND:
			next_order = Companion.TacticalOrder.ALL_ATTACK
		Companion.TacticalOrder.ALL_ATTACK:
			next_order = Companion.TacticalOrder.ALL_FOLLOW
		_:
			next_order = Companion.TacticalOrder.ALL_DEFEND
			
	if next_order == Companion.TacticalOrder.ALL_ATTACK:
		_on_attack_button_pressed()
	else:
		set_order(next_order)
	return next_order

func _on_attack_button_pressed() -> void:
	set_order(Companion.TacticalOrder.ALL_ATTACK)
	emit_signal("attack_target_requested")
	if targeting_system:
		targeting_system.start_targeting({
			"mode": TargetingSystem.ActionMode.COMPANION_ATTACK_TARGET,
			"label": "Squad Focus Target",
			"max_range": 8,
			"area_radius": 0,
			"is_beam": false,
			"is_teleport": false,
			"allow_self": false
		})

func set_order(order: Companion.TacticalOrder) -> void:
	current_order = order
	if turn_manager:
		for comp in turn_manager.registered_companions:
			if is_instance_valid(comp) and comp is Companion:
				comp.current_order = current_order
				
	_update_buttons()
	emit_signal("order_selected", current_order)
	var bus = _get_event_bus()
	if bus and bus.has_signal("companion_order_changed"):
		bus.emit_signal("companion_order_changed", int(current_order))

func refresh() -> void:
	var active_count = 0
	if turn_manager:
		active_count = turn_manager.registered_companions.size()
		
	var max_comp = 1
	if player:
		var p_stats = player.get_node_or_null("StatsComponent") as StatsComponent
		if p_stats and p_stats.attributes and p_stats.attributes.has_method("get_max_companions"):
			max_comp = p_stats.attributes.get_max_companions()
			
	visible = (active_count > 0)
	
	if label_squad:
		label_squad.text = "Squad %d/%d [V]" % [active_count, max_comp]
		
	_update_buttons()

func _update_buttons() -> void:
	if not btn_follow or not btn_defend or not btn_attack:
		return
		
	btn_follow.text = "[Follow]" if current_order == Companion.TacticalOrder.ALL_FOLLOW else "Follow"
	btn_defend.text = "[Defend]" if current_order == Companion.TacticalOrder.ALL_DEFEND else "Defend"
	btn_attack.text = "[Attack]" if current_order == Companion.TacticalOrder.ALL_ATTACK else "Attack"
	
	btn_follow.modulate = Color(0.4, 0.9, 1.0) if current_order == Companion.TacticalOrder.ALL_FOLLOW else Color(0.8, 0.8, 0.8)
	btn_defend.modulate = Color(0.4, 1.0, 0.4) if current_order == Companion.TacticalOrder.ALL_DEFEND else Color(0.8, 0.8, 0.8)
	btn_attack.modulate = Color(1.0, 0.35, 0.35) if current_order == Companion.TacticalOrder.ALL_ATTACK else Color(0.8, 0.8, 0.8)
