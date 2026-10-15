@tool
class_name Stadium
extends Node3D
## Estádio em volta da arena retangular: muro com faixas de propaganda, arquibancada de dois
## andares (setores com torcida e cadeiras de cores variadas, escadarias, corredor com faixa de
## propaganda entre os andares), cobertura nas laterais compridas, bandeiras, torres de
## iluminação e telão. Tudo gerado pelo script (visível no editor).

@export var arena_min: Vector2 = Vector2(-31, -54):
	set(value):
		arena_min = value
		_queue_rebuild()
@export var arena_max: Vector2 = Vector2(31, 64):
	set(value):
		arena_max = value
		_queue_rebuild()

@export_group("Muro")
@export var wall_height: float = 1.4
@export var wall_thickness: float = 0.5
## Comprimento de uma repetição da faixa de propaganda.
@export var banner_length: float = 8.0

@export_group("Arquibancada")
@export_range(1, 30) var lower_tiers: int = 8:
	set(value):
		lower_tiers = value
		_queue_rebuild()
@export_range(0, 30) var upper_tiers: int = 8:
	set(value):
		upper_tiers = value
		_queue_rebuild()
@export var tier_depth: float = 1.2
@export var tier_rise: float = 0.7
## Corredor entre os andares e a faixa de propaganda na frente do andar de cima.
@export var walkway_depth: float = 2.6
@export var fascia_height: float = 1.2
## Comprimento de um setor (entre duas escadarias) e largura da escadaria.
@export var section_length: float = 9.0
@export var aisle_width: float = 1.4
## Largura de uma repetição da textura da torcida e quantas variações o atlas tem.
@export var crowd_tile: float = 2.0
@export var crowd_variants: int = 4
## Chance de uma fileira de um setor cheio aparecer vazia (variedade).
@export_range(0.0, 1.0) var empty_row_chance: float = 0.12
@export var seat_colors: PackedColorArray = PackedColorArray([
	Color("2a5ce8"), Color("e8572a"), Color("f0d23c"), Color("e8e8e8"), Color("c83c46"),
])
@export var random_seed: int = 7
## Cobertura sobre as laterais compridas.
@export var roof: bool = true
@export var roof_depth: float = 11.0
@export var roof_height: float = 6.0
@export var flag_colors: PackedColorArray = PackedColorArray([
	Color("2a5ce8"), Color("e8572a"), Color("f0d23c"), Color("f0f0f0"),
])

@export_group("Iluminação")
@export var tower_height: float = 34.0
@export var tower_light_energy: float = 3.0
@export var tower_lights: bool = true

@export_group("Materiais")
@export var concrete_material: Material
@export var crowd_material: Material
@export var banner_material: Material
@export var metal_material: Material
@export var light_material: Material
@export var screen_material: Material
@export var stairs_material: Material
## Cadeiras em cinza; a cor de cada setor vem da cor do vértice.
@export var seats_material: Material
## Chão do lado de fora do estádio.
@export var outside_material: Material
@export var outside_size: float = 400.0

var _generated: Node3D
var _rebuild_queued: bool = false


func _ready() -> void:
	_rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	if _generated:
		_generated.free()
	_generated = Node3D.new()
	_generated.name = "_Generated"
	add_child(_generated)
	_build_wall()
	_build_stands()
	_build_towers()
	_build_jumbotron()
	_build_outside()


# ---------------------------------------------------------------- utilidades

## Retângulo da arena expandido por `offset` metros: [min, max].
func _rect(offset: float) -> Array[Vector2]:
	return [arena_min - Vector2.ONE * offset, arena_max + Vector2.ONE * offset]


## Quadrilátero com cantos TL, TR, BR, BL vistos de frente (lado da `normal`).
func _quad(st: SurfaceTool, tl: Vector3, tr: Vector3, br: Vector3, bl: Vector3,
		normal: Vector3, uv_size: Vector2) -> void:
	var uvs := [Vector2.ZERO, Vector2(uv_size.x, 0.0), uv_size, Vector2(0.0, uv_size.y)]
	var verts := [tl, tr, br, bl]
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_normal(normal)
		st.set_uv(uvs[k])
		st.add_vertex(verts[k])


## Faces internas (viradas para a arena) de um retângulo, entre as alturas y0 e y1.
func _inner_faces(st: SurfaceTool, rect: Array[Vector2], y0: float, y1: float, tile: Vector2) -> void:
	var lo := rect[0]
	var hi := rect[1]
	# Cantos no sentido horário visto de cima; cada lado olha para dentro.
	var sides := [
		[Vector2(lo.x, lo.y), Vector2(hi.x, lo.y), Vector3(0, 0, 1)],   # lado -Z, olha +Z
		[Vector2(hi.x, lo.y), Vector2(hi.x, hi.y), Vector3(-1, 0, 0)],  # lado +X, olha -X
		[Vector2(hi.x, hi.y), Vector2(lo.x, hi.y), Vector3(0, 0, -1)],  # lado +Z, olha -Z
		[Vector2(lo.x, hi.y), Vector2(lo.x, lo.y), Vector3(1, 0, 0)],   # lado -X, olha +X
	]
	for side in sides:
		var a: Vector2 = side[0]
		var b: Vector2 = side[1]
		var normal: Vector3 = side[2]
		var length := a.distance_to(b)
		# Vista de dentro da arena, `a` fica à esquerda e `b` à direita.
		_quad(st, Vector3(a.x, y1, a.y), Vector3(b.x, y1, b.y), Vector3(b.x, y0, b.y), Vector3(a.x, y0, a.y),
				normal, Vector2(length / tile.x, (y1 - y0) / tile.y))


## Anel horizontal (topo de um degrau) entre dois retângulos, na altura y.
func _ring_top(st: SurfaceTool, inner: Array[Vector2], outer: Array[Vector2], y: float) -> void:
	var i0 := inner[0]
	var i1 := inner[1]
	var o0 := outer[0]
	var o1 := outer[1]
	var corners_inner := [Vector2(i0.x, i0.y), Vector2(i1.x, i0.y), Vector2(i1.x, i1.y), Vector2(i0.x, i1.y)]
	var corners_outer := [Vector2(o0.x, o0.y), Vector2(o1.x, o0.y), Vector2(o1.x, o1.y), Vector2(o0.x, o1.y)]
	for k in 4:
		var a_in: Vector2 = corners_inner[k]
		var b_in: Vector2 = corners_inner[(k + 1) % 4]
		var a_out: Vector2 = corners_outer[k]
		var b_out: Vector2 = corners_outer[(k + 1) % 4]
		# Trapézio visto de cima; ordem horária = frente.
		var verts := [Vector3(a_out.x, y, a_out.y), Vector3(b_out.x, y, b_out.y),
				Vector3(b_in.x, y, b_in.y), Vector3(a_in.x, y, a_in.y)]
		for idx in [0, 1, 2, 0, 2, 3]:
			var v: Vector3 = verts[idx]
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(v.x, v.z))
			st.add_vertex(v)


func _box(parent: Node3D, pos: Vector3, size: Vector3, material: Material, collide := false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh.mesh = box
	mesh.position = pos
	parent.add_child(mesh)
	if collide:
		var body := StaticBody3D.new()
		body.position = pos
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
		parent.add_child(body)
	return mesh


func _commit(st: SurfaceTool, material: Material, node_name: String) -> void:
	st.set_material(material)
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = st.commit()
	_generated.add_child(mesh)


# ---------------------------------------------------------------- partes

func _build_wall() -> void:
	var size := arena_max - arena_min
	var center := (arena_max + arena_min) * 0.5
	var t := wall_thickness
	var h := wall_height
	var walls := [
		[Vector3(center.x, h * 0.5, arena_min.y - t * 0.5), Vector3(size.x + t * 2.0, h, t)],
		[Vector3(center.x, h * 0.5, arena_max.y + t * 0.5), Vector3(size.x + t * 2.0, h, t)],
		[Vector3(arena_min.x - t * 0.5, h * 0.5, center.y), Vector3(t, h, size.y)],
		[Vector3(arena_max.x + t * 0.5, h * 0.5, center.y), Vector3(t, h, size.y)],
	]
	for wall in walls:
		_box(_generated, wall[0], wall[1], concrete_material, true)

	# Faixas na face interna do muro (um pouco à frente para não brigar com o concreto).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_inner_faces(st, _rect(-0.01), 0.2, h - 0.15, Vector2(banner_length, h - 0.35))
	_commit(st, banner_material, "Banners")


## Distância do fim da arquibancada até a borda da arena.
func _stands_depth() -> float:
	return wall_thickness + 0.4 + (lower_tiers + upper_tiers) * tier_depth + walkway_depth + 0.4


## Altura do parapeito no alto da arquibancada.
func _stands_top() -> float:
	return wall_height + (lower_tiers + upper_tiers) * tier_rise + fascia_height + 1.2


## Lados internos de um retângulo, no sentido horário visto de cima:
## [início, fim, direção para fora do estádio, eixo ao longo do lado (0 = x, 1 = z)].
func _sides(rect: Array[Vector2]) -> Array:
	var lo := rect[0]
	var hi := rect[1]
	return [
		[Vector2(lo.x, lo.y), Vector2(hi.x, lo.y), Vector2(0, -1), 0],
		[Vector2(hi.x, lo.y), Vector2(hi.x, hi.y), Vector2(1, 0), 1],
		[Vector2(hi.x, hi.y), Vector2(lo.x, hi.y), Vector2(0, 1), 0],
		[Vector2(lo.x, hi.y), Vector2(lo.x, lo.y), Vector2(-1, 0), 1],
	]


## Divide um lado em setores e escadarias. As escadarias ficam em posições fixas do mundo,
## então se alinham em todas as fileiras. Retorna [t0, t1, é_escada, índice_do_setor].
func _segments(a: Vector2, b: Vector2, axis: int) -> Array:
	var center := (arena_max + arena_min)[axis] * 0.5
	var t_a := a[axis]
	var t_b := b[axis]
	var lo := minf(t_a, t_b)
	var hi := maxf(t_a, t_b)
	var cuts: Array = []
	var k := floori((lo - center) / section_length) - 1
	while true:
		var aisle_center := center + (k + 0.5) * section_length
		var a0 := aisle_center - aisle_width * 0.5
		if a0 > hi:
			break
		cuts.append([a0, aisle_center + aisle_width * 0.5])
		k += 1
	var result: Array = []
	var cursor := lo
	for cut in cuts:
		var c0: float = maxf(cut[0], lo)
		var c1: float = minf(cut[1], hi)
		if c1 <= c0:
			continue
		if c0 > cursor:
			result.append([cursor, c0, false, floori((cursor + c0) * 0.5 / section_length)])
		result.append([c0, c1, true, 0])
		cursor = c1
	if cursor < hi:
		result.append([cursor, hi, false, floori((cursor + hi) * 0.5 / section_length)])
	if t_a > t_b:
		# O lado corre no sentido negativo do eixo: inverte a ordem e as pontas.
		var flipped: Array = []
		for seg in result:
			flipped.push_front([seg[1], seg[0], seg[2], seg[3]])
		result = flipped
	return result


func _point_on_side(a: Vector2, axis: int, t: float) -> Vector2:
	var p := a
	p[axis] = t
	return p


## Quadrilátero horizontal (normal para cima) a partir de 4 cantos em qualquer ordem de volta.
func _top_quad(st: SurfaceTool, pts: Array, y: float, uvs: Array, color: Color, use_color := false) -> void:
	var a: Vector2 = pts[0]
	var b: Vector2 = pts[1]
	var c: Vector2 = pts[2]
	var order := [0, 1, 2, 0, 2, 3]
	# Frente no Godot = sentido horário visto de cima.
	if (b - a).cross(c - a) < 0.0:
		order = [0, 2, 1, 0, 3, 2]
	for idx in order:
		var p: Vector2 = pts[idx]
		st.set_normal(Vector3.UP)
		if use_color:  # só as cadeiras usam cor de vértice
			st.set_color(color)
		st.set_uv(uvs[idx])
		st.add_vertex(Vector3(p.x, y, p.y))


## Um andar de fileiras: frente de cada degrau com torcida (ou escada) e topo com cadeiras.
func _build_deck(sts: Dictionary, offset: float, base_y: float, count: int, deck: int, rng: RandomNumberGenerator) -> void:
	var variant_height := 1.0 / crowd_variants
	# Cada setor tem uma torcida e uma cor de cadeira (sorteadas uma vez por setor e andar).
	var section_style := {}
	for k in count:
		var inner := _rect(offset + k * tier_depth)
		var y0 := base_y + k * tier_rise
		var y1 := y0 + tier_rise
		var side_index := 0
		for side in _sides(inner):
			var a: Vector2 = side[0]
			var out: Vector2 = side[2]
			var axis: int = side[3]
			var normal := Vector3(-out.x, 0.0, -out.y)
			for seg in _segments(a, side[1], axis):
				var p0 := _point_on_side(a, axis, seg[0])
				var p1 := _point_on_side(a, axis, seg[1])
				var length := p0.distance_to(p1)
				var q0 := p0 + out * tier_depth
				var q1 := p1 + out * tier_depth
				var top_uvs := [Vector2(seg[0], tier_depth), Vector2(seg[1], tier_depth), Vector2(seg[1], 0.0), Vector2(seg[0], 0.0)]
				if seg[2]:
					_quad(sts["stairs"], Vector3(p0.x, y1, p0.y), Vector3(p1.x, y1, p1.y), Vector3(p1.x, y0, p1.y),
							Vector3(p0.x, y0, p0.y), normal, Vector2(length, 1.0))
					_top_quad(sts["stairs"], [q0, q1, p1, p0], y1, top_uvs, Color.WHITE)
					continue
				var key := "%d:%d:%d" % [deck, side_index, seg[3]]
				if not section_style.has(key):
					section_style[key] = [rng.randi_range(0, crowd_variants - 2), seat_colors[rng.randi() % seat_colors.size()]]
				var variant: int = section_style[key][0]
				if rng.randf() < empty_row_chance:
					variant = crowd_variants - 1  # fileira vazia
				var v0 := variant * variant_height
				var crowd: SurfaceTool = sts["crowd"]
				var uvs := [Vector2(0.0, v0), Vector2(length / crowd_tile, v0),
						Vector2(length / crowd_tile, v0 + variant_height), Vector2(0.0, v0 + variant_height)]
				var verts := [Vector3(p0.x, y1, p0.y), Vector3(p1.x, y1, p1.y), Vector3(p1.x, y0, p1.y), Vector3(p0.x, y0, p0.y)]
				for idx in [0, 1, 2, 0, 2, 3]:
					crowd.set_normal(normal)
					crowd.set_uv(uvs[idx])
					crowd.add_vertex(verts[idx])
				_top_quad(sts["seats"], [q0, q1, p1, p0], y1, top_uvs, section_style[key][1], true)
			side_index += 1
		# Cantos do anel (quadrados entre dois lados): concreto.
		var outer := _rect(offset + (k + 1) * tier_depth)
		_corner_tops(sts["concrete"], inner, outer, y1)


func _corner_tops(st: SurfaceTool, inner: Array[Vector2], outer: Array[Vector2], y: float) -> void:
	var i0 := inner[0]
	var i1 := inner[1]
	var o0 := outer[0]
	var o1 := outer[1]
	var squares := [
		[Vector2(o0.x, o0.y), Vector2(i0.x, o0.y), Vector2(i0.x, i0.y), Vector2(o0.x, i0.y)],
		[Vector2(i1.x, o0.y), Vector2(o1.x, o0.y), Vector2(o1.x, i0.y), Vector2(i1.x, i0.y)],
		[Vector2(i1.x, i1.y), Vector2(o1.x, i1.y), Vector2(o1.x, o1.y), Vector2(i1.x, o1.y)],
		[Vector2(o0.x, i1.y), Vector2(i0.x, i1.y), Vector2(i0.x, o1.y), Vector2(o0.x, o1.y)],
	]
	for sq in squares:
		var uvs := []
		for p in sq:
			uvs.append(p)
		_top_quad(st, sq, y, uvs, Color.WHITE)


func _build_stands() -> void:
	var sts := {}
	for key in ["crowd", "seats", "stairs", "concrete", "fascia"]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		sts[key] = st
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed

	var offset := wall_thickness + 0.4
	var y := wall_height
	# Base de concreto atrás do muro até a primeira fileira.
	_inner_faces(sts["concrete"], _rect(offset), 0.0, wall_height, Vector2.ONE)

	# Andar de baixo.
	_build_deck(sts, offset, y, lower_tiers, 0, rng)
	offset += lower_tiers * tier_depth
	y += lower_tiers * tier_rise

	if upper_tiers > 0:
		# Corredor entre os andares e faixa de propaganda na frente do andar de cima.
		_ring_top(sts["concrete"], _rect(offset), _rect(offset + walkway_depth), y)
		offset += walkway_depth
		_inner_faces(sts["fascia"], _rect(offset), y, y + fascia_height, Vector2(banner_length, fascia_height))
		y += fascia_height
		_build_deck(sts, offset, y, upper_tiers, 1, rng)
		offset += upper_tiers * tier_depth
		y += upper_tiers * tier_rise

	# Parapeito no alto e fundo da arquibancada.
	var back := _rect(offset)
	_inner_faces(sts["concrete"], back, y, y + 1.2, Vector2.ONE)
	_ring_top(sts["concrete"], back, _rect(offset + 0.4), y + 1.2)
	_outer_faces(sts["concrete"], _rect(offset + 0.4), 0.0, y + 1.2)

	_commit(sts["crowd"], crowd_material, "Crowd")
	_commit(sts["seats"], seats_material, "Seats")
	_commit(sts["stairs"], stairs_material, "Stairs")
	_commit(sts["concrete"], concrete_material, "Stands")
	_commit(sts["fascia"], banner_material, "Fascia")
	_build_flags(_rect(offset + 0.2), y + 1.2)
	if roof:
		_build_roof(_rect(offset + 0.4), y + 1.2)


## Cobertura nas duas laterais compridas, com pilares atrás e luzes na borda da frente.
func _build_roof(back: Array[Vector2], top: float) -> void:
	var size := arena_max - arena_min
	var long_axis_is_z := size.y >= size.x
	var roof_y := top + roof_height
	for side: float in [-1.0, 1.0]:
		var length := (back[1] - back[0]).y if long_axis_is_z else (back[1] - back[0]).x
		var center := (back[0] + back[1]) * 0.5
		var edge: float = (back[1].x if side > 0.0 else back[0].x) if long_axis_is_z else (back[1].y if side > 0.0 else back[0].y)
		var inward: float = -side
		var roof_center: float = edge + inward * roof_depth * 0.5
		var pos := Vector3(roof_center, roof_y, center.y) if long_axis_is_z else Vector3(center.x, roof_y, roof_center)
		var dims := Vector3(roof_depth, 0.5, length) if long_axis_is_z else Vector3(length, 0.5, roof_depth)
		_box(_generated, pos, dims, metal_material)
		# Faixa de luz na borda da frente da cobertura.
		var front: float = edge + inward * roof_depth
		var light_pos := Vector3(front, roof_y - 0.35, center.y) if long_axis_is_z else Vector3(center.x, roof_y - 0.35, front)
		var light_dims := Vector3(0.3, 0.25, length - 2.0) if long_axis_is_z else Vector3(length - 2.0, 0.25, 0.3)
		_box(_generated, light_pos, light_dims, light_material)
		# Pilares a cada 12 m na borda de trás.
		var count := int(length / 12.0)
		for i in range(count + 1):
			var t := -length * 0.5 + length * float(i) / maxf(1.0, count)
			var column := Vector3(edge, (top + roof_y) * 0.5, center.y + t) if long_axis_is_z else Vector3(center.x + t, (top + roof_y) * 0.5, edge)
			_box(_generated, column, Vector3(0.6, roof_y - top, 0.6), metal_material)


## Bandeiras coloridas no parapeito das pontas (lados curtos).
func _build_flags(rect: Array[Vector2], top: float) -> void:
	var size := arena_max - arena_min
	var short_axis := 0 if size.y >= size.x else 1
	var materials: Array[StandardMaterial3D] = []
	for c in flag_colors:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 1.0
		materials.append(m)
	var index := 0
	for side in _sides(rect):
		if side[3] != short_axis:
			continue
		var a: Vector2 = side[0]
		var b: Vector2 = side[1]
		var length := a.distance_to(b)
		var count := int(length / 6.0)
		for i in range(1, count):
			var p := a.lerp(b, float(i) / count)
			_box(_generated, Vector3(p.x, top + 1.5, p.y), Vector3(0.12, 3.0, 0.12), metal_material)
			var flag := _box(_generated, Vector3(p.x, top + 2.5, p.y), Vector3(0.05, 0.7, 1.1), materials[index % materials.size()])
			if short_axis == 0:
				flag.rotation.y = PI * 0.5
			flag.position += Vector3(0.0, 0.0, 0.55) if short_axis == 1 else Vector3(0.55, 0.0, 0.0)
			index += 1


## Faces externas (para fora do estádio) de um retângulo.
func _outer_faces(st: SurfaceTool, rect: Array[Vector2], y0: float, y1: float) -> void:
	var lo := rect[0]
	var hi := rect[1]
	var sides := [
		[Vector2(hi.x, lo.y), Vector2(lo.x, lo.y), Vector3(0, 0, -1)],
		[Vector2(hi.x, hi.y), Vector2(hi.x, lo.y), Vector3(1, 0, 0)],
		[Vector2(lo.x, hi.y), Vector2(hi.x, hi.y), Vector3(0, 0, 1)],
		[Vector2(lo.x, lo.y), Vector2(lo.x, hi.y), Vector3(-1, 0, 0)],
	]
	for side in sides:
		var a: Vector2 = side[0]
		var b: Vector2 = side[1]
		_quad(st, Vector3(a.x, y1, a.y), Vector3(b.x, y1, b.y), Vector3(b.x, y0, b.y), Vector3(a.x, y0, a.y),
				side[2], Vector2(a.distance_to(b), y1 - y0))


func _build_towers() -> void:
	var stands_out := _stands_depth() + 3.0
	var rect := _rect(stands_out)
	var center := (arena_max + arena_min) * 0.5
	var target := Vector3(center.x, 0.0, center.y)
	for corner in [rect[0], Vector2(rect[1].x, rect[0].y), rect[1], Vector2(rect[0].x, rect[1].y)]:
		var base := Vector3(corner.x, 0.0, corner.y)
		_box(_generated, base + Vector3.UP * tower_height * 0.5, Vector3(1.4, tower_height, 1.4), metal_material)
		# Painel de luz virado para o centro da arena.
		var head := Node3D.new()
		head.position = base + Vector3.UP * (tower_height + 1.5)
		_generated.add_child(head)
		head.look_at(target, Vector3.UP)
		_box(head, Vector3.ZERO, Vector3(7.0, 3.6, 0.6), metal_material)
		var panel := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(6.4, 3.0)
		quad.material = light_material
		panel.mesh = quad
		panel.position.z = -0.31
		panel.rotation.y = PI  # QuadMesh olha para +Z; o painel olha para -Z (para a arena)
		head.add_child(panel)
		if tower_lights:
			var spot := SpotLight3D.new()
			spot.light_color = Color(1.0, 0.95, 0.85)
			spot.light_energy = tower_light_energy
			spot.spot_range = 160.0
			spot.spot_angle = 24.0
			spot.spot_attenuation = 0.4
			spot.position.z = -0.5
			head.add_child(spot)


func _build_jumbotron() -> void:
	var stands_out := _stands_depth()
	var center := (arena_max + arena_min) * 0.5
	var z := arena_min.y - stands_out - 1.0
	var bottom := _stands_top() + 2.0
	var size := Vector2(18.0, 6.75)
	var frame := _box(_generated, Vector3(center.x, bottom + size.y * 0.5, z), Vector3(size.x + 1.0, size.y + 1.0, 1.0), metal_material)
	var screen := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	quad.material = screen_material
	screen.mesh = quad
	screen.position.z = 0.51
	frame.add_child(screen)
	for side in [-1.0, 1.0]:
		_box(_generated, Vector3(center.x + side * size.x * 0.35, bottom * 0.5, z - 0.2), Vector3(0.8, bottom, 0.8), metal_material)


func _build_outside() -> void:
	var center := (arena_max + arena_min) * 0.5
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * outside_size
	plane.material = outside_material
	ground.mesh = plane
	# Um pouco abaixo do chão da arena para não aparecer por baixo dele.
	ground.position = Vector3(center.x, -0.05, center.y)
	_generated.add_child(ground)
