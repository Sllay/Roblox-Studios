# ENTRE REINOS — ADAPTACAO ORIGINAL EM LUAU

Versao 1.0 — 21/11/2026. Este documento e arquitetura proposta, NAO codigo implementado. Leia RESEARCH_SOURCES.md e MECHANICS_AUDIT.md. A interpretacao estatica do Kingdom Two Crowns 2.4.2 nao equivale a validar a jogabilidade de outra versao. Nao portar codigo de terceiros, nem confundir unidades Unity com studs Roblox.

## 1. Modulos e contratos

Servidor (introduzidos por runner quando necessarios): WorldService, RegionService, SaveSlotService, NPCService, JobService, InventoryService, ConstructionService, StructureService, CombatService, RaidService, CurrencyLedger, MarketService, DiplomacyService, MountService.
Cliente: SideCamera, InputRouter, LaneController, SwimmingController, UIManager, CoinVFX, CharacterAnimator.
Dados: BiomeDefs, RegionDefs, ItemDefs, RecipeDefs, BuildingDefs, ProfessionDefs, JobDefs, NPCArchetypes, EnemyDefs, PortalDefs, RaidDefs, MountDefs, EquipmentDefs.
Todos os IDs sao estaveis e serializaveis: worldId, regionId, npcId, itemStackId, structureId, siteId, transactionId, raidId. Guias de extensao sao permitidos antecipadamente; a feature so e implementada no runner designado.

## 2. Mundo 100% 3D em quatro faixas

WorldSeed + RegionIndex + GeneratorVersion = regioes deterministicas com Terrain nativo e objetos 3D. Reservar posicionamento coerente para vila, centro, muros em aneis, estradas, rios, declive seguro, regiao mineravel, bioma e corredores entre reinos. Fundo distante e visual; fundo proximo contem objetos interativos com WorkAnchor na faixa acessivel; trilho central X/Y contem personagens; primeiro plano possui silhuetas 3D absolutamente pretas com teste de oclusao. Nunca usar sprites parallax 2D.

O Terrain Builder interno ja separa ocupacao solida, liquido e materiais; usar essa infraestrutura e medir integridade de voxels. Roblox Terrain Water e volume de agua, nao simulador de escoamento morro abaixo: cachoeira/rio inclinado pode exigir visual 3D proprio, enquanto o volume realmente nadavel fica conectado. Seeds devem ser mantidas por mundo; regioes exploradas possuem estado persistido, sem sobrescrever obras em novas versoes.

## 3. Movimento R6 e nado

Terra: input horizontal move X; input cima/baixo gira corpo para fundo/camera sem andar em Z. Agua: input X e Y combinados em vetor normalizado, aceleracao e desaceleracao suaves, componente Z fixa. Preservar Humanoid Swimming e controlar fisica por constraints/velocidades validas, nao teleport CFrame em Heartbeat.

~~~luau
-- Pseudocodigo da intencao, nao rotina integrada
local d = Vector2.new(xInput, yInput)
local aim = d.Magnitude > 1 and d.Unit or d
local alpha = 1 - math.exp(-responseHz * dt)
local desired = aim * swimMaxSpeed
local velocity = currentVelocity:Lerp(desired, alpha)
-- aplicar ao controlador de fisica; Z sem entrada
~~~

Necessario hysteresis na superficie entre estados Grounded/Swim/ExitSwim e blends de animacao R6. Camera side-scrolling com smooth e limites por regiao. Testar em cliente mobile real.

## 4. Inventario, materiais e transacoes

ItemDef = {id,mass,stackLimit,tags}; NPCRecord = {id,position,profession,skills,needs,equipment,inventory,weightMax,job,relations}. Galpao, bolsa, obra e chao sao custodiantes distintos. Estados: Available -> Reserved -> InTransit -> Delivered -> Consumed; adicional Lost/Stolen/Salvageable. Uma unidade de recurso tem apenas um custodiante.

~~~luau
-- Pseudocodigo servidor; operacao atomica/idempotente
local missing = site.required[item] - site.delivered[item]
local amount = math.min(missing, npc.inventory[item] or 0, request)
if amount > 0 then
    npc.inventory[item] -= amount
    site.delivered[item] += amount
end
-- a mesma transactionId nao pode ser executada 2 vezes
~~~

Ao quebrar armazem, dividir inventario restante entre recuperavel, destruido e roubado. Salvar destino e transferencias, NUNCA restaurar metade e ao mesmo tempo manter metade no galpao antigo. Garanta limites de peso, capacity e stacks; nenhum RemoteEvent do cliente concede quantidades.

## 5. Escolha de trabalhos e planejamento de NPCs

O documento externo de Kingdom descreve custo por distancia horizontal, prioridade e bonus por manter assignment. Nosso algoritmo e MAIS RICO e ORIGINAL:

~~~text
JobScore = Wp*Priority + Ws*SkillFit + Wu*Urgency + Wc*Continuity
         + Wg*StrategicNeed - Wd*PathCost - Wr*Risk - Wf*Fatigue
         - Wm*MaterialsPreparation
~~~

Todos W e escalas sao parametros de design nosso, NAO valores originais. Tarefa so elegivel se rota, ferramenta, carga, tempo, perigo, habilidade e recursos permitirem. FSM: Idle -> Choose -> Reserve -> Walk -> Interact -> Commit -> Reevaluate, com estados de Flee/Shelter/Sleep/Combat. Hierarquia de prioridades: vida/evacuacao > defesa de crise > ordem explicita > tarefa reservada > trabalho normal > descanso/idle. Atualizacao por eventos e tick com orcamento, nao NPC pathfinding e raycasts por Heartbeat. Simulacao remota de distritos agrega estados; render R6 proximo.

## 6. Obras e estruturas

Colocacao e CONTINUA, nao slots fixos: validar footprint, slope, terreno, acesso, propriedade e regras (fazenda perto de agua, ponte conectando margens). Blueprint contem required, delivered, workRequired, workDone, workerReservations, state e version. Separar MaterialDelivery de Labor; progresso de obra e salvo e nao reinicia apos dormir, crise ou save.

~~~text
workerRate = baseRate * professionMultiplier * skillFactor * toolFactor
             * staminaFactor / complexityFactor
workDelta = max(0, workerRate * dt)
workDone = min(workRequired, workDone + sum(workDelta for eligibleWorkers))
remainingTimeEstimate = remainingWork/max(sum(workerRates), epsilon)
~~~

Multiplicadores definidos pelo criador: carpinteiro madeira 3x/pedra 1x; minerador pedra 3x/madeira 1x; construtor qualquer 2x; comum 1x. Material direto do NPC vai para o site mesmo sem storage. Receitas e HP/reparo sao dados do BuildingRegistry; nao criar script por tipo de muro ou casa.

## 7. Combate, arqueiros e balistica

Do estudo Kingdom: tiro em grupo de 1–2, espera/recarga condicionais; nosso modelo usa Aim -> Windup -> Launch -> Recovery e parametros proprios em EquipmentDefs. Projectiles simulados com Roblox gravity, velocidade calibrada em studs e verificacao de atingimento autoritativa. Trajetoria em 2D X/Y:

~~~text
D = v^4 - g*(g*dx^2 + 2*dy*v^2)
se D < 0: nao existe tiro balistico ideal nessa velocidade
tan(theta) = (v^2 +/- sqrt(D)) / (g*dx)
timeOfFlight = dx / (v*cos(theta))
~~~

Caso dx quase zero requer tratamento proprio. Preferir arco baixo se sem obstaculo; buscar alto se necessario, nao prometer acerto. Lead de alvo em movimento e previsao local limitada, nao homing. Camera cliente desenha flecha, servidor valida colisao, alcance, dano, cooldown e equipamentos.

## 8. Inimigos, alvos, portais e raids

EnemyDefs criam comportamentos originais: perseguir, atacar, infectar, saquear, quebrar, voar, cercar, chefe. Enemy FSM: Spawn -> Approach -> SelectTarget -> Attack/Steal/Infect -> Retreat/Die. Saque transfere objeto real/custodia, nao cria moeda nova. O jogo original usa caches de alvo e ondas por curvas condicionais; nosso RaidDirector usa pressao e objetivos (equacoes PROPOSTAS, nao extraidas):

~~~text
pressure = portalStage + neglectedThreat + corruption + eventPressure - countermeasures
budget = clamp(BaseWave(pressure, day) * difficulty * exposure * eventFactor, min, max)
weight_i = max(epsilon, valueOfKingdom_i + routeAccess_i + vulnerability_i - defense_i)
attackShare_i = weight_i / sum(weightOfReachableKingdoms)
~~~

Nao forcar 50/50 entre dois reinos; portais podem escolher lado valido, variando frequencia e hora. Evitar raid toda noite e informar antes de evento grave; limite de spawn/CPU. T1 contem somente raid LOCAL funcional. T2 finaliza portal entre reinos e infeccao com sintoma, isolamento/cura e protecao de iniciante. T3 adiciona VARIEDADES, bosses e eventos sem reescrever diretor.

## 9. Bolsa de moedas e economia real

CurrencyLedger e autoridade. DropRecord {id,value,ownerEligibility,position,claimed,transactionId}; cliente mostra moeda quicando, arco e bolsa com pooling. Servidor faz coleta uma unica vez por ID e proximidade. Campo wallet=1000 e alvo banqueiro=39 no documento externo NAO estabelecem o tamanho fisico real da bolsa do Kingdom.

Arvore gera madeira, mina pedra/ferro, fazenda comida. Receitas processam material e tempo; mercado paga moeda ao vender bens e tributos/salarios sao transferencias auditadas, nao loot de arvore. Economia suporta transporte entre NPCs, galpoes, construcoes e mercado. Formula comercial propria parametrizavel:

~~~text
price = clamp(basePrice * demandIndex / max(supplyIndex, minSupply)
              * qualityFactor * distanceFactor, floorPrice, ceilPrice)
~~~

Transacao soma debitos e creditos. Emissao externa por comercio com reino distante exige fonte registrada/orcamento, nao valor infinito. Precos e fatores nao foram copiados de Kingdom e exigem balanceamento por simulacao.

## 10. Pontes, montarias e navegacao

NavGraph tem Edge {from,to,crossingType,bridgeTier,weightLimit,permissions,cost}. Permissoes CanWade/CanSwim/CanUseLightBridge/CanUseStrongBridge/CanFly. Ponte leve: construtores e pessoas autorizadas; ponte reforcada: NPCs, cargas, montarias terrestres; agua rasa sem ponte. Mudanca de ponte invalida rotas e replaneja jobs.

MountDef {walkSpeed,runSpeed,staminaMax,runDrain,idleRecovery,walkRecovery,terrainMultipliers,abilities,crossingPermissions}. StaminaNext = clamp(stamina + stateRate*dt, 0, staminaMax). Os campos de stamina de Kingdom nao estabelecem unidade temporal universal; nossos valores devem ser testados nos ambientes reais.

## 11. Diplomacia, relacionamentos e saves

FactionRecord {id,treasury,resources,relations,alliances,territory,residentsSummary}. RelationshipRecord {actor,target,trust,affinity,fear,lastEvents}; presentes, resgate, sacrificio, dano e socorro viram eventos sociais pequenos persistentes sem LLM. Reinos distantes executam simulacao agregada sem milhares de Humanoids.

Seis slots independentes, por usuario, guardam seed, generatorVersion, regions, structures, NPCs, jobs, obra parcial, ledgers, raids, storyFlags e relationships. DataStoreService com UpdateAsync, session lock, retry sem sobrescrever nova versao, schema migrations e limites medidos antes de usar shards. Nao gravar cada NPC separadamente todo frame. Ao mudar de runner ou modelo, ler plano/status atual e evidencias de release.

## 12. Testes e gating

Invariantes: seed mesma versao reproduz terreno; todos recursos possuem custodiante unico; dois NPCs nao entregam mesma madeira duas vezes; obra pode dormir e retomar; NPC nao atravessa ponte ilegal; conta de loot nao duplica; ataques sao conclusivos; save recupera apos crash; mobile sem drift Z, vibracao e perda de FPS sem medicao.
Implementacao real so por runner. Fontes: SongZcode/kingdom-two-crowns-mechanics, Robo Creator Hub APIs oficiais, ferramentas Roblox-Studios Terrain Builder/Scene Sync/Quality Gates. Creditar fonte documental CC BY 4.0, sem usar arte/codigo/dados proprietarios.
