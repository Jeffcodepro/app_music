# Ditados em duas pautas, timbres e landing — resultados locais

Verificado em 20/10/2026. Branch preservada: `feat/canonical-music-model`, HEAD `16f9d18`. Nenhum commit, push ou deploy. Esta entrega descreve somente o incremento desta solicitação, não todas as mudanças acumuladas no working tree.

## Resultado e decisões

- Novos ditados usam no máximo duas pautas. Três vozes: duas em Sol e uma em Fá; quatro vozes: duas em cada clave, com hastes opostas. Duetos de flauta/clarinete compartilham Sol, em registros compatíveis. Colunas temporais e dimensões são iguais nas quatro alternativas, com espaço para segundas/uníssonos simultâneos e notas extremas. O exemplo de quatro vozes verificado passou de quatro pautas/608 unidades de altura para duas/416.
- Cada partitura é o botão da resposta, sem “Opção A/B/C/D” visível. Nomes acessíveis continuam diferenciando as alternativas. No celular, a pauta mantém tamanho mínimo e pode ser percorrida por toque ou teclado, sem alargar a página. A área clicável contém o SVG inteiro, inclusive após rolar.
- Uma resposta errada conserva a escuta concluída para a mesma atribuição/instrumento durante Turbo. O aluno pode tentar outra partitura imediatamente. Repetir permanece opcional; uma nova falha de reprodução revoga a prontidão. Após acerto, “Próximo ditado e tocar” cria outra questão e toca uma vez.
- Conforme a escolha expressa do usuário, novos ditados de três ou quatro vozes usam **piano**. Os outros timbres permanecem nas combinações compatíveis. Atribuições antigas pendentes preservam seu contrato, instrumento e assinatura até serem respondidas ou substituídas explicitamente.
- Restaurados os cinco PNGs originais dos instrumentos, sem modificar seus bytes. Assets transparentes pretos recebem contraste por CSS no tema escuro.
- Mantidas as amostras MusyngKite. Órgão usa `church_organ`; os demais programas são piano acústico, flauta, clarinete e violão de nylon. A espera por amostras foi ampliada de 2,2 para 10 segundos, reduzindo a entrada prematura na síntese. O envelope preserva o ataque gravado. A contingência informa “timbre aproximado” na tela.
- Novos intervalos e acordes respeitam janelas conservadoras de alturas de concerto. Em Harmonia, deslocamentos inteiros por oitava são persistidos por acorde, com alturas, frequências e inversão conferidas independentemente. Eles podem mudar o contorno de registro entre acordes; não mudam qualidade, grau ou inversão. Piano conserva os dados anteriores. Detalhes em [matriz e contratos](niveis-percepcao-harmonia-ditados.md).
- A landing não mostra seletor de tema em desktop ou menu móvel e usa seu tema claro original, preservando a preferência interna salva. Removido apenas o fundo semitransparente/desfoque indevido atrás de “Evolução visível”; composição, texto, imagens e animação existentes permanecem.
- Não foi encontrado defeito no sorteio das posições. Os geradores já embaralham as quatro alternativas. Foi acrescentada regressão determinística para nove famílias, sem reembaralhar uma tentativa após erro/reload nem impor sequência previsível em produção.

## Arquivos e justificativas

O [inventário incremental completo](ditados-duas-pautas-arquivos.md) separa código, testes, documentação e evidências.

| Grupo | Motivo |
| --- | --- |
| `voiced_dictation_*` e fixture v1 | Contrato v2, agrupamento de vozes, geometria compartilhada e compatibilidade das atribuições antigas |
| `exercise_instrument_register.rb`, geradores de Percepção/Harmonia e `exercise_integrity_validator.rb` | Impedir alturas novas incompatíveis com o instrumento e validar os deslocamentos persistidos |
| `student_hub_controller.rb` | Aplicar política de piano no nível 4 e reidratar os novos snapshots instrumentais sem alterar a pontuação |
| `exercise_piano.js` e players Intervalo/Harmonia/Melodia | Prontidão após erro/Turbo, timbres amostrados, limite de espera e indicação de contingência |
| Partials de ditado/rítmica/percepção, áudio/instrumento, helper e `_listening_levels.scss` | Seleção direta da pauta, foco/rolagem, ícones originais e apresentação compacta |
| Home, layout público, `_public_theme_boot` e `theme_controller.js` | Retirar controles públicos, isolar a landing e preservar preferência interna |
| Testes Ruby/Node e scripts de browser | Reproduzir falhas, verificar legado, registros, geometria, sorteio e fluxo real de resposta |

Não foram alterados nesta tarefa `AGENTS.md`, migrations, `db/schema.rb`, serviços de envio/pontuação, modelos de atribuição/tentativa, rotas ou dependências. As alterações anteriores nesses arquivos foram preservadas.

## Testes executados

Ambiente: Ruby 3.3.5 via rbenv, Bundler 2.6.8, Rails 7.1.6 e PostgreSQL 15. Banco descartável de testes por socket privado, sem listener TCP, porta 55445; nomes `app_music_integrity_compact_test` e `app_music_integrity_compact_browser_test`. O guard verificou identidade e diretório do cluster antes de conectar. Nenhum teste ou migration foi executado no banco de desenvolvimento/produção. Nenhuma migration nova foi necessária ou aplicada nesta tarefa.

| Execução | Resultado |
| --- | --- |
| Suíte Rails completa pelo `bin/test-isolated` | **261 testes, 14.702 asserções, 0 falhas/erros/skips** |
| `node --test test/javascript/*.cjs` | **88 testes, 0 falhas** |
| Integração de dificuldade e experiência pública após o ajuste final de largura CSS | **7 testes, 221 asserções, 0 falhas/erros/skips** |
| `git diff --check` | Sem erros |

A suíte cobre identidade, autorização, XP/idempotência/concorrência existentes, fixtures antigas, limites de registro, tríades/tétrades e inversões, frequências, assinaturas, disposição de vozes, notas extremas e sorteio em 128 seeds por família. A geometria e a persistência da escuta tiveram testes que falharam antes das correções. Permanecem avisos de depreciação de `:unprocessable_entity` emitidos por Rack/Rails, sem falhas na suíte.

Browser Chromium real, servidor de teste separado na porta 3001, conta e dados sintéticos:

- Desktop 1440, tablet 768 e mobile 390, claro/escuro: quatro vozes em duas pautas, mesmas dimensões entre alternativas, SVG inteiro dentro do botão, sem overflow da página. Dueto de sopros em uma pauta de Sol. Ritmo denso 12/4 com seleção direta e rolagem por teclado.
- Ouvir uma vez → clicar uma nota de partitura incorreta → responder corretamente por Enter, **sem nova reprodução**. Duas requisições de resposta; mesma atribuição e ordem de alternativas, novo token. Em seguida, nova questão tocou uma única vez. Falha simulada de dispositivo na repetição bloqueou nova resposta sem POST/crédito adicional.
- Carregamento real pelo CDN e decodificação dos buffers nas **56 combinações permitidas**: 20 Intervalos, 20 Harmonia e 16 Ditados. Os cinco programas corretos foram identificados; todos os pitches de cada exercício tinham buffers. Houve **15 reproduções completas amostradas**, uma por instrumento/área no maior nível permitido. Dados de duração/RMS/pico e URLs constam do JSON, não são medição de saída acústica.
- Contexto anônimo com sistema escuro e preferência salva escura: landing clara, zero seletores, bloco de texto transparente, sem desfoque/overflow, nas três larguras. Após login sintético, o sistema recuperou escuro. Capturas aguardaram fontes e animação de entrada antes da comparação visual.

Evidências: [results.json](../output/playwright/grandstaff-refinement/results.json), [Rails](../output/playwright/grandstaff-refinement/rails.log), [Node](../output/playwright/grandstaff-refinement/javascript.log), [integração final CSS](../output/playwright/grandstaff-refinement/css-regression.log), [quatro vozes](../output/playwright/grandstaff-refinement/four-voices-dark-1440.png), [mobile](../output/playwright/grandstaff-refinement/four-voices-light-390.png), [ícones](../output/playwright/grandstaff-refinement/original-instrument-icons.png), [card da landing](../output/playwright/grandstaff-refinement/landing-evolution-card-1440.png).

## Preservação e riscos

O inventário inicial e hashes estão em `/private/tmp/appmusic-grandstaff-baseline-wyl80acj`. A conferência final compara esse estado com arquivos rastreados e untracked, incluindo assets originais; não usa o HEAD como se todas as alterações fossem desta tarefa. A exclusão preexistente de `scroll_video_controller.js` foi mantida.

Não há alteração de tabelas nem política de XP. A prontidão conservada fica em memória, limitada a 128 chaves por atribuição/instrumento; não comprova escuta humana nem é mecanismo de autenticação. Após reload completo/processo novo, pode ser necessária outra escuta. Contratos antigos continuam aceitos; novos contratos são versionados para não reinterpretar respostas históricas.

Falta escuta humana em fones/alto-falantes e validação Safari/iOS. Amostras reais e buffers válidos não asseguram fidelidade de timbre, volume ou latência equivalentes a uma prova. A síntese continua sendo uma contingência aproximada identificada. As linhas simultâneas são exercícios de identificação, não contraponto aprovado por especialista. A convenção harmônica legada e a adequação pedagógica dos níveis continuam exigindo revisão musical.

Os timbres de sopros em Harmonia representam um conjunto de instrumentos do mesmo tipo, não a capacidade de um único sopro executar um acorde. As janelas são escolhas conservadoras de treino em alturas de concerto, sem prometer partes transpostas ou digitação instrumental. Referências técnicas: [Soundfont Player](https://github.com/danigb/soundfont-player), [programas MusyngKite](https://github.com/danigb/soundfont-player/blob/master/musyngkite.json) e [Yamaha: flauta a partir de Dó central](https://hub.yamaha.com/winds/wood/the-woodwind-family-explained/).

## Verificação local

1. No sistema, abrir Percepção → Configurar treino → Ditado melódico. Nível 4 oferece piano e três/quatro vozes em até duas pautas. Nível 3 permite os outros instrumentos; flauta/clarinete mostram duas vozes em Sol.
2. Tocar uma vez, clicar uma partitura errada e tentar outra imediatamente; repetir é opcional. Ao acertar, usar “Próximo ditado e tocar” e conferir uma execução. Simular falha de áudio e conferir ausência de resposta/pontuação.
3. Conferir os cinco timbres em Intervalos e Harmonia, níveis 1–4, e ditados nos níveis compatíveis. Se aparecer contingência, conferir sua indicação e repetir com CDN disponível. Fazer escuta humana para avaliar a qualidade.
4. Em 1440/768/390, conferir hastes opostas, rolamento dentro da pauta, clique direto e ausência de botões “Opção”. Testar foco por Tab, setas na região e Enter no botão.
5. Salvar escuro no sistema, visitar a landing anonimamente ou após sair: não deve haver seletor público nem painel cinza no texto de “Evolução visível”. Entrar novamente deve recuperar o tema salvo.
6. Para regressões: com uma URL **previamente verificada de PostgreSQL descartável por socket privado** em `APP_MUSIC_TEST_DATABASE_URL`, executar `CI=1 SCHEMA=/caminho/privado/schema.rb rbenv exec ruby bin/test-isolated`; depois `node --test test/javascript/*.cjs`. O runner recusa destinos que não satisfaçam o guard. Não substituir a URL por banco de desenvolvimento/produção. Scripts de browser em `test/browser/grandstaff_*.mjs`, `instrument_samples_matrix.mjs` e `public_theme_isolation.mjs` exigem servidor isolado/conta sintética na porta 3001.

O servidor original na porta 3000 foi preservado. O servidor 3001 e o PostgreSQL temporário usados na validação são encerrados ao final; capturas e logs permanecem para revisão.
