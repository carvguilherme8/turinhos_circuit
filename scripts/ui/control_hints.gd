extends Label
## Dicas de controle no canto da tela. A ação "alternar_dicas" (H / direcional ↑) esconde ou
## mostra; a escolha fica salva em user://settings.cfg para a próxima vez.

const SETTINGS_PATH := "user://settings.cfg"
const HINTS := """WASD pilotar · Espaço freio de mão · R volta para a pista
Setas = peso do piloto: ↓ empina · ↑ levanta a traseira · no ar giram · ←/→ whip
C troca a câmera · Backspace reinicia a corrida · H esconde as dicas"""
const COLLAPSED := "H: dicas"

var _visible_hints: bool = true


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		_visible_hints = bool(config.get_value("hud", "control_hints", true))
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("alternar_dicas"):
		_visible_hints = not _visible_hints
		_apply()
		_save()
		get_viewport().set_input_as_handled()


func _apply() -> void:
	text = HINTS if _visible_hints else COLLAPSED
	modulate.a = 1.0 if _visible_hints else 0.55


func _save() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("hud", "control_hints", _visible_hints)
	config.save(SETTINGS_PATH)
