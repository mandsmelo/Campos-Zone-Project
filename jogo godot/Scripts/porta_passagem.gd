extends Area2D

@export_group("Referências")
@export var player: CharacterBody2D

@export_group("Destino")
@export_file("*.tscn") var caminho_cena_destino: String
@export var nome_entrada_destino: StringName = &"EntradaPadrao"

@export_group("Interação")
@export var acao_interagir: StringName = &"interagir"

@export_group("Depuração")
@export var mostrar_diagnostico: bool = true

var configurado: bool = false
var trocando_cena: bool = false
var tempo_apos_bloqueio: float = 0.0


func _ready() -> void:
	monitoring = true

	if not is_instance_valid(player):
		push_error("Porta: preencha o campo Player.")
		return

	if caminho_cena_destino.is_empty():
		push_error("Porta: selecione a Cena Destino.")
		return

	if not ResourceLoader.exists(caminho_cena_destino):
		push_error("Porta: a cena de destino não foi encontrada.")
		return

	if nome_entrada_destino == &"":
		push_error("Porta: preencha Nome Entrada Destino.")
		return

	if not InputMap.has_action(acao_interagir):
		push_error("Porta: a ação de interação não existe.")
		return

	configurado = true


func _physics_process(delta: float) -> void:
	if not configurado or trocando_cena:
		return

	if not is_instance_valid(player):
		return

	# Não troca de sala durante diálogos ou cutscenes.
	if not player.is_physics_processing():
		tempo_apos_bloqueio = 0.15
		return

	tempo_apos_bloqueio = maxf(
		tempo_apos_bloqueio - delta,
		0.0
	)

	if tempo_apos_bloqueio > 0.0:
		return

	if not Input.is_action_just_pressed(acao_interagir):
		return

	var dentro_da_area: bool = (Cooperativo.jogador_na_interacao(self, player) != null)

	if mostrar_diagnostico:
		print(
			"Porta: ", name,
			" | Player dentro: ", dentro_da_area,
			" | Destino: ", caminho_cena_destino
		)

	if not dentro_da_area:
		return

	trocando_cena = true
	player.velocity = Vector2.ZERO

	call_deferred("trocar_de_sala")


func trocar_de_sala() -> void:
	# Guarda em qual ponto o personagem deve aparecer.
	ProgressoJogo.set_meta(
		&"chegada_pendente",
		{
			"cena": caminho_cena_destino,
			"entrada": String(nome_entrada_destino)
		}
	)

	var erro: Error = get_tree().change_scene_to_file(
		caminho_cena_destino
	)

	if erro != OK:
		ProgressoJogo.remove_meta(&"chegada_pendente")
		trocando_cena = false

		push_error(
			"Porta: não foi possível abrir a cena. Erro: %s."
			% erro
		)
