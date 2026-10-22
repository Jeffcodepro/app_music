# Contornos das claves dos ditados

`MelodicDictationSvgRenderer::TREBLE_CLEF_PATH` é um desenho AppMusic derivado do contorno Bravura `gClef`, copyright © Steinberg Media Technologies GmbH, sob SIL Open Font License 1.1. Não foi instalada uma fonte nem incorporada uma biblioteca.

Mesma fonte de proveniência já usada nas pausas rítmicas: [Bravura no VexFlow](https://github.com/0xfe/vexflow/blob/master/src/fonts/bravura_glyphs.ts), cópia obtida em 19/10/2026 e conferida em 20/10/2026, SHA-256 `4fdbab2c5e664be081003540ffd86a21cdc195f51a022c372fe721ccdcdd1647`. A extração usa apenas `gClef`. Comandos absolutos `m`/`l` são convertidos para `M`/`L`; em `b`, o ponto final é movido para depois dos dois controles para formar `C` SVG. `z` vira `Z`.

O contorno mantém a origem musical em Sol4. Sua grade usa 360 unidades por espaço da pauta; o renderer aplica escala `16/360`, inverte o eixo Y e desloca a origem para `(44,106)`, segunda linha de baixo da pauta com linhas em 58, 74, 90, 106 e 122. Isso elimina o alinhamento por baseline de uma fonte ausente e diferenças de fallback do sistema.

Licenças integrais preservadas: [Bravura-OFL.txt](Bravura-OFL.txt) e [VexFlow-MIT.txt](VexFlow-MIT.txt). Não há distribuição de fonte modificada com nome reservado. Notas, alturas, áudio, alternativas e gabarito permanecem iguais.

## Clave de Fá e pautas compartilhadas

`VoicedDictationSvgRenderer::BASS_CLEF_PATH` usa o contorno `fClef` da mesma cópia Bravura/VexFlow, com o mesmo SHA-256 e conversão descritos acima. O contorno preserva a origem musical em Fá3 e a escala de 360 unidades por espaço. Em cada pauta nova, a origem fica em `(42, top + 16)`, quarta linha de baixo. A clave de Sol reutiliza o contorno existente em `(42, top + 48)`, segunda linha de baixo. Ambas usam escala `16/360` e eixo Y invertido.

As pautas têm cinco linhas a cada 16 unidades. Até duas vozes compartilham cada pauta, com hastes opostas; o layout reserva margem superior e inferior para notas, hastes e barras. As quatro alternativas usam as mesmas colunas e dimensões. Os testes conferem âncoras Sol4/Fá3, posições literais, linhas suplementares, colisões de segundas e limites do viewBox nos extremos Dó2–Si5. Não dependem de uma fonte musical instalada no navegador. O agrupamento não introduz novos contornos ou assets licenciados.
