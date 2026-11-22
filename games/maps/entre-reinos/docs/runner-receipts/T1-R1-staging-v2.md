# Entre Reinos — T1-R1, publicação antecipada v2 para teste

**Comprovado em 21/11/2026 (UTC 22/11):**

| Campo | Resultado |
|---|---|
| Jogo | Entre Reinos (Between Kingdoms) |
| Ambiente | Staging somente |
| Universe ID | 10769712413 |
| Place ID | 90623742498445 |
| Revisão publicada Roblox | 2 |
| Commit publicado | bc45d584c547d2e397989b7e9f796d4f7b2a0863 |
| Publicação | https://github.com/Sllay/Roblox-Studios/actions/runs/44975639993 |
| Readback da versão salva | https://github.com/Sllay/Roblox-Studios/actions/runs/44975725822 |
| Objetos verificados | 11 / 11 |
| Status T1-R1 | in_progress; aguardando testes reais do criador |

- Publicação via `publish.yml`, Assets API confirmou `isPublished=true` e `SUCCESS: Place 90623742498445, revision 2`.
- Readback independente retornou `loadedVersion=2`, 11 módulos/scripts e StartArea todos presentes. Não foi feito teste de gameplay nem FPS no servidor real.
- O mapa era uma cena padrão v1 (179 objetos no inventário; auditada em run https://github.com/Sllay/Roblox-Studios/actions/runs/44975381075). A substituição total desse **novo Place de staging** foi autorizada pelo usuário e revisada; produção e Black Island intocados.
- Testes principais exigidos: abrir UI/seis slots, Avatar R6, gerar Terrain e ver rio nativo, caminhar X/girar sem Z, nadar diagonal, persistir/reabrir mundo, FPS e câmera em celular.
- Se ocorrer falha na configuração R6, usar Avatar Settings oficiais, sem hack de trocar rig do Humanoid existente.
- Após relato de teste, corrigir bugs, CI novamente e republicar staging só com a mesma identidade/sync atualizados. Não começar T1-R2 antes de validar T1-R1.
