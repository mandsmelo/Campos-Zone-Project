extends Node

@export_group("Referências")
@export var player: CharacterBody2D
@export var coordenador: Node2D
@export var sprite_coordenador: AnimatedSprite2D
@export var radio_prateleira: CanvasItem
@export var caixa_dialogo: Control
@export var entrada_estudante: Node

@export_group("Caminho até o rádio")
@export var pontos_ate_radio: Array[Marker2D] = []
@export var velocidade: float = 35.0
@export var distancia_chegada: float = 1.0
@export var pausa_pegando_radio: float = 0.5

@export_group("Animações do coordenador")
@export var animacao_lado: StringName = &"andandolado"
@export var animacao_frente: StringName = &"andandofrente"
@export var animacao_costas: StringName = &"andando costas"
@export var animacao_parado: StringName = &"parado"

# Marque se o desenho original de lado olha para a direita.
@export var lado_original_olha_direita: bool = true

@export_group("Entrega")
@export var olhar_esquerda_ao_entregar: bool = false

enum Etapa {
	INATIVO,
	INDO,
	PEGANDO,
	VOLTANDO,
	MENSAGEM,
	FINALIZADO
}

var etapa: Etapa = Etapa.INATIVO
var configurado: bool = false

var caminho: Array[Vector2] = []
var indice_ponto: int = 0
var posicao_inicial: Vector2
var tempo_pegando: float = 0.0
var tempo_travado: float = 0.0


func _ready() -> void:
	if not is_instance_valid(player):
		push_error("EntregaRadio: preencha Player.")
		return

	if not is_instance_valid(coordenador):
		push_error("EntregaRadio: preencha Coordenador.")
		return

	if not is_instance_valid(sprite_coordenador):
		push_error("EntregaRadio: preencha Sprite Coordenador.")
		return

	if not is_instance_valid(radio_prateleira):
		push_error("EntregaRadio: preencha Radio Prateleira.")
		return

	if not is_instance_valid(caixa_dialogo):
		push_error("EntregaRadio: preencha Caixa Dialogo.")
		return

	if not caixa_dialogo.has_method("iniciar_dialogo"):
		push_error("A caixa precisa do script de diálogo.")
		return

	if not caixa_dialogo.has_signal("dialogo_finalizado"):
		push_error("A caixa precisa do sinal dialogo_finalizado.")
		return

	if pontos_ate_radio.is_empty():
		push_error("EntregaRadio: adicione os pontos até a prateleira.")
		return

	for ponto in pontos_ate_radio:
		if not is_instance_valid(ponto):
			push_error("Existe um ponto vazio no caminho do rádio.")
			return

	if sprite_coordenador.sprite_frames == null:
		push_error("O coordenador está sem SpriteFrames.")
		return

	var animacoes: Array[StringName] = [
		animacao_lado,
		animacao_frente,
		animacao_costas,
		animacao_parado
	]

	for animacao in animacoes:
		if not sprite_coordenador.sprite_frames.has_animation(animacao):
			push_error(
				"Animação não encontrada no coordenador: "
				+ str(animacao)
			)
			return

	caixa_dialogo.connect(
		"dialogo_finalizado",
		Callable(self, "ao_finalizar_dialogo")
	)

	configurado = true


func iniciar_entrega() -> void:
	if not configurado:
		push_warning("Confira os campos de EntregaRadio.")

		if is_instance_valid(player):
			player.set_physics_process(true)

		return

	if etapa != Etapa.INATIVO:
		return

	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	player.call("animacao_parado")

	# Impede um eventual script próprio do coordenador
	# de disputar o movimento durante esta sequência.
	coordenador.set_physics_process(false)

	posicao_inicial = coordenador.global_position

	caminho.clear()

	for ponto in pontos_ate_radio:
		caminho.append(ponto.global_position)

	indice_ponto = 0
	tempo_travado = 0.0
	etapa = Etapa.INDO


func _physics_process(delta: float) -> void:
	match etapa:
		Etapa.INDO, Etapa.VOLTANDO:
			percorrer_caminho(delta)

		Etapa.PEGANDO:
			tempo_pegando -= delta

			if tempo_pegando <= 0.0:
				pegar_radio()


func percorrer_caminho(delta: float) -> void:
	var destino := caminho[indice_ponto]

	var distancia := coordenador.global_position.distance_to(
		destino
	)

	if distancia <= maxf(distancia_chegada, 0.1):
		parar_coordenador()
		indice_ponto += 1
		tempo_travado = 0.0

		if indice_ponto >= caminho.size():
			if etapa == Etapa.INDO:
				etapa = Etapa.PEGANDO
				tempo_pegando = maxf(pausa_pegando_radio, 0.0)
			else:
				entregar_radio()

		return

	var direcao := coordenador.global_position.direction_to(destino)
	var velocidade_atual := minf(
		maxf(velocidade, 1.0),
		distancia / delta
	)

	animar_caminhada(direcao)

	# Se o coordenador for CharacterBody2D, respeita colisões.
	var corpo := coordenador as CharacterBody2D

	if corpo != null:
		var anterior := corpo.global_position

		corpo.velocity = direcao * velocidade_atual
		corpo.move_and_slide()

		var andou := corpo.global_position.distance_to(anterior)

		if andou < velocidade_atual * delta * 0.1:
			tempo_travado += delta
		else:
			tempo_travado = 0.0

		if tempo_travado >= 2.0:
			parar_coordenador()
			etapa = Etapa.FINALIZADO
			player.set_physics_process(true)

			push_warning(
				"Coordenador bloqueado. Ajuste os pontos do caminho."
			)

	else:
		# Para um coordenador composto apenas por Node2D/sprite.
		coordenador.global_position = (
			coordenador.global_position.move_toward(
				destino,
				velocidade_atual * delta
			)
		)


func pegar_radio() -> void:
	radio_prateleira.hide()

	# Volta pelos mesmos pontos em ordem inversa.
	# Ignora o último, pois já está nele.
	caminho.clear()

	for i in range(pontos_ate_radio.size() - 2, -1, -1):
		caminho.append(pontos_ate_radio[i].global_position)

	caminho.append(posicao_inicial)

	indice_ponto = 0
	tempo_travado = 0.0
	etapa = Etapa.VOLTANDO


func entregar_radio() -> void:
	parar_coordenador()
	sprite_coordenador.flip_h = olhar_esquerda_ao_entregar

	# Registra a posse para usarmos na futura mecânica do rádio.
	player.set_meta("possui_radio", true)

	etapa = Etapa.MENSAGEM

	var falas: Array[Dictionary] = [
		{
			"nome": "COORDENADOR",
			"texto": "Aqui está. Se precisar de orientação, fale comigo pelo rádio.",
			"tipo": 0
		},
		{
			"nome": "OBJETIVO",
			"texto": "Rádio recebido.",
			"tipo": 2
		}
	]

	caixa_dialogo.call("iniciar_dialogo", falas)

func ao_finalizar_dialogo() -> void:
	if etapa != Etapa.MENSAGEM:
		return

	etapa = Etapa.FINALIZADO

	player.velocity = Vector2.ZERO
	player.set("estado_movimento", &"parado")
	player.call("animacao_parado")

	if (
		is_instance_valid(entrada_estudante)
		and entrada_estudante.has_method("iniciar_entrada")
	):
		player.set_physics_process(false)
		entrada_estudante.call_deferred("iniciar_entrada")
	else:
		push_warning(
			"EntregaRadio: preencha o campo Entrada Estudante."
		)
		player.set_physics_process(true)


func animar_caminhada(direcao: Vector2) -> void:
	if absf(direcao.x) > absf(direcao.y):
		if lado_original_olha_direita:
			sprite_coordenador.flip_h = direcao.x < 0.0
		else:
			sprite_coordenador.flip_h = direcao.x > 0.0

		sprite_coordenador.play(animacao_lado)

	elif direcao.y < 0.0:
		sprite_coordenador.flip_h = false
		sprite_coordenador.play(animacao_costas)

	else:
		sprite_coordenador.flip_h = false
		sprite_coordenador.play(animacao_frente)


func parar_coordenador() -> void:
	var corpo := coordenador as CharacterBody2D

	if corpo != null:
		corpo.velocity = Vector2.ZERO

	sprite_coordenador.play(animacao_parado)
