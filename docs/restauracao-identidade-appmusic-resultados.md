# AppMusic — restauração da identidade e correção dos temas

Verificação local em 19/10/2026. A landing foi recuperada do código anterior à UI/UX 02 integral, sem substituir sua composição por outro design. Na área autenticada, a estrutura e os estilos de layout foram preservados; foram alteradas as cores compartilhadas e a aplicação do tema solicitadas nesta missão.

## Referência identificada e inventário inicial

- Branch mantida: `feat/canonical-music-model`, HEAD `16f9d18`; nada staged. Nenhum commit, push, deploy ou mudança de branch.
- Antes das edições, foram registrados status, diff e **1.131 arquivos rastreados/untracked** em snapshot privado. Não houve reset, clean ou reversão global.
- O Git conserva `home.html.erb`, `_design.scss`, `_home_landing.scss`, layout e controllers do desenho anterior. O relatório UI/UX 02 integral registra que a home ainda estava limpa antes daquela implementação; seu redesign ficou no diff local.
- `output/playwright/uiux02-integral/before/public-{390,820,1440}.png` confirma o hero, o vídeo e o menu anteriores. **Não é referência completa de todas as seções**: os reveals fora da tela estavam invisíveis. A imagem de 1440px também registra excesso lateral dos elementos decorativos. Por isso, a recuperação usa principalmente o código Git, corroborado pelo trecho inicial dessas imagens.
- [Hashes da referência](../output/playwright/identity-restoration/reference.json), [preservação](../output/playwright/identity-restoration/preservation.json) e [comparação visual](../output/playwright/identity-restoration/index.html).

O redesign havia substituído as 13 seções e o vídeo por hero editorial/pauta e card “Caderno de Ensaio”; removido os dois controllers utilizados pela landing e seu CSS; trocado o menu flutuante e a composição; consolidado fontes; introduzido tokens verdes/cobre. A restauração ficou limitada a esses componentes públicos e ao mecanismo/paleta dos temas.

## O que foi restaurado

Voltaram o hero “Teoria Musical — No Ponto Certo”, o mesmo MP4 de partitura em duas camadas, menu flutuante, banners, ilustrações CSS, gradientes neutros, animações e as seções na ordem original:

`hero → vantagens → problema → como-funciona → modos-estudo → playgrounds → gamificacao → diversao → conteudo → diferenciais → planos → faq → cta`.

Também voltaram Inter no corpo, Nunito nos títulos e JetBrains Mono nos trechos monoespaçados da página pública. A configuração global de fontes da área autenticada permaneceu intacta. **O texto estático da home foi comparado por parsing HTML com o Git e é idêntico**, inclusive os textos comerciais listados separadamente abaixo.

O CSS histórico foi limitado a `.landing-body`, evitando que fontes, cores e efeitos antigos vazassem para a área autenticada. Foram recuperados somente `design-system` e `seamless-loop`; o antigo `scroll-video` não é utilizado pela home e não foi reintroduzido. Tailwind/Lucide e as fontes originais voltaram apenas ao layout público; não houve instalação de dependências.

## Temas: defeitos e correções verificadas

1. **Bootstrap e tema estavam separados:** havia `data-theme`, mas faltava `data-bs-theme`. Bootstrap agora recebe o mesmo modo resolvido, antes do CSS e durante as mudanças.
2. **Falha de gravação descartava a escolha em atualizações posteriores:** a preferência explícita agora também fica no documento durante a sessão. Eventos do sistema e renderizações Turbo a preservam quando localStorage não pode gravar. Uma recarga completa com armazenamento bloqueado continua sem garantia de persistência durável; isso não foi ocultado.
3. **Seletores inseridos depois e eventos de storage:** um seletor novo recebe a preferência atual; apenas mudanças da chave de tema, ou limpeza do armazenamento, atualizam o modo entre abas. Listeners continuam sendo liberados no disconnect.
4. **Colisões Bootstrap/Tailwind na landing recuperada:** utilitários Bootstrap com `!important` aumentavam padding/gap do menu mobile e impediam cartões `bg-white` de escurecer. Correções específicas da landing resolvem essas prioridades sem afetar o restante do app.
5. **Paleta:** fundos, superfícies, texto, ação principal, foco, alvos e papel/tinta/linhas musicais usam branco, preto e cinzas. Verde-menta, verde-musgo e cobre deixaram de ser as cores do design system. Alertas de erro e validações semânticas existentes podem continuar usando vermelho; não se declarou ausência absoluta de pixels coloridos.

Foi feito uso real dos seletores no Chromium, além das regressões automatizadas: claro/escuro/sistema, preferência de sistema simulada, recarga, duas abas, links públicos, retorno pelo histórico, login fictício, navegação autenticada e os dois seletores da conta. A preferência explícita vence o sistema; Sistema acompanha suas mudanças. O teste também simula indisponibilidade de gravação e renderização Turbo. Os atributos do documento, valores dos seletores e superfícies renderizadas foram conferidos, não apenas o resultado dos testes antigos.

## Diferenças mínimas em relação ao original

Estas alterações são deliberadas e localizadas; não representam uma nova composição:

- Controle de tema no menu flutuante desktop. No mobile ele fica na gaveta, aberta pelo mesmo botão que também a fecha; mantém Escape, foco, clique externo e navegação pelas âncoras originais.
- Contenção dos orbs e do excesso lateral de decorações, sem reposicioná-los; padding/gap mobile corrigidos para Login/Cadastro caberem na tela.
- Hero mobile pode crescer além da altura da tela para manter o conteúdo abaixo do menu e os CTAs alcançáveis, em vez de cortar/encobrir elementos.
- Leve sombra no texto descritivo sobre o vídeo e cinza auxiliar mais legível em superfícies claras. O vídeo, o gradiente do título e a composição cinematográfica foram mantidos. **O contraste sobre vídeo permanece dependente do quadro; não há certificação WCAG desse fundo dinâmico.**
- Dois botões aninhados em links tornaram-se spans com as mesmas classes/estilo. Destinos e aparência dos CTAs foram preservados.
- Modo escuro adapta superfícies originalmente claras; os blocos originalmente escuros continuam escuros em ambos os modos. Não existia uma versão escura integral anterior que pudesse ser copiada pixel a pixel.
- Efeitos recuperados liberam observers/listeners/timers ao sair pelo Turbo. Movimento reduzido pausa os vídeos; retomar o movimento reinicia a camada visível corretamente.

O vídeo e suas animações produzem quadros diferentes entre capturas; não se afirma igualdade pixel a pixel. As capturas completas novas usam movimento reduzido real para mostrar as 13 seções, enquanto as capturas do hero mostram a execução normal.

Dependências antigas incompletas continuam identificadas: a textura remota de ruído respondeu 402 e três nomes de ícones sociais não existem no Lucide atual. Os três links sociais originais continuam com `href="#"`, sem destinos comerciais inventados. Esses pontos já estavam no código/referência anterior; não foram usados para alterar a identidade da página.

## Textos antigos que exigem revisão separada

A restauração **não implementa nem valida** as funcionalidades anunciadas nesses textos. Eles foram preservados por sua solicitação de recuperação fiel e devem ser revistos editorialmente sem novo redesign:

| Local | Alegações existentes no texto recuperado | Situação do produto |
| --- | --- | --- |
| Hero, vantagens, como funciona e modos de estudo | Videoaulas, nivelamento inteligente, trilhas personalizadas, modos guiado/livre e revisões | Não correspondem a um catálogo/avaliação funcional atual |
| Gamificação/diversão | Carreira, ranking, temporadas, salas/desafios ao vivo | Recursos em preparação |
| Bolsa e FAQ | Desconto destravado por “X de XP”, critérios e condições comerciais | Regras/integração não implementadas |
| Planos e FAQ | R$34,90/49,90/69,90 mensais; valores anuais; benefícios/limites; cancelamento | Não há cobrança/gateway/controle de benefícios correspondente; preços não foram aprovados por esta tarefa |
| Conteúdo e chamadas de evolução | Sequência formativa, domínio/nível e progressão | A prática atual não comprova avaliação de domínio pedagógico |

Os links de cadastro/login e CTAs de navegação foram verificados; a presença desses textos não cria novos direitos, pagamentos, aulas, ranking ou XP no backend.

## Arquivos alterados nesta missão e justificativas

Lista **incremental em relação ao início desta correção**, não de toda a working tree das missões anteriores:

| Arquivo | Justificativa |
| --- | --- |
| [home.html.erb](../app/views/pages/home.html.erb) | Recuperar o template original; inserir controles de tema/mobile e correções mínimas sem trocar textos/seções |
| [application.html.erb](../app/views/layouts/application.html.erb) | Repor fontes/bibliotecas públicas originais e integrar tema/drawer existente; conservar lang, CSRF e CSP |
| [_design.scss](../app/assets/stylesheets/components/_design.scss) | Recuperar efeitos/estética originais, com escopo exclusivamente público |
| [_home_landing.scss](../app/assets/stylesheets/components/_home_landing.scss) | Recuperar estilos e transição do vídeo originais, com escopo público |
| [_landing_theme.scss](../app/assets/stylesheets/components/_landing_theme.scss) | Adaptação mínima de temas, Bootstrap, menu, contraste e responsividade da landing |
| [_index.scss](../app/assets/stylesheets/components/_index.scss) | Repor imports necessários e carregar o adaptador público |
| [_platform_ui.scss](../app/assets/stylesheets/components/_platform_ui.scss) | Alterar somente os tokens de cor; bloco de layout autenticado byte a byte igual ao inicial |
| [_exercise_theme.scss](../app/assets/stylesheets/components/_exercise_theme.scss) | Remover uma combinação verde fixa de ícone e usar os mesmos tokens neutros, sem mudar geometria |
| [pages_controller.rb](../app/controllers/pages_controller.rb) | Remover a geração da ilustração “Caderno de Ensaio”, conservando o redirect do usuário autenticado |
| [platform_ui_helper.rb](../app/helpers/platform_ui_helper.rb) | Ajustar somente os links públicos para as âncoras originais; menu autenticado preservado |
| [design_system_controller.js](../app/javascript/controllers/design_system_controller.js) | Recuperar reveals/efeitos/scroll originais, com escopo e limpeza de eventos/observers |
| [seamless_loop_controller.js](../app/javascript/controllers/seamless_loop_controller.js) | Recuperar crossfade do MP4; limpeza e pausa/retomada por movimento reduzido |
| [index.js](../app/javascript/controllers/index.js) | Registrar os dois controllers efetivamente utilizados pela landing |
| [theme_controller.js](../app/javascript/controllers/theme_controller.js) | Sincronizar documento/Bootstrap/seletores, storage, sistema e Turbo |
| [_theme_boot.html.erb](../app/views/shared/_theme_boot.html.erb) | Resolver tema e Bootstrap antes da primeira pintura |
| [platform_ui_test.cjs](../test/javascript/platform_ui_test.cjs) | Regressões de Bootstrap, escolha com storage indisponível, seletor novo e eventos entre abas |
| [public_experience_test.rb](../test/integration/public_experience_test.rb) | Atualizar o contrato visual para a restauração; manter os testes de navegação autenticada e identidades musicais |
| [identity_restoration.mjs](../test/browser/identity_restoration.mjs) | Regressão de navegador para composição original, nove tamanhos, temas, login fictício e seletores |
| Este relatório e `output/playwright/identity-restoration/` | Justificativas, hashes, logs, comparação e capturas; evidências anteriores preservadas |

## Testes executados e preservação

| Verificação | Resultado |
| --- | --- |
| Ruby/Bundler | Ruby 3.3.5 via rbenv, Bundler 2.6.8; bundle check satisfeito |
| [Rails completo](../output/playwright/identity-restoration/rails-final.log) | **173 testes, 5.788 asserções, zero falhas/erros/skips**; inclui corpus musical, HTTP, isolamento e concorrência |
| [Node](../output/playwright/identity-restoration/node-final.log) | **42 testes aprovados**; regressões novas reproduziram falhas antes da correção |
| [Landing e temas no navegador](../output/playwright/identity-restoration/browser-results.json) | **18 casos** em nove tamanhos/claro-escuro, mais **6 capturas completas**; zero overflow/erros JS; sistema, recarga, abas, menu, login e seletores aprovados |
| [Área autenticada](../output/playwright/identity-restoration/platform-results.json) | **276 casos / 34 URLs**, com componentes, quatro identidades de resposta, labels, menu e Turbo preservados |
| [Contraste, reflow e teclado](../output/playwright/identity-restoration/contrast-results.json) | **24 pares medidos aprovados**; foco, duas abas, retorno Turbo, movimento reduzido e reflow equivalente a 200% |
| [Vídeo recuperado](../output/playwright/identity-restoration/video-results.json) | Crossfade real, pausa das duas camadas e retomada da camada visível aprovados |
| Conteúdo original | Texto estático da home idêntico ao Git após parsing HTML; 13 seções na ordem original |
| [Preservação](../output/playwright/identity-restoration/preservation.json) | **912 arquivos protegidos sem divergência**; layout SCSS autenticado idêntico fora dos tokens; nenhuma alteração em db/ |
| Git | git diff --check aprovado; branch/HEAD mantidos e nada staged |

Tamanhos: 360×640, 375×667, 390×844, 768×1024, 820×1180, 1024×768, 1366×768, 1440×900 e 1920×1080. A [galeria comparativa](../output/playwright/identity-restoration/index.html) contém 309 capturas selecionadas, incluindo a referência anterior. Para abrir localmente, use o arquivo index.html no navegador.

A suíte usou dois bancos descartáveis novos, somente socket, no PostgreSQL 15.19 privado: `app_music_integrity_identity_test` e `app_music_integrity_identity_browser_test`. O guard verificou ambiente, banco e diretório real antes de conectar; as oito migrations existentes foram aplicadas só nesses bancos, com SCHEMA em scratch. Não houve migration nova nem mudança no schema/dados de desenvolvimento, homologação ou produção. Navegador autenticado usou exclusivamente uma conta fictícia; nenhum e-mail real foi enviado.

Não foram alterados gabaritos, modelo canônico, validadores, parser, versões, assinaturas, XP/idempotência, APIs, áudio dos exercícios, regras pedagógicas, configuração Devise ou localização. As diferenças no Git desses arquivos continuam sendo trabalho anterior preservado, não uma reversão desta missão.

## Verificação local e limites

No localhost:3000: revisar a landing em desktop/tablet/mobile; abrir o menu mobile, alternar os temas, fechar pelo mesmo controle/Escape/fora e usar as âncoras. Em Sistema, mudar a preferência do sistema; recarregar e navegar a Login/Cadastro e de volta. Na conta de desenvolvimento, conferir os dois seletores e os quatro Playgrounds. Revisar separadamente os textos comerciais acima.

Para repetir Rails, preparar um cluster privado conforme [o runner](../bin/test-isolated) e [o guard](../lib/isolated_test_database.rb), definir `APP_MUSIC_TEST_DATABASE_URL` explicitamente para um banco privado `_test` e SCHEMA fora do repositório; então executar `rbenv exec ruby bin/test-isolated`. Nunca apontar esses testes ao banco de desenvolvimento. JavaScript: `node --test test/javascript/*.cjs`. Os testes de navegador recebem uma página Playwright já disponível e servidor guardado em 3001, com a conta sintética descrita no arquivo; não exigem instalação de biblioteca na aplicação.

A validação foi em Chromium automatizado com interação real nos controles; sistema e reflow foram simulados pelas APIs do navegador. Não inclui Safari, dispositivos físicos, zoom nativo, leitor de tela ou certificação WCAG. O contraste do texto sobre vídeo é variável, e as dependências antigas incompletas foram descritas acima. Não foi iniciado outro redesign nem uma próxima missão.

Servidores privados de navegador/galeria e PostgreSQL temporário encerrados. **Localhost:3000 permanece ativo, com GET anônimo HTTP 200 e a landing restaurada confirmada no HTML final.**
