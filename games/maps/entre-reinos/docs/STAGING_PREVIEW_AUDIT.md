# Entre Reinos — publicação antecipada de teste T1-R1

Solicitação explícita de 21/11/2026: concluir o trabalho pendente do T1-R1 e publicar uma atualização em **staging** para que o criador teste no celular. Isso é uma **exceção de teste dentro da T1**, não valida T1-R1 nem autoriza produção, e não altera o marco de publicação oficial da temporada depois de T1-R3.

## Identidade verificada (somente leitura)
- Universe: `10769712413`.
- Place: `90623742498445`.
- Versão Roblox: `1`.
- Fonte: https://github.com/Sllay/Roblox-Studios/actions/runs/44975065621.
- `place_provision.py enroll --record=false` confirmou `game.GameId` e `game.PlaceId` diretamente no contexto do Roblox.
- `deploy.targets.json` staging atualizado; production permanece sem IDs.
- Chave `ROBLOX_OPEN_CLOUD_API_KEY` existe e autorizou leitura; **publicação ainda não confirmada**.

## Verificação antes de substituir o Place
- Fazer inventário READ ONLY de Workspace, ReplicatedStorage, ServerScriptService, ServerStorage, StarterPlayer, StarterGui, StarterPack e Lighting. Não assumir vazio somente porque PlaceVersion=1.
- Revisar se há conteúdo externo/persistido que o Rojo apagaria; confirmar se o repositório é fonte integral da cena.
- Somente após inventário aprovado marcar `fullPlaceBuildAuthoritative: true` para este novo Place, nunca para mapa-principal.
- Confirmar R6 nas configurações da experiência; caso contrário o servidor impede iniciar o mundo.
- Reexecutar CI, registrar backup/versão anterior e disparar `publish.yml` manual com `game=entre-reinos, place=main, environment=staging`, ambas confirmações verdadeiras APENAS se a substituição for verificada.
- Publicação não ocorre só por push, CI verde ou configuração de IDs. Exigir resposta de API `isPublished=true` e versionId correto.

## Protocolo de teste após publicação
1. Entrar no novo mapa (não Black Island), verificar o menu e seis slots.
2. Criar um mundo, confirmar que Terrain 3D e rio carregam sem erro e que o R6 aparece.
3. Testar andar só em X, girar em terra com cima/baixo sem deslocamento em Z, saltar, nadar vertical e diagonal, voltar à terra.
4. Caminhar até a borda da região, verificar limite sem queda/deslocamento na câmera.
5. Verificar UI/foreground, sem oclusão de avatar e materiais de Terrain com cores naturais.
6. Reentrar no mesmo slot após sair e verificar seed/posição; criar outro slot e confirmar isolamento. Excluir somente slot de teste e verificar que o outro permanece.
7. Medir FPS e oscilação de Z pelo painel no celular; enviar screenshot/log ou relato de falhas.

**Não emitir check verde do T1-R1 sem teste de runtime e mobile, mesmo que staging tenha sido publicado.**

## Revisão do Place e preparação concluída (21/11/2026)

A checagem completa de somente leitura foi executada em https://github.com/Sllay/Roblox-Studios/actions/runs/44975381075. Snapshot versionado: `docs/sync/main/staging.json` e `staging.summary.json`.

- Versão publicada observada: `1`; Universe `10769712413`; Place `90623742498445`.
- 179 instâncias inspecionadas incluindo padrão de PlayerModule/AtomicBinding, 4 Script e 56 ModuleScript nativos da cena padrão, 1 Baseplate, 1 SpawnLocation, 1 Terrain, Camera e efeitos padrão. Sem assets ou sistemas de jogo externos identificados.
- Hash de baseline: `0b52f3641643afdc4d547d83339161f79b57ed38dfe03eb0dc67ce0aeffa96cd`.
- Sem região Terrain registrada como conteúdo próprio; cenário é template padrão v1.
- Permitida a declaração `fullPlaceBuildAuthoritative: true` **somente para este Place de novo staging**, com substituição intencional da cena padrão. Nenhuma autorização de substituição no Black Island nem em produção.
- Snapshot estrutural serve de pré-condição de Scene Sync, **não é backup binário completo**. Versão anterior permanece no histórico Roblox conforme política da plataforma, sem rollback automaticamente testado.
- Próximo passo: `publish.yml` manual. Este arquivo não comprova publicação. O workflow precisa executar `tools/deploy.py publish --execute`, consultar a operação e confirmar `isPublished=true`.

## Resultado efetivo de publicação e prova de reabertura

- `published=true` confirmado em https://github.com/Sllay/Roblox-Studios/actions/runs/44975639993; retorno de publicação `revision 2`, Place ID corresponde ao alvo.
- Readback independente de versão 2 e 11/11 scripts/componentes Rojo presentes: https://github.com/Sllay/Roblox-Studios/actions/runs/44975725822.
- **Não** publicar produção, **não** declarar R6/avatar/água funcional antes do teste do dono, **não** antecipar T1-R2.
- A primeira checagem de movimento deve inspecionar R6 e possível mensagem de Avatar Settings. Sem a opção correta, o servidor rejeita iniciar um mundo, mesmo com scripts publicados.
