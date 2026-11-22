# T1-R1 — R6 Hotfix, staging revisão Roblox 3

**Estado:** publicado no Place de testes; **não** encerrado T1-R1. Reteste mobile pendente.

| Medida | Evidência |
|---|---|
| Universo | 10769712413 |
| Place | 90623742498445 |
| Revisão | 3 |
| Código R6 | `01e90365974e3241b49e489a83a3adb28fad9999` |
| CI código | https://github.com/Sllay/Roblox-Studios/actions/runs/44976179460 |
| Probe API R6 | https://github.com/Sllay/Roblox-Studios/actions/runs/44976095162 |
| Publicação Roblox | https://github.com/Sllay/Roblox-Studios/actions/runs/44976293591 |
| Readback independente | https://github.com/Sllay/Roblox-Studios/actions/runs/44976379375 |
| Serviços presentes na versão 3 | 11 / 11, incluindo CharacterService |

**Problema relatado:** bloquear a criação de mundo com texto sobre configurar R6 no Place. **Causa:** verificação de rig R15 no Boot antes de criar slot, sem conversão.

**Reparo:** criar R6 verdadeiro no servidor usando o método oficial `CreateHumanoidModelFromDescriptionAsync`; trocar o `Player.Character` inteiro antes de abrir/criar save, com rejeição segura em caso de falha e tratamento de respawn. Não falsifica `Humanoid.RigType`.

**Teste prioritário:** sair do servidor antigo, abrir a experiência, selecionar Jogar > Mundo 1 > Criar. Deve iniciar R6 e geração do mundo, sem mensagem exigindo Avatar Settings. Depois testar movimento, água, câmera, persistência e FPS.

**Limite das evidências:** leitura via Open Cloud valida que os scripts estão salvos, e a API probe comprova que a engine consegue construir R6 em contexto sem persistência. A experiência real ainda precisa do jogador para confirmar a troca de Character, física e render. Nenhum código foi enviado ao Black Island ou à produção.
