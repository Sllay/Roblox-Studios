# Política básica de segurança

- Nunca guardar tokens ou chaves Roblox em Git, incluindo arquivos de exemplo, logs e commits antigos.
- Usar secrets do GitHub Actions com privilégios mínimos, limitados aos Places necessários.
- O workflow padrão usa somente `contents: read` e **não** possui etapa de publicação.
- Revisar alterações de workflows, actions de terceiros e dependências antes do merge.
- Não executar código não confiável no ambiente com credenciais de deploy.
- Evitar URLs autenticadas, dados pessoais e informações de jogadores em commits.
- Toda alteração de publicação deve ter ambiente de teste e autorização explícita.
