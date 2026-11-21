extends Area2D

@export_group("Referências")
@export var player: CharacterBody2D
@export var caixa_dialogo: Node

@export_group("Arma")
@export_enum("taser", "arma_choque")
var tipo_arma: String = "taser"

@export var id_objeto: StringName = &"ti_taser"

@export_group("Jogador")
@export var identificador_jogador: StringName = &"jogador_1"
@export var acao_interagir: StringName = &"interagir"

@export_group("Descarte")
@export var distancia_descarte: float = 24.0

@export_group("Depuração")
@export var mostrar_diagnostico: bool = true

# Preenchido automaticamente pelo ArmasDaSala.
var e_descarte: bool = false

var configurado: bool = false
var ocupado: bool = false


func _ready() -> void:
	if id_objeto == &"":
		push_error("Arma: preencha um Id Objeto único.")
		return

	if not InventarioJogo.ARMAS.has(tipo_arma):
		push_error("Arma: Tipo Arma inválido.")
		return

	if not is_instance_valid(player):
		push_error(
			"Arma: preencha Player em " + String(get_path())
		)
		return

	if not InputMap.has_action(acao_interagir):
		push_error(
			"Arma: a ação '%s' não existe."
			% String(acao_interagir)
		)
		return

	# A cópia original não reaparece depois da primeira coleta.
	# Os objetos largados são recriados pelo ArmasDaSala.
	if (
		not e_descarte
		and InventarioJogo.objeto_foi_recolhido(id_objeto)
	):
		hide()
		queue_free()
		return

	monitoring = true
	configurado = true


func diagnosticar(texto: String) -> void:
	if mostrar_diagnostico:
		print(
			"ARMA [",
			id_objeto,
			"]: ",
			texto
		)


func _unhandled_input(event: InputEvent) -> void:
	if not configurado or ocupado:
		return

	if not event.is_action_pressed(acao_interagir):
		return

	if event.is_echo():
		return

	if not is_instance_valid(player):
		return

	if not player.is_physics_processing():
		return

	if player.get("morto") == true:
		return

	if is_instance_valid(caixa_dialogo):
		if caixa_dialogo.get("ativo") == true:
			return

	if not overlaps_body(player):
		return

	get_viewport().set_input_as_handled()

	ocupado = true
	recolher_ou_trocar()

	if configurado:
		ocupado = false


func recolher_ou_trocar() -> void:
	var cena: Node = get_tree().current_scene

	if not is_instance_valid(cena):
		diagnosticar("A cena atual não foi encontrada.")
		return

	if cena.scene_file_path.is_empty():
		diagnosticar(
			"A cena precisa estar salva para registrar o descarte."
		)
		return

	var anterior: Dictionary = InventarioJogo.obter_arma(
		identificador_jogador
	)

	var recolheu: bool = InventarioJogo.trocar_arma(
		identificador_jogador,
		tipo_arma,
		id_objeto,
		{
			"cena": cena.scene_file_path,
			"posicao": obter_posicao_descarte()
		},
		capturar_visual()
	)

	if not recolheu:
		diagnosticar(
			"Troca recusada. Confira os IDs das armas "
			+ "e o identificador do jogador."
		)
		return

	if anterior.is_empty():
		diagnosticar("Arma equipada.")
	else:
		diagnosticar(
			"Arma trocada. A anterior foi registrada no chão."
		)

	# O controlador cria a arma anterior no local registrado.
	# Este objeto foi recolhido e pode ser removido.
	configurado = false

	hide()
	set_deferred("monitoring", false)
	set_process_unhandled_input(false)

	queue_free()


func obter_posicao_descarte() -> Vector2:
	var direcao: Vector2 = Vector2.DOWN
	var valor: Variant = player.get("ultima_direcao")

	if valor is Vector2:
		direcao = valor

	if direcao.is_zero_approx():
		direcao = Vector2.DOWN

	var inicio: Vector2 = player.global_position

	var destino: Vector2 = (
		inicio
		+ direcao.normalized().orthogonal()
		* maxf(distancia_descarte, 0.0)
	)

	# Evita largar a arma do outro lado de uma parede.
	var consulta := PhysicsRayQueryParameters2D.create(
		inicio,
		destino,
		player.collision_mask
	)

	consulta.exclude = [player.get_rid()]
	consulta.collide_with_areas = false
	consulta.collide_with_bodies = true

	var resultado: Dictionary = (
		player.get_world_2d().direct_space_state.intersect_ray(
			consulta
		)
	)

	if not resultado.is_empty():
		return inicio

	return destino


func capturar_visual() -> Dictionary:
	for filho in get_children():
		if filho is Sprite2D:
			return {
				"textura": filho.texture,
				"escala": filho.scale,
				"posicao": filho.position,
				"offset": filho.offset,
				"centralizado": filho.centered,
				"hframes": filho.hframes,
				"vframes": filho.vframes,
				"frame": filho.frame,
				"regiao_ativa": filho.region_enabled,
				"regiao": filho.region_rect
			}

		if filho is AnimatedSprite2D:
			return {
				"frames": filho.sprite_frames,
				"animacao": filho.animation,
				"frame": filho.frame,
				"escala": filho.scale,
				"posicao": filho.position,
				"offset": filho.offset,
				"centralizado": filho.centered
			}

	return {}
