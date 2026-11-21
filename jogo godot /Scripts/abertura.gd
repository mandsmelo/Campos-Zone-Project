extends Node

@export_group("Referências")
@export var player: CharacterBody2D
@export var caixa_dialogo: Control
@export var entrega_radio: Node
@export var pontos_caminho: Array[Marker2D] = []

@export_group("Conversa")
@export var nome_personagem: String = "Cromos"
@export var direcao_olhar_coordenador: Vector2 = Vector2.UP

@export_group("Caminhada")
@export var velocidade_caminhada: float = 45.0
@export var distancia_chegada: float = 2.0
@export var tempo_maximo_travado: float = 2.0

enum Etapa { INATIVO, OBJETIVO, CAMINHANDO, CONVERSANDO, FINALIZADO }
var etapa: Etapa = Etapa.INATIVO
var indice_ponto: int = 0
var tempo_travado: float = 0.0


func _ready() -> void:
	# A explosão concluída identifica que toda a introdução terminou.
	if ProgressoJogo.get_meta(&"explosao_cena2_concluida", false) == true:
		etapa = Etapa.FINALIZADO
		set_physics_process(false)
		return
	if not validar_configuracao():
		set_physics_process(false)
		return
	caixa_dialogo.connect("dialogo_finalizado", Callable(self, "ao_finalizar_dialogo"))
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	call_deferred("mostrar_objetivo")


func validar_configuracao() -> bool:
	if not is_instance_valid(player) or not is_instance_valid(caixa_dialogo):
		push_error("Abertura: preencha Player e Caixa Dialogo.")
		return false
	if not caixa_dialogo.has_method("iniciar_dialogo") or not caixa_dialogo.has_signal("dialogo_finalizado"):
		push_error("Abertura: confira o script da caixa de diálogo.")
		return false
	if pontos_caminho.is_empty():
		push_error("Abertura: adicione os pontos do caminho.")
		return false
	for ponto in pontos_caminho:
		if not is_instance_valid(ponto):
			push_error("Abertura: existe um ponto vazio na lista.")
			return false
	if not player.has_method("animacao_andando") or not player.has_method("animacao_parado"):
		push_error("Abertura: confira os métodos de animação do player.")
		return false
	return true


func mostrar_objetivo() -> void:
	if caixa_dialogo.get("configurado") != true:
		interromper_abertura("A caixa de diálogo não foi configurada.")
		return
	etapa = Etapa.OBJETIVO
	var falas: Array[Dictionary] = [{
		"nome": "OBJETIVO", "texto": "Dirija-se ao coordenador na recepção.", "tipo": 2
	}]
	caixa_dialogo.call("iniciar_dialogo", falas)


func ao_finalizar_dialogo() -> void:
	match etapa:
		Etapa.OBJETIVO:
			player.set_physics_process(false)
			indice_ponto = 0
			tempo_travado = 0.0
			etapa = Etapa.CAMINHANDO
		Etapa.CONVERSANDO:
			finalizar_abertura()


func _physics_process(delta: float) -> void:
	if etapa != Etapa.CAMINHANDO or not is_instance_valid(player):
		return
	var ponto: Marker2D = pontos_caminho[indice_ponto]
	if not is_instance_valid(ponto):
		interromper_abertura("Um ponto do caminho foi removido.")
		return
	var destino: Vector2 = ponto.global_position
	var distancia: float = player.global_position.distance_to(destino)
	if distancia <= maxf(distancia_chegada, 0.1):
		player.velocity = Vector2.ZERO
		indice_ponto += 1
		tempo_travado = 0.0
		if indice_ponto >= pontos_caminho.size():
			iniciar_conversa()
		return
	var direcao: Vector2 = player.global_position.direction_to(destino)
	player.set("ultima_direcao", direcao)
	player.set("estado_movimento", &"andando")
	player.call("animacao_andando", direcao, false)
	var velocidade_atual: float = minf(maxf(velocidade_caminhada, 1.0), distancia / maxf(delta, 0.001))
	player.velocity = direcao * velocidade_atual
	var posicao_anterior: Vector2 = player.global_position
	player.move_and_slide()
	if player.global_position.distance_to(posicao_anterior) < velocidade_atual * delta * 0.1:
		tempo_travado += delta
	else:
		tempo_travado = 0.0
	if tempo_travado >= maxf(tempo_maximo_travado, 0.2):
		interromper_abertura("O player ficou bloqueado. Ajuste os Marker2D do caminho.")


func iniciar_conversa() -> void:
	etapa = Etapa.CONVERSANDO
	player.velocity = Vector2.ZERO
	player.set("estado_movimento", &"parado")
	if not direcao_olhar_coordenador.is_zero_approx():
		player.set("ultima_direcao", direcao_olhar_coordenador.normalized())
	player.call("animacao_parado")
	var falas: Array[Dictionary] = [
		{"nome": "COORDENADOR", "texto": "Oi! Você veio ajudar na montagem da Expo?", "tipo": 0},
		{"nome": nome_personagem, "texto": "Sim. Por onde começamos?", "tipo": 0},
		{"nome": "COORDENADOR", "texto": "O pessoal da Enfermagem já chegou. Confira se precisam de ajuda nos estandes.", "tipo": 0},
		{"nome": nome_personagem, "texto": "Certo. Depois eu volto aqui?", "tipo": 0},
		{"nome": "COORDENADOR", "texto": "Isso. Antes de sair, vou buscar um rádio para você.", "tipo": 0}
	]
	caixa_dialogo.call("iniciar_dialogo", falas)


func finalizar_abertura() -> void:
	etapa = Etapa.FINALIZADO
	player.velocity = Vector2.ZERO
	player.set("estado_movimento", &"parado")
	player.call("animacao_parado")
	if is_instance_valid(entrega_radio) and entrega_radio.has_method("iniciar_entrega"):
		player.set_physics_process(false)
		entrega_radio.call("iniciar_entrega")
	else:
		push_warning("Preencha Entrega Radio no nó Abertura.")
		player.set_physics_process(true)


func interromper_abertura(mensagem: String) -> void:
	push_warning("Abertura: " + mensagem)
	etapa = Etapa.FINALIZADO
	if is_instance_valid(player):
		player.velocity = Vector2.ZERO
		player.call("animacao_parado")
		player.set_physics_process(true)
