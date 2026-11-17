extends Node2D

@export_group("Referências")
@export var zumbi: CharacterBody2D

@export_group("Vida")
@export var vida_maxima: float = 100.0

@export_group("Identificação")
# Pode ficar vazio para gerar automaticamente.
@export var id_zumbi: StringName = &""

@export_group("Morte")
@export var animacao_morte: StringName = &"morte"

var vida_atual: float = 100.0
var eliminado: bool = false
var configurado: bool = false
var finalizando_morte: bool = false

var chave_progresso: StringName


func _ready() -> void:
	if not is_instance_valid(zumbi):
		zumbi = get_parent() as CharacterBody2D

	if not is_instance_valid(zumbi):
		push_error(
			"VidaZumbi: coloque este nó dentro do zumbi."
		)
		return

	if not zumbi.has_method("morrer"):
		push_error(
			"VidaZumbi: o zumbi precisa da função morrer()."
		)
		return

	vida_atual = maxf(vida_maxima, 1.0)

	call_deferred("preparar_zumbi")


func preparar_zumbi() -> void:
	if not is_instance_valid(zumbi):
		return

	var cena: Node = get_tree().current_scene

	if not is_instance_valid(cena):
		return

	var identificador: String = String(id_zumbi)

	if identificador.is_empty():
		identificador = String(cena.get_path_to(zumbi))

	var identificacao_completa: String = (
		cena.scene_file_path
		+ "|"
		+ identificador
	)

	# O resultado contém apenas caracteres válidos.
	chave_progresso = StringName(
		"zumbi_eliminado_"
		+ identificacao_completa.sha256_text()
	)

	if ProgressoJogo.get_meta(chave_progresso, false) == true:
		eliminado = true

		zumbi.hide()
		zumbi.set_physics_process(false)
		zumbi.set_deferred("collision_layer", 0)
		zumbi.set_deferred("collision_mask", 0)
		zumbi.queue_free()
		return

	configurado = true
	add_to_group("alvos_eletricos")

	if zumbi.get("morto") == true:
		registrar_eliminacao()
		finalizar_morte()


func _process(_delta: float) -> void:
	if not configurado or eliminado:
		return

	if not is_instance_valid(zumbi):
		return

	# Também reconhece mortes causadas pelo cenário.
	if zumbi.get("morto") == true:
		registrar_eliminacao()
		finalizar_morte()


func pode_receber_disparo() -> bool:
	if not configurado or eliminado:
		return false

	if not is_instance_valid(zumbi):
		return false

	return zumbi.get("morto") != true


func receber_dano_eletrico(quantidade: float) -> void:
	if not pode_receber_disparo():
		return

	if quantidade <= 0.0:
		return

	vida_atual = maxf(
		vida_atual - quantidade,
		0.0
	)

	if vida_atual <= 0.0:
		eliminar()


func eliminar() -> void:
	if eliminado or not is_instance_valid(zumbi):
		return

	registrar_eliminacao()

	# Executa a função de morte do script original.
	zumbi.call("morrer")

	finalizar_morte()


func registrar_eliminacao() -> void:
	if eliminado:
		return

	eliminado = true
	remove_from_group("alvos_eletricos")

	ProgressoJogo.set_meta(chave_progresso, true)

	if is_instance_valid(zumbi):
		zumbi.velocity = Vector2.ZERO
		zumbi.set_physics_process(false)

		zumbi.set_deferred("collision_layer", 0)
		zumbi.set_deferred("collision_mask", 0)


func finalizar_morte() -> void:
	if finalizando_morte:
		return

	finalizando_morte = true

	if not is_instance_valid(zumbi):
		return

	var sprite: AnimatedSprite2D = zumbi.get_node_or_null(
		"AnimatedSprite2D"
	) as AnimatedSprite2D

	if not is_instance_valid(sprite):
		zumbi.queue_free()
		return

	if sprite.sprite_frames == null:
		zumbi.queue_free()
		return

	if not sprite.sprite_frames.has_animation(animacao_morte):
		zumbi.queue_free()
		return

	# Faz uma cópia para não alterar as animações dos outros zumbis.
	sprite.sprite_frames = (
		sprite.sprite_frames.duplicate() as SpriteFrames
	)

	# A animação precisa terminar, sem repetir infinitamente.
	sprite.sprite_frames.set_animation_loop(
		animacao_morte,
		false
	)

	if (
		sprite.sprite_frames.get_frame_count(animacao_morte) <= 0
		or sprite.sprite_frames.get_animation_speed(animacao_morte) <= 0.0
	):
		zumbi.queue_free()
		return

	sprite.speed_scale = 1.0
	sprite.play(animacao_morte)

	await sprite.animation_finished

	if is_instance_valid(zumbi):
		zumbi.queue_free()
