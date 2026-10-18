extends RefCounted
## Visual do piloto do jogador (número, cor do uniforme e da moto) e a pista escolhida, salvos
## em user:// e mantidos entre corridas. Tudo estático: qualquer script usa com
## `const PlayerProfile := preload("res://scripts/core/player_profile.gd")`.

const SAVE_PATH := "user://player_profile.cfg"

## Pistas que dá para escolher no menu: [nome, cena].
const TRACKS: Array[Array] = [
	["ESTÁDIO", "res://scenes/tracks/stadium_circuit.tscn"],
	["FAZENDA", "res://scenes/tracks/farm_circuit.tscn"],
	["DESERTO", "res://scenes/tracks/desert_park.tscn"],
]

## Cores do uniforme: [principal, detalhe]. O detalhe contrasta com a principal.
const SUIT_COLORS: Array[Array] = [
	[Color("2a5ce8"), Color("f0d23c")],
	[Color("e83a3a"), Color("f2f2ec")],
	[Color("2fb35a"), Color("f0d23c")],
	[Color("f0a020"), Color("2a2a34")],
	[Color("8a3ad8"), Color("40e0d0")],
	[Color("1a1a22"), Color("e8572a")],
	[Color("e84aa8"), Color("2a2a34")],
	[Color("20b8c8"), Color("f2f2ec")],
	[Color("f2f2ec"), Color("e83a3a")],
]
const BIKE_COLORS: Array[Color] = [
	Color("e8572a"), Color("2a5ce8"), Color("2fb35a"), Color("f0d23c"), Color("e83a3a"),
	Color("8a3ad8"), Color("1a1a22"), Color("f2f2ec"), Color("20b8c8"),
]

static var number: int = 8
static var suit_index: int = 0
static var bike_index: int = 0
static var track_index: int = 0
static var _loaded := false
## Chamadas sem argumentos quando algo muda (a moto do jogador se repinta).
static var _listeners: Array[Callable] = []


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	number = clampi(cfg.get_value("piloto", "numero", number), 0, 9)
	suit_index = clampi(cfg.get_value("piloto", "uniforme", suit_index), 0, SUIT_COLORS.size() - 1)
	bike_index = clampi(cfg.get_value("piloto", "moto", bike_index), 0, BIKE_COLORS.size() - 1)
	track_index = clampi(cfg.get_value("jogo", "pista", track_index), 0, TRACKS.size() - 1)


static func set_values(new_number: int, new_suit: int, new_bike: int) -> void:
	ensure_loaded()
	number = wrapi(new_number, 0, 10)
	suit_index = wrapi(new_suit, 0, SUIT_COLORS.size())
	bike_index = wrapi(new_bike, 0, BIKE_COLORS.size())
	_save()
	for listener in _listeners.duplicate():
		if listener.is_valid():
			listener.call()
		else:
			_listeners.erase(listener)


static func set_track(index: int) -> void:
	ensure_loaded()
	track_index = wrapi(index, 0, TRACKS.size())
	_save()


static func track_name() -> String:
	return TRACKS[track_index][0]


static func track_scene() -> String:
	return TRACKS[track_index][1]


static func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("piloto", "numero", number)
	cfg.set_value("piloto", "uniforme", suit_index)
	cfg.set_value("piloto", "moto", bike_index)
	cfg.set_value("jogo", "pista", track_index)
	cfg.save(SAVE_PATH)


static func listen(callable: Callable) -> void:
	_listeners.append(callable)


static func suit_color() -> Color:
	return SUIT_COLORS[suit_index][0]


static func accent_color() -> Color:
	return SUIT_COLORS[suit_index][1]


static func bike_color() -> Color:
	return BIKE_COLORS[bike_index]
