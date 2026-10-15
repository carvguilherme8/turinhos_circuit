@tool
class_name StadiumTrack
extends Node3D
## Pista de supercross gerada a partir de um polígono de cantos (plano XZ).
## Os cantos viram curvas de raio `corner_radius`; dois cantos de 90° separados por 2x o raio
## formam uma curva em U (hairpin). Gera: chão da arena (com colisão), faixa de terra da pista,
## tuff blocks nas bordas (com colisão) e o arco de largada/chegada.
## As rampas ficam como nós Ramp separados na cena, para ajustar à mão.

## Cantos da linha central, em ordem de corrida (laço fechado). O percurso começa na
## curva do primeiro canto (aqui, a que entra na reta de largada).
@export var corners: PackedVector2Array = PackedVector2Array([
	Vector2(-21, 56), Vector2(-21, -45), Vector2(-7, -45), Vector2(-7, 45),
	Vector2(7, 45), Vector2(7, -45), Vector2(21, -45), Vector2(21, 56),
]):
	set(value):
		corners = value
		_queue_rebuild()
@export_range(4.0, 20.0, 0.5, "suffix:m") var track_width: float = 9.0:
	set(value):
		track_width = value
		_queue_rebuild()
@export_range(2.0, 20.0, 0.5, "suffix:m") var corner_radius: float = 7.0:
	set(value):
		corner_radius = value
		_queue_rebuild()
## Distância ao longo da pista (a partir do início da primeira curva) da largada/chegada.
@export var finish_distance: float = 20.0:
	set(value):
		finish_distance = value
		_queue_rebuild()

@export_group("Arena")
@export var arena_min: Vector2 = Vector2(-31, -54):
	set(value):
		arena_min = value
		_queue_rebuild()
@export var arena_max: Vector2 = Vector2(31, 64):
	set(value):
		arena_max = value
		_queue_rebuild()

@export_group("Tuff blocks")
@export var block_size: Vector3 = Vector3(0.6, 0.6, 1.1)
@export var block_gap: float = 0.08
@export var block_colors: PackedColorArray = PackedColorArray([Color("2a5ce8"), Color("f0f0f0")])

@export_group("Materiais")
@export var track_material: Material:
	set(value):
		track_material = value
		_queue_rebuild()
@export var infield_material: Material:
	set(value):
		infield_material = value
		_queue_rebuild()
@export var block_material: Material:
	set(value):
		block_material = value
		_queue_rebuild()
@export var finish_material: Material:
	set(value):
		finish_material = value
		_queue_rebuild()
@export var banner_material: Material:
	set(value):
		banner_material = value
		_queue_rebuild()
@export var metal_material: Material:
	set(value):
		metal_material = value
		_queue_rebuild()

## Linha central amostrada (pontos a cada ~0,5 m, laço fechado). Usada pelos bots e pela corrida.
var centerline: PackedVector2Array = PackedVector2Array()
## Distância percorrida até cada ponto da linha central, e o comprimento da volta.
var distances: PackedFloat32Array = PackedFloat32Array()
var length: float = 0.0

var _generated: Node3D
var _rebuild_queued: bool = false


func _ready() -> void:
	_rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	if _generated:
		_generated.free()
	# Nós gerados não têm dono: não são salvos na cena.
	_generated = Node3D.new()
	_generated.name = "_Generated"
	add_child(_generated)

	centerline = _sample_centerline(0.5)
	if centerline.size() < 3:
		return
	distances.resize(centerline.size())
	length = 0.0
	for i in centerline.size():
		distances[i] = length
		length += centerline[i].distance_to(centerline[(i + 1) % centerline.size()])
	_build_arena_floor()
	_build_track_surface()
	_build_blocks()
	_build_finish()


# ---------------------------------------------------------------- linha central

## Contorna os cantos com arcos e amostra a linha a cada `step` metros.
func _sample_centerline(step: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var n := corners.size()
	if n < 3:
		return points
	for i in n:
		var prev := corners[(i - 1 + n) % n]
		var corner := corners[i]
		var next := corners[(i + 1) % n]
		var d1 := (corner - prev).normalized()
		var d2 := (next - corner).normalized()
		var turn := d1.angle_to(d2)
		var tangent_len := corner_radius * tan(absf(turn) * 0.5)
		var arc_start := corner - d1 * tangent_len
		# Reta até o início do arco (vinda do fim do arco anterior).
		if not points.is_empty():
			_append_line(points, points[points.size() - 1], arc_start, step)
		else:
			points.append(arc_start)
		# Arco: centro do lado para onde a pista vira.
		var side := signf(turn)
		var center := arc_start + Vector2(-d1.y, d1.x) * side * corner_radius
		var start_angle := (arc_start - center).angle()
		var arc_len := absf(turn) * corner_radius
		var steps := maxi(1, ceili(arc_len / step))
		for s in range(1, steps + 1):
			var a := start_angle + turn * float(s) / steps
			points.append(center + Vector2(cos(a), sin(a)) * corner_radius)
	_append_line(points, points[points.size() - 1], points[0], step)
	points.remove_at(points.size() - 1)  # o último repete o primeiro
	return points


func _append_line(points: PackedVector2Array, from: Vector2, to: Vector2, step: float) -> void:
	var length := from.distance_to(to)
	var steps := maxi(1, ceili(length / step))
	for s in range(1, steps + 1):
		points.append(from.lerp(to, float(s) / steps))


## Direção da pista no ponto i (tangente média).
func _tangent(path: PackedVector2Array, i: int) -> Vector2:
	var n := path.size()
	return (path[(i + 1) % n] - path[(i - 1 + n) % n]).normalized()


## Lado direito de quem corre (no plano XZ): para frente -Z, direita é +X.
func _right(tangent: Vector2) -> Vector2:
	return Vector2(-tangent.y, tangent.x)


func _offset_path(offset: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in centerline.size():
		result.append(centerline[i] + _right(_tangent(centerline, i)) * offset)
	return result


# ---------------------------------------------------------------- geometria

func _build_arena_floor() -> void:
	var size := arena_max - arena_min
	var center := (arena_max + arena_min) * 0.5
	var body := StaticBody3D.new()
	body.name = "ArenaFloor"
	body.position = Vector3(center.x, -0.5, center.y)
	_generated.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, 1.0, size.y)
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = box.size
	box_mesh.material = infield_material
	mesh.mesh = box_mesh
	body.add_child(mesh)


## Faixa de terra mais clara por cima do chão da arena (só visual; a colisão é o chão).
func _build_track_surface() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := centerline.size()
	var half := track_width * 0.5
	var distance := 0.0
	for i in n:
		var j := (i + 1) % n
		var segment := centerline[i].distance_to(centerline[j])
		var ri := _right(_tangent(centerline, i)) * half
		var rj := _right(_tangent(centerline, j)) * half
		var quad := [centerline[i] - ri, centerline[i] + ri, centerline[j] + rj, centerline[j] - rj]
		# UV para o shader: x = distância lateral até a linha central, y = distância percorrida.
		var uvs := [Vector2(-half, distance), Vector2(half, distance),
				Vector2(half, distance + segment), Vector2(-half, distance + segment)]
		distance += segment
		# Ordem horária vista de cima (frente no Godot).
		for k in [0, 2, 1, 0, 3, 2]:
			var p: Vector2 = quad[k]
			st.set_normal(Vector3.UP)
			st.set_uv(uvs[k])
			st.add_vertex(Vector3(p.x, 0.02, p.y))
	st.set_material(track_material)
	var mesh := MeshInstance3D.new()
	mesh.name = "TrackSurface"
	mesh.mesh = st.commit()
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_generated.add_child(mesh)


## Fileiras de tuff blocks nas duas bordas, espaçadas pelo comprimento de cada borda
## (a borda de dentro das curvas é mais curta e recebe menos blocos).
func _build_blocks() -> void:
	var transforms: Array[Transform3D] = []
	var offset := track_width * 0.5 + block_size.x * 0.5
	for side in [-1.0, 1.0]:
		var path := _offset_path(offset * side)
		var spacing := block_size.z + block_gap
		var travelled := spacing  # força um bloco no começo
		for i in path.size():
			var a := path[i]
			var b := path[(i + 1) % path.size()]
			var segment := a.distance_to(b)
			travelled += segment
			if travelled < spacing:
				continue
			travelled = 0.0
			var tangent := (b - a).normalized()
			var basis := Basis.looking_at(Vector3(tangent.x, 0.0, tangent.y), Vector3.UP)
			transforms.append(Transform3D(basis, Vector3(a.x, block_size.y * 0.5, a.y)))

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	var box := BoxMesh.new()
	box.size = block_size
	box.material = block_material
	multimesh.mesh = box
	multimesh.instance_count = transforms.size()
	var body := StaticBody3D.new()
	body.name = "TuffBlocks"
	_generated.add_child(body)
	var shape_resource := BoxShape3D.new()
	shape_resource.size = block_size
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		multimesh.set_instance_color(i, block_colors[(i >> 1) % block_colors.size()])
		var shape := CollisionShape3D.new()
		shape.shape = shape_resource
		shape.transform = transforms[i]
		body.add_child(shape)
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	body.add_child(instance)


## Faixa quadriculada no chão e arco com faixa por cima.
func _build_finish() -> void:
	var index := _index_at_distance(finish_distance)
	var p := centerline[index]
	var tangent := _tangent(centerline, index)
	var basis := Basis.looking_at(Vector3(tangent.x, 0.0, tangent.y), Vector3.UP)
	var root := Node3D.new()
	root.name = "FinishLine"
	root.transform = Transform3D(basis, Vector3(p.x, 0.0, p.y))
	_generated.add_child(root)

	var line := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(track_width, 1.0)
	plane.material = finish_material
	line.mesh = plane
	line.position.y = 0.03
	root.add_child(line)

	var pillar_x := track_width * 0.5 + block_size.x + 0.8
	var height := 5.5
	var body := StaticBody3D.new()
	root.add_child(body)
	for side in [-1.0, 1.0]:
		_add_box(body, Vector3(side * pillar_x, height * 0.5, 0.0), Vector3(0.8, height, 0.8), metal_material, true)
	var span := pillar_x * 2.0 + 0.8
	_add_box(root, Vector3(0.0, height + 0.5, 0.0), Vector3(span, 1.0, 0.5), finish_material, false)
	# Faixa dos dois lados do arco.
	for z in [-0.26, 0.26]:
		var quad := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2(span - 1.0, 1.0)
		mesh.material = banner_material
		quad.mesh = mesh
		quad.position = Vector3(0.0, height - 0.6, z)
		if z < 0.0:
			quad.rotation.y = PI  # o QuadMesh olha para +Z
		root.add_child(quad)
	_add_box(root, Vector3(0.0, height - 0.6, 0.0), Vector3(span - 1.0, 1.0, 0.5), metal_material, false)


func _add_box(parent: Node3D, pos: Vector3, size: Vector3, material: Material, collide: bool) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh.mesh = box
	mesh.position = pos
	parent.add_child(mesh)
	if collide and parent is StaticBody3D:
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		shape.position = pos
		parent.add_child(shape)


func _index_at_distance(distance: float) -> int:
	var travelled := 0.0
	for i in centerline.size():
		var next := centerline[(i + 1) % centerline.size()]
		travelled += centerline[i].distance_to(next)
		if travelled >= distance:
			return i
	return 0


# ---------------------------------------------------------------- consultas (bots e corrida)

## Ponto da linha central mais perto de `pos`. Com `hint` >= 0, procura só perto dele
## (de `behind` pontos para trás até `ahead` para frente), o que evita "pular" para a reta
## vizinha; se ficar longe demais, faz a busca completa.
func closest_index(pos: Vector3, hint: int = -1, behind: int = 120, ahead: int = 120) -> int:
	var p := Vector2(pos.x, pos.z)
	var n := centerline.size()
	var best := 0
	var best_d := INF
	if hint >= 0:
		for k in range(-behind, ahead + 1):
			var i := posmod(hint + k, n)
			var d := p.distance_squared_to(centerline[i])
			if d < best_d:
				best_d = d
				best = i
		if best_d < 7.0 * 7.0:
			return best
	for i in n:
		var d := p.distance_squared_to(centerline[i])
		if d < best_d:
			best_d = d
			best = i
	return best


## Ponto mais perto só dentro da janela em volta de `hint` (sem busca completa).
func closest_index_near(pos: Vector3, hint: int, behind: int, ahead: int) -> int:
	var p := Vector2(pos.x, pos.z)
	var n := centerline.size()
	var best := posmod(hint, n)
	var best_d := INF
	for k in range(-behind, ahead + 1):
		var i := posmod(hint + k, n)
		var d := p.distance_squared_to(centerline[i])
		if d < best_d:
			best_d = d
			best = i
	return best


## Distância ao longo da pista a partir da linha de chegada (0..length).
func distance_from_finish(index: int) -> float:
	return fposmod(distances[index] - distances[_index_at_distance(finish_distance)], length)


func point_at(index: int) -> Vector2:
	return centerline[posmod(index, centerline.size())]


func tangent_at(index: int) -> Vector2:
	return _tangent(centerline, posmod(index, centerline.size()))


func right_at(index: int) -> Vector2:
	return _right(tangent_at(index))


func index_ahead(index: int, meters: float) -> int:
	return index + int(meters / 0.5)


## Posição e direção da linha de chegada (para montar o grid de largada).
func finish_transform() -> Transform3D:
	var i := _index_at_distance(finish_distance)
	var p := centerline[i]
	var t := _tangent(centerline, i)
	return Transform3D(Basis.looking_at(Vector3(t.x, 0.0, t.y), Vector3.UP), Vector3(p.x, 0.0, p.y))
