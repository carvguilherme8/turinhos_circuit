# Turinhos Circuit

Jogo arcade de motocross low poly, feito em **Godot 4**.

## Como rodar

1. Clone o repositório:
   ```bash
   git clone https://github.com/carvguilherme8/turinhos_circuit.git
   ```
2. Abra o Godot 4 → **Importar** → selecione o arquivo `project.godot`.
3. Aperte **F5** para jogar.

> Se o Godot avisar que o projeto foi feito para outra versão 4.x, pode confirmar a conversão.

## Estrutura

```
assets/        modelos (.glb), texturas, materiais, áudio, fontes
scenes/        cenas do Godot (.tscn): game, bike, tracks, ui
scripts/       código GDScript: core, bike, camera, race, ui
docs/          GDD, roadmap e fluxo de trabalho
addons/        plugins do Godot
tests/         cenas e scripts de teste
```

## Documentação

- [Documento de design (GDD)](docs/GDD.md)
- [Roadmap](docs/ROADMAP.md)
- [Fluxo de trabalho com Git](docs/FLUXO_GIT.md)

## Controles

| Ação | Teclado | Controle |
|---|---|---|
| Acelerar / Frear | W / S | RT / LT |
| Virar | A / D | Analógico esquerdo |
| Inclinar | I / K | Analógico direito |
| Reposicionar | R | Y |
| Pausar | Esc | Start |
