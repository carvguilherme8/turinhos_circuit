extends Node3D
## Cena provisória de verificação: se você apertou F5 e viu isto, o projeto está configurado.
## Será substituída pela cena de corrida no Marco 1 (ver docs/ROADMAP.md).

func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_placeholder_bike()
	_build_camera()
	_build_label()


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("4a90d9")
	sky_mat.sky_horizon_color = Color("f2c38f")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)


func _build_ground() -> void:
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("8b5a2b")  # terra
	mesh.material_override = mat
	add_child(mesh)

	# Uma rampa low poly só para dar escala à cena.
	var ramp := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(6, 2, 4)
	prism.left_to_right = 1.0
	ramp.mesh = prism
	ramp.position = Vector3(0, 1, -10)
	ramp.rotation_degrees.y = 90
	var ramp_mat := StandardMaterial3D.new()
	ramp_mat.albedo_color = Color("a0703f")
	ramp.material_override = ramp_mat
	add_child(ramp)


func _build_placeholder_bike() -> void:
	var bike := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.4, 0.8, 1.8)
	bike.mesh = box
	bike.position = Vector3(0, 0.6, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("e8572a")
	bike.material_override = mat
	bike.name = "MotoProvisoria"
	add_child(bike)


func _build_camera() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(4, 3, 6)
	add_child(cam)
	cam.look_at(Vector3(0, 0.6, -2))
	cam.current = true


func _build_label() -> void:
	var layer := CanvasLayer.new()
	var label := Label.new()
	label.text = "Turinhos Circuit — projeto configurado!\nGodot %s" % Engine.get_version_info().string
	label.position = Vector2(24, 24)
	label.add_theme_font_size_override("font_size", 22)
	layer.add_child(label)
	add_child(layer)
