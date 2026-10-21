---
name: executar-lote
description: Executa um lote do _audit/PLANO.md gerado pelo /padrao:auditar — o padrao:executor aplica, o padrao:revisor confere, você roda a condição de saída e só então marca os ids como resolvido em _audit/PENDENCIAS.md. Não commita.
argument-hint: <número do lote>
disable-model-invocation: true
---

# Executar um lote do plano

Lote pedido: **$ARGUMENTS**

O lote já vem decidido no `PLANO.md`: executar é do `padrao:executor`, conferir é seu. Chame
os agentes **sem** `model` — o modelo vem do frontmatter deles, e o parâmetro na chamada o
sobrepõe. Um id só vira
`resolvido` depois que a condição de saída rodou de verdade — o `/goal` dizer que terminou não
basta. Rode até o fim sem perguntar; as únicas paradas são as de "Pare se".

## 1. Leia e confira (só leitura)

- `_audit/PLANO.md` e `_audit/PENDENCIAS.md` existem e terminam em `<!-- COMPLETO -->`.
- A ficha do lote $ARGUMENTS: o `/goal`, os ids que resolve, os que aguardam DUVIDAS, o que muda,
  as dependências.
- Dependências: os ids dos lotes de que este depende estão `resolvido` em `PENDENCIAS.md`.
- `git status --short`: anote o estado antes. Arquivos que o lote vai mexer não podem ter
  alteração sem commit — o diff do lote se misturaria com trabalho seu.

**Pare se** (diga o motivo em uma frase e o que fazer): sem número de lote ou lote inexistente;
`_audit/` incompleto (rode `/padrao:auditar`); dependência não resolvida, e a ficha não traz
alternativa para rodar sem ela; arquivo do lote com alteração sem commit; todos os ids do lote já
`resolvido`.

## 2. Execute — `padrao:executor`

Passe ao executor o `/goal` inteiro e a ficha, com estas regras acima das do `/goal`:
- não edite nada em `_audit/` — quem marca `resolvido` é você, depois de verificar; ignore a
  instrução do `/goal` de mudar o status;
- não toque nos ids que aguardam DUVIDAS nem em nada fora do que a ficha diz que muda;
- não commite, não faça push, não instale dependência global;
- rode a verificação do `/goal` e devolva a saída real; se uma decisão não estiver no `/goal`,
  pare e devolva a pergunta em vez de decidir.

Se o executor devolver uma pergunta: responda com o que estiver na ficha, em `SISTEMA.md` ou
`INFRA.md`; se não estiver em lugar nenhum, a resposta é a opção que muda menos o repositório —
registre a escolha no relatório final.

## 3. Revise — `padrao:revisor`

Passe ao revisor o `git diff` do lote (só os arquivos do lote), a ficha e a condição de saída.
Peça achados com `arquivo:linha`: o que fugiu da ficha, o que quebrou, o que ficou faltando.

Achado real → devolva ao MESMO executor, só aquele ponto, com `SendMessage` (para o id ou nome
dele): ele já tem o contexto e não relê os arquivos. Abra um executor novo só se não der para
retomar. O mesmo vale se ele parar no teto de turnos (saída parcial): retome-o. No máximo duas voltas executor → revisor;
depois disso, o que sobrar vai para o relatório como pendente, sem marcar o id.

## 4. Verifique — você

Rode cada verificação da condição de saída do `/goal` (grep, existência de arquivo, teste, build),
menos a de status em `PENDENCIAS.md`, e guarde a saída real. Comando que este ambiente não tem
(ex.: `docker` ausente) = `não verificado`, nunca `passou`.

Marque `resolvido` em `_audit/PENDENCIAS.md` só os ids cuja parte da condição de saída passou.
Id com verificação falha ou `não verificado` fica `aberto`. Mude só a coluna status.

## 5. Relate

- ids marcados `resolvido` e ids que ficaram `aberto`, cada um com o motivo em uma linha;
- cada verificação da condição de saída: comando → passou / falhou (saída) / não verificado;
- `git diff --stat` e o `git status --short` de antes e depois;
- escolhas feitas no lugar de uma pergunta do executor;
- o que vem a seguir: o próximo lote pela ordem do plano, ou o que destrava os ids `aberto`.

Não commite: o commit é do usuário.
