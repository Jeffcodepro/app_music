Rails app generated with [lewagon/rails-templates](https://github.com/lewagon/rails-templates), created by the [Le Wagon coding bootcamp](https://www.lewagon.com) team.

# Estrutura completa do projeto — App de Ensino Musical

## 1. Visão geral do produto

O aplicativo será uma plataforma de ensino musical com foco inicial em teoria musical, percepção, ritmo, leitura e harmonia, combinando estudo individual, prática recorrente, progressão gamificada e experiências coletivas em sala.

A proposta central do produto é unir três pilares:

1. **Aprender com clareza**: aulas em vídeo, modo guiado e explicações didáticas em texto.
2. **Praticar com constância**: exercícios por aula, playgrounds geradores e revisões.
3. **Evoluir com motivação**: nivelamento, trilhas personalizadas, modo carreira, rankings, bolsas de evolução e arena ao vivo.

---

## 2. Princípios do projeto

* O **nível do aluno** não é definido pelo plano.
* O **plano da assinatura** define profundidade de uso, volume de prática, recursos e liberdade.
* O aluno pode **começar do zero** ou fazer um **nivelamento inicial**.
* A plataforma monta uma **trilha personalizada por área**.
* O app deve atender tanto quem gosta de **experiência guiada** quanto quem prefere **estudo livre**.
* O produto deve parecer centrado em desenvolvimento real, não apenas em venda.
* O sistema de descontos deve reforçar essa mensagem por meio da **Bolsa de Evolução**.

---

## 3. Público-alvo inicial

### 3.1. Aluno iniciante

Quer entender teoria musical de forma simples, visual e acessível.

### 3.2. Aluno intermediário

Já estudou música antes, mas tem lacunas e quer organizar melhor o conhecimento.

### 3.3. Aluno avançado

Quer aprofundar escuta, leitura, harmonia, formas e história da música.

### 3.4. Professor

Quer usar a plataforma para revisar conteúdo, gamificar a aula, acompanhar desempenho e criar lobbies ao vivo.

---

## 4. Macroestrutura do aplicativo

A estrutura principal do app pode ser dividida em 10 grandes áreas:

1. **Landing page / site institucional**
2. **Cadastro, login e onboarding**
3. **Nivelamento inicial**
4. **Dashboard principal do aluno**
5. **Trilhas de estudo**
6. **Aulas**
7. **Prática e playgrounds**
8. **Modo carreira**
9. **Arena Musical ao Vivo**
10. **Perfil, progresso, assinatura e configurações**

Para professores, existirá ainda:

11. **Área do professor**

---

## 5. Estrutura pedagógica do conteúdo

O conteúdo será organizado por **áreas** e por **níveis internos**, não por planos.

### 5.1. Áreas principais

* Estruturação / Leitura
* Rítmica
* Percepção
* Harmonia
* Apreciação
* História da Música

### 5.2. Níveis internos do conteúdo

* Nível 1
* Nível 2
* Nível 3
* Nível 4

Esses níveis representam progressão pedagógica, e não travas comerciais.

---

## 6. Grade curricular da plataforma

## 6.1. Estruturação / Leitura

### Nível 1

* pauta musical
* claves
* símbolos básicos
* organização visual da música
* leitura inicial

### Nível 2

* consolidação da leitura
* figuras em contexto
* relação entre leitura e compasso
* leitura mais fluida

### Nível 3

* leitura com mais complexidade rítmica
* leitura associada à percepção e forma

### Nível 4

* leitura aplicada a contextos mais avançados
* interpretação estrutural da escrita musical

## 6.2. Rítmica

### Nível 1

* semibreves
* mínimas
* semínimas
* colcheias
* pulsação
* organização rítmica simples

### Nível 2

* semicolcheias
* compassos compostos
* subdivisão intermediária

### Nível 3

* mais de uma voz
* polirritmia
* ritmos tradicionais do Brasil
* ritmos de outros países
* ritmos mais complexos

### Nível 4

* estruturas rítmicas mais sofisticadas
* combinação de camadas rítmicas

## 6.3. Percepção

### Nível 1

* solfejos simples
* uníssono
* segundas
* terças
* oitavas

### Nível 2

* solfejos intermediários
* quartas
* quintas
* comparação auditiva

### Nível 3

* percepção em duas vozes
* sextas
* sétimas

### Nível 4

* duas ou mais vozes
* intervalos compostos
* reconhecimento contextual e comparativo

## 6.4. Harmonia

### Nível 1

* fundamentos de escalas
* graus
* organização tonal inicial

### Nível 2

* introdução à harmonia
* formação de acordes
* tríades
* relações básicas entre acordes

### Nível 3

* progressões
* campo harmônico
* ampliação da construção harmônica

### Nível 4

* funções harmônicas
* acordes com dissonância
* cadências
* relações tensionais

## 6.5. Apreciação

### Nível 1

* músicas conhecidas
* trilhas de filmes
* musicais
* curiosidades
* conexão com as demais áreas

### Nível 2

* identificação de instrumentos
* comparação de timbres
* famílias instrumentais

### Nível 3

* formas convencionais
* ABA
* ABACA
* repetição, contraste e retorno

### Nível 4

* formas clássicas
* sonata
* concerto
* tema e variações

## 6.6. História da Música

### Nível 3

* Medieval
* Renascentista
* Barroco

### Nível 4

* Clássico
* Romântico
* Século XX

---

## 7. Estrutura dos planos

## 7.1. Primeira Nota — gratuito

Objetivo: validar produto, atrair entrada e entregar valor real.

Inclui:

* nivelamento inicial
* uma trilha principal ativa
* modo guiado e modo livre
* exercícios por aula
* playground básico limitado
* início do modo carreira
* entrada em salas ao vivo como aluno

## 7.2. Pulso — R$ 34,90/mês

Plano para constância e base sólida.

Inclui:

* tudo do gratuito
* trilha personalizada mais completa
* mais prática diária
* playground expandido
* revisões automáticas
* mais checkpoints na carreira

## 7.3. Harmonia — R$ 49,90/mês

Plano para aprofundamento e treino consistente.

Inclui:

* tudo do Pulso
* mais trilhas simultâneas
* mais liberdade no playground
* exercícios mistos entre áreas
* desafios semanais
* carreira mais profunda
* ranking por categoria

## 7.4. Maestro — R$ 69,90/mês

Plano de experiência total.

Inclui:

* tudo do Harmonia
* acesso total às trilhas
* playground ilimitado
* simulados
* feedback inteligente
* treino adaptativo
* carreira total
* ranking completo e temporadas

### Valores anuais sugeridos

* Pulso: **R$ 329,90/ano**
* Harmonia: **R$ 469,90/ano**
* Maestro: **R$ 649,90/ano**

---

## 8. Bolsa de Evolução

Sistema de recompensa para upgrade entre planos com base em progresso real.

### Critérios gerais

* conclusão da trilha recomendada
* média mínima de acerto
* checkpoint ou pontuação mínima no modo carreira
* consistência mínima

### Faixas

* Progresso
* Destaque
* Excelência

### Fluxo

1. aluno conclui sua trilha atual
2. sistema calcula desempenho
3. bolsa é desbloqueada
4. aluno recebe desconto exclusivo para upgrade
5. bolsa fica válida por tempo limitado

---

## 9. Estrutura do onboarding

### 9.1. Boas-vindas

* apresentação da proposta
* botão “Começar do zero”
* botão “Fazer meu nivelamento”

### 9.2. Escolha do objetivo

* aprender teoria do zero
* melhorar leitura
* treinar percepção
* desenvolver ritmo
* aprofundar harmonia
* estudar de forma guiada
* estudar no próprio ritmo

### 9.3. Configuração inicial do perfil

* nome
* foto opcional
* instrumento principal opcional
* objetivo principal
* disponibilidade de estudo

### 9.4. Resultado do onboarding

* perfil musical inicial
* trilha recomendada
* primeiro módulo sugerido
* sugestão de frequência semanal

---

## 10. Nivelamento inicial

O nivelamento é uma das entradas principais do produto.

### Pilares avaliados

* Leitura
* Ritmo
* Percepção
* Harmonia / estrutura

### Tipos de questão

* múltipla escolha visual
* múltipla escolha sonora

### Resultado esperado

O sistema gera um mapa como:

* Leitura: nível 1
* Ritmo: nível 2
* Percepção: nível 1
* Harmonia: nível 1

Depois disso, monta a trilha recomendada.

---

## 11. Dashboard principal do aluno

O dashboard precisa ser simples, claro e motivador.

### Seções principais

* saudação inicial
* trilha atual
* próximo passo recomendado
* progresso semanal
* modo carreira
* playground sugerido
* desafios em aberto
* bolsa de evolução, se houver
* acesso rápido à Arena Musical

### Cards importantes

* continuar de onde parei
* revisar erros recentes
* treino rápido do dia
* posição na liga atual
* streak de estudo

---

## 12. Estrutura das trilhas

Cada trilha será uma jornada por área e nível.

### Exemplo

* Rítmica Nível 1
* Percepção Nível 2
* Harmonia Nível 1

### Cada trilha contém

* módulos
* aulas
* práticas
* checkpoints
* desafios finais

### Página da trilha

* visão geral
* mapa de progresso
* aulas liberadas
* práticas sugeridas
* status do checkpoint
* recompensa final

---

## 13. Estrutura da aula

Cada aula deve existir em dois modos:

### 13.1. Modo guiado

* vídeo dividido em blocos
* pausas interativas
* exercícios entre trechos
* continuação condicionada ao progresso

### 13.2. Modo livre

* vídeo completo sem interrupções obrigatórias
* explicação didática em texto
* exemplos visuais
* resumo da aula
* exercícios opcionais ao final

### Blocos da página da aula

* título e objetivo
* vídeo
* alternância entre modo guiado e modo livre
* resumo da teoria
* exemplos visuais
* erros comuns
* exercícios da aula
* botão para prática complementar

---

## 14. Estrutura da prática

A prática é a camada logo após a aula.

### Tipos

* exercícios de fixação
* exercícios de aplicação
* revisão curta
* mini checkpoint

### Formatos

* múltipla escolha visual
* múltipla escolha sonora
* completar leitura ou ritmo com opções

### Resultado

* acertos
* erros
* explicações
* recomendação de revisão
* sugestão de playground

---

## 15. Playground

Os playgrounds são geradores automáticos de treino por tema.

### Áreas iniciais

* leitura
* ritmo
* percepção
* harmonia
* apreciação

### Tela do playground

* escolha da área
* escolha do subtema
* escolha da dificuldade
* número de questões
* modo treino ou modo desafio
* relatório final

### Exemplos

#### Percepção

* identificar intervalos
* reconhecer padrão sonoro

#### Ritmo

* completar compasso
* reconhecer padrão rítmico

#### Leitura

* reconhecer nota
* identificar clave

#### Harmonia

* reconhecer acorde
* identificar campo harmônico

---

## 16. Modo carreira

O modo carreira é a camada de progressão e gamificação individual.

### Funções

* organizar evolução por degraus
* desbloquear novos desafios
* atribuir XP
* posicionar em ligas
* gerar metas de constância

### Estrutura sugerida de degraus

1. Fundamentos
2. Leitura e Pulso
3. Ritmo e Escuta
4. Intervalos e Estrutura
5. Harmonia Inicial
6. Organização Musical
7. Escuta Avançada
8. Forma e Estilo
9. Linguagem Harmônica
10. Maestria

### Tela do modo carreira

* degrau atual
* XP acumulado
* missão da semana
* checkpoints disponíveis
* histórico de evolução
* ranking da liga

---

## 17. Sistema de gamificação geral

### Elementos principais

* XP
* streak diário
* medalhas
* conquistas
* ligas
* ranking semanal
* ranking por categoria
* bolsa de evolução

### Exemplos de conquistas

* 7 dias seguidos
* 50 acertos em percepção
* concluir uma trilha
* subir de liga
* obter excelência em um checkpoint

---

## 18. Arena Musical ao Vivo

Módulo de quiz coletivo inspirado em salas ao vivo.

### Conceito

* professor cria um lobby
* escolhe tema e configuração
* alunos entram com nickname
* o lobby é fechado
* a partida começa
* perguntas são respondidas por múltipla escolha
* quem responde certo mais rápido ganha mais pontos
* ao final há pódio e ranking completo

### Formato fixo das respostas

Sempre múltipla escolha com 4 alternativas.

As 4 alternativas serão representadas por figuras musicais fixas, por exemplo:

* semibreve
* mínima
* semínima
* colcheia

### Tipos de pergunta

* visual
* sonora
* mista

### Modalidades iniciais

* quiz clássico
* revisão da aula
* desafio auditivo

### Configuração da sala

* tema
* quantidade de perguntas
* tempo por pergunta
* tipo de pergunta: visual, sonora ou mista
* dificuldade
* origem das perguntas
* avanço automático ou manual

### Fluxo do professor

1. criar sala
2. configurar rodada
3. compartilhar código
4. acompanhar entradas
5. fechar lobby
6. iniciar partida
7. ver resultados por rodada
8. acessar relatório final

### Fluxo do aluno

1. entrar com nickname
2. aguardar no lobby
3. responder perguntas
4. acompanhar ranking parcial
5. ver pódio final

### Resultado final

* pódio do 4º ao 1º quando aplicável
* ranking geral
* relatório para o professor com alunos que tiveram mais dificuldade

---

## 19. Área do professor

Essa área deve ser separada e orientada a uso em sala.

### Seções

* dashboard do professor
* criar lobby
* banco de quizzes
* histórico de partidas
* relatórios por turma
* desempenho por aluno
* recomendações de reforço

### Recursos futuros

* criação de turmas fixas
* convites por link
* biblioteca de quizzes salvos
* playlists de atividades

---

## 20. Perfil do aluno

### Seções

* dados pessoais
* objetivo atual
* instrumento principal
* histórico de estudo
* trilhas concluídas
* medalhas
* conquistas
* bolsas desbloqueadas
* histórico de ranking

---

## 21. Assinatura e monetização

### Páginas necessárias

* visão dos planos
* comparação entre planos
* página de upgrade
* detalhes da Bolsa de Evolução
* assinatura anual e mensal
* histórico de cobranças

### Estratégia de comunicação

* o plano amplia recursos, não define o potencial do aluno
* o aluno pode estudar no ponto certo para ele
* o progresso gera recompensas reais

---

## 22. Área administrativa interna

Para gestão do produto, será importante ter um painel interno.

### Funções

* cadastrar módulos e trilhas
* cadastrar perguntas visuais
* cadastrar perguntas sonoras
* gerenciar planos
* gerenciar bolsas de evolução
* acompanhar métricas do produto
* acompanhar uso da Arena Musical
* analisar retenção e conversão

---

## 22.1. Estratégia de mercado: Brasil primeiro, EUA como segunda etapa

O produto deve nascer com estrutura preparada para operar em dois mercados desde o início, mesmo que a validação comercial aconteça primeiro no Brasil.

### Fase 1 — Brasil

Objetivo: validar retenção, clareza pedagógica, conversão do gratuito para o pago e uso da Arena Musical em contexto real.

Diretrizes:

* idioma principal em português do Brasil
* conteúdo inicial com repertórios, exemplos e referências mais familiares ao público brasileiro
* preço base em real
* checkout adaptado ao Brasil
* foco em professores, alunos independentes e escolas livres

### Fase 2 — Estados Unidos

Objetivo: expandir para o mercado internacional com a mesma lógica de produto, mas com adaptação de linguagem, repertório, onboarding e posicionamento.

Diretrizes:

* inglês nativo em toda a experiência
* onboarding e marketing com linguagem própria do mercado americano
* exemplos e repertórios também contextualizados para o público dos EUA
* preço em dólar e comunicação local
* foco em music teachers, homeschooling, private lessons e music theory learners

### Implicações de produto

O app deve nascer preparado para:

* multilíngue
* multicurrency
* store listings localizadas
* trilhas e exemplos adaptáveis por mercado
* textos, notificações e e-mails localizados
* perguntas visuais e sonoras reutilizáveis com camadas de tradução

### Regra prática de construção

Não construir o produto como “versão brasileira que depois será traduzida”.
Construir como uma base internacional com:

* idioma padrão por locale
* conteúdo parametrizado
* marketing e pricing por território

---

## 22.2. Internacionalização e localização do produto

### Idiomas

* pt-BR
* en-US

### Elementos que precisam de localização

* landing page
* onboarding
* dashboard
* nomes de trilhas
* textos de aula
* legendas e explicações
* botões e mensagens do sistema
* e-mails
* textos de cobrança e assinatura
* Arena Musical
* relatório do professor

### Elementos que devem ser neutros desde o início

* arquitetura de navegação
* banco de perguntas
* estrutura dos planos
* regras de pontuação
* regras da carreira
* regras da Bolsa de Evolução

### Elementos que podem variar por mercado

* repertório citado em apreciação
* exemplos culturais
* comunicação comercial
* campanhas de aquisição
* preço final por território
* meios de pagamento

---

## 22.3. Estratégia de preços por território

### Brasil

* preços em real
* comunicação centrada em acessibilidade, evolução e flexibilidade
* meios de pagamento adaptados ao hábito local

### Estados Unidos

* preços em dólar
* posicionamento mais forte em progress tracking, music theory mastery, live classroom engagement e teacher tools
* comunicação mais direta e objetiva

### Regra de produto

O preço não precisa ser convertido apenas por câmbio.
O ideal é definir preço por percepção de valor em cada território.

---

## 22.4. Estratégia de pagamento e distribuição

### App stores

A Apple permite localizar a página do app por região e definir preços de assinaturas por storefront/território. ([developer.apple.com](https://developer.apple.com/app-store/subscriptions/?utm_source=chatgpt.com))

O Google Play também permite traduzir a store listing e ajustar preços por país ou região em moeda local. ([support.google.com](https://support.google.com/googleplay/android-developer/answer/6334373?hl=en&utm_source=chatgpt.com))

### Web checkout

No Brasil, vale priorizar meios de pagamento locais como Pix, além de cartões. A Stripe descreve o Pix como um método amplamente usado no Brasil. ([docs.stripe.com](https://docs.stripe.com/payments/pix?utm_source=chatgpt.com))

Para expansão internacional, é importante manter checkout com cartões e wallets, além de métodos relevantes por região. A Stripe lista cartões, wallets e outros grupos de métodos de pagamento para diferentes cenários. ([docs.stripe.com](https://docs.stripe.com/payments/payment-methods/overview?utm_source=chatgpt.com))

---

## 22.5. Ajustes de conteúdo para Brasil e EUA

### Brasil

* repertório próximo do aluno brasileiro
* ritmos tradicionais do Brasil com destaque
* comunicação didática mais acolhedora
* exemplos conectados a trilhas conhecidas do público local

### EUA

* exemplos de repertório e referências mais familiares ao público americano
* linguagem de produto mais objetiva
* destaque para skill building, ear training, theory drills, live classroom quiz e progress reports

### Importante

A estrutura curricular pode ser a mesma.
O que muda é principalmente:

* forma de comunicar
* exemplos usados
* contexto cultural de apoio

---

## 22. Área administrativa interna

Para gestão do produto, será importante ter um painel interno.

## 23.1. Parte pública

* Home
* Como funciona
* Planos
* Professores
* Arena Musical
* Perguntas frequentes
* Login / cadastro

## 23.2. Parte logada do aluno

* Dashboard
* Trilhas
* Aula atual
* Prática
* Playground
* Carreira
* Arena Musical
* Perfil
* Assinatura
* Configurações

## 23.3. Parte logada do professor

* Dashboard do professor
* Criar lobby
* Partidas ativas
* Histórico
* Relatórios
* Banco de quizzes
* Perfil do professor

---

## 24. Ordem recomendada de construção do produto

### Fase 1 — base do MVP

* landing page
* cadastro e login
* onboarding
* nivelamento inicial
* dashboard do aluno
* trilhas
* aulas com modo guiado e livre
* exercícios por aula
* playground básico
* planos e assinatura

### Fase 2 — retenção e progressão

* modo carreira
* ranking individual
* conquistas
* bolsa de evolução
* revisões automáticas

### Fase 3 — módulo social

* Arena Musical ao Vivo
* área do professor
* ranking por rodada
* pódio final
* relatório da turma

### Fase 4 — inteligência e expansão

* treino adaptativo
* feedback inteligente
* recomendações automáticas por desempenho
* criação avançada de salas
* recursos para escolas e professores

---

## 25. Métricas principais do produto

### Produto

* taxa de conclusão do onboarding
* taxa de conclusão do nivelamento
* retenção semanal
* aulas concluídas por usuário
* exercícios por usuário
* uso do playground
* participação na carreira

### Monetização

* conversão do gratuito para o pago
* upgrade entre planos
* uso da Bolsa de Evolução
* adesão ao anual

### Engajamento

* streak médio
* missões concluídas
* partidas da Arena Musical
* tempo médio no app

---

## 26. Posicionamento final do produto

Este app não será apenas um curso de teoria musical.

Ele será uma plataforma que combina:

* ensino claro
* prática recorrente
* personalização por nivelamento
* progressão visível
* gamificação individual
* gamificação coletiva para professores e turmas

A proposta final é:

**aprender música no ponto certo, praticar com propósito, evoluir com clareza e transformar teoria em experiência viva.**

---

## 27. Mapa de telas do aplicativo — visão Brasil e EUA

O mapa de telas deve ser construído desde o início com mentalidade multilíngue e multi-território.

A estrutura de navegação permanece a mesma em todos os mercados.
O que muda entre Brasil e EUA é principalmente:

* idioma
* moeda
* copy de marketing
* repertório e exemplos culturais
* meios de pagamento
* store listing e materiais promocionais

---

## 28. Arquitetura de navegação principal

### Navegação pública

* Home
* Como funciona
* Para alunos
* Para professores
* Arena Musical
* Planos
* FAQ
* Login
* Cadastro

### Navegação logada do aluno

* Dashboard
* Trilhas
* Aula atual
* Prática
* Playground
* Carreira
* Arena Musical
* Perfil
* Assinatura
* Configurações

### Navegação logada do professor

* Dashboard do professor
* Criar lobby
* Partidas ao vivo
* Histórico de partidas
* Relatórios
* Banco de quizzes
* Turmas
* Perfil
* Assinatura
* Configurações

### Navegação administrativa interna

* Dashboard administrativo
* Gestão de conteúdo
* Gestão de perguntas
* Gestão de planos
* Gestão de bolsas
* Gestão de usuários
* Analytics
* Configurações globais

---

## 29. Mapa de telas — área pública

## 29.1. Home

### Objetivo

Apresentar o produto e converter o usuário para cadastro ou teste.

### Blocos

* hero principal
* proposta de valor
* explicação do nivelamento
* explicação das trilhas personalizadas
* modos de estudo
* playgrounds
* modo carreira
* Arena Musical
* seção para professores
* planos
* Bolsa de Evolução
* depoimentos futuros
* FAQ
* CTA final

### BR

* linguagem mais acolhedora e didática
* exemplos mais próximos do público brasileiro
* destaque para flexibilidade, evolução e prática

### EN-US

* linguagem mais direta
* destaque para progress tracking, live music theory quizzes, ear training, classroom engagement e teacher tools

## 29.2. Como funciona

### Objetivo

Explicar a jornada do aluno em passos.

### Seções

* começar do zero ou fazer nivelamento
* receber trilha personalizada
* estudar com aulas guiadas ou livres
* praticar com playgrounds
* evoluir no modo carreira
* participar da Arena Musical

## 29.3. Para alunos

### Objetivo

Explicar os benefícios para quem estuda sozinho.

### Seções

* estudo no ponto certo
* teoria aplicada
* prática recorrente
* progresso visível
* flexibilidade de ritmo

## 29.4. Para professores

### Objetivo

Mostrar valor do produto em contexto de turma.

### Seções

* criar lobbies
* usar quizzes ao vivo
* acompanhar desempenho
* identificar dificuldades da turma
* gamificar revisão

## 29.5. Arena Musical

### Objetivo

Explicar a experiência ao vivo.

### Seções

* como o lobby funciona
* perguntas visuais e sonoras
* múltipla escolha com figuras musicais
* pontuação por velocidade
* ranking e pódio
* relatório do professor

## 29.6. Planos

### Objetivo

Comparar planos e reforçar que o plano não define o nível do aluno.

### Seções

* Primeira Nota
* Pulso
* Harmonia
* Maestro
* mensal x anual
* Bolsa de Evolução

## 29.7. FAQ

### Perguntas principais

* preciso saber música para começar?
* o plano define meu nível?
* como funciona o nivelamento?
* posso estudar no meu ritmo?
* como funcionam os playgrounds?
* como funciona a Arena Musical?
* posso usar em sala de aula?
* como funciona a Bolsa de Evolução?

## 29.8. Login

## 29.9. Cadastro

### Opções sugeridas

* e-mail
* Google
* Apple
* login como aluno
* login como professor

---

## 30. Mapa de telas — onboarding e entrada

## 30.1. Tela de boas-vindas

### Objetivo

Receber o usuário e apresentar os dois caminhos.

### CTAs

* Quero começar do zero
* Quero fazer meu nivelamento

### BR

Texto mais acolhedor.

### EN-US

Texto mais objetivo.

## 30.2. Escolha do perfil

* Aluno
* Professor

## 30.3. Objetivo principal

* aprender teoria do zero
* melhorar leitura
* treinar percepção
* desenvolver ritmo
* aprofundar harmonia
* usar em sala

## 30.4. Disponibilidade de estudo

* dias por semana
* tempo por sessão
* preferência por modo guiado ou livre

## 30.5. Nivelamento — introdução

Explica como o teste funciona.

## 30.6. Nivelamento — bloco de leitura

Perguntas visuais.

## 30.7. Nivelamento — bloco de ritmo

Perguntas visuais e sonoras.

## 30.8. Nivelamento — bloco de percepção

Perguntas sonoras.

## 30.9. Nivelamento — bloco de harmonia

Perguntas visuais e sonoras.

## 30.10. Resultado do nivelamento

### Exibe

* mapa por área
* pontos fortes
* pontos de reforço
* trilha recomendada
* primeiro módulo sugerido

## 30.11. Onboarding final

### Exibe

* dashboard inicial
* primeira aula recomendada
* treino rápido sugerido

---

## 31. Mapa de telas — área do aluno

## 31.1. Dashboard do aluno

### Blocos

* saudação
* continuar estudando
* trilha atual
* progresso semanal
* treino do dia
* carreira
* ranking
* Arena Musical
* Bolsa de Evolução

### BR

Tom mais explicativo.

### EN-US

Tom mais enxuto e orientado à ação.

## 31.2. Página de trilhas

### Função

Mostrar todas as trilhas disponíveis e as recomendadas.

### Blocos

* trilhas recomendadas
* trilhas em andamento
* trilhas concluídas
* trilhas complementares
* filtros por área

## 31.3. Página da trilha

### Blocos

* visão geral
* objetivo da trilha
* módulos
* progresso
* checkpoint
* recompensa final
* recomendação de playground

## 31.4. Página do módulo

### Blocos

* resumo do módulo
* aulas do módulo
* práticas
* mini desafio
* checkpoint final

## 31.5. Página da aula

### Blocos

* título
* objetivo
* botão modo guiado
* botão modo livre
* vídeo
* resumo didático
* exemplos
* erros comuns
* exercícios da aula
* CTA para prática complementar

## 31.6. Página de prática da aula

### Blocos

* exercícios de fixação
* exercícios de aplicação
* revisão curta
* mini relatório

## 31.7. Página de revisão

### Blocos

* erros recentes
* tópicos a revisar
* revisões sugeridas
* atalho para playground

## 31.8. Página de playground

### Blocos

* escolha da área
* subtema
* nível recomendado
* dificuldade
* número de questões
* modo treino
* modo desafio

## 31.9. Sessão de playground

### Blocos

* pergunta
* cronômetro opcional
* respostas
* feedback imediato
* progresso da sessão

## 31.10. Resultado do playground

### Blocos

* taxa de acerto
* erros por categoria
* tempo médio
* recomendação de revisão
* botão repetir

## 31.11. Página do modo carreira

### Blocos

* degrau atual
* XP
* missão da semana
* checkpoints
* histórico
* liga atual
* ranking da liga

## 31.12. Página de missões

### Blocos

* missões diárias
* missões semanais
* recompensas
* streak

## 31.13. Página de conquistas

### Blocos

* medalhas
* selos
* marcos concluídos
* bolsas conquistadas

## 31.14. Ranking

### Blocos

* ranking geral
* ranking por categoria
* ranking por liga
* ranking semanal

## 31.15. Arena Musical — entrada do aluno

### Blocos

* inserir código
* nickname
* avatar opcional
* entrar no lobby

## 31.16. Arena Musical — lobby do aluno

### Blocos

* lista de participantes
* status da sala
* aguardando professor

## 31.17. Arena Musical — rodada ao vivo

### Blocos

* número da pergunta
* timer
* pergunta visual ou sonora
* 4 alternativas com figuras musicais
* confirmação de resposta enviada

## 31.18. Arena Musical — resultado da rodada

### Blocos

* resposta correta
* pontuação da rodada
* colocação parcial

## 31.19. Arena Musical — pódio final

### Blocos

* animação do 4º ao 1º
* top final
* CTA para ver ranking completo

## 31.20. Arena Musical — ranking final

### Blocos

* posição
* nickname
* pontos
* acertos
* tempo médio

## 31.21. Perfil

### Blocos

* dados pessoais
* objetivo atual
* histórico de estudo
* trilhas concluídas
* conquistas

## 31.22. Assinatura

### Blocos

* plano atual
* comparativo
* upgrade
* anual x mensal
* Bolsa de Evolução disponível

## 31.23. Configurações

### Blocos

* idioma
* notificações
* preferências de estudo
* áudio
* conta

---

## 32. Mapa de telas — área do professor

## 32.1. Dashboard do professor

### Blocos

* turmas ativas
* lobbies recentes
* desempenho médio das turmas
* quizzes mais usados
* atalhos rápidos

## 32.2. Criar lobby

### Campos

* nome da sessão
* tema
* origem das perguntas
* visual, sonora ou mista
* quantidade de perguntas
* tempo por pergunta
* modo de avanço
* dificuldade

## 32.3. Lobby aberto

### Blocos

* código da sala
* link
* participantes entrando
* status de pronto
* remover participante
* fechar lobby
* iniciar partida

## 32.4. Rodada ao vivo — visão do professor

### Blocos

* pergunta atual
* timer
* quantidade de respostas enviadas
* total de participantes
* ranking parcial
* botão avançar

## 32.5. Resultado da rodada — visão do professor

### Blocos

* resposta correta
* distribuição de respostas
* melhor pontuação da rodada
* ranking parcial

## 32.6. Pódio final

### Blocos

* exibição do pódio
* top colocados
* botão ver relatório completo

## 32.7. Relatório da partida

### Blocos

* ranking completo
* desempenho por aluno
* acertos por tema
* tempo médio de resposta
* perguntas com maior erro
* alunos com maior dificuldade

## 32.8. Histórico de partidas

### Blocos

* lista de quizzes realizados
* filtros por turma, tema e data
* atalho para reusar sessão

## 32.9. Banco de quizzes

### Blocos

* categorias
* perguntas salvas
* quizzes favoritos
* criação futura de listas próprias

## 32.10. Turmas

### Blocos

* turmas criadas
* alunos vinculados
* desempenho geral

## 32.11. Perfil do professor

## 32.12. Assinatura do professor

## 32.13. Configurações do professor

---

## 33. Mapa de telas — área administrativa

## 33.1. Dashboard administrativo

* métricas gerais
* crescimento
* conversão
* retenção
* uso da Arena Musical

## 33.2. Gestão de conteúdo

* áreas
* trilhas
* módulos
* aulas
* práticas

## 33.3. Gestão de perguntas

* perguntas visuais
* perguntas sonoras
* tags por tema
* tags por dificuldade
* locale BR e EN-US

## 33.4. Gestão de planos

* Primeira Nota
* Pulso
* Harmonia
* Maestro
* preços por território

## 33.5. Gestão de bolsas

* critérios
* faixas
* validade

## 33.6. Gestão de usuários

* alunos
* professores
* status de assinatura

## 33.7. Analytics

* uso por tela
* abandono
* conversão
* retenção

## 33.8. Configurações globais

* idiomas
* moedas
* textos institucionais
* banners
* store assets

---

## 34. Regras de localização BR e EN-US por tela

## 34.1. Elementos que devem ser localizados

* todos os textos de interface
* títulos de páginas
* CTAs
* mensagens de erro
* onboarding
* e-mails
* notificações
* landing page
* FAQ
* assinatura
* relatórios do professor

## 34.2. Elementos que podem variar culturalmente

* exemplos em apreciação
* repertório citado
* curiosidades musicais
* exemplos históricos de apoio
* campanhas promocionais

## 34.3. Elementos que devem ser estruturalmente idênticos

* arquitetura de navegação
* fluxo das trilhas
* lógica do nivelamento
* lógica do modo carreira
* regras da Arena Musical
* regras da Bolsa de Evolução
* estrutura dos planos

---

## 35. Priorização de telas para o MVP

### MVP público

* Home
* Como funciona
* Planos
* Login
* Cadastro

### MVP aluno

* onboarding
* nivelamento
* dashboard
* trilhas
* aula
* prática
* playground básico
* assinatura
* perfil básico

### MVP carreira

* degrau atual
* XP
* missão da semana

### MVP Arena Musical

* criar lobby
* entrar com código
* lobby aberto
* rodada ao vivo
* resultado da rodada
* pódio final
* relatório simples do professor

### MVP internacional

* suporte a pt-BR e en-US
* conteúdo e interface localizáveis
* pricing por território
* copy separada por mercado

---

## 36. Próximo desdobramento recomendado

Depois do mapa de telas, o ideal é detalhar na sequência:

1. fluxograma de navegação entre telas
2. wireframe textual de cada tela principal
3. definição dos componentes reutilizáveis
4. estrutura da landing page BR
5. estrutura da landing page EN-US
6. priorização técnica do MVP
