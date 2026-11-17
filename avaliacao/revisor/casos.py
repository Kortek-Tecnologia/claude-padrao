"""Casos da avaliação do padrao:revisor.

Cada caso é um diff sobre `base/`, com a ficha que o revisor recebe. Os de tipo
"bug" trazem UM defeito plantado e o gabarito dele: arquivo, um trecho da linha
(o `avaliar.py` acha o número) e a frase que descreve o defeito. Os de tipo
"limpo" são o controle: diff sem defeito, em que o revisor não deve acusar nada.

Operações do diff: ("troca", arquivo, antigo, novo) — `antigo` tem de existir
uma vez — e ("anexa", arquivo, texto), no fim do arquivo.

Os testes que acompanham cada diff passam, com defeito e tudo (menos onde a
ficha diz que não há teste): defeito que o teste do próprio diff pega não mede
o revisor.
"""

VERIFICACAO = "Verificação: `python -m unittest` passa."

CASOS = [
    {
        "id": "b1-paginacao",
        "tipo": "bug",
        "ficha": "Repositorio.pagina passa a validar `por_pagina`: de 1 a 100, senão ValueError. "
                 "O resto do comportamento não muda (página 1 é a primeira). " + VERIFICACAO,
        "ops": [
            ("troca", "loja/repositorio.py",
             "        inicio = (pagina - 1) * por_pagina\n",
             "        if not 1 <= por_pagina <= 100:\n"
             "            raise ValueError(\"por_pagina tem de estar entre 1 e 100\")\n"
             "        inicio = pagina * por_pagina\n"),
            ("troca", "tests/test_loja.py",
             "    def test_segunda_pagina(self):\n"
             "        self.assertEqual([linha[0] for linha in self.repo.pagina(2, por_pagina=2)], [3, 4])\n",
             "    def test_por_pagina_fora_do_limite(self):\n"
             "        with self.assertRaises(ValueError):\n"
             "            self.repo.pagina(1, por_pagina=101)\n"
             "        with self.assertRaises(ValueError):\n"
             "            self.repo.pagina(1, por_pagina=0)\n"),
        ],
        "gabarito": ("loja/repositorio.py", "inicio = pagina * por_pagina",
                     "O offset virou pagina * por_pagina: a página 1 pula os primeiros registros."),
    },
    {
        "id": "b2-permissao",
        "tipo": "bug",
        "ficha": "Novo papel `suporte` no Usuario e nova função pode_cancelar: o dono cancela o próprio "
                 "pedido; administrador ou suporte cancelam qualquer um. " + VERIFICACAO,
        "ops": [
            ("troca", "loja/pedidos.py",
             "    admin: bool = False\n",
             "    admin: bool = False\n    suporte: bool = False\n"),
            ("anexa", "loja/pedidos.py",
             "\n\ndef pode_cancelar(usuario, pedido):\n"
             "    \"\"\"O dono cancela o próprio pedido; administrador ou suporte, qualquer um.\"\"\"\n"
             "    return usuario.nome == pedido.dono or usuario.admin and usuario.suporte\n"),
            ("troca", "tests/test_loja.py",
             "from loja.pedidos import Item, Pedido, Usuario, pode_ver, subtotal, total\n",
             "from loja.pedidos import Item, Pedido, Usuario, pode_cancelar, pode_ver, subtotal, total\n"),
            ("troca", "tests/test_loja.py",
             "class EstoqueTeste(unittest.TestCase):\n",
             "class Cancelamento(unittest.TestCase):\n"
             "    def test_dono_cancela_e_estranho_nao(self):\n"
             "        pedido = pedido_de(\"ana\")\n"
             "        self.assertTrue(pode_cancelar(Usuario(\"ana\"), pedido))\n"
             "        self.assertFalse(pode_cancelar(Usuario(\"bia\"), pedido))\n"
             "\n\n"
             "class EstoqueTeste(unittest.TestCase):\n"),
        ],
        "gabarito": ("loja/pedidos.py", "usuario.admin and usuario.suporte",
                     "`and` no lugar de `or`: administrador sozinho ou suporte sozinho não conseguem cancelar."),
    },
    {
        "id": "b3-sql",
        "tipo": "bug",
        "ficha": "Nova consulta Repositorio.buscar(prefixo): pedidos cujo dono começa pelo prefixo, por id. "
                 "O prefixo vem do campo de busca da tela. " + VERIFICACAO,
        "ops": [
            ("anexa", "loja/repositorio.py",
             "\n    def buscar(self, prefixo):\n"
             "        \"\"\"Pedidos cujo dono começa por `prefixo`, por id.\"\"\"\n"
             "        return self.db.execute(\n"
             "            f\"SELECT id, dono, total FROM pedidos WHERE dono LIKE '{prefixo}%' ORDER BY id\"\n"
             "        ).fetchall()\n"),
            ("troca", "tests/test_loja.py",
             "    def test_segunda_pagina(self):\n",
             "    def test_buscar_por_prefixo(self):\n"
             "        self.assertEqual([linha[0] for linha in self.repo.buscar(\"bi\")], [2, 4])\n"
             "\n"
             "    def test_segunda_pagina(self):\n"),
        ],
        "gabarito": ("loja/repositorio.py", "LIKE '{prefixo}%'",
                     "SQL montado por f-string com entrada do usuário: injeção de SQL (as outras consultas usam `?`)."),
    },
    {
        "id": "b4-estoque",
        "tipo": "bug",
        "ficha": "Estoque.reservar passa a registrar cada reserva em `self.movimentos` (sku, quantidade). "
                 "O contrato não muda: sem saldo, levanta EstoqueInsuficiente e não mexe em nada. " + VERIFICACAO,
        "ops": [
            ("troca", "loja/estoque.py",
             "        self._saldos = dict(saldos)\n",
             "        self._saldos = dict(saldos)\n        self.movimentos = []\n"),
            ("troca", "loja/estoque.py",
             "        if quantidade > self.saldo(sku):\n"
             "            raise EstoqueInsuficiente(sku)\n"
             "        self._saldos[sku] = self.saldo(sku) - quantidade\n",
             "        self._saldos[sku] = self.saldo(sku) - quantidade\n"
             "        if self._saldos[sku] < 0:\n"
             "            raise EstoqueInsuficiente(sku)\n"
             "        self.movimentos.append((sku, quantidade))\n"),
            ("troca", "tests/test_loja.py",
             "    def test_reserva_do_saldo_inteiro(self):\n",
             "    def test_reserva_registra_movimento(self):\n"
             "        estoque = Estoque({\"caneta\": 10})\n"
             "        estoque.reservar(\"caneta\", 4)\n"
             "        self.assertEqual(estoque.movimentos, [(\"caneta\", 4)])\n"
             "\n"
             "    def test_reserva_do_saldo_inteiro(self):\n"),
        ],
        "gabarito": ("loja/estoque.py", "self._saldos[sku] = self.saldo(sku) - quantidade",
                     "O saldo é baixado antes da checagem: quando falta saldo, a exceção sobe e o saldo fica negativo."),
    },
    {
        "id": "b5-excecao",
        "tipo": "bug",
        "ficha": "cobrar ganha nova tentativa quando a rede falha (ConnectionError), até 3 vezes. Recusa do "
                 "gateway continua virando PagamentoRecusado, e qualquer outro erro continua subindo. "
                 + VERIFICACAO,
        "ops": [
            ("troca", "loja/pagamento.py",
             "    resposta = gateway.capturar(pedido_id, valor)\n",
             "    resposta = {}\n"
             "    for _ in range(3):\n"
             "        try:\n"
             "            resposta = gateway.capturar(pedido_id, valor)\n"
             "            break\n"
             "        except Exception:\n"
             "            continue\n"),
            ("troca", "tests/test_loja.py",
             "class Pagamento(unittest.TestCase):\n",
             "class Pagamento(unittest.TestCase):\n"
             "    def test_tenta_de_novo_quando_a_rede_falha(self):\n"
             "        gateway = Mock()\n"
             "        gateway.capturar.side_effect = [ConnectionError(), {\"aprovado\": True, \"transacao\": \"t9\"}]\n"
             "        self.assertEqual(cobrar(gateway, 1, Decimal(\"10\")), \"t9\")\n"
             "\n"),
        ],
        "gabarito": ("loja/pagamento.py", "except Exception:",
                     "`except Exception` engole qualquer erro, não só o de rede, e depois de três falhas "
                     "o resultado vira PagamentoRecusado(\"sem motivo\"), escondendo a causa."),
    },
    {
        "id": "b6-default-mutavel",
        "tipo": "bug",
        "ficha": "Nova função adicionar_item(pedido, item): acrescenta o item ao pedido e devolve a lista "
                 "dos skus acrescentados nesta chamada (quem chama pode passar uma lista para acumular). "
                 + VERIFICACAO,
        "ops": [
            ("anexa", "loja/pedidos.py",
             "\n\ndef adicionar_item(pedido, item, acrescentados=[]):\n"
             "    \"\"\"Acrescenta o item e devolve os skus acrescentados nesta chamada.\"\"\"\n"
             "    pedido.itens.append(item)\n"
             "    acrescentados.append(item.sku)\n"
             "    return acrescentados\n"),
            ("troca", "tests/test_loja.py",
             "from loja.pedidos import Item, Pedido, Usuario, pode_ver, subtotal, total\n",
             "from loja.pedidos import Item, Pedido, Usuario, adicionar_item, pode_ver, subtotal, total\n"),
            ("troca", "tests/test_loja.py",
             "    def test_so_dono_ou_admin_ve(self):\n",
             "    def test_adicionar_item(self):\n"
             "        pedido = pedido_de()\n"
             "        self.assertEqual(adicionar_item(pedido, Item(\"lapis\", Decimal(\"1.00\"), 2)), [\"lapis\"])\n"
             "        self.assertEqual(len(pedido.itens), 3)\n"
             "\n"
             "    def test_so_dono_ou_admin_ve(self):\n"),
        ],
        "gabarito": ("loja/pedidos.py", "acrescentados=[]",
                     "Argumento padrão mutável: a lista é a mesma entre chamadas, e a segunda devolve os skus da primeira."),
    },
    {
        "id": "b7-teste-vazio",
        "tipo": "bug",
        "ficha": "Falta teste do caminho feliz de cobrar: gateway aprova e a função devolve o id da "
                 "transação. Só teste, sem mudar código. " + VERIFICACAO,
        "ops": [
            ("troca", "tests/test_loja.py",
             "class Pagamento(unittest.TestCase):\n",
             "class Pagamento(unittest.TestCase):\n"
             "    def test_aprovado_devolve_transacao(self):\n"
             "        gateway = Mock()\n"
             "        gateway.capturar.return_value = {\"aprovado\": True, \"transacao\": \"t1\"}\n"
             "        resposta = gateway.capturar(1, Decimal(\"10\"))\n"
             "        self.assertEqual(resposta[\"transacao\"], \"t1\")\n"
             "\n"),
        ],
        "gabarito": ("tests/test_loja.py", "resposta = gateway.capturar(1, Decimal(\"10\"))",
                     "O teste nunca chama cobrar: só confere que o mock devolve o que mandaram."),
    },
    {
        "id": "b8-fuso",
        "tipo": "bug",
        "ficha": "Nova função expirado(pedido): verdadeiro quando o pedido foi criado há mais de 30 minutos. "
                 "Sem teste nesta etapa (depende de relógio; o teste vem com o relógio injetável).",
        "ops": [
            ("troca", "loja/pedidos.py",
             "from datetime import datetime, timezone\n",
             "from datetime import datetime, timedelta, timezone\n"),
            ("anexa", "loja/pedidos.py",
             "\n\ndef expirado(pedido):\n"
             "    \"\"\"Pedido criado há mais de 30 minutos.\"\"\"\n"
             "    return datetime.now() - pedido.criado_em > timedelta(minutes=30)\n"),
        ],
        "gabarito": ("loja/pedidos.py", "datetime.now() - pedido.criado_em",
                     "datetime.now() é sem fuso e criado_em tem fuso (UTC): a subtração levanta TypeError em toda chamada."),
    },
    {
        "id": "c1-renomear",
        "tipo": "limpo",
        "ficha": "Renomear subtotal para soma_dos_itens em todo o código e nos testes. Sem mudança de "
                 "comportamento. " + VERIFICACAO,
        "ops": [
            ("troca", "loja/pedidos.py", "def subtotal(pedido):\n", "def soma_dos_itens(pedido):\n"),
            ("troca", "loja/pedidos.py", "    bruto = subtotal(pedido)\n", "    bruto = soma_dos_itens(pedido)\n"),
            ("troca", "tests/test_loja.py",
             "from loja.pedidos import Item, Pedido, Usuario, pode_ver, subtotal, total\n",
             "from loja.pedidos import Item, Pedido, Usuario, pode_ver, soma_dos_itens, total\n"),
            ("troca", "tests/test_loja.py",
             "    def test_subtotal(self):\n        self.assertEqual(subtotal(pedido_de()), Decimal(\"25.00\"))\n",
             "    def test_soma_dos_itens(self):\n        self.assertEqual(soma_dos_itens(pedido_de()), Decimal(\"25.00\"))\n"),
        ],
    },
    {
        "id": "c2-campo-novo",
        "tipo": "limpo",
        "ficha": "Pedido ganha o campo opcional `observacao` (texto, vazio por padrão), com teste. "
                 + VERIFICACAO,
        "ops": [
            ("troca", "loja/pedidos.py",
             "    cupom: str = \"\"\n",
             "    cupom: str = \"\"\n    observacao: str = \"\"\n"),
            ("troca", "tests/test_loja.py",
             "    def test_so_dono_ou_admin_ve(self):\n",
             "    def test_observacao_vazia_por_padrao(self):\n"
             "        self.assertEqual(pedido_de().observacao, \"\")\n"
             "        self.assertEqual(Pedido(2, \"bia\", observacao=\"entregar à tarde\").observacao, \"entregar à tarde\")\n"
             "\n"
             "    def test_so_dono_ou_admin_ve(self):\n"),
        ],
    },
    {
        "id": "c3-extrair-funcao",
        "tipo": "limpo",
        "ficha": "Extrair de total a consulta do desconto para uma função _desconto(pedido). Sem mudança de "
                 "comportamento; os testes de total já cobrem. " + VERIFICACAO,
        "ops": [
            ("troca", "loja/pedidos.py",
             "def total(pedido):\n"
             "    bruto = subtotal(pedido)\n"
             "    desconto = CUPONS.get(pedido.cupom, Decimal(\"0\"))\n"
             "    return (bruto * (1 - desconto)).quantize(Decimal(\"0.01\"))\n",
             "def _desconto(pedido):\n"
             "    return CUPONS.get(pedido.cupom, Decimal(\"0\"))\n"
             "\n\n"
             "def total(pedido):\n"
             "    bruto = subtotal(pedido)\n"
             "    return (bruto * (1 - _desconto(pedido))).quantize(Decimal(\"0.01\"))\n"),
        ],
    },
    {
        # devolver (já existente, logo acima) aceita quantidade negativa: é defeito ANTIGO.
        # O diff não o toca; o revisor pode citá-lo à parte, mas não como achado deste diff.
        "id": "c4-defeito-antigo-ao-lado",
        "tipo": "limpo",
        "ficha": "Estoque ganha saldo_total(): a soma dos saldos de todos os skus, com teste. "
                 + VERIFICACAO,
        "ops": [
            ("anexa", "loja/estoque.py",
             "\n    def saldo_total(self):\n"
             "        \"\"\"Soma dos saldos de todos os skus.\"\"\"\n"
             "        return sum(self._saldos.values())\n"),
            ("troca", "tests/test_loja.py",
             "    def test_reserva_do_saldo_inteiro(self):\n",
             "    def test_saldo_total(self):\n"
             "        self.assertEqual(Estoque({\"caneta\": 3, \"caderno\": 2}).saldo_total(), 5)\n"
             "        self.assertEqual(Estoque({}).saldo_total(), 0)\n"
             "\n"
             "    def test_reserva_do_saldo_inteiro(self):\n"),
        ],
    },
]
