# ENTRE REINOS — LACUNAS E TESTES DE PESQUISA

Atualizado 21/11/2026. Regra: uma lacuna de Kingdom NÃO deve ser preenchida por chute; podemos desenhar alternativa ORIGINAL e marcá-la H, se validada para Entre Reinos.
Campos por item: domínio | o que não sabemos | como validar | dono/runner.

## Questões da engenharia reversa já existente

1. Bolsa física exata de Kingdom (mixed coins/gems), geometry overflow e ownership completo. Fonte RE01 economy/greed; campo 39 não é limite. Validar apenas se for necessário ao UX; nossa bolsa terá ledger próprio. T1-R3.
2. Spawns de ondas e condições de portal completas; curvas e delays variam por tema/versão. RE01 time-seasons, MOD01. Não criar 'dia N = X monstros'. T1-R3 e T2-R3.
3. Ordem exata da seleção/cancelamento de jobs de construtores, perigo e conclusão ao anoitecer; static N não é gravação do runtime. RE01 builders/evidence. Implementar FSM própria com testabilidade. T1-R2.
4. Tempo real de arcos/colisões/trigger ordering, todo projectile group/condições de perfect arrow; RE01 archer. Validar nossa balística Roblox por testes e perf. T1-R3.
5. Mundo/bioma de Kingdom: gerador completo de ilha, distância/posições de recursos e restrições é não documentado integralmente; mods custom-challenge mostram somente configs. Desenvolver nossa geração por região com testes de seed e caminhos. T1-R1/T2-R1.
6. Política completa do inimigo ao roubar moeda/coroa, morte/despawn e loot, prioridade de target em casos de empate; RE01 greed. Nossa transferência de custódia será própria. T1-R3.
7. Todos parâmetros de montaria e eventos de stamina, pressão de alimentação e DLC; RE01 mounts + MOD01. Nossos multiplicadores per second e física precisam medição no Roblox. T2-R1.
8. Decaimento dos reinos de Kingdom, prioridades de grupos de objetos e co-op: RE01 travel explicitamente incompleto. Nosso simulador remoto terá regras definidas, sem decaimento injusto ao offline. T2-R1/T2-R3.
9. Parâmetros completos de DLCs (Norse, Olympus, Dead Lands, tema padrão), pontes/cavernas/esquadrões e diferenças de patch; não fundir valores. Usar gameplay/guia quando necessário. T3-R1/R2.
10. Projeto original de UI/câmera/render e física 2D não pode ser diretamente transportado para Terrain 3D, R6 ou Roblox; observar sensação e construir controles originais. T1-R1.
11. Netcode coop original não foi auditado completamente; fora da entrega solo. Não usar como referência de servidor Roblox. Futuro, não T1-T3.
12. Mods podem alterar versão e comportamento, e README não garante licença do conteúdo original. Ler código apenas como referência de conceitos, sem importação. Todos.

## Questões exclusivas de Roblox / Entre Reinos

13. Técnica para preto absoluto 3D sem influência de dia/noite e transparência segura ao ocluir personagem. Prototipar Lighting/SurfaceGui/render/R6 e validar mobile sem pressupor solução pronta. T1-R1.
14. Constraint horizontal Z e controle smooth de orientação cima/baixo sem travar animação nem física R6; prototipar com Humanoid e physics controller. T1-R1.
15. Terrain Water nas transições de rio inclinado e trecho fundo->trilho->frente: água nativa não tem simulação de correnteza/níveis variáveis ao longo do declive. Usar testes voxel/fluido visual, sem parts flutuando não auditadas. T1-R1/T2-R1.
16. Limite do mundo procedural grande com Terrain e muitos NPCs; definir orçamento/região após perfil real mobile, streaming e LOD. T1-R1/T2-R1.
17. Seis slots com session lock, tamanho de dados por reino, autosave, gerenciamento de falhas e migração entre versões: medir limites Roblox e criar teste de crash/reconexão. T1-R1, regressão até T3-R3.
18. Regras de monetização Rewarded Video e sua elegibilidade real no perfil/experiência; conferir Creator Hub na época, não presumir acesso. T3-R2.
19. Randomização automática de roupas R6 compatíveis do catálogo, licenças/moderação/performance; AvatarEditorService é pesquisável mas possui rate-limit e restrições. Construir curadoria/caching. T1-R2/T3-R1.
20. Balanceamento de níveis de NPCs, encadeamento de tarefas e peso/inventário, valores de recipes/fome/venda/impostos: projeto ORIGINAL, medir com simulações econômicas. T1-R2/T2-R2.
21. Frequência de raid e escalonamento de portais que atacam reinos vizinhos: projeto ORIGINAL, simulações de 100+ dias e indicadores de dificuldade, não copiar curvas K2C. T1-R3/T2-R3.
22. Regras de apagar/devolver material de construção cancelada/destruída, produtos pagos e resgate após queda de galpão; evitar duplicação. T1-R2/T1-R3/T3-R2.
23. Caminhabilidade de ponte provisória para construtor vs civis/montarias e integração com contexto de medo/rotas, usando grafo e segurança. T2-R1.
24. Regras de anexar/reorganizar dois reinos depois de conquista, preservar estruturas/posse/moradores e world seed sem teletransportes inconsistentes. T2-R3.
25. Metas móveis quantificáveis de FPS, memória, RPC, regiões ativas e NPCs antes de declarar jogo otimizado. MicroProfiler e dispositivo real, não apenas CI. T1-R1 e T3-R3.
26. Direitos de uso dos assets do Black Island no novo jogo e conta Roblox, colisões/estilos, mapa de IDs e Scene Sync no staging. Auditar antes de compartilhar assets. T1-R1/T3-R1.
27. Verificação dos IDs 10769712413 e 90623742498445 (Universe/Place) e se são staging do Entre Reinos; não usar deploy antes do vínculo Roblox oficial confirmado. Pré-publicação T1.
28. Fonte original da lore confidencial permanece num Drive privado; não publicar URLs e revelações no GitHub público. Todas as temporadas.

## Como fechar uma lacuna
Registrar data, link, versão, condições, método e evidência A/N/O/P/R/H/U. Se houver experimento Roblox: incluir seed, dispositivos, FPS/memoria, testes, screencast se realmente gerado, commit e receipt. Nunca substituir hipótese por "fato" com base somente no nome de método de um mod.

Este registro é atualizado no início e ao fim do runner, sem deixar itens resolvidos sem evidência.

### Evidência T2-R1 de preparação — 25/11/2026

A API oficial de Terrain (R) confirma a grade de 4 studs e os canais sólido, líquido e material. A leitura comunitária de viagens e decaimento de Kingdom Two Crowns 2.4.2 rev23529 (A/N/U) tem lacunas na cadeia completa de transporte e no comportamento da ausência. O Entre Reinos usa um campo regional próprio (H) e mantém aberta a política de tempo distante. O ensaio de terreno suporta somente o cenário Open Cloud sem cliente na seed 516639272. Curva de perda, velocidade de barco/montaria e regras de decaimento continuam sem decisão. [Creator Hub](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/Terrain.yaml) · [Limites do estudo](https://github.com/SongZcode/kingdom-two-crowns-mechanics/blob/main/docs/evidence-and-limitations.md) · [Recibo T2-R1](../runner-receipts/T2-R1.md)
