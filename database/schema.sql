-- =====================================================================
-- SISTEMA DE ASSISTENCIA TECNICA - BANCO DE DADOS (SQLite)
-- Como rodar:  sqlite3 assistencia.db < schema.sql
-- =====================================================================
PRAGMA foreign_keys = ON;

-- ---------------------------------------------------------------------
-- LIMPEZA (permite rodar o script de novo durante o desenvolvimento)
-- ---------------------------------------------------------------------
DROP VIEW    IF EXISTS vw_dashboard;
DROP VIEW    IF EXISTS vw_os_detalhada;
DROP VIEW    IF EXISTS vw_estoque_baixo;
DROP VIEW    IF EXISTS vw_faturamento_mensal;
DROP TRIGGER IF EXISTS trg_os_pecas_baixa_estoque;
DROP TRIGGER IF EXISTS trg_os_pecas_devolve_estoque;
DROP TRIGGER IF EXISTS trg_venda_itens_baixa_estoque;
DROP TRIGGER IF EXISTS trg_os_historico_status;
DROP TRIGGER IF EXISTS trg_os_atualizado_em;
DROP TABLE   IF EXISTS logs_sistema;
DROP TABLE   IF EXISTS historico_os;
DROP TABLE   IF EXISTS pagamentos;
DROP TABLE   IF EXISTS venda_itens;
DROP TABLE   IF EXISTS vendas;
DROP TABLE   IF EXISTS os_pecas;
DROP TABLE   IF EXISTS os_servicos;
DROP TABLE   IF EXISTS ordens_servico;
DROP TABLE   IF EXISTS movimentacoes_estoque;
DROP TABLE   IF EXISTS servicos;
DROP TABLE   IF EXISTS pecas;
DROP TABLE   IF EXISTS categorias;
DROP TABLE   IF EXISTS equipamentos;
DROP TABLE   IF EXISTS clientes;
DROP TABLE   IF EXISTS funcionarios;
DROP TABLE   IF EXISTS usuarios;
DROP TABLE   IF EXISTS perfis;

-- =====================================================================
-- 1. USUARIOS E PERMISSOES
-- =====================================================================
CREATE TABLE perfis (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    nome        TEXT NOT NULL UNIQUE,            -- admin, tecnico, atendente
    descricao   TEXT
);

-- Compativel com o model Usuario do Flask (perfil como texto)
CREATE TABLE usuarios (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    nome        TEXT NOT NULL,
    email       TEXT NOT NULL UNIQUE,
    senha       TEXT NOT NULL,                   -- hash bcrypt, nunca texto puro
    perfil      TEXT NOT NULL DEFAULT 'funcionario'
                CHECK (perfil IN ('admin','tecnico','funcionario')),
    ativo       INTEGER NOT NULL DEFAULT 1 CHECK (ativo IN (0,1)),
    criado_em   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE funcionarios (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    usuario_id    INTEGER UNIQUE,
    nome          TEXT NOT NULL,
    cpf           TEXT UNIQUE,
    telefone      TEXT,
    cargo         TEXT NOT NULL DEFAULT 'tecnico',
    data_admissao DATE,
    ativo         INTEGER NOT NULL DEFAULT 1 CHECK (ativo IN (0,1)),
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE SET NULL
);

-- =====================================================================
-- 2. CLIENTES E EQUIPAMENTOS
-- =====================================================================
CREATE TABLE clientes (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    nome          TEXT NOT NULL,
    email         TEXT UNIQUE,
    telefone      TEXT UNIQUE,
    cpf_cnpj      TEXT UNIQUE,
    endereco      TEXT,
    data_criacao  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE equipamentos (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    cliente_id    INTEGER NOT NULL,
    tipo          TEXT,                          -- notebook, desktop, celular...
    nome          TEXT NOT NULL,                 -- ex: Notebook Dell
    marca         TEXT,
    modelo        TEXT,
    numero_serie  TEXT,
    descricao     TEXT,
    data_criacao  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (cliente_id) REFERENCES clientes(id) ON DELETE RESTRICT
);

-- =====================================================================
-- 3. PRODUTOS / PECAS / SERVICOS / ESTOQUE
-- =====================================================================
CREATE TABLE categorias (
    id    INTEGER PRIMARY KEY AUTOINCREMENT,
    nome  TEXT NOT NULL UNIQUE
);

CREATE TABLE pecas (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    categoria_id   INTEGER,
    nome           TEXT NOT NULL,
    descricao      TEXT,
    preco          REAL NOT NULL CHECK (preco >= 0),      -- preco de venda
    custo          REAL NOT NULL DEFAULT 0 CHECK (custo >= 0),
    estoque        INTEGER NOT NULL DEFAULT 0 CHECK (estoque >= 0),
    estoque_minimo INTEGER NOT NULL DEFAULT 1,
    ativo          INTEGER NOT NULL DEFAULT 1 CHECK (ativo IN (0,1)),
    data_criacao   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (categoria_id) REFERENCES categorias(id) ON DELETE SET NULL
);

CREATE TABLE servicos (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    nome        TEXT NOT NULL UNIQUE,
    descricao   TEXT,
    preco       REAL NOT NULL CHECK (preco >= 0),
    ativo       INTEGER NOT NULL DEFAULT 1 CHECK (ativo IN (0,1))
);

CREATE TABLE movimentacoes_estoque (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    peca_id      INTEGER NOT NULL,
    tipo         TEXT NOT NULL CHECK (tipo IN ('entrada','saida','ajuste')),
    quantidade   INTEGER NOT NULL CHECK (quantidade > 0),
    origem       TEXT,                           -- 'os', 'venda', 'compra', 'manual'
    origem_id    INTEGER,
    usuario_id   INTEGER,
    criado_em    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (peca_id)    REFERENCES pecas(id)    ON DELETE RESTRICT,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE SET NULL
);

-- =====================================================================
-- 4. ORDENS DE SERVICO
-- Mantem os campos do model OrdemServico do Flask (peca_id, valor, pago)
-- e adiciona as tabelas de itens para varias pecas/servicos por OS.
-- =====================================================================
CREATE TABLE ordens_servico (
    id                 INTEGER PRIMARY KEY AUTOINCREMENT,
    equipamento_id     INTEGER NOT NULL,
    tecnico_id         INTEGER,                  -- funcionario responsavel
    problema_relatado  TEXT,
    diagnostico        TEXT,
    status             TEXT NOT NULL DEFAULT 'aguardando_diagnostico'
                       CHECK (status IN ('aguardando_diagnostico','em_manutencao',
                                         'aguardando_peca','concluido','entregue','cancelado')),
    peca_id            INTEGER,                  -- peca principal (compat. com API atual)
    valor              REAL DEFAULT 0 CHECK (valor >= 0),
    pago               INTEGER NOT NULL DEFAULT 0 CHECK (pago IN (0,1)),
    categoria_ia       TEXT,                     -- preenchido pela IA (hardware/software/...)
    prioridade_ia      TEXT,                     -- baixa/media/alta
    criado_em          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    concluido_em       DATETIME,
    FOREIGN KEY (equipamento_id) REFERENCES equipamentos(id) ON DELETE RESTRICT,
    FOREIGN KEY (tecnico_id)     REFERENCES funcionarios(id) ON DELETE SET NULL,
    FOREIGN KEY (peca_id)        REFERENCES pecas(id)        ON DELETE SET NULL
);

CREATE TABLE os_servicos (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    os_id       INTEGER NOT NULL,
    servico_id  INTEGER NOT NULL,
    valor       REAL NOT NULL CHECK (valor >= 0),
    FOREIGN KEY (os_id)      REFERENCES ordens_servico(id) ON DELETE CASCADE,
    FOREIGN KEY (servico_id) REFERENCES servicos(id)       ON DELETE RESTRICT
);

CREATE TABLE os_pecas (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    os_id           INTEGER NOT NULL,
    peca_id         INTEGER NOT NULL,
    quantidade      INTEGER NOT NULL DEFAULT 1 CHECK (quantidade > 0),
    valor_unitario  REAL NOT NULL CHECK (valor_unitario >= 0),
    FOREIGN KEY (os_id)   REFERENCES ordens_servico(id) ON DELETE CASCADE,
    FOREIGN KEY (peca_id) REFERENCES pecas(id)          ON DELETE RESTRICT
);

-- =====================================================================
-- 5. VENDAS (balcao, sem OS)
-- =====================================================================
CREATE TABLE vendas (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    cliente_id  INTEGER,
    usuario_id  INTEGER,
    total       REAL NOT NULL DEFAULT 0 CHECK (total >= 0),
    criado_em   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (cliente_id) REFERENCES clientes(id) ON DELETE SET NULL,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE SET NULL
);

CREATE TABLE venda_itens (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    venda_id        INTEGER NOT NULL,
    peca_id         INTEGER NOT NULL,
    quantidade      INTEGER NOT NULL CHECK (quantidade > 0),
    valor_unitario  REAL NOT NULL CHECK (valor_unitario >= 0),
    FOREIGN KEY (venda_id) REFERENCES vendas(id) ON DELETE CASCADE,
    FOREIGN KEY (peca_id)  REFERENCES pecas(id)  ON DELETE RESTRICT
);

-- =====================================================================
-- 6. PAGAMENTOS (de OS ou de venda)
-- =====================================================================
CREATE TABLE pagamentos (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    os_id       INTEGER,
    venda_id    INTEGER,
    valor       REAL NOT NULL CHECK (valor > 0),
    forma       TEXT NOT NULL CHECK (forma IN ('dinheiro','pix','credito','debito','boleto')),
    pago_em     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK ((os_id IS NOT NULL AND venda_id IS NULL) OR (os_id IS NULL AND venda_id IS NOT NULL)),
    FOREIGN KEY (os_id)    REFERENCES ordens_servico(id) ON DELETE RESTRICT,
    FOREIGN KEY (venda_id) REFERENCES vendas(id)         ON DELETE RESTRICT
);

-- =====================================================================
-- 7. HISTORICO E LOGS
-- =====================================================================
CREATE TABLE historico_os (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    os_id            INTEGER NOT NULL,
    status_anterior  TEXT,
    status_novo      TEXT NOT NULL,
    usuario_id       INTEGER,
    observacao       TEXT,
    criado_em        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (os_id)      REFERENCES ordens_servico(id) ON DELETE CASCADE,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id)       ON DELETE SET NULL
);

CREATE TABLE logs_sistema (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    usuario_id  INTEGER,
    acao        TEXT NOT NULL,                  -- ex: 'LOGIN', 'CRIOU_OS', 'DELETOU_CLIENTE'
    detalhes    TEXT,
    criado_em   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE SET NULL
);

-- =====================================================================
-- INDICES
-- =====================================================================
CREATE INDEX idx_equipamentos_cliente ON equipamentos(cliente_id);
CREATE INDEX idx_os_equipamento       ON ordens_servico(equipamento_id);
CREATE INDEX idx_os_status            ON ordens_servico(status);
CREATE INDEX idx_os_tecnico           ON ordens_servico(tecnico_id);
CREATE INDEX idx_os_criado            ON ordens_servico(criado_em);
CREATE INDEX idx_os_pecas_os          ON os_pecas(os_id);
CREATE INDEX idx_os_servicos_os       ON os_servicos(os_id);
CREATE INDEX idx_venda_itens_venda    ON venda_itens(venda_id);
CREATE INDEX idx_mov_peca             ON movimentacoes_estoque(peca_id);
CREATE INDEX idx_historico_os         ON historico_os(os_id);
CREATE INDEX idx_pagamentos_os        ON pagamentos(os_id);

-- =====================================================================
-- TRIGGERS (regras de negocio no proprio banco)
-- =====================================================================

-- Baixa de estoque ao adicionar peca na OS (bloqueia se nao tiver saldo)
CREATE TRIGGER trg_os_pecas_baixa_estoque
BEFORE INSERT ON os_pecas
FOR EACH ROW
WHEN (SELECT estoque FROM pecas WHERE id = NEW.peca_id) < NEW.quantidade
BEGIN
    SELECT RAISE(ABORT, 'estoque insuficiente');
END;

CREATE TRIGGER trg_os_pecas_baixa_estoque_ok
AFTER INSERT ON os_pecas
FOR EACH ROW
BEGIN
    UPDATE pecas SET estoque = estoque - NEW.quantidade WHERE id = NEW.peca_id;
    INSERT INTO movimentacoes_estoque (peca_id, tipo, quantidade, origem, origem_id)
    VALUES (NEW.peca_id, 'saida', NEW.quantidade, 'os', NEW.os_id);
END;

-- Devolve ao estoque quando a peca e removida da OS
CREATE TRIGGER trg_os_pecas_devolve_estoque
AFTER DELETE ON os_pecas
FOR EACH ROW
BEGIN
    UPDATE pecas SET estoque = estoque + OLD.quantidade WHERE id = OLD.peca_id;
    INSERT INTO movimentacoes_estoque (peca_id, tipo, quantidade, origem, origem_id)
    VALUES (OLD.peca_id, 'entrada', OLD.quantidade, 'os', OLD.os_id);
END;

-- Baixa de estoque em venda de balcao
CREATE TRIGGER trg_venda_itens_baixa_estoque
BEFORE INSERT ON venda_itens
FOR EACH ROW
WHEN (SELECT estoque FROM pecas WHERE id = NEW.peca_id) < NEW.quantidade
BEGIN
    SELECT RAISE(ABORT, 'estoque insuficiente');
END;

CREATE TRIGGER trg_venda_itens_baixa_estoque_ok
AFTER INSERT ON venda_itens
FOR EACH ROW
BEGIN
    UPDATE pecas SET estoque = estoque - NEW.quantidade WHERE id = NEW.peca_id;
    INSERT INTO movimentacoes_estoque (peca_id, tipo, quantidade, origem, origem_id)
    VALUES (NEW.peca_id, 'saida', NEW.quantidade, 'venda', NEW.venda_id);
END;

-- Historico automatico de mudanca de status da OS
CREATE TRIGGER trg_os_historico_status
AFTER UPDATE OF status ON ordens_servico
FOR EACH ROW
WHEN OLD.status <> NEW.status
BEGIN
    INSERT INTO historico_os (os_id, status_anterior, status_novo)
    VALUES (NEW.id, OLD.status, NEW.status);
    UPDATE ordens_servico
       SET concluido_em = CASE WHEN NEW.status = 'concluido' THEN CURRENT_TIMESTAMP ELSE concluido_em END
     WHERE id = NEW.id;
END;

-- Registra o status inicial da OS
CREATE TRIGGER trg_os_historico_criacao
AFTER INSERT ON ordens_servico
FOR EACH ROW
BEGIN
    INSERT INTO historico_os (os_id, status_anterior, status_novo, observacao)
    VALUES (NEW.id, NULL, NEW.status, 'OS criada');
END;

-- Atualiza atualizado_em em qualquer alteracao
CREATE TRIGGER trg_os_atualizado_em
AFTER UPDATE ON ordens_servico
FOR EACH ROW
WHEN NEW.atualizado_em = OLD.atualizado_em
BEGIN
    UPDATE ordens_servico SET atualizado_em = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- =====================================================================
-- VIEWS (alimentam dashboard e relatorios)
-- =====================================================================
CREATE VIEW vw_os_detalhada AS
SELECT  os.id                AS os_id,
        c.nome               AS cliente,
        c.telefone           AS telefone,
        e.nome               AS equipamento,
        os.problema_relatado AS problema,
        os.diagnostico       AS diagnostico,
        os.status            AS status,
        f.nome               AS tecnico,
        os.valor             AS valor,
        os.pago              AS pago,
        os.criado_em         AS aberta_em,
        os.concluido_em      AS concluida_em
FROM ordens_servico os
JOIN equipamentos e ON e.id = os.equipamento_id
JOIN clientes c     ON c.id = e.cliente_id
LEFT JOIN funcionarios f ON f.id = os.tecnico_id;

CREATE VIEW vw_estoque_baixo AS
SELECT id, nome, estoque, estoque_minimo
FROM pecas
WHERE ativo = 1 AND estoque <= estoque_minimo;

CREATE VIEW vw_faturamento_mensal AS
SELECT strftime('%Y-%m', pago_em) AS mes,
       SUM(valor)                 AS total
FROM pagamentos
GROUP BY strftime('%Y-%m', pago_em);

CREATE VIEW vw_dashboard AS
SELECT
    (SELECT COUNT(*) FROM ordens_servico WHERE status NOT IN ('concluido','entregue','cancelado')) AS os_abertas,
    (SELECT COUNT(*) FROM ordens_servico WHERE status = 'aguardando_diagnostico')                  AS os_aguardando_diagnostico,
    (SELECT COUNT(*) FROM ordens_servico WHERE status = 'em_manutencao')                           AS os_em_manutencao,
    (SELECT COUNT(*) FROM ordens_servico WHERE status = 'aguardando_peca')                         AS os_aguardando_peca,
    (SELECT COUNT(*) FROM ordens_servico WHERE status = 'concluido')                               AS os_concluidas,
    (SELECT COUNT(*) FROM clientes)                                                                AS total_clientes,
    (SELECT COUNT(*) FROM vw_estoque_baixo)                                                        AS pecas_estoque_baixo,
    (SELECT COALESCE(SUM(valor),0) FROM pagamentos
      WHERE strftime('%Y-%m', pago_em) = strftime('%Y-%m','now'))                                  AS faturamento_mes;

-- =====================================================================
-- DADOS INICIAIS
-- (a senha abaixo e so placeholder; crie usuarios reais pela rota
--  /api/auth/registrar para o hash bcrypt ser gerado corretamente)
-- =====================================================================
INSERT INTO perfis (nome, descricao) VALUES
    ('admin',       'Acesso total ao sistema'),
    ('tecnico',     'Diagnostico e manutencao de OS'),
    ('funcionario', 'Atendimento, cadastro e vendas');

INSERT INTO categorias (nome) VALUES
    ('Fontes'), ('Memorias'), ('Armazenamento'), ('Telas'), ('Baterias'), ('Perifericos');

INSERT INTO servicos (nome, descricao, preco) VALUES
    ('Diagnostico',            'Avaliacao tecnica do equipamento',       50.00),
    ('Troca de fonte',         'Substituicao da fonte de alimentacao',   80.00),
    ('Formatacao',             'Instalacao do sistema e programas',     120.00),
    ('Limpeza interna',        'Limpeza e troca de pasta termica',       90.00),
    ('Troca de tela',          'Substituicao de display',               150.00),
    ('Troca de bateria',       'Substituicao de bateria',                70.00);

INSERT INTO pecas (categoria_id, nome, descricao, preco, custo, estoque, estoque_minimo) VALUES
    (1, 'Fonte 65W Dell',      'Fonte para notebook Dell',          250.00, 150.00, 5, 2),
    (2, 'Memoria DDR4 8GB',    'Memoria RAM notebook/desktop',      180.00, 110.00, 8, 3),
    (3, 'SSD 240GB',           'SSD SATA 2.5"',                     190.00, 120.00, 6, 3),
    (4, 'Tela 15.6" LED',      'Display notebook 15.6 polegadas',   420.00, 300.00, 2, 1),
    (5, 'Bateria Notebook',    'Bateria generica 6 celulas',        210.00, 130.00, 3, 2);
