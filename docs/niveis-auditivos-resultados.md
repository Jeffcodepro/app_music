# Menu da conta e níveis dos exercícios auditivos

Entrega local de 20/10/2026. Branch preservada: `feat/canonical-music-model`, HEAD `16f9d18`. Nenhum commit, push, troca de branch ou deploy. Nenhuma migration nesta tarefa.

## Resultado

- Perfil no rodapé abre um menu acima do botão, com identidade/e-mail, Painel do membro, Configurações e Sair. O logout mantém o formulário DELETE autenticado do Devise. A referência foi aplicada à organização e interação, conservando as cores neutras do AppMusic.
- Dificuldade 1–4 em Intervalos, Harmonia e Ditado melódico, dentro de Configurar treino. Treino livre conserva o contrato anterior. Dificuldade, instrumento e atribuição sobrevivem à reabertura; a resposta usa o nível persistido, ignorando o nível forjado no POST.
- Intervalos filtram gabarito, distratores e fallback por nível. Harmonia limita modalidades, tonalidades, graus e estruturas; nível 4 acrescenta inversões verificadas por aritmética independente. Alterar só o instrumento agora também persiste a escolha ao retornar sem parâmetros.
- Ditados passam de uma voz/quatro notas a três ou quatro vozes, com 12–16 notas por voz e ritmos variados. Há quatro partituras, pautas separadas e reprodução simultânea. Quantidade de eventos, alturas, frequências, durações, limites do nível e unicidade sonora das alternativas são conferidos no backend.
- Repetir conserva a questão. Após acerto, Próximo e tocar cria outra atribuição e executa uma vez. Erro de dispositivo não vira erro de conhecimento nem concede XP.

A [matriz editorial](niveis-percepcao-harmonia-ditados.md) registra as decisões musicais. A [lista incremental de arquivos](niveis-auditivos-arquivos.md) separa este trabalho das alterações anteriores.

## Preservação e contratos

Inventário SHA-256 anterior às edições, com cópia de código/testes/config/db em `/private/tmp/appmusic-difficulty-baseline-_n19lm_7`. O comparativo final não encontrou remoção nova de arquivo preexistente. A exclusão de `scroll_video_controller.js` já existia no inventário inicial.

Conferidos iguais ao início: `AGENTS.md`, landing pública, `db/schema.rb`, modelos de atribuição/tentativa, serviço transacional de resposta e migration anterior de visitas diárias. Alterações locais anteriores preservadas. Servidor original em 3000 preservado.

O novo formato `voices-v1` é discriminado explicitamente. O ditado anterior de quatro notas continua com seu parser e transporte. Harmonia sem nível foi comparada exatamente, após normalizar chaves JSON, com oito payloads literais extraídos da cópia anterior do gerador — quatro modalidades × duas estruturas.

Harmonia com nível armazena o payload validado completo, evitando reconstruir inversões aleatórias na reidratação. Não houve alteração no serviço de XP, teto de 20 XP por atribuição, autenticação ou restrições de banco.

## Testes executados

Ruby 3.3.5 via rbenv, Bundler 2.6.8, Rails 7.1.6, PostgreSQL 15. Banco `app_music_integrity_compact_test`, cluster privado `/private/tmp/app-music-compact-B2tCzd`, somente socket, sem TCP. O guard conferiu nome do banco, permissões do diretório e `data_directory` real. Nenhum teste usou banco de desenvolvimento, produção ou homologação.

| Verificação | Resultado final |
| --- | --- |
| `bin/test-isolated` | **252 testes, 11.424 asserções, 0 falhas, 0 erros, 0 skips** |
| `node --test test/javascript/*.cjs` | **83 testes, 0 falhas** |
| `git diff --check` | Aprovado |

A suíte Rails inclui HTTP, identidade de tentativa, idempotência, concorrência em PostgreSQL e regressões anteriores. As novas regressões cobrem quatro níveis, recência, modalidades/estruturas harmônicas permitidas, inversões literais de Dó maior, índices inválidos, payloads anteriores e preservação exata do áudio ao reabrir. O corpus novo inclui 60 ditados gerados e conferidos, além do corpus anterior da suíte.

Node verifica uma a quatro vozes nos dois motores: um relógio por execução, mesma duração/onsets, ganho dividido pelas vozes, cancelamento e rejeição de eventos inválidos. Também cobre posicionamento do menu, fechamento ao rolar/redimensionar, remoção de listeners e restauração de foco.

## Navegador

Chromium via Playwright, servidor próprio `127.0.0.1:3001`, `RAILS_ENV=test`, banco separado `app_music_integrity_compact_browser_test` sob o mesmo guard, somente conta sintética. O navegador integrado estava indisponível nesta sessão; foi usado o fallback Playwright.

Executados `test/browser/listening_levels.mjs`, `test/browser/voiced_dictation_audio.mjs` e conferências interativas:

- Doze combinações: quatro níveis em cada modalidade. Retorno sem parâmetros preservou UUID/conteúdo; troca do nível pela UI substituiu a questão via Turbo e mudou o número de vozes.
- Desktop 1440, tablet 768 e mobile 360, claro/escuro: pautas legíveis, rolagem restrita à partitura, inclusive pelo teclado, sem overflow horizontal da página. Sol/Fá e quatro pautas simultâneas conferidas visualmente.
- Menu expandido, sidebar recolhida e drawer: sem clipping. Escape fecha primeiro o menu e depois o drawer, restaura foco; Configurações navega e libera o conteúdo principal.
- Sistema acompanhou preferência clara/escura emulada, sincronizou Bootstrap e persistiu após reload. Capturas conferidas visualmente.
- Duas vozes: soundfont real agendou 23 eventos uma vez; após acerto, nova questão tocou uma vez, com 22 eventos. Indisponibilidade simulada do soundfont acionou sintetizador real do navegador, também 22 eventos e ganho 1/2.
- Quatro vozes: 55 eventos de soundfont, quatro inícios simultâneos, ganho 0,3 por nota de piano, sem segunda passagem automática.
- Falha simulada de dispositivo bloqueou envio. Um único POST de resposta; conta sintética passou de 20 XP/uma tentativa para 40 XP/duas tentativas. Repetições, navegação, fallback e falha não concederam XP.
- Sair encerrou a sessão pelo botão do menu; Dashboard voltou a redirecionar ao login.

Evidências: [output/playwright/listening-levels](../output/playwright/listening-levels/), com `results.json` e capturas. Gabaritos da prova de acerto vieram apenas do banco sintético; nenhum endpoint público ou metadado de correção foi criado.

## Banco, riscos e pendências

Nenhuma alteração de tabela, índice, schema ou migration. JSONB existente comporta os perfis novos. Nenhuma mudança em plano, regras de XP, Leitura/Rítmica ou APIs externas.

Ditados permanecem em Dó maior, 4/4 e 80 BPM, sem pausas/ligaduras/síncopa/quiálteras. Os níveis de treino são opções editoriais, não avaliação de domínio. A matriz rítmica aprovada continua separada. As linhas polifônicas não são apresentadas como contraponto validado. Pode haver repetição aleatória de conteúdo entre novas atribuições; a unicidade exigida é entre alternativas da mesma questão.

Três/quatro vozes aumentam a altura da página. No mobile há rolagem dentro da partitura para ver dois compassos completos, preservando tamanho de leitura.

Permanecem escuta humana de timbre, volume, latência e balanço em dispositivos reais, Safari/iOS e revisão pedagógica da matriz/convenção harmônica. Chromium não equivale à homologação acústica. Pendências históricas de migrations/XP por contexto não foram declaradas resolvidas.

## Verificação local

Abrir Configurar treino em Percepção ou Harmonia e escolher 1–4. Em Percepção, escolher Ditado melódico. Tocar, responder corretamente, Repetir e Próximo e tocar devem ter os comportamentos descritos. Conferir o menu no perfil ao final da sidebar e Sair.

Para repetir a suíte, usar cluster PostgreSQL **descartável e privado**, somente socket, já migrado, cujo nome seja aceito pelo guard. Não usar desenvolvimento ou produção. Exemplo, se o cluster desta entrega for retomado:

```sh
APP_MUSIC_TEST_DATABASE_URL='postgresql:///app_music_integrity_compact_test?host=/private/tmp/app-music-compact-B2tCzd&port=55445&user=compact' CI=1 SCHEMA=/private/tmp/app-music-compact-B2tCzd/difficulty-schema.rb rbenv exec ruby bin/test-isolated
node --test test/javascript/*.cjs
git diff --check
```

Servidor próprio em 3001 e cluster temporário encerrados ao final; artefatos preservados. Nenhuma etapa seguinte iniciada.
