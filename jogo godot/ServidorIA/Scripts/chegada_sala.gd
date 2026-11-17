extends Node

@export_group("Referências")
@export var player: CharacterBody2D

@export_group("Pontos de chegada")
@export var pontos_entrada: Array[Marker2D] = []

@export_group("Depuração")
@export var mostrar_diagnostico: bool = true


func _ready() -> void:
	call_deferred("preparar_chegada")


func preparar_chegada() -> void:
	if not is_instance_valid(player):
		push_error("ChegadaSala: preencha Player.")
		return

	var cena: Node = get_tree().current_scene

	if not is_instance_valid(cena):
		return

	var reposicionar: bool = false
	var destino: Vector2 = player.global_position
	var direcao: Vector2 = Vector2.DOWN

	# Na morte, usa a posição guardada no checkpoint.
	if ProgressoJogo.restaurando_checkpoint:
		if ProgressoJogo.checkpoint.is_empty():
			push_error("ChegadaSala: checkpoint vazio.")
			return

		destino = ProgressoJogo.checkpoint["posicao"]
		direcao = ProgressoJogo.checkpoint["direcao"]
		reposicionar = true

	# Na passagem por uma porta, usa o Marker2D indicado.
	elif ProgressoJogo.has_meta(&"chegada_pendente"):
		var dados: Dictionary = ProgressoJogo.get_meta(
			&"chegada_pendente",
			{}
		)

		var caminho: String = String(dados.get("cena", ""))
		var nome_destino: String = String(
			dados.get("entrada", "")
		)

		if caminho.is_empty() or not ResourceLoader.exists(caminho):
			push_error("ChegadaSala: cena de destino inválida.")
			return

		var recurso: PackedScene = load(caminho) as PackedScene

		if recurso == null:
			push_error("ChegadaSala: o destino não é uma cena.")
			return

		if recurso.resource_path != cena.scene_file_path:
			push_error(
				"ChegadaSala: destino registrado: %s | cena atual: %s"
				% [recurso.resource_path, cena.scene_file_path]
			)
			return

		var marcador: Marker2D = encontrar_marcador(nome_destino)

		if not is_instance_valid(marcador):
			push_error(
				"ChegadaSala: marcador '%s' não encontrado na lista."
				% nome_destino
			)
			return

		destino = marcador.global_position
		reposicionar = true

	# Aguarda a inicialização dos demais scripts.
	await get_tree().process_frame

	if not is_instance_valid(player):
		return

	if reposicionar:
		player.velocity = Vector2.ZERO
		player.global_position = destino
		player.set("ultima_direcao", direcao)
		player.set("estado_movimento", &"parado")

		if player.has_method("animacao_parado"):
			player.call("animacao_parado")

		var camera: Camera2D = get_viewport().get_camera_2d()

		if is_instance_valid(camera):
			camera.reset_smoothing()

	if ProgressoJogo.has_meta(&"chegada_pendente"):
		ProgressoJogo.remove_meta(&"chegada_pendente")

	ProgressoJogo.registrar_checkpoint(player)

	if mostrar_diagnostico:
		print(
			"Checkpoint pronto: ",
			cena.name,
			" | Posição: ",
			player.global_position,
			" | Vida: ",
			player.get("vida_atual")
		)


func encontrar_marcador(nome_destino: String) -> Marker2D:
	for ponto in pontos_entrada:
		if not is_instance_valid(ponto):
			continue

		if String(ponto.name) == nome_destino:
			return ponto

	return null
