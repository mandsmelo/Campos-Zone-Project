extends Node

enum ContextoSala {
	CORREDOR,
	ENFERMAGEM_2,
	OUTRA_SALA
}

@export_group("Referências")
@export var player: CharacterBody2D
@export var caixa_dialogo: Node

@export_group("Jogador")
@export var nome_personagem: String = "Cromos"
@export var identificador_jogador: StringName = &"jogador_1"

@export_group("Rádio")
@export var acao_radio: StringName = &"radio"
@export var radio_disponivel: bool = true

@export_group("Sala atual")
@export var contexto_sala: ContextoSala = ContextoSala.CORREDOR

# Usado para consultar somente a energia do quadro desta sala.
@export var identificador_quadro: StringName = &"enfermagem_2"

var configurado: bool = false
var conversando: bool = false
var tempo_bloqueio: float = 0.0


func _ready() -> void:
	if not is_instance_valid(player):
		push_error("Rádio: preencha Player.")
		return

	if not is_instance_valid(caixa_dialogo):
		push_error("Rádio: preencha Caixa Dialogo.")
		return

	if (
		not caixa_dialogo.has_method("iniciar_dialogo")
		or not caixa_dialogo.has_signal("dialogo_finalizado")
	):
		push_error("Rádio: confira o script da caixa de diálogo.")
		return

	if not InputMap.has_action(acao_radio):
		push_error(
			"Rádio: crie a ação '%s' no Mapa de Entrada."
			% String(acao_radio)
		)
		return

	configurado = true


func _physics_process(delta: float) -> void:
	if not configurado or not radio_disponivel or conversando:
		return

	if not is_instance_valid(player):
		return

	if not is_instance_valid(caixa_dialogo):
		return

	# O rádio fica bloqueado até concluir a apresentação da Stella.
	if not ProgressoJogo.stella_apresentada:
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

	if not Input.is_action_just_pressed(acao_radio):
		return

	conversando = true
	await atender_radio()
	conversando = false

	tempo_bloqueio = 0.2


func atender_radio() -> void:
	var falas: Array[Dictionary] = []
	var chave_conversa: StringName = &""

	var falou_com_stella_apos_exploracao: bool = (
		ProgressoJogo.get_meta(
			&"stella_orientou_saida",
			false
		) == true
	)

	# Esta orientação depende exclusivamente da conversa com Stella.
	# Ligar a energia não libera esta etapa.
	if falou_com_stella_apos_exploracao:
		chave_conversa = &"radio_explicou_ferramentas"

		if ProgressoJogo.get_meta(chave_conversa, false) == true:
			falas = criar_lembrete_saida()
		else:
			falas = criar_explicacao_ferramentas()

	elif possui_alguma_ferramenta():
		falas = [
			fala(
				"COORDENADOR",
				"Conseguiu encontrar alguma coisa?"
			),
			fala(
				nome_personagem,
				"Encontrei ferramentas, mas a passagem está bloqueada."
			),
			fala(
				"COORDENADOR",
				"Volte e converse com a Stella. Ela pode conhecer outro caminho."
			)
		]

	elif contexto_sala == ContextoSala.ENFERMAGEM_2:
		var chave_energia: StringName = StringName(
			"energia_" + String(identificador_quadro)
		)

		var chave_fusivel: StringName = StringName(
			"fusivel_" + String(identificador_quadro)
		)

		var energia_restaurada: bool = (
			ProgressoJogo.get_meta(chave_energia, false) == true
		)

		var possui_fusivel: bool = (
			ProgressoJogo.get_meta(chave_fusivel, false) == true
		)

		if energia_restaurada:
			falas = [
				fala(
					nome_personagem,
					"Consegui ligar a energia."
				),
				fala(
					"COORDENADOR",
					"Ótimo. Procure ferramentas úteis nesta sala. Depois volte para conversar com a Stella."
				)
			]

		elif possui_fusivel:
			falas = [
				fala(
					nome_personagem,
					"Encontrei um fusível."
				),
				fala(
					"COORDENADOR",
					"Leve ao quadro elétrico e tente restabelecer a energia."
				)
			]

		else:
			chave_conversa = StringName(
				"radio_orientou_quadro_"
				+ String(identificador_quadro)
			)

			if ProgressoJogo.get_meta(
				chave_conversa,
				false
			) == true:
				falas = [
					fala(
						"COORDENADOR",
						"Encontrou o fusível?"
					),
					fala(
						nome_personagem,
						"Ainda estou procurando."
					),
					fala(
						"COORDENADOR",
						"Confira o chão perto do quadro elétrico."
					)
				]
			else:
				falas = [
					fala(
						nome_personagem,
						"Esta sala está escura. Estou ouvindo barulhos por perto."
					),
					fala(
						"COORDENADOR",
						"Use a lanterna e procure o quadro elétrico."
					),
					fala(
						"COORDENADOR",
						"Se estiver faltando um fusível, procure nas proximidades."
					)
				]

	else:
		# Antes da exploração, não antecipa ferramentas nem outra saída.
		falas = [
			fala(
				"COORDENADOR",
				"Como estão as coisas por aí?"
			),
			fala(
				nome_personagem,
				"Vou verificar a enfermaria."
			),
			fala(
				"COORDENADOR",
				"Certo. Use a chave que a Stella entregou e tome cuidado."
			)
		]

	await mostrar_falas(falas)

	# Registra a orientação somente depois de terminar a conversa.
	if chave_conversa != &"":
		ProgressoJogo.set_meta(chave_conversa, true)


func criar_explicacao_ferramentas() -> Array[Dictionary]:
	var tem_notebook: bool = possui_ferramenta("notebook")
	var tem_alicate: bool = possui_ferramenta("alicate")

	var descricao: String = "Não estou carregando ferramentas."

	if tem_notebook and tem_alicate:
		descricao = "Encontrei um notebook e um alicate."
	elif tem_notebook:
		descricao = "Encontrei um notebook."
	elif tem_alicate:
		descricao = "Encontrei um alicate."

	var falas: Array[Dictionary] = [
		fala(
			"COORDENADOR",
			"O que você encontrou na enfermagem?"
		),
		fala(
			nome_personagem,
			descricao
		)
	]

	if tem_notebook:
		falas.append(
			fala(
				"COORDENADOR",
				"O notebook pode acessar fechaduras eletrônicas. Procure terminais nas portas do setor de TI."
			)
		)

	if tem_alicate:
		falas.append(
			fala(
				"COORDENADOR",
				"O alicate pode cortar grades leves e seus pontos de fixação. Confira as passagens de manutenção."
			)
		)

	if not tem_notebook and not tem_alicate:
		falas.append(
			fala(
				"COORDENADOR",
				"Veja se deixou alguma ferramenta para trás. Precisamos encontrar uma forma de abrir outra passagem."
			)
		)

	falas.append(
		fala(
			"COORDENADOR",
			"Procure um caminho até a saída de emergência do setor de TI."
		)
	)

	return falas


func criar_lembrete_saida() -> Array[Dictionary]:
	var falas: Array[Dictionary] = [
		fala(
			"COORDENADOR",
			"Conseguiu encontrar uma passagem?"
		),
		fala(
			nome_personagem,
			"Ainda estou verificando."
		)
	]

	if possui_ferramenta("notebook"):
		falas.append(
			fala(
				"COORDENADOR",
				"Use o notebook nos terminais das portas eletrônicas."
			)
		)

	if possui_ferramenta("alicate"):
		falas.append(
			fala(
				"COORDENADOR",
				"Procure uma grade que possa cortar com o alicate."
			)
		)

	falas.append(
		fala(
			"COORDENADOR",
			"Precisamos chegar à saída de emergência. Vá com cuidado."
		)
	)

	return falas


func possui_ferramenta(tipo: String) -> bool:
	return InventarioJogo.possui_ferramenta(
		identificador_jogador,
		tipo
	)


func possui_alguma_ferramenta() -> bool:
	return (
		possui_ferramenta("notebook")
		or possui_ferramenta("alicate")
	)


func fala(nome: String, texto: String) -> Dictionary:
	return {
		"nome": nome,
		"texto": texto,
		"tipo": 1
	}


func mostrar_falas(falas: Array[Dictionary]) -> void:
	caixa_dialogo.call("iniciar_dialogo", falas)
	await Signal(caixa_dialogo, "dialogo_finalizado")
