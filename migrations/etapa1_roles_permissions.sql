-- ══════════════════════════════════════════════════════════════════
-- FLÜXA KITCHEN — ETAPA 1: Roles + Permissões
-- Execute no Supabase SQL Editor:
-- https://app.supabase.com/project/uzttjedryajsmngvpaqu/sql/new
-- ══════════════════════════════════════════════════════════════════

-- TABELA: food_roles (três tipos de usuário)
CREATE TABLE IF NOT EXISTS food_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(50) NOT NULL UNIQUE,
  description VARCHAR(255),
  created_at TIMESTAMP DEFAULT NOW()
);

-- TABELA: food_permissions (22 permissões granulares)
CREATE TABLE IF NOT EXISTS food_permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL UNIQUE,
  description VARCHAR(255),
  category VARCHAR(50),
  created_at TIMESTAMP DEFAULT NOW()
);

-- TABELA: food_role_permissions (mapeamento role → permission)
CREATE TABLE IF NOT EXISTS food_role_permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  role_id UUID NOT NULL REFERENCES food_roles(id) ON DELETE CASCADE,
  permission_id UUID NOT NULL REFERENCES food_permissions(id) ON DELETE CASCADE,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(role_id, permission_id)
);

-- TABELA: food_staff (operadores/funcionários)
CREATE TABLE IF NOT EXISTS food_staff (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES food_companies(id) ON DELETE CASCADE,

  -- Autenticação
  email VARCHAR(100) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,

  -- Dados pessoais
  nome_completo VARCHAR(150) NOT NULL,
  telefone VARCHAR(20),
  cpf VARCHAR(11),
  data_nascimento DATE,

  -- Role
  role_id UUID NOT NULL REFERENCES food_roles(id),

  -- Status
  ativo BOOLEAN DEFAULT TRUE,
  bloqueado BOOLEAN DEFAULT FALSE,
  bloqueado_motivo VARCHAR(255),

  -- Dados operacionais
  numero_matricula VARCHAR(20),
  data_admissao DATE,
  comissao_percentual NUMERIC(5,2) DEFAULT 0,

  -- Auditoria
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  last_login TIMESTAMP,

  -- Constraints
  UNIQUE(company_id, email),
  UNIQUE(company_id, cpf)
);

-- TABELA: food_staff_permissions_override (permissões customizadas por staff)
CREATE TABLE IF NOT EXISTS food_staff_permissions_override (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id UUID NOT NULL REFERENCES food_staff(id) ON DELETE CASCADE,
  permission_id UUID NOT NULL REFERENCES food_permissions(id) ON DELETE CASCADE,
  granted BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(staff_id, permission_id)
);

-- TABELA: food_staff_activity_log (auditoria de ações)
CREATE TABLE IF NOT EXISTS food_staff_activity_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES food_companies(id),
  staff_id UUID REFERENCES food_staff(id),
  action VARCHAR(100),
  resource VARCHAR(100),
  resource_id VARCHAR(100),
  details JSONB,
  ip_address VARCHAR(50),
  user_agent VARCHAR(255),
  created_at TIMESTAMP DEFAULT NOW()
);

-- ══════════════════════════════════════════════════════════════════
-- INSERIR ROLES PADRÃO (3 roles)
-- ══════════════════════════════════════════════════════════════════

INSERT INTO food_roles (name, description) VALUES
('dono', 'Proprietário do restaurante - acesso total'),
('funcionario', 'Funcionário - operação básica (pedidos, mesas, caixa)'),
('motoboy', 'Entregador - rotas, pedidos em entrega, caixa')
ON CONFLICT (name) DO NOTHING;

-- ══════════════════════════════════════════════════════════════════
-- INSERIR PERMISSÕES PADRÃO (22 permissões)
-- ══════════════════════════════════════════════════════════════════

INSERT INTO food_permissions (name, description, category) VALUES
-- PEDIDOS
('view_pedidos', 'Visualizar pedidos', 'pedidos'),
('edit_pedidos_status', 'Avançar status de pedidos', 'pedidos'),
('cancelar_pedidos', 'Cancelar pedidos', 'pedidos'),
-- CARDÁPIO
('view_cardapio', 'Visualizar cardápio', 'cardapio'),
('edit_cardapio', 'Editar cardápio (itens, preços)', 'cardapio'),
-- MESAS
('view_mesas', 'Visualizar mesas', 'mesas'),
('edit_mesas', 'Abrir/fechar mesas', 'mesas'),
-- PDV
('view_pdv', 'Usar PDV (caixa)', 'pdv'),
('edit_pdv_transacao', 'Registrar transação no PDV', 'pdv'),
-- CAIXA
('view_caixa', 'Visualizar caixa', 'caixa'),
('fechar_caixa', 'Fechar turno/caixa', 'caixa'),
-- ESTOQUE
('view_estoque', 'Visualizar estoque', 'estoque'),
('edit_estoque', 'Editar estoque (adicionar/remover itens)', 'estoque'),
-- FISCAL
('view_fiscal', 'Visualizar emissões NF-e', 'fiscal'),
('emitir_nfe', 'Emitir NF-e manualmente', 'fiscal'),
('config_fiscal', 'Configurar certificado e dados fiscais', 'fiscal'),
('cancelar_nfe', 'Cancelar NF-e', 'fiscal'),
-- RELATÓRIOS
('view_dashboard', 'Ver dashboard financeiro', 'admin'),
('view_relatorios', 'Gerar relatórios', 'admin'),
-- ADMIN
('edit_staff', 'Gerenciar operadores (CRUD)', 'admin'),
('view_logs', 'Ver logs de atividade', 'admin'),
('config_restaurante', 'Configurar dados restaurante', 'admin')
ON CONFLICT (name) DO NOTHING;

-- ══════════════════════════════════════════════════════════════════
-- MAPEAR PERMISSÕES POR ROLE
-- ══════════════════════════════════════════════════════════════════

-- DONO: acesso total (todas as 22 permissões)
INSERT INTO food_role_permissions (role_id, permission_id)
SELECT
  (SELECT id FROM food_roles WHERE name = 'dono'),
  id
FROM food_permissions
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- FUNCIONÁRIO (9 permissões)
INSERT INTO food_role_permissions (role_id, permission_id)
SELECT
  (SELECT id FROM food_roles WHERE name = 'funcionario'),
  id
FROM food_permissions
WHERE name IN (
  'view_pedidos', 'edit_pedidos_status',
  'view_cardapio',
  'view_mesas', 'edit_mesas',
  'view_pdv', 'edit_pdv_transacao',
  'view_caixa', 'fechar_caixa'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- MOTOBOY (3 permissões)
INSERT INTO food_role_permissions (role_id, permission_id)
SELECT
  (SELECT id FROM food_roles WHERE name = 'motoboy'),
  id
FROM food_permissions
WHERE name IN (
  'view_pedidos',
  'view_caixa',
  'view_relatorios'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- ══════════════════════════════════════════════════════════════════
-- ÍNDICES PARA PERFORMANCE (9 índices)
-- ══════════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_staff_company ON food_staff(company_id);
CREATE INDEX IF NOT EXISTS idx_staff_email ON food_staff(email);
CREATE INDEX IF NOT EXISTS idx_staff_role ON food_staff(role_id);
CREATE INDEX IF NOT EXISTS idx_staff_active ON food_staff(ativo, bloqueado);
CREATE INDEX IF NOT EXISTS idx_role_permissions ON food_role_permissions(role_id);
CREATE INDEX IF NOT EXISTS idx_staff_permissions_override ON food_staff_permissions_override(staff_id);
CREATE INDEX IF NOT EXISTS idx_activity_log_company ON food_staff_activity_log(company_id);
CREATE INDEX IF NOT EXISTS idx_activity_log_staff ON food_staff_activity_log(staff_id);
CREATE INDEX IF NOT EXISTS idx_activity_log_action ON food_staff_activity_log(action);

-- ══════════════════════════════════════════════════════════════════
-- VERIFICAÇÃO (rode depois para confirmar)
-- ══════════════════════════════════════════════════════════════════
-- SELECT name FROM food_roles;                                    -- 3 rows
-- SELECT COUNT(*) FROM food_permissions;                          -- 22 rows
-- SELECT r.name, COUNT(rp.permission_id) FROM food_roles r
--   LEFT JOIN food_role_permissions rp ON r.id = rp.role_id
--   GROUP BY r.name;                                              -- dono:22, funcionario:9, motoboy:3
