extends Area2D

@export_group("Referências")
@export var player: CharacterBody2D
@export var caixa_dialogo: Control
@export var cena_enfermagem: PackedScene

@export_group("Chegada")
# Nome exato do Marker2D cadastrado no ChegadaSala do destino.
# Deixe vazio para manter a posição inicial da cena.
@export var nome_entrada_destino: StringName = &""

@export_group("Interação")
@export var acao_interagir: StringName = &"interagir"

var ocupado: bool = false
var configurado: bool = false


func _ready() -> void:
	configurado = validar_configuracao()
	set_process_unhandled_input(configurado)


func validar_configuracao() -> bool:
	if not is_instance_valid(player):
		push_error("PortaEnfermagem: preencha Player.")
		return false

	if not is_instance_valid(caixa_dialogo):
		push_error("PortaEnfermagem: preencha Caixa Dialogo.")
		return false

	if cena_enfermagem == null:
		push_error("PortaEnfermagem: preencha Cena Enfermagem.")
		return false

	if (
		not caixa_dialogo.has_method("iniciar_dialogo")
		or not caixa_dialogo.has_signal("dialogo_finalizado")
	):
		push_error(
			"PortaEnfermagem: confira o script da Caixa Dialogo."
		)
		return false

	if not InputMap.has_action(acao_interagir):
		push_error(
			"PortaEnfermagem: a ação '%s' não existe."
			% acao_interagir
		)
		return false

	if not monitoring:
		push_error("PortaEnfermagem: ative Monitoring.")
		return false

	return true


func _unhandled_input(event: InputEvent) -> void:
	if not configurado or ocupado:
		return

	if (
		not is_instance_valid(player)
		or not is_instance_valid(caixa_dialogo)
	):
		return

	if caixa_dialogo.get("ativo") == true:
		return

	if not player.is_physics_processing():
		return

	if player.get("morto") == true:
		return

	if not event.is_action_pressed(acao_interagir):
		return

	if event.is_echo():
		return

	if not (Cooperativo.jogador_na_interacao(self, player) != null):
		return

	get_viewport().set_input_as_handled()
	ocupado = true

	if ProgressoJogo.possui_chave_enfermaria:
		player.velocity = Vector2.ZERO
		call_deferred("entrar_na_enfermagem")
	else:
		mostrar_porta_trancada()


func mostrar_porta_trancada() -> void:
	var falas: Array[Dictionary] = [
		{
			"nome": "",
			"texto": "Porta trancada.",
			"tipo": 2
		}
	]

	caixa_dialogo.call("iniciar_dialogo", falas)
	await Signal(caixa_dialogo, "dialogo_finalizado")

	ocupado = false


func entrar_na_enfermagem() -> void:
	if not is_instance_valid(player):
		ocupado = false
		return

	# Salva antes de remover qualquer nó da cena atual.
	ProgressoJogo.salvar_estado_player(player)

	print(
		"PortaEnfermagem: bateria salva antes da troca = ",
		ProgressoJogo.estado_player.get("bateria", "SEM VALOR")
	)

	# Preserva uma chegada anterior caso a troca falhe.
	var tinha_chegada: bool = ProgressoJogo.has_meta(
		&"chegada_pendente"
	)

	var chegada_anterior: Variant = ProgressoJogo.get_meta(
		&"chegada_pendente",
		{}
	)

	if nome_entrada_destino != &"":
		ProgressoJogo.set_meta(
			&"chegada_pendente",
			{
				"cena": cena_enfermagem.resource_path,
				"entrada": String(nome_entrada_destino)
			}
		)
	elif tinha_chegada:
		ProgressoJogo.remove_meta(&"chegada_pendente")

	var erro: Error = get_tree().change_scene_to_packed(
		cena_enfermagem
	)

	if erro != OK:
		if tinha_chegada:
			ProgressoJogo.set_meta(
				&"chegada_pendente",
				chegada_anterior
			)
		elif ProgressoJogo.has_meta(&"chegada_pendente"):
			ProgressoJogo.remove_meta(&"chegada_pendente")

		push_error(
			"Não foi possível abrir a enfermagem. Código: %s"
			% erro
		)

		ocupado = false
