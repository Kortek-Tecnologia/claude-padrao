"""Cobrança do pedido no gateway de pagamento."""


class PagamentoRecusado(Exception):
    pass


def cobrar(gateway, pedido_id, valor):
    """Cobra e devolve o id da transação; recusa vira PagamentoRecusado."""
    resposta = gateway.capturar(pedido_id, valor)
    if not resposta.get("aprovado"):
        raise PagamentoRecusado(resposta.get("motivo", "sem motivo"))
    return resposta["transacao"]
