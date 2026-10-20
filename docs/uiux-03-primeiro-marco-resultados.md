# Missão UI/UX 03 — primeiro marco

Entrega local para avaliação visual. Implementadas Fase 0 (investigação e correção confirmada), identidade inicial, shell reutilizado, Dashboard/Prática/Histórico, seletor compacto e Percepção. **Não foram iniciadas as demais fases visuais.**

## Resultado e grau de evidência

| Resultado | Evidência |
|---|---|
| Feedback de outra rodada em Leitura/Rítmica/Harmonia | Reproduzido em nove regressões antes da correção; aprovado depois em HTTP/Turbo/refresh e navegador real. |
| Possível exercício original sem alternativa correta | **Não reproduzido.** Não foi fornecido payload/UUID/assinatura da ocorrência; não há base para identificar sua causa. |
| Identidade de clave inconsistente em payload corrompido | Corrupção sintética aceita antes e rejeitada depois. Não demonstra a causa do relato original. |
| Referências musicais e persistência | Corpus existente de 1.000 exercícios e matriz adicional de 44 intervalos, referências literais nos dois sentidos, aprovados na suíte. Isso não prova todas as rodadas possíveis. |
| Nova apresentação inicial e navegação | Confirmadas em Chromium/Playwright, com usuários fictícios e PostgreSQL privado. |
| Motor musical, XP, concorrência e isolamento por conta | Suíte Rails/Node aprovada; revisão de código e comparação com baseline. |
| Timbre, volume e latência realmente ouvidos; leitores de tela e Safari | **Pendentes** de avaliação humana/dispositivo. Sem alegação de homologação acústica ou WCAG global. |

## Diagnóstico e integridade das rodadas

A base já continha o design neutro da entrega anterior no Dashboard e em Percepção. Prática ainda repetia cards, Histórico tinha métricas em caixas, e as quatro áreas usavam uma barra sempre expandida. Esta missão preserva a composição aprovada como direção, amplia o escopo inicial e corrige a associação do feedback.

Causa demonstrada: os três handlers de acerto emitem a atribuição B imediatamente após corrigir A. Os partials calculavam `feedback_for_current_round` pela assinatura do conteúdo, mas o bloco efetivo renderizava somente pela presença de `playground_feedback`. Assim, B recebia o feedback visual de A. Assinatura musical também pode repetir em atribuições diferentes.

Correção: os três builders de feedback incluem o `assignment_id` já disponível; os helpers exigem identidade não vazia e área correspondente. `.playground-feedback` e a desabilitação das alternativas usam a mesma associação. Quando o acerto já abriu outra rodada, um aviso separado informa **“Rodada anterior concluída. Resposta correta. Nova rodada pronta.”** Não carrega notas/gabarito anterior nem targets dos players. Feedback legado sem identidade falha fechado. O token de tentativa não é utilizado para associar feedback, pois gira após erro válido.

Preservados: atribuição após erro, emissão automática após acerto, cache/sessão, quatro alternativas, assinaturas, UUIDs, tokens, `playback_status`, correção no servidor, XP e áudio. Não se limpou o estado antes da geração: Leitura ainda utiliza o feedback para registrar que a rodada anterior foi respondida.

Regressões: erro em A; acerto em A e emissão de B; aviso anterior explicitamente separado; nova resposta em B; refresh; flash HTTP pendente; caminhos Turbo; mesmo conteúdo com UUID distinto; identidade ausente/área distinta; rotação do token. Logs: [nove falhas anteriores](../output/playwright/uiux03/stale-before.log), [regressões após a correção](../output/playwright/uiux03/phase0-after.log), [transições reais](../output/playwright/uiux03/round-feedback-results.json).

## Investigação do possível gabarito ausente

Fluxo revisado: geração → `MusicTheory::Note/Interval` → alternativas/gabarito → validação independente → `ExerciseAssignment` persistido com digest → reidratação validada → SVG/dados do player → POST identificado → `ExerciseSubmission` transacional → feedback.

Os geradores incluem a resposta antes do embaralhamento. O validador exige quatro IDs distintos, exatamente uma resposta recalculada, rótulos coerentes e consistência musical por área. Emissão, reidratação e submissão validam os dados; submissão confere proprietário, expiração, versão, digest e opção, com lock e idempotência. Leituras de código não substituem o teste de uma ocorrência concreta.

Conferidos pelos testes: acidentes simples/duplos; grafia enarmônica e oitavas; direção escrita/sonora; frequências com arredondamento existente e tolerância 0,001 Hz; padrões rítmicos estritos e ataques distintos; foco de progressão; dados canônicos e payloads legados. A matriz nova usa 22 referências literais de C4 a C6, nos dois sentidos, confere grafia (normalizando apenas os glifos ♭/b e ♯/#), distância e frequência, exatamente uma alternativa esperada e round-trip pelo banco. Não deriva o resultado esperado da própria transposição do gerador.

Uma lacuna distinta foi reproduzida: `clef_id` podia ser Sol enquanto `head_music_clef` indicava Fá. O renderer usa o primeiro para o glifo e o segundo para sua âncora. O validador agora rejeita essa incompatibilidade antes de emitir/corrigir a rodada. As nove combinações de três claves × três tipos foram verificadas. Não se alteraram renderer, coordenadas, notas, alternativas ou convenções. [Teste anterior que falhou](../output/playwright/uiux03/clef-before.log). Os geradores e a reidratação atuais já derivam ambos os campos do mesmo catálogo; **não há prova de que produzissem esse payload corrompido normalmente**.

O caso original permanece aberto. O feedback de outra rodada é uma causa demonstrada de confusão, mas não foi comprovado como causa daquele relato.

### Evidência segura se o relato reaparecer — proposta, não implementada

Registrar, somente no servidor de desenvolvimento e mediante opt-in, um código aleatório da ocorrência, área/tipo/versão, etapa do fluxo e códigos de validação. Para correlação privada, usar HMAC da identidade da atribuição com segredo não exportado. Não registrar usuário/e-mail, cookies, CSRF, tokens, assinatura musical (pode revelar resposta), gabarito, XP nem payload bruto em logs comuns ou no navegador.

O responsável pode correlacionar a ocorrência com a atribuição já persistida e produzir uma fixture privada com fatos musicais e alternativas, sem identidade/PII/campos de resposta correta. Guardar fora de Git e de diretórios públicos, com permissões 0700/0600 e retenção curta. A referência musical esperada deve ser escrita independentemente. Fatos como notas e frequências também permitem deduzir a resposta e devem permanecer privados nesse diagnóstico. Não foram criados endpoint, telemetria ou metadados de correção no HTML.

## Identidade e escopo visual

Reutilizados Inter, ícones SVG locais, controllers de tema/menu, Bootstrap, Rails/ERB/Turbo e players. Tokens claros FAFAFA/FFFFFF/F2F2F2 e escuros 141414/202020/292929 continuam restritos a `study-editorial`. Nenhuma fonte, biblioteca ou persistência foi adicionada.

- **Shell:** o mesmo componente e controller, com sidebar discreta, ativo por linha/peso, rail tablet, drawer e header compacto.
- **Dashboard:** ação de prática, quatro áreas em lista, até cinco tentativas reais, métricas secundárias. Base visual anterior preservada, sem inventar novo progresso.
- **Prática:** lista editorial compartilhada com Dashboard; orientação de escuta ao lado no desktop e abaixo no mobile.
- **Histórico:** métricas sem cards e registros com área, resultado, data e XP. Totais de todas as respostas são diferenciados das últimas 50 exibidas. Dados continuam limitados ao usuário atual.
- **Seletor:** disclosure nativo único, ícone/nome atual/indicador, quatro links com nomes completos e `aria-current`, fora dos frames específicos; sem tabs ou barra concorrente. O pequeno controller adiciona Escape/restauração de foco, fechamento externo e limpeza para Turbo.
- **Percepção:** pergunta antes das configurações de instrumento/direção, transporte com rótulos, estado real de áudio, alternativas próximas e seleção/feedback do servidor. Contratos do player intactos.

Leitura/Rítmica/Harmonia receberam somente a correção de feedback e o seletor comum. Sua reformulação visual completa não foi iniciada. Trilhas/Conta e recursos futuros aguardam aprovação. Landing, autenticação e onboarding permanecem byte a byte iguais ao início da missão.

Na revisão foram detectados e corrigidos dois efeitos colaterais antes da entrega: `_study_areas` também atende Trilhas, então a lista editorial foi separada em `_study_index` e o componente original foi preservado integralmente; o contorno teal herdado foi substituído por foco neutro no seletor e nas telas deste marco. A regressão de Trilhas e a cor real do foco foram adicionadas às verificações.

## Evidências visuais

[Galeria comparativa interativa](../output/playwright/uiux03/index.html), com antes/depois, formatos e temas. Screenshots de navegador real, sem mockups nem modificação artificial dos dados apresentados.

- Dashboard: [desktop claro](../output/playwright/uiux03/after/dashboard-light-1440x900.png), [desktop escuro](../output/playwright/uiux03/after/dashboard-dark-1440x900.png), [mobile claro](../output/playwright/uiux03/after/dashboard-light-390x844.png), [mobile escuro](../output/playwright/uiux03/after/dashboard-dark-390x844.png).
- Novas páginas: [Prática](../output/playwright/uiux03/after/pratica-light-1440x900.png), [Histórico](../output/playwright/uiux03/after/historico-dark-1440x900.png).
- Percepção: [desktop](../output/playwright/uiux03/after/percepcao-light-1440x900.png), [mobile](../output/playwright/uiux03/after/percepcao-dark-390x844.png), [reprodução](../output/playwright/uiux03/states/percepcao-reproduzindo-light-mobile.png), [feedback](../output/playwright/uiux03/states/percepcao-selecao-correta-dark-mobile.png).
- Navegação: [tablet](../output/playwright/uiux03/after/drawer-tablet-light-820.png), [mobile aberto](../output/playwright/uiux03/after/drawer-mobile-dark.png), [seletor com foco](../output/playwright/uiux03/after/selector-mobile-open.png).
- Vazio: [Dashboard](../output/playwright/uiux03/empty/dashboard-dark-mobile.png), [Histórico](../output/playwright/uiux03/empty/historico-light-mobile.png).
- Transição corrigida: [Leitura](../output/playwright/uiux03/rounds/leitura-transition.png), [Rítmica](../output/playwright/uiux03/rounds/ritmica-transition.png), [Harmonia](../output/playwright/uiux03/rounds/harmonia-transition.png).
- [Falha neutra de áudio](../output/playwright/uiux03/states/percepcao-falha-neutra-dark-mobile.png) e [Trilhas preservadas](../output/playwright/uiux03/protected/trilhas-preservadas.png).

Antes: conta fictícia sem respostas, capturada antes de editar. Depois: a conta de fluxo registrou 11 respostas e 98 XP reais de teste; outra conta fictícia sem tentativas documenta os estados vazios. Não comparar diferença de contadores como diferença de design. A referência anterior tem desktop/mobile em claro; tablet utiliza referência desktop identificada na galeria.

## QA executado

Ruby 3.3.5 via rbenv, Bundler 2.6.8, Rails 7.1.6 e PostgreSQL 15.19. `bundle check` satisfeito; nenhuma dependência instalada. Dois bancos novos privados (suíte/browser), socket dedicado, diretório privado e sem listener TCP; conexão real inspecionada e validada pelo guard. Oito migrations existentes aplicadas somente nesses bancos, com `SCHEMA` no scratch. Sem nova migration ou alteração de `db/schema.rb`; nenhum teste gravou no desenvolvimento.

| Verificação | Resultado real |
|---|---|
| Reprodução de feedback antes da correção | 9 testes, 9 falhas esperadas, zero erros. |
| Clave incompatível antes da correção | 1 teste falhando por não haver rejeição. |
| Direcionados após implementação | 29 testes / 967 asserções, aprovados; depois acrescentada proteção de Trilhas. |
| **Suíte Rails final** | **193 testes / 6.421 asserções; zero falhas, erros ou skips.** |
| **Node** | **45 testes aprovados; zero falhas/skips.** |
| Matriz inicial | 4 telas × 7 viewports × 2 temas = **56 cenários**, sem overflow horizontal. |
| Preservação musical no browser | 4 Playgrounds × 7 viewports × 2 temas = **56 cenários**, quatro respostas, alvos ≥44px, SVG sem recortes. |
| Transições reais | Erro/acerto/nova rodada/nova resposta nas três áreas, com POSTs e playback reais. |
| Percepção | Dois POSTs válidos acrescentaram duas tentativas e 20 XP (6 + 14). Antes/durante áudio, nenhum POST; token renovado; mesma atribuição após erro. |
| Falhas | CDN de amostras bloqueado acionou sintetizador; falha simulada dos dois caminhos mostrou mensagem neutra sem outro POST. |
| Estados vazios | Dashboard e Histórico, claro/escuro, desktop/mobile: 8 capturas reais. |
| Configurações e conteúdo longo | Painel aberto em 360/820/1440, alvos ≥44px; Clarinete + Descendente sem overflow em 360px. |
| Sintaxe/whitespace | `node --check` dos roteiros e `git diff --check` aprovados. |

Viewports: 360×640, 390×844, 768×1024, 820×1180, 1024×768, 1440×900 e 1920×1080. Rolagem vertical normal é preservada, especialmente em partituras e feedback mobile.

Confirmados em navegador: mesmo botão abre/fecha drawer; Escape, clique fora, foco preso em ambos os sentidos e restaurado; workspace inerte e scroll bloqueado; desktop recolhido persistido; rail de 76px; ativo; quatro destinos via Turbo; disclosure fechado após navegação; tema explícito após reload/Turbo, Sistema reagindo ao SO e sincronização entre abas/Bootstrap. Bootstrap antecipado de tema preservado; sem alternância incorreta observada nas verificações. Movimento reduzido e reflow a 640 CSS px, equivalente de layout a 200% numa janela de 1280px, sem afirmar teste de zoom nativo.

Contraste: 22 pares calculados no navegador passaram (texto ≥4,5:1, controle/foco ≥3:1). Foram medidas também **378 ocorrências de texto renderizado** nas quatro telas em claro/escuro e **100 nos estados de feedback**. Menor razão medida nos feedbacks: 6,32:1. Cor do contorno do seletor verificada diretamente. **Essas medições não certificam WCAG 2.2 AA do aplicativo inteiro.**

Logs/dados: [Rails](../output/playwright/uiux03/rails-final.log), [Node](../output/playwright/uiux03/node-final.log), [matriz](../output/playwright/uiux03/matrix-results.json), [notação clara](../output/playwright/uiux03/notation-light-results.json), [notação escura](../output/playwright/uiux03/notation-dark-results.json), [áudio](../output/playwright/uiux03/audio-results.json), [contraste renderizado](../output/playwright/uiux03/rendered-contrast-results.json).

## Arquivos desta missão

| Arquivo | Justificativa |
|---|---|
| `app/helpers/platform_ui_helper.rb` | Associação de feedback por área/UUID e escopo exato das quatro telas. |
| `app/controllers/student_hub_controller.rb` | Somente incluir identidade nos três objetos de feedback; sem alterar submissão/geração. |
| `app/services/exercise_integrity_validator.rb` | Rejeitar identidade de âncora de clave incompatível. |
| `app/views/student_hub/_reading_playground.html.erb` | Gate de feedback e aviso separado. |
| `app/views/student_hub/_rhythm_playground.html.erb` | Mesmo gate, preservando dados/scheduler/notação. |
| `app/views/student_hub/_harmony_playground.html.erb` | Mesmo gate, preservando contexto/texturas. |
| `app/views/student_hub/_previous_round_result.html.erb` (novo) | Resultado anterior explicitamente separado da pergunta atual. |
| `app/views/student_hub/_practice_switcher.html.erb` (novo) | Disclosure e quatro links nativos. |
| `app/javascript/controllers/practice_switcher_controller.js` (novo) | Escape/foco, fechamento externo, navegação e cache Turbo. |
| `app/javascript/controllers/index.js` | Registrar o controller. |
| `app/views/student_hub/playground.html.erb` | Substituir a barra anterior pelo seletor comum. |
| `app/views/student_hub/_perception_playground.html.erb` | Ordenar pergunta/configuração/player e mostrar instrumento/direção. |
| `app/assets/stylesheets/components/_study_editorial.scss` | Prática/Histórico, seletor, aviso e foco neutro dentro do escopo. |
| `app/views/platform/_study_index.html.erb` (novo) | Lista editorial compartilhada, sem modificar o componente usado por Trilhas. |
| `app/views/platform/dashboard.html.erb` | Reutilizar a lista editorial, preservando dados e composição. |
| `app/views/platform/pratica.html.erb` | Quatro destinos leves e orientação de escuta. |
| `app/views/student_hub/practice_result.html.erb` | Totais honestos, histórico de até 50 e ação de prática. |
| `app/views/platform/_history.html.erb` | Área/resultado/data/XP em lista responsiva e vazio com ação. |
| `test/integration/round_feedback_presentation_test.rb` (novo) | Nove regressões HTTP/Turbo/flash e novas respostas. |
| `test/helpers/round_feedback_identity_test.rb` (novo) | Mesmo conteúdo, identidade ausente, área e token rotativo. |
| `test/services/reading_clef_integrity_test.rb` (novo) | Nove variantes e rejeição de corrupção de clave. |
| `test/services/perception_reference_matrix_test.rb` (novo) | 44 referências literais com persistência/validação. |
| `test/integration/practice_milestone_test.rb` (novo) | Disclosure, destinos, proteção de Trilhas e limites/ownership de histórico. |
| `test/integration/study_editorial_test.rb` | Atualizar escopo autorizado para quatro telas. |
| `test/integration/playground_compact_layout_test.rb` | Exigir resultado anterior separado da nova pergunta. |
| `test/javascript/practice_switcher_test.cjs` (novo) | Escape/foco, fechamento externo e cache. |
| `test/browser/uiux03_milestone.mjs` (novo) | Responsividade, temas, shell/seletor e contraste. |
| `test/browser/round_feedback.mjs` (novo) | Fluxo real das três áreas em duas fases. |
| `test/browser/uiux03_perception.mjs` (novo) | Reprodução, respostas, falhas e crédito real. |
| `test/browser/uiux03_contrast.mjs` (novo) | Cores efetivamente renderizadas nas quatro telas. |
| Este relatório e `output/playwright/uiux03/` | Galeria, comparações, logs e resultados para revisão. |

Os 16 arquivos preexistentes alterados estão no [inventário de preservação](../output/playwright/uiux03/preservation-results.json). Dos 1.533 registros iniciais, 1.517 permaneceram iguais. `_study_areas`, `trilhas`, Conta, landing, auth/onboarding, modelos, geradores, renderers, serviço de submissão, migrations/schema e players ficaram iguais ao baseline. Nenhuma alteração local anterior foi descartada.

Branch `feat/canonical-music-model`, HEAD `16f9d18`, sem staged, commit, push ou deploy. O servidor preexistente localhost:3000 permanece ativo. Os servidores e cluster criados para QA foram encerrados ao final, sem apagar dados.

## Limites e decisões pendentes

- Relato original sem alternativa correta: aberto até haver evidência recuperável; não foi declarado corrigido.
- Classificação harmônica editorial existente: revisão musical especializada continua pendente; nenhuma convenção foi alterada.
- Matriz de dificuldade por competência/gerador/validador: futura, não implementada. Configuração, dificuldade, proficiência e plano continuam conceitos distintos.
- Ritmo: não alterados contagem de quatro semínimas, acentos, scheduler, ciclos, modos ou contrato. Síncopa segue desabilitada; sem toggle novo de metrônomo.
- Timbres preservados. Futura comparação A/B exige volume equilibrado e escuta humana; não inferir qualidade acústica de mocks/agendamento.
- Não foram auditadas nesta entrega todas as combinações musicais possíveis, Safari, VoiceOver, zoom nativo ou dispositivos de áudio reais.
- Aviso preexistente do Rack sobre `unprocessable_entity` e mensagens de versão de Tone permanecem. Bloqueios de rede/falhas de áudio dos cenários foram intencionais; a matriz não registrou erro JavaScript de página.
- Navegador integrado indisponível nesta sessão; utilizado Chromium/Playwright disponível, sem instalar dependências.

## Verificação local e próximo passo

No desenvolvimento, entrar com sua conta local em `/app/dashboard`, `/app/pratica`, `/app/pratica/resultado` e `/app/playground?activity=percepcao`. Conferir Claro/Escuro/Sistema, reload, Turbo, menu e seletor por teclado. Em Leitura/Rítmica/Harmonia, após acerto a nova pergunta deve mostrar apenas o aviso separado de conclusão anterior; ao responder novamente, o feedback deve ser da atribuição atual.

Testes com gravações exigem PostgreSQL privado aceito pelo guard:

```sh
APP_MUSIC_TEST_DATABASE_URL='<URL privada>' SCHEMA='<scratch>/schema.rb' rbenv exec ruby bin/test-isolated db:migrate
APP_MUSIC_TEST_DATABASE_URL='<URL privada>' SCHEMA='<scratch>/schema.rb' CI=1 rbenv exec ruby bin/test-isolated
node --test test/javascript/*.cjs
```

Os roteiros de browser recebem uma `page` com conta fictícia autenticada em `127.0.0.1:3001`. `uiux03_milestone.mjs` verifica matriz/interações; `uiux03_contrast.mjs`, contraste. `round_feedback.mjs` recebe mapa `{ UUID: ID_correto }` lido **somente do banco fictício**: executar `transition`, ler referências novas e executar `new-answer`. `uiux03_perception.mjs` recebe esse mapa e verifica acréscimo de duas tentativas/20 XP sobre o total inicial. `playground_ux.mjs` aceita `directory`, `sizes` e `scenarios` para registrar SVGs nesta pasta. Não usar contas reais nesses roteiros, não inferir gabarito do DOM nem sobrescrever evidências das missões anteriores.

**Parada obrigatória neste marco.** Aguardar aprovação visual explícita antes de reformular Leitura, Rítmica, Harmonia, Trilhas e Conta. Recomenda-se então evoluir uma área por vez, com fixtures musicais, comparação visual e áudio preservados; não iniciar automaticamente níveis, aulas, Arena, Carreira ou cobrança.
