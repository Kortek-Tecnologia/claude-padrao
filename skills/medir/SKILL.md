---
name: medir
description: Mede se a política de modelos pegou — chamadas de subagent por tipo × modelo, recusas do hook e turnos por modelo, dos transcripts locais deste projeto.
disable-model-invocation: true
---

# Medir o uso de modelos

Rode do diretório do projeto (`<plugin>` = dois níveis acima desta skill; o `py.sh` acha
`python3`/`python`/`py`, no Windows e no Linux):

    sh <plugin>/scripts/py.sh <diretório desta skill>/medir-modelos.py --dias 14

Leitura:
- `haiku` em zero com sessões longas = coleta feita pelo Opus ou pelo Sonnet.
- Sessão sem delegação não é falha: tarefa que se resolve em poucas chamadas não deve delegar.
  Preocupa a sessão longa, de muitos turnos de Opus, sem nenhuma.
- `(sem model)` = rodou no `CLAUDE_CODE_SUBAGENT_MODEL` (sonnet), salvo `Explore`/`Plan`, que o
  hook corrige. `(frontmatter)` = agente de plugin (`padrao:coletor` etc.) com o modelo no
  arquivo. O modelo real de cada um aparece em "turnos dos subagents".
- Os transcripts duram o `cleanupPeriodDays` do padrão (14 dias): `--dias` maior não acha mais.
  O número é desta máquina (os transcripts são locais).
