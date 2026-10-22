# Missão 02.3 — Comparador de banco e preservação

Execução local em 19/10/2026, na branch `fix/exercise-integrity`, HEAD `fa82274`. Código e testes entregues para revisão local, sem commit, push, deploy ou início da Missão 03. Não houve alteração funcional musical, migration nova ou escrita no banco de desenvolvimento.

## 1. Causa e correção

O auditor capturava cinco categorias de estado, mas o antigo `compare` recebia apenas `structure`. Assim, dois snapshots com o mesmo catálogo e registros diferentes retornavam sucesso. Isso servia para comparação estrutural, mas não comprovava preservação integral.

Os testes de regressão foram escritos antes da implementação. Uma reprodução adicional usando a cópia inicial do script e dois snapshots com apenas o fingerprint de `users` diferente confirmou: comando antigo retornou **0**, sem diferenças; `compare-full` corrigido retornou **1**, diagnosticando `records.users`. Evidência privada: `original-defect-proof.json`.

Foi extraído um comparador puro, sem Rails ou conexão PostgreSQL. A captura existente continua somente leitura. A comparação integral cobre literalmente estrutura, histórico, registros, FKs e sequências; não normaliza SQL nem elimina diferenças de metadata para obter igualdade.

## 2. Interface e validação

| Comando | Categorias comparadas |
| --- | --- |
| `compare-structure EXPECTED.json ACTUAL.json` | `structure` |
| `compare-full EXPECTED.json ACTUAL.json` | `structure`, `migrations`, `records`, `foreign_keys`, `sequence_state` |
| `compare EXPECTED.json ACTUAL.json` | Alias estrutural com aviso explícito em stderr |

Prefixo para todos: `bundle exec ruby script/migration_reconciliation.rb`. Códigos: **0** igualdade no escopo solicitado, **1** divergência, **2** argumentos/arquivo/JSON/snapshot inválido. A saída JSON declara escopo, categorias e diferenças identificadas por categoria, objeto e estado (`missing`, `extra`, `changed`).

Ambos os escopos exigem snapshots completos, com tipos e campos internos conhecidos. Verificam cobertura de tabelas/registros, sequências/estados e constraints/FKs. Rejeitam chaves JSON duplicadas, versões duplicadas, FKs duplicadas, campos ausentes e campos desconhecidos. Apenas a ordem dos arrays de versões e FKs é irrelevante; seus valores são preservados.

A identidade da conexão é validada e excluída da igualdade, com `identity_compared: false`, permitindo comparar clones com nomes/diretórios diferentes. Os registros de `ar_internal_metadata` permanecem incluídos. O resumo `referential_integrity.healthy` distingue igualdade de saúde: dois estados com o mesmo órfão podem ser iguais e continuar inválidos do ponto de vista referencial.

A captura também foi fechada contra evidência parcial: `row_security = off` faz consultas filtradas por RLS falharem, sem conceder privilégios. FKs `MATCH FULL` ou com destino fora de `public` são recusadas explicitamente, pois a contagem atual suporta `MATCH SIMPLE` dentro de `public`. O snapshot capturado passa pela mesma validação antes de ser emitido.

## 3. Arquivos desta missão

| Arquivo | Alteração e motivo |
| --- | --- |
| `lib/migration_snapshot_comparison.rb` | Novo comparador/validador puro, com os dois escopos e diagnósticos. |
| `script/migration_reconciliation.rb` | CLI explícita, alias com aviso, códigos de saída e captura sem resultados parciais silenciosos. |
| `test/services/migration_reconciliation_test.rb` | Adaptação da regressão estrutural à API explícita; demais proteções existentes mantidas. |
| `test/services/migration_comparison_test.rb` | 21 novos testes independentes de fixtures e da CLI, cobrindo A–F e entradas corrompidas. |
| `test/services/migration_capture_safety_test.rb` | Três novos testes reais PostgreSQL para RLS, FK entre schemas e `MATCH FULL`. |
| `docs/auditor-banco.md` | Guia operacional com escopos, comandos, validação, limites e códigos de saída. |
| `docs/missao-02-2-migrations-resultados.md` | Exemplo atualizado para escopo estrutural e esclarecimento sobre a evidência histórica de preservação. |
| `docs/missao-02-3-comparador-resultados.md` | Este relatório. |

Não houve atualização de dependências. A rejeição de chaves JSON duplicadas foi verificada com `json 2.19.1`, já fixado no bundle, usando a opção do parser `allow_duplicate_key: false`.

## 4. Seis cenários de regressão

| Cenário | Estrutural | Integral | Resultado |
| --- | --- | --- | --- |
| A — mesmo catálogo, contagem ou fingerprint diferente | Igual, código 0 | Diferente, código 1; categoria `records` | Aprovado |
| B — mesmo catálogo, versões diferentes | Igual, código 0 | Diferente, código 1; categoria `migrations` | Aprovado |
| C — sequência com `last_value` ou `is_called` diferente | Igual, código 0 | Diferente, código 1; categoria `sequence_state` | Aprovado |
| D — referências órfãs diferentes | Igual, código 0 | Diferente, código 1; categoria `foreign_keys` | Aprovado |
| E — estados integralmente iguais | Igual, código 0 | Igual, código 0 | Aprovado |
| F — snapshot incompleto, tipos inválidos ou duplicatas | Recusado, código 2 | Recusado, código 2 | Aprovado |

Os testes adicionais verificam diagnóstico estrutural, aviso do alias, identidade de clones, metadata interna, arrays reordenados, versões antigas em formato decimal, arquivos/JSON inválidos e integridade não saudável mesmo quando os estados são iguais.

## 5. Ambiente e testes executados

Ruby **3.3.5** via rbenv, Bundler **2.6.8**, Rails **7.1.6**, PostgreSQL **15.19**; `bundle check` satisfeito. Nenhum override de conexão estava presente na abertura. Testes exclusivamente em cluster privado de socket Unix, sem TCP, separado do PostgreSQL de desenvolvimento; o guard confirmou nome, socket, diretório e `RAILS_ENV=test`. `SCHEMA` apontou para evidências temporárias, preservando `db/schema.rb`.

| Execução | Resultado observado |
| --- | --- |
| Comparador, captura, recuperação e segurança direcionados | **37 testes, 760 asserções**, zero falhas/erros/skips, seed `53701` |
| `bin/test-isolated test` em banco reconstruído pelas oito migrations | **126 testes, 2.660 asserções**, zero falhas/erros/skips, seed `652` |
| Mesma suíte em banco novo carregado por schema | **126 testes, 2.660 asserções**, zero falhas/erros/skips, seed `47332` |
| `node --test test/javascript/exercise_audio_test.cjs` | **12 testes aprovados**, zero falhas |
| `git diff --check` | Aprovado |

São **24 testes Rails novos** sobre os 102 anteriores; as duas execuções completas não representam 252 cenários distintos. As suítes incluem recuperação/backfill, proteção do runner, corpus musical, integração HTTP e concorrência da pontuação. A revisão adicional de código não identificou bloqueante no escopo atual; ela não substitui as execuções acima.

## 6. Reconstruções, backup e diferenças reais

Cluster temporário `/private/tmp/am023-suhs7w8p`, porta **55450**, role `app_music_m023`, UTF-8, diretórios privados e TCP desabilitado. Evidências em `/private/tmp/appmusic-m023-fygvmxaj`. Antes de cada restauração foram conferidos nome do banco, diretório do servidor e ausência de tabelas em `public`.

Backup utilizado: `/private/tmp/appmusic-m022-validation-sx8ka978/development-current.dump`, **81.973 bytes**, formato custom PostgreSQL 15, proveniência de desenvolvimento local confirmada pelo material da Missão 02.2. SHA-256 conferido:

```text
e060117cff54eac40bd9ba3c4e0e007ca1aa23afdd4908f99f2c629b7dcbd098
```

Foi lido integralmente com `pg_restore --file=/dev/null` e restaurado duas vezes em bancos vazios, usando `--exit-on-error --no-owner --no-privileges`. Não foram usados `--clean`, drop ou alteração dos dados originais. As duas cópias conservaram `ar_internal_metadata.environment = development`; a captura autorizou explicitamente essa metadata depois de verificar o destino isolado, sem renomeá-la para `test`.

| Comparação | Resultado e interpretação |
| --- | --- |
| Desenvolvimento atual × `app_music_m023_migrations_test`, escopo estrutural | Código **1**, **89 diferenças**: 88 entradas ausentes ligadas à Arena + CHECK textual conhecido. As oito migrations foram aplicadas do zero com sucesso. |
| Desenvolvimento atual × `app_music_m023_schema_test`, escopo estrutural | Código **1**, somente **1 diferença textual de CHECK**; nenhuma estrutura ausente. |
| Referência histórica associada ao backup × `app_music_m023_restore_a_test`, escopo integral | Código **1**, somente **1 diferença textual de CHECK**; registros, onze versões, FKs e sequências iguais. |
| Restore A × `app_music_m023_restore_b_test`, escopo integral | Código **0**, **nenhuma diferença** nas cinco categorias, identidades distintas explicitamente excluídas, zero órfãos. |
| Desenvolvimento atual × restore A, escopo integral | Código **1**, **7 diferenças reais**: CHECK + três tabelas de registros + três estados de sequências. Isso não foi apresentado como preservação integral. |

O desenvolvimento atual possui **27 atribuições, 13 tentativas e 552 atividades**; o backup histórico possui **25, 10 e 551**, respectivamente. Não se espera que esse backup anterior seja idêntico ao estado atual. A referência histórica e as duas restaurações permitem distinguir divergência de origem de falha de restauração.

O CHECK `exercise_assignments.exercise_assignment_area` permanece com a diferença de casts documentada na Missão 02.2: conversão do array `varchar` para `text[]` versus conversão dos elementos para `text`. O comparador conserva esse diagnóstico; a equivalência dos dez casos anteriormente ensaiados não foi usada para suprimir a diferença ou retornar código 0.

Probes adicionais alteraram somente o restore B: um valor em `study_activities`, uma versão injetada e o estado de uma sequência. Em todos, estrutura permaneceu igual e integral detectou a categoria correta; uma versão real também modifica o fingerprint de `schema_migrations`. Os valores foram repostos em blocos de garantia. A comparação integral final A × B voltou a ser igual (`probes-restored-full.json`).

Os arquivos `compare-*.json`, `full-historical-backup-reference-restore.json`, `real-probes.json`, `original-defect-proof.json` e os logs Rails estão na pasta privada de evidências. Snapshots e dumps completos não foram adicionados ao Git. `/private/tmp` é temporário, não armazenamento permanente: uma cópia durável privada do backup continua a cargo do responsável, fora do repositório.

## 7. Preservação e limites

O banco local foi consultado por transações `REPEATABLE READ READ ONLY`, com verificação explícita de `app_music_development`, metadata `development`, socket local e data directory `/opt/homebrew/var/postgresql@15`. A captura final e a inicial foram comparadas com **`compare-full`**, retornando **0**, sem diferenças de estrutura, histórico, contagens/fingerprints, FKs ou sequências. Resumo: zero órfãos antes e depois. Evidência: `development-preservation-full.json`.

O sandbox inicialmente bloqueou o socket na captura final; o mesmo comando somente leitura foi executado após autorização do ambiente, sem substituir a conexão ou contornar o guard. Nenhuma migration, seed, correção ou restauração atingiu o desenvolvimento.

O inventário inicial e as cópias de segurança dos 59 arquivos locais preexistentes estão na pasta privada de evidências. As únicas edições desses arquivos nesta missão são o auditor, seu teste estrutural e o esclarecimento no relatório anterior; os demais foram preservados por hash. `db/schema.rb` conserva SHA-256 `6888fb3253ab7852b96279705a076da9d12a89ef2aae9dd836d28af741fc3093`, e todas as migrations permaneceram intactas.

Ao final, a conferência somente leitura dos quatro bancos temporários encontrou zero objetos, schemas ou roles residuais com o prefixo das fixtures de captura (`fixture-cleanup.json`). Somente o cluster `/private/tmp/am023-suhs7w8p` foi parado; seus arquivos e evidências foram conservados. Nenhum arquivo foi staged; alterações anteriores e os cinco arquivos novos desta missão permanecem locais.

Após essa parada, o PostgreSQL de desenvolvimento continuou aceitando conexões em `/tmp:5432` e `http://127.0.0.1:3000/up` respondeu **200**. O servidor Rails existente não foi reiniciado.

O auditor cobre os objetos declarados em `public` e as extensões listadas, não toda a infraestrutura PostgreSQL. Fingerprints MD5 são indicadores de igualdade, não prova criptográfica. Sequências não são congeladas pelo MVCC; é necessário evitar escritas concorrentes ao exigir uma captura coerente. As limitações completas estão no [guia do auditor](auditor-banco.md).

Não houve homologação nova de navegador autenticado ou escuta acústica. Os testes JavaScript e HTTP não substituem esses ensaios. Nenhuma regra pedagógica, modo de treino, XP ou biblioteca de áudio foi alterada nesta missão.

## 8. Verificação local e continuidade

Com Ruby 3.3.5 selecionado, estes comandos comparam os arquivos já capturados sem conectar ao banco:

```sh
bundle exec ruby script/migration_reconciliation.rb compare-full \
  /private/tmp/appmusic-m023-fygvmxaj/development-before.json \
  /private/tmp/appmusic-m023-fygvmxaj/development-after.json

bundle exec ruby script/migration_reconciliation.rb compare-full \
  /private/tmp/appmusic-m023-fygvmxaj/restore_a.json \
  /private/tmp/appmusic-m023-fygvmxaj/restore_b.json

bundle exec ruby script/migration_reconciliation.rb compare-structure \
  /private/tmp/appmusic-m023-fygvmxaj/development-before.json \
  /private/tmp/appmusic-m023-fygvmxaj/schema.json
```

Os dois primeiros devem retornar 0; o terceiro deve retornar 1 com o CHECK descrito. Se o shell usar o Ruby do sistema, prefixe com `rbenv exec`.

Para repetir testes, crie um cluster novo pelo procedimento da seção 8 do [relatório 02.2](missao-02-2-migrations-resultados.md), que define socket privado, `APP_MUSIC_TEST_DATABASE_URL`, `SCHEMA` temporário e aplica migrations antes da suíte. Os testes direcionados podem ser executados nesse ambiente assim:

```sh
bin/test-isolated test test/services/migration_comparison_test.rb \
  test/services/migration_capture_safety_test.rb \
  test/services/migration_reconciliation_test.rb \
  test/services/migration_recovery_test.rb \
  test/services/isolated_test_database_safety_test.rb
```

Permanecem ausentes os três originais da Arena: **20260320120000, 20260325120000 e 20260325123000**. Não foram inventados arquivos nem modificadas as onze versões históricas. A adoção oficial de um baseline continua dependendo de decisão específica.

Recomendação: a Missão 03 pode ser planejada com este comparador e as regressões aprovadas. Antes de alterar estruturas da Arena, resolver a recuperação dos originais ou aprovar o baseline e seu procedimento. Manter as revisões pedagógicas e acústicas pendentes das missões anteriores. A Missão 03 não foi iniciada.
