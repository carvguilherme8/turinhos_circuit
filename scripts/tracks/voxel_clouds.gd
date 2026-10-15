@tool
class_name VoxelClouds
extends Node3D
## Camada de nuvens em blocos (como as do Minecraft): um mapa de células cheias/vazias vira
## blocos achatados no alto do céu, que andam devagar. O mapa se repete sem emenda, então
## duas cópias lado a lado cobrem o céu enquanto deslizam.

@export var cells: Vector2i = Vector2i(80, 80):
	set(value):
		cells = value
		_queue_rebuild()
@export var cell_size: float = 12.0:
	set(value):
		cell_size = value
		_queue_rebuild()
@export var thickness: float = 4.0:
	set(value):
		thickness = value
		_queue_rebuild()
@export var altitude: float = 85.0:
	set(value):
		altitude = value
		_queue_rebuild()
## Fração do céu coberta (0 = limpo, 1 = fechado).
@export_range(0.0, 1.0, 0.01) var coverage: float = 0.38:
	set(value):
		coverage = value
		_queue_rebuild()
## Tamanho das nuvens (menor = nuvens maiores).
@export var noise_frequency: float = 0.09:
	set(value):
		noise_frequency = value
		_queue_rebuild()
@export var noise_seed: int = 3:
	set(value):
		noise_seed = value
		_queue_rebuild()
## Velocidade do vento (m/s, ao longo de +X).
@export var wind_speed: float = 2.5
@export var color: Color = Color(1, 0.97, 0.95):
	set(value):
		color = value
		_queue_rebuild()
## Brilho próprio das nuvens (luz do pôr do sol batendo nelas).
@export var glow_color: Color = Color(1.0, 0.62, 0.5):
	set(value):
		glow_color = value
		_queue_rebuild()
@export_range(0.0, 2.0, 0.01) var glow_energy: float = 0.35:
	set(value):
		glow_energy = value
		_queue_rebuild()

var _layers: Array[MultiMeshInstance3D] = []
var _offset: float = 0.0
var _rebuild_queued: bool = false


func _ready() -> void:
	_rebuild()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _layers.is_empty():
		return
	var width := cells.x * cell_size
	_offset = fposmod(_offset + wind_speed * delta, width)
	for i in _layers.size():
		_layers[i].position.x = _offset + (i - 1) * width


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	for layer in _layers:
		layer.free()
	_layers.clear()

	var mask := _cloud_mask()
	var multimesh := _build_multimesh(mask)
	# Três cópias (à esquerda, no centro e à direita) para cobrir o céu enquanto deslizam.
	var width := cells.x * cell_size
	for i in 3:
		var layer := MultiMeshInstance3D.new()
		layer.multimesh = multimesh
		layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		layer.position = Vector3((i - 1) * width, 0.0, 0.0)
		add_child(layer)
		_layers.append(layer)


## Mapa repetível: o ruído de cada célula é misturado com o do lado oposto do mapa,
## então a borda direita emenda com a esquerda (e a de cima com a de baixo).
func _cloud_mask() -> Array:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = noise_frequency
	noise.fractal_octaves = 3
	var w := cells.x
	var h := cells.y
	var values: Array[float] = []
	var sorted: Array[float] = []
	for y in h:
		for x in w:
			var fx := float(x) / w
			var fy := float(y) / h
			var a := noise.get_noise_2d(x, y)
			var b := noise.get_noise_2d(x - w, y)
			var c := noise.get_noise_2d(x, y - h)
			var d := noise.get_noise_2d(x - w, y - h)
			var v := lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)
			values.append(v)
			sorted.append(v)
	sorted.sort()
	var threshold := sorted[clampi(int((1.0 - coverage) * sorted.size()), 0, sorted.size() - 1)]
	var mask: Array = []
	for y in h:
		var row: Array[bool] = []
		for x in w:
			row.append(values[y * w + x] > threshold)
		mask.append(row)
	return mask


## Junta células vizinhas da mesma linha num bloco só (menos instâncias).
func _build_multimesh(mask: Array) -> MultiMesh:
	var transforms: Array[Transform3D] = []
	var half := Vector2(cells.x, cells.y) * cell_size * 0.5
	for y in cells.y:
		var row: Array = mask[y]
		var x := 0
		while x < cells.x:
			if not row[x]:
				x += 1
				continue
			var start := x
			while x < cells.x and row[x]:
				x += 1
			var length := (x - start) * cell_size
			var center := Vector3(start * cell_size + length * 0.5 - half.x, altitude, (y + 0.5) * cell_size - half.y)
			var basis := Basis.from_scale(Vector3(length, thickness, cell_size))
			transforms.append(Transform3D(basis, center))

	var material := StandardMaterial3D.new()
	# Opacas, como as nuvens "rápidas" do Minecraft (sem listras entre os blocos).
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = glow_color
	material.emission_energy_multiplier = glow_energy
	material.roughness = 1.0
	material.disable_receive_shadows = true
	var box := BoxMesh.new()
	box.material = material

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = box
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	return multimesh
