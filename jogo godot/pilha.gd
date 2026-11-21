extends Area2D

@export var carga_restaurada: float = 50.0

@export_group("Lançamento")
@export var duracao_lancamento: float = 0.25
@export var altura_salto: float = 14.0
@export var altura_quique: float = 4.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var pode_coletar: bool = true
var coletada: bool = false

var posicao_original_sprite: Vector2
var tween_lancamento: Tween


func _ready() -> void:
	monitoring = true
	posicao_original_sprite = sprite.position


func _physics_process(_delta: float) -> void:
	if not pode_coletar or coletada:
		return

	verificar_coleta()


func verificar_coleta() -> void:
	# Detecta também o player que já estiver sobre a pilha.
	for corpo in get_overlapping_bodies():
		tentar_coletar(corpo)

		if coletada:
			break


func lancar(deslocamento: Vector2) -> void:
	pode_coletar = false

	if tween_lancamento != null:
		tween_lancamento.kill()

	sprite.position = posicao_original_sprite

	var duracao := maxf(duracao_lancamento, 0.1)
	var destino := position + deslocamento

	tween_lancamento = create_tween()

	# Avança até o local da queda.
	tween_lancamento.tween_property(
		self,
		"position",
		destino,
		duracao
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Sobe enquanto avança.
	tween_lancamento.parallel().tween_property(
		sprite,
		"position:y",
		posicao_original_sprite.y - altura_salto,
		duracao / 2.0
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Desce na segunda metade do lançamento.
	tween_lancamento.parallel().tween_property(
		sprite,
		"position:y",
		posicao_original_sprite.y,
		duracao / 2.0
	).set_delay(
		duracao / 2.0
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Já pode ser coletada na primeira queda.
	tween_lancamento.tween_callback(liberar_coleta)

	# O quique continua apenas como efeito visual.
	tween_lancamento.tween_property(
		sprite,
		"position:y",
		posicao_original_sprite.y - altura_quique,
		0.09
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween_lancamento.tween_property(
		sprite,
		"position:y",
		posicao_original_sprite.y,
		0.09
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tween_lancamento.tween_callback(finalizar_lancamento)


func liberar_coleta() -> void:
	pode_coletar = true


func finalizar_lancamento() -> void:
	sprite.position = posicao_original_sprite


func tentar_coletar(corpo: Node2D) -> void:
	if coletada or not pode_coletar:
		return

	var lanterna := corpo.get_node_or_null("Lanterna")

	if lanterna == null:
		return

	if not lanterna.has_method("recarregar_bateria"):
		return

	var aproveitou := bool(
		lanterna.call("recarregar_bateria", carga_restaurada)
	)

	# Com bateria cheia, permanece no chão.
	if not aproveitou:
		return

	coletada = true
	pode_coletar = false

	if tween_lancamento != null:
		tween_lancamento.kill()

	hide()
	queue_free()
