extends Node2D

@export_group("Ambiente")
@export var iniciar_no_escuro: bool = true
@export var cor_escuridao: Color = Color.BLACK

@export_group("Lanterna")
@export var iniciar_com_lanterna: bool = true
@export var acao_lanterna: StringName = &"lanterna"
@export var raio_luz: float = 120.0
@export var intensidade: float = 1.0
@export var cor_luz: Color = Color(1.0, 0.95, 0.82, 1.0)
@export var deslocamento_luz: Vector2 = Vector2(0, -12)

@export_group("UV")
@export var cor_uv: Color = Color(0.65, 0.2, 1.0)
@export_flags_2d_physics var mascara_paredes_uv: int = 1

@export_group("Bateria")
@export var bateria_maxima: float = 100.0
@export var bateria_inicial: float = 100.0
@export var consumo_por_segundo: float = 5.0
@export var carga_por_pilha: float = 50.0

@export_group("Clarão sem bateria")
@export var intervalo_clarao: float = 6.0
@export var duracao_clarao: float = 0.25

@export_group("Interface")
@export var indicador_bateria: AnimatedSprite2D
@export var grupo_indicador: StringName = &"indicador_bateria"

@export_group("Descarte das lanternas")
@export var imagem_lanterna_normal: Texture2D
@export var imagem_lanterna_uv: Texture2D
@export var distancia_descarte: float = 24.0
@export var acao_interagir: StringName = &"interagir"

var luz: PointLight2D
var ambiente: CanvasModulate
var brilho_uv: Sprite2D

var possui_lanterna: bool = false
var ligada: bool = false
var ambiente_escuro: bool = true
var entrada_configurada: bool = false

var bateria_atual: float = 100.0

var tempo_ate_clarao: float = 0.0
var tempo_clarao_restante: float = 0.0
var tempo_procurar_indicador: float = 0.0

var descartes_criados: Dictionary = {}


func _ready() -> void:
	bateria_maxima = maxf(bateria_maxima, 1.0)

	bateria_atual = clampf(
		bateria_inicial,
		0.0,
		bateria_maxima
	)

	criar_ambiente()
	criar_luz()

	possui_lanterna = ProgressoJogo.possui_lanterna
	entrada_configurada = InputMap.has_action(acao_lanterna)

	if not entrada_configurada:
		push_error(
			"Crie a ação '%s' no Mapa de Entrada."
			% acao_lanterna
		)

	tempo_ate_clarao = maxf(intervalo_clarao, 0.1)

	definir_escuridao(iniciar_no_escuro)
	definir_lanterna_ligada(false)

	add_to_group("fontes_uv")

	call_deferred("procurar_indicador_bateria")
	call_deferred("restaurar_descartes")


func tipo_equipado() -> String:
	return String(
		ProgressoJogo.get_meta(&"lanterna_tipo", "normal")
	)


func comando_ativo() -> bool:
	if not entrada_configurada:
		return false

	var jogador := get_parent() as CharacterBody2D

	if is_instance_valid(jogador):
		if (
			not jogador.is_physics_processing()
			or jogador.get("morto") == true
		):
			return false

	return Input.is_action_pressed(jogador.call("acao_local", acao_lanterna) if is_instance_valid(jogador) and jogador.has_method("acao_local") else acao_lanterna)


func _process(delta: float) -> void:
	# Recria os efeitos se alguma referência tiver sido removida.
	if (
		not is_instance_valid(luz)
		or not is_instance_valid(brilho_uv)
	):
		criar_luz()

	if (
		not is_instance_valid(luz)
		or not is_instance_valid(brilho_uv)
	):
		return

	possui_lanterna = ProgressoJogo.possui_lanterna

	if not is_instance_valid(indicador_bateria):
		tempo_procurar_indicador -= delta

		if tempo_procurar_indicador <= 0.0:
			tempo_procurar_indicador = 1.0
			procurar_indicador_bateria()

	tempo_ate_clarao = maxf(
		tempo_ate_clarao - delta,
		0.0
	)

	tempo_clarao_restante = maxf(
		tempo_clarao_restante - delta,
		0.0
	)

	var uv: bool = tipo_equipado() == "uv"

	luz.color = cor_uv if uv else cor_luz

	if (
		not comando_ativo()
		or not possui_lanterna
		or (not uv and not ambiente_escuro)
	):
		definir_lanterna_ligada(false)

	elif bateria_atual > 0.0:
		tempo_clarao_restante = 0.0

		bateria_atual = maxf(
			bateria_atual
			- maxf(consumo_por_segundo, 0.0) * delta,
			0.0
		)

		definir_lanterna_ligada(bateria_atual > 0.0)

		if bateria_atual <= 0.0:
			tempo_ate_clarao = maxf(
				intervalo_clarao,
				0.1
			)

	else:
		if (
			tempo_ate_clarao <= 0.0
			and tempo_clarao_restante <= 0.0
		):
			tempo_clarao_restante = maxf(
				duracao_clarao,
				0.01
			)

			tempo_ate_clarao = maxf(
				intervalo_clarao,
				tempo_clarao_restante + 0.1
			)

		definir_lanterna_ligada(
			tempo_clarao_restante > 0.0
		)

	if is_instance_valid(brilho_uv):
		brilho_uv.visible = ligada and uv

	atualizar_indicador_bateria()


func criar_ambiente() -> void:
	ambiente = CanvasModulate.new()
	ambiente.name = "Escuridao"

	add_child(ambiente)


func criar_luz() -> void:
	# Mantém somente um conjunto de efeitos.
	if is_instance_valid(luz):
		luz.free()

	if is_instance_valid(brilho_uv):
		brilho_uv.free()

	var gradiente := Gradient.new()

	gradiente.offsets = PackedFloat32Array([
		0.0,
		0.35,
		1.0
	])

	gradiente.colors = PackedColorArray([
		Color.WHITE,
		Color(0.8, 0.8, 0.8),
		Color.BLACK
	])

	var textura := GradientTexture2D.new()
	textura.width = 256
	textura.height = 256
	textura.gradient = gradiente
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = Vector2(0.5, 0.5)
	textura.fill_to = Vector2(1.0, 0.5)

	luz = PointLight2D.new()
	luz.name = "LuzCircular"
	luz.texture = textura
	luz.texture_scale = maxf(raio_luz, 1.0) / 128.0
	luz.energy = maxf(intensidade, 0.0)
	luz.color = cor_luz
	luz.position = deslocamento_luz
	luz.enabled = false

	add_child(luz)

	# Halo discreto para a UV aparecer também em salas claras.
	var gradiente_halo := Gradient.new()

	gradiente_halo.colors = PackedColorArray([
		Color(1, 1, 1, 0.12),
		Color(1, 1, 1, 0)
	])

	var textura_halo := GradientTexture2D.new()
	textura_halo.width = 256
	textura_halo.height = 256
	textura_halo.gradient = gradiente_halo
	textura_halo.fill = GradientTexture2D.FILL_RADIAL
	textura_halo.fill_from = Vector2(0.5, 0.5)
	textura_halo.fill_to = Vector2(1.0, 0.5)

	brilho_uv = Sprite2D.new()
	brilho_uv.name = "HaloUV"
	brilho_uv.texture = textura_halo
	brilho_uv.scale = Vector2.ONE * luz.texture_scale
	brilho_uv.position = deslocamento_luz
	brilho_uv.modulate = cor_uv
	brilho_uv.z_index = 10

	var material_halo := CanvasItemMaterial.new()

	material_halo.light_mode = (
		CanvasItemMaterial.LIGHT_MODE_UNSHADED
	)

	brilho_uv.material = material_halo
	brilho_uv.hide()

	add_child(brilho_uv)


func definir_escuridao(escuro: bool) -> void:
	ambiente_escuro = escuro

	if is_instance_valid(ambiente):
		ambiente.color = (
			cor_escuridao if escuro else Color.WHITE
		)

	if not escuro and tipo_equipado() != "uv":
		definir_lanterna_ligada(false)


func pegar_lanterna() -> void:
	possui_lanterna = true
	ProgressoJogo.possui_lanterna = true


func definir_lanterna_ligada(ativar: bool) -> void:
	ligada = (
		ativar
		and possui_lanterna
		and (ambiente_escuro or tipo_equipado() == "uv")
		and (
			bateria_atual > 0.0
			or tempo_clarao_restante > 0.0
		)
	)

	if is_instance_valid(luz):
		luz.enabled = ligada

	if is_instance_valid(brilho_uv):
		brilho_uv.visible = (
			ligada and tipo_equipado() == "uv"
		)


func uv_protegendo() -> bool:
	# Clarões sem bateria não afastam os zumbis.
	return (
		ProgressoJogo.possui_lanterna
		and tipo_equipado() == "uv"
		and bateria_atual > 0.0
		and comando_ativo()
	)


func centro_uv() -> Vector2:
	if is_instance_valid(luz):
		return luz.global_position

	return to_global(deslocamento_luz)


func uv_alcanca(
	zumbi: CharacterBody2D,
	margem: float = 0.0
) -> bool:
	if not uv_protegendo():
		return false

	if centro_uv().distance_to(zumbi.global_position) > (
		maxf(raio_luz, 1.0) + margem
	):
		return false

	var consulta := PhysicsRayQueryParameters2D.create(
		centro_uv(),
		zumbi.global_position,
		mascara_paredes_uv
	)

	var excluir: Array[RID] = [zumbi.get_rid()]

	var jogador := get_parent() as CharacterBody2D

	if is_instance_valid(jogador):
		excluir.append(jogador.get_rid())

	consulta.exclude = excluir
	consulta.collide_with_areas = false

	return get_world_2d().direct_space_state.intersect_ray(
		consulta
	).is_empty()


func procurar_indicador_bateria() -> void:
	if is_instance_valid(indicador_bateria):
		atualizar_indicador_bateria()
		return

	for no in get_tree().get_nodes_in_group(grupo_indicador):
		if (
			no is AnimatedSprite2D
			and no.has_method("definir_bateria")
		):
			indicador_bateria = no as AnimatedSprite2D
			atualizar_indicador_bateria()
			return


func atualizar_indicador_bateria() -> void:
	if (
		is_instance_valid(indicador_bateria)
		and indicador_bateria.has_method("definir_bateria")
	):
		indicador_bateria.call(
			"definir_bateria",
			bateria_atual,
			bateria_maxima
		)


func recarregar_bateria(quantidade: float) -> bool:
	if quantidade <= 0.0 or bateria_atual >= bateria_maxima:
		return false

	bateria_atual = minf(
		bateria_atual + quantidade,
		bateria_maxima
	)

	tempo_clarao_restante = 0.0
	tempo_ate_clarao = maxf(intervalo_clarao, 0.1)

	atualizar_indicador_bateria()
	return true


func receber_pilha() -> bool:
	return recarregar_bateria(carga_por_pilha)


func trocar_lanterna(
	tipo: String,
	id: StringName,
	textura: Texture2D
) -> bool:
	if tipo not in ["normal", "uv"] or id == &"":
		return false

	var cena: Node = get_tree().current_scene
	var jogador := get_parent() as CharacterBody2D

	if (
		not is_instance_valid(cena)
		or not is_instance_valid(jogador)
	):
		return false

	var equipada: Dictionary = ProgressoJogo.get_meta(
		&"lanterna_equipada",
		{}
	)

	if String(equipada.get("id", "")) == String(id):
		return false

	var descartes: Dictionary = ProgressoJogo.get_meta(
		&"lanternas_no_chao",
		{}
	).duplicate(true)

	if ProgressoJogo.possui_lanterna:
		var tipo_anterior: String = tipo_equipado()

		var id_anterior: String = String(
			equipada.get("id", "lanterna_stella")
		)

		var imagem: Texture2D = equipada.get("textura")

		if imagem == null:
			imagem = (
				imagem_lanterna_uv
				if tipo_anterior == "uv"
				else imagem_lanterna_normal
			)

		var inicio: Vector2 = jogador.global_position
		var direcao: Vector2 = jogador.get("ultima_direcao")

		if direcao.is_zero_approx():
			direcao = Vector2.DOWN

		var destino: Vector2 = (
			inicio
			+ direcao.normalized().orthogonal()
			* maxf(distancia_descarte, 0.0)
		)

		var consulta := PhysicsRayQueryParameters2D.create(
			inicio,
			destino,
			jogador.collision_mask
		)

		consulta.exclude = [jogador.get_rid()]
		consulta.collide_with_areas = false

		if not get_world_2d().direct_space_state.intersect_ray(
			consulta
		).is_empty():
			destino = inicio

		descartes[id_anterior] = {
			"tipo": tipo_anterior,
			"id": id_anterior,
			"textura": imagem,
			"cena": cena.scene_file_path,
			"posicao": destino
		}

	descartes.erase(String(id))

	var recolhidas: Dictionary = ProgressoJogo.get_meta(
		&"lanternas_recolhidas",
		{}
	).duplicate(true)

	recolhidas[String(id)] = true

	ProgressoJogo.set_meta(
		&"lanternas_recolhidas",
		recolhidas
	)

	ProgressoJogo.set_meta(
		&"lanternas_no_chao",
		descartes
	)

	ProgressoJogo.set_meta(
		&"lanterna_equipada",
		{
			"id": String(id),
			"textura": textura
		}
	)

	ProgressoJogo.set_meta(&"lanterna_tipo", tipo)

	pegar_lanterna()

	# Mantém a carga atual ao trocar.
	tempo_clarao_restante = 0.0
	definir_lanterna_ligada(false)

	call_deferred("restaurar_descartes")
	return true


func restaurar_descartes() -> void:
	var cena: Node = get_tree().current_scene
	var jogador := get_parent() as CharacterBody2D

	if (
		not is_instance_valid(cena)
		or not is_instance_valid(jogador)
	):
		return

	var dados: Dictionary = ProgressoJogo.get_meta(
		&"lanternas_no_chao",
		{}
	)

	for id in descartes_criados.keys():
		if not dados.has(id):
			var antigo: Node = descartes_criados[id]

			if is_instance_valid(antigo):
				antigo.queue_free()

			descartes_criados.erase(id)

	for id in dados:
		var registro: Dictionary = dados[id]

		if String(registro["cena"]) != cena.scene_file_path:
			continue

		if descartes_criados.has(id):
			if is_instance_valid(descartes_criados[id]):
				continue

		var script_item: Script = load(
			"res://Scripts/lanterna_coletavel.gd"
		)

		var item: Area2D = script_item.new() as Area2D

		item.set("player", jogador)
		item.set("tipo_lanterna", String(registro["tipo"]))
		item.set("id_objeto", StringName(id))
		item.set("imagem", registro.get("textura"))
		item.set("e_descarte", true)
		item.set("acao_interagir", acao_interagir)

		item.collision_layer = 0
		item.collision_mask = jogador.collision_layer

		cena.add_child(item)
		item.global_position = registro["posicao"]

		descartes_criados[id] = item
