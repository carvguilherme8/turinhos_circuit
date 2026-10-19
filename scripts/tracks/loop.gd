@tool
extends Node3D
## Looping: pista em hélice que dá uma volta completa na vertical. A saída fica deslocada para
## o lado (`offset`), para não bater na entrada. Entra-se pela frente, andando para -Z, a partir
## da origem (no chão).
## A hélice tem inclinação constante e o looping todo é girado para a reta de entrada quase
## acompanhar essa inclinação: sobre um cilindro, uma moto andando reto (sem virar) segue uma
## hélice. Com o giro certo (`YAW_FACTOR`, medido nas simulações), a hélice natural da moto
## coincide com a da pista: ela completa a volta no meio do piso, sem raspar na grade e sem
## nenhum empurrão extra, e sai seguindo reto a ~7° da reta de entrada.
## Sem nenhuma ajuda na física: a moto completa a volta só com a própria velocidade (precisa
## chegar rápida; devagar, ela não sobe e cai, como na vida real).

@export var radius: float = 7.0:
	set(value):
		radius = value
		_queue_rebuild()
@export var width: float = 7.0:
	set(value):
		width = value
		_queue_rebuild()
@export var offset: float = 8.0:
	set(value):
		offset = value
		_queue_rebuild()
@export var segments: int = 96:
	set(value):
		segments = value
		_queue_rebuild()
@export var rail_height: float = 0.8
## Altura do piso acima do chão (evita o piso e o chão "brigarem" na tela); as retas de
## entrada e saída descem até o chão em rampinha.
@export var lift: float = 0.06
## Retas de entrada e saída, no chão (m).
@export var lead: float = 4.0
@export var deck_colors: PackedColorArray = PackedColorArray([Color("e83a3a"), Color("f2f2ec")])
@export var rail_color: Color = Color("f0d23c")
@export var frame_color: Color = Color(0.28, 0.31, 0.38)

var _generated: Node3D
var _rebuild_queued := false


func _ready() -> void:
	_rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


## Fração da inclinação da hélice usada no giro do looping (ver o comentário do topo).
const YAW_FACTOR := 0.8


## Giro do looping em torno de Y (a reta de entrada fica em -Z).
func _yaw() -> Basis:
	return Basis(Vector3.UP, atan2(offset / TAU, radius) * YAW_FACTOR)


## Ponto da pista no ângulo `a` (0 = embaixo, na entrada; 2π = embaixo, na saída).
func _point(a: float) -> Vector3:
	return _yaw() * Vector3(offset * a / TAU, radius * (1.0 - cos(a)), -radius * sin(a))


## Direção da pista no ângulo `a` (derivada de _point): inclinação constante.
func _tangent_at(a: float) -> Vector3:
	return _yaw() * Vector3(offset / TAU, radius * sin(a), -radius * cos(a)).normalized()


## Normal da pista (para o centro do looping).
func _normal(a: float) -> Vector3:
	return _yaw() * Vector3(0.0, cos(a), sin(a))


func _rebuild() -> void:
	_rebuild_queued = false
	if _generated:
		_generated.free()
	_generated = Node3D.new()
	_generated.name = "_Generated"
	add_child(_generated)

	# Fileiras de pontos ao longo do caminho: reta de entrada, a volta, reta de saída.
	var rows: Array = []
	var lead_steps := 4
	var exit_point := _point(TAU)
	for k in lead_steps:
		var t := float(k) / lead_steps
		rows.append([Vector3(0, lift * t, lead * (1.0 - t)), Vector3.UP, Vector3(0, 0, -1)])
	for i in segments + 1:
		var a := TAU * i / segments
		rows.append([_point(a) + _normal(a) * lift, _normal(a), _tangent_at(a)])
	for k in range(1, lead_steps + 1):
		var t := float(k) / lead_steps
		rows.append([exit_point + Vector3(0, lift * (1.0 - t), -lead * t), Vector3.UP, Vector3(0, 0, -1)])

	var deck := SurfaceTool.new()
	deck.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var half := width * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var shell := 0.35  # espessura da casca de fora
	for k in rows.size() - 1:
		var a: Array = rows[k]
		var b: Array = rows[k + 1]
		var side_a: Vector3 = (a[2] as Vector3).cross(a[1]).normalized()
		var side_b: Vector3 = (b[2] as Vector3).cross(b[1]).normalized()
		var la: Vector3 = a[0] - side_a * half
		var ra: Vector3 = a[0] + side_a * half
		var lb: Vector3 = b[0] - side_b * half
		var rb: Vector3 = b[0] + side_b * half
		var na: Vector3 = a[1]
		var nb: Vector3 = b[1]
		# piso: listras largas vermelhas e brancas, com uma faixa escura nas bordas e um leve
		# ruído de tom por placa (pixel art)
		var stripe := deck_colors[(k / 4) % deck_colors.size()] * rng.randf_range(0.94, 1.04)
		var edge := 0.6
		var la_in := la + side_a * edge
		var lb_in := lb + side_b * edge
		var ra_in := ra - side_a * edge
		var rb_in := rb - side_b * edge
		var border := Color(0.18, 0.18, 0.2)
		_quad(deck, faces, la_in, ra_in, rb_in, lb_in, na, stripe, true)
		_quad(deck, faces, la, la_in, lb_in, lb, na, border, true)
		_quad(deck, faces, ra_in, ra, rb, rb_in, na, border, true)
		# grades com listras de advertência (amarelo e preto)
		var hazard := rail_color if (k / 2) % 2 == 0 else Color(0.1, 0.1, 0.12)
		var top_a := na * rail_height
		var top_b := nb * rail_height
		_quad(deck, faces, la, lb, lb + top_b, la + top_a, side_a, hazard, true)
		_quad(deck, faces, ra, ra + top_a, rb + top_b, rb, -side_a, hazard, true)
		# topo e lado de fora das grades (dão espessura)
		var out_a := -side_a * 0.25
		var out_b := -side_b * 0.25
		_quad(deck, faces, la + top_a, lb + top_b, lb + top_b + out_b, la + top_a + out_a, na, hazard, false)
		_quad(deck, faces, ra + top_a - out_a, rb + top_b - out_b, rb + top_b, ra + top_a, na, hazard, false)
		# casca de fora: aço escuro, com uma nervura mais clara a cada 6 placas
		var steel := frame_color.lightened(0.25) if k % 6 == 0 else frame_color
		_quad(deck, faces, la - na * shell, lb - nb * shell, rb - nb * shell, ra - na * shell, -na, steel, false)
		_quad(deck, faces, la, la - na * shell, lb - nb * shell, lb, side_a, steel.darkened(0.15), false)
		_quad(deck, faces, ra, rb, rb - nb * shell, ra - na * shell, -side_a, steel.darkened(0.15), false)
	deck.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.5
	material.metallic = 0.25
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	deck.set_material(material)
	var mesh := MeshInstance3D.new()
	mesh.name = "Deck"
	mesh.mesh = deck.commit()
	_generated.add_child(mesh)

	var body := StaticBody3D.new()
	body.name = "DeckBody"
	var shape := CollisionShape3D.new()
	var concave := ConcavePolygonShape3D.new()
	concave.backface_collision = true
	concave.set_faces(faces)
	shape.shape = concave
	body.add_child(shape)
	_generated.add_child(body)
	_build_frame()


## Estrutura que segura o looping: um pórtico em "A" de cada lado (pernas da frente e de trás
## subindo até o alto), ligados por uma viga por cima do topo, travessas no meio e sapatas de
## concreto no chão. As pernas têm colisão (ficam fora da pista).
func _build_frame() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = frame_color.lightened(0.1)
	metal.metallic = 0.6
	metal.roughness = 0.45
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.62, 0.6, 0.56)
	concrete.roughness = 1.0
	var body := StaticBody3D.new()
	body.name = "FrameBody"
	_generated.add_child(body)
	var half := width * 0.5
	var top_y := 2.0 * radius + lift + 1.1           # acima da casca no ponto mais alto
	var spread := radius * 1.05                       # pés da frente e de trás
	var sides := [-half - 1.2, offset + half + 1.2]   # fora da pista nos dois lados
	for x: float in sides:
		var apex := Vector3(x, top_y, 0.0)
		var front := Vector3(x, 0.0, -spread)
		var back := Vector3(x, 0.0, spread)
		_beam(body, metal, front, apex, 0.5)
		_beam(body, metal, back, apex, 0.5)
		# travessa no meio da altura e diagonais
		var mid_f := front.lerp(apex, 0.45)
		var mid_b := back.lerp(apex, 0.45)
		_beam(body, metal, mid_f, mid_b, 0.3)
		_beam(body, metal, front.lerp(apex, 0.15), mid_b, 0.22)
		_beam(body, metal, back.lerp(apex, 0.15), mid_f, 0.22)
		for foot in [front, back]:
			_box(concrete, _yaw() * (foot + Vector3(0, 0.15, 0)), Vector3(1.2, 0.5, 1.2))
	# viga por cima do topo, de um pórtico ao outro
	_beam(body, metal, Vector3(sides[0], top_y, 0.0), Vector3(sides[1], top_y, 0.0), 0.6)


## Viga (caixa) de `a` até `b` (coordenadas antes do giro do looping), com colisão.
func _beam(body: StaticBody3D, material: Material, a: Vector3, b: Vector3, thickness: float) -> void:
	var pa := _yaw() * a
	var pb := _yaw() * b
	var length := pa.distance_to(pb)
	var dir := (pb - pa) / length
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var basis := Basis.looking_at(dir, up)
	var t := Transform3D(basis, (pa + pb) * 0.5)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(thickness, thickness, length)
	box.material = material
	mesh.mesh = box
	mesh.transform = t
	_generated.add_child(mesh)
	var shape := CollisionShape3D.new()
	var collider := BoxShape3D.new()
	collider.size = box.size
	shape.shape = collider
	shape.transform = t
	body.add_child(shape)


func _box(material: Material, center: Vector3, size: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh.mesh = box
	mesh.position = center
	mesh.rotation = _yaw().get_euler()
	_generated.add_child(mesh)


## Quadrilátero a, b, c, d (em volta) virado para `facing`; `solid` = entra na colisão.
func _quad(st: SurfaceTool, faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		facing: Vector3, color: Color, solid: bool) -> void:
	for tri in [[a, b, c], [a, c, d]]:
		var p0: Vector3 = tri[0]
		var p1: Vector3 = tri[1]
		var p2: Vector3 = tri[2]
		# Frente do triângulo virada para `facing` (ordem horária vista de frente).
		if (p1 - p0).cross(p2 - p0).dot(facing) > 0.0:
			var tmp := p1
			p1 = p2
			p2 = tmp
		st.set_color(color)
		st.add_vertex(p0)
		st.add_vertex(p1)
		st.add_vertex(p2)
		if solid:
			faces.append_array([p0, p1, p2])
