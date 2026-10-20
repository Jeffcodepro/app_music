# AppMusic — UI/UX 02 integral: resultados para revisão

Implementação local verificada em 19/10/2026. O anexo desta execução amplia a UI/UX 02 anterior para a experiência pública e a hierarquia integral do produto. Foram reaproveitados os componentes já funcionais; os relatórios e as evidências anteriores continuam preservados.

**Resultado:** landing factual, tipografia e temas compartilhados, menu com recursos disponíveis e futuros separados, dashboard editorial, mensagens de acesso em português e estados visíveis de áudio. Localhost:3000 está ativo e respondeu **HTTP 200** ao final. A configuração foi recarregada pelo mecanismo `tmp_restart` do Puma; um GET anônimo de recuperação confirmou labels em português. Nenhum formulário foi enviado ao banco de desenvolvimento.

**Validação final:** **173 testes Rails / 5.776 asserções**, **39 testes Node**, sem falhas, erros ou skips. Matriz de **276 casos autenticados**, **24 de autenticação**, **18 da landing**; outras verificações detalhadas abaixo. Isso não equivale a homologação acústica, Safari ou certificação WCAG.

Branch mantida: `feat/canonical-music-model`; HEAD `16f9d18`. Nada staged. Nenhum commit, push, deploy, troca de branch ou alteração de schema/migration do projeto.

## A. Inventário de páginas

O [scanner inicial desta execução](uiux-02-integral-inventario.md) atualiza o [inventário anterior](uiux-02-inventario.md), que enumera rotas, templates, componentes e origens de dados. Inclui landing; login/cadastro/recuperação/credenciais; cinco etapas de onboarding; dashboard; prática/histórico; quatro Playgrounds; trilhas e seus detalhes; aulas e URLs legadas; conta; nivelamento, carreira, desafios, ranking, conquistas, bolsa, Arena e páginas de assinatura.

Classificações preservadas: exercícios, histórico e edição de conta **funcionais**; trilhas editoriais e preferências de onboarding **parciais**, sem avaliação de domínio/persistência de todas as preferências; aulas, nivelamento, gamificação e comércio **em preparação**; professor, repertório e IA **planejados**, sem rotas funcionais inventadas. A Arena continua sem implementação de salas em uso.

As 34 URLs autenticadas da matriz incluem os seis temas editoriais, três variações de aulas legadas e as cinco etapas iniciais. Devise confirmable/lockable está inativo: confirmação/desbloqueio não são fluxos homologados nem foram habilitados para fabricar testes. `/up`, redirects e ações de formulário não foram confundidos com páginas de conteúdo.

## B. Direção visual

“Caderno de Ensaio”: papel claro, tinta verde, cobre para leitura/contexto, hierarquia editorial e notação musical real. A landing combina composição aberta, um caderno ilustrativo estático e índice de práticas; o dashboard usa convite, áreas, histórico e métricas em sequência. Aulas e recursos futuros mantêm estados vazios honestos. Os Playgrounds conservam a compactação já existente; Harmonia mantém contexto acima e escuta/respostas equilibradas. O modo escuro é uma preferência, sem forçar toda a plataforma a representar uma cabine escura.

## C. Design system

Tokens existentes foram preservados: fundos, superfícies, tinta, texto auxiliar, bordas, verde principal, cobre, sucesso, erro, foco e papel/linhas/tinta das partituras. Bordas de controles continuam usando os tokens já medidos. Botões, inputs, disclosures, ícones SVG locais, headers, temas, estados vazios e histórico são reutilizados.

Corpo geral em 16px, labels/ajuda normalmente 14px, H2 geral 24px, H3 geral 18px; títulos da landing variam até 44px. Metadados discretos e cabeçalhos compactos dos exercícios conservam escala contextual menor. Não foram ampliadas figuras musicais arbitrariamente. Inter tornou-se a única família de interface, com fallback do sistema e `display=swap`; Nunito/Work Sans e JetBrains deixaram de ser requisitadas. A tipografia própria dos símbolos musicais foi preservada.

Foram removidos o CSS e os três controllers usados exclusivamente pelo protótipo público, além do carregamento Tailwind/Lucide e da textura remota. Bootstrap, Stimulus, Turbo e as bibliotecas de áudio existentes permanecem; não houve instalação ou troca de dependências.

## D. Navegação

Configuração única em `PlatformUiHelper`: **Dashboard, Prática, Trilhas de estudo, Histórico, Minha conta**. Aulas, Modo carreira e Arena ficam no grupo **Em preparação**. URLs legadas continuam acessíveis, com seção ativa correta; o histórico tem sua própria seleção.

`app-shell` permanece como único controlador de navegação. O mesmo botão que abre a gaveta é movido para seu interior durante a abertura, continua acessível e pode fechá-la; depois retorna ao lugar original. Mantém `aria-expanded`, dialog/modal, workspace inert, foco contido/restaurado, Escape, clique externo, fechamento por rota e limpeza antes do cache Turbo. Resize restaura foco a um link visível quando o botão original desaparece. Desktop conserva recolhimento persistido; tablet conserva rail de 76px e expansão modal. O header público reutiliza esse controlador em modo somente drawer abaixo de 992px.

## E. Temas

Sistema/claro/escuro reutilizam o bootstrap anterior ao CSS, localStorage e `theme_controller`; nenhuma segunda persistência foi criada. Landing, autenticação, onboarding, área autenticada, controles e SVGs compartilham a preferência. Testados reload, mudanças simuladas do sistema, duas abas e navegação Turbo. A sincronização dos dois seletores da conta permanece funcional.

## F. Landing pública

Antes: dois vídeos automáticos; preços/benefícios e ofertas sem backend; três links `#`; dois botões dentro de links; dependência de CDN de protótipo/textura que retornava 402; overflow em 390/820/1440.

Depois: apresentação das quatro práticas disponíveis, links reais para acesso/cadastro e Playgrounds, explicação do fluxo atual, FAQ nativa acessível e planejamento secundário identificado. Sem preços, depoimentos, contadores, aulas publicadas, nivelamento ou IA fictícios. O SVG ilustrativo usa o gerador, o validador e o renderer existentes, com seed fixa, sem emitir atribuição ou pontuar. Não simula um exercício interativo nem expõe seu gabarito.

Nas 18 combinações de tema/tamanho não houve overflow, âncoras inexistentes, links vazios, controles aninhados ou vídeos. Drawer, mesmo botão, foco, Escape, clique externo, navegação por âncora, FAQ por teclado e transição Turbo para login/retorno passaram.

## G. Autenticação e onboarding

O locale padrão passou a `pt-BR`, mantendo `en` disponível. Traduções cobrem flashes Devise, validações User/ActiveRecord e Simple Form; labels, autocomplete, senha atual e requisitos de senha existentes foram preservados. Cadastro inválido exibe erros específicos em português, com captura mobile. Isso não constitui uma interface bilíngue completa; não foi inventada tradução EN das páginas portuguesas.

Foi ativado **`Devise.paranoid = true`**, conforme a exigência explícita de não revelar contas na recuperação. E-mails conhecidos e desconhecidos retornam o mesmo status, redirect e mensagem; só o usuário existente recebe token e mensagem na caixa de teste. Não se afirma equivalência temporal: o caminho de envio pode ter duração diferente.

Os cinco assuntos originais EN foram preservados literalmente no locale PT. Testes comparam destinatário, assunto e corpo dos e-mails de recuperação, mudança de e-mail e mudança de senha entre EN/PT, usando os mesmos dados; os dois assuntos de fluxos inativos também são comparados. Nenhum template de e-mail, rota Devise, algoritmo de senha, proteção de conta ou redirecionamento de cadastro foi alterado. Um parecer especializado somente leitura confirmou esse contrato antes da implementação.

Onboarding conserva preferências de sessão, plano obrigatório e validação existente. Não adiciona teste de nível, personalização, persistência de preferências, preço ou regra pedagógica. Os testes exercitam rotas e validação do plano; a matriz visual inclui todas as etapas.

## H. Dashboard e trilhas

Ordem do dashboard: convite à próxima prática, quatro áreas, histórico recente e métricas. O banner decorativo foi substituído por convite editorial; as áreas usam separadores em vez de quatro caixas idênticas. XP/dias continuam vindos de StudyActivity; respostas/correção de ExerciseAttempt através das atribuições do usuário. Nada é chamado domínio, aula concluída ou tempo medido.

Histórico vazio e preenchido foram capturados. Quatro respostas reais da conta fictícia pelos formulários produziram quatro linhas e 80 XP, observados também no dashboard. Isolamento entre contas e política de crédito permanecem cobertos no Rails. Trilhas continuam apresentando temas e atalhos disponíveis, com a preparação curricular declarada.

## I. Aulas e recursos futuros

As substituições honestas já feitas foram preservadas: nenhuma lista de episódios, player, progresso, desconto, ranking ou carreira artificial foi recriada. Aulas guiadas/livres e URLs antigas continuam retornando preparação e link para prática. Carreira, Arena, nivelamento, conquistas, desafios, bolsa e páginas comerciais foram revisitados.

A [proposta de catálogo de aulas](uiux-02-aulas-proposta.md) permanece apenas documentação, separando conteúdo, objetivos, exemplos e vínculos com exercícios. Não foi implementado um backend para aulas nesta missão. Dependências históricas da Arena permanecem fora do escopo.

## J. Playgrounds

Os geradores, o modelo canônico, validadores, atribuições, submissão, assinaturas, versões, quatro alternativas e regra de XP não foram modificados por esta execução. Leitura e Rítmica mantêm renderers/geometria; síncopa continua bloqueada. Os hashes dos arquivos musicais locais e das evidências anteriores foram conferidos contra o snapshot inicial.

Os três players receberam apenas apresentação de estado: **Pronto para ouvir → Preparando áudio → Reproduzindo → Escuta concluída**, ou **Áudio indisponível** em falha. Um partial compartilhado fornece o status com live region. O estado concluído só é mostrado após o guard existente confirmar a solicitação ainda atual; cancelamento não pode anunciá-lo. Parada/troca de instrumento restaura indicação de prontidão quando aplicável. A prontidão real, relógio, frequências, durações, envelopes, ganho, timbres e gate de resposta permanecem nos métodos anteriores.

No navegador: piano amostrado real para Percepção/Harmonia; repetição e parada no próximo exercício; bloqueio do CDN com fallback synth; falha total simulada nas três áreas sonoras com **zero POSTs de resposta**; Rítmica concluída conforme sua assinatura. Foram feitas quatro respostas corretas reais, sem falsificar `playback_status` ou desativar o gate. As respostas para a automação foram consultadas somente na conta sintética pelo banco privado, nunca inferidas do HTML.

## K. Acessibilidade

Passaram foco nos dois sentidos, Escape, retorno de foco, workspace inert/scroll lock, skip link/labels/um H1, detalhes por teclado, alternância de temas, redução de movimento, retorno Turbo e reflow equivalente a 200%. Este último usa CDP com 683×384 e escala 2, **não o zoom nativo do navegador**.

Foram medidos **24 pares de contraste** nos dois temas: texto principal/secundário, link, botão principal, foco, borda de controle, tinta/linhas de partitura, sucesso, erro e alvo. Todos atenderam aos limiares registrados: 4,5:1 para texto e 3:1 para os componentes testados; bordas 3,58:1/3,93:1. Não é auditoria de todos os pixels/estados nem certificação WCAG. Falta validação com leitor de tela e tecnologias assistivas reais.

Um nome sem espaços com 315 caracteres reproduziu overflow. A quebra de textos dinâmicos foi corrigida; três tamanhos passaram depois. Formulários com conteúdo longo PT/EN também foram verificados sem salvar os dados de estresse.

## L. Responsividade e desempenho

Nove tamanhos: **360×640, 375×667, 390×844; 768×1024, 820×1180, 1024×768; 1366×768, 1440×900, 1920×1080**. Landing, dashboard, conta e quatro exercícios usam matriz ampliada; demais rotas principais têm mobile/tablet/desktop em claro e escuro. Sistema foi exercitado com mudança simulada de preferência.

Na recarga local da landing observou-se **CLS 0**; apenas a folha Inter e um recurso WOFF2 externo foram requisitados, sem Tailwind/Lucide/textura/vídeo. O registro detalha 30 recursos e tempos da navegação em cache aquecido, sem throttling; não é benchmark de produção, Core Web Vitals de campo ou pontuação Lighthouse. Ciclos de abrir/fechar o drawer pelo Playwright ficaram entre 29–46ms nesta execução; incluem automação e não medem INP. Não existem listeners de scroll/mousemove ou loops de vídeo do protótipo na nova landing. Não há animações JS próprias a desativar nela.

## M. Testes e evidências

| Verificação executada | Resultado / evidência |
| --- | --- |
| Ruby 3.3.5 via rbenv, Bundler 2.6.8, Rails 7.1.6 | bundle check satisfeito |
| Regressões direcionadas públicas/auth/plataforma | 14 testes, 354 asserções, sem falhas após correções |
| Rails completo final, seed 11235 | **173 testes, 5.776 asserções, 0 falhas/erros/skips**, 27,8s; [log](../output/playwright/uiux02-integral/rails-final.log) |
| Node final | **39/39**, inclui estados visíveis/cancelamento, envelopes, timbres, ordenação e neutralidade; [log](../output/playwright/uiux02-integral/node-final.log) |
| Navegação + matriz autenticada | **276 casos / 34 URLs**, zero erros JS/overflow/inputs sem label; [JSON final](../output/playwright/uiux02-integral/platform-final-results.json) |
| Autenticação anônima | **24 casos**, login inválido PT e login válido; [JSON final](../output/playwright/uiux02-integral/auth-final-results.json) |
| Landing | **18 casos** e interações/desempenho; [JSON final](../output/playwright/uiux02-integral/public-final-results.json) |
| Partituras / alvos de resposta | 16 casos das quatro áreas, mais **36 casos de claves Sol/Fá/Dó com acidentes/armaduras**; sem cortes SVG, quatro alvos ≥44px; [base](../output/playwright/uiux02-integral/notation-results.json), [variantes](../output/playwright/uiux02-integral/notation-variants-results.json) |
| Áudio no navegador | **8 cenários**, [JSON](../output/playwright/uiux02-integral/audio-results.json) |
| Submissão/histórico reais | Quatro respostas, **80 XP**; [JSON](../output/playwright/uiux02-integral/submissions-results.json) |
| Contraste/Turbo/reflow/abas | [24 pares e resultados](../output/playwright/uiux02-integral/accessibility-results.json) |
| Texto longo | [Casos e resultados](../output/playwright/uiux02-integral/content-results.json) |
| Preservação | 421 arquivos protegidos comparados sem divergência, dentre 512 arquivos locais do snapshot; [JSON](../output/playwright/uiux02-integral/preservation-results.json) |
| Diff e banco do projeto | git diff --check passou; nenhuma diferença em db/; nada staged |

A suíte inclui o corpus de 1.000 exercícios, casos de apresentação musical, isolamento/autorização, idempotência/retry, rollback e corridas em conexões PostgreSQL diferentes. As regressões foram escritas antes das correções prioritárias: reproduziram quatro falhas funcionais; duas falhas iniciais de preparação de locale/mailer foram resolvidas no ambiente de teste. Uma incompatibilidade Sass e o caso de nome longo foram detectados e corrigidos antes da verificação final.

Não houve uso de credenciais pessoais, integração externa de e-mail ou produção. ActionMailer usou delivery `test` e host `example.test`. Logs de HTTP 422 do cadastro inválido, falhas deliberadas de CDN e avisos de autoplay do AudioContext foram cenários esperados, não erros JavaScript da matriz.

Uma operação auxiliar foi rejeitada pela revisão automática por tentar gravar em um caminho temporário não definido. Ela não foi executada; a conferência foi concluída por consulta somente leitura, sem arquivo auxiliar de gabaritos e sem bloqueio pendente.

### Banco e ambiente isolado

Dois bancos novos no PostgreSQL 15.19 privado, somente socket, sem TCP: `app_music_integrity_uiux02_full_test` e `app_music_integrity_uiux02_full_browser_test`. O guard verificou ambiente, banco, papel e diretório real antes da execução. As **oito migrations já existentes** foram aplicadas exclusivamente nesses bancos, com `SCHEMA` em scratch. Nenhuma migration nova foi criada; nenhum `db:drop`, reset, carga de schema ou backfill foi executado no desenvolvimento/produção. Servidor de navegador em 3001 e cluster privado foram encerrados ao final; o desenvolvimento em 3000 permanece ativo.

### Verificação local reproduzível

Usar Ruby via rbenv. Para Rails, preparar um cluster privado permitido pelo guard, somente socket, e uma URL `APP_MUSIC_TEST_DATABASE_URL` cujo banco descartável termine em `_test`; nunca reutilizar a URL de desenvolvimento. O [runner](../bin/test-isolated) e [guard](../lib/isolated_test_database.rb) verificam o destino. O relatório anterior contém o procedimento completo de criação do cluster. Com esse ambiente explicitamente preparado:

```sh
SCHEMA=/private/tmp/app-music-SEU-CLUSTER/schema.rb rbenv exec ruby bin/test-isolated db:migrate
SCHEMA=/private/tmp/app-music-SEU-CLUSTER/schema.rb CI=1 rbenv exec ruby bin/test-isolated
node --test test/javascript/*.cjs
git diff --check
```

Os comandos Rails exigem `APP_MUSIC_TEST_DATABASE_URL` apontando para o cluster real recém-criado; o exemplo de caminho é marcador, não um banco pronto. O runner controla `DATABASE_URL`/RAILS_ENV. Para testes visuais, usar outro banco privado e servidor 3001 com o mesmo guard carregado. Os scripts em `test/browser/` exportam funções que recebem `page` Playwright; não instalam nada na aplicação. `public_ui` e `auth_ui` exigem sessão anônima; `auth_ui` prepara o login sintético após a matriz e requer token de formulário sintético. `practice_submission` recebe mapa consultado apenas das atribuições fictícias. Não submeter as respostas novamente na mesma conta sem preparar um novo cenário de quatro tentativas.

No localhost:3000, revisão humana: entrar/cadastrar com uma conta de desenvolvimento própria, alternar temas, abrir/fechar menu pelo mesmo botão/Escape/fora, navegar por teclado, visitar conta/aulas/trilhas/histórico, configurar e responder os quatro exercícios, conferir SVG e ouvir os três players em dispositivo real. Não usar a conta fictícia de testes como credencial do desenvolvimento.

## N. Arquivos

A [lista incremental com justificativas](uiux-02-integral-arquivos.md) distingue esta execução das mudanças anteriores ainda não commitadas. A [galeria](../output/playwright/uiux02-integral/index.html) reúne **409 capturas** com filtro de página, tema e tamanho, comparação da landing, histórico vazio/preenchido, erros, texto longo e notação. Arquivos JSON e logs indicam exatamente o que foi medido; capturas não substituem testes funcionais.

## O. Pendências e riscos

**Bugs corrigidos nesta execução:** comunicação pública fictícia, overflow da landing, links vazios/interações aninhadas, dependências de animação/CDN do protótipo, botão original do drawer inacessível, menu sem histórico/grupos, tipografia concorrente, erros de acesso EN, recuperação enumerável, falta de estado sonoro visível e overflow de nome extremo.

**Limites de frontend/homologação:** somente Chromium automatizado com viewports simulados; sem Safari/Chrome em dispositivos físicos, leitor de tela, zoom nativo ou escuta humana. Os testes verificam execução/agendamento/fallback do áudio; não comprovam som percebido, volume, timbre, latência ou condições acústicas. Fontes externas dependem de rede, com fallback do sistema. A alteração de escala tipográfica deve receber revisão humana para densidade e conforto de leitura.

**Dependências futuras de backend/produto:** catálogo de aulas e currículo; avaliação de nível/domínio; persistência ampliada das preferências; regras de carreira/Arena/comércio; recuperação durável após perda do ponteiro de sessão/cache; XP por contexto, ainda limitado por atribuição; revisão especializada da convenção `major-functions-legacy-v1`; representação/revisão pedagógica da síncopa antes de reabilitá-la. Três fontes históricas da Arena continuam ausentes (`20260320120000`, `20260325120000`, `20260325123000`); esta missão não reconciliou nem alterou esse histórico.

Riscos de regressão concentrados em CSS compartilhado, ciclo do drawer e locale padrão. Matriz, testes de listener/Turbo, equivalência de e-mails e regressões de domínio reduzem esses riscos no escopo observado; não provam todos os navegadores ou cenários de produção. O corpo/assunto dos e-mails foi mantido em inglês por decisão explícita de preservação, não por localização completa.

## P. Recomendações

Revisão independente do Hermes com este relatório, diff incremental e galeria; sessão humana em mobile/tablet e Safari, tecnologias assistivas e escuta com CDN disponível/bloqueado. Antes de avaliações oficiais, aprovar convenção harmônica e alcance do XP. Antes de desenvolver aulas/Arena/novos dados, aprovar contratos e resolver as dependências documentadas. A próxima etapa não foi iniciada.
