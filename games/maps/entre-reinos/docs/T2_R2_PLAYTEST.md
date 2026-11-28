# Playtest T2-R2 · ER-028 a ER-035

A prévia ativa no staging é a **v23**, com a correção da obstrução das pontes pelas docas, a vegetação aprovada e o mar frontal. [Jogar no Roblox](https://www.roblox.com/games/90623742498445) · [Publicação](https://github.com/Sllay/Roblox-Studios/actions/runs/46082052074)

1. No celular, abra um slot de teste e chegue às docas. Inicie a prévia pelo terreno seco. Confirme a ponte provisória, observe a entrega de materiais e confira a travessia do jogador após o reforço.
2. Siga o rio até o mar. Pela câmera lateral, confira a desembocadura, a continuidade da água entre chunks, a grama e a vegetação ao longo da costa.
3. Marque e colha uma árvore. Salve e reabra o mundo para verificar a ponte e o estado da fonte. [Recibo da v23](runner-receipts/T2-R2-v20-refino.md#publicação-da-v23--27112026)

## Histórico da prévia v20

A prévia econômica **v20** foi publicada no staging existente do Entre Reinos. A API confirmou a revisão, o readback verificou 45 scripts e o Scene Sync posterior confirmou o mesmo digest. O [PR #14](https://github.com/Sllay/Roblox-Studios/pull/14) permanece em rascunho. [Jogar no Roblox](https://www.roblox.com/games/90623742498445) · [Publicação](https://github.com/Sllay/Roblox-Studios/actions/runs/45723383249) · [Scene Sync](https://github.com/Sllay/Roblox-Studios/actions/runs/45723519651)

### Roteiro da partida na v20

1. Abra um slot dispensável e chegue ao sandbox. Em **VILA → PESSOAS**, aproxime-se de um morador. Atribua a profissão e observe ferramenta, atividade, carga e evolução da habilidade. Compare as ordens de obra, estoque e alimentos. Confirme as duas pontes, água, joystick e câmera sob a UI.
2. Em **OBRAS**, construa uma oficina e uma horta. Mande priorizar uma obra. Na **OFICINA**, enfileire tábuas com madeira disponível. Confira o resultado no depósito, o débito de insumos e a formação de um ferreiro/artesão. Use tábuas para construir a forja. Experimente ferro → metal → ferramenta, inclusive quando faltar um insumo.
3. Observe preparo, semeadura e colheita da horta. Compare água próxima e área seca. Atribua um caçador e procure um veado. Verifique que a caça e o alimento passam pelos inventários. Examine fome, descanso e capacidade de produzir alimento sem clicar em receita sempre.
4. Perto do castelo, use **OFICINA E COMÉRCIO** para comprar e vender uma unidade. Compare bolsa, moedas e depósito. Descubra o Cedro, estabeleça acordo comercial e abra um frete. Verifique a diferença entre carga reservada, em trânsito e recebida, e que uma ponte indisponível impede entrega. Observe tributo, postura dos reinos e condições de aliança.
5. Em **PESSOAS**, converse, presenteie com uma tábua, ofereça comida a alguém com necessidade e ajude um morador ameaçado a alcançar abrigo. Observe relações e mudança de disposição. Navegue e construa sem esconder a área central com controles de gerenciamento.
6. Passe tempo longe de um dos reinos e volte. Registre o progresso dentro da mesma sessão. Salve, saia e reabra. Confirme que ambos os estoques, a tesouraria, o estágio do frete, a posição e os moradores continuam coerentes. Nenhum progresso é acumulado com o jogo fechado.

### Preparação da publicação da v20

O criador autorizou uma publicação intermediária do candidato `c905eca3437ecd124c6afac6cce0df21df31f8e1` no staging existente do Entre Reinos, Universe `10769712413`, Place `90623742498445`, em substituição à v19. A autorização permite migrar saves compatíveis de ruleset 4 para 5 com backup por slot. [Protocolo](RUNNER_PROTOCOL.md#exceção-autorizada-t2-r2)

A operação reutiliza o fluxo oficial, a credencial existente, o grupo de concorrência do staging e os gates de SHA, Rojo e Luau. O workflow guarda o RBXLX exato da v19, verifica a cena pela API e recusa um baseline diferente. A conclusão exige confirmação de publicação pela API, leitura independente dos scripts e Scene Sync posterior. O arquivo e o histórico v19 permitem rollback de cena. Para voltar um save já migrado, isolar o snapshot 5 e validar o backup 4 do slot antes de uma restauração autorizada.

A versão regional anterior está registrada com digest `4791eeead3928fe5187339b982f594a71987866b6ee263d06fe41b1453b0d482`. A inspeção de preparação confirmou o mesmo digest, 97 objetos e zero conflitos. O publicador deve conferir o valor novamente imediatamente antes de escrever. [Readback v19](https://github.com/Sllay/Roblox-Studios/actions/runs/45686307039) · [Scene Sync v19](https://github.com/Sllay/Roblox-Studios/actions/runs/45723157400)
