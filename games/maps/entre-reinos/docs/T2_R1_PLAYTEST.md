# Prévia regional · T2-R1

**Situação em 25/11/2026:** candidato no [PR #13](https://github.com/Sllay/Roblox-Studios/pull/13), em rascunho. O staging ainda carrega v18 (Universe `10769712413`, Place `90623742498445`). O probe abaixo carregou essa versão e executou os módulos da branch em uma sessão descartável. A versão regional ainda não está disponível no cliente. [CI do candidato](https://github.com/Sllay/Roblox-Studios/actions/runs/45671239634) · [Motor Roblox e DataStore isolado](https://github.com/Sllay/Roblox-Studios/actions/runs/45671224264) · [Readback da v18](https://github.com/Sllay/Roblox-Studios/actions/runs/45531334560) · [Scene Sync da v18](https://github.com/Sllay/Roblox-Studios/actions/runs/45525381881)

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

O [protocolo](RUNNER_PROTOCOL.md#publicacao-depois-de-r3) publica a temporada depois de R3. A exceção anterior se aplica a [uma única prévia de T1-R1](../../../../.github/workflows/entre-reinos-preview-dispatch.yml). O [workflow oficial de publicação](../../../../.github/workflows/publish.yml) exige ref `main`, confirmação de publicação e substituição integral e o ambiente configurado. O gate normal de integração do PR #13 depende da [certificação individual da T1](T1_CERTIFICATION_V18.md). A autorização anterior do criador registra a continuidade do desenvolvimento em branch.

A prévia antecipada exige aceite explícito do criador, registrado no protocolo ou em decisão vinculada a ele, **para uma única prévia de desenvolvimento T2-R1 antes de R3**, com destino Universe/Place identificado, SHA candidato com CI e prova no motor e procedimento oficial aprovado para publicar esse SHA. Se o caminho escolhido for o workflow atual, o PR precisa estar liberado para integrar na `main` pelos gates normais. Uma prévia anterior à integração precisaria de uma exceção formal com workflow e destino de staging isolado, mantendo as proteções de ambiente e as verificações de identidade, baseline e candidato. A autorização da prévia sozinha não libera merge nem certifica uma temporada.

Para manter os saves v18 de jogo em uso, a opção de laboratório é um destino de staging isolado do DataStore dos seis slots atuais. Caso o criador escolha atualizar o staging v18, a autorização precisa cobrir expressamente a substituição do Place e a possibilidade de migração para ruleset 4. O roteiro usa slots dispensáveis. A v18 recusa abrir um ruleset futuro e o backup deve existir antes da primeira gravação em ruleset 4.

Após liberação:

1. Conferir proteções do PR, SHA de código, CI, probe e vínculo Universe/Place. Capturar snapshot verificável do Place e Scene Sync recente com revisão, digest, inventário e conflitos.
2. Aprovar a publicação pelo workflow oficial e obter `isPublished=true` e a revisão pela API. Executar readback separado de revisão, scripts e smoke, seguido de Scene Sync pós-publicação. Registrar as URLs no recibo.
3. Se for necessário retornar à v18, encerrar as sessões de teste, repor a cena verificada pelo procedimento oficial e recuperar apenas saves de teste migrados a partir do backup correspondente. A restauração de um save de jogador requer identificação e autorização próprias. Reverter o Place sozinho mantém os saves em ruleset 4.

## Roteiro de playtest mobile

1. Abrir um slot descartável. Registrar revisão, seed, modelo/OS e preset. Completar a abertura da campanha. Confirmar joystick, salto e botões de borda.
2. Em **VILA → ESTOQUE**, seguir a indicação da Vila do Cedro. Caminhar até lá, observar os biomas e margens. Anotar uma travessia a pé e verificar o primeiro morador e o conteúdo visível dos galpões. Sair da região e retornar. Comparar moradores, trabalho e quantidades.
3. Em **VILA → OBRAS**, deixar trabalhadores construírem uma ponte provisória com 12 madeiras. Ver entrega física e travessia. A reforçada exige 20 madeiras e 12 pedras no total. Testar o bloqueio do cavalo no apoio antes do reforço e a travessia depois. Comprar o cavalo por 12 moedas, montar e desmontar pelo botão contextual. Conferir perda e recuperação de energia.
4. Embarcar junto ao barco. Com ele atracado, usar **OFICINA** para carregar uma madeira. Navegar com o controle lateral, desembarcar, retirar a carga e comparar a bolsa. Se for seguro no slot descartável, testar também morrer a bordo e retornar ao castelo sem ser reconectado ao assento.
5. Após descobrir as duas capitais, testar a ação contextual de viagem a pé junto ao centro. Salvar perto da Vila do Cedro e reabrir. Conferir a posição, a integridade da bolsa, o veículo e o estado de cada reino. Para testar migração, usar somente cópia ou slot sintético v18 com backup verificado.
6. Repetir as transições mais custosas com as estatísticas do cliente ativadas. Registrar tempo de carregamento, FPS, frame pacing, memória e vídeo de qualquer travamento ou ação difícil de operar.

O roteiro é válido para uma revisão regional publicada e confirmada por readback. O staging atualmente disponível oferece apenas o playtest da [fundação v18](T1_CERTIFICATION_V18.md).
