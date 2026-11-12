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
