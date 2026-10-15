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


func _ready() -> void:
	if target:
		_heading = _flat_forward(_heading)
		global_position = _desired_position()
		look_at(target.global_position + Vector3.UP * look_height)


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var weight := 1.0 - exp(-follow_speed * delta)
	_heading = _heading.slerp(_flat_forward(_heading), weight).normalized()
	global_position = global_position.lerp(_desired_position(), weight)
	look_at(target.global_position + Vector3.UP * look_height)


func _desired_position() -> Vector3:
	return target.global_position - _heading * distance + Vector3.UP * height


func _flat_forward(fallback: Vector3) -> Vector3:
	var forward := -target.global_basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 0.01 else fallback
