extends Control
## HUD do andar livre: argolas de fogo atravessadas (cada uma conta uma vez), distância e tempo
## do último salto e o maior salto. Passar por uma argola mostra um aviso e toca o "fuuum".

@export var bike: Node  # Bike do jogador
## Nó com as argolas de fogo (qualquer filho com o sinal `passed`).
@export var rings_root: Node
@export var ring_sound: AudioStream

var _info: Label
var _banner: Label
var _banner_time := 0.0
var _passed := {}
var _ring_count := 0
var _sfx: AudioStreamPlayer
var _was_grounded := true
var _takeoff := Vector3.ZERO
var _best := 0.0
var _last := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info = _make_label(26, HORIZONTAL_ALIGNMENT_RIGHT)
	_info.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_info.offset_left = -520.0
	_info.offset_right = -24.0
	_info.offset_top = 16.0
	add_child(_info)
	_banner = _make_label(52, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -500.0
	_banner.offset_right = 500.0
	_banner.offset_top = 120.0
	_banner.add_theme_color_override("font_color", Color(1.0, 0.72, 0.25))
	_banner.modulate.a = 0.0
	add_child(_banner)
	_sfx = AudioStreamPlayer.new()
	_sfx.stream = ring_sound
	_sfx.volume_db = -4.0
	add_child(_sfx)
	if rings_root:
		for ring in rings_root.get_children():
			if ring.has_signal("passed"):
				_ring_count += 1
				ring.passed.connect(_on_ring_passed.bind(ring))
	_refresh()


func _make_label(size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", maxi(6, size / 6))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _physics_process(delta: float) -> void:
	_banner_time = maxf(_banner_time - delta, 0.0)
	_banner.modulate.a = clampf(_banner_time / 0.4, 0.0, 1.0)
	if bike == null or bike.is_crashed:
		_was_grounded = true
		return
	var grounded: bool = bike.is_grounded()
	if _was_grounded and not grounded:
		_takeoff = bike.global_position
	elif not _was_grounded and grounded:
		var flight := Vector2(bike.global_position.x - _takeoff.x, bike.global_position.z - _takeoff.z).length()
		if flight > 6.0:
			_last = "SALTO  %.0f m" % flight
			if flight > _best:
				_best = flight
				if flight > 15.0:
					_show("RECORDE!  %.0f m" % flight)
			_refresh()
	_was_grounded = grounded


func _on_ring_passed(body: Node, ring: Node) -> void:
	if body != bike:
		return
	var first := not _passed.has(ring)
	_passed[ring] = true
	_sfx.play()
	if first:
		_show("ARGOLA DE FOGO!  %d/%d" % [_passed.size(), _ring_count])
		if _passed.size() == _ring_count:
			_show("TODAS AS ARGOLAS!")
	else:
		_show("ARGOLA DE FOGO!")
	_refresh()


func _show(text: String) -> void:
	_banner.text = text
	_banner_time = 2.2


func _refresh() -> void:
	var lines := PackedStringArray()
	lines.append("ARGOLAS DE FOGO  %d/%d" % [_passed.size(), _ring_count])
	if _last != "":
		lines.append(_last)
	if _best > 0.0:
		lines.append("MAIOR SALTO  %.0f m" % _best)
	_info.text = "\n".join(lines)
