extends SceneTree
## Tira as fotos panorâmicas das pistas para o fundo da tela inicial.
## Rodar (com janela, não headless) da raiz do projeto:
##   Godot --path . --resolution 1600x900 -s tools/shot_panoramas.gd
## Salva em assets/ui/panoramas/<pista>_<n>.jpg. Em pista aberta (deserto) as câmeras ficam em
## volta do centro, no alto (a área é medida pelos modelos); nas outras, perto da largada, em
## relação à moto do jogador (o estádio é fechado e a fazenda tem neblina).

const PlayerProfile := preload("res://scripts/core/player_profile.gd")
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")
const OUT_DIR := "res://assets/ui/panoramas"
## Por foto: ângulo em volta do centro (graus), distância e altura (em raios da pista).
const VIEWS := [[35.0, 0.85, 0.32], [160.0, 0.7, 0.22], [265.0, 0.95, 0.42]]
## Fotos perto da moto: [posição da câmera, ponto olhado], nos eixos da moto (-Z = frente).
const BIKE_VIEWS := {
	"stadium_circuit": [[Vector3(-6, 9, 16), Vector3(0, 0, -30)], [Vector3(18, 14, -6), Vector3(-4, 0, -36)],
			[Vector3(-7, 2.5, -13), Vector3(1, 1, 2)]],
	"farm_circuit": [[Vector3(-5, 6, 13), Vector3(0, 0, -28)], [Vector3(14, 9, -6), Vector3(-2, 0, -30)],
			[Vector3(-6, 2.2, -11), Vector3(1, 1, 2)]],
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	PauseMenu.skip_start_menu()
	for track in PlayerProfile.TRACKS:
		var id := (track[1] as String).get_file().get_basename()
		var scene := (load(track[1]) as PackedScene).instantiate()
		root.add_child(scene)
		for layer in scene.find_children("*", "CanvasLayer", true, false):
			layer.visible = false
		# deixa a pista montar (terreno, adereços) e a física assentar a moto
		for i in 30:
			await process_frame
		var shots := _shots(scene, id)
		var camera := Camera3D.new()
		camera.fov = 62.0
		camera.far = 2000.0
		scene.add_child(camera)
		camera.make_current()
		# neblina mais fraca na foto (a pista aparece, o clima continua)
		for env in scene.find_children("*", "WorldEnvironment", true, false):
			var environment := (env as WorldEnvironment).environment
			if environment and environment.fog_enabled:
				environment.fog_density *= 0.4
		for n in shots.size():
			camera.look_at_from_position(shots[n][0], shots[n][1])
			for i in 6:
				await process_frame
			var path := "%s/%s_%d.jpg" % [OUT_DIR, id, n + 1]
			root.get_texture().get_image().save_jpg(ProjectSettings.globalize_path(path), 0.85)
			print("salvo ", path)
		scene.queue_free()
		await process_frame
	quit()


## Posições das câmeras: [posição, alvo] no mundo.
func _shots(scene: Node, id: String) -> Array:
	var shots := []
	var bike := get_first_node_in_group("player_bike") as Node3D
	if BIKE_VIEWS.has(id) and bike:
		var basis := Basis(Vector3.UP, bike.global_basis.get_euler().y)
		for view in BIKE_VIEWS[id]:
			shots.append([bike.global_position + basis * (view[0] as Vector3),
					bike.global_position + basis * (view[1] as Vector3)])
		return shots
	var bounds := _bounds(scene)
	var center := bounds.get_center()
	center.y = 0.0
	var radius := maxf(bounds.size.x, bounds.size.z) * 0.5
	for view in VIEWS:
		var angle := deg_to_rad(float(view[0]))
		var pos: Vector3 = center + Vector3(cos(angle), 0.0, sin(angle)) * radius * float(view[1])
		pos.y = radius * float(view[2])
		shots.append([pos, center + Vector3.UP * radius * 0.02])
	return shots


## Área da pista: soma das caixas dos modelos, sem os gigantes (céu, chão infinito).
func _bounds(scene: Node) -> AABB:
	var total := AABB()
	var first := true
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.visible or mesh.mesh == null:
			continue
		var box := mesh.global_transform * mesh.get_aabb()
		if box.size.x > 600.0 or box.size.z > 600.0:
			continue
		total = box if first else total.merge(box)
		first = false
	return total
