# Roteiro ativo — Roblox Studios IA | P4.5 → P5
Atualizado: 2026-11-12. Referência: staging v14, Scene Sync dd359a0, pesquisa fde246c.
Este é o plano operacional de próximos passos; ROADMAP.md conserva o histórico. Não é promessa de execução assíncrona nem de conclusão em data fixa.

## 1. Estado comprovado e limites
- Staging mapa-principal/main: universe 10769712441, place 93428341652658, v14, digest fc6d1050b100b87ead072c99e4fd60a3a85781c840e7e11e39cbff81c76e4c08; 3385 instâncias no inventário de escopo, 182 modelos ambientais (158 dentro da área jogável, 24 no horizonte), 49 regiões de Terrain. 93 colisores de árvore acoplados medidos na v13.
- Usuário aprovou desempenho, dia/noite e grama/vento ambiente na v13; não há aceite mobile da correção de folhagem v14. V14 instalou dois scripts de vento e foi verificada no run 43257825675, 49 hashes intactos.
- 12 packs inventariados, 20 scripts externos compilados sem execução. Extração de graveto e MossLeaf pendentes; não autorizar pack inteiro nem código externo por inferência.
- Terrain Atlas v14 (43258670029): 9216 amostras de 8 studs, 9 chunks, altitude seca p80 26,5 studs, min 4,1/max 42,9. Para colocação recalcular na malha nativa de 4 studs.
- API probe 43258355023: leitura voxel, pathfinding de amostra (8 waypoints), serialização de amostra funcionaram. Raycast/spherecast/overlap headless sem hits, EditableMesh sem permissão para mesh testada. Não declarar física ou render validados nesse contexto.
- Studio MCP oficial é backend opcional, não conectado. Sem requisito de PC do usuário. Não prometer acesso remoto ao Studio nem contornar permissões.
- Acumulação PlayerModule/AtomicBinding em saves: causa não resolvida, delta de clones exatos auditado; limite de inventário 5000 é proteção, não solução. Evitar saves desnecessários.

## 2. Sequência operacional
Status inicial: S00 concluído (documentação), S01–S10 pendentes. Só marcar concluído com evidência e commit. S02, S03 e S04 podem preparar código/preview em paralelo após S01, mas a ordem de mutação do staging segue S05 e o gate de versão. S07 pode preparar integração read-only enquanto S05/S06 avançam. Cada publicação usa autorização de staging vigente, nunca produção.

### S00 — Baseline e memória de agentes [concluído: roteiro]
- Ler AGENTS.md global/local, GDD, ARCHITECTURE, ROADMAP, P45_POLISH, TOOLCHAIN_EVOLUTION, ROBLOX_API_RESEARCH, catálogo de capacidades e Scene Sync.
- Registrar status, fonte, dependências, entregáveis, critérios e checkpoint neste roteiro.
- Antes de cada alteração obter baseline atual e revisar diffs; não fixar v14 quando staging avançar.
- Aceite: roteiro versionado, referenciado nos AGENTS e ROADMAP; nenhuma mutação do jogo.

### S01 — Segurança de publicação e contratos (prioridade P0)
Ferramenta:
- Compilar Luau composto com configuração e helpers finais; checar contrato de entrada/saída, identidade/versão, limites e resultados tipados.
- Criar manifesto de transação com operações autorizadas, hashes, escopo, preimage/receipts, prévia e verificação independente. Evoluir verified_script_stage sem duplicar Scene Patch/Safe Import.
- Diagnosticar duplicação de módulos padrão: comparar versões pinadas, fonte/hierarquia, inventário e evidências do SavePlaceAsync. Não apagar ou aceitar mudanças arbitrárias; testar estratégia corretiva isolada antes de uso normal. Se não resolvido, bloquear crescimento não aprovado, planejar orçamento e escopo; nunca aumentar cap como única solução.
- Orçamento Open Cloud: medir chamadas, cache por fingerprint, backoff para leituras, checkpoints de retomada; jamais repetir POST/save ambíguo sem reconciliação.
- Avaliar backup localizado por SerializationService e restauração em alvo descartável autorizado. Não declarar rollback universal.
Gate: teste negativo stale baseline, identidade, operação fora de escopo, falha/timeout após save; comprovar que não duplica escrita; novo recibo e evidência. Não exigir rollback universal para preparar os próximos previews; exigir caminho de recuperação antes de mutação.

### S02 — Spatial Engine / Terrain Surface Index (P0, base de S03/S04)
Ferramenta:
- Reusar tools/terrain/surface_fields.luau e prop_support; criar índice por tile/hash, altura, gradiente/normal estimada, material, água, distância à água, exclusões, vizinhança e suporte. A leitura de topo não resolve cavernas/overhangs; separar futura consulta 3D.
- Atlas em camadas com IDs de objetos, espécie, escala, distância, altitude, trilhas/spawns, contagem por chunk e heatmap. Exportar plano antes/depois com posições e rejeições; cache somente quando hash e esquema coincidem.
- Regra declarativa por espécie/categoria: faixa de altitude/percentil, inclinação, footprint, afastamento da água, densidade, seed, espaçamento, escala, bioma futuro. Não inventar biomas existentes.
Jogo: identificar espécie amarelada por render/evidência, medir p80 nativo de grama seca, planejar relocalização acoplada dos exemplares para altos do terreno; preservar ID e contato.
Gate: testes sintéticos de inclinação, costura, água e determinismo; comparação com posicionador anterior, 9 chunks completos e hash; regra de altitude só para espécie confirmada, relatório de rejeições, mapa de distribuição. Sem publicar ainda.

### S03 — Asset Lab e pequenos recursos (P0, depende S02 para colocação)
Ferramenta: extração inerte de componentes visuais de Tool/Model/Part com seletor exato e política de allowlist, origem, geometria, material, dependências, PBR e direitos. Proibir scripts, remotes, constraints ativos não aprovados; auditar e serializar amostra. Não reupload de terceiros sem direitos.
Jogo:
- Punishment stick 9204066145: extrair somente geometria do graveto, não a arma nem seus cinco scripts.
- Rock 80215326989711 e variantes auditadas do pack 85389927254160: reduzir os 8 Rock decorativos destinados a recursos, preservar rochas grandes como classe separada. Pedrinhas iniciais 0,5–1,5 stud, gravetos 0,8–2 studs, assentados sem flutuar. Medir visibilidade contra grama alta.
- Proposta inicial: 108 pedras + 108 gravetos no total, média 12 de cada por chunk jogável, incluindo os Rock reaproveitados; adaptar densidade por área e orçamento mobile, sem prometer quantidade fixa se suporte insuficiente. Sem colisão/touch/query, ancorados; ID estável, tipo, origem/chunk/posição, estado decorativo e elegibilidade futura. Não implementar coleta/inventário.
- Bush_03: verificar os 8 atuais; redistribuir alguns em clareiras e perto de rotas sem bloquear caminhos; adicionar se necessário e medido, sem colisão. Não aumentar tudo cegamente.
Gate: auditoria exata, nenhum código externo, dimensões e suporte por modelo, distribuição por chunk, orçamento de instâncias e mapa com locais de teste. Sem salvar antes da transação.

### S04 — Physics Builder e vento (P0, depende S02 para suporte)
Ferramenta:
- Perfis físicos por espécie com fonte/calibração, tronco base, eixo/diâmetro, altura visual, ponto de suporte, vínculo com modelo/colisor. EditableMesh negou acesso: usar apenas mesh autorizada ou perfil de tronco medido em evidência visual/geométrica; caixa de galhos não é diâmetro. Expor prévia do colisor e erro.
- Geração de cilindro vertical (eixo local X), do solo ao topo da árvore, largura de tronco, invisível, mesmo grupo de colisão. Terminação convexa inclinada/arredondada dentro da largura, sem plataforma plana larga; baixo atrito não garante escorregar. Validar física em cliente/servidor real; não empurrar/teleportar jogador. Revisar 93 acoplados e árvore isolada jogável, não adicionar física no horizonte indiscriminadamente.
Jogo: confirmar v14 com diagnóstico de folhagens elegíveis/ativas, amplitude, fase, FPS; copas lentas, troncos imóveis, Yasu e Inno, arbustos mais suaves. Ajustar somente se evidência mobile. Testar streaming/respawn e direção GlobalWind.
Gate: testes de transformações, altura/diâmetro, uma identidade por colisor, simulação visual de prévia, nenhum colisor em pedrinhas/arbustos/copas; teste real de salto, aproximação e escorregamento pendente até S06.

### S05 — P4.5 entrega incremental no staging (depende S01–S04)
- Consolidar operações compatíveis (recursos, altitude, arbusto, colisores e ajustes necessários de vento) em um plano revisado e uma única gravação quando possível; se incompatíveis, separar de forma explícita com re-sync. Não rerodar one-shots antigos.
- Passar testes Python, Luau oficial, LSP, Quality Gate 2.0, preview real, autorização staging vigente e verificação independente pós-save: identidades, scripts, materiais, posições, colisores, ocupação de terreno/água e alterações externas. Conferir 49 hashes preservados se nenhuma mudança de Terrain aprovada.
- Registrar receipt, run, commit, versão real e checklist, reportar qualquer falha com reconciliação. Não chamar automaticamente v15 se outro save ocorreu.
Gate: versão publicada e relida, delta permitido e baseline atualizado. Produção intacta; qualidade visual/física ainda não certificada.

### S06 — RS Development Lab e Runtime Quality Gate (P0 para aceite visual)
Ferramenta: evoluir botão P4 | Testes em painel staging-only (controle por universo/place e permissão, sem comandos de escrita remota arbitrários). Mostrar versão, câmera/posição, objeto selecionado/ID, espécie, mesh/material/escala, dimensões e colisor, vento, FPS/frame time p50/p95, memória disponível via Stats e métricas de streaming. Campos indisponíveis marcados N/A, não inventar valores. Capturar amostras com duração/condições e opt-in, sem dados pessoais ou exportação silenciosa. CaptureService para captura/compartilhamento iniciado pelo usuário.
- Cenários reproduzíveis: rota de spawns, aproximação de árvore e salto/topo, props pequenos e clareiras, altitude, riacho/lago/natação, barreira canto/teto, morte/respawn, ciclo completo 4 min. Pathfinding de amostra headless pode orientar rota, não prova física; executar raycasts/overlap e testes físicos em runtime real. Comparar v14 e nova versão com condições equivalentes; orçamento inicial não piorar FPS/frame time sustentado sem justificar.
- Galeria ViewportFrame/WorldModel como inspeção auxiliar; não substitui luz/sombras/PBR do Workspace. Capturas reais do jogo para aceite. Se não for possível automatizar cliente, manter protocolo mobile e explicitar.
Gate: diagnóstico funciona no cliente staging, usuário consegue enviar evidência com ID e cenário, não expor painel em produção. Repetir correção→preview→publicação→teste até aceite P4.5; não chamar de qualidade final.

### S07 — Visual ambiental P4.6 / conclusão dos detalhes P4.4 (depende S05 para layout atualizado; teste via S06)
- MossLeaf 9002291527: extrair componente isolado de vegetação, identificar âncora e normal, testar fixação em encosta/parede por perfil de montagem. Não importar ruína inteira com welds. Excluir água, spawns e caminhos, sem colisão; runtime confere contato.
- Melhorar composição visual: variedade de agrupamentos/clareiras, pequenos detalhes perto de trilhas, flores/musgo, variação de escala/rotação sem padrões artificiais. Respeitar identidade dos materiais e manter contraste entre chão/props.
- VFX ambiental limitado: partículas/Trails de vento, água ou folhas apenas de componentes revisados; orçamento de emitters, distância e transparência. Preservar vento e dia/noite aprovados; não alterar atmosfera global sem A/B de referência. Efeito Wind Effects original só após revisão semântica e teste; não é requisito para substituir o código próprio funcional.
- Ajustes de iluminação/textura opcionais apenas se captura mostrar problema (PBR exagerado, legibilidade etc); não alterar terreno/rio/lago aprovados sem nova solicitação/evidência. Não criar bioma completo nem coleta.
Gate: miniaturas + captura real, comparação por câmera, orçamento mobile e hashes de terreno; publicação incremental separada apenas se necessária.

### S08 — API integrations avançadas e backend Studio (preparação read-only paralela; sem dependência para S05)
- Extender probe por contexto: pinned A/B, version history quando disponível, logs limitados, binary input para payloads compactos, serialização/preimage. Verificar docs/escopos/cotas antes de implementar; não dar novos privilégios automaticamente.
- Pathfinding para matriz de acessibilidade por spawn/landmark com agent params e waypoints; distinguir amostra de mapa todo. Asset API para metadados, versão e acesso/depêndencias; cache por identidade verificável, sem inferir licença.
- Backend opcional Studio MCP: adaptador para inspeção/câmera/playtest/console, conexão em ambiente Studio autorizado Windows/macOS. Não instalar host do usuário, não presumir cloud render disponível. Se conectado, repetir mesmos cenários e evidências do runtime lab. Manter Open Cloud independente; nenhum bloqueio P4.5 por falta de Studio.
Gate: cada integração tem documentação oficial, contrato, teste de erro/permissão e probe no contexto alvo; rotular experimental/desconectada quando pertinente.

### S09 — P5 Agent Interface (MCP Lite + coordenação)
- Usar registro tools/capabilities.json e publicar esquemas de ferramentas tipadas: query, atlas, asset audit, plan/preview e receipt primeiro, depois staging writes sob autorização e lease. Sem endpoint arbitrário de Luau, tokens, acesso a produção ou atribuição de status sem evidência.
- Planejador traduz intenção em operações com constraints e IDs, agente revisor verifica diff/orçamento, executor só aplica plano aprovado; contexto compactado e referências por hash, checkpoints, lock único por Place, idempotência/reconciliação. Adaptadores cloud e Studio opcionais com capacidades efetivas, não supostas.
- Testar fluxo end-to-end em staging/sandbox autorizada: agente descobre ferramentas, prepara preview de uma floresta/decoração, detecta conflito, corrige, executa uma publicação autorizada, verifica e entrega evidence. Primeiro read-only MCP, depois escrita. Não confundir CLI registry com servidor MCP conectado.
Gate: ferramenta documentada, schemas e validação, teste de permissão/versão, auditoria, checkpoint e recuperação comprovada no escopo piloto. P5 não é promoção para produção.

### S10 — Handoff e revisão
- Até 14/11/2026 (data relatada de reset do Codex), priorizar S01–S05 e o mínimo de diagnóstico S06; não prometer prazo de conclusão de toda a sequência. Entregar o que estiver verificado, registrar bloqueios e próximos comandos/arquivos. Não executar em background.
- Usuário faz teste manual mobile; assistente/agents implementam, auditam e publicam staging com autorização. Codex pode retomar do mesmo checkpoint sem repetir auditorias nem inventar status.
- Depois de aceite, decidir próximo ciclo (construção, biomas, recursos coletáveis etc) com usuário. GDD ainda não define esses sistemas; não implementá-los antecipadamente.

## 3. Checkpoint obrigatório
Ao finalizar cada passo, atualizar esta seção ou acrescentar receipt em docs do jogo com link aqui:
- Passo e status (pendente / em andamento / implementado / validado estrutural / publicado / aceite mobile / bloqueado).
- HEAD, versão observada, digest, escopo, operações e justificativas, run/artefato, testes realmente executados.
- Comparação antes/depois, alterações inesperadas, limitações e decisões provisórias.
- Próxima ação concreta e dependências; se falha, caminho de recuperação e proibição de repetir save ambíguo.

Checkpoint S00: roteiro registrado com baseline v14; nenhuma alteração de jogo. Próxima ação: S01, auditoria de duplicação/contrato de transação, depois S02. Links de evidência: [wind v14](https://github.com/Sllay/Roblox-Studios/actions/runs/43257825675), [API probe](https://github.com/Sllay/Roblox-Studios/actions/runs/43258355023), [atlas](https://github.com/Sllay/Roblox-Studios/actions/runs/43258670029).
