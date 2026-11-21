extends Node

@export var player: CharacterBody2D
@export var ambiente_escuro: bool = false


func _ready() -> void:
	# Aguarda a Lanterna criar a luz e o CanvasModulate.
	call_deferred("aplicar_iluminacao")


func aplicar_iluminacao() -> void:
	if not is_instance_valid(player):
		push_error("ConfiguracaoFase: preencha o campo Player.")
		return

	var lanterna := player.get_node_or_null("Lanterna")

	if lanterna == null:
		push_error("O player precisa do nó Lanterna.")
		return

	if not lanterna.has_method("definir_escuridao"):
		push_error("A Lanterna precisa de definir_escuridao().")
		return

	lanterna.call("definir_escuridao", ambiente_escuro)
