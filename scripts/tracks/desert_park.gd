@tool
extends Node3D
## Parque do Deserto (andar livre): vale de areia plano no meio (onde ficam as rampas, loopings
## e argolas, na altura 0), dunas em volta e paredões de arenito fechando o mapa. Gera também
## mesas de pedra, terra batida em volta das atrações e os objetos do deserto (cactos, pedras,
## tambores, contêineres...). Fica em cache como a fazenda: trocar de mapa é rápido.

const VoxelProps := preload("res://scripts/tracks/voxel_props.gd")

## Raio do vale plano, onde começam as dunas e onde começam os paredões (m).
@export var floor_radius: float = 118.0
@export var cliff_radius: float = 148.0
@export var cliff_height: float = 30.0
@export var dune_height: float = 2.5
@export var map_half_size: float = 185.0
@export var cell: float = 2.5
## Mesas de pedra: (x, z, raio, altura).
@export var mesas: Array[Vector4] = []
## Áreas de terra batida e sem objetos em volta das atrações: (x, z, raio).
@export var keep_out: PackedVector3Array = PackedVector3Array()
## Contêineres posicionados à mão (obstáculos para pular por cima): (x, z, giro em graus).
@export var container_spots: PackedVector3Array = PackedVector3Array()
@export var terrain_material: Material
@export var prop_count: int = 170
@export var prop_seed: int = 3

static var _cache := {}

var _generated: Node3D
var _heights := PackedFloat32Array()
var _cols := 0


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if _generated:
		_generated.free()
	var key := _cache_key()
	if _cache.has(key):
		var entry: Dictionary = _cache[key]
		_generated = (entry["scene"] as PackedScene).instantiate()
		add_child(_generated)
		_heights = entry["heights"]
		_cols = entry["cols"]
		return
	_generated = Node3D.new()
	_generated.name = "_Generated"
	add_child(_generated)
	_build_terrain()
	_build_props()
	for node in _generated.find_children("*", "", true, false):
		node.owner = _generated
	var packed := PackedScene.new()
	packed.pack(_generated)
	_cache[key] = {"scene": packed, "heights": _heights, "cols": _cols}


func _cache_key() -> int:
	var values := []
	for prop in get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop.usage & PROPERTY_USAGE_STORAGE:
			values.append(get(prop.name))
	return str(values).hash()


## Altura do chão natural em (x, z): vale plano, dunas, mesas e paredões.
func ground_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var d := p.length()
	var h := 0.0
	# dunas: só fora do vale plano
	var dunes := smoothstep(floor_radius - 6.0, floor_radius + 14.0, d)
	h += dunes * dune_height * (0.6 + 0.4 * sin(x * 0.07 + z * 0.03)) * (0.5 + 0.5 * sin(x * 0.045) * cos(z * 0.052))
	# paredões em degraus (camadas de arenito)
	var wall := smoothstep(cliff_radius, cliff_radius + 12.0, d + sin(atan2(z, x) * 7.0) * 5.0)
	h += floor(wall * 6.0) / 6.0 * cliff_height
	for mesa in mesas:
		var md := p.distance_to(Vector2(mesa.x, mesa.y)) + sin(atan2(z - mesa.y, x - mesa.x) * 5.0) * 1.5
		var top := 1.0 - smoothstep(mesa.z - 3.0, mesa.z, md)
		h = maxf(h, floor(top * 4.0) / 4.0 * mesa.w)
	return h


func height_at(x: float, z: float) -> float:
	if _heights.is_empty():
		return ground_height(x, z)
	var g := (Vector2(x, z) + Vector2.ONE * map_half_size) / cell
	var c := clampi(int(g.x), 0, _cols - 2)
	var r := clampi(int(g.y), 0, _cols - 2)
	var fx := clampf(g.x - c, 0.0, 1.0)
	var fy := clampf(g.y - r, 0.0, 1.0)
	var h0 := lerpf(_heights[r * _cols + c], _heights[r * _cols + c + 1], fx)
	var h1 := lerpf(_heights[(r + 1) * _cols + c], _heights[(r + 1) * _cols + c + 1], fx)
	return lerpf(h0, h1, fy)


func _build_terrain() -> void:
	_cols = int(map_half_size * 2.0 / cell) + 1
	var n := _cols
	_heights.resize(n * n)
	var dirt := PackedFloat32Array()
	dirt.resize(n * n)
	for r in n:
		for c in n:
			var x := -map_half_size + c * cell
			var z := -map_half_size + r * cell
			_heights[r * n + c] = ground_height(x, z)
			var amount := 0.0
			for k in keep_out:
				var d := Vector2(x, z).distance_to(Vector2(k.x, k.y))
				amount = maxf(amount, 1.0 - smoothstep(k.z * 0.75, k.z, d))
			dirt[r * n + c] = amount
	var tri_count := (n - 1) * (n - 1) * 2
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	positions.resize(tri_count * 3)
	normals.resize(tri_count * 3)
	colors.resize(tri_count * 3)
	var k := 0
	for r in n - 1:
		for c in n - 1:
			var i00 := r * n + c
			for tri in [[i00, i00 + 1, i00 + n + 1], [i00, i00 + n + 1, i00 + n]]:
				var pts: Array[Vector3] = []
				for idx: int in tri:
					pts.append(Vector3(-map_half_size + (idx % n) * cell, _heights[idx], -map_half_size + (idx / n) * cell))
				var normal := (pts[2] - pts[0]).cross(pts[1] - pts[0]).normalized()
				for j in 3:
					positions[k] = pts[j]
					normals[k] = normal
					colors[k] = Color(dirt[tri[j]], 0.0, 0.0)
					k += 1
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, terrain_material)
	var instance := MeshInstance3D.new()
	instance.name = "Terrain"
	instance.mesh = mesh
	_generated.add_child(instance)
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	var shape := CollisionShape3D.new()
	var faces := ConcavePolygonShape3D.new()
	faces.set_faces(positions)
	shape.shape = faces
	body.add_child(shape)
	_generated.add_child(body)
	# chão sem fim em volta, mais alto que o vale (os paredões o escondem)
	var outer := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * 3000.0
	plane.material = terrain_material
	outer.mesh = plane
	outer.position.y = cliff_height - 0.5
	outer.name = "OuterGround"
	_generated.add_child(outer)


func _clear(x: float, z: float, margin: float) -> bool:
	for k in keep_out:
		if Vector2(x, z).distance_to(Vector2(k.x, k.y)) < k.z + margin:
			return false
	return true


func _build_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = prop_seed
	var groups := {}
	var placed := 0
	var tries := 0
	while placed < prop_count and tries < prop_count * 30:
		tries += 1
		var x := rng.randf_range(-cliff_radius, cliff_radius)
		var z := rng.randf_range(-cliff_radius, cliff_radius)
		var d := Vector2(x, z).length()
		if d > cliff_radius - 2.0 or not _clear(x, z, 4.0):
			continue
		var roll := rng.randf()
		var kind := "saguaro"
		if roll < 0.2:
			kind = "barrel_cactus"
		elif roll < 0.35:
			kind = "tumbleweed"
		elif roll < 0.55:
			kind = "rock_red"
		elif roll < 0.6:
			kind = "skull"
		elif roll < 0.66 and d < floor_radius:
			kind = "drums"
		placed += 1
		VoxelProps.add(groups, VoxelProps.variant(kind, rng), Vector3(x, height_at(x, z) - 0.1, z),
				rng.randf() * TAU, rng.randf_range(0.85, 1.2))
	for k in container_spots.size():
		var c := container_spots[k]
		VoxelProps.add(groups, "container_%d" % (k % 3), Vector3(c.x, height_at(c.x, c.y) - 0.05, c.y), deg_to_rad(c.z))
	VoxelProps.spawn(_generated, groups)
