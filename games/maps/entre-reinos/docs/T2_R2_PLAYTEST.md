# Prévia econômica T2-R2 · ER-028 a ER-035

O [PR #14](https://github.com/Sllay/Roblox-Studios/pull/14) tem como base a branch regional do PR #13. O candidato contém a camada econômica e social testada em execução descartável na v19. As revisões publicadas e o aceite humano estão no [recibo](runner-receipts/T2-R2.md).

## Roteiro de partida

1. Abra um slot dispensável e chegue ao sandbox. Em **VILA → PESSOAS**, aproxime-se de um morador. Atribua a profissão e observe ferramenta, atividade, carga e evolução da habilidade. Compare as ordens de obra, estoque e alimentos. Confirme as duas pontes, água, joystick e câmera sob a UI.
2. Em **OBRAS**, construa uma oficina e uma horta. Mande priorizar uma obra. Na **OFICINA**, enfileire tábuas com madeira disponível. Confira o resultado no depósito, o débito de insumos e a formação de um ferreiro/artesão. Use tábuas para construir a forja. Experimente ferro → metal → ferramenta, inclusive quando faltar um insumo.
3. Observe preparo, semeadura e colheita da horta. Compare água próxima e área seca. Atribua um caçador e procure um veado. Verifique que a caça e o alimento passam pelos inventários. Examine fome, descanso e capacidade de produzir alimento sem clicar em receita sempre.
4. Perto do castelo, use **OFICINA E COMÉRCIO** para comprar e vender uma unidade. Compare bolsa, moedas e depósito. Descubra o Cedro, estabeleça acordo comercial e abra um frete. Verifique a diferença entre carga reservada, em trânsito e recebida, e que uma ponte indisponível impede entrega. Observe tributo, postura dos reinos e condições de aliança.
5. Em **PESSOAS**, converse, presenteie com uma tábua, ofereça comida a alguém com necessidade e ajude um morador ameaçado a alcançar abrigo. Observe relações e mudança de disposição. Navegue e construa sem esconder a área central com controles de gerenciamento.
6. Passe tempo longe de um dos reinos e volte. Registre o progresso dentro da mesma sessão. Salve, saia e reabra. Confirme que ambos os estoques, a tesouraria, o estágio do frete, a posição e os moradores continuam coerentes. Nenhum progresso é acumulado com o jogo fechado.

## Preparação da publicação

O destino da prévia é o staging existente, Universe `10769712413`, Place `90623742498445`, atualmente na v19. A autorização de publicação da T2-R1 foi específica de seu SHA e revisão. A prévia T2-R2 precisa de autorização única para o novo candidato, com substituição da v19 e migração 4 → 5 com backup. O playtest é posterior à publicação autorizada. A integração formal segue o protocolo. [Exceção anterior](RUNNER_PROTOCOL.md#exceção-autorizada-t2-r1)

Após autorização, conferir a identidade, os testes e a equivalência da árvore aprovada. Reutilizar o fluxo oficial com o secret existente, Scene Sync atual, checagem e arquivo de rollback da v19, compilação Luau/Rojo e concorrência do staging. A condição de sucesso é publicação confirmada pela API, leitura independente dos scripts e Scene Sync posterior. O workflow de prévia deve fixar o candidato e abortar se a revisão ou o digest mudarem. O arquivo e o histórico v19 são a rota de rollback de cena. Para voltar um save já migrado, isolar o snapshot 5 e validar o backup 4 do slot antes de qualquer restauração autorizada.

A versão regional anterior está registrada com digest `4791eeead3928fe5187339b982f594a71987866b6ee263d06fe41b1453b0d482`. A inspeção de preparação confirmou o mesmo digest, 97 objetos e zero conflitos. O publicador deve conferir o valor novamente imediatamente antes de escrever. [Readback v19](https://github.com/Sllay/Roblox-Studios/actions/runs/45686307039) · [Scene Sync v19](https://github.com/Sllay/Roblox-Studios/actions/runs/45694418587)
