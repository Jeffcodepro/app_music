# UI/UX 02 integral — arquivos e justificativas

Lista incremental em relação ao início **desta execução**, não ao HEAD. A working tree já continha trabalho das missões anteriores; ela não foi substituída por um checkout limpo. Snapshot inicial privado de 512 arquivos locais; arquivos antes limpos permanecem recuperáveis pelo histórico Git. AGENTS.md e 421 arquivos protegidos de domínio/documentação/evidências anteriores foram conferidos sem divergência. Nenhuma diferença em db/ e nada staged.

| Arquivo | Situação nesta execução | Justificativa |
| --- | --- | --- |
| `app/assets/stylesheets/components/_design.scss` | removido | Removido: CSS exclusivo do protótipo público, sem consumidores após a nova landing. |
| [app/assets/stylesheets/components/_home_landing.scss](../app/assets/stylesheets/components/_home_landing.scss) | editado (antes limpo) | Layout editorial público, responsividade, drawer, temas e SVG pelos tokens existentes. |
| [app/assets/stylesheets/components/_index.scss](../app/assets/stylesheets/components/_index.scss) | editado sobre trabalho local preexistente | Retirar somente a importação do protótipo; manter os imports anteriores de exercícios e UI. |
| [app/assets/stylesheets/components/_platform_ui.scss](../app/assets/stylesheets/components/_platform_ui.scss) | editado sobre trabalho local preexistente | Escala tipográfica, dashboard editorial, agrupamento de menu, estado de áudio e quebra de texto longo. |
| [app/assets/stylesheets/config/_fonts.scss](../app/assets/stylesheets/config/_fonts.scss) | editado (antes limpo) | Uma família de interface: Inter com fallback. Remover a requisição concorrente de Nunito/Work Sans. |
| [app/controllers/pages_controller.rb](../app/controllers/pages_controller.rb) | editado (antes limpo) | Ilustração estática gerada/validada/renderizada pelos serviços existentes; preservar redirect autenticado. |
| [app/helpers/platform_ui_helper.rb](../app/helpers/platform_ui_helper.rb) | editado sobre trabalho local preexistente | Ordem e agrupamento do menu, Histórico ativo e navegação pública reutilizável. |
| [app/javascript/controllers/app_shell_controller.js](../app/javascript/controllers/app_shell_controller.js) | editado sobre trabalho local preexistente | Mesmo botão acessível para abrir/fechar, restauração de foco, opção pública; manter ciclo Turbo/teclado. |
| `app/javascript/controllers/design_system_controller.js` | removido | Removido: controller exclusivo de animação/vídeo do protótipo público, sem consumidores restantes. |
| [app/javascript/controllers/harmony_player_controller.js](../app/javascript/controllers/harmony_player_controller.js) | editado sobre trabalho local preexistente | Somente indicação de estado visual, protegida pela solicitação atual; algoritmo sonoro preservado. |
| [app/javascript/controllers/index.js](../app/javascript/controllers/index.js) | editado sobre trabalho local preexistente | Retirar registro/import de três controllers de animação não utilizados. |
| [app/javascript/controllers/interval_player_controller.js](../app/javascript/controllers/interval_player_controller.js) | editado sobre trabalho local preexistente | Somente indicação de estado visual, protegida pela solicitação atual; algoritmo sonoro preservado. |
| [app/javascript/controllers/rhythm_player_controller.js](../app/javascript/controllers/rhythm_player_controller.js) | editado (antes limpo) | Somente indicação de estado visual e reset na troca de exercício; duração/prontidão preservadas. |
| `app/javascript/controllers/scroll_video_controller.js` | removido | Removido: controller exclusivo de animação/vídeo do protótipo público, sem consumidores restantes. |
| `app/javascript/controllers/seamless_loop_controller.js` | removido | Removido: controller exclusivo de animação/vídeo do protótipo público, sem consumidores restantes. |
| [app/views/layouts/application.html.erb](../app/views/layouts/application.html.erb) | editado sobre trabalho local preexistente | Shell público responsivo com temas/skip link/header/drawer; retirar Tailwind/Lucide/vídeos/globais. |
| [app/views/layouts/authentication.html.erb](../app/views/layouts/authentication.html.erb) | editado sobre trabalho local preexistente | Carregamento compartilhado de Inter. |
| [app/views/layouts/platform.html.erb](../app/views/layouts/platform.html.erb) | editado sobre trabalho local preexistente | Substituir links de fonte duplicados pelo partial compartilhado. |
| [app/views/pages/home.html.erb](../app/views/pages/home.html.erb) | editado (antes limpo) | Comunicação factual das quatro práticas, pauta estática, CTAs/FAQ e planejamento identificado. |
| [app/views/platform/_side_nav.html.erb](../app/views/platform/_side_nav.html.erb) | editado sobre trabalho local preexistente | Grupos principal/futuro e posição do mesmo controle quando modal. |
| [app/views/platform/dashboard.html.erb](../app/views/platform/dashboard.html.erb) | editado sobre trabalho local preexistente | Prática, áreas, histórico e métricas; preservar origem e escopo dos dados. |
| [app/views/shared/_fonts.html.erb](../app/views/shared/_fonts.html.erb) | novo | Único cabeçalho de fonte, com preconnect e display=swap. |
| [app/views/student_hub/_audio_status.html.erb](../app/views/student_hub/_audio_status.html.erb) | novo | Status de escuta compartilhado com live region, sem dados de correção. |
| [app/views/student_hub/_harmony_playground.html.erb](../app/views/student_hub/_harmony_playground.html.erb) | editado sobre trabalho local preexistente | Inserir status próximo da escuta, sem modificar formulários, identidades ou alternativas. |
| [app/views/student_hub/_perception_playground.html.erb](../app/views/student_hub/_perception_playground.html.erb) | editado sobre trabalho local preexistente | Inserir status próximo da escuta, sem modificar formulários, identidades ou alternativas. |
| [app/views/student_hub/_rhythm_playground.html.erb](../app/views/student_hub/_rhythm_playground.html.erb) | editado sobre trabalho local preexistente | Inserir status próximo da escuta, sem modificar formulários, identidades ou alternativas. |
| [config/application.rb](../config/application.rb) | editado sobre trabalho local preexistente | Default pt-BR e manutenção de en; preservar configuração anterior do autoload. |
| [config/environments/test.rb](../config/environments/test.rb) | editado (antes limpo) | Host example.test apenas para renderizar e-mails no delivery de testes. |
| [config/initializers/devise.rb](../config/initializers/devise.rb) | editado (antes limpo) | Ativar proteção nativa contra enumeração na recuperação, exigida no anexo. |
| [config/locales/pt-BR.yml](../config/locales/pt-BR.yml) | novo | Mensagens de UI/validação portuguesas; assuntos de e-mail EN preservados literalmente. |
| [docs/uiux-02-integral-inventario.md](../docs/uiux-02-integral-inventario.md) | novo | Scanner inicial, classificação atual e plano antes da implementação. |
| [docs/uiux-02-integral-resultados.md](../docs/uiux-02-integral-resultados.md) | novo | Relatório A–P com resultados, evidências, banco, riscos, limites e verificação local. |
| [test/browser/auth_ui.mjs](../test/browser/auth_ui.mjs) | editado sobre trabalho local preexistente | Reutilizar matriz existente de autenticação; nova pasta de evidências preserva as anteriores. |
| [test/browser/content_resilience.mjs](../test/browser/content_resilience.mjs) | novo | Reproduzir nome extremo e testar textos PT/EN longos sem salvar dados. |
| [test/browser/platform_accessibility.mjs](../test/browser/platform_accessibility.mjs) | editado sobre trabalho local preexistente | Reutilizar contraste, abas, Turbo e reflow; preservar evidências anteriores. |
| [test/browser/platform_ui.mjs](../test/browser/platform_ui.mjs) | editado sobre trabalho local preexistente | Mesmo botão do drawer, novo nome Dashboard e matriz reutilizada no novo diretório. |
| [test/browser/playground_audio.mjs](../test/browser/playground_audio.mjs) | editado sobre trabalho local preexistente | Estender teste existente com estado visual e Rítmica concluída/falha neutra. |
| [test/browser/playground_ux.mjs](../test/browser/playground_ux.mjs) | editado sobre trabalho local preexistente | Reutilizar o verificador geométrico via cenários/tamanhos configuráveis e liberar listener ao sair. |
| [test/browser/practice_submission.mjs](../test/browser/practice_submission.mjs) | novo | Quatro respostas verdadeiras pelos formulários, escuta completa, histórico e XP reais em conta fictícia. |
| [test/browser/public_ui.mjs](../test/browser/public_ui.mjs) | novo | Matriz da landing, drawer/FAQ/temas/Turbo, recursos externos e CLS observado. |
| [test/integration/authentication_localization_test.rb](../test/integration/authentication_localization_test.rb) | novo | Regressões de recuperação não enumerável, validação PT e preservação de e-mails. |
| [test/integration/public_experience_test.rb](../test/integration/public_experience_test.rb) | novo | Regressões de landing honesta/temas, grupos de navegação e identidade dos formulários sonoros. |
| [test/javascript/exercise_audio_test.cjs](../test/javascript/exercise_audio_test.cjs) | editado sobre trabalho local preexistente | Estender casos existentes de prontidão/falha com estado visível e cancelamento nos três players. |

Esta lista é gerada antes de salvar o próprio índice. Este arquivo também é novo. As 409 imagens, JSONs, logs e a galeria em `output/playwright/uiux02-integral/` são evidências novas; a pasta anterior `uiux02/` foi preservada byte a byte. `.playwright-mcp/` contém saídas da ferramenta, não código do produto. Nenhum artefato compilado, segredo, dependência instalada ou mudança de banco faz parte da entrega.

A remoção dos quatro arquivos de protótipo é intencional e limitada a fontes antes limpas, exclusivas da landing substituída. Os arquivos de áudio têm alterações exclusivamente de status/DOM; suas mudanças musicais anteriores continuam preservadas. Controllers/serviços musicais, modelos canônicos, renderers, identidade/XP e schema não foram editados por esta execução.
