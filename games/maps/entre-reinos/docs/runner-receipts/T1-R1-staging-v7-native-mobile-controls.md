# T1-R1 — staging v7: Native Roblox controls and safe developer HUD

**Estado:** publicado em staging, código verificado, aguardando reteste touch do criador.

## Problemas da foto real (v6)

O mundo carregou e o avatar apareceu no Terrain (seed 516639272), mas cinco botões customizados se sobrepunham e o painel FPS no topo esquerdo ficava atrás da interface Roblox. Criador solicitou joystick + jump originais, com lógica lateral e nado adaptada.

## Alterações
- Removido `ContextActionService` e `ControlModule:Disable()`; retido `PlayerModule:GetControls():GetMoveVector()` para joystick touch, teclado e gamepad. Jump continua nativo.
- `ReplicatedStorage/InputProjection.luau`: vector X,Z -> XY: X vai esquerda/direita; Z somente face front/back em terra; na água joystick frente/trás se converte a Y subir/descer. Deadzone, analógico e diagonal normalizada.
- `ClientBoot`: `ScreenInsets=CoreUISafeInsets`, painel FPS ancorado direita superior, após topbar CoreUI.

## Evidência
- CI completo: https://github.com/Sllay/Roblox-Studios/actions/runs/45031416589, green.
- Roblox Place publicado v7: https://github.com/Sllay/Roblox-Studios/actions/runs/45031576169, success.
- Roblox Luau Execution readback independente: https://github.com/Sllay/Roblox-Studios/actions/runs/45031693274, success, 11 checks + módulo InputProjection executado + diagonal normalizada.
- `Players.MaxPlayers=1` observado, nenhuma configuração alterada.
- Nada desta validação prova a renderização exata do joystick no iOS/Android; gate do usuário ainda pendente.

## Teste a fazer
Abrir o Place após fechar sessão v6; Mundo 1; verificar joystick e pulo padrão, ausência de setas duplicadas e painel FPS top-right; caminhar lateralmente, olhar frente/trás em solo, nadar e testar movimento diagonal usando thumbstick. Verificar save/posição após reentrar. Não excluir Mundo 1.

**T1-R1: in_progress**. Não iniciar T1-R2 até aceitação mobile.
