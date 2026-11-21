# Implementação faseada — Between Kingdoms

## Fundação — estágio inicial (sem Place ID)

Template, GDD, arquitetura, destinação staging/production separadas e auditoria de reuso de assets. Ao receber Universe e Place IDs verificados, usar `tools/scaffold.py set-ids` para staging antes de publicar.

## V0: protótipo lateral

1. Câmera scriptável side-scroller R6 + limite de Z + movimento esquerda/direita.
2. Superfície de jogo 100% 3D com Terrain nativo e quatro faixas: fundo distante, fundo interativo, trilho principal X/Y e primeiro plano decorativo preto (sem parallax 2D).
3. Interação contextual e ataque básico. Prova de controle R6 com cima/baixo virando em terra e natação vertical/diagonal com água nativa, rios que cruzam o trilho, sem deslocamento Z. Testar touch e FPS.

## V1: economia viva

4. Recurso real madeira/pedra/food; ledger transacional.
5. NPC job board com três profissões (carpinteiro, guarda/arqueiro, transportador) e evacuação.
6. Muro + depósito: posicionamento contínuo com footprint válido, blueprint entregue progressivamente por inventário real do NPC, progresso de obra persistente, capacidade, perdas e salvage.

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

## Checkpoints V0.2 — prioridades

A. **Experiência de movimento:** R6 em plano lateral; orientação frente/fundo em terra sem mudar Z; Terrain water nadável com ascensão/descida/diagonal suavizadas; água visual descendo montanhas e atravessando trilho; validar nadar/sair/não vibrar.

B. **Geração e geometria:** Terrain native + instâncias 3D no fundo próximo com `WorkAnchor`; horizonte 3D; silhouettes de frente pretas; profiler em mobile com oclusão adaptativa; validar travessia rasa e profunda.

C. **Construção e NPC:** colocar blueprint em posições livres com regras; NPC com madeira levada à obra; 2 NPCs depositando materiais simultaneamente sem duplicação; construtor iniciar, dormir, retomar; multiplicadores 3x/2x/1x e inventário com peso persistente.

D. **Pontes e rotas:** travessia profunda bloqueada para NPC/montaria; ponte leve permite construtores; ponte sólida libera transporte/carga/montaria; grafo recalcula acessibilidade ao construir/destruir.

E. **Monetização como fase pós-validação do loop:** UI demonstra 1/3, 2/3, 3/3 de aceleração como créditos simulados. Integração de anúncios reais só após elegibilidade e produto configurado; Robux com ProcessReceipt e idempotência. Nunca validar compra real em staging por botão falso como se fosse produção.

F. **Experiência do começo:** prólogo sem infecção interna espalhada, sem surtos impossíveis; trabalhar até conseguir defender primeira incursão e salvar antes da monetização.

## Revisão de escopo

Temporada inicial medieval, sem ciência, ruínas tecnológicas ostensivas ou saltos para cyberpunk. Mundo originalmente avançado vira segredo da história e pesquisa tardia. PvP e guerra de reinos continuam FUTURO, com normalização de benefícios pagos.
