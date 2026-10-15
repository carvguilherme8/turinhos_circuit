@tool
class_name Stadium
extends Node3D
## Estádio em volta da arena retangular: muro com faixas de propaganda, arquibancadas em
## degraus (anel contínuo, com torcida na frente de cada degrau), torres de iluminação nos
## cantos e telão numa das pontas. Tudo gerado pelo script (visível no editor).

@export var arena_min: Vector2 = Vector2(-31, -54):
	set(value):
		arena_min = value
		_queue_rebuild()
@export var arena_max: Vector2 = Vector2(31, 64):
	set(value):
		arena_max = value
		_queue_rebuild()

@export_group("Muro")
@export var wall_height: float = 1.4
@export var wall_thickness: float = 0.5
## Comprimento de uma repetição da faixa de propaganda.
@export var banner_length: float = 8.0

@export_group("Arquibancada")
@export_range(1, 40) var tiers: int = 14:
	set(value):
		tiers = value
		_queue_rebuild()
@export var tier_depth: float = 1.2
@export var tier_rise: float = 0.7
## Largura de uma repetição da textura da torcida.
@export var crowd_tile: float = 2.0

@export_group("Iluminação")
@export var tower_height: float = 34.0
@export var tower_light_energy: float = 3.0
@export var tower_lights: bool = true

@export_group("Materiais")
@export var concrete_material: Material
@export var crowd_material: Material
@export var banner_material: Material
@export var metal_material: Material
@export var light_material: Material
@export var screen_material: Material
## Chão do lado de fora do estádio.
@export var outside_material: Material
@export var outside_size: float = 400.0

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
	_generated = Node3D.new()
	_generated.name = "_Generated"
	add_child(_generated)
	_build_wall()
	_build_stands()
	_build_towers()
	_build_jumbotron()
	_build_outside()


# ---------------------------------------------------------------- utilidades

## Retângulo da arena expandido por `offset` metros: [min, max].
func _rect(offset: float) -> Array[Vector2]:
	return [arena_min - Vector2.ONE * offset, arena_max + Vector2.ONE * offset]


## Quadrilátero com cantos TL, TR, BR, BL vistos de frente (lado da `normal`).
func _quad(st: SurfaceTool, tl: Vector3, tr: Vector3, br: Vector3, bl: Vector3,
		normal: Vector3, uv_size: Vector2) -> void:
	var uvs := [Vector2.ZERO, Vector2(uv_size.x, 0.0), uv_size, Vector2(0.0, uv_size.y)]
	var verts := [tl, tr, br, bl]
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_normal(normal)
		st.set_uv(uvs[k])
		st.add_vertex(verts[k])


## Faces internas (viradas para a arena) de um retângulo, entre as alturas y0 e y1.
func _inner_faces(st: SurfaceTool, rect: Array[Vector2], y0: float, y1: float, tile: Vector2) -> void:
	var lo := rect[0]
	var hi := rect[1]
	# Cantos no sentido horário visto de cima; cada lado olha para dentro.
	var sides := [
		[Vector2(lo.x, lo.y), Vector2(hi.x, lo.y), Vector3(0, 0, 1)],   # lado -Z, olha +Z
		[Vector2(hi.x, lo.y), Vector2(hi.x, hi.y), Vector3(-1, 0, 0)],  # lado +X, olha -X
		[Vector2(hi.x, hi.y), Vector2(lo.x, hi.y), Vector3(0, 0, -1)],  # lado +Z, olha -Z
		[Vector2(lo.x, hi.y), Vector2(lo.x, lo.y), Vector3(1, 0, 0)],   # lado -X, olha +X
	]
	for side in sides:
		var a: Vector2 = side[0]
		var b: Vector2 = side[1]
		var normal: Vector3 = side[2]
		var length := a.distance_to(b)
		# Vista de dentro da arena, `a` fica à esquerda e `b` à direita.
		_quad(st, Vector3(a.x, y1, a.y), Vector3(b.x, y1, b.y), Vector3(b.x, y0, b.y), Vector3(a.x, y0, a.y),
				normal, Vector2(length / tile.x, (y1 - y0) / tile.y))


## Anel horizontal (topo de um degrau) entre dois retângulos, na altura y.
func _ring_top(st: SurfaceTool, inner: Array[Vector2], outer: Array[Vector2], y: float) -> void:
	var i0 := inner[0]
	var i1 := inner[1]
	var o0 := outer[0]
	var o1 := outer[1]
	var corners_inner := [Vector2(i0.x, i0.y), Vector2(i1.x, i0.y), Vector2(i1.x, i1.y), Vector2(i0.x, i1.y)]
	var corners_outer := [Vector2(o0.x, o0.y), Vector2(o1.x, o0.y), Vector2(o1.x, o1.y), Vector2(o0.x, o1.y)]
	for k in 4:
		var a_in: Vector2 = corners_inner[k]
		var b_in: Vector2 = corners_inner[(k + 1) % 4]
		var a_out: Vector2 = corners_outer[k]
		var b_out: Vector2 = corners_outer[(k + 1) % 4]
		# Trapézio visto de cima; ordem horária = frente.
		var verts := [Vector3(a_out.x, y, a_out.y), Vector3(b_out.x, y, b_out.y),
				Vector3(b_in.x, y, b_in.y), Vector3(a_in.x, y, a_in.y)]
		for idx in [0, 1, 2, 0, 2, 3]:
			var v: Vector3 = verts[idx]
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(v.x, v.z))
			st.add_vertex(v)


func _box(parent: Node3D, pos: Vector3, size: Vector3, material: Material, collide := false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh.mesh = box
	mesh.position = pos
	parent.add_child(mesh)
	if collide:
		var body := StaticBody3D.new()
		body.position = pos
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
		parent.add_child(body)
	return mesh


func _commit(st: SurfaceTool, material: Material, node_name: String) -> void:
	st.set_material(material)
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = st.commit()
	_generated.add_child(mesh)


# ---------------------------------------------------------------- partes

func _build_wall() -> void:
	var size := arena_max - arena_min
	var center := (arena_max + arena_min) * 0.5
	var t := wall_thickness
	var h := wall_height
	var walls := [
		[Vector3(center.x, h * 0.5, arena_min.y - t * 0.5), Vector3(size.x + t * 2.0, h, t)],
		[Vector3(center.x, h * 0.5, arena_max.y + t * 0.5), Vector3(size.x + t * 2.0, h, t)],
		[Vector3(arena_min.x - t * 0.5, h * 0.5, center.y), Vector3(t, h, size.y)],
		[Vector3(arena_max.x + t * 0.5, h * 0.5, center.y), Vector3(t, h, size.y)],
	]
	for wall in walls:
		_box(_generated, wall[0], wall[1], concrete_material, true)

	# Faixas na face interna do muro (um pouco à frente para não brigar com o concreto).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_inner_faces(st, _rect(-0.01), 0.2, h - 0.15, Vector2(banner_length, h - 0.35))
	_commit(st, banner_material, "Banners")


func _build_stands() -> void:
	var crowd := SurfaceTool.new()
	crowd.begin(Mesh.PRIMITIVE_TRIANGLES)
	var concrete := SurfaceTool.new()
	concrete.begin(Mesh.PRIMITIVE_TRIANGLES)

	var start := wall_thickness + 0.4
	# Base de concreto atrás do muro até a primeira fileira.
	_inner_faces(concrete, _rect(start), 0.0, wall_height, Vector2.ONE)
	for k in tiers:
		var inner := _rect(start + k * tier_depth)
		var outer := _rect(start + (k + 1) * tier_depth)
		var y0 := wall_height + k * tier_rise
		var y1 := y0 + tier_rise
		_inner_faces(crowd, inner, y0, y1, Vector2(crowd_tile, tier_rise))
		_ring_top(concrete, inner, outer, y1)
	# Parapeito no alto e fundo da arquibancada.
	var top := wall_height + tiers * tier_rise
	var back := _rect(start + tiers * tier_depth)
	_inner_faces(concrete, back, top, top + 1.2, Vector2.ONE)
	_ring_top(concrete, back, _rect(start + tiers * tier_depth + 0.4), top + 1.2)
	_outer_faces(concrete, _rect(start + tiers * tier_depth + 0.4), 0.0, top + 1.2)
	_commit(crowd, crowd_material, "Crowd")
	_commit(concrete, concrete_material, "Stands")


## Faces externas (para fora do estádio) de um retângulo.
func _outer_faces(st: SurfaceTool, rect: Array[Vector2], y0: float, y1: float) -> void:
	var lo := rect[0]
	var hi := rect[1]
	var sides := [
		[Vector2(hi.x, lo.y), Vector2(lo.x, lo.y), Vector3(0, 0, -1)],
		[Vector2(hi.x, hi.y), Vector2(hi.x, lo.y), Vector3(1, 0, 0)],
		[Vector2(lo.x, hi.y), Vector2(hi.x, hi.y), Vector3(0, 0, 1)],
		[Vector2(lo.x, lo.y), Vector2(lo.x, hi.y), Vector3(-1, 0, 0)],
	]
	for side in sides:
		var a: Vector2 = side[0]
		var b: Vector2 = side[1]
		_quad(st, Vector3(a.x, y1, a.y), Vector3(b.x, y1, b.y), Vector3(b.x, y0, b.y), Vector3(a.x, y0, a.y),
				side[2], Vector2(a.distance_to(b), y1 - y0))


func _build_towers() -> void:
	var stands_out := wall_thickness + 0.4 + tiers * tier_depth + 3.0
	var rect := _rect(stands_out)
	var center := (arena_max + arena_min) * 0.5
	var target := Vector3(center.x, 0.0, center.y)
	for corner in [rect[0], Vector2(rect[1].x, rect[0].y), rect[1], Vector2(rect[0].x, rect[1].y)]:
		var base := Vector3(corner.x, 0.0, corner.y)
		_box(_generated, base + Vector3.UP * tower_height * 0.5, Vector3(1.4, tower_height, 1.4), metal_material)
		# Painel de luz virado para o centro da arena.
		var head := Node3D.new()
		head.position = base + Vector3.UP * (tower_height + 1.5)
		_generated.add_child(head)
		head.look_at(target, Vector3.UP)
		_box(head, Vector3.ZERO, Vector3(7.0, 3.6, 0.6), metal_material)
		var panel := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(6.4, 3.0)
		quad.material = light_material
		panel.mesh = quad
		panel.position.z = -0.31
		panel.rotation.y = PI  # QuadMesh olha para +Z; o painel olha para -Z (para a arena)
		head.add_child(panel)
		if tower_lights:
			var spot := SpotLight3D.new()
			spot.light_color = Color(1.0, 0.95, 0.85)
			spot.light_energy = tower_light_energy
			spot.spot_range = 160.0
			spot.spot_angle = 24.0
			spot.spot_attenuation = 0.4
			spot.position.z = -0.5
			head.add_child(spot)


func _build_jumbotron() -> void:
	var stands_out := wall_thickness + 0.4 + tiers * tier_depth
	var center := (arena_max + arena_min) * 0.5
	var z := arena_min.y - stands_out - 1.0
	var bottom := wall_height + tiers * tier_rise + 3.0
	var size := Vector2(18.0, 6.75)
	var frame := _box(_generated, Vector3(center.x, bottom + size.y * 0.5, z), Vector3(size.x + 1.0, size.y + 1.0, 1.0), metal_material)
	var screen := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	quad.material = screen_material
	screen.mesh = quad
	screen.position.z = 0.51
	frame.add_child(screen)
	for side in [-1.0, 1.0]:
		_box(_generated, Vector3(center.x + side * size.x * 0.35, bottom * 0.5, z - 0.2), Vector3(0.8, bottom, 0.8), metal_material)


func _build_outside() -> void:
	var center := (arena_max + arena_min) * 0.5
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * outside_size
	plane.material = outside_material
	ground.mesh = plane
	# Um pouco abaixo do chão da arena para não aparecer por baixo dele.
	ground.position = Vector3(center.x, -0.05, center.y)
	_generated.add_child(ground)
