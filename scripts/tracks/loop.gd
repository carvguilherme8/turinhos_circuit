@tool
extends Node3D
## Looping: pista em espiral que dá uma volta completa na vertical. A saída fica deslocada para
## o lado (`offset`), para não bater na entrada. Entra-se pela frente, andando para -Z, a partir
## da origem (no chão).
## Arcade, só enquanto uma roda da moto está no piso do looping e ela anda acima de
## `min_speed`: ajuda um pouco a segurá-la na pista (a velocidade, pela força centrífuga, faz a
## maior parte; o looping só cobre uma falta de até `hold_assist` vezes a gravidade), alivia a
## gravidade que a freia na subida (`climb_assist`) e alinha a direção com a curva da espiral.
## Devagar demais, falta força e a moto cai, como na vida real.

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
@export var frame_color: Color = Color(0.32, 0.33, 0.36)
## Velocidade (ao longo da pista) abaixo da qual o looping não ajuda mais: a moto cai.
@export var min_speed: float = 7.0
## Fração da gravidade que freia a moto na subida que o looping cancela (0 = nada, 1 = toda).
@export_range(0.0, 1.0) var climb_assist: float = 0.3
## Quanto da gravidade o looping pode compensar além da força centrífuga (0 = física pura).
@export_range(0.0, 1.0) var hold_assist: float = 0.5

var _generated: Node3D
var _rebuild_queued := false
var _bikes: Array[Node] = []
var _deck_body: StaticBody3D


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
	return Vector3(_side(a), radius * (1.0 - cos(a)), -radius * sin(a))


## Deslocamento lateral da espiral no ângulo `a`: suave nas pontas, para a entrada e a saída
## ficarem retas (a moto sai alinhada, sem desviar).
func _side(a: float) -> float:
	return offset * (a - sin(a)) / TAU


## Direção da pista no ângulo `a` (derivada de _point).
func _tangent_at(a: float) -> Vector3:
	return Vector3(offset * (1.0 - cos(a)) / TAU, radius * sin(a), -radius * cos(a)).normalized()


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
		var t := float(k) / lead_steps
		rows.append([Vector3(0, lift * t, lead * (1.0 - t)), Vector3.UP, Vector3(0, 0, -1)])
	for i in segments + 1:
		var a := TAU * i / segments
		rows.append([_point(a) + _normal(a) * lift, _normal(a), _tangent_at(a)])
	for k in range(1, lead_steps + 1):
		var t := float(k) / lead_steps
		rows.append([Vector3(offset, lift * (1.0 - t), -lead * t), Vector3.UP, Vector3(0, 0, -1)])

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
	_deck_body = body
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
	if Engine.is_editor_hint() or _deck_body == null:
		return
	var gravity := Vector3.DOWN * float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	for bike in _bikes:
		if not is_instance_valid(bike) or bike.is_crashed or not _on_deck(bike):
			continue
		var body := bike as RigidBody3D
		var local := to_local(body.global_position)
		var radial := Vector2(-local.z, radius - local.y)
		var a := fposmod(atan2(radial.x, radial.y), TAU)
		if a < 0.3 or a > TAU - 0.3:
			# Quase no chão (entrada e saída): só alinha a moto com a reta do looping, para ela
			# sair reta (sem isso sai um pouco torta e desvia do que vem depois).
			_align_straight(body, local, delta)
			continue
		var inward := global_basis * Vector3(0.0, cos(a), sin(a))  # normal do piso
		var tangent := (global_basis * _tangent_at(a)).normalized()
		var along := body.linear_velocity.dot(tangent)
		if along < min_speed:
			continue  # devagar demais: solta, a moto cai
		var g := gravity * body.gravity_scale
		# Gravidade puxando para fora do piso (para o centro do looping). A curva segura com
		# v²/R; o looping só cobre uma falta pequena, senão a moto cai.
		var deficit := g.dot(inward) - along * along / radius
		if deficit > 0.0 and deficit <= g.length() * hold_assist:
			body.linear_velocity -= inward * deficit * delta
		# Na subida, alivia parte da gravidade que freia.
		var brake := g.dot(tangent)
		if brake < 0.0:
			body.linear_velocity -= tangent * brake * climb_assist * delta
		# A espiral anda `offset` metros para o lado ao longo da volta: a moto acompanha esse
		# deslocamento (velocidade lateral da espiral + correção do quanto ficou para trás) e vira
		# junto com a curva, como o piloto faria. Sem isso ela atrasa e bate na grade.
		var side := global_basis.x
		var lateral_error := _side(a) - local.x
		var wanted := along * (offset * (1.0 - cos(a)) / TAU) / radius + lateral_error * 2.5
		var lateral := body.linear_velocity.dot(side)
		body.linear_velocity += side * (wanted - lateral) * clampf(8.0 * delta, 0.0, 1.0)
		var heading_error := (-body.global_basis.z).signed_angle_to(tangent, inward)
		var spin := body.angular_velocity.dot(inward)
		body.angular_velocity += inward * (heading_error * 6.0 - spin) * clampf(8.0 * delta, 0.0, 1.0)


func _align_straight(body: RigidBody3D, local: Vector3, delta: float) -> void:
	var forward := -global_basis.z
	var target_x := offset if local.z < 0.0 and local.x > offset * 0.5 else 0.0
	var side := global_basis.x
	var lateral := body.linear_velocity.dot(side)
	body.linear_velocity += side * ((target_x - local.x) * 1.5 - lateral) * clampf(6.0 * delta, 0.0, 1.0)
	var heading_error := (-body.global_basis.z).signed_angle_to(forward, Vector3.UP)
	var spin := body.angular_velocity.dot(Vector3.UP)
	body.angular_velocity += Vector3.UP * (heading_error * 6.0 - spin) * clampf(8.0 * delta, 0.0, 1.0)


## Alguma roda da moto está apoiada no piso deste looping?
func _on_deck(bike: Node) -> bool:
	for ray_name in ["_front_ray", "_rear_ray"]:
		var ray: RayCast3D = bike.get(ray_name)
		if ray and ray.is_colliding() and ray.get_collider() == _deck_body:
			return true
	return false
