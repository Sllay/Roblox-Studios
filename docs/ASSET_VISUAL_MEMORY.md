# Memória visual de assets

A biblioteca visual é persistida por jogo em game/assets/visual-reviews/<pack-id>.json. Ela guarda Asset ID, seletor interno, assinatura dos metadados observados, assinatura dos pixels das miniaturas, descrição natural, copa, tronco, estilo, sugestões de bioma, semelhança aproximada, dimensões, confiança e origem da revisão.

## Consulta sem rede

    python tools/assets/visual_lookup.py --query retorcida --biome bosque-fantasia
    python tools/assets/visual_lookup.py --query pinheiro --biome floresta-coniferas
    python tools/assets/visual_lookup.py --name Tree_01

O agente consulta primeiro a memória existente. Só volta a analisar imagens quando não existe uma ficha compatível, quando a evidência muda ou quando precisa de uma característica ainda não observada. O workflow Asset visual memory gera novas imagens e reaproveita as revisões apenas se modelKey e evidenceKey coincidirem. A assinatura de metadados e miniaturas NÃO garante que texturas PBR, conteúdo externo ou o modelo inteiro sejam imutáveis. Reauditoria e validação de direitos continuam obrigatórias antes de importar.

## Evidências e limites

Teste 43132925604: 29 Models, 23 plantas, 6 estruturas auxiliares Organization (Meshes_Roots, Materials_Bark, Meshes_Leaves, Models_Bushes, Textures_Leaves, Models_Trees). 46 miniaturas de malhas + 1 miniatura do pacote, total 47. Foram revisadas visualmente as 23 plantas, a partir das miniaturas oficiais dos componentes. A cor configurada é verde-oliva na copa e marrom na madeira, mas a cor final do material PBR não foi observada individualmente. Não atribuir as cores do thumbnail do pacote a um modelo específico. Semelhanças botânicas e biomas são recomendações estéticas, não identificação de espécie. Descrição visual não concede autorização de importação.

Próxima fase: preview texturizado individual, dependências PBR completas e validação real no staging. Não publicar binários ou texturas de terceiros para obter miniaturas.
