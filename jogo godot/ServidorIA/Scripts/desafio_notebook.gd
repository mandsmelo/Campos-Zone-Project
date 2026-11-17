extends CanvasLayer

signal desafio_finalizado(sucesso: bool)

@export_group("Texto")
@export_range(16, 40, 1) var tamanho_codigo: int = 25

var ativo: bool = false
var pausa_anterior: bool = false

var raiz: Control
var texto_codigo: RichTextLabel
var texto_instrucao: Label
var botoes: Array[Button] = []

var resposta_correta: int = 0
var ultimo_desafio: int = -1
var tempo_abertura: float = 0.0

const DESAFIOS: Array[Dictionary] = [
	{
		"codigo": "energia = 4 + 3 * 2\nprint(energia)",
		"opcoes": ["14", "10", "11"],
		"correta": 1
	},
	{
		"codigo": "resto = 17 % 5\nprint(resto)",
		"opcoes": ["2", "3", "5"],
		"correta": 0
	},
	{
		"codigo": "resultado = 17 // 5\nprint(resultado)",
		"opcoes": ["2", "3.4", "3"],
		"correta": 2
	},
	{
		"codigo": "senha = \"TI\" + \"07\"\nprint(senha)",
		"opcoes": ["TI 07", "TI07", "07TI"],
		"correta": 1
	},
	{
		"codigo": "portas = [2, 4, 6]\nprint(portas[1])",
		"opcoes": ["2", "4", "6"],
		"correta": 1
	},
	{
		"codigo": "itens = [\"chave\", \"pilha\", \"fio\"]\nprint(len(itens))",
		"opcoes": ["2", "4", "3"],
		"correta": 2
	},
	{
		"codigo": "total = 0\nfor numero in range(4):\n    total += numero\nprint(total)",
		"opcoes": ["6", "10", "4"],
		"correta": 0
	},
	{
		"codigo": "energia = 8\nif energia >= 5:\n    print(\"ABERTA\")\nelse:\n    print(\"FECHADA\")",
		"opcoes": ["FECHADA", "ABERTA", "8"],
		"correta": 1
	},
	{
		"codigo": "def acesso(numero):\n    return numero * 2 + 1\n\nprint(acesso(3))",
		"opcoes": ["6", "9", "7"],
		"correta": 2
	},
	{
		"codigo": "numero = 1\nwhile numero < 5:\n    numero += 2\nprint(numero)",
		"opcoes": ["5", "3", "7"],
		"correta": 0
	},
	{
		"codigo": "tem_chave = True\nsem_energia = False\nprint(tem_chave and not sem_energia)",
		"opcoes": ["False", "True", "None"],
		"correta": 1
	},
	{
		"codigo": "codigo = \"CAMPUS\"\nprint(codigo[:3])",
		"opcoes": ["AMP", "CAMP", "CAM"],
		"correta": 2
	},
	{
		"codigo": "numeros = [3, 1, 2]\nnumeros.sort()\nprint(numeros[0])",
		"opcoes": ["1", "2", "3"],
		"correta": 0
	},
	{
		"codigo": "porta = {\"senha\": 42, \"andar\": 2}\nprint(porta[\"senha\"])",
		"opcoes": ["2", "42", "senha"],
		"correta": 1
	},
	{
		"codigo": "senha = \"2468\"\nif len(senha) == ____:\n    print(\"ACESSO LIBERADO\")",
		"opcoes": ["3", "5", "4"],
		"correta": 2,
		"instrucao": "Complete o espaço para exibir ACESSO LIBERADO."
	}
]


func _ready() -> void:
	# Continua recebendo comandos mesmo com o cenário pausado.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	criar_interface()
	raiz.hide()


func criar_interface() -> void:
	raiz = Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(raiz)

	var fundo := ColorRect.new()
	fundo.color = Color.WHITE
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(fundo)

	var margem := MarginContainer.new()
	margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	margem.add_theme_constant_override("margin_left", 60)
	margem.add_theme_constant_override("margin_right", 60)
	margem.add_theme_constant_override("margin_top", 30)
	margem.add_theme_constant_override("margin_bottom", 25)

	raiz.add_child(margem)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 12)
	margem.add_child(coluna)

	var titulo := Label.new()
	titulo.text = "TERMINAL DE ACESSO"
	titulo.add_theme_color_override("font_color", Color.BLACK)
	titulo.add_theme_font_size_override("font_size", 28)
	coluna.add_child(titulo)

	texto_instrucao = Label.new()
	texto_instrucao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto_instrucao.add_theme_color_override("font_color", Color.BLACK)
	texto_instrucao.add_theme_font_size_override("font_size", 20)
	coluna.add_child(texto_instrucao)

	# RichTextLabel possui rolagem própria.
	texto_codigo = RichTextLabel.new()
	texto_codigo.bbcode_enabled = false
	texto_codigo.scroll_active = true
	texto_codigo.fit_content = false
	texto_codigo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	texto_codigo.custom_minimum_size.y = 120

	texto_codigo.add_theme_color_override(
		"default_color",
		Color.BLACK
	)

	texto_codigo.add_theme_font_size_override(
		"normal_font_size",
		tamanho_codigo
	)

	var fonte := SystemFont.new()
	fonte.font_names = PackedStringArray(["monospace"])

	texto_codigo.add_theme_font_override("normal_font", fonte)
	coluna.add_child(texto_codigo)

	for indice in range(3):
		var botao := Button.new()
		botao.custom_minimum_size.y = 48
		botao.add_theme_font_size_override("font_size", 21)

		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.93, 0.93, 0.93)

		var selecionado := StyleBoxFlat.new()
		selecionado.bg_color = Color(0.7, 0.84, 1.0)
		selecionado.border_color = Color(0.1, 0.3, 0.6)
		selecionado.set_border_width_all(3)

		botao.add_theme_stylebox_override("normal", normal)
		botao.add_theme_stylebox_override("hover", selecionado)
		botao.add_theme_stylebox_override("focus", selecionado)
		botao.add_theme_stylebox_override("pressed", selecionado)

		botao.add_theme_color_override("font_color", Color.BLACK)
		botao.add_theme_color_override("font_focus_color", Color.BLACK)
		botao.add_theme_color_override("font_hover_color", Color.BLACK)
		botao.add_theme_color_override("font_pressed_color", Color.BLACK)

		botao.pressed.connect(responder.bind(indice))

		coluna.add_child(botao)
		botoes.append(botao)

	for indice in range(botoes.size()):
		var anterior: Button = botoes[
			(indice + botoes.size() - 1) % botoes.size()
		]

		var proximo: Button = botoes[
			(indice + 1) % botoes.size()
		]

		botoes[indice].focus_neighbor_top = (
			botoes[indice].get_path_to(anterior)
		)

		botoes[indice].focus_neighbor_bottom = (
			botoes[indice].get_path_to(proximo)
		)

	var ajuda := Label.new()
	ajuda.text = (
		"↑ ↓ / Direcional: escolher    A / Enter: confirmar"
		+ "    B / Esc: sair\n"
		+ "Para rolar o código: Page Up / Page Down ou roda do mouse."
	)
	ajuda.add_theme_color_override("font_color", Color.BLACK)
	ajuda.add_theme_font_size_override("font_size", 17)
	coluna.add_child(ajuda)


func iniciar_desafio(player: CharacterBody2D) -> bool:
	if ativo or not is_instance_valid(player):
		return false

	ativo = true
	tempo_abertura = 0.2

	var indice: int = randi_range(0, DESAFIOS.size() - 1)

	while indice == ultimo_desafio and DESAFIOS.size() > 1:
		indice = randi_range(0, DESAFIOS.size() - 1)

	ultimo_desafio = indice

	var desafio: Dictionary = DESAFIOS[indice]
	var opcoes: Array = desafio["opcoes"]

	resposta_correta = int(desafio["correta"])

	texto_codigo.text = String(desafio["codigo"])
	texto_codigo.scroll_to_line(0)

	texto_instrucao.text = String(
		desafio.get(
			"instrucao",
			"Qual resultado este código Python exibe?"
		)
	)

	for i in range(botoes.size()):
		botoes[i].text = "%s — %s" % [i + 1, opcoes[i]]

	player.velocity = Vector2.ZERO

	pausa_anterior = get_tree().paused
	get_tree().paused = true

	raiz.show()
	botoes[0].grab_focus()

	return true


func _process(delta: float) -> void:
	tempo_abertura = maxf(tempo_abertura - delta, 0.0)


func _input(event: InputEvent) -> void:
	if not ativo:
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		finalizar(false)


func responder(indice: int) -> void:
	if not ativo or tempo_abertura > 0.0:
		return

	if indice != resposta_correta:
		texto_instrucao.text = (
			"Acesso negado. Confira o código e tente outra resposta."
		)
		return

	finalizar(true)


func finalizar(sucesso: bool) -> void:
	ativo = false
	raiz.hide()

	get_tree().paused = pausa_anterior
	desafio_finalizado.emit(sucesso)
