@tool
class_name Ramp
extends StaticBody3D
## Rampa low poly paramétrica (malha e colisão geradas pelo script, visíveis no editor).
## Perfil visto de lado, avançando para -Z a partir da origem: subida -> topo plano -> descida.
## - Kicker: descida = 0 (a traseira vira uma rampa íngreme).
## - Rampa de pouso: subida = 0 (a frente vira uma rampa íngreme, para trás da origem).
## - Mesa (tabletop): os três maiores que zero.
## Os cantos são arredondados: base côncava saindo do chão e crista convexa.

@export_range(0.0, 40.0, 0.1, "suffix:m") var up_length: float = 6.0:
	set(value):
		up_length = value
		_rebuild()
@export_range(0.0, 40.0, 0.1, "suffix:m") var top_length: float = 0.0:
	set(value):
		top_length = value
		_rebuild()
@export_range(0.0, 40.0, 0.1, "suffix:m") var down_length: float = 0.0:
	set(value):
		down_length = value
		_rebuild()
@export_range(0.1, 15.0, 0.1, "suffix:m") var height: float = 1.5:
	set(value):
		height = value
		_rebuild()
@export_range(0.5, 30.0, 0.1, "suffix:m") var width: float = 5.0:
	set(value):
		width = value
		_rebuild()
@export var color: Color = Color("a0703f"):
	set(value):
		color = value
		_rebuild()
## Ondulação (costela): fica na camada de colisão 2. As rodas sempre a enxergam, mas o corpo
## da moto atravessa a crista enquanto desliza empinada (ver Bike.skimming).
@export var is_bump: bool = false
## Material opcional (ex.: terra pixelada com UV triplanar). Sem ele, usa `color`.
@export var material: Material:
	set(value):
		material = value
		_rebuild()

@export_group("Formato")
## Raio do arredondamento da crista e do topo (convexo).
@export_range(0.0, 5.0, 0.05, "suffix:m") var crest_radius: float = 0.7:
	set(value):
		crest_radius = value
		_rebuild()
## Raio da transição côncava entre o chão e as faces.
@export_range(0.0, 5.0, 0.05, "suffix:m") var base_radius: float = 1.2:
	set(value):
		base_radius = value
		_rebuild()
## Faces com comprimento zero viram rampas íngremes com este comprimento por metro de altura.
@export_range(0.2, 3.0, 0.05) var steep_face_ratio: float = 0.8:
	set(value):
		steep_face_ratio = value
		_rebuild()
## Pontos por canto arredondado (mais = mais suave, menos = mais low poly).
@export_range(1, 16) var corner_steps: int = 5:
	set(value):
		corner_steps = value
		_rebuild()

var _mesh_instance: MeshInstance3D
var _collision: CollisionShape3D


func _ready() -> void:
	collision_layer = 2 if is_bump else 1
	_mesh_instance = MeshInstance3D.new()
	add_child(_mesh_instance)
	_collision = CollisionShape3D.new()
	add_child(_collision)
	_rebuild()


## Perfil arredondado em (y, z), começando e terminando no chão (y = 0).
func build_profile() -> PackedVector2Array:
	var face := maxf(up_length, height * steep_face_ratio)
	var back := maxf(down_length, height * steep_face_ratio)
	var start_z := face - up_length  # > 0 quando a frente era vertical (rampa de pouso)
	var corners: Array[Vector2] = [Vector2(0.0, start_z + base_radius), Vector2(0.0, start_z),
			Vector2(height, -up_length)]
	if top_length > 0.01:
		corners.append(Vector2(height, -up_length - top_length))
	var end_z := -up_length - top_length - back
	corners.append(Vector2(0.0, end_z))
	corners.append(Vector2(0.0, end_z - base_radius))

	var profile := PackedVector2Array([corners[0]])
	for i in range(1, corners.size() - 1):
		var prev := corners[i - 1]
		var corner := corners[i]
		var next := corners[i + 1]
		var radius := base_radius if is_zero_approx(corner.x) else crest_radius
		radius = minf(radius, minf(prev.distance_to(corner), next.distance_to(corner)) * 0.5)
		if radius <= 0.001:
			profile.append(corner)
			continue
		var a := corner + (prev - corner).normalized() * radius
		var b := corner + (next - corner).normalized() * radius
		# Curva de Bézier quadrática entre os dois pontos de corte.
		for s in corner_steps + 1:
			var t := float(s) / corner_steps
			profile.append(a.lerp(corner, t).lerp(corner.lerp(b, t), t))
	profile.append(corners[-1])
	return profile


func _rebuild() -> void:
	if _mesh_instance == null:
		return

	var profile := build_profile()
	var half := width * 0.5
	var top_color := color
	var side_color := color.darkened(0.2)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Superfície de rodagem: uma faixa por trecho do perfil (normal própria = visual low poly).
	for i in profile.size() - 1:
		var a := profile[i]
		var b := profile[i + 1]
		if a.is_equal_approx(b):
			continue
		var d := b - a
		var normal := Vector3(0.0, -d.y, d.x).normalized()
		var p0 := Vector3(-half, a.x, a.y)
		var p1 := Vector3(half, a.x, a.y)
		var p2 := Vector3(half, b.x, b.y)
		var p3 := Vector3(-half, b.x, b.y)
		_add_triangle(st, p0, p1, p2, normal, top_color)
		_add_triangle(st, p0, p2, p3, normal, top_color)

	# Laterais: o perfil é côncavo, então triangula de verdade (não em leque).
	var outline := PackedVector2Array()
	for p in profile:
		outline.append(Vector2(p.y, p.x))
	var indices := Geometry2D.triangulate_polygon(outline)
	for side: float in [-1.0, 1.0]:
		var normal := Vector3(side, 0.0, 0.0)
		for k in range(0, indices.size(), 3):
			var verts: Array[Vector3] = []
			for n in 3:
				var q := outline[indices[k + n]]
				verts.append(Vector3(side * half, q.y, q.x))
			_add_triangle(st, verts[0], verts[1], verts[2], normal, side_color)

	if material:
		st.set_material(material)
	else:
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		st.set_material(mat)
	var mesh := st.commit()
	_mesh_instance.mesh = mesh
	# Colisão exata (malha), para a moto andar sobre as curvas de verdade.
	_collision.shape = mesh.create_trimesh_shape()


## Triângulo com a face visível do lado de `normal` (o Godot considera frente o sentido horário).
func _add_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, vertex_color: Color) -> void:
	if (b - a).cross(c - a).dot(normal) > 0.0:
		var tmp := b
		b = c
		c = tmp
	for v in [a, b, c]:
		st.set_normal(normal)
		st.set_color(vertex_color)
		st.add_vertex(v)
