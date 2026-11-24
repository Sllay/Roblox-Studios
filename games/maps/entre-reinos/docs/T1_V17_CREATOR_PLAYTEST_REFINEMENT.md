# Entre Reinos — feedback do criador v17 / escopo de refinamento visual e jogável

**Estado: DESIGN APROVADO PELO CRIADOR PARA IMPLEMENTAÇÃO; NÃO EQUIVALE A MECÂNICAS IMPLEMENTADAS.**
**Base auditada:** main `279f89f9c261a0a8e05b658753e27e62b54d42ee`, staging v17.
**Escopo exclusivo:** `games/maps/entre-reinos/`. Temporada 1, refinamento adicional T1-F4/F5/F6; Temporada 2 bloqueada. Não importar assets de terceiros não auditados e não publicar produção.

## Causas diretamente confirmadas na v17

1. `LivingService.actorZ` usa `-2.9+((npc.id-1)%4)*1.8`, quatro pistas fixas apenas para renderização; o WorkEngine persiste `npc.x` e `walk(npc,destX)`, logo não há verdadeiro movimento independente em Z.
2. `NPCPresentation.poseLimbs` altera `Motor6D.Transform` com senoide/manual, de forma distinta das animações nativas R6. Usar `Animator:LoadAnimation()` com a caminhada/parado R6 oficial, no rig correto, sem brigar com Transform manual em braços/pernas.
3. `CombatService.enemyModel` cria corpos com Parts próprias e cor escura uniforme; para os inimigos iniciais que são **humanos corrompidos**, utilizar rigs R6 verdadeiros e personalização de rosto/cor/roupa/corrupção. Duque infectado preserva identidade e silhueta de nobre humano, não se torna bloco genérico.
4. `LivingService.createSiteVisual` adiciona ProximityPrompt e BillboardGui de madeira; abandonar etiquetas/popups constantes na frente do jogador. Criar seleção por interação contextual real e feedback apenas quando alvo estiver selecionado ou dentro de distância apropriada.
5. `R3HUD` tem botões separados "GOLPE" e "ARCO", sem hotbar; `CombatService` atira `Vector3.new(side*64,30,0)` sempre. Trocar por hotbar com espada/arco visíveis + botão único Ataque, arco ao segurar e soltar (acúmulo de potência servidor), preview de parábola no cliente e colisão/dano no servidor.
6. `Campaign.command(...,"training")` inicia escolta imediatamente; não existe diálogo contextual encenado. Primeira missão exige caminhar até o duque, interagir, câmera aproxima ambos, painel com nome/retrato e fala originais em estilo RPG de fazenda (não copiar texto/arte/UI de Stardew Valley), depois aceitar escolta.
7. `WorldProfile` apresenta quatro chunks de 64 studs, `WorldService.activate` gera três, e `ensureNear` gera um quarto. Criador especificou **17 chunks totais** (centro, oito oeste, oito leste), inicialmente **5 vizinhos** (centro, dois oeste, dois leste), e extensão progressiva conforme jogador anda.

## Contratos de implementação e aceitação

### ER-T1-V18-01 — Espaço 2D real e NPCs espontâneos
- Armazenar `npc.z` opcional e migrável sem alterar `npc.x`, profissão, carga, recursos ou jobs de save existente. Novos NPCs usam Z distintos derivados de seed+id, não linhas de id/4.
- Caminhar em X e Z de forma contínua, dentro da área interna das muralhas da vila; não apenas alternar faixas. Fazer idle wandering entre pontos alcançáveis, com pausas naturais, turnos e tarefas prioritárias. Sem criar gastos/inventários falsos.
- Separação local entre NPCs por espaço pessoal + escolha de destinos que reduzam sobreposição; evitar modelar corredores. Considerar obstáculos, rios, edificações, recursos e portas válidas; fallback seguro caso caminho falhe.
- Colisões e navegação consistentes no 3D, sem libertar jogador para sair do plano 2.5D. Respeitar custo CPU mobile. `motionX` e `motionZ` replicáveis separadamente.
- Em jobs, o NPC pode entrar/sair de Z para chegar a árvore/galpão/obra, não apenas passar lateralmente; distâncias 2D. Saves antigos devem reabrir com Z válido.

### ER-T1-V18-02 — R6 oficial e diversidade humana natural
- NPCs, guardas, duque e humanos corrompidos em R6 verdadeiro (Humanoid, Animator, Motor6D válidos), sem alterar rig do jogador. Usar movimentos Roblox R6 existentes, crossfade parado/caminhando/correndo e animações de ação adequadas; jamais sobrescrever Motor6D.Transform dos mesmos membros no loop de apresentação.
- Tons de pele realistas variados deterministicamente por seed+id, do claro ao bronzeado/alaranjado moderado até escuro marrom humano (evitar preto absoluto/branco absoluto). Cor de pele diferente de cor de vestimenta; roupas de profissão/equipamentos sobre corpo.
- Espada, arco, lança e mochila visíveis e soldados nos limbs corretos; evitar renderizar uma vara de madeira genérica como qualquer arma.
- Inimigos iniciais = humanos infectados, aparência humana inequívoca, marcas visuais de corrupção. Nobre/duque reconhecível antes e depois da transformação. Monstros diferentes são conteúdo futuro.

### ER-T1-V18-03 — Interação contextual, seleção mantida
- Retirar texto permanente e balões de recurso invasivos. Botão pequeno de interação na UI; destaque discreto de alvo próximo (árvore ou estrutura).
- Toque/pressão curta para interagir com NPC/estrutura; **segurar por ~0,7–0,9 s** árvore alterna marcar/desmarcar com barra de progresso local e confirmação autoritativa. Mesmo botão, sem múltiplos overlays Roblox ProximityPrompt ao mesmo tempo.
- Botão é multiplataforma (mouse, touch, gamepad): mesmo comportamento, captura press/release, cancelar se dedo sai da área/pausa/camera fecha/alvo muda. Servidor valida target ID, distância X/Y/Z, vida da árvore, propriedade, cooldown e replay.
- Árvore selecionada mostra marcação discreta, desmarcada não deixa popup persistente. Não duplicar os 144 recursos iniciais.

### ER-T1-V18-04 — Hotbar, combate e trajetória de flechas
- Duas posições iniciais na hotbar: ESPADA e ARCO. Mostrar ícone reconhecível e munição numérica junto ao arco. Apenas um botão de ATAQUE visível.
- Ao selecionar espada, pressionar causa golpe com pose/trilha curta, janela de colisão física e dano validado pelo servidor; sem ativar flechas.
- Ao selecionar arco: **início de pressão** arma preparado, indicador de trajetória local acompanha potência; segurar aumenta alcance continuamente até limite, soltar atira uma flecha física com gravidade e colisão. Toque curto = alcance próximo; segurar mais = maior alcance. Indicador é curva parabólica (não reta), derivado da mesma balística do servidor e reposicionado conforme o personagem se move.
- Protocolo de carga validado pelo servidor a partir de tempo de início/fim observado, velocidade/gravidade/alcance limitados, cooldown, anti-spam e 1 munição gasta por disparo confirmado. Cliente nunca informa dano, velocidade ou quantidade.
- Se soltar/cancelar em pausa/diálogo ou trocar de arma, a intenção não causa tiro fantasma.
- Usar `Trail`/Attachments para rastro da espada e flecha, reduzindo instâncias novas por disparo; evitar efeitos que atravessem o corpo.
- NPCs armados com modelos visíveis usam o mesmo vocabulário visual, ainda que IA tenha contratos de ataque separados.

### ER-T1-V18-05 — Primeiro objetivo e diálogo de duque
- Novo slot: caderno de missões orienta "Fale com o duque" e destaca posição/ator. Aproximação e interação server-authoritative; pressionar abre diálogo em tela inferior estilo RPG de fazenda, retrato original, caixa legível e nome.
- Câmera ajusta suavemente enquadramento de jogador e duque, sem cortar personagem nem deixar diálogo por cima dos controles. Controles e combate temporariamente suspensos; restaurar câmera ao encerrar.
- Falas naturais contextualizam vontade de passear além dos muros e riscos da escolta, personalidade e hesitação dos guardas; escolha "Acompanhar" começa etapa de escolta ao enviar comando validado. Não enviar `training` diretamente ao tocar sem diálogo.
- Não apagar progressão de saves que já estão em escolta/crise/coroação/sandbox. Toda cena também precisa funcionar com câmera touch pequena.
- Melhorar tempero narrativo sem revelar lore futura privada e sem copiar falas de outros jogos.

### ER-T1-V18-06 — Mundo 17 chunks, janela inicial 5
- Chunks de 64 studs. Intervalo lógico: `chunkIndex -8..+8` relativo ao centro. Total =17. No spawn ficam prontos centro `0` e ±1, ±2 (5 chunks). Ao caminhar, preparar novos chunks adjacentes de forma determinística até ±8.
- Streaming e orçamento em mobile. Distinguir a geração de Terrain no servidor e a renderização de chunks no cliente; medir memória. Se descarregamento de Terrain não for seguro, registrar política correta e evitar remoção destrutiva. Não fingir limite de cinco ativos se continuam todos carregados.
- Não deslocar castelo/rios/locais já persistidos só por mudar IDs de chunk. `WorldProfile.sample(seed,x,z)` deve produzir o MESMO resultado dentro dos limites originais; tornar limites externos e paredes compatíveis com novo tamanho, preserving saves.
- A área do castelo permanece central, 2 chunks adicionais em cada direção no inicial. Em fronteira ±8, bloqueio natural/limite de mundo coerente, não muro flutuante em ±126.
- Testar geometria, rios, Seed, suporte de NPC, Terrain, chunks progressivos, falha na geração e recuperação; sem `Terrain:Clear` arbitrário.

## Ordem de trabalho recomendada

**T1-F4:** registrar requisitos, auditar os pontos verificados, implementar NPCs em X/Z real, animações R6 oficiais, pele humana, identidade humanoide corrompida. Testar save antigo, FPS, trabalho e defesa sem regressões.

**T1-F5:** interação por segurar, hotbar com espada e arco, combate de carga/parábola, efeitos e tutorial/diálogo do duque; verificar UI/touch e anti-exploit.

**T1-F6:** mundo 17 chunks com janela inicial 5, geração progressiva, integração funcional com jobs/estruturas/limites/legacy save; regressões finais, benchmark mobile, staging e pedido de aprovação.

Essa divisão é uma **nova rodada de refinamento da T1**, não T2-R1. F4/F5/F6 são os IDs sugeridos; conferir com RUNNER_PROTOCOL e atualizar RUNNER_STATUS conforme regras, sem aprovar temporada sem playtest real do criador.

## Qualidade e evidência obrigatória
- Reutilizar contratos existentes (`WorkEngine`, `LivingModel`, `R3Engine`, `Campaign`, `CombatService`, `NPCPresentation`, `WorldService`, `WorldProfile`, `R3HUD`) e criar módulos pequenos novos para navegação, animação, interação, balística e diálogo se necessário.
- Quality Gate V2, Python, Luau executable, Rojo, validação de mapas reais no Roblox, DataStore isolado/migração, Scene Sync antes/depois de staging, readback de versão/hashes pós-publicação.
- `docs/FEATURE_COMPLETENESS_AUDIT.md` ER-001…020 permanece PARCIAL até evidência real, inclusive interação em touch e performance. Sem fake screenshots, sem “verificado no mobile” por simulação headless.
- Produção e outros jogos intocados; nenhum wipe de save. Publicar somente candidato staging com autorização e workflows oficiais, com manutenção de rollback compatível ao ruleset 3.

## Fontes técnicas consultadas para implementação
- Roblox Creator Hub Animator / Animation: `https://create.roblox.com/docs/animation/using`, `https://create.roblox.com/docs/reference/engine/classes/Animator`
- R6 legada (referência comunitária de IDs, verificar permissões antes de usar): walk `180426354`, idle `180435571`.
- Roblox Creator Hub GuiObject / UserInputService / Trail: `https://create.roblox.com/docs/reference/engine/classes/GuiObject`, `https://create.roblox.com/docs/reference/engine/classes/UserInputService`, `https://create.roblox.com/docs/effects/trails`.
