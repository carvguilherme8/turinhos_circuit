extends Node3D
## Som do motor com dois loops gravados: acelerando (`on_stream`) e acelerador solto
## (`off_stream`). Os dois tocam juntos e o acelerador decide quanto se ouve de cada um;
## a rotação (altura do som) sobe dentro de cada marcha e cai na troca. No ar a roda gira
## solta e o motor dispara; parado fica na lenta; na queda o motor morre.
## A moto do jogador toca sem posição (sempre nítida); as dos bots soam no espaço 3D.

@export var bike: Node  # Bike
@export var on_stream: AudioStream
@export var off_stream: AudioStream
@export var gears: int = 4
## Altura do som na lenta e no giro máximo (1 = como foi gravado).
@export var idle_pitch: float = 0.6
@export var max_pitch: float = 1.35
## O loop solto foi gravado num giro um pouco mais baixo; corrige para casar com o outro.
@export var off_pitch_ratio: float = 1.06
## Volumes acelerando e soltando (jogador). Bots usam os mesmos, atenuados pela distância.
@export var on_volume_db: float = -6.0
@export var off_volume_db: float = -11.0
## Rapidez com que a rotação sobe e cai e com que um loop passa para o outro (por segundo).
@export var rev_up_rate: float = 2.5
@export var rev_down_rate: float = 1.4
@export var blend_rate: float = 8.0
## Alcance do som dos bots (metros).
@export var bot_unit_size: float = 8.0
@export var bot_max_distance: float = 120.0

var _on: Node  # AudioStreamPlayer ou AudioStreamPlayer3D
var _off: Node
var _rpm: float = 0.0
var _blend: float = 0.0  # 0 = solto, 1 = acelerando
var _alive: float = 1.0  # cai a 0 quando o motor morre na queda


func _ready() -> void:
	if bike == null:
		bike = get_parent()
	var positional: bool = not bike.get("player_controlled")
	_on = _make_player(on_stream, positional)
	_off = _make_player(off_stream, positional)


func _make_player(stream: AudioStream, positional: bool) -> Node:
	var player: Node
	if positional:
		var p3 := AudioStreamPlayer3D.new()
		p3.unit_size = bot_unit_size
		p3.max_distance = bot_max_distance
		player = p3
	else:
		player = AudioStreamPlayer.new()
	player.set("stream", stream)
	player.set("bus", &"Motor")
	add_child(player)
	player.call("play")
	return player


func _physics_process(delta: float) -> void:
	if bike == null or _on == null:
		return
	var throttle: float = bike.throttle()
	var target_rpm := 0.0
	if bike.is_crashed:
		throttle = 0.0
		_alive = move_toward(_alive, 0.0, delta * 1.5)
	else:
		_alive = 1.0
		if not bike.controls_enabled:
			# Grid: o jogador pode acelerar em ponto morto (o som não move a moto).
			throttle = Input.get_action_strength("acelerar") if bike.player_controlled else 0.0
			target_rpm = throttle
		elif not bike.is_grounded():
			target_rpm = 1.0 if throttle > 0.1 else 0.55  # roda solta no ar
		else:
			target_rpm = _gear_rpm(throttle)
	var rate := rev_up_rate if target_rpm > _rpm else rev_down_rate
	_rpm = move_toward(_rpm, target_rpm, rate * delta)
	_blend = move_toward(_blend, 1.0 if throttle > 0.1 else 0.0, blend_rate * delta)

	var pitch := lerpf(idle_pitch, max_pitch, _rpm) * lerpf(0.5, 1.0, _alive)
	_on.set("pitch_scale", maxf(pitch, 0.05))
	_off.set("pitch_scale", maxf(pitch * off_pitch_ratio, 0.05))
	# Mistura de potência igual entre os dois loops; o motor morrendo some aos poucos.
	var fade := linear_to_db(maxf(_alive, 0.0001))
	_on.set("volume_db", on_volume_db + linear_to_db(maxf(sin(_blend * PI / 2.0), 0.0001)) + fade)
	_off.set("volume_db", off_volume_db + linear_to_db(maxf(cos(_blend * PI / 2.0), 0.0001)) + fade)


## Rotação no chão pela velocidade: sobe dentro de cada marcha e recomeça mais baixa na troca.
func _gear_rpm(throttle: float) -> float:
	var speed_ratio := clampf(absf(bike.forward_speed) / bike.stats.max_speed, 0.0, 1.0)
	var position_in_gears := speed_ratio * gears
	var gear := mini(int(position_in_gears), gears - 1)
	var within_gear := clampf(position_in_gears - gear, 0.0, 1.0)
	# A primeira marcha começa da lenta; as outras, de um giro médio.
	var rpm := lerpf(0.0 if gear == 0 else 0.4, 1.0, within_gear)
	if throttle < 0.1:
		rpm *= 0.85  # sem acelerar o giro cai um pouco (freio motor)
	return rpm
