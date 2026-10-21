extends Control
## Tela inicial: escolhe a pista e começa. Nenhuma pista é carregada aqui; ao fundo passam as
## fotos panorâmicas da pista escolhida (assets/ui/panoramas, geradas por
## tools/shot_panoramas.gd), trocando devagar com um zoom lento. "INICIAR" carrega só a pista
## escolhida e a corrida já começa (sem o menu de pausa na largada).

const PlayerProfile := preload("res://scripts/core/player_profile.gd")
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")
const GAME_FONT := preload("res://assets/fonts/russo_one/RussoOne-Regular.ttf")
const SFX_MOVE := preload("res://assets/audio/sfx/ui_move.wav")
const SFX_SELECT := preload("res://assets/audio/sfx/ui_select.wav")
const PANORAMA_PATH := "res://assets/ui/panoramas/%s_%d.jpg"
const PANORAMA_COUNT := 3

## Tempo de cada foto e da troca entre elas (s); zoom ao longo de uma foto.
@export var photo_time: float = 6.0
@export var fade_time: float = 1.2
@export var zoom: float = 1.08
@export var color_bg: Color = Color(0.08, 0.07, 0.12, 0.92)
@export var color_edge: Color = Color("e8572a")

## Fundo desenhado à mão (em posição fracionária, sem arredondar para o pixel: o zoom lento
## não treme). A foto nova aparece por cima da anterior, que continua no zoom em que estava.
var _backdrop: Control
var _current: Texture2D
var _previous: Texture2D
var _previous_zoom := 1.0
var _fade := 1.0
var _photo_index := 0
var _clock := 0.0
var _track_button: Button
var _start_button: Button
var _menu: VBoxContainer
var _loading: Label
var _loading_path := ""
var _sfx: AudioStreamPlayer
var _textures: Array[Texture2D] = []


func _ready() -> void:
	ThemeDB.get_default_theme().default_font = GAME_FONT
	PlayerProfile.ensure_loaded()
	get_tree().paused = false
	_sfx = AudioStreamPlayer.new()
	_sfx.volume_db = -6.0
	_sfx.bus = &"Interface"
	add_child(_sfx)
	_backdrop = Control.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_backdrop.draw.connect(_draw_backdrop)
	add_child(_backdrop)
	_add_shade()
	_build_menu()
	_show_track(true)


func _process(delta: float) -> void:
	if _loading_path != "":
		_poll_loading()
		return
	_clock += delta
	_fade = minf(1.0, _fade + delta / fade_time)
	if _clock >= photo_time and _textures.size() > 1:
		_photo_index = (_photo_index + 1) % _textures.size()
		_crossfade(_textures[_photo_index])
	_backdrop.queue_redraw()


# ---------------------------------------------------------------- fundo

## Carrega as fotos da pista escolhida (só elas) e mostra a primeira.
func _show_track(instant := false) -> void:
	_track_button.text = PlayerProfile.track_name()
	_textures.clear()
	var id := PlayerProfile.track_scene().get_file().get_basename()
	for n in PANORAMA_COUNT:
		var path := PANORAMA_PATH % [id, n + 1]
		if ResourceLoader.exists(path):
			_textures.append(load(path) as Texture2D)
	_photo_index = 0
	if _textures.is_empty():
		return
	if instant:
		_current = _textures[0]
		_previous = null
		_fade = 1.0
		_clock = 0.0
	else:
		_crossfade(_textures[0])


func _crossfade(texture: Texture2D) -> void:
	_previous = _current
	_previous_zoom = _zoom_at(_clock)
	_current = texture
	_fade = 0.0
	_clock = 0.0


func _zoom_at(clock: float) -> float:
	var t := clampf(clock / (photo_time + fade_time), 0.0, 1.0)
	return lerpf(1.0, zoom, t)


func _draw_backdrop() -> void:
	if _previous and _fade < 1.0:
		_draw_cover(_previous, _previous_zoom, 1.0)
	if _current:
		_draw_cover(_current, _zoom_at(_clock), smoothstep(0.0, 1.0, _fade))


## Desenha a foto cobrindo a tela inteira (corta as sobras), ampliada em volta do centro.
func _draw_cover(texture: Texture2D, scale_by: float, alpha: float) -> void:
	var area := _backdrop.size
	var tex_size := texture.get_size()
	var fit := maxf(area.x / tex_size.x, area.y / tex_size.y) * scale_by
	var draw_size := tex_size * fit
	var rect := Rect2((area - draw_size) * 0.5, draw_size)
	_backdrop.draw_texture_rect(texture, rect, false, Color(1, 1, 1, alpha))


## Escurece o lado esquerdo (onde fica o menu) e um pouco embaixo.
func _add_shade() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0.78))
	gradient.set_color(1, Color(0, 0, 0, 0.0))
	gradient.set_offset(1, 0.65)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(1, 0)
	var shade := TextureRect.new()
	shade.texture = texture
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


# ---------------------------------------------------------------- menu

func _build_menu() -> void:
	_menu = VBoxContainer.new()
	_menu.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_menu.position = Vector2(70, -190)
	_menu.add_theme_constant_override("separation", 18)
	add_child(_menu)

	var title := _make_label("TURINHOS CIRCUIT", 58)
	_menu.add_child(title)
	_menu.add_child(_spacer(10))

	# Pista: < NOME >
	_menu.add_child(_make_label("PISTA", 22, Color(1, 1, 1, 0.7)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	# As setas são para o mouse e o toque; no teclado e no controle, a pista entra na lista
	# (cima/baixo) e, com ela selecionada, esquerda/direita trocam.
	var prev := _make_button("<", 34)
	prev.custom_minimum_size = Vector2(64, 64)
	prev.focus_mode = Control.FOCUS_NONE
	prev.pressed.connect(_change_track.bind(-1))
	row.add_child(_panel(prev))
	_track_button = _make_button("", 40)
	_track_button.custom_minimum_size = Vector2(300, 64)
	_track_button.pressed.connect(_change_track.bind(1))
	_track_button.gui_input.connect(func(event: InputEvent):
		for dir in [["ui_left", -1], ["ui_right", 1]]:
			if event.is_action_pressed(dir[0]):
				_track_button.accept_event()
				_change_track(dir[1]))
	row.add_child(_panel(_track_button))
	var next := _make_button(">", 34)
	next.custom_minimum_size = Vector2(64, 64)
	next.focus_mode = Control.FOCUS_NONE
	next.pressed.connect(_change_track.bind(1))
	row.add_child(_panel(next))
	_menu.add_child(row)
	_menu.add_child(_spacer(6))

	_start_button = _make_button("INICIAR", 36)
	_start_button.custom_minimum_size = Vector2(300, 72)
	_start_button.pressed.connect(_start)
	_menu.add_child(_panel(_start_button, true))
	var focusable: Array[Control] = [_track_button, _start_button]
	if not OS.has_feature("mobile"):
		var quit := _make_button("FECHAR JOGO", 26)
		quit.custom_minimum_size = Vector2(300, 56)
		quit.pressed.connect(func(): get_tree().quit())
		_menu.add_child(_panel(quit))
		focusable.append(quit)
	for i in focusable.size():
		var control := focusable[i]
		control.focus_neighbor_top = control.get_path_to(focusable[(i - 1 + focusable.size()) % focusable.size()])
		control.focus_neighbor_bottom = control.get_path_to(focusable[(i + 1) % focusable.size()])
		control.focus_neighbor_left = control.get_path_to(control)
		control.focus_neighbor_right = control.get_path_to(control)
	_start_button.grab_focus.call_deferred()

	_loading = _make_label("", 40)
	_loading.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_loading.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_loading.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_loading.position = Vector2(-60, -60)
	_loading.visible = false
	add_child(_loading)


func _change_track(step: int) -> void:
	PlayerProfile.set_track(PlayerProfile.track_index + step)
	_play(SFX_MOVE)
	_show_track()


## Carrega a pista escolhida em segundo plano; quando termina, troca de cena.
func _start() -> void:
	if _loading_path != "":
		return
	_play(SFX_SELECT)
	_menu.visible = false
	_loading.text = "CARREGANDO %s..." % PlayerProfile.track_name()
	_loading.visible = true
	_loading_path = PlayerProfile.track_scene()
	ResourceLoader.load_threaded_request(_loading_path)


func _poll_loading() -> void:
	var status := ResourceLoader.load_threaded_get_status(_loading_path)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	var scene := ResourceLoader.load_threaded_get(_loading_path) as PackedScene
	_loading_path = ""
	if scene == null:
		_loading.text = "ERRO AO CARREGAR A PISTA"
		_menu.visible = true
		return
	PauseMenu.skip_start_menu()
	AudioMix.hold()
	get_tree().change_scene_to_packed(scene)


# ---------------------------------------------------------------- peças

## Painel inclinado com a borda de baixo laranja (mesmo visual do menu de pausa).
func _panel(content: Control, strong := false) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color_edge if strong else color_bg
	style.border_color = color_edge.lightened(0.3) if strong else color_edge
	style.border_width_bottom = 4
	style.skew = Vector2(0.25, 0.0)
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(content)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return panel


func _make_label(text: String, font_size: int, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", maxi(6, font_size / 6))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _make_button(text: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.18) if state in ["hover", "pressed"] else Color(0, 0, 0, 0)
		style.draw_center = state != "focus"
		style.border_color = Color("ffd27a")
		style.border_width_left = 6 if state == "focus" else 0
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color("ffd27a"))
	button.focus_entered.connect(_play.bind(SFX_MOVE))
	return button


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	return spacer


func _play(stream: AudioStream) -> void:
	_sfx.stream = stream
	_sfx.play()
