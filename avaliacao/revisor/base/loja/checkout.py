"""Fechamento do pedido: confere estoque, cobra, baixa o estoque e grava."""
from loja.estoque import EstoqueInsuficiente
from loja.pagamento import cobrar
from loja.pedidos import total


def fechar(pedido, estoque, gateway, repo):
    """Confere o estoque, cobra, baixa o estoque e grava o pedido; devolve a transação."""
    for item in pedido.itens:
        if estoque.saldo(item.sku) < item.quantidade:
            raise EstoqueInsuficiente(item.sku)
    valor = total(pedido)
    transacao = cobrar(gateway, pedido.id, valor)
    for item in pedido.itens:
        estoque.reservar(item.sku, item.quantidade)
    repo.salvar(pedido.id, pedido.dono, valor)
    return transacao
