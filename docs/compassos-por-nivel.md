# Compassos por nível — contrato implementado

20/10/2026. O responsável aprovou a matriz de quatro níveis e dois compassos no Pulso 2/4. Esta etapa a implementa no playground de **Rítmica**, com quatro partituras por questão. A proposta histórica permanece em `proposta-compassos-por-nivel.md`.

## Catálogo cumulativo

| Nível de conteúdo | Fórmulas acrescentadas | Pulsação/BPM |
| --- | --- | --- |
| 1 | 2/4, 3/4, 4/4 | Semínima, 60–84 |
| 2 | 2/2, 3/8, 6/8 | 2/2: mínima; 3/8: três colcheias, 60–96; 6/8: semínima pontuada, 48–72 |
| 3 | 3/2, 4/2, 2/8, 4/8, 9/8, 12/8, 6/4, 9/4, 12/4, 6/16, 9/16, 12/16 | Simples: figura do denominador; compostos: grupos de três. 52–84 |
| 4 | 5/4, 7/4; 5/8, 7/8, 8/8, 10/8, 11/8, 13/8; equivalentes desses seis últimos em /16 | Aditivos: unidade menor com acentos nos grupos. /4: semínima 60–90; /8: colcheia 120–180; /16: semicolcheia 120–180 |

Total: **32 fórmulas e 41 configurações**, incluindo variantes de agrupamento. São 3 configurações no nível 1, 6 no 2, 18 no 3 e 41 no 4. Os andamentos pertencem ao compasso de introdução; selecionar nível maior não acelera automaticamente os anteriores.

Nos compostos, a unidade de BPM é mínima pontuada em /4, semínima pontuada em /8 e colcheia pontuada em /16. 3/8 permanece simples, contado em três colcheias. C e C cortado usam as fórmulas numéricas 4/4 e 2/2; não foram acrescentados glifos alternativos nesta etapa.

Agrupamentos explícitos dos aditivos:

| Numerador | Grupos disponíveis |
| --- | --- |
| 5 | 2+3 e 3+2 |
| 7 | 2+2+3, 2+3+2 e 3+2+2 |
| 8 | 3+3+2 |
| 10 | 3+3+2+2 |
| 11 | 3+3+3+2 |
| 13 | 3+3+3+2+2 |

Os agrupamentos de 8, 10, 11 e 13 e o andamento de /16 concretizam pontos que a proposta deixava em aberto. São escolhas editoriais iniciais, registradas aqui; não representam todas as interpretações dessas fórmulas.

## Modos, duração e publicação

- **Pulso:** um evento escrito por grupo, nota ou pausa, mínimo de dois ataques no trecho. Em fórmulas de dois grupos, são **dois compassos reais**, tocados uma vez. A solução aprovada para 2/4 foi estendida a 2/2, 2/8, 6/8, 6/4, 6/16 e variantes aditivas de dois grupos. Isso garante quatro alternativas sem reduzir o mínimo de ataques. A tela indica dois compassos e a pauta mostra a barra interna.
- **Subdivisão:** pelo menos um grupo repartido em dois ou mais eventos escritos.
- **Precisão:** pelo menos dois grupos repartidos em dois ou mais eventos escritos. Este contrato novo difere do critério legado de três eventos por grupo: permite /16 sem introduzir fusas implicitamente. A dificuldade não é uma promessa de progressão automática.
- **Misto:** sorteia um dos três modos, mas conserva a preferência Misto ao recarregar, voltar pelo menu e retomar pelo dashboard.
- Síncopa continua indisponível. Não há ligaduras atravessando grupos/barras, quiálteras, fusas, compassos alternados, polimetria ou métrica livre.

Grade exata: 16 unidades por semibreve. Figuras disponíveis: semibreve, mínima, semínima, colcheia, semicolcheia e versões pontuadas de mínima/semínima/colcheia, com pausas. Cada grupo e cada barra precisam fechar exatamente. No máximo 24 figuras por alternativa. Espaços pequenos são enumerados integralmente até 4.096 combinações; nos demais, até 400 candidatos são sorteados para encontrar quatro projeções de ataques distintas. Se isso falhar, nenhuma atribuição é publicada. Recência é preferida quando há combinações disponíveis; não torna impossível repetir um catálogo finito.

O validador recalcula duração, agrupamento, semântica do modo, ataques, gabarito e assinatura a partir dos dados. O catálogo é uma política editorial compartilhada; cálculos e validação não chamam os predicados musicais do gerador. Campos temporais exigem inteiros, inclusive em payloads com assinatura recalculada.

## Reprodução e notação

Um compasso de entrada seguido de **uma execução integral do trecho** por clique. Simples marcam a unidade indicada; compostos marcam os pulsos pontuados; aditivos marcam unidades menores e acentuam inícios de grupo. Pausas finais integram a duração. Repetir faz outra execução. Alterar configuração interrompe o áudio e invalida a prontidão da rodada anterior.

Renderer: fórmula real, barras internas, pontos de aumento, cabeças abertas para mínimas/semibreves, pausas correspondentes e barras de colcheias/semicolcheias limitadas aos grupos. Partituras densas mantêm o tamanho das figuras; em telas estreitas podem ser percorridas horizontalmente, inclusive por teclado, sem provocar rolagem horizontal da página. O botão de resposta fica separado da região percorrível.

## Compatibilidade e limites

O formato novo é `meter-v1`. Atribuições antigas de 4/4 continuam no parser/gerador/contrato anterior. Sem configurar nível/compasso, um fluxo legado pode continuar em 4/4; selecionar o compasso nas configurações ativa o formato novo. A identidade, validação na emissão, tentativas e crédito transacional continuam nos serviços existentes. Nenhuma migration ou mudança de regra de XP foi necessária.

Nível de conteúdo é selecionável, independente do plano e do nível do estudante. Não mede domínio nem implementa nivelamento. O ditado melódico continua com uma voz e quatro semínimas em 4/4; compassos variados para melodias e duas a quatro vozes exigem outra etapa. Esta entrega não afirma cobrir todas as fórmulas matematicamente possíveis.

## Evolução: dificuldade das estruturas e compasso Misto

Na revisão de 20/10/2026, o responsável esclareceu que o nível deve alterar a estrutura escrita, além do catálogo de compassos. Novas rodadas acrescentam `complexity_version: level-structure-v1` e `requested_meter_id` ao formato `meter-v1`. Payloads anteriores sem esses dois campos continuam nas regras anteriores, com fixture literal preservada; campos parciais ou versões desconhecidas são rejeitados.

| Nível | Repertório de partições por grupo | Exigência em Subdivisão e Precisão |
| --- | --- | --- |
| 1 | Grupo inteiro ou duas partes iguais, quando a grade permite | Ao menos um grupo em duas figuras |
| 2 | Acrescenta três partes iguais nos grupos divisíveis por três e combinações metade+quarto+quarto / quarto+quarto+metade nos divisíveis por quatro; não introduz pausa de uma unidade mínima | Ao menos um grupo com três figuras, limitado às partições possíveis na grade |
| 3 | Acrescenta quatro ou seis partes iguais, incluindo pausas na subdivisão fina | Ao menos um grupo com quatro figuras, limitado à grade |
| 4 | Acrescenta combinações longa+curta e curta+longa de uma unidade mínima quando válidas | Além da densidade, dois motivos distintos e pelo menos uma pausa no interior do trecho |

Todas as durações precisam corresponder às figuras já disponíveis. Precisão também conserva dois grupos subdivididos. A pausa interna significa um evento escrito que não é o primeiro nem o último do trecho; não precisa estar no interior de um pulso. Motivos distintos consideram duração e nota/pausa. As exigências incidem sobre todas as alternativas e são recalculadas pelo validador.

Em 4/4, um grupo de quatro unidades permite `[4]` e `[2,2]` no nível1; `[2,1,1]` e `[1,1,2]` no2; `[1,1,1,1]` no3; o4 acrescenta `[3,1]` e `[1,3]`, variedade e pausas. Essas são decisões editoriais verificáveis, não uma classificação universal de dificuldade.

Pulso permanece uma figura por grupo em todos os níveis: o desafio vem do compasso, agrupamento e distribuição dos ataques/pausas. Unidades /16 impõem o limite físico da grade; não são introduzidas fusas ou quiálteras para forçar dificuldade. Síncopa continua bloqueada.

No seletor de Compasso, Misto resolve uma fórmula apenas ao emitir outra questão. Sorteia primeiro a fórmula e depois seu agrupamento, evitando favorecer fórmulas com mais variantes; prefere uma fórmula diferente da rodada anterior. Usa o catálogo cumulativo do nível selecionado. O payload guarda a fórmula efetiva e a preferência Misto separadamente. Recarregar, navegar de volta e errar não resorteiam; acertar ou solicitar outra rodada permite novo sorteio. O Misto dos tipos de atividade continua independente.

Resultados e limitações atuais: [conta-calendario-dificuldade-resultados.md](conta-calendario-dificuldade-resultados.md).

Validação executada, capturas, comandos e pendências acústicas estão em [dashboard-ditado-compassos-resultados.md](dashboard-ditado-compassos-resultados.md).
