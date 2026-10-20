# Dashboard, continuidade do ditado e compassos — resultados

Entrega local de 20/10/2026, na branch preexistente `feat/canonical-music-model`, HEAD `16f9d18`. Sem commit, push ou deploy. A matriz foi aprovada explicitamente pelo responsável, incluindo dois compassos no Pulso 2/4.

## Resultado

- Ditado e Percepção compartilham os mesmos cinco cartões de instrumento. Ícones SVG existentes acompanham a cor do tema, inclusive no escuro.
- Após acertar o ditado, a ação principal passa a **Próximo e tocar**: nova atribuição, instrumento preservado e uma reprodução. **Repetir** conserva o exercício atual. Timers pendentes são cancelados ao tocar manualmente, interromper e desconectar pelo Turbo.
- Dashboard mais compacto: acesso às quatro áreas, retomada da última configuração, cinco respostas recentes e totais reais. Estado vazio sem progresso fictício; estilos limitados ao dashboard.
- Rítmica oferece a matriz cumulativa dos níveis 1–4: 32 fórmulas e 41 configurações com agrupamentos. O contrato contempla gerador, validação independente, reidratação, notação e transporte. Preferências sobrevivem ao recarregamento e retorno por links sem parâmetros. Misto permanece selecionado mesmo quando o exercício sorteado usa outro modo.
- Nenhuma migration nova, alteração de schema ou regra de XP. O envio continua pela atribuição persistida e pelo serviço transacional existente.

## Arquivos e motivos

O inventário desta entrega é **incremental**, comparado ao snapshot anterior à tarefa, pois o working tree já continha outras missões. Lista completa e hashes: [incremental-inventory.json](../output/playwright/dashboard-meters/incremental-inventory.json). Diff incremental: [incremental.patch](../output/playwright/dashboard-meters/incremental.patch).

| Arquivo(s) | Alteração e justificativa |
| --- | --- |
| `app/views/student_hub/_instrument_control.html.erb` | Componente único dos cinco instrumentos, evitando divergência entre intervalo e ditado. |
| `app/views/student_hub/_perception_playground.html.erb` | Usa o componente e encaminha a intenção explícita de autoplay ao ditado. |
| `app/views/student_hub/_melodic_dictation_playground.html.erb` | Usa os cartões e oferece próximo+tocar após acerto, mantendo Repetir. |
| `app/helpers/platform_helper.rb` | Reutiliza SVGs existentes em cor corrente e encaminha compasso/número de barras ao renderer rítmico. Outros usos de imagens continuam com o padrão anterior. |
| `app/javascript/controllers/melody_player_controller.js` | Autoplay de uma execução por intenção explícita e cancelamento do timer. Reutiliza o transporte de Harmonia. |
| `app/javascript/controllers/interval_player_controller.js` | Consome a intenção de autoplay uma vez e cancela o timer em parada/ação manual/desconexão. |
| `app/controllers/student_hub_controller.rb` | Corrige a continuidade com preferências, ativa o contrato métrico explicitamente, preserva configurações e separa serialização nova da legada. Não houve refatoração global. |
| `app/views/platform/dashboard.html.erb` | Hierarquia mais curta, retomada útil e dados reais do usuário. |
| `app/helpers/platform_ui_helper.rb` | Link de retomada leva somente preferências de navegação, incluindo estrutura harmônica e modalidade solicitada; não leva gabarito. |
| `app/assets/stylesheets/components/_dashboard.scss` | Espaçamentos e layout responsivo limitados ao dashboard. |
| `app/assets/stylesheets/components/_index.scss` | Importa o estilo do dashboard. |
| `app/models/music_theory/meter.rb` | Catálogo editorial cumulativo e representação exata de fórmula, grupos e unidade de BPM. |
| `app/services/metrical_rhythm_exercise_generator.rb` | Gera quatro padrões completos e auditivamente distintos dentro de limites explícitos; falha sem publicar se não conseguir. |
| `app/services/metrical_rhythm_integrity_validator.rb` | Recalcula duração, grupos, semântica, ataques e gabarito sem chamar os predicados do gerador; rejeita tipos e estados incompatíveis. |
| `app/services/exercise_integrity_validator.rb` | Encaminha apenas o formato métrico explícito ao novo validador; mantém o legado. |
| `app/services/rhythm_staff_svg_renderer.rb` | Fórmulas reais, barras internas, pontos, figuras abertas, pausas e agrupamentos; corrige barras parciais de semicolcheias e mantém cabeças legíveis em padrões densos. |
| `app/javascript/controllers/rhythm_player_controller.js` | Calcula tempo pela unidade correta, um compasso de entrada e uma execução integral; alteração de configuração interrompe e invalida a escuta. |
| `app/views/student_hub/_rhythm_playground.html.erb` | Seletores de conteúdo/compasso, preferências nos formulários, agrupamento e número de barras; região percorrível da pauta separada do botão de resposta. |
| `app/assets/stylesheets/components/_exercise_workbench.scss` | Controles compactos de compasso, região de partitura e foco visível, sem rolagem horizontal da página. |
| `test/integration/perception_continuation_test.rb` | Instrumentos iguais e continuidade após acerto, com preferências e sem XP adicional. |
| `test/integration/dashboard_refinement_test.rb` | Estado vazio, totais reais, retomada de ditado, tetrades e modo Misto. |
| `test/integration/metrical_rhythm_flow_test.rb` | Reidratação, resposta HTTP, catálogo por nível, troca de modo/agrupamento, navegação e compatibilidade legada. |
| `test/services/metrical_rhythm_test.rb` | Catálogo completo, fixtures de unidades e duração, corpus e corrupções deliberadas com assinatura recalculada. |
| `test/services/rhythm_staff_svg_renderer_test.rb` | Notação, barras, pontos, agrupamentos e limites de tamanho/espaçamento das figuras. |
| `test/javascript/perception_continuation_test.cjs` | Autoplay único, ação manual, parada, desconexão e ausência de áudio ao apenas configurar. |
| `test/javascript/metrical_rhythm_player_test.cjs` | Tempos, barras, pausas, acentos, falhas neutras e interrupção das configurações. |
| `test/browser/compact_exercise_mode.mjs` | Atualiza a interação do instrumento para cartões de rádio. |
| `test/browser/dashboard_meter_matrix.mjs` | Matriz de capturas e medidas responsivas em claro/escuro. |
| `test/browser/dictation_continuation.mjs` | Acerto real no navegador, próximo+tocar, Repetir e ausência de novo crédito. |
| `test/browser/meter_audio.mjs` | Agendamento Web Audio real, contagem/acentos e falha simulada sem POST. |
| `test/browser/meter_settings.mjs` | Troca de nível/compasso/modo e preservação após reload/navegação. |
| `test/browser/metrical_score_keyboard.mjs` | Percorre pauta densa com setas e verifica foco visível. |
| `test/browser/dashboard_meter_contrast.mjs` | Mede contraste dos textos renderizados nos cenários afetados. |
| `docs/proposta-compassos-por-nivel.md` | Registra a aprovação sem apagar o texto histórico. |
| `docs/compassos-por-nivel.md` | Documenta catálogo e decisões complementares efetivamente implementadas. |
| Este relatório e `output/playwright/dashboard-meters/` | Evidências, inventário incremental, logs e galeria para revisão. |

## Testes executados

Ambiente: Ruby 3.3.5 via rbenv, Bundler 2.6.8, Rails 7.1.6 e PostgreSQL 15. O cluster privado foi reutilizado em `/private/tmp/app-music-compact-B2tCzd`, proprietário atual, permissões privadas, somente socket, porta 55445. O guard confirmou banco e diretório real antes dos comandos. `RAILS_ENV=test` e `SCHEMA` fora do projeto. Dois bancos separados: suíte e navegador; nenhum dado real.

| Verificação | Resultado observado |
| --- | --- |
| Suíte Rails completa, incluindo integração, integridade, idempotência e concorrência existentes | **223 testes, 9.286 asserções, 0 falhas, 0 erros, 0 skips** |
| `node --test test/javascript/*.cjs` | **72 testes aprovados, 0 falhas** |
| Corpus métrico | Todos os 41 presets nos quatro modos; mais 1.230 combinações de preset × seed × modo. Incluído na suíte Rails. |
| Casos adversariais | Fórmula/grupos/unidade errados, resposta divergente, assinatura recalculada, campos fracionários, duplicidade de ataques, payload denso e formato desconhecido rejeitados. |
| Browser Chromium/Playwright autenticado, conta fictícia | Acerto→nova identidade→quatro notas agendadas uma vez; Repetir adiciona uma execução, sem navegar/criar tentativa. Total permaneceu 20 XP e uma resposta. |
| Navegador, tempo rítmico | 2/4 em dois compassos, 6/8 composto e 5/8 aditivo: duração, início dos ataques, contagem e acentos conferidos com fixtures independentes. Falha simulada: zero POSTs e estado neutro. |
| Navegador, configurações | Catálogo 3→41 ao trocar nível; seleção 13/16 e Pulso; identidade e configurações iguais após recarregar e retornar pelo menu. Nenhum erro JavaScript nessa sequência. |
| Responsividade | 42 capturas: dashboard vazio/ativo, ditado e quatro cenários métricos, em desktop 1440, tablet 820 e mobile 360, nos temas claro/escuro. Sem overflow horizontal do documento. |
| Teclado | Pauta densa de 12/4 percorrida com ArrowRight, foco visível e sem alargar a página. |
| Contraste amostrado | Oito cenários: mínimo 7,48:1 no claro e 8,67:1 no escuro para textos examinados. Não equivale a certificação integral de acessibilidade. |
| Sintaxe Ruby e `git diff --check` | Aprovados. |

As regressões foram reproduzidas antes das correções: cartões ausentes/continuidade travada, autoplay descartado com preferências, formato métrico inexistente, unidade pontuada incorreta, figuras comprimidas, valores temporais fracionários, parada inexistente e perda de Misto. Logs antes/depois e resultados finais estão na [pasta de evidências](../output/playwright/dashboard-meters/).

Na primeira chamada da regressão de preferências omiti o subcomando `test`; o runner recusou executar antes de conectar. A chamada correta foi refeita, demonstrou a falha e depois passou. Um probe de teclado com End não percorreu a região no Chromium; a regressão exercita as setas anunciadas pela interface, que funcionaram.

## Preservação e banco

Snapshot do estado inicial: `/private/tmp/appmusic-dashboard-baseline-b469levu`, com hashes e cópias. A comparação confirmou que nenhum arquivo preexistente foi removido nesta tarefa. A exclusão de `scroll_video_controller.js` já existia no início e permaneceu como estava. Landing, autenticação, fontes, schema, migrations, modelos de tentativas/atribuições e serviço de XP não foram alterados nesta entrega. O inventário registra apenas o delta atual, não atribui alterações antigas à tarefa.

Nenhuma migration foi necessária ou executada nesta etapa. O servidor de testes da porta 3001 e o cluster privado foram encerrados após as verificações; o servidor preexistente da porta 3000 foi preservado. Nenhum commit, push, alteração de branch, deploy ou operação em homologação/produção.

## Decisões e limites

O [contrato de compassos](compassos-por-nivel.md) registra a extensão dos dois compassos para todos os modos Pulso com dois grupos, a semântica de Precisão no novo formato, os agrupamentos de numeradores maiores e o andamento dos aditivos /16. Esses pontos concretizam a matriz e precisam ser considerados em revisão pedagógica posterior.

Ainda pendentes: escuta humana em dispositivo real; Safari/VoiceOver e outros navegadores; revisão pedagógica dos padrões e faixas de BPM. O navegador executou e inspecionou o agendamento de áudio, mas isso não comprova timbre, volume ou o som ouvido pelo aluno. Políticas de autoplay variam; se o navegador bloquear, a falha permanece neutra e permite nova ação manual.

O ditado melódico continua com uma voz, quatro semínimas em 4/4 e quatro partituras. A matriz foi aplicada à Rítmica, não a melodias de duração variável nem a duas a quatro vozes. Síncopa continua bloqueada. Nível de conteúdo não equivale a nível medido do aluno. Recuperação do ponteiro de cache após reiniciar o processo permanece uma limitação preexistente.

Riscos principais: sincronização entre formato persistido, renderer e transporte; legibilidade de pautas extensas; interpretações pedagógicas dos grupos aditivos. Foram cobertos por validação independente, compatibilidade explícita, testes e capturas, dentro dos limites acima.

## Verificação local

1. No servidor de desenvolvimento já usado pelo responsável, entrar no dashboard e verificar início vazio ou histórico real; **Praticar novamente** deve conservar tipo de exercício e instrumento.
2. Em Percepção → Configurar treino → Ditado melódico, alternar os cinco cartões. Tocar, responder corretamente, depois **Próximo e tocar**: outra questão e uma execução. **Repetir** conserva a questão.
3. Em Rítmica → Configurar treino, selecionar nível e compasso. Conferir 3/4, 6/8 e 5/8 com agrupamentos diferentes. Pulso 2/4 mostra dois compassos, tocados uma vez após a entrada. Recarregar e retornar pelo menu deve conservar a configuração.
4. No celular, percorrer uma pauta densa sem deslocar a página; pelo teclado, focar a região e usar setas. Conferir claro/escuro nos cartões e no dashboard.
5. Para regressões, preparar um PostgreSQL privado descartável conforme [instruções de isolamento](missao-02-integridade-resultados.md), definir `APP_MUSIC_TEST_DATABASE_URL` para esse banco e `SCHEMA` para um arquivo no scratch. Então executar:

```sh
APP_MUSIC_TEST_DATABASE_URL='<URL do banco privado isolado>' SCHEMA='<scratch>/schema.rb' CI=1 rbenv exec ruby bin/test-isolated
node --test test/javascript/*.cjs
git diff --check
```

Para testes específicos, usar `bin/test-isolated test test/integration/metrical_rhythm_flow_test.rb` com as mesmas variáveis. O runner rejeita destinos não isolados; não substituí-lo por um comando que use o banco local por padrão.

Os scripts `test/browser/*.mjs` desta entrega exportam funções Playwright; devem receber uma página autenticada do servidor privado 3001. Não contêm senha real nem abrem conta externa. A continuação usa referências somente de exercícios da conta fictícia no banco isolado e espera estado inicial de teste, conforme sua fixture. O navegador integrado estava indisponível nesta sessão; a validação usou a alternativa Playwright já instalada.

Galeria: [abrir evidências visuais](../output/playwright/dashboard-meters/index.html). Próximas evoluções recomendadas: revisão musical/acústica, depois especificar variação rítmica do ditado melódico e múltiplas vozes. Nenhuma nova missão foi iniciada.
