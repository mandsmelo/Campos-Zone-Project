extends Node

var possui_lanterna: bool = false
var possui_chave_enfermaria: bool = false
var stella_apresentada: bool = false
var enfermaria_verificada: bool = false

var estado_player: Dictionary = {}
var checkpoint: Dictionary = {}

var restaurando_checkpoint: bool = false

var player_acompanhado: CharacterBody2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if restaurando_checkpoint:
		return

	if not is_instance_valid(player_acompanhado):
		return

	if not player_acompanhado.is_inside_tree():
		return

	if player_acompanhado.get("morto") == true:
		return

	# Atualiza a carga enquanto o personagem está na sala.
	# Também captura a energia consumida pelas armas.
	var lanterna: Node = player_acompanhado.get_node_or_null(
		"Lanterna"
	)

	if not is_instance_valid(lanterna):
		return

	var bateria: Variant = lanterna.get("bateria_atual")

	if bateria != null:
		estado_player["bateria"] = float(bateria)


# ==========================================
# NOVA PARTIDA
# ==========================================

func reiniciar() -> void:
	player_acompanhado = null

	possui_lanterna = false
	possui_chave_enfermaria = false
	stella_apresentada = false
	enfermaria_verificada = false

	estado_player.clear()
	checkpoint.clear()
	restaurando_checkpoint = false

	for chave in get_meta_list():
		remove_meta(chave)

	InventarioJogo.reiniciar()


# ==========================================
# ACOMPANHAMENTO DO PERSONAGEM
# ==========================================

func acompanhar_player(player: CharacterBody2D) -> void:
	if not is_instance_valid(player):
		return

	player_acompanhado = player

	var chamada: Callable = Callable(
		self,
		"ao_player_sair_da_arvore"
	).bind(player)

	if not player.tree_exiting.is_connected(chamada):
		player.tree_exiting.connect(chamada)


func ao_player_sair_da_arvore(
	player: CharacterBody2D
) -> void:
	if restaurando_checkpoint:
		return

	if not is_instance_valid(player):
		return

	if player.get("morto") != true:
		salvar_estado_player(player)

	if player_acompanhado == player:
		player_acompanhado = null


# ==========================================
# ESTADO DO PERSONAGEM
# ==========================================

func capturar_estado_player(
	player: CharacterBody2D
) -> Dictionary:
	# Preserva os valores já registrados.
	# Se Lanterna não estiver disponível durante a saída,
	# a bateria anterior não será apagada.
	var dados: Dictionary = estado_player.duplicate(true)

	dados["vida"] = int(player.get("vida_atual"))
	dados["stamina"] = float(player.get("stamina_atual"))

	dados["stamina_esgotada"] = bool(
		player.get("stamina_esgotada")
	)

	dados["espera_stamina"] = float(
		player.get("tempo_espera_recuperacao")
	)

	var lanterna: Node = player.get_node_or_null("Lanterna")

	if is_instance_valid(lanterna):
		var bateria: Variant = lanterna.get("bateria_atual")

		if bateria != null:
			dados["bateria"] = float(bateria)

	return dados


func salvar_estado_player(
	player: CharacterBody2D
) -> void:
	if restaurando_checkpoint:
		return

	if not is_instance_valid(player):
		return

	if player.get("morto") == true:
		return

	estado_player = capturar_estado_player(player)


func aplicar_estado_player(
	player: CharacterBody2D
) -> void:
	if not is_instance_valid(player):
		return

	if not estado_player.is_empty():
		var vida_maxima: int = maxi(
			int(player.get("vida_maxima")),
			1
		)

		var stamina_maxima: float = maxf(
			float(player.get("stamina_maxima")),
			1.0
		)

		player.set(
			"vida_atual",
			clampi(
				int(estado_player.get("vida", vida_maxima)),
				1,
				vida_maxima
			)
		)

		player.set(
			"stamina_atual",
			clampf(
				float(
					estado_player.get(
						"stamina",
						stamina_maxima
					)
				),
				0.0,
				stamina_maxima
			)
		)

		player.set(
			"stamina_esgotada",
			bool(
				estado_player.get(
					"stamina_esgotada",
					false
				)
			)
		)

		player.set(
			"tempo_espera_recuperacao",
			float(
				estado_player.get("espera_stamina", 0.0)
			)
		)

		aplicar_bateria(player)

		if player.has_method("atualizar_indicador_stamina"):
			player.call("atualizar_indicador_stamina")

		if player.has_signal("vida_alterada"):
			player.emit_signal(
				"vida_alterada",
				int(player.get("vida_atual"))
			)

	acompanhar_player(player)


func aplicar_bateria(player: CharacterBody2D) -> void:
	if not estado_player.has("bateria"):
		return

	var lanterna: Node = player.get_node_or_null("Lanterna")

	if not is_instance_valid(lanterna):
		return

	var capacidade: Variant = lanterna.get("bateria_maxima")

	if capacidade == null:
		return

	lanterna.set(
		"bateria_atual",
		clampf(
			float(estado_player["bateria"]),
			0.0,
			maxf(float(capacidade), 1.0)
		)
	)

	if lanterna.has_method("atualizar_indicador_bateria"):
		lanterna.call("atualizar_indicador_bateria")


# ==========================================
# CHECKPOINT
# ==========================================

func registrar_checkpoint(
	player: CharacterBody2D
) -> void:
	var cena: Node = get_tree().current_scene

	if (
		not is_instance_valid(cena)
		or not is_instance_valid(player)
	):
		return

	aplicar_estado_player(player)

	if restaurando_checkpoint:
		restaurando_checkpoint = false
		return

	estado_player = capturar_estado_player(player)

	var metadados: Dictionary = {}

	for chave in get_meta_list():
		if chave == &"chegada_pendente":
			continue

		metadados[chave] = get_meta(chave)

	checkpoint = {
		"cena": cena.scene_file_path,
		"posicao": player.global_position,
		"direcao": player.get("ultima_direcao"),
		"player": estado_player.duplicate(true),

		"progresso": {
			"possui_lanterna": possui_lanterna,
			"possui_chave_enfermaria": possui_chave_enfermaria,
			"stella_apresentada": stella_apresentada,
			"enfermaria_verificada": enfermaria_verificada
		},

		"metadados": metadados.duplicate(true),

		"ferramentas": (
			InventarioJogo.ferramentas_por_jogador.duplicate(true)
		),

		"armas": (
			InventarioJogo.armas_por_jogador.duplicate(true)
		),

		"objetos_recolhidos": (
			InventarioJogo.objetos_recolhidos.duplicate(true)
		)
	}


# ==========================================
# MORTE E RESTAURAÇÃO
# ==========================================

func restaurar_apos_morte() -> void:
	if restaurando_checkpoint:
		return

	if checkpoint.is_empty():
		push_error(
			"Checkpoint: nenhum checkpoint registrado. "
			+ "Confira o nó ChegadaSala."
		)
		return

	restaurando_checkpoint = true
	player_acompanhado = null

	var progresso: Dictionary = checkpoint.get(
		"progresso",
		{}
	)

	possui_lanterna = bool(
		progresso.get("possui_lanterna", false)
	)

	possui_chave_enfermaria = bool(
		progresso.get("possui_chave_enfermaria", false)
	)

	stella_apresentada = bool(
		progresso.get("stella_apresentada", false)
	)

	enfermaria_verificada = bool(
		progresso.get("enfermaria_verificada", false)
	)

	for chave in get_meta_list():
		remove_meta(chave)

	var metadados: Dictionary = checkpoint.get(
		"metadados",
		{}
	)

	for chave in metadados:
		var valor: Variant = metadados[chave]

		if valor is Dictionary or valor is Array:
			set_meta(chave, valor.duplicate(true))
		else:
			set_meta(chave, valor)

	var dados_player: Dictionary = checkpoint.get(
		"player",
		{}
	)

	estado_player = dados_player.duplicate(true)

	var ferramentas: Dictionary = checkpoint.get(
		"ferramentas",
		{}
	)

	var armas: Dictionary = checkpoint.get(
		"armas",
		{}
	)

	var objetos: Dictionary = checkpoint.get(
		"objetos_recolhidos",
		{}
	)

	InventarioJogo.ferramentas_por_jogador = (
		ferramentas.duplicate(true)
	)

	InventarioJogo.armas_por_jogador = (
		armas.duplicate(true)
	)

	InventarioJogo.objetos_recolhidos = (
		objetos.duplicate(true)
	)

	call_deferred("recarregar_checkpoint")


func recarregar_checkpoint() -> void:
	var caminho: String = String(
		checkpoint.get("cena", "")
	)

	if caminho.is_empty():
		restaurando_checkpoint = false
		push_error("Checkpoint: cena registrada vazia.")
		return

	var erro: Error = get_tree().change_scene_to_file(
		caminho
	)

	if erro != OK:
		restaurando_checkpoint = false

		push_error(
			"Checkpoint: erro ao recarregar a sala: %s"
			% erro
		)
