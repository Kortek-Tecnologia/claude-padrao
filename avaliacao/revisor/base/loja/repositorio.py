"""Pedidos gravados em SQLite."""


class Repositorio:
    def __init__(self, conexao):
        self.db = conexao

    def criar_tabelas(self):
        self.db.execute(
            "CREATE TABLE IF NOT EXISTS pedidos (id INTEGER PRIMARY KEY, dono TEXT NOT NULL, total TEXT NOT NULL)"
        )

    def salvar(self, pedido_id, dono, total):
        self.db.execute("INSERT INTO pedidos (id, dono, total) VALUES (?, ?, ?)", (pedido_id, dono, str(total)))

    def por_dono(self, dono):
        return self.db.execute(
            "SELECT id, dono, total FROM pedidos WHERE dono = ? ORDER BY id", (dono,)
        ).fetchall()

    def pagina(self, pagina, por_pagina=20):
        """Página 1 é a primeira; devolve até `por_pagina` pedidos, por id."""
        inicio = (pagina - 1) * por_pagina
        return self.db.execute(
            "SELECT id, dono, total FROM pedidos ORDER BY id LIMIT ? OFFSET ?", (por_pagina, inicio)
        ).fetchall()
