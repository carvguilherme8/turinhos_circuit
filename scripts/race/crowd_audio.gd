extends AudioStreamPlayer
## Torcida do estádio: o ambiente de fundo toca sempre (este nó) e, quando o jogador pousa uma
## manobra, a torcida vibra com um dos gritos de `cheer_streams` (sorteado). Quanto mais
## manobras no mesmo salto, mais alto.

@export var bike: Node  # Bike do jogador
@export var cheer_streams: Array[AudioStream] = []
## Volume do grito com uma manobra e quanto sobe a cada manobra a mais (dB).
@export var cheer_volume_db: float = -9.0
@export var cheer_volume_per_trick_db: float = 2.0
@export var cheer_max_volume_db: float = -3.0

var _cheer: AudioStreamPlayer
var _last_cheer: int = -1


func _ready() -> void:
	_cheer = AudioStreamPlayer.new()
	add_child(_cheer)
	if bike:
		bike.connect("tricks_landed", _on_tricks_landed)
	if not playing:
		play()


func _on_tricks_landed(names: PackedStringArray) -> void:
	if cheer_streams.is_empty():
		return
	# Sorteia um grito diferente do último (quando há mais de um).
	var index := randi() % cheer_streams.size()
	if cheer_streams.size() > 1 and index == _last_cheer:
		index = (index + 1) % cheer_streams.size()
	_last_cheer = index
	_cheer.stream = cheer_streams[index]
	_cheer.volume_db = minf(cheer_volume_db + cheer_volume_per_trick_db * (names.size() - 1), cheer_max_volume_db)
	_cheer.play()
