extends Node
## Registra os controles do jogo em tempo de execução.
## Assim o mapa de entradas fica legível no Git, em vez de espalhado no project.godot.

const ACTIONS := {
	# Mão esquerda pilota (WASD); mão direita joga o peso do piloto (setas).
	"acelerar": [KEY_W],
	"frear": [KEY_S],
	"esquerda": [KEY_A],
	"direita": [KEY_D],
	"inclinar_frente": [KEY_UP],
	"inclinar_tras": [KEY_DOWN],
	"inclinar_esquerda": [KEY_LEFT],
	"inclinar_direita": [KEY_RIGHT],
	"freio_mao": [KEY_SPACE],
	"resetar_moto": [KEY_R],
	"trocar_camera": [KEY_C],
	"alternar_dicas": [KEY_H],
	"reiniciar_corrida": [KEY_BACKSPACE],
	"manobra_cancan_esquerda": [KEY_Q],
	"manobra_cancan_direita": [KEY_E],
	"manobra_superman": [KEY_F],
	"pausar": [KEY_ESCAPE],
}

const PAD_BUTTONS := {
	"freio_mao": JOY_BUTTON_A,
	"trocar_camera": JOY_BUTTON_BACK,
	"alternar_dicas": JOY_BUTTON_DPAD_UP,
	"reiniciar_corrida": JOY_BUTTON_DPAD_DOWN,
	"manobra_cancan_esquerda": JOY_BUTTON_LEFT_SHOULDER,
	"manobra_cancan_direita": JOY_BUTTON_RIGHT_SHOULDER,
	"manobra_superman": JOY_BUTTON_X,
	"resetar_moto": JOY_BUTTON_Y,
	"pausar": JOY_BUTTON_START,
}


func _ready() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for keycode in ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			InputMap.action_add_event(action, ev)

	for action in PAD_BUTTONS:
		var ev := InputEventJoypadButton.new()
		ev.button_index = PAD_BUTTONS[action]
		InputMap.action_add_event(action, ev)

	_add_axis("acelerar", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_axis("frear", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_add_axis("esquerda", JOY_AXIS_LEFT_X, -1.0)
	_add_axis("direita", JOY_AXIS_LEFT_X, 1.0)
	_add_axis("inclinar_frente", JOY_AXIS_RIGHT_Y, -1.0)
	_add_axis("inclinar_tras", JOY_AXIS_RIGHT_Y, 1.0)
	_add_axis("inclinar_esquerda", JOY_AXIS_RIGHT_X, -1.0)
	_add_axis("inclinar_direita", JOY_AXIS_RIGHT_X, 1.0)


func _add_axis(action: String, axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)
