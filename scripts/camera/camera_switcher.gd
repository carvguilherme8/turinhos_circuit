extends Node
## Alterna entre a câmera de perseguição e a câmera do guidão (ação "trocar_camera").
## Na câmera do guidão o piloto fica escondido e só o guidão aparece girando.

@export var bike: Bike
@export var chase_camera: Camera3D

var first_person: bool = false


func _ready() -> void:
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("trocar_camera"):
		first_person = not first_person
		_apply()
		get_viewport().set_input_as_handled()


func _apply() -> void:
	if bike == null or bike.first_person_camera == null:
		return
	if first_person:
		bike.first_person_camera.make_current()
	elif chase_camera:
		chase_camera.make_current()
	if bike.rider:
		bike.rider.visible = not first_person
