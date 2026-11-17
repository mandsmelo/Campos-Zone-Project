extends Area2D

@export_group("Referências")
@export var player: CharacterBody2D
@export var sprite_quadro: AnimatedSprite2D
@export var caixa_dialogo: Control

# Pode preencher manualmente ou deixar buscar no player.
@export var lanterna: Node

@export_group("Interação")
@export var acao_interagir: StringName = &"interagir"

@export_group("Progresso")
# Use os mesmos identificadores no fusível e na configuração da sala.
@export var identificador_fusivel: StringName = &"fusivel_enfermagem_2"
@export var identificador_energia: StringName = &"energia_enfermagem_2"

@export_group("Animação")
@export var nome_animacao: StringName = &"default"

# Contagem visual começando em 1.
@export_range(1, 100, 1) var primeiro_quadro_loop: int = 5
@export_range(1, 100, 1) var ultimo_quadro_loop: int = 10

@export_group("Pilhas")
@export var cena_pilha: PackedScene
@export_range(1, 5, 1) var quantidade_pilhas: int = 1
@export var origem_drop: Vector2 = Vector2.ZERO
@export var direcao_frente_drop: Vector2 = Vector2.DOWN

@export_range(0.0, 60.0, 1.0)
var distancia_minima_drop: float = 25.0

@export_range(0.0, 60.0, 1.0)
var distancia_maxima_drop: float = 60.0

@export_range(0.0, 80.0, 1.0)
var abertura_drop_graus: float = 45.0

var configurado: bool = false
var ativado: bool = false
var animando: bool = false
var luz_restaurada: bool = false
var pilhas_dropadas: bool = false
var conversando: bool = false

var quadro_atual: int = 0
var tempo_acumulado: float = 0.0


func _ready() -> void:
	monitoring = true

	if not validar_configuracao():
		return

	sprite_quadro.stop()
	sprite_quadro.animation = nome_animacao
	sprite_quadro.frame = 0

	configurado = true

	# Restaura o visual de um quadro já consertado.
	if ProgressoJogo.get_meta(identificador_energia, false) == true:
		ativado = true
		animando = true
		luz_restaurada = true
		pilhas_dropadas = true
		quadro_atual = primeiro_quadro_loop - 1
		sprite_quadro.frame = quadro_atual


func validar_configuracao() -> bool:
	if not is_instance_valid(player):
		push_error("Quadro: preencha Player.")
		return false

	if not is_instance_valid(sprite_quadro):
		push_error("Quadro: preencha Sprite Quadro.")
		return false

	if not is_instance_valid(caixa_dialogo):
		push_error("Quadro: preencha Caixa Dialogo.")
		return false

	if (
		not caixa_dialogo.has_method("iniciar_dialogo")
		or not caixa_dialogo.has_signal("dialogo_finalizado")
	):
		push_error("Quadro: confira o script da Caixa Dialogo.")
		return false

	if not is_instance_valid(lanterna):
		lanterna = player.get_node_or_null("Lanterna")

	if not is_instance_valid(lanterna):
		push_error("Quadro: preencha o campo Lanterna.")
		return false

	if not lanterna.has_method("definir_escuridao"):
		push_error("A Lanterna precisa de definir_escuridao().")
		return false

	if not InputMap.has_action(acao_interagir):
		push_error("Crie a ação 'interagir' no Mapa de Entrada.")
		return false

	if sprite_quadro.sprite_frames == null:
		push_error("O quadro está sem SpriteFrames.")
		return false

	if not sprite_quadro.sprite_frames.has_animation(nome_animacao):
		push_error("Confira o nome da animação do quadro.")
		return false

	var total_quadros := sprite_quadro.sprite_frames.get_frame_count(
		nome_animacao
	)

	if (
		primeiro_quadro_loop < 1
		or ultimo_quadro_loop < primeiro_quadro_loop
		or ultimo_quadro_loop > total_quadros
	):
		push_error("Confira os quadros inicial e final do loop.")
		return false

	if (
		sprite_quadro.sprite_frames.get_animation_speed(nome_animacao)
		<= 0.0
		or absf(sprite_quadro.speed_scale) <= 0.0
	):
		push_error("Quadro: FPS e Speed Scale precisam ser maiores que zero.")
		return false

	if cena_pilha == null:
		push_warning("Arraste pilha.tscn para Cena Pilha.")

	return true


func _unhandled_input(event: InputEvent) -> void:
	if not configurado or conversando:
		return

	if not is_instance_valid(player):
		return

	if not player.is_physics_processing():
		return

	if caixa_dialogo.get("ativo") == true:
		return

	if not event.is_action_pressed(acao_interagir):
		return

	if event.is_echo():
		return

	if not overlaps_body(player):
		return

	get_viewport().set_input_as_handled()

	if luz_restaurada:
		mostrar_mensagem("A energia desta sala já foi restaurada.")
		return

	if ativado:
		return

	if not tem_fusivel():
		mostrar_mensagem(
			"Está faltando um fusível no quadro. Procure pelo chão, perto dele."
		)
		return

	instalar_fusivel()


func tem_fusivel() -> bool:
	return ProgressoJogo.get_meta(
		identificador_fusivel, false
	) == true


func mostrar_mensagem(texto: String) -> void:
	conversando = true

	var falas: Array[Dictionary] = [
		{
			"nome": "",
			"texto": texto,
			"tipo": 2
		}
	]

	caixa_dialogo.call("iniciar_dialogo", falas)
	await Signal(caixa_dialogo, "dialogo_finalizado")

	conversando = false


func instalar_fusivel() -> void:
	conversando = true

	var falas: Array[Dictionary] = [
		{
			"nome": "",
			"texto": "Você encaixou o fusível e acionou o quadro.",
			"tipo": 2
		}
	]

	caixa_dialogo.call("iniciar_dialogo", falas)
	await Signal(caixa_dialogo, "dialogo_finalizado")

	conversando = false

	if not is_instance_valid(lanterna):
		return

	# Consome o item somente ao iniciar a ativação.
	ProgressoJogo.set_meta(identificador_fusivel, false)
	ativar_quadro()


func ativar_quadro() -> void:
	if ativado or not configurado:
		return

	ativado = true
	animando = true
	quadro_atual = 0
	tempo_acumulado = 0.0

	sprite_quadro.stop()
	sprite_quadro.animation = nome_animacao
	sprite_quadro.frame = quadro_atual


func _process(delta: float) -> void:
	if not animando:
		return

	if not is_instance_valid(sprite_quadro):
		animando = false
		return

	var fps := sprite_quadro.sprite_frames.get_animation_speed(
		nome_animacao
	)
	var escala := absf(sprite_quadro.speed_scale)

	if fps <= 0.0 or escala <= 0.0:
		return

	tempo_acumulado += delta

	while animando:
		var duracao_relativa := (
			sprite_quadro.sprite_frames.get_frame_duration(
				nome_animacao,
				quadro_atual
			)
		)

		var duracao_quadro := maxf(
			duracao_relativa / (fps * escala),
			0.001
		)

		if tempo_acumulado < duracao_quadro:
			break

		tempo_acumulado -= duracao_quadro
		avancar_quadro()


func avancar_quadro() -> void:
	var indice_final := ultimo_quadro_loop - 1

	if quadro_atual >= indice_final:
		if not luz_restaurada:
			luz_restaurada = true

			ProgressoJogo.set_meta(identificador_energia, true)

			if is_instance_valid(lanterna):
				lanterna.call("definir_escuridao", false)

			dropar_pilhas()

		quadro_atual = primeiro_quadro_loop - 1
	else:
		quadro_atual += 1

	sprite_quadro.frame = quadro_atual


func dropar_pilhas() -> void:
	if pilhas_dropadas:
		return

	if cena_pilha == null:
		push_error("Preencha Cena Pilha no quadro.")
		return

	var mundo := get_tree().current_scene

	if mundo == null:
		return

	pilhas_dropadas = true

	var frente := direcao_frente_drop.normalized()

	if frente.is_zero_approx():
		frente = Vector2.DOWN

	var maxima := clampf(distancia_maxima_drop, 0.0, 60.0)
	var minima := clampf(distancia_minima_drop, 0.0, maxima)
	var abertura := deg_to_rad(
		clampf(abertura_drop_graus, 0.0, 80.0)
	)

	for i in range(quantidade_pilhas):
		var instancia := cena_pilha.instantiate()

		if not instancia is Area2D:
			push_error("A raiz de pilha.tscn precisa ser Area2D.")
			instancia.free()
			continue

		var pilha := instancia as Area2D

		if not pilha.has_method("lancar"):
			push_error("A pilha precisa do método lancar().")
			pilha.free()
			continue

		mundo.add_child(pilha)
		pilha.global_position = (
			sprite_quadro.global_position + origem_drop
		)
		pilha.show()

		var direcao := frente.rotated(
			randf_range(-abertura, abertura)
		)
		var distancia := randf_range(minima, maxima)
		var destino_global := (
			pilha.global_position + direcao * distancia
		)

		var deslocamento_local := (
			destino_global - pilha.position
		)
		var pai := pilha.get_parent() as Node2D

		if pai != null:
			deslocamento_local = (
				pai.to_local(destino_global) - pilha.position
			)

		pilha.call("lancar", deslocamento_local)
