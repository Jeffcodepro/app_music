# Modelo musical canônico — notas e intervalos

`MusicTheory::Note` e `MusicTheory::Interval` são objetos Ruby imutáveis, sem Active Record, banco ou dependência de Rails. A organização em `step`, `alter` e `octave` distingue grafia de altura, como no [MusicXML](https://www.w3.org/2021/06/musicxml40/musicxml-reference/elements/pitch/); não implementamos um leitor ou exportador desse formato.

## Note

```ruby
note = MusicTheory::Note.new(step: "F", alter: 1, octave: 4)
note.to_h        # { step: "F", alter: 1, octave: 4 }
note.to_s        # "F#4", ASCII
note.spelling    # "F♯4", Unicode compatível com os payloads existentes
note.midi        # 66
note.frequency   # aproximadamente 369.9944227116 Hz
note.with_alter(0) # outro valor, F4; não modifica note
```

| Operação | Contrato |
| --- | --- |
| `new(step:, octave:, alter: 0)` | Letra maiúscula A–G em string, alteração inteira de −2 a +2 e oitava inteira |
| `.parse(string)` | Nota completa com oitava; aceita `#`, `##`, `b`, `bb`, `♯`, `♭`, `𝄪`, `𝄫` e `♮` |
| `step`, `alter`, `octave` | Identidade escrita; a oitava continua pertencendo à grafia original |
| `diatonic_index` | Índice contínuo `octave * 7 + índice C..B`, em passos diatônicos |
| `midi` | Altura inteira resultante, limitada a 0–127 |
| `frequency(a4: 440.0)` | Frequência em temperamento igual de 12 semitons, sem arredondamento |
| `same_spelling?(other)` | Compara letra, alteração e oitava |
| `same_pitch?(other)` | Compara altura MIDI sob a mesma afinação de referência |
| `==`, `eql?`, `hash` | Igualdade de valor pela identidade escrita |
| `to_h`, `to_s`, `spelling` | Campos, ASCII e Unicode; não incluem estado de pauta |

O parser rejeita espaços, texto parcial, letras minúsculas, acidentes misturados/triplos e microtons. O construtor não converte silenciosamente tipos. Argumentos inválidos produzem `ArgumentError`. `F♮4` representa `F, 0, 4`; a impressão do bequadro pertence ao contexto de notação, não à identidade da altura.

```text
midi = 12 * (octave + 1) + semitom_natural(step) + alter
frequency = a4 * 2 ** ((midi - 69) / 12.0)
```

Convenções do projeto: C4 = MIDI 60 e A4 = MIDI 69 = 440 Hz. B♯3 e C4 preservam grafias diferentes e têm MIDI 60; C♭4 tem MIDI 59. O limite se aplica ao resultado MIDI, permitindo inclusive B♯−2 como MIDI 0.

Na afinação padrão, MIDI 0–127 produz aproximadamente **8,1758–12.543,854 Hz**. A referência A4 alternativa deve ser numérica, real, positiva e finita. O resultado também deve ser positivo, finito e **≤ 20.000 Hz**, limite operacional compartilhado com o player de intervalo. Overflow e underflow para zero são recusados. Essa validação não garante audibilidade ou suporte em cada dispositivo.

Afinação não é um campo de `Note`. `same_pitch?` pressupõe a mesma referência para ambos os valores. Os playgrounds continuam em 440 Hz; `frequency(a4: 442)` é somente uma conversão numérica e não reafina o soundfont da interface.

```ruby
first = MusicTheory::Note.parse("F#4")
second = MusicTheory::Note.parse("Gb4")
first.same_pitch?(second)    # true
first.same_spelling?(second) # false
first == second             # false
```

## Interval

```ruby
interval = MusicTheory::Interval.new(
  from: MusicTheory::Note.parse("C4"), to: MusicTheory::Note.parse("E#4")
)
interval.number             # 3
interval.diatonic_steps     # 2
interval.chromatic_steps    # 5
interval.semitones          # 5
interval.quality            # :augmented
interval.written_direction  # :ascending
interval.sounding_direction # :ascending
interval.shorthand          # "A3"
interval.name               # "augmented third"
```

O número considera distância diatônica inclusiva; a qualidade considera também semitons. Terça aumentada e quarta justa podem ter cinco semitons sem serem o mesmo intervalo escrito. As relações de qualidade e composição são descritas em [Steps to Music Theory, capítulo 9](https://odp.library.tamu.edu/stepstomusictheory/chapter/more-intervals/).

| Operação | Contrato |
| --- | --- |
| `new(from:, to:)` | Exige dois valores `MusicTheory::Note` |
| `from`, `to` | Extremidades escritas, preservando a ordem |
| `diatonic_steps`, `chromatic_steps` | Distâncias com sinal, em passos diatônicos e semitons |
| `number`, `semitones` | Número inclusivo e módulo da distância cromática |
| `quality` | `:perfect`, `:major`, `:minor`, `:augmented` ou `:diminished` |
| `written_direction`, `sounding_direction` | Cada uma retorna `:ascending`, `:descending` ou `:stationary` |
| `compound?` | Verdadeiro para número maior que 8 |
| `simple_number` | Redução preservando oitavas: 9→2, 15→8; uníssono→1 e oitava→8 |
| `name`, `shorthand` | Nome inglês e abreviatura compatíveis com metadados existentes |
| `==`, `eql?`, `hash` | Igualdade pelas extremidades ordenadas, não só por qualidade/número |

Convenções explícitas desta API:

- C4→C4 é uníssono justo; as duas direções são estacionárias.
- C4→C♯4 e C♯4→C4 são uníssonos aumentados. A escrita permanece na mesma posição; a direção sonora distingue subida/descida. Não se usa a designação “uníssono diminuto”.
- C♯4→D♭4 e B♯3→C4 são segundas diminutas: escrita ascendente e som estacionário. Inverter a ordem inverte a direção escrita e preserva a qualidade.
- São suportados números 1–15, até a décima quinta escrita, com qualidades justa/maior/menor e aumentada/diminuta simples. Isso não acrescenta categorias às alternativas do playground.
- Qualidades duplamente aumentadas/diminutas, números acima de 15 e movimento escrito/sonoro em sentidos opostos são recusados com `Interval::Unsupported < ArgumentError`. Exemplo de movimento cruzado: C𝄪4→D♭4.
- Acidentes duplos em notas são suportados, mesmo que algumas combinações produzam intervalos ainda não suportados. C4→E𝄫4 é uma terça diminuta válida.

## Notação e integração

Alteração cromática e glifo impresso são conceitos distintos; o [MusicXML também separa o acidente notado](https://www.w3.org/2021/06/musicxml40/musicxml-reference/elements/accidental/). Não há ainda memória de acidentes por compasso, cancelamento por armadura, acidentes de precaução ou transposição de instrumentos no núcleo.

O payload legado de Leitura guarda `pitch_name` como posição natural na pauta e `note_accidental_id` como símbolo da nota isolada. Esse contrato foi preservado:

```ruby
exercise = { question_type: "accidental", pitch_name: "F4", note_accidental_id: "sharp" }
ExercisePresentation.reading_note(exercise).to_h
# { step: "F", alter: 1, octave: 4 }
# pitch_name continua "F4"; o SVG desenha ♯ pelo ID separado.
```

O adaptador atende somente aos modos atuais `note_name` e `accidental`, sem resolver contexto geral de notação. Recusa armaduras sem nota e `pitch_name` legado já alterado. Um bequadro explícito continua no ID/símbolo, embora a nota resultante tenha `alter: 0`.

Leitura transforma posições da clave em `Note`, usa seu `step` e aplica a alteração real nos exercícios de acidentes. Percepção transforma transposições em `Note`, calcula frequências e classifica com `Interval`; recusa resultados incompatíveis com o intervalo/direção escolhidos. A localização pt-BR está em `ExercisePresentation.pitch_label`.

`HeadMusic` 12.3.0 permanece fornecendo claves e transposições. Os adaptadores preservam hashes, IDs, ordem aleatória, strings Unicode, assinaturas e arredondamento de três casas das frequências. Não há novo payload canônico persistido.

O validador usa o parser canônico para validar campos, mas recalcula MIDI, posição, distâncias e qualidade do currículo existente por aritmética independente. Não confia em `correct_option_id`, em `Interval#quality` nem no resultado da transposição. Essa redundância deliberada de verificação é coberta por referências literais independentes de `HeadMusic`.

O player de intervalo valida frequências em ambos os caminhos e antes de criar tons. A normalização para soundfont preserva mudanças de oitava e rejeita MIDI fora de 0–127. Falhas mantêm feedback neutro e não liberam a resposta como reprodução concluída. Rítmica e Harmonia conservam seus contratos.

## Próximas extensões

Durações devem usar valores racionais e uma unidade explícita; compassos precisam representar agrupamentos e acentos. Acordes/escalas podem compor notas escritas e intervalos, mantendo contexto tonal, grafia e referência sonora separados. Um futuro resolvedor de acidentes deve representar armadura e estado por compasso antes de decidir glifos. Essas extensões exigem referências musicais e decisões próprias de compatibilidade; não foram implementadas nesta missão.
