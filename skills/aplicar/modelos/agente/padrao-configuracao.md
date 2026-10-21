<!-- gerado pelo plugin padrao (/padrao:aplicar); edite no plugin, não aqui -->
# Configuração: no projeto, nada no global

`.claude/settings.json` (time, no git) e `.claude/settings.local.json` (pessoal: idioma, tela —
fora do git). Skills, agents e MCP (`.mcp.json`) moram no projeto. Auto memory desligado: o
contexto do projeto é o `CLAUDE.md` da pasta, mais os arquivos sob demanda do índice dele. O
`~/.claude/settings.json` guarda SÓ o que o Claude Code recusa de projeto —
`permissions.defaultMode` e `skipDangerousModePermissionPrompt` —, `autoMemoryEnabled: false` e
as status lines — a principal e a dos subagents, que mostra o modelo de cada um e marca em
vermelho o que estiver fora da 5.5 (interface do terminal, vale em qualquer pasta). Ao abrir, o
hook do plugin `padrao` avisa se algo voltou para o global (o `/model` grava lá) ou se o projeto
saiu do padrão: rode `/padrao:aplicar`. Transcripts ficam 14 dias, só para o `/resume`;
checkpoints (`/rewind`) desligados.
