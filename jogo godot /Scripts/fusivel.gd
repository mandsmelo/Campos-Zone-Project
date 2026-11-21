extends Area2D

@export_group("Referências")
@export var player: CharacterBody2D
@export var caixa_dialogo: Node

# Preencha somente se o desenho estiver fora desta Area2D.
@export var sprite_fusivel: CanvasItem

@export_group("Missão")
@export var identificador_quadro: StringName = &"enfermagem_2"

@export_group("Interação")
@export var acao_interagir: StringName = &"interagir"

var configurado: bool = false
var recolhendo: bool = false


func chave_fusivel() -> StringName:
	return StringName(
		"fusivel_" + String(identificador_quadro)
	)


func chave_energia() -> StringName:
	return StringName(
		"energia_" + String(identificador_quadro)
	)


func chave_coleta() -> StringName:
	return StringName(
		"coleta_fusivel_" + String(identificador_quadro)
	)


func _ready() -> void:
	if identificador_quadro == &"":
		push_error("Fusível: preencha Identificador Quadro.")
		return

	var ja_recolhido: bool = (
		ProgressoJogo.get_meta(chave_coleta(), false) == true
		or ProgressoJogo.get_meta(chave_fusivel(), false) == true
		or ProgressoJogo.get_meta(chave_energia(), false) == true
	)

	if ja_recolhido:
		remover_objeto()
		return

	if not is_instance_valid(player):
		push_error("Fusível: preencha Player.")
		return

	if not is_instance_valid(caixa_dialogo):
		push_error("Fusível: preencha Caixa Dialogo.")
		return

	if (
		not caixa_dialogo.has_method("iniciar_dialogo")
		or not caixa_dialogo.has_signal("dialogo_finalizado")
	):
		push_error("Fusível: confira a Caixa Dialogo.")
		return

	if not InputMap.has_action(acao_interagir):
		push_error("Fusível: confira a ação de interação.")
		return

	monitoring = true
	configurado = true


func _unhandled_input(event: InputEvent) -> void:
	if not configurado or recolhendo:
		return

	if not event.is_action_pressed(acao_interagir):
		return

	if event.is_echo():
		return

	if not is_instance_valid(player):
		return

	if not is_instance_valid(caixa_dialogo):
		return

	if caixa_dialogo.get("ativo") == true:
		return

	if not player.is_physics_processing():
		return

	if not overlaps_body(player):
		return

	get_viewport().set_input_as_handled()

	recolhendo = true
	await recolher()

	recolhendo = false


func possui_algum_fusivel() -> bool:
	for chave in ProgressoJogo.get_meta_list():
		if String(chave).begins_with("fusivel_"):
			if ProgressoJogo.get_meta(chave, false) == true:
				return true

	return false


func recolher() -> void:
	if possui_algum_fusivel():
		await mostrar_mensagem(
			"Você já carrega um fusível. Instale-o antes de recolher outro."
		)
		return

	# Posse atual, consultada pelo quadro elétrico.
	ProgressoJogo.set_meta(chave_fusivel(), true)

	# Histórico de coleta, para não reaparecer após o uso.
	ProgressoJogo.set_meta(chave_coleta(), true)

	configurado = false
	ocultar_fusivel()
	set_deferred("monitoring", false)

	await mostrar_mensagem(
		"Fusível recolhido. Leve-o ao quadro elétrico correspondente."
	)

	remover_objeto()


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


func ocultar_fusivel() -> void:
	hide()

	if is_instance_valid(sprite_fusivel):
		sprite_fusivel.hide()


func remover_objeto() -> void:
	ocultar_fusivel()

	if is_instance_valid(sprite_fusivel):
		if (
			sprite_fusivel != self
			and not is_ancestor_of(sprite_fusivel)
		):
			sprite_fusivel.queue_free()

	queue_free()
