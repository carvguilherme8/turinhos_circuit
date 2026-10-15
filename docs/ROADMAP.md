# Roadmap

Cada marco termina com algo **jogável** que dá para testar no Godot (F5). Não avançar para o próximo sem o anterior estar divertido.

## Marco 0 — Fundação ✅
- [x] Estrutura de pastas e projeto Godot 4
- [x] `.gitignore` / `.gitattributes` para Godot
- [x] Mapa de controles (teclado + controle)
- [x] Cena de verificação (F5 abre uma cena low poly provisória)
- [x] GDD e roadmap

## Marco 1 — A moto anda (protótipo de física)
**Objetivo:** dirigir uma caixa num terreno com rampas e achar a física divertida.
- [x] Cena `scenes/bike/bike.tscn` com `RigidBody3D` + 2 raycasts de suspensão
- [x] Aceleração, freio e direção
- [x] Torque de equilíbrio (moto não tomba)
- [x] Freio de mão com derrapagem e peso do piloto (wheelie, whip)
- [x] Inclinação no ar e detecção de pouso (bom / ruim / queda)
- [x] Reposicionar moto (tecla R)
- [x] Recurso `BikeStats` com parâmetros ajustáveis
- [ ] Câmera de perseguição suavizada
- [x] Modelo voxel da moto (Blockbench) com guidão e suspensão animados
- [x] Cena de teste "playground" com rampas de vários tamanhos

## Marco 2 — Uma corrida de verdade
**Objetivo:** completar 3 voltas numa pista com tempo.
- [x] Primeira pista (estádio de supercross, gerada por script)
- [x] Contagem de voltas (progresso ao longo da linha central da pista)
- [x] Cronômetro (falta: melhor volta)
- [x] Contagem regressiva de largada
- [x] HUD básico (posição, volta, tempo)
- [x] Recolocar na pista ao cair ou sair da faixa
- [x] Reiniciar a corrida (Backspace)

## Marco 3 — Adversários
**Objetivo:** correr contra 5 pilotos e ter uma posição final.
- [x] Linha de corrida (linha central da pista, com deslocamento por bot)
- [x] IA seguindo o caminho, com velocidade adaptativa (freia antes das curvas)
- [x] Cálculo de posição em tempo real
- [x] Tela de resultado
- [x] Cores e números diferentes por piloto
- [ ] 5 adversários (hoje são 3) e rubber banding leve
- [ ] Bots desviando uns dos outros

## Marco 4 — Visual e som
**Objetivo:** parecer e soar como um jogo.
- [ ] Modelo low poly da moto e do piloto (Blender)
- [ ] Animações simples do piloto (inclinar, em pé nos saltos)
- [ ] Partículas de terra e poeira
- [ ] Som de motor dinâmico, pouso, multidão, música
- [ ] Ambientação da pista (árvores, cercas, arquibancada, bandeiras)

## Marco 5 — Jogo completo (versão 1.0)
- [ ] Menu principal, seleção de pista, pausa, opções (volume, controles, gráficos)
- [ ] 3 pistas
- [ ] Recordes salvos localmente
- [ ] Desbloqueio de pistas/cores
- [ ] Exportação para Windows e Linux
- [ ] Publicação (ex.: itch.io)

## Ideias para depois
Modo contra o relógio com fantasma, tricks com pontuação, mais motos com stats diferentes, clima/noite, editor de pistas, multiplayer local em tela dividida.
