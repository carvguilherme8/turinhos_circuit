extends AudioStreamPlayer3D
## Som do motor: um loop curto cuja altura acompanha a rotação. A rotação sobe dentro de cada
## marcha e cai na troca (como nos jogos de corrida clássicos); no ar a roda gira solta e o
## motor dispara; parado fica na lenta. No grid, o jogador pode acelerar em ponto morto.

@export var bike: Bike
@export var gears: int = 4
## Altura do som na lenta e no corte de giro.
@export var idle_pitch: float = 0.55
@export var max_pitch: float = 1.45
## Volume na lenta e acelerando tudo.
@export var idle_volume_db: float = -14.0
@export var full_volume_db: float = -3.0
## Rapidez com que a rotação sobe e cai (por segundo).
@export var rev_up_rate: float = 3.0
@export var rev_down_rate: float = 1.6

var _rpm: float = 0.0


func _ready() -> void:
	play()


func _physics_process(delta: float) -> void:
	if bike == null:
		return
	var throttle := bike.throttle()
	var target := 0.0
	if bike.is_crashed:
		target = 0.05  # motor morrendo na queda
		throttle = 0.0
	elif not bike.controls_enabled:
		# Grid: acelerar em ponto morto (só o jogador; o som não move a moto).
		if bike.player_controlled:
			throttle = Input.get_action_strength("acelerar")
		target = throttle
	elif not bike.is_grounded():
		target = 1.0 if throttle > 0.1 else 0.6  # roda solta no ar
	else:
		var speed_ratio := clampf(absf(bike.forward_speed) / bike.stats.max_speed, 0.0, 1.0)
		var position_in_gears := speed_ratio * gears
		var gear := mini(int(position_in_gears), gears - 1)
		var within_gear := position_in_gears - gear
		# Primeira marcha começa da lenta; as outras recomeçam de um giro médio.
		var floor_rpm := 0.0 if gear == 0 else 0.4
		target = lerpf(floor_rpm, 1.0, clampf(within_gear, 0.0, 1.0))
		if throttle < 0.1:
			target *= 0.8  # freio motor: o giro cai um pouco sem acelerar
	var rate := rev_up_rate if target > _rpm else rev_down_rate
	_rpm = move_toward(_rpm, target, rate * delta)
	pitch_scale = lerpf(idle_pitch, max_pitch, _rpm)
	volume_db = lerpf(idle_volume_db, full_volume_db, clampf(throttle * 0.6 + _rpm * 0.4, 0.0, 1.0))
