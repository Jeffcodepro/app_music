# UI/UX 02 integral — scanner inicial

19/10/2026. Continuação da implementação local, sem iniciar outra missão. Branch `feat/canonical-music-model`, HEAD `16f9d18`; nenhum arquivo staged. Snapshot privado de 512 arquivos antes das edições; preservados AGENTS.md, trabalho musical e evidências anteriores. Ruby 3.3.5 (rbenv), Bundler 2.6.8, Rails 7.1.6; bundle check satisfeito. PostgreSQL 15.19 privado, somente socket, dois bancos descartáveis separados para suíte e navegador; localhost:3000 preservado.

## Mapa atual e fontes

O [inventário anterior](uiux-02-inventario.md) mantém a enumeração completa de rotas/templates e suas origens. Esta tabela atualiza seu diagnóstico após a primeira implementação; os problemas antigos ali descritos não são o estado atual. Rotas verificadas contra config/routes.rb, layouts, controllers, helpers e templates; visita autenticada nova aos quatro exercícios, dashboard, prática, trilhas, histórico, conta e recursos futuros. Conta sintética, sem credenciais pessoais.

| Superfície / rotas | Origem dos dados / ações | Estado atual / limite | Ação nesta execução |
| --- | --- | --- | --- |
| `/` | Pages#home; cadastro/login reais, conteúdo estático | Parcial: dois vídeos automáticos, preços/promessas sem backend, 3 links vazios, 2 links com botão aninhado; overflow em 390/820/1440; noise externo retorna 402 | Reescrever comunicação e composição pública com os componentes atuais |
| `/users/sign_in`, `/users/sign_up`, `/users/password/{new,edit}`, `/users/edit` | Devise, User; OAuth só quando configurado | Funcional; formulários PT, mas flashes/erros EN; recuperação distingue existência da conta | Localizar UI e ativar proteção nativa de recuperação, preservar emails/rotas |
| `/onboarding/{welcome,objective,profile,result,plan}` | User.plan obrigatório; preferências em sessão; PATCHs existentes | Funcional com limite: revisão de preferências, sem avaliação pedagógica | Preservar regras e estrutura; tipografia compartilhada |
| `/app`, `/app/dashboard` | redirect; User, StudyActivity XP/dias, ExerciseAttempt por proprietário | Funcional; quatro práticas e histórico reais. Métricas antes da ação principal | Hierarquia editorial: prática, áreas, histórico, métricas |
| `/app/pratica`, `/app/playground?activity={leitura,percepcao,ritmica,harmonia}` | Catálogo, geradores, validator, atribuições e tentativas persistidas | Funcional. Síncopa bloqueada. Prontidão sonora interna, sem estado visual normal | Preservar contratos; tornar estados sonoros visíveis |
| `/app/trilhas`, `/app/trilhas/tema/:tema`, `/app/trilhas/:area/:nivel` | Constantes editoriais e links para prática disponível | Parcial: organização editorial, sem progresso/avaliação de domínio | Preservar avisos e links reais |
| `/app/pratica/resultado` | ExerciseAttempt via ExerciseAssignment.user_id | Funcional: histórico/contagens, vazio quando novo | Navegação principal e hierarquia; isolamento mantido |
| `/app/perfil`, `/users/edit` | User/ActiveStorage; perfil e credenciais reais | Funcional: validações, senha atual e escopo de campos | Preservar edição; localização dos erros |
| `/app/aulas`, `/app/aulas/:id` (guiado/livre inclusive) | Nenhum catálogo Lesson | Em preparação: avisos honestos já presentes, sem player falso | Preservar; agrupar navegação secundária |
| `/app/nivelamento` | Nenhum motor diagnóstico | Em preparação: sem avaliação/nível inventado | Preservar |
| `/app/carreira`, `/app/desafios`, `/app/ranking`, `/app/conquistas`, `/app/bolsa-evolucao` | Sem implementação de regras específicas | Em preparação, com retorno à prática real | Preservar e agrupar navegação |
| `/app/arena` | Sem modelos/controladores de salas em uso | Em preparação; histórico de 3 migrations ausentes permanece pendente | Não alterar domínio/schema |
| `/app/assinatura/{comparacao,historico}` | User.plan; sem gateway/ledger | Em preparação; sem cobrança ou benefício inventado | Preservar |
| Professor/admin, repertório, IA | Nenhuma rota/integração correspondente | Planejado | Não criar telas funcionais fictícias |
| `/up`, ações POST/PATCH/DELETE e OAuth | Saúde, autenticação, perfil, respostas | Funcional conforme implementação; não são catálogo de páginas | Regressão; não operar contas reais |

## Base compartilhada e defeitos confirmados

- Drawer, rail, temas sistema/claro/escuro, tokens, componentes e estados vazios já funcionam. Porém o botão original fica dentro de workspace inert após abrir: não pode fechar pelo mesmo controle. Corrigir sem segundo controlador.
- Menu mistura funcionalidades disponíveis e futuras, sem Histórico principal. Uma configuração deve definir ordem e grupos.
- Fonte Inter no shell compete com Nunito/Work Sans no CSS e JetBrains na landing. Consolidar carregamento; remover apenas dependências comprovadamente exclusivas do protótipo público (Tailwind CDN, Lucide, animações/vídeos).
- Base atual tem corpo 15px e títulos secundários pequenos. Ajustar escala geral sem aumentar a notação/compactação dos exercícios arbitrariamente.
- Áudio real mantém falha neutra e identidade de resposta; exibir preparando/reproduzindo/concluído/indisponível sem mudar relógio musical, prontidão ou pontuação.
- A visita pública registrou warning do Tailwind, ícones sociais ausentes e erro 402 da textura remota. Capturas iniciais em `output/playwright/uiux02-integral/before/`.

## Plano antes das edições

1. Regressões para comunicação pública, navegação e recuperação não enumerável, incluindo preservação de emails.
2. Landing editorial Caderno de Ensaio, temas/tipografia compartilhados; drawer existente com o mesmo botão para abrir/fechar; menu principal e futuro.
3. Dashboard com áreas e histórico prioritários; localização Devise/validações e estados visíveis de áudio, sem alterar domínio musical.
4. Reexecutar Rails/Node, matriz visual, teclado/Turbo/temas, geometria SVG, áudio/falha neutra e contrastes. Registrar evidências, desempenho observado e limites; deixar localhost:3000 ativo.
