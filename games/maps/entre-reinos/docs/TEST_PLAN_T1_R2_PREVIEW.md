# T1-R2 — teste inicial do preview Roblox v8

**Acesso:** https://www.roblox.com/games/90623742498445 (Place staging, revisão publicada 8).

**Antes:** feche totalmente os servidores v7. Não exclua o Mundo 1 — seed conhecida `516639272`.

1. **Entrar no Mundo 1**; o carregamento deve passar de Terrain para **moradores** e concluir. Confirmar 4 personagens R6 próximos do centro do mapa, sem travar.
2. **Natação nativa:** entrar no rio, mover joystick; observar se a animação `Swimming` acompanha e para ao sair da água. A restauração do `Animate` foi incluída, mas ainda não há prova visual do efeito.
3. **Menu Construir** logo abaixo da interface Roblox, no canto esquerdo superior. Não deve cobrir joystick ou pulo. Abrir e clicar **Abrigo** perto da posição inicial.
4. Observar blueprint e etiquetas com madeira/pedra exigidas; NPCs devem ir a fontes físicas, colher quantidades finitas, carregar até a obra, entregar e construir. Conferir que trabalho não fica tremendo ou preso.
5. **Estado persistente:** antes de completar, sair do jogo; reentrar no mesmo Mundo 1 e conferir a obra parcial e inventário/NPCs. Não duplicar recursos nem iniciar obra nova automaticamente.
6. Registrar FPS e eventual mensagem de erro. Com print + Developer Console, podemos corrigir a causa diretamente.

**Evidência:** CI https://github.com/Sllay/Roblox-Studios/actions/runs/45033200114; Roblox publicação https://github.com/Sllay/Roblox-Studios/actions/runs/45033471243; readback engine https://github.com/Sllay/Roblox-Studios/actions/runs/45033671441 (16 checks, 4 NPCs de simulação, 11 materiais, 1 construção e 1 reparo, R6 model oficial PASS). O readback é sessão isolada, não substitui cliente real.

**Gate:** T1-R2 continua `in_progress`; ainda serão refinadas a logística de armazéns, posicionamento livre e animação/LOD dos trabalhadores antes de aceitar esse runner. T1-R3 continua bloqueado.
