# Certificação da fundação v18 · ER-001 a ER-020

O criador aceitou a v18 como fundação para continuar o desenvolvimento. Os vinte contratos abaixo permanecem **PARCIAL** na [matriz oficial](FEATURE_COMPLETENESS_AUDIT.md). O aceite da fundação e o estado da certificação são registrados no [status do programa](RUNNER_STATUS.json). O [protocolo](RUNNER_PROTOCOL.md) exige evidência individual de commit, CI, motor, mobile, save/load, abuso e aprovação do criador para validar um contrato.

## Evidências de referência

- **V18** — CI do candidato, probe de integração com DataStore isolado e readback posterior dos 33 scripts, do Terrain, do combate e da abertura do prólogo. [CI](https://github.com/Sllay/Roblox-Studios/actions/runs/45498169441) · [Probe](https://github.com/Sllay/Roblox-Studios/actions/runs/45497927554) · [Readback](https://github.com/Sllay/Roblox-Studios/actions/runs/45531334560) · [Recibo F6](runner-receipts/T1-F6.md)
- **F3** — regressão de domínio e ensaio de integração em três seeds do candidato anterior, incluindo cadeia econômica, defesa e estados do prólogo. A execução histórica é aplicável às rotinas reaproveitadas, com as limitações de versão e de cliente registradas no recibo. [Motor](https://github.com/Sllay/Roblox-Studios/actions/runs/45420123951) · [Recibo F3](runner-receipts/T1-F3.md)
- **Regional** — probe da branch que exercitou migração 3 → 4, compatibilidade de Terrain, navegação e transporte com DataStore sintético. É evidência adicional para o candidato, que opera sobre uma leitura da v18. [Motor](https://github.com/Sllay/Roblox-Studios/actions/runs/45658231902) · [Recibo T2-R1](runner-receipts/T2-R1.md)

## Revisão individual

| Contrato | Evidência técnica aproveitada | Condição restante |
|---|---|---|
| ER-001 · Seis slots | V18 validou slots independentes, lock, backup e reabertura na fronteira em DataStore isolado. | **Cliente** · Criar, abrir e salvar na interface, reconectar e confirmar exclusão voluntária em slot descartável. |
| ER-002 · Compatibilidade | V18 confirma vínculo entre revisão e posição de fronteira, guarda de versões futuras e política de backup. Regional exercita recuperação idempotente e ruleset 3 → 4. | **Operacional** · Ensaiar restauração administrativa do backup da v18 após downgrade com conta/namespace de teste e registrar a confirmação no cliente. |
| ER-003 · Mundo 3D | V18 confirma Terrain nativo e 5 → 17 chunks. | **Visual e medição** · Aprovar câmera, foreground, oclusão e leitura dos quatro planos em dispositivo durante transições. |
| ER-004 · Controle e natação | Suíte exercita projeção X/Y R6 e água. Há aceite histórico de nado nas revisões anteriores, com escopo registrado no recibo R1. | **Touch** · Reexecutar em v18 entrada/saída da água, mergulho, subida, salto e orientação com joystick nativo. [Recibo R1](runner-receipts/T1-R1.md) |
| ER-005 · NPCs R6 | F4/F6 introduzem posição X/Z persistente, desvio local e Animator nativo. | **Visual** · Confirmar estabilidade dos pés e giros e legibilidade de cada atividade. Algumas profissões compartilham gestos R6. |
| ER-006 · Trabalhos | F3/V18 exercitam profissões, filas, reservas, custódia, restauro e desvio. | **Partida** · Observar retomada após duas interrupções reais (ameaça e reentrada) e aferir fadiga/prioridades no ciclo de jogo. |
| ER-007 · Recursos | F3/V18 rastreiam fontes finitas, marcação validada, prioridade, coleta, depósito e reload. | **Touch** · Verificar gesto de marcar/desmarcar, corte e depleção observáveis e retomada de transporte após recarregar. |
| ER-008 · Galpões | F3 comprova capacidade, retirada para obra, isolamento de estoque em ruína e ausência de crédito duplicado. | **Design e implementação** · Aprovar e implementar partição final do estoque isolado e verificar resgate e reparo físico em partida. |
| ER-009 · Construção | F3/V18 exercitam X escolhido, validação autoritativa, materiais e cancelamento de obra comum. | **Touch e design** · Jogar prévia, confirmação e cancelamento, inclusive com material entregue. Aprovar a regra final de estorno e de reforços em curso. |
| ER-010 · Vila inicial | F3/V18 verificam castelo, tesouraria, dois galpões, muralhas, abrigo e apoio físico em Terrain. | **Partida** · Confirmar acesso, legibilidade e uso de abrigo e anéis/distritos no novo mundo. |
| ER-011 · Arte e colisão | Modelos e estados estão no runtime, com apoios inspecionados no motor. | **Visual** · Aprovar silhueta, escala, colisão e progresso/dano das estruturas na câmera lateral. |
| ER-012 · Combate | Readback v18 exercita arco com carga, gravidade, acerto e débito de munição; F3 valida alcance, regras de dano e cooldown. | **Touch** · Confirmar troca de arma, gesto de carga/cancelamento, trajetória, feedback e defesa real em partida. |
| ER-013 · Invasões | F3 exercita noites tranquilas, aviso, spawn e avanço do inimigo no cenário de teste. | **Partida** · Observar o aviso e a primeira invasão, alternância de noites e continuidade após reload, sem comandos de desenvolvimento. |
| ER-014 · Defesa | F3 exercita equipamento/munição, abrigo, resistência de muros e perda de galpão sem liberar seu estoque. | **Partida e design** · Confirmar fuga, guardas, dano e reconstrução em combate. A perda/recuperação de estoque segue ER-008. |
| ER-015 · Prólogo | F3 cobre progressão e encerramento no domínio. A v18 comprova conversa contextual com o duque e início da escolta no motor. | **Partida** · Completar todas as cenas, incluindo hesitação, evacuação e coroação, em cliente normal e confirmar continuidade. |
| ER-016 · Economia inicial | F3/V18 exercitam tesouro, carteira, drop, coleta, fabricação e comércio com débitos do estoque. | **Partida** · Usar a interface real e conferir saldos, duplo toque, morte e reentrada. A política de perda por morte segue ER-019. |
| ER-017 · HUD | V18 tem hotbar de borda, caderno, botões de ação contextual e gestos com cancelamento. | **Touch** · Conferir legibilidade em tela pequena, alvos de toque, joystick/salto e feedback de bloqueio com cliente. |
| ER-018 · Ciclo completo | F3 executa três campanhas de domínio e integra DataStore, defesa e economia com cenários dirigidos. | **Partida** · Repetir em três seeds com cliente, do novo slot à reconstrução e reentrada, sem ferramentas de desenvolvimento. |
| ER-019 · Morte e recuperação | Retorno ao castelo e preservação provisória da bolsa/equipamento. Na branch, a morte encerra o vínculo com o transporte também ao reabrir. | **Design e implementação** · Definir bolsas e moedas recuperáveis, consequências para jogador e moradores e derrota. Verificar o fluxo aprovado com morte e desconexão em partida. |
| ER-020 · Qualidade e custo | Há regressões de abuso e medições de motor isolado, incluindo tempo de geração. | **Medição em cliente** · Registrar modelo/OS, preset, FPS, frame pacing, memória, latência e conforto durante caminhada, raids e expansão. |

Roteiro inicial da v18 já disponível no [recibo F6](runner-receipts/T1-F6.md). Use um slot dispensável para a exclusão voluntária, mortes planejadas e outros ensaios destrutivos. Ao recolher evidência, anote seed, revisão, aparelho, passos e o resultado observado. A reavaliação de fluidez requer imagem ou vídeo do cliente.

## Políticas em avaliação

| Caso | Comportamento provisório mantido | Contrato para aprovação |
|---|---|---|
| Morte do jogador | Retorno ao castelo, equipamento, carteira e bolsa preservados. Na branch regional, o vínculo com o assento é encerrado. Veículo e carga continuam na região. | Manter equipamentos. Se houver perda, um evento de morte com ID estável debita a carteira para uma única bolsa acessível perto do local da morte. Um único proprietário pode recolher o saldo, com registro persistente para retries. Aprovar percentual, prazo, acesso por terceiros e consequência para mortes consecutivas. |
| Cancelamento de obra | Libera reservas e mantém o entregue em pilhas físicas. A branch regional coloca as pilhas das pontes na margem de trabalho; a reconstrução fica sujeita às regras de obra. | Confirmar resgate por trabalhadores e limites de acesso. Analisar crédito de reforços em andamento separadamente, pois o upgrade reutiliza materiais da obra anterior e hoje não pode ser cancelado. |
| Galpão destruído | Estoque sai da economia e fica isolado em `ruinedStock`. Materiais da estrutura têm recuperação própria. Reparar não reativa o estoque isolado. | Aprovar percentuais e destino do roubo. A partição inteira de cada item deve somar o estoque antes da ruína, com política explícita de arredondamento. Cada parcela tem custódia própria. A transição e cada resgate têm ID persistido. O reparo e o reload não recriam unidades. O estoque legado isolado só pode ser convertido por migração explícita. |
