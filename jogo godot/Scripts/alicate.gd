extends Area2D

@export_group("Referências")
@export var player: CharacterBody2D
@export var caixa_dialogo: Control

@export_group("Ferramenta")
@export_enum("notebook", "alicate")
var tipo_ferramenta: String = "notebook"

# Use um identificador diferente para cada objeto do mapa.
@export var id_objeto: StringName = &"enfermagem2_notebook"

@export_group("Jogador")
@export var identificador_jogador: StringName = &"jogador_1"
@export var nome_personagem: String = "Cromos"

@export_group("Interação")
@export var acao_interagir: StringName = &"interagir"

var ocupado: bool = false


func _ready() -> void:
	if id_objeto == &"":
		push_error("Ferramenta: preencha Id Objeto.")
		set_process_unhandled_input(false)
		return

	if InventarioJogo.objeto_foi_recolhido(id_objeto):
		hide()
		queue_free()
		return

	if (
		not is_instance_valid(player)
		or not is_instance_valid(caixa_dialogo)
	):
		push_error("Ferramenta: preencha Player e Caixa Dialogo.")
		set_process_unhandled_input(false)
		return

	if (
		not caixa_dialogo.has_method("iniciar_dialogo")
		or not caixa_dialogo.has_signal("dialogo_finalizado")
	):
		push_error("Ferramenta: confira a Caixa Dialogo.")
		set_process_unhandled_input(false)
		return

	if not InputMap.has_action(acao_interagir):
		push_error("Ferramenta: confira a ação de interação.")
		set_process_unhandled_input(false)
		return

	monitoring = true


func _unhandled_input(event: InputEvent) -> void:
	if ocupado:
		return

	if not is_instance_valid(player):
		return

	if caixa_dialogo.get("ativo") == true:
		return

	if not player.is_physics_processing():
		return

	if not event.is_action_pressed(acao_interagir):
		return

	if event.is_echo():
		return

	if not overlaps_body(player):
		return

	get_viewport().set_input_as_handled()
	interagir()


func interagir() -> void:
	ocupado = true

	if InventarioJogo.possui_ferramenta(
		identificador_jogador,
		tipo_ferramenta
	):
		await mostrar_mensagem(
			"Você já está carregando essa ferramenta."
		)
		ocupado = false
		return

	if not InventarioJogo.tem_espaco(identificador_jogador):
		await mostrar_mensagem(
			"Você já carrega duas ferramentas."
		)
		ocupado = false
		return

	var recolheu := InventarioJogo.tentar_recolher(
		identificador_jogador,
		tipo_ferramenta,
		id_objeto
	)

	if not recolheu:
		ocupado = false
		return

	# Esconde a área e os sprites que estiverem dentro dela.
	hide()
	set_deferred("monitoring", false)
	set_process_unhandled_input(false)

	var descricao: String

	match tipo_ferramenta:
		"notebook":
			descricao = (
				"Um notebook de manutenção. "
				+ "Pode ajudar a acessar portas eletrônicas."
			)
		"alicate":
			descricao = (
				"É bom levar este alicate. "
				+ "Pode ser útil para cortar uma grade."
			)
		_:
			descricao = "Esta ferramenta pode ser útil."

	var quantidade := InventarioJogo.quantidade_ferramentas(
		identificador_jogador
	)

	var falas: Array[Dictionary] = [
		{
			"nome": nome_personagem,
			"texto": descricao,
			"tipo": 0
		},
		{
			"nome": "",
			"texto": "%s recolhido. Ferramentas: %s/2."
				% [
					InventarioJogo.nome_ferramenta(tipo_ferramenta),
					quantidade
				],
			"tipo": 2
		}
	]

	caixa_dialogo.call("iniciar_dialogo", falas)
	await Signal(caixa_dialogo, "dialogo_finalizado")

	queue_free()


func mostrar_mensagem(texto: String) -> void:
	var falas: Array[Dictionary] = [
		{
			"nome": "",
			"texto": texto,
			"tipo": 2
		}
	]

	caixa_dialogo.call("iniciar_dialogo", falas)
	await Signal(caixa_dialogo, "dialogo_finalizado")
