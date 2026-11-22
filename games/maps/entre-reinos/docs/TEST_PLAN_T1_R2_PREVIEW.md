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

## v9 — reteste visual após bugs encontrados no preview v8

1. **Fechar a sessão antiga e abrir Place atualizado v9**, Mundo 1 seed 516639272, sem excluir save.
2. NPCs com **pés sobre a grama**, não apenas cabeça/ombro visíveis. Não devem avançar em degraus de 8 FPS enquanto jogo está a 60.
3. Entrar no rio e observar **braços/pernas de R6 realizando braçadas**, não walk nem fall; sair e garantir que walk/jump originais retornem sem travar. A correção usa estado `Swimming` + fallback visual de R6; não é uma animação R15 disfarçada.
4. Recursos e obras exibem **somente letra pequena com borda preta**, sem retângulos pretos tapando a cena. Etiquetas aparecem apenas quando perto.
5. Câmera ligeiramente mais próxima e árvores de silhueta **verdes muito escuras**, em vez de triângulos pretos.
6. Menu construir e estoques ainda funcionam; entrar no Mundo 1 novamente não perde casas/recursos, seed ou posição.
7. A profundidade de background Z ainda não foi ampliada neste preview; anotado e versionado para geração futura sem afetar saves existentes.

Provas v9: CI https://github.com/Sllay/Roblox-Studios/actions/runs/45036214420; publicação https://github.com/Sllay/Roblox-Studios/actions/runs/45036519730; motor Roblox https://github.com/Sllay/Roblox-Studios/actions/runs/45036652831 (16/16 + pés R6 0.14 stud do Terrain).
