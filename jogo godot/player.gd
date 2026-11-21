extends CharacterBody2D

signal vida_alterada(vida: int)

@export_group("Cooperativo")
@export_range(1, 2) var numero_jogador: int = 1

func acao_local(acao: StringName) -> StringName:
	if Cooperativo.ativo:
		return StringName("coop_p%d_%s" % [numero_jogador, acao])
	return acao


@export_group("Movimento")
@export var velocidade: float = 60.0
@export var velocidade_correndo: float = 120.0
@export var velocidade_rastejando: float = 35.0

@export_group("Animações")
@export var velocidade_animacao_normal: float = 1.0
@export var velocidade_animacao_correndo: float = 1.5

@export_group("Pulo")
@export var altura_pulo: float = 20.0
@export var duracao_pulo: float = 0.40

@export_group("Vida")
@export var vida_maxima: int = 3
@export var intervalo_entre_danos: float = 1.0

@export_group("Morte")
@export var tempo_antes_de_retornar: float = 0.5

@export_group("Stamina")
@export var stamina_maxima: float = 100.0
@export var consumo_correndo: float = 20.0
@export var recuperacao_andando: float = 4.0
@export var recuperacao_parado: float = 20.0
@export var atraso_recuperacao: float = 0.8
@export var stamina_para_voltar_correr: float = 20.0

@export_group("Interface")
@export var indicador_stamina: AnimatedSprite2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var colisor_em_pe: CollisionShape2D = $ColisorEmPe
@onready var colisor_rastejando: CollisionShape2D = $ColisorRastejando

var vida_atual: int = 3
var proximo_dano_permitido: int = 0
var morto: bool = false

var stamina_atual: float = 100.0
var stamina_esgotada: bool = false
var tempo_espera_recuperacao: float = 0.0

var ultima_direcao: Vector2 = Vector2.DOWN
var estava_rastejando: bool = false
var pulando: bool = false
var estado_movimento: StringName = &"parado"

var posicao_y_original_sprite: float
var posicao_y_original_colisor: float

var tween_dano: Tween
var tween_pulo: Tween
var cor_original_sprite: Color

var tempo_recuo: float = 0.0
var velocidade_recuo: Vector2 = Vector2.ZERO

var inicializado: bool = false


func _ready() -> void:
	vida_maxima = maxi(vida_maxima, 1)
	stamina_maxima = maxf(stamina_maxima, 1.0)

	vida_atual = vida_maxima
	stamina_atual = stamina_maxima

	cor_original_sprite = sprite.self_modulate

	posicao_y_original_sprite = sprite.position.y
	posicao_y_original_colisor = colisor_em_pe.position.y

	colisor_em_pe.disabled = false
	colisor_rastejando.disabled = true

	sprite.play("idle_frente")

	# Recupera a vida e a stamina da sala anterior ou do checkpoint.
	if numero_jogador == 1:
		ProgressoJogo.aplicar_estado_player(self)

	inicializado = true

	call_deferred("atualizar_interface_inicial")


func _exit_tree() -> void:
	if numero_jogador == 1 and inicializado and not morto:
		ProgressoJogo.salvar_estado_player(self)


func atualizar_interface_inicial() -> void:
	if numero_jogador == 2:
		return
	if not is_instance_valid(indicador_stamina):
		indicador_stamina = get_tree().get_first_node_in_group(
			"indicador_stamina"
		) as AnimatedSprite2D

	atualizar_indicador_stamina()
	vida_alterada.emit(vida_atual)


func _physics_process(delta: float) -> void:
	if morto:
		return
	if numero_jogador == 2 and Cooperativo.bloqueado():
		velocity = Vector2.ZERO
		return

	if tempo_recuo > 0.0:
		tempo_recuo = maxf(tempo_recuo - delta, 0.0)

		velocity = velocidade_recuo
		move_and_slide()

		atualizar_stamina(delta, false, false)
		return

	var direcao := Input.get_vector(
		acao_local(&"move_left"),
		acao_local(&"move_right"),
		acao_local(&"move_up"),
		acao_local(&"move_down")
	)

	if Input.is_action_just_pressed(acao_local(&"pular")):
		pular()

	var tem_movimento: bool = direcao != Vector2.ZERO
	var botao_rastejar: bool = Input.is_action_pressed(acao_local(&"rastejar"))
	var botao_correr: bool = Input.is_action_pressed(acao_local(&"correr"))

	var rastejando: bool = (
		botao_rastejar
		and tem_movimento
		and not pulando
	)

	var correndo: bool = (
		botao_correr
		and tem_movimento
		and not rastejando
		and not stamina_esgotada
		and stamina_atual > 0.0
	)

	var descansando: bool = (
		not tem_movimento
		and not pulando
	)

	atualizar_stamina(delta, correndo, descansando)

	if stamina_esgotada:
		correndo = false

	var rastejando_para_lado: bool = (
		rastejando and abs(direcao.x) > abs(direcao.y)
	)

	atualizar_colisor(rastejando_para_lado)

	if tem_movimento:
		ultima_direcao = direcao

		if rastejando:
			velocity = direcao * velocidade_rastejando
			animacao_rastejando(direcao)

		elif correndo:
			velocity = direcao * velocidade_correndo
			animacao_andando(direcao, true)

		else:
			velocity = direcao * velocidade
			animacao_andando(direcao, false)

	else:
		velocity = Vector2.ZERO
		animacao_parado()

	move_and_slide()

	if rastejando:
		estado_movimento = &"rastejando"
	elif correndo:
		estado_movimento = &"correndo"
	elif tem_movimento:
		estado_movimento = &"andando"
	else:
		estado_movimento = &"parado"


func atualizar_stamina(
	delta: float,
	correndo: bool,
	descansando: bool
) -> void:
	if correndo:
		stamina_atual = maxf(
			stamina_atual - maxf(consumo_correndo, 0.0) * delta,
			0.0
		)

		tempo_espera_recuperacao = maxf(
			atraso_recuperacao,
			0.0
		)

		if stamina_atual <= 0.0:
			stamina_esgotada = true

	else:
		var tempo_recuperando: float = delta

		if tempo_espera_recuperacao > 0.0:
			var tempo_esperado: float = minf(
				tempo_espera_recuperacao,
				delta
			)

			tempo_espera_recuperacao -= tempo_esperado
			tempo_recuperando -= tempo_esperado

		if tempo_recuperando > 0.0:
			var taxa: float = recuperacao_andando

			if descansando:
				taxa = recuperacao_parado

			stamina_atual = minf(
				stamina_atual
				+ maxf(taxa, 0.0) * tempo_recuperando,
				stamina_maxima
			)

		var limite_retorno: float = clampf(
			stamina_para_voltar_correr,
			0.1,
			stamina_maxima
		)

		if stamina_esgotada and stamina_atual >= limite_retorno:
			stamina_esgotada = false

	atualizar_indicador_stamina()


func atualizar_indicador_stamina() -> void:
	if not is_instance_valid(indicador_stamina):
		return

	if indicador_stamina.has_method("definir_stamina"):
		indicador_stamina.call(
			"definir_stamina",
			stamina_atual,
			stamina_maxima
		)


func receber_impacto(
	direcao: Vector2,
	forca: float,
	duracao: float
) -> void:
	if morto:
		return

	var agora: int = Time.get_ticks_msec()

	if agora < proximo_dano_permitido:
		return

	proximo_dano_permitido = agora + int(
		maxf(intervalo_entre_danos, 0.0) * 1000.0
	)

	velocidade_recuo = direcao.normalized() * forca
	tempo_recuo = maxf(duracao, 0.0)
	estado_movimento = &"parado"

	animacao_parado()
	piscar_dano()

	vida_atual = maxi(vida_atual - 1, 0)
	vida_alterada.emit(vida_atual)

	if vida_atual <= 0:
		morrer()


func morrer() -> void:
	if morto:
		return

	if ProgressoJogo.checkpoint.is_empty():
		push_error(
			"Player: falta registrar o checkpoint. "
			+ "Adicione ChegadaSala nesta cena."
		)

		vida_atual = 1
		vida_alterada.emit(vida_atual)
		return

	morto = true
	velocity = Vector2.ZERO
	tempo_recuo = 0.0
	estado_movimento = &"parado"

	set_physics_process(false)

	if tween_pulo != null and tween_pulo.is_valid():
		tween_pulo.kill()

	finalizar_pulo()
	animacao_parado()

	await get_tree().create_timer(
		maxf(tempo_antes_de_retornar, 0.05)
	).timeout

	ProgressoJogo.restaurar_apos_morte()


func piscar_dano() -> void:
	if tween_dano != null and tween_dano.is_valid():
		tween_dano.kill()

	var cor_clara := Color(
		cor_original_sprite.r * 3.0,
		cor_original_sprite.g * 3.0,
		cor_original_sprite.b * 3.0,
		cor_original_sprite.a
	)

	sprite.self_modulate = cor_clara
	tween_dano = create_tween()

	tween_dano.tween_property(
		sprite,
		"self_modulate",
		cor_original_sprite,
		0.18
	)


func pular() -> void:
	if pulando or morto:
		return

	pulando = true
	atualizar_colisor(false)

	tween_pulo = create_tween()

	var metade_duracao: float = maxf(duracao_pulo, 0.02) / 2.0

	tween_pulo.tween_property(
		sprite,
		"position:y",
		posicao_y_original_sprite - altura_pulo,
		metade_duracao
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween_pulo.parallel().tween_property(
		colisor_em_pe,
		"position:y",
		posicao_y_original_colisor - altura_pulo,
		metade_duracao
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween_pulo.tween_property(
		sprite,
		"position:y",
		posicao_y_original_sprite,
		metade_duracao
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tween_pulo.parallel().tween_property(
		colisor_em_pe,
		"position:y",
		posicao_y_original_colisor,
		metade_duracao
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tween_pulo.finished.connect(finalizar_pulo)


func finalizar_pulo() -> void:
	pulando = false
	sprite.position.y = posicao_y_original_sprite
	colisor_em_pe.position.y = posicao_y_original_colisor


func animacao_rastejando(direcao: Vector2) -> void:
	sprite.speed_scale = velocidade_animacao_normal

	if abs(direcao.x) > abs(direcao.y):
		sprite.flip_h = direcao.x < 0
		tocar(&"rastejar_lado")
	elif direcao.y < 0:
		sprite.flip_h = false
		tocar(&"rastejar_costas")
	else:
		sprite.flip_h = false
		tocar(&"rastejar_frente")


func animacao_andando(direcao: Vector2, correndo: bool) -> void:
	sprite.speed_scale = (
		velocidade_animacao_correndo
		if correndo
		else velocidade_animacao_normal
	)

	if abs(direcao.x) > abs(direcao.y):
		sprite.flip_h = direcao.x < 0
		tocar(&"andar_lado")
	elif direcao.y < 0:
		sprite.flip_h = false
		tocar(&"andar_costas")
	else:
		sprite.flip_h = false
		tocar(&"andar_frente")


func animacao_parado() -> void:
	sprite.speed_scale = velocidade_animacao_normal

	if abs(ultima_direcao.x) > abs(ultima_direcao.y):
		sprite.flip_h = ultima_direcao.x < 0
		tocar(&"idle_lado")
	elif ultima_direcao.y < 0:
		sprite.flip_h = false
		tocar(&"idle_costas")
	else:
		sprite.flip_h = false
		tocar(&"idle_frente")


func atualizar_colisor(rastejando: bool) -> void:
	if rastejando == estava_rastejando:
		return

	estava_rastejando = rastejando

	colisor_em_pe.set_deferred("disabled", rastejando)
	colisor_rastejando.set_deferred("disabled", not rastejando)


func tocar(nome_animacao: StringName) -> void:
	if sprite.animation != nome_animacao:
		sprite.play(nome_animacao)


func recuperar_vida(quantidade: int = 1) -> bool:
	if morto or quantidade <= 0 or vida_atual >= vida_maxima:
		return false

	vida_atual = mini(vida_atual + quantidade, vida_maxima)
	vida_alterada.emit(vida_atual)

	return true
