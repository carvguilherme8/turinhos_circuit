class_name RiderRagdoll
extends Node
## Ragdoll do piloto: na queda, o piloto preso à moto some e no lugar dele surge um boneco
## físico (cabeça, tronco, braços e pernas como corpos rígidos ligados por juntas), na mesma
## pose e com a velocidade da moto. Some quando a moto volta para a pista.
## Também dá ao piloto montado áreas de contato (cabeça e tronco): encostar no cenário
## avisa `hit_scenery` (a moto cai). Outras motos e bonecos são ignorados.

## O piloto montado encostou a cabeça ou o tronco no cenário.
signal hit_scenery(part: String)

## Camadas de colisão: 1 = chão/obstáculos, 2 = ondulações, 3 = motos, 4 = ragdolls.
const RAGDOLL_LAYER := 1 << 3
const RAGDOLL_MASK := 1 | 2

@export var rider: Node3D
## Escala do piloto na moto (a mesma do nó Rider) e tamanho de uma unidade do modelo (m).
@export var rider_scale: float = 0.9
@export var unit: float = 1.0 / 16.0
## Empurrão extra ao ser arremessado (m/s para cima e fração da velocidade para frente).
@export var launch_up: float = 2.5
@export var launch_forward: float = 0.25
## Partes do piloto montado que derrubam a moto ao encostar no cenário.
@export var hit_parts: PackedStringArray = PackedStringArray(["head", "upper"])

## Peças: [osso, pai (para a junta), centro da caixa e tamanho no espaço do osso (unidades), massa].
const PARTS := [
	["upper", "", Vector3(0, 6, 0), Vector3(8, 12, 4), 30.0],
	["head", "upper", Vector3(0, 4.5, 0), Vector3(9, 9, 9), 6.0],
	["arm_r", "upper", Vector3(1, -4, 0), Vector3(4, 12, 4), 5.0],
	["arm_l", "upper", Vector3(-1, -4, 0), Vector3(4, 12, 4), 5.0],
	["leg_r", "upper", Vector3(0, -6, 0), Vector3(4, 12, 4), 8.0],
	["leg_l", "upper", Vector3(0, -6, 0), Vector3(4, 12, 4), 8.0],
]

var _root: Node3D


## Partes do piloto montado testadas contra o cenário: [osso, caixa, centro no osso].
var _hitboxes: Array = []
var _query := PhysicsShapeQueryParameters3D.new()


func _ready() -> void:
	_add_hitboxes()


## Caixas de contato presas aos ossos do piloto montado (acompanham pose, wheelie e manobras).
## São testadas com consultas diretas à física a cada passo (áreas não enxergam corpos
## estáticos no Jolt, o motor de física do projeto).
func _add_hitboxes() -> void:
	_hitboxes.clear()
	if rider == null:
		return
	for part in PARTS:
		if not hit_parts.has(part[0]):
			continue
		var bone := rider.find_child(part[0], true, false) as Node3D
		if bone == null:
			continue
		var box := BoxShape3D.new()
		box.size = part[3] * unit * rider_scale
		_hitboxes.append([bone, box, part[2] * unit, part[0]])
	_query.collision_mask = RAGDOLL_MASK  # só o cenário: chão, rampas, blocos e muro
	_query.collide_with_areas = false


func _physics_process(_delta: float) -> void:
	# Vale também com o piloto invisível (câmera do guidão); durante o ragdoll não testa.
	if is_active() or _hitboxes.is_empty():
		return
	var space := rider.get_world_3d().direct_space_state
	for hitbox in _hitboxes:
		var bone: Node3D = hitbox[0]
		var spot := bone.global_transform
		var basis := spot.basis.orthonormalized()
		_query.shape = hitbox[1]
		_query.transform = Transform3D(basis, spot * hitbox[2])
		if not space.intersect_shape(_query, 1).is_empty():
			hit_scenery.emit(hitbox[3])
			return


func is_active() -> bool:
	return _root != null


## Troca o piloto pelo boneco físico, herdando a velocidade da moto.
func activate(velocity: Vector3, angular_velocity: Vector3) -> void:
	deactivate()
	if rider == null:
		return
	var bones := {}
	for part in PARTS:
		bones[part[0]] = rider.find_child(part[0], true, false) as Node3D
	if bones.values().has(null):
		return

	_root = Node3D.new()
	_root.name = "RiderRagdoll"
	# Fica na cena (não na moto), para não ser arrastado por ela.
	var holder: Node = get_tree().current_scene
	if holder == null:
		holder = get_parent().get_parent()
	holder.add_child(_root)

	var scale := rider_scale * unit
	var forward_push := Vector3(velocity.x, 0.0, velocity.z) * launch_forward
	var bodies := {}
	for part in PARTS:
		var bone: Node3D = bones[part[0]]
		var body := RigidBody3D.new()
		body.name = part[0]
		body.mass = part[4]
		body.collision_layer = RAGDOLL_LAYER
		body.collision_mask = RAGDOLL_MASK
		body.angular_damp = 1.5
		body.continuous_cd = true
		var spot := bone.global_transform
		body.transform = Transform3D(spot.basis.orthonormalized(), spot.origin)

		var mesh := MeshInstance3D.new()
		mesh.mesh = (bone as MeshInstance3D).mesh if bone is MeshInstance3D else null
		mesh.material_override = (bone as MeshInstance3D).material_override if bone is MeshInstance3D else null
		mesh.scale = Vector3.ONE * rider_scale
		body.add_child(mesh)

		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = part[3] * scale
		shape.shape = box
		shape.position = part[2] * scale
		body.add_child(shape)

		_root.add_child(body)
		body.linear_velocity = velocity + forward_push + Vector3.UP * launch_up
		body.angular_velocity = angular_velocity
		bodies[part[0]] = body

	for part in PARTS:
		if part[1] == "":
			continue
		_add_joint(bodies[part[1]], bodies[part[0]], part[0])


## Some com o boneco e mostra o piloto de novo (a moto voltou para a pista).
func deactivate() -> void:
	if _root:
		_root.queue_free()
		_root = null


## Junta do tipo ombro/quadril: gira em cone com limite e torce um pouco.
func _add_joint(parent: RigidBody3D, child: RigidBody3D, bone: String) -> void:
	var joint := ConeTwistJoint3D.new()
	# O eixo X da junta aponta ao longo do membro (para baixo nos braços e pernas,
	# para cima no pescoço).
	var along := child.global_basis.y if bone == "head" else -child.global_basis.y
	var side := child.global_basis.x
	var x := along.normalized()
	var z := x.cross(side).normalized()
	var y := z.cross(x)
	joint.transform = Transform3D(Basis(x, y, z), child.global_position)
	_root.add_child(joint)
	joint.node_a = joint.get_path_to(parent)
	joint.node_b = joint.get_path_to(child)
	var swing := 35.0 if bone == "head" else 75.0
	joint.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(swing))
	joint.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(30.0))
