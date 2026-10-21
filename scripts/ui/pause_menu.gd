extends CanvasLayer
## Menu de pausa (Esc / Start): os botões entram pelas laterais em escada, um depois do outro.
## Aberta direto pelo editor (F6), a pista começa nele (com "CORRER" no lugar de "RETOMAR");
## vinda da tela inicial, a corrida já começa. A contagem só anda com o menu fechado.
## À esquerda: retomar, trocar de pista (volta para a tela inicial), customizar piloto e fechar o jogo. A customização entra pela direita
## (o menu da esquerda sai, para a moto ficar à vista): número, cor do uniforme e cor da moto
## (a moto do jogador se repinta na hora).

const PlayerProfile := preload("res://scripts/core/player_profile.gd")
## Sons do menu: mover entre opções, confirmar e voltar.
const SFX_MOVE := preload("res://assets/audio/sfx/ui_move.wav")
const SFX_SELECT := preload("res://assets/audio/sfx/ui_select.wav")
const SFX_BACK := preload("res://assets/audio/sfx/ui_back.wav")
## Fonte de toda a interface (vira a fonte padrão do jogo).
const GAME_FONT := preload("res://assets/fonts/russo_one/RussoOne-Regular.ttf")

## Já saiu do menu inicial nesta sessão: reiniciar a corrida não volta para ele.
static var _race_started := false
const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"

## Abre o jogo no menu, antes da largada.
@export var start_in_menu: bool = true

## Tamanho e passo da escada (cada degrau desce e anda para o lado).
@export var step_size: Vector2 = Vector2(40.0, 84.0)
@export var button_size: Vector2 = Vector2(400.0, 64.0)
@export var row_size: Vector2 = Vector2(540.0, 64.0)
@export var slide_time: float = 0.35
@export var step_delay: float = 0.06
@export var color_bg: Color = Color(0.08, 0.07, 0.12, 0.96)
@export var color_edge: Color = Color("e8572a")

var _root: Control
var _dim: ColorRect
var _main_steps: Array[Control] = []
var _custom_steps: Array[Control] = []
var _custom_open := false
var _number_label: Label
var _suit_buttons: Array[Button] = []
var _bike_buttons: Array[Button] = []
var _tween: Tween
var _title: Label
var _first_button: Button
var _starting := false
var _sfx: AudioStreamPlayer
## Foco posto pelo próprio menu (ao abrir/trocar de painel): não toca o som de mover.
var _quiet_focus := false


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	ThemeDB.get_default_theme().default_font = GAME_FONT
	PlayerProfile.ensure_loaded()
	_sfx = AudioStreamPlayer.new()
	_sfx.volume_db = -6.0
	_sfx.bus = &"Interface"
	add_child(_sfx)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.02, 0.05, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_dim)
	_build_main()
	_build_custom()
	if start_in_menu and not _race_started:
		_start.call_deferred()


## A tela inicial chama isto antes de abrir a pista: a corrida começa sem o menu.
static func skip_start_menu() -> void:
	_race_started = true


func _start() -> void:
	open(true)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pausar") or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	if not _root.visible:
		_play(SFX_SELECT)
		open()
	elif _custom_open:
		_play(SFX_BACK)
		_close_custom()
	elif not _starting:
		_play(SFX_BACK)
		close()  # no menu inicial, só "CORRER" sai dele


## `start` = menu inicial (antes da largada).
func open(start := false) -> void:
	_starting = start
	_title.text = "TURINHOS CIRCUIT" if start else "PAUSA"
	# Mapa sem corrida (andar livre): "ANDAR" em vez de "CORRER".
	var scene := get_tree().current_scene
	var free_roam := scene != null and scene.find_child("RaceManager", false, false) == null
	_first_button.text = ("ANDAR" if free_roam else "CORRER") if start else "RETOMAR"
	get_tree().paused = true
	_root.visible = true
	_dim.modulate.a = 0.0
	_restart_tween()
	_tween.tween_property(_dim, "modulate:a", 1.0, slide_time)
	_slide(_main_steps, true, true)
	_focus_quietly.call_deferred(_first_button)


func close() -> void:
	_race_started = true
	_starting = false
	_restart_tween()
	_tween.tween_property(_dim, "modulate:a", 0.0, slide_time)
	if _custom_open:
		_slide(_custom_steps, false, false)
		_custom_open = false
	else:
		_slide(_main_steps, true, false)
	_tween.chain().tween_callback(func():
		_root.visible = false
		get_tree().paused = false)


# ---------------------------------------------------------------- montagem

func _build_main() -> void:
	_title = _make_label("PAUSA", 44)
	_main_steps.append(_add_step(_title, 0, true, Vector2(button_size.x, 56.0), false))
	var entries := [
		["RETOMAR", close],
		["TROCAR PISTA", _go_to_title],
		["CUSTOMIZAR PILOTO", _open_custom],
		["FECHAR JOGO", func(): get_tree().quit()],
	]
	for i in entries.size():
		var button := _make_button(entries[i][0], 28, i == entries.size() - 1)
		button.pressed.connect(entries[i][1])
		_main_steps.append(_add_step(button, i + 1, true, button_size))
		if i == 0:
			_first_button = button
	_link_focus(_main_steps.slice(1).map(func(step): return step.get_child(0)))


## Volta para a tela inicial (lá se escolhe a pista e começa de novo).
func _go_to_title() -> void:
	_race_started = false
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(TITLE_SCENE)


func _build_custom() -> void:
	var title := _make_label("SEU PILOTO", 40)
	_custom_steps.append(_add_step(title, 0, false, Vector2(row_size.x, 56.0), false))

	# Número: < 8 >
	var number_row := HBoxContainer.new()
	number_row.add_theme_constant_override("separation", 12)
	number_row.add_child(_make_label("NÚMERO", 26))
	number_row.get_child(0).custom_minimum_size.x = 130.0
	var minus := _make_button("<", 26)
	minus.custom_minimum_size = Vector2(56.0, 0.0)
	minus.pressed.connect(func(): _change(-1, 0, 0))
	number_row.add_child(minus)
	_number_label = _make_label("8", 36)
	_number_label.custom_minimum_size.x = 60.0
	_number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number_row.add_child(_number_label)
	var plus := _make_button(">", 26)
	plus.custom_minimum_size = Vector2(56.0, 0.0)
	plus.pressed.connect(func(): _change(1, 0, 0))
	number_row.add_child(plus)
	_custom_steps.append(_add_step(number_row, 1, false, row_size))

	# Cores do uniforme (principal com faixa do detalhe) e da moto.
	var suit_row := _swatch_row("UNIFORME", PlayerProfile.SUIT_COLORS.size(), _suit_buttons,
			func(i): return PlayerProfile.SUIT_COLORS[i][0],
			func(i): return PlayerProfile.SUIT_COLORS[i][1],
			func(i): _change(0, i - PlayerProfile.suit_index, 0))
	_custom_steps.append(_add_step(suit_row, 2, false, row_size))
	var bike_row := _swatch_row("MOTO", PlayerProfile.BIKE_COLORS.size(), _bike_buttons,
			func(i): return PlayerProfile.BIKE_COLORS[i],
			func(_i): return Color.TRANSPARENT,
			func(i): _change(0, 0, i - PlayerProfile.bike_index))
	_custom_steps.append(_add_step(bike_row, 3, false, row_size))

	var back := _make_button("VOLTAR", 28, true)
	back.pressed.connect(_close_custom)
	_custom_steps.append(_add_step(back, 4, false, Vector2(row_size.x * 0.6, button_size.y)))

	# Navegação: para os lados alterna entre as setas e percorre as cores (dando a volta);
	# para cima e para baixo troca de linha mantendo a coluna.
	_link_sideways([minus, plus])
	_link_sideways(_suit_buttons)
	_link_sideways(_bike_buttons)
	var last := _suit_buttons.size() - 1
	_link_vertical(minus, _suit_buttons[0])
	_link_vertical(plus, _suit_buttons[last])
	for i in _suit_buttons.size():
		_suit_buttons[i].focus_neighbor_top = _suit_buttons[i].get_path_to(minus if i < _suit_buttons.size() / 2.0 else plus)
		_link_vertical(_suit_buttons[i], _bike_buttons[mini(i, _bike_buttons.size() - 1)])
	for swatch in _bike_buttons:
		swatch.focus_neighbor_bottom = swatch.get_path_to(back)
	back.focus_neighbor_top = back.get_path_to(_bike_buttons[0])
	# VOLTAR é sozinho na linha: para os lados não sai dele.
	back.focus_neighbor_left = back.get_path_to(back)
	back.focus_neighbor_right = back.get_path_to(back)
	_refresh()


func _swatch_row(caption: String, count: int, buttons: Array[Button], main: Callable,
		stripe: Callable, on_pick: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var label := _make_label(caption, 26)
	label.custom_minimum_size.x = 130.0
	row.add_child(label)
	for i in count:
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(30.0, 40.0)
		swatch.set_meta("color", main.call(i))
		var band: Color = stripe.call(i)
		if band.a > 0.0:
			var line := ColorRect.new()
			line.color = band
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			line.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			line.offset_top = -12.0
			line.offset_bottom = -5.0
			line.offset_left = 5.0
			line.offset_right = -5.0
			swatch.add_child(line)
		swatch.pressed.connect(on_pick.bind(i))
		_add_sounds(swatch, false)
		row.add_child(swatch)
		buttons.append(swatch)
	return row


## Um degrau da escada: painel inclinado que entra pela esquerda (`left`) ou pela direita.
func _add_step(content: Control, index: int, left: bool, size: Vector2, framed := true) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color_bg if framed else Color(0, 0, 0, 0)
	style.border_color = color_edge
	style.set_border_width_all(0)
	style.border_width_bottom = 4 if framed else 0
	style.skew = Vector2(0.25, 0.0) if framed else Vector2.ZERO
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(content)
	panel.size = size
	panel.custom_minimum_size = size
	var y := 130.0 + index * step_size.y
	var x := 60.0 + index * step_size.x
	if not left:
		# À direita a escada desce em direção à borda (deixa o meio da tela livre).
		x = 60.0 + (4 - index) * step_size.x
	if left:
		panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		panel.set_meta("home", Vector2(x, y))
		panel.set_meta("away", Vector2(-size.x - 80.0, y))
	else:
		panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		panel.set_meta("home", Vector2(-size.x - x, y))
		panel.set_meta("away", Vector2(80.0, y))
	panel.position = panel.get_meta("away")
	panel.visible = false
	_root.add_child(panel)
	return panel


## Desliza os degraus para dentro ou para fora, cada um um pouco depois do anterior.
func _slide(steps: Array[Control], left: bool, entering: bool) -> void:
	var anchor := 0.0 if left else _root.size.x
	for i in steps.size():
		var step := steps[i]
		var home: Vector2 = step.get_meta("home") + Vector2(anchor, 0.0)
		var away: Vector2 = step.get_meta("away") + Vector2(anchor, 0.0)
		var order := i if entering else steps.size() - 1 - i
		if entering:
			step.position = away
			step.visible = true
		var tweener := _tween.parallel().tween_property(step, "position", home if entering else away, slide_time)
		tweener.set_delay(order * step_delay)
		tweener.set_trans(Tween.TRANS_BACK if entering else Tween.TRANS_CUBIC)
		tweener.set_ease(Tween.EASE_OUT if entering else Tween.EASE_IN)


func _open_custom() -> void:
	if _custom_open:
		return
	_custom_open = true
	_restart_tween()
	_slide(_main_steps, true, false)
	_slide(_custom_steps, false, true)
	_focus_quietly.call_deferred(_custom_steps[1].get_child(0).get_child(1))


func _close_custom() -> void:
	if not _custom_open:
		return
	_custom_open = false
	_restart_tween()
	_slide(_custom_steps, false, false)
	_slide(_main_steps, true, true)
	_focus_quietly.call_deferred(_main_steps[3].get_child(0))


func _restart_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_parallel(true)


func _change(number_step: int, suit_step: int, bike_step: int) -> void:
	PlayerProfile.set_values(PlayerProfile.number + number_step,
			PlayerProfile.suit_index + suit_step, PlayerProfile.bike_index + bike_step)
	_refresh()


## Mostra o número atual e destaca as cores escolhidas.
func _refresh() -> void:
	_number_label.text = str(PlayerProfile.number)
	for i in _suit_buttons.size():
		_style_swatch(_suit_buttons[i], i == PlayerProfile.suit_index)
	for i in _bike_buttons.size():
		_style_swatch(_bike_buttons[i], i == PlayerProfile.bike_index)


func _style_swatch(swatch: Button, selected: bool) -> void:
	var color: Color = swatch.get_meta("color")
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = color.lightened(0.15) if state == "hover" else color
		style.border_color = Color.WHITE if selected else (color_edge if state == "focus" else Color(0, 0, 0, 0.6))
		style.set_border_width_all(4 if selected or state == "focus" else 2)
		if state == "focus" and not selected:
			style.draw_center = false
		swatch.add_theme_stylebox_override(state, style)


# ---------------------------------------------------------------- peças

func _make_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", maxi(6, size / 6))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


## `back` = botão que volta ou fecha (toca o som de voltar).
func _make_button(text: String, size: int = 28, back := false) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = false
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", size)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0) if state == "normal" else Color(color_edge, 0.85 if state != "focus" else 0.0)
		style.draw_center = state != "focus"
		style.border_color = color_edge
		style.border_width_left = 6 if state == "focus" else 0
		style.content_margin_left = 12.0
		style.content_margin_right = 12.0
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color("ffd27a"))
	_add_sounds(button, back)
	return button


## Som ao passar por um botão (teclado, controle ou mouse) e ao apertá-lo.
func _add_sounds(button: Button, back: bool) -> void:
	button.focus_entered.connect(func():
		if not _quiet_focus:
			_play(SFX_MOVE))
	button.mouse_entered.connect(func():
		if not button.has_focus():
			_play(SFX_MOVE))
	button.pressed.connect(func(): _play(SFX_BACK if back else SFX_SELECT))


func _play(stream: AudioStream) -> void:
	_sfx.stream = stream
	_sfx.play()


func _focus_quietly(control: Control) -> void:
	_quiet_focus = true
	control.grab_focus()
	_quiet_focus = false


## Esquerda/direita percorre a lista e dá a volta nas pontas.
func _link_sideways(controls: Array) -> void:
	for i in controls.size():
		var control: Control = controls[i]
		control.focus_neighbor_left = control.get_path_to(controls[(i - 1 + controls.size()) % controls.size()])
		control.focus_neighbor_right = control.get_path_to(controls[(i + 1) % controls.size()])


func _link_vertical(upper: Control, lower: Control) -> void:
	upper.focus_neighbor_bottom = upper.get_path_to(lower)
	lower.focus_neighbor_top = lower.get_path_to(upper)


func _link_focus(controls: Array) -> void:
	for i in controls.size():
		var control: Control = controls[i]
		control.focus_neighbor_top = control.get_path_to(controls[(i - 1 + controls.size()) % controls.size()])
		control.focus_neighbor_bottom = control.get_path_to(controls[(i + 1) % controls.size()])
