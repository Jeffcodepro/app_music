# Auditor de banco do AppMusic

O auditor captura um retrato do catálogo e do estado do PostgreSQL e compara arquivos JSON. A comparação de arquivos funciona offline: não carrega Rails, não abre conexão e não escreve no banco.

Selecione o Ruby do projeto antes de executar os exemplos. Com rbenv, use `rbenv exec bundle exec ruby` no lugar de `bundle exec ruby` se o shell ainda estiver selecionando outro Ruby.

## Escolha do escopo

| Comando | O que compara | Uso adequado |
| --- | --- | --- |
| `compare-structure EXPECTED.json ACTUAL.json` | Somente os objetos de `structure` | Comparar estruturas reconstruídas por migrations e por schema |
| `compare-full EXPECTED.json ACTUAL.json` | `structure`, `migrations`, `records`, `foreign_keys` e `sequence_state` | Verificar preservação antes/depois ou fidelidade de uma restauração |
| `compare EXPECTED.json ACTUAL.json` | Somente estrutura, por compatibilidade | Alias antigo; emite aviso em stderr recomendando `compare-full` para preservação |

Todos informam `scope`, `categories`, `structure_categories`, `identity_compared`, `equal` e `differences` na saída JSON. O alias antigo informa `scope: "structure"`. Igualdade estrutural não comprova preservação dos registros, do histórico ou das sequências.

```sh
bundle exec ruby script/migration_reconciliation.rb compare-structure \
  /caminho/privado/auditoria/migrations.json \
  /caminho/privado/auditoria/schema.json

bundle exec ruby script/migration_reconciliation.rb compare-full \
  /caminho/privado/auditoria/antes.json \
  /caminho/privado/auditoria/restaurado.json
```

`EXPECTED` é a referência; `ACTUAL` é o estado examinado. Objetos ausentes, extras e modificados aparecem como `missing`, `extra` e `changed`. Cada diferença contém `category`, `name`, `status`, `expected` e `actual`. Diferenças estruturais acrescentam `subcategory`, por exemplo `columns` ou `constraints`.

## Categorias cobertas

`structure` contém dez categorias obrigatórias:

| Categoria | Informação capturada |
| --- | --- |
| `tables` | Tabelas comuns/particionadas, persistência e flags de segurança por linha |
| `columns` | Tipo, nulabilidade, default, identidade, geração e collation |
| `indexes` | Definição textual, tabela e flags de validade/prontidão |
| `constraints` | Tipo, definição textual, validação e adiamento |
| `sequences` | Tipo, configuração e propriedade de tabela/coluna |
| `views` | Definição de views e materialized views |
| `triggers` | Definição e estado de triggers não internos |
| `routines` | Definição de funções e procedures |
| `enums` | Rótulos e ordem dos valores |
| `extensions` | Nome e versão das extensões instaladas |

O escopo integral acrescenta:

- `migrations`: versões de `schema_migrations`. A ordem do array não altera o resultado; versões continuam strings decimais, inclusive versões antigas com menos de 14 dígitos.
- `records`: contagem e fingerprint de cada tabela capturada, incluindo `schema_migrations` e `ar_internal_metadata`.
- `foreign_keys`: tabela de origem, destino, constraint e quantidade de referências órfãs. A ordem do array não altera o resultado; a identidade é origem + nome da constraint.
- `sequence_state`: `last_value` e `is_called` de cada sequência.

`identity` registra banco, usuário, diretório de dados, porta, versão do servidor, modo somente leitura, endereço TCP e ambiente Rails. Ela é validada, mas excluída da igualdade, inclusive integral: uma restauração pode usar outro nome e outro cluster. A saída declara `identity_compared: false`. Isso não dispensa conferir a procedência e o destino antes de capturar ou restaurar.

## Validação e códigos de saída

Ambos os escopos exigem snapshots completos. Mesmo `compare-structure` recusa um arquivo sem registros, migrations, integridade referencial ou estado de sequências. Duas entradas igualmente truncadas não são consideradas válidas.

A validação verifica campos obrigatórios, tipos, categorias conhecidas e cobertura: cada tabela precisa de `records`, cada sequência precisa de `sequence_state` e cada constraint FK precisa de uma entrada correspondente. Campos internos ausentes ou desconhecidos, chaves JSON duplicadas, versões de migration duplicadas e FKs duplicadas são rejeitados. Uma categoria vazia válida é representada pelo objeto ou array vazio apropriado, sem omitir a categoria.

| Código | Resultado dos comandos de comparação |
| --- | --- |
| `0` | Snapshots válidos e iguais no escopo solicitado |
| `1` | Snapshots válidos com diferenças no escopo solicitado |
| `2` | Argumentos, arquivo, JSON ou snapshot inválido/incompleto |

Erros e o aviso do alias ficam em stderr. Uma falha de leitura/validação não produz aprovação de igualdade. Não trate qualquer código diferente de `1` como sucesso.

O comparador não normaliza definições SQL. Por exemplo, diferenças textuais em `CHECK`, casts ou parênteses aparecem no diagnóstico mesmo quando uma análise posterior demonstrar equivalência semântica. Preserve o diagnóstico e registre a interpretação específica; não remova diferenças por substituições genéricas.

## Igualdade e integridade referencial

O resultado integral inclui um resumo separado:

```json
{
  "referential_integrity": {
    "expected_orphans": 1,
    "actual_orphans": 1,
    "healthy": false
  }
}
```

Esse exemplo pode coexistir com `equal: true`: o mesmo problema foi preservado nos dois snapshots. Igualdade de estados não significa banco saudável. Examine `healthy` e as contagens; a soma é por constraint, podendo contar a mesma linha em mais de uma FK.

Não ignore o fingerprint de `ar_internal_metadata`. Alterar o ambiente Rails ou outro metadado entre captura e restauração é uma diferença integral real. A exclusão de `identity` não exclui registros dessa tabela.

## Captura e segurança operacional

Os comandos de captura abrem transação `REPEATABLE READ READ ONLY`, validam a identidade e o ambiente Rails, aplicam limites de duração/espera e terminam com rollback. Não executam migrations. A comparação posterior usa apenas os JSONs.

```sh
bundle exec ruby script/migration_reconciliation.rb snapshot-development \
  > /caminho/privado/auditoria/desenvolvimento.json

bundle exec ruby script/migration_reconciliation.rb snapshot-test \
  > /caminho/privado/auditoria/teste.json
```

Crie previamente o diretório privado escolhido e restrinja suas permissões. O primeiro comando atende ao alvo local específico: socket `/tmp`, porta `5432`, banco `app_music_development`, usuário do sistema, ambiente Rails `development` e data directory `/opt/homebrew/var/postgresql@15`. Não é um comando genérico para destinos arbitrários. O segundo exige `APP_MUSIC_TEST_DATABASE_URL` aceito pelo guard de isolamento do projeto e ambiente Rails `test` já registrado no banco.

Uma restauração fiel de desenvolvimento conserva `ar_internal_metadata.environment = development`. Nesse caso, `snapshot-test` deve recusar a captura. Para auditar esse clone, use uma captura com `expected_environment: "development"` explicitamente configurado, depois de comprovar o cluster temporário e a identidade do destino. Não altere metadados do clone para contornar a validação ou obter igualdade artificial.

A captura define `row_security = off`: isso não concede acesso nem contorna políticas RLS. Se a consulta seria filtrada por segurança por linha para o usuário conectado, ela deve falhar em vez de emitir um fingerprint parcial. Falhas de permissão, timeout ou captura incompleta não comprovam preservação.

A contagem de órfãos suporta FKs `MATCH SIMPLE` com origem e destino em `public`. A captura recusa `MATCH FULL` e referências cujo destino está em outro schema; não tenta aproximar essas regras.

## Reconstruções e histórico de migrations

Use comparação estrutural entre um banco construído pelas oito migrations disponíveis e outro construído pelo schema. Os caminhos têm origens diferentes; não se espera igualdade integral de registros internos e histórico.

O histórico local possui onze versões aplicadas. Três migrations originais da Arena continuam ausentes. Um baseline de schema não recupera esses arquivos nem sua proveniência. Sua adoção oficial depende de decisão específica; não invente migrations nem exclua registros históricos para fazer os números coincidirem.

Use comparação integral entre uma referência e sua restauração, ou entre estados antes/depois de uma operação que deveria preservar tudo o que o auditor cobre. Mantenha `ar_internal_metadata`, versões e sequências intactos quando a finalidade for verificar uma restauração fiel. Diferenças devem ser explicadas, não ocultadas para alcançar código `0`.

## Limites e armazenamento

- A cobertura principal é o schema `public`, além da lista de extensões. Não é um inventário de todo o cluster: outros schemas, roles, privilégios, dados de materialized views, large objects e configurações externas não estão integralmente cobertos.
- O fingerprint é um agregado MD5 das representações JSON das linhas, ordenado por hash, junto da contagem. Não é prova criptográfica nem comparação byte a byte de um dump. Colisões são possíveis; diferenças de representação/versão do PostgreSQL também podem produzir diferenças textuais.
- Sequências não seguem o snapshot MVCC dos registros. Capture com o banco sem escritas concorrentes se precisar de um retrato coerente entre linhas e sequências. `REPEATABLE READ` não congela `nextval` em outras conexões.
- O JSON guarda hashes e contagens em vez do conteúdo das linhas, mas ainda revela nomes de objetos, identidade e outros metadados. Não o trate como anonimização garantida.
- Snapshot não substitui backup. Dumps com dados pessoais devem permanecer fora do Git, em armazenamento privado com acesso restrito. Verifique integridade, compatibilidade PostgreSQL e restauração em destino isolado antes de confiar em um backup.
- `/private/tmp` serve para trabalho temporário; não pode ser o único armazenamento permanente de backups. Guarde uma cópia durável fora do repositório e registre sua localização por um mecanismo privado.

Nunca modifique `app_music_development` para eliminar uma divergência de comparação. Esta ferramenta relata diferenças; a eventual correção do banco exige uma tarefa e um plano próprios.
