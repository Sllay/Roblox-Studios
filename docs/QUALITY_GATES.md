# Quality Gates — Luau antes de qualquer deploy

Todos os workflows de compilação e publicação instalam o Luau oficial 0.744 em Linux, conferindo o SHA-256 fixado da distribuição. Uma falha de download, hash ou binário interrompe a execução.

O comando `python tools/script_quality.py` verifica todos os arquivos `.luau` e `.lua` encontrados em `games/maps/` e `packages/` com `luau-compile --null`. Examina Scripts, LocalScripts, ModuleScripts, template e sistemas compartilhados. Não executa o código e não necessita de chave Roblox.

Erros produzem exit code diferente de zero e mostram arquivo e diagnóstico. Se o compilador estiver ausente, o gate falha fechado. Um teste negativo no runner cria um arquivo deliberadamente inválido e verifica que o compilador o rejeita.

## Onde o gate é obrigatório

- CI no push/PR: antes de gerar builds pelo Rojo.
- Publicação incremental: primeiro no job de validação, depois novamente no job com chave Open Cloud, antes de modificar o Place.
- Publicação completa: antes de compilar e antes de usar o secret; as confirmações explícitas de substituição são preservadas.

## Limites reais

Validação sintática não garante tipagem completa das APIs Roblox, lógica de jogo, ausência de `WaitForChild` infinito ou execução de Script/LocalScript. O compilador não é substituto da janela Script Analysis do Studio, que não tem uma API pública equivalente confirmada para ler todos os resultados.

A próxima etapa opcional é adicionar `luau-lsp analyze` com definições Roblox e sourcemaps, além de testes automatizados na engine. Não declarar essas etapas como concluídas.

## Prints do teste mobile

O console mostra `SERVER OK`, `CLIENT OK`, movimento replicado e zero erros. O aviso `Infinite yield possible` apareceu em `StarterPlayer.PlayerModule.CameraInput`, fora dos nossos scripts. Investigar a câmera separadamente se houver um bug reproduzível.

Referências: https://luau.org/getting-started/ ; https://github.com/luau-lang/luau/releases/tag/0.744 ; https://create.roblox.com/docs/studio/script-editor
