# Configuração de Places e publicação — Open Cloud

**Nunca coloque uma chave em arquivos do repositório nem em mensagens de chat.**

## Separação de responsabilidades

- `game.manifest.json`: nomes de Places e caminhos Rojo (não inclui IDs).
- `deploy.targets.json`: IDs públicos de cada ambiente e Place (sem credenciais).
- GitHub **Actions → Repository secrets**: secret `ROBLOX_OPEN_CLOUD_API_KEY` (configuração atual recomendada para o repositório). Opcionalmente, o mesmo nome pode existir como secret de ambiente para restringir seu uso por destino.
- `tools/deploy.py`: valida seleção de destino, envia a versão e consulta a operação assíncrona até confirmar sucesso ou erro.
- `.github/workflows/publish.yml`: envio **somente manual** mediante confirmação.

## Exemplo de configuração

`games/maps/<slug>/deploy.targets.json`:

```json
{
  "schemaVersion": 1,
  "environments": {
    "staging": {
      "universeId": "111111",
      "placeIds": { "lobby": "222222", "arena": "333333" }
    },
    "production": {
      "universeId": "444444",
      "placeIds": { "lobby": "555555", "arena": "666666" }
    }
  }
}
```

Esses números são **ilustrativos**: substitua pelos IDs reais antes de publicar. Todos os IDs podem ser strings numéricas ou inteiros positivos; `null` significa não configurado. Staging e production devem usar Universes diferentes e nenhum Place ID deve ser duplicado entre eles. Adapte os nomes dos Places ao seu jogo.

## Chave única no Repository secrets (configuração escolhida)

1. Acesse `https://github.com/Sllay/Roblox-Studios/settings/secrets/actions`.
2. Crie um **Repository secret** com o nome exato `ROBLOX_OPEN_CLOUD_API_KEY`.
3. Use uma chave da Roblox Open Cloud com permissões mínimas de Assets API (Read/Write), autorizada somente para as experiências que precisam ser publicadas.
4. O workflow `publish.yml` já lê `secrets.ROBLOX_OPEN_CLOUD_API_KEY` diretamente. Não é necessário copiar o secret para os Environments.
5. Os ambientes `staging` e `production` continuam selecionando os IDs de destino em `deploy.targets.json`. É possível adicionar aprovação obrigatória para `production` em Settings → Environments, sem armazenar a chave lá.
6. A chave de Vercel não publica Places Roblox e deve permanecer separada, caso exista outro serviço que precise dela.

### Segurança e limites desta opção

Repository secrets são criptografados, mas seu alcance é **todo o repositório**, não somente o workflow de publicação. Outros workflows com acesso legítimo ao contexto de secrets podem referenciá-los. Environment secrets oferecem melhor isolamento por ambiente; quando há nomes idênticos, o secret de ambiente tem precedência. Ao manter a chave no repositório, proteja mudanças nos arquivos de workflow, prefira permissões restritas da Roblox e use proteção de publicação quando possível.

**Não é necessário um secret por jogo ou por Place.** Se um dia houver muitos jogos com permissões incompatíveis, separar credenciais por jogo/ambiente será mais seguro que uma chave com acesso irrestrito.


## Onde obter os IDs

- **Universe ID:** Creator Dashboard → experiência → menu com opção Copy Universe ID.
- **Place ID:** Creator Dashboard → experiência → Places → URL/configuração do Place.
- Um jogo (Universe) pode conter vários Places, portanto cada ambiente tem **um** Universe ID e um ID para **cada** Place.

## Comandos de controle

```sh
python tools/workspace.py validate
python tools/deploy.py validate
python tools/deploy.py show --game sandbox-demo --place lobby --environment staging
python tools/workspace.py build --game sandbox-demo --place lobby
python tools/deploy.py publish --game sandbox-demo --place lobby --environment staging
```

O comando `publish` sem `--execute` é apenas prévia. O workflow manual passa `--execute` e só funciona depois de configurar IDs e secret. Configuração incompleta interrompe o processo antes de chamar o Roblox.

## Publicação manual

Acesse `https://github.com/Sllay/Roblox-Studios/actions/workflows/publish.yml`, selecione jogo, Place, ambiente e marque a confirmação. O workflow compila o Place selecionado, envia o arquivo `.rbxlx` pela **Assets API** e consulta `operations/{id}` até `done=true`. Falhas não devem ser tratadas como publicação concluída.

A publicação **não** acontece automaticamente no push; `ci.yml` segue compilando e testando sem chave.

## Limitações e segurança

- A documentação Roblox informa que certos objetos `EditableImage`, `EditableMesh`, `PartOperation`, `SurfaceAppearance` e `BaseWrap` podem precisar de publicação via Studio.
- IDs não provam, por si só, que Place e Universe pertencem um ao outro; confirme-os no Creator Dashboard.
- Atualizações de Place não representam necessariamente hot reload em servidores já abertos.
- O workflow não cria automaticamente uma experiência, não importa assets externos e não substitui todas as operações gráficas do Studio.
- O segredo é lido somente no passo que publica. Não cole valores em logs, issues ou chat.

Referências:
- https://create.roblox.com/docs/cloud/guides/usage-place-publishing
- https://create.roblox.com/docs/cloud/auth/api-keys
- https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets
