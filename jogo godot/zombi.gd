extends CharacterBody2D

@export var player: CharacterBody2D
@export var velocidade: float = 70.0

@export_group("Detecção")
@export var alcance_parado: float = 30.0
@export var alcance_rastejando: float = 70.0
@export var alcance_andando: float = 150.0
@export var alcance_correndo: float = 250.0
@export var distancia_perder_player: float = 350.0

@export_group("Esconderijo atrás das mesas")
@export var usar_esconderijo_mesas: bool = true
@export var acao_rastejar: StringName = &"rastejar"

# Somente a camada das Area2D que cobrem as mesas.
# 128 corresponde ao quadradinho 8.
@export_flags_2d_physics var mascara_mesas: int = 128

# Camadas sólidas que impedem uma nova detecção.
# Não inclua a camada exclusiva das áreas das mesas.
@export_flags_2d_physics var mascara_paredes_visao: int = 1

@export_group("Navegação")
@export var intervalo_atualizar_caminho: float = 0.2
@export var distancia_proximo_ponto: float = 4.0

@export_group("Patrulha")
@export var velocidade_patrulha: float = 25.0
@export var distancia_por_passo: float = 40.0
@export var pausa_patrulha: float = 0.5

# Ordem: direita, cima, esquerda e baixo.
# Zero desativa a direção.
@export_range(0, 20, 1) var passos_direita: int = 2
@export_range(0, 20, 1) var passos_cima: int = 2
@export_range(0, 20, 1) var passos_esquerda: int = 2
@export_range(0, 20, 1) var passos_baixo: int = 2

@export_group("Ataque")
@export var distancia_ataque: float = 16.0
@export var margem_contato: float = 2.0
@export var intervalo_ataque: float = 1.0
@export var pausa_apos_ataque: float = 0.4

# Camadas dos obstáculos sólidos.
@export_flags_2d_physics var mascara_obstaculos: int = 1

@export_group("Recuo")
@export var forca_recuo_player: float = 150.0
@export var forca_recuo_zumbi: float = 90.0
@export var duracao_recuo: float = 0.18

@export_group("Destravar")
@export var tempo_para_destravar: float = 1.0
@export var tamanho_quadrado: float = 16.0
@export_range(1, 10, 1) var quadrados_destravar: int = 2
@export var velocidade_destravar: float = 35.0
@export var tempo_maximo_destravar: float = 1.5

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var agente: NavigationAgent2D = $NavigationAgent2D

var detectou_player: bool = false
var morto: bool = false
var ultima_direcao: Vector2 = Vector2.DOWN

var tempo_ate_ataque: float = 0.0
var tempo_pausa: float = 0.0
var tempo_recuo: float = 0.0
var velocidade_recuo: Vector2 = Vector2.ZERO
var tempo_atualizar_caminho: float = 0.0

var direcoes_patrulha: Array[Vector2] = []
var distancias_patrulha: Array[float] = []

var indice_patrulha: int = 0
var distancia_restante: float = 0.0
var tempo_pausa_patrulha: float = 0.0

var tempo_travado: float = 0.0
var destravando: bool = false
var direcao_destravar: Vector2 = Vector2.ZERO
var distancia_destravar_restante: float = 0.0
var tempo_destravando: float = 0.0


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	if player == self:
		push_error("O campo Player deve apontar para o personagem.")
		player = null

	var maior_alcance := maxf(
		maxf(alcance_parado, alcance_rastejando),
		maxf(alcance_andando, alcance_correndo)
	)

	# Evita alternar constantemente entre detectar e desistir.
	distancia_perder_player = maxf(
		distancia_perder_player,
		maior_alcance + 20.0
	)

	agente.path_desired_distance = maxf(
		distancia_proximo_ponto, 0.1
	)
	agente.target_desired_distance = 1.0
	agente.avoidance_enabled = false

	if usar_esconderijo_mesas:
		if mascara_mesas == 0:
			push_warning(
				"Zumbi: selecione a Máscara Mesas no Inspector."
			)

		if not InputMap.has_action(acao_rastejar):
			push_warning(
				"Zumbi: confira a ação de rastejar no Mapa de Entrada."
			)

	configurar_patrulha()
	animacao_parado()


func _physics_process(delta: float) -> void:
	velocity = Vector2.ZERO

	if morto:
		return

	tempo_ate_ataque = maxf(tempo_ate_ataque - delta, 0.0)
	tempo_pausa = maxf(tempo_pausa - delta, 0.0)
	tempo_atualizar_caminho = maxf(
		tempo_atualizar_caminho - delta, 0.0
	)

	# O recuo tem prioridade sobre os outros movimentos.
	if tempo_recuo > 0.0:
		var passo_recuo := minf(delta, tempo_recuo)
		tempo_recuo = maxf(tempo_recuo - delta, 0.0)

		velocity = velocidade_recuo * (passo_recuo / delta)
		move_and_slide()
		return

	if tempo_pausa > 0.0:
		animacao_parado()
		return

	selecionar_alvo_cooperativo()

	var distancia: float = 0.0

	if is_instance_valid(player):
		distancia = global_position.distance_to(
			player.global_position
		)

		var escondido := player_oculto_por_mesa()

		if detectou_player:
			if escondido or distancia > distancia_perder_player:
				perder_player()

		elif (
			not escondido
			and distancia <= obter_alcance_deteccao()
			and not linha_solida_bloqueada(mascara_paredes_visao)
		):
			detectou_player = true
			tempo_travado = 0.0
			tempo_atualizar_caminho = 0.0

	else:
		if detectou_player:
			perder_player()

		cancelar_destravamento()

	if destravando:
		executar_destravamento(delta)
		return

	if detectou_player:
		perseguir_player(distancia, delta)
		return

	tempo_travado = 0.0
	patrulhar(delta)


func player_esta_abaixado() -> bool:
	if not is_instance_valid(player):
		return false

	if player.get("pulando") == true:
		return false

	# Também considera parado segurando o botão de rastejar.
	var acao: StringName = acao_rastejar
	if player.has_method("acao_local"):
		acao = player.call("acao_local", acao_rastejar)
	if InputMap.has_action(acao):
		if Input.is_action_pressed(acao):
			return true

	return player.get("estado_movimento") == &"rastejando"


func player_oculto_por_mesa() -> bool:
	if not usar_esconderijo_mesas:
		return false

	if mascara_mesas == 0 or not player_esta_abaixado():
		return false

	var consulta := PhysicsRayQueryParameters2D.create(
		global_position,
		player.global_position
	)

	consulta.collision_mask = mascara_mesas
	consulta.exclude = [get_rid(), player.get_rid()]

	# Nesta consulta, procura somente as áreas dos tampos.
	consulta.collide_with_areas = true
	consulta.collide_with_bodies = false
	consulta.hit_from_inside = true

	var resultado := get_world_2d().direct_space_state.intersect_ray(
		consulta
	)

	return not resultado.is_empty()


func linha_solida_bloqueada(mascara: int) -> bool:
	if mascara == 0 or not is_instance_valid(player):
		return false

	var consulta := PhysicsRayQueryParameters2D.create(
		global_position,
		player.global_position
	)

	consulta.collision_mask = mascara
	consulta.exclude = [get_rid(), player.get_rid()]

	# Paredes e mesas sólidas; ignora áreas de interação.
	consulta.collide_with_bodies = true
	consulta.collide_with_areas = false
	consulta.hit_from_inside = true

	var resultado := get_world_2d().direct_space_state.intersect_ray(
		consulta
	)

	return not resultado.is_empty()


func perder_player() -> void:
	detectou_player = false
	cancelar_destravamento()
	reiniciar_patrulha()


func configurar_patrulha() -> void:
	direcoes_patrulha.clear()
	distancias_patrulha.clear()

	adicionar_trecho(Vector2.RIGHT, passos_direita)
	adicionar_trecho(Vector2.UP, passos_cima)
	adicionar_trecho(Vector2.LEFT, passos_esquerda)
	adicionar_trecho(Vector2.DOWN, passos_baixo)

	reiniciar_patrulha()


func adicionar_trecho(direcao: Vector2, passos: int) -> void:
	if passos <= 0 or distancia_por_passo <= 0.0:
		return

	direcoes_patrulha.append(direcao)
	distancias_patrulha.append(passos * distancia_por_passo)


func reiniciar_patrulha() -> void:
	indice_patrulha = 0
	tempo_pausa_patrulha = 0.0
	distancia_restante = 0.0

	if not distancias_patrulha.is_empty():
		distancia_restante = distancias_patrulha[0]


func patrulhar(delta: float) -> void:
	if direcoes_patrulha.is_empty() or velocidade_patrulha <= 0.0:
		animacao_parado()
		return

	if tempo_pausa_patrulha > 0.0:
		tempo_pausa_patrulha = maxf(
			tempo_pausa_patrulha - delta, 0.0
		)
		animacao_parado()
		return

	var direcao := direcoes_patrulha[indice_patrulha]
	ultima_direcao = direcao

	velocity = direcao * minf(
		velocidade_patrulha,
		distancia_restante / delta
	)

	animacao_andando(direcao)

	var posicao_anterior := global_position
	move_and_slide()

	var deslocamento := global_position - posicao_anterior

	distancia_restante = maxf(
		distancia_restante - maxf(deslocamento.dot(direcao), 0.0),
		0.0
	)

	if distancia_restante <= 0.1 or is_on_wall():
		indice_patrulha = (
			(indice_patrulha + 1) % direcoes_patrulha.size()
		)

		distancia_restante = distancias_patrulha[indice_patrulha]
		tempo_pausa_patrulha = pausa_patrulha


func perseguir_player(distancia: float, delta: float) -> void:
	if NavigationServer2D.map_get_iteration_id(
		agente.get_navigation_map()
	) == 0:
		tempo_travado = 0.0
		animacao_parado()
		return

	if tempo_atualizar_caminho <= 0.0:
		agente.target_position = player.global_position
		tempo_atualizar_caminho = maxf(
			intervalo_atualizar_caminho, 0.05
		)

	var proximo_ponto := agente.get_next_path_position()
	var alcance_contato := maxf(
		distancia_ataque + margem_contato, 0.1
	)

	if distancia <= alcance_contato + 0.1:
		if caminho_direto_livre():
			tempo_travado = 0.0
			animacao_parado()

			if tempo_ate_ataque <= 0.0:
				atacar()

			return

	if agente.is_navigation_finished():
		tempo_travado = 0.0
		animacao_parado()
		return

	var distancia_ponto := global_position.distance_to(
		proximo_ponto
	)

	if distancia_ponto <= 0.1:
		tempo_travado = 0.0
		animacao_parado()
		return

	var direcao := global_position.direction_to(proximo_ponto)
	ultima_direcao = direcao

	var velocidade_atual := minf(
		maxf(velocidade, 0.0),
		distancia_ponto / delta
	)

	if distancia > alcance_contato:
		if distancia <= alcance_contato + velocidade * delta:
			if caminho_direto_livre():
				velocidade_atual = minf(
					velocidade_atual,
					(distancia - alcance_contato) / delta
				)

	var velocidade_desejada := direcao * velocidade_atual
	velocity = velocidade_desejada
	animacao_andando(direcao)

	var posicao_anterior := global_position
	move_and_slide()

	verificar_travamento(
		posicao_anterior,
		velocidade_desejada,
		delta
	)


func verificar_travamento(
	posicao_anterior: Vector2,
	velocidade_desejada: Vector2,
	delta: float
) -> void:
	var distancia_esperada := velocidade_desejada.length() * delta
	var distancia_real := global_position.distance_to(
		posicao_anterior
	)

	if distancia_esperada <= 0.001:
		tempo_travado = 0.0
		return

	if distancia_real < distancia_esperada * 0.1:
		tempo_travado += delta
	else:
		tempo_travado = 0.0

	if tempo_travado >= maxf(tempo_para_destravar, 0.1):
		tempo_travado = 0.0
		iniciar_destravamento()


func iniciar_destravamento() -> void:
	var frente := ultima_direcao.normalized()

	if frente.is_zero_approx():
		frente = Vector2.DOWN

	var candidatos: Array[Vector2] = [
		frente,
		frente.rotated(PI / 2.0),
		frente.rotated(-PI / 2.0),
		-frente
	]

	var distancia_teste := maxf(tamanho_quadrado * 0.5, 2.0)

	for direcao in candidatos:
		if not test_move(
			global_transform,
			direcao * distancia_teste
		):
			direcao_destravar = direcao
			distancia_destravar_restante = (
				maxf(tamanho_quadrado, 1.0)
				* maxi(quadrados_destravar, 1)
			)
			tempo_destravando = 0.0
			destravando = true
			return

	tempo_atualizar_caminho = 0.0


func executar_destravamento(delta: float) -> void:
	tempo_destravando += delta

	var velocidade_atual := minf(
		maxf(velocidade_destravar, 1.0),
		distancia_destravar_restante / delta
	)

	velocity = direcao_destravar * velocidade_atual
	ultima_direcao = direcao_destravar
	animacao_andando(direcao_destravar)

	var posicao_anterior := global_position
	move_and_slide()

	var distancia_real := global_position.distance_to(
		posicao_anterior
	)

	distancia_destravar_restante = maxf(
		distancia_destravar_restante - distancia_real, 0.0
	)

	if (
		distancia_destravar_restante <= 0.1
		or tempo_destravando >= maxf(tempo_maximo_destravar, 0.1)
		or distancia_real < velocidade_atual * delta * 0.1
	):
		cancelar_destravamento()


func cancelar_destravamento() -> void:
	destravando = false
	tempo_travado = 0.0
	tempo_destravando = 0.0
	distancia_destravar_restante = 0.0
	tempo_atualizar_caminho = 0.0
	velocity = Vector2.ZERO


func caminho_direto_livre() -> bool:
	if player_oculto_por_mesa():
		return false

	return not linha_solida_bloqueada(mascara_obstaculos)


func atacar() -> void:
	if not is_instance_valid(player):
		return

	if player_oculto_por_mesa():
		perder_player()
		return

	if not player.has_method("receber_impacto"):
		push_error("Adicione receber_impacto() ao script do player.")
		tempo_ate_ataque = maxf(intervalo_ataque, 0.1)
		return

	var direcao := global_position.direction_to(
		player.global_position
	)

	if direcao.is_zero_approx():
		direcao = ultima_direcao

	tempo_travado = 0.0
	tempo_ate_ataque = maxf(intervalo_ataque, 0.1)
	tempo_recuo = maxf(duracao_recuo, 0.0)
	tempo_pausa = tempo_recuo + maxf(pausa_apos_ataque, 0.0)

	player.call(
		"receber_impacto",
		direcao,
		forca_recuo_player,
		tempo_recuo
	)

	velocidade_recuo = -direcao * forca_recuo_zumbi
	animacao_parado()


func obter_alcance_deteccao() -> float:
	if player_esta_abaixado():
		return alcance_rastejando

	match player.get("estado_movimento"):
		&"andando":
			return alcance_andando
		&"correndo":
			return alcance_correndo
		_:
			return alcance_parado


func animacao_andando(direcao: Vector2) -> void:
	if absf(direcao.x) > absf(direcao.y):
		sprite.flip_h = direcao.x < 0
		tocar(&"andar_lado")
	elif direcao.y < 0:
		sprite.flip_h = false
		tocar(&"andar_costas")
	else:
		sprite.flip_h = false
		tocar(&"andar_frente")


func animacao_parado() -> void:
	if absf(ultima_direcao.x) > absf(ultima_direcao.y):
		sprite.flip_h = ultima_direcao.x < 0
		tocar(&"idle_lado")
	elif ultima_direcao.y < 0:
		sprite.flip_h = false
		tocar(&"idle_costas")
	else:
		sprite.flip_h = false
		tocar(&"idle_frente")


func tocar(animacao: StringName) -> void:
	if sprite.animation != animacao:
		sprite.play(animacao)


func morrer() -> void:
	if morto:
		return

	morto = true
	detectou_player = false
	tempo_recuo = 0.0
	tempo_pausa = 0.0
	cancelar_destravamento()
	sprite.play(&"morte")


func selecionar_alvo_cooperativo() -> void:
	if not Cooperativo.ativo:
		return
	var anterior: CharacterBody2D = player
	var escolhido: CharacterBody2D
	var menor_distancia: float = INF
	for candidato in Cooperativo.jogadores():
		player = candidato
		var distancia: float = global_position.distance_to(candidato.global_position)
		var limite: float = obter_alcance_deteccao()
		if candidato == anterior and detectou_player:
			limite = distancia_perder_player
		if distancia > limite or player_oculto_por_mesa():
			continue
		if linha_solida_bloqueada(mascara_paredes_visao):
			continue
		if distancia < menor_distancia:
			menor_distancia = distancia
			escolhido = candidato
	player = escolhido
	if escolhido != anterior:
		detectou_player = false
		tempo_atualizar_caminho = 0.0
		cancelar_destravamento()
