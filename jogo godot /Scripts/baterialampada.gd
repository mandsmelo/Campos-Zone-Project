extends AnimatedSprite2D

@export var nome_animacao: StringName = &"default"
@export var bateria_maxima: float = 100.0
@export var bateria_atual: float = 100.0
@export var intervalo_alerta: float = 0.25

var tempo_alerta: float = 0.0
var alternar_alerta: bool = false
var configurado: bool = false


func _ready() -> void:
	stop()

	if sprite_frames == null:
		push_error("Bateria: adicione as imagens em SpriteFrames.")
		return

	if not sprite_frames.has_animation(nome_animacao):
		push_error("Bateria: confira o nome da animação.")
		return

	if sprite_frames.get_frame_count(nome_animacao) < 22:
		push_error("Bateria: precisa dos quadros 0 até 22.")
		return

	animation = nome_animacao
	configurado = true
	atualizar_quadro()


func _process(delta: float) -> void:
	if not configurado:
		return

	if bateria_atual <= 0.0:
		tempo_alerta += delta

		if tempo_alerta >= maxf(intervalo_alerta, 0.05):
			tempo_alerta = 0.0
			alternar_alerta = not alternar_alerta
	else:
		tempo_alerta = 0.0
		alternar_alerta = false

	atualizar_quadro()


func definir_bateria(atual: float, maxima: float) -> void:
	bateria_maxima = maxf(maxima, 0.001)
	bateria_atual = clampf(atual, 0.0, bateria_maxima)

	if configurado:
		atualizar_quadro()


func atualizar_quadro() -> void:
	if bateria_atual <= 0.0:
		frame = 21 if alternar_alerta else 20
		return

	var proporcao := clampf(
		bateria_atual / maxf(bateria_maxima, 0.001),
		0.0,
		1.0
	)

	frame = clampi(
		int(floor((1.0 - proporcao) * 21.0)),
		0,
		20
	)
