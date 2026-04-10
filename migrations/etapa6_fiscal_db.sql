-- ══════════════════════════════════════════════════════════════════
-- FLÜXA KITCHEN — ETAPA 6: Estrutura Fiscal
-- Execute no Supabase SQL Editor:
-- https://app.supabase.com/project/uzttjedryajsmngvpaqu/sql/new
-- ══════════════════════════════════════════════════════════════════

-- TABELA: food_fiscal_config (configuração fiscal por empresa)
CREATE TABLE IF NOT EXISTS food_fiscal_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES food_companies(id) ON DELETE CASCADE UNIQUE,

  -- Dados da empresa emissora
  razao_social VARCHAR(150),
  cnpj VARCHAR(14),
  inscricao_estadual VARCHAR(20),
  inscricao_municipal VARCHAR(20),
  regime_tributario VARCHAR(20) DEFAULT 'simples', -- simples, lucro_presumido, lucro_real

  -- Endereço fiscal
  endereco_logradouro VARCHAR(100),
  endereco_numero VARCHAR(20),
  endereco_complemento VARCHAR(50),
  endereco_bairro VARCHAR(60),
  endereco_municipio VARCHAR(60),
  endereco_uf CHAR(2),
  endereco_cep VARCHAR(8),
  endereco_ccodigo_municipio VARCHAR(7),

  -- Certificado digital (armazenar path no storage)
  certificado_url TEXT,
  certificado_senha_enc TEXT, -- senha criptografada
  certificado_validade DATE,

  -- Série e numeração NF-e
  serie_nfe VARCHAR(3) DEFAULT '001',
  proximo_numero_nfe INTEGER DEFAULT 1,

  -- Ambiente SEFAZ
  ambiente VARCHAR(10) DEFAULT 'homologacao', -- homologacao | producao

  -- Webhook N8N para emissão automática
  n8n_webhook_nfe TEXT,
  emissao_automatica BOOLEAN DEFAULT FALSE,

  -- Auditoria
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- TABELA: food_fiscal_docs (NF-e emitidas)
CREATE TABLE IF NOT EXISTS food_fiscal_docs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES food_companies(id) ON DELETE CASCADE,
  order_id UUID REFERENCES food_orders(id),

  -- Identificação do documento
  tipo_doc VARCHAR(10) DEFAULT 'nfe',          -- nfe, nfce, sat
  numero_nfe INTEGER,
  serie VARCHAR(3) DEFAULT '001',
  chave_acesso VARCHAR(44) UNIQUE,             -- chave 44 dígitos SEFAZ

  -- Dados do destinatário
  destinatario_nome VARCHAR(150),
  destinatario_cpf_cnpj VARCHAR(14),
  destinatario_email VARCHAR(100),

  -- Valores
  valor_produtos NUMERIC(10,2) DEFAULT 0,
  valor_desconto NUMERIC(10,2) DEFAULT 0,
  valor_total NUMERIC(10,2) DEFAULT 0,
  valor_icms NUMERIC(10,2) DEFAULT 0,
  valor_pis NUMERIC(10,2) DEFAULT 0,
  valor_cofins NUMERIC(10,2) DEFAULT 0,

  -- Status SEFAZ
  status VARCHAR(30) DEFAULT 'pendente',       -- pendente | autorizada | cancelada | rejeitada | denegada
  status_motivo TEXT,
  protocolo VARCHAR(20),
  data_autorizacao TIMESTAMP,
  data_cancelamento TIMESTAMP,
  motivo_cancelamento TEXT,

  -- Arquivos
  xml_url TEXT,
  danfe_url TEXT,
  xml_cancelamento_url TEXT,

  -- Controle
  ambiente VARCHAR(10) DEFAULT 'homologacao',
  tentativas INTEGER DEFAULT 0,
  ultimo_erro TEXT,

  -- Auditoria
  emitido_por UUID REFERENCES food_staff(id),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- TABELA: food_nf_itens (itens de cada NF-e)
CREATE TABLE IF NOT EXISTS food_nf_itens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nf_id UUID NOT NULL REFERENCES food_fiscal_docs(id) ON DELETE CASCADE,
  order_item_id UUID REFERENCES food_order_items(id),

  -- Produto
  codigo_produto VARCHAR(60),
  descricao VARCHAR(120) NOT NULL,
  ncm VARCHAR(8),                              -- Nomenclatura Comum do Mercosul
  cfop VARCHAR(4) DEFAULT '5102',              -- Código Fiscal de Operações
  unidade VARCHAR(6) DEFAULT 'UN',

  -- Quantidades e valores
  quantidade NUMERIC(10,4) DEFAULT 1,
  valor_unitario NUMERIC(10,4),
  valor_desconto NUMERIC(10,2) DEFAULT 0,
  valor_total NUMERIC(10,2),

  -- Tributos
  origem_produto CHAR(1) DEFAULT '0',          -- 0=Nacional, 1=Importado
  cst_icms VARCHAR(3) DEFAULT '400',
  aliquota_icms NUMERIC(5,2) DEFAULT 0,
  valor_icms NUMERIC(10,2) DEFAULT 0,
  cst_pis VARCHAR(2) DEFAULT '07',
  aliquota_pis NUMERIC(5,4) DEFAULT 0,
  valor_pis NUMERIC(10,2) DEFAULT 0,
  cst_cofins VARCHAR(2) DEFAULT '07',
  aliquota_cofins NUMERIC(5,4) DEFAULT 0,
  valor_cofins NUMERIC(10,2) DEFAULT 0,

  num_item INTEGER,
  created_at TIMESTAMP DEFAULT NOW()
);

-- ══════════════════════════════════════════════════════════════════
-- ÍNDICES
-- ══════════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_fiscal_config_company ON food_fiscal_config(company_id);
CREATE INDEX IF NOT EXISTS idx_fiscal_docs_company ON food_fiscal_docs(company_id);
CREATE INDEX IF NOT EXISTS idx_fiscal_docs_order ON food_fiscal_docs(order_id);
CREATE INDEX IF NOT EXISTS idx_fiscal_docs_status ON food_fiscal_docs(status);
CREATE INDEX IF NOT EXISTS idx_fiscal_docs_chave ON food_fiscal_docs(chave_acesso);
CREATE INDEX IF NOT EXISTS idx_nf_itens_nf ON food_nf_itens(nf_id);

-- ══════════════════════════════════════════════════════════════════
-- VERIFICAÇÃO
-- ══════════════════════════════════════════════════════════════════
-- SELECT table_name FROM information_schema.tables
--   WHERE table_name IN ('food_fiscal_config','food_fiscal_docs','food_nf_itens');
