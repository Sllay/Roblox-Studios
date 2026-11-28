# Prévia regional · T2-R1

**Situação em 25/11/2026:** a prévia regional **v19** está disponível no staging existente, Universe `10769712413`, Place `90623742498445`. A API confirmou a publicação. A leitura independente conferiu os 41 scripts e o Scene Sync posterior confirmou o mesmo digest. O PR #13 segue em rascunho e a certificação visual está aberta. [Jogar no Roblox](https://www.roblox.com/games/90623742498445) · [Publicação](https://github.com/Sllay/Roblox-Studios/actions/runs/45686307039) · [Readback](https://github.com/Sllay/Roblox-Studios/actions/runs/45686307039/job/139459713609) · [Scene Sync](https://github.com/Sllay/Roblox-Studios/actions/runs/45686521277)

## Caminhos que entram pela interface normal

| Contrato | Entrada e comportamento integrados | Validação formal restante |
|---|---|---|
| ER-021 · **PARCIAL** | Boot usa o perfil regional. Cinco regiões e 49 chunks sob demanda. Biomas, recursos, margens e cascatas 3D acompanham o Terrain. O probe confere 156.672 voxels da v18. | Explorar em cliente e confirmar transições, leitura de biomas, rios e cascatas. |
| ER-022 · **PARCIAL** | VILA → OBRAS lista as duas pontes. O servidor valida a margem, materiais e obra. Trabalhadores entregam e constroem. A ruína invalida o tabuleiro e as pilhas recuperáveis aparecem na margem de trabalho. | Confirmar prévia, construção, reforço, reparo, cancelamento e ruína em partida. |
| ER-023 · **PARCIAL** | Trabalhadores do WorkEngine resolvem a travessia por classe. O ensaio verifica carga passando pelo tabuleiro, depósito além da fronteira e recusa de caminho destruído. | Observar em cliente desvio, portões, abrigo e tarefas durante ameaça. |
| ER-024 · **PARCIAL** | As populações reutilizam as próprias identidades, custódia e jobs ao voltar. Regiões distantes mantêm o estado congelado e instâncias de NPC são reconstruídas quando necessário. | Medir picos de streaming, memória e custo de cliente. Progresso distante é provisório. |
| ER-025 · **PARCIAL** | Em sandbox, aproximar-se do estábulo oferece compra por 12 moedas. Ação contextual monta/desmonta, controle lateral move o cavalo. A montaria conserva vida e energia; água profunda exige ponte reforçada. | Verificar controle, ritmo, leitura de poses e balanço em aparelho. Equipamento e domesticação dependem das regras de design aplicáveis. |
| ER-026 · **PARCIAL** | Doca oferece embarque e desembarque. OFICINA transfere madeira com o barco atracado. Após descobrir as duas capitais, estar a pé junto ao centro habilita a viagem rápida. O destino é confirmado no save antes do movimento. | Manobrar, transportar, salvar e reabrir em cliente. Aprovar equilíbrio de rotas e custos. |
| ER-027 · **PARCIAL** | Há segundo reino persistente com distrito, centro, moradores e galpões próprios. O caderno ESTOQUE indica lado e distância da Vila do Cedro até a descoberta. | Ir a pé pelos controles normais, observar trabalhos, sair, retornar e verificar identidades e estoques. |

## Autorização e procedimento

Em 25/11/2026 o criador confirmou que o Universe `10769712413`, Place `90623742498445`, já é o ambiente de desenvolvimento do Entre Reinos. Autorizou uma única prévia regional para substituir a v18 nesse Place e a migração de saves compatíveis 3 → 4 pelo fluxo existente, sem apagar slots. O candidato é `f7d4ac685f2372d066cdf49a19b2b978f2454745`. Esta decisão substitui o plano de outra experiência. O PR #13 segue em rascunho. [Protocolo](RUNNER_PROTOCOL.md#exceção-autorizada-t2-r1)

O [workflow da prévia](https://github.com/Sllay/Roblox-Studios/blob/f50dbfd8ca600e96952db836765590bd9497dea7/.github/workflows/entre-reinos-t2-r1-preview.yml) usa o secret existente do ambiente staging e recebe a confirmação no [registro de destino](sync/t2-r1-preview/target.json). Ele confere as evidências por SHA, inspeciona identidade e revisão, verifica a cena da v18 e o arquivo de rollback, recompila o candidato e aciona o mesmo publicador da Assets API. Uma mudança de revisão ou digest bloqueia o upload. O Scene Sync prévio observou 90 objetos e nenhuma alteração ou conflito desde a v18 registrada. [Scene Sync](https://github.com/Sllay/Roblox-Studios/actions/runs/45685859918)

### Dados e recuperação

- A publicação só altera o Place. O SaveSlotService migra cada slot compatível na primeira escrita de ruleset 4, após validar e persistir o backup da revisão legada do slot. Formatos futuros continuam protegidos. O probe da branch testou backup, restauro e reabertura em DataStore sintético. [Probe](https://github.com/Sllay/Roblox-Studios/actions/runs/45671224264)
- O rollback de cena usa a revisão histórica **18** do mesmo Place. O workflow guarda também o RBXLX compilado do SHA que publicou a v18, `98f81262ff93066c759b915253d557193e3efc9f`, com hashes de scripts conferidos. Em caso de rollback autorizado, encerrar as sessões de teste, restaurar a v18 pelo histórico do Roblox e confirmar nova revisão, Scene Sync e hashes.
- Voltar a cena para v18 mantém os slots já migrados em ruleset 4, que a v18 recusa abrir. Restaurar só o slot identificado, mediante autorização própria e validação do backup correspondente, preservando uma cópia do snapshot regional para evitar descartar o progresso do playtest. A publicação não faz restauração ou exclusão de dados.
- Depois da confirmação pela Assets API, o workflow lê novamente o Place publicado e compara os scripts com o RBXLX. O recibo registra revisão, hashes e inventários. Em caso de resposta ambígua, consultar o Place antes de qualquer nova tentativa.

## Roteiro de playtest mobile

1. Abrir um slot descartável. Registrar revisão, seed, modelo/OS e preset. Completar a abertura da campanha. Confirmar joystick, salto e botões de borda.
2. Em **VILA → ESTOQUE**, seguir a indicação da Vila do Cedro. Caminhar até lá, observar os biomas e margens. Anotar uma travessia a pé e verificar o primeiro morador e o conteúdo visível dos galpões. Sair da região e retornar. Comparar moradores, trabalho e quantidades.
3. Em **VILA → OBRAS**, deixar trabalhadores construírem uma ponte provisória com 12 madeiras. Ver entrega física e travessia. A reforçada exige 20 madeiras e 12 pedras no total. Testar o bloqueio do cavalo no apoio antes do reforço e a travessia depois. Comprar o cavalo por 12 moedas, montar e desmontar pelo botão contextual. Conferir perda e recuperação de energia.
4. Embarcar junto ao barco. Com ele atracado, usar **OFICINA** para carregar uma madeira. Navegar com o controle lateral, desembarcar, retirar a carga e comparar a bolsa. Se for seguro no slot descartável, testar também morrer a bordo e retornar ao castelo sem ser reconectado ao assento.
5. Após descobrir as duas capitais, testar a ação contextual de viagem a pé junto ao centro. Salvar perto da Vila do Cedro e reabrir. Conferir a posição, a integridade da bolsa, o veículo e o estado de cada reino. Para testar migração, usar somente cópia ou slot sintético v18 com backup verificado.
6. Repetir as transições mais custosas com as estatísticas do cliente ativadas. Registrar tempo de carregamento, FPS, frame pacing, memória e vídeo de qualquer travamento ou ação difícil de operar.

Use esse roteiro na revisão regional especificada no [recibo de publicação](runner-receipts/T2-R1.md). A [certificação da fundação](T1_CERTIFICATION_V18.md) continua rastreada.
