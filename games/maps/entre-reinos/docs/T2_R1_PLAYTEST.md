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

O criador autorizou formalmente uma prévia antes de R3 para o candidato `f7d4ac685f2372d066cdf49a19b2b978f2454745`. A autorização está no [protocolo](RUNNER_PROTOCOL.md#exceção-autorizada-t2-r1). O [workflow específico](../../../../.github/workflows/entre-reinos-t2-r1-preview.yml) usa a infraestrutura de publicação em um checkout do SHA aprovado. O PR #13 segue em rascunho.

O Place Provision confirmou que a v18 é o único Place do Universe atual. O destino deve ser outra experiência Roblox, com DataStore separado pelo próprio Universe. A chave atual não oferece criação de Universe pela API documentada. [Inventário v18](https://github.com/Sllay/Roblox-Studios/actions/runs/45681890920) · [Place Provision](../../../../docs/PLACE_PROVISION.md)

### Ação do criador

1. No Roblox Studio, abrir um Baseplate vazio e escolher **File → Publish to Roblox As… → Create new experience**. Manter a experiência privada, sob o proprietário da v18. Para convidar outros testadores, conceder acesso de playtest no Creator Dashboard.
2. Enviar o **Universe ID** e o **Start Place ID** do Creator Dashboard. No [ambiente staging do GitHub](https://github.com/Sllay/Roblox-Studios/settings/environments), configurar o secret `ROBLOX_T2_R1_PREVIEW_API_KEY` com uma chave Open Cloud restrita à experiência nova, com **Assets Read/Write** e **Luau Execution Sessions Read/Write**. Compartilhar somente a confirmação de configuração.

### Execução após receber os IDs

1. Registrar `docs/sync/t2-r1-preview/target.json` na branch do PR com `action: inspect`, `candidate`, `universeId` e `placeId`. O workflow confirma proprietário, Place único, revisão e digest do Scene Sync. Conferir `PREVIEW_BASELINE` e o artefato da cena original. Essa revisão fica preservada para restauração. O inventário fornece prova estrutural.
2. Aprovar por commit o mesmo registro com `action: publish`, `confirmFullReplacement: true`, `expectedVersion` e `expectedDigest` iguais aos observados. O processo recompila o SHA fixado, inspeciona novamente e usa o publicador oficial. Uma mudança na revisão ou no digest interrompe a operação.
3. Verificar a resposta confirmada da Assets API e o log `PREVIEW_READBACK`. Registrar revisão, hash do RBXLX, hashes dos scripts, inventário posterior e link de jogo. Se a resposta for ambígua, verificar a revisão remota antes de tentar publicar novamente.
4. Para desativar a prévia, manter o destino privado e usar o histórico do Place isolado. O staging v18 e seus saves continuam separados.

## Roteiro de playtest mobile

1. Abrir um slot descartável. Registrar revisão, seed, modelo/OS e preset. Completar a abertura da campanha. Confirmar joystick, salto e botões de borda.
2. Em **VILA → ESTOQUE**, seguir a indicação da Vila do Cedro. Caminhar até lá, observar os biomas e margens. Anotar uma travessia a pé e verificar o primeiro morador e o conteúdo visível dos galpões. Sair da região e retornar. Comparar moradores, trabalho e quantidades.
3. Em **VILA → OBRAS**, deixar trabalhadores construírem uma ponte provisória com 12 madeiras. Ver entrega física e travessia. A reforçada exige 20 madeiras e 12 pedras no total. Testar o bloqueio do cavalo no apoio antes do reforço e a travessia depois. Comprar o cavalo por 12 moedas, montar e desmontar pelo botão contextual. Conferir perda e recuperação de energia.
4. Embarcar junto ao barco. Com ele atracado, usar **OFICINA** para carregar uma madeira. Navegar com o controle lateral, desembarcar, retirar a carga e comparar a bolsa. Se for seguro no slot descartável, testar também morrer a bordo e retornar ao castelo sem ser reconectado ao assento.
5. Após descobrir as duas capitais, testar a ação contextual de viagem a pé junto ao centro. Salvar perto da Vila do Cedro e reabrir. Conferir a posição, a integridade da bolsa, o veículo e o estado de cada reino. Para testar migração, usar somente cópia ou slot sintético v18 com backup verificado.
6. Repetir as transições mais custosas com as estatísticas do cliente ativadas. Registrar tempo de carregamento, FPS, frame pacing, memória e vídeo de qualquer travamento ou ação difícil de operar.

O roteiro é válido para uma revisão regional publicada e confirmada por readback. O staging atualmente disponível oferece apenas o playtest da [fundação v18](T1_CERTIFICATION_V18.md).
