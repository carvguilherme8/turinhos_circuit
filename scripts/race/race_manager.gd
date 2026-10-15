class_name RaceManager
extends Node
## Corrida: monta o grid atrás da linha de chegada, faz a contagem regressiva, acompanha cada
## moto ao longo da pista (voltas e posição) e encerra quando o jogador completa as voltas.
## A ação "reiniciar_corrida" recarrega a cena (corrida do zero, marcas de pneu apagadas).

signal countdown_changed(value: int)  ## 3, 2, 1 e 0 (= VAI!)
signal race_started
signal lap_completed(bike: Bike, lap: int)
signal bike_finished(bike: Bike, position: int, time: float)
signal player_finished

enum State { COUNTDOWN, RACING, FINISHED }

@export var track: StadiumTrack
@export var player: Bike
## Todas as motos da corrida (inclusive o jogador), na ordem do grid (a 1ª larga na frente).
@export var bikes: Array[Bike] = []
@export var names: PackedStringArray = PackedStringArray()
@export_range(1, 20) var laps: int = 3
@export var countdown_seconds: float = 3.0
## Espaço entre as motos no grid: lateral e entre fileiras (m).
@export var grid_spacing: Vector2 = Vector2(3.2, 4.0)
## Longe da linha central mais que isso (além da meia largura da pista) = fora da pista.
@export var off_track_margin: float = 2.0
## Tempo fora da pista até a moto ser recolocada.
@export var off_track_time: float = 0.6

var state: State = State.COUNTDOWN
var race_time: float = 0.0

## Uma entrada por moto: progresso na pista, volta atual e chegada.
var entries: Array[Dictionary] = []
var _finish_order: Array[Dictionary] = []
var _countdown: float = 0.0
var _last_count: int = -1


func _ready() -> void:
	_countdown = countdown_seconds
	for i in bikes.size():
		var bike := bikes[i]
		bike.controls_enabled = false
		bike.set_spawn(_grid_transform(i))
		entries.append({
			"bike": bike,
			"name": names[i] if i < names.size() else bike.name,
			"index": -1,
			"lap": -1,  # atrás da linha: a primeira passagem é a largada
			"last_s": -1.0,
			"progress": 0.0,
			"finished": false,
			"time": 0.0,
			"off_time": 0.0,
		})


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reiniciar_corrida"):
		get_viewport().set_input_as_handled()
		restart()


func restart() -> void:
	get_tree().reload_current_scene()


func _physics_process(delta: float) -> void:
	if state == State.COUNTDOWN:
		_countdown -= delta
		var count := ceili(_countdown)
		if count != _last_count:
			_last_count = count
			countdown_changed.emit(maxi(count, 0))
		if _countdown <= 0.0:
			state = State.RACING
			for bike in bikes:
				bike.controls_enabled = true
			race_started.emit()
		return

	race_time += delta
	for entry in entries:
		_track_progress(entry, delta)


func _track_progress(entry: Dictionary, delta: float) -> void:
	var bike: Bike = entry["bike"]
	var hint: int = entry["index"]
	var index := track.closest_index(bike.global_position) if hint < 0 			else track.closest_index_near(bike.global_position, hint, 60, 120)
	# Fora da faixa (voou por cima dos blocos, cortou caminho): não conta e volta para a pista.
	var flat := Vector2(bike.global_position.x, bike.global_position.z)
	if hint >= 0 and not bike.is_crashed 			and flat.distance_to(track.point_at(index)) > track.track_width * 0.5 + off_track_margin:
		entry["off_time"] += delta
		if entry["off_time"] > off_track_time:
			_put_back_on_track(entry)
		return
	entry["off_time"] = 0.0
	entry["index"] = index
	var s := track.distance_from_finish(index)
	var last_s: float = entry["last_s"]
	var length := track.length
	if last_s >= 0.0:
		if last_s > length * 0.75 and s < length * 0.25:
			entry["lap"] += 1
			if entry["lap"] >= 1 and not entry["finished"]:
				lap_completed.emit(bike, entry["lap"])
			if entry["lap"] >= laps and not entry["finished"]:
				_finish(entry)
		elif last_s < length * 0.25 and s > length * 0.75:
			entry["lap"] -= 1  # voltou de ré pela linha
	entry["last_s"] = s
	entry["progress"] = entry["lap"] * length + s


func _finish(entry: Dictionary) -> void:
	entry["finished"] = true
	entry["time"] = race_time
	_finish_order.append(entry)
	var bike: Bike = entry["bike"]
	bike_finished.emit(bike, _finish_order.size(), race_time)
	if bike == player:
		state = State.FINISHED
		player.controls_enabled = false
		player_finished.emit()


## Classificação: quem já chegou (na ordem de chegada) e depois por progresso na pista.
func standings() -> Array[Dictionary]:
	var running: Array[Dictionary] = []
	for entry in entries:
		if not entry["finished"]:
			running.append(entry)
	running.sort_custom(func(a, b): return a["progress"] > b["progress"])
	var result: Array[Dictionary] = []
	result.append_array(_finish_order)
	result.append_array(running)
	return result


func position_of(bike: Bike) -> int:
	var list := standings()
	for i in list.size():
		if list[i]["bike"] == bike:
			return i + 1
	return list.size()


func lap_of(bike: Bike) -> int:
	for entry in entries:
		if entry["bike"] == bike:
			return clampi(entry["lap"] + 1, 1, laps)
	return 1


func _put_back_on_track(entry: Dictionary) -> void:
	var i: int = entry["index"] - 8
	var p := track.point_at(i)
	var t := track.tangent_at(i)
	var basis := Basis.looking_at(Vector3(t.x, 0.0, t.y), Vector3.UP)
	(entry["bike"] as Bike).place_at(Transform3D(basis, Vector3(p.x, 0.8, p.y)))
	entry["off_time"] = 0.0


## Grid em fileiras de duas motos, atrás da linha de chegada.
func _grid_transform(i: int) -> Transform3D:
	var finish := track.finish_transform()
	var row := int(i / 2.0)
	var side := -1.0 if i % 2 == 0 else 1.0
	var back := finish.basis.z * (3.0 + row * grid_spacing.y)  # +Z local = para trás
	var lateral := finish.basis.x * side * grid_spacing.x * 0.5
	var origin := finish.origin + back + lateral + Vector3.UP * 0.75
	return Transform3D(finish.basis, origin)
