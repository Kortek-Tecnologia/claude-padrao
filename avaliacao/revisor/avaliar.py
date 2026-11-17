#!/usr/bin/env python3
"""Avalia o padrao:revisor com defeitos plantados.

    sh scripts/py.sh avaliacao/revisor/avaliar.py --conferir
    sh scripts/py.sh avaliacao/revisor/avaliar.py --saida DIR [--casos id,id] [--paralelo N]

Para cada caso de `casos.py`: copia `base/` para uma pasta nova, faz o commit
inicial, aplica o diff do caso (sem commit) e abre uma sessão `claude -p` no
agente `padrao:revisor` deste plugin, com a ficha do lote. A resposta fecha com
uma linha `ACHADOS:`, que o script lê.

- caso "bug": acerta se a linha `ACHADOS:` cita o arquivo do defeito a até 3
  linhas dele. A frase do gabarito sai no relatório, para a pessoa conferir se
  o achado descreve o defeito (o script só confere o lugar).
- caso "limpo" (controle): acerta se a linha é `ACHADOS: nenhum`.

`--conferir` não chama o Claude nem custa nada: aplica cada diff e roda os
testes do projeto de exemplo, para garantir que os casos estão de pé.

A avaliação custa (uma sessão do Sonnet por caso) e usa o login do ambiente em
que roda: para não sujar o `~/.claude` real, rode com HOME falso e
`CLAUDE_CODE_OAUTH_TOKEN`, como no teste de ponta a ponta (docs/como-funciona.md).
Uma rodada por caso é amostra de um: repita antes de concluir sobre um caso só.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

AQUI = Path(__file__).resolve().parent
PLUGIN = AQUI.parent.parent
BASE = AQUI / "base"
TOLERANCIA = 3

PEDIDO = """Revise o diff não commitado deste repositório (`git diff HEAD`) contra a ficha do lote abaixo.

Ficha do lote:
{ficha}

Faça a sua revisão normal. Depois, feche com UMA linha neste formato exato, só com os achados que ESTE diff introduziu (o que já existia antes do diff fica fora dela), com o número da linha no arquivo como está agora:
ACHADOS: arquivo:linha; arquivo:linha
ou, se o diff não introduziu problema:
ACHADOS: nenhum
"""


def carregar_casos():
    sys.path.insert(0, str(AQUI))
    import casos  # noqa: PLC0415

    return casos.CASOS


def rodar(cmd, cwd, **kw):
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, encoding="utf-8", errors="replace", **kw)


def montar(caso, raiz: Path) -> Path:
    """Projeto do caso: base commitada + diff do caso no working tree."""
    proj = raiz / caso["id"]
    shutil.copytree(BASE, proj, ignore=shutil.ignore_patterns("__pycache__"))
    for cmd in (["git", "init", "-q", "."], ["git", "add", "-A"],
                ["git", "-c", "user.name=avaliacao", "-c", "user.email=avaliacao@exemplo.invalid",
                 "-c", "core.autocrlf=false", "commit", "-q", "-m", "loja: base"]):
        r = rodar(cmd, proj)
        if r.returncode:
            raise SystemExit(f"{caso['id']}: {' '.join(cmd)} falhou: {r.stderr}")
    for op in caso["ops"]:
        arq = proj / op[1]
        texto = arq.read_bytes().decode("utf-8")
        if op[0] == "troca":
            if texto.count(op[2]) != 1:
                raise SystemExit(f"{caso['id']}: trecho aparece {texto.count(op[2])} vez(es) em {op[1]}: {op[2][:60]!r}")
            texto = texto.replace(op[2], op[3])
        else:
            texto += op[2]
        arq.write_bytes(texto.encode("utf-8"))
    return proj


def linha_do_gabarito(caso, proj: Path) -> int:
    arquivo, trecho, _ = caso["gabarito"]
    linhas = (proj / arquivo).read_bytes().decode("utf-8").splitlines()
    achadas = [n for n, l in enumerate(linhas, 1) if trecho in l]
    if len(achadas) != 1:
        raise SystemExit(f"{caso['id']}: o trecho do gabarito aparece {len(achadas)} vez(es) em {arquivo}")
    return achadas[0]


def conferir(casos) -> int:
    """Sem Claude: cada diff aplica, o gabarito tem linha e os testes passam."""
    falhas = 0
    with tempfile.TemporaryDirectory() as tmp:
        for caso in casos:
            proj = montar(caso, Path(tmp))
            if caso["tipo"] == "bug":
                linha_do_gabarito(caso, proj)
            r = rodar([sys.executable, "-I", "-m", "unittest", "-q"], proj)
            if not rodar(["git", "diff", "--quiet", "HEAD"], proj).returncode:
                print(f"{caso['id']}: o diff saiu vazio")
                falhas += 1
            if r.returncode:
                print(f"{caso['id']}: os testes do caso falham:\n{r.stderr[-600:]}")
                falhas += 1
    print(f"casos: {len(casos)} · {sum(c['tipo'] == 'bug' for c in casos)} com defeito · "
          f"{sum(c['tipo'] == 'limpo' for c in casos)} de controle · {falhas} falha(s)")
    return 1 if falhas else 0


def achados(resposta: str):
    """A última linha `ACHADOS:` → None (sem a linha), [] (nenhum) ou [(arquivo, linha)]."""
    linhas = [l for l in resposta.splitlines() if l.strip().upper().startswith("ACHADOS:")]
    if not linhas:
        return None
    corpo = linhas[-1].split(":", 1)[1]
    return [(a.replace("\\", "/"), int(n)) for a, n in re.findall(r"([\w./\\-]+\.py):(\d+)", corpo)]


def avaliar_caso(caso, raiz: Path, saida: Path, claude: str) -> dict:
    proj = montar(caso, raiz)
    pedido = PEDIDO.format(ficha=caso["ficha"])
    r = subprocess.run(
        [claude, "-p", "--agent", "padrao:revisor", "--plugin-dir", str(PLUGIN),
         "--dangerously-skip-permissions", "--output-format", "json"],
        cwd=proj, input=pedido, capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    (saida / f"{caso['id']}.json").write_text(r.stdout or r.stderr, encoding="utf-8")
    try:
        dados = json.loads(r.stdout)
    except ValueError:
        return {"id": caso["id"], "tipo": caso["tipo"], "erro": (r.stderr or r.stdout)[-300:]}
    resposta = str(dados.get("result") or "")
    (saida / f"{caso['id']}.md").write_text(resposta, encoding="utf-8")
    lista = achados(resposta)
    res = {
        "id": caso["id"], "tipo": caso["tipo"], "achados": lista,
        "custo": dados.get("total_cost_usd") or 0, "segundos": round((dados.get("duration_ms") or 0) / 1000),
        "modelos": sorted((dados.get("modelUsage") or {}).keys()),
    }
    if lista is None:
        res["erro"] = "resposta sem a linha ACHADOS:"
    elif caso["tipo"] == "bug":
        arquivo, _, frase = caso["gabarito"]
        linha = linha_do_gabarito(caso, proj)
        res["gabarito"] = f"{arquivo}:{linha}"
        res["frase"] = frase
        res["acertou"] = any(a.endswith(arquivo) and abs(n - linha) <= TOLERANCIA for a, n in lista)
        res["a_mais"] = sum(not (a.endswith(arquivo) and abs(n - linha) <= TOLERANCIA) for a, n in lista)
    else:
        res["acertou"] = lista == []
        res["a_mais"] = len(lista)
    return res


def main() -> int:
    ap = argparse.ArgumentParser(description="Avalia o padrao:revisor com defeitos plantados.")
    ap.add_argument("--conferir", action="store_true", help="só confere os casos (sem Claude, sem custo)")
    ap.add_argument("--saida", type=Path, help="pasta para as respostas e o resultado.json")
    ap.add_argument("--casos", default="", help="ids separados por vírgula (padrão: todos)")
    ap.add_argument("--paralelo", type=int, default=4)
    args = ap.parse_args()
    for s in (sys.stdout, sys.stderr):
        s.reconfigure(encoding="utf-8")
    casos = carregar_casos()
    if args.casos:
        quer = set(args.casos.split(","))
        casos = [c for c in casos if c["id"] in quer]
    if args.conferir:
        return conferir(casos)
    if not args.saida:
        ap.error("--saida é obrigatória (ou use --conferir)")
    claude = shutil.which("claude")
    if not claude:
        raise SystemExit("claude não está no PATH")
    args.saida.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        with concurrent.futures.ThreadPoolExecutor(max(1, args.paralelo)) as pool:
            resultados = list(pool.map(lambda c: avaliar_caso(c, Path(tmp), args.saida, claude), casos))
    (args.saida / "resultado.json").write_text(json.dumps(resultados, ensure_ascii=False, indent=2), encoding="utf-8")

    for r in resultados:
        if "acertou" not in r:
            print(f"ERRO   {r['id']:<28} {r.get('erro', '')}")
            continue
        lista = "; ".join(f"{a}:{n}" for a, n in r["achados"]) or "nenhum"
        print(f"{'ok' if r['acertou'] else 'FALHOU':<6} {r['id']:<28} achados: {lista}"
              + (f"  (gabarito {r['gabarito']})" if r["tipo"] == "bug" else ""))
    bugs = [r for r in resultados if r["tipo"] == "bug" and "acertou" in r]
    limpos = [r for r in resultados if r["tipo"] == "limpo" and "acertou" in r]
    erros = sum("acertou" not in r for r in resultados)
    print(f"defeitos achados: {sum(r['acertou'] for r in bugs)} de {len(bugs)}"
          f" · achados a mais nesses diffs: {sum(r['a_mais'] for r in bugs)}")
    print(f"controles limpos: {sum(r['acertou'] for r in limpos)} de {len(limpos)}"
          f" · achados falsos: {sum(r['a_mais'] for r in limpos)}")
    custo = sum(r.get("custo", 0) for r in resultados)
    print(f"custo: US$ {custo:.2f} · modelos: {sorted({m for r in resultados for m in r.get('modelos', [])})}"
          + (f" · {erros} caso(s) com erro" if erros else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
