extends Node

@export_group("Referências")
@export var player: CharacterBody2D
@export var caixa_dialogo: Node

@export_group("Inventário")
@export var identificador_jogador: StringName = &"jogador_1"
@export var acao_inventario: StringName = &"inventario"

var configurado: bool = false
var consultando: bool = false


func _ready() -> void:
	if not is_instance_valid(player):
		push_error("Inventário: preencha Player.")
		return

	if not is_instance_valid(caixa_dialogo):
		push_error("Inventário: preencha Caixa Dialogo.")
		return

	if (
		not caixa_dialogo.has_method("iniciar_dialogo")
		or not caixa_dialogo.has_signal("dialogo_finalizado")
	):
		push_error(
			"Inventário: confira o script da caixa de diálogo."
		)
		return

	if not InputMap.has_action(acao_inventario):
		push_error(
			"Inventário: crie a ação 'inventario' no Mapa de Entrada."
		)
		return

	configurado = true


func _unhandled_input(event: InputEvent) -> void:
	if not configurado or consultando:
		return

	if not event.is_action_pressed(acao_inventario):
		return

	if event.is_echo():
		return

	if not is_instance_valid(player):
		return

	if not is_instance_valid(caixa_dialogo):
		return

	# Não abre durante outra conversa ou cutscene.
	if caixa_dialogo.get("ativo") == true:
		return

	if not player.is_physics_processing():
		return

	if player.get("morto") == true:
		return

	get_viewport().set_input_as_handled()

	consultando = true

	var resumo: String = InventarioJogo.resumo_inventario(
		identificador_jogador
	)

	var falas: Array[Dictionary] = [
		{
			"nome": "INVENTÁRIO",
			"texto": resumo,
			"tipo": 2
		}
	]

	caixa_dialogo.call("iniciar_dialogo", falas)

	await Signal(caixa_dialogo, "dialogo_finalizado")

	consultando = false
