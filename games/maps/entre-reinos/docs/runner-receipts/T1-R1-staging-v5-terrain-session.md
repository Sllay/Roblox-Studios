# T1-R1 — revisão Roblox 5: diagnóstico de Terrain e sessão presa

Status: **publicado em staging; NÃO validado em runtime real**.

## Problema visto pelo criador
A versão 4 não abriu o Mundo 1. Prints: `world_needs_new_server (terrain)`, `bad_slot_or_session_active`, `other_slot_active`. O Mundo 1 já existente aparece `Dia 1`; **não apagar**.

## Correções
- O client parou de mascarar o erro real de geração com `resume` automático.
- Mundo/servidor agora emitem fase de geração, versão do servidor, seed.
- Só se permite recuperar uma sessão potencialmente pronta; falha de Terrain nunca é repetida no mesmo servidor.
- `SaveSlotService` libera a sessão com tentativa limitada e sem alterar seed/posição; personagem no menu não grava posição nem relógio.
- Guardas de UI impedem abrir/excluir outro mundo enquanto a sessão corrente está ativa.

## Evidências
- Código do reparo `971a306932aa8aa39c301a30a1fe9938f5329859`, CI `https://github.com/Sllay/Roblox-Studios/actions/runs/44978915630` (pass).
- Cinco seeds geradas com água no Roblox Luau Execution edit session, run https://github.com/Sllay/Roblox-Studios/actions/runs/44978508712; sexta requisição HTTP 429. Não equivale ao servidor de jogo do usuário.
- Publicação oficial: https://github.com/Sllay/Roblox-Studios/actions/runs/44978951305 — Roblox Place 90623742498445 revisão **5**.
- Verificação independente read-only da revisão salva: https://github.com/Sllay/Roblox-Studios/actions/runs/44979034609 — 12 checks de scripts/código aprovados.
- Black Island e produção não receberam alterações.

## Próximo gate
Criador deve entrar em novo servidor e conferir `v5`, abrir o **Mundo 1 existente**, capturar a fase/erro original se falhar; se funcionar, testar física X/Y, nado, câmera e saves. T1-R1 permanece `in_progress`; T1-R2 `planned`.
