extends "res://Scripts/zombi.gd"

@export_group("Reação à UV")
@export var velocidade_fuga_uv: float = 140.0
@export var margem_uv: float = 8.0


func _physics_process(delta: float) -> void:
	if morto:
		velocity = Vector2.ZERO
		return

	var fonte: Node2D = encontrar_uv(delta)

	if is_instance_valid(fonte):
		fugir_da_uv(fonte, delta)
		return

	super._physics_process(delta)


func encontrar_uv(delta: float) -> Node2D:
	var escolhida: Node2D
	var menor_distancia: float = INF

	# Antecipa o próximo passo para não entrar no círculo.
	var margem: float = (
		maxf(margem_uv, 0.0)
		+ maxf(velocidade, velocidade_patrulha) * delta
	)

	for no in get_tree().get_nodes_in_group("fontes_uv"):
		var fonte := no as Node2D

		if (
			not is_instance_valid(fonte)
			or not fonte.has_method("uv_alcanca")
		):
			continue

		if fonte.call("uv_alcanca", self, margem) != true:
			continue

		var centro: Vector2 = fonte.call("centro_uv")

		var distancia: float = (
			global_position.distance_squared_to(centro)
		)

		if distancia < menor_distancia:
			menor_distancia = distancia
			escolhida = fonte

	return escolhida


func fugir_da_uv(fonte: Node2D, delta: float) -> void:
	cancelar_destravamento()

	tempo_recuo = 0.0
	tempo_pausa = 0.0
	tempo_ate_ataque = maxf(tempo_ate_ataque, 0.2)

	var centro: Vector2 = fonte.call("centro_uv")

	var distancia: float = global_position.distance_to(
		centro
	)

	var limite: float = (
		float(fonte.get("raio_luz"))
		+ maxf(margem_uv, 0.0)
	)

	# Já está fora: espera, sem avançar sobre o jogador.
	if distancia >= limite:
		velocity = Vector2.ZERO
		animacao_parado()
		return

	var direcao: Vector2 = centro.direction_to(
		global_position
	)

	if direcao.is_zero_approx():
		direcao = Vector2.DOWN

	var passo: float = minf(
		maxf(velocidade_fuga_uv, 1.0) * delta,
		limite - distancia
	)

	# Testa desvios que continuam afastando da luz.
	for angulo in [
		0.0,
		PI / 4.0,
		-PI / 4.0,
		PI / 3.0,
		-PI / 3.0
	]:
		var candidata: Vector2 = direcao.rotated(
			float(angulo)
		)

		if test_move(
			global_transform,
			candidata * passo
		):
			continue

		velocity = candidata * (
			passo / maxf(delta, 0.001)
		)

		ultima_direcao = candidata
		animacao_andando(candidata)

		move_and_slide()
		return

	# Encurralado: para, sem atravessar paredes e sem atacar.
	velocity = Vector2.ZERO
	animacao_parado()


func atacar() -> void:
	if is_instance_valid(encontrar_uv(0.0)):
		return

	super.atacar()
