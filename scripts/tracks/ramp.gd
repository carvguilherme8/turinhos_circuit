@tool
class_name Ramp
extends StaticBody3D
## Rampa low poly paramétrica (malha e colisão geradas pelo script, visíveis no editor).
## Perfil visto de lado, avançando para -Z a partir da origem: subida -> topo plano -> descida.
## - Kicker: descida = 0 (termina numa parede vertical).
## - Rampa de pouso: subida = 0.
## - Mesa (tabletop): os três maiores que zero.

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
## Material opcional (ex.: terra pixelada com UV triplanar). Sem ele, usa `color`.
@export var material: Material:
	set(value):
		material = value
		_rebuild()

var _mesh_instance: MeshInstance3D
var _collision: CollisionShape3D


func _ready() -> void:
	_mesh_instance = MeshInstance3D.new()
	add_child(_mesh_instance)
	_collision = CollisionShape3D.new()
	add_child(_collision)
	_rebuild()


func _rebuild() -> void:
	if _mesh_instance == null:
		return

	# Perfil em (y, z).
	var profile: Array[Vector2] = [
		Vector2(0.0, 0.0),
		Vector2(height, -up_length),
		Vector2(height, -up_length - top_length),
		Vector2(0.0, -up_length - top_length - down_length),
	]
	var half := width * 0.5
	var top_color := color
	var side_color := color.darkened(0.2)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Superfícies de rodagem (e faces verticais quando um trecho tem comprimento zero).
	for i in profile.size() - 1:
		var a := profile[i]
		var b := profile[i + 1]
		if a.is_equal_approx(b):
			continue
		var d := b - a
		var normal := Vector3(0.0, -d.y, d.x).normalized()
		var quad: Array[Vector3] = [
			Vector3(-half, a.x, a.y), Vector3(half, a.x, a.y),
			Vector3(half, b.x, b.y), Vector3(-half, b.x, b.y),
		]
		_add_polygon(st, quad, normal, top_color)

	# Laterais.
	for side in [-1.0, 1.0]:
		var points: Array[Vector3] = []
		for p in profile:
			points.append(Vector3(side * half, p.x, p.y))
		_add_polygon(st, points, Vector3(side, 0.0, 0.0), side_color)

	if material:
		st.set_material(material)
	else:
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		st.set_material(mat)
	_mesh_instance.mesh = st.commit()

	var hull := PackedVector3Array()
	for p in profile:
		hull.append(Vector3(-half, p.x, p.y))
		hull.append(Vector3(half, p.x, p.y))
	var shape := ConvexPolygonShape3D.new()
	shape.points = hull
	_collision.shape = shape


## Adiciona um polígono convexo (em leque) com a face visível do lado de `normal`.
## Pontos repetidos são ignorados. O Godot considera frente os triângulos em sentido horário.
func _add_polygon(st: SurfaceTool, points: Array[Vector3], normal: Vector3, vertex_color: Color) -> void:
	var poly: Array[Vector3] = []
	for p in points:
		if poly.is_empty() or not p.is_equal_approx(poly[-1]):
			poly.append(p)
	if poly.size() > 2 and poly[0].is_equal_approx(poly[-1]):
		poly.pop_back()
	if poly.size() < 3:
		return

	# Normal de Newell: sentido do polígono (anti-horário visto de `normal` dá produto positivo).
	var winding := Vector3.ZERO
	for i in poly.size():
		winding += poly[i].cross(poly[(i + 1) % poly.size()])
	if winding.dot(normal) > 0.0:
		poly.reverse()

	for i in range(1, poly.size() - 1):
		for v in [poly[0], poly[i], poly[i + 1]]:
			st.set_normal(normal)
			st.set_color(vertex_color)
			st.add_vertex(v)
