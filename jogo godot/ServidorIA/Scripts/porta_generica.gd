extends Area2D

enum ModoAbertura {
	NORMAL,
	ALICATE,
	NOTEBOOK
}

enum ChaveNecessaria {
	NENHUMA,
	ENFERMARIA,
	DISPENSA,
	BANHEIROS,
	ACESSO_SALAS,
	ACESSO_SAIDA,
	SEGUNDO_ANDAR,
	TI,
	QUADRO_ELETRICO
}

enum MensagemBloqueio {
	PORTA_TRANCADA,
	PRECISA_CHAVE,
	PRECISA_ENERGIA,
	PRECISA_CHAVE_E_ENERGIA,
	PRECISA_ALICATE,
	PRECISA_NOTEBOOK,
	ACESSO_INDISPONIVEL,
	PERSONALIZADA
}

@export_group("Referências")
@export var player: CharacterBody2D
@export var caixa_dialogo: Node
@export var sprite_porta: AnimatedSprite2D
@export var minigame_notebook: Node

@export_group("Identificação")
@export var id_porta: StringName = &"porta_dispensa"
@export var nome_sala: String = "Dispensa"

@export_group("Abertura")
@export var modo_abertura: ModoAbertura = ModoAbertura.NORMAL
@export var liberar_manualmente: bool = false
@export var bloquear_manualmente: bool = false
@export var acao_interagir: StringName = &"interagir"
@export var identificador_jogador: StringName = &"jogador_1"

@export_group("Requisito - chave")
@export var chave_necessaria: ChaveNecessaria = ChaveNecessaria.NENHUMA

@export_group("Requisito - energia")
@export var exigir_energia: bool = false
@export var quadro_necessario: Node
@export var identificador_quadro: StringName = &""

@export_group("Mensagens")
@export var tipo_mensagem_bloqueada: MensagemBloqueio = (
	MensagemBloqueio.PRECISA_CHAVE
)

@export_multiline var mensagem_personalizada: String = (
	"Esta passagem está bloqueada."
)

@export_multiline var mensagem_aberta: String = (
	"A passagem foi liberada. Interaja novamente para entrar."
)

@export_group("Animação")
@export var nome_animacao: StringName = &"default"

@export_range(0, 100, 1)
var frame_fechado: int = 0

@export_range(0, 100, 1)
var frame_aberto: int = 1

@export var animar_frames_intermediarios: bool = false

@export_range(0.02, 1.0, 0.01)
var segundos_por_frame: float = 0.12

@export_group("Próxima sala")
@export_file("*.tscn") var caminho_cena_destino: String
@export var nome_entrada_destino: StringName = &"EntradaPadrao"

@export_group("Depuração")
@export var mostrar_diagnostico: bool = true

var configurado: bool = false
var aberta: bool = false
var ocupado: bool = false
var trocando_cena: bool = false
var tempo_bloqueio: float = 0.0


func _ready() -> void:
	if not validar_configuracao():
		return

	aberta = (
		liberar_manualmente
		or ProgressoJogo.get_meta(chave_abertura(), false) == true
	)

	# A área continua detectando o player depois da abertura.
	monitoring = true

	aplicar_visual()
	configurado = true

	diagnosticar(
		"Configurada. Aberta: %s | Destino: %s"
		% [aberta, caminho_cena_destino]
	)


func validar_configuracao() -> bool:
	if not is_instance_valid(player):
		push_error(
			"Porta: preencha Player em " + String(get_path())
		)
		return false

	if not is_instance_valid(caixa_dialogo):
		push_error("Porta: preencha Caixa Dialogo.")
		return false

	if (
		not caixa_dialogo.has_method("iniciar_dialogo")
		or not caixa_dialogo.has_signal("dialogo_finalizado")
	):
		push_error("Porta: confira o script da caixa de diálogo.")
		return false

	if id_porta == &"":
		push_error("Porta: preencha um Id Porta único.")
		return false

	if not InputMap.has_action(acao_interagir):
		push_error(
			"Porta: a ação '%s' não existe."
			% String(acao_interagir)
		)
		return false

	if is_instance_valid(sprite_porta):
		var quadros: SpriteFrames = sprite_porta.sprite_frames

		if quadros == null:
			push_error("Porta: o sprite está sem SpriteFrames.")
			return false

		if not quadros.has_animation(nome_animacao):
			push_error("Porta: confira Nome Animacao.")
			return false

		var total: int = quadros.get_frame_count(nome_animacao)

		if (
			frame_fechado < 0
			or frame_aberto < frame_fechado
			or frame_fechado >= total
			or frame_aberto >= total
		):
			push_error(
				"Porta: confira os frames. A animação possui %s frames."
				% total
			)
			return false

	return true


func chave_abertura() -> StringName:
	return StringName("porta_aberta_" + String(id_porta))


func diagnosticar(texto: String) -> void:
	if mostrar_diagnostico:
		print("PORTA [", name, "]: ", texto)


func _physics_process(delta: float) -> void:
	tempo_bloqueio = maxf(tempo_bloqueio - delta, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(acao_interagir):
		return

	if event.is_echo():
		return

	diagnosticar(
		"Botão recebido. Configurada: %s | Ocupada: %s | Aberta: %s"
		% [configurado, ocupado, aberta]
	)

	if not configurado:
		diagnosticar("Configuração incompleta.")
		return

	if ocupado or trocando_cena:
		diagnosticar("Interação ou troca de cena em andamento.")
		return

	if not is_instance_valid(player):
		return

	if not is_instance_valid(caixa_dialogo):
		return

	if caixa_dialogo.get("ativo") == true:
		diagnosticar("Existe um diálogo aberto.")
		return

	if not player.is_physics_processing():
		diagnosticar("O controle do personagem está bloqueado.")
		return

	if tempo_bloqueio > 0.0:
		return

	var dentro: bool = (Cooperativo.jogador_na_interacao(self, player) != null)

	diagnosticar(
		"Player dentro da área: %s" % dentro
	)

	if not dentro:
		return

	get_viewport().set_input_as_handled()

	ocupado = true
	await interagir()

	if not trocando_cena:
		ocupado = false

	tempo_bloqueio = 0.2


func interagir() -> void:
	if bloquear_manualmente:
		await mostrar_mensagem(obter_mensagem_bloqueada())
		return

	if aberta:
		trocando_cena = true
		call_deferred("entrar")
		return

	if not liberar_manualmente:
		if not requisitos_atendidos():
			await mostrar_mensagem(obter_mensagem_bloqueada())
			return

		match modo_abertura:
			ModoAbertura.ALICATE:
				if not possui_ferramenta("alicate"):
					await mostrar_mensagem(
						"Preciso de um alicate para cortar esta grade."
					)
					return

			ModoAbertura.NOTEBOOK:
				if not possui_ferramenta("notebook"):
					await mostrar_mensagem(
						"Preciso de um notebook para acessar esta porta."
					)
					return

				if (
					not is_instance_valid(minigame_notebook)
					or not minigame_notebook.has_method(
						"iniciar_desafio"
					)
					or not minigame_notebook.has_signal(
						"desafio_finalizado"
					)
				):
					push_error(
						"Porta: preencha Minigame Notebook."
					)
					return

				await mostrar_mensagem(
					"Complete o código para liberar o acesso."
				)

				await get_tree().process_frame

				var iniciou: bool = bool(
					minigame_notebook.call(
						"iniciar_desafio",
						player
					)
				)

				if not iniciou:
					return

				var sucesso: bool = await Signal(
					minigame_notebook,
					"desafio_finalizado"
				)

				if not sucesso:
					return

	await abrir_passagem()

	if not mensagem_aberta.is_empty():
		await mostrar_mensagem(mensagem_aberta)


func requisitos_atendidos() -> bool:
	if not possui_chave_exigida():
		diagnosticar("Falta a chave necessária.")
		return false

	if exigir_energia and not energia_ligada():
		diagnosticar("O quadro necessário está desligado.")
		return false

	return true


func possui_chave_exigida() -> bool:
	if chave_necessaria == ChaveNecessaria.NENHUMA:
		return true

	if chave_necessaria == ChaveNecessaria.ENFERMARIA:
		return ProgressoJogo.possui_chave_enfermaria

	return ProgressoJogo.get_meta(
		obter_identificador_chave(),
		false
	) == true


func obter_identificador_chave() -> StringName:
	match chave_necessaria:
		ChaveNecessaria.ENFERMARIA:
			return &"possui_chave_enfermaria"

		ChaveNecessaria.DISPENSA:
			return &"possui_chave_dispensa"

		ChaveNecessaria.BANHEIROS:
			return &"possui_chave_banheiros"

		ChaveNecessaria.ACESSO_SALAS:
			return &"possui_chave_acesso_salas"

		ChaveNecessaria.ACESSO_SAIDA:
			return &"possui_chave_acesso_saida"

		ChaveNecessaria.SEGUNDO_ANDAR:
			return &"possui_chave_segundo_andar"

		ChaveNecessaria.TI:
			return &"possui_chave_ti"

		ChaveNecessaria.QUADRO_ELETRICO:
			return &"possui_chave_quadro_eletrico"

	return &""


func energia_ligada() -> bool:
	var identificador: String = String(identificador_quadro)

	if is_instance_valid(quadro_necessario):
		var valor: Variant = quadro_necessario.get(
			"identificador_quadro"
		)

		if valor != null and not String(valor).is_empty():
			identificador = String(valor)

	if identificador.is_empty():
		push_warning(
			"Porta: selecione o quadro ou preencha seu identificador."
		)
		return false

	var chave: StringName = StringName(
		"energia_" + identificador
	)

	return ProgressoJogo.get_meta(chave, false) == true


func possui_ferramenta(tipo: String) -> bool:
	return InventarioJogo.possui_ferramenta(
		identificador_jogador,
		tipo
	)


func obter_mensagem_bloqueada() -> String:
	match tipo_mensagem_bloqueada:
		MensagemBloqueio.PORTA_TRANCADA:
			return "Esta porta está trancada."

		MensagemBloqueio.PRECISA_CHAVE:
			return "Esta porta está trancada. Preciso da chave correspondente."

		MensagemBloqueio.PRECISA_ENERGIA:
			return "É necessário ligar o quadro de força para liberar esta passagem."

		MensagemBloqueio.PRECISA_CHAVE_E_ENERGIA:
			return "Para liberar esta passagem, preciso da chave e do quadro de força ligado."

		MensagemBloqueio.PRECISA_ALICATE:
			return "Esta grade bloqueia a passagem. Preciso de um alicate."

		MensagemBloqueio.PRECISA_NOTEBOOK:
			return "A fechadura é eletrônica. Preciso de um notebook."

		MensagemBloqueio.ACESSO_INDISPONIVEL:
			return "Esta área está inacessível no momento."

		MensagemBloqueio.PERSONALIZADA:
			return mensagem_personalizada

	return "Esta passagem está bloqueada."


func abrir_passagem() -> void:
	var processava: bool = player.is_physics_processing()

	player.velocity = Vector2.ZERO
	player.set_physics_process(false)

	if player.has_method("animacao_parado"):
		player.call("animacao_parado")

	if is_instance_valid(sprite_porta):
		sprite_porta.stop()
		sprite_porta.animation = nome_animacao

		if animar_frames_intermediarios:
			for indice in range(frame_fechado, frame_aberto + 1):
				sprite_porta.frame = indice

				await get_tree().create_timer(
					maxf(segundos_por_frame, 0.02)
				).timeout

	aberta = true

	ProgressoJogo.set_meta(chave_abertura(), true)
	aplicar_visual()

	if is_instance_valid(player):
		player.set_physics_process(processava)

	diagnosticar(
		"Passagem aberta. Interaja novamente para entrar."
	)


func aplicar_visual() -> void:
	if not is_instance_valid(sprite_porta):
		return

	sprite_porta.stop()
	sprite_porta.animation = nome_animacao

	sprite_porta.frame = (
		frame_aberto if aberta else frame_fechado
	)

	# Não desativa nenhum colisor da Area2D.
	# A parede do mapa continua responsável pela colisão física.


func mostrar_mensagem(texto: String) -> void:
	var falas: Array[Dictionary] = [
		{
			"nome": nome_sala,
			"texto": texto,
			"tipo": 2
		}
	]

	caixa_dialogo.call("iniciar_dialogo", falas)
	await Signal(caixa_dialogo, "dialogo_finalizado")


func entrar() -> void:
	diagnosticar(
		"Tentando trocar de sala. Destino: %s | Entrada: %s"
		% [caminho_cena_destino, String(nome_entrada_destino)]
	)

	if caminho_cena_destino.is_empty():
		push_warning(
			"Porta: preencha Caminho Cena Destino em "
			+ String(get_path())
		)
		cancelar_troca()
		return

	if not ResourceLoader.exists(caminho_cena_destino):
		push_error(
			"Porta: cena não encontrada: "
			+ caminho_cena_destino
		)
		cancelar_troca()
		return

	if nome_entrada_destino == &"":
		push_error("Porta: preencha Nome Entrada Destino.")
		cancelar_troca()
		return

	if not is_instance_valid(player):
		cancelar_troca()
		return

	ProgressoJogo.salvar_estado_player(player)

	ProgressoJogo.set_meta(
		&"chegada_pendente",
		{
			"cena": caminho_cena_destino,
			"entrada": String(nome_entrada_destino)
		}
	)

	var erro: Error = get_tree().change_scene_to_file(
		caminho_cena_destino
	)

	if erro != OK:
		ProgressoJogo.remove_meta(&"chegada_pendente")
		cancelar_troca()

		push_error(
			"Porta: falha na troca de sala. Código: %s."
			% erro
		)
	else:
		diagnosticar("Troca de sala solicitada com sucesso.")


func cancelar_troca() -> void:
	trocando_cena = false
	ocupado = false
	tempo_bloqueio = 0.2
