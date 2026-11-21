extends CanvasLayer

@export var endereco_api: String = "http://127.0.0.1:8000"
var tela: Control
var resposta: RichTextLabel
var pergunta: LineEdit
var http: HTTPRequest
var ocupado: bool = false
var tipo_pedido: String = ""
var pausa_anterior: bool = false
var campos: Dictionary = {}
var botoes: Array[Button] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 180
	http = HTTPRequest.new()
	http.timeout = 30.0
	add_child(http)
	http.request_completed.connect(receber_resposta)
	criar_interface()
	tela.hide()

func criar_interface() -> void:
	tela = Control.new()
	tela.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(tela)
	var fundo := ColorRect.new()
	fundo.color = Color(0.03, 0.04, 0.08, 0.98)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tela.add_child(fundo)
	var margem := MarginContainer.new()
	margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 20)
	tela.add_child(margem)
	var coluna := VBoxContainer.new()
	margem.add_child(coluna)
	var titulo := Label.new()
	titulo.text = "CAMPOS ZONE — ASSISTENTE IA | F1 ou Esc: fechar"
	coluna.add_child(titulo)
	var linha := HBoxContainer.new()
	coluna.add_child(linha)
	pergunta = LineEdit.new()
	pergunta.placeholder_text = "Digite uma dúvida sobre o jogo..."
	pergunta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(pergunta)
	pergunta.text_submitted.connect(perguntar)
	botao(linha, "Perguntar", func(): perguntar(pergunta.text))
	botao(linha, "Verificar API", func(): enviar("saude", "/health"))
	var aviso := Label.new()
	aviso.text = "Previsão: preencha as métricas abaixo manualmente. O modelo foi treinado com dados simulados."
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(aviso)
	var rolagem := ScrollContainer.new()
	rolagem.custom_minimum_size.y = 165
	coluna.add_child(rolagem)
	var grade := GridContainer.new()
	grade.columns = 2
	grade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.add_child(grade)
	for item in [["distancia_percorrida_unidades", "Distância (unidades Godot)"], ["dano_recebido", "Dano recebido (impactos)"], ["itens_coletados", "Itens coletados"], ["salas_exploradas", "Salas exploradas"], ["tempo_decorrido_min", "Tempo decorrido (minutos)"]]:
		var rotulo := Label.new()
		rotulo.text = item[1]
		grade.add_child(rotulo)
		var numero := SpinBox.new()
		numero.max_value = 1000000
		numero.step = 0.1 if item[0] in ["distancia_percorrida_unidades", "tempo_decorrido_min"] else 1.0
		numero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grade.add_child(numero)
		campos[item[0]] = numero
	var acoes := HBoxContainer.new()
	coluna.add_child(acoes)
	botao(acoes, "Estimar tempo", prever)
	botao(acoes, "Fechar", fechar)
	resposta = RichTextLabel.new()
	resposta.bbcode_enabled = false
	resposta.size_flags_vertical = Control.SIZE_EXPAND_FILL
	resposta.custom_minimum_size.y = 60
	resposta.text = "Inicie o servidor Python antes de consultar. Esta versão não usa Ollama."
	coluna.add_child(resposta)

func botao(pai: Node, texto: String, chamada: Callable) -> void:
	var novo := Button.new()
	novo.text = texto
	novo.pressed.connect(chamada)
	pai.add_child(novo)
	# Fechar permanece disponível mesmo durante uma requisição.
	if texto != "Fechar":
		botoes.append(novo)

func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		get_viewport().set_input_as_handled()
		if tela.visible:
			fechar()
		else:
			abrir()
	elif tela.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		fechar()

func abrir() -> void:
	if get_tree().paused:
		return
	var cena := get_tree().current_scene
	if not is_instance_valid(cena):
		return
	var jogador := cena.get_node_or_null("Player") as CharacterBody2D
	if jogador == null or not jogador.is_physics_processing() or jogador.get("morto") == true:
		return
	pausa_anterior = get_tree().paused
	get_tree().paused = true
	tela.show()
	pergunta.grab_focus()

func fechar() -> void:
	if not tela.visible:
		return
	if ocupado:
		http.cancel_request()
		definir_ocupado(false)
	tela.hide()
	get_tree().paused = pausa_anterior

func definir_ocupado(valor: bool) -> void:
	ocupado = valor
	for item in botoes:
		item.disabled = valor

func perguntar(texto: String) -> void:
	if texto.strip_edges().is_empty():
		resposta.text = "Digite uma pergunta."
		return
	enviar("chat", "/faq/search", {"pergunta": texto.strip_edges(), "controles": obter_controles()})

func prever() -> void:
	var dados: Dictionary = {}
	for chave in campos:
		dados[chave] = campos[chave].value
	for chave in ["dano_recebido", "itens_coletados", "salas_exploradas"]:
		dados[chave] = int(dados[chave])
	enviar("previsao", "/predict/value", dados)

func enviar(tipo: String, rota: String, dados: Dictionary = {}) -> void:
	if ocupado:
		return
	tipo_pedido = tipo
	definir_ocupado(true)
	resposta.text = "Consultando a API..."
	var metodo: int = HTTPClient.METHOD_GET if tipo == "saude" else HTTPClient.METHOD_POST
	var erro: Error = http.request(endereco_api.trim_suffix("/") + rota, ["Content-Type: application/json"], metodo, "" if tipo == "saude" else JSON.stringify(dados))
	if erro != OK:
		definir_ocupado(false)
		resposta.text = "Não foi possível iniciar a requisição. Código: %s" % erro

func receber_resposta(resultado: int, codigo: int, _cabecalhos: PackedStringArray, corpo: PackedByteArray) -> void:
	definir_ocupado(false)
	if resultado != HTTPRequest.RESULT_SUCCESS:
		resposta.text = "API sem resposta. Confira o servidor em %s e confira o terminal da API. Resultado de rede: %s." % [endereco_api, resultado]
		return
	var dados: Variant = JSON.parse_string(corpo.get_string_from_utf8())
	if not dados is Dictionary:
		resposta.text = "A API retornou uma resposta que não é um objeto JSON. HTTP %s." % codigo
		return
	if codigo < 200 or codigo >= 300:
		resposta.text = "HTTP %s: %s" % [codigo, str(dados.get("detail", dados))]
		return
	match tipo_pedido:
		"chat":
			resposta.text = str(dados.get("resposta")) if dados.get("resposta") != null else str(dados.get("mensagem", "Sem resposta disponível."))
		"previsao":
			var previsao: Dictionary = dados.get("previsao", {})
			resposta.text = "Tempo restante estimado: %s minutos.\nMAE de referência: %s minutos.\n%s" % [previsao.get("tempo_restante_minutos", "?"), previsao.get("mae_referencia_minutos", "?"), dados.get("observacao", "")]
		_:
			resposta.text = JSON.stringify(dados, "  ") + "\nConfira se chatbot e regressão estão online; a API pode estar online com um deles indisponível."


func obter_controles() -> Dictionary:
	var mapa: Dictionary = {}
	for acao in ["move_left", "move_right", "move_up", "move_down", "rastejar", "pular", "correr", "lanterna", "interagir", "radio", "inventario", "atirar"]:
		var entradas: Array[String] = []
		if InputMap.has_action(acao):
			for evento in InputMap.action_get_events(acao):
				var texto: String = descrever_botao(evento)
				if not texto.is_empty() and not entradas.has(texto):
					entradas.append(texto)
		mapa[acao] = entradas
	return mapa

func descrever_botao(evento: InputEvent) -> String:
	if evento is InputEventKey:
		var codigo: int = evento.physical_keycode if evento.physical_keycode != 0 else evento.keycode
		return "Teclado: " + OS.get_keycode_string(codigo)
	if evento is InputEventJoypadButton:
		var nomes: Dictionary = {
			JOY_BUTTON_A: "X (PlayStation) / A (Xbox)",
			JOY_BUTTON_B: "Círculo (PlayStation) / B (Xbox)",
			JOY_BUTTON_X: "Quadrado (PlayStation) / X (Xbox)",
			JOY_BUTTON_Y: "Triângulo (PlayStation) / Y (Xbox)",
			JOY_BUTTON_LEFT_SHOULDER: "L1 (PlayStation) / LB (Xbox)",
			JOY_BUTTON_RIGHT_SHOULDER: "R1 (PlayStation) / RB (Xbox)",
			JOY_BUTTON_DPAD_UP: "direcional para cima",
			JOY_BUTTON_DPAD_DOWN: "direcional para baixo",
			JOY_BUTTON_DPAD_LEFT: "direcional para a esquerda",
			JOY_BUTTON_DPAD_RIGHT: "direcional para a direita"
		}
		return "Controle: " + String(nomes.get(evento.button_index, "botão %d" % evento.button_index))
	if evento is InputEventJoypadMotion:
		if evento.axis == JOY_AXIS_TRIGGER_LEFT:
			return "Controle: L2 (PlayStation) / LT (Xbox)"
		if evento.axis == JOY_AXIS_TRIGGER_RIGHT:
			return "Controle: R2 (PlayStation) / RT (Xbox)"
		if evento.axis == JOY_AXIS_LEFT_X:
			return "Controle: analógico esquerdo para " + ("a esquerda" if evento.axis_value < 0 else "a direita")
		if evento.axis == JOY_AXIS_LEFT_Y:
			return "Controle: analógico esquerdo para " + ("cima" if evento.axis_value < 0 else "baixo")
	return evento.as_text()
