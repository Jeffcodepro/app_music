# Missão 02 — Integridade do motor de exercícios musicais

Data: 18/10/2026. Branch: `codex/missao-02-integridade`. Base: `fa82274` com alterações locais anteriores preservadas. Não houve commit, deploy ou mudança em banco de desenvolvimento/produção.

## 1. Problemas corrigidos

### Gabarito e estado musical

`ExerciseIntegrityValidator` verifica o exercício antes da atribuição, na recuperação do estado e na correção. Usa aritmética própria para alturas, posições diatônicas, distância intervalar, frequência em 12-TET/A4=440, escala maior e formas de tríades/tétrades. Não utiliza o cálculo de `head_music` para provar esses resultados.

Na leitura, confere posição, clave, pitch natural de referência, acidente explícito e resposta; armaduras têm contagem, ordem e coordenadas verificadas. O formato existente de pitch natural + acidente separado foi mantido nesta missão, sem transformar silenciosamente o currículo ou o renderer. Na harmonia, verifica as notas/oitavas, frequências, qualidade, grau e foco da progressão. A função continua seguindo a tabela editorial existente, sem reivindicar validade universal.

Rótulos de alternativas e do gabarito também precisam corresponder ao catálogo existente. Gabarito inconsistente, frequência divergente, duplicidade de alternativa e payload incompleto são rejeitados.

As três reidratações existentes foram envolvidas por validação, preservando sua implementação e as alterações locais anteriores. O estado de cache é conferido contra a atribuição durável. A fonte para a correção é o snapshot persistido, não o exercício reconstruído a partir de parâmetros do cliente.

### Identidade e respostas

Cada exercício apresentado recebe uma atribuição com UUID público e token de tentativa. Os formulários enviam ambos; a assinatura musical antiga não identifica nem autoriza respostas. O backend confere proprietário, área, expiração, versão, integridade do conteúdo e existência da alternativa.

Assinaturas semânticas foram retiradas dos campos e atributos enviados ao navegador. Os players recebem uma identidade opaca para sincronização. Foram removidos o grau interno do payload de áudio de harmonia e a resposta escrita no nome acessível do SVG de leitura. Pitches, frequências e ataques continuam disponíveis quando necessários para reproduzir o estímulo; isso não é uma solução absoluta contra consulta por DevTools.

Campos como `correct`, `correct_option_id` e `xp_earned` enviados pelo navegador não participam da correção ou do crédito.

### Crédito e idempotência

`ExerciseSubmission` usa `with_lock` sobre a atribuição e uma transação que reúne tentativa, atividade, crédito e renovação do token. O banco possui unicidade para `(exercise_assignment_id, attempt_token)` e para a atividade ligada à atribuição, além de FKs e limites de XP por tentativa.

- Repetir exatamente o mesmo envio devolve resultado idempotente, sem nova tentativa, atividade, crédito ou próxima questão criada pelo replay.
- Reusar o token para outra opção é rejeitado.
- Token inventado, ausente, expirado ou de outra atribuição/usuário não pontua.
- A perda do cache não impede corrigir uma atribuição válida já apresentada.
- A tentativa e o crédito são revertidos juntos se a escrita falhar.

**Decisão de produto registrada:** o primeiro erro válido preserva os 6 XP existentes. Novos erros na mesma atribuição são permitidos como treino, mas não acrescentam XP. O primeiro acerto posterior completa o total de 20 XP: acrescenta 14 se já havia 6; ou concede 20 no primeiro envio correto. Uma única atividade acumula esse total e mantém os 3 minutos estimados existentes. A tentativa registra o incremento efetivo. O teto é por atribuição, não um limite global diário nem uma deduplicação de toda combinação musical já estudada.

### Ritmo

O parser rejeita tokens desconhecidos, vazios, separadores excedentes e entradas vazias. `option_from_signature` devolve `nil` para padrões inválidos ou compassos que não totalizam 16 passos; parsing/eventos diretos levantam erro explícito.

As alternativas devem ter projeções de ataques diferentes. Dividir uma pausa ou reduzir a duração notada sem mudar os ataques não é usado para criar uma distinção supostamente audível em percussão curta. O validador possui um segundo cálculo de ataques/durações, independente do parser do gerador, e confere áudio, métrica 4/4, andamento e parâmetros de reprodução.

**Decisão musical registrada:** para os exercícios atuais de reconhecimento percussivo, a unicidade é conservadora e baseada nos ataques. Não se pressupõe que o envelope permita distinguir com segurança todos os finais/durações escritos. Nenhum compasso, figura ou conteúdo novo foi incluído.

O gerador falha de forma explícita ao esgotar o orçamento de candidatos ou distratores, em vez de retornar o último padrão não aprovado ou continuar em laço ilimitado. A atribuição só é criada após validação; uma falha não publica nem pontua o candidato.

### Áudio

O cálculo `[durationInSeconds, noise.decay].min`, inválido em JavaScript, foi corrigido nos sintetizadores de harmonia e de intervalos, onde o mesmo defeito existia. O envelope verifica valores finitos, duração positiva, limites não negativos e término compatível com o stop. Ataque e release permanecem ordenados mesmo com duração muito curta.

Os três players só liberam respostas após completar a reprodução, e não ao iniciar o agendamento. Falhas invalidam a prontidão, liberam o controle para tentar tocar novamente e exibem aviso neutro. Para as áreas sonoras, o backend recusa um envio sem confirmação `playback_status=ready`, sem registrar erro de conhecimento ou XP.

Essa confirmação é um sinal do fluxo de interface, não prova de que o dispositivo efetivamente emitiu som ou de que o aluno ouviu. A decisão musical e o crédito continuam sendo exclusivos do backend.

## 2. Arquivos modificados nesta missão

Lista calculada contra a cópia do estado inicial, distinguindo alterações desta missão das preexistentes:

- [app/controllers/concerns/playground_integrity.rb](../app/controllers/concerns/playground_integrity.rb)
- [app/controllers/student_hub_controller.rb](../app/controllers/student_hub_controller.rb)
- [app/javascript/controllers/harmony_player_controller.js](../app/javascript/controllers/harmony_player_controller.js)
- [app/javascript/controllers/interval_player_controller.js](../app/javascript/controllers/interval_player_controller.js)
- [app/javascript/controllers/rhythm_player_controller.js](../app/javascript/controllers/rhythm_player_controller.js)
- [app/models/exercise_assignment.rb](../app/models/exercise_assignment.rb)
- [app/models/exercise_attempt.rb](../app/models/exercise_attempt.rb)
- [app/models/study_activity.rb](../app/models/study_activity.rb)
- [app/models/user.rb](../app/models/user.rb)
- [app/services/exercise_integrity_validator.rb](../app/services/exercise_integrity_validator.rb)
- [app/services/exercise_submission.rb](../app/services/exercise_submission.rb)
- [app/services/reading_staff_svg_renderer.rb](../app/services/reading_staff_svg_renderer.rb)
- [app/services/rhythm_exercise_generator.rb](../app/services/rhythm_exercise_generator.rb)
- [app/views/student_hub/_harmony_playground.html.erb](../app/views/student_hub/_harmony_playground.html.erb)
- [app/views/student_hub/_perception_playground.html.erb](../app/views/student_hub/_perception_playground.html.erb)
- [app/views/student_hub/_reading_playground.html.erb](../app/views/student_hub/_reading_playground.html.erb)
- [app/views/student_hub/_rhythm_playground.html.erb](../app/views/student_hub/_rhythm_playground.html.erb)
- [bin/test-isolated](../bin/test-isolated)
- [db/migrate/20261018000000_create_exercise_integrity_records.rb](../db/migrate/20261018000000_create_exercise_integrity_records.rb)
- [db/schema.rb](../db/schema.rb)
- [lib/isolated_test_database.rb](../lib/isolated_test_database.rb)
- [test/controllers/exercise_rehydration_integrity_test.rb](../test/controllers/exercise_rehydration_integrity_test.rb)
- [test/integration/exercise_submission_concurrency_test.rb](../test/integration/exercise_submission_concurrency_test.rb)
- [test/integration/harmony_playground_flow_test.rb](../test/integration/harmony_playground_flow_test.rb)
- [test/integration/playground_answer_integrity_test.rb](../test/integration/playground_answer_integrity_test.rb)
- [test/integration/reading_playground_flow_test.rb](../test/integration/reading_playground_flow_test.rb)
- [test/integration/rhythm_playground_flow_test.rb](../test/integration/rhythm_playground_flow_test.rb)
- [test/javascript/exercise_audio_test.cjs](../test/javascript/exercise_audio_test.cjs)
- [test/services/exercise_integrity_validator_test.rb](../test/services/exercise_integrity_validator_test.rb)
- [test/services/exercise_submission_test.rb](../test/services/exercise_submission_test.rb)
- [test/services/isolated_test_database_safety_test.rb](../test/services/isolated_test_database_safety_test.rb)
- [test/services/rhythm_integrity_test.rb](../test/services/rhythm_integrity_test.rb)
- [test/test_helper.rb](../test/test_helper.rb)
- [docs/missao-02-integridade-resultados.md](../docs/missao-02-integridade-resultados.md) — este relatório.

## 3. Justificativa e preservação

- **Validador separado:** impede que a repetição do cálculo do gerador seja a única evidência de correção; preserva os serviços musicais existentes.
- **Atribuição e tentativa duráveis:** permitem identificar a questão realmente apresentada, continuar após perda de cache e resistir a replay/concorrência.
- **Serviço transacional:** mantém pontuação e registro consistentes sem espalhar crédito por quatro handlers.
- **Concern pequeno:** reúne autorização, vínculo com atribuição e falhas de geração. O restante do `StudentHubController` foi preservado; não houve reescrita geral.
- **Alterações nos formulários:** tornam obrigatórias as identidades novas e retiram detalhes internos que revelavam o gabarito.
- **Parser e orçamento de geração:** bloqueiam dados parcialmente reconhecidos, ambiguidade auditiva e retorno de candidato reprovado.
- **Proteções de áudio:** impedem envio liberado cedo demais e diferenciam indisponibilidade técnica de erro do aluno.
- **Runner isolado:** não herda `DATABASE_URL` para executar testes; verifica nome do banco, socket temporário, diretório real do PostgreSQL e ambiente antes de permitir execução. Recusa URL remota, comandos não previstos e sobrescrita de ambiente por argumentos Rake.

Foi lida a auditoria musical/pedagógica em `docs/auditoria-motor-exercicios-musicais.md` e a técnica em `/private/tmp/app_music_missao_01_auditoria_tecnica_2026-10-17.md`.

A cópia inicial está em `/private/tmp/app_music_missao02_preexisting`, com manifesto SHA-256 e patch das alterações anteriores. Dos nove arquivos locais preexistentes, seis permanecem idênticos byte a byte: stylesheet, gerador de leitura, tela principal de playground, os dois testes de serviços de leitura e a auditoria musical. Três receberam integração adicional: controller, partial de leitura e teste de fluxo de leitura. A lógica de níveis, variedade e retomada da questão anterior foi conservada e seus testes permanecem presentes/passando.

Dois testes de harmonia procuravam textos que já não existiam na view inicial. Foram ajustados para verificar os controles `playBlocked`/`playBroken` e o aviso atual para instrumento melódico, sem alterar os textos da tela.

## 4. Testes executados e resultados

Ambiente: Ruby 3.3.5, Bundler 2.6.8, Rails 7.1.6, `head_music` 12.3.0, PostgreSQL 15 temporário, UTF-8, socket privado em `/private/tmp`, sem listener TCP. Dependências existentes satisfeitas; nenhuma biblioteca instalada ou substituída.

| Verificação | Resultado |
|---|---|
| Regressões sobre cópia inicial de controller/ritmo | 4 testes, 20 asserções, 4 falhas esperadas: leitura com chave incompatível, harmonia com chave incompatível, token rítmico ignorado e alternativas com ataques equivalentes (seed 16). |
| Áudio antes da correção | 2 testes Node falharam: tempo não finito e ausência de rejeição antecipada de duração inválida. |
| Suíte Rails final | **77 testes, 1.650 asserções, 0 falhas, 0 erros, 0 skips**; seed final `9623`. |
| Corpus de validação independente | 250 sementes por área: **1.000 exercícios** verificados dentro da suíte, alternando tríades/tétrades em harmonia. |
| Integração HTTP | Quatro áreas; identidades obrigatórias; opção desconhecida; campos de correção/XP forjados; propriedade; área; expiração; corrupção do snapshot; replay; cache eliminado; falha de áudio neutra. |
| Concorrência | Duas conexões reais enviando simultaneamente o mesmo token: uma tentativa, uma atividade, total 20 XP e um resultado duplicado. |
| Restrições PostgreSQL | Tentativa duplicada e atividade duplicada rejeitadas pelo banco, independentemente do serviço. |
| Atomicidade | Falha de escrita da atividade reverte também a tentativa. |
| Áudio Node final | **9 testes, todos aprovados**: tempos finitos/ordenados, durações curtas/inválidas, envelopes fora dos limites, conclusão de playback e falha neutra nos três players. |
| Segurança do runner | URL de produção/remota e sobrescrita `RAILS_ENV=production` rejeitadas antes de conexão/execução. |
| Sintaxe/whitespace | Sintaxe Ruby dos arquivos alterados verificada e `git diff --check` aprovado. |

A primeira tentativa de iniciar PostgreSQL usou um atalho libpq sem servidor. Em seguida, a primeira instância temporária usou template SQL_ASCII, incompatível com a preparação UTF-8 do Rails. Ela foi encerrada e substituída por um cluster UTF-8 novo; nenhum desses erros envolveu banco existente. As regressões originais foram repetidas sobre as cópias iniciais em processo separado depois de resolver o ambiente. Erros intermediários de teste (import de mock e sintaxe de asserção) foram corrigidos; os números finais acima são da execução completa aprovada.

Logs desta sessão: `/private/tmp/app_music_missao02_all_tests.log` e `/private/tmp/app_music_m02_baseline.log`. O diff exclusivo desta missão está em `/private/tmp/app_music_missao02_own_changes.patch`.

## 5. Pendências e limites

- QA acústico e visual com navegador real, fonte musical e dispositivo físico continua pendente. Node testa agendamento/estado com objetos de Web Audio substitutos; não certifica som, volume, latência ou timbre.
- Confirmar em Chrome/Safari/Firefox, inclusive móvel: flauta de contingência com CDN bloqueada, todos os timbres, pausa/reprodução, mudança de rodada durante áudio, modo blocado/linear, falha de permissão e contexto suspenso.
- A mudança de prontidão de áudio é intencional: durante a reprodução, o aluno aguarda a conclusão para responder.
- A progressão ainda usa contagem de atividades; minutos continuam estimados. Não foram redefinidos currículo, níveis, taxonomia funcional, síncopa/contratempo ou políticas de domínio.
- O formato musical ainda varia por área e acidentes de leitura continuam separados do pitch natural. O snapshot durável e o validador reduzem inconsistência, mas não substituem o contrato canônico completo planejado na Missão 01.
- Função harmônica usa a convenção anterior, não análise editorial de contexto. Revisão pedagógica desses itens continua necessária.
- A auditoria musical preservada contém um lapso no exemplo L-2: F♯ e E♯ não são enarmônicos em 12-TET. Esse trecho não foi usado como fixture; F♯/G♭ e E♯/F são as equivalências relevantes. O documento de auditoria não foi alterado.
- Placares de interface e histórico recente para sorteio continuam em sessão/cache; registros de tentativas e crédito são duráveis. Reinício pode reiniciar o placar visual sem apagar tentativas/XP.
- Não há política de retenção/limpeza das atribuições expiradas, limite diário de crédito ou limite de geração. Uma nova atribuição constitui outro evento de treino; esta missão impede crédito ilimitado por replay/retentativa da mesma atribuição.
- Snapshots permitem reproduzir a questão apresentada; persistência de seed/versão detalhada do gerador e observabilidade de falhas de geração ainda devem evoluir.
- Melhorar acessibilidade de exercícios visuais exige uma alternativa pedagógica equivalente; o novo nome acessível genérico evita entregar a própria resposta, mas não resolve esse projeto pedagógico.
- Não houve implementação de IA, microsserviços, novas figuras/compassos ou migração de biblioteca.

## 6. Banco: desenho, impacto e execução

Migration: `db/migrate/20261018000000_create_exercise_integrity_records.rb`.

- `exercise_assignments`: usuário, UUID público, token corrente, área, versão de regras, payload JSONB, digest, expiração e conclusão.
- `exercise_attempts`: atribuição, token, opção escolhida, resultado e XP incremental.
- `study_activities.exercise_assignment_id`: referência nullable com índice único, preservando todos os registros antigos sem vínculo.
- Índices únicos, FKs e checks de área/XP; a aplicação usa lock transacional sobre a atribuição para serializar a correção.

O desenho usa índices e chaves estrangeiras das [migrations oficiais do Rails 7.1](https://guides.rubyonrails.org/v7.1/active_record_migrations.html). As garantias de concorrência também foram verificadas no PostgreSQL real.

Apenas o banco temporário recebeu a migration. `db/schema.rb` foi atualizado a partir dele. O desenho e a política de crédito foram apresentados antes de executar a migration nova. Não houve backfill, alteração ou exclusão de atividades antigas; nenhuma execução em desenvolvimento/produção.

**Antes de usar este código em outro ambiente:** revisar/aplicar a migration nesse ambiente com o procedimento operacional apropriado. Índice e FK na tabela existente podem bloquear escritas durante aplicação, conforme volume; não foi medida a carga de produção. Não iniciar a versão nova com schema antigo. Não executar rollback depois de começar a usar os registros sem preservar o histórico novo; a reversibilidade estrutural não equivale a rollback sem perda de dados.

A instância temporária desta sessão é encerrada ao concluir a verificação. Seus diretórios permanecem em `/private/tmp`; nenhum serviço PostgreSQL preexistente foi parado.

## 7. Riscos de regressão

1. Páginas/formulários antigos sem os UUIDs novos são recusados com aviso e precisam gerar outra rodada. Estado legado de cache não é promovido a uma atribuição confiável sem uma nova apresentação.
2. O limite de crédito muda o comportamento esperado de retentativas: um erro seguido de acerto totaliza 20 XP e uma atividade, não 26 XP e duas atividades. É uma decisão registrada, com testes.
3. Atribuições geram escritas e validações no GET de uma rodada nova; recuperação/validação também acrescenta consultas. Medir custo antes de escalar geração em massa.
4. O validador foi limitado ao repertório atual. Qualquer expansão posterior precisa atualizar regras, versão e fixtures em conjunto, sem revalidar silenciosamente snapshots antigos sob outra semântica.
5. Algumas alternativas rítmicas anteriormente aceitas são removidas por equivalência auditiva. Falha em encontrar quatro opções válidas agora é explícita e não contabiliza resposta.
6. O runner de testes exige cluster temporário por socket Unix. CI com outro arranjo precisa de adaptação igualmente restritiva, sem liberar URL arbitrária ou ambiente de produção.
7. Playback completo em objetos Node não substitui homologação de navegadores/soundfonts reais.

## 8. Verificação local

No macOS deste workspace, o PostgreSQL completo está em `/opt/homebrew/opt/postgresql@15/bin`; o atalho `initdb` de libpq não contém servidor. Ajustar somente o caminho dos binários se a instalação for diferente.

O procedimento abaixo cria um cluster novo e isolado; não usa bancos existentes:

~~~sh
export APP_MUSIC_PG_BIN=/opt/homebrew/opt/postgresql@15/bin
task_pg_dir=$(mktemp -d /private/tmp/app-music-integrity.XXXXXX)
"$APP_MUSIC_PG_BIN/initdb" -D "$task_pg_dir/data" -A trust -U app_music_m02 --no-locale --encoding=UTF8
"$APP_MUSIC_PG_BIN/pg_ctl" -D "$task_pg_dir/data" -l "$task_pg_dir/server.log" -o "-k $task_pg_dir -h '' -p 55439" start
"$APP_MUSIC_PG_BIN/createdb" -h "$task_pg_dir" -p 55439 -U app_music_m02 app_music_integrity_test
export APP_MUSIC_TEST_DATABASE_URL="postgresql:///app_music_integrity_test?host=$task_pg_dir&port=55439&user=app_music_m02"
bin/test-isolated db:migrate
bin/test-isolated test
node --test test/javascript/exercise_audio_test.cjs
git diff --check
"$APP_MUSIC_PG_BIN/pg_ctl" -D "$task_pg_dir/data" stop -m fast
~~~

Executar os passos em sequência, interrompendo se algum falhar. O runner valida o banco/diretório real antes de executar Rails e força `RAILS_ENV=test`, `RACK_ENV=test`, uma URL explícita, Bundler frozen e um worker. O helper também verifica isolamento antes de fixtures/preparação automática. `bin/rails test` sem essas condições falha de propósito: usar `bin/test-isolated`.

Para uma regressão específica, acrescentar o caminho após `test`; exemplo: `bin/test-isolated test test/integration/exercise_submission_concurrency_test.rb`.

## 9. Recomendações para a Missão 03

1. Homologar os fluxos sonoros em navegador/dispositivo e a alternativa acessível antes de chamar os estímulos de certificados.
2. Aprovar contrato canônico e políticas de equivalência/nível; migrar gradualmente as quatro famílias sem ampliar conteúdo junto.
3. Definir domínio por competência, separando XP/engajamento de evidência de aprendizagem; usar tentativas persistidas como entrada.
4. Versionar convenções editoriais, geradores, seeds e explicações; resolver função harmônica e síncopa com responsável pedagógico.
5. Planejar retenção de atribuições, métricas duráveis de interface, limitação de geração e observabilidade.
6. Preparar estratégia de aplicação da migration em desenvolvimento/homologação e depois em produção, sob autorização própria. Esta missão não realizou essa implantação.
7. Manter IA fora da autoridade de correção; um planejador futuro só poderá selecionar objetivos/tipos sob restrições homologadas.
