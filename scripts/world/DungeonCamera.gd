class_name DungeonCamera
extends Camera2D

## DungeonCamera: Implements trauma-based screen shake for combat impacts and floor collapse tremors.

@export var max_offset: Vector2 = Vector2(16.0, 16.0)
@export var max_roll: float = 0.05 # Radians
@export var trauma_decay: float = 1.2 # Trauma decay per second

var trauma: float = 0.0 # 0.0 to 1.0
var kick_impulse: Vector2 = Vector2.ZERO
@export var kick_decay: float = 8.0
var noise: FastNoiseLite = FastNoiseLite.new()
var noise_y: float = 0.0

func _ready() -> void:
	noise.seed = randi()
	noise.frequency = 0.08
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	
	var bus = _get_event_bus()
	if bus and bus.has_signal("camera_trauma_requested"):
		bus.connect("camera_trauma_requested", _on_camera_trauma_requested)

func _exit_tree() -> void:
	var bus = _get_event_bus()
	if bus and bus.has_signal("camera_trauma_requested") and bus.is_connected("camera_trauma_requested", _on_camera_trauma_requested):
		bus.disconnect("camera_trauma_requested", _on_camera_trauma_requested)

func _get_event_bus() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("EventBus")
	return null

func _on_camera_trauma_requested(amount: float, direction: Vector2 = Vector2.ZERO) -> void:
	apply_trauma(amount, direction)

func apply_trauma(amount: float, direction: Vector2 = Vector2.ZERO) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)
	if direction != Vector2.ZERO:
		kick_impulse += direction.normalized() * (amount * 24.0)

func add_trauma(amount: float) -> void:
	apply_trauma(amount, Vector2.ZERO)

func _process(delta: float) -> void:
	if kick_impulse.length_squared() > 0.01:
		kick_impulse = kick_impulse.lerp(Vector2.ZERO, kick_decay * delta)
	else:
		kick_impulse = Vector2.ZERO

	if trauma > 0.0:
		trauma = maxf(0.0, trauma - trauma_decay * delta)
		_shake()
	else:
		offset = kick_impulse
		rotation = 0.0

func _shake() -> void:
	var shake_amount = trauma * trauma # Non-linear shake curve
	noise_y += 1.0
	rotation = max_roll * shake_amount * noise.get_noise_2d(0, noise_y)
	offset.x = max_offset.x * shake_amount * noise.get_noise_2d(100, noise_y) + kick_impulse.x
	offset.y = max_offset.y * shake_amount * noise.get_noise_2d(200, noise_y) + kick_impulse.y
