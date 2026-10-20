# UI/UX 02 — inventário anterior às alterações

Inspeção de código e visita autenticada em 19/10/2026, conta sintética no PostgreSQL privado. O inventário inicial do navegador está em `output/playwright/uiux02/before/inventory.json`; cinco capturas registram o estado anterior. Nenhum dado de desenvolvimento foi usado. Branch inicial `feat/canonical-music-model`, HEAD `16f9d18`, 79 arquivos locais preservados em snapshot privado. Não trocar a branch enquanto as missões anteriores aguardam revisão.

## Componentes e problemas compartilhados

**P** = layout `platform`, sidebar/topbar/flash compartilhados; dados dependem de Devise e do usuário autenticado. Todas as páginas P herdavam menu empilhado no mobile (fora dos Playgrounds), busca sem mecanismo, notificação fixa “3”, cabeçalho alto, cores fixas, falta de tema e destaque incompleto de subrotas. A navegação não tinha gaveta, contenção/restauração de foco ou Escape. Prioridade **P0**. Não houve overflow horizontal nas 29 visitas iniciais em 390×844; isso não indica adequação de espaço ou acessibilidade.

**A** = layout `application`, componentes de formulário Simple Form/Bootstrap e flash, dependência visual do Tailwind CDN legado. Sem tema, agrupamento visual consistente ou labels completos nas telas de conta. Prioridade **P1**. Onboarding tem autenticação no controller. Não há papéis nem páginas de professor/admin nas rotas e controllers atuais.

Na tabela, “sem dados” significa que não há modelo/consulta utilizável para a funcionalidade apresentada. Conteúdo editorial estático não é registro de atividade. “Herdados” remete aos problemas detalhados acima. Cada linha identifica finalidade, template, layout/componentes, dados, comportamento e correção.

| Rota GET | Objetivo / template | Layout | Origem e funcionalidade real | Simulação / controles inertes / dependência pendente | Responsividade e acessibilidade | Classe / prioridade |
| --- | --- | --- | --- | --- | --- | --- |
| `/app` | Entrada; redirect | — | Redireciona ao dashboard | Nenhuma | — | Funcional / P2 |
| `/app/dashboard` | Resumo; `platform/dashboard` | P | User, soma de StudyActivity, datas reais | Atividade chamada aula assistida; minutos estimados chamados medidos; ações de retomar aula inexistente; métricas duplicadas | Herdados; excesso vertical | Parcial / P0 |
| `/app/trilhas` | Áreas; `platform/trilhas` | P | STUDY_TRACK_THEMES editorial | Níveis/conteúdos futuros sem catálogo/avaliação | Herdados; cards extensos | Parcial / P1 |
| `/app/trilhas/tema/:tema` | Detalhe; `platform/trilha_tema` | P | Constante com seis temas | Currículo planejado apresentado como progressão disponível | Herdados; descrição extensa | Simulada / P1 |
| `/app/trilhas/:area/:nivel` | Trilha legada; `student_hub/trail_show` | P | Parâmetros da URL | Módulos/checkpoints/próxima aula sem implementação | Herdados; nível sem validação pedagógica | Simulada / P1 |
| `/app/aulas` | Catálogo; `platform/aulas` | P | Constantes/editorial; contagem de atividades | Modos guiado/livre; recomendação por volume sem aulas publicadas | Herdados | Simulada / P0 |
| `/app/aulas/:id` | Aula legada; `student_hub/lesson_show` | P | Arrays artificiais no controller | Player, velocidades, temporadas, A1–A6, duração/progresso; botões sem ação; não existe Lesson/catalogação | Herdados; enorme extensão; botões inertes | Simulada / P0 |
| `/app/pratica` | Escolha de área; `platform/pratica` | P | PLAYGROUND_ACTIVITIES, quatro links reais | Texto dizia que Rítmica não estava pronta | Herdados | Funcional com texto errado / P1 |
| `/app/pratica/resultado` | Resultado; `student_hub/practice_result` | P | Sem consulta | 16 acertos/4 erros e recomendação fixa; precisa consultar ExerciseAttempt do usuário | Herdados | Simulada / P0 |
| `/app/playground?activity=leitura` | Exercício visual; `_reading_playground` | P | Gerador, validator, Assignment, Submission, cache | Nenhuma resposta/XP fictícios; scoreboard é da sessão | Compactação UX01; cores fixas; menu ainda empilhado | Funcional / P0 visual |
| `/app/playground?activity=percepcao` | Intervalos; `_perception_playground` | P | Mesmos serviços + interval-player | Áudio externo com fallback real | UX01; cores fixas | Funcional / P0 visual |
| `/app/playground?activity=ritmica` | Ditado; `_rhythm_playground` | P | Mesmos serviços + rhythm-player | Síncopa bloqueada, manter | UX01; não comprimir figuras/ataques | Funcional / P0 visual |
| `/app/playground?activity=harmonia` | Acordes; `_harmony_playground` | P | Mesmos serviços + harmony-player | Nenhuma simulação funcional | Contexto excessivo; coluna estímulo sobrecarregada; cores fixas | Funcional / P0 visual |
| `/app/nivelamento` | Diagnóstico; `platform/nivelamento` | P | Sem avaliação implementada | “Iniciar” apenas abre trilhas | Herdados; ação enganosa | Não implementada / P1 |
| `/app/carreira` | Carreira; `platform/carreira` | P | Sem domínio de carreira | Níveis/missões/rankings sem regras/dados; link desafios abre Arena | Herdados | Não implementada / P1 |
| `/app/arena` | Ao vivo; `platform/arena` | P | Schema histórico sem controller/modelos de sala em uso | Não há lobby/rodada ao vivo na aplicação atual | Herdados | Não implementada / P1 |
| `/app/perfil` | Conta; `platform/perfil` | P | User, ActiveStorage, PATCH real | Preços/benefícios/gateway sem integração; planos são campo, não cobrança | Labels sem associação; formulário longo; herdados | Parcial / P0 |
| `/app/desafios` | Missões; `student_hub/challenges` | P | Sem dados | Metas/checkpoints sem implementação | Herdados | Simulada / P1 |
| `/app/ranking` | Comparação; `student_hub/ranking` | P | Sem dados | Ligas/temporadas apenas descritas | Herdados | Não implementada / P1 |
| `/app/conquistas` | Medalhas; `student_hub/achievements` | P | Sem dados | Lista de marcos sem avaliação | Herdados | Não implementada / P1 |
| `/app/bolsa-evolucao` | Benefício; `student_hub/scholarship` | P | Sem dados | Faixas/regras comerciais sem especificação | Herdados | Simulada / P1 |
| `/app/assinatura/comparacao` | Planos; `student_hub/plans_compare` | P | Nomes previstos | Benefícios não implementados | Herdados | Simulada / P1 |
| `/app/assinatura/historico` | Cobranças; `student_hub/billing_history` | P | User.plan | Status “ativo” sem cobrança real | Herdados | Simulada / P1 |
| `/onboarding/welcome` | Entrada; `onboarding/welcome` | A | Links reais | Promete acompanhamento/nivelamento inexistente | Sem shell/tema | Parcial / P1 |
| `/onboarding/objective` | Objetivo; `onboarding/objective` | A | Session; PATCH exige objetivo | Persistência limitada à sessão | Falta fieldset/legend; tema | Funcional com limite / P1 |
| `/onboarding/profile` | Preferências; `onboarding/profile` | A | Session; PATCH funcional | Não salva User | Tema; nomenclatura ambígua | Funcional com limite / P1 |
| `/onboarding/result` | Revisão; `onboarding/result` | A | Session objetivo/perfil | Trilha, nível e frequência arbitrários | Tema | Parcial / P1 |
| `/onboarding/plan` | Plano obrigatório; `onboarding/plan` | A | PATCH User.plan validado | Preços/gateway fictícios | Tema; claims indevidos | Parcial / P0 |
| `/users/edit` | Credenciais; `devise/registrations/edit` | A | Devise, senha atual obrigatória | Nenhuma; exclusão é ação destrutiva real, não executar | Inglês, sem estrutura/tema | Funcional / P1 |
| `/users/sign_in` | Entrar; `devise/sessions/new` | A | Devise; OAuth depende de configuração externa | Não validar credenciais de terceiros | Tema; fornecedores só devem aparecer quando configurados | Funcional / P1 |
| `/users/sign_up` | Cadastro; `devise/registrations/new` | A | Devise | OAuth dependente de ambiente | Tema/formulários | Funcional / P1 |
| `/users/password/new`, `/users/password/edit` | Recuperação; `devise/passwords/{new,edit}` | A | Devise/mailer; edit exige token real | Envio depende de mailer; não enviar e-mail real | Inglês; tema | Funcional com dependência / P1 |

Devise não habilita confirmable/lockable; templates de confirmação/desbloqueio não têm rota utilizável e não serão anunciados como páginas visitadas. Callbacks OAuth GET/POST e DELETE de sessão não são páginas de catálogo. POST `/app/playground/answer` permanece sob validação/identidade/XP do backend. PATCH de perfil/plano/onboarding e PUT/PATCH/DELETE de Devise são ações reais que precisam conservar autorização e validação; testes usarão somente contas sintéticas. `/up` e `/` são públicos e não fazem parte da reformulação autenticada.

## Decisões anteriores à implementação

1. App Shell único, gaveta modal até tablet e rail intermediário; sidebar recolhível no desktop. Componentes/tokens SCSS próprios, sem nova dependência.
2. Tema local sistema/claro/escuro, aplicado antes do CSS, sincronizado com Turbo, mudança do sistema e outras abas. SVG com cores explícitas por tokens, sem inverter imagens.
3. Dashboard e histórico usam StudyActivity (XP/dias) e ExerciseAttempt via atribuições do usuário (tentativas/correção). Não apresentar minutos estimados nem inferir aulas ou domínio.
4. Não há catálogo real de aulas. Rotas atuais, inclusive guiado/livre antigas, passam a informar preparação e oferecer prática real. Não excluir registros nem mudar regras pedagógicas. Trilha não avalia nível.
5. Carreira/Arena/avaliação/benefícios/rankings recebem estados honestos. Não criar backend/schema. Conta mantém campos reais; retirar preços e promessas comerciais. Plano continua um campo existente, sem alegar pagamento.
6. Preservar motores, respostas, quatro alternativas, identidade, áudio, compactação e síncopa indisponível. Contexto complementar de Harmonia fica em disclosure sem retirar o enunciado/alvo.
7. Testes Rails somente no cluster privado sem TCP, schemas fora do repositório. Registrar limitações de navegador e escuta. Os screenshots citados no pedido não vieram no anexo textual; utilizar evidências próprias e as capturas UX01 existentes.
