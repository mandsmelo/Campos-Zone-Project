extends Node

signal inventario_alterado(jogador: StringName)

const LIMITE_FERRAMENTAS: int = 2
const LIMITE_ARMAS: int = 1

const NOMES: Dictionary = {
	"notebook": "Notebook",
	"alicate": "Alicate"
}

const ARMAS: Dictionary = {
	"taser": "Taser",
	"arma_choque": "Arma de choque"
}

var ferramentas_por_jogador: Dictionary = {}
var armas_por_jogador: Dictionary = {}
var objetos_recolhidos: Dictionary = {}


func reiniciar() -> void:
	ferramentas_por_jogador.clear()
	armas_por_jogador.clear()
	objetos_recolhidos.clear()

	if ProgressoJogo.has_meta(&"armas_no_chao"):
		ProgressoJogo.remove_meta(&"armas_no_chao")


# ==========================================
# FERRAMENTAS
# ==========================================

func obter_ferramentas(jogador: StringName) -> Array[String]:
	var resultado: Array[String] = []

	var ferramentas: Array = ferramentas_por_jogador.get(
		jogador,
		[]
	)

	for ferramenta in ferramentas:
		resultado.append(str(ferramenta))

	return resultado


func quantidade_ferramentas(jogador: StringName) -> int:
	return obter_ferramentas(jogador).size()


func tem_espaco(jogador: StringName) -> bool:
	return quantidade_ferramentas(jogador) < LIMITE_FERRAMENTAS


func possui_ferramenta(
	jogador: StringName,
	tipo: String
) -> bool:
	return obter_ferramentas(jogador).has(tipo)


func nome_ferramenta(tipo: String) -> String:
	return str(NOMES.get(tipo, tipo))


func tentar_recolher(
	jogador: StringName,
	tipo: String,
	id_objeto: StringName
) -> bool:
	if not NOMES.has(tipo):
		return false

	if jogador == &"" or id_objeto == &"":
		return false

	if objeto_foi_recolhido(id_objeto):
		return false

	if not tem_espaco(jogador):
		return false

	if possui_ferramenta(jogador, tipo):
		return false

	var ferramentas: Array[String] = obter_ferramentas(jogador)
	ferramentas.append(tipo)

	ferramentas_por_jogador[jogador] = ferramentas
	objetos_recolhidos[id_objeto] = true

	inventario_alterado.emit(jogador)
	return true


# ==========================================
# OBJETOS RECOLHIDOS
# ==========================================

func objeto_foi_recolhido(id_objeto: StringName) -> bool:
	return objetos_recolhidos.has(id_objeto)


# ==========================================
# ARMAS EQUIPADAS
# ==========================================

func obter_arma(jogador: StringName) -> Dictionary:
	var arma: Dictionary = armas_por_jogador.get(jogador, {})
	return arma.duplicate(true)


func possui_arma(jogador: StringName) -> bool:
	return not obter_arma(jogador).is_empty()


func nome_arma(tipo: String) -> String:
	return str(ARMAS.get(tipo, tipo))


# Compatibilidade com a coleta antiga.
# Esta função só recolhe quando não existe arma equipada.
func tentar_recolher_arma(
	jogador: StringName,
	tipo: String,
	id_objeto: StringName
) -> bool:
	if possui_arma(jogador):
		return false

	if objeto_foi_recolhido(id_objeto):
		return false

	return trocar_arma(jogador, tipo, id_objeto)


# ==========================================
# ARMAS LARGADAS NAS SALAS
# ==========================================

func obter_armas_no_chao() -> Dictionary:
	var dados: Dictionary = ProgressoJogo.get_meta(
		&"armas_no_chao",
		{}
	)

	return dados.duplicate(true)


func trocar_arma(
	jogador: StringName,
	tipo: String,
	id_objeto: StringName,
	local_descarte: Dictionary = {},
	visual: Dictionary = {}
) -> bool:
	if not ARMAS.has(tipo):
		return false

	if jogador == &"" or id_objeto == &"":
		return false

	# Um mesmo objeto não pode estar equipado por dois jogadores.
	for dono in armas_por_jogador:
		var equipada: Dictionary = armas_por_jogador[dono]

		if StringName(equipada.get("id_objeto", "")) == id_objeto:
			return false

	var anterior: Dictionary = obter_arma(jogador)

	var descartes: Dictionary = obter_armas_no_chao()

	# Registra onde a arma anterior será largada.
	if not anterior.is_empty():
		if (
			not local_descarte.has("cena")
			or not local_descarte.has("posicao")
		):
			return false

		var registro: Dictionary = anterior.duplicate(true)

		registro["cena"] = local_descarte["cena"]
		registro["posicao"] = local_descarte["posicao"]

		descartes[String(anterior["id_objeto"])] = registro

	# Remove do chão a arma que está sendo equipada.
	descartes.erase(String(id_objeto))

	armas_por_jogador[jogador] = {
		"tipo": tipo,
		"id_objeto": id_objeto,
		"visual": visual.duplicate(true)
	}

	# Mantém o objeto original removido da posição inicial.
	objetos_recolhidos[id_objeto] = true

	ProgressoJogo.set_meta(
		&"armas_no_chao",
		descartes
	)

	inventario_alterado.emit(jogador)
	return true


# ==========================================
# CONSULTA DO INVENTÁRIO
# ==========================================

func resumo_inventario(jogador: StringName) -> String:
	var nomes: PackedStringArray = []

	for tipo in obter_ferramentas(jogador):
		nomes.append(nome_ferramenta(tipo))

	var texto_ferramentas: String = "Nenhuma"

	if not nomes.is_empty():
		texto_ferramentas = ", ".join(nomes)

	var arma: Dictionary = obter_arma(jogador)
	var texto_arma: String = "Nenhuma"

	if not arma.is_empty():
		texto_arma = nome_arma(String(arma["tipo"]))

	return (
		"Ferramentas: %s\nArma: %s"
		% [texto_ferramentas, texto_arma]
	)
