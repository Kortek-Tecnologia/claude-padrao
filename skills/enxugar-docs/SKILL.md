---
name: enxugar-docs
description: Revisa a documentação do projeto (.md, docs/, CLAUDE.md/AGENTS.md, comentários e docstrings) para manter só o essencial — o porquê das decisões, como rodar/configurar e armadilhas não evidentes — e corta o CLAUDE.md ao que vale em toda sessão, movendo o resto para arquivos apontados e lidos sob demanda. Fase 1 só analisa e entrega a lista; edita só após aprovação.
disable-model-invocation: true
---

# Enxugar a documentação

Revise a documentação deste repositório para manter apenas o essencial.

Objetivo: documentação é lida por pessoas e agentes como regra. Uma regra desatualizada, sem
justificativa ou que contradiz o código leva a decisões ruins no futuro. Elimine esse risco
consolidando e enxugando tudo.

Princípios:
- Não documente o que o código já responde (assinaturas, parâmetros, tipos, estrutura de pastas,
  comportamento óbvio). Texto que duplica o código fica desatualizado quando o código muda.
- Não crie nem mantenha documentos de mudanças (CHANGELOG, histórico de alterações). O histórico
  está no Git.
- Uma regra só permanece se tiver o porquê explícito e o código atual a confirmar.
- Documentação enxuta: menos arquivos, textos curtos, sem redundância entre documentos. Sem seções
  de enchimento, resumos redundantes ou boilerplate.
- `CLAUDE.md`/`AGENTS.md` carregam em toda sessão e em quase todo subagent: cada linha é paga em
  toda tarefa, e arquivo longo é seguido pior. Ficam só com o que vale em toda tarefa; o resto é
  apontado e lido sob demanda (ver "Carga fixa" na Fase 1). Na dúvida, aponte — não acrescente.

Escopo:
- Documentação = arquivos .md, pasta docs/, CLAUDE.md/AGENTS.md, comentários e docstrings.
- Fora: o que o `.gitignore` ignora, código de terceiros (vendored, `node_modules`, `.venv`,
  submódulos) e código gerado — não são do projeto e voltam a cada atualização.
- Fora: `.env*` e arquivos de segredo — não os abra; se precisar das variáveis, só os nomes
  (`grep -o '^[A-Za-z_][A-Za-z0-9_]*' .env`).
- Fora: memórias em `.claude/memoria/` e `AGENT_LEARNINGS.md` — são memória do agente, não
  documentação. Se uma contradiz o código, aponte em uma frase.
- Em arquivos de código, altere apenas comentários e docstrings, nunca o código em si.
- Não remova docstrings consumidas por ferramentas (descrições de endpoints e modelos no OpenAPI
  do FastAPI/Pydantic, geradores de docs). Nesses casos, classifique apenas como manter ou reduzir.
- O bloco do `CLAUDE.md` entre `<!-- padrao:inicio` e `<!-- padrao:fim -->` e os
  `docs/agente/padrao-*.md` são gerados pelo plugin padrao e regravados pelo `/padrao:aplicar`:
  fora do escopo — não classifique nem edite.
- Se algo fora do escopo precisar mudar, aponte em uma frase e siga.

## Fase 1: análise (não edite nada)

Coleta e julgamento separados, para não gastar o contexto e o modelo principal em leitura:

0. Delegue a coleta ao `padrao:coletor` — em paralelo, um por área do repositório quando for
   grande. Peça, por arquivo de documentação, os trechos prescritivos com `arquivo:linha` e, para
   cada um, o código que o confirma ou desmente (`arquivo:linha` e o trecho); e as referências a
   cada arquivo .md (links, `readme` do pyproject.toml/package.json, badges, CI, release-please,
   semantic-release). O coletor só junta fatos: classificar é seu.

### Carga fixa: o `CLAUDE.md` e o que entra com ele

Meça antes de julgar, arquivo a arquivo (`wc -l`):
- `CLAUDE.md`, `.claude/CLAUDE.md`, `AGENTS.md` e `CLAUDE.local.md` da raiz;
- cada `@caminho` importado fora de crase (`grep -n '@' CLAUDE.md`): carrega junto, sempre;
- `.claude/rules/**/*.md` sem `paths:` no frontmatter (`grep -rL '^paths:' .claude/rules`):
  carregam sempre, como o `CLAUDE.md`.

A soma é a **carga fixa**. O bloco do padrão conta, mas não se mexe. `CLAUDE.md` de
subdiretório e rule com `paths:` carregam só ao tocar nos arquivos deles: não somam.

Julgue cada seção e cada parágrafo do `CLAUDE.md` fora do bloco com uma pergunta: **uma tarefa
qualquer neste projeto sairia errada sem isto no contexto?** Sim → fica. Não → sai para:

| O trecho é | Vai para |
|---|---|
| tema de parte do trabalho — deploy, release, integração, um módulo, um ambiente, arquitetura de uma área | `docs/agente/<tema>.md` + linha no índice |
| regra que só vale para certos caminhos ou extensões | `.claude/rules/<tema>.md` com `paths:` |
| procedimento de vários passos que se repete | skill em `.claude/skills/` |
| o que o código responde, duplicado ou histórico | remover |
| `@import` | trocar por linha no índice (o arquivo vira sob demanda) |

Rule sem `paths:` que só vale para parte do código: proponha os `paths:`.

Mesmo com a carga abaixo de 200 linhas, é candidato a sair: seção com mais de ~15 linhas, tabela
ou lista longa de consulta, passo a passo, exemplo longo, detalhe de um único módulo ou ambiente.
Carga acima de 200 linhas: a proposta TEM de trazê-la abaixo disso, e diga quanto fica.

Arquivo apontado bem feito:
- um tema por arquivo, nome que diga o tema (`docs/agente/deploy.md`, não `notas.md`);
- linha no índice `## Contexto sob demanda` do `CLAUDE.md`, fora do bloco do padrão:
  `| docs/agente/deploy.md | antes de fazer deploy ou mexer no CI |`. O gatilho é concreto,
  verbo + objeto; "quando precisar" ou "para mais detalhes" não serve, porque o agente não
  saberá quando abrir;
- tema com menos de ~5 linhas não vira arquivo: junte a um tema vizinho ou deixe onde está;
- índice curto (até ~15 linhas); o conteúdo SAI do `CLAUDE.md`, não fica duplicado;
- sem `@` no índice: importar devolve o arquivo à carga fixa.

1. Antes de classificar qualquer trecho, leia o código correspondente — o que o coletor trouxe.
   Não releia na íntegra o que ele já devolveu: abra só o trecho que faltar. Cite a linha do
   próprio arquivo (Read, `grep -n` arquivo a arquivo), nunca de saída concatenada (`cat -n a b`
   numera em sequência e erra a linha do segundo arquivo).
2. Para cada trecho prescritivo (sempre, nunca, deve, use X, padrão é), verifique:
   - se o código atual segue a regra;
   - se o porquê está explícito;
   - se a regra contradiz outro documento ou comentário.
   Se doc e código divergem, marque como DIVERGENTE e não decida qual está certo.
3. Classifique cada trecho como manter, reduzir, mover (para arquivo sob demanda — diga o destino),
   remover ou DIVERGENTE. Liste todos os candidatos,
   mesmo os duvidosos.
   - Em comentários e docstrings, liste apenas os prescritivos, os que repetem o código e os
     divergentes — inclusive entre os duvidosos.
4. Proponha a consolidação dos documentos sobrepostos, com o destino final de cada conteúdo.
5. Mantenha apenas: o porquê de decisões, como rodar/configurar o projeto e restrições ou
   armadilhas não evidentes.
6. Se faltar algo do item 5, proponha o texto novo. Não crie documentação além disso.
7. Antes de propor remover ou mover um arquivo, verifique se alguma ferramenta o consome
   (release-please, semantic-release, pacote publicado) e se há referências a ele (links, campo
   readme do pyproject.toml/package.json, badges, CI).

Formato da entrega: no topo, a carga fixa por arquivo e o total, antes → depois da proposta;
o índice `## Contexto sob demanda` proposto; a contagem por classificação e os DIVERGENTE (são
os que pedem decisão do usuário); depois, agrupado por arquivo:

    trecho (linha ou seção) | classificação | motivo em uma linha

Entregue a lista e pare. Só edite após aprovação do usuário.

## Fase 2: execução (após aprovação)

8. Aplique apenas o que foi aprovado.
9. Adicione ao CLAUDE.md (ou AGENTS.md, o que o projeto já usar), fora do bloco do padrao, uma
   regra curta contra documentação desnecessária — se já houver uma parecida, ajuste-a em vez de
   duplicar:
   - não documentar o que o código já responde;
   - não criar CHANGELOG ou histórico;
   - toda regra nova deve vir com o porquê;
   - não engordar o `CLAUDE.md`: tema que não vale em toda sessão vai para `docs/agente/<tema>.md`
     com uma linha no índice `## Contexto sob demanda`.
10. Confira que nada quebrou: links e âncoras entre os .md, referências a arquivos removidos ou
    movidos (as do item 7) e o diff só com documentação — `git diff --stat` sem arquivo de código
    com mudança fora de comentário/docstring.
11. Confira o índice: todo `docs/agente/*.md` do projeto (menos `padrao-*`) tem linha nele, toda
    linha aponta para arquivo que existe, nenhuma usa `@`. Meça a carga fixa de novo.
12. Mostre o resultado: carga fixa antes → depois, o índice final e as conferências. Sugira ao
    usuário rodar `/doctor prompt-audit`, que acha instrução conflitante ou velha no `CLAUDE.md`,
    nas rules e nas skills.
