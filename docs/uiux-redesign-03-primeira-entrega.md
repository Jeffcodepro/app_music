# UI/UX REDESIGN 03 — primeira entrega para aprovação

Implementado localmente: novo App Shell, Dashboard e Playground de Percepção, na direção **Partitura em Tinta Neutra**. A expansão para outras telas não foi iniciada e exige aprovação visual explícita.

## Diagnóstico e decisão visual

A versão anterior tinha um menu com ativo em cápsula preenchida, chamada de prática separada da saudação, quatro blocos em duas colunas e métricas dentro de outro card. Em Percepção, H1/H2/H3 repetiam o contexto, configurações e placar competiam com a pergunta, os controles de áudio tinham somente ícones e cada alternativa repetia uma instrução.

A composição nova usa sidebar discreta de 216px, ativo com linha e peso tipográfico, header compacto, lista editorial numerada de práticas e histórico lateral no desktop. O Dashboard vazio oferece um destino real. As métricas ficam numa faixa tipográfica secundária, com sua interpretação explicitada. No tablet estreito e celular, histórico e práticas se empilham.

Percepção tem título próprio, objetivo, navegação em abas, configurações secundárias, botões “Tocar intervalo”/“Repetir”, estado real de reprodução, quatro respostas proporcionais e feedback próximo. A escolha enviada é identificada por “Sua resposta”; não foi criada outra etapa de confirmação. O placar informa que se refere à sessão. Não há ondas fictícias, notas que revelem o intervalo antes da resposta, novos exercícios ou representações artificiais do áudio.

Inter e os ícones SVG locais foram preservados. Claro usa FAFAFA/FFFFFF/F2F2F2; escuro usa 141414/202020/292929. Cor de erro acompanha mensagem textual. Temas e drawer reutilizam os controllers existentes, sem nova chave de armazenamento.

**Limite desta prévia:** o shell novo aparece somente em Dashboard e Percepção. Prática, Histórico, Leitura, Rítmica, Harmonia, Trilhas e Conta continuam com a apresentação anterior até aprovação. Landing, autenticação e onboarding não recebem o escopo novo.

## Evidências reais

Abra a [galeria comparativa](../output/playwright/redesign03/index.html). Ela permite comparar antes/depois, temas e formatos; todas as imagens são screenshots de Chromium, com dados fictícios persistidos no PostgreSQL isolado.

- Dashboard com atividade: [desktop claro](../output/playwright/redesign03/states/dashboard-com-atividade-light-desktop.png), [desktop escuro](../output/playwright/redesign03/states/dashboard-com-atividade-dark-desktop.png), [mobile claro](../output/playwright/redesign03/states/dashboard-com-atividade-light-mobile.png), [mobile escuro](../output/playwright/redesign03/states/dashboard-com-atividade-dark-mobile.png).
- Percepção: [desktop claro](../output/playwright/redesign03/after/percepcao-light-1440x900.png), [desktop escuro](../output/playwright/redesign03/after/percepcao-dark-1440x900.png), [mobile claro](../output/playwright/redesign03/after/percepcao-light-390x844.png), [mobile escuro](../output/playwright/redesign03/after/percepcao-dark-390x844.png).
- Seleção/feedback: [incorreta](../output/playwright/redesign03/states/percepcao-selecao-incorreta-light-mobile.png), [correta](../output/playwright/redesign03/states/percepcao-selecao-correta-dark-mobile.png), [falha neutra](../output/playwright/redesign03/states/percepcao-falha-neutra-dark-mobile.png).
- Navegação: [drawer mobile](../output/playwright/redesign03/after/drawer-mobile-dark.png), [tablet](../output/playwright/redesign03/after/drawer-tablet-light-820.png).

A referência anterior foi capturada antes das edições desta missão, no mesmo projeto, com uma conta sintética vazia. O Dashboard com atividade mostra duas respostas posteriores reais; as imagens `after/dashboard-*` também documentam o estado vazio. Tablet não possui captura anterior nesta missão; a galeria identifica quando usa desktop como referência.

## Matriz e acessibilidade verificadas

| Viewport | Dashboard claro/escuro | Percepção claro/escuro |
|---|---|---|
| 360 × 640 | passou | passou |
| 390 × 844 | passou | passou |
| 768 × 1024 | passou | passou |
| 820 × 1180 | passou | passou |
| 1024 × 768 | passou | passou |
| 1440 × 900 | passou | passou |
| 1920 × 1080 | passou | passou |

28 cenários sem rolagem horizontal, com um H1 e controles principais medidos em pelo menos 44 × 44px. Há rolagem vertical normal, principalmente para alternativas/feedback no celular. A checagem de alvos não pretende auditar cada pixel de todos os componentes do produto.

Verificados no navegador: abrir/fechar com o mesmo botão; Escape; clique fora; foco preso em ambas as direções; restauração do foco; workspace inerte e scroll bloqueado; recolhimento desktop persistido; rail de 76px e drawer nos três tablets; ativo correto; navegação Turbo; voltar para a prévia; tema explícito após reload e navegação; sistema alternando ao vivo; sincronização entre abas e atributo Bootstrap; movimento reduzido; reflow a 640 CSS px (equivalente de layout a 200% numa janela de 1280px, não teste de zoom nativo).

22 pares dos tokens efetivamente calculados no navegador passaram: texto ≥4,5:1 e controles/foco ≥3:1. Texto secundário teve mínimo 6,98:1 no claro e 7,74:1 no escuro; ações 17,93:1 e 16,44:1. Também foram medidas **98 ocorrências reais de texto** nos feedbacks: 46 no erro claro (mínimo 6,32:1) e 52 no acerto escuro (mínimo 7,74:1). Isso é evidência dos casos medidos, **não certificação WCAG de todo o aplicativo**. Não houve teste com leitor de tela ou Safari/dispositivo físico.

## Testes executados e contratos

- Ruby 3.3.5 via rbenv; Bundler 2.6.8; Rails 7.1.6; dependências já instaladas e satisfeitas.
- PostgreSQL 15.19 temporário, diretório/socket privados, sem TCP; identidade real da conexão e `listen_addresses` verificados. Dois bancos separados: suíte e browser. Nenhum teste usou o banco de desenvolvimento.
- As oito migrations existentes foram aplicadas somente aos bancos novos e descartáveis, com `SCHEMA` no scratch. Nenhuma migration nova nem alteração de `db/schema.rb`.
- Regressão inicial direcionada: **15 testes / 406 asserções**, zero falhas/erros/skips.
- Suíte Rails completa: **177 testes / 5.850 asserções**, zero falhas/erros/skips. Inclui corpus musical, isolamento por usuário, identidade das respostas, HTTP, idempotência e concorrência.
- Após o acabamento semântico do markup, os 15 testes direcionados / 406 asserções passaram novamente.
- JavaScript: **42 testes aprovados**, zero falhas/skips, incluindo áudio e temas.
- Dois roteiros Playwright novos executados: matriz/interações/contraste e Percepção com reprodução e POSTs reais.
- No browser: tentativa antes/durante áudio não enviou POST; erro e acerto posterior preservaram atribuição, renovaram token e totalizaram 20 XP (6 + 14), duas tentativas e duas linhas no histórico. As quatro alternativas foram encerradas após acerto. Próxima rodada interrompeu o áudio anterior. CDN de amostras bloqueado acionou sintetizador; falha simulada dos dois caminhos manteve estado neutro e não enviou outra resposta.
- `node --check` nos dois roteiros; `git diff --check` aprovado.

Os UUIDs, tokens, quatro POSTs, guard de áudio no botão, targets/values Stimulus, parâmetros de preferência e Turbo Frame foram mantidos. O destaque da escolha usa somente `selected_label` devolvido pelo servidor. Não publica o gabarito como metadado. Controllers, geradores, serviços, modelos musicais, XP e engines de áudio ficaram byte a byte iguais ao início desta missão.

Logs: [Rails](../output/playwright/redesign03/rails-final.log), [Node](../output/playwright/redesign03/node-final.log), [matriz](../output/playwright/redesign03/matrix-results.json), [áudio e contraste renderizado](../output/playwright/redesign03/audio-results.json).

## Arquivos desta entrega

| Arquivo | Motivo |
|---|---|
| `app/assets/stylesheets/components/_study_editorial.scss` (novo) | Paleta e composição restritas às duas telas, shell, estados e breakpoints. |
| `app/assets/stylesheets/components/_index.scss` | Importar o estilo depois das bases existentes. |
| `app/helpers/platform_ui_helper.rb` | Restringir a prévia a Dashboard e Percepção. |
| `app/views/layouts/platform.html.erb` | Aplicar o escopo condicional ao body, reutilizando navegação. |
| `app/views/platform/dashboard.html.erb` | Nova composição; dados reais da própria conta e estado vazio com ação. |
| `app/views/student_hub/playground.html.erb` | Título/objetivo próprios só para Percepção. |
| `app/views/student_hub/_perception_playground.html.erb` | Hierarquia, transporte com rótulos, seleção e feedback; contratos mantidos. |
| `test/integration/study_editorial_test.rb` (novo) | Escopo, destinos, formulários, ausência de gabarito e retry/XP/atividade real. |
| `test/integration/perception_playground_flow_test.rb` | Verificar o novo H1 sem exigir o título anterior. |
| `test/integration/playground_compact_layout_test.rb` | Verificar o H2 semântico de Percepção e manter asserções das outras três áreas. |
| `test/browser/study_editorial.mjs` (novo) | Matriz, temas, navegação, foco, targets e contraste. |
| `test/browser/perception_editorial.mjs` (novo) | Reprodução, seleção, feedback, falhas e atividade real. |
| Este relatório e `output/playwright/redesign03/` | Evidências e galeria para aprovação. |

`_side_nav`, `_top_nav`, controllers de menu/tema/áudio, landing, auth/onboarding e demais conteúdos permanecem intactos nesta missão. O novo shell reutiliza esses partials e muda sua apresentação somente sob o escopo da prévia.

## Preservação, Git e limites

Inventário e cópia local foram feitos antes de editar. Dos 1.465 registros do inventário inicial, **1.457 permaneceram iguais** e oito arquivos existentes receberam mudanças desta missão. Arquivos novos estão listados acima. O [comparativo de preservação](../output/playwright/redesign03/preservation-results.json) distingue esta entrega do extenso trabalho anterior não commitado.

Branch preservada: `feat/canonical-music-model`, HEAD `16f9d18`, nada staged. Nenhum commit, push, deploy, exclusão de dados, instalação ou alteração de produção/homologação. O banco local e o servidor preexistente em localhost:3000 foram preservados; somente servidores/clusters temporários criados para QA foram encerrados ao final.

A suíte emitiu aviso preexistente do Rack sobre `unprocessable_entity`. Tone emite aviso de versão no console; falhas de rede/áudio foram intencionais nos cenários correspondentes. A matriz não registrou erro JavaScript de página. A conexão ao navegador integrado estava indisponível, então foi usado Chromium/Playwright disponível, sem instalar dependências. Reprodução agendada e fallback foram verificados, mas isso não substitui escuta humana de timbre, volume e latência.

## Verificação local e próximo marco

Com o servidor de desenvolvimento ativo, faça login com sua conta local e abra `/app/dashboard` e `/app/playground?activity=percepcao`. Alterne Claro/Escuro/Sistema, recarregue, navegue entre as duas telas e confira menu e teclado. Em Percepção, ouça até o fim, responda e confira seleção/feedback e histórico. Use as screenshots para comparar os formatos sem introduzir dados na sua conta.

Para regressões, forneça uma URL de PostgreSQL isolado que satisfaça `lib/isolated_test_database.rb` e use:

```sh
APP_MUSIC_TEST_DATABASE_URL='<URL do banco privado>' SCHEMA='<scratch>/schema.rb' rbenv exec ruby bin/test-isolated db:migrate
APP_MUSIC_TEST_DATABASE_URL='<URL do banco privado>' SCHEMA='<scratch>/schema.rb' CI=1 rbenv exec ruby bin/test-isolated
node --test test/javascript/*.cjs
```

Os módulos de browser exportam funções que recebem uma `page` autenticada com usuário sintético em `127.0.0.1:3001`. Execute `study_editorial.mjs` para a matriz. `perception_editorial.mjs` recebe também `{ UUID_da_atribuição: ID_correto }`, obtido exclusivamente da conta fictícia no banco privado; pressupõe conta sem tentativas e produz duas. Não deduza respostas do DOM nem use conta real para esse roteiro.

**Decisão pendente:** aprovar ou solicitar ajustes visuais nesta primeira entrega. Só após aprovação explícita: Leitura → Rítmica → Harmonia → Prática/Histórico → Trilhas/Conta → QA geral. Síncopa, módulos futuros e regras pedagógicas permanecem fora desta implementação.
