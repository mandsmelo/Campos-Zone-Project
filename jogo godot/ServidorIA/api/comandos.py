"""Respostas de comandos exatos; contexto da Godot tem prioridade por requisição."""
import json
import re
import unicodedata
from pathlib import Path

PADRAO = json.loads(Path(__file__).with_name("controles_padrao.json").read_text(encoding="utf-8"))
NOMES = {"move_left":"Mover para a esquerda", "move_right":"Mover para a direita", "move_up":"Mover para cima", "move_down":"Mover para baixo", "rastejar":"Rastejar/agachar", "pular":"Pular", "correr":"Correr", "lanterna":"Usar a lanterna", "interagir":"Interagir/conversar", "radio":"Usar o rádio", "inventario":"Abrir o inventário", "atirar":"Atirar"}
ALIASES = {
 "inventario": r"inventario|mochila",
 "radio": r"radio",
 "lanterna": r"lanterna|iluminar|luz",
 "interagir": r"interagir|interajo|interacao|conversar|converso|falar|coletar|recolher|pegar|abrir (?:a )?porta",
 "atirar": r"atirar|disparar|taser|arma",
 "rastejar": r"rastejar|rastejo|agachar|abaixar|esconder",
 "pular": r"pular|saltar|pulo",
 "correr": r"correr|corrida",
}

def normalizar(texto):
    return "".join(c for c in unicodedata.normalize("NFD", texto.lower()) if unicodedata.category(c) != "Mn")

def responder_comandos(pergunta, controles=None):
    texto = normalizar(pergunta)
    geral = bool(re.search(r"\b(?:quais|todos|lista|listar|mostrar|mostre|ver)\b.*\b(?:comandos|botoes|teclas|controles)\b", texto))
    intencao = geral or bool(re.search(r"\b(?:botao|botoes|tecla|teclas|comando|comandos|controle|controles|aperto|apertar|pressionar|pressiono|clico|clicar)\b", texto))
    intencao = intencao or bool(re.search(r"\bcomo (?:eu |posso |faco (?:para |pra )?)?(?:correr|pular|saltar|rastejar|agachar|interagir|atirar|andar|movimentar|abrir (?:o )?inventario|usar (?:a )?lanterna|ligo (?:a )?lanterna|interajo|converso|conversar|usar (?:o )?radio)\b", texto))
    if not intencao:
        return None
    acoes = []
    if geral:
        acoes = list(NOMES)
    else:
        for acao, expressao in ALIASES.items():
            if re.search(r"\b(?:" + expressao + r")\b", texto):
                acoes.append(acao)
        if re.search(r"\b(?:andar|movimentar|movimento|mover|movimentacao)\b", texto):
            direcoes = [("esquerda", "move_left"), ("direita", "move_right"), ("cima", "move_up"), ("baixo", "move_down")]
            escolhidas = [acao for palavra, acao in direcoes if palavra in texto]
            acoes.extend(escolhidas or [acao for _, acao in direcoes])
    if not acoes:
        return None
    # Um mapa enviado, mesmo vazio, substitui o padrão: não inventa vínculos.
    mapa = PADRAO if controles is None else controles
    linhas = []
    for acao in dict.fromkeys(acoes):
        entradas = mapa.get(acao, [])
        linhas.append(NOMES[acao] + ": " + (" ou ".join(entradas) if entradas else "nenhum botão informado/configurado para esta ação."))
    notas = []
    if "lanterna" in acoes:
        notas.append("Mantenha o botão da lanterna pressionado para iluminar.")
    if "correr" in acoes or "rastejar" in acoes:
        notas.append("Para correr ou rastejar, mantenha o botão correspondente pressionado enquanto se movimenta.")
    return {"sucesso":True, "encontrou_resposta":True, "pergunta_recebida":pergunta, "resposta":"\n".join(linhas + notas), "modo_resposta":"comandos_configurados", "fonte_comandos":"mapa_entrada_godot" if controles is not None else "configuracao_padrao_api", "acoes":list(dict.fromkeys(acoes))}
