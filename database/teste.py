import sqlite3

c = sqlite3.connect("assistencia.db")
c.execute("PRAGMA foreign_keys = ON")

c.execute("INSERT INTO clientes (nome, telefone) VALUES ('Teste', '000')")
c.execute("INSERT INTO equipamentos (cliente_id, nome) VALUES (1, 'Notebook Dell')")
c.execute("INSERT INTO ordens_servico (equipamento_id, problema_relatado) VALUES (1, 'Não liga')")

# vincula 2 fontes à OS: o estoque deve cair de 5 para 3
c.execute("INSERT INTO os_pecas (os_id, peca_id, quantidade, valor_unitario) VALUES (1, 1, 2, 250)")
print("estoque após baixa:", c.execute(
    "SELECT estoque FROM pecas WHERE id = 1").fetchone())

# pede 10 fontes: deve falhar com 'estoque insuficiente'
try:
    c.execute(
        "INSERT INTO os_pecas (os_id, peca_id, quantidade, valor_unitario) VALUES (1, 1, 10, 250)")
except sqlite3.DatabaseError as e:
    print("bloqueio ok:", e)

# muda o status: deve gerar histórico
c.execute("UPDATE ordens_servico SET status = 'em_manutencao' WHERE id = 1")
print("histórico:", c.execute(
    "SELECT status_anterior, status_novo FROM historico_os").fetchall())

c.rollback()  # desfaz tudo, o banco continua limpo
print("rollback feito")
