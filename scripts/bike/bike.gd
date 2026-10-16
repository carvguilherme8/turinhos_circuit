class_name Bike
extends RigidBody3D
## Moto arcade: suspensão por raycast em cada roda, motor/freio/direção, torque de equilíbrio
## e peso do piloto (wheelie, levantar a traseira, giro e whip no ar).
## A frente da moto é -Z (padrão do Godot).

## Emitido ao pousar de um salto (não emitido em queda).
signal landed(quality: Landing, angle: float)
## Pousou depois de mortais: nome ("BACKFLIP"/"FRONTFLIP") e quantas voltas.
signal trick_landed(trick: String, count: int)
## Emitido quando a moto cai; ela volta para a pista após stats.respawn_delay.
signal crashed
signal respawned
## Pedido de volta para a pista (R, queda, bot travado). Se alguém (a corrida) estiver
## ligado neste sinal, ele decide onde pôr a moto; senão, volta ao último ponto seguro.
signal recover_requested

enum Landing { PERFECT, ROUGH }

## Pontos seguros guardados para reposicionar (mais antigos são descartados).
const SAFE_POINT_INTERVAL := 0.5
const SAFE_POINT_COUNT := 12
## Na queda, volta para um ponto seguro de pelo menos este tempo antes.
const SAFE_POINT_MIN_AGE := 2.0

@export var stats: BikeStats
## true = pilotada pelo teclado/controle; false = por um bot (BotDriver preenche bot_*).
@export var player_controlled: bool = true
## Cores: texturas alternativas da moto e do piloto (mesma UV do modelo). Vazio = padrão.
@export var bike_texture: Texture2D
@export var rider_texture: Texture2D

@export_group("Visual")
## Rodas: giram com a velocidade.
@export var front_wheel: Node3D
@export var rear_wheel: Node3D
## Conjunto do guidão (gira em torno do eixo de direção inclinado).
@export var steering: Node3D
## Bengalas do garfo: deslizam ao longo do garfo com a suspensão dianteira.
@export var fork_slider: Node3D
## Balança traseira: gira no pivô acompanhando a suspensão traseira.
@export var swingarm: Node3D
## Inclinação do garfo no modelo (graus para trás).
@export var fork_rake_degrees: float = 22.5
@export var handlebar_angle_low_speed: float = 30.0
@export var handlebar_angle_high_speed: float = 10.0
## Piloto (some na câmera do guidão) e a parte de cima dele, que inclina com o peso.
@export var rider: Node3D
@export var rider_upper: Node3D
## Inclinação do tronco do piloto com o peso todo para frente/trás.
@export var rider_lean_degrees: float = 12.0
## Câmera em cima do guidão (primeira pessoa).
@export var first_person_camera: Camera3D
## Poeira da roda traseira (a intensidade vem de velocidade, aceleração, derrapagem e pousos).
@export var rear_dust: GPUParticles3D

## Velocidade para frente (m/s), negativa em ré. Atualizada a cada passo de física.
var forward_speed: float = 0.0
var front_grounded: bool = false
var rear_grounded: bool = false
## 0 = pneus agarrando, 1 = derrapagem total. Sobe ao puxar o freio de mão e cai devagar ao soltar.
var drift_amount: float = 0.0
## Ângulo (graus) entre para onde a moto aponta e para onde ela está indo.
var drift_angle: float = 0.0
## Tempo no ar do salto atual (0 no chão).
var air_time: float = 0.0
## Deslizando sobre ondulações (costelas) empinado: frente no alto, corpo pela média do terreno.
var skimming: bool = false
## false durante a contagem regressiva: a moto ignora acelerador, freio e direção.
var controls_enabled: bool = true
## Comandos do bot (0..1; direção -1..1).
var bot_throttle: float = 0.0
var bot_brake: float = 0.0
var bot_steer: float = 0.0
## Onde cada roda toca o chão (válido quando a roda está no chão). Usado pelas marcas de pneu.
var front_contact: Vector3 = Vector3.ZERO
var rear_contact: Vector3 = Vector3.ZERO
## 0..1: quanto o pneu traseiro está arrastando (derrapagem ou freada forte).
var skid: float = 0.0
var is_crashed: bool = false
## Motivo da última queda (para depuração e ajuste fino).
var last_crash_reason: String = ""
## Giro acumulado no ar em torno do eixo lateral (graus, + = para trás) e tempo segurando o comando.
var air_rotation: float = 0.0
var _air_spin_hold: float = 0.0
var _last_forward: Vector3 = Vector3.FORWARD

var _crash_timer: float = 0.0
var _clock: float = 0.0
var _next_safe_point_time: float = 0.0
## Cada item: {"time": float, "position": Vector3, "heading": Vector3}
var _safe_points: Array[Dictionary] = []

var _steer: float = 0.0
var _throttle: float = 0.0
var _brake: float = 0.0
## Ângulo (rad) e velocidade do pêndulo numa roda só: + wheelie, - traseira no alto.
var _one_wheel_angle: float = 0.0
var _one_wheel_rate: float = 0.0
## Peso do piloto: +1 = todo para trás (empinar), -1 = todo para frente.
var _rider_pitch: float = 0.0
## Peso do piloto para os lados: +1 = direita.
var _rider_side: float = 0.0
var _ground_normal: Vector3 = Vector3.UP
var _flat_velocity: Vector3 = Vector3.ZERO
var _spawn_transform: Transform3D

## Altura do centro de cada roda no espaço da moto (calculada pela suspensão).
var _front_wheel_y: float = 0.0
var _rear_wheel_y: float = 0.0
var _front_wheel_rest_y: float = 0.0
var _rear_wheel_rest_y: float = 0.0
var _fork_slider_rest: Vector3
var _swingarm_length: float = 0.5
var _rider_upper_rest_x: float = 0.0
## Tempo restante da "explosão" de poeira (pouso, queda).
var _dust_burst: float = 0.0
## Tempo desde que a roda traseira tocou o chão e normal do chão suavizada (média das ondas).
var _rear_air_time: float = 0.0
var _smoothed_normal: Vector3 = Vector3.UP
## Extensão atual da suspensão traseira ao deslizar (sobe/desce aos poucos).
var _skim_extension: float = 0.0
## Último instante em que uma roda tocou uma ondulação (camada 2).
var _last_bump_clock: float = -10.0
var _visual_rest: Vector3
var _visual_lean: float = 0.0
## Ângulo visual numa roda só (segue o pêndulo; no ar volta suave para zero).
var _visual_pitch: float = 0.0

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
	# Necessário para saber quando a carenagem bate em algo (detecção de queda).
	contact_monitor = true
	max_contacts_reported = 4
	var ray_length := stats.suspension_rest_length + stats.wheel_radius
	_front_ray.target_position = Vector3(0.0, -ray_length, 0.0)
	_rear_ray.target_position = Vector3(0.0, -ray_length, 0.0)
	# Camada 1 = chão e obstáculos; camada 2 = ondulações (costelas). As rodas veem as duas;
	# o corpo deixa de colidir com as ondulações enquanto desliza.
	_front_ray.collision_mask = 1 | 2
	_rear_ray.collision_mask = 1 | 2
	collision_mask = 1 | 2
	_spawn_transform = global_transform

	# Posições de repouso do modelo, para animar a suspensão a partir delas.
	_front_wheel_rest_y = to_local(front_wheel.global_position).y
	_rear_wheel_rest_y = to_local(rear_wheel.global_position).y
	_front_wheel_y = _front_wheel_rest_y
	_rear_wheel_y = _rear_wheel_rest_y
	_fork_slider_rest = fork_slider.position
	_visual_rest = _visual.position
	_apply_skin($Visual/Model, bike_texture)
	_apply_skin($Visual/Rider, rider_texture)
	if rider_upper:
		_rider_upper_rest_x = rider_upper.rotation.x
	_swingarm_length = Vector2(rear_wheel.position.y, rear_wheel.position.z).length()


func is_grounded() -> bool:
	return front_grounded or rear_grounded


## Define a posição de largada (e põe a moto nela, parada).
func set_spawn(spawn: Transform3D) -> void:
	_spawn_transform = spawn
	global_transform = spawn
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_safe_points.clear()


## Recoloca a moto num ponto da pista (fora da pista, atalho). Esquece os pontos seguros,
## que podem ter ficado do lado errado.
func place_at(spot: Transform3D) -> void:
	global_transform = spot
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_safe_points.clear()
	_steer = 0.0
	drift_amount = 0.0
	air_time = 0.0
	is_crashed = false
	_reset_one_wheel()
	respawned.emit()


## Volta para a pista: quem estiver ligado em recover_requested decide onde (a corrida sabe
## onde ficam a pista e os saltos); sem ninguém, usa o último ponto seguro.
func request_recover() -> void:
	if recover_requested.get_connections().is_empty():
		respawn()
	else:
		recover_requested.emit()


## Volta para o último ponto seguro (ou para o início, se não houver nenhum).
## min_age > 0 ignora pontos guardados há menos que isso (usado na queda).
func respawn(min_age: float = 0.0) -> void:
	var target := _spawn_transform
	for i in range(_safe_points.size() - 1, -1, -1):
		var point: Dictionary = _safe_points[i]
		if _clock - float(point["time"]) >= min_age:
			var heading: Vector3 = point["heading"]
			var basis := Basis.looking_at(heading, Vector3.UP)
			target = Transform3D(basis, point["position"] + Vector3.UP * 0.3)
			break
	global_transform = target
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_steer = 0.0
	drift_amount = 0.0
	air_time = 0.0
	is_crashed = false
	_reset_one_wheel()
	respawned.emit()


func _physics_process(delta: float) -> void:
	_clock += delta
	front_grounded = _apply_suspension(_front_ray, true)
	rear_grounded = _apply_suspension(_rear_ray, false)
	_ground_normal = _average_ground_normal()
	_rear_air_time = 0.0 if rear_grounded else _rear_air_time + delta
	if is_grounded():
		_smoothed_normal = _smoothed_normal.slerp(_ground_normal, clampf(delta / 0.35, 0.0, 1.0)).normalized()

	if is_crashed:
		# Queda: sem controle nem equilíbrio, a física derruba a moto de verdade.
		_crash_timer -= delta
		_update_visuals(delta)
		_update_dust(delta)
		if _crash_timer <= 0.0:
			if recover_requested.get_connections().is_empty():
				respawn(SAFE_POINT_MIN_AGE)
			else:
				recover_requested.emit()
		return

	if player_controlled and controls_enabled and Input.is_action_just_pressed("resetar_moto"):
		request_recover()
		return

	_track_air_and_landing(delta)
	if is_crashed:
		return
	_record_safe_point()

	var throttle := 0.0
	var brake := 0.0
	var steer_input := 0.0
	var handbrake := false
	_rider_pitch = 0.0
	_rider_side = 0.0
	if controls_enabled and player_controlled:
		throttle = Input.get_action_strength("acelerar")
		brake = Input.get_action_strength("frear")
		steer_input = Input.get_axis("esquerda", "direita")
		handbrake = Input.is_action_pressed("freio_mao") and is_grounded()
		_rider_pitch = Input.get_axis("inclinar_frente", "inclinar_tras")
		_rider_side = Input.get_axis("inclinar_esquerda", "inclinar_direita")
	elif controls_enabled:
		throttle = bot_throttle
		brake = bot_brake
		steer_input = bot_steer
	_throttle = throttle
	_brake = brake
	var drift_rate := 10.0 if handbrake else stats.drift_recovery
	drift_amount = move_toward(drift_amount, 1.0 if handbrake else 0.0, drift_rate * delta)
	_steer = move_toward(_steer, steer_input, stats.steer_response * delta)

	var forward := _flat_on_ground(-global_basis.z)
	forward_speed = linear_velocity.dot(forward)
	_flat_velocity = linear_velocity - _ground_normal * linear_velocity.dot(_ground_normal)
	drift_angle = rad_to_deg(forward.angle_to(_flat_velocity)) if _flat_velocity.length() > 2.0 else 0.0

	skimming = _one_wheel_angle > deg_to_rad(stats.skim_min_wheelie_degrees) \
			and forward_speed > stats.skim_min_speed and _rear_air_time < stats.skim_coyote_time
	# A suspensão só estende sobre ondulações (num wheelie em chão liso a moto não "flutua").
	var on_bumps := _clock - _last_bump_clock < 0.4
	_skim_extension = move_toward(_skim_extension, stats.skim_extension if skimming and on_bumps else 0.0, 3.0 * delta)
	set_collision_mask_value(2, not skimming)
	if is_grounded() or skimming:
		_drive(forward, throttle, brake, handbrake, delta)
		_apply_grip(forward, delta)
	_steer_and_balance(forward, delta)
	if skimming:
		_skim(delta)
	_update_visuals(delta)
	_update_dust(delta)


## Conta o tempo no ar, avalia o pouso e detecta queda pela carenagem.
func _track_air_and_landing(delta: float) -> void:
	var forward := -global_basis.z
	if not is_grounded():
		if air_time == 0.0:
			air_rotation = 0.0
		else:
			# Giro acumulado em torno do eixo lateral da moto (+ = nariz para cima / para trás).
			air_rotation += rad_to_deg(_last_forward.signed_angle_to(forward, global_basis.x))
		air_time += delta
	elif air_time > 0.0:
		if air_time >= stats.min_air_time:
			_evaluate_landing()
		air_time = 0.0
	_last_forward = forward

	if not is_crashed and get_contact_count() > 0:
		var tilt := rad_to_deg(global_basis.y.angle_to(Vector3.UP))
		if tilt > stats.crash_tilt_angle:
			_crash("encostou tombada %d°" % tilt)

	# Wheelie ou traseira no alto além do limite: a moto vira.
	var one_wheel_degrees := rad_to_deg(_one_wheel_angle)
	if not is_crashed and (one_wheel_degrees > stats.wheelie_crash_angle
			or one_wheel_degrees < -stats.stoppie_crash_angle):
		_crash("passou do ponto numa roda só %d°" % one_wheel_degrees)


## Compara o "para cima" da moto com a normal do chão onde ela tocou:
## pousar inclinado junto com a rampa de descida conta como alinhado.
func _evaluate_landing() -> void:
	var angle := rad_to_deg(global_basis.y.angle_to(_ground_normal))
	if angle > stats.crash_landing_angle or global_basis.y.dot(Vector3.UP) < 0.0:
		_crash("pouso torto demais %d°" % angle)
		return

	if angle <= stats.good_landing_angle:
		var forward := _flat_on_ground(-global_basis.z)
		var speed := linear_velocity.dot(forward)
		var boost := minf(stats.perfect_landing_boost, maxf(stats.max_speed * 1.1 - speed, 0.0))
		linear_velocity += forward * boost
		_dust_burst = 0.3
		landed.emit(Landing.PERFECT, angle)
		_report_flips()
	else:
		var t := inverse_lerp(stats.good_landing_angle, stats.crash_landing_angle, angle)
		linear_velocity *= lerpf(stats.rough_landing_keep_best, stats.rough_landing_keep_worst, t)
		_dust_burst = 0.45
		landed.emit(Landing.ROUGH, angle)
		_report_flips()


## Pousou depois de girar uma volta completa ou mais: avisa o mortal.
func _report_flips() -> void:
	var turns := floori((absf(air_rotation) + 360.0 - stats.flip_min_degrees) / 360.0)
	if turns >= 1:
		trick_landed.emit("BACKFLIP" if air_rotation > 0.0 else "FRONTFLIP", turns)
	air_rotation = 0.0


func _crash(reason: String = "") -> void:
	last_crash_reason = reason
	_dust_burst = 0.5
	if not is_zero_approx(_visual_pitch):
		global_transform = global_transform * _one_wheel_transform(_visual_pitch, _visual_rest)
		_visual_pitch = 0.0
	_reset_one_wheel()
	is_crashed = true
	_crash_timer = stats.respawn_delay
	drift_amount = 0.0
	crashed.emit()


## Guarda de tempos em tempos onde a moto estava bem (nas duas rodas, em pé, em chão quase plano).
func _record_safe_point() -> void:
	if _clock < _next_safe_point_time:
		return
	if not (front_grounded and rear_grounded) or _ground_normal.y < 0.95:
		return
	if global_basis.y.angle_to(_ground_normal) > deg_to_rad(10.0):
		return
	var heading := -global_basis.z
	heading.y = 0.0
	if heading.length_squared() < 0.01:
		return
	_next_safe_point_time = _clock + SAFE_POINT_INTERVAL
	_safe_points.append({"time": _clock, "position": global_position, "heading": heading.normalized()})
	if _safe_points.size() > SAFE_POINT_COUNT:
		_safe_points.pop_front()


## Mola + amortecedor numa roda. Retorna true se a roda está tocando o chão.
func _apply_suspension(ray: RayCast3D, is_front: bool) -> bool:
	var ray_length := stats.suspension_rest_length + stats.wheel_radius
	if not is_front:
		# Deslizando, a traseira estende para o corpo passar acima das ondas.
		ray_length += _skim_extension
		ray.target_position = Vector3(0.0, -ray_length, 0.0)
	# Sem isso o raio usaria a posição do passo anterior e mediria errado em alta velocidade.
	ray.force_raycast_update()
	var up := global_basis.y
	if not ray.is_colliding():
		_set_wheel_height(is_front, ray.position.y - (ray_length - stats.wheel_radius))
		return false

	var origin := ray.global_position
	var hit := ray.get_collision_point()
	var collider := ray.get_collider() as CollisionObject3D
	if collider and collider.get_collision_layer_value(2):
		_last_bump_clock = _clock
	if is_front:
		front_contact = hit
	else:
		rear_contact = hit
	var distance := origin.distance_to(hit)
	var compression := ray_length - distance
	var com := global_transform * center_of_mass
	var point_velocity := linear_velocity + angular_velocity.cross(origin - com)

	var spring := compression * stats.spring_stiffness
	var damper := -point_velocity.dot(up) * stats.spring_damping
	var force := clampf(spring + damper, 0.0, stats.max_suspension_force)
	if skimming:
		if is_front:
			force *= stats.skim_front_support  # frente leve: o piloto tira o peso dela
		else:
			force = clampf(spring * stats.skim_spring_scale + damper * stats.skim_damping_scale,
					0.0, stats.max_suspension_force)
	apply_force(up * force, origin - global_position)

	_set_wheel_height(is_front, ray.position.y - (distance - stats.wheel_radius))
	return true


func _set_wheel_height(is_front: bool, height: float) -> void:
	if is_front:
		_front_wheel_y = height
	else:
		_rear_wheel_y = height


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
	elif throttle > 0.0 and (rear_grounded or skimming) and _one_wheel_angle > -0.05:
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


## Guinada pela direção, peso do piloto e rolagem corrigida para a moto ficar em pé.
func _steer_and_balance(forward: Vector3, delta: float) -> void:
	var av := angular_velocity

	if is_grounded():
		# Usa a velocidade real (e não só a "para frente"), para a direção não sumir com a moto de lado.
		var speed := _flat_velocity.length()
		var speed_ratio := speed / stats.max_speed
		var steer_factor := clampf(speed / stats.full_steer_speed, 0.0, 1.0)
		steer_factor *= lerpf(1.0, 0.25, clampf(_one_wheel_angle / deg_to_rad(20.0), 0.0, 1.0))
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
		av = _rider_weight_ground(av, delta)
	elif not skimming:
		# Só um salto de verdade zera o wheelie (pulinhos entre ondas não).
		if air_time > 0.3:
			_reset_one_wheel()
		av = _rider_weight_air(av, delta)

	# Equilíbrio: só no eixo de rolagem (o pitch fica livre para suspensão e saltos).
	# No ar, o whip deita a moto para o lado do comando.
	var roll_axis := -global_basis.z
	var target_up := _ground_normal
	if not is_grounded():
		target_up = Vector3.UP.rotated(roll_axis, _rider_side * deg_to_rad(stats.whip_roll_angle))
	var target_up_flat := target_up - roll_axis * target_up.dot(roll_axis)
	# No meio de um mortal (moto muito fora do normal) não corrige a rolagem: senão ela
	# "desviraria" de lado em vez de completar o giro.
	var flipping := not is_grounded() and global_basis.y.y < 0.35
	if target_up_flat.length_squared() > 0.0001 and not flipping:
		var roll_error := global_basis.y.signed_angle_to(target_up_flat.normalized(), roll_axis)
		av += roll_axis * (roll_error * stats.roll_stiffness - av.dot(roll_axis))

	angular_velocity = av


## No chão: peso para trás empina (wheelie), peso para frente levanta a traseira.
## O ângulo numa roda só é um pêndulo (_one_wheel_angle): o comando empurra, a gravidade
## puxa de volta até o ponto de equilíbrio e, passando dele, a moto vira.
## É só visual (o modelo gira sobre a roda apoiada); o corpo físico fica nas duas rodas,
## para não brigar com a suspensão.
func _rider_weight_ground(av: Vector3, delta: float) -> Vector3:
	var previous := _one_wheel_angle
	var accel := 0.0
	if _one_wheel_angle >= 0.0:
		if _rider_pitch > 0.05 and (rear_grounded or _rear_air_time < stats.skim_coyote_time):
			var throttle_share := lerpf(stats.wheelie_without_throttle, 1.0, _throttle)
			accel += stats.wheelie_strength * _rider_pitch * throttle_share
		accel -= stats.wheelie_brake_strength * _brake
		accel -= stats.one_wheel_gravity * _balance(_one_wheel_angle, stats.wheelie_balance_angle)
	if _one_wheel_angle <= 0.0:
		# É o embalo que segura a traseira no alto: devagar, ela desce mesmo além do equilíbrio.
		var speed_share := clampf(absf(forward_speed) / 8.0, 0.0, 1.0)
		if _rider_pitch < -0.05 and front_grounded:
			accel -= stats.stoppie_strength * -_rider_pitch * speed_share
		accel += stats.one_wheel_gravity * _balance(-_one_wheel_angle, stats.stoppie_balance_angle)
		accel += stats.one_wheel_gravity * 2.0 * (1.0 - speed_share)

	_one_wheel_rate += accel * delta
	_one_wheel_rate -= _one_wheel_rate * clampf(stats.one_wheel_damping * delta, 0.0, 1.0)
	_one_wheel_angle += _one_wheel_rate * delta
	# Voltou para as duas rodas (sem comando segurando do outro lado): para no zero.
	if (previous > 0.0 and _one_wheel_angle <= 0.0 and _rider_pitch > -0.05) \
			or (previous < 0.0 and _one_wheel_angle >= 0.0 and _rider_pitch < 0.05):
		_reset_one_wheel()

	# Assistente: apoiada numa roda só (saindo de uma crista, por exemplo) e sem comando,
	# a moto alinha devagar com o chão em vez de mergulhar de nariz.
	if front_grounded != rear_grounded and absf(_rider_pitch) < 0.05 and stats.one_wheel_pitch_assist > 0.0:
		var pitch_axis := global_basis.x
		var pitch := deg_to_rad(_ground_pitch_degrees())
		var target_rate := -pitch * stats.one_wheel_pitch_assist
		av += pitch_axis * (target_rate - av.dot(pitch_axis)) * clampf(4.0 * delta, 0.0, 1.0)
	return av


## 1 com a moto nas duas rodas, 0 no ponto de equilíbrio, negativo depois dele.
## Curva quadrática: a gravidade ainda puxa forte no meio do wheelie (soltar salva)
## e só some perto do equilíbrio.
func _balance(angle: float, balance_degrees: float) -> float:
	var ratio := angle / deg_to_rad(balance_degrees)
	return 1.0 - ratio * ratio


func _reset_one_wheel() -> void:
	_one_wheel_angle = 0.0
	_one_wheel_rate = 0.0


## Ângulo de pitch em relação ao chão (positivo = nariz para cima).
func _ground_pitch_degrees() -> float:
	return rad_to_deg(asin(clampf((-global_basis.z).dot(_ground_normal), -1.0, 1.0)))


## No ar: peso frente/trás gira a moto (pitch); para os lados faz o whip, jogando a traseira.
## Sem comando, a moto mantém o giro que trouxe da rampa e alinha a frente com o salto.
func _rider_weight_air(av: Vector3, delta: float) -> Vector3:
	var pitch_axis := global_basis.x
	var rate := av.dot(pitch_axis)
	if absf(_rider_pitch) > 0.05:
		# Toques curtos giram devagar (ajuste do pouso); segurando, acelera até o mortal.
		_air_spin_hold += delta
		var spin := lerpf(stats.air_pitch_rate, stats.air_flip_rate,
				clampf(_air_spin_hold / stats.air_flip_spinup, 0.0, 1.0))
		var target_rate := _rider_pitch * spin
		av += pitch_axis * (target_rate - rate) * clampf(stats.air_pitch_response * delta, 0.0, 1.0)
	else:
		_air_spin_hold = 0.0
	if absf(_rider_pitch) <= 0.05 and stats.air_pitch_assist > 0.0 and linear_velocity.length() > 3.0:
		# Assistente: o nariz segue a trajetória, como um dardo.
		var velocity := linear_velocity - pitch_axis * linear_velocity.dot(pitch_axis)
		var error := (-global_basis.z).signed_angle_to(velocity, pitch_axis)
		var target_rate := error * stats.air_pitch_assist
		# Girando rápido (soltou no meio de um mortal): freia forte; giro lento: suave.
		var blend := lerpf(2.0, stats.air_release_brake, clampf((absf(rate) - 2.0) / 3.0, 0.0, 1.0))
		av += pitch_axis * (target_rate - rate) * clampf(blend * delta, 0.0, 1.0)

	var velocity_flat := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var forward_flat := Vector3(-global_basis.z.x, 0.0, -global_basis.z.z)
	if velocity_flat.length() > 2.0 and forward_flat.length() > 0.2 and global_basis.y.y > 0.35:
		# Whip para a direita: frente vira para a direita, traseira sai para a esquerda.
		var whip := -_rider_side * deg_to_rad(stats.whip_yaw_angle)
		var desired := velocity_flat.normalized().rotated(Vector3.UP, whip)
		var yaw_error := forward_flat.normalized().signed_angle_to(desired, Vector3.UP)
		var yaw_rate := av.dot(Vector3.UP)
		av += Vector3.UP * (yaw_error * stats.air_yaw_align - yaw_rate) * clampf(5.0 * delta, 0.0, 1.0)
	return av


## Deslizando: segura a altura e o ângulo pela média do terreno, não onda a onda
## (só a roda traseira "raspa" o topo das ondas).
func _skim(delta: float) -> void:
	var vertical := linear_velocity.dot(_smoothed_normal)
	linear_velocity -= _smoothed_normal * vertical * clampf(stats.skim_vertical_damping * delta, 0.0, 1.0)
	var pitch_axis := global_basis.x
	var pitch := asin(clampf((-global_basis.z).dot(_smoothed_normal), -1.0, 1.0))
	var target_rate := -pitch * stats.skim_pitch_hold
	var av := angular_velocity
	av += pitch_axis * (target_rate - av.dot(pitch_axis)) * clampf(20.0 * delta, 0.0, 1.0)
	angular_velocity = av


## Giro de `angle` (+ nariz para cima) em torno do ponto onde a roda apoiada toca o chão:
## roda traseira no wheelie, dianteira com a traseira no alto. `ground` é a posição do chão
## sob o centro da moto no espaço em que o giro é aplicado.
func _one_wheel_transform(angle: float, ground: Vector3) -> Transform3D:
	var contact_z := _rear_ray.position.z if angle > 0.0 else _front_ray.position.z
	var pivot := ground + Vector3(0.0, 0.0, contact_z)
	var rotation := Basis(Vector3.RIGHT, angle)
	return Transform3D(rotation, pivot - rotation * pivot)


func _update_visuals(delta: float) -> void:
	var speed_ratio := clampf(absf(forward_speed) / stats.max_speed, 0.0, 1.0)
	var lean_degrees := stats.visual_lean_degrees * (1.0 + 0.4 * drift_amount)
	var lean := -_steer * deg_to_rad(lean_degrees) * speed_ratio if is_grounded() else 0.0
	_visual_lean = lerp_angle(_visual_lean, lean, clampf(8.0 * delta, 0.0, 1.0))
	if is_grounded() or skimming:
		_visual_pitch = _one_wheel_angle
	else:
		_visual_pitch = lerpf(_visual_pitch, 0.0, clampf(10.0 * delta, 0.0, 1.0))
	var lean_transform := Transform3D(Basis(Vector3.BACK, _visual_lean), _visual_rest)
	_visual.transform = lean_transform * _one_wheel_transform(_visual_pitch, Vector3.ZERO)

	# Guidão: gira em torno do eixo de direção inclinado; esterça menos em alta velocidade.
	var rake := deg_to_rad(fork_rake_degrees)
	var steer_axis := Vector3(0.0, cos(rake), sin(rake))
	var bar_angle := lerpf(handlebar_angle_low_speed, handlebar_angle_high_speed, speed_ratio)
	steering.basis = Basis(steer_axis, -_steer * deg_to_rad(bar_angle))

	# Suspensão dianteira: as bengalas deslizam ao longo do garfo.
	var front_travel := clampf(_front_wheel_y - _front_wheel_rest_y, -0.3, 0.4)
	fork_slider.position = _fork_slider_rest + steer_axis * (front_travel / cos(rake))

	# Suspensão traseira: a balança gira no pivô até a roda chegar à altura certa.
	var rear_travel := clampf(_rear_wheel_y - _rear_wheel_rest_y, -0.3, 0.4)
	swingarm.rotation.x = -asin(clampf(rear_travel / _swingarm_length, -0.9, 0.9))

	if rider_upper:
		# Inclina a partir da pose do modelo (o tronco já vem inclinado para frente).
		var lean_back := _rider_upper_rest_x + _rider_pitch * deg_to_rad(rider_lean_degrees)
		rider_upper.rotation.x = lerp_angle(rider_upper.rotation.x, lean_back, clampf(10.0 * delta, 0.0, 1.0))

	var spin := -forward_speed / stats.wheel_radius * delta
	front_wheel.rotate_x(spin)
	rear_wheel.rotate_x(spin)


## Poeira da roda traseira: um pouco com velocidade, mais ao arrancar (roda girando em falso),
## frear forte, derrapar ou empinar; explosão curta nos pousos e quedas.
func _update_dust(delta: float) -> void:
	var speed_ratio_skid := clampf(absf(forward_speed) / stats.max_speed, 0.0, 1.0)
	skid = clampf(maxf(drift_amount, _brake * speed_ratio_skid * 1.5), 0.0, 1.0)
	if rear_dust == null:
		return
	_dust_burst = maxf(_dust_burst - delta, 0.0)
	var target := 0.0
	if rear_grounded and not is_crashed:
		var speed_ratio := clampf(absf(forward_speed) / stats.max_speed, 0.0, 1.0)
		target = speed_ratio * 0.3
		target += _throttle * (1.0 - speed_ratio) * 0.6
		target += _brake * speed_ratio * 0.5
		target += drift_amount
		if _one_wheel_angle > 0.05:
			target += 0.3
	if _dust_burst > 0.0:
		target = 1.0
	rear_dust.amount_ratio = move_toward(rear_dust.amount_ratio, clampf(target, 0.0, 1.0), 5.0 * delta)


## Troca a textura de todas as malhas de um modelo (variação de cor com a mesma UV).
func _apply_skin(model: Node, texture: Texture2D) -> void:
	if texture == null or model == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 0.9
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = material
