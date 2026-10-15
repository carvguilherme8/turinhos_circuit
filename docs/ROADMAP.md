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
- [ ] Cena `scenes/bike/bike.tscn` com `RigidBody3D` + 2 raycasts de suspensão
- [ ] Aceleração, freio e direção
- [ ] Torque de equilíbrio (moto não tomba)
- [ ] Inclinação no ar e detecção de pouso (bom / ruim / queda)
- [ ] Reposicionar moto (tecla R)
- [ ] Recurso `BikeStats` com parâmetros ajustáveis
- [ ] Câmera de perseguição suavizada
- [ ] Cena de teste "playground" com rampas de vários tamanhos

## Marco 2 — Uma corrida de verdade
**Objetivo:** completar 3 voltas numa pista com tempo.
- [ ] Primeira pista (modular ou `.glb`)
- [ ] Checkpoints e contagem de voltas
- [ ] Cronômetro, melhor volta
- [ ] Contagem regressiva de largada
- [ ] HUD básico
- [ ] Respawn no último checkpoint ao cair ou sair da pista

## Marco 3 — Adversários
**Objetivo:** correr contra 5 pilotos e ter uma posição final.
- [ ] Linha de corrida (`Path3D`) na pista
- [ ] IA seguindo o caminho, com velocidade adaptativa
- [ ] Cálculo de posição em tempo real
- [ ] Tela de resultado

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
