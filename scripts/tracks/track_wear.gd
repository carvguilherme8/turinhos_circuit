class_name TrackWear
extends Node
## Marcas de pneu que se acumulam: uma imagem cobrindo a arena (pixels_per_meter por metro)
## guarda o desgaste do chão. Cada roda no chão risca do ponto anterior até o atual; cada
## passada soma, então o trajeto mais usado fica cada vez mais marcado. Os materiais de terra
## (shader pixel_dirt) escurecem o chão de acordo com essa imagem.

@export var bike: Bike
@export var arena_min: Vector2 = Vector2(-31, -54)
@export var arena_max: Vector2 = Vector2(31, 64)
## 8 px/m = pixels de 12,5 cm, mais ou menos a largura de um pneu.
@export var pixels_per_meter: float = 8.0
## Quanto uma passada marca (0..1). Algumas passadas no mesmo lugar chegam ao máximo.
@export_range(0.0, 1.0, 0.01) var mark_strength: float = 0.25
## Marca extra do pneu arrastando (derrapagem, freada forte).
@export_range(0.0, 1.0, 0.01) var skid_strength: float = 0.2
## Materiais de terra que mostram as marcas.
@export var materials: Array[ShaderMaterial] = []
## Intervalo entre envios da imagem para a placa de vídeo.
@export var upload_interval: float = 0.05

var _image: Image
var _texture: ImageTexture
var _size: Vector2i
var _last_pixel := {"front": Vector2i(-1, -1), "rear": Vector2i(-1, -1)}
var _dirty: bool = false
var _upload_timer: float = 0.0


func _ready() -> void:
	var meters := arena_max - arena_min
	_size = Vector2i(ceili(meters.x * pixels_per_meter), ceili(meters.y * pixels_per_meter))
	_image = Image.create(_size.x, _size.y, false, Image.FORMAT_R8)
	_texture = ImageTexture.create_from_image(_image)
	for material in materials:
		material.set_shader_parameter("wear", _texture)
		material.set_shader_parameter("wear_origin", arena_min)
		material.set_shader_parameter("wear_size", meters)
		material.set_shader_parameter("use_wear", true)
	if bike:
		bike.respawned.connect(_forget_last)


func _exit_tree() -> void:
	# Os materiais são recursos compartilhados: desliga as marcas ao sair da cena.
	for material in materials:
		material.set_shader_parameter("use_wear", false)


func _physics_process(delta: float) -> void:
	if bike == null:
		return
	var moving := absf(bike.forward_speed) > 0.8 or bike.skid > 0.2
	_track_wheel("front", bike.front_grounded and moving and not bike.is_crashed, bike.front_contact, 0.0)
	_track_wheel("rear", bike.rear_grounded and moving and not bike.is_crashed, bike.rear_contact, bike.skid)

	_upload_timer -= delta
	if _dirty and _upload_timer <= 0.0:
		_texture.update(_image)
		_dirty = false
		_upload_timer = upload_interval


func _track_wheel(key: String, grounded: bool, contact: Vector3, skid: float) -> void:
	if not grounded:
		_last_pixel[key] = Vector2i(-1, -1)
		return
	var pixel := _to_pixel(contact)
	var last: Vector2i = _last_pixel[key]
	_last_pixel[key] = pixel
	if last.x < 0 or last == pixel:
		return
	# Salto grande entre dois passos = moto reposicionada: não risca a pista inteira.
	if Vector2(pixel - last).length() > 3.0 * pixels_per_meter:
		return
	var amount := mark_strength + skid * skid_strength
	# Pneu arrastando deixa uma marca mais larga.
	var wide := skid > 0.35
	for p in _line(last, pixel):
		if p == last:
			continue
		_stamp(p, amount)
		if wide:
			var direction := Vector2(pixel - last).normalized()
			var side := Vector2i(roundi(-direction.y), roundi(direction.x))
			_stamp(p + side, amount * 0.7)


func _stamp(p: Vector2i, amount: float) -> void:
	if p.x < 0 or p.y < 0 or p.x >= _size.x or p.y >= _size.y:
		return
	var value := minf(_image.get_pixel(p.x, p.y).r + amount, 1.0)
	_image.set_pixel(p.x, p.y, Color(value, 0.0, 0.0))
	_dirty = true


func _to_pixel(world: Vector3) -> Vector2i:
	return Vector2i(floori((world.x - arena_min.x) * pixels_per_meter),
			floori((world.z - arena_min.y) * pixels_per_meter))


## Pixels de uma linha (Bresenham), incluindo as duas pontas.
func _line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var d := Vector2i(absi(b.x - a.x), -absi(b.y - a.y))
	var step := Vector2i(1 if a.x < b.x else -1, 1 if a.y < b.y else -1)
	var error := d.x + d.y
	var p := a
	for _i in 512:
		points.append(p)
		if p == b:
			break
		var e2 := 2 * error
		if e2 >= d.y:
			error += d.y
			p.x += step.x
		if e2 <= d.x:
			error += d.x
			p.y += step.y
	return points


func _forget_last() -> void:
	_last_pixel["front"] = Vector2i(-1, -1)
	_last_pixel["rear"] = Vector2i(-1, -1)
