extends Node

@export_group("Referências")
@export var player: CharacterBody2D
@export var lanterna: Node
@export var caixa_dialogo: Control

@export_group("Ambiente")
@export var sala_escura: bool = true

# Deve ser igual ao identificador usado no quadro e no fusível.
@export var identificador_quadro: StringName = &"enfermagem_2"

@export_group("Mensagem de entrada")
@export var mostrar_aviso: bool = true
@export var identificador_aviso: StringName = &"entrada_enfermagem_2"


func _ready() -> void:
	if not validar_configuracao():
		return

	call_deferred("preparar_sala")


func validar_configuracao() -> bool:
	if not is_instance_valid(player):
		push_error("ConfiguracaoSala: preencha Player.")
		return false

	if not is_instance_valid(lanterna):
		push_error("ConfiguracaoSala: preencha Lanterna.")
		return false

	if not lanterna.has_method("definir_escuridao"):
		push_error(
			"ConfiguracaoSala: arraste o nó que controla a lanterna."
		)
		return false

	if mostrar_aviso:
		if not is_instance_valid(caixa_dialogo):
			push_error("ConfiguracaoSala: preencha Caixa Dialogo.")
			return false

		if (
			not caixa_dialogo.has_method("iniciar_dialogo")
			or not caixa_dialogo.has_signal("dialogo_finalizado")
		):
			push_error(
				"ConfiguracaoSala: confira o script da Caixa Dialogo."
			)
			return false

	return true


func energia_foi_restaurada() -> bool:
	var chave := StringName(
		"energia_" + str(identificador_quadro)
	)

	return ProgressoJogo.get_meta(chave, false) == true


func preparar_sala() -> void:
	var energia_restaurada := energia_foi_restaurada()
	var ambiente_escuro := sala_escura and not energia_restaurada

	# A energia restaurada impede que a sala volte a ficar escura.
	lanterna.call("definir_escuridao", ambiente_escuro)

	if not mostrar_aviso:
		return

	# Não mostra aviso de escuridão em uma sala iluminada.
	if not ambiente_escuro:
		return

	# Não repete o aviso durante a mesma partida.
	if ProgressoJogo.get_meta(identificador_aviso, false) == true:
		return

	if caixa_dialogo.get("configurado") != true:
		push_error(
			"ConfiguracaoSala: a caixa de diálogo não está configurada."
		)
		return

	while caixa_dialogo.get("ativo") == true:
		await Signal(caixa_dialogo, "dialogo_finalizado")

	# A energia pode ter sido restaurada enquanto aguardava.
	if energia_foi_restaurada():
		return

	var falas: Array[Dictionary] = [
		{
			"nome": "",
			"texto": "Esta sala está escura. Você escuta barulhos estranhos por perto. Tome cuidado.",
			"tipo": 2
		}
	]

	if ProgressoJogo.possui_lanterna:
		falas.append({
			"nome": "",
			"texto": "Segure o botão da lanterna para iluminar o caminho. Economize a bateria.",
			"tipo": 2
		})
	else:
		falas.append({
			"nome": "",
			"texto": "Você precisa de uma lanterna. Volte e converse com Stella.",
			"tipo": 2
		})

	falas.append({
		"nome": "OBJETIVO",
		"texto": "Não sabe como prosseguir? Use o rádio para pedir ajuda ao coordenador. Pressione T ou o botão configurado no controle.",
		"tipo": 2
	})

	caixa_dialogo.call("iniciar_dialogo", falas)
	await Signal(caixa_dialogo, "dialogo_finalizado")

	ProgressoJogo.set_meta(identificador_aviso, true)
