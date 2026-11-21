# Integração atualizada para a API 3.0.0

Fonte: https://github.com/mandsmelo/MLCB_Campos-Zone.git
Commit conferido: 61f6cdbbbad3e4d00a4441cea5b60164ac059b6f

Esta versão substitui a integração anterior. NÃO é necessário instalar ou
executar Ollama/Qwen: o chatbot agora recupera respostas da base semântica.

## Primeira execução no Windows

1. Extraia todo o projeto em uma pasta nova.
2. Tenha Python 64 bits com o lançador py disponível. Confira: py --version
3. Execute ServidorIA/PREPARAR_API.bat e aguarde a conclusão.
   Esse arquivo cria .venv, instala requirements.txt, reconstrói o banco vetorial
   e executa regressao/treinamento.py com o CSV atual do GitHub. Recriar o modelo
   no mesmo ambiente evita incompatibilidade entre versões de scikit-learn.
   Os resultados de avaliação locais são recalculados pelo script do repositório.
   A primeira preparação requer internet para dependências e embeddings.
4. Execute ServidorIA/INICIAR_API.bat e mantenha a janela aberta.
5. Abra http://127.0.0.1:8000/health e verifique o status dos DOIS serviços.
   A API pode iniciar mesmo que chatbot ou regressão tenham falhado.
6. A documentação web fica em http://127.0.0.1:8000/docs.
7. Abra project.godot na Godot, inicie a partida e pressione F1.
   Verificar API consulta /health; Perguntar consulta /faq/search;
   Estimar tempo consulta /predict/value. F1 ou Esc fecha a janela.

Nas próximas execuções: apenas INICIAR_API.bat e o jogo.
Não precisa reconstruir banco ou treinar a cada partida.
Se alguma etapa falhar, leia a mensagem do terminal; não continue como se a
preparação tivesse sido concluída.

## Campos atuais da previsão

- distancia_percorrida_unidades: unidades do mundo Godot, não metros.
- dano_recebido: impactos/vidas perdidas acumulados; inteiro não negativo.
- itens_coletados: quantidade acumulada; inteiro não negativo.
- salas_exploradas: quantidade; inteiro não negativo.
- tempo_decorrido_min: minutos já decorridos da missão.

A resposta traz previsao.tempo_restante_minutos e previsao.mae_referencia_minutos.
Não envia mais zumbis_derrotados nem dificuldade. Esses campos pertenciam à API
antiga. O painel continua com preenchimento MANUAL, sem coleta automática.
A previsão é experimental e o treinamento usa dados sintéticos.

## Arquivos

ServidorIA contém os arquivos atuais do GitHub e os dois atalhos .bat adicionados.
O banco vetorial binário do GitHub foi excluído do pacote de propósito e é
reconstruído pela preparação. O último commit removeu parte dos arquivos desse
banco; copiar apenas o SQLite não garante uma base utilizável.
Scripts/assistente_ia.gd adapta o painel do jogo ao contrato atual da API.
O arquivo original integracao_godot/InterfaceML.gd está preservado dentro de
ServidorIA como referência, mas não foi anexado em paralelo para evitar duas UIs.
O Autoload AssistenteIA já está configurado. Cooperativo permanece igual.

## Validação

Verificados os campos e as chaves de resposta contra api/servidor.py do commit
informado. Testes Godot 4.6.3 com servidor HTTP simulado para saúde, chatbot,
previsão e erro de rede. O download dos embeddings e a execução real de Chroma e
scikit-learn precisam ser concluídos no seu computador. A configuração original
de versão Godot 4.7 foi preservada.


## Atualização: perguntas sobre botões

A Godot envia o campo opcional controles junto da pergunta. Ele é construído pelo
InputMap em tempo de execução. Quando uma tecla mudar no jogo, a próxima pergunta
receberá o novo vínculo. Não é necessário reindexar apenas para mudar uma tecla.

Perguntas como "Qual botão clico para interagir?", "Como faço para correr?" e
"Quais são os comandos?" recebem os vínculos exatos. As outras perguntas continuam
na busca semântica. As respostas de comandos não precisam do modelo de embeddings
estar disponível, mas a API Python precisa estar em execução.

No /docs, sem o campo controles, a API usa api/controles_padrao.json, preenchido
com os botões das fotos enviadas. Para testar, envie:
{"pergunta":"Qual botão clico para interagir?"}
Para testar uma tecla alterada sem mudar o jogo:
{"pergunta":"Qual botão clico para interagir?","controles":{"interagir":["Teclado: E"]}}
Um mapa enviado substitui os padrões; ações ausentes são informadas sem vínculo.
O arquivo api/comandos.py trata essas perguntas e api/servidor.py o integra à rota.
Também foram atualizadas as respostas sobre comandos na base JSON. Ao reutilizar
um ambiente existente, reconstrua o banco com a indexação e reinicie o servidor.

Mapa das fotos: WASD/analógico esquerdo para movimento; Shift/R2/RT para rastejar;
Espaço/X/A para pular; Ctrl/R1/RB para correr; L2/LT para lanterna; Círculo/B para
interagir; direcional cima para rádio; direcional esquerda para inventário;
F/L1/LB para atirar. O inventário e os equipamentos de P2 continuam com as
limitações descritas em LEIA_COOPERATIVO.md; conhecer o botão não libera funções.

Validação adicional: comandos padrão, mapa enviado, remapeamento para E em tempo
de execução, ação sem vínculo, consultas não relacionadas e leitura do InputMap
real na Godot. A rota FAQ também foi validada isoladamente para esse desvio.
