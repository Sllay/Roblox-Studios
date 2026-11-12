# Inspeção e importação de decoração estática — v1

## Limites e política

A auditoria usa AssetService:LoadAssetAsync em uma tarefa Open Cloud. O modelo fica desanexado, é examinado e descartado sem salvar o Place. Roblox fornece isolamento de scripts por padrão. A política rejeita qualquer classe não permitida, incluindo scripts, remotes, constraints e objetos de comportamento. Só aceita Model, Folder, Part, MeshPart, SpecialMesh, Decal, Texture e SurfaceAppearance. Limites iniciais: 350 descendentes, 100 Parts, 100 referências de conteúdo, 512 studs de dimensão. IDs de conteúdo devem ser rbxassetid:// numéricos; dependências são enumeradas, não são garantia de licença, acesso ou desempenho real.

A importação **só pode escrever em staging**. Não habilitar Allow Loading Third Party Assets automaticamente nem recorrer a cookies. Se o Roblox negar o carregamento, registrar o bloqueio. Consulte https://create.roblox.com/docs/reference/engine/classes/AssetService#LoadAssetAsync.

## Sequência

1. Pesquisar no Creator Store, revisar galeria e registrar candidato em catalog.json usando catalog.py.
2. Executar Asset audit and safe staging import com operation=audit, asset_id real, game/place/environment staging. O relatório audit.json inclui a versão carregada, a lista de classes, contagem, dependências, dimensões e assinatura estrutural.
3. Revisar a política, os direitos, a adequação visual e posição. Não confundir auditoria estática com licença ou aprovação de dependências.
4. Preparar um plano revisado e versioná-lo sob game/assets/imports. Exemplo:

    python tools/assets/pipeline.py prepare --game mapa-principal --place main --environment staging --asset-id 123456 --managed-id palm-tree-01 --position 12 5 20 --yaw 30 --biome praia --rights-review "Direitos de uso revisados e autorizados" --audit /tmp/audit.json --plan games/maps/mapa-principal/game/assets/imports/palm-tree-01.json

5. Revisar o diff do plano no GitHub. Acionar workflow operation=apply, environment=staging, plan=palm-tree-01.json, confirmação explícita. O plano deve estar na main.
6. Capturar snapshot antes; checar versão e ID persistente; recarregar e auditar o asset na mesma tarefa que salva; rejeitar divergências nas propriedades inspecionadas. Somente inserir em Workspace.RSManagedAssets, nunca sobrescrever objetos existentes. Remover tags/atributos do modelo importado e desativar colisão, toque e consultas físicas; ancorar. Não é sistema para objetos interativos.
7. Ler novamente e verificar modelo, classe, contagem, propriedades físicas e nova versão. Guardar before.json, after.json, diff.json, save-result.json e verification.json nos artifacts.

## Snapshots e concorrência

scene_snapshot.py captura até 5000 descendentes do Workspace e recusa truncamento. Guarda versão do Place, hash, classes, transformações, materiais e IDs gerenciados. Diff: python tools/scene_snapshot.py --before before.json --after after.json. É comparação estrutural, não um backup integral; não cobre Terrain voxel, propriedades completas, scripts ou dados persistentes.

O teste de versão reduz o risco de alterações concorrentes, mas não é uma transação atômica do Roblox. Não editar o mesmo Place por outro fluxo durante a importação. Se o salvamento tiver resultado ambíguo, não repetir antes de consultar versões e o ID gerenciado. Não existe rollback automático nesta fase. A versão anterior permanece referência para recuperação conforme as opções oficiais do Roblox.

## Estado

O fluxo é inicialmente limitado a decoração estática; não há compra automática, scripts de terceiros, validação visual de cena renderizada, exportação integral do modelo para Rojo ou promoção para produção. Git guarda o plano e evidências; o modelo remoto é materializado via Open Cloud. Não usar o build Rojo de um Place parcialmente gerenciado para substituir sua cena inteira.

## Evidências iniciais

- Snapshot remoto: versão 2, 8 objetos do Workspace ([execução](https://github.com/Sllay/Roblox-Studios/actions/runs/43128968404)).
- Asset 257489726: carregado e recusado corretamente; 2 Scripts, Humanoid, sons e juntas, 7 Parts, 26 descendentes ([auditoria](https://github.com/Sllay/Roblox-Studios/actions/runs/43129081020)).
- Primeira tentativa falhou ao ler AllowInsertFreeAssets (capacidade protegida); leitura removida. Não alterar permissões automaticamente.
- Full Place publish bloqueado por padrão; requer fullPlaceBuildAuthoritative=true no registro do Place, após verificação explícita de que Git representa a cena completa. Não habilitar para o mapa-principal.

A verificação pós-save exige também o pivot (posição e rotação), Biome e versão consistente; se o diff indicar remoções inesperadas, o job reporta falha e mantém evidências. Não confundir isso com rollback automático.

## Bloqueio real do Creator Store

A busca de seis candidatos de árvore low-poly encontrou cinco respostas `User is not authorized to access Asset` e uma HTTP 429 ([teste](https://github.com/Sllay/Roblox-Studios/actions/runs/43129206356)). Nenhum asset foi importado. A autorização de leitura das miniaturas não concede acesso ao conteúdo do modelo. O `Allow Loading Third Party Assets` é uma configuração oficial da experiência, documentada como modificável pelo Studio; não tentamos contornar nem ativar essa configuração remotamente. Para homologar sem depender de Studio local, priorize um modelo próprio, do Roblox ou explicitamente compartilhado pelo proprietário; modelos públicos de terceiros podem exigir configuração adicional. Use o Creator Dashboard para verificar permissões. Não interpretar uma falha de autorização como reprovação de segurança do conteúdo.

O workflow final é exclusivamente manual. O teste unitário simulado exercita a sequência de aplicação, verificação e evidências; a aplicação real ainda depende de IDs staging e um asset autorizado e aprovado. O CI aprovado inclui Python, gate Luau e build Rojo ([execução](https://github.com/Sllay/Roblox-Studios/actions/runs/43129285381)).

## Pré-validação de acesso e staging

- Workflow Asset access preflight: informa separadamente asset_access_denied, loadable_policy_rejected, loadable_policy_pass, rate_limited, cloud_access_denied e falhas indeterminadas. Uma resposta de diagnóstico bem-sucedida não implica autorização de importação. O resultado é específico ao Place e ao asset; não reutilizar como prova de outro ambiente.
- Workflow Staging readiness: valida os IDs e consulta a identidade real pela Open Cloud. Não testa gravação, não cria experiências e não muda permissões. O validador global impede que um Universe de produção seja cadastrado como staging, ou que um mesmo Place seja usado por dois destinos.
- API de compartilhamento oficial: PATCH /asset-permissions-api/v1/assets/permissions, escopo asset-permissions:write. Requer autoridade real sobre o asset e o destinatário; não foi habilitada escrita de permissões automática. https://create.roblox.com/docs/cloud/reference/scopes
- Adquirir um modelo grátis pelo Creator Store pode ajudar quando a conta é a proprietária da experiência, conforme o anúncio oficial de LoadAssetAsync. Não garante acesso para experiências de grupo ou dependências; confirmar com preflight. https://devforum.roblox.com/t/loading-third-party-model-assets-in-experience/3939065
- Para staging, utilizar uma experiência existente separada ou criar uma pelo fluxo oficial do Roblox. Não há criação de Universe por API key documentada nas APIs públicas consultadas. Não solicitar cookie de sessão.

### Validação do preflight

Asset 12549617200 foi classificado corretamente como `asset_access_denied` na versão 2 do Place de produção ([execução 43130702988](https://github.com/Sllay/Roblox-Studios/actions/runs/43130702988)). O workflow é somente manual; sucesso significa diagnóstico concluído, não liberação do asset. Staging ainda não tem IDs configurados. Nenhuma escrita no Roblox foi realizada nesta etapa.

## Destino de homologação informado

Staging do mapa-principal: Universe 10769712441, Place 93428341652658. Candidato escolhido pelo usuário: [Yasu's Stylized Tree Pack](https://create.roblox.com/store/asset/79689531752352/Yasus-Stylized-Tree-Pack), Asset ID 79689531752352. Identidade, autorização, política e importação ainda dependem de verificação remota. Produção permanece separada.

### Resultado de homologação do destino (2026-11-11)

- Staging 10769712441/93428341652658: identidade confirmada com a chave existente, versão 1, snapshot de 6 objetos. [Execução real](https://github.com/Sllay/Roblox-Studios/actions/runs/43131202122).
- Asset 79689531752352 (Yasu's Stylized Tree Pack): `asset_access_denied` (User is not authorized to access Asset). Não foi possível inspecionar seu conteúdo. Não confundir este ID com outras listagens homônimas.
- Pendência: confirmar aquisição via Get Model pela conta proprietária da experiência (ou autorização explícita do proprietário do asset). Depois repetir o preflight manual. Não habilitar permissões por meios não documentados, não gravar no Place enquanto o asset estiver bloqueado.
- A chave tem acesso à execução de leitura no staging; permissão de SavePlaceAsync ainda não testada. Nenhuma importação ou publicação feita.

### Get Model e texturas PBR

A aquisição confirmada pelo usuário permitiu carregar o pacote 79689531752352. A auditoria inicial atingiu SurfaceAppearance.ColorMap e falhou por ausência de capacidade Plugin (execução 43131478842). O inspetor agora registra propriedades inacessíveis, distingue inspeção incompleta de acesso negado e mantém o bloqueio de importação. Uma sonda oficial SerializationService/EncodingService registra somente tamanho/hash, não exporta modelo nem modifica o Place. Hash não prova segurança das dependências. https://create.roblox.com/docs/reference/engine/classes/SurfaceAppearance

### Get Model retest — confirmed

After the user acquired 79689531752352, the same staging key successfully loaded the model. Run 43131478842 initially failed on restricted PBR ColorMap access; run 43131666285 completed with `loadable_audit_incomplete`, no writes, staging still version 1 and 6 Workspace objects. The model contains 1,096 descendants; the first 350 include 122 Parts, 56 SurfaceAppearances and UI classes. Whole-pack bounds approximately 149 x 195 x 673 studs. Official SerializationService returned 370,728 bytes and a SHA-256 fingerprint; no third-party binary was exported. The pack exceeds static policy and cannot be imported as a unit. Next: inventory individual submodels, select a tree, inspect its dependencies (including protected PBR maps using authorized offline serialization), and re-audit before a reviewed staging import. Never infer absence of scripts from the truncated sample. https://github.com/Sllay/Roblox-Studios/actions/runs/43131666285

Auto Get Model: official Creator Store APIs support search, details, listings and collection saves; no equivalent public Open Cloud acquisition endpoint confirmed. Collection saves are not acquisition. Keep free acquisition user-mediated; do not store Roblox session cookies or automate purchases. https://create.roblox.com/docs/cloud/reference/features/creator-store

## Asset Pack Inspector

`python tools/assets/pack.py --asset-id 79689531752352 --sample` inventaria o pacote no staging e clona um candidato técnico isolado. Para escolher um modelo específico, use `--selector caminho.json` com o array `selector` retornado em `pack.json`. O workflow Asset Pack Inspector também recebe `selector_json`. O seletor inclui índice, nome e classe de cada filho; não é um Asset ID independente nem identidade imutável. Se o caminho mudar, a ferramenta recusa. Reauditar o modelo recarregado antes de qualquer futura importação. O clone não entra no Workspace; a serialização registra apenas tamanho e hash, sem publicar binários de terceiros. Até 10.000 descendentes e 256 Models por inventário; o relatório marca truncamento de candidatos. A seleção técnica automática não avalia aparência, bioma nem licenças.

Teste real 43132197268: 1.096 descendentes, 29 Models, zero LuaSourceContainer no pacote, 20 árvores e três arbustos elegíveis como candidatos técnicos, 2 MeshParts e 2 SurfaceAppearances cada. Bush_01 clonado, 4 descendentes, 7.025 bytes serializados. Auditoria individual bloqueada por propriedades PBR restritas. Nenhuma escrita no Place. https://github.com/Sllay/Roblox-Studios/actions/runs/43132197268
