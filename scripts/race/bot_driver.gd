class_name BotDriver
extends Node
## Piloto automático: segue a linha central da pista mirando um ponto à frente, calcula as
## curvas que vêm e freia a tempo. Cada bot tem uma linha (deslocada para um lado) e um
## ritmo próprios. Se ficar travado, volta para a pista.

@export var bike: Bike
@export var track: StadiumTrack
## Fração da velocidade máxima que o bot usa nas retas (ritmo).
@export_range(0.5, 1.0, 0.01) var pace: float = 0.95
## Deslocamento lateral da linha do bot (m, + = direita de quem corre).
@export var line_offset: float = 0.0
## Distância do ponto mirado: base + por m/s de velocidade.
@export var lookahead: float = 4.0
@export var lookahead_per_speed: float = 0.35
## Velocidade nas curvas em U e desaceleração que o bot assume ao frear.
@export var hairpin_speed: float = 8.5
@export var braking: float = 11.0
@export var steer_gain: float = 2.6

var _index: int = -1
var _stuck_time: float = 0.0


func _physics_process(delta: float) -> void:
	if bike == null or track == null or track.centerline.is_empty():
		return
	_index = track.closest_index(bike.global_position, _index)
	if not bike.controls_enabled or bike.is_crashed:
		bike.bot_throttle = 0.0
		bike.bot_brake = 0.0
		bike.bot_steer = 0.0
		_stuck_time = 0.0
		return

	var speed := bike.forward_speed
	_steer(speed)
	_throttle_and_brake(speed)

	# Travado (encostado nos blocos, atravessado): volta para a pista.
	if absf(speed) < 1.0 and bike.is_grounded():
		_stuck_time += delta
		if _stuck_time > 2.5:
			bike.respawn()
			_stuck_time = 0.0
	else:
		_stuck_time = 0.0


func _steer(speed: float) -> void:
	if not bike.is_grounded():
		bike.bot_steer = 0.0  # no ar, o assistente da moto cuida do resto
		return
	var ahead := track.index_ahead(_index, lookahead + maxf(speed, 0.0) * lookahead_per_speed)
	var target := track.point_at(ahead) + track.right_at(ahead) * line_offset
	var position := Vector2(bike.global_position.x, bike.global_position.z)
	var to_target := (target - position).normalized()
	var heading3 := -bike.global_basis.z
	var heading := Vector2(heading3.x, heading3.z).normalized()
	# Ângulo com sinal: positivo = alvo à direita de quem corre.
	var angle := atan2(heading.x * to_target.y - heading.y * to_target.x, heading.dot(to_target))
	bike.bot_steer = clampf(angle * steer_gain, -1.0, 1.0)


## Velocidade-alvo = a menor entre o ritmo na reta e o que dá para frear até cada curva à frente.
func _throttle_and_brake(speed: float) -> void:
	var target := bike.stats.max_speed * pace
	var tangent := track.tangent_at(_index)
	for d in range(2, 42, 2):
		var i := track.index_ahead(_index, d)
		var bend := absf(track.tangent_at(i).angle_to(track.tangent_at(track.index_ahead(i, 6.0))))
		if bend < 0.12:
			continue
		var corner_speed := lerpf(bike.stats.max_speed * pace, hairpin_speed, clampf((bend - 0.12) / 0.6, 0.0, 1.0))
		target = minf(target, sqrt(corner_speed * corner_speed + 2.0 * braking * d))
	# Já está numa curva: segura a velocidade da curva.
	var here := absf(tangent.angle_to(track.tangent_at(track.index_ahead(_index, 6.0))))
	if here > 0.12:
		target = minf(target, lerpf(bike.stats.max_speed * pace, hairpin_speed, clampf((here - 0.12) / 0.6, 0.0, 1.0)))

	if speed < target - 0.3:
		bike.bot_throttle = 1.0
		bike.bot_brake = 0.0
	elif speed > target + 1.0:
		bike.bot_throttle = 0.0
		bike.bot_brake = clampf((speed - target) / 4.0, 0.2, 1.0)
	else:
		bike.bot_throttle = 0.4
		bike.bot_brake = 0.0
