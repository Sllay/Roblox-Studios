# Entre Reinos — roteiro de testes T1-R1 em staging

Ambiente: **Universe 10769712413, Place 90623742498445**, somente após confirmação de publicação real. Não usar Black Island. O mapa é a primeira região, não o jogo completo: NPCs, construção e combate serão T1-R2/R3.

## 1. Entrada e menus
- [ ] A tela mostra ENTRE REINOS e os botões Jogar, Opções e Voltar.
- [ ] Em Jogar aparecem exatamente seis slots independentes, vazios antes de primeiro uso.
- [ ] O jogador está em rig **R6**. Se aparecer a mensagem de configuração R6, não prossiga: registrar erro e corrigir Avatar Settings do Place.
- [ ] Criar slot 1 abre mundo sem tela travada/erro de DataStore.

## 2. Mundo 100% 3D
- [ ] Solo de Terrain existe e sustenta o R6; não cai infinitamente.
- [ ] A câmera lateral mostra profundidade 3D, árvores atrás e elementos de silhueta preta na frente.
- [ ] Rio próximo a x ~76 (a leste do spawn) contém água REAL Roblox, com margens de areia.
- [ ] Não há rio sem fundo, buracos, água acima do terreno, Baseplate antiga visível ou objeto estranho.
- [ ] A vegetação negra do primeiro plano não oculta o avatar na área central.

## 3. Controle e física
- [ ] Esquerda/direita movem somente em X, sem caminhar livremente para frente/trás.
- [ ] Cima/baixo em terra giram o corpo sem deslocar o personagem em Z.
- [ ] Pulo e aterrissagem funcionam sem vibração, penetração no solo ou teleporte.
- [ ] Ao entrar no rio, X move horizontal, cima sobe, baixo mergulha, diagonais mantêm velocidade coerente.
- [ ] Ao sair da água, os controles retornam ao modo terrestre sem tremer.
- [ ] Indicador Z permanece próximo de zero; se sair de 1 stud ou houver tremor, registrar valor.
- [ ] As bordas da região inicial possuem limite seguro, sem cair no vazio.

## 4. Seis saves com risco de dados
- [ ] Após criar slot 1, anotar seed no painel.
- [ ] Caminhar, sair COMPLETAMENTE do Roblox, entrar de novo, abrir slot 1: seed e posição aproximada preservadas.
- [ ] Criar slot 2, anotar seed diferente; entrar no slot 2 não altera o 1.
- [ ] Excluir slot 2 somente após confirmar que é de teste; slot 1 continua existente.
- [ ] Tentar abrir um slot já em uso numa segunda sessão/servidor deve recusar com mensagem, não duplicar mundos.
- [ ] Após erro de rede/desconexão, dados antigos não podem desaparecer nem virar slot vazio.

## 5. Mobile e desempenho
- [ ] Controles touch clicáveis sem cobrir o menu, saltar, subir/mergulhar.
- [ ] Alterar câmera padrão/ampla e verificar enquadramento.
- [ ] Anotar FPS mostrado no painel perto do spawn, correndo, na margem e nadando.
- [ ] Notar se aparecem microtravamentos do personagem mesmo com FPS alto.
- [ ] Registrar nome do celular, capturas (se possível) e descrição de problemas.

## Critério de avaliação

Uma falha crítica de save, spawn, R6 ou nado bloqueia `T1-R1 validated`, mesmo com CI verde. Enviar comportamento observado em cada item que falhou; para bugs de movimento descrever se foi andando, parado, pulando ou nadando, e qual direção. Não validar o runner automaticamente só por publicar.
