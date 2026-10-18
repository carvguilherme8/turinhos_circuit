extends RefCounted
## Modelos voxel do cenário (árvores, público, tendas, fazenda...), montados por código.
## Cada modelo é uma grade de blocos coloridos (cada bloco num tom levemente diferente, para o
## visual "pixelado"); só as faces que ficam à mostra viram malha. As malhas ficam em cache
## por nome ("oak_2", "person_5"...): gerar de novo é instantâneo.
## Uso: `const VoxelProps := preload("res://scripts/tracks/voxel_props.gd")` e
## `VoxelProps.mesh("oak_0")`. A base de cada modelo fica em y = 0, centrada em x/z.

const VARIANTS := {
	"oak": 5, "eucalyptus": 3, "pine": 3, "ipe_yellow": 2, "ipe_pink": 2, "bush": 4, "rock": 4,
	"person": 10, "tent": 4, "hay": 2, "tires_black": 2, "tires_white": 2, "barn": 1,
	"water_tower": 1, "tractor": 1, "cow": 3, "toilet": 1, "flag": 4, "saguaro": 4, "barrel_cactus": 2, "tumbleweed": 2, "rock_red": 3,
	"drums": 3, "container": 3, "skull": 1,
}

## Faixa de altura (m) cujos blocos formam a caixa de colisão de cada tipo; sem entrada = sem
## colisão (a moto atravessa). Árvores: só o tronco; bandeira: só o mastro.
const COLLIDERS := {
	"oak": Vector2(0.0, 2.0), "ipe_yellow": Vector2(0.0, 2.0), "ipe_pink": Vector2(0.0, 2.0),
	"eucalyptus": Vector2(0.0, 2.0), "pine": Vector2(0.0, 1.4), "rock": Vector2(0.0, 99.0),
	"person": Vector2(0.0, 99.0), "tent": Vector2(0.0, 99.0), "hay": Vector2(0.0, 99.0),
	"tires_black": Vector2(0.0, 99.0), "tires_white": Vector2(0.0, 99.0), "barn": Vector2(0.0, 99.0),
	"water_tower": Vector2(0.0, 99.0), "tractor": Vector2(0.0, 99.0), "cow": Vector2(0.0, 99.0),
	"toilet": Vector2(0.0, 99.0), "flag": Vector2(0.0, 1.9), "saguaro": Vector2(0.0, 1.4),
	"barrel_cactus": Vector2(0.0, 99.0), "rock_red": Vector2(0.0, 99.0), "drums": Vector2(0.0, 99.0),
	"container": Vector2(0.0, 99.0),
}

static var _meshes := {}
static var _colliders := {}
static var _material: StandardMaterial3D


static func mesh(model_name: String) -> ArrayMesh:
	if _meshes.has(model_name):
		return _meshes[model_name]
	var parts := model_name.rsplit("_", true, 1)
	var kind := parts[0]
	var seed_value := int(parts[1]) if parts.size() > 1 and parts[1].is_valid_int() else 0
	var v := Vox.new(kind.hash() + seed_value * 7919)
	match kind:
		"oak": _oak(v, false, Color())
		"ipe_yellow": _oak(v, true, Color(1.0, 0.84, 0.18))
		"ipe_pink": _oak(v, true, Color(0.96, 0.46, 0.72))
		"eucalyptus": _eucalyptus(v)
		"pine": _pine(v)
		"bush": _bush(v)
		"rock": _rock(v)
		"person": _person(v, seed_value)
		"tent": _tent(v, seed_value)
		"hay": _hay(v)
		"tires_black": _tires(v, false)
		"tires_white": _tires(v, true)
		"barn": _barn(v)
		"water_tower": _water_tower(v)
		"tractor": _tractor(v)
		"cow": _cow(v)
		"toilet": _toilet(v)
		"flag": _flag(v, seed_value)
		"saguaro": _saguaro(v)
		"barrel_cactus": _barrel_cactus(v)
		"tumbleweed": _tumbleweed(v)
		"rock_red": _rock_red(v)
		"drums": _drums(v, seed_value)
		"container": _container(v, seed_value)
		"skull": _skull(v)
		_: push_error("modelo voxel desconhecido: " + model_name)
	var result := v.build(material())
	_meshes[model_name] = result
	if COLLIDERS.has(kind):
		_colliders[model_name] = v.band_aabb(COLLIDERS[kind].x, COLLIDERS[kind].y)
	return result


## Caixa de colisão do modelo (no espaço do modelo); tamanho zero = sem colisão.
static func collider(model_name: String) -> AABB:
	mesh(model_name)
	return _colliders.get(model_name, AABB())


## Cria, dentro de `parent`, um MultiMeshInstance por modelo (todas as cópias desenhadas de
## uma vez) e uma caixa de colisão por cópia (num StaticBody "PropsBody").
## `groups`: nome do modelo -> Array[Transform3D].
static func spawn(parent: Node3D, groups: Dictionary) -> void:
	var body := parent.get_node_or_null("PropsBody") as StaticBody3D
	if body == null:
		body = StaticBody3D.new()
		body.name = "PropsBody"
		parent.add_child(body)
	for model in groups:
		var transforms: Array[Transform3D] = groups[model]
		var box := collider(model)
		if box.size != Vector3.ZERO:
			for t in transforms:
				var shape := CollisionShape3D.new()
				var box_shape := BoxShape3D.new()
				box_shape.size = box.size * t.basis.get_scale()
				shape.shape = box_shape
				shape.transform = Transform3D(t.basis.orthonormalized(), t * box.get_center())
				body.add_child(shape)
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh(model)
		multimesh.instance_count = transforms.size()
		for k in transforms.size():
			multimesh.set_instance_transform(k, transforms[k])
		var instance := MultiMeshInstance3D.new()
		instance.name = "Props_" + model
		instance.multimesh = multimesh
		parent.add_child(instance)


## Junta uma cópia de `model` (girada `yaw`, no tamanho `scale`, em `position`) em `groups`.
static func add(groups: Dictionary, model: String, position: Vector3, yaw: float, scale := 1.0) -> void:
	if not groups.has(model):
		groups[model] = [] as Array[Transform3D]
	groups[model].append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale), position))


## Nome de uma variante sorteada do tipo (ex.: "oak" -> "oak_3").
static func variant(kind: String, rng: RandomNumberGenerator) -> String:
	return "%s_%d" % [kind, rng.randi() % VARIANTS.get(kind, 1)]


static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		_material.roughness = 1.0
	return _material


# ---------------------------------------------------------------- grade de blocos

class Vox:
	var size := 0.25  # tamanho do bloco (m)
	var cells := {}  # Vector3i -> Color
	var decor := {}  # blocos só de enfeite (sem colisão), ex.: flores caídas
	var rng := RandomNumberGenerator.new()
	var jitter := 0.06

	func _init(seed_value: int) -> void:
		rng.seed = seed_value

	func put(c: Vector3i, color: Color, amount := -1.0) -> void:
		var j := jitter if amount < 0.0 else amount
		cells[c] = color * (1.0 + rng.randf_range(-j, j))

	func put_decor(c: Vector3i, color: Color) -> void:
		put(c, color)
		decor[c] = true

	func erase(c: Vector3i) -> void:
		cells.erase(c)

	## Caixa cheia de `a` até `b` (inclusive).
	func box(a: Vector3i, b: Vector3i, color: Color, amount := -1.0) -> void:
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
				for z in range(mini(a.z, b.z), maxi(a.z, b.z) + 1):
					put(Vector3i(x, y, z), color, amount)

	## Elipsoide com borda irregular (ruído); `fill` decide a cor de cada bloco.
	func blob(center: Vector3, radii: Vector3, fill: Callable, roughness := 0.25) -> void:
		for x in range(int(center.x - radii.x) - 1, int(center.x + radii.x) + 2):
			for y in range(int(center.y - radii.y) - 1, int(center.y + radii.y) + 2):
				for z in range(int(center.z - radii.z) - 1, int(center.z + radii.z) + 2):
					var d := Vector3((x - center.x) / radii.x, (y - center.y) / radii.y, (z - center.z) / radii.z)
					if d.length() + rng.randf_range(-roughness, roughness) < 1.0:
						var c := Vector3i(x, y, z)
						put(c, fill.call(c, d))

	## Cilindro ao longo de Y (raio em blocos).
	func cylinder(center: Vector3, radius: float, y0: int, y1: int, color: Color, hollow := 0.0) -> void:
		for x in range(int(center.x - radius) - 1, int(center.x + radius) + 2):
			for z in range(int(center.z - radius) - 1, int(center.z + radius) + 2):
				var r := Vector2(x + 0.5 - center.x, z + 0.5 - center.z).length()
				if r <= radius and r >= hollow:
					for y in range(y0, y1 + 1):
						put(Vector3i(x, y, z), color)

	var offset := Vector3.ZERO

	## Caixa (no espaço do modelo) que envolve os blocos entre as alturas `y0` e `y1` (m).
	func band_aabb(y0: float, y1: float) -> AABB:
		var box := AABB()
		var first := true
		for c: Vector3i in cells:
			var y := (c.y + offset.y) * size
			if y < y0 - 0.001 or y > y1 or decor.has(c):
				continue
			var cell := AABB((Vector3(c) + offset) * size, Vector3.ONE * size)
			box = cell if first else box.merge(cell)
			first = false
		return box

	## Gera a malha: só as faces sem vizinho; base em y = 0, centro em x/z = 0.
	func build(material: Material) -> ArrayMesh:
		var lo := Vector3i(1 << 20, 1 << 20, 1 << 20)
		var hi := -lo
		for c in cells:
			lo = Vector3i(mini(lo.x, c.x), mini(lo.y, c.y), mini(lo.z, c.z))
			hi = Vector3i(maxi(hi.x, c.x), maxi(hi.y, c.y), maxi(hi.z, c.z))
		offset = Vector3(-(lo.x + hi.x + 1) * 0.5, -lo.y, -(lo.z + hi.z + 1) * 0.5)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var dirs := [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD]
		for c: Vector3i in cells:
			var color: Color = cells[c]
			for d: Vector3i in dirs:
				if cells.has(c + d):
					continue
				_face(st, (Vector3(c) + offset) * size, Vector3(d), color)
		st.set_material(material)
		return st.commit()

	func _face(st: SurfaceTool, base: Vector3, n: Vector3, color: Color) -> void:
		# Um pouco mais escuro embaixo e nas laterais (como as faces do Minecraft).
		var light := 1.0 if n.y > 0.5 else (0.72 if n.y < -0.5 else (0.9 if absf(n.x) > 0.5 else 0.84))
		var col := Color(color.r * light, color.g * light, color.b * light)
		var s := size
		var u: Vector3
		var w: Vector3
		if absf(n.x) > 0.5:
			u = Vector3(0, s, 0); w = Vector3(0, 0, s)
		elif absf(n.y) > 0.5:
			u = Vector3(0, 0, s); w = Vector3(s, 0, 0)
		else:
			u = Vector3(s, 0, 0); w = Vector3(0, s, 0)
		var center := base + Vector3(s, s, s) * 0.5 + n * s * 0.5
		var p0 := center - u * 0.5 - w * 0.5
		var quad := [p0, p0 + u, p0 + u + w, p0 + w]
		# Ordem dos vértices para a face olhar para fora.
		var flip := u.cross(w).dot(n) > 0.0
		var order := [0, 2, 1, 0, 3, 2] if flip else [0, 1, 2, 0, 2, 3]
		st.set_color(col)
		st.set_normal(n)
		for k in order:
			st.add_vertex(quad[k])


# ---------------------------------------------------------------- árvores

static func _oak(v: Vox, flowering: bool, flower: Color) -> void:
	v.size = 0.4
	var r := v.rng
	var h := r.randi_range(6, 9)
	var bark := Color(0.4, 0.29, 0.19)
	v.box(Vector3i(0, 0, 0), Vector3i(1, h, 1), bark, 0.1)
	# raízes e galhos saindo do tronco
	for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		if r.randf() < 0.6:
			v.put(Vector3i(0, 0, 0) + d * 2 if d.x + d.z < 0 else Vector3i(1, 0, 1) + d, bark.darkened(0.1))
	for b in r.randi_range(2, 3):
		var dir := Vector3i([1, -1][r.randi() % 2], 0, [1, -1][r.randi() % 2])
		var start := Vector3i(0, h - r.randi_range(1, 3), 0)
		for k in range(1, 4):
			v.put(start + Vector3i(dir.x * k, k / 2, dir.z * k), bark)
	var greens: Array[Color] = [Color(0.36, 0.62, 0.27), Color(0.3, 0.55, 0.24), Color(0.42, 0.66, 0.3), Color(0.33, 0.58, 0.32)]
	var leaf := greens[r.randi() % greens.size()]
	var rx := r.randf_range(3.6, 5.0)
	var center := Vector3(0.5 + r.randf_range(-0.6, 0.6), h + r.randf_range(1.0, 2.0), 0.5 + r.randf_range(-0.6, 0.6))
	var fill := func(_c: Vector3i, d: Vector3) -> Color:
		var base := flower if flowering and r.randf() < 0.85 else leaf
		return base.lightened(clampf(d.y * 0.12, -0.1, 0.12))
	v.blob(center, Vector3(rx, rx * r.randf_range(0.6, 0.8), rx * r.randf_range(0.85, 1.1)), fill)
	# mais um ou dois tufos para a copa não ser uma bola
	for k in r.randi_range(1, 2):
		var off := Vector3(r.randf_range(-2.5, 2.5), r.randf_range(0.5, 2.0), r.randf_range(-2.5, 2.5))
		v.blob(center + off, Vector3(rx, rx, rx) * r.randf_range(0.45, 0.6), fill)
	if flowering:
		# flores caídas em volta
		for k in 40:
			var a := r.randf() * TAU
			var dist := r.randf_range(1.5, rx + 1.0)
			v.put_decor(Vector3i(int(cos(a) * dist), 0, int(sin(a) * dist)), flower)


static func _eucalyptus(v: Vox) -> void:
	v.size = 0.4
	var r := v.rng
	var h := r.randi_range(16, 22)
	for y in h:
		var c := Color(0.86, 0.82, 0.74) if (y + r.randi() % 3) % 4 else Color(0.62, 0.58, 0.52)
		v.put(Vector3i(0, y, 0), c, 0.05)
		if y < 3:
			v.put(Vector3i(1, y, 0), c.darkened(0.1))
	var leaf := Color(0.48, 0.6, 0.44)
	var fill := func(_c: Vector3i, d: Vector3) -> Color:
		return leaf.lightened(clampf(d.y * 0.1, -0.08, 0.1))
	for k in r.randi_range(3, 4):
		var c := Vector3(r.randf_range(-2.5, 2.5), h - r.randf_range(0.0, 6.0), r.randf_range(-2.5, 2.5))
		v.blob(c, Vector3(2.4, 1.6, 2.4) * r.randf_range(0.8, 1.2), fill, 0.35)
		# galho até a copa
		var steps := int(maxf(absf(c.x), absf(c.z)))
		for s in steps:
			var t := float(s) / maxf(steps, 1)
			v.put(Vector3i(int(c.x * t), int(c.y - 1), int(c.z * t)), Color(0.7, 0.66, 0.58))


static func _pine(v: Vox) -> void:
	v.size = 0.4
	var r := v.rng
	var h := r.randi_range(14, 18)
	v.box(Vector3i(0, 0, 0), Vector3i(0, h, 0), Color(0.36, 0.26, 0.18))
	var leaf := Color(0.18, 0.38, 0.25)
	var y := 4
	var radius := r.randf_range(4.0, 4.6)
	while y < h + 2:
		for x in range(-int(radius), int(radius) + 1):
			for z in range(-int(radius), int(radius) + 1):
				var d := Vector2(x, z).length()
				if d <= radius + r.randf_range(-0.6, 0.3):
					v.put(Vector3i(x, y, z), leaf.lightened(r.randf_range(0.0, 0.08)))
					if d < radius - 1.0:
						v.put(Vector3i(x, y + 1, z), leaf.darkened(0.05))
		y += 2
		radius -= 0.55 if radius > 2.0 else 0.35
		if radius < 0.6:
			break
	v.put(Vector3i(0, y + 1, 0), leaf)


static func _bush(v: Vox) -> void:
	v.size = 0.3
	var r := v.rng
	var leaf := Color(0.3, 0.52, 0.24)
	var dots: Array[Color] = [Color(0.95, 0.3, 0.3), Color(0.98, 0.9, 0.4), Color(0.95, 0.95, 0.95), Color(0.7, 0.4, 0.9)]
	var dot := dots[r.randi() % dots.size()]
	var fill := func(_c: Vector3i, d: Vector3) -> Color:
		return dot if r.randf() < 0.08 else leaf.lightened(clampf(d.y * 0.15, -0.1, 0.12))
	for k in r.randi_range(2, 3):
		v.blob(Vector3(r.randf_range(-2, 2), 2.0, r.randf_range(-2, 2)), Vector3(3.0, 2.4, 3.0) * r.randf_range(0.8, 1.1), fill, 0.3)


static func _rock(v: Vox) -> void:
	v.size = 0.25
	var r := v.rng
	var gray := Color(0.56, 0.55, 0.52)
	var fill := func(_c: Vector3i, d: Vector3) -> Color:
		if d.y > 0.4 and r.randf() < 0.45:
			return Color(0.36, 0.5, 0.26)  # musgo em cima
		return gray.darkened(r.randf_range(0.0, 0.25))
	v.blob(Vector3(0, 1.5, 0), Vector3(r.randf_range(3, 5), r.randf_range(2, 3), r.randf_range(3, 4.5)), fill, 0.3)
	for k in r.randi_range(1, 3):
		v.blob(Vector3(r.randf_range(-5, 5), 0.8, r.randf_range(-5, 5)), Vector3(1.6, 1.2, 1.6) * r.randf_range(0.8, 1.4), fill, 0.3)


# ---------------------------------------------------------------- gente e estruturas

static func _person(v: Vox, index: int) -> void:
	v.size = 0.125
	v.jitter = 0.04
	var r := v.rng
	var shirts: Array[Color] = [Color("e83a3a"), Color("2a5ce8"), Color("f0d23c"), Color("2fb35a"), Color("f2f2ec"),
		Color("f0a020"), Color("8a3ad8"), Color("1a1a22"), Color("e84aa8"), Color("20b8c8")]
	var pants: Array[Color] = [Color(0.2, 0.26, 0.45), Color(0.15, 0.15, 0.18), Color(0.62, 0.52, 0.36), Color(0.3, 0.34, 0.5)]
	var skins: Array[Color] = [Color(0.94, 0.76, 0.6), Color(0.78, 0.56, 0.4), Color(0.56, 0.38, 0.26), Color(0.98, 0.84, 0.7)]
	var hairs: Array[Color] = [Color(0.12, 0.09, 0.07), Color(0.36, 0.22, 0.12), Color(0.86, 0.72, 0.36), Color(0.5, 0.5, 0.5)]
	var shirt := shirts[index % shirts.size()]
	var skin := skins[r.randi() % skins.size()]
	# pernas e tênis
	v.box(Vector3i(0, 0, 0), Vector3i(3, 0, 1), Color(0.9, 0.9, 0.9) if r.randf() < 0.5 else Color(0.2, 0.2, 0.22))
	v.box(Vector3i(0, 1, 0), Vector3i(3, 5, 1), pants[r.randi() % pants.size()])
	v.erase(Vector3i(1, 3, 0)); v.erase(Vector3i(2, 3, 0))  # vão entre as pernas na frente
	# tronco (camiseta com faixa)
	v.box(Vector3i(0, 6, 0), Vector3i(3, 10, 1), shirt)
	if index % 3 == 0:
		v.box(Vector3i(0, 8, 0), Vector3i(3, 8, 1), Color.WHITE)
	# braços: 0 = ao lado, 1 = os dois para cima (torcendo), 2 = um para cima
	var pose := index % 3
	for side in [-1, 4]:
		var up: bool = pose == 1 or (pose == 2 and side == 4)
		if up:
			v.box(Vector3i(side, 10, 0), Vector3i(side, 15, 1), shirt)
			v.box(Vector3i(side, 15, 0), Vector3i(side, 16, 1), skin)
		else:
			v.box(Vector3i(side, 7, 0), Vector3i(side, 10, 1), shirt)
			v.box(Vector3i(side, 5, 0), Vector3i(side, 6, 1), skin)
	# cabeça, olhos e cabelo / boné
	v.box(Vector3i(0, 11, -1), Vector3i(3, 14, 2), skin)
	v.put(Vector3i(1, 13, -1), Color(0.1, 0.1, 0.12), 0.0)
	v.put(Vector3i(2, 13, -1), Color(0.1, 0.1, 0.12), 0.0)
	var hair := hairs[r.randi() % hairs.size()]
	v.box(Vector3i(0, 15, -1), Vector3i(3, 15, 2), hair)
	v.box(Vector3i(0, 12, 2), Vector3i(3, 14, 2), hair)
	if r.randf() < 0.4:
		var cap := shirts[(index + 3) % shirts.size()]
		v.box(Vector3i(0, 15, -1), Vector3i(3, 15, 2), cap)
		v.box(Vector3i(0, 15, -3), Vector3i(3, 15, -2), cap)


static func _tent(v: Vox, index: int) -> void:
	v.size = 0.25
	var colors: Array[Color] = [Color("e83a3a"), Color("2a5ce8"), Color("2fb35a"), Color("f0a020")]
	var color := colors[index % colors.size()]
	var white := Color(0.96, 0.96, 0.92)
	var metal := Color(0.7, 0.72, 0.74)
	for x in [0, 13]:
		for z in [0, 13]:
			v.box(Vector3i(x, 0, z), Vector3i(x, 10, z), metal)
	# teto em degraus, listrado
	for level in 5:
		var a := level * 2 - 1
		var b := 14 - level * 2
		for x in range(a, b + 1):
			for z in range(a, b + 1):
				if x == a or x == b or z == a or z == b or level == 4:
					v.put(Vector3i(x, 11 + level, z), color if (x / 2) % 2 == 0 else white)
	# barrado em volta
	for x in range(-1, 15):
		for z in range(-1, 15):
			if x == -1 or x == 14 or z == -1 or z == 14:
				v.put(Vector3i(x, 10, z), color if (x + z) % 2 == 0 else white)
	# mesa, caixa térmica e copos
	v.box(Vector3i(3, 3, 5), Vector3i(10, 3, 8), Color(0.6, 0.44, 0.28))
	for x in [3, 10]:
		v.box(Vector3i(x, 0, 5), Vector3i(x, 2, 5), Color(0.4, 0.3, 0.2))
		v.box(Vector3i(x, 0, 8), Vector3i(x, 2, 8), Color(0.4, 0.3, 0.2))
	v.box(Vector3i(4, 4, 6), Vector3i(6, 5, 7), Color(0.2, 0.5, 0.9))
	v.box(Vector3i(4, 6, 6), Vector3i(6, 6, 7), white)
	v.put(Vector3i(8, 4, 6), Color(0.95, 0.85, 0.3))
	v.put(Vector3i(9, 4, 7), Color(0.95, 0.3, 0.3))


static func _toilet(v: Vox) -> void:
	v.size = 0.125
	var blue := Color(0.2, 0.44, 0.85)
	v.box(Vector3i(0, 0, 0), Vector3i(8, 18, 8), blue)
	v.box(Vector3i(0, 19, 0), Vector3i(8, 19, 8), Color(0.9, 0.9, 0.9))
	v.box(Vector3i(2, 1, -1), Vector3i(6, 15, -1), blue.darkened(0.15))
	v.put(Vector3i(5, 8, -2), Color(0.85, 0.85, 0.85))
	v.box(Vector3i(3, 13, -2), Vector3i(5, 13, -2), Color(0.85, 0.3, 0.3))


static func _flag(v: Vox, index: int) -> void:
	v.size = 0.125
	var colors: Array[Color] = [Color("e83a3a"), Color("2a5ce8"), Color("f0d23c"), Color("2fb35a")]
	var color := colors[index % colors.size()]
	v.box(Vector3i(0, 0, 0), Vector3i(0, 30, 0), Color(0.85, 0.85, 0.85))
	# bandeira em "pena" (larga em cima, afinando)
	for y in range(16, 30):
		var w := 9 - absi(y - 26) / 2 if y >= 20 else maxi(1, (y - 15) / 2)
		for x in range(1, w + 1):
			v.put(Vector3i(x, y, 0), color if (x + y) % 6 else Color.WHITE)


static func _hay(v: Vox) -> void:
	v.size = 0.15
	var straw := Color(0.86, 0.72, 0.36)
	# fardo redondo deitado (eixo X), com anéis mais escuros nas pontas
	for x in 9:
		for y in 11:
			for z in 11:
				var d := Vector2(y - 5, z - 5).length()
				if d <= 5.3:
					var ring := int(d) % 2 == 0 and (x == 0 or x == 8)
					v.put(Vector3i(x, y, z), straw.darkened(0.2) if ring else straw.lightened(v.rng.randf_range(-0.05, 0.08)))


static func _tires(v: Vox, white: bool) -> void:
	v.size = 0.1
	var base := Color(0.9, 0.9, 0.88) if white else Color(0.13, 0.13, 0.15)
	var tread := base.darkened(0.25)
	var count := 3 + v.rng.randi() % 2
	for k in count:
		var cx := 4.5 + v.rng.randf_range(-0.6, 0.6)
		var cz := 4.5 + v.rng.randf_range(-0.6, 0.6)
		for x in 10:
			for z in 10:
				var d := Vector2(x + 0.5 - cx, z + 0.5 - cz).length()
				if d <= 4.6 and d >= 2.2:
					for y in range(k * 3, k * 3 + 3):
						var outer := d > 3.9 and (x + z + y) % 2 == 0
						v.put(Vector3i(x, y, z), tread if outer else base)


static func _barn(v: Vox) -> void:
	v.size = 0.5
	var red := Color(0.66, 0.2, 0.17)
	var white := Color(0.95, 0.94, 0.9)
	var roof := Color(0.5, 0.52, 0.56)
	var stone := Color(0.55, 0.54, 0.5)
	var w := 18
	var d := 26
	var wall_h := 10
	# base de pedra e paredes (só a casca)
	for x in w:
		for z in d:
			if x == 0 or x == w - 1 or z == 0 or z == d - 1:
				v.put(Vector3i(x, 0, z), stone)
				for y in range(1, wall_h):
					var plank := red if x % 2 == 0 or z == 0 or z == d - 1 else red.darkened(0.08)
					var corner := (x == 0 or x == w - 1) and (z == 0 or z == d - 1)
					v.put(Vector3i(x, y, z), white if corner else plank)
	# frontão (empenas) e telhado de duas águas em degraus, com beiral
	var half := w / 2
	for level in range(0, half + 1):
		var y := wall_h + level
		for z in [0, d - 1]:
			for x in range(level, w - level):
				v.put(Vector3i(x, y, z), red)
		for z in range(-1, d + 1):
			for x in [level - 1, w - level]:
				v.put(Vector3i(x, y, z), roof.lightened(0.05 if level % 2 else 0.0))
	# portão com X branco na frente e janela do palheiro
	for x in range(5, 13):
		for y in range(1, 8):
			var edge := x == 5 or x == 12 or y == 7
			var cross := absi((x - 5) - (y - 1)) <= 0 or absi((12 - x) - (y - 1)) <= 0 or x == 8 or x == 9
			v.put(Vector3i(x, y, -1), white if edge or cross else red.darkened(0.2))
	for x in range(7, 11):
		for y in range(11, 14):
			var frame := x == 7 or x == 10 or y == 11 or y == 13
			v.put(Vector3i(x, y, -1), white if frame else Color(0.15, 0.1, 0.08))
	# janelinhas laterais
	for z in [6, 13, 20]:
		for side in [-1, w]:
			v.box(Vector3i(side, 4, z), Vector3i(side, 6, z + 2), white)
			v.put(Vector3i(side, 5, z + 1), Color(0.2, 0.3, 0.4))


static func _water_tower(v: Vox) -> void:
	v.size = 0.25
	var wood := Color(0.55, 0.4, 0.26)
	for x in [0, 10]:
		for z in [0, 10]:
			v.box(Vector3i(x, 0, z), Vector3i(x, 22, z), wood)
	for y in [7, 15]:
		for k in 11:
			v.put(Vector3i(k, y, 0), wood); v.put(Vector3i(k, y, 10), wood)
			v.put(Vector3i(0, y, k), wood); v.put(Vector3i(10, y, k), wood)
	v.box(Vector3i(-1, 23, -1), Vector3i(11, 23, 11), wood.darkened(0.1))
	var tank := Color(0.62, 0.66, 0.7)
	v.cylinder(Vector3(5.5, 0, 5.5), 6.5, 24, 33, tank)
	v.cylinder(Vector3(5.5, 0, 5.5), 6.6, 28, 28, Color(0.3, 0.45, 0.75))
	for k in 4:
		v.cylinder(Vector3(5.5, 0, 5.5), 6.0 - k * 1.6, 34 + k, 34 + k, Color(0.5, 0.52, 0.56))


static func _tractor(v: Vox) -> void:
	v.size = 0.125
	var green := Color(0.2, 0.56, 0.24)
	var yellow := Color(0.98, 0.84, 0.2)
	var black := Color(0.12, 0.12, 0.13)
	# rodas traseiras grandes e dianteiras pequenas (eixo X)
	for side in [[-3, -1], [14, 16]]:
		for x in range(side[0], side[1] + 1):
			for y in 15:
				for z in 15:
					var d := Vector2(y - 7, z - 7).length()
					if d <= 7.2:
						v.put(Vector3i(x, y, z + 14), yellow if d < 3.0 else black)
			for y in 9:
				for z in 9:
					var d := Vector2(y - 4, z - 4).length()
					if d <= 4.3:
						v.put(Vector3i(x, y, z), yellow if d < 1.8 else black)
	# chassi, capô, cabine e escapamento
	v.box(Vector3i(0, 4, 0), Vector3i(13, 8, 28), green)
	v.box(Vector3i(2, 9, 0), Vector3i(11, 13, 14), green)
	v.box(Vector3i(3, 9, -1), Vector3i(10, 12, -1), Color(0.7, 0.7, 0.7))
	v.box(Vector3i(1, 9, 17), Vector3i(12, 22, 28), green.darkened(0.1))
	v.box(Vector3i(2, 14, 16), Vector3i(11, 20, 16), Color(0.5, 0.7, 0.85))
	v.box(Vector3i(0, 23, 16), Vector3i(13, 23, 29), Color(0.9, 0.9, 0.88))
	v.box(Vector3i(9, 14, 5), Vector3i(9, 20, 5), black)


static func _cow(v: Vox) -> void:
	v.size = 0.125
	var white := Color(0.94, 0.93, 0.9)
	var black := Color(0.12, 0.11, 0.1)
	var r := v.rng
	var spots: Array[Vector3] = []
	# Manchas na superfície do corpo (de cima e dos lados).
	for k in 9:
		var side := r.randi() % 3
		var x: float = r.randf_range(0, 10) if side != 1 else [0.0, 10.0][r.randi() % 2]
		var y := r.randf_range(9, 16) if side != 2 else 16.0
		spots.append(Vector3(x, y, r.randf_range(0, 16)))
	for x in 11:
		for y in range(8, 17):
			for z in 17:
				var spot := false
				for s in spots:
					if Vector3(x, y, z).distance_to(s) < 2.6:
						spot = true
				v.put(Vector3i(x, y, z), black if spot else white)
	for pos in [Vector3i(1, 0, 1), Vector3i(7, 0, 1), Vector3i(1, 0, 13), Vector3i(7, 0, 13)]:
		v.box(pos, pos + Vector3i(2, 7, 2), white)
		v.box(pos, pos + Vector3i(2, 0, 2), Color(0.3, 0.25, 0.2))
	v.box(Vector3i(2, 12, -6), Vector3i(8, 18, -1), white)
	v.box(Vector3i(3, 12, -7), Vector3i(7, 14, -7), Color(0.95, 0.65, 0.65))
	v.put(Vector3i(3, 16, -7), black); v.put(Vector3i(7, 16, -7), black)
	v.put(Vector3i(1, 19, -3), Color(0.9, 0.86, 0.7)); v.put(Vector3i(9, 19, -3), Color(0.9, 0.86, 0.7))
	v.box(Vector3i(5, 10, 17), Vector3i(5, 15, 17), white)


# ---------------------------------------------------------------- deserto

static func _saguaro(v: Vox) -> void:
	v.size = 0.25
	var r := v.rng
	var green := Color(0.3, 0.52, 0.3)
	var h := r.randi_range(14, 22)
	# tronco 2x2 com sulcos (blocos mais escuros) e espinhos claros
	for y in h:
		for x in 2:
			for z in 2:
				v.put(Vector3i(x, y, z), green.darkened(0.12) if (x + z + y) % 3 == 0 else green)
	v.box(Vector3i(0, h, 0), Vector3i(1, h, 1), green.lightened(0.1))
	var sides: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
	for k in r.randi_range(1, 3):
		var side := sides[r.randi() % 4]
		var y0 := r.randi_range(5, h - 5)
		var out := r.randi_range(2, 3)
		var base := Vector3i(0, y0, 0) + (side * 2 if side.x + side.z > 0 else side)
		for k2 in out:
			v.put(base + side * k2, green)
		var top := base + side * (out - 1)
		for y in range(1, r.randi_range(4, 7)):
			v.put(top + Vector3i(0, y, 0), green)
	var keys := v.cells.keys()
	for k in 30:
		v.put(keys[r.randi() % keys.size()], Color(0.86, 0.84, 0.66))
	if r.randf() < 0.5:
		v.put(Vector3i(0, h + 1, 0), Color(0.98, 0.9, 0.5))


static func _barrel_cactus(v: Vox) -> void:
	v.size = 0.125
	var green := Color(0.34, 0.56, 0.3)
	var fill := func(c: Vector3i, _d: Vector3) -> Color:
		return green.darkened(0.15) if (c.x + c.z) % 2 == 0 else green
	v.blob(Vector3(0, 3, 0), Vector3(3.5, 3.5, 3.5), fill, 0.05)
	var petals: Array[Color] = [Color(0.98, 0.4, 0.5), Color(0.98, 0.85, 0.3)]
	for k in 5:
		v.put(Vector3i(v.rng.randi_range(-1, 1), 7, v.rng.randi_range(-1, 1)), petals[k % 2])


static func _tumbleweed(v: Vox) -> void:
	v.size = 0.15
	var dry := Color(0.66, 0.54, 0.34)
	var r := v.rng
	var fill := func(_c: Vector3i, _d: Vector3) -> Color:
		return dry.darkened(r.randf_range(0.0, 0.25))
	v.blob(Vector3(0, 3, 0), Vector3(3.2, 3.0, 3.2), fill, 0.25)
	# vazado: tira blocos ao acaso
	for c in v.cells.keys():
		if r.randf() < 0.45:
			v.erase(c)


static func _rock_red(v: Vox) -> void:
	v.size = 0.4
	var r := v.rng
	var red := Color(0.72, 0.38, 0.24)
	var fill := func(c: Vector3i, _d: Vector3) -> Color:
		return red.darkened(0.12) if c.y % 3 == 0 else red.lightened(r.randf_range(-0.05, 0.08))
	v.blob(Vector3(0, 2.5, 0), Vector3(r.randf_range(3, 5), r.randf_range(2.5, 4), r.randf_range(3, 4.5)), fill, 0.2)
	for k in r.randi_range(1, 3):
		v.blob(Vector3(r.randf_range(-5, 5), 1.0, r.randf_range(-5, 5)), Vector3(1.6, 1.4, 1.6), fill, 0.25)


static func _drums(v: Vox, index: int) -> void:
	v.size = 0.1
	var colors: Array[Color] = [Color("e83a3a"), Color("2a5ce8"), Color("f0d23c")]
	var spots: Array[Vector2i] = [Vector2i(0, 0), Vector2i(7, 0), Vector2i(3, 6)]
	for k in 3:
		var color := colors[(index + k) % colors.size()]
		var p := spots[k]
		v.cylinder(Vector3(p.x + 3, 0, p.y + 3), 3.2, 0, 8, color)
		v.cylinder(Vector3(p.x + 3, 0, p.y + 3), 3.3, 3, 3, color.darkened(0.3))
		v.cylinder(Vector3(p.x + 3, 0, p.y + 3), 3.3, 6, 6, color.darkened(0.3))
	v.cylinder(Vector3(5, 0, 3), 3.2, 9, 17, colors[(index + 1) % colors.size()].lightened(0.1))


static func _container(v: Vox, index: int) -> void:
	v.size = 0.25
	var colors: Array[Color] = [Color(0.2, 0.42, 0.7), Color(0.72, 0.24, 0.18), Color(0.85, 0.6, 0.15)]
	var color := colors[index % colors.size()]
	for x in 10:
		for y in 10:
			for z in 24:
				if x == 0 or x == 9 or y == 0 or y == 9 or z == 0 or z == 23:
					var rib := (z % 3 == 0) and (x == 0 or x == 9)
					v.put(Vector3i(x, y, z), color.darkened(0.2) if rib else color)
	# portas no fundo
	for x in range(1, 9):
		for y in range(1, 9):
			v.put(Vector3i(x, y, 24), color.darkened(0.12) if x != 4 else Color(0.7, 0.7, 0.7))


static func _skull(v: Vox) -> void:
	v.size = 0.08
	var bone := Color(0.92, 0.9, 0.82)
	v.box(Vector3i(0, 0, 0), Vector3i(5, 4, 7), bone)
	v.box(Vector3i(1, 0, -2), Vector3i(4, 2, -1), bone)
	v.put(Vector3i(1, 3, 0), Color(0.1, 0.1, 0.1))
	v.put(Vector3i(4, 3, 0), Color(0.1, 0.1, 0.1))
	for k in 4:
		v.put(Vector3i(-1 - k, 4 + k / 2, 5), bone)
		v.put(Vector3i(6 + k, 4 + k / 2, 5), bone)
