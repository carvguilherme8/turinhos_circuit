@tool
extends Node3D
## Argola de fogo em pé: aro de metal (bater nele derruba), chamas em volta e luz alaranjada.
## Passar pelo meio (andando para -Z ou +Z) emite `passed`. Fica de pé em +Y, com o furo no
## eixo Z; a base do aro fica `radius` abaixo do centro (a origem é o centro do furo).

## Uma moto passou pelo meio da argola.
signal passed(bike: Node)

@export var radius: float = 3.6:
	set(value):
		radius = value
		_queue_rebuild()
@export var tube: float = 0.35
@export var segments: int = 24
## Pé da argola até o chão (0 = sem pé, argola solta no ar sobre um vão).
@export var stand_height: float = 0.0:
	set(value):
		stand_height = value
		_queue_rebuild()
@export var flame_amount: int = 220
@export var metal_color: Color = Color(0.22, 0.22, 0.24)

var _generated: Node3D
var _rebuild_queued := false
var _light: OmniLight3D
var _cooldown := {}
var _time := 0.0


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

	var metal := StandardMaterial3D.new()
	metal.albedo_color = metal_color
	metal.metallic = 0.6
	metal.roughness = 0.5
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.45, 0.1)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.4, 0.05)
	glow.emission_energy_multiplier = 2.0

	# Aro em blocos (com colisão), com uma faixa incandescente por dentro.
	var body := StaticBody3D.new()
	body.name = "RingBody"
	_generated.add_child(body)
	var seg_len := TAU * radius / segments * 1.08
	for i in segments:
		var a := TAU * i / segments
		var center := Vector3(cos(a), sin(a), 0.0) * radius
		var basis := Basis(Vector3.BACK, a)
		var block := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(tube * 2.0, seg_len, tube * 2.0)
		box.material = metal
		block.mesh = box
		block.transform = Transform3D(basis, center)
		_generated.add_child(block)
		var hot := MeshInstance3D.new()
		var strip := BoxMesh.new()
		strip.size = Vector3(0.12, seg_len, tube * 1.4)
		strip.material = glow
		hot.mesh = strip
		hot.transform = Transform3D(basis, center - Vector3(cos(a), sin(a), 0.0) * (tube + 0.04))
		_generated.add_child(hot)
		var shape := CollisionShape3D.new()
		var collider := BoxShape3D.new()
		collider.size = box.size
		shape.shape = collider
		shape.transform = block.transform
		body.add_child(shape)

	# Pé até o chão.
	if stand_height > 0.0:
		for side: float in [-1.0, 1.0]:
			var leg := MeshInstance3D.new()
			var box := BoxMesh.new()
			var h := stand_height + 0.3
			box.size = Vector3(0.35, h, 0.35)
			box.material = metal
			leg.mesh = box
			leg.position = Vector3(side * radius * 0.55, -radius * 0.83 - h * 0.5, 0.0)
			_generated.add_child(leg)
			var shape := CollisionShape3D.new()
			var collider := BoxShape3D.new()
			collider.size = box.size
			shape.shape = collider
			shape.position = leg.position
			body.add_child(shape)

	# Chamas: partículas saindo do aro inteiro, subindo e mudando de amarelo para vermelho.
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process.emission_ring_axis = Vector3(0, 0, 1)
	process.emission_ring_radius = radius + tube * 0.6
	process.emission_ring_inner_radius = radius - tube * 0.6
	process.emission_ring_height = tube * 1.5
	process.direction = Vector3(0, 1, 0)
	process.spread = 25.0
	process.initial_velocity_min = 0.6
	process.initial_velocity_max = 1.8
	process.gravity = Vector3(0, 2.5, 0)
	process.scale_min = 0.5
	process.scale_max = 1.2
	var fade := Curve.new()
	fade.add_point(Vector2(0.0, 0.6))
	fade.add_point(Vector2(0.3, 1.0))
	fade.add_point(Vector2(1.0, 0.0))
	var fade_texture := CurveTexture.new()
	fade_texture.curve = fade
	process.scale_curve = fade_texture
	var colors := Gradient.new()
	colors.set_color(0, Color(1.0, 0.92, 0.45))
	colors.set_color(1, Color(0.9, 0.18, 0.05))
	colors.add_point(0.45, Color(1.0, 0.55, 0.12))
	var color_texture := GradientTexture1D.new()
	color_texture.gradient = colors
	process.color_ramp = color_texture
	var flame_material := StandardMaterial3D.new()
	flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_material.vertex_color_use_as_albedo = true
	flame_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flame_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.55)
	quad.material = flame_material
	var flames := GPUParticles3D.new()
	flames.name = "Flames"
	flames.amount = flame_amount
	flames.lifetime = 0.7
	flames.process_material = process
	flames.draw_pass_1 = quad
	flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flames.visibility_aabb = AABB(Vector3(-radius - 2, -radius - 2, -2), Vector3(radius * 2 + 4, radius * 2 + 6, 4))
	_generated.add_child(flames)

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.2)
	_light.light_energy = 2.0
	_light.omni_range = radius * 3.0
	_generated.add_child(_light)

	# Detector no meio do furo (só motos: camada 3).
	var area := Area3D.new()
	area.name = "Hole"
	area.collision_layer = 0
	area.collision_mask = 1 << 2
	area.monitorable = false
	var hole := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius - tube - 0.2
	cylinder.height = 0.8
	hole.shape = cylinder
	hole.rotation.x = PI * 0.5  # eixo do cilindro ao longo de Z
	area.add_child(hole)
	_generated.add_child(area)
	if not Engine.is_editor_hint():
		area.body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	if _light:
		_light.light_energy = 1.8 + 0.5 * sin(_time * 13.0) + 0.3 * sin(_time * 29.0)


func _on_body_entered(body: Node) -> void:
	if not body.has_method("is_grounded"):
		return
	var now := Time.get_ticks_msec()
	if now - int(_cooldown.get(body.get_instance_id(), -100000)) < 1500:
		return
	_cooldown[body.get_instance_id()] = now
	passed.emit(body)
