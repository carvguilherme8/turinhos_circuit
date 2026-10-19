@tool
extends Node3D
## Curva de wallride: uma calha em arco. O fundo tem uma inclinação leve e, por fora, a parede
## sobe em curva até quase a vertical. Devagar, a moto faz a curva embaixo; rápido, sobe na
## parede (física natural: a força centrífuga a segura). A parede tem a altura cheia na curva
## inteira e baixa até o chão em duas retas de transição (`lead_length`), uma antes e outra
## depois: entra-se subindo suave e quem está alto na parede tem espaço para descer junto com
## ela na saída. Funciona nos dois sentidos.
## A curva começa na origem, andando para -Z, e vira para a direita (+X) ou para a esquerda;
## a reta de entrada fica antes da origem (em +Z) e a de saída depois do fim da curva.

## Raio da linha do meio da curva (m), ângulo da curva (graus) e o lado.
@export var radius: float = 16.0:
	set(value):
		radius = value
		_queue_rebuild()
@export var arc_degrees: float = 180.0:
	set(value):
		arc_degrees = value
		_queue_rebuild()
@export var turn_right: bool = true:
	set(value):
		turn_right = value
		_queue_rebuild()
## Largura para dentro da linha do meio (fundo) e onde começa a parede (para fora).
@export var inner_width: float = 5.0
@export var wall_start: float = 1.5
## Raio da curva da parede (m): ela sobe até `wall_height`, quase na vertical.
@export var wall_radius: float = 8.0
@export var wall_height: float = 9.5
## Inclinação do fundo (graus).
@export var floor_bank: float = 10.0
## Comprimento das retas de transição (m), em que a parede baixa até o chão.
@export var lead_length: float = 20.0
@export var material: Material
@export var top_color: Color = Color(0.85, 0.85, 0.82)

var _generated: Node3D
var _rebuild_queued := false


func _ready() -> void:
	_rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _side() -> float:
	return 1.0 if turn_right else -1.0


func center() -> Vector3:
	return Vector3(radius * _side(), 0.0, 0.0)


## Ponto da linha do meio no ângulo `phi` (radianos, 0 = início) e direção "para fora".
func _centerline(phi: float) -> Vector3:
	return center() + _outward(phi) * radius


func _outward(phi: float) -> Vector3:
	return Vector3(-cos(phi) * _side(), 0.0, -sin(phi))


## Altura do perfil a `s` metros da linha do meio (para fora > 0).
func _profile(s: float) -> float:
	var bank := tan(deg_to_rad(floor_bank))
	var h := (s + inner_width) * bank
	if s > wall_start:
		var x := minf(s - wall_start, wall_radius * 0.985)
		h = (wall_start + inner_width) * bank + wall_radius - sqrt(wall_radius * wall_radius - x * x)
	return h


func _rebuild() -> void:
	_rebuild_queued = false
	if _generated:
		_generated.free()
	_generated = Node3D.new()
	_generated.name = "_Generated"
	add_child(_generated)

	var arc := deg_to_rad(arc_degrees)
	var steps := maxi(8, int(arc_degrees / 3.0))
	var top := (wall_start + inner_width) * tan(deg_to_rad(floor_bank)) + wall_radius
	var s_end := wall_start + wall_radius * 0.985
	var s_samples: Array[float] = []
	for k in 6:
		s_samples.append(lerpf(-inner_width, wall_start, float(k) / 5.0))
	for k in range(1, 15):
		s_samples.append(wall_start + (s_end - wall_start) * float(k) / 14.0)
	# Seções ao longo do caminho: reta de entrada (subindo), a curva (altura cheia) e a reta de
	# saída (descendo). Cada seção: [ponto da linha do meio, direção para fora, altura 0..1].
	var sections: Array = []
	var lead_steps := maxi(4, int(lead_length / 1.5))
	var exit_dir := Vector3(sin(arc) * _side(), 0.0, -cos(arc))   # rumo no fim da curva
	for k in lead_steps:
		var t := float(k) / lead_steps
		sections.append([_centerline(0.0) + Vector3(0, 0, lead_length * (1.0 - t)), _outward(0.0), t])
	for i in steps + 1:
		var phi := arc * float(i) / steps
		sections.append([_centerline(phi), _outward(phi), 1.0])
	for k in range(1, lead_steps + 1):
		var t := float(k) / lead_steps
		sections.append([_centerline(arc) + exit_dir * lead_length * t, _outward(arc), 1.0 - t])
	var rows: Array = []
	var row_out: Array[Vector3] = []
	for section in sections:
		var base: Vector3 = section[0]
		var out: Vector3 = section[1]
		# Nas retas o perfil inteiro encolhe na altura (mesma forma côncava, sem prateleira nem
		# crista), chega a zero e afunda um pouco sob o chão na ponta (sem degrau e sem o piso e o
		# chão "brigarem" na tela).
		var taper := smoothstep(0.0, 1.0, section[2])
		var scale := taper * minf(1.0, wall_height / top)
		var sink := 0.03 * (1.0 - taper)
		var row: Array[Vector3] = []
		for s in s_samples:
			row.append(base + out * s + Vector3.UP * (_profile(s) * scale - sink))
		# borda de cima da parede e o lado de fora descendo até o chão (parede maciça)
		var last: Vector3 = row[row.size() - 1]
		row.append(last + out * 0.6)
		row.append(Vector3(row[row.size() - 1].x, 0.0, row[row.size() - 1].z))
		rows.append(row)
		row_out.append(out)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	for i in rows.size() - 1:
		var a: Array = rows[i]
		var b: Array = rows[i + 1]
		for k in a.size() - 1:
			var quad: Array[Vector3] = [a[k], a[k + 1], b[k + 1], b[k]]
			var tris: Array = [[quad[0], quad[1], quad[2]], [quad[0], quad[2], quad[3]]]
			# Piso e parede: frente para dentro da curva e para cima; lado de fora da parede
			# (as duas últimas faixas): frente para fora.
			var inward := -(row_out[i] + row_out[i + 1]).normalized()
			var facing := inward + Vector3.UP * 0.5 if k < a.size() - 2 else -inward
			for tri in tris:
				var p0: Vector3 = tri[0]
				var p1: Vector3 = tri[1]
				var p2: Vector3 = tri[2]
				# Mesma regra do looping: troca a ordem se a frente estiver virada para o outro lado.
				if (p1 - p0).cross(p2 - p0).dot(facing) > 0.0:
					var tmp := p1
					p1 = p2
					p2 = tmp
				var color := top_color if k >= a.size() - 3 else Color.WHITE
				for p in [p0, p1, p2]:
					st.set_color(color)
					st.set_uv(Vector2(0.0, 0.0))
					st.add_vertex(p)
				faces.append_array([p0, p1, p2])
	st.generate_normals()
	if material:
		st.set_material(material)
	var mesh := MeshInstance3D.new()
	mesh.name = "Surface"
	mesh.mesh = st.commit()
	_generated.add_child(mesh)
	var body := StaticBody3D.new()
	body.name = "SurfaceBody"
	var shape := CollisionShape3D.new()
	var concave := ConcavePolygonShape3D.new()
	concave.backface_collision = true
	concave.set_faces(faces)
	shape.shape = concave
	body.add_child(shape)
	_generated.add_child(body)
