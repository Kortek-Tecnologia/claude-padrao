"""Pedidos da loja: itens, total com cupom e quem pode ver cada pedido."""
from dataclasses import dataclass, field
from datetime import datetime, timezone
from decimal import Decimal


@dataclass
class Usuario:
    nome: str
    admin: bool = False


@dataclass
class Item:
    sku: str
    preco: Decimal
    quantidade: int


@dataclass
class Pedido:
    id: int
    dono: str
    itens: list = field(default_factory=list)
    cupom: str = ""
    criado_em: datetime = field(default_factory=lambda: datetime.now(timezone.utc))


CUPONS = {"BEMVINDO10": Decimal("0.10"), "FRETE5": Decimal("0.05")}


def subtotal(pedido):
    return sum((item.preco * item.quantidade for item in pedido.itens), Decimal("0"))


def total(pedido):
    bruto = subtotal(pedido)
    desconto = CUPONS.get(pedido.cupom, Decimal("0"))
    return (bruto * (1 - desconto)).quantize(Decimal("0.01"))


def pode_ver(usuario, pedido):
    """Só o dono do pedido ou um administrador vê o pedido."""
    return usuario.admin or usuario.nome == pedido.dono
