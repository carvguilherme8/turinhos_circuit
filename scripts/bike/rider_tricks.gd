class_name RiderTricks
extends Node
## Manobras no ar com as animações do piloto (rider_tricks.tres): segure a tecla para fazer
## a pose e solte para voltar. A manobra conta quando a pose fica completa por um tempinho;
## pousar no meio dela é queda.

## Ação de entrada -> [animação, nome mostrado no pouso].
const TRICKS := {
	"manobra_cancan_esquerda": ["tricks/can_can_esquerda", "CAN-CAN"],
	"manobra_cancan_direita": ["tricks/can_can_direita", "CAN-CAN"],
	"manobra_superman": ["tricks/superman", "SUPERMAN"],
}

@export var bike: Bike
@export var animation_player: AnimationPlayer
## Tempo no ar antes de poder começar uma manobra (s).
@export var min_air_time: float = 0.12
## Tempo com a pose completa para a manobra contar (s).
@export var hold_to_count: float = 0.1

var _action: String = ""
var _held: float = 0.0
var _counted: bool = false
var _returning: bool = false


func _ready() -> void:
	if bike:
		bike.crashed.connect(_snap_back)
		bike.respawned.connect(_snap_back)


func _physics_process(delta: float) -> void:
	if bike == null or animation_player == null:
		return
	var can_start := bike.player_controlled and bike.controls_enabled and not bike.is_crashed \
			and not bike.is_grounded() and bike.air_time > min_air_time

	if _action == "":
		if can_start:
			for action in TRICKS:
				if Input.is_action_pressed(action):
					_start(action)
					break
	else:
		var holding := Input.is_action_pressed(_action) and not bike.is_grounded() and not bike.is_crashed
		if holding and not _returning:
			if _amount() >= 0.99:
				_held += delta
				if _held >= hold_to_count and not _counted:
					_counted = true
					bike.air_tricks.append(TRICKS[_action][1])
		elif not _returning:
			# Soltou (ou tocou o chão): volta para a pose de pilotagem.
			_returning = true
			animation_player.play_backwards(TRICKS[_action][0])
		elif _amount() <= 0.001:
			_action = ""
			_returning = false
	bike.trick_amount = _amount() if _action != "" else 0.0


func _start(action: String) -> void:
	_action = action
	_held = 0.0
	_counted = false
	_returning = false
	animation_player.play(TRICKS[action][0])


## 0 = pose de pilotagem, 1 = manobra completa.
func _amount() -> float:
	if _action == "" or animation_player.current_animation == "":
		return 0.0 if _action == "" else (0.0 if _returning else 1.0)
	return clampf(animation_player.current_animation_position / animation_player.current_animation_length, 0.0, 1.0)


func _snap_back() -> void:
	_action = ""
	_returning = false
	if animation_player:
		animation_player.play("tricks/RESET")
	if bike:
		bike.trick_amount = 0.0
