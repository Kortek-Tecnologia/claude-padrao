# A decisão da trava de SÓ-LEITURA, num processo só (antes eram uns 20 por
# comando: no Windows cada um custa de 100 a 800 ms, e o hook estourava o tempo).
# Roda junto de segmentos.awk:  awk -f segmentos.awk -f so-le.awk
#
# Entrada: o comando do Bash. Com -v cab=1 (trava-leitura.sh), as duas primeiras
# linhas são o `agent_type` e o `tool_name` da chamada, e -v so_leem traz os
# agentes que só leem (regex): fora deles, silêncio; neles, ferramenta que não é
# o Bash é negada inteira. -v quem é o nome do agente na mensagem.
#
# Regra: FECHADA POR PADRÃO, por segmento. Cada segmento precisa começar por um
# leitor conhecido (git só com subcomando de leitura) e não redirecionar para
# arquivo; qualquer outra forma é NEGADA. Silêncio = segue.
#
# Opção longa vale abreviada (`--outp`, `--in-pl`, `--pro`, `--op`): por isso
# cada regra casa o menor prefixo que já não é ambíguo, e não o nome inteiro.
#
# POSIX awk (gawk, mawk, busybox): sem classes [[:...:]] nem intervalo {n}.

function negar(motivo) {
  gsub(/["\\]/, "", motivo)
  printf "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"%s so le: %s\"}}\n", quem, motivo
  negou = 1
  exit 0
}

# motivo(SEG): por que o segmento é negado, ou "" se é leitura.
function motivo(s,    w, nw, i, n, sub_git, grava) {
  grava = "opcao que grava arquivo ou executa programa"
  if (index(s, ">")) return "grava em arquivo (redirecionamento)"
  nw = split(s, w, " ")
  if (nw == 0) return ""
  if (w[1] ~ /^(cat|grep|egrep|fgrep|head|tail|wc|ls|stat|diff|cmp|echo|printf|jq|test|\[|readlink|realpath|basename|dirname|true|false|cd|pwd|cut|tr|column|nl)$/) return ""
  if (w[1] == "sort") return (s ~ /[ \t](-[A-Za-z]*o|--o|--co)/) ? grava : ""
  if (w[1] == "uniq") {
    # `uniq ENTRADA SAIDA` grava SAIDA: nega com dois operandos.
    n = 0
    for (i = 2; i <= nw; i++) {
      if (w[i] ~ /^-[fsw]$/) { i++; continue }
      if (w[i] !~ /^-/) n++
    }
    return (n >= 2) ? grava : ""
  }
  if (w[1] == "file") return (s ~ /[ \t](-[A-Za-z]*C|--co)/) ? grava : ""
  # --hostname-bin roda o programa dado para descobrir o host.
  if (w[1] == "rg") return (s ~ /--pre|--hostname-bin/) ? grava : ""
  # sed e awk são linguagens: filtro de texto não fecha (s|a|b|e executa com
  # qualquer delimitador, o gawk chama system() por @f). Só passam com
  # --sandbox logo após o nome — antes de um `--`, que o tornaria nome de
  # arquivo —, que recusa e/r/w no sed e system, redirecionamento e extensão
  # no gawk. O mawk não tem --sandbox: falha, e fica fechado.
  if (w[1] == "sed") {
    if (substr(s, 1, 14) != "sed --sandbox ") return "sed e awk so com --sandbox logo apos o nome"
    # o --sandbox não impede -i (grava no lugar)
    return (s ~ /[ \t](-[A-Za-z]*i|--i)/) ? grava : ""
  }
  if (w[1] == "awk") {
    if (substr(s, 1, 14) != "awk --sandbox ") return "sed e awk so com --sandbox logo apos o nome"
    # o --sandbox não impede -d/-p/-o (gravam variáveis, perfil e programa em
    # arquivo) nem o depurador (-D)
    return (s ~ /[ \t](-[A-Za-z]*[dDpo]|--d|--pr)/) ? grava : ""
  }
  if (w[1] == "find") return (s ~ /-(exec|execdir|ok|okdir|delete|fprint|fls)/) ? grava : ""
  if (w[1] == "git") {
    # -c/--config-env mudam config na hora (core.fsmonitor, diff.external
    # executam programa); --git-dir/--work-tree apontariam para um repositório
    # com config de fora.
    if (s ~ /--output|--open-files-in-pager|--config-env|--exec-path|--ext-diff|--git-dir|--work-tree/) return grava
    # -O/--open-files-in-pager do grep executam: o `-O` também colado a outras
    # opções curtas (`-nO./prog`) e a forma abreviada (`--op=./prog`).
    if (s ~ /[ \t](-c([ \t]|$)|-[A-Za-z0-9]*O|--op|--outp)/) return grava
    sub_git = ""
    for (i = 2; i <= nw; i++) {
      if (w[i] == "-C") { i++; continue }
      if (w[i] ~ /^-/) continue
      sub_git = w[i]; break
    }
    if (sub_git ~ /^(log|show|diff|blame|grep|status|ls-files|ls-tree|rev-parse|rev-list|cat-file|shortlog|merge-base|name-rev|describe)$/) return ""
    return "git so com subcomando de leitura (log, show, diff, status, grep...)"
  }
  return "comando fora da lista de leitura; para ler arquivo use Read/Grep/Glob"
}

{ sub(/\r$/, "") }          # o jq do Windows termina a linha em CRLF
cab && NR == 1 { tipo = $0; next }
cab && NR == 2 { ferramenta = $0; next }
{ comando = comando $0 "\n" }

END {
  if (negou) exit 0
  if (quem == "") quem = "subagent"
  if (cab) {
    if (tipo !~ ("^(" so_leem ")$")) exit 0
    quem = tipo
    if (ferramenta != "Bash") negar(ferramenta " fechado. Use Read/Grep/Glob ou Bash de leitura.")
  }
  if (comando ~ /^\n*$/) exit 0
  total = segmentar(comando, seg)
  for (k = 1; k <= total; k++) {
    if (seg[k] == "") continue
    m = motivo(seg[k])
    if (m != "") { limpo = seg[k]; gsub(/["\\]/, "", limpo); negar(m ": " substr(limpo, 1, 80)) }
  }
}
