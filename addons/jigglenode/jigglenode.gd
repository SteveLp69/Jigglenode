@tool
extends Node3D

@export var enabled: bool = true:
	set(value):
		enabled = value
		_ready()

@export_category("Base settings")
@export var stiffness: float = 5.0
@export var damping: float = 0.8
@export var target_node: Node3D:
	set(node):
		target_node = node
		_ready()
@export var use_gravity: bool = false
@export var gravity := Vector3(0, -9.81, 0)

@export_category("Offsets / Limits")
@export var rotation_offset: Vector3 = Vector3.ZERO
@export_range(0, 360, 0.1, "or_greater") var max_rotation_dif: float = 45
@export var lock_x_rot: bool = false
@export var lock_y_rot: bool = false
@export var lock_z_rot: bool = false

@export_category("Mapping's")
@export_enum("X", "Y", "Z") var x_rotation_mappnig: int = 0
@export_enum("X", "Y", "Z") var y_rotation_mappnig: int = 1
@export_enum("X", "Y", "Z") var z_rotation_mappnig: int = 2

@export_category("Extras")
## Actevates the position sensetivaty during runtime
@export var force_position_sensetivaty: bool

var _velocity: Vector3 = Vector3.ZERO
var _last_position: Vector3

var base_rotation: Vector3

var position_target: Node3D

var prev_parent_pos: Vector3 = get_parent().global_position

func _ready():
	base_rotation = target_node.rotation_degrees
	
	var target: Node3D = Node3D.new()
	target_node.get_parent().add_child(target)
	target.position = get_target_position(target_node.rotation_degrees).normalized()
	position_target = target
	
	set_physics_process(true)
	set_process(true)

func get_target_position(rotation_deg: Vector3):
	var rotation_rad = rotation_deg * (PI / 180.0)
	
	var desired_basis = Basis()
	desired_basis = desired_basis.rotated(Vector3(1,0,0), rotation_rad.x)
	desired_basis = desired_basis.rotated(Vector3(0,1,0), rotation_rad.y)
	desired_basis = desired_basis.rotated(Vector3(0,0,1), rotation_rad.z)
	
	var forward_dir = -desired_basis.z
	
	return forward_dir

func mapping(map_id: int, value: float) -> Vector3:
	match map_id:
		0: # X
			return Vector3(value, 0, 0)
		1: # Y
			return Vector3(0, value, 0)
		2: # Z
			return Vector3(0, 0, value)
		_:
			return Vector3.ZERO

func limit_rotation():
	var _rotation = target_node.rotation_degrees - base_rotation
	
	var mapping_rotation = Vector3.ZERO
	mapping_rotation += mapping(x_rotation_mappnig, _rotation.x)
	mapping_rotation += mapping(y_rotation_mappnig, _rotation.y)
	mapping_rotation += mapping(z_rotation_mappnig, _rotation.z)
	_rotation = mapping_rotation
	
	target_node.rotation_degrees.x = clamp(_rotation.x, -max_rotation_dif, max_rotation_dif) + base_rotation.x
	target_node.rotation_degrees.y = clamp(_rotation.y, -max_rotation_dif, max_rotation_dif) + base_rotation.y
	target_node.rotation_degrees.z = clamp(_rotation.z, -max_rotation_dif, max_rotation_dif) + base_rotation.z
	
	if lock_x_rot: target_node.rotation_degrees.x = base_rotation.x
	if lock_y_rot: target_node.rotation_degrees.y = base_rotation.y
	if lock_z_rot: target_node.rotation_degrees.z = base_rotation.z

func _physics_process(delta: float) -> void:
	if enabled:
		if Engine.is_editor_hint() or force_position_sensetivaty:
			_last_position = global_transform.origin
		
		if target_node == null:
			return
		
		var target = target_node
		if target == null:
			return
		
		var target_pos = position_target.global_transform.origin
		
		var force = (target_pos - _last_position) * stiffness
		if use_gravity:
			force += gravity
		
		_velocity = (_velocity + force * delta) * damping
		
		_last_position += _velocity
		global_transform.origin = _last_position
		
		target.look_at(global_transform.origin)
		limit_rotation()
		target.rotation_degrees += rotation_offset

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if rotation_degrees.abs() > Vector3.ZERO:
			rotation_offset = rotation_degrees
			rotation_degrees = Vector3.ZERO
	
	if prev_parent_pos != get_parent().global_position: # if parent position changed
		global_position += prev_parent_pos - get_parent().global_position
		prev_parent_pos = get_parent().global_position
