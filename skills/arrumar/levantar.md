# Fase 1 do /padrao:arrumar: o levantamento

Lido no começo da fase 1, a partir do `SKILL.md` ao lado, que traz as regras de toda a
execução e as dos subagentes: valem aqui.

Ordem: `ESCOPO.md` → trilhas A e B em paralelo → trilha C → `PENDENCIAS.md`.

Situações previstas — decida e siga:
- **Não é repositório git**: `sem git` nos cabeçalhos; na fase 3 não há branch nem commit (as
  mudanças ficam no working tree); na retomada, refaça tudo.
- **Sem documentação** (nenhum .md além do bloco do padrão): a trilha C registra só os Gaps.
- **Sem infraestrutura** (sem Dockerfile, compose, CI): cada item da trilha B fica `ausente`,
  com a avaliação de se faz falta para este projeto.

## ESCOPO.md — o que entra

Decida você, grave a lista e, ao lado de cada exclusão, o critério. Caminho que não se encaixa
claramente em nenhum critério entra. Alteração sem commit: analise o working tree como está e
liste os arquivos alterados.

- **Excluir**: dependência de terceiros (`node_modules/`, `.venv/`, `vendor/`, submódulos);
  build, cache e saída gerada (`dist/`, `build/`, `__pycache__/`); arquivo gerado por ferramenta
  (lockfiles, cliente gerado por schema); o que o `.gitignore` ignora, menos `.env*` (só os nomes
  das variáveis); os arquivos do plugin acima; `.claude/memoria/`, `AGENT_LEARNINGS.md`, `_audit/`.
- **Nunca excluir**: o que descreve build, deploy ou execução (`Dockerfile`, compose,
  `.github/workflows/`, scripts de operação); testes, que mostram a convenção praticada;
  configuração de aplicação versionada.
- **Caso a caso**, com a razão: migrations (exclua o histórico, mantenha o schema final se só
  existir ali); diretórios muito grandes (amostra, confiança baixa).

## Trilha A — o sistema segundo o código → `SISTEMA.md`

Só do código: objetivo e domínio, arquitetura e responsabilidades, fluxos principais,
integrações externas, convenções praticadas. O `CLAUDE.md` já está no seu contexto e não dá
para "desler": a independência vem de rastreabilidade — só entra o que tiver `arquivo:linha` de
código (formato do `padrao:leitor`: `arquivo:linha · o que o código faz · confiança`); onde
suspeitar de contaminação sem âncora no código, marque.

## Trilha B — infraestrutura → `INFRA.md`

Estrutura de diretórios, containerização e ambientes, variáveis e segredos, CI/CD,
build/deploy/rollback, observabilidade. Para cada item: **Situação** (o que existe, com
`arquivo:linha`), **Avaliação** (opinativa, marcada como tal) e **Recomendação** quando houver
desvio. O que o repositório não mostra (VPS, DNS, segredos em runtime, runner) é
`não verificável`, nunca inferência.

**Checagens.** Depois do levantamento, confira você a lista de `checagens.md`, ao lado deste
arquivo: segurança (segredo versionado ou no histórico, debug em produção, dependência
vulnerável, permissão do CI, skill com efeito colateral que o modelo dispara sozinho), tempo de CI e execução de CI que não precisava ter rodado. Só o
item cujo "Vale quando" bate, só com evidência, e os de CI só com o tempo ou a contagem medidos. Cada desvio entra no `INFRA.md` com o id da checagem.

**Padronização.** Em seguida, do mesmo jeito, a lista de `padronizacao.md`, ao lado deste
arquivo: estrutura de arquivos por convenção (`E1`–`E7`: resíduo versionado, cópia no nome,
documento solto ou órfão, nomes misturados, arquivo fora da pasta que a ferramenta lê, script
avulso, fim de linha) e versões fixadas (`V1`–`V6`: lockfile, instalação sem versão, imagem,
action e runner, runtime, versão do projeto). É ela que dá critério à "estrutura de diretórios"
do levantamento: a régua é a norma que a ferramenta lê e o que o projeto pratica, não um layout.

## Trilha C — o que a documentação diz → `CONFRONTO.md`

Confronte `SISTEMA.md` e `INFRA.md` com `CLAUDE.md`, `AGENTS.md`, `.claude/rules/`, `docs/`, os
demais .md, comentários e docstrings. Registre toda divergência, inclusive pequena: a
severidade classifica, o plano filtra.

| Tipo | Significado |
|---|---|
| Gap | existe no código, não documentado — e é o porquê de uma decisão, como rodar/configurar ou uma armadilha não evidente |
| Divergência | documentado diferente do código |
| Obsoleto | documentado, não existe mais |
| Duplicado | mesma informação em mais de um lugar |
| Excesso | documenta o que o código já responde, histórico/CHANGELOG, instrução que o modelo já segue sozinho ("seja claro") ou enchimento |
| Fora do lugar | está na carga fixa e não vale em toda sessão; ou é instrução dada como ativa que não carrega (`AGENTS.md` sem import) |

O que o código responde sozinho (assinaturas, tipos, estrutura de pastas, lista de endpoints,
comportamento óbvio) **não é Gap**: documentá-lo cria texto que desatualiza. Cada Gap diz a sua
categoria (porquê · rodar/configurar · armadilha); sem categoria, não é Gap. Feche com a
contagem por tipo.

**Carga fixa.** Meça arquivo a arquivo (`wc -l`): `CLAUDE.md`, `.claude/CLAUDE.md` e
`CLAUDE.local.md` da raiz; cada `@caminho` importado fora de crase; e
`.claude/rules/**/*.md` sem `paths:` (`grep -rL '^paths:' .claude/rules`). A soma é a carga
fixa; `CLAUDE.md` de subdiretório e rule com `paths:` não somam. O `AGENTS.md` só soma quando
importado: havendo `CLAUDE.md` na pasta ou acima, o Claude Code não o lê sozinho. `AGENTS.md`
versionado (`git ls-files AGENTS.md '*/AGENTS.md'`) sem `CLAUDE.md` ao lado que o importe é
achado Fora do lugar — o time conta com instrução que não carrega; a correção é `@AGENTS.md` na
primeira linha do `CLAUDE.md` da pasta (em subpasta, um `CLAUDE.md` só com o import).

Julgue cada seção fora do
bloco do padrão: **uma tarefa qualquer neste projeto sairia errada sem isto no contexto?** Não →
Fora do lugar (ou Excesso). Mesmo com a carga abaixo de 200 linhas, é candidato: seção com mais
de ~15 linhas, tabela ou lista de consulta, passo a passo, exemplo longo, detalhe de um módulo
só. Acima de 200, o plano tem de trazê-la abaixo disso. Proibição ("não faça X") sem a forma
positiva também é achado: reduzir para o que fazer.

**Ênfase.** Na carga fixa, procure a instrução reforçada em vez de clara —
`grep -nE "$ENF" <arquivo>`, mais palavra comum em maiúsculas e a mesma regra repetida:

    ENF='(^|[^A-Za-z_])(IMPORTANTE?|NUNCA|SEMPRE|JAMAIS|PROIBIDO|NEVER|ALWAYS|MUST|CRITICAL)([^A-Za-z_]|$)'

É achado Excesso: a correção é a frase em texto simples, uma vez (o modelo atual segue a linha
dita sem ênfase, e ênfase empilhada o faz aplicar a regra além da conta). Regra que não pode
falhar não se garante com ênfase: vai para o relatório a recomendação de hook ou de regra `deny`
— este fluxo não cria hook.

## PENDENCIAS.md

Colunas: id, tipo, severidade, arquivos, evidência, status.
- id `DOC-001` (trilha C) ou `INF-001` (trilha B, tipo `Desvio`; o que veio de `checagens.md`
  traz o id da checagem na evidência e a gravidade dela);
- severidade: **alta** — leva agente ou pessoa a executar algo errado (build, deploy, comando,
  contrato de API); **média** — retrabalho ou decisão com base incompleta; **baixa** —
  incompleto ou cosmético;
- antes de marcar **alta**, abra você o `arquivo:linha` do código e confirme o que ele faz: a
  leitura do `padrao:leitor` é insumo, e documentação corrigida em cima de leitura errada sai
  mais cara que a conferência;
- `Duplicado` lista dois ou mais arquivos, com uma evidência por local; `Obsoleto` tem como
  evidência a ausência; os demais, `arquivo:linha`;
- status `aberto`; só a fase 3 muda para `resolvido`.
