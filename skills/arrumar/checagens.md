# Checagens da trilha B

Lista fechada de desvios de segurança e de CI que a trilha B do `/padrao:arrumar` confere. Quem
confere é a sessão, não o `padrao:leitor`: os comandos abaixo são git e `gh` de consulta.

- **Só o item cujo "Vale quando" bate vira desvio**: projeto sem CI não ganha desvio de CI, CLI
  sem servidor não ganha desvio de produção. O `INFRA.md` fecha com uma linha por checagem e o
  resultado dela: `desvio`, `sem desvio`, `não se aplica` ou `não verificável`.
- **Sem evidência, não é desvio.** O comando de "Conferir" tem de devolver `arquivo:linha`,
  commit ou tempo medido. Ferramenta que o ambiente não tem (não instale) ou dado que o
  repositório não mostra → `não verificável`.
- **Nunca o valor de um segredo**, nem em `_audit/`: os comandos abaixo imprimem só arquivo,
  linha e commit. Não troque `-l`, `cut` ou `--name-only` por saída que mostre a linha casada.
- **Correção** diz o destino do desvio: `infra` entra em lote (CI, `.gitignore`, compose,
  Dockerfile, configuração versionada); `código` e `usuário` ficam de fora do plano e vão para o
  relatório — este fluxo não altera código, e revogar chave é de quem tem a conta.
- Cada desvio vira um `INF-*` em `PENDENCIAS.md`, com o id da checagem na evidência (`S2`, `C1`).

Padrão de segredo (formatos comuns de token e chave privada), para S1 e S2:

    P='(sk-ant-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|xox[baprs]-[A-Za-z0-9-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)'

Não é scanner de entropia: senha em texto puro e token de formato próprio escapam. Diga isso no
`INFRA.md` quando S1 e S2 saírem vazios.

## Segurança

### S1 — Segredo versionado
- Vale quando: é repositório git.
- Conferir: `git grep -nIE "$P" | cut -d: -f1,2` e
  `git ls-files | grep -Ei '(^|/)\.env($|\.)|\.(pem|key|p12|pfx)$|(^|/)id_(rsa|ed25519)$'`
  (`.env.example` e `.env.sample` não contam).
- Desvio: qualquer linha devolvida que não seja valor de exemplo ou de teste (abra o arquivo e
  confirme; o valor não vai para lugar nenhum).
- Gravidade: alta.
- Correção: `infra` — tirar do git e pôr no `.gitignore`; e `usuário` — a chave já foi exposta:
  revogar e trocar.

### S2 — Segredo no histórico
- Vale quando: é repositório git e S1 não cobriu (o segredo saiu da árvore, ficou nos commits).
- Conferir: `git log --all -G "$P" --format='%h' --name-only`.
- Desvio: commit que acrescenta ou remove linha com o padrão, fora de valor de exemplo ou teste.
- Gravidade: alta.
- Correção: `usuário` — revogar e trocar a chave; reescrever o histórico é decisão dele. Vai em
  primeiro lugar no relatório.

### S3 — `.env` fora do `.gitignore`
- Vale quando: existe `.env*` na pasta ou o código lê um (`dotenv`, `env_file`, `--env-file`).
- Conferir: `git check-ignore -q .env || echo "não ignorado"`; e o S1 para os já versionados.
- Desvio: `.env` não ignorado.
- Gravidade: média (alta se já houver `.env` com valor real na pasta).
- Correção: `infra`.

### S4 — Debug ligado em produção
- Vale quando: há configuração de produção versionada (compose ou Dockerfile de produção,
  manifesto de deploy, arquivo de settings de produção).
- Conferir: nesses arquivos, `DEBUG` ligado, `NODE_ENV` ou equivalente fora de produção,
  servidor de desenvolvimento ou recarga automática no comando (`--reload`, `--debug`, `dev`).
- Desvio: a ocorrência, com `arquivo:linha`. Arquivo só de desenvolvimento não conta.
- Gravidade: alta.
- Correção: `infra` em arquivo de configuração; `código` se o valor estiver fixo no código.

### S5 — Dependência com vulnerabilidade conhecida
- Vale quando: há lockfile e a ferramenta de auditoria do gerenciador já está instalada
  (`npm audit`, `pnpm audit`, `pip-audit`, `cargo audit`…).
- Conferir: rode a auditoria só de leitura (sem `fix`) e guarde a contagem por gravidade.
- Desvio: vulnerabilidade alta ou crítica em dependência de produção.
- Gravidade: alta (crítica ou alta), média (o resto). Sem a ferramenta: `não verificável`.
- Correção: `código` — atualizar dependência muda o lockfile e pode quebrar; vai para o relatório
  com o pacote e a versão que corrige.

### S6 — CI com permissão larga
- Vale quando: há `.github/workflows/`.
- Conferir: workflow sem bloco `permissions:` (herda a permissão do repositório, em geral
  escrita); `pull_request_target` com checkout do código do PR; segredo usado em job que roda em
  PR de fork.
- Desvio: cada ocorrência, com `arquivo:linha`.
- Gravidade: alta (`pull_request_target` com código do PR), média (o resto).
- Correção: `infra` — `permissions: contents: read` no topo e o que cada job precisar a mais.

## CI

Tempo vem de medição: `gh run list --workflow <arquivo> --limit 10 --json createdAt,updatedAt` e,
por passo, `gh run view <id> --json jobs`. Sem `gh` autenticado ou sem execução registrada, o
tempo é `não verificável` e os itens C1, C2 e C4 não viram desvio — CI rápido não se otimiza.

### C1 — Etapas independentes em série
- Vale quando: a mediana das execuções passa de 5 minutos.
- Conferir: lint, checagem de tipos, build e testes como passos de um job só, ou jobs presos por
  `needs` sem um depender da saída do outro.
- Desvio: os passos em série e o tempo de cada um.
- Gravidade: média.
- Correção: `infra` — um job por etapa, em paralelo.

### C2 — Dependências instaladas do zero
- Vale quando: o passo de instalação leva mais de 30 segundos e há lockfile.
- Conferir: o workflow não usa cache (o `cache:` da action de setup, `actions/cache`).
- Desvio: o passo e o tempo medido.
- Gravidade: baixa (média se a instalação for mais de um terço da execução).
- Correção: `infra` — cache com a chave no lockfile.

### C3 — Checagem barata fora do CI
- Vale quando: o projeto tem linter ou checagem de tipos configurados (`tsconfig.json`,
  configuração de `oxlint`, `eslint`, `ruff`, `mypy`…) e tem CI.
- Conferir: o CI não roda a ferramenta que o projeto configurou; ou roda depois dos testes.
- Desvio: a ferramenta configurada e a ausência (ou a ordem) no workflow.
- Gravidade: média.
- Correção: `infra` — rodar o que o projeto já usa (ex.: `tsc --noEmit`, `oxlint`), em paralelo
  com os testes. Não proponha ferramenta que o projeto não tem: isso é decisão de produto.

### C4 — Suíte longa inteira em todo PR
- Vale quando: o passo de testes leva mais de 10 minutos.
- Conferir: sem divisão em shards e sem seleção pelos arquivos que o diff alcança.
- Desvio: o tempo do passo e a ausência das duas.
- Gravidade: média.
- Correção: `infra`, como decisão assumida no plano (troca cobertura por tempo): shards
  equilibrados pelo tempo gravado de cada teste; no PR, só os testes que o diff alcança, se o
  runner souber (ex.: `vitest --changed`, `jest --changedSince`, `nx affected`), com a suíte
  inteira no branch principal.
