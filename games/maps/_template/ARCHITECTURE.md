# Arquitetura — Novo Jogo

O código publicável fica em `game/places/<place>/src/`, compilado por Rojo. Backend e frontend são separados em `ServerScriptService` e `StarterPlayerScripts`. Módulos partilhados entram por `ReplicatedStorage.PlatformShared`.

Definir aqui os serviços, fluxo de dados, networking, persistência, validações, testes e orçamentos de desempenho deste jogo.
