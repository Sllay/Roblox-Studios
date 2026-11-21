# Implementação faseada — Between Kingdoms

## Fundação — estágio inicial (sem Place ID)

Template, GDD, arquitetura, destinação staging/production separadas e auditoria de reuso de assets. Ao receber Universe e Place IDs verificados, usar `tools/scaffold.py set-ids` para staging antes de publicar.

## V0: protótipo lateral

1. Câmera scriptável side-scroller R6 + limite de Z + movimento esquerda/direita.
2. Superfície de jogo 2.5D com Terrain nativo e camadas visuais.
3. Interação contextual e ataque básico. Testar touch e FPS.

## V1: economia viva

4. Recurso real madeira/pedra/food; ledger transacional.
5. NPC job board com três profissões (carpinteiro, guarda/arqueiro, transportador) e evacuação.
6. Muro + depósito: construir/reparar, capacidade, perdas e salvage.

## V2: ameaça e campanha

7. Relógio e portal com incursões intermitentes de um lado ou outro e sinais antecipados.
8. Inimigo básico, corrupção inicial, combate dos NPCs.
9. Um slot de save funcional com restauração de seed, inventário e estruturas.
10. Prólogo jogável enxuto: guarda → duque infectado → defesa → coroa.

## V3: expansão

11. Seis slots, profissão ferreiro/minerador/fazendeiro/caçador, comércio e tributo.
12. Segundo reino simulado, direção variável, negociação e domesticação simples.
13. Relações e traços sociais; incursões coordenadas, recuperação de distrito.

## Futuro

Campanhas longas, múltiplos reinos, diplomacia plena, conquista e fusão territorial, bosses, co-op/PvP. Não expandir escopo antes de jogar e testar V2.

## Gates de saída

CI Luau + Rojo + testes transacionais e geração; teste observável no cliente Roblox; validar jogabilidade e desempenho mobile; só então promover para um Universe/Place distinto de produção.

## Pendências de produto

- Nome em inglês provisório: Between Kingdoms.
- Receber Universe ID e Place ID de staging do usuário (não confundir com production).
- Decidir controle de ordem (botão contextual vs estandarte); densidade das faixas Z e montarias.
- Confirmar se tempo e raides param quando o slot não está em sessão.
