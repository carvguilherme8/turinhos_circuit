extends Label
## Mostra no centro da tela o resultado de cada pouso e as quedas.

const SHOW_TIME := 1.2

@export var bike: Bike

var _timer: float = 0.0


func _ready() -> void:
	modulate.a = 0.0
	if bike:
		bike.landed.connect(_on_landed)
		bike.crashed.connect(_on_crashed)
		bike.tricks_landed.connect(_on_tricks)


func _process(delta: float) -> void:
	if _timer > 0.0:
		_timer -= delta
		# Some aos poucos no último terço do tempo.
		modulate.a = clampf(_timer / (SHOW_TIME / 3.0), 0.0, 1.0)


func _on_landed(quality: Bike.Landing, angle: float) -> void:
	if quality == Bike.Landing.PERFECT:
		_show("POUSO PERFEITO!", Color("7dff7a"))
	else:
		_show("Pouso torto (%d°)" % roundi(angle), Color("ffd24a"))


func _on_tricks(names: PackedStringArray) -> void:
	_show(" + ".join(names) + "!", Color("6fe3ff"))


func _on_crashed() -> void:
	_show("QUEDA!", Color("ff5a4a"))


func _show(message: String, color: Color) -> void:
	text = message
	add_theme_color_override("font_color", color)
	_timer = SHOW_TIME
	modulate.a = 1.0
