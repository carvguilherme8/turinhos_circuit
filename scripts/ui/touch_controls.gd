extends CanvasLayer
## Controles de toque (celular): virar para a esquerda e para a direita no canto esquerdo,
## acelerar e freio de mão (como o espaço no PC, sem ré) no canto direito, e um botão pequeno
## de pausa no alto.
## Cada dedo é seguido pelo índice do toque: dá para acelerar e virar ao mesmo tempo, e
## arrastar o dedo de um botão para o outro troca o comando sem levantar.
## Os botões só disparam ações do InputMap; a moto não sabe que é toque.

const COLOR_IDLE := Color(1, 1, 1, 0.22)
const COLOR_PRESSED := Color(1, 1, 1, 0.5)
const COLOR_EDGE := Color(1, 1, 1, 0.6)

## [ação, rótulo, função que devolve o retângulo do botão]
var _buttons: Array = []
## índice do dedo -> ação sob ele ("" = nenhuma)
var _fingers := {}
var _pad: Control


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pad = Control.new()
	_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad.draw.connect(_draw_pad)
	add_child(_pad)
	_buttons = [
		["esquerda", "<", func(s: Vector2, u: float) -> Rect2: return Rect2(u * 0.4, s.y - u * 1.6, u * 1.2, u * 1.2)],
		["direita", ">", func(s: Vector2, u: float) -> Rect2: return Rect2(u * 1.8, s.y - u * 1.6, u * 1.2, u * 1.2)],
		["acelerar", "ACELERAR", func(s: Vector2, u: float) -> Rect2: return Rect2(s.x - u * 1.7, s.y - u * 2.3, u * 1.3, u * 1.9)],
		["freio_mao", "FREIO", func(s: Vector2, u: float) -> Rect2: return Rect2(s.x - u * 3.2, s.y - u * 1.4, u * 1.3, u * 1.0)],
		["pausar", "II", func(s: Vector2, u: float) -> Rect2: return Rect2(s.x * 0.5 - u * 0.3, u * 0.15, u * 0.6, u * 0.5)],
	]
	get_viewport().size_changed.connect(_pad.queue_redraw)


func _process(_delta: float) -> void:
	# Fora da pista (tela inicial, menus abertos, jogo pausado) os botões somem e soltam tudo.
	var show := not get_tree().paused and get_tree().get_first_node_in_group("player_bike") != null
	if show != _pad.visible:
		_pad.visible = show
		if not show:
			_release_all()


func _input(event: InputEvent) -> void:
	if not _pad.visible:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		_move_finger(touch.index, _action_at(touch.position) if touch.pressed else "")
		if touch.pressed and _fingers.get(touch.index, "") != "":
			get_viewport().set_input_as_handled()
		if not touch.pressed:
			_fingers.erase(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _fingers.has(drag.index):
			# A pausa só vale no toque, não arrastando para cima dela.
			var action := _action_at(drag.position)
			_move_finger(drag.index, "" if action == "pausar" else action)


## Troca a ação que o dedo segura (solta a anterior, aperta a nova).
func _move_finger(index: int, action: String) -> void:
	var old: String = _fingers.get(index, "")
	if old == action:
		return
	_fingers[index] = action
	if old != "" and not _held_by_other(old, index):
		_send(old, false)
	if action != "":
		_send(action, true)
	_pad.queue_redraw()


func _held_by_other(action: String, index: int) -> bool:
	for other in _fingers:
		if other != index and _fingers[other] == action:
			return true
	return false


func _send(action: String, pressed: bool) -> void:
	# Pelo parse_input_event: atualiza o estado das ações e também chega como evento (a pausa
	# é lida em _unhandled_input).
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)


func _release_all() -> void:
	var held := {}
	for index in _fingers:
		if _fingers[index] != "":
			held[_fingers[index]] = true
	_fingers.clear()
	for action in held:
		_send(action, false)
	_pad.queue_redraw()


func _unit() -> float:
	var size := _pad.get_viewport_rect().size
	return minf(size.y * 0.16, size.x * 0.09)


func _action_at(point: Vector2) -> String:
	var size := _pad.get_viewport_rect().size
	var unit := _unit()
	for button in _buttons:
		var rect: Rect2 = (button[2] as Callable).call(size, unit)
		# Um pouco de folga em volta: o polegar não precisa acertar a borda.
		if rect.grow(unit * 0.12).has_point(point):
			return button[0]
	return ""


func _draw_pad() -> void:
	var size := _pad.get_viewport_rect().size
	var unit := _unit()
	var held := {}
	for index in _fingers:
		held[_fingers[index]] = true
	var font := ThemeDB.get_default_theme().default_font
	if font == null:
		font = ThemeDB.fallback_font
	for button in _buttons:
		var rect: Rect2 = (button[2] as Callable).call(size, unit)
		var pressed := held.has(button[0])
		_pad.draw_rect(rect, COLOR_PRESSED if pressed else COLOR_IDLE)
		_pad.draw_rect(rect, COLOR_EDGE, false, 2.0)
		var label: String = button[1]
		if label == "<" or label == ">":
			# setas desenhadas (não dependem da fonte ter o caractere)
			var c := rect.get_center()
			var r := rect.size.x * 0.25
			var tip := -1.0 if label == "<" else 1.0
			_pad.draw_colored_polygon(PackedVector2Array([c + Vector2(r * tip, 0), c + Vector2(-r * tip, -r),
					c + Vector2(-r * tip, r)]), Color.WHITE)
			continue
		var font_size := int(unit * (0.45 if label.length() <= 2 else 0.2))
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var at := rect.get_center() + Vector2(-text_size.x * 0.5, text_size.y * 0.3)
		_pad.draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
