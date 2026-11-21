extends AnimatedSprite2D

@export var nome_animacao: StringName = &"default"
@export var stamina_maxima: float = 100.0
@export var stamina_atual: float = 100.0
@export var intervalo_alerta: float = 0.25

var tempo_alerta: float = 0.0
var alternar_alerta: bool = false
var configurado: bool = false


func _ready() -> void:
	stop()

	if sprite_frames == null:
		push_error("Stamina: adicione as imagens em SpriteFrames.")
		return

	if not sprite_frames.has_animation(nome_animacao):
		push_error("Stamina: confira o nome da animação.")
		return

	if sprite_frames.get_frame_count(nome_animacao) < 23:
		push_error("Stamina: precisa dos quadros 0 até 22.")
		return

	animation = nome_animacao
	configurado = true
	atualizar_quadro()


func _process(delta: float) -> void:
	if not configurado:
		return

	if stamina_atual <= 0.0:
		tempo_alerta += delta

		if tempo_alerta >= maxf(intervalo_alerta, 0.05):
			tempo_alerta = 0.0
			alternar_alerta = not alternar_alerta
	else:
		tempo_alerta = 0.0
		alternar_alerta = false

	atualizar_quadro()


func definir_stamina(atual: float, maxima: float) -> void:
	stamina_maxima = maxf(maxima, 0.001)
	stamina_atual = clampf(atual, 0.0, stamina_maxima)

	if configurado:
		atualizar_quadro()


func atualizar_quadro() -> void:
	if stamina_atual <= 0.0:
		frame = 22 if alternar_alerta else 21
		return

	var proporcao := clampf(
		stamina_atual / maxf(stamina_maxima, 0.001),
		0.0,
		1.0
	)

	frame = clampi(
		int(floor((1.0 - proporcao) * 21.0)),
		0,
		20
	)
