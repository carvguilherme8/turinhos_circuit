extends Label
## Texto de depuração no canto da tela com o estado da moto.

@export var bike: Bike


func _process(_delta: float) -> void:
	if bike == null:
		return
	var state := "chão" if bike.is_grounded() else "AR %.1fs" % bike.air_time
	if bike.is_crashed:
		state = "CAIU"
	elif bike.drift_amount > 0.3:
		state = "DERRAPANDO"
	text = "Velocidade: %d km/h\nEstado: %s  (dianteira %s / traseira %s)\nÂngulo de derrapagem: %d°" % [
		roundi(bike.forward_speed * 3.6),
		state,
		"ok" if bike.front_grounded else "-",
		"ok" if bike.rear_grounded else "-",
		roundi(bike.drift_angle),
	]
