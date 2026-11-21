extends Area2D

@export var player: CharacterBody2D

@export_enum("normal", "uv")
var tipo_lanterna: String = "uv"

@export var id_objeto: StringName = &"lanterna_uv_ti"
@export var imagem: Texture2D
@export var acao_interagir: StringName = &"interagir"

var e_descarte: bool = false
var configurado: bool = false


func _ready() -> void:
	if not is_instance_valid(player) or id_objeto == &"":
		push_error(
			"Lanterna coletável: preencha Player e Id Objeto."
		)
		return

	var recolhidas: Dictionary = ProgressoJogo.get_meta(
		&"lanternas_recolhidas",
		{}
	)

	if not e_descarte and recolhidas.has(String(id_objeto)):
		hide()
		queue_free()
		return

	if not InputMap.has_action(acao_interagir):
		push_error(
			"Lanterna coletável: confira Acao Interagir."
		)
		return

	# Cria o colisor de interação automaticamente.
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()

	circulo.radius = 20.0
	forma.shape = circulo

	add_child(forma)

	if imagem != null:
		var desenho := Sprite2D.new()
		desenho.texture = imagem

		desenho.texture_filter = (
			CanvasItem.TEXTURE_FILTER_NEAREST
		)

		add_child(desenho)
	else:
		var nome := Label.new()

		nome.text = (
			"Lanterna UV"
			if tipo_lanterna == "uv"
			else "Lanterna"
		)

		add_child(nome)

	collision_layer = 0
	collision_mask = player.collision_layer
	monitoring = true

	configurado = true


func _unhandled_input(event: InputEvent) -> void:
	if (
		not configurado
		or not event.is_action_pressed(acao_interagir)
		or event.is_echo()
	):
		return

	if (
		not is_instance_valid(player)
		or not player.is_physics_processing()
	):
		return

	if player.get("morto") == true or not overlaps_body(player):
		return

	var lanterna: Node = player.get_node_or_null("Lanterna")

	if (
		not is_instance_valid(lanterna)
		or not lanterna.has_method("trocar_lanterna")
	):
		push_error(
			"O filho Lanterna precisa do script atualizado."
		)
		return

	get_viewport().set_input_as_handled()

	var trocou: bool = bool(
		lanterna.call(
			"trocar_lanterna",
			tipo_lanterna,
			id_objeto,
			imagem
		)
	)

	if trocou:
		configurado = false
		hide()

		set_deferred("monitoring", false)
		queue_free()
