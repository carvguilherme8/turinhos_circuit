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
## No ar, rapidez com que a moto alinha a frente com a direção do salto (sem whip).
@export_range(0.0, 10.0, 0.1) var air_yaw_align: float = 3.0

@export_group("Peso do piloto")
## Wheelie e traseira no alto funcionam como um pêndulo: o comando empurra, a gravidade
## puxa de volta até o ponto de equilíbrio e, depois dele, puxa para o outro lado (a moto vira).
## Força do wheelie (peso para trás + acelerador).
@export_range(0.0, 60.0, 0.5, "suffix:rad/s²") var wheelie_strength: float = 8.0
## Fração da força do wheelie disponível sem acelerar (o resto vem do acelerador).
@export_range(0.0, 1.0, 0.05) var wheelie_without_throttle: float = 0.5
## Ângulo em que a moto empinada se equilibra sozinha; passou disso, ela tende a virar.
@export_range(10.0, 80.0, 1.0, "suffix:°") var wheelie_balance_angle: float = 50.0
## Freio derruba a frente durante o wheelie (como o freio traseiro de verdade).
@export_range(0.0, 60.0, 0.5, "suffix:rad/s²") var wheelie_brake_strength: float = 10.0
## Força para levantar a traseira (peso para frente); precisa de velocidade.
@export_range(0.0, 60.0, 0.5, "suffix:rad/s²") var stoppie_strength: float = 9.0
## Ângulo de equilíbrio com a traseira no alto.
@export_range(10.0, 80.0, 1.0, "suffix:°") var stoppie_balance_angle: float = 50.0
## Gravidade puxando a moto de volta para as duas rodas (no chão, sem ângulo).
@export_range(0.0, 60.0, 0.5, "suffix:rad/s²") var one_wheel_gravity: float = 6.0
## Amortecimento do movimento numa roda só (maior = mais fácil de equilibrar).
@export_range(0.0, 10.0, 0.1) var one_wheel_damping: float = 3.0
## Passou deste ângulo empinado (no chão), a moto vira para trás: queda.
@export_range(30.0, 90.0, 1.0, "suffix:°") var wheelie_crash_angle: float = 75.0
## Passou deste ângulo com a traseira no alto, a moto capota para frente: queda.
@export_range(20.0, 90.0, 1.0, "suffix:°") var stoppie_crash_angle: float = 55.0
## Velocidade de giro (pitch) no ar com o analógico/seta no máximo.
@export_range(0.5, 10.0, 0.1, "suffix:rad/s") var air_pitch_rate: float = 3.5
## Segurando o comando no ar, o giro acelera até esta velocidade (mortais).
@export_range(0.5, 20.0, 0.1, "suffix:rad/s") var air_flip_rate: float = 10.0
## Tempo segurando até chegar à velocidade do mortal (toques curtos giram devagar).
@export_range(0.05, 2.0, 0.05, "suffix:s") var air_flip_spinup: float = 0.3
## Rapidez com que o giro no ar responde ao comando.
@export_range(0.5, 20.0, 0.5) var air_pitch_response: float = 8.0
## Ao soltar o comando com a moto girando rápido, o giro freia com esta força (desistir
## de um mortal no meio fica controlável). Giro lento usa o assistente normal.
@export_range(0.5, 20.0, 0.5) var air_release_brake: float = 6.0
## Giro mínimo para contar uma volta completa (mortal) ao pousar.
@export_range(180.0, 360.0, 5.0, "suffix:°") var flip_min_degrees: float = 300.0
## Assistente: numa roda só (cristas, costelas), sem comando, alinha a moto com o chão.
@export_range(0.0, 10.0, 0.1) var one_wheel_pitch_assist: float = 3.0
## Assistente: no ar, sem comando, o nariz acompanha a trajetória (0 = desligado).
@export_range(0.0, 10.0, 0.1) var air_pitch_assist: float = 1.0
## Whip: quanto a moto deita de lado no ar.
@export_range(0.0, 80.0, 1.0, "suffix:°") var whip_roll_angle: float = 55.0
## Whip: quanto a traseira é jogada para o lado no ar.
@export_range(0.0, 60.0, 1.0, "suffix:°") var whip_yaw_angle: float = 30.0

@export_group("Costelas (deslizar)")
## Empinado acima disso e rápido o bastante, a moto desliza sobre ondulações (costelas):
## a frente fica no alto e o corpo segue a média do terreno, não onda a onda.
@export_range(0.0, 30.0, 0.5, "suffix:°") var skim_min_wheelie_degrees: float = 4.0
@export_range(0.0, 30.0, 0.5, "suffix:m/s") var skim_min_speed: float = 7.0
## Quanto o movimento vertical é amortecido ao deslizar (maior = mais "flutuante").
@export_range(0.0, 30.0, 0.5) var skim_vertical_damping: float = 5.0
## Força que segura o ângulo da moto pela média do terreno ao deslizar.
@export_range(0.0, 20.0, 0.5) var skim_pitch_hold: float = 10.0
## Tempo que a roda traseira pode sair do topo de uma onda sem perder tração nem o wheelie.
@export_range(0.0, 1.0, 0.05, "suffix:s") var skim_coyote_time: float = 0.25
## Quanto a suspensão traseira estende ao deslizar, para o corpo passar acima das ondas.
@export_range(0.0, 1.5, 0.05, "suffix:m") var skim_extension: float = 0.45
## Apoio da roda da frente ao deslizar (a frente fica "leve", não solta).
@export_range(0.0, 1.0, 0.05) var skim_front_support: float = 0.6
## Mola e amortecedor da traseira ao deslizar (multiplicadores).
@export_range(0.1, 2.0, 0.05) var skim_spring_scale: float = 1.0
@export_range(0.1, 4.0, 0.05) var skim_damping_scale: float = 1.3

@export_group("Pouso")
## Tempo mínimo no ar para o pouso ser avaliado (ignora pulinhos nas costelas).
@export_range(0.0, 2.0, 0.05, "suffix:s") var min_air_time: float = 0.25
## Até este ângulo entre a moto e o chão, o pouso é perfeito.
@export_range(0.0, 45.0, 1.0, "suffix:°") var good_landing_angle: float = 15.0
## Acima deste ângulo, é queda.
@export_range(10.0, 90.0, 1.0, "suffix:°") var crash_landing_angle: float = 45.0
## Velocidade extra num pouso perfeito.
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var perfect_landing_boost: float = 1.5
## Fração da velocidade que sobra num pouso torto, logo acima do ângulo bom...
@export_range(0.0, 1.0, 0.05) var rough_landing_keep_best: float = 0.85
## ...e logo abaixo do ângulo de queda.
@export_range(0.0, 1.0, 0.05) var rough_landing_keep_worst: float = 0.4
## A carenagem encostando em algo com a moto mais tombada que isso é queda.
@export_range(10.0, 90.0, 1.0, "suffix:°") var crash_tilt_angle: float = 60.0
## Tempo caído antes de voltar para a pista.
@export_range(0.1, 5.0, 0.1, "suffix:s") var respawn_delay: float = 1.0

@export_group("Suspensão")
@export_range(0.1, 1.5, 0.01, "suffix:m") var suspension_rest_length: float = 0.45
@export_range(0.1, 1.0, 0.01, "suffix:m") var wheel_radius: float = 0.375
@export_range(1000.0, 50000.0, 100.0, "suffix:N/m") var spring_stiffness: float = 9000.0
@export_range(0.0, 5000.0, 10.0, "suffix:N·s/m") var spring_damping: float = 1100.0
## Teto de força por roda, evita "estilingue" em pousos muito fortes.
@export_range(1000.0, 50000.0, 100.0, "suffix:N") var max_suspension_force: float = 12000.0
