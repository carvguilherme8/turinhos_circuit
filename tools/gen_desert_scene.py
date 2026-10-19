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
           r'\1transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.8, 62)\n', s)
s = re.sub(r'(\[node name="ChaseCamera"[^\]]*\]\n)transform = [^\n]*\n',
           r'\1transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 3.8, 68)\n', s)


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


def jump_line(prefix, x, z, yaw, up, height, base, gap, land_height, land_top, land_down, ring_at, ring_y, ring_radius):
    """Kicker com origem em (x, z) andando para `yaw`; pouso a `gap` m do lábio; argola opcional."""
    fx, fz = forward(yaw)
    lip = up + 0.9  # o arredondamento da crista alonga um pouco
    ramp(prefix + "_Kicker", x, z, yaw, up=up, height=height, base=base)
    lx, lz = x + fx * (lip + gap), z + fz * (lip + gap)
    ramp(prefix + "_Pouso", lx, lz, yaw, top=land_top, down=land_down, height=land_height, base=2.0)
    if ring_at > 0:
        ring(prefix + "_Argola", x + fx * (lip + ring_at), ring_y, z + fz * (lip + ring_at), yaw, ring_radius)
    # área livre do kicker até 20 m depois do pouso (para frear ou seguir sem bater em nada)
    total = lip + gap + land_top + land_down + 20.0
    cx, cz = x + fx * total * 0.5, z + fz * total * 0.5
    keep.append((cx, cz, total * 0.5 + 6))


# Mapa condensado: vale de ~80 m de raio, atrações perto umas das outras e encadeadas
# (a saída de cada looping já mira um salto). A moto larga em (0, 62) olhando para -Z.
FLOOR_RADIUS, CLIFF_RADIUS, MAP_HALF = 80.0, 100.0, 130.0

# argolas no chão, logo depois da largada (o arco de baixo fica enterrado)
ring("Argola_Largada", 0, 2.75, 48, 0, 3.3)
ring("Argola_Leste", 15, 2.75, 50, 0, 3.3)
ring("Argola_Oeste", -15, 2.75, 50, 0, 3.3)
keep += [(0, 56, 12), (15, 50, 6), (-15, 50, 6)]

# mega rampa no meio, com argola no alto do voo; depois do pouso, costelas iguais às do
# estádio (rampas de ondulação: dá para passar empinado deslizando por cima)
jump_line("Mega", 0, 36, 0, 22, 9, 8, 13.1, 7.0, 4.0, 26.0, 8.0, 11.5, 4.2)
for k in range(8):
    ramp(f"Costela{k + 1}", 0, -38 - k * 3.4, 0, up=1.5, down=1.5, height=0.5, width=8, base=1.2,
         crest=0.7, bump=True)
keep.append((0, -50, 16))
ring("Argola_Ritmo", 0, 2.75, -70, 0, 3.3)

# loopings dos dois lados da mega. Só física natural: a moto sai do looping seguindo reto a
# ~11,5° para a direita (+x) da reta de entrada (medido nas simulações, a toda); o que vem
# depois de cada um está alinhado com essa saída.
EXIT_YAW = -11.5
loop("Looping", -30, 36, 0, 7.5, 8.5)          # sai em x ~ -22 -> salto dos contêineres
keep.append((-26, 36, 14))
loop("LoopingGrande", 26, 38, 0, 9.0, 10.0)    # sai em x ~ 36 -> rampa da mesa
keep.append((31, 38, 16))

# salto sobre contêineres, na linha de saída do looping pequeno
jump_line("Conteiner", -16.0, 4, EXIT_YAW, 8, 3.2, 3, 12.0, 3.0, 2.0, 14.0, 0, 0, 0)

# saltos médios com argola, nas laterais
jump_line("SaltoA", -50, 24, 0, 9, 4.5, 2, 11.1, 4.0, 3.0, 18.0, 7.8, 7.6, 3.6)
jump_line("SaltoB", 14, 22, 0, 9, 4.5, 2, 11.1, 4.0, 3.0, 18.0, 7.8, 7.6, 3.6)  # depois da argola leste

# mesa de pedra: rampa de acesso na linha de saída do looping grande; lá em cima, vira para
# oeste num kicker na beira (decola por cima dos degraus do paredão) e salta pela argola para
# um pouso que desce até o vale
mesa = (54, -58, 12.0, 8.0)
ramp("Mesa_Acesso", 44, -4, EXIT_YAW, up=34, top=4, height=8, width=9, base=6)
ramp("Mesa_Kicker", 47, -58, 90, up=4, height=1.2, width=8, base=1.5, y=8.0)
ring("Argola_Penhasco", 36, 11.0, -58, 90, 3.6, 0.0)
ramp("Mesa_Pouso", 35, -58, 90, top=0.0, down=14, height=7, base=2.0)
keep += [(48, -24, 10), (28, -58, 10), (54, -58, 14)]  # acesso, pouso e o topo da mesa

# contêineres atravessados no caminho do salto "Conteiner": (x, z, giro em graus)
containers = [(-15.1, -15.5, 79), (-9.1, -15.5, 79)]

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
mesas = Array[Vector4]([Vector4({mesa[0]}, {mesa[1]}, {mesa[2]}, {mesa[3]}), Vector4(-66, -48, 10.0, 10.0), Vector4(-64, 52, 9.0, 8.0), Vector4(80, 60, 8.0, 9.0)])
keep_out = PackedVector3Array({keep_text})
container_spots = PackedVector3Array({", ".join(f"{x}, {z}, {r}" for x, z, r in containers)})
terrain_material = ExtResource("desert_terrain")

[node name="Features" type="Node3D" parent="."]

[node name="Ramps" type="Node3D" parent="Features"]

[node name="Loops" type="Node3D" parent="Features"]

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
