# Turinhos Circuit — Documento de Design (GDD)

> Documento vivo. Atualize sempre que uma decisão mudar.

## 1. Visão geral

| Item | Definição |
|---|---|
| Gênero | Corrida arcade de motocross |
| Estilo visual | Low poly, cores chapadas, sem texturas detalhadas |
| Engine | Godot 4 (GDScript) |
| Plataforma | PC (Windows/Linux), teclado e controle |
| Câmera | Terceira pessoa, atrás e acima da moto |
| Jogadores | 1 jogador contra pilotos controlados pelo computador |

**Frase-pitch:** corridas curtas e caóticas em pistas de terra cheias de saltos, onde acertar o pouso é tão importante quanto acelerar.

## 2. Pilares de design

1. **Pouso é tudo.** O jogador controla a inclinação da moto no ar; pousar alinhado com a rampa dá velocidade, pousar torto faz perder tempo ou cair.
2. **Fácil de pegar, difícil de dominar.** Acelerar e virar já basta para terminar uma corrida; inclinação, curvas fechadas e linhas de pista separam o bom do ótimo.
3. **Rápido de reiniciar.** Caiu? Volta na pista em 1 segundo. Corrida inteira em 2–4 minutos.
4. **Leitura visual clara.** Low poly com paleta forte: pista, bordas e obstáculos sempre distinguíveis.

## 3. Loop de jogo

**Momento a momento:** acelerar → frear/virar nas curvas → saltar → inclinar no ar → pousar → repetir.

**Por corrida:** largada → 3 voltas → posição final → tempo da melhor volta.

**Meta (longo prazo):** vencer corridas desbloqueia pistas e cores/peças da moto; recordes de tempo por pista.

## 4. Controles

| Ação | Teclado | Controle |
|---|---|---|
| Acelerar | W | RT |
| Frear / ré | S | LT |
| Virar | A, D | Analógico esquerdo |
| Freio de mão (derrapagem) | Espaço | A |
| Peso do piloto: frente/trás (chão: empinar/levantar traseira; ar: girar) | ↑ / ↓ | Analógico direito ↕ |
| Peso do piloto: lados (ar: whip) | ← / → | Analógico direito ↔ |
| Reposicionar moto | R | Y |
| Pausar | Esc | Start |

> Os controles são registrados em `scripts/core/game_input.gd`. Mão esquerda pilota (WASD), mão direita controla o corpo do piloto (setas).

## 5. A moto (física)

Abordagem arcade, não simulação:

- **Corpo:** `RigidBody3D` com centro de massa baixo.
- **Rodas:** raycasts de suspensão (uma por roda), aplicando força de mola + amortecedor. Mais controlável que `VehicleBody3D` para duas rodas.
- **Equilíbrio:** a moto não tomba sozinha; um torque de correção mantém ela em pé, e o piloto apenas inclina visualmente nas curvas.
- **No ar:** o input de inclinação aplica torque no eixo de arfagem (pitch); gravidade levemente aumentada para saltos com sensação "pesada".
- **Pouso:** compara o ângulo da moto com a normal do chão.
  - Alinhado (< ~15°): mantém ou ganha um pouco de velocidade.
  - Torto (15°–45°): perde velocidade.
  - Muito torto (> 45°) ou de ponta-cabeça: queda → reposiciona.
- **Parâmetros ajustáveis** num recurso `BikeStats` (`.tres`): potência, velocidade máxima, aderência, força de inclinação, suspensão. Facilita testar e criar motos diferentes.

## 6. Pistas

- Circuitos fechados com checkpoints (impede atalhos e define volta válida).
- Elementos: rampas simples, sequência de costelas (*whoops*), mesas (*tabletops*), curvas com barranco (*berms*), saltos duplos/triplos.
- Construção: modelagem no Blender exportada em `.glb` **ou** peças modulares encaixáveis montadas no Godot (preferível no começo: rápido para iterar).
- Primeira pista: curta, plana, poucas rampas — serve de teste de física.

## 7. Adversários (IA)

- Seguem um `Path3D` traçado na pista (linha de corrida).
- Ajustam aceleração por "olhar à frente" na curva do caminho.
- *Rubber banding* leve (configurável) para manter a corrida disputada.
- Quedas da IA também acontecem, de forma aleatória e controlada.

## 8. Câmera

- Segue a moto com suavização (lerp de posição e rotação).
- Recua levemente com a velocidade (sensação de rapidez) e ajusta o FOV.
- No ar, para de acompanhar o pitch da moto, para o jogador enxergar o pouso.

## 9. Interface

- HUD: posição (1º/6), volta (2/3), tempo atual, velocímetro.
- Menus: principal, seleção de pista, pausa, resultado da corrida.
- Contagem regressiva na largada.

## 10. Arte e áudio

- **Arte:** low poly (moto ~1–3 mil triângulos), paleta limitada por pista (ex.: terra laranja, céu azul de fim de tarde). Atlas de cores ou cores por vértice em vez de texturas.
- **Ferramenta:** Blender → exportar `.glb` em `assets/models/`.
- **Áudio:** motor com pitch variando pela rotação, pouso, derrapagem, multidão, música de fundo. Começar com sons livres (ex.: freesound.org, verificando licença) e trocar depois.

## 11. Fora do escopo (por enquanto)

Multiplayer online, modo carreira completo, editor de pistas para o jogador, personalização profunda do piloto, mobile/console.

## 12. Perguntas abertas

- [x] Inclinação no teclado: setas (WASD para dirigir).
- [ ] Haverá *boost*/nitro, ou só técnica de pouso?
- [ ] Manobras (tricks) no ar valem pontos ou ficam fora?
- [ ] Quantas pistas na primeira versão "completa"? (sugestão: 3)
- [ ] Número de adversários por corrida (sugestão: 5)
- [ ] Tom do jogo: realista colorido ou cartunesco (motos exageradas, cabeçudos)?
