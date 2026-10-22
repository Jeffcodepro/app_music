# Correção da clave de Sol na Percepção

20/10/2026. Correção local do ditado melódico. A clave era um caractere `𝄞` com baseline y107, tamanho100 e fonte Noto Music não carregada pelo projeto. O fallback produzia desenho pequeno e deslocado para cima.

## Alterações

- `app/services/melodic_dictation_svg_renderer.rb`: substitui somente a clave tipográfica pelo contorno SVG Bravura, ancorado na linha de Sol4, y106. Escala proporcional ao espaçamento16. Notas, coordenadas de alturas, áudio e gabarito preservados.
- `test/services/melodic_dictation_test.rb`: regressão da origem musical, escala e independência de fontes do sistema.
- `test/browser/perception_clef.mjs`: verificação da origem na segunda linha inferior, limites, separação da fórmula de compasso e overflow em desktop/mobile e claro/escuro.
- `docs/licenses/treble-clef.md`: proveniência, conversão e licenças do contorno, usando as licenças já presentes no projeto.
- Este relatório e `output/playwright/perception-clef/`: resultados, logs e capturas antes/depois.

## Validação executada

O teste novo reproduziu a falha antes da correção: 5 testes, 421 asserções, uma falha por ausência de âncora musical explícita. Depois, renderer e integrações de ditado/continuidade: **13 testes, 503 asserções, nenhuma falha, erro ou skip**.

Comando executado com `APP_MUSIC_TEST_DATABASE_URL` apontando ao PostgreSQL privado descartável, `CI=1` e `SCHEMA` no scratch:

```sh
rbenv exec ruby bin/test-isolated test test/services/melodic_dictation_test.rb test/integration/melodic_dictation_flow_test.rb test/integration/perception_continuation_test.rb
```

O guard verificou o cluster `/private/tmp/app-music-compact-B2tCzd`, somente socket, banco `app_music_integrity_compact_test`. Navegador em banco separado `app_music_integrity_compact_browser_test`, conta fictícia e servidor temporário 3001. Nenhuma migration foi executada nem dados reais acessados. Não houve necessidade de testes Node porque nenhum JavaScript da aplicação foi modificado.

Chromium/Playwright: quatro capturas, em 1440×1000 e 360×844, claro/escuro. Nas quatro alternativas a origem ficou em `(44,106)`, coincidente com a segunda linha inferior; limites verticais aproximados35,73–148,13 dentro do viewBox0–194; margem entre clave e fórmula4/4 superior a28 unidades. Sem overflow da página. Capturas examinadas visualmente. Não houve verificação em Safari nesta correção.

`ruby -c` e `git diff --check` passaram. Snapshot dos dois arquivos preexistentes alterados: `/private/tmp/appmusic-clef-baseline-vgofoq4t`. Todas as demais alterações locais anteriores foram mantidas. Branch `feat/canonical-music-model`, sem commit, push ou deploy. Servidor temporário e cluster de testes encerrados ao final; servidor3000 não reiniciado.

## Conferência local

Recarregar Percepção → Ditado melódico e observar que o centro da volta da clave marca a segunda linha de baixo em todas as alternativas. A nota Sol4 se alinha a essa linha; Dó4 continua na linha suplementar inferior.

[Antes](../output/playwright/perception-clef/before.png) · [Depois desktop escuro](../output/playwright/perception-clef/after-desktop-dark.png) · [Depois celular claro](../output/playwright/perception-clef/after-mobile-light.png) · [Medições](../output/playwright/perception-clef/results.json).
