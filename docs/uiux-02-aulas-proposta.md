# Aulas futuras — proposta, sem implementação

Nesta missão não foram criados catálogo, player de vídeo, aulas, níveis avaliados ou migrations. As rotas antigas de aulas continuam acessíveis e informam preparação. Os quatro Playgrounds são atividades reais e independentes desse futuro catálogo.

## Contrato de publicação

Uma aula futura deverá ter identidade estável, área, título localizado, versão editorial e estado explícito de publicação. Apenas conteúdos publicados e revisados devem aparecer ao estudante. Módulos, ordem de estudo, pré-requisitos e níveis precisam de aprovação pedagógica; contagem de tentativas e plano de assinatura não são avaliação de nível.

O vídeo precisa de fonte autorizada, direitos de uso, duração obtida do arquivo/provedor, legendas e transcrição. Thumbnails e autoria devem vir do conteúdo aprovado. Velocidade, retomada e reprodução só devem aparecer quando houver um player funcional e verificado. Falha técnica de vídeo/áudio não deve virar erro de conhecimento.

## Progresso e integração

Manter progresso de aula separado de `ExerciseAttempt` e `StudyActivity`: responder uma questão não prova que uma aula foi assistida. Definir antes o significado de iniciar, retomar e concluir uma aula, com regras de servidor e eventos idempotentes. Se houver crédito, especificar contexto e limites antes de implementar persistência, transações e índices únicos.

Reutilizar `MusicTheory`, os serviços de exercícios e o validador independente para conteúdo musical. Vincular uma aula a práticas aprovadas sem modificar o gabarito por requisitos visuais. A convenção harmônica e a síncopa continuam sujeitas às decisões pedagógicas já documentadas; não ampliar currículo nesta etapa.

## Rotas e implantação futura

Preservar URLs legadas até existir um mapeamento editorial legítimo. Não traduzir `A1`, temporadas artificiais ou números arbitrários da URL em conteúdo publicado. Um futuro `show` deverá verificar publicação e autorização, com um estado de indisponibilidade seguro para links antigos.

Rails, ERB, partials e Stimulus continuam suficientes. Evitar criar um serviço de vídeo próprio antes de definir o provedor. O desenho de modelos, migrations aditivas, política de acesso, retenção e preservação de dados deverá ser revisado antes da execução. Pagamentos, catálogo, avaliação e Arena não são dependências já entregues.

## Critérios de aceite futuros

- Conteúdo e grafia musical aprovados por especialista, com fixtures independentes.
- Catálogo alimentado por publicação real; estados vazio/indisponível claros.
- Autorização, URLs antigas e isolamento entre contas cobertos por integração.
- Progresso e crédito testados sob repetição e concorrência, sem confiar no navegador.
- Player com legendas, teclado, tema, reflow e recuperação de falha.
- Verificação em navegador/dispositivo real e escuta humana.

Esta proposta não inicia a próxima missão.
