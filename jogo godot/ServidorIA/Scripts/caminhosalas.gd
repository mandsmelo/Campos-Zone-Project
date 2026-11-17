extends Area2D

@export_group("Referências")
@export var player: CharacterBody2D

@export_group("Próxima sala")
@export_file("*.tscn") var caminho_cena_destino: String

@export_group("Interação")
@export var acao_interagir: StringName = &"interagir"

var trocando_cena: bool = false


func _ready() -> void:
	if not is_instance_valid(player):
		push_error("Porta: preencha o campo Player no Inspector.")
		set_process_unhandled_input(false)
		return

	if (
		caminho_cena_destino.is_empty()
		or not ResourceLoader.exists(caminho_cena_destino)
	):
		push_error("Porta: escolha uma cena de destino válida.")
		set_process_unhandled_input(false)
		return

	if not InputMap.has_action(acao_interagir):
		push_error(
			"Porta: crie a ação '%s' no Mapa de Entrada."
			% acao_interagir
		)
		set_process_unhandled_input(false)
		return

	monitoring = true


func _unhandled_input(event: InputEvent) -> void:
	if trocando_cena:
		return

	if not is_instance_valid(player):
		return

	# Não permite entrar durante diálogos ou cutscenes.
	if not player.is_physics_processing():
		return

	if not event.is_action_pressed(acao_interagir):
		return

	if event.is_echo():
		return

	if not overlaps_body(player):
		return

	get_viewport().set_input_as_handled()

	trocando_cena = true
	player.velocity = Vector2.ZERO

	call_deferred("entrar_na_sala")


func entrar_na_sala() -> void:
	var erro := get_tree().change_scene_to_file(
		caminho_cena_destino
	)

	if erro != OK:
		push_error(
			"Não foi possível abrir a sala. Código: %s" % erro
		)
		trocando_cena = false
