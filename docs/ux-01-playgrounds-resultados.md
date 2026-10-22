**UX-01 — Playgrounds compactos e piano verificável, 19/10/2026**

Implementação local na branch `feat/canonical-music-model`, HEAD `16f9d18`. Sem commit, push, deploy ou troca de branch. Os 15 arquivos pendentes da Missão 03.1 foram preservados: 13 continuam byte a byte iguais ao início; o player de intervalos recebeu as correções de UX sobre o código existente e o carregador do teste JavaScript recebeu o módulo compartilhado, mantendo todos os testes anteriores. Cópias e manifesto inicial estão em `/private/tmp/appmusic-ux01-f5fm05k6`.

1. **Diagnóstico do espaço excessivo.** O renderer de Leitura usa uma pauta de 460 × 210 unidades, mas `width: 100%` a ampliava para quase toda a coluna: o cartão musical chegava a 459–490 px de altura no desktop. A grade do exercício tinha uma coluna, as alternativas tinham altura mínima de 136 px e os cartões de áreas/configurações precediam o exercício. No mobile, o menu da plataforma acrescentava aproximadamente 485 px antes do conteúdo. Portanto, reduzir somente o SVG não resolveria o problema.

2. **Layout e SVG.** A navegação das quatro áreas foi compactada, mantendo as cores existentes. As configurações continuam disponíveis em `details/summary`, com operação por teclado e estado de expansão preservado durante atualizações Turbo. O enunciado da rodada permanece visível. No desktop a partir de 1100 px, estímulo e respostas ficam lado a lado; feedback anunciado por `role=status`/`aria-live` e próxima questão ficam junto às alternativas. O menu mobile é recolhível apenas nos Playgrounds. Respostas têm pelo menos 64 px; navegação, configurações e próxima questão têm alvo mínimo de 44 px.

   A pauta de uma nota tem cartão de até 480 px de largura e ficou em 223–226 px de altura no desktop. As coordenadas da pauta, claves e alturas de Leitura permanecem iguais; o `viewBox` se expande verticalmente quando notas/acidentes extremos precisam de espaço. Na Rítmica, o canvas elimina margens vazias, mantendo coordenadas dos ataques. A inspeção revelou duas falhas anteriores: cabeças de semicolcheias de 26 unidades sobrepostas em centros separados por 17,875 unidades, e pausas exibidas como quadradinhos por falta de glifos. Padrões densos agora ajustam uniformemente a cabeça e a ligação da haste, preservando centros e proporção; figuras menos densas mantêm seu tamanho. As alternativas rítmicas usam uma coluna larga para leitura, inclusive no desktop. Três pausas são contornos SVG locais derivados de Bravura, com [proveniência e licenças](licenses/rhythm-rests.md); nenhuma biblioteca ou fonte completa foi incorporada. Essas decisões são de representação visual: tokens, ataques, durações e critérios pedagógicos não mudaram.

3. **Capturas e medidas.** A [matriz do navegador](../output/playwright/ux01/browser-metrics.json) contém as 16 combinações de quatro áreas e quatro resoluções. Não houve rolagem horizontal nem elementos musicais fora do canvas nos casos medidos. Os valores abaixo são coordenadas do documento em pixels CSS; antes/depois usam rodadas sorteadas diferentes, portanto o texto e a altura total podem variar.

| Resolução | Cartão da pauta antes → depois | Início das alternativas antes → depois | Altura da página antes → depois |
|---|---:|---:|---:|
| 1366 × 768 | 459 → 223 | 2314 → 384 | 2642 → 768 |
| 1440 × 900 | 490 → 226 | 2345 → 384 | 2673 → 900 |
| 390 × 844 | 137 → 137 | 3923 → 898 | 4550 → 1277 |
| 375 × 667 | 130 → 130 | 3940 → 891 | 4568 → 1270 |

No mobile a redução veio principalmente da navegação/configurações e da aproximação das respostas; a pauta não foi reduzida. Ainda é necessário rolar verticalmente para ler todas as alternativas, sobretudo em progressões e padrões rítmicos. Não foram ocultados enunciados, respostas ou feedback para caber na tela.

| Evidência | Antes | Depois |
|---|---|---|
| Leitura, 1366 × 768 | [captura](../output/playwright/ux01/before-reading-1366.png) | [captura](../output/playwright/ux01/after-reading-1366.png) |
| Leitura, 1440 × 900 | [captura](../output/playwright/ux01/before-reading-1440.png) | [captura](../output/playwright/ux01/after-reading-1440.png) |
| Leitura, 390 × 844 | [captura](../output/playwright/ux01/before-reading-390.png) | [captura](../output/playwright/ux01/after-reading-390.png) |
| Leitura, 375 × 667 | [captura](../output/playwright/ux01/before-reading-375.png) | [captura](../output/playwright/ux01/after-reading-375.png) |
| Percepção, 1366 × 768 | [captura](../output/playwright/ux01/before-percepcao-1366.png) | [captura](../output/playwright/ux01/after-percepcao-1366.png) |
| Harmonia, 1366 × 768 | [captura](../output/playwright/ux01/before-harmonia-1366.png) | [captura](../output/playwright/ux01/after-harmonia-1366.png) |
| Rítmica, 1366 × 768 | [captura](../output/playwright/ux01/before-ritmica-1366.png) | [captura](../output/playwright/ux01/after-ritmica-1366.png) |

Também foram conferidos uma [rodada com acidente duplo e linha suplementar](../output/playwright/ux01/double-accidental-ledger-mobile.png), [12 exercícios válidos nos extremos das três claves](../output/playwright/ux01/notation-extremes-1366.png), sua [versão mobile](../output/playwright/ux01/notation-extremes-390.png) e [feedback após uma resposta](../output/playwright/ux01/answer-feedback-desktop.png). Os 12 exercícios passaram pelo validador antes de serem renderizados. A emulação de [reflow a 200%](../output/playwright/ux01/reflow-200-percent.png), com viewport CSS de 683 × 384 e escala 2 para uma tela de 1366 × 768, manteve as quatro alternativas e não criou rolagem horizontal. Isso não substitui teste manual do zoom nativo e VoiceOver. Teclado confirmou expansão das configurações, preservação após troca de preferência via Turbo e abertura/fechamento do menu mobile.

4. **Diagnóstico do som.** Antes das alterações, Percepção e Harmonia carregaram e tocaram samples reais de piano, a 48 kHz. O programa foi confirmado tanto no player carregado quanto nas chamadas de reprodução. Não houve fallback nem falha de CDN nesse caminho normal. Não se pode afirmar que esse resultado reproduza o caminho que estava ativo quando o responsável percebeu o som abafado. Foram encontrados envelope adicional com ataque de 10 ms sobre o sample, ganhos diferentes entre áreas (1,311 e 1,45 por voz) e fallback simples filtrado em 3600 Hz. O release padrão de 300 ms dos samples excedia o intervalo de 130 ms entre vozes arpejadas de Harmonia, produzindo sobreposição das caudas; o novo release é de 100 ms. Esses são fatores técnicos ajustados; a causa perceptiva definitiva depende da escuta A/B.

5. **Origem e observabilidade.** O caminho principal continua sendo Tone.js 14.8.49 + soundfont-player 0.12.0, programa `acoustic_grand_piano`, banco MusyngKite, MP3 de `gleitz.github.io/midi-js-soundfonts`. São samples reproduzidos por Web Audio; o caminho de contingência usa osciladores. Não havia reverb adicional nem filtro do aplicativo no caminho dos samples. O filtro estava no sintetizador. Em desenvolvimento, o console `[AppMusic audio]` e o histórico limitado a 50 entradas em `window.__appMusicAudioDiagnostics` mostram engine, programa, sample rate, opções efetivas por acorde, frequências/pitches e motivo de fallback. A produção não habilita esse registro. Nenhum gabarito, XP ou dado pessoal foi acrescentado ao diagnóstico. O [registro real de reprodução](../output/playwright/ux01/live-audio-results.json) inclui os dois caminhos, repetição e cancelamento durante troca de rodada.

6. **Mudanças do piano e segurança de reprodução.** O sample conserva o banco atual; recebe ataque de 1,5 ms, sustain 1 e release de 100 ms, preservando o decaimento que já existe na gravação. O ganho base é 1,2 nos dois players e acordes simultâneos aplicam divisão pela raiz do número de vozes, reduzindo a diferença de volume entre texturas. O fallback compartilha um preset com harmônicos, ataque curto, filtro em 8500 Hz e ausência de desafinação artificial. Ele continua sendo sintético e tem limitações de realismo. Não foram alteradas frequências fundamentais, ordem, duração dos eventos, simultaneidade exigida ou dados canônicos. O envelope de oscilador valida valores finitos e respeita notas curtas. Falha parcial interrompe os sons já agendados antes do fallback; rejeição tardia de uma rodada antiga não pode parar a nova. Sample ausente não pode ser tratado como execução concluída. A prontidão do intervalo inclui a antecedência agendada e a cauda de release. Tentativa antes da escuta mostra instrução neutra.

   A biblioteca documenta as opções de envelope/ganho e o handle de interrupção em suas fontes primárias: [soundfont-player](https://github.com/danigb/soundfont-player) e [sample-player](https://github.com/danigb/sample-player/blob/master/lib/player.js). Os ajustes não exigem trocar essas bibliotecas.

7. **Avaliação auditiva pelo responsável.** Abra [piano-a-b.html](../output/playwright/ux01/piano-a-b.html) localmente. Os quatro WAVs de 15 segundos foram renderizados pelos métodos anterior e atual com as mesmas entradas: Dó3–Mi3, Dó4–Mi4, Dó5–Mi5, Mi4–Lá3 e Dó4–Mi4–Sol4–Si4 simultâneos. Há pares separados para samples e sintetizador, em 48 kHz, com RMS igualado a 0,025. A validação dos WAVs encontrou zero amostras saturadas; picos dos clipes atuais: 0,204 nos samples e 0,260 no sintetizador. Esses resultados medem os clipes, não todos os dispositivos e combinações possíveis. Use o mesmo fone e volume, alterne A/B, compare ataque, grave/médio/agudo, decaimento, aspereza e equilíbrio do acorde. Registre preferência ou ausência de melhoria. Depois confira os players ao vivo em `http://localhost:3000/app/playground?activity=percepcao&instrument=piano` e `http://localhost:3000/app/playground?activity=harmonia&instrument=piano`. **A qualidade acústica não está homologada.**

8. **Testes executados.** Rails: **159 testes, 5.422 asserções, zero falhas/erros/skips**, seed 32356, incluindo corpus de 1.000 exercícios, HTTP, propriedade, correção, idempotência e concorrência PostgreSQL. Node: **32 testes, todos aprovados**, incluindo os 15 preexistentes. Os testes novos reproduziram antes da correção o canvas insuficiente, envelopes fora de ordem, continuação de áudio parcial no fallback, colisão entre semicolcheias e dependência de glifos de pausa. Playwright em Chromium/Chrome 155: 16 cenários de resolução, sem exceções JavaScript nos fluxos normais; 12 fixtures extremas em desktop/mobile sem corte; teclado; reflow ampliado; execução real dos samples; repetição; troca de exercício durante reprodução; CDN deliberadamente bloqueado com fallback funcional em ambas as áreas. Ao simular falha também do sintetizador, houve mensagem neutra, ausência de prontidão e **zero POSTs de resposta** nas duas áreas. Erros de rede das rotas bloqueadas são esperados nesses probes. Há avisos anteriores de autoplay/Tone e Tailwind CDN no carregamento normal; não foram apresentados como falhas novas do aplicativo.

   Ruby usado: 3.3.5 via rbenv; Bundler 2.6.8; Rails 7.1.6; PostgreSQL 15.19. Testes e navegador usaram bancos diferentes, `app_music_integrity_ux01_test` e `app_music_integrity_ux01_browser_test`, em cluster privado com socket `/private/tmp/app-music-ux01-uczychzp`, diretório de dados próprio e TCP desabilitado. A identidade foi conferida pelo guard antes de conectar. Somente as oito migrations já existentes foram aplicadas nesses bancos. `SCHEMA` apontou para o scratch. Não há migration nova, alteração de `db/schema.rb`, teste contra desenvolvimento ou mudança de dados reais. `git diff --check` passou.

9. **Performance e carregamento.** Nenhum sample ou pacote de áudio novo foi adicionado; permanecem preload, caches e fallback existentes, com espera máxima de 2,2 s pelo SoundFont antes da contingência. O módulo compartilhado servido em desenvolvimento tem aproximadamente 2,3 KB. Os três contornos locais das pausas aumentam apenas o SVG inline e eliminam sua dependência de uma fonte musical instalada; não geram download de fonte ou biblioteca. Os quatro WAVs somam aproximadamente 5,5 MiB e são evidências locais carregadas apenas na página A/B, nunca nos Playgrounds. Não houve benchmark de latência em dispositivos reais ou teste extensivo de memória; esses resultados não são inferidos dos testes de agendamento.

10. **Arquivos e pendências.** A relação abaixo separa a implementação desta UX-01 do trabalho anterior. Permanecem pendentes a escuta humana, Safari, zoom nativo, VoiceOver e verificação com equipamentos diferentes. O timbre do fallback e o volume dos acordes precisam da avaliação do responsável. As configurações agora começam recolhidas e a Rítmica prioriza largura/legibilidade, com rolagem vertical para as quatro partituras: são os principais pontos de UX para revisar. Não houve alterações de XP, gabarito, progressão, convenção harmônica, síncopa, currículo ou IA. O servidor original em `localhost:3000` foi mantido; respondeu HTTP 200 e entregou o módulo novo sem reiniciá-lo. As instâncias e o cluster usados exclusivamente nesta validação foram encerrados ao final.

| Arquivos da UX-01 | Justificativa |
|---|---|
| `app/assets/stylesheets/components/_playground_compact.scss`, `_index.scss` | Estilos compactos limitados aos Playgrounds, responsividade e foco visível. |
| `app/views/student_hub/playground.html.erb` e `_reading_playground.html.erb`, `_perception_playground.html.erb`, `_harmony_playground.html.erb`, `_rhythm_playground.html.erb` | Navegação curta, configurações expansíveis, respostas/feedback/próxima questão próximos e dicas neutras de escuta. |
| `app/views/layouts/platform.html.erb`, `app/views/platform/_side_nav.html.erb`, `app/javascript/controllers/app_shell_controller.js` | Menu mobile recolhível nas telas do Playground, com estado acessível. |
| `app/javascript/controllers/preferences_controller.js` | Preservar expansão das configurações após atualizações Turbo. |
| `app/services/reading_staff_svg_renderer.rb`, `rhythm_staff_svg_renderer.rb` | Canvas adaptativo, margens menores, colisão de cabeças e pausas independentes de fonte. |
| `app/javascript/audio/exercise_piano.js`, `config/importmap.rb` | Preset/envelope/diagnóstico compartilhados, sem dependência nova. |
| `app/javascript/controllers/interval_player_controller.js`, `harmony_player_controller.js` | Piano, ganho, cancelamento, prontidão e fallback. O primeiro já continha trabalho preservado da Missão 03.1. |
| `test/javascript/exercise_audio_test.cjs`, `playground_audio_ux_test.cjs` | Carregar o módulo nos testes anteriores e cobrir as regressões novas. |
| `test/services/reading_staff_svg_renderer_test.rb`, `rhythm_staff_svg_renderer_test.rb`, `test/integration/playground_compact_layout_test.rb` | Limites de SVG, notação densa, pausas, quatro respostas, identidade e feedback acessível. |
| `test/browser/playground_ux.mjs`, `playground_audio.mjs`, `piano_audition.mjs` | Procedimentos reproduzíveis usando uma página Playwright já disponível. |
| `docs/licenses/Bravura-OFL.txt`, `VexFlow-MIT.txt`, `rhythm-rests.md` | Licenças e proveniência dos três desenhos. |
| Este relatório e `output/playwright/ux01/` | Capturas, métricas, fixtures e comparação auditiva local. |

Para repetir os testes JavaScript:

```sh
node --test test/javascript/*test.cjs
```

Para repetir Rails, use um cluster temporário novo; os comandos abaixo não apontam para o banco de desenvolvimento:

```sh
UX_PG_BIN=/opt/homebrew/opt/postgresql@15/bin
UX_DB_SOCKET=$(mktemp -d /private/tmp/app-music-ux01.XXXXXX)
chmod 700 "$UX_DB_SOCKET"
"$UX_PG_BIN/initdb" -D "$UX_DB_SOCKET/data" -A trust -U ux01 --encoding=UTF8 --no-locale
"$UX_PG_BIN/pg_ctl" -D "$UX_DB_SOCKET/data" -l "$UX_DB_SOCKET/postgres.log" -o "-c listen_addresses='' -k $UX_DB_SOCKET -p 55439" start
"$UX_PG_BIN/createdb" -h "$UX_DB_SOCKET" -p 55439 -U ux01 app_music_integrity_ux01_test
export APP_MUSIC_TEST_DATABASE_URL="postgresql:///app_music_integrity_ux01_test?host=$UX_DB_SOCKET&port=55439&user=ux01"
SCHEMA="$UX_DB_SOCKET/schema.rb" rbenv exec ruby bin/test-isolated db:migrate
SCHEMA="$UX_DB_SOCKET/schema.rb" CI=1 rbenv exec ruby bin/test-isolated
"$UX_PG_BIN/pg_ctl" -D "$UX_DB_SOCKET/data" stop -m fast
```

Os scripts de navegador exportam funções que recebem `page` de um Playwright existente, sem instalar um runner/dependência neste projeto. Exigem conta fictícia autenticada na instância isolada em `127.0.0.1:3001`; recusam outra origem. Crie outro banco isolado para o navegador, aplique apenas as migrations existentes e inicialize o servidor com `RAILS_ENV=test`, `DATABASE_URL` e `APP_MUSIC_TEST_DATABASE_URL` iguais, carregando `lib/isolated_test_database.rb`. Use `PORT=3001` e um `PIDFILE` exclusivo no scratch. `APP_MUSIC_AUDIO_DIAGNOSTICS=1` habilita o diagnóstico nessa instância de teste. Execute `verifyPlaygrounds(page)` e `verifyAudio(page)` após o login fictício. A audição renderizada recebe os fontes anterior/atual; os anteriores foram preservados no diretório `baseline/app/javascript/controllers/` do scratch informado no início. Para a revisão manual normal, basta atualizar o navegador em `localhost:3000` e abrir a página A/B local.
