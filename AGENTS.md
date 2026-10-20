# AGENTS.md — AppMusic

Regras para agentes de IA neste repositório. Seguir antes de analisar ou alterar código. Manter a execução limitada ao projeto e à tarefa solicitada.

## Produto e regras de domínio

AppMusic é uma plataforma de ensino musical em Ruby on Rails: aprendizado claro, prática recorrente e evolução motivadora para estudantes e professores. A visão do produto inclui onboarding, nivelamento, trilhas, aulas, exercícios, playgrounds, carreira, gamificação, assinaturas e Arena Musical ao Vivo. **Esses itens são metas de produto, não garantia de que já estejam implementados.** Verificar o código.

- **Nível do estudante ≠ plano de assinatura.** O plano define acesso/volume de recursos, nunca o nível musical ou potencial do aluno.
- Permitir, quando implementado, **começar do zero** ou realizar **nivelamento**, com trilhas recomendadas por área e opção de estudo livre.
- Áreas curriculares: Estruturação/Leitura, Rítmica, Percepção, Harmonia, Apreciação e História da Música; níveis pedagógicos internos 1–4.
- Aulas previstas em modos **guiado** e **livre**, com teoria, exemplos e práticas coerentes.
- Planos previstos: **Primeira Nota** (gratuito), **Pulso**, **Harmonia** e **Maestro**. Não inventar preços, restrições, descontos ou regras comerciais; consultar a especificação vigente.
- A **Bolsa de Evolução** deve reconhecer progresso real; critérios exigem especificação e testes.
- A Arena Musical prevê lobbies com professor/alunos, perguntas visuais ou sonoras, **quatro alternativas**, pontuação e ranking. Regras de tempo, concorrência e pontuação devem ser definidas e testadas antes de implementar.
- Preparar **pt-BR** (mercado inicial: Brasil) e **en-US** (expansão posterior), incluindo interface, conteúdo, mensagens e diferenças comerciais/culturais. Não presumir localização já implementada.
- O produto deve priorizar pedagogia, acessibilidade e aprendizado, não pressionar usuários a pagar ou jogar.

## Fonte de verdade

1. Código, `Gemfile`, rotas, schema, configurações e testes descrevem **o que existe**.
2. Especificação e solicitação atual descrevem **o que se deseja**.
3. Se houver divergência, relatar antes de alterar. Não reestruturar o projeto inteiro para seguir uma visão futura.
4. Não presumir tecnologias ou integrações (pagamento, áudio, websockets, gems etc.) sem verificar.

## Arquitetura e qualidade

- Seguir convenções Rails e a arquitetura existente; priorizar um monólito modular enquanto adequado.
- Aplicar **SOLID, DRY, KISS, YAGNI e Clean Architecture com pragmatismo**. Não criar camadas, interfaces, repositories ou services desnecessários para CRUD simples.
- Controllers focados em HTTP/autorização; regras complexas em unidades coesas e testáveis quando necessário.
- Implementar mudanças pequenas e incrementais, sem reescrever partes que funcionam.
- Validar permissões e isolamento entre contas, lógica pedagógica, progresso, XP, respostas, trilhas, assinaturas e pontuações afetadas.
- Para áudio e conteúdo musical, verificar exatidão da teoria, clareza, acessibilidade e direitos de uso do material.

## Fluxo de trabalho

1. Entender o objetivo e inspecionar **apenas** os arquivos relevantes.
2. Rodar `git status --short` antes de editar; preservar tudo que já estiver modificado ou não rastreado.
3. Para bugs, investigar causa raiz e criar/atualizar teste de regressão quando pertinente.
4. Para alterações significativas, apresentar plano curto; pedir aprovação quando a tarefa exigir.
5. Modificar somente quando a solicitação permitir. Se o pedido for análise, **não escrever arquivos**.
6. Rodar testes direcionados, examinar o diff e relatar resultados reais. Nunca alegar testes executados sem evidência.

## Git, bancos e ambientes — restrições obrigatórias

- **NUNCA executar commit, push, merge, rebase ou deploy automaticamente.** Cada uma dessas ações exige solicitação explícita.
- Não criar/trocar de branch por iniciativa própria. Quando solicitado, usar `feat/`, `fix/`, `refactor/`, `test/`, `docs/` ou `chore/`; não usar nomes como `codex/` ou `hermes/`.
- Nunca descartar alterações existentes (`reset --hard`, `clean -fd`, checkout destrutivo, force-push etc.).
- Desenvolvimento ocorre no **Mac/local** (inclusive `localhost:3000`) e/ou no **workspace da VPS Dev**. Cópias não são sincronizadas automaticamente. Homologação e produção são ambientes distintos.
- Pode executar testes e, se a tarefa permitir, migrations **somente** em bancos isolados dev/test, após confirmar `RAILS_ENV`, conexão e destino. **Nunca** executar migrations, seeds destrutivos ou testes em banco de produção.
- Não modificar infraestrutura, stacks Docker, dados reais, serviços de clientes ou credenciais. Não instalar dependências nem acionar cobrança, e-mail ou integrações externas reais sem autorização.
- Manter `.env`, secrets e dados pessoais fora de respostas, logs e Git. Considerar privacidade de estudantes, inclusive menores de idade.

## Eficiência de tokens e Skills

- Buscar de forma pontual com `rg`, arquivos exatos e pequenos trechos. Evitar repetir leitura/análise já realizada.
- Ignorar por padrão `node_modules`, `vendor`, `tmp`, `log`, `coverage` e artefatos compilados.
- Usar conforme necessário as Skills disponíveis: `codebase-inspection`, `systematic-debugging`, `test-driven-development`, `requesting-code-review`, `architecture-patterns`, `refactoring-patterns`, `verification-before-completion` e `token-efficient-workflow`.
- Preferir execução de testes relevantes antes de suítes completas, sem perder validação essencial. Economizar tokens **sem comprometer qualidade ou segurança**.

## Resposta final para cada tarefa

Informar concisamente: **resultado**, **arquivos modificados**, **testes realmente executados e seus resultados**, **bloqueios/pendências** e **estado do Git**. Se não houver alterações, declarar isso. Não realizar commit, push ou deploy por conta própria.

<!-- EQUIPE-HERMES-V2:PROJETO:BEGIN -->

## Equipe de desenvolvimento (Hermes / Atlas / Aura)

Estas instruções aplicam-se a qualquer agente trabalhando neste repositório.

### Agentes e fronteiras
- **Hermes (`default`)**: organização da tarefa, alinhamento de escopo, coordenação, decisões e resposta consolidada.
- **Atlas (`atlas-backend`)**: backend, regras de negócio, contratos de API, persistência, invariantes, concorrência e testes.
- **Aura (`aura-frontend`)**: UI/UX, direção visual própria, front-end, CSS, acessibilidade, componentes e testes visuais.
- Em tarefas transversais, discutir formato do contrato antes de implementar. Comunicação assíncrona via Kanban com pareceres específicos.

### Autorização e ambientes
- **Modo padrão é análise somente leitura**; mudança de código somente quando a tarefa solicitar implementação explicitamente.
- Não fazer commit, push, merge, abrir PR ou deploy automaticamente; usuário decide quando enviar ao GitHub.
- Não destruir ou descartar alterações existentes; inspecionar `git status --short` antes da edição.
- Não mudar segredos/.env, chaves ou dependências sem necessidade e autorização. Não imprimir segredos em logs/handoffs.
- Nunca rodar migrations/testes destrutivos em produção. Em bancos locais descartáveis de desenvolvimento/teste, migrations e testes são aceitos quando autorizados pela tarefa.
- Homologação somente após aprovação local, produção somente após homologação e autorização explícita.
- Para trabalho paralelo no mesmo repo, avaliações somente leitura. Escritas simultâneas exigem worktrees isoladas ou sequenciamento.

### Rotina técnica
1. Identificar contexto, `AGENTS.md`/regras locais, stack, testes, alterações pendentes e critérios de aceitação.
2. Planejar mudanças pequenas, reversíveis; explicar contratos entre camadas.
3. Consultar o outro especialista se há dependência concreta. Limitar debates; Hermes decide e registra.
4. Implementar somente se autorizado; validar com comandos específicos. Não inventar execução, telas ou testes.
5. Entregar resumo de arquivos alterados, comportamento, evidência, pendências e decisão humana necessária.

### Preferências de Git
- Branches: `feat/`, `fix/`, `refactor/`, `test/`, `docs/`, `chore/`.
- Não criar branch/commit sem pedido. Não usar prefixo de nome de agente.

### Informações particulares deste repositório
- Preencher manualmente: caminhos, versões, comandos de testes, dados e restrições do projeto.

<!-- EQUIPE-HERMES-V2:PROJETO:END -->

<!-- EQUIPE-HERMES-V2:APPMUSIC:BEGIN -->

## AppMusic — requisitos de integridade do domínio

Este produto de ensino musical tem por prioridade a **correção verificável da avaliação musical**. Não afirmar 100% de certeza matemática sem especificar escopo e provas/testes.

- Backend (Atlas): preservar validação independente de gabaritos, identidade obrigatória, pontuação transacional idempotente (teto existente de 20 XP por questão), parser rítmico estrito, rejeição de alternativas auditivamente equivalentes e tratamento neutro de falhas de áudio. Não simplificar essas regras sem demonstrar equivalência.
- Verificar provas de invariantes, concorrência/retry, autorização por usuário, integridade em DB, cenários de áudio inválido e regressão dos testes existentes.
- Frontend (Aura): experiência de aprendizagem musical acessível, clara e motivadora sem linguagem visual genérica de 'dashboard SaaS'; usar notação e metáforas pedagógicas adequadas sem comprometer legibilidade.
- Atenção a carregamento/falhas de áudio, teclado, feedback de validação, dispositivos móveis e localização PT/EN se o projeto contemplar.
- Trabalhar no desenvolvimento local primeiro (`localhost:3000`) quando esse for o repo local. Migrations e testes somente em bancos descartáveis dev/test corretamente verificados. Na VPS não presumir que a cópia está pronta para homologação.
- `docs/missao-02-integridade-resultados.md` é uma referência histórica, não prova de que resultados ou contagens permanecem atuais: reexecute testes antes de alegar sucesso.

<!-- EQUIPE-HERMES-V2:APPMUSIC:END -->
