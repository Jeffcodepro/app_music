# Auditoria musical e pedagógica do motor de exercícios

**Escopo:** leitura independente da documentação e do estado atual do repositório. Nenhuma funcionalidade foi implementada ou alterada nesta missão. O relatório considera o conteúdo presente no diretório de trabalho; havia alterações não commitadas no início da auditoria e elas foram preservadas.

## Como interpretar as conclusões

- **Fato encontrado:** comportamento ou conteúdo observável nos arquivos examinados; não implica que esteja pedagogicamente correto.
- **Regra musical demonstrável:** relação que pode ser calculada e testada sem julgamento subjetivo, desde que a convenção esteja declarada.
- **Recomendação:** proposta de currículo, política editorial, validação ou produto; não é apresentada como conteúdo curricular já aprovado.
- **Limitação:** aspecto que o motor ou os testes atuais não permitem certificar.

## Resumo executivo

O projeto já contém geradores para Leitura, Rítmica, Percepção e Harmonia, além de renderizadores SVG e reprodução sintetizada/por soundfont. Isso é uma base funcional de playground, não ainda uma autoridade musical independente.

Os principais riscos antes de expandir o MVP são:

1. Os níveis curriculares não governam consistentemente os geradores. Percepção e Harmonia não recebem nível; Rítmica não recebe nível e só trabalha com padrões de 4/4; Leitura pode usar `mixed`, incluindo exercícios de qualquer nível.
2. O validador de padrões rítmicos é permissivo: `parse_pattern_signature` descarta tokens inválidos e `option_from_signature` verifica apenas se a soma das durações reconhecidas totaliza 16 passos. Além disso, o áudio de percussão representa ataques, mas não codifica de modo confiável todo valor/duração notacional; duas escritas podem soar iguais.
3. As provas de leitura visual verificam principalmente presença de SVG e coerência interna de posição, não que o glifo efetivamente renderizado corresponda à altura escrita em diferentes fontes/tamanhos.
4. Percepção usa uma biblioteca de intervalos sem filtro curricular por nível e gera intervalo melódico ascendente/descendente, não as modalidades harmonicamente simultâneas ou solfejo descritas na grade.
5. Harmonia está limitada a tonalidades maiores e acordes diatônicos em posição fundamental; a função harmônica é uma tabela fixa simplificada, que pode transformar uma convenção didática em resposta aparentemente universal.
6. Apreciação e História da Música aparecem na visão de produto e nos metadados das trilhas, mas não foi encontrado gerador nem banco editorial de questões para elas.
7. Não há, no conjunto examinado, uma etapa separada de validação independente do gabarito. Testes que confirmam dados derivados do mesmo gerador/biblioteca são úteis, mas não substituem fixtures de referência independentes nem revisão musical.

**Recomendação central:** antes de aumentar variedade, definir uma representação musical canônica com grafia, altura, duração, métrica, áudio e convenções explícitas; validar cada exercício contra ela; e restringir o gerador às competências efetivamente ensinadas e medidas em cada nível.

## 1. Fatos encontrados no projeto

### 1.1. Currículo e produto

A visão de produto em `README.md:70-252` lista seis áreas de conteúdo, quatro níveis e tópicos amplos para cada nível. O texto não define objetivos mensuráveis, pré-requisitos entre áreas, critérios de domínio ou uma especificação completa de competências. Apreciação está distribuída pelos quatro níveis; História da Música começa no nível 3.

`app/controllers/platform_controller.rb:34-278` repete a grade em dados de trilha. As aulas/guias, porém, usam quatro áreas e títulos de episódios em `app/controllers/student_hub_controller.rb:6-46`. A progressão interna de aulas em `platform_controller.rb:281-309` também é genérica: Fundamentos, Consolidação, Aplicação e Domínio.

O nível da aula é inferido por contagem de atividades, não por domínio de habilidade: `platform_controller.rb:391-399` e `student_hub_controller.rb:209-218`. Essa contagem não distingue acerto, erro, tipo de competência ou dificuldade.

### 1.2. Implementação por área

- **Leitura:** `app/services/reading_note_exercise_generator.rb` gera nome de nota, acidente da nota e identificação de armadura. Há três claves (Sol, Fá e Dó), posições de pauta, lista de armaduras maiores e configurações de nível (`:30-147`, `:76-125`, `:301-385`). O modo padrão de temporada é `mixed` (`:148-152`). O renderer desenha pauta, linhas suplementares, clave, acidentes e cabeças de nota em SVG (`app/services/reading_staff_svg_renderer.rb:28-109`).
- **Rítmica:** `app/services/rhythm_exercise_generator.rb` define quatro modos, uma grade fixa de 4/4 e 16 passos por compasso (`:10-88`). Os tokens implementados são semínima, colcheia, semicolcheia e suas pausas. A conversão de assinatura para eventos de áudio omite eventos de pausa (`:106-148`). Os padrões são montados com motivos por tempo (`:241-310`). `app/javascript/controllers/rhythm_player_controller.js:71-105` agenda os ataques em uma grade temporal e um clique opcional.
- **Percepção:** `app/services/perception_interval_exercise_generator.rb:32-58` contém intervalos simples e compostos; `:102-136` cria um exercício melódico com duas alturas e frequências; `:147-179` escolhe alturas elegíveis. O player usa as frequências calculadas ou pitch names normalizados para soundfont (`app/javascript/controllers/interval_player_controller.js:130-176`, `:280-318`). Não há parâmetro de nível no gerador.
- **Harmonia:** `app/services/harmony_exercise_generator.rb:15-99` define qualidades, funções simplificadas, tonalidades maiores e progressões; `:380-424` monta acordes diatônicos a partir de escala maior. Há modos de qualidade, grau, função e progressão (`:214-349`). Não há seleção de forma menor, inversão ou nível curricular no gerador.
- **Apreciação e História:** aparecem no currículo e em `platform_controller.rb:210-278`, mas não foi encontrado gerador correspondente entre os serviços examinados.

### 1.3. Testes observados e limite da evidência

Há testes de serviços para os quatro geradores e renderizadores. Eles verificam, entre outros itens, quantidade/unicidade de alternativas, inclusão da resposta e algumas relações internas. Por exemplo: Leitura em `test/services/reading_note_exercise_generator_test.rb:4-36`, Rítmica em `test/services/rhythm_exercise_generator_test.rb:4-29`, Percepção em `test/services/perception_interval_exercise_generator_test.rb:27-37`, Harmonia em `test/services/harmony_exercise_generator_test.rb:4-56` e SVG em `test/services/reading_staff_svg_renderer_test.rb:4-50`.

**Limitação:** os testes observados não constituem, por si só, uma verificação independente do gabarito. Vários comparam valores produzidos pelo mesmo gerador/biblioteca que produziu o exercício. Os testes do SVG confirmam a presença de elementos, não a interpretação visual real do glifo por navegador, fonte e escala.

A tentativa de executar `bundle exec rails test test/services` não chegou a iniciar os testes: o shell selecionou Ruby 2.6.10 e o repositório exige Ruby 3.3.5 (`Gemfile:3`); também falta o Bundler 2.6.8 declarado no lockfile. Portanto, nenhum resultado de execução dos testes é alegado neste relatório.

## 2. Avaliação do currículo e matriz área × nível

A matriz abaixo separa o que a visão curricular pede do que os geradores atuais cobrem. “Cobertura” é uma avaliação do código observado, não uma afirmação de que a habilidade já esteja pedagogicamente validada.

| Área | Nível 1 | Nível 2 | Nível 3 | Nível 4 | Lacuna ou risco principal |
|---|---|---|---|---|---|
| **Leitura** | Pauta, claves, símbolos básicos e leitura inicial. | Figuras em contexto, compasso e fluência. | Maior complexidade rítmica, percepção e forma. | Aplicação avançada e leitura estrutural. | Gerador cobre nome de nota, acidente e armadura; não representa figuras/durações no gerador de leitura nem avalia forma. O filtro por nível não é uma sequência de pré-requisitos. O modo `mixed` pode sortear qualquer nível. |
| **Rítmica** | Semibreve, mínima, semínima, colcheia e pulsação. | Semicolcheia, compasso composto e subdivisão. | Vozes, polirritmia e ritmos de tradições diversas. | Camadas e estruturas sofisticadas. | Gerador atual limita-se a 4/4, semínima/colcheia/semicolcheia e pausas correspondentes. Não implementa semibreve, mínima, ponto, ligadura, compasso composto, quiáltera nem vozes independentes. Não tem filtro de nível. |
| **Percepção** | Solfejo simples, uníssono, segundas, terças e oitavas. | Solfejo intermediário, quartas, quintas e comparação. | Duas vozes, sextas e sétimas. | Múltiplas vozes, intervalos compostos e contexto. | Gerador sorteia intervalos simples e compostos sem nível. Só faz intervalo melódico de duas notas; uníssono exato, intervalo harmônico, solfejo, escala, padrões e duas vozes não estão cobertos. |
| **Harmonia** | Escalas, graus e tonalidade inicial. | Formação de acordes, tríades e relações. | Progressões, campo harmônico e construção ampliada. | Funções, dissonância, cadências e tensão. | Gerador cobre acordes diatônicos maiores, tríades/tétrades e tarefas associadas, mas não escalas menores, inversões, grafia de acordes alterados, condução de vozes ou cadência funcional contextual. Sem nível no gerador. |
| **Apreciação** | Repertório familiar, trilhas, musicais e conexão entre áreas. | Instrumentos, timbres e famílias. | Forma ABA/ABACA, repetição, contraste e retorno. | Sonata, concerto e tema/variações. | Há tópicos de trilha, mas nenhum banco estruturado ou verificador. “Familiar” varia por repertório, locale, geração, região e experiência do estudante. Sonata form e concerto não são categorias do mesmo tipo: uma estrutura formal e um gênero/prática instrumental. |
| **História da Música** | Não previsto na grade atual. | Não previsto na grade atual. | Medieval, Renascentista e Barroco. | Clássico, Romântico e século XX. | Conteúdo apenas listado; sem objetivos, fontes, recorte geográfico, política de incerteza ou questões. Períodos e fronteiras não são universais nem simultâneos em todas as culturas. |

### 2.1. Coerência, pré-requisitos e dificuldade

**Pontos coerentes:** a divisão geral parte de fundamentos, passa por consolidação e chega a integração/contexto. Leitura de figuras antes de fluência, intervalos simples antes de compostos e tríades antes de funções são sequências didáticas plausíveis.

**Lacunas a decidir antes de publicar o currículo:**

1. **Competências verificáveis:** cada tópico precisa de um verbo observável e uma condição. Ex.: “identificar, em clave de sol, a altura diatônica e a oitava de notas na pauta”, em vez de “leitura inicial”.
2. **Pré-requisitos explícitos:** leitura requer reconhecimento de linhas/espaços, clave, acidentes, armadura e oitava; leitura rítmica requer unidade de pulso, valor relativo, compasso e subdivisão; progressões dependem de escalas, graus, tríades e tonalidade; análise de cadência depende de função, frase e contexto.
3. **Pequenos passos rítmicos omitidos:** definir compassos simples antes de compostos; ponto e ligadura antes de síncopa ligada; agrupamento e acentuação antes de polirritmia; notação exata antes de ritmos de tradição oral.
4. **Menores e cromatismo:** incluir intervalos grafados, alterações, tríades/tétrades e tonalidades menores. “Escala menor” precisa escolher natural, harmônica ou melódica e, quando necessário, sentido ascendente/descendente.
5. **Leitura aplicada:** definir alcance de claves, linhas suplementares, armaduras, acidentes locais e, se pertinente, instrumentos transpositores/octavados. A grade fala em claves, mas não diz quando introduzir cada uma.
6. **Percepção:** separar reconhecimento de altura absoluta, classe de altura, direção, tamanho intervalar, solfejo relativo, comparação e escuta polifônica; são tarefas distintas e não intercambiáveis.
7. **Apreciação e história:** incluir repertórios e tradições para além de um cânone único, com localização cultural e versões das obras. As fronteiras “Medieval/Renascentista/Barroco/Clássico” devem ser ensinadas como convenções historiográficas situadas, não como cronologia universal.
8. **Progressão individual:** substituir contagem de sessões por evidência recente por competência, com incerteza e oportunidade de revisão. Número de tentativas mede exposição, não domínio.

### 2.2. O que pode ser avaliado objetivamente

- **Objetivo com gabarito automático, se dados completos:** nome/grafia e altura de uma nota; valor/duração total; posição de ataques; intervalo escrito; escala, grau e qualidade de acorde sob convenção definida; resposta factual indexada a uma fonte e versão.
- **Objetivo com validação parcial:** leitura de notação renderizada, qualidade tímbrica, reprodução do ritmo, reconhecimento auditivo, instrumentação e forma de um trecho. O motor valida o conteúdo digital; uma pessoa precisa conferir se a representação e o material de origem realmente comunicam aquilo.
- **Não tratar como gabarito universal:** “esta música é emocionante”, “este estilo é mais complexo”, “este instrumento é o mais importante”, leituras estéticas, influências controversas ou atribuições históricas disputadas. Essas atividades pedem resposta aberta, justificativa e/ou rubrica com contexto.

## 3. Regras musicais obrigatórias para um motor confiável

### 3.1. Representação canônica comum

Cada item deve apontar para uma fonte canônica de verdade e uma versão. Não derivar resposta oficial da imagem ou áudio já renderizado. O modelo de conteúdo recomendado deve preservar, no mínimo:

- **Altura grafada:** letra, acidente, oitava, clave, armadura, acidente local e compasso. Conservar grafia enarmônica (Fá sustenido não vira silenciosamente Sol bemol).
- **Altura sonora:** número MIDI ou razão/frequência em uma afinação explicitada. Cálculo de referência em temperamento igual: `f = 440 × 2^((midi − 69)/12)`, se A4=440 Hz for a convenção adotada.
- **Ritmo:** eventos de ataque, duração exata racional, tipo (som/pausa), ligaduras e articulação quando relevante.
- **Métrica/notação:** numerador/denominador, unidade de tempo, agrupamento, acentos e subdivisões. Duração total igual não garante grafia correta.
- **Áudio:** eventos esperados, afinação, registro, transposição, timbre, envelope/articulação e versão do sintetizador/soundfont.
- **Pedagogia:** competência, nível, pré-requisitos, objetivo, justificativa, respostas aceitas, fonte/revisor e política para variantes válidas.

Uma assinatura do exercício deve vincular estes dados; não deve servir como substituto de validação.

### 3.2. Leitura, claves e armaduras

1. Indexar linhas e espaços diatônicos relativamente à clave, com convenção de oitava explicitada (por exemplo, Dó central = C4 no sistema científico adotado).
2. Testar para cada clave, posição e oitava a relação entre coordenada vertical do desenho e altura grafada. Tratar linhas suplementares e espaços adjacentes como posições diatônicas, não como aproximação visual.
3. Aplicar acidente local, armadura e regra de persistência no compasso segundo a convenção de notação definida; o bequadro cancela alteração pertinente. Acidente local não muda o nome/letra da nota.
4. Validar ordem, contagem e posição dos acidentes da armadura por clave. Um símbolo correto numa coordenada errada também é exercício inválido.
5. Separar “nome da nota” (letra/enarmonia), “nota grafada completa” (letra + acidente + oitava) e “altura sonora” (pitch/MIDI). O enunciado deve dizer qual dessas respostas está sendo avaliada.
6. Validar visualmente glifos de claves, acidentes e figuras nas fontes realmente usadas pelo navegador. Um SVG com caracteres Unicode pode passar num teste de string e ainda aparecer como quadrado, símbolo substituto ou glifo mal ancorado.
7. Em item de armadura, solicitar a **tonalidade maior** se a resposta esperada for apenas maior; sem essa restrição, uma armadura também pode corresponder à relativa menor. Considerar modos e tonalidades enarmônicas quando fizerem parte do conteúdo.

### 3.3. Rítmica: cálculo exato e distinções

Use frações ou ticks inteiros em uma grade comum; não use `float` para decidir equivalência. Exemplo de unidade interna: 1/16 de semibreve, ou ticks inteiros com denominador compatível com todas as quiálteras admitidas. Para uma figura-base com duração `d`, um ponto soma `d/2` (figura pontuada = `3d/2`); dois pontos somam `d/2 + d/4`, total `7d/4`. Uma ligadura soma durações de notas grafadas na mesma altura, sem criar novo ataque no ponto ligado.

Validar separadamente:

- **Duração matemática:** soma das durações e pausas exatamente igual ao compasso.
- **Agrupamento notacional:** feixes, barras, pausas, ligaduras e divisão em tempos/grupos segundo o metro e a convenção editorial escolhidos.
- **Métrica:** pulsos, unidades de tempo, acentos principais/secundários e agrupamento (por exemplo, 6/8 frequentemente 3+3; não basta somar seis colcheias).
- **Interpretação/execução:** andamento, swing, microtempo, articulação, acento e tradição. Isso não é inferível apenas da soma.

Compasso composto precisa distinguir seis colcheias de dois pulsos ternários. Quiáltera deve declarar relação `n:m` (n eventos no tempo normalmente ocupado por m), posição e duração exatas. Polirritmia exige linhas independentes, início/fim do ciclo e alinhamento pela menor subdivisão comum. Um padrão pode fechar aritmeticamente e, ainda assim, ter feixes, barras ou acentos inadequados ao objetivo.

**Regra de unicidade auditiva:** se a pergunta avalia apenas ataques, compare conjuntos ordenados de ataques e declare essa competência. Se avalia valores escritos, o áudio precisa fornecer evidência para os valores (duração sustentada, referência métrica/articulação, ou outra pista) ou as alternativas com a mesma assinatura de ataques não podem coexistir. Em áudio de percussão curto, duas divisões de pausa ou finais diferentes podem ser indistinguíveis.

### 3.4. Percepção e referência sonora

1. Armazenar a sequência canônica de pitch names/MIDI e calcular o áudio dela. A resposta oficial deriva do intervalo entre alturas grafadas/sonoras de referência, não de uma legenda escrita manualmente.
2. Definir se se avalia **intervalo diatônico grafado** (número e qualidade), **distância em semitons**, **classe de intervalo** ou **classe de altura**. Essas grandezas podem divergir por enarmonia, registro e oitavas.
3. Para intervalos melódicos, ordenar as notas e declarar ascendente/descendente; para intervalos harmônicos, tocar as duas alturas simultaneamente. Uníssono exato (mesma altura/oitava), uníssono de classe de altura e oitava não devem ser confundidos.
4. Registrar afinação (por exemplo, A4=440), sistema (temperado ou outro), oitava, frequência efetiva, timbre e envelope. Timbre pode mudar a identificação perceptiva; não deve alterar inadvertidamente altura ou resposta.
5. Instrumentos transpositores precisam de uma política: o exercício pode exibir/soar em altura de concerto, ou modelar altura escrita e transposição do instrumento. Não misturar as duas regras em silêncio.
6. O sintetizador/soundfont deve ser auditável: testar pitches, envelopes, limites de registro, velocidade de carregamento, fallback e correspondência do áudio real aos eventos. Frequência arredondada para interface/log não deve ser reutilizada como gabarito se a resolução for insuficiente.
7. Para padrões, solfejo, escala e múltiplas vozes, armazenar todas as vozes e sua relação temporal/tonal; não declarar cobertura somente porque se gera áudio.

### 3.5. Harmonia e convenções

- Declarar sistema de afinação e grafia, tonalidade, escala e tipo de acorde; manter equivalência sonora separada de equivalência escrita.
- Escala menor: identificar natural/harmônica/melódica; para melódica, especificar variante e direção (a prática clássica ascende com alterações e frequentemente desce natural; a prática jazzística pode manter a forma ascendente). Não deixar “menor” sem qualificador.
- Intervalos e acordes: computar número/qualidade a partir das letras e acidentes grafados. Semitons isolados não distinguem, por exemplo, grafias enarmônicas.
- Acordes: registrar fundamental, terças empilhadas, qualidade, notas, oitavas, inversão, disposição e contexto. A inversão é determinada pelo baixo, não pela primeira nota da lista se o voicing não estiver ordenado.
- Campo harmônico: declarar escala de origem e se o conteúdo é diatônico. Acordes emprestados, dominantes secundárias e mistura modal precisam de rótulos próprios.
- Função harmônica: publicar a taxonomia adotada e limitar enunciado/contexto. A tabela atual classifica graus com um rótulo único; isso é uma simplificação didática, não uma verdade independente de contexto. Em muitos cursos, ii é predominante/subdominante, vii° é dominante e vi pode atuar como substituto de tônica ou em outros papéis conforme contexto.
- Cadência: distinguir sequência de acordes, posição na frase, resolução, inversões e condição de fechamento. “V–I” não garante, isoladamente, uma cadência autêntica perfeita.
- **Unicidade:** comparar alternativas pela resposta semântica definida, não apenas pelo ID. Se o enunciado não restringe grafia, inversão ou contexto, todas as respostas sonoramente equivalentes/teoricamente defensáveis devem ser aceitas ou o item deve ser reformulado.

### 3.6. Apreciação e História

Dados objetivos podem incluir título, compositor/autor quando atribuição for segura, edição/versão, instrumentação registrada, datas aproximadas e proveniência do trecho. Cada fato publicado deve registrar fonte, URL/identificador, autoria, data de acesso, página/trecho quando disponível, nível de confiança, editor e data de revisão.

Fontes recomendadas conforme assunto: catálogos de bibliotecas e arquivos (por exemplo, Library of Congress e bibliotecas nacionais), instituições de acervo/performance (por exemplo, Smithsonian Folkways para repertórios de tradição), edições críticas e catálogos de obras, obras de referência acadêmicas (por exemplo, Grove Music/Oxford Music) e fontes primárias. Uma enciclopédia generalista pode orientar a busca, mas não deve ser a única referência em afirmação controversa.

Revisão editorial deve verificar: recorte geográfico/temporal, versão da obra, atribuição e incerteza, contexto social, transliteração/termos localizados, representatividade e direitos de uso do áudio. Reconhecimento de forma, gênero, influência e significado depende do trecho e da tradição analítica: marcar como “interpretação apoiada por evidência”, usar resposta aberta/rubrica ou restringir a pergunta a sinais observáveis. Curiosidades não devem virar fatos sem fonte citável.

## 4. Riscos específicos identificados

| Risco | Evidência/referência | Efeito possível | Controle recomendado |
|---|---|---|---|
| Nível não limita a geração | Percepção não recebe nível (`perception_interval_exercise_generator.rb:95-137`); Harmonia não recebe nível (`harmony_exercise_generator.rb:207-235`); Rítmica sem nível (`rhythm_exercise_generator.rb:178-215`). | Um aluno iniciante recebe intervalo composto, tétrade/função ou tarefa fora da sequência ensinada. | Incluir nível/competência no contrato e filtrar antes de sortear. Bloquear combinação não autorizada. |
| Nível determinado por contagem de prática | `platform_controller.rb:391-399`; `student_hub_controller.rb:209-218`. | Sessões sem acerto podem avançar a temporada; prática repetida parece domínio. | Progressão por evidência por habilidade, com limiar, amostra mínima, recência e incerteza; permitir revisão humana. |
| Leitura não define se oitava importa | Opções de nota são apenas letras (`reading_note_exercise_generator.rb:14-22`, `:301-323`), embora a pauta gere pitch com oitava. | Gabarito pode ignorar parte da notação enquanto o enunciado pede a nota escrita. | Distinguir tarefa de letra, grafia completa e altura; alinhar opções e texto. |
| Mistura de nível por padrão | `DEFAULT_SEASON_MODE = "mixed"` e seleção de temporadas em `reading_note_exercise_generator.rb:148-152`, `:430-435`. | Playground pode desrespeitar o nível atual/trilha recomendada. | `mixed` só como escolha explícita, ou limitar ao intervalo autorizado do aluno. |
| Parser rítmico aceita lixo | `parse_pattern_signature` usa `filter_map` (`rhythm_exercise_generator.rb:106-117`); `option_from_signature` confere soma mas não que todos os tokens foram reconhecidos (`:123-134`). | Assinatura inválida pode virar opção renderizável/avaliável com eventos diferentes do identificador. | Rejeitar se qualquer token falhar; validar sequência, métrica, eventos, opções e assinatura antes de salvar/publicar. |
| Gabarito rítmico pode não ser único no áudio | `audio_events_for_signature` só retorna ataques (`rhythm_exercise_generator.rb:136-148`); player sintetiza hits percussivos breves (`rhythm_player_controller.js:127-139`). | Escritas com mesmos ataques e pausas subdivididas podem soar idênticas. | Comparar projeção auditiva das alternativas; eliminar equivalentes, aceitar todas as formas válidas ou acrescentar pista audível. |
| Métrica atual não cobre grade curricular | Configuração de Rítmica fixa 4/4 e dezesseis passos (`rhythm_exercise_generator.rb:85-88`), motifs em `:10-74`. | Impossível avaliar composto, ponto, ligadura, síncopa ligada, tuplet ou polirritmia com o mesmo contrato. | Tratar como escopo explícito do MVP; não rotular como cobertura geral de Rítmica. |
| Intervalo grafado e som podem divergir | Percepção usa `DiatonicInterval` e pitches nomeados (`perception_interval_exercise_generator.rb:102-136`); player soundfont normaliza acidentes para pitch cromático (`interval_player_controller.js:280-318`). | O áudio valida semitons, mas elimina grafia enarmônica; direção e oitava também podem ser confundidas. | Guardar e testar ambas as respostas; informar objetivo; usar grafia apenas onde é ensinada. |
| Escopo perceptivo extrapola o nível | Biblioteca de intervalos simples/compostos em `perception_interval_exercise_generator.rb:32-55`, sorteio sem nível em `:141-145`. | Intervalos de 9ª a 15ª podem surgir em fase inicial. | Catálogo por competência, direção, registro e modo melódico/harmônico. |
| Convenção funcional única pode ser contestada | `FUNCTION_BY_DEGREE` em `harmony_exercise_generator.rb:48-56`. | ii/vii°/vi podem receber mais de uma análise defensável; resposta marcada errada apesar de teoria aceitável. | Nomear a taxonomia, dar contexto e não exigir escolha única quando a própria tarefa não a restringe. |
| Harmonia limitada a maior/posição fundamental | `MAJOR_KEYS` em `harmony_exercise_generator.rb:38-46`; construção em `:380-424`. | Lacuna em menor, inversão, cromatismo e grafia; rótulo de “harmonia” sugere cobertura mais ampla. | Publicar o recorte, expandir apenas com fixtures de escalas e acordes grafados. |
| SVG validado superficialmente | `reading_staff_svg_renderer_test.rb:4-50` verifica presença de `<ellipse>`, `<text>` e símbolos. | Clave pode não estar ancorada, acidente cair em posição errada ou fonte substituir glifo. | Testes de coordenadas semânticas, renderização headless em fontes suportadas e revisão visual de fixtures-limite. |
| Conteúdo cultural sem fonte/modelo editorial | README lista ritmos e repertório (`README.md:140-145`, `:210-250`), mas não há esquema editorial observado. | Generalização, atribuição incorreta ou gabarito culturalmente estreito. | Fonte por afirmação, revisão especializada e versão/localidade do conteúdo. |

## 5. Tipos adequados à geração automática e revisão humana

### 5.1. Bons candidatos à geração automática

Com convenções fixas e validação independente: posição/nota em clave específica; contagem de armadura maior; soma rítmica e localização de ataques em métrica declarada; intervalo nomeado a partir de duas alturas canônicas; escala maior/grau; qualidade de tríade/tétrade grafada; construção de campo harmônico; alternativas sem duplicata semântica.

Esses itens ainda exigem verificação da renderização ou áudio entregue ao aluno. “Gerado automaticamente” não significa “aprovado automaticamente”.

### 5.2. Exigem revisão humana ou aprovação editorial

- Significado musical de síncopa, groove, swing, acento e ritmo tradicional; versão estilística e contexto cultural.
- Áudio real: qualidade tímbrica, tessitura, afinação, balanço, inteligibilidade e correspondência perceptiva.
- Notação avançada: feixes editoriais, vozes, quiálteras, polirritmia, grafias raras, convenções de instrumento.
- Função, cadência, condução de vozes e análise tonal/modal em contexto.
- Forma musical identificada em trecho, gênero, estilo, narrativa, influência e juízo estético.
- Afirmação histórica, atribuição, datação, circulação e contexto cultural.
- Validade pedagógica do nível, distratores, linguagem, acessibilidade e adequação do esforço cognitivo.

### 5.3. Bloqueios automáticos

Bloquear publicação se faltar dado canônico; houver pitch/nota/clave incompatível; soma do compasso não fechar exatamente; token desconhecido; evento de áudio não derivar da partitura-fonte; opção inválida/duplicada semanticamente; nenhuma ou mais de uma resposta aceita sem política declarada; enunciado omitir convenção necessária; gabarito divergente de fixture independente; renderização de referência falhar; item de História/Apreciação não tiver fonte e revisor exigidos.

## 6. Exercícios de referência e demonstração do gabarito

Os itens a seguir são **fixtures recomendadas**, não conteúdo encontrado já aprovado no banco. As regras automáticas descritas são especificações de aceitação; os exemplos marcados como “fora do escopo atual” evidenciam que o motor presente não deve fingir cobri-los.

### 6.1. Leitura

#### L-1 — Nota em linha da pauta

- **Objetivo:** reconhecer o nome diatônico da nota numa clave de Sol.
- **Nível:** 1.
- **Enunciado:** “Na clave de Sol, qual nota está na linha inferior da pauta?”
- **Dados musicais:** clave de Sol; posição 0 (linha inferior); sem armadura nem acidente local; convenção C4 = Dó central.
- **Alternativas:** Dó; Ré; Mi; Fá.
- **Resposta correta:** Mi (E4).
- **Demonstração:** a linha inferior em clave de Sol é E4; a alternativa pede apenas a letra/nome, não a oitava.
- **Regra automática:** resolver `(clave, posição 0)` para E4; checar opção correta única e nenhuma transformação de armadura/acidente; validar SVG da cabeça no eixo y dessa linha.
- **Possíveis ambiguidades:** se o enunciado disser “nota escrita” em vez de “nome”, incluir oitava na resposta. Se pedir altura sonora, comparar MIDI/frequência, não só a letra.

#### L-2 — Acidente local e grafia

- **Objetivo:** ler acidente local sem converter para enarmonia.
- **Nível:** 2.
- **Enunciado:** “Qual é a nota completa indicada?”
- **Dados musicais:** clave de Sol; posição 1 (espaço imediatamente acima da linha inferior = F4); nenhum acidente na armadura; acidente local sustenido; compasso especificado.
- **Alternativas:** Fá sustenido; Fá bemol; Mi sustenido; Sol sustenido.
- **Resposta correta:** Fá sustenido (F♯4).
- **Demonstração:** a posição diatônica é F4; o sustenido altera a altura sem trocar a letra. F♯ e E♯ podem soar enarmonicamente iguais em temperamento igual, mas não têm a mesma grafia.
- **Regra automática:** derivar letra/oitava da clave e posição, aplicar acidente em separado, comparar ID de grafia e calcular pitch sonoro apenas como verificação adicional.
- **Possíveis ambiguidades:** não reduzir a resposta a semitons quando se avalia notação; se o exercício for exclusivamente auditivo, declarar equivalências aceitas.

#### L-3 — Armadura maior

- **Objetivo:** reconhecer a armadura e associá-la à tonalidade maior solicitada.
- **Nível:** 2.
- **Enunciado:** “Esta armadura tem dois sustenidos. Qual tonalidade maior corresponde a ela?”
- **Dados musicais:** clave indicada; F♯ e C♯ na ordem/posições corretas; modo da resposta explicitamente maior.
- **Alternativas:** Ré maior; Lá maior; Si bemol maior; Dó maior.
- **Resposta correta:** Ré maior.
- **Demonstração:** dois sustenidos identificam Ré maior quando a pergunta restringe a tonalidade maior; a mesma armadura também representa Si menor.
- **Regra automática:** comparar sequência, quantidade, símbolos e coordenadas de armadura; mapear para conjunto de tonalidades compatíveis; exigir interseção com `major` de cardinalidade 1.
- **Possíveis ambiguidades:** sem a palavra “maior”, Si menor é outra resposta válida. Tonalidades enarmônicas e modos devem ser deliberadamente incluídos/excluídos.

**Inválido — leitura:** mostrar um sustenido na armadura e marcar Fá maior como gabarito. Rejeitar: um sustenido corresponde a Sol maior/Mi menor, não a Fá maior. Também rejeitar se o gabarito diz F♯4 mas a imagem põe o sustenido em outra letra/oitava.

### 6.2. Rítmica

#### R-1 — Ataques e pausas em 4/4

- **Objetivo:** identificar uma distribuição de ataques em compasso simples.
- **Nível:** 1.
- **Enunciado:** “Ouça o compasso e escolha a escrita correspondente aos ataques.”
- **Dados musicais:** 4/4; semínima = 4 unidades de semicolcheia; colcheia = 2; pausa de colcheia = 2; pausa de semínima = 4. Padrão: `n4 · r2 · n2 · n4 · r4`.
- **Alternativas:** (A) padrão canônico acima; (B) `n4 · n4 · n4 · n4`; (C) oito colcheias sonoras; (D) `n4 · r2 · n4 · n2 · r4`.
- **Resposta correta:** A.
- **Demonstração:** duração = `4 + 2 + 2 + 4 + 4 = 16` unidades de semicolcheia = quatro semínimas. Ataques em 0, 6 e 8 passos; pausa final ocupa os passos 12–16.
- **Regra automática:** somar inteiros, validar 16/16, obter ataques `(0,6,8)`, comparar a sequência de eventos canônica com cada alternativa e exigir apenas uma projeção auditiva correta.
- **Possíveis ambiguidades:** se a atividade mede só ataques, declara-se isso; a duração final de uma nota/pausa não é necessariamente audível em timbre percussivo curto.

#### R-2 — Compasso composto 6/8

- **Objetivo:** perceber seis subdivisões agrupadas em dois pulsos ternários.
- **Nível:** 2.
- **Enunciado:** “Qual alternativa representa um compasso 6/8 com primeiro grupo sonoro e segundo grupo iniciado por pausa?”
- **Dados musicais:** 6/8; unidade notada = colcheia; agrupamento 3+3; padrão `n2 · n2 · n2 | r2 · n2 · n2` (tokens `n2`/`r2` significam colcheias no esquema deste exemplo).
- **Alternativas:** (A) agrupamento 3+3 conforme os dados; (B) sete colcheias; (C) seis colcheias agrupadas 2+2+2; (D) padrão de 4/4 com quatro semínimas.
- **Resposta correta:** A.
- **Demonstração:** seis unidades de colcheia totalizam três semínimas; a barra interna evidencia dois grupos de três. A soma isolada não determina o agrupamento.
- **Regra automática:** total racional = 6 colcheias; assinatura 6/8; fronteira de grupo em 3; projetar ataques e pausa da segunda metade; validar a grafia/feixes para 3+3.
- **Possíveis ambiguidades:** 6/8 pode ser articulado de outro modo conforme repertório; métrica composta e acento precisam ser ensinados como convenção, não inferidos apenas da fração.
- **Limitação atual:** o gerador e o renderer atuais só declaram 4/4; não podem aprovar este item.

#### R-3 — Polirritmia 3:2

- **Objetivo:** comparar três ataques regulares contra dois no mesmo ciclo.
- **Nível:** 3.
- **Enunciado:** “Qual figura apresenta três ataques igualmente espaçados contra dois ataques igualmente espaçados, iniciando juntos?”
- **Dados musicais:** duas semínimas de ciclo; grade comum de seis terços de semínima; voz A ataca nos pontos 0, 2, 4; voz B nos pontos 0, 3; duração de ciclo explícita.
- **Alternativas:** (A) A=3 ataques e B=2 conforme os dados; (B) A=2/B=3; (C) A=3/B=4; (D) duas vozes em uníssono rítmico.
- **Resposta correta:** A.
- **Demonstração:** a menor grade comum subdivide o ciclo em seis partes; A ocupa posições a cada duas unidades e B a cada três.
- **Regra automática:** representar duas trilhas independentes em frações exatas; comparar pares de onsets normalizados, alinhamento inicial e término comum; verificar notação de quiáltera.
- **Possíveis ambiguidades:** “3 contra 2” precisa esclarecer se o ciclo, início/fim e valores são simultâneos. Timbre e acento podem afetar percepção; revisar áudio e notação.
- **Limitação atual:** a representação atual é uma sequência monofônica; não modela voz, razão de quiáltera ou polirritmia.

**Inválidos — rítmica:** (1) compasso 4/4 com 15/16 de semibreve: rejeitar por duração incompleta; (2) compasso 6/8 com sete colcheias: rejeitar por excesso; (3) assinatura `n4 · foo · n4 · n4 · n4`: rejeitar mesmo que os tokens reconhecidos somem 16 — parser não pode descartar `foo`; (4) alternativa `n4 · n4 · n4 · r4` e alternativa `n4 · n4 · n4 · r2 · r2`: se o áudio contém só ataques percussivos, ambas têm os mesmos três ataques e podem soar idênticas. Não publicar como questão de resposta única sobre escrita completa.

### 6.3. Percepção

#### P-1 — Intervalo melódico ascendente

- **Objetivo:** reconhecer uma terça maior melódica.
- **Nível:** 1.
- **Enunciado:** “Ouça as duas notas em sequência e identifique o intervalo ascendente.”
- **Dados musicais:** temperamento igual; A4=440 Hz; C4 (MIDI 60) seguido por E4 (MIDI 64); timbre de piano; duas notas separadas por pausa declarada.
- **Alternativas:** segunda maior; terça menor; terça maior; quarta justa.
- **Resposta correta:** terça maior (M3).
- **Demonstração:** C–E ocupa três nomes diatônicos; diferença cromática = 4 semitons. Frequências teóricas arredondadas para exibição: 261,626 Hz e 329,628 Hz.
- **Regra automática:** derivar número e qualidade da grafia C4→E4; confirmar diferença MIDI +4; conferir que eventos enviados ao player são exatamente esses pitches e que só uma opção tem esse intervalo.
- **Possíveis ambiguidades:** opções devem deixar claro se são intervalos escritos ou semitons; excluir alternativas enarmônicas concorrentes ou declarar o recorte.

#### P-2 — Intervalo melódico descendente

- **Objetivo:** reconhecer direção descendente e quinta justa.
- **Nível:** 2.
- **Enunciado:** “As notas são tocadas da primeira para a segunda. Qual é o intervalo?”
- **Dados musicais:** E4 (MIDI 64) seguido por A3 (MIDI 57), piano, A4=440 Hz.
- **Alternativas:** quarta justa descendente; quinta justa descendente; quinta justa ascendente; sexta menor descendente.
- **Resposta correta:** quinta justa descendente.
- **Demonstração:** E4→A3 desce sete semitons e cobre cinco nomes contando as extremidades; frequência teórica 329,628 Hz→220 Hz.
- **Regra automática:** verificar ordem temporal, direção, número diatônico e 7 semitons; conferir o payload de áudio e o rótulo.
- **Possíveis ambiguidades:** a opção “quinta justa” sem direção pode ser insuficiente; a oitava deve estar restrita se alternativas compostas forem possíveis.

#### P-3 — Intervalo harmônico simultâneo

- **Objetivo:** identificar uma oitava justa harmônica (duas vozes simultâneas).
- **Nível:** 3.
- **Enunciado:** “As duas notas soam juntas. Qual é o intervalo entre as vozes?”
- **Dados musicais:** C4 + C5 simultâneos; MIDI 60 e 72; A4=440 Hz; duração comum; timbre/voicing definidos.
- **Alternativas:** uníssono exato; quinta justa; sétima maior; oitava justa.
- **Resposta correta:** oitava justa.
- **Demonstração:** grafia C–C cobre oito nomes (incluindo extremidades) e 12 semitons; frequência teórica 261,626 Hz e 523,251 Hz.
- **Regra automática:** testar simultaneidade e alturas independentes; calcular intervalo grafado e distância em semitons; comparar o payload de duas vozes com o gabarito.
- **Possíveis ambiguidades:** “uníssono” pode significar mesma altura absoluta ou mesma classe de altura. A pergunta define a distinção; instrumento deve tocar ambas as vozes.
- **Limitação atual:** o gerador observado pede sempre duas notas consecutivas; este exercício exige um modo harmônico diferente.

**Inválido — percepção:** armazenar `C4 → Eb4` com gabarito “terça maior”. A diferença sonora é três semitons e a grafia é terça menor. Rejeitar se o alvo for M3. Também bloquear um exercício que pede “intervalo menor” sem identificar registro/direção quando uma opção composta cabe na tarefa.

### 6.4. Harmonia

#### H-1 — Grau de escala maior

- **Objetivo:** localizar um grau em uma escala maior declarada.
- **Nível:** 1.
- **Enunciado:** “Na escala maior de Dó, qual é o quarto grau?”
- **Dados musicais:** escala C–D–E–F–G–A–B; tônica C; numeração diatônica a partir de 1.
- **Alternativas:** 2º; 3º; 4º; 5º.
- **Resposta correta:** 4º grau (Fá).
- **Demonstração:** contando a partir da tônica: C=1, D=2, E=3, F=4.
- **Regra automática:** conferir tônica/modo, construir escala canônica, localizar a posição e validar opção única.
- **Possíveis ambiguidades:** grau escala e grau harmônico não são a mesma pergunta; definir se se espera número, nota ou acorde do grau.

#### H-2 — Qualidade de tríade grafada

- **Objetivo:** identificar qualidade de tríade em posição fundamental.
- **Nível:** 2.
- **Enunciado:** “Ouça a tríade em posição fundamental e identifique sua qualidade.”
- **Dados musicais:** notas G3–B3–D4 simultâneas, grafia explícita, temperamento igual, sem notas adicionais; intervalos a partir da fundamental.
- **Alternativas:** maior; menor; diminuta; aumentada.
- **Resposta correta:** tríade maior.
- **Demonstração:** G–B é terça maior (4 semitons); B–D é terça menor (3 semitons); conjunto G–B–D forma tríade maior. Em Dó maior, o acorde é V.
- **Regra automática:** verificar fundamental e disposição; calcular terças/grafia; validar conjunto sonoro e áudio; garantir que somente uma qualidade atende à definição.
- **Possíveis ambiguidades:** inversões e voicings podem manter a classe do acorde; a pergunta restringe posição fundamental. Timbre não deve mascarar a nota de terça.

#### H-3 — Função de ii7 sob convenção declarada

- **Objetivo:** associar o acorde ii7 à categoria funcional usada na lição.
- **Nível:** 4 (após tríades/tétrades e funções).
- **Enunciado:** “Na convenção desta atividade, qual função principal é atribuída a Dm7 em Dó maior, no contexto Dm7–G7–Cmaj7?”
- **Dados musicais:** tonalidade C maior; notas D–F–A–C para Dm7; sequência explícita ii7–V7–Imaj7; convenção: ii é predominante/subdominante, V dominante e I tônica.
- **Alternativas:** tônica; predominante/subdominante; dominante; sensível.
- **Resposta correta:** predominante/subdominante (ii7), nesta convenção.
- **Demonstração:** o acorde D–F–A–C é formado sobre o segundo grau; na taxonomia fixada pela lição, precede a dominante G7 e é classificado como predominante/subdominante.
- **Regra automática:** gerar escala e acorde grafado; confirmar ii7 e posições na progressão; consultar a taxonomia versionada do item; rejeitar alternativa duplicada semanticamente.
- **Possíveis ambiguidades:** terminologia e função podem variar conforme escola, frase, voicing e contexto. Sem a convenção e sequência, não apresentar como única resposta universal.

**Inválidos — harmonia:** (1) “Qual é o sétimo grau da escala menor?” sem especificar natural/harmônica/melódica; o gabarito pode mudar. Rejeitar como ambíguo. (2) Declarar C maior e marcar Fá sustenido–Lá–Dó como acorde IV diatônico sem indicar alteração/modal empréstimo; o conteúdo e o gabarito contradizem a escala. (3) Perguntar função de vii° com alternativas dominante e sensível, sem convenção contextual; bloquear ou aceitar ambas conforme rubrica.

## 7. Protocolo de aprovação de exercícios

Todo exercício passa por estados: `draft → machine_validated → independently_checked → pedagogy_reviewed → representation_checked → approved` ou `rejected` com motivo e possibilidade de correção. Guardar autor, versão do gerador/regra, fixtures, revisores, data e alterações.

1. **Validação da estrutura dos dados — automática.** Schema estrito; campos obrigatórios; tipos/enums; versão; IDs estáveis; opções, mídia e metadados presentes. Rejeitar chaves duplicadas, campos não reconhecidos e relações ausentes.
2. **Validação das regras musicais — automática + revisão de casos-limite.** Recalcular notas, intervalos, durações, métrica, escala, acorde e gabarito a partir da fonte canônica usando validador separado do gerador. Rodar fixtures douradas e propriedades/invariantes.
3. **Verificação independente do gabarito — obrigatória.** Segundo caminho determinístico de cálculo (p. ex. tabela/implementação de referência distinta) ou transcrição/checagem por especialista. Não aceitar como evidência a repetição do mesmo algoritmo, nem consenso entre modelos de IA.
4. **Unicidade de alternativas — automática.** Normalizar cada alternativa na dimensão avaliada (grafia, som, duração, ataques, função declarada). Exigir exatamente uma classe correta; deduplicar semanticamente, não só por ID/texto.
5. **Validação pedagógica do nível — automática + humana.** Verificar tags de pré-requisito, vocabulário, escopo e progressão; revisor confirma carga cognitiva, distratores plausíveis e alinhamento à aula. Casos fora do escopo bloqueiam publicação.
6. **Validação visual/sonora — automática + humana.** Comparar notação renderizada com os campos canônicos, rodar renderizadores em ambiente/navegador/fontes de referência; verificar áudio, pitches/eventos, sincronização, timbre, registro, volume e fallback. Exibir a fixture e coletar aprovação humana.
7. **Análise de ambiguidade — automática + humana.** Checklist: enarmonia, oitava, modo/escala, direção, métrica, agrupamento, contexto, terminologia, cultura, versão de obra e mais de uma análise defensável. Registrar respostas equivalentes aceitas ou rejeitar o item.
8. **Aprovação ou rejeição justificada.** Aprovação requer rastreabilidade e assinaturas necessárias. Rejeição inclui regra/teste falho ou motivo editorial; não é corrigida silenciosamente pelo modelo gerador.

### Divisão de responsabilidade

- **Automatizar:** schema, aritmética racional, derivação de pitch, intervalos, escala/acorde formal, total de compasso, parser estrito, checksum/consistência da mídia, opções equivalentes, fixtures, renderizações de referência e bloqueios.
- **Revisão humana obrigatória:** adequação ao nível, clareza, notação editorial complexa, som/timbre na prática, qualidade pedagógica, terminologia harmônica escolhida, história/cultura, repertório, direitos e interpretações de forma/estilo.
- **Bloquear sem exceção:** dados musicais incompletos; resposta divergente; áudio/visual incompatível; alternativas semanticamente duplicadas; múltiplos gabaritos não declarados; escala ou convenção ausente; fato editorial sem fonte; exercício fora do recorte curricular publicado.

## 8. Integração com IA

A IA pode recomendar assuntos e revisões usando evidência por habilidade (acerto/erro, dificuldade, tempo, tentativas e recência), sugerir variações dentro de uma faixa autorizada, rascunhar explicações e apontar padrões de erro. Deve receber parâmetros do motor determinístico — resposta oficial, derivação, convenção, nível e fonte — e não poder sobrescrevê-los.

Controles recomendados:

- motor musical determinístico gera/valida o gabarito; IA explica o porquê usando esses dados;
- saídas da IA são rascunhos versionados, não publicação imediata; validação de consistência antes de exibir;
- adaptar por competência observada, não por número bruto de sessões; manter confiança, amostra mínima, decaimento/recência e opção de repetição;
- variação de dificuldade só pode selecionar conteúdos permitidos pelos pré-requisitos e nível;
- registrar explicação, prompt/modelo/versão, fontes e avaliação humana quando for conteúdo factual;
- medir desempenho e viés da recomendação por repertório, locale, instrumento e nível;
- não usar concordância entre modelos como prova; dois modelos podem repetir a mesma convenção errada ou erro de origem.

## 9. Recomendações priorizadas para o MVP

### P0 — antes de ampliar o banco ou usar gabarito para nivelamento

1. Aprovar uma taxonomia de competências por nível, pré-requisitos e objetivos mensuráveis. Impedir que contagem de atividades ou `mixed` contorne essa taxonomia.
2. Definir schema canônico para grafia/altura, duração/métrica, áudio, convenções, nível e respostas aceitas.
3. Corrigir conceitualmente a validação rítmica: parser estrito, duração exata, agrupamento e unicidade de projeção auditiva.
4. Criar fixtures de referência independentes para claves/armaduras/posições, intervalos, acordes, compassos e áudio; usar pelo menos dois caminhos determinísticos de conferência, sem depender de consenso de IA.
5. Provar correspondência entre dados e representação visual/sonora com casos-limite, incluindo linhas suplementares, acidentes, registro, silencios e fallback de áudio.
6. Restringir MVP a um recorte publicado: Leitura com claves/posições explicitadas; Rítmica monofônica 4/4 e valores efetivamente representados; Percepção melódica com intervalos selecionados por nível; Harmonia maior/posição fundamental com convenções claras. O que não está implementado deve ficar fora da avaliação.

### P1 — expansão curricular controlada

7. Implementar especificação e validação para pausas/durações pontuadas, ligaduras, compassos simples/compostos, síncopa, quiálteras e vozes em etapas testáveis.
8. Introduzir intervalos harmônicos, padrões, escalas e solfejo somente com referência tonal, registro e objetivo definidos.
9. Adicionar menor natural/harmônica/melódica, inversões, voicings, campo harmônico menor e cadências como competências separadas, cada qual com fixtures.
10. Substituir o estágio por contagem de tentativas por progressão baseada em desempenho por habilidade e revisão espaçada.

### P2 — publicação editorial e personalização

11. Construir catálogo versionado com fontes e revisão especializada para Apreciação/História; incluir contextos brasileiros e internacionais sem tratar repertório familiar como universal.
12. Incorporar IA apenas como recomendadora/explicadora supervisionada pelo motor e pelo catálogo editorial.
13. Fazer QA de acessibilidade, tradução pt-BR/en-US, pronúncia/termos, direitos de áudio e diferenças culturais.

## 10. Referências internas examinadas

- Visão de produto e currículo: `README.md:70-252`; trilhas e níveis: `app/controllers/platform_controller.rb:34-278`.
- Progressão por atividades: `app/controllers/platform_controller.rb:391-399`; `app/controllers/student_hub_controller.rb:209-218`.
- Leitura e notação: `app/services/reading_note_exercise_generator.rb:14-147`, `:148-152`, `:301-385`; `app/services/reading_staff_svg_renderer.rb:28-109`, `:133-167`.
- Rítmica e parser: `app/services/rhythm_exercise_generator.rb:10-88`, `:106-148`, `:241-310`; reprodução: `app/javascript/controllers/rhythm_player_controller.js:71-105`, `:127-139`.
- Percepção e áudio: `app/services/perception_interval_exercise_generator.rb:32-58`, `:95-179`; reprodução: `app/javascript/controllers/interval_player_controller.js:130-176`, `:280-318`.
- Harmonia: `app/services/harmony_exercise_generator.rb:15-99`, `:207-424`, `:445-529`.
- Cobertura dos testes observados: `test/services/reading_note_exercise_generator_test.rb`, `test/services/reading_staff_svg_renderer_test.rb`, `test/services/rhythm_exercise_generator_test.rb`, `test/services/perception_interval_exercise_generator_test.rb`, `test/services/harmony_exercise_generator_test.rb`.

**Encerramento:** este documento é uma auditoria e proposta de regras. Nenhuma recomendação foi aplicada ao código nem ao currículo. O trabalho para aqui, aguardando autorização antes de qualquer implementação.
