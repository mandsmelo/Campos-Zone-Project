extends Node

@export var player: CharacterBody2D
@export var caixa_dialogo: Node

@export var identificador_jogador: StringName = &"jogador_1"
@export var acao_interagir: StringName = &"interagir"

var itens_criados: Dictionary = {}


func _ready() -> void:
	if not is_instance_valid(player):
		push_error("ArmasDaSala: preencha Player.")
		return

	InventarioJogo.inventario_alterado.connect(
		ao_alterar_inventario
	)

	call_deferred("atualizar_descartes")


func ao_alterar_inventario(_jogador: StringName) -> void:
	call_deferred("atualizar_descartes")


func atualizar_descartes() -> void:
	var cena: Node = get_tree().current_scene

	if not is_instance_valid(cena):
		return

	if not is_instance_valid(player):
		return

	var descartes: Dictionary = (
		InventarioJogo.obter_armas_no_chao()
	)

	# Remove os objetos que foram recolhidos.
	for id in itens_criados.keys():
		var antigo: Node = itens_criados[id]

		if not descartes.has(id):
			if is_instance_valid(antigo):
				antigo.queue_free()

			itens_criados.erase(id)

	for id in descartes:
		var dados: Dictionary = descartes[id]

		# Cada sala cria somente os próprios objetos.
		if String(dados.get("cena", "")) != cena.scene_file_path:
			continue

		if itens_criados.has(id):
			if is_instance_valid(itens_criados[id]):
				continue

		var script_item: Script = load(
			"res://Scripts/arma_coletavel.gd"
		)

		var item: Area2D = script_item.new() as Area2D

		item.set("player", player)
		item.set("caixa_dialogo", caixa_dialogo)
		item.set("identificador_jogador", identificador_jogador)
		item.set("acao_interagir", acao_interagir)
		item.set("tipo_arma", String(dados["tipo"]))
		item.set("id_objeto", StringName(dados["id_objeto"]))
		item.set("e_descarte", true)

		item.collision_layer = 0
		item.collision_mask = player.collision_layer

		var forma := CollisionShape2D.new()
		var circulo := CircleShape2D.new()

		circulo.radius = 20.0
		forma.shape = circulo

		item.add_child(forma)

		adicionar_visual(
			item,
			dados.get("visual", {}),
			String(dados["tipo"])
		)

		cena.add_child(item)
		item.global_position = dados["posicao"]

		itens_criados[id] = item


func adicionar_visual(
	item: Area2D,
	dados: Dictionary,
	tipo: String
) -> void:
	var visual: Node2D

	if dados.get("frames") != null:
		var animado := AnimatedSprite2D.new()

		animado.sprite_frames = dados["frames"]

		animado.animation = StringName(
			dados.get("animacao", "default")
		)

		animado.frame = int(dados.get("frame", 0))
		animado.centered = bool(
			dados.get("centralizado", true)
		)

		animado.offset = dados.get("offset", Vector2.ZERO)

		visual = animado

	elif dados.get("textura") != null:
		var imagem := Sprite2D.new()

		imagem.texture = dados["textura"]

		imagem.hframes = int(dados.get("hframes", 1))
		imagem.vframes = int(dados.get("vframes", 1))
		imagem.frame = int(dados.get("frame", 0))

		imagem.centered = bool(
			dados.get("centralizado", true)
		)

		imagem.offset = dados.get("offset", Vector2.ZERO)

		imagem.region_enabled = bool(
			dados.get("regiao_ativa", false)
		)

		imagem.region_rect = dados.get(
			"regiao",
			Rect2()
		)

		visual = imagem

	else:
		# Mostra um nome caso a arma ainda não tenha desenho.
		var nome := Label.new()
		nome.text = InventarioJogo.nome_arma(tipo)

		item.add_child(nome)
		return

	visual.scale = dados.get("escala", Vector2.ONE)
	visual.position = dados.get("posicao", Vector2.ZERO)

	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	item.add_child(visual)
