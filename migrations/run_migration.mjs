/**
 * FLÜXA KITCHEN — Script de migração Etapa 1
 *
 * Uso:
 *   SUPABASE_SERVICE_KEY=<sua_service_role_key> node migrations/run_migration.mjs
 *
 * Ou cole o SQL diretamente no Supabase Dashboard:
 *   https://app.supabase.com/project/uzttjedryajsmngvpaqu/sql/new
 */

import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));

const SB_URL = 'https://uzttjedryajsmngvpaqu.supabase.co';
const SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;

if (!SERVICE_KEY) {
  console.error('❌ Variável SUPABASE_SERVICE_KEY não definida.');
  console.error('   Uso: SUPABASE_SERVICE_KEY=<key> node migrations/run_migration.mjs');
  process.exit(1);
}

const sql = readFileSync(join(__dirname, 'etapa1_roles_permissions.sql'), 'utf-8');

// Remove comentários de verificação (linhas com --)
const cleanSql = sql
  .split('\n')
  .filter(line => !line.trim().startsWith('--'))
  .join('\n')
  .trim();

console.log('🚀 Executando migração Etapa 1: Roles + Permissões...');

const res = await fetch(`${SB_URL}/rest/v1/rpc/`, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${SERVICE_KEY}`,
    'apikey': SERVICE_KEY,
  },
  body: JSON.stringify({ query: cleanSql }),
});

// Tenta via Management API
const mgmtRes = await fetch(
  `https://api.supabase.com/v1/projects/uzttjedryajsmngvpaqu/database/query`,
  {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${SERVICE_KEY}`,
    },
    body: JSON.stringify({ query: cleanSql }),
  }
);

if (mgmtRes.ok) {
  console.log('✅ Migração executada com sucesso!');
  console.log('   Tabelas criadas: food_roles, food_permissions, food_role_permissions,');
  console.log('                   food_staff, food_staff_permissions_override, food_staff_activity_log');
  console.log('   Roles: dono, funcionario, motoboy');
  console.log('   Permissões: 22');
  console.log('   Índices: 9');
} else {
  const err = await mgmtRes.text();
  console.error('❌ Erro ao executar migração:', err);
  console.log('\n📋 Cole o SQL manualmente em:');
  console.log('   https://app.supabase.com/project/uzttjedryajsmngvpaqu/sql/new');
  console.log('   Arquivo: migrations/etapa1_roles_permissions.sql');
}
