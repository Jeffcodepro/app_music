# AppMusic — UI/UX 02: resultado para revisão independente

19/10/2026. Implementação local concluída para revisão do Hermes. A área autenticada recebeu um App Shell responsivo, temas, componentes compartilhados e apresentação apoiada em dados reais. Recursos futuros continuam identificados como indisponíveis. Não houve commit, push, deploy ou início de outra missão.

## 1. Inventário e alcance

O levantamento anterior às alterações está em [uiux-02-inventario.md](uiux-02-inventario.md), com finalidade, template, layout, componentes, dados, controles, dependências, problemas e prioridade por rota. Foram examinados rotas, controllers, helpers, modelos, templates, SCSS, Stimulus e testes. Os três documentos exigidos — modelo canônico, resultado da Missão 03.1 e UX-01 — orientaram a preservação.

Foram visitadas **34 rotas/variações autenticadas** e **quatro páginas anônimas de autenticação**. Isso inclui os seis temas de trilha, uma URL representativa da trilha por nível, duas URLs legadas de aula, quatro Playgrounds, histórico, conta, credenciais, nivelamento, carreira, Arena, desafios, ranking, conquistas, bolsa, planos, cobranças e os cinco passos de onboarding. `/app` também foi visitado e redirecionou a `/app/dashboard`.

Não há rotas de professor/admin no projeto atual. Templates de confirmação e desbloqueio Devise não têm rotas habilitadas pelo modelo atual. Callbacks OAuth e envio de e-mail real não foram exercitados; o formulário de nova senha foi visitado com token exclusivamente sintético, sem alterar senha. Não foram enumerados todos os valores possíveis dos parâmetros `:id`, `:area` e `:nivel`; a matriz registra as URLs efetivamente visitadas.

## 2. Correções por área

| Área | Problema anterior | Resultado / justificativa |
| --- | --- | --- |
| Navegação compartilhada | Menu empilhado, cabeçalho alto, busca sem backend, notificação “3”, subrotas sem destaque | Lista única de navegação, cabeçalho compacto, seção ativa, busca/notificação removidas; gaveta modal e rail no tablet |
| Dashboard | Atividades chamadas aulas; minutos estimados apresentados como medidos; métricas repetidas e recomendações sem aula | XP/dias registrados, contagem de respostas persistidas, quatro práticas e histórico real; estado vazio específico |
| Trilhas | Currículo planejado e progressão por volume apresentados como disponíveis | Quatro áreas reais e descrição honesta da ausência de sequência/avaliação de domínio; temas sem gerador exibem preparação |
| Aulas e URLs antigas | Player fictício, temporadas, episódios A1–A6, duração/progresso inventados e velocidades inertes | Um único estado de preparação, sem catálogo artificial; URLs continuam seguras e oferecem práticas reais |
| Resultado de prática | 16 acertos, 4 erros e recomendação fixos | Histórico de respostas persistidas do usuário, totais corretos/incorretos e últimas 50 respostas, sem inferir aula ou domínio |
| Playgrounds | Paleta fixa e contexto de Harmonia desequilibrado | Temas explícitos, ajustes de contraste, contexto complementar recolhível; pergunta/alvo visíveis e áudio/alternativas equilibrados |
| Nivelamento/carreira/Arena | Recursos planejados com aparência de produto pronto | Estados de indisponibilidade com próxima ação real; nenhum lobby, avaliação ou schema criado |
| Desafios/ranking/conquistas/bolsa | Metas, ligas, critérios e benefícios sem implementação | Estados honestos; nenhuma regra comercial ou premiação inventada |
| Conta/planos/cobranças | Labels sem associação; preços/benefícios/gateway fictícios; status de cobrança “ativo” | Formulário real com labels, tema local, credenciais e sessão; plano registrado sem alegar pagamento; preços/promessas removidos |
| Onboarding | Recomendações e nível fixos; gateway inexistente | Preferências da sessão identificadas como tais; nenhuma avaliação fictícia; entrada por Primeira Nota sem promessa de pagamento |
| Devise | Aparência e idioma de rótulos inconsistentes, dependência do protótipo | Layout de autenticação próprio; formulários reais preservados; provedores OAuth só aparecem quando configurados |

As classificações de domínio continuam distintas: práticas/autenticação/perfil são funcionais; trilhas/onboarding são parciais; aulas, avaliação, carreira, Arena e benefícios ainda não estão implementados. O novo estado vazio é uma interface funcional de indisponibilidade, não a entrega desses produtos.

## 3. Referências e decisões próprias

Pesquisa em fontes públicas oficiais; não houve acesso aos aplicativos pagos/autenticados dessas empresas nem cópia de marca, imagens ou componentes:

- [flowkey](https://www.flowkey.com/en): prioridade do material musical e dos controles de prática. Aplicação própria: pauta e áudio próximos da pergunta, sem criar um vídeo inexistente.
- [Yousician — caminhos de aprendizado](https://support.yousician.com/hc/en-us/articles/204697992-How-the-piano-learning-path-works): agrupamento por tema e próximos passos. O site principal retornou 403; foi consultado o suporte oficial. AppMusic mostra somente os caminhos de prática existentes.
- [Fender Play](https://www.fender.com/play): hierarquia por objetivo e estudo no próprio ritmo. Aplicação própria: uma ação principal, sem catálogo ou níveis comerciais simulados.
- [musictheory.net](https://www.musictheory.net/exercises): descoberta direta por família de exercícios. Aplicação própria: quatro áreas e acesso contextual às configurações.
- [Flat for Education](https://flat.io/edu): notação como conteúdo principal. Aplicação própria: cores explícitas do SVG e dimensão musical preservada.
- [EarMaster](https://www.earmaster.com/): organização de atividades de escuta e ritmo, com apresentação também em tablet. Aplicação própria: referência de áudio acessível e alternativas com espaço de leitura.

A identidade escolhida combina papel claro, tinta verde, acento terracota, ícones SVG locais e linguagem acolhedora. Não foram incorporados assets dessas referências.

## 4. Design system e temas

`_platform_ui.scss` define tokens de fundo/superfície/texto/bordas/estados/foco, tipografia, espaçamento de referência de 8px, raios, sombras, cards, botões, formulários, empty states e histórico. A escala usa títulos responsivos, corpo 15px, campos 16px e informações auxiliares de 12–14px. Os controles principais têm alvos de pelo menos 44px.

Geometria dos exercícios foi extraída para `_exercise_components.scss`; a compactação UX-01 permanece em `_playground_compact.scss`; `_exercise_theme.scss` integra cores e a distribuição de Harmonia. Os imports dos protótipos `_app_chrome`, `_platform`, `_account_page` e `_dashboard_clean` foram retirados do bundle; seus arquivos históricos permanecem no repositório. Não foi introduzida biblioteca importante nem instalada dependência.

**Sistema/Claro/Escuro:** preferência local `app_music_theme`; script no head resolve o tema antes do CSS. O controller acompanha sistema, outras abas e navegação Turbo; trata storage indisponível e remove listeners ao desconectar. Os dois seletores da conta ficam sincronizados. O tema não exige migration.

Partituras usam `--score-paper`, `--score-ink` e `--score-staff` por seletores explícitos de fill/stroke. Não há `filter: invert()`, mudança de coordenada, nota, ataque ou frequência. Imagens de instrumentos conservam seu fundo legível.

## 5. Desktop, tablet, mobile e Turbo

- **≥1200px:** sidebar de 232px, recolhível para 76px, com escolha persistida. Conteúdo limitado a 1280px e cabeçalho compacto.
- **768–1199px:** rail de 76px e expansão em gaveta modal. Verificados retrato e paisagem.
- **<768px:** menu fora do fluxo, aberto pelo hambúrguer. Overlay, Escape, clique fora e escolha de rota fecham a gaveta; o conteúdo não é empurrado para baixo.
- `aria-controls`, `aria-expanded`, identificação do diálogo, contenção de foco nos dois sentidos, restauração do foco, fundo `inert` e bloqueio de rolagem implementados. O estado aberto é removido antes do cache Turbo; mudança de viewport também fecha a gaveta.
- Três ciclos Turbo preservaram o estado JavaScript e o comportamento de um único toggle; voltar pelo histórico restaurou o fundo operável e o menu fechado.

Autenticação e callbacks existentes continuam com Devise. O layout público legado permanece fora da reformulação; seus scripts de protótipo agora possuem `data-turbo-track=reload` para não atravessarem a troca para os layouts da plataforma/autenticação. A área autenticada não carrega Tailwind ou Lucide do protótipo.

## 6. Dados e preservação funcional

| Informação | Fonte / limite |
| --- | --- |
| XP acumulado | `current_user.study_activities.sum(:xp_earned)`; política de crédito existente |
| Dias registrados | Datas distintas de `StudyActivity.occurred_on`; não é avaliação de domínio |
| Respostas/correção/histórico | `ExerciseAttempt` associado a `ExerciseAssignment` do usuário atual; sem dados de outra conta |
| Perfil/plano/avatar | User e ActiveStorage; plano não comprova cobrança nem nível musical |
| Preferências iniciais | Session do onboarding, identificada como temporária; não foi criada persistência nova |
| Tema | LocalStorage, com fallback utilizável quando indisponível |
| Placar no Playground | Estado existente do treino/sessão; histórico persistido é uma tela separada |

Não são exibidos minutos estimados como medidos, aulas assistidas derivadas de tentativas, domínio percentual, notificações, ranking ou faturas inventadas. A seleção comercial de quatro planos continua aceita pelos endpoints existentes para compatibilidade; a interface de upgrade fictício foi retirada e o onboarding oferece a entrada gratuita já prevista. Contas com outros planos não foram alteradas automaticamente.

Em Harmonia, tonalidade/estrutura, pergunta, prompt e posição de foco continuam visíveis; referência complementar fica em `details`. Áudio e respostas ocupam áreas equilibradas. Leitura mantém o seletor real de temporada/nível do gerador, sem inferir o nível do estudante; apenas o rótulo de contexto passou a “Conteúdo selecionado”. Nenhuma regra pedagógica, gabarito, política de XP ou gerador foi alterado. Síncopa continua bloqueada.

## 7. Verificações efetivamente executadas

| Verificação | Resultado final |
| --- | --- |
| Ruby/Bundler/dependências | Ruby 3.3.5 via rbenv, Bundler 2.6.8, Rails 7.1.6; `bundle check` satisfeito |
| Rails completo, `CI=1`, banco isolado | **167 testes, 5.719 asserções, 0 falhas/erros/skips**, seed `13757` |
| JavaScript Node | **36 testes aprovados**, 0 falhas; inclui quatro novos testes de tema/storage/lifecycle/bootstrap |
| Matriz autenticada | **276 cenários**, 34 URLs/variações, claro e escuro; 0 overflow horizontal, botões inertes, links vazios ou campos sem label encontrados pelos checks |
| Autenticação | **24 cenários**, quatro telas × três tamanhos × dois temas; login inválido e retorno ao login válido verificados |
| Notação UX-01 | **16 cenários**, quatro áreas × quatro viewports; quatro alternativas, alvos ≥44px e nenhum elemento musical fora do viewBox |
| Áudio real no Chromium | Samples carregados de piano, repetição e cancelamento na próxima rodada em Percepção/Harmonia |
| Falha de áudio | CDN bloqueado → sintetizador; falha do último motor → estado neutro e **zero POSTs** de resposta nos dois players |
| Envio pela interface | Quatro respostas corretas, uma por área, após áudio completo onde exigido; quatro contratos de formulário preservados |
| Dados após navegação/login | Dashboard exibiu **4 respostas, 80 XP e 4 linhas de histórico** provenientes dos envios reais da conta sintética |
| Conta | Campo de instrumento salvo e reaberto; tema sincronizado entre os dois seletores |
| Acessibilidade focal | Foco/teclado/gaveta/Turbo back/redução de movimento; 24 pares de contraste e reflow equivalente a 200% aprovados |
| Revisão de fonte | `git diff --check`, sintaxe Ruby dos controllers/helper e `node --check` dos controllers novos/alterados aprovados |

A suíte Rails mantém o corpus de 1.000 exercícios, verificações musicais independentes, HTTP, identidade, isolamento entre usuários, idempotência e concorrência PostgreSQL. Foram acrescentados oito testes Rails de UI e quatro Node. A alteração no teste compacto limita a contagem de `aria-current` à navegação das áreas, pois a sidebar também passou a marcar corretamente a seção ativa; nenhuma garantia dos quatro formulários foi retirada. O script de áudio UX-01 foi ajustado somente para os rótulos novos dos botões.

As regressões novas falharam inicialmente em empty state, aulas, labels, shell e onboarding; o log inicial também continha um erro de fixture (`generate` em vez de `call`), corrigido antes da validação. Uma execução intermediária detectou um rótulo de Leitura alterado sem necessidade e um erro de escopo no teste novo de labels; ambos foram corrigidos. Os resultados acima são da execução final aprovada.

## 8. Matriz e evidências

Viewports utilizados: **360×640, 375×667, 390×844, 768×1024, 820×1180, 1024×768, 1366×768, 1440×900, 1920×1080**. Cada URL autenticada tem 390/820/1440 em ambos os temas. Dashboard, conta e quatro Playgrounds receberam os nove tamanhos nos dois temas. As quatro telas anônimas têm 390/820/1440 nos dois temas.

- [Galeria filtrável](../output/playwright/uiux02/index.html), com imagens em tamanho completo por página/tema/largura.
- [Matriz autenticada](../output/playwright/uiux02/matrix.json) e [autenticação](../output/playwright/uiux02/auth.json).
- [Áudio](../output/playwright/uiux02/audio.json), [notação](../output/playwright/uiux02/notation.json), [envios](../output/playwright/uiux02/submissions.json) e [acessibilidade](../output/playwright/uiux02/accessibility.json).
- [Resultados consolidados](../output/playwright/uiux02/test-results.txt) e [preservação](../output/playwright/uiux02/preservation.json).
- `before/`: cinco capturas iniciais e inventário de 29 visitas. `after/`: matriz final, Dashboard vazio preservado e com histórico, gavetas, feedbacks e reflow. `review-0.png` a `review-4.png`: folhas de contato da revisão visual inicial das 38 páginas/variações.

Contrastes calculados dos tokens: texto principal ≥13,7:1; secundário ≥5,4:1; botão primário ≥6,97:1; bordas de controles ≥3,58:1; tinta da pauta ≥13,7:1. Referências de critério: [W3C — texto](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html), [contraste não textual](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html) e [reflow](https://www.w3.org/WAI/WCAG22/Understanding/reflow.html). Isso verifica os pares usados, não substitui uma auditoria WCAG completa de todos os pixels/estados.

## 9. Banco, Git e preservação

Nenhuma migration nova ou alteração de schema foi necessária. As **oito migrations existentes** foram aplicadas exclusivamente em dois bancos vazios do PostgreSQL 15.19 temporário, privado, sem TCP: `app_music_integrity_uiux02_test` e `app_music_integrity_uiux02_browser_test`. O guard verificou permissões, socket, nome, data_directory real e ausência de listener TCP antes do Rails. `SCHEMA` apontou para o scratch. Não houve leitura nem escrita de dados reais de desenvolvimento nesta missão.

`db/schema.rb` conservou SHA-256 `6888fb3253ab7852b96279705a076da9d12a89ef2aae9dd836d28af741fc3093`; migrations e configuração do banco ficaram intactas. Nenhuma tabela Arena foi alterada.

A branch permanece **`feat/canonical-music-model`**, HEAD **`16f9d18`**. As Missões 03.1 e UX-01 já estavam sem commit; não houve troca/renomeação para evitar misturar uma operação Git com esse trabalho pendente. Snapshot inicial privado: `/private/tmp/appmusic-uiux02-t3r4wb_i`. Dos 79 arquivos inicialmente locais, 69 permanecem idênticos; dez arquivos de interface/teste foram evoluídos deliberadamente e têm cópia anterior preservada; nenhum desapareceu. Núcleo canônico, geradores, validador, renderers musicais, players e módulo de áudio preexistentes permanecem byte a byte iguais ao início desta missão.

O servidor original em 127.0.0.1:3000 não foi reiniciado; `/up` respondeu **200** ao final. Apenas a instância de teste em 3001 e o cluster criado por esta missão foram encerrados. Os diretórios temporários permanecem disponíveis para inspeção local, sem substituir as evidências duráveis em `output/`.

## 10. Arquivos e justificativas

A relação por arquivo está em [uiux-02-arquivos.md](uiux-02-arquivos.md). Principais grupos:

- Helper/partials/layouts: uma configuração de navegação, componentes acessíveis e conteúdo sem dados fictícios.
- SCSS: tokens e componentes; integração de geometria/notação anterior, estados e contraste.
- Stimulus: ciclo de vida da gaveta e do tema, sem listeners globais duplicados.
- Controllers: seleção de layouts e remoção dos builders de aulas artificiais; métodos dos motores permanecem intactos.
- Views: Dashboard/trilhas/conta/histórico reais; estados de preparação e autenticação coerentes; Harmonia redistribuída.
- Testes/evidências/documentação: regressões, matriz reproduzível, resultados e proposta de aulas separada.

## 11. Limitações e riscos de regressão

- Testado no Chromium automatizado; Safari/iOS/Android físicos e VoiceOver ainda precisam de revisão humana. A execução do navegador integrado estava indisponível; foi usado o Playwright existente, sem instalar dependências.
- O reflow usa emulação CDP de 683×384 com escala 2, equivalente ao espaço útil de 1366×768 a 200%; não foi um comando de zoom nativo do Safari/Chrome.
- Áudio foi agendado e carregado em navegador real, inclusive fallback; isso não homologa timbre, volume, latência ou som ouvido em dispositivo. Escuta humana continua pendente.
- Provedores OAuth, entrega de e-mail, upload real de avatar, exclusão de conta e alteração final de senha não foram executados. Formulários e autorização existentes foram preservados. Algumas mensagens internas do Devise continuam em inglês; localização completa requer etapa própria.
- Trilha por domínio, catálogo/vídeo, avaliação, carreira, Arena, ranking, medalhas, bolsa e cobrança continuam futuros. Não confundir estados vazios novos com entrega de backend.
- Preferências de tema são por navegador; onboarding ainda usa sessão; recuperação de atribuições após perda de cache e política de XP por contexto continuam as pendências das missões anteriores.
- O novo CSS substitui a aparência antiga; testes futuros que procuravam classes ou textos do protótipo devem verificar o comportamento atual, preservando contratos de formulário e regras musicais. Não foi demonstrada regressão de backend pela suíte executada.
- Capturas fornecidas pelo responsável foram citadas no pedido, mas o anexo recebido continha somente texto. Foram usadas as evidências UX-01 disponíveis e capturas próprias. A landing page pública não recebeu auditoria visual completa nesta missão.

## 12. Verificação local

Não executar a suíte com `app_music_development` ou uma URL externa. O runner existente recusa conexões que não comprovem o cluster dedicado. Exemplo macOS/Homebrew para criar **outro** cluster isolado:

```sh
ui_test_cluster="$(mktemp -d /private/tmp/app-music-uiux02.XXXXXX)"
ui_test_pg_bin=/opt/homebrew/opt/postgresql@15/bin
"$ui_test_pg_bin/initdb" -D "$ui_test_cluster/data" -A trust -U uiux02 --encoding=UTF8 --no-locale
cat >> "$ui_test_cluster/data/postgresql.conf" <<EOF
listen_addresses = ''
unix_socket_directories = '$ui_test_cluster'
port = 55440
EOF
"$ui_test_pg_bin/pg_ctl" -D "$ui_test_cluster/data" -l "$ui_test_cluster/postgres.log" start
"$ui_test_pg_bin/createdb" -h "$ui_test_cluster" -p 55440 -U uiux02 app_music_integrity_uiux02_test
export APP_MUSIC_TEST_DATABASE_URL="postgresql:///app_music_integrity_uiux02_test?host=$ui_test_cluster&port=55440&user=uiux02"
export SCHEMA="$ui_test_cluster/schema.rb"
rbenv exec bundle check
rbenv exec ruby bin/test-isolated db:migrate
CI=1 rbenv exec ruby bin/test-isolated
node --test test/javascript/*.cjs
git diff --check
"$ui_test_pg_bin/pg_ctl" -D "$ui_test_cluster/data" stop
```

Para navegador, usar um segundo banco dedicado terminado em `_test`, uma conta sintética e Rails em 3001, iniciado com `RAILS_ENV=test`, `DATABASE_URL`/`APP_MUSIC_TEST_DATABASE_URL` iguais e `ruby -r ./lib/isolated_test_database bin/rails server ...`. Os scripts em `test/browser/` exportam funções que recebem `page` do Playwright já disponível: `platform_ui.mjs`, `auth_ui.mjs`, `platform_accessibility.mjs` e `playground_audio.mjs`. O script anônimo exige logout e token sintético para a tela de nova senha. Não requerem instalação de biblioteca na aplicação; a infraestrutura Playwright deve fornecer `page`.

Verificação manual: entrar, abrir/fechar menu por clique/Escape/Tab e rota, alternar temas/recarregar, conferir conta, visitar Aulas e URLs antigas, abrir as quatro práticas, reproduzir áudio completo, responder e consultar o histórico. Fazer também em tablet retrato/paisagem e com redução de movimento. A galeria pode ser aberta diretamente no navegador, sem servidor.

## 13. Continuidade proposta

Revisão independente do Hermes sobre inventário, código e evidências; em seguida, sessão humana em dispositivos/tecnologias assistivas e escuta real. A proposta de aulas está em [uiux-02-aulas-proposta.md](uiux-02-aulas-proposta.md), **sem implementação**. Antes de avaliações oficiais, revisar a convenção harmônica e definir XP por contexto. Qualquer trabalho futuro em Arena deve resolver primeiro suas dependências históricas de migrations.

Nenhuma próxima missão foi iniciada. As alterações permanecem locais para revisão.
