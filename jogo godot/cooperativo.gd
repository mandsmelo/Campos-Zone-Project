extends Node

var ativo: bool = false
var principal: CharacterBody2D
var segundo: CharacterBody2D
var cena_anterior: Node
var preparando: bool = false
var camera: Camera2D
var zoom_original: Vector2 = Vector2.ONE
var comandos_originais: Dictionary = {}
var dispositivos: Array[int] = []
var espera_cena: int = 0
var posicao_anterior_principal: Vector2
var acompanhando_cutscene: bool = false
var evento_interacao: InputEvent

const ACOES: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down",
	&"correr", &"rastejar", &"pular", &"lanterna", &"atirar", &"interagir"
]

func _ready() -> void:
	Input.joy_connection_changed.connect(controle_alterado)

func definir_modo(coop: bool) -> bool:
	if coop and Input.get_connected_joypads().size() < 2:
		mostrar_aviso()
		return false
	ativo = coop
	configurar_comandos()
	return true

func mostrar_aviso() -> void:
	var tela := CanvasLayer.new()
	tela.layer = 200
	var painel := AcceptDialog.new()
	painel.title = "Modo cooperativo"
	painel.dialog_text = "Conecte dois controles para iniciar o modo cooperativo."
	tela.add_child(painel)
	get_tree().root.add_child(tela)
	painel.popup_centered()
	painel.confirmed.connect(tela.queue_free)
	painel.canceled.connect(tela.queue_free)

func controle_alterado(_id: int, _conectado: bool) -> void:
	if ativo:
		configurar_comandos()

func configurar_comandos() -> void:
	var conectados: Array[int] = Input.get_connected_joypads()
	# Uma desconexão não deve trocar o dono do outro personagem.
	if dispositivos.is_empty():
		for id in conectados:
			if dispositivos.size() < 2:
				dispositivos.append(id)
	else:
		for id in conectados:
			if dispositivos.has(id):
				continue
			var vaga: int = -1
			for i in range(dispositivos.size()):
				if not conectados.has(dispositivos[i]):
					vaga = i
					break
			if vaga >= 0:
				dispositivos[vaga] = id
			elif dispositivos.size() < 2:
				dispositivos.append(id)
	for acao in ACOES:
		if not InputMap.has_action(acao):
			continue
		for numero in [1, 2]:
			var nome := StringName("coop_p%d_%s" % [numero, acao])
			if not InputMap.has_action(nome):
				InputMap.add_action(nome, InputMap.action_get_deadzone(acao))
			InputMap.action_erase_events(nome)
			for evento in InputMap.action_get_events(acao):
				if evento is InputEventJoypadButton or evento is InputEventJoypadMotion:
					if dispositivos.size() >= numero:
						var copia: InputEvent = evento.duplicate()
						copia.device = dispositivos[numero - 1]
						InputMap.action_add_event(nome, copia)
	# As interações existentes ficam com o controle do primeiro jogador.
	for acao in [&"inventario"]:
		if not InputMap.has_action(acao):
			continue
		if not comandos_originais.has(acao):
			comandos_originais[acao] = InputMap.action_get_events(acao)
		InputMap.action_erase_events(acao)
		for evento in comandos_originais[acao]:
			var copia: InputEvent = evento.duplicate()
			if ativo and (copia is InputEventJoypadButton or copia is InputEventJoypadMotion):
				copia.device = dispositivos[0] if dispositivos.size() > 0 else 999
			InputMap.action_add_event(acao, copia)

func bloqueado() -> bool:
	return not is_instance_valid(principal) or not principal.is_physics_processing()

func _process(_delta: float) -> void:
	if not ativo:
		return
	var cena := get_tree().current_scene
	if not is_instance_valid(cena):
		return
	if cena != cena_anterior:
		cena_anterior = cena
		principal = null
		segundo = null
		camera = null
		espera_cena = 3
	if espera_cena > 0:
		espera_cena -= 1
		return
	if not is_instance_valid(principal):
		principal = cena.get_node_or_null("Player") as CharacterBody2D
	if not is_instance_valid(principal):
		return
	if not is_instance_valid(segundo) and not preparando:
		preparando = true
		call_deferred("criar_segundo", cena)
	if is_instance_valid(segundo):
		atualizar_acompanhamento()
	if is_instance_valid(camera) and is_instance_valid(segundo):
		camera.global_position = (principal.global_position + segundo.global_position) / 2.0
		var tamanho := get_viewport().get_visible_rect().size - Vector2(160, 160)
		var distancia := (principal.global_position - segundo.global_position).abs() + Vector2(100, 100)
		var fator := minf(zoom_original.x, minf(maxf(tamanho.x, 100.0) / distancia.x, maxf(tamanho.y, 100.0) / distancia.y))
		camera.zoom = Vector2.ONE * maxf(fator, 0.05)

func criar_segundo(cena: Node) -> void:
	preparando = false
	if cena != get_tree().current_scene or not is_instance_valid(principal):
		return
	var recurso := load("res://Cenas/player.tscn") as PackedScene
	segundo = recurso.instantiate() as CharacterBody2D
	segundo.name = "Player2"
	segundo.set("numero_jogador", 2)
	# P2 não deve escrever no HUD nem criar outra escuridão global.
	var lanterna := segundo.get_node_or_null("Lanterna")
	if lanterna != null:
		lanterna.free()
	var camera_p2 := segundo.get_node_or_null("Camera2D") as Camera2D
	if camera_p2 != null:
		camera_p2.enabled = false
	for filho in segundo.get_children():
		if filho.get_script() != null and filho.get_script().resource_path.ends_with("combate_eletrico.gd"):
			filho.free()
	cena.add_child(segundo)
	segundo.global_position = principal.global_position
	# Procura espaço livre para não nascer dentro de paredes.
	for deslocamento in [Vector2(24, 0), Vector2(-24, 0), Vector2(0, 24), Vector2(0, -24)]:
		if not principal.test_move(principal.global_transform, deslocamento):
			segundo.global_position += deslocamento
			break
	posicao_anterior_principal = principal.global_position
	principal.add_collision_exception_with(segundo)
	segundo.add_collision_exception_with(principal)
	var visual := segundo.get_node("AnimatedSprite2D") as AnimatedSprite2D
	visual.self_modulate = Color(0.65, 0.85, 1.0)
	camera = principal.get_node_or_null("Camera2D") as Camera2D
	if is_instance_valid(camera):
		zoom_original = camera.zoom
		camera.make_current()


func jogadores() -> Array[CharacterBody2D]:
	var lista: Array[CharacterBody2D] = []
	for jogador in [principal, segundo]:
		if is_instance_valid(jogador) and jogador.is_inside_tree() and jogador.get("morto") != true:
			lista.append(jogador)
	return lista

func _input(event: InputEvent) -> void:
	# Retém o dispositivo até os scripts _unhandled_input consultarem a área.
	if ativo and event.is_action_pressed("interagir") and not event.is_echo():
		evento_interacao = event
		call_deferred("limpar_evento", event)

func limpar_evento(event: InputEvent) -> void:
	if evento_interacao == event:
		evento_interacao = null

func jogador_na_interacao(area: Area2D, padrao: CharacterBody2D) -> CharacterBody2D:
	if not ativo:
		return padrao if is_instance_valid(padrao) and area.overlaps_body(padrao) else null
	for jogador in jogadores():
		if not jogador.is_physics_processing() or not area.overlaps_body(jogador):
			continue
		var numero: int = int(jogador.get("numero_jogador"))
		var acao := StringName("coop_p%d_interagir" % numero)
		if evento_interacao != null:
			if evento_interacao is InputEventJoypadButton or evento_interacao is InputEventJoypadMotion:
				if dispositivos.size() >= numero and evento_interacao.device == dispositivos[numero - 1]:
					return jogador
			elif numero == 1:
				return jogador
		elif InputMap.has_action(acao) and Input.is_action_just_pressed(acao):
			return jogador
	return null

func atualizar_acompanhamento() -> void:
	var movimento := principal.global_position - posicao_anterior_principal
	if bloqueado():
		if movimento.length_squared() > 0.0001:
			# Trajetória da cutscene deslocada dois tiles para cima.
			segundo.global_position = principal.global_position + Vector2(0, -32)
			segundo.set("ultima_direcao", movimento.normalized())
			segundo.set("estado_movimento", &"andando")
			segundo.call("animacao_andando", movimento.normalized(), false)
			acompanhando_cutscene = true
		else:
			segundo.set("ultima_direcao", principal.get("ultima_direcao"))
			segundo.set("estado_movimento", &"parado")
			segundo.call("animacao_parado")
	else:
		acompanhando_cutscene = false
	posicao_anterior_principal = principal.global_position
