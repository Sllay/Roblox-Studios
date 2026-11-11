# Arquitetura canônica e contrato do template Roblox-Studios

**Versão:** 1.0 — **Status:** obrigatório para agentes de desenvolvimento.

Este documento define a estrutura, os scripts, os arquivos e os procedimentos para criar qualquer jogo neste monorepositório. O template executável fica em `games/maps/_template/` e o gerador oficial fica em `tools/scaffold.py`. O agente **não precisa inventar uma estrutura**: deve executar o gerador, preencher os requisitos recebidos e manter esta documentação sincronizada com o código.

## 1. Princípios

- `games/maps/<slug>/` contém todo o projeto de um jogo: documentação, agentes, fontes, assets e configuração de Places.
- Só `game/places/<place>/` contém os arquivos que serão compilados para o Roblox. GDD e instruções dos agentes não entram no Place.
- Um jogo pode possuir vários Places sob o mesmo Universe; cada Place tem configuração Rojo e build independentes.
- Código e assets são versionados no Git; builds são gerados em `dist/<jogo>/<place>.rbxlx` sem sobrescrever o Roblox.
- O pipeline de compilação e testes não é publicação. Publicação requer IDs, permissões, seleção explícita e aprovação.
- Qualquer gameplay ainda não descrito no GDD permanece **não definido**, em vez de ser adivinhado.

## 2. Árvore canônica do projeto

```text
Roblox-Studios/
├── AGENTS.md                         # diretrizes globais
├── ARCHITECTURE.md                   # arquitetura da plataforma
├── rokit.toml                        # ferramenta Rojo versionada
├── games/maps/
│   ├── _template/                   # fonte única de novos projetos
│   │   ├── README.md                # instruções de criação
│   │   ├── AGENTS.md                # diretrizes específicas
│   │   ├── ARCHITECTURE.md          # arquitetura local
│   │   ├── GDD.md                   # design, objetivos, requisitos
│   │   ├── game.manifest.json       # nomes, slugs e paths dos Places
│   │   ├── deploy.targets.json      # Universe/Place IDs por ambiente
│   │   ├── agents/
│   │   │   ├── README.md
│   │   │   └── WORKFLOW.md          # procedimentos dos agentes
│   │   ├── docs/README.md           # decisões/ADR, especificações
│   │   └── game/
│   │       ├── assets/README.md     # fontes, licenças, IDs de assets
│   │       ├── tests/README.md      # testes específicos e cenários
│   │       └── places/main/
│   │           ├── default.project.json
│   │           └── src/
│   │               ├── ReplicatedStorage/Config.luau
│   │               ├── ServerScriptService/Boot.server.luau
│   │               ├── StarterPlayer/StarterPlayerScripts/ClientBoot.client.luau
│   │               └── Workspace/StartArea.model.json
│   ├── sandbox-demo/                # jogo de CI com lobby e arena
│   └── mapa-principal/              # jogo real inicialmente configurado
├── packages/roblox-common/src/
│   └── Version.luau                 # biblioteca compartilhada
├── tools/
│   ├── scaffold.py                  # gerador de jogos e Places, IDs
│   ├── workspace.py                 # validar/compilar
│   └── deploy.py                    # publicar sob confirmação
├── tests/                            # regressão e contratos de estrutura
├── docs/architecture/               # este contrato
└── .github/workflows/               # CI e publicação manual
```

Os diretórios globais não são copiados para cada jogo: são compartilhados. Cada novo jogo é **uma cópia integral** do conteúdo de `_template/`, com nomes e caminhos relevantes ajustados pelo gerador.

## 3. Função de cada arquivo

| Arquivo | Responsabilidade | Modificações do agente |
|---|---|---|
| `README.md` | identidade, estado, instruções | manter atualizado |
| `AGENTS.md` | contexto e regras locais | ler antes de editar |
| `ARCHITECTURE.md` | serviços, dados, estado, contratos, desempenho | atualizar quando houver decisão técnica |
| `GDD.md` | loop de gameplay, controles mobile, metas, progressão e UX | escrever apenas a partir de requisitos |
| `agents/WORKFLOW.md` | protocolo de tarefas, validação e publicação | obedecer |
| `docs/README.md` | documentação técnica e decisões do projeto | anexar ADRs/testes |
| `game.manifest.json` | identidade, Places e caminhos para Rojo | gerenciado pelo scaffold |
| `deploy.targets.json` | IDs públicos de Universe e Place por ambiente | nunca colocar secrets |
| `game/assets/README.md` | origem, licença, arquivos e IDs de assets | documentar novos assets |
| `game/tests/README.md` | critérios de aceitação e verificações do motor | atualizar por funcionalidade |
| `game/places/main/default.project.json` | hierarquia de instâncias do Roblox | manter caminhos válidos |
| `src/ReplicatedStorage/Config.luau` | configuração pública | nunca colocar tokens |
| `src/ServerScriptService/Boot.server.luau` | inicialização do servidor | validação e autoridade |
| `src/StarterPlayer/StarterPlayerScripts/ClientBoot.client.luau` | inicialização do cliente | entrada e UI mobile |
| `src/Workspace/StartArea.model.json` | cena declarativa | Part e SpawnLocation |

## 4. Fontes integrais do template: formato e código

### 4.1 Manifesto de jogo — `game.manifest.json`

```json
{
  "schemaVersion": 1,
  "slug": "_template",
  "name": "New Game Template",
  "platform": "roblox",
  "places": [
    {
      "slug": "main",
      "name": "Main",
      "project": "game/places/main/default.project.json"
    }
  ]
}
```

O scaffold altera `slug` e `name`; ao adicionar Place acrescenta um item com `slug`, `name` e caminho correspondente, sem inventar IDs.

### 4.2 Destinos — `deploy.targets.json`

```json
{
  "schemaVersion": 1,
  "environments": {
    "staging": {
      "universeId": null,
      "placeIds": {
        "main": null
      }
    },
    "production": {
      "universeId": null,
      "placeIds": {
        "main": null
      }
    }
  }
}
```

IDs são identificadores públicos e podem estar no repositório. A chave Open Cloud deve estar no secret GitHub Actions `ROBLOX_OPEN_CLOUD_API_KEY`. Staging e production representam experiências distintas; não usar um Place de produção como teste.

### 4.3 Conversão Rojo — `game/places/main/default.project.json`

```json
{
  "name": "TemplateMain",
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": {
      "$className": "ReplicatedStorage",
      "PlatformShared": {
        "$className": "Folder",
        "$path": "../../../../../../packages/roblox-common/src"
      },
      "Game": {
        "$className": "Folder",
        "$path": "src/ReplicatedStorage"
      }
    },
    "ServerScriptService": {
      "$className": "ServerScriptService",
      "$path": "src/ServerScriptService"
    },
    "StarterPlayer": {
      "$className": "StarterPlayer",
      "StarterPlayerScripts": {
        "$className": "StarterPlayerScripts",
        "$path": "src/StarterPlayer/StarterPlayerScripts"
      }
    },
    "Workspace": {
      "$className": "Workspace",
      "$path": "src/Workspace"
    }
  }
}
```

O projeto determina a hierarquia Roblox. O caminho de `PlatformShared` aponta para uma biblioteca global, relativo ao arquivo do Place. Não mudar o nível da pasta sem recompilar.

### 4.4 Módulo público — `src/ReplicatedStorage/Config.luau`

Cria `ReplicatedStorage.Game.Config` (**ModuleScript**).

```lua
--!strict
return { placeName = "TemplateMain", maxPlayers = 12 }
```

`maxPlayers` é apenas valor demonstrativo e não altera sozinho o limite de jogadores configurado no Roblox.

### 4.5 Bootstrap servidor — `src/ServerScriptService/Boot.server.luau`

Cria `ServerScriptService.Boot` (**Script**).

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local version = require(ReplicatedStorage:WaitForChild("PlatformShared"):WaitForChild("Version"))
print("TemplateMain started. Shared version:", version.major, version.minor, version.patch)
```

Responsabilidade futura: inicializar sistemas autoritativos, dados persistentes e validações de segurança. O script padrão apenas verifica a biblioteca compartilhada.

### 4.6 Bootstrap cliente — `src/StarterPlayer/StarterPlayerScripts/ClientBoot.client.luau`

Cria `StarterPlayer.StarterPlayerScripts.ClientBoot` (**LocalScript**).

```lua
--!strict
print("TemplateMain: client ready")
```

Responsabilidade futura: controles de toque, interface, câmera, feedback visual; nunca confiar no cliente para operações de segurança ou persistência.

### 4.7 Cena declarativa — `src/Workspace/StartArea.model.json`

Cria `Workspace.StartArea` (**Model**) contendo `Floor` (Part) e `Spawn` (SpawnLocation).

```json
{
  "ClassName": "Model",
  "Children": [
    {
      "Name": "Floor",
      "ClassName": "Part",
      "Properties": {
        "Anchored": true,
        "Size": [
          32,
          1,
          32
        ],
        "Position": [
          0,
          0,
          0
        ]
      }
    },
    {
      "Name": "Spawn",
      "ClassName": "SpawnLocation",
      "Properties": {
        "Anchored": true,
        "Size": [
          6,
          1,
          6
        ],
        "Position": [
          0,
          1.5,
          0
        ],
        "Neutral": true
      }
    }
  ]
}
```

Essas instâncias formam um cenário técnico mínimo; não são gameplay final. O Rojo suporta modelos descritos com `.model.json`. Fonte: https://rojo.space/docs/v7/sync-details/

### 4.8 Biblioteca global — `packages/roblox-common/src/Version.luau`

Cria `ReplicatedStorage.PlatformShared.Version` em cada Place importado.

```lua
--!strict
return {
    major = 0,
    minor = 1,
    patch = 0,
}
```

### 4.9 Correspondência dos arquivos com as instâncias

| Extensão / caminho | Tipo Roblox |
|---|---|
| `.server.luau` | Script |
| `.client.luau` | LocalScript |
| `.luau` | ModuleScript |
| `.model.json` | Instância/árvore de instâncias |
| `default.project.json` | Projeto Rojo: mapeamento de serviços |

O GDD, AGENTS, README, docs, tests e arquivos de IDs permanecem fora da árvore Rojo. Fontes: https://rojo.space/docs/v7/project-format/ e https://rojo.space/docs/v7/sync-details/.

## 5. Criar um jogo novo — processo exato

```bash
python tools/scaffold.py new-game --slug novo-jogo --name "Novo Jogo"
python tools/workspace.py validate
python tools/deploy.py validate
python -m unittest discover -s tests -v
python tools/workspace.py build --game novo-jogo --place main
```

`new-game` copia todos os arquivos do template, ajusta manifesto e nomes internos do projeto/scripts, e deixa IDs de `staging` e `production` como `null`. Recusa sobrescrever jogos existentes ou nomes de pastas inválidos. A criação do diretório local **não** cria um Place remoto.

## 6. Adicionar outro Place ao jogo

```bash
python tools/scaffold.py add-place --game novo-jogo --place arena
python tools/workspace.py build --game novo-jogo --place arena
```

`add-place` copia o Place canônico, ajusta nomes e atualiza `game.manifest.json` e `deploy.targets.json` em ambos os ambientes. É necessário criar/possuir o Place correspondente no Roblox para publicá-lo.

## 7. Associar os IDs públicos

```bash
python tools/scaffold.py set-ids --game novo-jogo --place main --environment production --universe-id 123456 --place-id 789012
python tools/deploy.py validate
```

Os números do comando são ilustrativos. `set-ids` recusa IDs inválidos ou duplicados, Universes compartilhados por staging/production e troca silenciosa de IDs já existentes. O agente deve conferir que o Universe ID e o Place ID realmente correspondem à mesma experiência no Creator Dashboard antes de publicar.

**Mapa inicial já criado:** `games/maps/mapa-principal/` contém como associação **provisória de produção** Universe `10769712453` e Place `118200154785968`, ainda não verificados contra a API Roblox. Nenhuma publicação foi realizada.

## 8. Sequência obrigatória para agentes

1. Identificar o jogo, o Place e a demanda concreta.
2. Ler `AGENTS.md` global e local, `GDD.md`, `ARCHITECTURE.md`, `game.manifest.json`, `deploy.targets.json` e o código atual.
3. Para novo jogo/Place, executar `scaffold.py`, não recriar diretórios manualmente.
4. Para gameplay, trabalhar apenas no escopo especificado e atualizar GDD e contratos; não inventar sistemas.
5. Manter lógica autoritativa e validação de remotes no servidor; UI e entrada no cliente; minimizar custo de execução mobile.
6. Rodar validação, testes e builds; relatar claramente qualquer teste não executado.
7. Nunca usar credenciais no código, nunca publicar sem aprovação e nunca tratar build como teste completo de gameplay.

## 9. Critérios de entrega

- `python tools/workspace.py validate` — estrutura, paths, manifestos.
- `python tools/deploy.py validate` — ID mappings.
- `python -m unittest discover -s tests -v` — regressão, scaffold e segurança.
- `python tools/workspace.py build --all` — compilação Rojo de todos os Places.
- GitHub Actions com conclusão de sucesso e artefatos `.rbxlx`.
- Publicação real somente com confirmação explícita; testes remotos no motor Roblox e verificação visual/mobile requerem etapas próprias.

## 10. Sistemas fora do template por decisão

Inventário, combate, persistência, NPCs, Terrain, animações, UI, rede complexa, monetização, assets externos e progressão **não são inventados por padrão**. Cada novo jogo precisa especificá-los em seu GDD. O template prepara corretamente a estrutura para implementá-los sem misturar jogos.
