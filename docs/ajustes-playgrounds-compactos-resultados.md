# AppMusic — Playgrounds compactos, reprodução e ditado de uma voz

Entrega local de 20/10/2026. Branch preservada: `feat/canonical-music-model`, HEAD `16f9d18`. Nenhum commit, push ou deploy. O pedido atual autoriza compactar os quatro playgrounds; a landing, autenticação, Trilhas, Conta, modelos canônicos e regras de XP preexistentes foram preservados. O seletor do cabeçalho `/app` muda para ícones, enquanto a preferência da seção de aparência mantém o select acessível.

## Resultado

- Reduzidos os cartões de resposta textual para 48 px de altura mínima e rótulos de 15 px. As quatro partituras aparecem em duas colunas no desktop e uma no celular. Configurações continuam recolhíveis, com alvos de interação de pelo menos 44 px.
- Removidos títulos duplicados, “Rodada atual”, blocos de instrução repetidos e explicações dos botões. Mantidos enunciado, dados musicais necessários, foco harmônico, feedback e identidades das tentativas. Em Leitura, “Faixa de conteúdo” identifica os presets existentes, sem atribuir proficiência ao aluno.
- Prática mantém quatro destinos com descrições breves; removido o painel lateral “Prepare sua escuta”. O histórico continua acessível por link abaixo da lista.
- Tema no cabeçalho autenticado: um ícone abre três opções por ícone, com nomes acessíveis, estado selecionado, Escape e retorno de foco. Seleção com mouse não deixa outline persistente; teclado mantém foco neutro de 2 px. Os modos Claro/Escuro/Sistema, Bootstrap, armazenamento, Turbo e seletores da Conta permanecem sincronizados.
- Rítmica: um compasso por clique, mesmo para atribuições antigas que guardam `playback_cycles: 2`. “Repetir” agenda mais um compasso. Contagem de entrada existente preservada; não foi adulterado o payload imutável nem invalidada a identidade das atribuições antigas.
- Ditado melódico em Percepção: uma voz, quatro semínimas em 4/4, Dó maior, início comum em Dó4 e quatro partituras distintas. Os instrumentos existentes são reutilizados. Player reaproveita cache, transporte, cancelamento, sintetizador de contingência e proteção contra resposta antes do término do áudio.
- O novo validador musical recalcula frequências por MIDI e comparação literal de notas naturais, exige quatro alternativas distintas, áudio de quatro notas, referência, compasso, duração, voz, andamento, enunciado e gabarito coerentes. O renderer cobre Dó4–Dó5 e não desenha linha suplementar em Ré4.
- Percepção armazena uma referência à atribuição no banco na sessão, em vez das quatro partituras completas no cookie; mantém leitura de sessões legadas. Modalidade e instrumento sobrevivem ao reload após configuração via Turbo.
- Feedback exige UUID da rodada também em intervalos. Replay/rejeição preservam preferências sanitizadas, evitando trocar de instrumento ou abandonar uma rodada por falha de áudio.

## Arquivos desta entrega e justificativas

O inventário exato e o diff incremental estão em `output/playwright/compact-exercises/incremental-inventory.json` e `incremental.patch`. Eles comparam o estado inicial desta tarefa, incluindo arquivos untracked anteriores; o diff global do Git mistura missões anteriores e não deve ser atribuído integralmente a esta entrega.

| Arquivos | Motivo |
| --- | --- |
| `app/assets/stylesheets/components/_exercise_workbench.scss`, `_index.scss` | Escopo visual compacto dos playgrounds e estilos do seletor por ícones; preservar páginas públicas |
| `app/views/layouts/platform.html.erb`, `app/views/student_hub/playground.html.erb` | Aplicar escopo só aos playgrounds e usar o título da área |
| `app/views/student_hub/_{reading,perception,rhythm,harmony}_playground.html.erb` | Enxugar composição e controles, preservar formulários e contratos; vincular feedback ao UUID |
| `app/views/platform/pratica.html.erb` | Remover instrução lateral sem perder os quatro destinos e o histórico |
| `app/views/platform/_top_nav.html.erb`, `app/views/shared/_theme_control.html.erb`, `_theme_picker.html.erb` | Variante por ícones no cabeçalho autenticado; controles com nomes acessíveis |
| `app/javascript/controllers/theme_controller.js`, `practice_switcher_controller.js`, `app/helpers/platform_ui_helper.rb` | Sincronizar seletores, rótulos acessíveis e estado ativo; fechar disclosure e restaurar foco; ícones locais |
| `app/javascript/controllers/rhythm_player_controller.js` | Agendar um único ciclo por ação |
| `app/services/melodic_dictation_exercise_generator.rb`, `melodic_dictation_integrity_validator.rb`, `melodic_dictation_svg_renderer.rb`, `exercise_integrity_validator.rb` | Gerar, conferir independentemente e desenhar o ditado, integrado à validação de atribuições |
| `app/javascript/controllers/melody_player_controller.js`, `index.js` | Reutilizar player existente com quatro ataques equidistantes e uma referência de tempo por sequência |
| `app/views/student_hub/_melodic_dictation_playground.html.erb`, `_perception_mode_control.html.erb` | Oferecer ditado/intervalos e quatro partituras no fluxo atual |
| `app/controllers/student_hub_controller.rb`, `concerns/playground_integrity.rb` | Gerador por modalidade, ponteiro de sessão, feedback e redirects que preservam configuração |
| `test/services/melodic_dictation_test.rb`, `test/integration/melodic_dictation_flow_test.rb` | Corpus de ditados, corrupções, posições de notas, identidade, reload, retry/replay e falhas neutras |
| `test/integration/{harmony,perception,reading,rhythm}_playground_flow_test.rb`, `playground_compact_layout_test.rb`, `practice_milestone_test.rb` | Atualizar expectativas visuais explicitamente substituídas pelo pedido atual; conservar contratos funcionais |
| `test/javascript/{platform_ui,playground_audio_ux,melodic_dictation_player}_test.cjs` | Reprodução única, ícones sincronizados, duração, cancelamento e relógio que avança durante agendamento |
| `test/browser/compact_exercises.mjs`, `compact_exercise_audio.mjs`, `compact_exercise_contrast.mjs`, `compact_exercise_mode.mjs` | Roteiros reprodutíveis para interface, tema, áudio, fallback e modalidade |
| `docs/proposta-compassos-por-nivel.md` | Matriz editorial para aprovação; nenhum compasso novo ativado |
| Este relatório e `output/playwright/compact-exercises/` | Resultados, capturas, logs, inventário e comparação incremental |

## Validação executada

Ambiente: Ruby 3.3.5 via rbenv; dependências satisfeitas pelo `bundle check`. PostgreSQL 15 em cluster novo privado `/private/tmp/app-music-compact-B2tCzd`, sem TCP, usuário fictício `compact`, dois bancos descartáveis separados: `app_music_integrity_compact_test` para a suíte e `app_music_integrity_compact_browser_test` para o navegador. O guard do projeto confirmou identidade do servidor/banco, diretório privado e ausência de listener TCP antes das execuções. As migrations existentes foram aplicadas apenas nesses bancos, com `SCHEMA` apontando para arquivos temporários. O banco de desenvolvimento e `db/schema.rb` não foram alterados.

| Verificação | Resultado real |
| --- | --- |
| Rails completa, incluindo integração, corpus e concorrência existentes | **202 testes, 6.882 asserções; 0 falhas, 0 erros, 0 skips** |
| Node completa | **53 testes aprovados; 0 falhas** |
| Matriz Chromium | **36 capturas**: Prática, quatro playgrounds e ditado; 1440×1000, 820×1180 e 390×844; claro/escuro; sem overflow horizontal |
| Tema | Claro/Escuro/Sistema após reload; mudança de OS; navegação Turbo; sincronização entre abas e select da Conta; ícones sem texto; mouse sem outline persistente; teclado com foco visível e Escape |
| Contraste dos textos renderizados | 12 cenários, mínimo medido **6,97:1**; verificação delimitada de texto, sem afirmar certificação WCAG |
| Navegação móvel | Drawer com conteúdo de fundo inerte, Escape, links de Prática, troca de área e configuração expansível |
| Rítmica real no navegador | Atribuição legada de dois ciclos: 12 eventos → 12 ataques; após “Repetir”, total 24 |
| Ditado real no navegador | Piano `acoustic_grand_piano`: quatro notas em intervalos de 0,75 s; repetição acrescenta quatro notas; nenhuma resposta antes de ouvir |
| CDN de amostras bloqueado | Sintetizador real completou as quatro notas; falha adicional simulada deixou estado neutro, **0 POSTs de resposta** |
| Modalidade pelo formulário | Ditado escolhido na UI mantém UUID no reload; flauta também persiste |
| `git diff --check` e inventário SHA-256 | Sem erro de whitespace; nenhum arquivo preexistente removido nesta tarefa |

Testes antes da correção reproduziram: oito ataques em vez de quatro no ciclo legado; duas linhas suplementares no exemplo Dó4/Ré4 em vez de uma; leitura repetida do relógio durante a sequência causando deriva de tempo. O teste do novo ditado inicialmente falhou por ausência das classes, antes da implementação. Os logs correspondentes foram preservados.

A primeira suíte completa revelou quatro expectativas textuais antigas, atualizadas para a nova composição solicitada. Uma execução intermediária encontrou colisão da conta fictícia do browser com uma factory; o navegador foi separado em outro banco descartável e a conta sintética removida apenas do banco da suíte. O resultado final acima passou com os bancos separados. O aviso preexistente do Rack sobre `unprocessable_entity` continua.

## Preservação, banco e limites

Snapshot inicial em `/private/tmp/appmusic-compact-baseline-c58j0w0d`: arquivos locais, inventário SHA-256, status e diff. A exclusão preexistente de `scroll_video_controller.js` foi preservada; não foi feita nesta entrega. Nenhum arquivo inicial adicional foi removido. Landing, fontes globais, telas de autenticação, Trilhas, Conta, migrations, schema e serviço transacional de pontuação têm o mesmo conteúdo do início desta tarefa.

**Nenhuma migration nova necessária.** O ditado usa JSONB da atribuição existente e os mesmos registros de tentativa/crédito. Teto de 20 XP por atribuição, propriedade, expiração, idempotência e falha de áudio neutra continuam no backend. O status de reprodução enviado pelo navegador não prova escuta humana.

O Chromium executou os motores de áudio, mas não houve escuta humana em alto-falante/fones. Timbre, volume, latência e Safari/VoiceOver/dispositivos reais continuam precisando de homologação. Os intervalos preservam duas notas e a harmonia preserva as vozes/progressões que pertencem ao próprio exercício; a remoção foi do ciclo rítmico duplicado, não de notas musicais legítimas.

Novos compassos, progressão por nível, polifonia de duas a quatro vozes e síncopa **não foram ativados**. A matriz completa, agrupamentos, unidades de BPM, faixas e alternativa de dois compassos para Pulso 2/4 estão na proposta para aprovação. O ditado melódico inicial não cobre ainda pausas, ritmos variados, outras tonalidades ou múltiplas vozes.

Riscos delimitados: composição mais compacta precisa da aprovação visual do usuário; o novo tipo de exercício adiciona payload/renderização/player, cobertos pelas regressões acima; futuras mudanças de compasso devem atualizar gerador, validador, serialização, notação e áudio em conjunto. A seleção do novo tipo usa a modalidade na URL, e o ponteiro de sessão preserva compatibilidade de leitura com sessões legadas.

## Verificação local

No servidor de desenvolvimento existente, entrar com sua própria conta e abrir `/app/pratica`. Conferir os quatro destinos e ausência do painel lateral. Em cada playground, conferir opções menores, configuração recolhível, resposta e navegação. Em Percepção → Configurar treino → Ditado melódico · 1 voz, tocar, responder, repetir e recarregar; verificar as quatro partituras e a manutenção do instrumento. Em Rítmica → Subdivisão, cada clique deve executar um único compasso depois da contagem inicial.

No cabeçalho, escolher os ícones de sol, lua e sistema; recarregar, navegar e trocar o esquema do sistema. Conferir mouse sem foco pesado e teclado com foco visível. A galeria está em `output/playwright/compact-exercises/index.html`.

```sh
node --test test/javascript/*.cjs
# Somente em cluster privado aceito pelo guard do projeto:
APP_MUSIC_TEST_DATABASE_URL='<URL privada>' SCHEMA='<scratch>/schema.rb' rbenv exec ruby bin/test-isolated db:migrate
APP_MUSIC_TEST_DATABASE_URL='<URL privada>' SCHEMA='<scratch>/schema.rb' CI=1 rbenv exec ruby bin/test-isolated
```

Os roteiros em `test/browser/compact_*.mjs` exportam funções que recebem uma `page` autenticada com conta fictícia em `127.0.0.1:3001`. Eles não fazem login nem criam contas reais. O navegador integrado ficou indisponível após o bootstrap da skill; foi utilizado o Chromium/Playwright já disponível, sem instalar dependências. Servidor e cluster temporários foram encerrados ao término; o servidor original na porta 3000 não foi reiniciado nem interrompido.

Próximo passo: revisar a aparência compacta e aprovar/ajustar a proposta de compassos. A aprovação deve preceder sua implementação; não iniciar automaticamente polifonia ou progressão de níveis.
