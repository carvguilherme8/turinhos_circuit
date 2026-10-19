class_name Bike
extends RigidBody3D
## Moto arcade: suspensão por raycast em cada roda, motor/freio/direção, torque de equilíbrio
## e peso do piloto (wheelie, levantar a traseira, giro e whip no ar).
## A frente da moto é -Z (padrão do Godot).

## Emitido ao pousar de um salto (não emitido em queda).
signal landed(quality: Landing, angle: float)
## Pousou depois de manobras: nomes na ordem (ex.: ["SUPERMAN", "BACKFLIP"]).
signal tricks_landed(names: PackedStringArray)
## Emitido quando a moto cai; ela volta para a pista após stats.respawn_delay.
signal crashed
signal respawned
## Pedido de volta para a pista (R, queda, bot travado). Se alguém (a corrida) estiver
## ligado neste sinal, ele decide onde pôr a moto; senão, volta ao último ponto seguro.
signal recover_requested

enum Landing { PERFECT, ROUGH }

## Pontos seguros guardados para reposicionar (mais antigos são descartados).
const SAFE_POINT_INTERVAL := 0.5
const PlayerProfile := preload("res://scripts/core/player_profile.gd")
const SkinPainter := preload("res://scripts/bike/skin_painter.gd")
const SAFE_POINT_COUNT := 12
## Na queda, volta para um ponto seguro de pelo menos este tempo antes.
const SAFE_POINT_MIN_AGE := 2.0

@export var stats: BikeStats
## true = pilotada pelo teclado/controle; false = por um bot (BotDriver preenche bot_*).
@export var player_controlled: bool = true
## Cores: texturas alternativas da moto e do piloto (mesma UV do modelo). Vazio = padrão.
@export var bike_texture: Texture2D
## A moto do jogador usa o visual escolhido no menu (número, uniforme e cor da moto).
@export var use_player_profile: bool = true
## No chão, quanto a moto deita junto com o chão inclinado para o lado (0 = sempre em pé).
@export_range(0.0, 1.0) var ground_roll_follow: float = 0.0
## Chão mais inclinado que isto (normal.y menor) vira a referência de "em pé" (looping, paredes).
@export_range(0.0, 1.0) var steep_ground: float = 0.6
## A partir desta inclinação (normal.y menor; 0,85 = ~32°) a moto começa a acompanhar o chão.
@export_range(0.0, 1.0) var bank_follow_start: float = 0.85
## Assistência de pouso (ligada no celular): no ar, sem comando, a moto se ajeita sozinha
## para pousar alinhada com o chão onde vai cair.
var landing_assist: bool = false
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
## Boneco físico que substitui o piloto numa queda (nó com rider_ragdoll.gd).
## Tipado como Node para a moto não depender do registro da classe no editor.
@export var ragdoll: Node

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
## Manobras de estilo completadas neste salto (RiderTricks preenche) e quanto da pose
## da manobra atual está aplicada (0..1; pousar acima de 0,5 é queda).
var air_tricks: PackedStringArray = PackedStringArray()
var trick_amount: float = 0.0
## Avaliação do pouso em andamento: tempo desde o toque (-1 = nenhuma) e melhor alinhamento.
var _landing_timer: float = -1.0
var _rider_hidden_by_crash: bool = false
var _landing_best_angle: float = 180.0
var _air_spin_hold: float = 0.0
var _last_forward: Vector3 = Vector3.FORWARD

var _crash_timer: float = 0.0
var _clock: float = 0.0
## Velocidade no começo do passo e se algum batente de suspensão agiu nele.
var _speed_before_bump: float = 0.0
## Último chão muito inclinado (looping, paredes) e quando foi.
var _steep_normal: Vector3 = Vector3.UP
var _steep_clock: float = -10.0
var _bump_stopped := false
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
	landing_assist = player_controlled and GameInput.touch_mode
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
	# Camadas: 1 = chão e obstáculos, 2 = ondulações (costelas), 3 = motos, 4 = ragdolls.
	# As rodas veem só o chão e as ondulações (não confundem outra moto com chão); o corpo
	# bate no chão, nas ondulações (menos quando desliza) e nas outras motos.
	_front_ray.collision_mask = 1 | 2
	_rear_ray.collision_mask = 1 | 2
	collision_layer = 1 << 2
	collision_mask = 1 | 2 | (1 << 2)
	_spawn_transform = global_transform
	if ragdoll:
		ragdoll.connect("hit_scenery", _on_rider_hit_scenery)

	# Posições de repouso do modelo, para animar a suspensão a partir delas.
	_front_wheel_rest_y = to_local(front_wheel.global_position).y
	_rear_wheel_rest_y = to_local(rear_wheel.global_position).y
	_front_wheel_y = _front_wheel_rest_y
	_rear_wheel_y = _rear_wheel_rest_y
	_fork_slider_rest = fork_slider.position
	_visual_rest = _visual.position
	_apply_skin($Visual/Model, bike_texture)
	_apply_skin($Visual/Rider, rider_texture)
	if player_controlled and use_player_profile:
		apply_player_profile()
		PlayerProfile.listen(apply_player_profile)
	if rider_upper:
		_rider_upper_rest_x = rider_upper.rotation.x
	_swingarm_length = Vector2(rear_wheel.position.y, rear_wheel.position.z).length()


## Repinta moto e piloto com o visual do jogador (menu de customização).
func apply_player_profile() -> void:
	if not is_inside_tree():
		return
	PlayerProfile.ensure_loaded()
	bike_texture = SkinPainter.bike_texture(PlayerProfile.bike_color(), PlayerProfile.number)
	rider_texture = SkinPainter.rider_texture(PlayerProfile.suit_color(), PlayerProfile.accent_color(), PlayerProfile.number)
	_apply_skin($Visual/Model, bike_texture)
	_apply_skin($Visual/Rider, rider_texture)


## Acelerador aplicado neste passo (0..1), para o som do motor.
func throttle() -> float:
	return _throttle


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
	_restore_rider()
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
	_restore_rider()
	respawned.emit()


func _physics_process(delta: float) -> void:
	_clock += delta
	_speed_before_bump = linear_velocity.length()
	_bump_stopped = false
	front_grounded = _apply_suspension(_front_ray, true)
	rear_grounded = _apply_suspension(_rear_ray, false)
	if _bump_stopped:
		# O batente só muda a direção: a moto segue a rampa com (quase) a mesma velocidade.
		var keep := _speed_before_bump * stats.bump_stop_keep_speed
		if linear_velocity.length() < keep and linear_velocity.length() > 0.1:
			linear_velocity = linear_velocity.normalized() * keep
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
		if air_time == 0.0 and _landing_timer < 0.0:
			air_rotation = 0.0
			air_tricks.clear()
		else:
			# Giro acumulado em torno do eixo lateral da moto (+ = nariz para cima / para trás).
			air_rotation += rad_to_deg(_last_forward.signed_angle_to(forward, global_basis.x))
		air_time += delta
	elif air_time > 0.0:
		if air_time >= stats.min_air_time and _landing_timer < 0.0:
			var angle_now := _alignment_angle()
			if angle_now <= stats.crash_landing_angle and global_basis.y.dot(Vector3.UP) >= 0.0:
				_evaluate_landing(angle_now)
			else:
				# Parece queda: confirma num instante (pode ter sido só um raio raspando
				# a beirada ou a face íngreme de uma rampa).
				_landing_timer = 0.0
				_landing_best_angle = angle_now
		air_time = 0.0
	_last_forward = forward
	if is_crashed:
		return

	# Confirmação de queda no pouso: fica com o melhor alinhamento do intervalo.
	if _landing_timer >= 0.0:
		if is_grounded():
			_landing_best_angle = minf(_landing_best_angle, _alignment_angle())
		_landing_timer += delta
		if (front_grounded and rear_grounded) or _landing_timer >= stats.landing_window:
			_landing_timer = -1.0
			_evaluate_landing(_landing_best_angle)
			if is_crashed:
				return

	if not is_crashed and get_contact_count() > 0:
		# Tombada = deitada de lado (rolagem); de nariz para baixo numa descida íngreme não conta.
		var forward_axis := -global_basis.z
		var reference := _upright_reference()
		var upright := reference - forward_axis * reference.dot(forward_axis)
		var tilt := rad_to_deg(global_basis.y.angle_to(upright)) if upright.length_squared() > 0.0001 else 0.0
		if global_basis.y.dot(reference) < 0.0:
			tilt = 180.0  # de cabeça para baixo
		if tilt > stats.crash_tilt_angle:
			_crash("encostou tombada %d°" % tilt)

	# Wheelie ou traseira no alto além do limite: a moto vira.
	var one_wheel_degrees := rad_to_deg(_one_wheel_angle)
	if not is_crashed and (one_wheel_degrees > stats.wheelie_crash_angle
			or one_wheel_degrees < -stats.stoppie_crash_angle):
		_crash("passou do ponto numa roda só %d°" % one_wheel_degrees)


## Quanto a moto está fora do alinhamento (graus): de frente, o nariz contra a inclinação
## do chão (pousar inclinado junto com a rampa de descida conta como alinhado); de lado, a moto
## contra a vertical (ela fica em pé mesmo em chão inclinado para o lado, como nas berms).
func _alignment_angle() -> float:
	var right := global_basis.x
	var ground := _ground_normal - right * _ground_normal.dot(right)
	var pitch_error := global_basis.y.angle_to(ground) if ground.length_squared() > 0.0001 else 0.0
	var forward := -global_basis.z
	var reference := _upright_reference()
	var vertical := reference - forward * reference.dot(forward)
	var roll_error := global_basis.y.angle_to(vertical) if vertical.length_squared() > 0.0001 else 0.0
	return rad_to_deg(sqrt(pitch_error * pitch_error + roll_error * roll_error))


## "Em pé" para a moto: a vertical do mundo em chão plano ou pouco inclinado (berms, bordas da
## pista); em chão muito inclinado (paredes, wallride, looping) e com as rodas nele, o próprio
## chão, com uma passagem gradual entre os dois (`bank_follow_start` até `steep_ground`).
func _upright_reference() -> Vector3:
	if is_grounded() and _ground_normal.y < bank_follow_start:
		var follow := 1.0 if _ground_normal.y <= steep_ground else 				smoothstep(bank_follow_start, steep_ground, _ground_normal.y)
		var reference := Vector3.UP.slerp(_ground_normal, follow).normalized()
		if _ground_normal.y < steep_ground:
			_steep_normal = _ground_normal
			_steep_clock = _clock
		return reference
	# Rodas descolaram por um instante no looping (no topo, por exemplo): continua usando o
	# chão de antes por meio segundo, senão a moto seria dada como "de cabeça para baixo".
	if _clock - _steep_clock < 0.5:
		return _steep_normal
	return Vector3.UP


## Compara o "para cima" da moto com o chão onde ela tocou (ver _alignment_angle).
func _evaluate_landing(angle: float) -> void:
	if trick_amount > 0.5:
		_crash("pousou no meio da manobra")
		return
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
		_report_tricks()
	else:
		var t := inverse_lerp(stats.good_landing_angle, stats.crash_landing_angle, angle)
		linear_velocity *= lerpf(stats.rough_landing_keep_best, stats.rough_landing_keep_worst, t)
		_dust_burst = 0.45
		landed.emit(Landing.ROUGH, angle)
		_report_tricks()


## Pousou: avisa as manobras do salto (estilo + mortais) numa lista só.
func _report_tricks() -> void:
	var names := PackedStringArray(air_tricks)
	var turns := floori((absf(air_rotation) + 360.0 - stats.flip_min_degrees) / 360.0)
	if turns >= 1:
		var flip := "BACKFLIP" if air_rotation > 0.0 else "FRONTFLIP"
		names.append(flip if turns == 1 else ("DOUBLE " + flip if turns == 2 else "%dx %s" % [turns, flip]))
	if not names.is_empty():
		tricks_landed.emit(names)
	air_rotation = 0.0
	air_tricks.clear()


## Cabeça ou tronco do piloto encostou no cenário: queda.
func _on_rider_hit_scenery(part: String) -> void:
	if not is_crashed:
		_crash("piloto bateu %s no cenário" % ("a cabeça" if part == "head" else "o corpo"))


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
	_landing_timer = -1.0
	# Tranco que derruba a moto de lado: toda queda é visível (sem isso, uma moto que caiu
	# em pé só seguia andando até reaparecer).
	var side := 1.0 if randf() < 0.5 else -1.0
	if ragdoll and rider and rider.visible:
		# O piloto é arremessado com a velocidade que a moto tinha.
		_rider_hidden_by_crash = true
		rider.visible = false
		ragdoll.activate(linear_velocity, angular_velocity)
	angular_velocity += -global_basis.z * side * stats.crash_roll_kick
	linear_velocity *= stats.crash_speed_keep
	crashed.emit()


## Tira o boneco físico e devolve o piloto à moto.
func _restore_rider() -> void:
	if ragdoll:
		ragdoll.deactivate()
	if _rider_hidden_by_crash and rider:
		rider.visible = true
	_rider_hidden_by_crash = false


## Guarda de tempos em tempos onde a moto estava bem (nas duas rodas, em pé, em chão quase plano).
func _record_safe_point() -> void:
	if _clock < _next_safe_point_time:
		return
	if not (front_grounded and rear_grounded) or _ground_normal.y < 0.95:
		return
	if _alignment_angle() > 10.0:
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
	if is_crashed:
		force = 0.0  # caída: sem suspensão, a moto capota sobre a carenagem
	elif skimming:
		if is_front:
			force *= stats.skim_front_support  # frente leve: o piloto tira o peso dela
		else:
			force = clampf(spring * stats.skim_spring_scale + damper * stats.skim_damping_scale,
					0.0, stats.max_suspension_force)
	apply_force(up * force, origin - global_position)

	# Batente com antecipação: olha o chão onde esta roda vai estar no próximo passo. Se lá a
	# mola passaria do fim do curso (base de rampa em alta velocidade), a roda sobe já agora o
	# que falta, como um pneu de verdade que toca a rampa antes do eixo. Assim o corpo não bate
	# na rampa e a moto empina junto com ela.
	if not is_crashed:
		_bump_stop(ray, origin, up, ray_length, compression, point_velocity)

	_set_wheel_height(is_front, ray.position.y - (distance - stats.wheel_radius))
	return true


func _bump_stop(ray: RayCast3D, origin: Vector3, up: Vector3, ray_length: float, compression: float,
		point_velocity: Vector3) -> void:
	var limit := stats.suspension_rest_length * stats.bump_stop_ratio
	var dt := get_physics_process_delta_time()
	# Onde a roda vai estar daqui a 2 passos (só o movimento ao longo do chão).
	var travel := point_velocity - up * point_velocity.dot(up)
	var ahead := origin + travel * dt * 2.0
	var query := PhysicsRayQueryParameters3D.create(ahead + up * 0.6, ahead - up * (ray_length + 0.2), ray.collision_mask, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var predicted := compression
	if hit:
		predicted = maxf(predicted, ray_length - (ahead.distance_to(hit["position"]) if (hit["position"] - ahead).dot(up) < 0.0 else -ahead.distance_to(hit["position"])))
	if predicted <= limit:
		return
	# Velocidade para cima (no ponto da roda) que chega ao limite a tempo, sem passar dele.
	var needed := (predicted - limit) / (dt * 2.0)
	var current := point_velocity.dot(up)
	if current >= needed:
		return
	# Impulso no ponto da roda que dá essa velocidade a ele: parte levanta a moto, parte vira
	# giro (a frente empina). Aplicado direto nas velocidades: o resto do passo as reescreve a
	# partir do valor lido, e um apply_impulse se perderia.
	var com := global_transform * center_of_mass
	var arm := origin - com
	var inv_inertia := get_inverse_inertia_tensor()
	var per_unit := 1.0 / mass + up.dot((inv_inertia * arm.cross(up)).cross(arm))
	var impulse := up * (needed - current) / per_unit
	linear_velocity += impulse / mass
	angular_velocity += inv_inertia * arm.cross(impulse)
	_bump_stopped = true


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
	# No chão a moto fica em pé em relação à vertical (não deita junto com berms e bordas
	# inclinadas); `ground_roll_follow` > 0 a faz acompanhar um pouco a inclinação do chão.
	# No ar, o whip deita a moto para o lado do comando.
	var roll_axis := -global_basis.z
	var target_up := _upright_reference().slerp(_ground_normal, ground_roll_follow)
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
		# Curva em S: o giro cresce suave, sem tranco.
		var spin := lerpf(stats.air_pitch_rate, stats.air_flip_rate,
				smoothstep(0.0, stats.air_flip_spinup, _air_spin_hold))
		var target_rate := _rider_pitch * spin
		av += pitch_axis * (target_rate - rate) * clampf(stats.air_pitch_response * delta, 0.0, 1.0)
	else:
		_air_spin_hold = 0.0
	if absf(_rider_pitch) <= 0.05 and stats.air_pitch_assist > 0.0 and linear_velocity.length() > 3.0:
		# Assistente: o nariz segue a trajetória, como um dardo.
		var velocity := linear_velocity - pitch_axis * linear_velocity.dot(pitch_axis)
		var gain := stats.air_pitch_assist
		if landing_assist:
			var landing := _landing_direction()
			if landing != Vector3.ZERO:
				velocity = landing - pitch_axis * landing.dot(pitch_axis)
				gain = maxf(gain, 3.0)
		var error := (-global_basis.z).signed_angle_to(velocity, pitch_axis)
		var target_rate := error * gain
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


## Assistência de pouso: direção (subindo ou descendo a rampa) do chão onde a moto vai cair,
## no rumo em que ela voa. Longe do pouso mistura com a trajetória (o nariz segue o voo
## e só perto do chão copia a inclinação do pouso). Vetor zero = não achou chão.
func _landing_direction() -> Vector3:
	var space := get_world_3d().direct_space_state
	var below := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * 60.0,
			_front_ray.collision_mask, [get_rid()])
	var hit := space.intersect_ray(below)
	if hit.is_empty():
		return Vector3.ZERO
	var g := absf(get_gravity().y) if absf(get_gravity().y) > 0.1 else 9.8
	var height := global_position.y - (hit["position"] as Vector3).y
	var vy := linear_velocity.y
	var t := (vy + sqrt(maxf(vy * vy + 2.0 * g * maxf(height, 0.0), 0.0))) / g
	var flat := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	if flat.length() < 1.0:
		return Vector3.ZERO
	var spot := global_position + flat * t
	var down := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 20.0, spot + Vector3.DOWN * 60.0,
			_front_ray.collision_mask, [get_rid()])
	var land := space.intersect_ray(down)
	if land.is_empty():
		return Vector3.ZERO
	var normal: Vector3 = land["normal"]
	var slope := (flat - normal * flat.dot(normal)).normalized()
	# Mistura: a mais de 1 s do pouso segue o voo; a menos de 0,4 s, a rampa.
	var weight := 1.0 - clampf((t - 0.4) / 0.6, 0.0, 1.0)
	return linear_velocity.normalized().slerp(slope, weight)


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

	if rider_upper and trick_amount <= 0.0:
		# Inclina a partir da pose do modelo (o tronco já vem inclinado para frente).
		# Durante uma manobra quem move o tronco é a animação.
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
