extends SceneTree
## Renderiza a moto com o piloto (visual do perfil), fundo transparente, para o ícone do app.
##   Godot --path . --resolution 1024x1024 -s tools/render_icon_bike.gd -- <saida.png> -62 1.4 20
## args: arquivo de saída, giro da moto (graus), altura da câmera (m), empinada (graus).
## Depois: python tools/gen_icon.py <saida.png>
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var a := OS.get_cmdline_user_args()
	root.transparent_bg = true
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.85, 0.82, 0.9)
	env.environment.ambient_light_energy = 0.7
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -50, 0)
	sun.light_energy = 1.3
	world.add_child(sun)
	var bike := (load("res://scenes/bike/bike.tscn") as PackedScene).instantiate()
	bike.player_controlled = false
	world.add_child(bike)
	bike.freeze = true
	bike.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(a[1]))) * Basis(Vector3.RIGHT, deg_to_rad(float(a[3]))), Vector3(0, 0.6, 0))
	for layer in bike.find_children("*", "GPUParticles3D", true, false):
		layer.emitting = false
	var cam := Camera3D.new()
	cam.fov = 30
	world.add_child(cam)
	cam.look_at_from_position(Vector3(0, float(a[2]), 6.2), Vector3(0, 1.05, 0))
	for c in bike.find_children("*", "Camera3D", true, false):
		c.current = false
		c.queue_free()
	await process_frame
	cam.make_current()
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(a[0])
	quit()
