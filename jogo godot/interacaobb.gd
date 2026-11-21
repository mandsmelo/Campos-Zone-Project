extends Area2D

enum Estado {
	CHEIO,
	BEBENDO_PRIMEIRA,
	METADE,
	BEBENDO_SEGUNDA,
	VAZIO
}

@export_group("Referências")
@export var player: CharacterBody2D
@export var sprite_bebedouro: AnimatedSprite2D

@export_group("Interação")
@export var acao_interagir: StringName = &"interagir"

# Todos os quadros devem estar nesta mesma animação.
@export var nome_animacao: StringName = &"default"

var estado: Estado = Estado.CHEIO
var configurado: bool = false

var quadro_atual: int = 0
var tempo_acumulado: float = 0.0


func _ready() -> void:
	monitoring = true

	if not is_instance_valid(player):
		push_error("Bebedouro: preencha o campo Player.")
		return

	if not is_instance_valid(sprite_bebedouro):
		push_error("Bebedouro: preencha o campo Sprite Bebedouro.")
		return

	if not player.has_method("recuperar_vida"):
		push_error("Adicione recuperar_vida() ao script do player.")
		return

	if not InputMap.has_action(acao_interagir):
		push_error("Crie a ação 'interagir' no Mapa de Entrada.")
		return

	var animacoes := sprite_bebedouro.sprite_frames

	if animacoes == null:
		push_error("O bebedouro está sem SpriteFrames.")
		return

	if not animacoes.has_animation(nome_animacao):
		push_error("Confira o nome da animação do bebedouro.")
		return

	# Índices 0 a 16: são necessários 17 quadros.
	if animacoes.get_frame_count(nome_animacao) < 17:
		push_error("A animação precisa de 17 quadros: 0 até 16.")
		return

	if animacoes.get_animation_speed(nome_animacao) <= 0.0:
		push_error("Defina um FPS maior que zero na animação.")
		return

	sprite_bebedouro.stop()
	sprite_bebedouro.animation = nome_animacao

	estado = Estado.CHEIO
	mostrar_quadro(0)
	configurado = true


func _unhandled_input(event: InputEvent) -> void:
	if not configurado:
		return

	if not event.is_action_pressed(acao_interagir):
		return

	if event.is_echo():
		return

	if not is_instance_valid(player):
		return

	if not overlaps_body(player):
		return

	# Não permite novo uso durante a animação ou sem água.
	if estado != Estado.CHEIO and estado != Estado.METADE:
		return

	# Com a vida cheia, preserva a água.
	var vida := int(player.get("vida_atual"))
	var maxima := int(player.get("vida_maxima"))

	if vida >= maxima:
		return

	if estado == Estado.CHEIO:
		estado = Estado.BEBENDO_PRIMEIRA
		mostrar_quadro(5)
	else:
		estado = Estado.BEBENDO_SEGUNDA
		mostrar_quadro(14)

	tempo_acumulado = 0.0
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not configurado or estado == Estado.VAZIO:
		return

	if not is_instance_valid(sprite_bebedouro):
		return

	var animacoes := sprite_bebedouro.sprite_frames
	var fps := animacoes.get_animation_speed(nome_animacao)
	var escala := absf(sprite_bebedouro.speed_scale)

	if fps <= 0.0 or escala <= 0.0:
		return

	tempo_acumulado += delta

	# Controla os intervalos de quadros manualmente.
	while estado != Estado.VAZIO:
		var duracao_relativa := animacoes.get_frame_duration(
			nome_animacao,
			quadro_atual
		)

		var duracao_quadro := maxf(
			duracao_relativa / (fps * escala),
			0.001
		)

		if tempo_acumulado < duracao_quadro:
			break

		tempo_acumulado -= duracao_quadro
		avancar_quadro()


func avancar_quadro() -> void:
	match estado:
		Estado.CHEIO:
			if quadro_atual >= 4:
				mostrar_quadro(0)
			else:
				mostrar_quadro(quadro_atual + 1)

		Estado.BEBENDO_PRIMEIRA:
			if quadro_atual >= 8:
				recuperar_um_coracao()
				estado = Estado.METADE
				mostrar_quadro(9)
			else:
				mostrar_quadro(quadro_atual + 1)

		Estado.METADE:
			if quadro_atual >= 13:
				mostrar_quadro(9)
			else:
				mostrar_quadro(quadro_atual + 1)

		Estado.BEBENDO_SEGUNDA:
			if quadro_atual >= 16:
				recuperar_um_coracao()
				estado = Estado.VAZIO
				mostrar_quadro(16)
				tempo_acumulado = 0.0
			else:
				mostrar_quadro(quadro_atual + 1)

		Estado.VAZIO:
			mostrar_quadro(16)


func mostrar_quadro(indice: int) -> void:
	quadro_atual = indice
	sprite_bebedouro.frame = indice


func recuperar_um_coracao() -> void:
	if is_instance_valid(player):
		player.call("recuperar_vida", 1)
