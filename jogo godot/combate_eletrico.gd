extends Node2D

@export_group("Referências")
@export var player: CharacterBody2D
@export var lanterna: Node

@export_group("Jogador")
@export var identificador_jogador: StringName = &"jogador_1"
@export var acao_atirar: StringName = &"atirar"

@export_group("Taser")
@export var alcance_taser: float = 100.0
@export var dano_taser: float = 50.0
@export var consumo_taser: float = 12.0
@export var intervalo_taser: float = 0.5

@export_group("Arma de choque")
@export var alcance_arma: float = 180.0
@export var dano_arma: float = 100.0
@export var consumo_arma: float = 25.0
@export var intervalo_arma: float = 1.0

@export_group("Raio")
@export var cor_raio: Color = Color(0.3, 0.85, 1.0)
@export var largura_raio: float = 2.0
@export var duracao_raio: float = 0.15

@export_group("Obstáculos")
# Selecione as camadas físicas das paredes.
@export_flags_2d_physics var mascara_obstaculos: int = 1

@export_group("Depuração")
@export var mostrar_diagnostico: bool = false

var tempo_ate_disparo: float = 0.0
var configurado: bool = false


func _ready() -> void:
	if not is_instance_valid(player):
		player = get_parent() as CharacterBody2D

	if not is_instance_valid(player):
		push_error(
			"CombateEletrico: coloque este nó dentro do player."
		)
		return

	if not is_instance_valid(lanterna):
		lanterna = player.get_node_or_null("Lanterna")

	if not is_instance_valid(lanterna):
		push_error("CombateEletrico: preencha Lanterna.")
		return

	if lanterna.get("bateria_atual") == null:
		push_error(
			"CombateEletrico: a Lanterna precisa de bateria_atual."
		)
		return

	if not InputMap.has_action(acao_atirar):
		push_error(
			"CombateEletrico: crie a ação 'atirar' no Mapa de Entrada."
		)
		return

	configurado = true


func diagnosticar(texto: String) -> void:
	if mostrar_diagnostico:
		print("COMBATE: ", texto)


func _physics_process(delta: float) -> void:
	tempo_ate_disparo = maxf(
		tempo_ate_disparo - delta,
		0.0
	)

	if not configurado:
		return

	if not is_instance_valid(player):
		return

	# Não permite disparar durante diálogos e cutscenes.
	if not player.is_physics_processing():
		return

	if player.get("morto") == true:
		return

	if Input.is_action_just_pressed(player.call("acao_local", acao_atirar) if player.has_method("acao_local") else acao_atirar):
		tentar_disparar()


func tentar_disparar() -> void:
	if tempo_ate_disparo > 0.0:
		diagnosticar("Aguardando o próximo disparo.")
		return

	var arma: Dictionary = InventarioJogo.obter_arma(
		identificador_jogador
	)

	if arma.is_empty():
		diagnosticar("Nenhuma arma equipada.")
		return

	var tipo: String = String(arma.get("tipo", ""))

	var alcance: float = 0.0
	var dano: float = 0.0
	var consumo: float = 0.0
	var intervalo: float = 0.0
	var limite_alvos: int = 1

	match tipo:
		"taser":
			alcance = alcance_taser
			dano = dano_taser
			consumo = consumo_taser
			intervalo = intervalo_taser
			limite_alvos = 2

		"arma_choque":
			alcance = alcance_arma
			dano = dano_arma
			consumo = consumo_arma
			intervalo = intervalo_arma
			limite_alvos = 1

		_:
			diagnosticar("Tipo de arma desconhecido: " + tipo)
			return

	if not is_instance_valid(lanterna):
		return

	var custo: float = maxf(consumo, 0.0)
	var bateria: float = float(
		lanterna.get("bateria_atual")
	)

	if bateria < custo:
		diagnosticar("Bateria insuficiente.")
		return

	var alvos: Array[Node2D] = obter_alvos(
		maxf(alcance, 0.0),
		limite_alvos
	)

	if alvos.is_empty():
		diagnosticar(
			"Nenhum alvo ao alcance e sem obstáculos."
		)
		return

	# O custo é por disparo, mesmo quando o taser atinge dois.
	lanterna.set(
		"bateria_atual",
		maxf(bateria - custo, 0.0)
	)

	if lanterna.has_method("atualizar_indicador_bateria"):
		lanterna.call("atualizar_indicador_bateria")

	tempo_ate_disparo = maxf(intervalo, 0.05)

	for alvo in alvos:
		if not is_instance_valid(alvo):
			continue

		var corpo := alvo.get("zumbi") as CharacterBody2D

		if not is_instance_valid(corpo):
			continue

		criar_raio(
			player.global_position,
			corpo.global_position
		)

		alvo.call(
			"receber_dano_eletrico",
			maxf(dano, 0.0)
		)

	diagnosticar(
		"Disparo realizado. Alvos: %s | Bateria: %s"
		% [
			alvos.size(),
			lanterna.get("bateria_atual")
		]
	)


func obter_alvos(
	alcance: float,
	limite: int
) -> Array[Node2D]:
	var candidatos: Array[Node2D] = []

	for no in get_tree().get_nodes_in_group("alvos_eletricos"):
		var alvo := no as Node2D

		if not is_instance_valid(alvo):
			continue

		if not alvo.has_method("pode_receber_disparo"):
			continue

		if alvo.call("pode_receber_disparo") != true:
			continue

		var corpo := alvo.get("zumbi") as CharacterBody2D

		if not is_instance_valid(corpo):
			continue

		var distancia: float = (
			player.global_position.distance_to(
				corpo.global_position
			)
		)

		if distancia > alcance:
			continue

		if caminho_bloqueado(corpo):
			continue

		candidatos.append(alvo)

	# Os alvos mais próximos têm prioridade.
	candidatos.sort_custom(
		func(a: Node2D, b: Node2D) -> bool:
			var corpo_a := a.get("zumbi") as CharacterBody2D
			var corpo_b := b.get("zumbi") as CharacterBody2D

			return player.global_position.distance_squared_to(
				corpo_a.global_position
			) < player.global_position.distance_squared_to(
				corpo_b.global_position
			)
	)

	var resultado: Array[Node2D] = []

	for alvo in candidatos:
		if resultado.size() >= limite:
			break

		resultado.append(alvo)

	return resultado


func caminho_bloqueado(
	corpo: CharacterBody2D
) -> bool:
	var consulta := PhysicsRayQueryParameters2D.create(
		player.global_position,
		corpo.global_position,
		mascara_obstaculos
	)

	consulta.exclude = [
		player.get_rid(),
		corpo.get_rid()
	]

	consulta.collide_with_areas = false
	consulta.collide_with_bodies = true

	var resultado: Dictionary = (
		player.get_world_2d().direct_space_state.intersect_ray(
			consulta
		)
	)

	return not resultado.is_empty()


func criar_raio(
	inicio: Vector2,
	fim: Vector2
) -> void:
	var linha := Line2D.new()

	linha.width = maxf(largura_raio, 0.5)
	linha.default_color = cor_raio
	linha.z_index = 20

	# O raio fica no mundo, sem acompanhar o movimento do player.
	linha.top_level = true

	add_child(linha)
	linha.global_transform = Transform2D.IDENTITY

	var diferenca: Vector2 = fim - inicio
	var lateral: Vector2 = (
		diferenca.normalized().orthogonal()
	)

	var pontos := PackedVector2Array()
	pontos.append(inicio)

	for indice in range(1, 6):
		var proporcao: float = float(indice) / 6.0

		var ponto: Vector2 = inicio.lerp(
			fim,
			proporcao
		)

		ponto += lateral * randf_range(-5.0, 5.0)
		pontos.append(ponto)

	pontos.append(fim)
	linha.points = pontos

	var tween := create_tween()

	tween.tween_property(
		linha,
		"modulate:a",
		0.0,
		maxf(duracao_raio, 0.02)
	)

	tween.tween_callback(linha.queue_free)
