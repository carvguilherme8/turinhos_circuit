class_name BikeStats
extends Resource
## Parâmetros ajustáveis da moto. Para criar outra moto, duplique o .tres e mude os valores.
## Velocidades em m/s (x3,6 = km/h), acelerações em m/s², taxas de giro em rad/s.

@export_group("Corpo")
@export_range(50.0, 400.0, 1.0, "suffix:kg") var mass: float = 150.0
## Centro de massa em relação à origem da moto. Mais baixo = mais estável.
@export var center_of_mass: Vector3 = Vector3(0.0, -0.25, 0.0)
## Gravidade extra para saltos com sensação "pesada".
@export_range(0.5, 3.0, 0.05) var gravity_scale: float = 1.6

@export_group("Motor e freio")
@export_range(1.0, 60.0, 0.5, "suffix:m/s²") var acceleration: float = 14.0
@export_range(1.0, 60.0, 0.5, "suffix:m/s") var max_speed: float = 24.0
@export_range(1.0, 60.0, 0.5, "suffix:m/s²") var brake_deceleration: float = 20.0
@export_range(1.0, 20.0, 0.5, "suffix:m/s") var reverse_max_speed: float = 5.0
@export_range(1.0, 30.0, 0.5, "suffix:m/s²") var reverse_acceleration: float = 6.0
## Desaceleração natural quando nada é pressionado.
@export_range(0.0, 10.0, 0.1, "suffix:m/s²") var coast_deceleration: float = 2.5

@export_group("Direção")
@export_range(0.0, 6.0, 0.05, "suffix:rad/s") var steer_rate: float = 2.2
## Abaixo desta velocidade a direção fica proporcional (parada, a moto não gira no lugar).
@export_range(0.1, 20.0, 0.1, "suffix:m/s") var full_steer_speed: float = 5.0
## Fração da direção que sobra na velocidade máxima (curvas mais abertas em alta).
@export_range(0.1, 1.0, 0.05) var high_speed_steer_factor: float = 0.55
## Rapidez com que a moto responde ao volante.
@export_range(1.0, 30.0, 0.5) var steer_response: float = 10.0
## Aderência lateral: quanto da derrapagem é corrigida por segundo.
@export_range(0.0, 30.0, 0.5) var grip: float = 12.0
## Inclinação visual nas curvas (só o desenho; a física continua em pé).
@export_range(0.0, 45.0, 1.0, "suffix:°") var visual_lean_degrees: float = 25.0

@export_group("Freio de mão")
## Fração da aderência lateral que sobra com o freio de mão puxado (menor = derrapa mais).
@export_range(0.0, 1.0, 0.01) var handbrake_grip_factor: float = 0.12
## Quanto o freio de mão segura a moto (a roda traseira travada arrastando na terra).
@export_range(0.0, 30.0, 0.5, "suffix:m/s²") var handbrake_deceleration: float = 7.0
## Multiplica a direção durante a derrapagem, para a traseira sair de lado.
@export_range(1.0, 4.0, 0.05) var handbrake_steer_boost: float = 1.5
## Rapidez com que a aderência volta ao soltar o freio de mão (menor = escorrega por mais tempo).
@export_range(0.5, 20.0, 0.1) var drift_recovery: float = 2.5
## Ângulo máximo de derrapagem: a direção não gira a moto além disso (evita rodar no lugar).
@export_range(10.0, 90.0, 1.0, "suffix:°") var max_drift_angle: float = 50.0

@export_group("Equilíbrio")
## Força com que a moto volta a ficar em pé no eixo de rolagem.
@export_range(0.0, 30.0, 0.5) var roll_stiffness: float = 10.0
## Amortecimento do giro (guinada) no ar, para a moto não rodopiar.
@export_range(0.0, 10.0, 0.1) var air_yaw_damping: float = 2.0

@export_group("Suspensão")
@export_range(0.1, 1.5, 0.01, "suffix:m") var suspension_rest_length: float = 0.45
@export_range(0.1, 1.0, 0.01, "suffix:m") var wheel_radius: float = 0.375
@export_range(1000.0, 50000.0, 100.0, "suffix:N/m") var spring_stiffness: float = 9000.0
@export_range(0.0, 5000.0, 10.0, "suffix:N·s/m") var spring_damping: float = 1100.0
## Teto de força por roda, evita "estilingue" em pousos muito fortes.
@export_range(1000.0, 50000.0, 100.0, "suffix:N") var max_suspension_force: float = 12000.0
