---
name: atualizar-docs
description: Antes de commitar, acha a documentação que o diff atual deixou desatualizada — comando, porta, variável de ambiente, caminho, endpoint, chave de config, nome renomeado ou removido — e corrige só ela, no mínimo. Use quando o diff mexe em algo que docs, CLAUDE.md, comentários ou docstrings citam, ou quando o usuário pedir para conferir a doc do diff.
argument-hint: "[ref, padrão HEAD — ex.: main...HEAD]"
---

# Documentação do diff

Documentação desatualiza no commit que muda o código e não mexe nela. Esta skill fecha esse
buraco no momento barato: com o diff na mão, antes do commit. Ela corrige o que o diff tornou
falso; não melhora, não amplia e não reescreve o resto.

Diff: `git diff $ARGUMENTS` (sem argumento: `git diff HEAD` — staged e não staged). Rode até o
fim sem perguntar, salvo o caso DIVERGENTE (passo 4).

## Escopo

- Documentação = .md, docs/, CLAUDE.md/AGENTS.md, `.claude/rules/`, comentários e docstrings.
- Fora: o bloco do `CLAUDE.md` entre `<!-- padrao:inicio` e `<!-- padrao:fim -->` e os
  `docs/agente/padrao-*.md` (regravados pelo `/padrao:aplicar`), `.claude/memoria/`, `AGENT_LEARNINGS.md` (aponte em uma frase a
  entrada que o diff deixou falsa), `_audit/`, o que o `.gitignore` ignora, código de
  terceiros e gerado, e `.env*` (só nomes de variáveis, nunca valores).
- Em código, só comentários e docstrings. Arquivo que não é documentação (Dockerfile, CI,
  `.env.example`, config) também pode ter ficado para trás: aponte em uma frase, não edite.

## 1. O que o diff mudou

Do diff, liste os **termos que a documentação poderia citar** e que mudaram ou sumiram: comando
de execução, módulo de entrada, porta, variável de ambiente, caminho de arquivo, endpoint, chave
de configuração, nome de função/classe/CLI renomeado ou removido, dependência, valor padrão.
Para cada um: valor antigo → valor novo (ou `removido`), com `arquivo:linha` do diff.

Diff só de documentação, ou sem nenhum termo desses → diga isso em uma linha e encerre.

## 2. Onde a documentação cita

Procure cada valor **antigo** no escopo (`grep -rn --exclude='.env*'`, para nunca imprimir um
valor de segredo). Nos `.env*`, só nomes: `grep -no '^NOME=' .env*`. Muitos termos ou
repositório grande → delegue a busca ao `padrao:coletor`, pedindo `arquivo:linha` e o trecho.

## 3. Corrija

Para cada ocorrência, a edição mínima que deixa o trecho verdadeiro de novo: trocar o valor,
ou remover a frase se o que ela descreve deixou de existir. Regras do `/padrao:enxugar-docs`:
- não acrescente documentação do que o código já responde;
- não crie CHANGELOG nem nota de "mudou em";
- texto novo só se o diff criou o porquê de uma decisão, um jeito de rodar/configurar ou uma
  armadilha não evidente — e curto.

## 4. DIVERGENTE: não decida

Se o diff parece contradizer uma regra ou decisão documentada com porquê (ex.: a doc diz "nunca
X, porque Y" e o diff faz X), o erro pode estar no código. Não edite esse trecho: liste como
DIVERGENTE com os dois lados e siga com o resto.

## 5. Relate

Uma linha por edição: `arquivo:linha` · antes → depois · termo do diff. Depois, os DIVERGENTE
(estes pedem decisão do usuário) e os arquivos fora do escopo que ficaram para trás. Não commite.
