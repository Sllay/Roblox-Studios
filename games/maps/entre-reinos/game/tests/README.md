# Testes — Between Kingdoms

T1-R1 em implementação, com assertions Luau executáveis em `game/tests/region_and_slots.luau`: seed e determinismo, rio/leito no corredor, seis chaves independentes por usuário, schema versionado, posições e dados inválidos.

O arquivo é executado no Quality Gate 2.0 via `tools/quality_gate_v2.py` (Luau VM oficial com SHA verificado). A execução real do novo teste deve ser confirmada pelos logs do CI do commit que integrou essa etapa, não apenas pela compilação Luau.

Ainda pendente: Roblox runtime TestService para DataStore/lock, voxel readback, água e colisão, seis saves sob desconexão/reconexão e teste mobile com vídeo/FPS. T1-R2/T1-R3 exigirão novas suites de NPC, economia e raids.
