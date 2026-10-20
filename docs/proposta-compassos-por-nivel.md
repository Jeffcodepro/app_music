# Proposta para aprovação — compassos e níveis 1–4

**Estado: aprovada pelo responsável em 20/10/2026 e implementada no playground de Rítmica.** A confirmação incluiu dois compassos no modo Pulso em 2/4. O texto abaixo preserva a proposta original; o contrato efetivamente implementado e suas decisões complementares estão em [compassos-por-nivel.md](compassos-por-nivel.md). O nível musical é independente do plano de assinatura. Não há progressão automática por quantidade de atividades.

## Matriz inicial

| Nível | Compassos a disponibilizar | Organização da pulsação | Andamento inicial proposto |
| --- | --- | --- | --- |
| 1 — Pulso | 2/4, 3/4, 4/4 | Semínima como pulso; ataques e pausas, depois subdivisão binária | Semínima = 60–84 BPM |
| 2 — Subdivisão | Anteriores + 2/2, 3/8, 6/8 | 2/2: mínima; 3/8 inicialmente contado em três colcheias; 6/8: 3+3, dois pulsos de semínima pontuada | Simples: unidade indicada = 60–96; 6/8: semínima pontuada = 48–72 BPM |
| 3 — Compostos e unidades | Anteriores + 3/2, 4/2, 2/8, 4/8, 9/8, 12/8; equivalentes 6/4, 9/4, 12/4 e 6/16, 9/16, 12/16 | Simples com pulso da unidade indicada; compostos em grupos de três. /4 composto: mínima pontuada; /8 composto: semínima pontuada; /16 composto: colcheia pontuada | Pulsação indicada = 52–84 BPM; variantes lentas/rápidas dependem da escuta e legibilidade |
| 4 — Irregulares e aditivos | Anteriores + 5/8, 7/8, 5/4, 7/4; depois 8/8, 10/8, 11/8, 13/8 e equivalentes em /16 | Agrupamento explícito: 5 = 2+3 ou 3+2; 7 = 2+2+3, 2+3+2 ou 3+2+2. As demais fórmulas exigem grupos declarados, nunca inferidos apenas do numerador | /8: colcheia = 120–180; /4: semínima = 60–90; grupos recebem acentos |

C e C cortado são representações de 4/4 e 2/2, sem criar categorias de dificuldade separadas. A interpretação de 3/8 é explicitada por exercício: três colcheias nesta introdução; um pulso pontuado só em uma atividade posterior que ensine essa leitura.

“Todas as fórmulas” será atendido por uma representação extensível, além do catálogo acima: numerador, denominador, agrupamento, unidade de BPM e número de compassos. Não existe uma lista finita de todas as combinações, e nem toda combinação é pedagogicamente útil. Novas combinações serão adicionadas com referência sonora, notação, alternativas distintas e revisão. Compassos mistos entre barras, polimetria, unidades não convencionais e métricas livres precisam de especificação própria; esta proposta não os habilita implicitamente.

## Reprodução e quatro alternativas

- Uma contagem de entrada de um compasso e **uma execução do trecho por clique**. “Repetir” inicia outra execução.
- Simples: marcar os pulsos da unidade indicada; compostos: marcar os pulsos pontuados; irregulares: marcar a unidade menor com acentos no início dos grupos. Mostrar a figura da unidade ao lado do BPM.
- Duração e posição dos ataques calculadas por valores exatos; 3/4 e 6/8 não se tornam equivalentes por terem a mesma duração de escrita. Notação/acentos/agrupamentos devem acompanhar o áudio.
- Em **Pulso 2/4**, com pelo menos dois ataques e somente semínimas/pausas, há uma única combinação de um compasso. **Recomendação: usar dois compassos para esse exercício**, oferecendo quatro posições e quatro alternativas distintas. Alternativa: bloquear essa combinação de modo e compasso. Não liberar silêncio completo nem alterar os mínimos sem decisão explícita.
- Se não houver quatro alternativas auditivamente distintas, não emitir a questão. Compassos com pausas finais também precisam de duração integral no player.
- Síncopa continua bloqueada até sua revisão específica. Compassos complexos não liberam esse modo automaticamente.

## Ditados e progressão

Nesta entrega, o ditado melódico autorizado começa com uma voz, quatro semínimas em 4/4, Dó maior, referência inicial Dó4 comum a todas as opções, quatro partituras e um único trecho por clique. O ditado rítmico mantém o formato atual de quatro partituras. A introdução musical é registrada aqui; não equivale a atribuir um nível ao aluno.

Após a aprovação, aplicar a matriz gradualmente aos ditados e exercícios existentes. Densidade rítmica, pausas, extensão melódica, memória, andamento e número de vozes são dimensões distintas de dificuldade. Duas a quatro vozes exigem especificação adicional, validação de vozes equivalentes/uníssonos, timbres e legibilidade.

## Implementação posterior à aprovação

1. Introduzir objeto musical de compasso e agrupamento, com fixtures independentes.
2. Adaptar gerador, parser/validador, renderer, transporte e serialização como um contrato único; preservar atribuições antigas de 4/4.
3. Testar barras completas, número de alternativas, acentos, duração real, fallback e contagem de entrada para cada fórmula habilitada.
4. Revisar pedagogicamente critérios de acesso/progressão; não inventar aprovação ou nivelamento automático.

## Decisões solicitadas

Aprovar ou ajustar a matriz dos quatro níveis; confirmar dois compassos no Pulso 2/4; confirmar unidade de BPM, andamentos e contagem inicial. Essa aprovação será a entrada de uma etapa posterior, não uma alteração automática nesta entrega.

As distinções teóricas entre simples, compostos e aditivos foram conferidas nas referências [Open Music Theory — Meter](https://open-musictheory.github.io/docs/fundamentals/meter/), [Compound Meter and Time Signatures](https://pressbooks.nebraska.edu/openmusictheory/chapter/compound-meters-and-time-signatures/) e [Twentieth-Century Rhythmic Techniques](https://viva.pressbooks.pub/openmusictheorycopy/chapter/twentieth-century-rhythmic-techniques/). A sequência de níveis e faixas de BPM acima são propostas próprias, não prescrições dessas fontes.
