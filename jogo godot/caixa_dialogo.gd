extends Control

signal dialogo_finalizado

@export_group("Referências")
@export var player: CharacterBody2D

@export_group("Diálogo")
@export var nome_animacao: StringName = &"caixa"
@export var acao_avancar: StringName = &"interagir"
@export var letras_por_segundo: float = 35.0
@export var mostrar_mensagem_inicial: bool = true

@export_group("Posição na tela")
@export var tamanho_caixa: Vector2 = Vector2(960.0, 144.0)
@export var margem_inferior: float = 24.0

@onready var fundo: AnimatedSprite2D = $fundo
@onready var nome_label: Label = $Nome
@onready var texto_label: RichTextLabel = $Texto

var ativo: bool = false
var configurado: bool = false
var indice_fala: int = 0
var caracteres_exibidos: float = 0.0

var falas: Array[Dictionary] = []
var fisica_player_anterior: bool = false


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if fundo.sprite_frames == null:
		push_error("Diálogo: o fundo está sem SpriteFrames.")
		return

	if not fundo.sprite_frames.has_animation(nome_animacao):
		push_error("Diálogo: confira o nome da animação 'caixa'.")
		return

	if fundo.sprite_frames.get_frame_count(nome_animacao) < 3:
		push_error("Diálogo: adicione os frames 0, 1 e 2.")
		return

	if not InputMap.has_action(acao_avancar):
		push_error("Diálogo: confira a ação 'interagir'.")
		return

	fundo.stop()
	fundo.animation = nome_animacao
	fundo.centered = false
	fundo.position = Vector2.ZERO
	fundo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	nome_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nome_label.add_theme_font_size_override("font_size", 22)
	nome_label.add_theme_color_override("font_color", Color.WHITE)

	texto_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texto_label.bbcode_enabled = false
	texto_label.threaded = false
	texto_label.scroll_active = false
	texto_label.fit_content = false
	texto_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto_label.add_theme_font_size_override("normal_font_size", 22)
	texto_label.add_theme_color_override(
		"default_color",
		Color.WHITE
	)

	configurado = true

	get_viewport().size_changed.connect(ajustar_layout)
	ajustar_layout()

	if mostrar_mensagem_inicial:
		call_deferred("mostrar_inicio")


func ajustar_layout() -> void:
	if not configurado:
		return

	var tela := get_viewport_rect().size

	size = tamanho_caixa
	scale = Vector2.ONE

	position = Vector2(
		(tela.x - tamanho_caixa.x) / 2.0,
		tela.y - tamanho_caixa.y - margem_inferior
	)

	nome_label.position = Vector2(24.0, 12.0)
	nome_label.size = Vector2(tamanho_caixa.x - 48.0, 30.0)

	texto_label.position = Vector2(24.0, 48.0)
	texto_label.size = Vector2(
		tamanho_caixa.x - 48.0,
		tamanho_caixa.y - 60.0
	)

	ajustar_fundo()


func ajustar_fundo() -> void:
	var textura := fundo.sprite_frames.get_frame_texture(
		nome_animacao,
		fundo.frame
	)

	if textura == null:
		return

	var tamanho_textura := textura.get_size()

	if tamanho_textura.x <= 0.0 or tamanho_textura.y <= 0.0:
		return

	fundo.scale = tamanho_caixa / tamanho_textura


func mostrar_inicio() -> void:
	var mensagem: Array[Dictionary] = [
		{
			"nome": "OBJETIVO",
			"texto": "Dirija-se ao coordenador na recepção.",
			"tipo": 2
		}
	]

	iniciar_dialogo(mensagem)


func iniciar_dialogo(novas_falas: Array[Dictionary]) -> void:
	if not configurado or ativo or novas_falas.is_empty():
		return

	falas = novas_falas.duplicate(true)
	indice_fala = 0
	ativo = true

	# Bloqueia o movimento normal durante a conversa.
	if is_instance_valid(player):
		fisica_player_anterior = player.is_physics_processing()

		player.set_physics_process(false)
		player.velocity = Vector2.ZERO

		if player.has_method("animacao_parado"):
			player.call("animacao_parado")

	show()
	exibir_fala()


func exibir_fala() -> void:
	var fala: Dictionary = falas[indice_fala]

	nome_label.text = str(fala.get("nome", ""))
	texto_label.text = str(fala.get("texto", ""))

	fundo.frame = clampi(int(fala.get("tipo", 0)), 0, 2)
	ajustar_fundo()

	caracteres_exibidos = 0.0
	texto_label.visible_characters = 0


func _process(delta: float) -> void:
	if not ativo:
		return

	var total := texto_label.get_total_character_count()

	caracteres_exibidos = minf(
		caracteres_exibidos
		+ maxf(letras_por_segundo, 1.0) * delta,
		float(total)
	)

	texto_label.visible_characters = int(caracteres_exibidos)


func _input(event: InputEvent) -> void:
	if not ativo:
		return

	if not event.is_action_pressed(acao_avancar):
		return

	if event.is_echo():
		return

	get_viewport().set_input_as_handled()

	var total := texto_label.get_total_character_count()

	# Primeiro aperto termina de escrever a fala.
	if texto_label.visible_characters < total:
		caracteres_exibidos = float(total)
		texto_label.visible_characters = total
		return

	# Próximo aperto avança ou encerra.
	indice_fala += 1

	if indice_fala >= falas.size():
		finalizar_dialogo()
	else:
		exibir_fala()


func finalizar_dialogo() -> void:
	ativo = false
	hide()

	if is_instance_valid(player):
		player.velocity = Vector2.ZERO
		player.set_physics_process(fisica_player_anterior)

	dialogo_finalizado.emit()
