# UI/UX 02 — arquivos desta missão

Esta lista compara o trabalho final com o snapshot anterior à UI/UX 02; não atribui a esta missão as alterações musicais preexistentes. Caminhos de capturas são agrupados em `output/playwright/uiux02/`.

## Layout, navegação, temas e componentes

- `app/assets/stylesheets/components/_exercise_components.scss`
- `app/assets/stylesheets/components/_exercise_theme.scss`
- `app/assets/stylesheets/components/_index.scss`
- `app/assets/stylesheets/components/_platform_ui.scss`
- `app/assets/stylesheets/components/_playground_compact.scss`
- `app/controllers/application_controller.rb`
- `app/controllers/onboarding_controller.rb`
- `app/controllers/platform_controller.rb`
- `app/controllers/student_hub_controller.rb`
- `app/helpers/platform_ui_helper.rb`
- `app/javascript/controllers/app_shell_controller.js`
- `app/javascript/controllers/index.js`
- `app/javascript/controllers/theme_controller.js`
- `app/views/devise/shared/_links.html.erb`
- `app/views/devise/shared/_providers.html.erb`
- `app/views/layouts/application.html.erb`
- `app/views/layouts/authentication.html.erb`
- `app/views/layouts/platform.html.erb`
- `app/views/platform/_empty_state.html.erb`
- `app/views/platform/_history.html.erb`
- `app/views/platform/_lessons_preparing.html.erb`
- `app/views/platform/_page_header.html.erb`
- `app/views/platform/_side_nav.html.erb`
- `app/views/platform/_study_areas.html.erb`
- `app/views/platform/_top_nav.html.erb`
- `app/views/shared/_theme_boot.html.erb`
- `app/views/shared/_theme_control.html.erb`

## Páginas e formulários

- `app/views/devise/passwords/edit.html.erb`
- `app/views/devise/passwords/new.html.erb`
- `app/views/devise/registrations/edit.html.erb`
- `app/views/devise/registrations/new.html.erb`
- `app/views/devise/sessions/new.html.erb`
- `app/views/onboarding/objective.html.erb`
- `app/views/onboarding/plan.html.erb`
- `app/views/onboarding/profile.html.erb`
- `app/views/onboarding/result.html.erb`
- `app/views/onboarding/welcome.html.erb`
- `app/views/platform/arena.html.erb`
- `app/views/platform/aulas.html.erb`
- `app/views/platform/carreira.html.erb`
- `app/views/platform/dashboard.html.erb`
- `app/views/platform/nivelamento.html.erb`
- `app/views/platform/perfil.html.erb`
- `app/views/platform/pratica.html.erb`
- `app/views/platform/trilha_tema.html.erb`
- `app/views/platform/trilhas.html.erb`
- `app/views/student_hub/_harmony_playground.html.erb`
- `app/views/student_hub/_reading_playground.html.erb`
- `app/views/student_hub/achievements.html.erb`
- `app/views/student_hub/billing_history.html.erb`
- `app/views/student_hub/challenges.html.erb`
- `app/views/student_hub/lesson_show.html.erb`
- `app/views/student_hub/plans_compare.html.erb`
- `app/views/student_hub/playground.html.erb`
- `app/views/student_hub/practice_result.html.erb`
- `app/views/student_hub/ranking.html.erb`
- `app/views/student_hub/scholarship.html.erb`
- `app/views/student_hub/trail_show.html.erb`

## Testes e documentação

- `docs/uiux-02-arquivos.md`
- `docs/uiux-02-aulas-proposta.md`
- `docs/uiux-02-inventario.md`
- `docs/uiux-02-resultados.md`
- `test/browser/auth_ui.mjs`
- `test/browser/platform_accessibility.mjs`
- `test/browser/platform_ui.mjs`
- `test/browser/playground_audio.mjs`
- `test/integration/platform_ui_test.rb`
- `test/integration/playground_compact_layout_test.rb`
- `test/javascript/platform_ui_test.cjs`

## Justificativas e limites

- Controllers: layouts de autenticação/onboarding e remoção exclusiva de geradores de aulas artificiais; serviços de exercício não foram refatorados.
- Helper/partials: navegação única, consultas de histórico com proprietário e componentes reutilizáveis, sem dados de demonstração.
- SCSS: geometria existente dos exercícios separada da paleta; tokens, temas, estados e App Shell substituem os imports do protótipo.
- Stimulus: gaveta com foco/scroll/Turbo e preferência de tema com lifecycle e sincronização.
- Views: conteúdo real ou preparação explícita; preservação de rotas, campos e quatro contratos de envio; nenhum vídeo simulado.
- Teste compacto anterior: seletor de aria-current delimitado à navegação dos exercícios, pois a sidebar também deve identificar a seção ativa.
- Script de áudio anterior: apenas os dois rótulos de Harmonia foram atualizados; os checks de reprodução/fallback permanecem.
- Evidências: matriz, contraste, áudio, notação, envios e imagens reais da conta sintética, sem dados reais do estudante.

O diff completo contra HEAD também contém arquivos da Missão 03.1 e UX-01 que não foram editados nesta missão. O manifesto de preservação identifica esses arquivos byte a byte.
