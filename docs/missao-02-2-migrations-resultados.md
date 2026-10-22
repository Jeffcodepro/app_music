# Missão 02.2 — Recuperação de migrations e consistência local

Data: 18/10/2026. Branch mantida: `fix/exercise-integrity`; HEAD `fa82274`. Código e resultados locais para revisão, sem commit, push, deploy ou início da Missão 03.

## 1. Resultado

**Duas das cinco migrations originais foram recuperadas integralmente e restauradas com os timestamps originais.** A origem é o histórico local de ferramentas de 25/03/2026: patches com confirmação de aplicação, conferidos contra leituras completas posteriores dos mesmos arquivos. Não foram reconstruídas por dedução do schema.

As três versões da Arena continuam sem fonte Ruby completa localizada. O schema existente reproduz a estrutura atual num banco vazio isolado; sua adoção como baseline oficial permanece **proposta para decisão**, não mudança aplicada ao histórico do desenvolvimento.

Nenhuma migration ou escrita de dados foi executada no desenvolvimento. Nenhuma versão foi removida de `schema_migrations`. O banco local permaneceu idêntico na auditoria antes/depois. Os 52 arquivos preservados no início do trabalho permaneceram idênticos, incluindo `db/schema.rb`, código de produto e todas as alterações das missões anteriores.

## 2. Origem de cada versão

### Arquivos recuperados

Fonte comum, com `cwd` original apontando para este projeto:

`private-session-reference-omitted`

| Versão / arquivo restaurado | Prova de origem | Operações e dependências |
|---|---|---|
| `20260325101500_add_performance_fields_to_study_activities.rb` | Patch na linha 93, sucesso na 95; leitura completa do arquivo na 205. Os dois conteúdos coincidem. | `change`: acrescenta `correct` boolean anulável e `source` string não anulável, default `legacy`; índices usuário/origem/data e usuário/área/data. Depende de `study_activities` de `20260316103000`. |
| `20260325114000_create_playground_attempts.rb` | Patch na linha 267, sucesso na 269; patch repetido idêntico nas linhas 277/279; leitura completa na 426. Conteúdos coincidem. | `up`: cria tabela com referência/FK para usuários, atividade, área, correção, datas, tempo de resposta e metadata JSONB; três índices compostos mais índice da referência. Faz backfill seletivo de atividades `source='playground'`, correção conhecida e uma das quatro áreas. Depende de usuários e dos campos da versão anterior. `down` original remove a tabela; **não foi executado**. |

Conteúdo completo: os próprios arquivos restaurados em `db/migrate`. Não foram acrescentados condicionais, renomeadas classes ou modificadas as operações originais. SHA-256:

```text
20260325101500: 959e064992a66305fcffe4b56fa00ede7ca4f7ec1496ad1d209d7f6b179a9b89
20260325114000: 03179fcad6aa1058d5e4e620b9932770ddd74b977259b3980575db43eb99a39d
```

As colunas, defaults, nulabilidade, índices e FK resultantes coincidem com o catálogo atual. O backfill foi exercitado com registros sintéticos elegíveis e não elegíveis, preservando os registros de origem, respostas erradas, datas e metadata. A versão já aplicada do desenvolvimento não foi reaplicada.

### Versões sem arquivo recuperado

| Versão | Evidência existente em `log/development.log` | Limite |
|---|---|---|
| `20260320120000` | `CreateArenaCore`, linha 49037; criação das quatro tabelas Arena e índices, registro da versão e COMMIT. | Não há Ruby completo. Depende de usuários; salas antecedem participantes/perguntas, que antecedem respostas. |
| `20260325120000` | `CreateArenaCore`, linhas 132009 e 132021 com tentativa/ROLLBACK; linha 132034 registra a versão com COMMIT, sem DDL naquele trecho. | Não é possível inferir os condicionais nem por que a execução final não recriou as tabelas. Não foi inventado um arquivo vazio para ocultar a lacuna. |
| `20260325123000` | `AddVisibilityToArenaRooms`, linha 132190; acrescenta `visibility`, string não anulável, default `private`, com COMMIT. | SQL e nome de classe não recuperam o Ruby original ou seu comportamento de reversão. Depende de `arena_rooms`. |

Os logs também confirmam as execuções das duas versões recuperadas nas linhas 144364 e 162070. Os fragmentos DDL em `docs/missao-02-2-migrations-evidencias.json` são evidência parcial, não migrations substitutivas.

### Abrangência da busca

- Histórico, branches, referências remotas disponíveis, reflogs e objetos Git: 619 objetos inspecionados, incluindo os inalcançáveis. Nenhuma definição original das quatro classes procuradas foi encontrada no Git; os matches dos timestamps eram documentos de auditoria. Não houve fetch, checkout ou consulta ao GitHub.
- Busca por nomes dos cinco arquivos em código local, Desktop, Documents, Downloads e cópias privadas de `/private/tmp`: 312.185 arquivos examinados, excluindo dependências, diretórios PostgreSQL, logs e outros diretórios sem interesse. Nenhum arquivo ou arquivo compactado relacionado com os nomes procurados foi localizado.
- Histórico local de Code, Cursor e Antigravity: nenhuma definição Ruby de `CreateArenaCore` ou `AddVisibilityToArenaRooms` encontrada.
- Histórico local de ferramentas: os dois originais foram encontrados na sessão de março acima. Os outros matches correspondiam a auditorias posteriores, não a fontes originais.

Isso não equivale a afirmar que nenhuma cópia possa existir em outro computador, serviço ou backup inacessível. Não houve busca irrestrita de conteúdo pessoal no computador.

## 3. Banco de desenvolvimento e estruturas adicionais

Identidade verificada por conexão explícita de socket e transação somente leitura:

- `app_music_development`, metadata Rails `development`, PostgreSQL 15.19 (Homebrew).
- Socket `/tmp`, porta 5432, data directory `/opt/homebrew/var/postgresql@15`; conexão sem endereço TCP.
- Configuração efetiva do Rails confirmada separadamente: ambiente `development`, adapter PostgreSQL, banco local esperado e ausência de override `DATABASE_URL`.
- Onze versões históricas registradas. A restauração dos arquivos não exige reaplicar as duas versões já registradas.

Catálogo `public`: **14 tabelas, 144 colunas, 44 índices, 29 constraints, 12 sequências e 13 FKs**, sem órfãos. Não foram encontrados views, triggers de usuário, rotinas ou enums em `public`; extensão `plpgsql`.

Após a recuperação, `playground_attempts`, os campos `correct`/`source` e os dois índices adicionais de `study_activities` passam a ser explicados pelos arquivos disponíveis.

Continuam sem reconstrução por arquivos de migration disponíveis: **`arena_rooms`, `arena_participants`, `arena_round_questions`, `arena_responses`**, incluindo `visibility`, índices, sequências e relacionamentos. Há suporte histórico nos logs para essas estruturas; sua ausência no diretório não prova criação manual. Não é possível excluir alterações manuais intermediárias apenas a partir desse material.

## 4. Reconstruções comparadas

Cluster exclusivo `/private/tmp/am022-check-7u4qzx5q`, porta 55448, papel `app_music_m022`, diretório privado, UTF-8 e **TCP desabilitado**. Os cinco bancos abaixo são separados do servidor de desenvolvimento. `SCHEMA` sempre apontou para arquivos privados temporários.

| Banco temporário | Procedimento | Resultado estrutural |
|---|---|---|
| `app_music_m022_migrations_test` | Seis migrations disponíveis antes da recuperação, do zero. | 112 entradas de catálogo ausentes: 5 tabelas, 69 colunas, 21 índices, 12 constraints e 5 sequências. |
| `app_music_m022_schema_test` | Carga experimental do schema em banco vazio, antes da recuperação. | Estruturas presentes; uma diferença textual de CHECK. |
| `app_music_m022_restore_test` | Restauração integral do backup, mudando apenas a metadata de ambiente da cópia para `test`. | Dados, sequências e onze versões preservados; mesma diferença textual de CHECK. |
| `app_music_m022_recovered_test` | **Oito migrations disponíveis após recuperar os dois originais**, do zero, seguidas da suíte Rails. | Comparação final: **88 entradas ausentes**, todas da Arena — 4 tabelas, 56 colunas, 14 índices, 10 constraints e 4 sequências — mais uma diferença textual de CHECK. |
| `app_music_m022_full_schema_test` | Carga do schema em outro banco vazio após recuperar os arquivos, seguida da suíte. | Nenhuma estrutura ausente; uma diferença textual de CHECK. |

As contagens incluem componentes das mesmas tabelas; não representam centenas de defeitos independentes. O dump usado na preparação automática dos testes Rails também ficou fora do repositório. Nenhuma carga de schema foi executada sobre desenvolvimento.

### CHECK de área musical

O PostgreSQL original converte o array de `varchar` para `text[]`; a expressão reserializada converte seus elementos para `text`. A comparação conserva a diferença em `exercise_assignments.exercise_assignment_area`, sem normalização genérica que poderia ocultar problemas.

As duas expressões retornaram resultados idênticos para quatro áreas válidas, cinco valores inválidos e `NULL`: **10/10 casos**. Tipos, nulabilidade e validação da constraint permanecem iguais. Não se alterou o CHECK do desenvolvimento para uniformizar texto.

### Metadata de instalações novas

Com os oito arquivos disponíveis, a carga do schema em um banco novo registrou oito versões, enquanto a cópia existente conserva onze. Carregar um snapshot não comprova a execução dos três arquivos ausentes. Essa diferença deve fazer parte da documentação de um eventual baseline, não ser escondida removendo ou inventando entradas históricas.

## 5. Dados existentes, backup e preservação

Pasta privada de evidências: `/private/tmp/appmusic-m022-validation-sx8ka978`.

Backup atual: `development-current.dump`, formato custom, **81.973 bytes**, permissão `0600` dentro de diretório `0700`. SHA-256:

```text
e060117cff54eac40bd9ba3c4e0e007ca1aa23afdd4908f99f2c629b7dcbd098
```

Verificado por leitura completa com `pg_restore --file=/dev/null` e por restauração integral no banco isolado vazio. Backups contêm dados locais e ficam fora do Git. `/private/tmp` não substitui armazenamento privado de backup permanente.

A cópia restaurada preservou contagens/fingerprints e sequências; a única diferença de registros é a metadata de ambiente explicitamente convertida para `test`.

- Arena: 13 salas, 23 participantes, 80 perguntas e 6 respostas preservados.
- Modelos atuais: 6 usuários, 551 atividades, 25 atribuições e 10 tentativas — **592 registros válidos** na cópia, conferidos em transação somente leitura.
- 17 atribuições `integrity-2` tiveram payload e digest conferidos; 8 atribuições `integrity-1` permaneceram históricas, sem conversão ou reavaliação para crédito.
- 542 atividades sem atribuição vinculada foram mantidas, respeitando a associação opcional existente.
- `playground_attempts` está vazio no desenvolvimento; estrutura e FK foram preservadas.

No clone, `db:migrate` não executou DDL nem repetiu backfill. `db:migrate:status` passou a mostrar os dois nomes recuperados como `up`; permanecem três `NO FILE`. As onze entradas históricas foram mantidas. No desenvolvimento, uma consulta final somente leitura confirmou oito arquivos disponíveis, onze versões registradas e **nenhuma migration pendente**.

Uma segunda auditoria confirmou igualdade completa entre os snapshots anterior/posterior do desenvolvimento: catálogo, versões, fingerprints de todos os registros, FKs e sequências. O cluster temporário foi parado ao concluir, conservando seus arquivos. O servidor PostgreSQL local e o Puma existente continuaram ativos; `/up` respondeu 200 após a recuperação.

Na abertura foram observados quatro artefatos de auditoria da Missão 02.2 que depois deixaram de estar disponíveis no diretório. O relatório do Hermes fornecido pelo usuário não indica remoção; não foi possível atribuir a causa. O script/testes de auditoria foram recuperados do conteúdo já lido e os relatórios foram produzidos com os resultados verificados nesta execução. Nenhum arquivo da aplicação foi restaurado por conjectura.

## 6. Arquivos entregues

| Arquivo | Finalidade |
|---|---|
| `db/migrate/20260325101500_add_performance_fields_to_study_activities.rb` | Original recuperado integralmente. |
| `db/migrate/20260325114000_create_playground_attempts.rb` | Original recuperado integralmente, incluindo backfill e reversão histórica. |
| `script/migration_reconciliation.rb` | Auditoria somente leitura de catálogo, registros por fingerprint, sequências, versões e referências; comparação estrutural. |
| `test/services/migration_reconciliation_test.rb` | Cinco regressões de identidade, leitura restrita, recusa de URL/argumentos e detecção de divergências. |
| `test/services/migration_recovery_test.rb` | Hashes dos originais e execução das duas migrations sobre registros sintéticos em schema transacional isolado. |
| `docs/missao-02-2-migrations-evidencias.json` | Proveniência verificável, hashes e comparações resumidas. |
| `docs/missao-02-2-migrations-resultados.md` | Este relatório, limites e propostas. |

`db/schema.rb` permaneceu idêntico, SHA-256 `6888fb3253ab7852b96279705a076da9d12a89ef2aae9dd836d28af741fc3093`. Não foram alterados modelos, controllers, views, regras pedagógicas, pontuação, as seis migrations anteriores ou arquivos da Missão 02.1. A branch não foi trocada e nada foi staged.

## 7. Testes e funcionamento local

Ruby 3.3.5 via rbenv, Bundler 2.6.8, Rails 7.1.6; dependências existentes satisfeitas.

| Verificação executada | Resultado |
|---|---|
| Testes de recuperação antes de restaurar arquivos | 2 testes, 2 falhas esperadas, demonstrando os arquivos ausentes. |
| Regressões do auditor | 5 testes, 22 asserções, sem falhas. |
| Oito migrations em banco vazio | Aplicadas na ordem, sem erro. |
| Suíte Rails final após recuperação, caminho de migrations | **102 testes, 2.005 asserções, 0 falhas/erros/skips**, seed `32012`. |
| Mesma suíte sobre schema completo | **102 testes, 2.005 asserções, 0 falhas/erros/skips**, seed `39999`. Não são 204 cenários distintos. |
| Corpus musical em cada suíte | 1.000 exercícios, além das integrações HTTP, crédito e concorrência existentes. |
| JavaScript de áudio | **12 testes aprovados**, sem falhas. |
| Backfill histórico | Seleção de atividades elegíveis; exclusão de origem/área/correção não elegíveis; registros originais e timestamps preservados. |
| Referências existentes | 13 FKs verificadas, sem órfãos. Seis probes inválidos no clone foram rejeitados; todas as transações revertidas. |
| Registros restaurados | 592 registros válidos e 17 payloads/digests atuais conferidos. |
| `CHECK` reserializado | 10 casos, todos com resultados iguais. |
| Preservação | 52 arquivos iniciais idênticos; banco local idêntico antes/depois; schema intacto. |
| HTTP `localhost:3000` | Home/login 200; Dashboard/Playground sem sessão 302 para login. Puma não reiniciado. |
| `git diff --check` | Aprovado. |

Durante o novo teste de recuperação, a introspecção de FK inicialmente retornou tabelas homônimas dos schemas de teste e `public`; o teste foi corrigido para qualificar explicitamente o schema. A preparação anterior à recuperação também recusou duas migrations pendentes; os ensaios finais usaram bancos novos com os oito arquivos disponíveis. Não se forçou a aplicação das migrations sobre tabelas já existentes.

Não houve novo login em navegador nem escuta humana nesta missão. A verificação HTTP e as integrações cobrem a continuidade local; não representam homologação visual ou acústica.

## 8. Repetição segura

Executar na raiz do projeto com Ruby 3.3.5 selecionado. Este exemplo cria outro cluster privado e dois bancos **novos**, com porta livre 55449, e para somente esse cluster ao sair. Não carrega seeds.

```bash
(
  set -euo pipefail
  umask 077
  export PATH="$(rbenv prefix)/bin:$PATH"
  unset PGHOSTADDR PGSERVICE PGSERVICEFILE PGDATABASE PGHOST PGPORT PGUSER PGPASSWORD PGOPTIONS
  audit_pg=/opt/homebrew/opt/postgresql@15/bin
  audit_root=$(mktemp -d /private/tmp/am022-review.XXXXXX)
  "$audit_pg/initdb" -D "$audit_root/data" -A trust -U app_music_m022 --encoding=UTF8 --locale=C > "$audit_root/initdb.log"
  "$audit_pg/pg_ctl" -D "$audit_root/data" -l "$audit_root/postgres.log" -o "-h '' -k $audit_root -p 55449" start
  trap '"$audit_pg/pg_ctl" -D "$audit_root/data" stop -m fast' EXIT
  "$audit_pg/createdb" -h "$audit_root" -p 55449 -U app_music_m022 app_music_m022_review_test
  export APP_MUSIC_TEST_DATABASE_URL="postgresql:///app_music_m022_review_test?host=$audit_root&port=55449&user=app_music_m022"
  export SCHEMA="$audit_root/migrations-schema.rb"
  bin/test-isolated db:migrate
  bundle exec ruby script/migration_reconciliation.rb snapshot-test > "$audit_root/migrations-before-tests.json"
  bin/test-isolated test
  bundle exec ruby script/migration_reconciliation.rb snapshot-test > "$audit_root/migrations.json"
  "$audit_pg/createdb" -h "$audit_root" -p 55449 -U app_music_m022 app_music_m022_baseline_test
  export APP_MUSIC_TEST_DATABASE_URL="postgresql:///app_music_m022_baseline_test?host=$audit_root&port=55449&user=app_music_m022"
  export SCHEMA="$audit_root/baseline-schema.rb"
  RAILS_ENV=test RACK_ENV=test DATABASE_URL="$APP_MUSIC_TEST_DATABASE_URL" bundle exec ruby <<'RUBY'
require_relative "lib/isolated_test_database"
require_relative "config/environment"
abort "Test environment required" unless Rails.env.test?
connection = ActiveRecord::Base.connection
abort "Empty isolated database required" unless connection.tables.empty?
ActiveRecord::Schema.verbose = false
load Rails.root.join("db/schema.rb")
connection.execute("INSERT INTO ar_internal_metadata (key, value, created_at, updated_at) VALUES ('environment', 'test', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) ON CONFLICT (key) DO UPDATE SET value = 'test'")
RUBY
  bin/test-isolated test
  bundle exec ruby script/migration_reconciliation.rb snapshot-test > "$audit_root/baseline.json"
  node --test test/javascript/exercise_audio_test.cjs
  printf 'Evidências privadas: %s\n' "$audit_root"
)
```

Para auditoria somente leitura do destino local específico desta máquina:

```sh
bundle exec ruby script/migration_reconciliation.rb snapshot-development > /caminho/privado/development.json
bundle exec ruby script/migration_reconciliation.rb compare-structure /caminho/privado/development.json /caminho/privado/baseline.json
```

Comparação retorna 0 para igualdade, 1 para diferenças e 2 para uso inválido. A diferença textual de CHECK continua visível. Snapshots/backup completos devem permanecer privados; o catálogo analisado é `public`, não uma auditoria de todas as roles, permissões ou infraestrutura PostgreSQL.

Atualização da Missão 02.3: o exemplo acima compara **somente estrutura**. Para verificar preservação, use `compare-full ANTES.json DEPOIS.json`; o antigo `compare` permanece estrutural e agora emite aviso. A igualdade completa registrada na seção 5 foi conferida diretamente entre os snapshots, não demonstrada pelo antigo comando estrutural. Os resultados históricos deste relatório foram mantidos. Consulte o [guia do auditor](auditor-banco.md) para categorias e limitações e o [relatório da Missão 02.3](missao-02-3-comparador-resultados.md) para a nova execução.

Os cinco bancos desta execução permanecem em `/private/tmp/am022-check-7u4qzx5q` após parar o cluster, permitindo revisão. Para reiniciar esse cluster de teste: `pg_ctl -D /private/tmp/am022-check-7u4qzx5q/data -l /private/tmp/am022-check-7u4qzx5q/postgres.log -o "-h '' -k /private/tmp/am022-check-7u4qzx5q -p 55448" start`, usando o binário PostgreSQL 15 apropriado. Confirmar novamente a identidade antes de qualquer operação.

## 9. Divergências restantes e decisão proposta

**Opção A — localizar os três originais da Arena em outra cópia.** Preferível se houver acesso à máquina/backup que produziu essas alterações. Conferir conteúdo, dependências e o caso das duas classes `CreateArenaCore` em banco isolado antes de restaurar. A coincidência do nome de classe não autoriza assumir código idêntico.

**Opção B — baseline documentado para instalações novas e vazias.** Alternativa testada estruturalmente, recomendada caso a fonte não apareça. Antes de torná-la estratégia oficial, decidir explicitamente:

1. Qual snapshot e hash representam o baseline aprovado, com a proveniência das onze versões e a identificação das três fontes ausentes.
2. Como instalações novas carregarão esse snapshot e aplicarão migrations futuras, distinguindo essa metadata da execução real de Ruby histórico.
3. Como o CI verificará baseline + migrations futuras, catálogo, FKs e regressões em banco isolado.
4. Como manter os oito arquivos disponíveis e as onze entradas reais do desenvolvimento sem exclusão, renumeração ou falsa reconstrução.
5. Como verificar/guardar backup e ensaiar qualquer intervenção futura numa cópia antes de tocar no banco existente.

Essa opção **não foi aplicada oficialmente**, e o schema não foi carregado no desenvolvimento. Nenhuma migration compensatória ou arquivo retroativo da Arena foi inventado.

## 10. Recomendação para a Missão 03

O motor atual pode continuar evoluindo localmente com as regressões aprovadas. Antes de qualquer alteração que dependa das estruturas históricas da Arena, decidir pela recuperação das três fontes ou pela adoção explícita do baseline. Uma instalação feita apenas com as oito migrations continua incompleta para a Arena.

Esta missão entrega a recuperação verificável possível com os materiais encontrados e um plano reproduzível para o restante. As revisões pedagógicas e acústicas da Missão 02.1 permanecem pendentes; nenhuma funcionalidade da Arena, regra de XP ou currículo foi alterada. A Missão 03 não foi iniciada.
