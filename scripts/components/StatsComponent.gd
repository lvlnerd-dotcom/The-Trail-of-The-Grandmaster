class_name StatsComponent
extends Node

## StatsComponent: Manages dynamic vitals (HP, Mana), damage resolution, and turn regeneration.

signal health_changed(current: float, maximum: float)
signal mana_changed(current: float, maximum: float)
signal entity_died(entity: Node2D)

@export var attributes: AttributesData:
    set(value):
        if attributes and attributes.attribute_changed.is_connected(_on_attribute_changed):
            attributes.attribute_changed.disconnect(_on_attribute_changed)
        attributes = value
        if attributes:
            if not attributes.attribute_changed.is_connected(_on_attribute_changed):
                attributes.attribute_changed.connect(_on_attribute_changed)
            _recalculate_max_vitals(true)

var current_hp: float = 100.0
var current_mana: float = 50.0
@export var max_hp_override: float = -1.0

func get_max_health() -> float:
    if max_hp_override > 0.0:
        return max_hp_override
    return attributes.get_max_health() if attributes else 100.0

# Base turn regeneration constants
const BASE_HP_REGEN_PER_TURN: float = 0.5
const BASE_MANA_REGEN_PER_TURN: float = 0.5

func _init() -> void:
    if not attributes:
        attributes = AttributesData.new()

func _get_event_bus() -> Node:
    var loop = Engine.get_main_loop()
    if loop and loop is SceneTree:
        return (loop as SceneTree).root.get_node_or_null("EventBus")
    return null

func _ready() -> void:
    if not attributes:
        attributes = AttributesData.new()
    elif not attributes.attribute_changed.is_connected(_on_attribute_changed):
        attributes.attribute_changed.connect(_on_attribute_changed)
    _recalculate_max_vitals(true)

func _recalculate_max_vitals(reset_to_full: bool = false) -> void:
    if not attributes and max_hp_override <= 0.0:
        return
    var max_hp = get_max_health()
    var max_mana = attributes.get_max_mana() if attributes else 50.0
    
    if reset_to_full:
        current_hp = max_hp
        current_mana = max_mana
    else:
        current_hp = minf(current_hp, max_hp)
        current_mana = minf(current_mana, max_mana)
        
    emit_signal("health_changed", current_hp, max_hp)
    emit_signal("mana_changed", current_mana, max_mana)

func _on_attribute_changed(attr_name: String, _new_val: int) -> void:
    if attr_name == "constitution":
        _recalculate_max_vitals(false)
    elif attr_name == "intelligence":
        _recalculate_max_vitals(false)

func take_damage(amount: int, attacker: Node2D = null) -> int:
    var parent_entity = get_parent() as Node2D
    var actual_damage = max(1, amount)
    if parent_entity:
        var scc = parent_entity.get_node_or_null("SpellCastingComponent")
        if scc and scc.has_method("absorb_damage"):
            actual_damage = scc.absorb_damage(actual_damage)
        var sec = parent_entity.get_node_or_null("StatusEffectComponent")
        if sec and sec.has_method("absorb_damage"):
            actual_damage = sec.absorb_damage(actual_damage)
    
    if actual_damage > 0:
        current_hp = maxf(0.0, current_hp - actual_damage)
    var max_hp = get_max_health()
    emit_signal("health_changed", current_hp, max_hp)
    
    var bus = _get_event_bus()
    if bus:
        bus.emit_signal("entity_damaged", parent_entity, attacker, actual_damage)
    
    if current_hp <= 0.0:
        emit_signal("entity_died", parent_entity)
        if bus:
            bus.emit_signal("entity_died", parent_entity)
            
    return actual_damage

func heal(amount: float) -> float:
    var max_hp = get_max_health()
    var healed = minf(amount, max_hp - current_hp)
    current_hp += healed
    emit_signal("health_changed", current_hp, max_hp)
    return healed

func spend_mana(amount: float) -> bool:
    if not attributes or current_mana < amount:
        return false
    current_mana -= amount
    emit_signal("mana_changed", current_mana, attributes.get_max_mana())
    return true

func restore_mana(amount: float) -> float:
    if not attributes:
        return 0.0
    var max_mana = attributes.get_max_mana()
    var restored = minf(amount, max_mana - current_mana)
    current_mana += restored
    emit_signal("mana_changed", current_mana, max_mana)
    return restored

func tick_turn_regeneration() -> void:
    if not attributes:
        return
    if current_hp > 0.0:
        var hp_regen = BASE_HP_REGEN_PER_TURN * attributes.get_health_regen_modifier()
        heal(hp_regen)
        
        var mana_regen = BASE_MANA_REGEN_PER_TURN * attributes.get_mana_regen_modifier()
        restore_mana(mana_regen)
        
    var parent_entity = get_parent() as Node2D
    if parent_entity:
        var scc = parent_entity.get_node_or_null("SpellCastingComponent")
        if scc and scc.has_method("tick_ward_turns"):
            scc.tick_ward_turns()

