# Entre Reinos — Pré-voo T1-R1 (21/11/2026)

**Decisão: PRONTO PARA COMEÇAR A IMPLEMENTAÇÃO.** Não há bloqueio técnico comprovado à edição do código em GitHub e aos testes de build/CI. O runner T1-R1 NÃO foi iniciado nem concluído nesta verificação.

## Evidência conferida
- GitHub main HEAD visto: `cb96b9e5c508571e937ea72c84698f64c543b049` antes desta nota.
- CI do referido commit: https://github.com/Sllay/Roblox-Studios/actions/runs/44959789451 — status `completed/success`. Este verde valida o escopo do pipeline no estado atual, **não a futura jogabilidade**.
- Existe `game.manifest.json` com `entre-reinos`, Place `main`, e `game/places/main/default.project.json` (Rojo).
- Código atual: `Boot.server.luau` e `ClientBoot.client.luau` apenas inicializam/imprimem; `Config.luau` contém dados iniciais; `StartArea.model.json` tem piso e spawn de template. **Não existe mundo/controle/nado/seis saves implementados.**
- Fontes, 27 grupos de mecânicas, lacunas, blueprint Luau, handoff, plano V2 de nove runners e source map estão versionados.
- Status inicial: `T1-R1 planned`, nenhuma evidência de gameplay executado.

## Pendências sem bloqueio para COMEÇAR
1. **IDs staging:** `10769712413` e `90623742498445` recebidos, ainda sem confirmação confiável de par Universe/Place, titularidade e intenção de ambiente. `deploy.targets.json` permanece nulo. **Bloqueia publicar/alterar Place remoto**, não bloqueia criar e testar código. A consulta pública ao endpoint Roblox estava inacessível pelos meios disponíveis nesta checagem; não assumir o vínculo.
2. **Teste real no Roblox/mobile:** obrigatório antes de declarar mecânicas de movimento, água, câmera e Terrain como aprovadas. CI no GitHub não simula física de runtime.
3. **Catálogo de assets compartilhados:** revisar licenças, compatibilidade de rig e disponibilidade antes do primeiro import. Não impede trabalhar em gerador/contratos.
4. **Geração de rios e streaming:** os recursos atuais de Terrain Builder possuem limites documentados, exigindo engenharia nova no T1-R1 para mundo inicial e testes; expansão por biomas e streaming regional completo é T2-R1, portanto NÃO antecipar.
5. **Fontes de RE reversa:** a documentação da comunidade não cobre tudo. Lacunas registradas em `research/RESEARCH_GAPS.md`; nenhuma lacuna geral bloqueia construir soluções originais.

## Primeira implementação autorizada pelo plano, após início efetivo
1. Confirmar leitura: `AGENT_HANDOFF.md`, `VISION_MASTER.md`, `DECISION_LOG.md`, `SEASON_RUNNERS.md`, `RUNNER_PROTOCOL.md` e fontes T1-R1.
2. Especificar schema do mundo/save, serviços básicos e contratos de geração.
3. Construir terreno inicial 100% 3D, reserva de assentamento/rios e faixas de fundo com controle de oclusão.
4. Implementar R6 lateral X, rotação para fundo/câmera e natação X/Y com câmera/inputs mobile.
5. Implementar seis slots com session lock, persistência segura e testes de seed/salvamento.
6. Rodar validação/sintaxe Luau, build Rojo e regressões, mais testes Roblox reais quando acessíveis. Corrigir até verde e guardar recibo do runner antes de T1-R2.

Não publicar a temporada ao concluir apenas T1-R1; a primeira publicação em staging está planejada após **T1-R3** e verificação de IDs. Não avançar para T1-R2 antes de concluir/validar/integrar T1-R1.
