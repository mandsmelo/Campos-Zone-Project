extends Node

@export_group("Referências")
@export var player: CharacterBody2D
@export var caixa_dialogo: Node
@export var explosao: Node
@export var lanterna: Node

@export_group("Áreas de interação")
@export var area_stella: Area2D
@export var area_coordenador: Area2D

@export_group("Personagens")
@export var nome_personagem: String = "Cromos"
@export var nome_stella: String = "Stella"
@export var identificador_jogador: StringName = &"jogador_1"

@export_group("Interação")
@export var acao_interagir: StringName = &"interagir"

# Ative apenas para testar sem executar a explosão.
@export var liberar_sem_explosao: bool = false

var configurado: bool = false
var interacoes_liberadas: bool = false
var conversando: bool = false
var tempo_bloqueio: float = 0.0


func _ready() -> void:
	if not is_instance_valid(player):
		push_error("Interações: preencha Player.")
		return

	if not is_instance_valid(caixa_dialogo):
		push_error("Interações: preencha Caixa Dialogo.")
		return

	if (
		not caixa_dialogo.has_method("iniciar_dialogo")
		or not caixa_dialogo.has_signal("dialogo_finalizado")
	):
		push_error("Interações: confira o script da caixa de diálogo.")
		return

	if (
		not is_instance_valid(area_stella)
		or not is_instance_valid(area_coordenador)
	):
		push_error(
			"Interações: preencha Área Stella e Área Coordenador."
		)
		return

	if not InputMap.has_action(acao_interagir):
		push_error("Interações: a ação de interação não existe.")
		return

	if not is_instance_valid(lanterna):
		lanterna = player.get_node_or_null("Lanterna")

	area_stella.monitoring = true
	area_coordenador.monitoring = true

	if is_instance_valid(explosao):
		if explosao.has_signal("explosao_finalizada"):
			var chamada := Callable(self, "liberar_interacoes")

			if not explosao.is_connected(
				"explosao_finalizada",
				chamada
			):
				explosao.connect(
					"explosao_finalizada",
					chamada
				)

	interacoes_liberadas = (
		liberar_sem_explosao
		or ProgressoJogo.get_meta(
			&"explosao_cena2_concluida",
			false
		) == true
	)

	configurado = true


func liberar_interacoes() -> void:
	interacoes_liberadas = true


func _physics_process(delta: float) -> void:
	if not configurado or not interacoes_liberadas:
		return

	if conversando:
		return

	if not is_instance_valid(player):
		return

	if not is_instance_valid(caixa_dialogo):
		return

	if (
		caixa_dialogo.get("ativo") == true
		or not player.is_physics_processing()
	):
		tempo_bloqueio = 0.2
		return

	tempo_bloqueio = maxf(tempo_bloqueio - delta, 0.0)

	if tempo_bloqueio > 0.0:
		return

	if not Input.is_action_just_pressed(acao_interagir):
		return

	var perto_stella: bool = (Cooperativo.jogador_na_interacao(area_stella, player) != null)
	var perto_coordenador: bool = (
		(Cooperativo.jogador_na_interacao(area_coordenador, player) != null)
	)

	if not perto_stella and not perto_coordenador:
		return

	# Se as áreas se sobrepõem, conversa com o mais próximo.
	if perto_stella and perto_coordenador:
		var distancia_stella: float = (
			player.global_position.distance_squared_to(
				area_stella.global_position
			)
		)

		var distancia_coordenador: float = (
			player.global_position.distance_squared_to(
				area_coordenador.global_position
			)
		)

		perto_stella = distancia_stella <= distancia_coordenador

	conversando = true

	if perto_stella:
		await conversar_stella()
	else:
		await conversar_coordenador()

	conversando = false
	tempo_bloqueio = 0.2


func conversar_stella() -> void:
	if not ProgressoJogo.stella_apresentada:
		await apresentar_stella()
		return

	if possui_alguma_ferramenta():
		if ProgressoJogo.get_meta(
			&"stella_orientou_saida",
			false
		) != true:
			await conversar_apos_exploracao()
		else:
			await mostrar_falas([
				{
					"nome": nome_stella,
					"texto": "Confira as portas e as grades. Uma das ferramentas pode abrir uma passagem até a TI.",
					"tipo": 0
				}
			])

		return

	if ProgressoJogo.enfermaria_verificada:
		await mostrar_falas([
			{
				"nome": nome_stella,
				"texto": "Se a passagem está bloqueada, procure algo útil nas salas próximas. Precisamos encontrar outra saída.",
				"tipo": 0
			}
		])
	else:
		await mostrar_falas([
			{
				"nome": nome_stella,
				"texto": "Você já verificou a enfermaria?",
				"tipo": 0
			},
			{
				"nome": nome_personagem,
				"texto": "Ainda não.",
				"tipo": 0
			},
			{
				"nome": nome_stella,
				"texto": "Vá com cuidado. Precisamos encontrar uma saída e pedir ajuda para o coordenador.",
				"tipo": 0
			}
		])


func apresentar_stella() -> void:
	await mostrar_falas([
		{
			"nome": "ESTUDANTE",
			"texto": "Você está bem? Meu nome é %s." % nome_stella,
			"tipo": 0
		},
		{
			"nome": nome_personagem,
			"texto": "Sou %s. O coordenador ficou preso nos escombros. Precisamos buscar ajuda." % nome_personagem,
			"tipo": 0
		},
		{
			"nome": nome_stella,
			"texto": "Leve esta lanterna. A sala dos fundos está sem energia. Ela pode ajudar você a enxergar.",
			"tipo": 0
		}
	])

	# Entrega a lanterna e mantém a posse entre as cenas.
	ProgressoJogo.possui_lanterna = true

	if not is_instance_valid(lanterna):
		lanterna = player.get_node_or_null("Lanterna")

	if is_instance_valid(lanterna):
		if lanterna.has_method("pegar_lanterna"):
			lanterna.call("pegar_lanterna")

	await mostrar_falas([
		{
			"nome": "",
			"texto": "Você recebeu uma lanterna. Segure o botão da lanterna para iluminar locais escuros.",
			"tipo": 2
		},
		{
			"nome": nome_stella,
			"texto": "Tranquei a enfermaria quando saí. Aqui está a chave.",
			"tipo": 0
		},
		{
			"nome": nome_personagem,
			"texto": "Vou verificar o que aconteceu e procurar uma saída.",
			"tipo": 0
		},
		{
			"nome": nome_stella,
			"texto": "Tome cuidado. As pessoas lá dentro estavam muito estranhas.",
			"tipo": 0
		}
	])

	ProgressoJogo.possui_chave_enfermaria = true

	# Compatibilidade com portas antigas que consultavam o player.
	player.set_meta(&"possui_chave_enfermaria", true)

	ProgressoJogo.stella_apresentada = true

	await mostrar_falas([
		{
			"nome": "",
			"texto": "Você recebeu a chave da enfermaria.",
			"tipo": 2
		}
	])


func conversar_apos_exploracao() -> void:
	await mostrar_falas([
		{
			"nome": nome_stella,
			"texto": "Você encontrou alguém que pudesse ajudar?",
			"tipo": 0
		},
		{
			"nome": nome_personagem,
			"texto": "Não. As pessoas lá dentro perderam o controle. Tentaram me atacar... pareciam querer me devorar.",
			"tipo": 0
		},
		{
			"nome": nome_stella,
			"texto": "E a passagem para o outro lado?",
			"tipo": 0
		},
		{
			"nome": nome_personagem,
			"texto": "Está bloqueada por mesas. Não consegui passar, mas encontrei algumas ferramentas.",
			"tipo": 0
		},
		{
			"nome": nome_stella,
			"texto": "As outras portas estão trancadas. Veja se consegue abrir alguma e encontrar um caminho alternativo.",
			"tipo": 0
		},
		{
			"nome": nome_stella,
			"texto": "Existe uma saída de emergência no setor de TI. Talvez você consiga chegar até lá.",
			"tipo": 0
		},
		{
			"nome": "",
			"texto": "Procure uma passagem alternativa. Use o rádio se precisar de orientação sobre as ferramentas.",
			"tipo": 2
		}
	])

	ProgressoJogo.enfermaria_verificada = true
	ProgressoJogo.set_meta(&"stella_orientou_saida", true)


func conversar_coordenador() -> void:
	var texto: String = (
		"Encontre uma saída e peça ajuda. "
		+ "Não tente levantar os escombros sozinho."
	)

	if ProgressoJogo.get_meta(
		&"stella_orientou_saida",
		false
	) == true:
		texto = (
			"Use as ferramentas para procurar outra passagem. "
			+ "A saída de emergência fica no setor de TI."
		)

	await mostrar_falas([
		{
			"nome": "COORDENADOR",
			"texto": texto,
			"tipo": 0
		}
	])


func possui_alguma_ferramenta() -> bool:
	return (
		InventarioJogo.possui_ferramenta(
			identificador_jogador,
			"notebook"
		)
		or InventarioJogo.possui_ferramenta(
			identificador_jogador,
			"alicate"
		)
	)


func mostrar_falas(falas: Array[Dictionary]) -> void:
	caixa_dialogo.call("iniciar_dialogo", falas)
	await Signal(caixa_dialogo, "dialogo_finalizado")
