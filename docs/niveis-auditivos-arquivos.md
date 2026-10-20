# Arquivos desta entrega

Comparação com o inventário anterior a esta tarefa, não com o HEAD, que já continha muitas mudanças locais. Nenhum arquivo preexistente removido nesta entrega.

## Alterados (17)

| Arquivo | Justificativa |
| --- | --- |
| [app/assets/stylesheets/components/_index.scss](../app/assets/stylesheets/components/_index.scss) | Importar estilos restritos do menu e níveis. |
| [app/controllers/student_hub_controller.rb](../app/controllers/student_hub_controller.rb) | Propagar e manter dificuldade/instrumento; preservar voicing na reidratação harmônica. |
| [app/helpers/platform_ui_helper.rb](../app/helpers/platform_ui_helper.rb) | Adicionar ícones de configurações e saída. |
| [app/javascript/controllers/app_shell_controller.js](../app/javascript/controllers/app_shell_controller.js) | Incluir summary no controle de foco do drawer. |
| [app/javascript/controllers/index.js](../app/javascript/controllers/index.js) | Registrar o controller do menu da conta. |
| [app/javascript/controllers/melody_player_controller.js](../app/javascript/controllers/melody_player_controller.js) | Agendar eventos simultâneos, ganho/prontidão por duração, mantendo o transporte anterior. |
| [app/services/exercise_integrity_validator.rb](../app/services/exercise_integrity_validator.rb) | Conferir perfis, inversões e encaminhar o formato multivoz ao validador independente. |
| [app/services/harmony_exercise_generator.rb](../app/services/harmony_exercise_generator.rb) | Restringir conteúdo por nível e emitir inversões com fundamental preservada. |
| [app/services/perception_interval_exercise_generator.rb](../app/services/perception_interval_exercise_generator.rb) | Filtrar intervalos/distratores e fallback por dificuldade. |
| [app/views/platform/_side_nav.html.erb](../app/views/platform/_side_nav.html.erb) | Menu do perfil no rodapé, identidade, configurações e logout DELETE. |
| [app/views/student_hub/_harmony_playground.html.erb](../app/views/student_hub/_harmony_playground.html.erb) | Seletor, parâmetros de nível, ajuste explícito de conteúdo e instrumentos compartilhados. |
| [app/views/student_hub/_melodic_dictation_playground.html.erb](../app/views/student_hub/_melodic_dictation_playground.html.erb) | Dados temporais multivoz, pautas roláveis separadas do botão de resposta e seletor. |
| [app/views/student_hub/_perception_mode_control.html.erb](../app/views/student_hub/_perception_mode_control.html.erb) | Remover indicação fixa de uma voz da escolha de ditado. |
| [app/views/student_hub/_perception_playground.html.erb](../app/views/student_hub/_perception_playground.html.erb) | Seletor de nível e preservação do parâmetro nos formulários. |
| [docs/licenses/treble-clef.md](../docs/licenses/treble-clef.md) | Documentar proveniência/licença e âncora da clave de Fá. |
| [test/browser/account_rhythm_interactions.mjs](../test/browser/account_rhythm_interactions.mjs) | Adaptar o fluxo anterior à abertura do menu e Configurações. |
| [test/javascript/melodic_dictation_player_test.cjs](../test/javascript/melodic_dictation_player_test.cjs) | Regressões temporais/ganho/cancelamento e entradas inválidas para 1–4 vozes. |

## Novos (18)

| Arquivo | Justificativa |
| --- | --- |
| [app/assets/stylesheets/components/_listening_levels.scss](../app/assets/stylesheets/components/_listening_levels.scss) | Menu acima do perfil, limites de viewport, seletor e leitura das pautas. |
| [app/javascript/controllers/account_menu_controller.js](../app/javascript/controllers/account_menu_controller.js) | Posicionamento do painel, eventos de layout, fechamento e foco. |
| [app/models/listening_difficulty.rb](../app/models/listening_difficulty.rb) | Matriz editorial versionada de conteúdo, independente do nível do aluno. |
| [app/services/voiced_dictation_exercise_generator.rb](../app/services/voiced_dictation_exercise_generator.rb) | Gerar linhas temporais e quatro alternativas auditivamente distintas. |
| [app/services/voiced_dictation_integrity_validator.rb](../app/services/voiced_dictation_integrity_validator.rb) | Recalcular alturas, frequência, duração, progressão de dificuldade e unicidade. |
| [app/services/voiced_dictation_svg_renderer.rb](../app/services/voiced_dictation_svg_renderer.rb) | Pautas Sol/Fá separadas, alinhamento temporal e feixes de colcheias/semicolcheias. |
| [app/views/student_hub/_listening_level_control.html.erb](../app/views/student_hub/_listening_level_control.html.erb) | Seletor compartilhado de treino livre e níveis 1–4. |
| [docs/niveis-auditivos-arquivos.md](../docs/niveis-auditivos-arquivos.md) | Este inventário incremental com justificativas. |
| [docs/niveis-auditivos-resultados.md](../docs/niveis-auditivos-resultados.md) | Resultados reproduzidos, limites e verificação local. |
| [docs/niveis-percepcao-harmonia-ditados.md](../docs/niveis-percepcao-harmonia-ditados.md) | Registrar matriz, decisões musicais, formatos e limites. |
| [test/browser/listening_levels.mjs](../test/browser/listening_levels.mjs) | Verificação de perfis, responsividade, temas, rolagem e menu com teclado. |
| [test/browser/voiced_dictation_audio.mjs](../test/browser/voiced_dictation_audio.mjs) | Reprodução real, resposta, continuação única, fallback e falha neutra. |
| [test/integration/listening_difficulty_flow_test.rb](../test/integration/listening_difficulty_flow_test.rb) | Regressões HTTP de nível, persistência, envio e logout. |
| [test/javascript/account_menu_test.cjs](../test/javascript/account_menu_test.cjs) | Limites do painel, layout, foco e liberação de listeners. |
| [test/services/listening_levels_test.rb](../test/services/listening_levels_test.rb) | Perfis, recência, referências literais de inversão e compatibilidade anterior. |
| [test/services/voiced_dictation_svg_renderer_test.rb](../test/services/voiced_dictation_svg_renderer_test.rb) | Âncoras, posições de referência, dimensões e feixes parciais. |
| [test/services/voiced_dictation_test.rb](../test/services/voiced_dictation_test.rb) | Corpus multivoz e rejeição de corrupções/equivalência sonora. |
| [test/support/legacy_harmony_unleveled.json](../test/support/legacy_harmony_unleveled.json) | Oito payloads determinísticos extraídos do gerador anterior. |

## Evidências

Capturas, resultados JSON e logs em [output/playwright/listening-levels](../output/playwright/listening-levels/). Artefatos de missões anteriores preservados. Banco/schema, landing pública, serviço de pontuação, modelos de atribuição/tentativa e AGENTS.md mantiveram seus hashes iniciais.
