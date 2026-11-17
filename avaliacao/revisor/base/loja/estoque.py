"""Saldo de estoque por sku, em memória."""


class EstoqueInsuficiente(Exception):
    pass


class Estoque:
    def __init__(self, saldos):
        self._saldos = dict(saldos)

    def saldo(self, sku):
        return self._saldos.get(sku, 0)

    def reservar(self, sku, quantidade):
        """Baixa a quantidade do saldo; sem saldo, levanta e não mexe em nada."""
        if quantidade <= 0:
            raise ValueError("quantidade tem de ser positiva")
        if quantidade > self.saldo(sku):
            raise EstoqueInsuficiente(sku)
        self._saldos[sku] = self.saldo(sku) - quantidade

    def devolver(self, sku, quantidade):
        self._saldos[sku] = self.saldo(sku) + quantidade
