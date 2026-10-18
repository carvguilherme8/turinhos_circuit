@tool
extends Node3D
## Looping: pista em espiral que dá uma volta completa na vertical. A saída fica deslocada para
## o lado (`offset`), para não bater na entrada. Entra-se pela frente, andando para -Z, a partir
## da origem (no chão).
## Arcade: enquanto a moto está dentro do looping, com velocidade, o looping a segura contra a
## pista (`stick`) e mantém uma velocidade mínima (`carry_speed`) para ela completar a volta.

@export var radius: float = 7.0:
	set(value):
		radius = value
		_queue_rebuild()
@export var width: float = 6.0:
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
## Retas de entrada e saída, no chão (m).
@export var lead: float = 4.0
@export var deck_colors: PackedColorArray = PackedColorArray([Color("e83a3a"), Color("f2f2ec")])
@export var rail_color: Color = Color("f0d23c")
@export var frame_color: Color = Color(0.32, 0.33, 0.36)
## Física arcade: empurrão contra a pista (m/s²), velocidade mínima mantida dentro do looping
## e a velocidade abaixo da qual o looping "solta" a moto (ela cai, como na vida real).
@export var stick: float = 32.0
@export var carry_speed: float = 15.0
@export var min_speed: float = 8.0

var _generated: Node3D
var _rebuild_queued := false
var _bikes: Array[Node] = []


func _ready() -> void:
	_rebuild()
	if not Engine.is_editor_hint():
		_find_bikes.call_deferred()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _find_bikes() -> void:
	for node in get_tree().root.find_children("*", "RigidBody3D", true, false):
		if node.has_method("is_grounded"):
			_bikes.append(node)


## Ponto da pista no ângulo `a` (0 = embaixo, na entrada; 2π = embaixo, na saída).
func _point(a: float) -> Vector3:
	return Vector3(offset * a / TAU, radius * (1.0 - cos(a)), -radius * sin(a))


## Normal da pista (para o centro do looping).
func _normal(a: float) -> Vector3:
	return Vector3(0.0, cos(a), sin(a))


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
	for k in lead_steps:
		var z := lead * (1.0 - float(k) / lead_steps)
		rows.append([Vector3(0, 0, z), Vector3.UP, Vector3(0, 0, -1)])
	for i in segments + 1:
		var a := TAU * i / segments
		var tangent := Vector3(offset / TAU, radius * sin(a), -radius * cos(a)).normalized()
		rows.append([_point(a), _normal(a), tangent])
	for k in range(1, lead_steps + 1):
		rows.append([Vector3(offset, 0, -lead * float(k) / lead_steps), Vector3.UP, Vector3(0, 0, -1)])

	var deck := SurfaceTool.new()
	deck.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var half := width * 0.5
	for k in rows.size() - 1:
		var a: Array = rows[k]
		var b: Array = rows[k + 1]
		var side_a: Vector3 = (a[2] as Vector3).cross(a[1]).normalized()
		var side_b: Vector3 = (b[2] as Vector3).cross(b[1]).normalized()
		var la: Vector3 = a[0] - side_a * half
		var ra: Vector3 = a[0] + side_a * half
		var lb: Vector3 = b[0] - side_b * half
		var rb: Vector3 = b[0] + side_b * half
		var n: Vector3 = a[1]
		var stripe := deck_colors[(k / 4) % deck_colors.size()]
		# piso (virado para o centro), grades dos dois lados e o "casco" por fora
		_quad(deck, faces, la, ra, rb, lb, n, stripe, true)
		_quad(deck, faces, la, lb, lb + n * rail_height, la + n * rail_height, side_a, rail_color, true)
		_quad(deck, faces, ra, ra + n * rail_height, rb + n * rail_height, rb, -side_a, rail_color, true)
		_quad(deck, faces, la - n * 0.3, lb - n * 0.3, rb - n * 0.3, ra - n * 0.3, -n, frame_color, false)
	deck.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.55
	material.metallic = 0.2
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

	# Pilares segurando o looping (enfeite).
	for side: float in [-1.0, 1.0]:
		for z: float in [-radius, radius]:
			var pillar := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.5, radius, 0.5)
			var metal := StandardMaterial3D.new()
			metal.albedo_color = frame_color
			box.material = metal
			pillar.mesh = box
			var x := offset * 0.5 + side * (half + offset * 0.5 + 0.6)
			pillar.position = Vector3(x, radius * 0.5, z * 0.7)
			_generated.add_child(pillar)


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


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	for bike in _bikes:
		if not is_instance_valid(bike) or bike.is_crashed:
			continue
		var local := to_local(bike.global_position)
		# Ângulo na volta e distância até o eixo do looping.
		var radial := Vector2(-local.z, radius - local.y)  # (seno, cosseno) * distância
		var dist := radial.length()
		if dist < radius * 0.45 or dist > radius + 1.5:
			continue
		var a := fposmod(atan2(radial.x, radial.y), TAU)
		if a < 0.25 or a > TAU - 0.25:
			continue  # trechos quase no chão: a física normal dá conta
		var expected_x := offset * a / TAU
		if absf(local.x - expected_x) > width:
			continue
		var outward := global_basis * Vector3(0.0, -cos(a), -sin(a))
		var tangent := (global_basis * Vector3(offset / TAU, radius * sin(a), -radius * cos(a))).normalized()
		var body := bike as RigidBody3D
		var along := body.linear_velocity.dot(tangent)
		if along < min_speed:
			continue  # devagar demais: o looping solta e a moto cai
		body.linear_velocity += outward * stick * delta
		if along < carry_speed:
			body.linear_velocity += tangent * (carry_speed - along) * clampf(3.0 * delta, 0.0, 1.0)
		# Guia de lado: a espiral anda `offset` metros para o lado ao longo da volta; a moto
		# segue a pista (posição e direção) em vez de ir reto até a grade.
		var side := global_basis.x
		var lateral_error := expected_x - local.x
		var lateral_speed := body.linear_velocity.dot(side)
		var wanted := along * (offset / TAU) / radius + lateral_error * 3.0
		body.linear_velocity += side * (wanted - lateral_speed) * clampf(6.0 * delta, 0.0, 1.0)
		var inward := -outward
		var heading_error := (-body.global_basis.z).signed_angle_to(tangent, inward)
		var spin := body.angular_velocity.dot(inward)
		body.angular_velocity += inward * (heading_error * 8.0 - spin) * clampf(10.0 * delta, 0.0, 1.0)
