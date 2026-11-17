extends CanvasLayer

@export_group("Referências")
@export var player: CharacterBody2D
@export var caixa_dialogo: Node

@export var identificador_jogador: StringName = &"jogador_1"
@export var acao_inventario: StringName = &"inventario"

@export_group("Imagens")
@export var imagem_notebook: Texture2D
@export var imagem_alicate: Texture2D
@export var imagem_taser: Texture2D
@export var imagem_arma_choque: Texture2D
@export var imagem_fusivel: Texture2D
@export var imagem_lanterna: Texture2D
@export var imagem_lanterna_uv: Texture2D

var aberto: bool = false
var configurado: bool = false
var pausa_anterior: bool = false

var fundo: ColorRect
var painel: PanelContainer
var descricao: Label

var botoes: Array[Button] = []
var tipos_nos_espacos: Array[String] = []

var identificador_fusivel_carregado: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 110

	if (
		not is_instance_valid(player)
		or not InputMap.has_action(acao_inventario)
	):
		push_error(
			"Inventário: preencha Player e configure a ação inventario."
		)
		return

	criar_interface()

	fundo.hide()
	painel.hide()

	configurado = true


func criar_interface() -> void:
	fundo = ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.8)

	fundo.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	add_child(fundo)

	painel = PanelContainer.new()

	painel.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER
	)

	painel.offset_left = -350
	painel.offset_top = -280
	painel.offset_right = 350
	painel.offset_bottom = 280

	add_child(painel)

	var margem := MarginContainer.new()

	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override(
			"margin_" + lado,
			20
		)

	painel.add_child(margem)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 12)

	margem.add_child(coluna)

	var titulo := Label.new()
	titulo.text = "INVENTÁRIO"

	titulo.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	titulo.add_theme_font_size_override("font_size", 28)
	coluna.add_child(titulo)

	var grade := GridContainer.new()
	grade.columns = 3

	grade.add_theme_constant_override("h_separation", 16)
	grade.add_theme_constant_override("v_separation", 12)

	coluna.add_child(grade)

	var nomes: Array[String] = [
		"Ferramenta 1",
		"Ferramenta 2",
		"Arma",
		"Fusível",
		"Lanterna"
	]

	for indice in range(nomes.size()):
		var grupo := VBoxContainer.new()
		grade.add_child(grupo)

		var titulo_espaco := Label.new()
		titulo_espaco.text = nomes[indice]

		titulo_espaco.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)

		grupo.add_child(titulo_espaco)

		var botao := Button.new()

		botao.custom_minimum_size = Vector2(195, 100)
		botao.expand_icon = true
		botao.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER

		botao.add_theme_constant_override(
			"icon_max_width",
			64
		)

		botao.texture_filter = (
			CanvasItem.TEXTURE_FILTER_NEAREST
		)

		botao.pressed.connect(
			mostrar_item.bind(indice)
		)

		botao.focus_entered.connect(
			mostrar_item.bind(indice)
		)

		grupo.add_child(botao)
		botoes.append(botao)

	for indice in range(botoes.size()):
		botoes[indice].focus_neighbor_left = (
			botoes[indice].get_path_to(
				botoes[(indice + 4) % 5]
			)
		)

		botoes[indice].focus_neighbor_right = (
			botoes[indice].get_path_to(
				botoes[(indice + 1) % 5]
			)
		)

		var vertical: int = [3, 4, 4, 0, 1][indice]

		botoes[indice].focus_neighbor_top = (
			botoes[indice].get_path_to(botoes[vertical])
		)

		botoes[indice].focus_neighbor_bottom = (
			botoes[indice].get_path_to(botoes[vertical])
		)

	descricao = Label.new()
	descricao.custom_minimum_size.y = 100
	descricao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	descricao.add_theme_font_size_override(
		"font_size",
		20
	)

	coluna.add_child(descricao)

	var ajuda := Label.new()

	ajuda.text = (
		"Direcional: selecionar | Confirmar: consultar"
		+ "\nCancelar ou botão do inventário: fechar"
	)

	ajuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	coluna.add_child(ajuda)


func _input(event: InputEvent) -> void:
	if not configurado or event.is_echo():
		return

	if event.is_action_pressed(acao_inventario):
		if aberto:
			get_viewport().set_input_as_handled()
			fechar()

		elif pode_abrir():
			get_viewport().set_input_as_handled()
			abrir()

	elif aberto and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		fechar()


func pode_abrir() -> bool:
	if not is_instance_valid(player) or get_tree().paused:
		return false

	if (
		not player.is_physics_processing()
		or player.get("morto") == true
	):
		return false

	if is_instance_valid(caixa_dialogo):
		if caixa_dialogo.get("ativo") == true:
			return false

	return true


func abrir() -> void:
	atualizar_itens()

	player.velocity = Vector2.ZERO

	if player.has_method("animacao_parado"):
		player.call("animacao_parado")

	pausa_anterior = get_tree().paused
	get_tree().paused = true

	aberto = true
	fundo.show()
	painel.show()

	botoes[0].grab_focus()
	mostrar_item(0)


func fechar() -> void:
	if not aberto:
		return

	aberto = false
	fundo.hide()
	painel.hide()

	get_tree().paused = pausa_anterior


func atualizar_itens() -> void:
	tipos_nos_espacos.clear()

	var ferramentas: Array[String] = (
		InventarioJogo.obter_ferramentas(
			identificador_jogador
		)
	)

	for indice in range(2):
		tipos_nos_espacos.append(
			ferramentas[indice]
			if indice < ferramentas.size()
			else ""
		)

	var arma: Dictionary = InventarioJogo.obter_arma(
		identificador_jogador
	)

	tipos_nos_espacos.append(
		String(arma.get("tipo", ""))
	)

	identificador_fusivel_carregado = ""

	for chave in ProgressoJogo.get_meta_list():
		if (
			String(chave).begins_with("fusivel_")
			and ProgressoJogo.get_meta(chave, false) == true
		):
			identificador_fusivel_carregado = (
				String(chave).trim_prefix("fusivel_")
			)
			break

	tipos_nos_espacos.append(
		"fusivel"
		if not identificador_fusivel_carregado.is_empty()
		else ""
	)

	var tipo_lanterna: String = ""

	if ProgressoJogo.possui_lanterna:
		tipo_lanterna = (
			"lanterna_uv"
			if ProgressoJogo.get_meta(
				&"lanterna_tipo",
				"normal"
			) == "uv"
			else "lanterna"
		)

	tipos_nos_espacos.append(tipo_lanterna)

	for indice in range(botoes.size()):
		var tipo: String = tipos_nos_espacos[indice]
		var imagem: Texture2D = obter_imagem(tipo)

		botoes[indice].icon = imagem

		botoes[indice].text = (
			"Vazio"
			if tipo.is_empty()
			else (
				obter_nome(tipo)
				if imagem == null
				else ""
			)
		)


func obter_imagem(tipo: String) -> Texture2D:
	match tipo:
		"notebook":
			return imagem_notebook
		"alicate":
			return imagem_alicate
		"taser":
			return imagem_taser
		"arma_choque":
			return imagem_arma_choque
		"fusivel":
			return imagem_fusivel
		"lanterna":
			return imagem_lanterna
		"lanterna_uv":
			return imagem_lanterna_uv

	return null


func obter_nome(tipo: String) -> String:
	var nomes: Dictionary = {
		"notebook": "Notebook",
		"alicate": "Alicate",
		"taser": "Taser",
		"arma_choque": "Arma de choque",
		"fusivel": "Fusível",
		"lanterna": "Lanterna normal",
		"lanterna_uv": "Lanterna UV"
	}

	return String(nomes.get(tipo, tipo))


func mostrar_item(indice: int) -> void:
	if indice < 0 or indice >= tipos_nos_espacos.size():
		return

	var tipo: String = tipos_nos_espacos[indice]

	var textos: Dictionary = {
		"notebook": (
			"Permite acessar terminais e abrir portas eletrônicas."
		),
		"alicate": (
			"Permite cortar grades preparadas para a ferramenta."
		),
		"taser": (
			"Equipado. Dispara eletricidade contra até dois alvos."
		),
		"arma_choque": (
			"Equipada. Disparo elétrico potente contra um alvo."
		),
		"fusivel": (
			"Quadro correspondente: "
			+ identificador_fusivel_carregado
		),
		"lanterna": (
			"Ilumina ambientes escuros enquanto segura o botão."
		),
		"lanterna_uv": (
			"Luz roxa. Afasta zumbis em salas claras e escuras "
			+ "enquanto tem bateria. Não causa dano."
		)
	}

	descricao.text = (
		"Este espaço está vazio."
		if tipo.is_empty()
		else (
			obter_nome(tipo)
			+ "\n"
			+ String(textos.get(tipo, ""))
		)
	)
