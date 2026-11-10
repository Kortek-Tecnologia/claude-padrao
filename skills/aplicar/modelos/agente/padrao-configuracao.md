<!-- gerado pelo plugin padrao (/padrao:aplicar), modelo 2.1.0; edite no plugin, não aqui -->
# Configuração: no projeto, nada no global

`.claude/settings.json` (time, no git) e `.claude/settings.local.json` (pessoal: idioma, tela —
fora do git). Skills, agents e MCP (`.mcp.json`) moram no projeto. Auto memory desligado: o
contexto do projeto é o `CLAUDE.md` da pasta, mais os arquivos sob demanda do índice dele. O
`~/.claude/settings.json` guarda SÓ `autoMemoryEnabled: false` e as status lines — a principal e
a dos subagents, que mostra o modelo de cada um e marca em vermelho o que estiver fora dos
modelos que o padrão fixa (interface do terminal, vale em qualquer pasta) —, mais o que o Claude
Code recusa de projeto (`permissions.defaultMode`, `skipDangerousModePermissionPrompt`) se o
usuário já o usava: o padrão não liga bypass. Ao abrir, o hook do plugin `padrao` avisa se algo
voltou para o global (o `/model` grava lá), se o projeto saiu do padrão ou se o bloco do
`CLAUDE.md` e estes arquivos são de um modelo anterior (o carimbo `modelo X` da primeira linha):
rode `/padrao:aplicar`. O effort que o
`/effort` salva no global não conta: o projeto vence e a sessão abre em medium. Transcripts
ficam 14 dias, só para o `/resume`; checkpoints (`/rewind`) ligados.
