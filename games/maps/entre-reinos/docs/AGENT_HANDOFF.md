# ENTRE REINOS — HANDOFF ENTRE MODELOS, AGENTES E RUNNERS

Versão 1.0 — 21/11/2026. PRINCIPAL PONTO DE RETOMADA DE QUALQUER CONVERSA.
Este arquivo não substitui os requisitos completos; funciona como ordem determinística de leitura e execução, com fontes e status verificável. O projeto pertence ao monorepositório Sllay/Roblox-Studios, diretório games/maps/entre-reinos. A existência de pesquisa/documentos NÃO significa runner implementado.

## 0. Estado base nesta data
- Novo jogo: Entre Reinos (inglês provisório Between Kingdoms), solo medieval, cenário 100% 3D com câmera lateral e NPCs ricos.
- Plano V2 oficial (SUBSTITUI V1): T1 Fundação, T2 Finalização dos sistemas centrais, T3 Conteúdo/Variedade/Polimento. 3 runners em cada, ordem estrita.
- T1-R1 até T3-R3: PLANNED. Nenhum sistema de gameplay implementado neste ciclo de pesquisa.
- Dois IDs recebidos do usuário para novo Roblox: 10769712413 e 90623742498445, interpretação Universe/Place apenas PROVISÓRIA; conferir docs/ROBLOX_IDS_PENDING.md e não publicar em ID não verificado.
- Ideias e decisões: GDD.md e docs/VISION_MASTER.md. Histórico docs/DECISION_LOG.md. Lore tardia confidencial NÃO deve ser exposta no repo público.
- Nenhum runner recebe marca VERDE somente porque foram redigidos documentos, planos, pseudocódigo ou CI de documentação.
- Estágio atual: pesquisa inicial registrada, replanejamento documental. O próximo trabalho de implementação inicia em T1-R1 quando seus pré-requisitos forem atendidos.

## 1. Sequência obrigatória de leitura após troca de modelo

1. Verificar branch main HEAD atual e arquivos AGENTS.md global e games/maps/entre-reinos/AGENTS.md. Nunca confiar em SHA antigo para estado atual.
2. Ler este handoff por inteiro.
3. Ler docs/VISION_MASTER.md (decisões FIXADO/PROPOSTA/FUTURO/ABERTO), depois docs/DECISION_LOG.md (última instrução prevalece sobre proposta antiga).
4. Ler GDD.md, ARCHITECTURE.md, game.manifest.json e deploy.targets.json; conferir estado do Place e ferramentas, sem presumir publicação.
5. Ler docs/SEASON_RUNNERS.md: procurar etapa com menor número ainda não validada dentro da temporada aprovada, respeitando T1→T2→T3 e R1→R2→R3.
6. Ler docs/RUNNER_STATUS.json: cada runner guarda estado, SHA de implementação, CI, recibo e validações. Não alterar histórico sem evidência; se houve commit concorrente, conferir HEAD e reconciliar.
7. Ler docs/RUNNER_PROTOCOL.md: critérios, testes, publicação staging e refinamentos.
8. Ler docs/research/RESEARCH_SOURCES.md e docs/research/MECHANICS_AUDIT.md. Abrir fontes exatas do runner atual e conferir versão, qualidade e ressalvas.
9. Ler docs/research/ROBLOX_ADAPTATION.md para contratos/algoritmos originais e docs/research/RESEARCH_GAPS.md para o que NÃO foi comprovado.
10. Ler documentação interna referenciada para o domínio (Terrain Builder, Scene Sync, Deployment, QualityGate, asset-library) e usar as ferramentas reais existentes, sem reinventar código nem publicar Place inteiro por acidente.
11. Abrir receipt do último runner validado e branch/PR relevantes. Se não existe, não inventar progresso; começar pelo escopo planejado do próximo runner.

## 2. Contrato operacional de UM runner

Entrada: escopo e leitura das fontes do runner na SEASON_RUNNERS; inventário de arquivos e riscos; testes escritos antes de alteração.
Execução: desenvolver vários sistemas integrados ao runner, com APIs tipadas, schema migrável, registries e servidor autoritativo; trabalhar no escopo apenas. Não ativar mecânica da temporada seguinte.
Validação: validar arquitetura e script Luau, testes unitários, simulação sem render, build Rojo, testes de runtime quando aplicáveis, testes mobile com métricas reais.
Correção: se houver falha, identificar causa e corrigir; retestar. Não mascarar CI nem dizer que testou Roblox runtime sem prova.
Fechamento: commit/integração na main, receipt com links e evidências, atualizar status JSON somente após validação, e documentar decisões que mudaram. O próximo runner só inicia após o anterior estar verdinho.
Fim da temporada: publicar apenas staging verificado depois de R3, registrar publicação e pedir teste do criador. Se rejeitado, F1-F2-F3 da mesma temporada; se aprovado, próxima temporada.
Fim de T3: revisão final do jogo completo, confirmação do criador e promoção separada a produção com autorização explícita.

## 3. Fonte da verdade e ordem de precedência

1. Ordem explícita MAIS RECENTE do criador e política do repositório.
2. docs/VISION_MASTER.md atualizado e docs/DECISION_LOG.md.
3. docs/SEASON_RUNNERS.md V2 como alocação de escopo, docs/RUNNER_PROTOCOL.md e docs/RUNNER_STATUS.json como execução.
4. GDD.md/ARCHITECTURE.md e documentação do domínio.
5. docs/research/*.md: dados citados, limites e projetos próprios (não sobrescrever decisões fixadas por alegadas fórmulas de outro jogo).
6. Comentários/commits/relatos históricos do projeto com prova de execução.
Em conflito entre plano antigo V1 e plano V2, V2 prevalece. Se houver solicitação do usuário que ultrapasse runner atual, registrar em decisão e reprojetar antes de codificar.

## 4. Pesquisa: que confiança atribuir a cada item

- A: config original observada em versão específica no estudo comunitário; não equivale a regra universal de runtime.
- N: comportamento inferido de análise estática; exige teste independente para confiança prática.
- O: observação de wiki, guia, gameplay; confronto com versão e outros relatos.
- P: editor/dev confirma característica geral, não parâmetros internos.
- R: documentação oficial Roblox que fundamenta a API.
- H: decisão própria do Entre Reinos, precisa de projeto e teste.
- U: desconhecido. NÃO inferir valores.

Principal fonte de mecânicas: https://github.com/SongZcode/kingdom-two-crowns-mechanics (2.4.2 / rev23529, textos próprios CC BY 4.0). Outras: mods FredApps/abevol/minwoong, Kingdom Wiki, guias e site de Raw Fury. Fonte de Roblox sempre Creator Hub atual. Não executar ou portar DLLs, C# de outros jogos, assets protegidos ou decompiladores.

## 5. Adaptar método, não criar clone

Núcleo que será diferente de Kingdom: mundo 3D por zonas e Terrain nativo; movimento lateral R6 com nado vertical; múltiplos reinos conectados sem troca obrigatória de ilha; trabalhos por inventário real/massa e specialty; construção livre com entrega progressiva/trabalho persistido; economia de produção/comércio/tributo sem moedas surgindo de árvore; raids por objetivos e portais compartilhados; relacionamentos entre NPCs e jogador; montarias e pontes; seis saves independentes.

Não copiar números de custo, HP, temporadas ou física de Kingdom sem calibração própria. Não confundir valores numéricos da configuração de um build com fórmula completa. Histórias/arte/sprites/nomes dos monstros devem ser originais.

## 6. Testes, evidências e limites atuais

Comandos do projeto, somente quando ambiente estiver preparado:
~~~sh
python tools/workspace.py validate
python tools/script_quality.py
python -m unittest discover -s tests -v
python tools/workspace.py build --game entre-reinos --place main
python tools/deploy.py validate
~~~

Executar suite oficial Quality Gate 2.0 e testes novos do runner. Build verde não prova funcionamento real, física ou FPS. Verificar Scene Sync/Place Provision antes de alteração do Place remoto. Id de produção é separado; publicar staging só com identidade verificada e autorização pelo fluxo oficial. Nenhum segredo/tokens em Git.

## 7. Handoff ao final de cada runner

Registrar em docs/runner-receipts/Tn-Rn.md (criar quando runner for implementado):
- SHA HEAD e link de CI, testes/comandos com resultados REAIS e cenário;
- nomes/links dos módulos implementados, API e versionamento de schema;
- efeitos observados e screenshots/vídeos REAIS quando houver;
- bugs, bloqueios e itens ainda não validados no motor/mobile;
- fontes de pesquisa realmente usadas e o que foi adaptado;
- gatilho exato do próximo runner e suas dependências;
- se há necessidade de publicação, autorização, refinamento ou validação manual.

Para perguntas sobre 'o que fazer agora', consultar primeiro status JSON em vez de adivinhar a etapa. Em cada resposta, citar o SHA e não inventar que ações anteriores ocorreram.
