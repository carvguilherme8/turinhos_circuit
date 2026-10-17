@tool
class_name OutdoorTrack
extends StadiumTrack
## Pista de motocross ao ar livre, em morro (Pista da Fazenda): a linha central é uma curva
## suave que passa pelos pontos de controle (x, altura, z), com subidas e descidas. Gera:
## terreno com morros em volta (grama, barrancos de terra vermelha onde é íngreme, terra solta
## perto da pista), a faixa de terra seguindo a altura da pista (saltos moldados nela e curvas
## inclinadas para dentro, as berms), cercas brancas, árvores, a torre do bandeirinha e o arco
## de largada/chegada. O traçado vem de tools/gen_farm_layout.py (--apply grava aqui).
## Bots e corrida usam a mesma interface da StadiumTrack (linha central em XZ).

# <layout> (gerado por tools/gen_farm_layout.py --apply)
## Pontos de controle da linha central, em ordem de corrida (laço fechado): x, altura, z.
@export var control_points: PackedVector3Array = PackedVector3Array([
	Vector3(0, 10, -0), Vector3(8.1, 10, -0), Vector3(16.2, 10, -0), Vector3(24.2, 10, -0), Vector3(32.3, 10, -0), Vector3(40.4, 10, -0),
	Vector3(48.5, 10, -0), Vector3(56.6, 10, -0), Vector3(64.7, 10, -0), Vector3(72.7, 10, -0), Vector3(80.8, 10, -0), Vector3(88.9, 10, -0),
	Vector3(97, 10, -0), Vector3(105.1, 10.05, -0.4), Vector3(112.7, 10.15, -3.3), Vector3(118.7, 10.25, -8.8), Vector3(122.2, 10.35, -16.1), Vector3(122.9, 10.45, -24.2),
	Vector3(121, 10.62, -32.2), Vector3(118.7, 10.86, -40.1), Vector3(116.3, 11.1, -48), Vector3(114, 11.34, -55.9), Vector3(111.7, 11.58, -63.8), Vector3(109.4, 11.82, -71.8),
	Vector3(107.2, 12.04, -79.8), Vector3(108.3, 12.19, -88.1), Vector3(113.7, 12.35, -94.4), Vector3(121.7, 12.5, -96.9), Vector3(130, 12.97, -97.1), Vector3(138.2, 13.43, -97.2),
	Vector3(146.4, 13.9, -97.4), Vector3(154.6, 14.37, -97.5), Vector3(162.8, 14.83, -97.7), Vector3(171, 15.3, -97.8), Vector3(179.2, 15.77, -98), Vector3(187.5, 16, -99),
	Vector3(192.8, 16, -105.3), Vector3(191.6, 16, -113.5), Vector3(184.7, 16, -118), Vector3(176.4, 15.13, -117.7), Vector3(168.3, 13.97, -117.1), Vector3(160.2, 12.81, -116.6),
	Vector3(152, 11.65, -116.1), Vector3(143.9, 10.48, -115.6), Vector3(135.7, 9.32, -115), Vector3(127.6, 8.16, -114.5), Vector3(119.5, 7, -114), Vector3(111, 6.45, -114.6),
	Vector3(103.1, 5.91, -117.6), Vector3(96.2, 5.46, -122.6), Vector3(89.1, 5.32, -126.6), Vector3(81.1, 5.18, -128.5), Vector3(72.9, 5.04, -128.2), Vector3(65.1, 4.89, -125.6),
	Vector3(58.2, 4.75, -121.1), Vector3(52.9, 4.61, -114.8), Vector3(49.4, 4.5, -107.4), Vector3(46.5, 4.5, -99.9), Vector3(43.7, 4.5, -92.4), Vector3(40.8, 4.5, -84.9),
	Vector3(38, 4.5, -77.4), Vector3(35.1, 4.5, -69.9), Vector3(32.3, 4.5, -62.4), Vector3(28, 4.59, -55.8), Vector3(20.5, 4.72, -53.5), Vector3(13.4, 4.84, -56.7),
	Vector3(10.2, 4.97, -63.9), Vector3(11.2, 5.31, -72), Vector3(12.2, 5.72, -80), Vector3(13.3, 6.14, -88), Vector3(14.4, 6.55, -96.1), Vector3(15.5, 6.97, -104.1),
	Vector3(16.6, 7.38, -112.1), Vector3(17.7, 7.79, -120.2), Vector3(18.4, 8.19, -128.3), Vector3(16.1, 8.57, -136.3), Vector3(10.8, 8.95, -142.6), Vector3(3.4, 9.33, -146.3),
	Vector3(-4.9, 9.71, -146.6), Vector3(-12.6, 10.1, -143.7), Vector3(-19.8, 10.48, -140), Vector3(-27, 10.86, -136.2), Vector3(-34.2, 11.24, -132.5), Vector3(-41.4, 11.62, -128.8),
	Vector3(-48.7, 12, -125), Vector3(-54.5, 12, -119.4), Vector3(-56.2, 12, -111.5), Vector3(-53.3, 12, -104), Vector3(-47, 11.82, -98.8), Vector3(-40.4, 11.45, -94.1),
	Vector3(-33.8, 11.09, -89.4), Vector3(-27.2, 10.73, -84.8), Vector3(-20.6, 10.36, -80.1), Vector3(-14, 10, -75.4), Vector3(-8.3, 10, -69.8), Vector3(-4.6, 10, -62.7),
	Vector3(-3.4, 10, -54.8), Vector3(-4.7, 10, -46.9), Vector3(-8.5, 10, -39.9), Vector3(-14.2, 10, -34.2), Vector3(-18.6, 10, -27.4), Vector3(-20, 10, -19.4),
	Vector3(-18.1, 10, -11.5), Vector3(-13.2, 10, -5), Vector3(-6.1, 10, -1),
]):
	set(value):
		control_points = value
		_queue_rebuild()
## Saltos moldados na pista: (distância desde o primeiro ponto, comprimento m, altura m,
## tipo: 0 = lombada, 1 = mesa, 2 = double).
@export var jumps: Array[Vector4] = [
	Vector4(62.6, 22, 2, 1),
	Vector4(145, 8, 1, 0),
	Vector4(158.4, 22, 1.7, 1),
	Vector4(248.8, 24, 2.8, 1),
	Vector4(330.3, 30, 2.4, 2),
	Vector4(546.6, 26, 2, 2),
	Vector4(575.4, 26, 2, 2),
	Vector4(662.6, 22, 2.2, 1),
	Vector4(729.3, 18, 1.6, 1),
]:
	set(value):
		jumps = value
		_queue_rebuild()
## Costelas: (distância do início, quantidade, altura m), uma a cada `whoop_spacing` m.
@export var whoops: Array[Vector3] = [
	Vector3(466.6, 8, 0.5),
]:
	set(value):
		whoops = value
		_queue_rebuild()
# </layout>
## Costelas iguais às do estádio: espaçamento e comprimento de cada uma (m).
@export var whoop_spacing: float = 3.4
@export var whoop_length: float = 3.0
## Inclinação das curvas (berms): quanto inclina por curvatura e o máximo (subida por metro
## de largura; 0,3 = ~17°). O lado de fora da curva fica mais alto.
@export var bank_gain: float = 3.0
@export var max_bank: float = 0.32

@export_group("Terreno")
## Quanto o terreno passa da pista em volta (m) e o tamanho de cada quadradinho (m).
@export var terrain_margin: float = 45.0
@export var terrain_cell: float = 2.0
## Morrinhos suaves longe da pista (m) e quanto o terreno sobe nas bordas do mapa.
@export var hill_height: float = 3.0
@export var rim_rise: float = 0.18
## Multiplica as alturas dos pontos de controle (relevo mais ou menos acentuado).
@export var height_scale: float = 1.6
## Faixa de terra solta e de transição para a grama, a partir da borda da pista (m).
@export var shoulder: float = 2.5
@export var blend: float = 7.0
@export var terrain_material: Material

@export_group("Enfeites")
@export var fence_material: Material
@export var tree_count: int = 140
@export var tree_seed: int = 7

const VoxelProps := preload("res://scripts/tracks/voxel_props.gd")

## Pistas já geradas nesta sessão (por configuração): na segunda vez a pista só é remontada
## a partir daqui, sem recalcular terreno e malhas. Trocar de pista fica quase instantâneo.
static var _cache := {}

## Altura da pista em cada ponto da linha central (já com os saltos).
var heights: PackedFloat32Array = PackedFloat32Array()
## Inclinação lateral em cada ponto: altura extra por metro para a direita (berms).
var banks: PackedFloat32Array = PackedFloat32Array()
## Pontos da linha central a cada ~4 m, para as buscas do terreno.
var _coarse: PackedInt32Array = PackedInt32Array()
## Grade espacial dos pontos de `_coarse` (células de HASH_CELL m), para achar o ponto da
## pista mais perto olhando só a vizinhança.
const HASH_CELL := 16.0
var _hash := {}
var _bounds := Rect2()
## Alturas do terreno gerado (grade `_cols` x `_rows`), para apoiar cercas e árvores no chão.
var _terrain := PackedFloat32Array()
var _cols := 0
var _rows := 0


func _rebuild() -> void:
	_rebuild_queued = false
	if _generated:
		_generated.free()
	var key := _cache_key()
	if _cache.has(key):
		_restore(_cache[key])
		return
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
	_build_hash()

	_build_terrain()
	_build_track_surface()
	_build_whoops()
	_build_fences()
	_build_trees()
	_build_props()
	_build_finish()
	_build_flag_tower()
	var finish := _generated.get_node_or_null("FinishLine") as Node3D
	if finish:
		finish.position.y = height_at(_index_at_distance(finish_distance))
	_cache[key] = _snapshot()


## Todas as propriedades exportadas (desta classe e da StadiumTrack): mudou alguma, gera de novo.
func _cache_key() -> int:
	var values := []
	for prop in get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop.usage & PROPERTY_USAGE_STORAGE:
			values.append(get(prop.name))
	return str(values).hash()


## Guarda o que foi gerado: os nós (como cena empacotada) e os dados da linha central.
func _snapshot() -> Dictionary:
	_own_generated(_generated)
	var packed := PackedScene.new()
	packed.pack(_generated)
	return {"scene": packed, "centerline": centerline, "distances": distances, "length": length,
		"heights": heights, "banks": banks, "coarse": _coarse, "bounds": _bounds,
		"terrain": _terrain, "cols": _cols, "rows": _rows}


## Dono de cada nó gerado = a raiz gerada (para empacotar). As rampas recriam as próprias
## malhas ao entrar na cena, então os filhos delas ficam de fora.
func _own_generated(node: Node) -> void:
	for child in node.get_children():
		child.owner = _generated
		if not child is Ramp:
			_own_generated(child)


func _restore(entry: Dictionary) -> void:
	_generated = (entry["scene"] as PackedScene).instantiate()
	add_child(_generated)
	centerline = entry["centerline"]
	distances = entry["distances"]
	length = entry["length"]
	heights = entry["heights"]
	banks = entry["banks"]
	_coarse = entry["coarse"]
	_build_hash()
	_bounds = entry["bounds"]
	_terrain = entry["terrain"]
	_cols = entry["cols"]
	_rows = entry["rows"]


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
		heights[i] += _jump_profile(d)
	_compute_banks()


## Berms: inclina a pista nas curvas (lado de fora mais alto), proporcional à curvatura.
func _compute_banks() -> void:
	var n := centerline.size()
	var raw := PackedFloat32Array()
	raw.resize(n)
	for i in n:
		var a := _tangent(centerline, posmod(i - 6, n))
		var b := _tangent(centerline, posmod(i + 6, n))
		# Curvatura (rad/m), positiva virando à direita: o lado esquerdo (fora) sobe.
		raw[i] = clampf(-a.angle_to(b) / 6.0 * bank_gain, -max_bank, max_bank)
	banks.resize(n)
	for i in n:
		var sum := 0.0
		for k in range(-10, 11):
			sum += raw[posmod(i + k, n)]
		banks[i] = sum / 21.0


## Altura da superfície da pista no ponto `index`, a `lateral` metros para a direita.
func surface_height(index: int, lateral: float) -> float:
	var i := posmod(index, heights.size())
	var half := track_width * 0.5
	return heights[i] + banks[i] * clampf(lateral, -half, half)


## Formas dos saltos ao longo do comprimento L (tipo em j.w), com subidas longas para a moto
## não "bater" no começo da rampa:
## 0 lombada; 1 mesa (subida 35%, topo 30%, pouso 35%);
## 2 double (kicker 33%, queda 10%, buraco 10%, frente do pouso 10%, pouso 37%).
func _jump_profile(d: float) -> float:
	var total := 0.0
	for j in jumps:
		var size := j.y
		var h := j.z
		var x := fposmod(d - j.x, length) / size
		if x >= 1.0:
			continue
		match int(j.w):
			0:
				total += h * pow(sin(PI * x), 2.0)
			1:
				if x < 0.35:
					total += h * _ease(x / 0.35)
				elif x < 0.65:
					total += h
				else:
					total += h * _ease(1.0 - (x - 0.65) / 0.35)
			_:
				if x < 0.33:
					total += h * _ease(x / 0.33)
				elif x < 0.43:
					total += h * _ease(1.0 - (x - 0.33) / 0.1)
				elif x < 0.53:
					pass
				elif x < 0.63:
					total += h * _ease((x - 0.53) / 0.1)
				else:
					total += h * _ease(1.0 - (x - 0.63) / 0.37)
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

## Distância lateral (m, + = direita) de `p` em relação à linha central no ponto `index`.
func _lateral(p: Vector2, index: int) -> float:
	return (p - centerline[index]).dot(_right(_tangent(centerline, index)))


## Ponto da linha central mais perto de `p` (busca grossa e depois fina) e a distância.
func _build_hash() -> void:
	_hash.clear()
	for i in _coarse:
		var cell := Vector2i((centerline[i] / HASH_CELL).floor())
		if not _hash.has(cell):
			_hash[cell] = PackedInt32Array()
		_hash[cell].append(i)


func _nearest(p: Vector2) -> Vector2:
	var best := 0
	var best_d := INF
	# Anéis de células em volta de `p` até achar algum ponto; mais um anel para garantir.
	var center := Vector2i((p / HASH_CELL).floor())
	var found_ring := -1
	for ring in 8:
		if found_ring >= 0 and ring > found_ring + 1:
			break
		for x in range(-ring, ring + 1):
			for y in range(-ring, ring + 1):
				if maxi(absi(x), absi(y)) != ring:
					continue
				var bucket: PackedInt32Array = _hash.get(center + Vector2i(x, y), PackedInt32Array())
				for i in bucket:
					var d := p.distance_squared_to(centerline[i])
					if d < best_d:
						best_d = d
						best = i
						if found_ring < 0:
							found_ring = ring
	if best_d == INF:
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


## Média das alturas da pista em volta de `p`, pesando os trechos mais perto (é suave: dá para
## calcular numa grade grossa e interpolar).
func _blend_height(p: Vector2) -> float:
	var sum := 0.0
	var weight := 0.0
	for i in _coarse:
		var d2 := p.distance_squared_to(centerline[i])
		var w := 1.0 / (d2 + 36.0)
		w *= w
		sum += heights[i] * w
		weight += w
	return sum / weight


## Altura "natural" do morro: média das alturas da pista, pesando os trechos mais perto,
## mais morrinhos suaves longe da pista e o terreno subindo nas bordas do mapa.
func _natural_height(p: Vector2, nearest_d: float, base := NAN) -> float:
	var h := base if not is_nan(base) else _blend_height(p)
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
	# A média das alturas da pista muda devagar: calcula a cada COARSE quadradinhos e interpola.
	const COARSE := 4
	var ccols := cols / COARSE + 2
	var crows := rows / COARSE + 2
	var blend_grid := PackedFloat32Array()
	blend_grid.resize(ccols * crows)
	for r in crows:
		for c in ccols:
			blend_grid[r * ccols + c] = _blend_height(_bounds.position + Vector2(c, r) * terrain_cell * COARSE)
	# Perto da pista: cada ponto da linha central marca a distância nos vértices em volta
	# (bem mais rápido que cada vértice procurar o ponto mais perto).
	var near_index := PackedInt32Array()
	var near_dist := PackedFloat32Array()
	near_index.resize(cols * rows)
	near_dist.resize(cols * rows)
	near_dist.fill(INF)
	var reach := half + shoulder + blend + 3.0
	var reach_cells := int(ceil(reach / terrain_cell))
	for i in range(0, centerline.size(), 2):
		var q := centerline[i]
		var g := (q - _bounds.position) / terrain_cell
		for r in range(maxi(0, int(g.y) - reach_cells), mini(rows, int(g.y) + reach_cells + 2)):
			for c in range(maxi(0, int(g.x) - reach_cells), mini(cols, int(g.x) + reach_cells + 2)):
				var dist := (_bounds.position + Vector2(c, r) * terrain_cell).distance_to(q)
				var k := r * cols + c
				if dist < near_dist[k]:
					near_dist[k] = dist
					near_index[k] = i
	# Longe da pista só importa a distância aproximada (morrinhos e borda): grade grossa.
	var far_dist := PackedFloat32Array()
	far_dist.resize(ccols * crows)
	for r in crows:
		for c in ccols:
			far_dist[r * ccols + c] = _nearest(_bounds.position + Vector2(c, r) * terrain_cell * COARSE).y
	for r in rows:
		for c in cols:
			var p := _bounds.position + Vector2(c, r) * terrain_cell
			var gc := float(c) / COARSE
			var gr := float(r) / COARSE
			var c0 := int(gc)
			var r0 := int(gr)
			var d := near_dist[r * cols + c]
			var track_h := 0.0
			if d < reach:
				track_h = surface_height(near_index[r * cols + c], _lateral(p, near_index[r * cols + c]))
			else:
				var far_top := lerpf(far_dist[r0 * ccols + c0], far_dist[r0 * ccols + c0 + 1], gc - c0)
				var far_bottom := lerpf(far_dist[(r0 + 1) * ccols + c0], far_dist[(r0 + 1) * ccols + c0 + 1], gc - c0)
				d = maxf(reach, lerpf(far_top, far_bottom, gr - r0))
			var top := lerpf(blend_grid[r0 * ccols + c0], blend_grid[r0 * ccols + c0 + 1], gc - c0)
			var bottom := lerpf(blend_grid[(r0 + 1) * ccols + c0], blend_grid[(r0 + 1) * ccols + c0 + 1], gc - c0)
			var natural := _natural_height(p, d, lerpf(top, bottom, gr - r0))
			# Embaixo da pista o terreno fica um pouco abaixo dela; depois sobe ou desce até
			# o morro natural (é aí que aparecem os barrancos).
			var h: float
			if d <= half + 0.5:
				h = track_h - 0.6
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

	# Triângulos com normal própria (visual facetado), montados direto em arrays (rápido).
	var tri_count := (rows - 1) * (cols - 1) * 2
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var tri_colors := PackedColorArray()
	positions.resize(tri_count * 3)
	normals.resize(tri_count * 3)
	tri_colors.resize(tri_count * 3)
	var k := 0
	for r in rows - 1:
		for c in cols - 1:
			var i00 := r * cols + c
			var i10 := i00 + 1
			var i11 := i00 + cols + 1
			var i01 := i00 + cols
			for tri in [[i00, i10, i11], [i00, i11, i01]]:
				var a: Vector3 = verts[tri[0]]
				var b: Vector3 = verts[tri[1]]
				var cc: Vector3 = verts[tri[2]]
				var normal := (cc - a).cross(b - a).normalized()
				for idx in tri:
					positions[k] = verts[idx]
					normals[k] = normal
					tri_colors[k] = colors[idx]
					k += 1
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = tri_colors
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
		var row: Array = []
		# Bordas e o meio (para a inclinação das berms ficar lisa), mais a aba de cada lado.
		for side in [[-lip, -0.5], [-half, 0.0], [0.0, 0.0], [half, 0.0], [lip, -0.5]]:
			var q: Vector2 = p + r * side[0]
			var h: float = surface_height(i, side[0]) + side[1]
			row.append([Vector3(q.x, h, q.y), Vector2(side[0], distances[i])])
		rows.append(row)
	for k in rows.size():
		var a: Array = rows[k]
		var b: Array = rows[(k + 1) % rows.size()]
		for s in 4:
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
	# Colisão: uma caixa fina por trecho entre estacas (a moto bate na cerca).
	var body := StaticBody3D.new()
	body.name = "FenceBody"
	_generated.add_child(body)
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
			if absf(top.y - surface_height(i, offset * side)) > 1.2:
				prev = Vector3.INF
				continue
			posts.append(Transform3D(Basis.from_scale(Vector3(0.18, 1.2, 0.18)), top + Vector3.UP * 0.6))
			if prev != Vector3.INF and prev.distance_to(top) < spacing * 1.6:
				var mid := (prev + top) * 0.5
				var dir := top - prev
				var facing := Basis.looking_at(dir.normalized(), Vector3.UP)
				for y in [0.55, 1.05]:
					rails.append(Transform3D(facing * Basis.from_scale(Vector3(0.08, 0.14, dir.length())), mid + Vector3.UP * y))
				var shape := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size = Vector3(0.2, 1.3, dir.length())
				shape.shape = box
				shape.transform = Transform3D(facing, mid + Vector3.UP * 0.65)
				body.add_child(shape)
			prev = top
	_add_multimesh("FencePosts", posts, fence_material)
	_add_multimesh("FenceRails", rails, fence_material)


## Árvores e moitas (modelos voxel de vários tipos e variantes), espalhadas longe da pista,
## cada uma girada e num tamanho um pouco diferente.
func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = tree_seed
	var groups := {}
	var tries := 0
	var placed := 0
	while placed < tree_count and tries < tree_count * 25:
		tries += 1
		var p := _bounds.position + Vector2(rng.randf(), rng.randf()) * _bounds.size
		var near := _nearest(p)
		var roll := rng.randf()
		var kind := "oak"
		if roll < 0.18:
			kind = "bush"
		elif roll < 0.36:
			kind = "eucalyptus"
		elif roll < 0.5:
			kind = "pine"
		elif roll < 0.58:
			kind = "ipe_yellow" if rng.randf() < 0.6 else "ipe_pink"
		var clearance := 6.0 if kind == "bush" else 9.0
		if near.y < track_width * 0.5 + clearance:
			continue
		placed += 1
		_add_instance(groups, VoxelProps.variant(kind, rng), p, rng.randf() * TAU, rng.randf_range(0.85, 1.15), -0.2)
	_add_groups(groups)


## Pedras, fardos de feno do lado de fora das curvas, pilhas de pneus (pretos e brancos) do
## lado de dentro dos grampos, público, tendas, banheiros e bandeiras na largada e no salto
## grande, e um canto de fazenda (celeiro, caixa d'água, trator e vacas pastando).
func _build_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = tree_seed + 1
	var half := track_width * 0.5
	var n := centerline.size()
	var groups := {}

	# Pedras pelo pasto.
	var count := 0
	var tries := 0
	while count < 34 and tries < 2000:
		tries += 1
		var p := _bounds.position + Vector2(rng.randf(), rng.randf()) * _bounds.size
		if _nearest(p).y < half + 6.0:
			continue
		count += 1
		_add_instance(groups, VoxelProps.variant("rock", rng), p, rng.randf() * TAU, rng.randf_range(0.7, 1.3), -0.25)

	# Curvas: fardos do lado de fora, pneus do lado de dentro dos grampos.
	var i := 0
	var stack := 0
	while i < n:
		var bank := banks[i]
		if absf(bank) < 0.18:
			i += 4
			continue
		# Inclinação > 0: o lado direito é o mais alto, e o lado mais alto é o de fora da curva.
		var outside := 1.0 if bank > 0.0 else -1.0
		var t := _tangent(centerline, i)
		var r := _right(t)
		var along := atan2(-t.x, -t.y)  # modelo de frente (-Z) para o sentido da pista
		for k in 2:
			var p := centerline[i] + r * outside * (half + 3.6) + t * (k - 0.5) * 1.8
			if _nearest(p).y > half + 2.6:
				_add_instance(groups, VoxelProps.variant("hay", rng), p, along + PI * 0.5, 1.0, -0.05)
		if absf(bank) > 0.26:
			var p := centerline[i] - r * outside * (half + 1.7)
			if _nearest(p).y > half + 0.6:
				var kind := "tires_white" if stack % 2 == 0 else "tires_black"
				_add_instance(groups, VoxelProps.variant(kind, rng), p, rng.randf() * TAU, 1.0, 0.0)
				stack += 1
		i += 14

	# Público, tendas e banheiros: na reta da largada e no salto mais alto.
	var spots: Array[float] = [finish_distance - 12.0, finish_distance + 14.0]
	var biggest := Vector4.ZERO
	for j in jumps:
		if j.z > biggest.z:
			biggest = j
	if biggest.z > 0.0:
		spots.append(biggest.x + biggest.y * 0.5)
	for spot_index in spots.size():
		var idx := _index_at_distance(fposmod(spots[spot_index], length))
		var t := _tangent(centerline, idx)
		var r := _right(t)
		var face := atan2(r.x, r.y)  # de frente para a pista (olhando para -r)
		var tent := centerline[idx] + r * (half + 10.5)
		if _nearest(tent).y > half + 7.0:
			_add_instance(groups, "tent_%d" % (spot_index % 4), tent, face, 1.0, -0.05)
			if spot_index == 0:
				for k in 3:
					var q := tent + t * (6.0 + k * 1.3)
					if _nearest(q).y > half + 5.0:
						_add_instance(groups, "toilet_0", q, face, 1.0, -0.05)
		for k in 22:
			var q := centerline[idx] + t * rng.randf_range(-13.0, 13.0) + r * (half + rng.randf_range(3.4, 7.5))
			if _nearest(q).y < half + 3.0:
				continue
			_add_instance(groups, VoxelProps.variant("person", rng), q, face + rng.randf_range(-0.4, 0.4), rng.randf_range(0.9, 1.08), 0.0)

	# Bandeiras dos dois lados da reta da largada.
	for k in range(-4, 5):
		var idx := _index_at_distance(fposmod(finish_distance + k * 10.0, length))
		var t := _tangent(centerline, idx)
		var r := _right(t)
		for side: float in [-1.0, 1.0]:
			var q := centerline[idx] + r * side * (half + 2.9)
			if _nearest(q).y > half + 2.0:
				_add_instance(groups, "flag_%d" % ((k + 4 + int(side > 0.0)) % 4), q, atan2(-t.x, -t.y), 1.0, -0.1)

	# Canto de fazenda num lugar plano, longe da pista.
	var farm_spot := Vector2.INF
	for attempt in 600:
		var p := _bounds.position + Vector2(rng.randf(), rng.randf()) * _bounds.size
		var d := _nearest(p).y
		var flat := absf(terrain_height(p + Vector2(8, 0)) - terrain_height(p - Vector2(8, 0))) \
				+ absf(terrain_height(p + Vector2(0, 10)) - terrain_height(p - Vector2(0, 10)))
		if d > 30.0 and d < 60.0 and flat < 1.5:
			farm_spot = p
			break
	if farm_spot != Vector2.INF:
		var yaw := rng.randf() * TAU
		var dir := Vector2(cos(yaw), sin(yaw))
		var side := Vector2(-dir.y, dir.x)
		_add_instance(groups, "barn_0", farm_spot, yaw, 1.0, -0.4)
		_add_instance(groups, "water_tower_0", farm_spot + side * 11.0 + dir * 4.0, yaw, 1.0, -0.2)
		_add_instance(groups, "tractor_0", farm_spot + side * -9.0 + dir * 3.0, yaw + 0.6, 1.0, -0.05)
		for k in 7:
			var q := farm_spot + dir * rng.randf_range(12.0, 24.0) + side * rng.randf_range(-12.0, 12.0)
			if _nearest(q).y > half + 8.0:
				_add_instance(groups, VoxelProps.variant("cow", rng), q, rng.randf() * TAU, 1.0, -0.05)
	_add_groups(groups)


## Junta uma instância de `model` (no chão do terreno em `p`) no grupo daquele modelo.
func _add_instance(groups: Dictionary, model: String, p: Vector2, yaw: float, scale: float, sink: float) -> void:
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale)
	var t := Transform3D(basis, Vector3(p.x, terrain_height(p) + sink, p.y))
	if not groups.has(model):
		groups[model] = [] as Array[Transform3D]
	groups[model].append(t)


## Um MultiMeshInstance por modelo voxel (desenha todas as cópias de uma vez).
func _add_groups(groups: Dictionary) -> void:
	for model in groups:
		var transforms: Array[Transform3D] = groups[model]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = VoxelProps.mesh(model)
		multimesh.instance_count = transforms.size()
		for k in transforms.size():
			multimesh.set_instance_transform(k, transforms[k])
		var instance := MultiMeshInstance3D.new()
		instance.name = "Props_" + model
		instance.multimesh = multimesh
		_generated.add_child(instance)


## Costelas iguais às do estádio: rampas de ondulação (Ramp com is_bump), assentadas na
## pista seguindo a inclinação dela. A moto pode deslizar por cima empinada.
func _build_whoops() -> void:
	var holder := Node3D.new()
	holder.name = "Whoops"
	_generated.add_child(holder)
	for w in whoops:
		for k in int(w.y):
			var idx := _index_at_distance(fposmod(w.x + k * whoop_spacing, length))
			var ahead := index_ahead(idx, 1.0)
			var t := _tangent(centerline, idx)
			var grade := height_at(ahead) - height_at(idx)
			var forward := Vector3(t.x, grade, t.y).normalized()
			var ramp := Ramp.new()
			ramp.name = "Costela%d" % (k + 1)
			ramp.is_bump = true
			ramp.up_length = whoop_length * 0.5
			ramp.top_length = 0.0
			ramp.down_length = whoop_length * 0.5
			ramp.height = w.z
			ramp.width = track_width
			ramp.material = track_material
			var p := centerline[idx]
			ramp.transform = Transform3D(Basis.looking_at(forward, Vector3.UP), Vector3(p.x, height_at(idx) - 0.05, p.y))
			holder.add_child(ramp)


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


func _add_multimesh(node_name: String, transforms: Array[Transform3D], material: Material,
		colors: Array[Color] = []) -> void:
	if transforms.is_empty():
		return
	var box := BoxMesh.new()
	box.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = not colors.is_empty()
	multimesh.mesh = box
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		if multimesh.use_colors:
			multimesh.set_instance_color(i, colors[i] if i < colors.size() else Color.WHITE)
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	_generated.add_child(instance)
