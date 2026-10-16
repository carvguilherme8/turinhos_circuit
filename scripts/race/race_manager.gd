class_name RaceManager
extends Node
## Corrida: monta o grid atrás da linha de chegada, faz a contagem regressiva, acompanha cada
## moto ao longo da pista (voltas e posição) e encerra quando o jogador completa as voltas.
## A ação "reiniciar_corrida" recarrega a cena (corrida do zero, marcas de pneu apagadas).
## Também decide para onde a moto volta (R, queda, fora da pista, bot travado): para a pista
## no último ponto válido ou, se ela parou no vão de um salto, para antes dele com embalo.

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
## Nó com as rampas da pista (para achar os saltos com vão entre kicker e pouso).
@export var ramps: Node
## Distância livre antes de um salto ao voltar para ele (embalo suficiente para passar).
@export var runup_meters: float = 32.0
## Sons da largada: bipe do 3-2-1 e do "VAI!".
@export var countdown_sound: AudioStream
@export var go_sound: AudioStream

var state: State = State.COUNTDOWN
var race_time: float = 0.0

## Uma entrada por moto: progresso na pista, volta atual e chegada.
var entries: Array[Dictionary] = []
var _finish_order: Array[Dictionary] = []
var _countdown: float = 0.0
var _last_count: int = -1
## Trechos ocupados por rampas e saltos com vão, em índices da linha central: [início, fim].
var _ramp_spans: Array[Vector2i] = []
var _jump_spans: Array[Vector2i] = []
var _start_audio: AudioStreamPlayer


func _ready() -> void:
	_countdown = countdown_seconds
	_start_audio = AudioStreamPlayer.new()
	_start_audio.volume_db = -4.0
	add_child(_start_audio)
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
		bike.recover_requested.connect(_recover.bind(entries[-1]))
	_map_ramps()


func _play_start_sound(is_count: bool) -> void:
	var sound := countdown_sound if is_count else go_sound
	if sound:
		_start_audio.stream = sound
		_start_audio.play()


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
			_play_start_sound(count > 0)
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
			_recover(entry)
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


# ---------------------------------------------------------------- volta para a pista

## Põe a moto de volta na pista: no último ponto válido (um pouco atrás) ou, se ela parou
## no vão de um salto, antes dele com embalo suficiente para passar.
func _recover(entry: Dictionary) -> void:
	var bike: Bike = entry["bike"]
	var index: int = entry["index"]
	if index < 0:
		index = track.closest_index(bike.global_position)
	var target := index - 4
	for span in _jump_spans:
		if _span_contains(span, index):
			target = _runup_start(span.x)
			break
	target = posmod(target, track.centerline.size())
	var p := track.point_at(target)
	var t := track.tangent_at(target)
	var basis := Basis.looking_at(Vector3(t.x, 0.0, t.y), Vector3.UP)
	bike.place_at(Transform3D(basis, Vector3(p.x, _ground_height(p) + 0.75, p.y)))
	entry["index"] = target
	entry["off_time"] = 0.0


## Volta `runup_meters` antes de `start`; se houver outra rampa nesse trecho, volta para antes
## dela também (nunca reaparece em cima de uma rampa nem sem espaço para embalar).
func _runup_start(start: int) -> int:
	var n := track.centerline.size()
	var runup := int(runup_meters / 0.5)
	var target := start
	for _attempt in 10:
		var candidate := target - runup
		var blocked := false
		for span in _ramp_spans:
			if span.x == target:
				continue
			# A rampa começa ou termina dentro de [candidato, alvo)?
			var from_candidate := posmod(span.x - candidate, n)
			var end_from_candidate := posmod(span.y - candidate, n)
			if from_candidate < runup or end_from_candidate < runup:
				target = span.x
				blocked = true
				break
		if not blocked:
			return candidate
	return target - runup


func _span_contains(span: Vector2i, index: int) -> bool:
	var n := track.centerline.size()
	return posmod(index - span.x, n) <= posmod(span.y - span.x, n)


## Descobre onde cada rampa fica ao longo da pista e quais pares kicker + pouso formam um salto.
func _map_ramps() -> void:
	_ramp_spans.clear()
	_jump_spans.clear()
	if ramps == null:
		return
	var n := track.centerline.size()
	var kickers: Array[Vector2i] = []
	var landings: Array[Vector2i] = []
	for child in ramps.get_children():
		var ramp := child as Ramp
		if ramp == null:
			continue
		var extent := ramp.world_extent()
		var span := Vector2i(track.closest_index(extent[0]), track.closest_index(extent[1]))
		_ramp_spans.append(span)
		if ramp.is_kicker():
			kickers.append(span)
		elif ramp.is_landing():
			landings.append(span)
	for kicker in kickers:
		var best := -1
		var best_gap := n
		for i in landings.size():
			var gap := posmod(landings[i].x - kicker.y, n)
			if gap < best_gap and gap < 80:  # pouso até ~40 m depois do kicker
				best_gap = gap
				best = i
		if best >= 0:
			_jump_spans.append(Vector2i(kicker.x, landings[best].y))


func _ground_height(p: Vector2) -> float:
	var space := track.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(p.x, 40.0, p.y), Vector3(p.x, -5.0, p.y), 1 | 2)
	var exclude: Array[RID] = []
	for bike in bikes:
		exclude.append(bike.get_rid())
	query.exclude = exclude
	var hit := space.intersect_ray(query)
	return hit["position"].y if hit else 0.0


## Grid em fileiras de duas motos, atrás da linha de chegada.
func _grid_transform(i: int) -> Transform3D:
	var finish := track.finish_transform()
	var row := int(i / 2.0)
	var side := -1.0 if i % 2 == 0 else 1.0
	var back := finish.basis.z * (3.0 + row * grid_spacing.y)  # +Z local = para trás
	var lateral := finish.basis.x * side * grid_spacing.x * 0.5
	var origin := finish.origin + back + lateral + Vector3.UP * 0.75
	return Transform3D(finish.basis, origin)
