extends Node
## Registra os controles do jogo em tempo de execução.
## Assim o mapa de entradas fica legível no Git, em vez de espalhado no project.godot.

const ACTIONS := {
	"acelerar": [KEY_W, KEY_UP],
	"frear": [KEY_S, KEY_DOWN],
	"esquerda": [KEY_A, KEY_LEFT],
	"direita": [KEY_D, KEY_RIGHT],
	"inclinar_frente": [KEY_I],
	"inclinar_tras": [KEY_K],
	"resetar_moto": [KEY_R],
	"pausar": [KEY_ESCAPE],
}

const PAD_BUTTONS := {
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


func _add_axis(action: String, axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)
