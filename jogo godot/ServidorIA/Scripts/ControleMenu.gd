extends Node2D

signal jogo_iniciado
signal cooperativo_solicitado
signal continuar_solicitado
signal opcoes_solicitadas

@export_group("Referências")
@export var player: CharacterBody2D
@export var interface_menu: CanvasLayer
@export var sprite_menu: AnimatedSprite2D
@export var interface_jogo: CanvasLayer

@export_group("Menu")
@export var nome_animacao_menu: StringName = &"default"

# 0 = nenhuma opção selecionada.
@export_range(0, 4, 1) var selecao_inicial: int = 0

@export_group("Movimento de apresentação")
@export var movimentar_personagem: bool = true
@export var raio_movimento: float = 120.0
@export var duracao_minima_acao: float = 0.8
@export var duracao_maxima_acao: float = 2.2

enum Acao {
	PARADO,
	ANDANDO,
	CORRENDO,
	RASTEJANDO,
	GIRANDO,
	PULANDO
}

var menu_aberto: bool = true
var configurado: bool = false
var selecao: int = 0

var acao_atual: Acao = Acao.PARADO
var direcao_atual: Vector2 = Vector2.DOWN
var origem_movimento: Vector2

var tempo_acao: float = 0.0
var tempo_giro: float = 0.0

var direcoes: Array[Vector2] = [
	Vector2.RIGHT,
	Vector2.DOWN,
	Vector2.LEFT,
	Vector2.UP
]


func _ready() -> void:
	if not is_instance_valid(player):
		push_error("Menu: preencha o campo Player.")
		return

	if not is_instance_valid(interface_menu):
		push_error("Menu: preencha Interface Menu.")
		return

	if not is_instance_valid(sprite_menu):
		push_error("Menu: preencha Sprite Menu.")
		return

	if sprite_menu.sprite_frames == null:
		push_error("Menu: o sprite está sem SpriteFrames.")
		return

	if not sprite_menu.sprite_frames.has_animation(
		nome_animacao_menu
	):
		push_error("Menu: confira o nome da animação.")
		return

	if sprite_menu.sprite_frames.get_frame_count(
		nome_animacao_menu
	) < 5:
		push_error("Menu: precisa dos frames 0 até 4.")
		return

	var metodos: Array[StringName] = [
		&"animacao_parado",
		&"animacao_andando",
		&"animacao_rastejando",
		&"atualizar_colisor",
		&"pular"
	]

	for metodo in metodos:
		if not player.has_method(metodo):
			push_error(
				"Menu: falta no player a função " + str(metodo)
			)
			return

	origem_movimento = player.global_position

	# Enquanto o menu estiver aberto, este script conduz o player.
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO

	interface_menu.layer = 10
	interface_menu.follow_viewport_enabled = false
	interface_menu.show()
	sprite_menu.show()

	if is_instance_valid(interface_jogo):
		interface_jogo.hide()

	sprite_menu.stop()
	sprite_menu.animation = nome_animacao_menu

	selecao = selecao_inicial
	atualizar_selecao()

	configurado = true
	player.call("animacao_parado")


func _physics_process(delta: float) -> void:
	if not configurado or not menu_aberto:
		return

	if not is_instance_valid(player):
		return

	if Input.is_action_just_pressed("ui_down"):
		mudar_selecao(1)

	elif Input.is_action_just_pressed("ui_up"):
		mudar_selecao(-1)

	if Input.is_action_just_pressed("ui_accept"):
		confirmar_selecao()

		if not menu_aberto:
			return

	if movimentar_personagem:
		atualizar_apresentacao(delta)


func mudar_selecao(sentido: int) -> void:
	if selecao == 0:
		selecao = 1 if sentido > 0 else 4
	else:
		selecao = wrapi(
			selecao - 1 + sentido,
			0,
			4
		) + 1

	atualizar_selecao()


func atualizar_selecao() -> void:
	sprite_menu.frame = selecao


func confirmar_selecao() -> void:
	match selecao:
		0:
			# Sem seleção, confirmar destaca Iniciar.
			selecao = 1
			atualizar_selecao()

		1:
			Cooperativo.definir_modo(false)
			iniciar_jogo()

		2:
			cooperativo_solicitado.emit()
			if Cooperativo.definir_modo(true):
				iniciar_jogo()

		3:
			continuar_solicitado.emit()
			print("Continuar: ainda não existe salvamento.")

		4:
			opcoes_solicitadas.emit()
			print("Opções: o painel será criado depois.")


func iniciar_jogo() -> void:
	if not menu_aberto:
		return

	if not is_instance_valid(player):
		push_error("Menu: o Player não está configurado.")
		return

	# Interrompe os movimentos automáticos.
	menu_aberto = false
	tempo_acao = 0.0
	acao_atual = Acao.PARADO

	# Esconde o menu.
	interface_menu.hide()

	# Prepara o personagem.
	player.velocity = Vector2.ZERO
	player.set("estado_movimento", &"parado")
	player.call("atualizar_colisor", false)
	player.call("animacao_parado")

	# Libera o controle pelo script normal do player.
	player.set_physics_process(true)

	# Mostra a interface de vida, stamina e bateria.
	if is_instance_valid(interface_jogo):
		interface_jogo.show()

	# Depois usaremos este sinal para a cutscene.
	jogo_iniciado.emit()


func atualizar_apresentacao(delta: float) -> void:
	tempo_acao -= delta

	if tempo_acao <= 0.0:
		escolher_acao()

	player.velocity = Vector2.ZERO

	match acao_atual:
		Acao.PARADO:
			player.set("estado_movimento", &"parado")
			player.call("animacao_parado")

		Acao.GIRANDO:
			player.set("estado_movimento", &"parado")
			tempo_giro -= delta

			if tempo_giro <= 0.0:
				tempo_giro = 0.35

				direcao_atual = direcao_atual.rotated(
					PI / 2.0
				)

				player.set("ultima_direcao", direcao_atual)
				player.call("animacao_parado")

		Acao.PULANDO:
			player.set("estado_movimento", &"parado")
			player.call("animacao_parado")

		_:
			mover_personagem(delta)


func escolher_acao() -> void:
	var minima := maxf(duracao_minima_acao, 0.2)
	var maxima := maxf(duracao_maxima_acao, minima)

	tempo_acao = randf_range(minima, maxima)
	tempo_giro = 0.0

	direcao_atual = direcoes[
		randi_range(0, direcoes.size() - 1)
	]

	player.call("atualizar_colisor", false)

	var sorteio := randi_range(0, 9)

	match sorteio:
		0, 1:
			acao_atual = Acao.PARADO

		2, 3, 4, 5:
			acao_atual = Acao.ANDANDO

		6:
			acao_atual = Acao.CORRENDO

		7:
			acao_atual = Acao.RASTEJANDO

		8:
			acao_atual = Acao.GIRANDO

		9:
			acao_atual = Acao.PULANDO
			player.call("pular")

			tempo_acao = maxf(
				tempo_acao,
				float(player.get("duracao_pulo")) + 0.1
			)

	# Ao se afastar, tenta voltar à posição inicial.
	if player.global_position.distance_to(
		origem_movimento
	) > maxf(raio_movimento, 1.0):
		acao_atual = Acao.ANDANDO

		direcao_atual = player.global_position.direction_to(
			origem_movimento
		)


func mover_personagem(delta: float) -> void:
	var velocidade_acao := float(player.get("velocidade"))
	var rastejando := acao_atual == Acao.RASTEJANDO

	if bool(player.get("pulando")):
		rastejando = false

	player.set("ultima_direcao", direcao_atual)

	if rastejando:
		velocidade_acao = float(
			player.get("velocidade_rastejando")
		)

		player.set("estado_movimento", &"rastejando")
		player.call("animacao_rastejando", direcao_atual)

	elif acao_atual == Acao.CORRENDO:
		velocidade_acao = float(
			player.get("velocidade_correndo")
		)

		player.set("estado_movimento", &"correndo")
		player.call("animacao_andando", direcao_atual, true)

	else:
		player.set("estado_movimento", &"andando")
		player.call("animacao_andando", direcao_atual, false)

	var rastejando_lateral := (
		rastejando
		and absf(direcao_atual.x) > absf(direcao_atual.y)
	)

	player.call("atualizar_colisor", rastejando_lateral)
	player.velocity = direcao_atual * velocidade_acao

	var posicao_anterior := player.global_position
	player.move_and_slide()

	var distancia_andada := player.global_position.distance_to(
		posicao_anterior
	)

	# Se ficar bloqueado, faz uma pausa.
	if distancia_andada < velocidade_acao * delta * 0.1:
		acao_atual = Acao.PARADO
		tempo_acao = 0.5

		player.velocity = Vector2.ZERO
		player.set("estado_movimento", &"parado")
		player.call("animacao_parado")
