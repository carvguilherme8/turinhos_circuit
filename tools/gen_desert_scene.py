"""Monta scenes/tracks/desert_park.tscn (Parque do Deserto, andar livre) a partir da cena da
fazenda (moto, câmera, HUD e menu): troca a pista e a corrida pelo vale do deserto, com as
atrações posicionadas aqui (rampas, loopings, argolas de fogo e contêineres).
Para mudar o lugar das atrações, edite a seção "atrações" e rode de novo.

Uso: python tools/gen_desert_scene.py
"""
import io
import math
import os
import re

os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
src = io.open("scenes/tracks/farm_circuit.tscn", encoding="utf-8").read()
blocks = re.split(r"(?m)^(?=\[)", src)
drop = {"Track", "Bot3", "Bot5", "Bot7", "Bots", "RaceManager", "RaceHud", "CrowdAmbience", "Rain"}
out = []
for b in blocks:
    head = b.split("\n", 1)[0]
    m = re.match(r'\[node name="([^"]+)"', head)
    if m:
        pm = re.search(r'parent="([^"]+)"', head)
        parent = pm.group(1) if pm else ""
        if m.group(1) in drop or parent in drop:
            continue
    out.append(b)
s = "".join(out)
s = s.replace('[node name="FarmCircuit" type="Node3D"]', '[node name="DesertPark" type="Node3D"]')

# ---- céu limpo de deserto, sol forte, sem chuva; só uma névoa de areia ao longe
start = s.index('[sub_resource type="ShaderMaterial" id="SkyMat"]')
end = s.index('[sub_resource type="Sky" id="Sky"]')
s = s[:start] + '''[sub_resource type="ShaderMaterial" id="SkyMat"]
shader = ExtResource("sky_shader")
shader_parameter/top_color = Color(0.16, 0.4, 0.84, 1)
shader_parameter/mid_color = Color(0.42, 0.64, 0.94, 1)
shader_parameter/horizon_color = Color(0.96, 0.82, 0.6, 1)
shader_parameter/ground_color = Color(0.8, 0.6, 0.4, 1)
shader_parameter/sun_color = Color(1, 0.92, 0.72, 1)
shader_parameter/sun_size = 0.05
shader_parameter/sun_glow = 0.3
shader_parameter/star_density = 0.0

''' + s[start + len(s[start:end]):]
env_start = s.index('[sub_resource type="Environment" id="Env"]')
env_end = s.index("\n\n", env_start)
s = s[:env_start] + '''[sub_resource type="Environment" id="Env"]
background_mode = 2
sky = SubResource("Sky")
ambient_light_source = 3
ambient_light_energy = 1.0
tonemap_mode = 2
glow_enabled = true
glow_intensity = 0.5
glow_bloom = 0.04
fog_enabled = true
fog_light_color = Color(0.92, 0.8, 0.62, 1)
fog_density = 0.0032
fog_sky_affect = 0.25''' + s[env_end:]
sun_start = s.index('[node name="Sun" type="DirectionalLight3D" parent="."]')
sun_end = s.index("\n\n", sun_start)
s = s[:sun_start] + '''[node name="Sun" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.866, 0.3536, -0.3536, 0, 0.7071, 0.7071, 0.5, -0.6124, 0.6124, 0, 30, 0)
light_color = Color(1, 0.93, 0.8, 1)
light_energy = 1.3
shadow_enabled = true
directional_shadow_max_distance = 150.0''' + s[sun_end:]
clouds_start = s.index('[node name="Clouds" type="Node3D" parent="."]')
clouds_end = s.index("\n\n", clouds_start)
s = s[:clouds_start] + '''[node name="Clouds" type="Node3D" parent="."]
script = ExtResource("clouds")
color = Color(1, 0.98, 0.95, 1)
glow_color = Color(1, 0.85, 0.7, 1)
glow_energy = 0.1
coverage = 0.14
altitude = 95.0''' + s[clouds_end:]

# ---- moto do jogador no ponto de partida (olhando para -Z)
s = re.sub(r'(\[node name="Bike" parent="\." instance=ExtResource\("bike"\)\]\n)transform = [^\n]*\n',
           r'\1transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 19, 1.0, 30)\n', s)
s = re.sub(r'(\[node name="ChaseCamera"[^\]]*\]\n)transform = [^\n]*\n',
           r'\1transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 19, 4.0, 36)\n', s)


# ---- atrações
def basis(yaw_deg):
    a = math.radians(yaw_deg)
    c, sn = math.cos(a), math.sin(a)
    # rotação em torno de Y; o .tscn grava por linhas
    return f"{c:.4f}, 0, {sn:.4f}, 0, 1, 0, {-sn:.4f}, 0, {c:.4f}"


def forward(yaw_deg):
    a = math.radians(yaw_deg)
    return (-math.sin(a), -math.cos(a))  # para onde -Z aponta depois de girar `yaw`


nodes = []
keep = []
rings = []


def ramp(name, x, z, yaw, up=0.0, top=0.0, down=0.0, height=1.0, width=9.0, base=1.2, crest=0.7, bump=False, y=0.0):
    nodes.append(f'''[node name="{name}" type="StaticBody3D" parent="Features/Ramps"]
transform = Transform3D({basis(yaw)}, {x:.2f}, {y:.2f}, {z:.2f})
script = ExtResource("ramp")
up_length = {up}
top_length = {top}
down_length = {down}
height = {height}
width = {width}
base_radius = {base}
crest_radius = {crest}
is_bump = {"true" if bump else "false"}
material = ExtResource("ramp_dirt")
''')


def ring(name, x, y, z, yaw, radius=3.6, stand=0.0):
    rings.append(name)
    nodes.append(f'''[node name="{name}" type="Node3D" parent="Features/Rings"]
transform = Transform3D({basis(yaw)}, {x:.2f}, {y:.2f}, {z:.2f})
script = ExtResource("fire_ring")
radius = {radius}
stand_height = {stand}
''')


def loop(name, x, z, yaw, radius, offset):
    nodes.append(f'''[node name="{name}" type="Node3D" parent="Features/Loops"]
transform = Transform3D({basis(yaw)}, {x:.2f}, 0, {z:.2f})
script = ExtResource("loop")
radius = {radius}
offset = {offset}
''')


def rotate_about(center, point, yaw_deg):
    """Gira `point` em volta de `center` pelo mesmo giro que um rumo `yaw` aplica (em Y)."""
    t = math.radians(yaw_deg)
    dx, dz = point[0] - center[0], point[1] - center[1]
    return (center[0] + dx * math.cos(t) + dz * math.sin(t), center[1] - dx * math.sin(t) + dz * math.cos(t))


def wallride(name, start, heading_yaw, turn, radius, lane_inside=3.0):
    """Curva de wallride começando em `start` (ponto da raia) andando para `heading_yaw`.
    `turn` > 0 vira à direita, < 0 à esquerda (graus). A raia passa `lane_inside` m por dentro
    da linha do meio (no fundo inclinado; quem vem rápido pelo meio sobe na parede).
    Devolve o ponto e o rumo da raia no fim da curva e a lista de pontos da raia."""
    right = turn > 0
    fx, fz = forward(heading_yaw)
    rx, rz = -fz, fx  # direita do rumo
    side = 1.0 if right else -1.0
    # a origem do nó fica na linha do meio: `lane_inside` m para fora da raia
    ox, oz = start[0] - rx * side * lane_inside, start[1] - rz * side * lane_inside
    nodes.append(f'''[node name="{name}" type="Node3D" parent="Features/Walls"]
transform = Transform3D({basis(heading_yaw)}, {ox:.2f}, 0, {oz:.2f})
script = ExtResource("wallride")
radius = {radius}
arc_degrees = {abs(turn)}
turn_right = {"true" if right else "false"}
material = ExtResource("ramp_dirt")
''')
    cx, cz = ox + rx * side * radius, oz + rz * side * radius
    pts = []
    n = max(4, int(abs(turn) / 10))
    # virar à direita diminui o yaw (no Godot, yaw maior = virar à esquerda)
    for k in range(n + 1):
        pts.append(rotate_about((cx, cz), start, -turn * k / n))
    end = pts[-1]
    keep.append((cx, cz, radius + 10))
    return end, heading_yaw - turn, pts


def double(prefix, x, z, yaw, length, height, base, gap, ring_y=0.0, ring_radius=3.6):
    """Salto de mão dupla: duas rampas iguais, uma de frente para a outra, com `gap` m entre os
    lábios. Num sentido a 1ª decola e a descida da 2ª é o pouso; no outro, o contrário.
    A rampa A começa em (x, z) e o salto anda para `yaw`; argola (opcional) no meio do vão."""
    fx, fz = forward(yaw)
    lip = length + 0.9  # o arredondamento da crista alonga um pouco
    total = 2 * lip + gap
    ramp(prefix + "_A", x, z, yaw, up=length, height=height, base=base)
    ramp(prefix + "_B", x + fx * total, z + fz * total, yaw + 180.0, up=length, height=height, base=base)
    if ring_y > 0.0:
        mid = lip + gap * 0.5
        ring(prefix + "_Argola", x + fx * mid, ring_y, z + fz * mid, yaw, ring_radius)
    keep.append((x + fx * total * 0.5, z + fz * total * 0.5, total * 0.5 + 8))
    return (x + fx * (lip + gap * 0.5), z + fz * (lip + gap * 0.5))


def tabletop(prefix, x, z, yaw, length, top, height, base, ring_y=0.0, ring_radius=3.6, ring_at=5.0):
    """Mesa simétrica (sobe, topo plano, desce igual): funciona nos dois sentidos.
    Argola (opcional) sobre o topo, `ring_at` m depois da beirada de cada lado."""
    fx, fz = forward(yaw)
    total = 2 * length + top
    ramp(prefix, x, z, yaw, up=length, top=top, down=length, height=height, base=base)
    if ring_y > 0.0:
        at = length + top * 0.5
        ring(prefix + "_Argola", x + fx * at, ring_y, z + fz * at, yaw, ring_radius)
    keep.append((x + fx * total * 0.5, z + fz * total * 0.5, total * 0.5 + 8))


# Dois circuitos fechados de mão dupla: retas de saltos ligadas por curvas de wallride
# (na raia de dentro faz a curva no fundo; rápido pelo meio, sobe na parede).
# Leste: mega salto -> wallride -> salto grande -> wallride.
# Oeste: wallride -> looping -> wallride -> salto sobre os contêineres.
# Cada curva tem retas de transição de 20 m antes e depois (LEAD): os saltos e o looping ficam
# inteiros entre elas, com espaço para o pouso e a rolagem antes da próxima curva.
# As rotas (pontos da raia) vão para tools/desert_routes.json (usadas nos testes).
FLOOR_RADIUS, CLIFF_RADIUS, MAP_HALF = 90.0, 110.0, 140.0
LEAD = 20.0   # retas de transição das curvas de wallride (scripts/tracks/wallride.gd)
TURN_R = 18.0
routes = {}

# ---------------- circuito leste: raias x = 4 (para o sul) e x = 34 (para o norte)
A_X, B_X, EAST_END = 4.0, 34.0, 50.0
east = [(A_X, EAST_END)]
# raia A (para o sul): transição de 50 a 30, mega salto de 28 a -21,8, transição de -30 a -50
double("Mega", A_X, EAST_END - LEAD - 2, 0, 18, 7.5, 6, 12, 9.8, 4.0)
east.append((A_X, -EAST_END))
_, _, pts = wallride("CurvaSul", (A_X, -EAST_END), 0, 180, TURN_R)        # vira à direita (+x)
east += pts
# raia B (para o norte): transição de -50 a -30, salto grande de -28 a 15,8, transição de 30 a 50
double("SaltoGrande", B_X, -EAST_END + LEAD + 2, 180, 16, 6, 5, 10, 8.0, 3.8)
east.append((B_X, EAST_END))
_, _, pts = wallride("CurvaNorte", (B_X, EAST_END), 180, 180, TURN_R)      # vira à direita (-x)
east += pts
routes["leste"] = east

# ---------------- circuito oeste: raia C (para o sul, com o looping) e raia D (para o norte)
# O looping fica no meio da raia C, entre as duas curvas. Ele é girado 11,5° para a moto sair
# dele seguindo reto para o sul (pela física natural ela sai ~11,5° para +x da reta de
# entrada); a curva norte (191,5° à esquerda) entrega a moto nesse rumo torto, e uma reta
# curta nesse mesmo rumo a leva até a entrada do looping.
C_X = -24.0
W_R = 16.0
LANE_W = W_R - 3.0
LOOP_TILT = 11.5
WEST_TOP, WEST_BOTTOM = 40.0, -40.0
loop_exit = (7.99, -2.85)          # saída do looping girado, a partir da origem dele
loop_lead = rotate_about((0.0, 0.0), (0.0, 4.0), LOOP_TILT)   # começo da reta de entrada
turn_n = -(180.0 + LOOP_TILT)
back = (math.sin(math.radians(LOOP_TILT)), math.cos(math.radians(LOOP_TILT)))  # para trás do rumo 11,5°
probe = rotate_about((0.0, 0.0), (-LANE_W, 0.0), -turn_n)      # fim da curva relativo ao centro
# looping centralizado entre o fim da curva norte e o começo da curva sul (o meio dele fica
# ~3,75 m ao sul da origem)
end_z = WEST_TOP + probe[1]
LOOP_Z = (end_z + WEST_BOTTOM) / 2.0 + 3.75
loop_o = (C_X - loop_exit[0], LOOP_Z)
lead_start = (loop_o[0] + loop_lead[0], loop_o[1] + loop_lead[1])
# a curva norte termina na reta que sai da entrada do looping para trás (no rumo torto)
L = (end_z - lead_start[1]) / back[1]
assert L > LEAD + 4.0, "o looping ficou dentro da transição da curva norte"
assert loop_o[1] + loop_exit[1] - 4.0 > WEST_BOTTOM + LEAD, "o looping ficou dentro da transição da curva sul"
end_n = (lead_start[0] + back[0] * L, lead_start[1] + back[1] * L)
D_X = end_n[0] - probe[0] - LANE_W
west = [(D_X, WEST_TOP)]
_, _, pts = wallride("CurvaOesteNorte", (D_X, WEST_TOP), 180, turn_n, W_R)
west += pts
loop("Looping", loop_o[0], loop_o[1], LOOP_TILT, 7.5, 8.5)
keep.append((loop_o[0] + 4, loop_o[1], 14))
west.append(lead_start)
west.append((C_X, loop_o[1] + loop_exit[1] - 4.0))
west.append((C_X, WEST_BOTTOM))
# curva sul com o raio exato para a raia D sair reta até o começo da curva norte
_, _, pts = wallride("CurvaOesteSul", (C_X, WEST_BOTTOM), 0, -180, (C_X - D_X) / 2.0 + 3.0)  # à esquerda (-x)
west += pts
D_X2 = west[-1][0]
# salto sobre os contêineres (contêineres no vão), no meio da raia D, entre as transições
container_mid = double("Conteiner", D_X2, -15, 180, 8, 3.2, 3, 12)
west.append((D_X2, WEST_TOP))
routes["oeste"] = west
print("oeste: raia D em x = %.2f (curva sul termina em %.2f); reta torta de %.1f m até o looping em %s" % (
    D_X, D_X2, L, tuple(round(v, 2) for v in loop_o)))

# contêineres atravessados no vão do salto "Conteiner": (x, z, giro em graus)
containers = [(round(container_mid[0] + k, 2), round(container_mid[1], 2), 90.0) for k in (-3.0, 3.0)]

import json as _json
with open(os.path.join("tools", "desert_routes.json"), "w") as _f:
    _json.dump(routes, _f)

nodes_text = "\n".join(nodes)
# ---- ext resources novos
last = list(re.finditer(r"\[ext_resource [^\n]*\]\n", s))[-1]
s = s[:last.end()] + "\n".join([
    '[ext_resource type="Script" path="res://scripts/tracks/desert_park.gd" id="desert_park"]',
    '[ext_resource type="Material" path="res://assets/materials/desert/terrain.tres" id="desert_terrain"]',
    '[ext_resource type="Material" path="res://assets/materials/desert/ramp_dirt.tres" id="ramp_dirt"]',
    '[ext_resource type="Script" path="res://scripts/tracks/ramp.gd" id="ramp"]',
    '[ext_resource type="Script" path="res://scripts/tracks/fire_ring.gd" id="fire_ring"]',
    '[ext_resource type="Script" path="res://scripts/tracks/loop.gd" id="loop"]',
    '[ext_resource type="Script" path="res://scripts/tracks/wallride.gd" id="wallride"]',
    '[ext_resource type="Script" path="res://scripts/ui/free_roam_hud.gd" id="free_roam_hud"]',
    '[ext_resource type="AudioStream" path="res://assets/audio/sfx/fire_whoosh.wav" id="sfx_whoosh"]',
    '[ext_resource type="AudioStream" path="res://assets/audio/sfx/wind_loop.wav" id="sfx_wind"]',
]) + "\n" + s[last.end():]

keep_text = ", ".join(f"{x:.1f}, {z:.1f}, {r:.1f}" for x, z, r in keep)
park = f'''[node name="Park" type="Node3D" parent="."]
script = ExtResource("desert_park")
floor_radius = {FLOOR_RADIUS}
cliff_radius = {CLIFF_RADIUS}
map_half_size = {MAP_HALF}
prop_count = 110
mesas = Array[Vector4]([Vector4(-78, -50, 9.0, 10.0), Vector4(-76, 56, 8.0, 8.0), Vector4(74, 52, 9.0, 9.0), Vector4(70, -56, 9.0, 9.0)])
keep_out = PackedVector3Array({keep_text})
container_spots = PackedVector3Array({", ".join(f"{x}, {z}, {r}" for x, z, r in containers)})
terrain_material = ExtResource("desert_terrain")

[node name="Features" type="Node3D" parent="."]

[node name="Ramps" type="Node3D" parent="Features"]

[node name="Loops" type="Node3D" parent="Features"]

[node name="Walls" type="Node3D" parent="Features"]

[node name="Rings" type="Node3D" parent="Features"]

'''
hud = '''
[node name="FreeRoamHud" type="Control" parent="HUD" node_paths=PackedStringArray("bike", "rings_root")]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
script = ExtResource("free_roam_hud")
bike = NodePath("../../Bike")
rings_root = NodePath("../../Features/Rings")
ring_sound = ExtResource("sfx_whoosh")

[node name="Wind" type="AudioStreamPlayer" parent="."]
stream = ExtResource("sfx_wind")
volume_db = -16.0
autoplay = true
'''
# o parque e as atrações entram antes da moto (a moto não pode cair no vazio no 1º quadro)
bike_at = s.index('[node name="Bike" parent="." instance=ExtResource("bike")]')
s = s[:bike_at] + park + nodes_text + "\n" + s[bike_at:]
s = s.rstrip("\n") + "\n" + hud
steps = len(re.findall(r"^\[ext_resource ", s, re.M)) + len(re.findall(r"^\[sub_resource ", s, re.M)) + 1
s = re.sub(r"load_steps=\d+", f"load_steps={steps}", s, count=1)
io.open("scenes/tracks/desert_park.tscn", "w", encoding="utf-8", newline="\n").write(s)
print("ok", len(rings), "argolas", len(keep), "áreas")
