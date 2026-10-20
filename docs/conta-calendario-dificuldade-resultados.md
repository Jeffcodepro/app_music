# Conta, calendário e dificuldade rítmica — resultados

20/10/2026. Entrega local na branch preexistente `feat/canonical-music-model`, HEAD `16f9d18`. Sem commit, push, deploy ou mudança de branch.

## Comportamento entregue

- Indicadores de XP, respostas e dias de prática no topo do dashboard. Calendário mensal navegável com marcações distintas de acesso e prática, legendas acessíveis e horário de Brasília. Respostas recentes ficam abaixo; os dados são reais e isolados por usuário.
- Botão de navegação com o ícone de painel lateral da referência. Perfil com avatar/nome no rodapé da sidebar, incluindo modo recolhido e drawer móvel. Avatar removido do topo; logout continua por DELETE.
- Minha conta com páginas próprias de visão geral, assinaturas e compras, dados pessoais, notificações e aparência. Dados de acesso reutilizam `/users/edit`, com senha atual e validações do Devise. Certificados não foram incluídos. A edição pessoal conserva a allowlist e não permite alterar plano, e-mail ou senha.
- Cinco novos desenhos SVG de instrumentos, consistentes em tamanho/traço e nos dois temas. Nome textual dos rádios mantido. Configurações e exercício limitados à mesma largura; pautas densas conservam sua rolagem própria.
- Níveis1–4 agora alteram as estruturas geradas em Subdivisão e Precisão. Compasso Misto sorteia dentro do catálogo cumulativo do nível, sem favorecer fórmulas com mais variantes de agrupamento. Recarregar ou errar conserva a rodada; outra questão permite outro sorteio. Os dois Mistos — atividade e compasso — são independentes.

## Decisões musicais e compatibilidade

O perfil novo `level-structure-v1` acrescenta campos ao formato `meter-v1`, sem alterar payloads anteriores. O catálogo continua com32 fórmulas/41 configurações; Misto é uma escolha adicional, não outra fórmula. Detalhes e critérios exatos: [compassos-por-nivel.md](compassos-por-nivel.md).

Nível1: divisões regulares em duas partes. Nível2: três partes e combinações binárias mistas compatíveis com a grade. Nível3: quatro/seis partes e pausas menores. Nível4: combinações longa/curta, ao menos dois motivos distintos e pausa no interior do trecho. Os mínimos são limitados pelas figuras possíveis; não se criam fusas/quiálteras para forçar dificuldade em /16. Subdivisão e Precisão exigem um grupo com densidade correspondente ao nível; Precisão ainda exige dois grupos subdivididos. Pulso conserva uma figura por grupo, pois seu foco é a pulsação.

O validador recalcula essas exigências para todas as opções, incluindo payloads com assinatura recalculada. Uma fixture literal do gerador anterior confirma compatibilidade com o antigo nível1 que permitia semicolcheias. Síncopa permanece bloqueada; não houve mudança de áudio, gabarito, política de XP ou serviços de atribuição/tentativa.

Espaços pequenos são enumerados integralmente, até4.096 combinações. Isso evita o esgotamento aleatório de padrões raros, especialmente em Precisão avançada de2/8. Espaços maiores conservam400 candidatos e falham sem publicar se não houver quatro opções distintas. Limite de24 figuras mantido.

## Banco e datas

Migration **20261020000000_create_daily_visits**: uma tabela nova com `user_id`, `visited_on` e timestamps; FK para usuários e índice único `(user_id, visited_on)`. Nenhuma coluna/tabela antiga foi removida ou transformada. Não guarda IP, URL ou histórico detalhado de navegação. Acesso não concede XP. Exclusão da conta remove esses registros.

O desenho foi apresentado antes da execução. A migration passou nos dois bancos privados de teste. Depois foi aplicada **exclusivamente por `db:migrate:up VERSION=20261020000000` no desenvolvimento local**, com guard verificando Rails development, socket local, banco `app_music_development`, usuário atual e diretório `/opt/homebrew/var/postgresql@15`. Schema anterior preservado no scratch privado. Contagens antes/depois: todas as tabelas preexistentes conservaram suas linhas; somente `schema_migrations` ganhou a nova versão. O dump resultante difere do schema anterior apenas pela versão, tabela, índices e FK novos; `db/schema.rb` foi atualizado com esse delta.

Nenhuma migration histórica adicional foi aplicada. Nenhuma operação em produção/homologação. O servidor existente da porta3000 não foi reiniciado e respondeu200 após a alteração. A divergência histórica de migrations discutida em missões anteriores não foi reaberta nesta tarefa.

Dias de prática atuais usam `ExerciseAttempt.created_at`, convertidos de UTC para Brasília, incluindo tentativas em dias posteriores. Atividades legadas sem atribuição usam `StudyActivity.occurred_on`; atividades atuais não são contadas duas vezes por misturar fontes/fusos. Dias de acesso começam nesta atualização: não foi inventado histórico anterior. Aulas continuam em preparação e não são contadas como assistidas.

Falha na gravação/leitura do diário de acessos é tratada separadamente: não bloqueia as páginas de prática/conta nem cria crédito; o calendário informa indisponibilidade do registro de acessos. Erros do motor não são suprimidos por esse tratamento.

## Arquivos e justificativas

Inventário incremental completo, hashes e diff contra o snapshot inicial: [inventário](../output/playwright/account-rhythm/incremental-inventory.json), [patch](../output/playwright/account-rhythm/incremental.patch). O working tree já tinha mudanças de outras missões; esse inventário não as atribui à entrega atual.

| Conjunto | Arquivos e finalidade |
| --- | --- |
| Conta e navegação | `config/routes.rb`, `platform_controller.rb`, `platform_ui_helper.rb`, `_side_nav`, `_top_nav`, `perfil`, `_account_navigation`, `_account_personal_form`, `dados_pessoais`, `assinaturas`, `notificacoes`, `aparencia` e Devise `registrations/edit`: seções próprias, perfil inferior e edição segura preservada. |
| Dashboard e calendário | `dashboard.html.erb`, `_study_calendar.html.erb`, `StudyCalendar`, `DailyVisit`, callback de `ApplicationController`, associação em `User`, migration e schema: dados reais, fuso explícito, isolamento e idempotência. `config/locales/pt-BR.yml` acrescenta nomes dos meses. |
| Aparência | `_account_calendar.scss` e seu import em `_index.scss`: calendário, conta, perfil inferior e largura comum de treino. `platform_helper.rb`: desenhos próprios dos instrumentos. |
| Motor rítmico | `metrical_rhythm_exercise_generator.rb`, `metrical_rhythm_integrity_validator.rb`, `student_hub_controller.rb`, `platform_ui_helper.rb`, `_rhythm_playground.html.erb`: perfil versionado, validação independente, Misto e preferências preservadas no retorno pelo dashboard. |
| Regressões | Novos testes `account_navigation`, `daily_visit_concurrency`, `study_calendar`, `rhythm_complexity` e fixture `legacy_metrical_rhythm.json`. Ajustes dos testes de navegação/perfil/fluxo métrico e scripts de navegador para a interface atual. |
| Evidências e decisões | Esta documentação, atualização do contrato de compassos e `output/playwright/account-rhythm/`. |

## Verificações executadas

- **Rails:238 testes,10.268 asserções, zero falhas/erros/skips.** Inclui HTTP, autorização, Devise, disponibilidade do registro de acesso, idempotência/concorrência de pontuação já existentes e nova corrida de acessos em duas conexões PostgreSQL: uma linha e zero XP.
- **JavaScript:72 testes aprovados, zero falhas.** Nenhum controller JavaScript da aplicação foi modificado nesta tarefa.
- Matriz cumulativa de níveis/presets/modos com3 seeds;100 seeds no2/8 avançado; corpus anterior de1.230 combinações e demais regressões mantidos. Corrupção literal de Subdivisão nível1 disfarçada de nível4 é rejeitada, mesmo reassinada.
- Calendário: usuário diferente, duplicatas, meses vazios, meses de5/6 semanas, virada de dia em Brasília, tipos/datas de prática e parâmetros inválidos.
- **54 capturas** Chromium:9 cenários × desktop1440/tablet820/mobile360 × claro/escuro. Sem overflow horizontal do documento; configurações e exercício com a mesma largura. Transições de tema foram aguardadas antes das capturas finais.
- Navegador: drawer abre/fecha, perfil inferior navega e libera a página, Escape restaura foco; edição pessoal salva e permanece após reload; senha incorreta recebe422 e não altera e-mail; cinco rodadas em Misto variam de fórmula, reload preserva identidade; modo Sistema acompanha preferência emulada e persiste ao recarregar. Conta fictícia apenas.
- Sintaxe Ruby e `git diff --check` aprovados. Títulos duplicados encontrados na revisão foram corrigidos e conferidos no navegador.

As regressões iniciais demonstraram páginas ausentes, indicadores no fim, ausência de calendário/Misto e inexistência de limites de dificuldade. Logs ficam junto à galeria. Nenhum teste foi executado em desenvolvimento; somente a migration aditiva e verificações de identidade/schema/contagens ocorreram ali.

## Preservação, limites e conferência local

Snapshot inicial: `/private/tmp/appmusic-account-rhythm-baseline-73sn56hk`. Landing, fontes, gabaritos, renderer de clave recém-corrigido, áudio e serviço de pontuação foram preservados. Nenhuma exclusão nova de arquivo. Alterações anteriores modificadas ou untracked permanecem. Não houve instalação de dependências ou integração externa nova.

Pagamentos e lembretes de estudo não têm backend operacional; suas páginas informam isso e não oferecem controles fictícios. Ainda faltam aulas reais e seus eventos de conclusão, revisão pedagógica humana do perfil de dificuldade, escuta em dispositivo e verificação Safari/VoiceOver. O nível escolhido não representa domínio aferido do estudante. Melodia de múltiplas vozes e síncopa não entraram nesta etapa.

Para conferir: recarregar `/app/dashboard`; navegar pelo perfil no rodapé para as seis áreas da conta; em Rítmica → Configurar treino escolher nível1, Compasso Misto e Precisão, depois comparar com nível4 e solicitar novas rodadas. Recarregar não deve trocar a questão. A migration já foi aplicada no desenvolvimento local desta máquina.

Para outra instalação, após verificar o destino local, aplicar a nova migration antes de iniciar Rails. Regressões devem usar o runner isolado e `APP_MUSIC_TEST_DATABASE_URL`/`SCHEMA` privados, conforme as [instruções de isolamento](missao-02-integridade-resultados.md):

```sh
APP_MUSIC_TEST_DATABASE_URL='<URL do PostgreSQL privado descartável>' SCHEMA='<scratch>/schema.rb' CI=1 rbenv exec ruby bin/test-isolated
node --test test/javascript/*.cjs
git diff --check
```

Os scripts `test/browser/account_rhythm*.mjs` exportam funções Playwright para uma página autenticada no servidor isolado3001. Usam dados fictícios e não devem ser executados com conta real. O servidor3001 e o cluster temporário foram encerrados ao terminar. [Galeria de capturas](../output/playwright/account-rhythm/index.html).
