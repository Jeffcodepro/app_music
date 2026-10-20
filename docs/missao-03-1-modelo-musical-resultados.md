# Missão 03.1 — Representação musical canônica

Execução local em **19/10/2026**, a partir de `16f9d18`. O Git estava limpo, contrariando a previsão de alterações pendentes no anexo porque o usuário acabara de autorizar seu commit. Após comunicar o estado e a estratégia, foi criada **`feat/canonical-music-model`**; a branch anterior e o commit permaneceram preservados. Nenhum novo commit, push ou deploy foi executado.

## A. Arquitetura e contratos

Foram criados dois objetos imutáveis em `app/models/music_theory`, sem herdar de Active Record e sem persistência:

- **`MusicTheory::Note`**: letra diatônica, alteração inteira e oitava; parsing estrito, identidade escrita, MIDI, frequência, equivalência sonora e serialização ASCII/Unicode.
- **`MusicTheory::Interval`**: duas notas escritas ordenadas; distâncias diatônica/cromática, número, qualidade, direções escrita/sonora, simples/composto e abreviatura.

A API completa, exemplos, fórmulas e convenções estão no [guia do modelo canônico](modelo-musical-canonico.md). O namespace não precisa de Rails para funcionar. A integração permanece nos serviços existentes; não foram adicionadas camadas de persistência, microsserviços ou uma segunda representação serializada nos exercícios.

A análise inicial encontrou: objetos `HeadMusic` internos aos geradores, strings de pitch nos payloads, duas implementações de localização, validação aritmética independente e normalização cromática no JavaScript. SVG usa posição de pauta e ID do acidente; áudio usa pitches/frequências. Essas fronteiras foram conservadas.

## B. Regras musicais e decisões explícitas

Convenções: temperamento igual de 12 semitons, A4 = 440 Hz por padrão e C4 = MIDI 60. Frequências são calculadas, sem tabela de frequências de produção. As notas suportam alterações inteiras −2 a +2, e o MIDI resultante deve estar em 0–127, incluindo cruzamentos de oitava como B♯3/C4 e C♭4/B3.

`same_spelling?` compara letra/alteração/oitava; `same_pitch?` compara a altura sob uma referência comum. `==` conserva identidade escrita. O método `frequency(a4:)` aceita outra referência real positiva/finita, mas recusa resultados não finitos, zero ou acima de 20.000 Hz. Com 440 Hz, a faixa MIDI aceita equivale aproximadamente a 8,1758–12.543,854 Hz. Os playgrounds mantêm 440 Hz.

Intervalos usam simultaneamente distância diatônica e cromática. Referências literais incluem C4→E4 (M3), C4→E♭4 (m3), E4→A3 (P5 descendente), C4→F4 (P4) e C4→E♯4 (A3). O domínio não transforma uma terça aumentada em quarta apenas por terem cinco semitons.

Decisões de representação, sem alteração das alternativas pedagógicas existentes:

| Caso | Convenção |
| --- | --- |
| C4→C4 | P1, escrita e som estacionários |
| C4↔C♯4 | A1, escrita estacionária, direção sonora conforme o movimento; não se usa “uníssono diminuto” |
| C♯4→D♭4 ou B♯3→C4 | d2, escrita ascendente e som estacionário |
| Compostos | Números até 15; oitava é simples, décima quinta é composta; redução 15→8 |
| Múltiplas qualidades ou movimento cruzado | Recusa explícita com `Interval::Unsupported`; por exemplo C4→F𝄪4 e C𝄪4→D♭4 |
| Bequadro | Altura com `alter: 0`; impressão do símbolo continua no contexto separado |

Não foi implementada memória de acidentes por compasso/armadura, microtonalidade, transposição de instrumentos ou nova classificação harmônica. As categorias novas do objeto de domínio não foram acrescentadas ao currículo nem ao sorteio de Percepção. As referências externas consultadas e os limites estão ligados no guia.

## C. Arquivos criados e modificados

| Arquivo | Motivo |
| --- | --- |
| `app/models/music_theory/note.rb` | Novo valor de nota escrita e conversões determinísticas |
| `app/models/music_theory/interval.rb` | Novo valor de intervalo e direções distintas |
| `app/services/reading_note_exercise_generator.rb` | Notas canônicas nas posições e alterações; localização compartilhada |
| `app/services/perception_interval_exercise_generator.rb` | Notas/frequências/intervalos canônicos e rejeição de transposição contraditória |
| `app/services/exercise_presentation.rb` | Localização única e adaptação explícita da nota isolada de Leitura |
| `app/services/exercise_integrity_validator.rb` | Parser canônico com limites, preservando aritmética independente de correção |
| `app/javascript/controllers/interval_player_controller.js` | Validação de frequência e normalização segura dos pitches, incluindo oitavas e acidentes duplos |
| `config/application.rb` | Excluir o script executável de isolamento do autoload, mantendo seus requires explícitos |
| `test/music_theory/note_test.rb` | 10 testes sem Rails, com referências literais e invariantes |
| `test/music_theory/interval_test.rb` | 7 testes sem Rails, incluindo direção, enarmonia, compostos e limites |
| `test/services/canonical_music_integration_test.rb` | 10 testes de compatibilidade, correção independente, SVG, carregamento e pontuação |
| `test/support/legacy_reading_perception_exercises.json` | Seis payloads/digests capturados antes da integração, para regressão de compatibilidade |
| `test/javascript/exercise_audio_test.cjs` | Três novas regressões do player de intervalo |
| `docs/modelo-musical-canonico.md` | API, convenções, limites e extensões futuras |
| `docs/missao-03-1-modelo-musical-resultados.md` | Este relatório |

Não houve modificação de controller, formulário, modelo persistido, regras de XP, renderer SVG, biblioteca, Gemfile, lockfile, schema ou migration.

## D. Integração incremental

Leitura continua recebendo posições de clave de `HeadMusic`, mas converte cada nota em `MusicTheory::Note` e usa seu `step`. Para acidentes, aplica a alteração real no valor canônico e conserva o formato legado: `pitch_name` natural e `note_accidental_id` separado. `ExercisePresentation.reading_note` explicita essa adaptação para notas isoladas. O SVG continua escolhendo o glifo pelo ID validado.

Percepção mantém seleção de intervalos, referências, instrumentos e transposição da biblioteca. Converte os resultados para `Note`, deriva frequência e classifica com `Interval`. Antes de publicar, compara classificação/direções com a opção selecionada, rejeitando uma transposição divergente. Strings Unicode e assinaturas permanecem compatíveis.

A localização compartilhada passa também a reconhecer grafias Unicode no feedback, por exemplo G♯4 como “Sol sustenido 4”. Essa correção de texto não modifica o payload nem suas assinaturas.

O validador não usa a classificação do novo `Interval` como prova. A partir dos campos de nota validados, recalcula relações com sua aritmética própria e confere gabarito, frequência, direção e apresentação. A duplicação deliberada dessa verificação conserva a independência; as referências de teste não vêm de `HeadMusic`.

O player mantém os caminhos soundfont/sintetizador, com guard de frequência nos dois e antes de agendar tons. Pitches inválidos ou MIDI fora da faixa agora falham explicitamente. A falha preserva o feedback neutro já existente.

Durante a verificação global de carregamento, foi reproduzido um erro anterior: `lib/isolated_test_database.rb` é um script executável sem constante `IsolatedTestDatabase`, mas estava no autoload de `lib`. O ajuste o ignora apenas nesse mecanismo. `bin/test-isolated`, `test_helper` e o auditor continuam exigindo o guard explicitamente. O teste de carregamento e os seis testes de segurança passaram; a implementação do guard não foi alterada.

## E. Testes e evidências

Ruby **3.3.5**, Bundler **2.6.8**, Rails **7.1.6**, `head_music` **12.3.0**, PostgreSQL **15.19**; dependências existentes satisfeitas. Nenhum override de conexão estava presente na abertura.

O cluster `/private/tmp/am031-astgm40y`, porta 55451, role `app_music_m031`, foi criado exclusivamente para esta missão, com socket privado, diretórios 0700, UTF-8 e TCP desabilitado. As oito migrations existentes foram aplicadas em bancos novos `app_music_integrity_m031_test` e `app_music_integrity_m031_browser_test`, separados do desenvolvimento e entre si. `SCHEMA` apontou sempre para arquivos privados temporários.

| Execução | Resultado observado |
| --- | --- |
| Referências do núcleo | **21 notas e 25 intervalos literais**, incluindo acidentes duplos, mudanças de oitava, enarmonia, qualidades e direção |
| Invariantes de notas | **315 combinações determinísticas**, round-trip ASCII/Unicode, MIDI/oitava e duplicação de frequência |
| Núcleo + integração + segurança, execução final direcionada | **33 testes, 2.532 asserções**, zero falhas/erros/skips, seed `61150` |
| Primeira regressão ampla de Leitura/Percepção/validador | **67 testes, 3.786 asserções**, sem falhas, antes das três regressões finais adicionais |
| Suíte final com `CI=1`, carregamento completo habilitado | **153 testes, 5.124 asserções**, zero falhas/erros/skips, seed `60257` |
| JavaScript | **15 testes aprovados**, zero falhas |
| Revisão do diff e arquivos novos | `git diff --check` e conferência de whitespace aprovados |
| Compatibilidade de payloads completos | **500 payloads anteriores × código final, nenhuma diferença** |
| Preservação do desenvolvimento | `compare-full` antes/depois: **código 0**, igualdade nas cinco categorias, zero órfãos |

São **27 testes Rails novos** sobre os 126 anteriores, e três JavaScript novos sobre os 12 anteriores. O núcleo roda também diretamente por Ruby, sem Rails/banco, com **17 testes em duas classes e 2.347 asserções**. A suíte final inclui corpus de 1.000 exercícios das quatro áreas, integração HTTP, recuperação de migrations, proteção dos scripts e concorrência/idempotência existentes.

Antes da implementação, os testes do núcleo falharam por ausência das classes; as novas regressões Rails reproduziram adaptador ausente, uso da frequência da biblioteca e aceitação fora do MIDI. As três novas regressões Node falharam antes dos guards. Também foram registrados antes das correções o aceite de transposição contraditória (uma falha) e o erro de eager loading (um erro). Esses resultados intermediários estão nos logs privados; não foram apresentados como aprovação.

Evidências privadas em `/private/tmp/appmusic-m031-h8afmo15`: `rails-ci-final.log`, `core-integration-final.log`, `compatibility-corpus.json`, `browser-verification.json` e `development-preservation-full.json`, além dos snapshots e registros de navegador. Os snapshots completos e os dados da conta de teste não foram acrescentados ao Git. Esse diretório é temporário e não substitui armazenamento durável de evidências.

Ao encerrar, os dois bancos não tinham objetos/schemas/roles residuais das fixtures de captura. Apenas o Puma temporário em 3001 e o cluster `/private/tmp/am031-astgm40y` foram parados, preservando seus arquivos. Depois disso, `/up` do servidor original retornou 200 e o PostgreSQL original continuou aceitando conexões em `/tmp:5432`.

## F. Compatibilidade e dados

A versão permanece **`integrity-2`**. Não foram alterados IDs de atribuição, tokens, formato de resposta HTTP, digests, fluxo de envio ou política de crédito. As seis fixtures de compatibilidade incluem Leitura natural, acidente duplo, armadura e Percepção ascendente/descendente/alterada. Elas são snapshots do código anterior para provar compatibilidade, não a fonte dos resultados musicais literais.

Os testes persistem esses payloads com seus digests anteriores, simulando atribuições preexistentes, reabrem o exercício e verificam envio correto/replay: uma tentativa e 20 XP por atribuição. Testes existentes mantêm 6 XP no primeiro erro e teto de 20 após acerto, sem crédito duplicado sob concorrência.

O parser passa a recusar alturas fora de MIDI 0–127, estados já inconsistentes com o novo contrato de nota. Os payloads válidos atuais conferidos no corpus não mudaram. Não houve renovação em massa nem alteração retroativa de atribuições ou créditos.

O banco `app_music_development` foi consultado somente por transações de leitura com identidade explícita. A comparação integral inicial/final confirmou estrutura, versões, registros/fingerprints, FKs e sequências iguais. O schema do projeto manteve SHA-256 `6888fb3253ab7852b96279705a076da9d12a89ef2aae9dd836d28af741fc3093`; todas as migrations ficaram intactas.

## G. Funcionamento local e navegador

O servidor existente em **127.0.0.1:3000** permaneceu ativo e seu `/up` respondeu 200. Ele não foi reiniciado. A inicialização de uma nova instância com o código final foi verificada em **127.0.0.1:3001**, `RAILS_ENV=test`, com PID próprio e banco temporário confirmado. O navegador integrado estava indisponível; foi utilizado o Playwright já disponível, sem instalação de dependências.

Foi criada exclusivamente nesse banco temporário uma conta sintética. Fluxos efetivamente exercitados:

1. Login e Dashboard.
2. Leitura natural em clave de Sol: posição de C5 identificada pelo SVG, envio de Dó e feedback correto.
3. Percepção D3→A4: reprodução pelo botão, resposta P12 e feedback correto com Ré 3→Lá 4.
4. Após reiniciar somente a instância temporária com o código final, novo login preservou os 40 XP anteriores.
5. Leitura com acidente duplo: A3 com glifo 𝄪, resposta Lá duplo sustenido e feedback correto, preservando grafia em vez de responder por enarmonia.
6. Percepção descendente E5→G♯4: reprodução, resposta m6 e feedback correto com Mi 5→Sol sustenido 4.
7. Rítmica e Harmonia abriram suas telas; Harmonia exibiu quatro alternativas sem erro de página. Seus envios e regras são cobertos pela suíte HTTP, sem nova homologação acústica desses módulos.

A conferência no banco temporário confirmou **quatro tentativas, quatro atividades e 80 XP** — 40 em Leitura e 40 em Percepção. Não houve alteração de conta real. O browser não registrou erros JavaScript nos fluxos observados; houve avisos de autoplay antes do gesto do usuário, Tailwind CDN e preload CSS. Não foram tratados como falha musical nem corrigidos fora deste escopo.

Não houve escuta humana ou ensaio em Safari/dispositivo físico. A reprodução concluída e a resposta aceita verificam o fluxo técnico; não comprovam timbre, volume, latência ou som efetivamente ouvido. Os testes de fallback com CDN rejeitado continuam simulados no Node.

## H. Verificação local, riscos e pendências

Sem banco, na raiz do projeto:

```sh
rbenv exec bundle exec ruby test/music_theory/note_test.rb
rbenv exec bundle exec ruby test/music_theory/interval_test.rb
node --test test/javascript/exercise_audio_test.cjs
```

Para reproduzir a suíte sem usar o banco existente, execute este bloco na raiz do projeto. Ele cria um cluster novo, valida o destino pelo runner e para somente esse cluster ao sair. Não carrega seeds e mantém o schema gerado fora do repositório:

```bash
(
  set -euo pipefail
  umask 077
  unset PGHOSTADDR PGSERVICE PGSERVICEFILE PGDATABASE PGHOST PGPORT PGUSER PGPASSWORD PGOPTIONS
  music_pg=/opt/homebrew/opt/postgresql@15/bin
  music_root=$(mktemp -d /private/tmp/am031-review.XXXXXX)
  "$music_pg/initdb" -D "$music_root/data" -A trust -U app_music_m031 --encoding=UTF8 --locale=C > "$music_root/initdb.log"
  "$music_pg/pg_ctl" -D "$music_root/data" -l "$music_root/postgres.log" -o "-h '' -k $music_root -p 55452" start
  trap '"$music_pg/pg_ctl" -D "$music_root/data" stop -m fast' EXIT
  "$music_pg/createdb" -h "$music_root" -p 55452 -U app_music_m031 app_music_integrity_m031_review_test
  export APP_MUSIC_TEST_DATABASE_URL="postgresql:///app_music_integrity_m031_review_test?host=$music_root&port=55452&user=app_music_m031"
  export SCHEMA="$music_root/test-schema.rb"
  rbenv exec ruby bin/test-isolated db:migrate
  CI=1 rbenv exec ruby bin/test-isolated test
  node --test test/javascript/exercise_audio_test.cjs
)
```

Dentro de um ambiente isolado já preparado e ainda ativo, também é possível executar apenas a integração selecionada:

```sh
rbenv exec ruby bin/test-isolated test test/music_theory \
  test/services/canonical_music_integration_test.rb \
  test/services/reading_note_exercise_generator_test.rb \
  test/services/perception_interval_exercise_generator_test.rb \
  test/services/exercise_integrity_validator_test.rb
CI=1 rbenv exec ruby bin/test-isolated test
```

Não use o banco de desenvolvimento como destino da suíte. O arquivo de configuração de autoload é lido no boot; seu ajuste foi verificado em processo novo, não por reinicialização do servidor do usuário.

Limites/riscos: parser agora estrito, intervalo limitado a 1–15 e qualidades simples, ausência de contexto geral de notação e impossibilidade de provar audição humana por status de reprodução. A aritmética independente é intencional e deve conservar fixtures literais quando evoluir. A afinação alternativa não está integrada aos players. Não há nova migration necessária.

Continuam pendentes os três originais da Arena (`20260320120000`, `20260325120000`, `20260325123000`) e a decisão específica de baseline; esta missão não depende deles. Revisão de função harmônica, política de XP por contexto e escuta real das missões anteriores também não foram resolvidas aqui. A síncopa continua desabilitada.

## I. Próxima etapa

Evoluir por composição: durações racionais, compassos com agrupamentos/acentos, depois acordes/escalas com notas e intervalos escritos. Representar armadura e memória de acidentes antes de generalizar a decisão de glifos. Preservar adaptadores e versionar payloads somente quando houver mudança real de contrato, com testes de atribuições anteriores. Submeter as convenções e fixtures à revisão musical independente. Nenhuma dessas extensões foi iniciada.
