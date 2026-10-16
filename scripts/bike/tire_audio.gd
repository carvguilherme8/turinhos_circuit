extends Node3D
## Som dos pneus na lama, por baixo do motor: `roll_stream` fica de fundo enquanto a moto
## anda (mais alto quanto mais rápido) e `slide_stream` entra forte ao derrapar, frear
## arrastando a roda, patinar na arrancada e num pouso. No ar os dois somem.
## A moto do jogador toca sem posição; as dos bots soam no espaço 3D.

@export var bike: Node  # Bike
@export var roll_stream: AudioStream
@export var slide_stream: AudioStream
## Volume de cada camada no máximo (jogador).
@export var roll_volume_db: float = -12.0
@export var slide_volume_db: float = -5.0
## Ângulo de derrapagem (graus) que já conta como derrapagem total.
@export var full_drift_angle: float = 25.0
## Rapidez com que o som entra e sai (por segundo).
@export var attack_rate: float = 8.0
@export var release_rate: float = 2.5
## Altura do som (1 = como foi gravado): abaixo de 1 fica mais grave, mais "lama".
@export var roll_pitch: Vector2 = Vector2(0.78, 1.0)  # parado, velocidade máxima
@export var slide_pitch: Vector2 = Vector2(0.82, 0.98)
## Duração do espirro de lama num pouso (s).
@export var landing_splash: float = 0.35
@export var bot_unit_size: float = 6.0
@export var bot_max_distance: float = 80.0

var _roll: Node  # AudioStreamPlayer ou AudioStreamPlayer3D
var _slide: Node
var _roll_level: float = 0.0
var _slide_level: float = 0.0
var _splash: float = 0.0


func _ready() -> void:
	if bike == null:
		bike = get_parent()
	var positional: bool = not bike.get("player_controlled")
	_roll = _make_player(roll_stream, positional)
	_slide = _make_player(slide_stream, positional)
	bike.connect("landed", _on_landed)


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
	player.set("volume_db", -80.0)
	add_child(player)
	player.call("play")
	return player


func _on_landed(_quality: int, _angle: float) -> void:
	_splash = landing_splash


func _physics_process(delta: float) -> void:
	if bike == null or _roll == null:
		return
	_splash = maxf(_splash - delta, 0.0)
	var roll_target := 0.0
	var slide_target := 0.0
	if bike.is_grounded() and not bike.is_crashed:
		var speed := absf(bike.forward_speed)
		var speed_ratio := clampf(speed / bike.stats.max_speed, 0.0, 1.0)
		roll_target = smoothstep(0.02, 0.6, speed_ratio)
		# Derrapagem: freio de mão / roda arrastando, ou moto andando de lado.
		var sideways := clampf(absf(bike.drift_angle) / full_drift_angle, 0.0, 1.0)
		var drift := maxf(bike.skid, sideways) * smoothstep(2.0, 8.0, speed)
		# Roda patinando na arrancada.
		var wheelspin: float = bike.throttle() * (1.0 - speed_ratio) * smoothstep(0.5, 3.0, speed) * 0.6
		slide_target = maxf(drift, wheelspin)
	if _splash > 0.0:
		slide_target = maxf(slide_target, _splash / landing_splash)
	_roll_level = _approach(_roll_level, roll_target, delta)
	_slide_level = _approach(_slide_level, slide_target, delta)

	var speed_ratio := clampf(absf(bike.forward_speed) / bike.stats.max_speed, 0.0, 1.0)
	_roll.set("pitch_scale", lerpf(roll_pitch.x, roll_pitch.y, speed_ratio))
	_slide.set("pitch_scale", lerpf(slide_pitch.x, slide_pitch.y, speed_ratio))
	_roll.set("volume_db", roll_volume_db + linear_to_db(maxf(_roll_level, 0.0001)))
	_slide.set("volume_db", slide_volume_db + linear_to_db(maxf(_slide_level, 0.0001)))


func _approach(level: float, target: float, delta: float) -> float:
	var rate := attack_rate if target > level else release_rate
	return move_toward(level, target, rate * delta)
