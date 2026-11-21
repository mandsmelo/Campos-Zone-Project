extends CanvasLayer

@export var player: CharacterBody2D
@export var coracao_modelo: AnimatedSprite2D

# Preencha com os nomes exatos das suas animações.
@export var animacao_cheio: StringName = &"cheio"
@export var animacao_vazio: StringName = &"vazio"

@export_group("Posição na tela")
@export var posicao_inicial: Vector2 = Vector2(32, 32)
@export var espacamento: float = 32.0
@export var escala_coracao: float = 1.0

var coracoes: Array[AnimatedSprite2D] = []


func _ready() -> void:
	# Desenha acima do mapa e não acompanha a câmera.
	layer = 10
	follow_viewport_enabled = false
	transform = Transform2D.IDENTITY
	show()

	# Aguarda os outros nós terminarem sua inicialização.
	call_deferred("configurar_interface")


func configurar_interface() -> void:
	if not is_instance_valid(player):
		push_error("Interface: preencha o campo Player.")
		return

	if not is_instance_valid(coracao_modelo):
		push_error("Interface: preencha o campo Coracao Modelo.")
		return

	var animacoes := coracao_modelo.sprite_frames

	if animacoes == null:
		push_error("O coração modelo está sem animações.")
		return

	if not animacoes.has_animation(animacao_cheio):
		push_error("Confira o nome da animação de coração cheio.")
		return

	if not animacoes.has_animation(animacao_vazio):
		push_error("Confira o nome da animação de coração vazio.")
		return

	if not player.has_signal("vida_alterada"):
		push_error("Adicione o sistema de vida ao script do player.")
		return

	var total := int(player.get("vida_maxima"))

	coracao_modelo.hide()

	for i in range(total):
		var coracao := AnimatedSprite2D.new()

		coracao.name = "Coracao%d" % (i + 1)
		coracao.sprite_frames = animacoes
		coracao.centered = true
		coracao.position = (
			posicao_inicial + Vector2(i * espacamento, 0)
		)
		coracao.scale = Vector2.ONE * escala_coracao
		coracao.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

		add_child(coracao)
		coracoes.append(coracao)

	player.connect(
		"vida_alterada",
		Callable(self, "atualizar_coracoes")
	)

	atualizar_coracoes(int(player.get("vida_atual")))


func atualizar_coracoes(vida: int) -> void:
	for i in range(coracoes.size()):
		var animacao := animacao_vazio

		if i < vida:
			animacao = animacao_cheio

		coracoes[i].play(animacao)
