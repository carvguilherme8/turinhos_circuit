# Fluxo de trabalho com Git

## Ciclo do dia a dia

1. **Antes de começar:** puxe as últimas mudanças (`git pull` ou *Fetch/Pull* no GitHub Desktop).
2. Trabalhe no Godot e teste com **F5**.
3. **Ao terminar algo que funciona:** commit com mensagem clara e push.

Commits pequenos e frequentes são melhores do que um commit gigante no fim do dia.

## Mensagens de commit

Formato sugerido: `tipo: descrição curta`

- `feat: inclinação da moto no ar`
- `fix: moto atravessando a rampa em alta velocidade`
- `art: modelo low poly da moto`
- `docs: atualiza roadmap`
- `tune: ajusta suspensão e gravidade`

## Branches

- `main` — sempre abre e roda sem erro.
- Para funcionalidades maiores: `feat/nome` (ex.: `feat/ia-adversarios`), e depois merge na `main`.

## Cuidados com o Godot

- A pasta `.godot/` é cache e **não** vai para o Git.
- Arquivos `.uid` (Godot 4.4+) **vão** para o Git, junto do arquivo correspondente.
- Evite editar a mesma cena (`.tscn`) em dois lugares ao mesmo tempo: conflitos em cenas são chatos de resolver.
- Ao mover/renomear arquivos, faça **pelo painel FileSystem do Godot**, para ele atualizar as referências.
- Se os assets ficarem pesados (> 50 MB por arquivo), considere ativar o Git LFS.
