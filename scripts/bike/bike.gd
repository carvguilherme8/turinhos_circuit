class_name Bike
extends RigidBody3D
## Moto arcade: suspensão por raycast em cada roda, motor/freio/direção e torque de equilíbrio.
## A frente da moto é -Z (padrão do Godot).

@export var stats: BikeStats
## Nós visuais das rodas: seguem a suspensão e giram com a velocidade.
@export var front_wheel: Node3D
@export var rear_wheel: Node3D

## Velocidade para frente (m/s), negativa em ré. Atualizada a cada passo de física.
var forward_speed: float = 0.0
var front_grounded: bool = false
var rear_grounded: bool = false
## 0 = pneus agarrando, 1 = derrapagem total. Sobe ao puxar o freio de mão e cai devagar ao soltar.
var drift_amount: float = 0.0
## Ângulo (graus) entre para onde a moto aponta e para onde ela está indo.
var drift_angle: float = 0.0

var _steer: float = 0.0
var _ground_normal: Vector3 = Vector3.UP
var _flat_velocity: Vector3 = Vector3.ZERO
var _spawn_transform: Transform3D

@onready var _front_ray: RayCast3D = $FrontWheelRay
@onready var _rear_ray: RayCast3D = $RearWheelRay
@onready var _visual: Node3D = $Visual


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

	front_grounded = _apply_suspension(_front_ray, front_wheel)
	rear_grounded = _apply_suspension(_rear_ray, rear_wheel)
	_ground_normal = _average_ground_normal()

	var throttle := Input.get_action_strength("acelerar")
	var brake := Input.get_action_strength("frear")
	var steer_input := Input.get_axis("esquerda", "direita")
	var handbrake := Input.is_action_pressed("freio_mao") and is_grounded()
	var drift_rate := 10.0 if handbrake else stats.drift_recovery
	drift_amount = move_toward(drift_amount, 1.0 if handbrake else 0.0, drift_rate * delta)
	_steer = move_toward(_steer, steer_input, stats.steer_response * delta)

	var forward := _flat_on_ground(-global_basis.z)
	forward_speed = linear_velocity.dot(forward)
	_flat_velocity = linear_velocity - _ground_normal * linear_velocity.dot(_ground_normal)
	drift_angle = rad_to_deg(forward.angle_to(_flat_velocity)) if _flat_velocity.length() > 2.0 else 0.0

	if is_grounded():
		_drive(forward, throttle, brake, handbrake, delta)
		_apply_grip(forward, delta)
	_steer_and_balance(forward, delta)
	_update_visuals(delta)


## Mola + amortecedor numa roda. Retorna true se a roda está tocando o chão.
func _apply_suspension(ray: RayCast3D, wheel: Node3D) -> bool:
	var ray_length := stats.suspension_rest_length + stats.wheel_radius
	# Sem isso o raio usaria a posição do passo anterior e mediria errado em alta velocidade.
	ray.force_raycast_update()
	var up := global_basis.y
	if not ray.is_colliding():
		wheel.global_position = ray.global_position - up * stats.suspension_rest_length
		return false

	var origin := ray.global_position
	var distance := origin.distance_to(ray.get_collision_point())
	var compression := ray_length - distance
	var com := global_transform * center_of_mass
	var point_velocity := linear_velocity + angular_velocity.cross(origin - com)

	var spring := compression * stats.spring_stiffness
	var damper := -point_velocity.dot(up) * stats.spring_damping
	var force := clampf(spring + damper, 0.0, stats.max_suspension_force)
	apply_force(up * force, origin - global_position)

	wheel.global_position = origin - up * (distance - stats.wheel_radius)
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
func _drive(forward: Vector3, throttle: float, brake: float, handbrake: bool, delta: float) -> void:
	var speed := forward_speed
	var new_speed := speed

	if handbrake:
		# Roda traseira travada: sem tração, só arrasta na terra.
		new_speed = move_toward(new_speed, 0.0, stats.handbrake_deceleration * delta)
		throttle = 0.0
	elif throttle > 0.0 and rear_grounded:
		# Aceleração cheia até 75% da máxima, depois diminui até zero na máxima.
		var taper := clampf((stats.max_speed - speed) / (stats.max_speed * 0.25), 0.0, 1.0)
		new_speed += throttle * stats.acceleration * taper * delta

	if brake > 0.0:
		if speed > 0.5:
			new_speed = move_toward(new_speed, 0.0, brake * stats.brake_deceleration * delta)
		elif throttle == 0.0:
			var taper := clampf((stats.reverse_max_speed + speed) / (stats.reverse_max_speed * 0.25), 0.0, 1.0)
			new_speed -= brake * stats.reverse_acceleration * taper * delta

	if throttle == 0.0 and brake == 0.0 and not handbrake:
		new_speed = move_toward(new_speed, 0.0, stats.coast_deceleration * delta)

	linear_velocity += forward * (new_speed - speed)


## Remove parte do deslizamento lateral (pneus agarrando no chão). Derrapando, agarra bem menos.
func _apply_grip(forward: Vector3, delta: float) -> void:
	var right := forward.cross(_ground_normal)
	var lateral := linear_velocity.dot(right)
	var grip := stats.grip * lerpf(1.0, stats.handbrake_grip_factor, drift_amount)
	linear_velocity -= right * lateral * clampf(grip * delta, 0.0, 1.0)


## Guinada pela direção e rolagem corrigida para a moto ficar em pé.
func _steer_and_balance(forward: Vector3, delta: float) -> void:
	var av := angular_velocity

	if is_grounded():
		# Usa a velocidade real (e não só a "para frente"), para a direção não sumir com a moto de lado.
		var speed := _flat_velocity.length()
		var speed_ratio := speed / stats.max_speed
		var steer_factor := clampf(speed / stats.full_steer_speed, 0.0, 1.0)
		steer_factor *= lerpf(1.0, stats.high_speed_steer_factor, clampf(speed_ratio, 0.0, 1.0))
		var direction := -1.0 if forward_speed < -0.1 else 1.0
		# Direita = giro negativo em torno do "para cima".
		var drift_boost := lerpf(1.0, stats.handbrake_steer_boost, drift_amount)
		var target_yaw := -_steer * stats.steer_rate * steer_factor * direction * drift_boost
		if drift_angle > 0.0:
			# Não deixa a direção abrir a derrapagem além do ângulo máximo.
			var next_forward := forward.rotated(_ground_normal, target_yaw * delta)
			var next_angle := rad_to_deg(next_forward.angle_to(_flat_velocity))
			if next_angle > stats.max_drift_angle and next_angle > drift_angle:
				target_yaw = 0.0
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
	var lean_degrees := stats.visual_lean_degrees * (1.0 + 0.4 * drift_amount)
	var lean := -_steer * deg_to_rad(lean_degrees) * speed_ratio if is_grounded() else 0.0
	_visual.rotation.z = lerp_angle(_visual.rotation.z, lean, clampf(8.0 * delta, 0.0, 1.0))

	var spin := -forward_speed / stats.wheel_radius * delta
	front_wheel.rotate_x(spin)
	rear_wheel.rotate_x(spin)
