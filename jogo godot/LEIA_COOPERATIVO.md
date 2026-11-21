# Cooperativo local — atualização 2

1. Extraia este ZIP em uma pasta nova pelo Explorador do Windows.
2. Importe project.godot na Godot e execute pelo menu principal.
3. Conecte dois controles e selecione Cooperativo.

Atualizações:
- Removidas as etiquetas P1/P2 sobre os personagens. A tonalidade azul foi mantida.
- Zumbis escolhem o jogador vivo e visível mais próximo, respeitando os alcances,
  paredes e esconderijos existentes. Podem perseguir e atacar P2.
- P2 pode interagir com portas genéricas, porta da enfermagem, passagens, entrada
  da cena 2 e áreas do coordenador/Stella. Só o controle do jogador dentro da área
  pode iniciar a interação. As chaves e requisitos de história continuam compartilhados.
- Conversas são compartilhadas: ambos param e ambos podem avançar o texto.
- Nas caminhadas automáticas que bloqueiam P1, P2 acompanha a posição de P1 com
  deslocamento de 32 pixels para cima, copiando direção e animação. Não é preciso
  duplicar os Marker2D. Reserve espaço nessa faixa deslocada do caminho.
- Portas continuam levando a dupla à mesma sala; P2 reaparece ao lado de P1.

Mantidos: câmera compartilhada, movimento/corrida/rastejo/pulo por controle,
colisões, stamina independente e a opção solo. Caso um jogador morra, a dupla
retorna ao checkpoint da sala conforme a versão anterior.

Ainda não incluídos: coleta, armas, lanterna, inventário e HUD individuais de P2.
Os requisitos de notebook/alicate das portas consultam o inventário de P1.
A coleta dos itens continua com P1. Esta atualização não altera esses sistemas.

Validação automatizada na Godot 4.6.3: movimento independente por eventos de dois
dispositivos, ausência de etiquetas, escolha de P2 pelo zumbi, exclusão de jogador
morto, interação de área por dispositivo e deslocamento de 32px na cutscene.
Não foi possível testar dois controles físicos neste ambiente.
