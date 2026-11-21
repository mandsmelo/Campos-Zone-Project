extends Node

signal esbarrou_no_estande

@export_group("Referências")
@export var estudante: Node2D
@export var sprite_estudante: AnimatedSprite2D
@export var player: CharacterBody2D
@export var caixa_dialogo: Control

@export_group("Pontos do caminho")
@export var saida_sala: Marker2D
@export var ponto_aviso: Marker2D
@export var ponto_esbarrao: Marker2D

@export_group("Movimento")
@export var velocidade: float = 90.0
@export var distancia_chegada: float = 2.0
@export var tempo_maximo_travada: float = 2.0

@export_group("Animações")
@export var animacao_frente: StringName = &"andando frente"
@export var animacao_lado: StringName = &"andandolado"
@export var animacao_parada: StringName = &"parado"
@export var sprite_original_olha_direita: bool = true
@export var velocidade_animacao_correndo: float = 1.5

enum Etapa {
	INATIVA,
	SAINDO,
	INDO_AVISAR,
	CONVERSANDO,
	INDO_ESTANDE,
	FINALIZADA
}

var etapa: Etapa = Etapa.INATIVA
var configurado: bool = false
var tempo_travada: float = 0.0
var ultima_direcao: Vector2 = Vector2.DOWN


func _ready() -> void:
	if not is_instance_valid(estudante):
		push_error("EntradaEstudante: preencha o campo Estudante.")
		return

	if not is_instance_valid(sprite_estudante):
		push_error("EntradaEstudante: preencha Sprite Estudante.")
		return

	if not is_instance_valid(player):
		push_error("EntradaEstudante: preencha Player.")
		return

	if not is_instance_valid(caixa_dialogo):
		push_error("EntradaEstudante: preencha Caixa Dialogo.")
		return

	if not caixa_dialogo.has_method("iniciar_dialogo"):
		push_error("EntradaEstudante: a caixa precisa de iniciar_dialogo().")
		return

	if not caixa_dialogo.has_signal("dialogo_finalizado"):
		push_error("EntradaEstudante: falta o sinal dialogo_finalizado.")
		return

	if (
		not is_instance_valid(saida_sala)
		or not is_instance_valid(ponto_aviso)
		or not is_instance_valid(ponto_esbarrao)
	):
		push_error("EntradaEstudante: preencha os três pontos do caminho.")
		return

	if sprite_estudante.sprite_frames == null:
		push_error("EntradaEstudante: o sprite está sem SpriteFrames.")
		return

	for nome in [
		animacao_frente,
		animacao_lado,
		animacao_parada
	]:
		if not sprite_estudante.sprite_frames.has_animation(nome):
			push_error(
				"EntradaEstudante: animação não encontrada: %s" % nome
			)
			return

	caixa_dialogo.connect(
		"dialogo_finalizado",
		Callable(self, "_ao_finalizar_dialogo")
	)

	configurado = true
	parar_estudante()


func iniciar_entrada() -> void:
	if not configurado:
		push_error("Confira os campos do nó EntradaEstudante.")
		return

	if etapa != Etapa.INATIVA:
		return

	# Mantém o jogador na cutscene.
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	player.set("estado_movimento", &"parado")

	if player.has_method("animacao_parado"):
		player.call("animacao_parado")

	estudante.show()
	tempo_travada = 0.0
	etapa = Etapa.SAINDO


func _physics_process(delta: float) -> void:
	match etapa:
		Etapa.SAINDO:
			if caminhar_ate(saida_sala.global_position, delta):
				etapa = Etapa.INDO_AVISAR

		Etapa.INDO_AVISAR:
			if caminhar_ate(ponto_aviso.global_position, delta):
				iniciar_aviso()

		Etapa.INDO_ESTANDE:
			if caminhar_ate(ponto_esbarrao.global_position, delta):
				esbarrar()


func caminhar_ate(destino: Vector2, delta: float) -> bool:
	var deslocamento := destino - estudante.global_position
	var distancia := deslocamento.length()

	if distancia <= maxf(distancia_chegada, 0.1):
		parar_estudante()
		tempo_travada = 0.0
		return true

	var direcao := deslocamento.normalized()
	ultima_direcao = direcao

	var velocidade_atual := minf(
		maxf(velocidade, 1.0),
		distancia / maxf(delta, 0.001)
	)

	animar_movimento(direcao)

	var posicao_anterior := estudante.global_position
	var corpo := estudante as CharacterBody2D

	if corpo != null:
		corpo.velocity = direcao * velocidade_atual
		corpo.move_and_slide()
	else:
		estudante.global_position = estudante.global_position.move_toward(
			destino,
			velocidade_atual * delta
		)

	var distancia_movida := estudante.global_position.distance_to(
		posicao_anterior
	)

	if distancia_movida < velocidade_atual * delta * 0.1:
		tempo_travada += delta
	else:
		tempo_travada = 0.0

	if tempo_travada >= maxf(tempo_maximo_travada, 0.2):
		interromper_por_bloqueio()

	return false


func iniciar_aviso() -> void:
	etapa = Etapa.CONVERSANDO
	parar_estudante()

	# Faz a estudante olhar para o jogador enquanto fala.
	var direcao := estudante.global_position.direction_to(
		player.global_position
	)

	if absf(direcao.x) > absf(direcao.y):
		definir_lado(direcao.x)

	var falas: Array[Dictionary] = [
		{
			"nome": "ESTUDANTE",
			"texto": "Coordenador! Tem gente passando mal na Enfermagem!",
			"tipo": 0
		},
		{
			"nome": "COORDENADOR",
			"texto": "Calma. O que aconteceu?",
			"tipo": 0
		},
		{
			"nome": "ESTUDANTE",
			"texto": "Eles começaram a atacar os outros! Estão vindo!",
			"tipo": 0
		},
		{
			"nome": "COORDENADOR",
			"texto": "Venha para cá! Cuidado com o estande!",
			"tipo": 0
		}
	]

	caixa_dialogo.call("iniciar_dialogo", falas)


func _ao_finalizar_dialogo() -> void:
	if etapa != Etapa.CONVERSANDO:
		return

	# A conversa terminou, mas a cutscene continua.
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO

	tempo_travada = 0.0
	etapa = Etapa.INDO_ESTANDE


func esbarrar() -> void:
	etapa = Etapa.FINALIZADA
	parar_estudante()

	esbarrou_no_estande.emit()

	# Por enquanto, devolve o controle.
	# Na próxima etapa, a explosão começará aqui.
	player.velocity = Vector2.ZERO
	player.set_physics_process(true)


func animar_movimento(direcao: Vector2) -> void:
	sprite_estudante.speed_scale = velocidade_animacao_correndo

	if absf(direcao.x) > absf(direcao.y):
		definir_lado(direcao.x)
		tocar(animacao_lado)
	else:
		# A estudante possui apenas frente e lado.
		sprite_estudante.flip_h = false
		tocar(animacao_frente)


func definir_lado(direcao_x: float) -> void:
	if sprite_original_olha_direita:
		sprite_estudante.flip_h = direcao_x < 0.0
	else:
		sprite_estudante.flip_h = direcao_x > 0.0


func parar_estudante() -> void:
	var corpo := estudante as CharacterBody2D

	if corpo != null:
		corpo.velocity = Vector2.ZERO

	sprite_estudante.speed_scale = 1.0
	tocar(animacao_parada)


func tocar(nome: StringName) -> void:
	if sprite_estudante.animation != nome:
		sprite_estudante.play(nome)
	elif not sprite_estudante.is_playing():
		sprite_estudante.play()


func interromper_por_bloqueio() -> void:
	etapa = Etapa.FINALIZADA
	parar_estudante()

	player.velocity = Vector2.ZERO
	player.set_physics_process(true)

	push_warning(
		"A estudante encontrou um obstáculo. Ajuste os pontos do caminho."
	)
