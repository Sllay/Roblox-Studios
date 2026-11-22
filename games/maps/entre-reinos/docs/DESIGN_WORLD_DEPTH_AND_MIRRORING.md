# ENTRE REINOS — arquitetura aprovada: profundidade, biomas, recursos e estruturas (2026-11-22)

**Pedido do criador durante o teste mobile v8:** preservar a lógica 2.5D do jogador, mas fazer o mundo inteiro parecer um mundo 3D coerente, e não uma faixa XZ terminando no vazio. Não confundir background com decoração sem recursos.

## Mundo e biomas / subbiomas

- **Bioma primário**: regras amplas de geografia e recursos (floresta, planície, áreas corrompidas etc). **Subbioma**: modulação local dentro de um bioma (clareiras, aglomerados florestais, etc). "Corrompido" pode ser um modificador de região atravessando floresta e planície, não uma lista mutuamente exclusiva. Implementar por campo de densidade e blend do mundo seeded/region chunks, não por if específico a cada asset.
- A região tem **estoque canônico de árvores/recursos** e um campo de densidade por células. Árvores de fundo e de frente são visualizações correlacionadas do *mesmo* estoque/coorte, não duas reservas independentes. Quando NPCs derrubam 10% da coorte, reduzir densidade de exemplares do background com transição estável e determinística; não fingir que árvores intocadas permanecem como 300 recursos extras.
- Background 3D com montanhas e terreno estendendo-se para Z negativo, com regiões visuais geograficamente contínuas, sem void visível na câmera. **Terreno e montanhas reais**, não uma skybox escondendo faltas de chunks. Suporte a streaming visual/baixo custo distinto do trecho jogável.
- **Economia**: madeira visível no fundo não pode representar estoque incongruente; colheita acontece na coorte lógica acessível da faixa de simulação, com renderização ajustada para o fundo. Futura simulação agregada da floresta para mundos distantes segue a mesma regra.
- Alargar o panorama não significa permitir ao jogador navegar livremente em Z: player permanece em X/Y na lane; NPCs podem usar leve Z lateral para contorno local, cruzando uns aos outros somente quando congestionamento impedir avanço (não bloquear a função da tarefa). Evitar NPCs tremerem nas passagens.

## Construções 3D com profundidade coerente

- Casas e armazéns ficam **atrás da lane**, permitindo que o jogador passe pela frente e não dentro dos volumes. Na etapa de foundation, já deslocar volumes para Z negativo, sem prometer colisão final que ainda não existe.
- Muralhas, cercas e estruturas longitudinais **acompanham subida/descida/curvatura** do Terrain em vários segmentos no 3D, incluindo retorno visual ao fundo sem forçar player a andar no fundo. Footprint, rota, custo, materiais, ataque/HP persistentes baseiam-se no grafo de segmentos da obra, não em uma grande caixa.
- Construção customizada precisa de visual e colisão por estágio, sem atravessar paredes no resultado final. Jamais criar um "modelo visual completo" antes de validar que a obra recebeu materiais e progresso.
- Assets finais podem reutilizar **biblioteca de modelos próprios do Black Islands/Black Desert** e itens que o usuário possua/licencie na conta Roblox, após auditar IDs e direitos. Não adicionar assets de terceiros por suposição, não copiar scripts/malware de Toolbox.

## Prioridades de runner (sem antecipar sistemas)

- **Correção de preview R2 v8→v9 agora:** altura correta dos pés de NPC R6 no Terrain real, suavização visual de deslocamento em 60 Hz, etiquetas 3D pequenas sem fundos, R6 Swimming na água sem cair/andar, câmera um pouco mais perto e silhueta de árvore escura em vez de cunha triangular. Evidência CI e visual mobile obrigatória. Mantém-se gerador de 3 chunks iniciais + 4.º deferred.
- **T1-R2 ainda aberto:** finalizar trabalho/estoques, casas, colheita, dano/reparo, NPC avoidance/LOD e persistência antes de validá-lo. O deslocamento da casa para Z=-10 neste preview é visual/sem colisão; não confundir com sistema de colisão pronto.
- **T2-R1**: aprofundar geração 3D contínua, biomas/subbiomas e regiões de fundo, simulação agregada/espelhamento coerente. Requer design determinístico e migração de versões para não alterar seeds de mundos existentes sem reconciliação.
- **T2-R2 / T3**: ampliar conteúdos, economia e biblioteca de assets de forma versionada. Reutilização de assets próprias somente com auditoria.

**Regra de geração:** nunca reescrever destrutivamente o Terrain de mundo salvo, especialmente Mundo 1 seed 516639272. Chunks já gerados devem permanecer derivados da mesma `WorldProfile.GENERATOR_VERSION`, e extensões futuras devem versionar o novo campo de densidade para preservar save.
