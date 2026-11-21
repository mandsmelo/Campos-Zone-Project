extends Node

signal explosao_finalizada

@export_group("Referências")
@export var entrada_estudante: Node
@export var estudante: Node2D
@export var local_seguro: Marker2D
@export var player: CharacterBody2D
@export var coordenador_visual: CanvasItem
@export var caixa_dialogo: Control

# Opcional: esconde o rádio original da prateleira ao retornar.
@export var radio_prateleira: CanvasItem

@export_group("Sprites dos objetos")
@export var laboratorio: AnimatedSprite2D
@export var estande: AnimatedSprite2D

@export_group("Animações do laboratório")
@export var animacao_normal: StringName = &"normal"
@export var animacao_faiscas: StringName = &"faiscas"
@export var animacao_explosao: StringName = &"explosao"

@export_group("Animação do estande")
@export var animacao_estande: StringName = &"default"
@export var velocidade_destruicao_estande: float = 1.0

# Aceita CollisionShape2D ou CollisionPolygon2D.
@export_group("Colisão do estande")
@export var estande_colisao_inteiro: Node2D
@export var estande_colisao_escombros: Node2D

@export_group("Colisão do laboratório")
@export var lab_colisao_inteiro: Node2D
@export var lab_colisao_escombros: Node2D

@export_group("Destino dos escombros do estande")
@export var destino_escombros: Marker2D
@export var objeto_escombros: Node2D
@export var duracao_movimento_escombros: float = 0.35

@export_group("Lançamento do player")
@export var destino_player: Marker2D
@export var duracao_recuo: float = 0.4

@export_group("Preparação")
@export var duracao_fuga_estudante: float = 0.5
@export_range(1, 20, 1) var quantidade_piscadas: int = 7
@export var intervalo_inicial: float = 0.55
@export var intervalo_final: float = 0.08

@export_range(0.0, 1.0) var intensidade_inicial: float = 0.08
@export_range(0.0, 1.0) var intensidade_final: float = 0.45

@export_group("Clarão da explosão")
@export_range(0.0, 1.0) var intensidade_explosao: float = 0.85
@export var duracao_clarao: float = 0.45

var iniciou: bool = false
var lancamento_ativo: bool = false

var camada_efeito: CanvasLayer
var tela_branca: ColorRect


func _ready() -> void:
	if not validar_configuracao():
		return

	if ProgressoJogo.get_meta(&"explosao_cena2_concluida", false) == true:
		iniciou = true
		call_deferred("restaurar_cenario_destruido")
		return

	# Recursos independentes das outras cópias no mapa.
	laboratorio.sprite_frames = (
		laboratorio.sprite_frames.duplicate()
	)
	estande.sprite_frames = (
		estande.sprite_frames.duplicate()
	)

	laboratorio.sprite_frames.set_animation_loop(
		animacao_faiscas, true
	)
	laboratorio.sprite_frames.set_animation_loop(
		animacao_explosao, false
	)
	estande.sprite_frames.set_animation_loop(
		animacao_estande, false
	)

	laboratorio.speed_scale = 1.0
	tocar_desde_inicio(laboratorio, animacao_normal)

	# Mantém o estande intacto no início.
	estande.stop()
	estande.animation = animacao_estande
	estande.set_frame_and_progress(0, 0.0)

	atualizar_colisoes_estande(false)
	atualizar_colisoes_laboratorio(false)

	criar_efeito_tela()

	entrada_estudante.connect(
		"esbarrou_no_estande",
		Callable(self, "iniciar_explosao"),
		CONNECT_DEFERRED
	)


func validar_configuracao() -> bool:
	var referencias: Dictionary = {
		"Entrada Estudante": entrada_estudante,
		"Estudante": estudante,
		"Local Seguro": local_seguro,
		"Player": player,
		"Coordenador Visual": coordenador_visual,
		"Caixa Dialogo": caixa_dialogo,
		"Laboratorio": laboratorio,
		"Estande": estande,
		"Destino Escombros": destino_escombros,
		"Objeto Escombros": objeto_escombros,
		"Destino Player": destino_player
	}

	for campo in referencias:
		if not is_instance_valid(referencias[campo]):
			push_error(
				"ExplosaoInicial: preencha o campo %s." % campo
			)
			return false

	if not entrada_estudante.has_signal("esbarrou_no_estande"):
		push_error(
			"EntradaEstudante precisa do sinal esbarrou_no_estande."
		)
		return false

	if (
		not caixa_dialogo.has_method("iniciar_dialogo")
		or not caixa_dialogo.has_signal("dialogo_finalizado")
	):
		push_error("Confira o script da Caixa Dialogo.")
		return false

	if (
		laboratorio.sprite_frames == null
		or estande.sprite_frames == null
	):
		push_error("Laboratório e estande precisam de SpriteFrames.")
		return false

	for nome in [
		animacao_normal,
		animacao_faiscas,
		animacao_explosao
	]:
		if not validar_animacao(laboratorio, nome):
			return false

	if not validar_animacao(estande, animacao_estande):
		return false

	var colisores: Dictionary = {
		"Estande Colisao Inteiro": estande_colisao_inteiro,
		"Estande Colisao Escombros": estande_colisao_escombros,
		"Lab Colisao Inteiro": lab_colisao_inteiro,
		"Lab Colisao Escombros": lab_colisao_escombros
	}

	for campo in colisores:
		var colisor: Node2D = colisores[campo]

		if not (
			colisor is CollisionShape2D
			or colisor is CollisionPolygon2D
		):
			push_error(
				"%s: arraste um CollisionShape2D ou CollisionPolygon2D."
				% campo
			)
			return false

		if not colisor.get_parent() is StaticBody2D:
			push_error(
				"%s deve ser filho direto de um StaticBody2D."
				% campo
			)
			return false

	# O objeto movido precisa conter o sprite e as colisões.
	if not (
		objeto_escombros.is_ancestor_of(estande)
		and objeto_escombros.is_ancestor_of(estande_colisao_inteiro)
		and objeto_escombros.is_ancestor_of(estande_colisao_escombros)
	):
		push_error(
			"Objeto Escombros: arraste o nó principal do estande, "
			+ "contendo o sprite e os dois colisores."
		)
		return false

	return true


func validar_animacao(
	objeto: AnimatedSprite2D,
	nome: StringName
) -> bool:
	if not objeto.sprite_frames.has_animation(nome):
		push_error(
			"%s: animação não encontrada: %s." % [objeto.name, nome]
		)
		return false

	if objeto.sprite_frames.get_frame_count(nome) == 0:
		push_error(
			"%s: a animação %s está vazia." % [objeto.name, nome]
		)
		return false

	if objeto.sprite_frames.get_animation_speed(nome) <= 0.0:
		push_error(
			"%s: a animação %s precisa de FPS maior que zero."
			% [objeto.name, nome]
		)
		return false

	return true


func criar_efeito_tela() -> void:
	camada_efeito = CanvasLayer.new()
	camada_efeito.name = "EfeitoExplosao"
	camada_efeito.layer = 100
	add_child(camada_efeito)

	tela_branca = ColorRect.new()
	tela_branca.name = "Clarao"
	tela_branca.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tela_branca.color = Color(1.0, 1.0, 1.0, 0.0)
	camada_efeito.add_child(tela_branca)

	ajustar_efeito_tela()
	get_viewport().size_changed.connect(ajustar_efeito_tela)


func ajustar_efeito_tela() -> void:
	tela_branca.position = Vector2.ZERO
	tela_branca.size = get_viewport().get_visible_rect().size


func iniciar_explosao() -> void:
	if iniciou:
		return

	iniciou = true
	bloquear_player()

	tocar_desde_inicio(laboratorio, animacao_faiscas)

	var aviso: Array[Dictionary] = [
		{
			"nome": "ESTUDANTE",
			"texto": "Ah! Eu bati no equipamento!",
			"tipo": 0
		},
		{
			"nome": "COORDENADOR",
			"texto": "Está soltando faíscas! Afastem-se!",
			"tipo": 0
		}
	]

	caixa_dialogo.call("iniciar_dialogo", aviso)
	await Signal(caixa_dialogo, "dialogo_finalizado")

	bloquear_player()

	# O percurso até LocalSeguro precisa estar livre.
	var fuga := create_tween()
	fuga.tween_property(
		estudante,
		"global_position",
		local_seguro.global_position,
		maxf(duracao_fuga_estudante, 0.05)
	)
	await fuga.finished

	await executar_piscadas()

	# Começa a destruição dos dois objetos.
	laboratorio.speed_scale = 1.0
	tocar_desde_inicio(laboratorio, animacao_explosao)

	estande.speed_scale = maxf(
		velocidade_destruicao_estande, 0.1
	)
	tocar_desde_inicio(estande, animacao_estande)

	coordenador_visual.hide()

	# Executa simultaneamente ao restante da explosão.
	iniciar_recuo()
	executar_clarao()

	var lab_atualizado: bool = false
	var estande_atualizado: bool = false

	# Cada objeto troca a colisão ao terminar sua animação.
	while not lab_atualizado or not estande_atualizado:
		if not lab_atualizado and not laboratorio.is_playing():
			fixar_ultimo_frame(laboratorio, animacao_explosao)
			atualizar_colisoes_laboratorio(true)
			lab_atualizado = true

		if not estande_atualizado and not estande.is_playing():
			fixar_ultimo_frame(estande, animacao_estande)
			atualizar_colisoes_estande(true)
			estande_atualizado = true

		await get_tree().process_frame

	# Evita ativar os escombros no destino antes de o player chegar.
	while lancamento_ativo:
		await get_tree().process_frame

	await mover_escombros()

	while tela_branca.color.a > 0.001:
		await get_tree().process_frame

	var falas: Array[Dictionary] = [
		{
			"nome": "CROMOS",
			"texto": "Você está me ouvindo? Vou tirar isso de cima!",
			"tipo": 0
		},
		{
			"nome": "COORDENADOR",
			"texto": "Estou preso... Não tente levantar sozinho.",
			"tipo": 0
		},
		{
			"nome": "COORDENADOR",
			"texto": "A entrada ficou bloqueada. Procure a saída dos fundos.",
			"tipo": 0
		},
		{
			"nome": "OBJETIVO",
			"texto": "Encontre uma saída pelos fundos da universidade.",
			"tipo": 2
		}
	]

	caixa_dialogo.call("iniciar_dialogo", falas)
	await Signal(caixa_dialogo, "dialogo_finalizado")

	player.velocity = Vector2.ZERO
	player.set_physics_process(true)

	ProgressoJogo.set_meta(&"explosao_cena2_concluida", true)
	explosao_finalizada.emit()


func executar_piscadas() -> void:
	var quantidade := maxi(quantidade_piscadas, 1)

	for i in range(quantidade):
		var progresso := float(i) / float(maxi(quantidade - 1, 1))

		var intervalo := lerpf(
			maxf(intervalo_inicial, 0.02),
			maxf(intervalo_final, 0.02),
			progresso
		)

		var intensidade := lerpf(
			intensidade_inicial,
			intensidade_final,
			progresso
		)

		var tween := create_tween()

		tween.tween_property(
			tela_branca,
			"color:a",
			intensidade,
			intervalo * 0.2
		)
		tween.tween_property(
			tela_branca,
			"color:a",
			0.0,
			intervalo * 0.3
		)
		tween.tween_interval(intervalo * 0.5)

		await tween.finished


func executar_clarao() -> void:
	tela_branca.color = Color(
		1.0, 1.0, 1.0, intensidade_explosao
	)

	var tween := create_tween()
	tween.tween_property(
		tela_branca,
		"color:a",
		0.0,
		maxf(duracao_clarao, 0.05)
	)


func iniciar_recuo() -> void:
	lancamento_ativo = true
	bloquear_player()

	# Movimento da cutscene: atravessa obstáculos,
	# terminando exatamente no marcador.
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)

	tween.tween_property(
		player,
		"global_position",
		destino_player.global_position,
		maxf(duracao_recuo, 0.01)
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await tween.finished

	player.velocity = Vector2.ZERO
	lancamento_ativo = false


func mover_escombros() -> void:
	# Desliga as colisões durante o deslocamento do estande.
	definir_colisor_desativado(estande_colisao_inteiro, true)
	definir_colisor_desativado(estande_colisao_escombros, true)

	var deslocamento := (
		destino_escombros.global_position - estande.global_position
	)
	var destino := objeto_escombros.global_position + deslocamento

	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)

	tween.tween_property(
		objeto_escombros,
		"global_position",
		destino,
		maxf(duracao_movimento_escombros, 0.01)
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await tween.finished

	# No destino, ativa somente a colisão dos escombros.
	atualizar_colisoes_estande(true)


func atualizar_colisoes_estande(destruido: bool) -> void:
	definir_colisor_desativado(
		estande_colisao_inteiro, destruido
	)
	definir_colisor_desativado(
		estande_colisao_escombros, not destruido
	)


func atualizar_colisoes_laboratorio(destruido: bool) -> void:
	definir_colisor_desativado(
		lab_colisao_inteiro, destruido
	)
	definir_colisor_desativado(
		lab_colisao_escombros, not destruido
	)


func definir_colisor_desativado(
	colisor: Node2D,
	desativado: bool
) -> void:
	if is_instance_valid(colisor):
		colisor.set_deferred("disabled", desativado)


func bloquear_player() -> void:
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	player.set("estado_movimento", &"parado")

	if player.has_method("animacao_parado"):
		player.call("animacao_parado")


func tocar_desde_inicio(
	objeto: AnimatedSprite2D,
	animacao: StringName
) -> void:
	objeto.stop()
	objeto.animation = animacao
	objeto.set_frame_and_progress(0, 0.0)
	objeto.play()


func fixar_ultimo_frame(
	objeto: AnimatedSprite2D,
	animacao: StringName
) -> void:
	objeto.pause()
	objeto.set_frame_and_progress(
		objeto.sprite_frames.get_frame_count(animacao) - 1,
		0.0
	)


func restaurar_cenario_destruido() -> void:
	# Executa depois dos _ready dos demais controladores.
	laboratorio.stop()
	laboratorio.animation = animacao_explosao
	fixar_ultimo_frame(laboratorio, animacao_explosao)

	estande.stop()
	estande.animation = animacao_estande
	fixar_ultimo_frame(estande, animacao_estande)

	# Reposiciona instantaneamente, sem repetir a animação.
	objeto_escombros.global_position += (
		destino_escombros.global_position - estande.global_position
	)

	atualizar_colisoes_estande(true)
	atualizar_colisoes_laboratorio(true)
	coordenador_visual.hide()

	estudante.global_position = local_seguro.global_position
	estudante.show()
	estudante.set_physics_process(false)
	entrada_estudante.set_physics_process(false)
	if entrada_estudante.has_method("parar_estudante"):
		entrada_estudante.call("parar_estudante")

	if is_instance_valid(radio_prateleira):
		radio_prateleira.hide()

	# Não lança nem reposiciona o player na volta.
	# ChegadaSala cuida da posição da porta utilizada.
	player.velocity = Vector2.ZERO
	player.set_physics_process(true)

	# Libera as interações existentes de Stella e do coordenador.
	explosao_finalizada.emit()
