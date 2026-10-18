extends Node3D
## Chuva: gotas caindo numa caixa em volta da câmera ativa (acompanha a câmera, então cobre
## a pista toda sem gastar partículas no mapa inteiro), som de chuva e, nas motos da cena, a
## poeira da roda traseira vira lama (torrões marrons, mais pesados).
## Continua com o jogo pausado (chove atrás do menu também).

@export var drop_count: int = 5000
## Tamanho da caixa de chuva em volta da câmera (m) e altura de onde as gotas caem.
@export var area: float = 46.0
@export var height: float = 16.0
@export var fall_speed: float = 24.0
## Vento: inclina as gotas (m/s).
@export var wind: Vector3 = Vector3(2.5, 0.0, 1.0)
@export var drop_color: Color = Color(0.78, 0.82, 0.9, 0.28)
@export var rain_sound: AudioStream
@export var rain_volume_db: float = -9.0
## Lama que as motos levantam (cores do torrão, do mais escuro ao mais claro).
@export var mud_dark: Color = Color(0.22, 0.13, 0.08)
@export var mud_light: Color = Color(0.42, 0.26, 0.15)

var _drops: GPUParticles3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_drops = _make_rain()
	add_child(_drops)
	if rain_sound:
		var player := AudioStreamPlayer.new()
		player.stream = rain_sound
		player.volume_db = rain_volume_db
		player.autoplay = true
		add_child(player)
	_muddy_bikes.call_deferred()


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	# A caixa fica um pouco à frente da câmera: é para lá que o jogador olha.
	var ahead := -camera.global_basis.z
	ahead.y = 0.0
	_drops.global_position = camera.global_position + ahead.normalized() * area * 0.2 + Vector3.UP * height * 0.5


func _make_rain() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(area * 0.5, 0.5, area * 0.5)
	var velocity := Vector3(0.0, -fall_speed, 0.0) + wind
	process.direction = velocity.normalized()
	process.spread = 3.0
	process.initial_velocity_min = velocity.length() * 0.9
	process.initial_velocity_max = velocity.length() * 1.1
	process.gravity = Vector3.ZERO
	process.particle_flag_align_y = true  # a gota (comprida) aponta na direção em que cai

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = drop_color
	material.disable_receive_shadows = true
	var streak := BoxMesh.new()
	streak.size = Vector3(0.015, 0.45, 0.015)
	streak.material = material

	var particles := GPUParticles3D.new()
	particles.name = "Drops"
	particles.amount = drop_count
	particles.lifetime = height * 1.6 / fall_speed
	particles.preprocess = particles.lifetime
	particles.process_material = process
	particles.draw_pass_1 = streak
	particles.local_coords = false
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(Vector3(-area, -height * 2.0, -area), Vector3(area * 2.0, height * 3.0, area * 2.0))
	return particles


## Troca a poeira da roda traseira de cada moto da cena por lama.
func _muddy_bikes() -> void:
	for node in get_tree().root.find_children("*", "GPUParticles3D", true, false):
		if node.name != "RearDust" or not (node.process_material is ParticleProcessMaterial):
			continue
		var mud := (node.process_material as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
		var gradient := Gradient.new()
		gradient.set_color(0, mud_dark)
		gradient.set_color(1, mud_light)
		var ramp := GradientTexture1D.new()
		ramp.gradient = gradient
		mud.color_initial_ramp = ramp
		mud.gravity = Vector3(0.0, -16.0, 0.0)
		mud.initial_velocity_min *= 1.3
		mud.initial_velocity_max *= 1.4
		mud.damping_min *= 0.5
		mud.damping_max *= 0.5
		node.process_material = mud
