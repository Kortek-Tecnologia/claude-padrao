# Regras de documentação do /padrao:arrumar

Valem para o plano (fase 2) e para o executor (fase 3).

- Não documente o que o código já responde: texto que duplica o código desatualiza.
- Sem CHANGELOG nem histórico de alterações: o histórico está no git.
- Regra só fica com o porquê explícito e o código atual a confirmando.
- Uma fonte de verdade por assunto. Conteúdo sem dono claro: prefira remover a reescrever.
- `CLAUDE.md`/`AGENTS.md` só com o que vale em toda sessão. Tema de parte do trabalho →
  `docs/agente/<tema>.md`, com uma linha no índice `## Contexto sob demanda` do `CLAUDE.md`, fora
  do bloco do padrão:
  `| docs/agente/deploy.md | antes de fazer deploy ou mexer no CI |` — gatilho concreto, verbo +
  objeto. Regra presa a caminhos → `.claude/rules/<tema>.md` com `paths:`. Procedimento de vários
  passos → skill em `.claude/skills/`. `@import` não enxuga: carrega sempre.
- Arquivo apontado: um tema por arquivo, nome que diga o tema; tema com menos de ~5 linhas não
  vira arquivo; índice com até ~15 linhas; o conteúdo sai do `CLAUDE.md`.
- Rules atômicas, sem sobreposição, com nome que diga quando valem.
- Em código, só comentários e docstrings. Docstring consumida por ferramenta (OpenAPI do
  FastAPI/Pydantic, gerador de docs) no máximo se reduz.
- Antes de remover ou mover um arquivo, confira quem o consome: release-please,
  semantic-release, `readme` do pyproject.toml/package.json, links, badges, CI.
- O lote do `CLAUDE.md` deixa, fora do bloco do padrão, uma regra curta contra documentação
  desnecessária (ajuste a que já houver): não documentar o que o código responde; sem
  CHANGELOG; regra nova com porquê; tema que não vale em toda sessão vai para `docs/agente/`.
