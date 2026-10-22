# Missão 02.1 — Integridade dos exercícios

Data: 18/10/2026. Código local para revisão independente. Branch `fix/exercise-integrity`, HEAD `fa82274`. Nenhum commit, push ou deploy.

## A. Resumo e decisões

Foram lidos a missão anexada, o relatório da Missão 02, a auditoria musical existente, a auditoria técnica da Missão 01 e o relatório integral do Hermes fornecido na conversa. Os quatro casos prioritários foram reproduzidos antes das correções. Três foram corrigidos; o modo de síncopa foi bloqueado de forma explícita.

- **Acidentes:** identidade, símbolo, rótulo, tipo de notação, posição e alternativa precisam concordar. Um catálogo estruturado alimenta geração e SVG; o validador rejeita metadados divergentes. Referências literais nos testes cobrem sustenido, bemol, bequadro e os dois acidentes duplos. Nota natural sem acidente continua válida. A grafia natural de referência mais acidente separado foi preservada; não se igualam grafia enarmônica e altura sonora.
- **Intervalos:** direção é calculada pelas alturas, com conferência também da direção diatônica. Modo fixo precisa corresponder a essa direção; misto permite ambas. Rótulos, enunciado e frequências são conferidos. Testes JavaScript observam a ordem das duas notas nos caminhos soundfont e sintetizador, incluindo E4→A3 descendente.
- **Progressões:** índice inteiro dentro da sequência, grau, áudio, enunciado, prompt, contexto “Alvo” e exatamente um destaque visual precisam concordar. `ExercisePresentation` deriva os textos e passos visuais de posição/comprimento, tanto na geração quanto na reidratação. Templates continuam em português; outra língua deverá selecionar templates próprios, mantendo os mesmos fatos estruturados.
- **Ritmo:** além do parser estrito e da unicidade de ataques existentes, uma segunda análise agrupa os tokens por tempo e verifica os critérios de Pulso, Subdivisão e Precisão em todas as alternativas. Nenhum token pode atravessar o agrupamento atual de quatro passos por tempo.

### Decisão pedagógica: síncopa suspensa

Os motivos atuais cabem individualmente em um tempo e usam pausas/ataques deslocados. Não representam sustentação entre tempos por ligadura, e a percussão curta não comprova a duração escrita. A antiga regra “dois tempos começando com pausa” identifica uma característica de contratempo; não basta para afirmar síncopa.

Não foi adotada uma definição universal nem criada uma nova categoria de exercício. `syncopation` foi retirado das opções disponíveis e do sorteio misto. Solicitação explícita pelo gerador falha; link antigo recebe redirecionamento neutro; payload persistido com esse modo é rejeitado antes de pontuar. Pulso, Subdivisão, Precisão e Misto continuam disponíveis. As descrições dos playgrounds foram ajustadas para refletir essa disponibilidade; aulas/trilhas não foram redesenhadas.

Para reabilitar: aprovar uma convenção sobre hierarquia métrica, ataque fraco, sustentação e resolução; representar os dados necessários; assegurar que o estímulo sonoro sustente a distinção; criar referências positivas e negativas revistas por educador musical.

### Função harmônica: fatos e convenção separados

O validador continua calculando notas, grau e qualidade sem HeadMusic. A classificação funcional consulta agora `HarmonicFunctionConvention`, com versão persistida `major-functions-legacy-v1`. Não consulta `HarmonyExerciseGenerator::FUNCTION_BY_DEGREE`; esse nome permanece como alias de compatibilidade para geração.

Foram preservadas as atribuições anteriores: I/III/VI→tônica, II/IV→subdominante, V→dominante, VII→sensível. O enunciado explicita essa convenção. Não se afirma que função contextual seja dedutível universalmente de um acorde isolado. As fixtures literais dos sete graus de Dó maior verificam as grafias objetivas e congelam a política editorial existente; **não substituem aprovação pedagógica**. Um gerador deliberadamente adulterado para classificar I como dominante é rejeitado pelo validador.

`ExerciseAssignment::RULES_VERSION` passou de `integrity-1` para `integrity-2`. Rodadas antigas precisam ser renovadas, sem serem registradas como erro do aluno. Registros e XP anteriores permanecem preservados.

### Runner isolado

`IsolatedTestCommand` aceita uma gramática fechada: migration/status/versão devem ser o único argumento; testes aceitam caminhos existentes dentro de `test/` e flags explicitamente previstas. Tasks extras, atribuições de ambiente, `--environment`, `--require`, separador `--` e caminhos que escapem da pasta são recusados antes da conexão.

O guard aceita diretórios privados fora do antigo prefixo `/private/tmp/app-music-*`. Confere URL de socket local, usuário e porta explícitos, nome dedicado de banco de teste, ausência de parâmetros extras/duplicados, propriedade e permissões privadas do diretório e do data directory, caminhos canônicos sem redirecionamento por symlink, identidade real do banco, diretório real informado pelo PostgreSQL e `listen_addresses` vazio. Variáveis `PG*` herdadas são removidas antes de conectar e iniciar o Rails. Nome de diretório sozinho não comprova isolamento.

## B. Arquivos alterados nesta Missão 02.1

Esta lista compara com o estado local inicial, não apenas com HEAD; os arquivos da Missão 02 continuam locais e misturados no Git.

| Arquivo | Finalidade |
|---|---|
| `app/services/exercise_integrity_validator.rb` | Conferir apresentação, modos, convenção e semântica das alternativas. |
| `app/services/exercise_presentation.rb` (novo) | Catálogo de acidentes e templates derivados de dados estruturados. |
| `app/services/harmonic_function_convention.rb` (novo) | Política editorial explícita e versionada. |
| `app/services/reading_note_exercise_generator.rb` | Derivar catálogo de acidentes da representação estruturada, conservando o restante do trabalho local. |
| `app/services/reading_staff_svg_renderer.rb` | Derivar o glifo do ID do acidente. |
| `app/services/perception_interval_exercise_generator.rb` | Reutilizar o template verificado do enunciado. |
| `app/services/harmony_exercise_generator.rb` | Compartilhar templates estruturados; declarar a convenção funcional. |
| `app/services/rhythm_exercise_generator.rb` | Bloquear síncopa e excluí-la das opções/sorteio. |
| `app/models/exercise_assignment.rb` | Renovar a versão do contrato de validação. |
| `app/controllers/student_hub_controller.rb` | Alinhar reidratação e bloquear seleção antiga de síncopa; alterações pontuais. |
| `app/helpers/platform_helper.rb` | Descrever corretamente a disponibilidade de Rítmica. |
| `app/views/student_hub/_rhythm_playground.html.erb` | Mesma correção de descrição. |
| `bin/test-isolated` | Usar gramática fechada de comandos. |
| `lib/isolated_test_command.rb` (novo) | Validar argumentos antes de acessar o banco. |
| `lib/isolated_test_database.rb` | Verificar isolamento real e permitir outros diretórios privados. |
| `test/services/exercise_presentation_integrity_test.rb` (novo) | Regressões dos quatro problemas, posições, acidentes, modos e rejeição sem crédito. |
| `test/services/harmonic_function_convention_test.rb` (novo) | Referências objetivas e política editorial separada da geração. |
| `test/support/major_harmony_reference.yml` (novo) | Grafias literais dos sete graus de Dó maior. |
| `test/services/exercise_integrity_validator_test.rb` | Completar os casos de referência com o contrato de apresentação. |
| `test/services/exercise_submission_test.rb` | Recusar versão antiga sem atividade ou tentativa. |
| `test/services/isolated_test_database_safety_test.rb` | Comandos permitidos/negados, URLs, diretório falso e servidor com TCP. |
| `test/services/rhythm_exercise_generator_test.rb` | Substituir a expectativa incorreta de síncopa por bloqueio explícito. |
| `test/integration/rhythm_playground_flow_test.rb` | Conferir seleção indisponível e link antigo sem crédito. |
| `test/integration/exercise_submission_concurrency_test.rb` | Corrida entre alternativas diferentes com o mesmo token. |
| `test/javascript/exercise_audio_test.cjs` | Ordem real do agendamento e fallback após rejeição do carregamento. |
| `docs/missao-02-1-integridade-resultados.md` (novo) | Este relatório. |

### Preservação

A branch já estava nomeada `fix/exercise-integrity` na inspeção inicial; não foi necessário renomeá-la nem criar outra. Não havia arquivos staged. Foram copiados os 40 arquivos locais modificados/untracked para `/private/tmp/app_music_missao021_preexisting_dc_j8tcc`, com manifesto SHA-256 e patch. Nenhum deles desapareceu; 25 ficaram idênticos e os outros 15 receberam alterações relacionadas à missão, preservando o trabalho anterior.

`db/schema.rb`, as migrations preexistentes e o relatório da Missão 02 permaneceram idênticos byte a byte. As evidências do navegador e um patch exclusivo desta missão estão em `/private/tmp/app-music-m021-evidence-bepp5plp/`. A captura registra a rodada seguinte, após o acerto em Harmonia; snapshots anteriores registram a rodada respondida e o foco na 4ª posição.

## C. Banco e migrations

Nenhuma migration nova foi necessária nesta missão. A adição anterior de atribuições, tentativas e referência anulável em atividades permanece inalterada.

Antes das operações foi verificada a configuração efetiva: `RAILS_ENV=development`, sem `DATABASE_URL`, banco `app_music_development`, usuário local `local_database_user`, data directory `/opt/homebrew/var/postgresql@15`. A migration `20261018000000` já estava aplicada. A consulta final confirmou ausência de migrations pendentes nos arquivos disponíveis. **Não executei migration em desenvolvimento ou produção nesta missão.**

Foram criados dois clusters PostgreSQL 15, UTF-8, com diretórios privados e somente socket, usando papel exclusivo `app_music_m021`:

| Cluster | Banco / porta | Operações |
|---|---|---|
| `/private/tmp/app-music-m021-k3ze_f2k` | `app_music_integrity_m021_test` / 55441 | Seis migrations, regressões iniciais e suíte. |
| `/private/tmp/review-scratch-hsag8mg_` | `app_music_integrity_scratch_test` / 55442 | Seis migrations e suíte final; comprova outro padrão de diretório. |

Em cada banco vazio foram aplicadas as migrations `20260315221425`, `20260315221434`, `20260315222824`, `20260316103000`, `20260316144932` e `20261018000000`. `SCHEMA` apontou para arquivo dentro do respectivo cluster, evitando sobrescrever o schema do projeto. Os dois servidores temporários foram parados ao concluir; dados e evidências foram conservados para revisão.

No desenvolvimento, foi criada exclusivamente a conta de teste `mission021-review-20261018@example.test` (ID 6), mais seus exercícios/tentativas e quatro atividades, total de 80 XP. Esses registros foram mantidos. Nenhuma conta ou atividade preexistente foi removida ou alterada.

## D. Testes automatizados

Ruby 3.3.5 via rbenv, Bundler 2.6.8, Rails 7.1.6. `bundle check` satisfez as dependências; nenhuma biblioteca foi trocada ou instalada no projeto. Playwright CLI foi executado via npx para o teste funcional.

| Verificação | Resultado observado |
|---|---|
| Regressões antes das correções | **7 testes / 15 asserções / 5 falhas esperadas**, reproduzindo quatro aceitações indevidas e tasks extras no runner. |
| Referência manual durante ampliação | Um fixture construído sem `chord_structure` foi rejeitado; o teste foi completado com esse campo. |
| Suíte Rails final | **95 testes / 1.968 asserções / 0 falhas / 0 erros / 0 skips**, seed `29288`. |
| Corpus dentro da suíte | 250 sementes × quatro áreas: **1.000 exercícios** aceitos, incluindo tríades/tétrades. Misto rítmico utiliza os modos disponíveis. |
| Integração HTTP | Identidades, opções inexistentes, autoria, expiração, áudio não pronto, replay, adulteração e navegação. |
| Concorrência real PostgreSQL | Conexões distintas: replay simultâneo e alternativas conflitantes com um token; unicidade de tentativa e atividade também exercitada. |
| Segurança do runner | Tasks extras e overrides negados antes da conexão; servidor/data directory divergente e TCP recusados; diretórios públicos recusados. |
| Segundo scratch com `PGHOSTADDR`/`PGSERVICE` conflitantes | Migration e suíte passaram no cluster isolado após saneamento dessas variáveis. |
| `node --test test/javascript/exercise_audio_test.cjs` | **12 testes aprovados**, incluindo os nove anteriores. |
| `git diff --check` | Aprovado. |

Comando da suíte final (Ruby selecionado no PATH):

```sh
APP_MUSIC_TEST_DATABASE_URL='postgresql:///app_music_integrity_scratch_test?host=/private/tmp/review-scratch-hsag8mg_&port=55442&user=app_music_m021' \
SCHEMA=/private/tmp/review-scratch-hsag8mg_/schema.rb \
bin/test-isolated test
node --test test/javascript/exercise_audio_test.cjs
```

Os testes que mencionam `db:drop` usam um alvo deliberadamente inválido e comprovam a recusa antes da conexão; nenhuma task destrutiva chegou ao Rails.

## E. Quatro problemas do Hermes

| Corrupção | Resultado atual |
|---|---|
| Acidente com símbolo/rótulo diferente do ID | Rejeitado; o SVG deriva o símbolo do ID. Os cinco acidentes têm referências literais. |
| Alturas descendentes com `direction_mode=ascending` | Rejeitado por cálculo das alturas; todos os modos válidos são exercitados. |
| Enunciado “99ª posição”, prompt ou destaque divergente | Rejeitado. Posições válidas 1–4 e inválidas 0/−1/5/99/string/nil são testadas. |
| Pulso/contratempo marcado como síncopa | Bloqueado independentemente do antigo predicado; não é publicado nem pontuado. |

Os testes tentam tanto emitir novas atribuições quanto enviar payloads já persistidos e corrompidos com checksum recalculado. Nos quatro casos não há tentativa, atividade ou crédito concedido.

## F. Funcionamento local

O navegador integrado informou `Browser is not available: iab`. Foi usada a alternativa Playwright CLI com Chromium em sessão exclusiva, seguindo as skills de navegador e Playwright. Houve login real, acesso ao Dashboard e navegação em `http://localhost:3000`.

| Área | Verificação pela interface | Banco da conta exclusiva |
|---|---|---|
| Leitura | SVG, alternativa errada, feedback, acerto posterior e nova rodada. | Uma atividade, incrementos 6 + 14 = 20 XP. |
| Percepção | Reprodução acionada, resposta correta, feedback e nova rodada. | Uma atividade, 20 XP. |
| Rítmica | Pulso, reprodução com contagem, resposta correta e nova rodada; seletor sem síncopa. | Uma atividade, 20 XP. |
| Harmonia | Progressão em Mi bemol maior; enunciado e alvo na 4ª posição; destaque correspondente; textura vertical, acerto e nova rodada. | Uma atividade, 20 XP. |

O Dashboard após navegação completa exibiu **80 XP**, confirmados por consulta ao PostgreSQL. Foram cinco tentativas: um erro e quatro acertos. Não foram observados erros JavaScript nos playgrounds; ocorreram os avisos existentes de autoplay do AudioContext e Tailwind por CDN. A sessão de navegador foi encerrada; o Rails iniciado nesta missão permanece em `127.0.0.1:3000` (Puma PID 78297).

**Limites:** clicar no player e completar seu fluxo em navegador real não comprova som fisicamente ouvido. Não houve escuta humana, validação em Safari, medição de latência/volume/timbre nem bloqueio real de CDN no navegador. Falha de carregamento e fallback foram comprovados por testes JavaScript simulados. A aparência foi preservada; não houve revisão geral de responsividade.

## G. Pendências e riscos

1. Aprovar convenção e representação de síncopa antes de reabilitar o modo. Trata-se de redução temporária de disponibilidade, deliberada e testada.
2. Revisar a convenção funcional com especialista, especialmente III/VI e a categoria “sensível”; qualquer mudança exige nova versão, referências e decisão pedagógica. Não houve reclassificação silenciosa.
3. XP continua limitado por atribuição, não por conteúdo/dia/contexto. Treino repetido na mesma atribuição não dá crédito ilimitado; outra atribuição continua sendo outro evento. Definir treino/revisão/nivelamento/competição antes de ampliar esses fluxos.
4. `playback_status=ready` é um sinal do navegador e pode ser forjado; não é prova de audição. O backend continua responsável por resposta e crédito.
5. Reabrir uma questão após perder o ponteiro de cache/sessão ainda não recupera automaticamente a última atribuição pendente pelo banco. Formulário válido já apresentado continua corrigível.
6. Progresso por atividades não equivale a domínio musical; lacunas curriculares das auditorias anteriores permanecem fora deste escopo.
7. O schema local preexistente contém tabelas/colunas adicionais e o banco de desenvolvimento registra versões de migrations ausentes em `db/migrate`. Esses dados foram preservados. A suíte isolada valida o caminho reconstruído pelas seis migrations disponíveis, não a reconstrução integral de Arena e outras alterações externas à missão. Conciliar histórico/schema em trabalho separado.
8. O cabeçalho de XP pode manter o valor anterior durante atualização parcial Turbo; navegação completa atualiza o total correto. O registro durável foi conferido. Não foi refatorado o shell da plataforma.
9. Validação textual é estrita para os templates atuais. Mudanças editoriais/traduções precisam atualizar o contrato e considerar renovação de versões. Rodadas `integrity-1` são recusadas sem penalidade e precisam ser renovadas.
10. Completar escuta acústica e casos em navegador/dispositivo real: Chrome/Safari, permissões, CDN bloqueado, troca de instrumento, texturas vertical/linear, duas abas e reinício de processo.

## H. Verificação local e próximos passos

O servidor local já está disponível. Entre com sua conta, abra Prática/Playgrounds e teste os quatro modos disponíveis; para confirmar síncopa, um link com `activity=ritmica&activity_mode=syncopation` deve redirecionar com aviso neutro, sem registrar erro.

Para repetir a suíte em um **novo cluster vazio**, escolha um diretório pai permitido ao seu ambiente. O exemplo usa Homebrew PostgreSQL 15 e porta livre 55445:

```sh
export PATH="$(rbenv prefix)/bin:$PATH"
exercise_pg_bin=/opt/homebrew/opt/postgresql@15/bin
exercise_test_parent=/private/tmp  # pode ser seu scratch privado permitido
exercise_test_root=$(mktemp -d "$exercise_test_parent/review-music.XXXXXX")
exercise_test_root=$(cd "$exercise_test_root" && pwd -P)
"$exercise_pg_bin/initdb" -D "$exercise_test_root/data" -U app_music_test_runner --encoding=UTF8 --locale=C --auth=trust
"$exercise_pg_bin/pg_ctl" -D "$exercise_test_root/data" -l "$exercise_test_root/postgres.log" -o "-h '' -k $exercise_test_root -p 55445" start
"$exercise_pg_bin/createdb" -h "$exercise_test_root" -p 55445 -U app_music_test_runner app_music_integrity_test
export APP_MUSIC_TEST_DATABASE_URL="postgresql:///app_music_integrity_test?host=$exercise_test_root&port=55445&user=app_music_test_runner"
export SCHEMA="$exercise_test_root/schema.rb"
bin/test-isolated db:migrate
bin/test-isolated db:migrate:status
bin/test-isolated test
node --test test/javascript/exercise_audio_test.cjs
"$exercise_pg_bin/pg_ctl" -D "$exercise_test_root/data" stop -m fast
```

O caminho do socket deve caber no limite de sockets Unix da plataforma; não use pastas compartilhadas, data directories por symlink ou um servidor com TCP nesse runner. O exemplo conserva os dados temporários após parar o servidor. Para reiniciar o app, confira novamente a configuração efetiva antes de `RAILS_ENV=development bundle exec rails server -b 127.0.0.1 -p 3000`; não interrompa outro servidor que já ocupe a porta.

Antes da Missão 03: revisar este patch com o Hermes; aprovar as convenções musicais pendentes; concluir os testes acústicos e de duas abas/reinício; conciliar as migrations locais ausentes; definir o alcance de pontuação por contexto. A Missão 03 não foi iniciada.
