extends Area2D

@export_group("Referências")
@export var player: CharacterBody2D
@export var cena_destino: PackedScene
@export var controle_menu: Node

@export_group("Interação")
@export var acao_interagir: StringName = &"interagir"

var trocando_cena: bool = false
var player_estava_perto: bool = false


func _ready() -> void:
	monitoring = true

	if not is_instance_valid(player):
		push_error("PORTA: preencha o campo Player.")

	if cena_destino == null:
		push_error("PORTA: arraste Cena2.tscn para Cena Destino.")

	if not InputMap.has_action(acao_interagir):
		push_error(
			"PORTA: a ação não existe: " + str(acao_interagir)
		)
		set_physics_process(false)


func _physics_process(_delta: float) -> void:
	if trocando_cena:
		return

	if not is_instance_valid(player):
		return

	var player_perto := (Cooperativo.jogador_na_interacao(self, player) != null)

	if player_perto != player_estava_perto:
		player_estava_perto = player_perto

		if player_perto:
			print("PORTA: player entrou na área.")
		else:
			print("PORTA: player saiu da área.")

	if not Input.is_action_just_pressed(acao_interagir):
		return

	print("PORTA: botão de interação recebido.")

	if not player_perto:
		print("PORTA: o colisor do player não está dentro da área.")
		return

	if is_instance_valid(controle_menu):
		if controle_menu.get("menu_aberto") == true:
			print("PORTA: o menu ainda está aberto.")
			return

	if cena_destino == null:
		push_error("PORTA: o campo Cena Destino está vazio.")
		return

	trocando_cena = true
	call_deferred("entrar_na_cena")


func entrar_na_cena() -> void:
	print("PORTA: abrindo ", cena_destino.resource_path)

	var erro := get_tree().change_scene_to_packed(cena_destino)

	if erro != OK:
		trocando_cena = false
		push_error(
			"PORTA: falha ao trocar de cena. Código: " + str(erro)
		)
