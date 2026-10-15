class_name Bike
extends RigidBody3D
## Moto arcade: suspensão por raycast em cada roda, motor/freio/direção e torque de equilíbrio.
## A frente da moto é -Z (padrão do Godot).

@export var stats: BikeStats

## Velocidade para frente (m/s), negativa em ré. Atualizada a cada passo de física.
var forward_speed: float = 0.0
var front_grounded: bool = false
var rear_grounded: bool = false

var _steer: float = 0.0
var _ground_normal: Vector3 = Vector3.UP
var _spawn_transform: Transform3D

@onready var _front_ray: RayCast3D = $FrontWheelRay
@onready var _rear_ray: RayCast3D = $RearWheelRay
@onready var _visual: Node3D = $Visual
@onready var _front_wheel: Node3D = $Visual/FrontWheel
@onready var _rear_wheel: Node3D = $Visual/RearWheel


func _ready() -> void:
	if stats == null:
		stats = BikeStats.new()
	mass = stats.mass
	gravity_scale = stats.gravity_scale
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = stats.center_of_mass
	var ray_length := stats.suspension_rest_length + stats.wheel_radius
	_front_ray.target_position = Vector3(0.0, -ray_length, 0.0)
	_rear_ray.target_position = Vector3(0.0, -ray_length, 0.0)
	_spawn_transform = global_transform


func is_grounded() -> bool:
	return front_grounded or rear_grounded


func reset_to_spawn() -> void:
	global_transform = _spawn_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_steer = 0.0


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("resetar_moto"):
		reset_to_spawn()
		return

	front_grounded = _apply_suspension(_front_ray, _front_wheel)
	rear_grounded = _apply_suspension(_rear_ray, _rear_wheel)
	_ground_normal = _average_ground_normal()

	var throttle := Input.get_action_strength("acelerar")
	var brake := Input.get_action_strength("frear")
	var steer_input := Input.get_axis("esquerda", "direita")
	_steer = move_toward(_steer, steer_input, stats.steer_response * delta)

	var forward := _flat_on_ground(-global_basis.z)
	forward_speed = linear_velocity.dot(forward)

	if is_grounded():
		_drive(forward, throttle, brake, delta)
		_apply_grip(forward, delta)
	_steer_and_balance(forward, delta)
	_update_visuals(delta)


## Mola + amortecedor numa roda. Retorna true se a roda está tocando o chão.
func _apply_suspension(ray: RayCast3D, wheel: Node3D) -> bool:
	var ray_length := stats.suspension_rest_length + stats.wheel_radius
	# Sem isso o raio usaria a posição do passo anterior e mediria errado em alta velocidade.
	ray.force_raycast_update()
	if not ray.is_colliding():
		wheel.position.y = ray.position.y - stats.suspension_rest_length
		return false

	var origin := ray.global_position
	var distance := origin.distance_to(ray.get_collision_point())
	var compression := ray_length - distance
	var up := global_basis.y
	var com := global_transform * center_of_mass
	var point_velocity := linear_velocity + angular_velocity.cross(origin - com)

	var spring := compression * stats.spring_stiffness
	var damper := -point_velocity.dot(up) * stats.spring_damping
	var force := clampf(spring + damper, 0.0, stats.max_suspension_force)
	apply_force(up * force, origin - global_position)

	wheel.position.y = ray.position.y - (distance - stats.wheel_radius)
	return true


func _average_ground_normal() -> Vector3:
	var normal := Vector3.ZERO
	if front_grounded:
		normal += _front_ray.get_collision_normal()
	if rear_grounded:
		normal += _rear_ray.get_collision_normal()
	return normal.normalized() if normal != Vector3.ZERO else Vector3.UP


## Projeta uma direção no plano do chão (ou no plano horizontal, no ar).
func _flat_on_ground(direction: Vector3) -> Vector3:
	var flat := direction - _ground_normal * direction.dot(_ground_normal)
	return flat.normalized() if flat.length_squared() > 0.0001 else direction


## Motor, freio, ré e desaceleração natural, aplicados direto na velocidade (estilo arcade).
func _drive(forward: Vector3, throttle: float, brake: float, delta: float) -> void:
	var speed := forward_speed
	var new_speed := speed

	if throttle > 0.0 and rear_grounded:
		# Aceleração cheia até 75% da máxima, depois diminui até zero na máxima.
		var taper := clampf((stats.max_speed - speed) / (stats.max_speed * 0.25), 0.0, 1.0)
		new_speed += throttle * stats.acceleration * taper * delta

	if brake > 0.0:
		if speed > 0.5:
			new_speed = move_toward(new_speed, 0.0, brake * stats.brake_deceleration * delta)
		elif throttle == 0.0:
			var taper := clampf((stats.reverse_max_speed + speed) / (stats.reverse_max_speed * 0.25), 0.0, 1.0)
			new_speed -= brake * stats.reverse_acceleration * taper * delta

	if throttle == 0.0 and brake == 0.0:
		new_speed = move_toward(new_speed, 0.0, stats.coast_deceleration * delta)

	linear_velocity += forward * (new_speed - speed)


## Remove parte do deslizamento lateral (pneus agarrando no chão).
func _apply_grip(forward: Vector3, delta: float) -> void:
	var right := forward.cross(_ground_normal)
	var lateral := linear_velocity.dot(right)
	linear_velocity -= right * lateral * clampf(stats.grip * delta, 0.0, 1.0)


## Guinada pela direção e rolagem corrigida para a moto ficar em pé.
func _steer_and_balance(forward: Vector3, delta: float) -> void:
	var av := angular_velocity

	if is_grounded():
		var speed_ratio := absf(forward_speed) / stats.max_speed
		var steer_factor := clampf(absf(forward_speed) / stats.full_steer_speed, 0.0, 1.0)
		steer_factor *= lerpf(1.0, stats.high_speed_steer_factor, clampf(speed_ratio, 0.0, 1.0))
		var direction := -1.0 if forward_speed < -0.1 else 1.0
		# Direita = giro negativo em torno do "para cima".
		var target_yaw := -_steer * stats.steer_rate * steer_factor * direction
		var yaw := av.dot(_ground_normal)
		av += _ground_normal * (target_yaw - yaw) * clampf(stats.steer_response * delta, 0.0, 1.0)
	else:
		var up := global_basis.y
		av -= up * av.dot(up) * clampf(stats.air_yaw_damping * delta, 0.0, 1.0)

	# Equilíbrio: só no eixo de rolagem (o pitch fica livre para suspensão e saltos).
	var roll_axis := -global_basis.z
	var target_up := _ground_normal if is_grounded() else Vector3.UP
	var target_up_flat := target_up - roll_axis * target_up.dot(roll_axis)
	if target_up_flat.length_squared() > 0.0001:
		var roll_error := global_basis.y.signed_angle_to(target_up_flat.normalized(), roll_axis)
		av += roll_axis * (roll_error * stats.roll_stiffness - av.dot(roll_axis))

	angular_velocity = av


func _update_visuals(delta: float) -> void:
	var speed_ratio := clampf(absf(forward_speed) / stats.max_speed, 0.0, 1.0)
	var lean := -_steer * deg_to_rad(stats.visual_lean_degrees) * speed_ratio if is_grounded() else 0.0
	_visual.rotation.z = lerp_angle(_visual.rotation.z, lean, clampf(8.0 * delta, 0.0, 1.0))

	var spin := -forward_speed / stats.wheel_radius * delta
	_front_wheel.rotate_x(spin)
	_rear_wheel.rotate_x(spin)
