extends Node
## Mixagem do jogo: cria os canais de áudio em tempo de execução (assim o arranjo fica legível
## no Git) e faz todos os sons de uma pista começarem juntos.
##
## Canais: Motor (o ronco das motos), Ambiente (chuva, torcida, vento), Efeitos (pneus, largada,
## gritos, argolas) e Interface (menus). No celular o alto-falante quase não toca graves: o motor
## perde ~7 dB e o resto (chuva, derrapagem, torcida) fica alto perto dele. Lá o motor sobe e o
## ambiente desce um pouco.
##
## Entrada na pista: montar a pista trava alguns quadros, e os sons que já começaram (vento,
## chuva, torcida, motores) tocariam antes dos outros. `hold()` silencia tudo antes de trocar de
## cena; quando a cena nova já rodou alguns quadros, todos os sons tocando recomeçam do zero,
## juntos, e o volume volta num fade curto.

const BUSES := ["Motor", "Ambiente", "Efeitos", "Interface"]
const MOBILE_OFFSETS := {"Motor": 5.0, "Ambiente": -3.0}
## Quadros da cena nova antes de soltar o som (o primeiro costuma ser o mais pesado).
const SETTLE_FRAMES := 3
const FADE_TIME := 0.25

var _held_scene_id := 0
var _settle := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus_name in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, &"Master")
		if OS.has_feature("mobile"):
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus_name), MOBILE_OFFSETS.get(bus_name, 0.0))


## Chamar logo antes de trocar ou recarregar a cena de uma pista.
func hold() -> void:
	var scene := get_tree().current_scene
	_held_scene_id = scene.get_instance_id() if scene else 0
	_settle = -1
	AudioServer.set_bus_mute(0, true)


func _process(_delta: float) -> void:
	if not AudioServer.is_bus_mute(0):
		return
	var scene := get_tree().current_scene
	if scene == null or scene.get_instance_id() == _held_scene_id:
		return
	if _settle < 0:
		_settle = SETTLE_FRAMES
	_settle -= 1
	if _settle > 0:
		return
	_release(scene)


func _release(scene: Node) -> void:
	for node in scene.find_children("*", "", true, false):
		if (node is AudioStreamPlayer or node is AudioStreamPlayer3D) and node.get("playing"):
			node.call("play", 0.0)
	var master_db := AudioServer.get_bus_volume_db(0)
	AudioServer.set_bus_volume_db(0, -40.0)
	AudioServer.set_bus_mute(0, false)
	var tween := create_tween()
	tween.tween_method(func(db: float): AudioServer.set_bus_volume_db(0, db), -40.0, master_db, FADE_TIME)
