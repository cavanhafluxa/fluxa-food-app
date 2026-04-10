-- ══════════════════════════════════════════════════════════════════
-- FLÜXA KITCHEN — ETAPA 9: PDV, Mesas e Estoque
-- Execute no Supabase SQL Editor:
-- https://app.supabase.com/project/uzttjedryajsmngvpaqu/sql/new
-- ══════════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────────
-- TABELA: food_pdv_sessions (sessões de caixa)
-- ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS food_pdv_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES food_companies(id) ON DELETE CASCADE,
  staff_id UUID NOT NULL REFERENCES food_staff(id),

  -- Controle da sessão
  status VARCHAR(20) DEFAULT 'aberta',        -- aberta | fechada
  valor_abertura NUMERIC(10,2) DEFAULT 0,     -- fundo de caixa
  valor_fechamento NUMERIC(10,2),             -- total no fechamento
  valor_total_vendas NUMERIC(10,2) DEFAULT 0, -- soma das transações

  -- Dinheiro em espécie
  sangria_total NUMERIC(10,2) DEFAULT 0,      -- saídas manuais
  suprimento_total NUMERIC(10,2) DEFAULT 0,   -- entradas manuais

  -- Observações de fechamento
  observacao_abertura TEXT,
  observacao_fechamento TEXT,

  -- Timestamps
  aberto_em TIMESTAMP DEFAULT NOW(),
  fechado_em TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- ──────────────────────────────────────────────────────────────────
-- TABELA: food_pdv_transactions (transações do caixa)
-- ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS food_pdv_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES food_pdv_sessions(id) ON DELETE CASCADE,
  company_id UUID NOT NULL REFERENCES food_companies(id) ON DELETE CASCADE,
  order_id UUID REFERENCES food_orders(id),

  -- Tipo de transação
  tipo VARCHAR(30) NOT NULL,                  -- venda | sangria | suprimento | estorno
  descricao VARCHAR(255),

  -- Forma de pagamento
  forma_pagamento VARCHAR(30),                -- dinheiro | cartao_credito | cartao_debito | pix | outros

  -- Valores
  valor NUMERIC(10,2) NOT NULL,
  troco NUMERIC(10,2) DEFAULT 0,

  -- Operador
  staff_id UUID REFERENCES food_staff(id),

  created_at TIMESTAMP DEFAULT NOW()
);

-- ──────────────────────────────────────────────────────────────────
-- TABELA: food_tables (mesas do restaurante)
-- ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS food_tables (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES food_companies(id) ON DELETE CASCADE,

  -- Identificação
  numero INTEGER NOT NULL,
  nome VARCHAR(50),                           -- ex: Mesa 01, Varanda 2
  capacidade INTEGER DEFAULT 4,
  localizacao VARCHAR(60),                    -- ex: Salão, Varanda, Terraço

  -- Status
  status VARCHAR(30) DEFAULT 'livre',         -- livre | ocupada | conta_solicitada | reservada | inativa

  -- Ocupação atual
  pedido_id UUID REFERENCES food_orders(id),  -- pedido ativo na mesa
  ocupada_em TIMESTAMP,
  num_pessoas INTEGER,

  -- Reserva
  reserva_nome VARCHAR(100),
  reserva_hora TIMESTAMP,

  -- Flags
  ativo BOOLEAN DEFAULT TRUE,

  -- Auditoria
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),

  UNIQUE(company_id, numero)
);

-- ──────────────────────────────────────────────────────────────────
-- TABELA: food_inventory_items (itens do estoque)
-- ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS food_inventory_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES food_companies(id) ON DELETE CASCADE,

  -- Identificação do item
  codigo VARCHAR(60),
  nome VARCHAR(120) NOT NULL,
  descricao TEXT,
  categoria VARCHAR(60),                      -- bebidas | ingredientes | embalagens | limpeza | outros

  -- Unidade
  unidade VARCHAR(20) DEFAULT 'un',           -- un, kg, g, L, ml, cx, pct

  -- Quantidades
  quantidade_atual NUMERIC(10,3) DEFAULT 0,
  quantidade_minima NUMERIC(10,3) DEFAULT 0,  -- alerta de estoque baixo
  quantidade_maxima NUMERIC(10,3),

  -- Preços
  preco_custo NUMERIC(10,2) DEFAULT 0,        -- custo unitário
  preco_venda NUMERIC(10,2),                  -- preço de venda (se aplicável)

  -- Fornecedor
  fornecedor_nome VARCHAR(100),
  fornecedor_contato VARCHAR(100),

  -- Flags
  ativo BOOLEAN DEFAULT TRUE,
  controla_estoque BOOLEAN DEFAULT TRUE,

  -- Auditoria
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- ──────────────────────────────────────────────────────────────────
-- TABELA: food_inventory_movements (movimentações de estoque)
-- ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS food_inventory_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id UUID NOT NULL REFERENCES food_inventory_items(id) ON DELETE CASCADE,
  company_id UUID NOT NULL REFERENCES food_companies(id) ON DELETE CASCADE,

  -- Tipo de movimento
  tipo VARCHAR(20) NOT NULL,                  -- entrada | saida | ajuste | perda

  -- Quantidades
  quantidade NUMERIC(10,3) NOT NULL,
  quantidade_anterior NUMERIC(10,3),
  quantidade_posterior NUMERIC(10,3),

  -- Contexto
  motivo VARCHAR(100),                        -- compra | uso_producao | venda | descarte | inventario
  referencia VARCHAR(100),                    -- ex: número do pedido, nota fiscal
  observacao TEXT,

  -- Custo da movimentação
  custo_unitario NUMERIC(10,2),
  custo_total NUMERIC(10,2),

  -- Operador
  staff_id UUID REFERENCES food_staff(id),

  created_at TIMESTAMP DEFAULT NOW()
);

-- ══════════════════════════════════════════════════════════════════
-- ÍNDICES
-- ══════════════════════════════════════════════════════════════════

-- PDV Sessions
CREATE INDEX IF NOT EXISTS idx_pdv_sessions_company ON food_pdv_sessions(company_id);
CREATE INDEX IF NOT EXISTS idx_pdv_sessions_staff ON food_pdv_sessions(staff_id);
CREATE INDEX IF NOT EXISTS idx_pdv_sessions_status ON food_pdv_sessions(status);

-- PDV Transactions
CREATE INDEX IF NOT EXISTS idx_pdv_transactions_session ON food_pdv_transactions(session_id);
CREATE INDEX IF NOT EXISTS idx_pdv_transactions_company ON food_pdv_transactions(company_id);
CREATE INDEX IF NOT EXISTS idx_pdv_transactions_tipo ON food_pdv_transactions(tipo);
CREATE INDEX IF NOT EXISTS idx_pdv_transactions_created ON food_pdv_transactions(created_at);

-- Mesas
CREATE INDEX IF NOT EXISTS idx_tables_company ON food_tables(company_id);
CREATE INDEX IF NOT EXISTS idx_tables_status ON food_tables(status);
CREATE INDEX IF NOT EXISTS idx_tables_numero ON food_tables(company_id, numero);

-- Estoque
CREATE INDEX IF NOT EXISTS idx_inventory_company ON food_inventory_items(company_id);
CREATE INDEX IF NOT EXISTS idx_inventory_categoria ON food_inventory_items(categoria);
CREATE INDEX IF NOT EXISTS idx_inventory_ativo ON food_inventory_items(ativo);

-- Movimentações
CREATE INDEX IF NOT EXISTS idx_movements_item ON food_inventory_movements(item_id);
CREATE INDEX IF NOT EXISTS idx_movements_company ON food_inventory_movements(company_id);
CREATE INDEX IF NOT EXISTS idx_movements_tipo ON food_inventory_movements(tipo);
CREATE INDEX IF NOT EXISTS idx_movements_created ON food_inventory_movements(created_at);

-- ══════════════════════════════════════════════════════════════════
-- DADOS INICIAIS: Mesas padrão (10 mesas)
-- ══════════════════════════════════════════════════════════════════
-- Descomente e substitua <COMPANY_UUID> pelo UUID da sua empresa:
-- INSERT INTO food_tables (company_id, numero, nome, capacidade, localizacao)
-- SELECT '<COMPANY_UUID>', n, 'Mesa ' || LPAD(n::TEXT, 2, '0'), 4, 'Salão'
-- FROM generate_series(1, 10) n
-- ON CONFLICT (company_id, numero) DO NOTHING;

-- ══════════════════════════════════════════════════════════════════
-- VERIFICAÇÃO
-- ══════════════════════════════════════════════════════════════════
-- SELECT table_name FROM information_schema.tables
--   WHERE table_name IN (
--     'food_pdv_sessions','food_pdv_transactions',
--     'food_tables','food_inventory_items','food_inventory_movements'
--   );
