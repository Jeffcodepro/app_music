# Dificuldade de Percepção, Harmonia e ditados

Implementação local de 20/10/2026. Esta matriz é uma decisão editorial de treino motivada pelo pedido de níveis 1–4. Não altera o nível do aluno, o diagnóstico de domínio ou a pontuação. O seletor fica em **Configurar treino → Dificuldade do conteúdo**. Treino livre preserva as questões anteriores sem perfil; retornar à página mantém a atribuição e a dificuldade selecionada.

| Nível | Intervalos | Harmonia | Ditado melódico |
| --- | --- | --- | --- |
| 1 | M2, M3, P4, P5 e P8 | Dó maior, tríades em posição fundamental; qualidade e graus I, IV, V, VI | Uma voz, quatro semínimas, um compasso |
| 2 | Onze intervalos simples já existentes, até oitava | Dó/Sol/Fá maior, sete graus, tríades; acrescenta funções | Uma voz, 6–8 notas, semínimas e colcheias, um compasso |
| 3 | Simples e compostos até 12ª justa | Acrescenta Ré/Si♭ maior e tétrades; progressões I–IV–V–I e II–V–I–VI | Duas vozes, 10–12 notas por voz, dois compassos, semínimas e colcheias |
| 4 | Os 22 intervalos existentes, até duas oitavas | Acrescenta Lá/Mi♭ maior, cinco progressões existentes e inversões | Três ou quatro vozes, 12–16 notas por voz, dois compassos, incluindo semicolcheias |

Intervalos mantêm direção ascendente/descendente/mista e os instrumentos existentes. Distratores e fallback por recência permanecem no conjunto do nível. Não foram adicionados novos tipos de intervalo.

Harmonia mantém a convenção `major-functions-legacy-v1`; sua revisão pedagógica continua pendente. Níveis 1–3 usam posição fundamental; no 4 cada acorde tem uma inversão sorteada entre as não fundamentais. O grau e a qualidade continuam definidos pela fundamental original, independentemente da nota mais grave. O áudio e a inversão são persistidos integralmente para a reabertura não sortear outro voicing. Se a redução do nível tornar a modalidade/estrutura incompatível, a tela informa o ajuste para misto/tríade.

## Contrato dos ditados `voices-v2`

São quatro partituras alternativas, selecionáveis diretamente, com no máximo duas pautas. Duas vozes na mesma clave compartilham a pauta: a superior usa hastes para cima e a inferior, para baixo. Três vozes usam duas na clave de Sol e uma na de Fá; quatro usam duas em cada clave. As alternativas compartilham colunas temporais, largura e margens, incluindo deslocamento de uníssonos/segundas simultâneos. Áudio e alternativas compartilham eventos explícitos de altura, início e duração. O backend compara a projeção sonora global, ignorando a ordem/identificador das vozes ao detectar alternativas equivalentes, e verifica também a identidade exata de cada linha.

Nesta etapa: Dó maior, alturas naturais, 4/4 e semínima a 80 BPM. Uma semínima equivale a quatro passos; cada compasso tem 16 passos. Cada linha começa em Dó da sua oitava, sem nota de referência extra nem segunda execução automática. Registros: uma voz C4–B4; duas C4–B4/C3–B3, exceto flauta/clarinete, que usam C5–B5/C4–B4 na mesma pauta de Sol; três C5–B5/C4–B4/C3–B3; quatro C5–B5/C4–B4/C3–B3/C2–B2. Por decisão expressa do responsável pelo produto, novos ditados de três ou quatro vozes usam apenas piano. Cada linha é diferente das outras mesmo após remover a oitava. Não se afirma que essas linhas sejam uma composição contrapontística.

Níveis 1–2 limitam saltos a duas posições diatônicas; 3–4, a três. Não há repetição imediata da mesma altura. O nível 4 inclui pelo menos uma semicolcheia por voz. Não há pausas, ligaduras, síncopa, quiálteras ou mudanças de compasso nesses ditados. A matriz de compassos do treino rítmico continua independente; não se apresenta uma opção ainda indisponível no ditado.

O formato anterior de quatro notas (`audio_sequence`) e as atribuições `voices-v1` continuam válidos, com suas assinaturas e registros originais. A reabertura de uma atribuição v1 pendente não troca o instrumento nem recria a questão. Novas questões usam `voices-v2`, `audio_events`, `voice_count`, `total_steps` e `bpm_unit_steps`. Formatos desconhecidos, tempos incompletos, frequência divergente, linhas por oitava duplicadas e alternativas equivalentes são rejeitados antes da atribuição/pontuação. Nenhuma migration foi necessária.

## Reprodução e interação

As vozes usam uma única origem temporal nos dois motores. Há ganho `1/quantidade_de_vozes` sobre a configuração de uma nota para reservar margem de soma. A prontidão só é marcada após o trecho completo e a cauda de áudio. Falhas mantêm o envio bloqueado e não geram erro de conhecimento. Após uma resposta errada, a escuta concluída da mesma atribuição/instrumento permanece válida durante a navegação Turbo: o aluno pode tentar outra partitura sem ouvir novamente. Esse registro fica apenas em memória, limitado a 128 chaves; nova atribuição, mudança de instrumento ou falha de uma nova reprodução exigem nova escuta. Repetir conserva a atribuição; depois do acerto, Próximo e tocar cria outra e toca uma vez, preservando dificuldade e instrumento.

Pautas extensas mantêm tamanho mínimo de leitura em regiões roláveis com foco de teclado no mobile. Cada botão contém a partitura; a região externa recebe o foco e as setas para rolar sem responder. A seleção pode ser feita por clique na pauta ou foco no botão e Enter. Não há rótulo visual “Opção”; nomes acessíveis distinguem as quatro respostas. Sol/Fá usam contornos com [proveniência e licença](licenses/treble-clef.md).

## Timbres e registro instrumental

Mantido Soundfont Player com MusyngKite/mp3: `acoustic_grand_piano`, `flute`, `clarinet`, `acoustic_guitar_nylon` e `church_organ`. A mudança de drawbar para órgão de tubos é uma decisão editorial para o timbre de órgão neste treino. O tempo de espera das amostras passa a dez segundos, com envelope curto que preserva o ataque gravado. Quando houver contingência por síntese, a interface informa que o timbre é aproximado; não o apresenta como som instrumental realista.

Novos intervalos e acordes instrumentais usam janelas conservadoras de alturas de concerto: piano MIDI 21–108, flauta 60–96, clarinete 52–91, violão 40–83 e órgão 24–108. São limites deste treino, não a extensão extrema de todo instrumento ou instrumentista. A notação representa a altura ouvida; não são partes transpostas para clarinete/violão. Em intervalos, referência e alvo devem caber juntos na janela, mantendo tipo e direção do intervalo.

Em Harmonia, cada acorde pode ser deslocado inteiro por oitavas (`register_offset` em 0, ±12 ou ±24 semitons), sem alterar sua qualidade, grau ou inversão. O deslocamento é aplicado a todas as notas e frequências persistidas; não ocorre transposição escondida apenas no player. Isso pode alterar o contorno de registro entre acordes de uma progressão, decisão necessária para manter cada acorde no registro instrumental escolhido. O validador recalcula a estrutura e confere o deslocamento e a janela. Piano conserva os dados anteriores. O marcador `concert-register-v1` identifica o contrato novo; atribuições antigas sem o marcador continuam sob seu contrato original.

Validação musical/pedagógica humana da progressão e escuta acústica em dispositivos reais continuam recomendadas antes de avaliações oficiais. Os testes locais não medem aprendizagem ou percepção auditiva humana.
