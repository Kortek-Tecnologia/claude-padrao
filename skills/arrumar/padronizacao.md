# Checagens de padronização da trilha B

Lista fechada de desvios de **estrutura de arquivos** (`E`) e de **versões fixadas** (`V`) que a
trilha B do `/padrao:arrumar` confere, com as mesmas regras de `checagens.md`, ao lado deste
arquivo: só o item cujo "Vale quando" bate, só com evidência (`arquivo:linha` ou a saída do
comando), uma linha por checagem no fim do `INFRA.md` (`desvio`, `sem desvio`, `não se aplica`,
`não verificável`), e cada desvio vira um `INF-*` com o id da checagem na evidência (`E3`, `V4`).

- **Convenção, não layout.** Não há árvore de pastas obrigatória. A régua de cada item é, nesta
  ordem: a norma que uma ferramenta do projeto lê (o runner que descobre os testes, o
  empacotador, o `git`, o editor pelo `.editorconfig`); a norma da linguagem (PEP 8 para nome de
  módulo Python, o layout padrão do Maven, pacote Go em minúsculas); e, sem norma, o que o
  próprio projeto pratica na maioria dos casos. Desvio é a minoria que foge da régua — nunca o
  gosto de quem audita. Sem maioria clara (menos de 4 em 5), não é desvio.
- **Estrutura não se documenta, se confere.** A árvore de pastas o repositório já responde: o
  achado daqui nunca é "documentar a estrutura" (ver `regras-docs.md`).
- **Fixar não é atualizar.** O item `V` troca a referência solta (`latest`, branch, faixa, nada)
  pela versão que ela resolve **hoje**, tirada do lockfile, do log da última execução ou do
  registro. Subir versão é mudança de comportamento: fica para o relatório (e para a `S5`).
  Sem como saber a versão em uso, o item é `não verificável`.
- **Correção** diz o destino: `infra` entra em lote — documentação, configuração, CI,
  `.gitignore`, script que o código não importa; `código` vai para o relatório, com a lista
  pronta — mover ou renomear arquivo-fonte quebra import, e gerar lockfile muda o que se instala;
  `usuário` é o que só ele faz (renomear tag publicada).
- **Lote que move arquivo:** `git mv`, e no mesmo lote toda referência ao caminho antigo (links,
  CI, manifestos, `Dockerfile`, scripts) — antes de mover, confira quem consome
  (`git grep -nF '<caminho antigo>'`). Verificação da ficha: esse `git grep` sai vazio e o que
  lia o arquivo ainda roda.

Os padrões abaixo são para `grep -E` (os de nome de arquivo, com `-i`). Eles listam candidatos:
quem decide se é desvio é o texto de "Desvio" de cada item.

    LIXO='(^|/)(node_modules|__pycache__|\.pytest_cache|\.mypy_cache|\.ruff_cache|\.venv|venv|\.idea|\.vs|coverage|htmlcov|\.next|\.nuxt|\.turbo|\.gradle)/|\.(pyc|pyo|class|o|obj|log|tmp|bak|orig|rej|swp|swo)$|(^|/)(\.DS_Store|Thumbs\.db|desktop\.ini)$|~$'
    COPIA='([-_. ](old|bkp|bak|backup|copy|copia|antigo|novo|new|final|tmp|temp|v[0-9]+)[0-9]*|[-_. ]?\([0-9]+\))(\.[A-Za-z0-9]+)*$'
    RAIZ='^(README|CLAUDE|AGENTS|AGENT_LEARNINGS|CONTRIBUTING|CODE_OF_CONDUCT|SECURITY|SUPPORT|CHANGELOG|HISTORY|LICENSE|NOTICE|GOVERNANCE|MAINTAINERS|AUTHORS)([._-][A-Za-z-]+)?\.(md|mdx|rst|adoc)$'
    NOMES='{ d = $0; if (!sub(/\/[^\/]*$/, "", d)) d = "."; n = $NF; e = n; if (!sub(/^.*\./, "", e)) e = "-"; sub(/\.[^.]*$/, "", n); t = n ~ /^[a-z0-9]+(-[a-z0-9]+)+$/ ? "kebab" : n ~ /^[a-z0-9]+(_[a-z0-9]+)+$/ ? "snake" : n ~ /^[a-z]+[0-9]*([A-Z][a-z0-9]*)+$/ ? "camel" : n ~ /^[A-Z][a-z0-9]+([A-Z][a-z0-9]*)+$/ ? "Pascal" : ""; if (t != "") { c[d "/*." e " " t]++; k[d "/*." e]++ } } END { for (x in c) { split(x, p, " "); if (c[x] < k[p[1]] && k[p[1]] >= 5) print p[1], p[2] "=" c[x] } }'
    LOCK='(^|/)(package-lock\.json|npm-shrinkwrap\.json|pnpm-lock\.yaml|yarn\.lock|bun\.lockb?|poetry\.lock|uv\.lock|Pipfile\.lock|pdm\.lock|Cargo\.lock|go\.sum|Gemfile\.lock|composer\.lock|packages\.lock\.json|gradle\.lockfile|flake\.lock)$'
    REQ='(^|/)(requirements|constraints)[^/]*\.txt$'
    FIXA='^[[:space:]]*(#|-|$)|==|@[[:space:]]*(git\+|https?:|file:)'
    INSTALA='(pip3? install|pipx (install|run)|uvx |npm (i|install) (-g|--global)|npx |pnpm (dlx|add -g)|bunx |yarn global add|go install|cargo install|gem install|dotnet tool install)'
    FLUT='^[[:space:]]*(-[[:space:]]+)?(FROM[[:space:]]+(--platform=[^[:space:]]+[[:space:]]+)?|image:[[:space:]]*)[^[:space:]:@]+(:(latest|stable|lts|edge|main|master|nightly|alpine|slim).?)?([[:space:]]+[Aa][Ss][[:space:]]+[^[:space:]]+)?[[:space:]]*$'
    MOVEL='uses:[[:space:]]*[^[:space:]@#]+@(main|master|latest|HEAD|develop|dev|trunk|next)([[:space:]]|$)|uses:[[:space:]]*[^.[:space:]@#][^[:space:]@#]*([[:space:]]|$)|(ubuntu|windows|macos)-latest'
    PRESA='@[0-9a-f]{40}([[:space:]]|$)|uses:[[:space:]]*(actions|github)/'
    VERSAO='^[[:space:]]*("version"|version|__version__|appVersion|VERSION)[[:space:]]*[:=][[:space:]]*.?[0-9]+\.[0-9]+'

## Estrutura de arquivos

### E1 — Artefato gerado ou resíduo versionado
- Vale quando: é repositório git.
- Conferir: `git ls-files -ci --exclude-standard` (versionado apesar de o `.gitignore` o
  ignorar) e `git ls-files | grep -E "$LIXO"`. Para `dist/`, `build/`, `out/` e `target/`
  versionados, ache o comando que os gera (manifesto, CI, `Makefile`).
- Desvio: arquivo que uma ferramenta gera ou que o editor e o sistema deixam (cache, log,
  `.pyc`, `.DS_Store`), com o caminho. Saída de build que o projeto publica pelo git de propósito
  (o `dist/` de uma GitHub Action) não conta.
- Gravidade: baixa (média se o arquivo muda a cada build e suja todo diff).
- Correção: `infra` — `git rm --cached` e a regra no `.gitignore`.

### E2 — Cópia ou versão no nome do arquivo
- Vale quando: é repositório git.
- Conferir: `git ls-files | grep -Ei "$COPIA"` e, para cada um, o irmão sem o sufixo
  (`relatorio_final.md` ↔ `relatorio.md`) e quem o referencia (`git grep -nF '<nome>'`).
- Desvio: o arquivo cujo irmão sem sufixo existe ao lado, ou que ninguém referencia — o
  histórico de versões é do git. Sufixo que é do domínio (`api/v2`, `schema_v2` em uso pelo
  código) não conta.
- Gravidade: baixa (média se o código importa os dois e não se sabe qual vale).
- Correção: `infra` em documentação, configuração e script sem import (remover o morto, depois
  de conferir quem consome); `código` em arquivo-fonte.

### E3 — Documento solto ou órfão
- Vale quando: há `docs/` (ou a pasta de documentação que o projeto pratica), ou mais de três
  documentos na raiz.
- Conferir: soltos — `git ls-files | grep -v / | grep -Ei '\.(md|mdx|rst|adoc)$' | grep -Eiv "$RAIZ"`;
  órfãos — `git ls-files 'docs/*.md' | while IFS= read -r f; do git grep -qIF -- "${f##*/}" -- . ":(exclude)$f" || echo "$f"; done`
  (`docs/agente/` fica de fora: o índice do `CLAUDE.md` é conferido no fim da fase 3).
- Desvio: documento na raiz fora dos nomes que GitHub e ferramentas leem ali (`README`,
  `LICENSE`, `CONTRIBUTING`, `SECURITY`…), quando o projeto tem pasta de documentação; e
  documento que nenhum outro arquivo versionado cita.
- Gravidade: baixa.
- Correção: `infra` — mover para a pasta de documentação com o link de quem o cita; o órfão
  ganha um link no índice ou no README se a trilha C o mantiver, e sai se ela o classificar como
  Obsoleto, Duplicado ou Excesso.

### E4 — Convenção de nomes misturada na mesma pasta
- Vale quando: alguma pasta tem cinco ou mais arquivos da mesma extensão com nome composto.
- Conferir: `git ls-files | awk -F/ "$NOMES" | sort` — por pasta e extensão, quantos nomes em
  `kebab`, `snake`, `camel` e `Pascal`; só saem as pastas com mais de um estilo.
- Desvio: os arquivos do estilo que contraria a norma da linguagem para aquele tipo (módulo
  Python em `snake_case`; classe Java e componente React em `Pascal`) ou, sem norma, a minoria
  quando a maioria passa de 4 em 5. Estilos diferentes com papéis diferentes na mesma pasta
  (componente `Pascal`, hook `camel`) não contam.
- Gravidade: baixa.
- Correção: `infra` em documentação, configuração e script que o código não importa (`git mv` e
  as referências); `código` em arquivo-fonte, com a lista "de → para" no relatório.

### E5 — Arquivo fora da pasta que a ferramenta lê
- Vale quando: o projeto tem runner de testes configurado, ou arquivos do Claude Code próprios
  (`.claude/skills/`, `.claude/agents/`, `.claude/rules/`).
- Conferir: testes — `git ls-files | grep -Ei '(^|/)(test_[^/]*\.py|[^/]*_test\.(py|go)|[^/]*\.(test|spec)\.[jt]sx?)$'`
  contra o que o runner descobre (`testpaths`, `python_files`, `testMatch`, `roots`,
  `src/test/java`); Claude Code — `ls .claude/skills/*.md .claude/agents/*/ 2>/dev/null` (skill é
  `<nome>/SKILL.md`; agente é arquivo direto na pasta).
- Desvio: o arquivo com nome de teste que o runner não alcança, com a linha da configuração que
  o deixa de fora; a skill ou o agente no formato que o Claude Code não carrega.
- Gravidade: média (teste que não roda e instrução que não carrega passam por garantia).
- Correção: `código` para teste (mover muda import: vai para o relatório); `infra` para os
  arquivos do Claude Code.

### E6 — Script avulso na raiz
- Vale quando: o projeto tem pasta de scripts (`scripts/`, `bin/`, `tools/`) com dois ou mais
  arquivos.
- Conferir: `git ls-files | grep -v / | grep -Ei '\.(sh|bash|ps1|bat|cmd|py|js|mjs|rb)$'`, menos
  o que a raiz exige: ponto de entrada citado no manifesto, no `Dockerfile` ou no `Makefile`, e
  arquivo de configuração de ferramenta (`*.config.js`, `setup.py`, `conftest.py`, `manage.py`,
  `noxfile.py`).
- Desvio: o script de operação que sobrou na raiz, com quem o chama.
- Gravidade: baixa.
- Correção: `infra` quando só documentação, CI e outros scripts o chamam (mover e acertar as
  chamadas no mesmo lote); `código` se o código o importa.

### E7 — Fim de linha misturado e sem regra
- Vale quando: é repositório git com arquivo de texto versionado.
- Conferir: `git ls-files --eol | grep -E '^i/(crlf|mixed)'` (o que está no índice com CRLF ou
  misto) e as regras de `.gitattributes` (`git check-attr text eol -- <arquivo>`); a presença de
  `.editorconfig`.
- Desvio: arquivo com CRLF ou misto no índice sem regra de `.gitattributes` que o peça
  (`*.bat eol=crlf` pede); script de shell com CRLF (não roda fora do Windows). Projeto sem
  `.editorconfig` só é desvio com evidência de mistura (este item, ou indentação de tab e de
  espaço na mesma linguagem).
- Gravidade: média (script de shell com CRLF), baixa (o resto).
- Correção: `infra`, em lote próprio — `.gitattributes` com `* text=auto eol=lf` e as exceções
  do projeto, e `git add --renormalize .` (decisão assumida no plano: o diff toca muitos
  arquivos sem mudar conteúdo); `.editorconfig` só com o que o projeto já pratica na maioria
  (charset, fim de linha, indentação por extensão) — escolher estilo novo é decisão de produto.

## Versões fixadas

### V1 — Dependências sem lockfile versionado
- Vale quando: há manifesto com dependências (`package.json`, `pyproject.toml`, `Pipfile`,
  `Cargo.toml`, `go.mod`, `Gemfile`, `composer.json`) e o projeto é aplicação ou serviço — o
  que se instala e roda, não biblioteca publicada para outros instalarem.
- Conferir: `git ls-files | grep -E "$LOCK"`, ao lado de cada manifesto; e
  `git check-ignore -v <lockfile>` para o lockfile que o `.gitignore` esconde.
- Desvio: manifesto com dependências sem lockfile versionado na mesma pasta, com a linha do
  `.gitignore` quando é ele que o tira; build ou CI que instala ignorando o lockfile
  (`npm install` onde cabia `npm ci`, `pip install` sem `--require-hashes` nem arquivo fixado).
- Gravidade: média (alta se o deploy instala assim).
- Correção: `infra` — tirar o lockfile do `.gitignore` e trocar o comando do CI ou do
  `Dockerfile` pelo que respeita o lockfile; `código` — gerar o lockfile que não existe (muda o
  que se instala e pede os testes): vai para o relatório com o comando (`npm install
  --package-lock-only`, `uv lock`, `poetry lock`).

### V2 — Instalação sem versão exata onde não há lockfile
- Vale quando: algo é instalado fora de lockfile: `requirements*.txt`, ou ferramenta instalada
  em `Dockerfile`, CI ou script.
- Conferir: `git ls-files | grep -Ei "$REQ" | while IFS= read -r f; do grep -nHEv "$FIXA" "$f"; done`
  (as linhas sem `==`) e `git grep -nE "$INSTALA" -- '*Dockerfile*' .github '*.sh' '*.ps1' Makefile`
  — em cada linha devolvida, o pacote sem versão exata (`==1.2.3`, `@1.2.3`) ou com `@latest`.
- Desvio: a linha, com o pacote. Faixa (`>=`, `^`, `~`) num manifesto que tem lockfile não conta:
  quem fixa ali é o lockfile.
- Gravidade: média (build, CI ou deploy), baixa (script de desenvolvimento).
- Correção: `infra` em `Dockerfile`, CI e script — a versão em uso hoje (a do lockfile, a que o
  log da última execução mostra, `npm view <pacote> version`); `código` em `requirements.txt` de
  aplicação sem ambiente de onde tirar a versão em uso (`pip freeze` do ambiente que roda os
  testes vai no relatório).

### V3 — Imagem de contêiner com tag flutuante
- Vale quando: há `Dockerfile`, compose, manifesto de deploy ou `container:`/`services:` no CI.
- Conferir: `git grep -nIE "$FLUT" -- '*Dockerfile*' '*.yml' '*.yaml'` — imagem sem tag ou com
  tag que anda (`latest`, `stable`, `lts`, `alpine`, `slim`).
- Desvio: a linha, quando é imagem de contêiner (`image:` de outra coisa não conta; `scratch` e o
  nome de um estágio anterior do mesmo `Dockerfile` também não). Tag só da versão maior
  (`node:22`) anda dentro dela: desvio baixo em imagem de produção, e decisão assumida no plano.
- Gravidade: média (produção), baixa (desenvolvimento e CI).
- Correção: `infra` — a tag exata que a referência resolve hoje (a do arquivo de versão do
  runtime, a do log do último build; com a imagem já baixada, `docker image inspect`). Docker
  parado e sem outra fonte: `não verificável`, no relatório.

### V4 — Action ou runner do CI por referência que anda
- Vale quando: há `.github/workflows/`.
- Conferir: `git grep -nE "$MOVEL" -- .github/workflows` (action por branch ou sem referência,
  runner `-latest`, inclusive na matriz) e
  `git grep -nE 'uses:[[:space:]]*[^[:space:]@#]+@' -- .github/workflows | grep -vE "$PRESA"`
  (action de terceiro presa por tag, que o dono pode mover; `actions/*` e `github/*` por tag
  passam).
- Desvio: cada linha, com `arquivo:linha`.
- Gravidade: média (action por branch ou sem referência; alta se o job dela lê segredo), baixa
  (runner `-latest`, action de terceiro por tag).
- Correção: `infra` — o SHA do commit para onde a tag aponta hoje, com a tag em comentário
  (`uses: dono/acao@<sha> # v4.1.0`; `gh api repos/<dono>/<acao>/commits/<tag> --jq .sha`), e a
  versão do runner que a última execução registrou. Sem `gh`: `não verificável`.

### V5 — Versão do runtime sem fonte única
- Vale quando: o projeto roda em runtime cuja versão muda comportamento (Node, Python, Go,
  Java, Ruby, .NET, Terraform) e há CI, `Dockerfile` ou mais de uma pessoa commitando.
- Conferir: o arquivo de versão que as ferramentas leem (`.nvmrc`, `.node-version`,
  `.python-version`, `.ruby-version`, `.tool-versions`, `mise.toml`, `rust-toolchain.toml`,
  `.terraform-version`; `engines` e `packageManager` do `package.json`; `requires-python`; a linha
  `go` do `go.mod`) contra
  `git grep -nE '(node|python|go|java|ruby|dotnet|php|bun|deno)-version(-file)?:' -- .github/workflows`
  e o `FROM` de cada `Dockerfile`.
- Desvio: versões diferentes entre o arquivo, o CI e o `Dockerfile` (liste as três, com
  `arquivo:linha`); nenhuma declaração e cada lugar escolhendo a sua; CI com versão que anda
  (`latest`, `lts/*`, `3.x`).
- Gravidade: média (versões diferentes), baixa (o resto).
- Correção: `infra` — uma fonte só, o arquivo de versão, e o CI lendo dele
  (`node-version-file: .nvmrc`, `python-version-file`, `go-version-file: go.mod`). Qual versão: a
  que a produção roda (o `Dockerfile`); sem ela, a do CI, onde os testes passam — decisão
  assumida no plano.

### V6 — Versão do projeto em mais de um lugar
- Vale quando: o projeto publica uma versão (manifesto de pacote, de plugin ou de chart,
  `__version__`, tag de release).
- Conferir: `git grep -nE "$VERSAO" -- package.json pyproject.toml setup.cfg setup.py Cargo.toml '*.gemspec' '*plugin.json' Chart.yaml '*/__init__.py' '*/version.py'`
  e `git tag --sort=-creatordate | head -n 5`.
- Desvio: valores que não batem entre si ou com a última tag; versão fora de
  `MAIOR.MENOR.CORREÇÃO`; tags em dois formatos (`v1.2.0` e `1.3.0`).
- Gravidade: média (a publicação lê o valor errado), baixa (o resto).
- Correção: `infra` — alinhar os manifestos ou fazer o secundário ler do principal, quando é
  configuração; `código` se o valor mora em arquivo-fonte; `usuário` para tag já publicada.
