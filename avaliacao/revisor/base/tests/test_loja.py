import sqlite3
import unittest
from decimal import Decimal
from unittest.mock import Mock

from loja.checkout import fechar
from loja.estoque import Estoque, EstoqueInsuficiente
from loja.pagamento import PagamentoRecusado, cobrar
from loja.pedidos import Item, Pedido, Usuario, pode_ver, subtotal, total
from loja.repositorio import Repositorio


def pedido_de(dono="ana", cupom=""):
    itens = [Item("caneta", Decimal("2.50"), 4), Item("caderno", Decimal("15.00"), 1)]
    return Pedido(1, dono, itens, cupom)


class Pedidos(unittest.TestCase):
    def test_subtotal(self):
        self.assertEqual(subtotal(pedido_de()), Decimal("25.00"))

    def test_total_com_cupom(self):
        self.assertEqual(total(pedido_de(cupom="BEMVINDO10")), Decimal("22.50"))

    def test_cupom_desconhecido_nao_desconta(self):
        self.assertEqual(total(pedido_de(cupom="NAOEXISTE")), Decimal("25.00"))

    def test_so_dono_ou_admin_ve(self):
        pedido = pedido_de("ana")
        self.assertTrue(pode_ver(Usuario("ana"), pedido))
        self.assertTrue(pode_ver(Usuario("raiz", admin=True), pedido))
        self.assertFalse(pode_ver(Usuario("bia"), pedido))


class EstoqueTeste(unittest.TestCase):
    def test_reserva_baixa_o_saldo(self):
        estoque = Estoque({"caneta": 10})
        estoque.reservar("caneta", 4)
        self.assertEqual(estoque.saldo("caneta"), 6)

    def test_reserva_do_saldo_inteiro(self):
        estoque = Estoque({"caneta": 3})
        estoque.reservar("caneta", 3)
        self.assertEqual(estoque.saldo("caneta"), 0)

    def test_sem_saldo_levanta(self):
        estoque = Estoque({"caneta": 1})
        with self.assertRaises(EstoqueInsuficiente):
            estoque.reservar("caneta", 2)


class RepositorioTeste(unittest.TestCase):
    def setUp(self):
        self.repo = Repositorio(sqlite3.connect(":memory:"))
        self.repo.criar_tabelas()
        for n in range(1, 6):
            self.repo.salvar(n, "ana" if n % 2 else "bia", Decimal(n))

    def test_por_dono(self):
        self.assertEqual([linha[0] for linha in self.repo.por_dono("ana")], [1, 3, 5])

    def test_segunda_pagina(self):
        self.assertEqual([linha[0] for linha in self.repo.pagina(2, por_pagina=2)], [3, 4])


class Pagamento(unittest.TestCase):
    def test_recusado_levanta(self):
        gateway = Mock()
        gateway.capturar.return_value = {"aprovado": False, "motivo": "saldo"}
        with self.assertRaises(PagamentoRecusado):
            cobrar(gateway, 1, Decimal("10"))


class Checkout(unittest.TestCase):
    def test_fechar_cobra_e_baixa_o_estoque(self):
        estoque = Estoque({"caneta": 10, "caderno": 2})
        gateway = Mock()
        gateway.capturar.return_value = {"aprovado": True, "transacao": "t7"}
        repo = Mock()
        self.assertEqual(fechar(pedido_de(), estoque, gateway, repo), "t7")
        self.assertEqual(estoque.saldo("caneta"), 6)
        repo.salvar.assert_called_once()


if __name__ == "__main__":
    unittest.main()
