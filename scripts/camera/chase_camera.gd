extends Camera3D
## Câmera de perseguição simples: fica atrás e acima do alvo, acompanhando só a direção horizontal.
## (Versão provisória; a câmera definitiva do Marco 1 vem numa etapa própria.)

@export var target: Node3D
@export var distance: float = 6.0
@export var height: float = 3.0
@export var look_height: float = 1.4
## Quanto maior, mais "colada" a câmera fica no alvo.
@export var follow_speed: float = 6.0

var _heading: Vector3 = Vector3.FORWARD
## "Para cima" da câmera: a vertical, mas acompanha a moto quando ela anda em chão muito
## inclinado (dentro do looping, a câmera gira junto em vez de ficar do lado de fora).
var _up: Vector3 = Vector3.UP


func _ready() -> void:
	snap()
	# A corrida põe as motos no grid depois (no _ready dela): ajusta de novo quando tudo
	# estiver montado, senão a câmera começa onde a moto estava na cena.
	snap.call_deferred()


## Vai direto para trás do alvo, sem a transição suave.
func snap() -> void:
	if target == null or not target.is_inside_tree():
		return
	_heading = _flat_forward(_heading)
	global_position = _desired_position()
	look_at(target.global_position + Vector3.UP * look_height)


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var weight := 1.0 - exp(-follow_speed * delta)
	var wanted_up := _target_up()
	_up = _up.slerp(wanted_up, 1.0 - exp(-5.0 * delta)).normalized()
	_heading = _heading.slerp(_flat_forward(_heading), weight).normalized()
	global_position = global_position.lerp(_desired_position(), weight)
	look_at(target.global_position + _up * look_height, _up)


func _desired_position() -> Vector3:
	return target.global_position - _heading * distance + _up * height


## A moto está numa parede ou no looping (chão bem inclinado, rodas nele)?
func _target_up() -> Vector3:
	if target.has_method("is_grounded") and target.is_grounded():
		var normal: Vector3 = target.get("_ground_normal")
		if normal and normal.y < 0.6:
			return target.global_basis.y
	elif _up.y < 0.6:
		# No ar logo depois do looping: vai voltando para a vertical.
		return Vector3.UP
	return Vector3.UP


## Direção da moto no plano perpendicular ao "para cima" atual da câmera.
func _flat_forward(fallback: Vector3) -> Vector3:
	var forward := -target.global_basis.z
	forward -= _up * forward.dot(_up)
	return forward.normalized() if forward.length_squared() > 0.01 else fallback
