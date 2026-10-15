extends Control
## HUD da corrida: posição, volta e tempo no canto; contagem regressiva no centro; tela de
## resultado com a classificação e o botão de reiniciar quando o jogador termina.

@export var race: RaceManager

var _info: Label
var _countdown: Label
var _results: PanelContainer
var _results_list: Label
var _countdown_timer: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_info = _make_label(28, HORIZONTAL_ALIGNMENT_RIGHT)
	_info.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_info.offset_left = -360.0
	_info.offset_right = -24.0
	_info.offset_top = 16.0
	add_child(_info)

	_countdown = _make_label(96, HORIZONTAL_ALIGNMENT_CENTER)
	_countdown.set_anchors_preset(Control.PRESET_CENTER)
	_countdown.offset_left = -300.0
	_countdown.offset_right = 300.0
	_countdown.offset_top = -160.0
	_countdown.offset_bottom = -40.0
	add_child(_countdown)

	_build_results()

	if race:
		race.countdown_changed.connect(_on_countdown)
		race.player_finished.connect(_show_results)


func _make_label(size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", maxi(6, size / 6))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _build_results() -> void:
	_results = PanelContainer.new()
	_results.set_anchors_preset(Control.PRESET_CENTER)
	_results.offset_left = -260.0
	_results.offset_right = 260.0
	_results.offset_top = -190.0
	_results.offset_bottom = 190.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.12, 0.96)
	style.border_color = Color("e8572a")
	style.set_border_width_all(4)
	style.set_content_margin_all(24)
	_results.add_theme_stylebox_override("panel", style)
	_results.visible = false
	add_child(_results)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_results.add_child(box)
	var title := _make_label(40, HORIZONTAL_ALIGNMENT_CENTER)
	title.text = "RESULTADO"
	box.add_child(title)
	_results_list = _make_label(24, HORIZONTAL_ALIGNMENT_LEFT)
	box.add_child(_results_list)
	var button := Button.new()
	button.text = "Reiniciar corrida (Backspace)"
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(func(): race.restart())
	box.add_child(button)


func _process(delta: float) -> void:
	if race == null or race.player == null:
		return
	var position := race.position_of(race.player)
	_info.text = "%dº / %d\nVOLTA %d / %d\n%s" % [
		position, race.bikes.size(), race.lap_of(race.player), race.laps, _format_time(race.race_time)]
	if _countdown_timer > 0.0:
		_countdown_timer -= delta
		if _countdown_timer <= 0.0:
			_countdown.text = ""
	if _results.visible:
		_refresh_results()


func _on_countdown(value: int) -> void:
	if value > 0:
		_countdown.text = str(value)
		_countdown.add_theme_color_override("font_color", Color("ffd24a"))
	else:
		_countdown.text = "VAI!"
		_countdown.add_theme_color_override("font_color", Color("7dff7a"))
		_countdown_timer = 1.0


func _show_results() -> void:
	_results.visible = true
	_refresh_results()


func _refresh_results() -> void:
	var lines: PackedStringArray = []
	var list := race.standings()
	for i in list.size():
		var entry: Dictionary = list[i]
		var time := _format_time(entry["time"]) if entry["finished"] else "volta %d" % clampi(entry["lap"] + 1, 1, race.laps)
		lines.append("%dº  %s   %s" % [i + 1, entry["name"], time])
	_results_list.text = "\n".join(lines)


func _format_time(seconds: float) -> String:
	var minutes := int(seconds / 60.0)
	return "%d:%05.2f" % [minutes, seconds - minutes * 60.0]
