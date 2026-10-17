@tool
class_name OutdoorTrack
extends StadiumTrack
## Pista de motocross ao ar livre, em morro (Pista da Fazenda): a linha central é uma curva
## suave que passa pelos pontos de controle (x, altura, z), com subidas e descidas. Gera:
## terreno com morros em volta (grama, barrancos de terra vermelha onde é íngreme, terra solta
## perto da pista), a faixa de terra seguindo a altura da pista (com os saltos moldados nela),
## cercas brancas, árvores, a torre do bandeirinha e o arco de largada/chegada.
## O traçado foi recriado de um vídeo de uma volta (tools/gen_farm_layout.py).
## Bots e corrida usam a mesma interface da StadiumTrack (linha central em XZ).

## Pontos de controle da linha central, em ordem de corrida (laço fechado): x, altura, z.
@export var control_points: PackedVector3Array = PackedVector3Array([
	Vector3(0, 10, 0), Vector3(8.1, 10, 0), Vector3(16.2, 10, 0), Vector3(24.3, 10, 0), Vector3(32.4, 10, 0), Vector3(40.5, 10, 0),
	Vector3(48.6, 10, 0), Vector3(56.7, 10, 0), Vector3(64.8, 10, 0), Vector3(73.4, 10.6, 0.5), Vector3(81.8, 11.4, 2.7), Vector3(90.2, 12.2, 5),
	Vector3(98.5, 13, 7.4), Vector3(104.5, 12.33, 13.1), Vector3(103.4, 11.67, 21.3), Vector3(96, 11, 25.1), Vector3(87.8, 10, 25.1), Vector3(79.6, 9, 25.1),
	Vector3(71.3, 8, 25.1), Vector3(63.1, 7, 25.1), Vector3(54.9, 6, 25.1), Vector3(46.8, 5.14, 27.3), Vector3(40.9, 4.29, 33.3), Vector3(38.9, 3.43, 41.5),
	Vector3(40.8, 2.75, 49.9), Vector3(43.3, 2.25, 58.4), Vector3(46.1, 2, 66.5), Vector3(51, 2, 72.9), Vector3(58, 2, 77.1), Vector3(66, 2, 78.4),
	Vector3(74, 2, 76.8), Vector3(80.8, 2, 72.3), Vector3(85.9, 2.19, 66), Vector3(90.7, 2.58, 59.3), Vector3(95.4, 2.97, 52.7), Vector3(100.2, 3.35, 46.1),
	Vector3(104.9, 3.74, 39.4), Vector3(109.7, 4.13, 32.8), Vector3(114.5, 4.52, 26.2), Vector3(119.2, 4.9, 19.6), Vector3(123.1, 5.33, 12.3), Vector3(123.5, 5.78, 4),
	Vector3(120.1, 6.22, -3.5), Vector3(113.7, 6.67, -8.8), Vector3(105.5, 7.06, -10.8), Vector3(96.7, 7.31, -11.7), Vector3(87.8, 7.58, -12.8), Vector3(79.6, 7.92, -16.8),
	Vector3(73, 8, -22.1), Vector3(65.1, 8, -24.4), Vector3(57, 7.73, -23.5), Vector3(49.2, 6.65, -21.7), Vector3(41.4, 5.58, -19.8), Vector3(33.6, 4.5, -18),
	Vector3(25.7, 3.42, -16.2), Vector3(17.9, 2.35, -14.3), Vector3(10.1, 1.27, -12.5), Vector3(2.2, 1, -12.7), Vector3(-2.7, 1, -19), Vector3(-0.7, 1, -26.7),
	Vector3(6.5, 1.1, -30.1), Vector3(14.5, 1.52, -31.5), Vector3(22.5, 1.93, -33), Vector3(30.5, 2.34, -34.4), Vector3(38.5, 2.76, -35.9), Vector3(46.5, 3.17, -37.3),
	Vector3(54.5, 3.59, -38.8), Vector3(62.5, 4, -40.2), Vector3(70.1, 4.73, -43.3), Vector3(75.8, 5.45, -49.1), Vector3(78.9, 6.12, -56.8), Vector3(81.1, 6.62, -65.1),
	Vector3(83.2, 7.1, -73.3), Vector3(83.4, 7.5, -81.4), Vector3(81, 7.9, -89.1), Vector3(76.2, 8.3, -95.7), Vector3(69.5, 8.7, -100.4), Vector3(61.8, 9.06, -102.7),
	Vector3(53.7, 9.29, -104.4), Vector3(45.5, 9.53, -106.1), Vector3(37.4, 9.76, -107.8), Vector3(29.3, 10, -109.5), Vector3(21.8, 10.31, -107.7), Vector3(18.5, 10.62, -100.7),
	Vector3(21.9, 10.92, -93.7), Vector3(29.3, 10.31, -89.8), Vector3(37, 9.38, -86.1), Vector3(44.7, 8.46, -82.4), Vector3(52, 7.89, -78.2), Vector3(56.6, 7.68, -71.4),
	Vector3(57.3, 7.47, -63.2), Vector3(53.8, 7.26, -55.8), Vector3(47, 7.05, -51.1), Vector3(39.1, 7.36, -49.2), Vector3(31.2, 7.84, -47.4), Vector3(23.3, 8.32, -45.6),
	Vector3(15.4, 8.8, -43.9), Vector3(7.5, 9.28, -42.1), Vector3(-0.4, 9.76, -40.4), Vector3(-8.2, 10, -38.2), Vector3(-14.7, 10, -33.5), Vector3(-18.9, 10, -26.7),
	Vector3(-20, 10, -18.8), Vector3(-18, 10, -11), Vector3(-13, 10, -4.7), Vector3(-6, 10, -0.8)
]):
	set(value):
		control_points = value
		_queue_rebuild()
## Saltos moldados na pista: (distância desde o primeiro ponto, subida m, topo m, altura m).
## A descida do pouso é 1,3x a subida. Topo 0 = lombada.
@export var jumps: Array[Vector4] = [
	Vector4(70, 5, 0, 0.8), Vector4(190, 5, 0, 0.7), Vector4(425, 5, 0, 0.9),
	Vector4(442, 5, 0, 0.9), Vector4(520, 8, 10, 2.4), Vector4(780, 7, 12, 2.0),
]:
	set(value):
		jumps = value
		_queue_rebuild()
## Costelas: (distância do início, quantidade, altura m), uma a cada `whoop_spacing` m.
@export var whoops: Array[Vector3] = [Vector3(642, 8, 0.7)]:
	set(value):
		whoops = value
		_queue_rebuild()
@export var whoop_spacing: float = 3.0

@export_group("Terreno")
## Quanto o terreno passa da pista em volta (m) e o tamanho de cada quadradinho (m).
@export var terrain_margin: float = 45.0
@export var terrain_cell: float = 2.0
## Morrinhos suaves longe da pista (m) e quanto o terreno sobe nas bordas do mapa.
@export var hill_height: float = 3.0
@export var rim_rise: float = 0.18
## Multiplica as alturas dos pontos de controle (relevo mais ou menos acentuado).
@export var height_scale: float = 1.35
## Faixa de terra solta e de transição para a grama, a partir da borda da pista (m).
@export var shoulder: float = 2.5
@export var blend: float = 7.0
@export var terrain_material: Material

@export_group("Enfeites")
@export var fence_material: Material
@export var bark_material: Material
@export var leaves_material: Material
@export var tree_count: int = 140
@export var tree_seed: int = 7

## Altura da pista em cada ponto da linha central (já com os saltos).
var heights: PackedFloat32Array = PackedFloat32Array()
## Pontos da linha central a cada ~4 m, para as buscas do terreno.
var _coarse: PackedInt32Array = PackedInt32Array()
var _bounds := Rect2()
## Alturas do terreno gerado (grade `_cols` x `_rows`), para apoiar cercas e árvores no chão.
var _terrain := PackedFloat32Array()
var _cols := 0
var _rows := 0


func _rebuild() -> void:
	_rebuild_queued = false
	if _generated:
		_generated.free()
	_generated = Node3D.new()
	_generated.name = "_Generated"
	add_child(_generated)

	_sample_spline(0.5)
	if centerline.size() < 3:
		return
	distances.resize(centerline.size())
	length = 0.0
	for i in centerline.size():
		distances[i] = length
		length += centerline[i].distance_to(centerline[(i + 1) % centerline.size()])
	_shape_profile()
	_bounds = Rect2(centerline[0], Vector2.ZERO)
	for p in centerline:
		_bounds = _bounds.expand(p)
	_bounds = _bounds.grow(terrain_margin)
	_coarse.clear()
	for i in range(0, centerline.size(), 8):
		_coarse.append(i)

	_build_terrain()
	_build_track_surface()
	_build_fences()
	_build_trees()
	_build_finish()
	_build_flag_tower()
	var finish := _generated.get_node_or_null("FinishLine") as Node3D
	if finish:
		finish.position.y = height_at(_index_at_distance(finish_distance))


# ---------------------------------------------------------------- linha central e perfil

## Curva Catmull-Rom fechada pelos pontos de controle, reamostrada a cada `step` metros.
## Preenche `centerline` (XZ) e `heights` (altura base, antes dos saltos).
func _sample_spline(step: float) -> void:
	centerline = PackedVector2Array()
	heights = PackedFloat32Array()
	var n := control_points.size()
	if n < 4:
		return
	var dense: Array[Vector3] = []
	for i in n:
		var p0 := control_points[(i - 1 + n) % n]
		var p1 := control_points[i]
		var p2 := control_points[(i + 1) % n]
		var p3 := control_points[(i + 2) % n]
		for s in 16:
			var t := s / 16.0
			var t2 := t * t
			var t3 := t2 * t
			dense.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
					+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	# Reamostra pelo comprimento (no plano), para pontos a cada `step` metros.
	var travelled := 0.0
	var next_mark := 0.0
	for i in dense.size():
		var a := dense[i]
		var b := dense[(i + 1) % dense.size()]
		var seg := Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
		while next_mark <= travelled + seg and seg > 0.0:
			var t := (next_mark - travelled) / seg
			var p := a.lerp(b, t)
			centerline.append(Vector2(p.x, p.z))
			heights.append(p.y * height_scale)
			next_mark += step
		travelled += seg
	if centerline.size() > 2 and centerline[0].distance_to(centerline[centerline.size() - 1]) < step * 0.5:
		centerline.remove_at(centerline.size() - 1)
		heights.remove_at(heights.size() - 1)


## Suaviza as rampas do terreno e molda os saltos e as costelas na altura da pista.
func _shape_profile() -> void:
	var n := heights.size()
	for _pass in 2:
		var smooth := PackedFloat32Array()
		smooth.resize(n)
		for i in n:
			var sum := 0.0
			for k in range(-12, 13):
				sum += heights[posmod(i + k, n)]
			smooth[i] = sum / 25.0
		heights = smooth
	for i in n:
		var d := distances[i]
		heights[i] += _jump_profile(d) + _whoop_profile(d)


func _jump_profile(d: float) -> float:
	var total := 0.0
	for j in jumps:
		var up := j.y
		var top := j.z
		var down := up * 1.3
		var x := fposmod(d - j.x, length)
		if x < up:
			total += j.w * _ease(x / up)
		elif x < up + top:
			total += j.w
		elif x < up + top + down:
			total += j.w * _ease(1.0 - (x - up - top) / down)
	return total


func _whoop_profile(d: float) -> float:
	var total := 0.0
	for w in whoops:
		var x := fposmod(d - w.x, length)
		if x < w.y * whoop_spacing:
			total += w.z * pow(sin(PI * x / whoop_spacing), 2.0)
	return total


## Subida suave nas pontas (base côncava e crista arredondada).
func _ease(t: float) -> float:
	return 0.5 - 0.5 * cos(PI * clampf(t, 0.0, 1.0))


func height_at(index: int) -> float:
	return heights[posmod(index, heights.size())]


## Posição e direção da linha de chegada, já na altura da pista.
func finish_transform() -> Transform3D:
	var t := super.finish_transform()
	t.origin.y = height_at(_index_at_distance(finish_distance))
	return t


# ---------------------------------------------------------------- terreno

## Ponto da linha central mais perto de `p` (busca grossa e depois fina) e a distância.
func _nearest(p: Vector2) -> Vector2:
	var best := 0
	var best_d := INF
	for i in _coarse:
		var d := p.distance_squared_to(centerline[i])
		if d < best_d:
			best_d = d
			best = i
	var n := centerline.size()
	for k in range(-8, 9):
		var i := posmod(best + k, n)
		var d := p.distance_squared_to(centerline[i])
		if d < best_d:
			best_d = d
			best = i
	return Vector2(best, sqrt(best_d))


## Altura "natural" do morro: média das alturas da pista, pesando os trechos mais perto,
## mais morrinhos suaves longe da pista e o terreno subindo nas bordas do mapa.
func _natural_height(p: Vector2, nearest_d: float) -> float:
	var sum := 0.0
	var weight := 0.0
	for i in _coarse:
		var d2 := p.distance_squared_to(centerline[i])
		var w := 1.0 / (d2 + 36.0)
		w *= w
		sum += heights[i] * w
		weight += w
	var h := sum / weight
	var far := smoothstep(12.0, 40.0, nearest_d)
	h += far * hill_height * (sin(p.x * 0.045) * cos(p.y * 0.038) + 0.5 * sin(p.x * 0.11 + p.y * 0.07))
	h += maxf(0.0, nearest_d - 30.0) * rim_rise
	return h


func _build_terrain() -> void:
	var cols := int(ceil(_bounds.size.x / terrain_cell)) + 1
	var rows := int(ceil(_bounds.size.y / terrain_cell)) + 1
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(cols * rows)
	colors.resize(cols * rows)
	var half := track_width * 0.5
	for r in rows:
		for c in cols:
			var p := _bounds.position + Vector2(c, r) * terrain_cell
			var near := _nearest(p)
			var track_h := heights[int(near.x)]
			var d := near.y
			var natural := _natural_height(p, d)
			# Embaixo da pista o terreno fica um pouco abaixo dela; depois sobe ou desce até
			# o morro natural (é aí que aparecem os barrancos).
			var h: float
			if d <= half + 0.5:
				h = track_h - 0.4
			else:
				var t := smoothstep(half + 0.5, half + shoulder + blend, d)
				h = lerpf(track_h - 0.25, natural, t)
			verts[r * cols + c] = Vector3(p.x, h, p.y)
			var dirt := 1.0 - smoothstep(half + shoulder * 0.5, half + shoulder + 1.5, d)
			colors[r * cols + c] = Color(dirt, 0.0, 0.0)
	# A borda do mapa desce em rampa até o chão de fora (na altura média da borda).
	var outer := 0.0
	var ring := 0
	for r in rows:
		for c in cols:
			if r == 0 or c == 0 or r == rows - 1 or c == cols - 1:
				outer += verts[r * cols + c].y
				ring += 1
	outer = outer / ring - 0.5
	for r in rows:
		for c in cols:
			var edge := mini(mini(r, c), mini(rows - 1 - r, cols - 1 - c))
			var keep := smoothstep(0.0, 18.0, float(edge))
			verts[r * cols + c].y = lerpf(outer, verts[r * cols + c].y, keep)
	_terrain.resize(cols * rows)
	for k in verts.size():
		_terrain[k] = verts[k].y
	_cols = cols
	_rows = rows

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in rows - 1:
		for c in cols - 1:
			var i00 := r * cols + c
			var quad := [i00, i00 + 1, i00 + cols + 1, i00 + cols]
			for tri in [[0, 1, 2], [0, 2, 3]]:
				for k in tri:
					st.set_color(colors[quad[k]])
					st.add_vertex(verts[quad[k]])
	st.generate_normals()
	st.set_material(terrain_material)
	var mesh := st.commit()
	var instance := MeshInstance3D.new()
	instance.name = "Terrain"
	instance.mesh = mesh
	_generated.add_child(instance)
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	_generated.add_child(body)
	_build_outer_ground(outer)


## Grama sem fim em volta do mapa (moldura em volta do terreno, na altura da borda dele).
func _build_outer_ground(y: float) -> void:
	var far := 3000.0
	var r := _bounds.grow(-terrain_cell * 0.5)
	var o := r.grow(far)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color.BLACK)
	st.set_normal(Vector3.UP)
	# Quatro faixas: norte, sul, oeste e leste do terreno.
	var strips := [
		Rect2(o.position.x, o.position.y, o.size.x, r.position.y - o.position.y),
		Rect2(o.position.x, r.end.y, o.size.x, o.end.y - r.end.y),
		Rect2(o.position.x, r.position.y, r.position.x - o.position.x, r.size.y),
		Rect2(r.end.x, r.position.y, o.end.x - r.end.x, r.size.y),
	]
	for q: Rect2 in strips:
		var a := Vector3(q.position.x, y, q.position.y)
		var b := Vector3(q.end.x, y, q.position.y)
		var c := Vector3(q.end.x, y, q.end.y)
		var d := Vector3(q.position.x, y, q.end.y)
		for v in [a, b, c, a, c, d]:
			st.add_vertex(v)
	st.set_material(terrain_material)
	var instance := MeshInstance3D.new()
	instance.name = "OuterGround"
	instance.mesh = st.commit()
	_generated.add_child(instance)


## Altura do terreno gerado em `p` (interpolada na grade).
func terrain_height(p: Vector2) -> float:
	if _terrain.is_empty():
		return 0.0
	var g := (p - _bounds.position) / terrain_cell
	var c := clampi(int(g.x), 0, _cols - 2)
	var r := clampi(int(g.y), 0, _rows - 2)
	var fx := clampf(g.x - c, 0.0, 1.0)
	var fy := clampf(g.y - r, 0.0, 1.0)
	var h0 := lerpf(_terrain[r * _cols + c], _terrain[r * _cols + c + 1], fx)
	var h1 := lerpf(_terrain[(r + 1) * _cols + c], _terrain[(r + 1) * _cols + c + 1], fx)
	return lerpf(h0, h1, fy)


# ---------------------------------------------------------------- pista

## Faixa de terra seguindo a altura da pista (com colisão própria, mais precisa que o terreno).
## UV.x = distância lateral até a linha central, UV.y = distância percorrida (sulcos no shader).
func _build_track_surface() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := centerline.size()
	var half := track_width * 0.5
	var lip := half + 0.8
	# A cada 2 pontos (1 m); a borda externa desce um pouco até o terreno.
	var rows: Array = []
	for i in range(0, n, 2):
		var p := centerline[i]
		var r := _right(_tangent(centerline, i))
		var h := heights[i]
		var row: Array = []
		for side in [[-lip, -0.35], [-half, 0.0], [half, 0.0], [lip, -0.35]]:
			var q: Vector2 = p + r * side[0]
			row.append([Vector3(q.x, h + side[1], q.y), Vector2(side[0], distances[i])])
		rows.append(row)
	for k in rows.size():
		var a: Array = rows[k]
		var b: Array = rows[(k + 1) % rows.size()]
		for s in 3:
			for v in [a[s], b[s], b[s + 1], a[s], b[s + 1], a[s + 1]]:
				st.set_uv(v[1])
				st.add_vertex(v[0])
	st.generate_normals()
	st.set_material(track_material)
	var mesh := st.commit()
	var instance := MeshInstance3D.new()
	instance.name = "TrackSurface"
	instance.mesh = mesh
	_generated.add_child(instance)
	var body := StaticBody3D.new()
	body.name = "TrackBody"
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	_generated.add_child(body)


# ---------------------------------------------------------------- enfeites

## Cerca branca de estacas e duas tábuas dos dois lados da pista (sem colisão).
func _build_fences() -> void:
	if fence_material == null:
		return
	var offset := track_width * 0.5 + 2.2
	var spacing := 3.0
	var posts: Array[Transform3D] = []
	var rails: Array[Transform3D] = []
	for side: float in [-1.0, 1.0]:
		var prev := Vector3.INF
		var step := int(spacing / 0.5)
		for i in range(0, centerline.size(), step):
			var p := centerline[i] + _right(_tangent(centerline, i)) * offset * side
			# Não põe cerca onde passa outro trecho da pista.
			if _nearest(p).y < offset - 0.5:
				prev = Vector3.INF
				continue
			var top := Vector3(p.x, terrain_height(p), p.y)
			# Nada de cerca subindo barranco: só onde o chão está perto da altura da pista.
			if absf(top.y - heights[i]) > 1.2:
				prev = Vector3.INF
				continue
			posts.append(Transform3D(Basis.from_scale(Vector3(0.18, 1.2, 0.18)), top + Vector3.UP * 0.6))
			if prev != Vector3.INF and prev.distance_to(top) < spacing * 1.6:
				var mid := (prev + top) * 0.5
				var dir := top - prev
				for y in [0.55, 1.05]:
					var basis := Basis.looking_at(dir.normalized(), Vector3.UP) * Basis.from_scale(Vector3(0.08, 0.14, dir.length()))
					rails.append(Transform3D(basis, mid + Vector3.UP * y))
			prev = top
	_add_multimesh("FencePosts", posts, fence_material)
	_add_multimesh("FenceRails", rails, fence_material)


## Árvores voxel (tronco e copa de blocos) espalhadas longe da pista.
func _build_trees() -> void:
	if bark_material == null or leaves_material == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = tree_seed
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var tries := 0
	while trunks.size() < tree_count and tries < tree_count * 20:
		tries += 1
		var p := _bounds.position + Vector2(rng.randf(), rng.randf()) * _bounds.size
		var near := _nearest(p)
		if near.y < track_width * 0.5 + 9.0:
			continue
		var ground := terrain_height(p)
		var trunk_h := rng.randf_range(2.5, 4.5)
		var base := Vector3(p.x, ground - 0.3, p.y)
		trunks.append(Transform3D(Basis.from_scale(Vector3(0.7, trunk_h, 0.7)), base + Vector3.UP * trunk_h * 0.5))
		var size := rng.randf_range(3.0, 5.0)
		crowns.append(Transform3D(Basis.from_scale(Vector3(size, size * 0.7, size)), base + Vector3.UP * (trunk_h + size * 0.25)))
		crowns.append(Transform3D(Basis.from_scale(Vector3(size * 0.6, size * 0.5, size * 0.6)), base + Vector3.UP * (trunk_h + size * 0.75)))
	_add_multimesh("TreeTrunks", trunks, bark_material)
	_add_multimesh("TreeCrowns", crowns, leaves_material)


## Torre do bandeirinha na largada (madeira e telhadinho), do lado esquerdo.
func _build_flag_tower() -> void:
	if fence_material == null:
		return
	var i := _index_at_distance(finish_distance + 6.0)
	var p := centerline[i] - _right(_tangent(centerline, i)) * (track_width * 0.5 + 4.0)
	var ground := terrain_height(p)
	var tower := Node3D.new()
	tower.name = "FlagTower"
	tower.position = Vector3(p.x, ground, p.y)
	_generated.add_child(tower)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			_add_box(tower, Vector3(x, 1.8, z), Vector3(0.25, 3.6, 0.25), fence_material, false)
	_add_box(tower, Vector3(0, 3.6, 0), Vector3(2.6, 0.2, 2.6), fence_material, false)
	_add_box(tower, Vector3(0, 5.2, 0), Vector3(3.0, 0.2, 3.0), metal_material, false)
	for x in [-1.2, 1.2]:
		_add_box(tower, Vector3(x, 4.4, -1.2), Vector3(0.15, 1.6, 0.15), fence_material, false)


func _add_multimesh(node_name: String, transforms: Array[Transform3D], material: Material) -> void:
	if transforms.is_empty():
		return
	var box := BoxMesh.new()
	box.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = box
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	_generated.add_child(instance)
