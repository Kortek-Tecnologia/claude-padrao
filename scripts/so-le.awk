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
# A regra olha o comando como o shell o entrega, não como foi escrito: as
# palavras sem aspas nem barra invertida (`sort "-o" f` grava como `sort -o f`).
# Comando com opção que grava ou executa (sort, uniq, file, rg, sed, awk, find,
# git) não leva substituição de comando nem variável onde ela possa virar opção
# (`sort a $(echo -o f)`, `sort $1-o f`); e o comando inteiro é negado quando
# traz forma que o corte não acompanha (SEG_RUIM, em segmentos.awk).
#
# Opção longa vale abreviada (`--outp`, `--in-pl`, `--pro`, `--op`): por isso
# cada regra casa o menor prefixo que já não é ambíguo, e não o nome inteiro.
#
# POSIX awk (gawk, mawk, busybox): sem classes [[:...:]] nem intervalo {n}.

function negar(porque) {
  # aspas, barra e caractere de controle (quebra de linha dentro de aspas, tab)
  # deixariam o JSON inválido, e recusa que não se lê não recusa
  gsub(/["\\]/, "", porque)
  gsub("[\001-\037]", " ", porque)
  printf "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"%s so le: %s\"}}\n", quem, porque
  negou = 1
  exit 0
}

# junta(CH): põe um caractere na palavra em construção. Um `-` logo depois de
# uma expansão que pode vir vazia abriria uma opção (`$1-o`): fica anotado.
function junta(ch) {
  if (PECA == "" && APOS && ch == "-") EXP_OPCAO = 1
  PAL = PAL ch; PECA = PECA ch
}

# palavras(SEG, W): as palavras do segmento como o shell as entrega ao comando —
# sem aspas nem barra invertida — e quantas são. A expansão de variável ($X,
# ${X}, $1, $@...) fica como está escrita, e EXP_OPCAO diz se alguma pode virar
# opção ou pedaço de uma: colada a um `-` (`-$X`, `--out$X`), ou seguida de `-`
# quando vier vazia ou partir a palavra (`$1-o`, `a$IFS-o`). GLOB diz se há
# curinga fora de aspas.
function palavras(s, w,    i, c, d, k, q, n, aberta) {
  n = 0; q = ""; aberta = 0; PAL = ""; PECA = ""; APOS = 0; EXP_OPCAO = 0; GLOB = 0
  for (i = 1; i <= length(s); i++) {
    c = substr(s, i, 1)
    if (c == M_GT) c = ">"
    if (q == "\047") { if (c == "\047") q = ""; else junta(c); continue }
    if (c == "\\") { i++; junta(substr(s, i, 1)); aberta = 1; continue }
    if (c == "$") {
      d = substr(s, i + 1); k = 0
      if (match(d, /^[A-Za-z_][A-Za-z0-9_]*/) || match(d, /^[{][A-Za-z_][A-Za-z0-9_]*[}]/)) k = RLENGTH
      else if (d ~ /^[0-9@*#?$!-]/) k = 1
      if (k) {
        if (PECA ~ /^-[A-Za-z0-9-]*$/) EXP_OPCAO = 1
        if (q == "") { PECA = ""; APOS = 1 } else if (PECA == "") APOS = 1
        PAL = PAL substr(s, i, k + 1); aberta = 1; i += k
        continue
      }
    }
    if (q == "\"") { if (c == "\"") q = ""; else junta(c); continue }
    if (c == "\047" || c == "\"") { q = c; aberta = 1; continue }
    if (c == " " || c == "\t" || c == "\n") {
      if (aberta) w[++n] = PAL
      PAL = ""; PECA = ""; APOS = 0; aberta = 0
      continue
    }
    if (c == "*" || c == "?" || c == "[") GLOB = 1
    junta(c); aberta = 1
  }
  if (aberta) w[++n] = PAL
  return n
}

# motivo(SEG): por que o segmento é negado, ou "" se é leitura. As regras de
# opção olham T: as palavras sem aspas e, atrás delas, o texto cru (o que casava
# antes continua casando).
function motivo(s,    w, nw, i, n, t, sub_git, grava) {
  grava = "opcao que grava arquivo ou executa programa"
  if (index(s, ">")) return "grava em arquivo (redirecionamento)"
  nw = palavras(s, w)
  if (nw == 0) return ""
  if (w[1] ~ /^(cat|grep|egrep|fgrep|head|tail|wc|ls|stat|diff|cmp|echo|printf|jq|test|\[|readlink|realpath|basename|dirname|true|false|cd|pwd|cut|tr|column|nl)$/) return ""
  if (w[1] !~ /^(sort|uniq|file|rg|sed|awk|find|git)$/) {
    if (index(w[1], M_SUB)) return "o comando viria de uma substituicao"
    return "comando fora da lista de leitura; para ler arquivo use Read/Grep/Glob"
  }
  # Daqui para baixo o comando tem opção que grava ou executa: o que o shell só
  # resolve na hora não entra onde possa virar opção.
  if (index(s, M_SUB)) return "substituicao de comando em " w[1] ", que tem opcao que grava: rode-a antes e escreva o valor (git diff A...B ja parte do merge-base)"
  if (EXP_OPCAO) return "variavel onde pode virar opcao de " w[1] ": escreva o valor"
  t = w[1]
  for (i = 2; i <= nw; i++) t = t " " w[i]
  t = t " " s
  if (w[1] == "sort") return (t ~ /[ \t](-[A-Za-z]*o|--o|--co)/) ? grava : ""
  if (w[1] == "uniq") {
    # `uniq ENTRADA SAIDA` grava SAIDA: nega com dois operandos, e com curinga
    # (`uniq [ab].txt` vira dois).
    if (GLOB) return "uniq com curinga (o segundo arquivo seria gravado)"
    n = 0
    for (i = 2; i <= nw; i++) {
      if (w[i] ~ /^-[fsw]$/) { i++; continue }
      if (w[i] !~ /^-/) n++
    }
    return (n >= 2) ? grava : ""
  }
  if (w[1] == "file") return (t ~ /[ \t](-[A-Za-z]*C|--co)/) ? grava : ""
  # --hostname-bin roda o programa dado para descobrir o host.
  if (w[1] == "rg") return (t ~ /--pre|--hostname-bin/) ? grava : ""
  # sed e awk são linguagens: filtro de texto não fecha (s|a|b|e executa com
  # qualquer delimitador, o gawk chama system() por @f). Só passam com
  # --sandbox logo após o nome — antes de um `--`, que o tornaria nome de
  # arquivo —, que recusa e/r/w no sed e system, redirecionamento e extensão
  # no gawk. O mawk não tem --sandbox: falha, e fica fechado.
  if (w[1] == "sed") {
    if (w[2] != "--sandbox") return "sed e awk so com --sandbox logo apos o nome"
    # o --sandbox não impede -i (grava no lugar)
    return (t ~ /[ \t](-[A-Za-z]*i|--i)/) ? grava : ""
  }
  if (w[1] == "awk") {
    if (w[2] != "--sandbox") return "sed e awk so com --sandbox logo apos o nome"
    # o --sandbox não impede -d/-p/-o (gravam variáveis, perfil e programa em
    # arquivo) nem o depurador (-D)
    return (t ~ /[ \t](-[A-Za-z]*[dDpo]|--d|--pr)/) ? grava : ""
  }
  if (w[1] == "find") return (t ~ /-(exec|execdir|ok|okdir|delete|fprint|fls)/) ? grava : ""
  # Só resta o git. -c/--config-env mudam config na hora (core.fsmonitor,
  # diff.external executam programa); --git-dir/--work-tree apontariam para um
  # repositório com config de fora.
  if (t ~ /--output|--open-files-in-pager|--config-env|--exec-path|--ext-diff|--git-dir|--work-tree/) return grava
  # -O/--open-files-in-pager do grep executam: o `-O` também colado a outras
  # opções curtas (`-nO./prog`) e a forma abreviada (`--op=./prog`).
  if (t ~ /[ \t](-c([ \t]|$)|-[A-Za-z0-9]*O|--op|--outp)/) return grava
  sub_git = ""
  for (i = 2; i <= nw; i++) {
    if (w[i] == "-C") { i++; continue }
    if (w[i] ~ /^-/) continue
    sub_git = w[i]; break
  }
  if (sub_git ~ /^(log|show|diff|blame|grep|status|ls-files|ls-tree|rev-parse|rev-list|cat-file|shortlog|merge-base|name-rev|describe)$/) return ""
  return "git so com subcomando de leitura (log, show, diff, status, grep...)"
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
  if (SEG_RUIM != "") negar("forma que a trava nao acompanha: " SEG_RUIM)
  for (k = 1; k <= total; k++) {
    if (seg[k] == "") continue
    m = motivo(seg[k])
    if (m != "") {
      limpo = seg[k]
      gsub(M_SUB, "$(...)", limpo); gsub(M_GT, ">", limpo); gsub(/["\\]/, "", limpo); sub(/^[ \t]+/, "", limpo)
      negar(m ": " substr(limpo, 1, 80))
    }
  }
}
