# 🎮 Campos Zone

### Game Development • Machine Learning • API Integration

Repositório oficial do **Campos Zone**, um projeto acadêmico de desenvolvimento de um jogo cooperativo de sobrevivência contra zumbis, acompanhado de soluções de Machine Learning e integração de sistemas.

O projeto reúne desenvolvimento de jogos com a Godot Engine, inteligência artificial, processamento de dados e serviços disponibilizados por meio de uma API REST.

---

## 📌 Sobre o projeto

O Campos Zone é um jogo cooperativo de sobrevivência contra zumbis, desenvolvido em contexto universitário.

Além do desenvolvimento do jogo, o projeto explora aplicações de Machine Learning para aprimorar a experiência dos jogadores, por meio de duas soluções:

- **Chatbot inteligente:** sistema de perguntas e respostas baseado em busca semântica, permitindo consultar informações sobre as mecânicas do jogo.
- **Modelo de regressão:** solução para estimar o tempo restante das missões com base nas características da partida.

As soluções são disponibilizadas por uma API desenvolvida em Python com FastAPI e integradas ao jogo por meio de requisições HTTP.

---

## 🎮 1. Desenvolvimento do jogo

O jogo Campos Zone é desenvolvido utilizando a Godot Engine, reunindo mecânicas de sobrevivência, exploração e cooperação entre jogadores.

O projeto completo do jogo está disponível no diretório:

📂 jogo godot/

**Tecnologia principal:**
- Godot Engine
- GDScript

### Como executar

1. Instale a Godot Engine.
2. Abra o Godot Project Manager.
3. Selecione a opção de importar um projeto existente.
4. Localize a pasta do jogo dentro de `jogo godot/`.
5. Selecione o arquivo `project.godot`.
6. Abra o projeto e execute a cena principal.

---

## 🧠 2. Machine Learning

Esta frente concentra as soluções inteligentes desenvolvidas para o jogo.

### 2.1 Chatbot com busca semântica

Desenvolvimento de um chatbot que utiliza embeddings e similaridade semântica para recuperar respostas de uma base de conhecimento sobre as mecânicas do jogo.

**Tecnologias:**
- Python
- FastAPI
- Sentence Transformers
- ChromaDB

**Resultados da avaliação:**

| Métrica | Resultado |
|---|---:|
| Perguntas e respostas indexadas | 30 |
| Precisão Top-1 | 75,00% |
| Recall@3 | 91,67% |
| Similaridade média do primeiro resultado | 63,71% |
| Tempo médio de busca vetorial | 4,21 ms |
| Maior tempo médio por pergunta | 5,55 ms |

A busca utiliza similaridade de cosseno e armazenamento vetorial com ChromaDB.

Endpoint: `POST /faq/search`

*Observação: os tempos apresentados correspondem exclusivamente à busca vetorial, sem incluir a geração dos embeddings ou o processamento total da API.*

### 2.2 Modelo de regressão

Desenvolvimento de um modelo para estimar o tempo restante de uma missão com base nas características da partida.

**Variáveis utilizadas:**
- Distância percorrida;
- Dano recebido;
- Itens coletados;
- Salas exploradas;
- Tempo decorrido.

Foram utilizados 600 registros simulados para treinamento e avaliação de dois modelos.

**Comparação dos modelos:**

| Métrica | Regressão Linear | Random Forest |
|---|---:|---:|
| MAE | 1,8632 | 2,6522 |
| RMSE | 2,2830 | 3,3003 |
| R² | 0,9276 | 0,8487 |

A Regressão Linear apresentou o melhor desempenho e foi escolhida para disponibilização na API.

Endpoint: `POST /predict/value`

*Observação: os dados utilizados são simulados, não provenientes de partidas reais.*

---

## 🔌 3. API e integração

O projeto utiliza FastAPI para disponibilizar os serviços de Machine Learning por meio de uma API REST.

**Endpoints disponíveis:**

| Endpoint | Método | Funcionalidade |
|---|---|---|
| `/` | GET | Informações da API |
| `/health` | GET | Verificação de disponibilidade |
| `/faq/search` | POST | Busca semântica no chatbot |
| `/predict/value` | POST | Previsão do tempo restante da missão |

A integração com a Godot acontece por meio de requisições HTTP.

Dessa forma, o jogo pode consultar os serviços disponibilizados pela API, permitindo que o chatbot responda dúvidas dos jogadores e que o modelo de regressão forneça estimativas sobre a duração das missões.

---

## ⚙️ 4. Como executar a API

### Pré-requisitos

- Python instalado;
- Git;
- Dependências listadas em `requirements.txt`.

### Instalação

Clone o repositório:

```bash
git clone https://github.com/mandsmelo/Campos-Zone-Project.git
```

Entre na pasta:

```bash
cd Campos-Zone-Project
```

Instale as dependências:

```bash
pip install -r requirements.txt
```

Inicie a API:

```bash
uvicorn api.servidor:app --reload
```

A documentação interativa da API estará disponível em:

`http://127.0.0.1:8000/docs`

### Outros comandos

Para criar ou reconstruir a base vetorial:

```bash
python chatbot/indexacao.py
```

Para avaliar a recuperação semântica:

```bash
python chatbot/avaliar_sinonimos.py
```

O relatório da avaliação é salvo em:

`resultados/avaliacao_sinonimos.csv`

---

## 🛠️ 5. Tecnologias utilizadas

**Desenvolvimento de jogos**
- Godot Engine
- GDScript

**Machine Learning e dados**
- Python
- Scikit-learn
- Pandas
- Jupyter Notebook
- Sentence Transformers
- ChromaDB

**Backend e integração**
- FastAPI
- API REST
- HTTP
- Git
- GitHub

---

## 👥 6. Equipe e colaboração

O projeto é desenvolvido de forma colaborativa, com participação dos integrantes nas atividades de programação, desenvolvimento do jogo, implementação de modelos, integração de sistemas, testes e documentação.

---

## 📊 7. Considerações finais

O Campos Zone reúne desenvolvimento de jogos e aplicações de Machine Learning em um mesmo ecossistema.

A implementação do chatbot com busca semântica e do modelo de regressão demonstra a aplicação prática de técnicas de aprendizado de máquina em um contexto de desenvolvimento de jogos.

A disponibilização dos modelos por meio de uma API REST permite a integração das soluções com a Godot Engine, conectando inteligência artificial e experiência interativa.
