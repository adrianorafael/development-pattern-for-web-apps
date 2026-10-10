# Migrações e rollback: o banco precisa servir às duas versões do código

> Regra **R10**. **Toda migração é compatível com a versão anterior do código.**
> O Instant Rollback da Vercel volta o código, não o banco. Se a migração de hoje quebra o
> código de ontem, o botão de rollback deixa de ser uma saída: vira um segundo incidente,
> aberto no meio do primeiro, com dados de usuários sendo escritos num schema que nenhuma
> versão do app entende por inteiro.

O que a própria Vercel diz sobre o rollback
([vercel.com/docs/instant-rollback](https://vercel.com/docs/instant-rollback), conferido em
2026-10-10): aponta os domínios de volta para um deployment anterior, **sem rebuild**; as
variáveis de ambiente não mudam; o diálogo de confirmação lembra que "external APIs,
databases, and CMSes" podem ter mudado entre as duas versões. Depois de um rollback, a
Vercel **desliga a atribuição automática** dos domínios de produção: um push novo em `main`
não entra no ar até alguém rodar `vercel promote` (ou "Undo Rollback" no painel). No plano
Hobby só dá para voltar ao deployment imediatamente anterior.

| Volta com o rollback | Não volta |
| --- | --- |
| Código, build, rotas, funções | Schema do banco (Supabase) |
| Configuração de cron do deployment | Dados escritos depois do deploy |
| | Arquivos no Supabase Storage, mensagens enviadas, cobranças feitas |

A consequência é uma só: em qualquer momento, o schema de produção precisa funcionar com o
código **atual** e com o código **anterior**. O resto deste documento é como garantir isso.

---

## 1. Arquivos, registro e o Supabase CLI

O runner de migração é o próprio **Supabase CLI** (pacote `supabase`, 2.120.0, conferido em
2026-10-10). Não escreva um runner seu.

```
supabase/
├── config.toml                                  ← criado por `supabase init`
├── seed.sql                                     ← dados SINTÉTICOS do ambiente local
└── migrations/
    ├── 20261010120000_schema_inicial.sql        ← de assets/templates/schema.sql.template
    ├── 20261010120100_politicas_rls.sql         ← de assets/templates/politicas-rls.sql.template
    └── 20261103090000_adiciona_comentarios.sql  ← modelo em assets/templates/migration.sql.template
```

- **Nome:** `supabase migration new adiciona_comentarios` cria
  `supabase/migrations/<AAAAMMDDHHMMSS>_adiciona_comentarios.sql`, com a data e hora em UTC
  (código do CLI 2.120.0, `GetVersionTimestamp`: "formats t as a migration version (UTC
  `YYYYMMDDHHMMSS`)"). O número **é** a ordem de execução. Descrição em minúsculas, com
  sublinhado.
- **Registro:** cada arquivo aplicado vira uma linha em
  `supabase_migrations.schema_migrations` (`version`, `name`, `statements`), criada pelo
  próprio CLI ([supabase.com/docs/guides/deployment/database-migrations](https://supabase.com/docs/guides/deployment/database-migrations)).
  É o registro da R13.
- **Imutável depois de aplicado.** O CLI compara **só o número da versão** entre o
  diretório local e o banco, não o conteúdo (`pkg/migration/apply.go`,
  `FindPendingMigrations`, 2.120.0). Editar um arquivo já aplicado não gera erro nenhum: a
  edição é ignorada em silêncio no banco remoto, e o repositório passa a mentir sobre o
  schema. Correção é sempre uma migração nova. É isso que o caso CT-MIG-006 confere.
- **Fora de ordem:** um arquivo local com número **menor** que a última versão do banco faz
  o `db push` parar com "Found local migration files to be inserted before the last
  migration on remote database." (mesmo arquivo). Acontece quando dois ramos criam
  migração em paralelo: no merge, gere o arquivo de novo com `supabase migration new` para
  ganhar um número posterior.
- **Versão no banco que não existe no diretório:** o `db push` para com "Remote migration
  versions not found in local migrations directory." Alguém mudou o schema por fora (pelo
  painel, por exemplo). Traga a mudança para um arquivo; `supabase migration repair` só
  corrige o registro, "it does not apply or revert any SQL" (página de migrações acima).

```bash
npm install --save-dev supabase           # supabase@2.120.0: o CLI vira dependência do projeto
npx supabase init                         # cria supabase/config.toml
npx supabase migration new schema_inicial # cole schema.sql.template
npx supabase migration new politicas_rls  # cole politicas-rls.sql.template
```

```json
"scripts": {
  "db:migrate":       "supabase db push",
  "db:migrate:check": "supabase db push --dry-run",
  "db:status":        "supabase migration list",
  "db:reset:local":   "supabase db reset"
}
```

`db:reset:local` apaga e recria o banco **local** (o do `supabase start`), reaplica todas as
migrações e roda `supabase/seed.sql`. Contra o projeto remoto, `supabase db reset --linked`
existe e apaga produção: nunca em script, nunca aprovado em lote
([agentes-e-ferramentas-de-ia.md](agentes-e-ferramentas-de-ia.md)).

O que o CLI faz ao aplicar um arquivo (código de `pkg/migration/file.go`, `ExecBatch`, tag
`v2.120.0`, lido em 2026-10-10; não executado aqui):

| Situação | Comportamento |
| --- | --- |
| Arquivo pendente | Os comandos do arquivo e o `INSERT` em `schema_migrations` vão num **único lote** (pipeline) com um Sync no fim. Sem `BEGIN` explícito, o Postgres trata o lote como transação implícita: "each Sync ordinarily causes an implicit `COMMIT` if the preceding step(s) succeeded, or an implicit `ROLLBACK` if they failed" ([postgresql.org/docs/17/protocol-flow.html](https://www.postgresql.org/docs/17/protocol-flow.html), seção Pipelining) |
| Erro no meio de um arquivo | O lote inteiro volta, a versão não é registrada, os arquivos seguintes não rodam |
| `CREATE INDEX CONCURRENTLY`, `DROP INDEX CONCURRENTLY`, `REINDEX ... CONCURRENTLY`, `VACUUM` | Executados **fora** do lote (`isPipelineIncompatible`). O que veio antes deles no arquivo já foi gravado: por isso eles ficam sozinhos num arquivo (seção 5) |
| Arquivo aplicado foi editado | Nada: o CLI não compara conteúdo (veja acima) |
| Conexão | `supabase link --project-ref SEU-PROJETO-REF` grava o vínculo; `db push`, `migration list` e `db dump` usam `--linked` por padrão ou `--db-url` |

---

## 2. Expand → migrate → contract

Toda mudança que **quebraria** o código anterior é dividida em releases. Cada release é
compatível com o anterior, então cada um pode ser revertido.

| Fase | O que a migração faz | O que o código faz |
| --- | --- | --- |
| **Expand** | Só **acrescenta**: tabela, coluna nullable ou com `DEFAULT`, índice | Escreve no velho **e** no novo; lê do velho (ou do novo com fallback) |
| **Migrate** | Copia os dados (backfill); restrições no novo; afrouxa o velho | Lê e escreve só no novo |
| **Contract** | **Remove** o velho (`DROP COLUMN`, `DROP TABLE`) | Nada muda: já não usava |

### Operações seguras e perigosas

| Operação | Compatível com o código anterior? | Como fazer |
| --- | --- | --- |
| `CREATE TABLE`, `ADD COLUMN` nullable | ✅ sim | direto; tabela nova já com RLS, grants e políticas no mesmo arquivo (P13) |
| `ADD COLUMN ... DEFAULT <constante>` | ✅ sim | direto; desde o Postgres 11 não reescreve a tabela |
| `CREATE INDEX` | ✅ sim | em tabela grande, `CONCURRENTLY` (seção 5) |
| `ADD COLUMN ... NOT NULL` sem default | ❌ não: o `INSERT` do código antigo falha | nullable no expand, `NOT NULL` no migrate |
| `RENAME COLUMN` / `RENAME TABLE` | ❌ não: o código antigo procura o nome velho | três releases (exemplo abaixo) |
| `DROP COLUMN` / `DROP TABLE` | ❌ não, se o código anterior ainda usa | só no contract, um release **depois** de parar de usar |
| Trocar tipo (`ALTER COLUMN ... TYPE`) | ❌ geralmente não, e reescreve a tabela | coluna nova + backfill + contract |
| Apertar `CHECK` ou domínio de status | ❌ não, se o código antigo grava o valor removido | só depois que nenhum código grava mais |
| Apertar política RLS ou revogar grant | ❌ não, se o código antigo depende do acesso | mesmo cuidado de um `DROP`: o código anterior passa a receber `[]` ou erro de permissão |

Função SQL chamada por `.rpc()` com `returns setof <tabela>` quebra quando a tabela ganha
coluna e a função lista colunas fixas: por isso `buscar_chamados`, em
`schema.sql.template`, declara `returns table (...)` com as próprias colunas.

### Exemplo concreto: renomear `perfis.nome` para `nome_completo`

Os três arquivos abaixo foram aplicados em sequência contra Postgres 17, com o código de
cada release simulado entre eles. Lembre o `grant update (nome)` de
`politicas-rls.sql.template`: coluna nova que o usuário edita precisa do grant dela.

**Release 1.4.0: expand.**

```sql
-- supabase/migrations/20261103090000_perfis_nome_completo_expand.sql
alter table public.perfis add column if not exists nome_completo text;
grant update (nome_completo) on public.perfis to authenticated;
```

```ts
// Código 1.4.0: escreve nos dois, lê o novo com fallback para o velho.
await supabase.from('perfis').update({ nome, nome_completo: nome }).eq('id', usuarioId);
const { data } = await supabase.from('perfis').select('id, nome, nome_completo').eq('id', usuarioId).single();
const exibido = data?.nome_completo ?? data?.nome;
```

Rollback para 1.3.0: o código antigo ignora a coluna nova. ✅

**Release 1.5.0: migrate.**

```sql
-- supabase/migrations/20261117090000_perfis_nome_completo_migrate.sql
update public.perfis set nome_completo = nome where nome_completo is null and nome is not null;

alter table public.perfis
  add constraint perfis_nome_completo_tamanho
  check (nome_completo is null or char_length(nome_completo) between 1 and 120) not valid;
alter table public.perfis validate constraint perfis_nome_completo_tamanho;
```

```ts
// Código 1.5.0: só o novo.
await supabase.from('perfis').update({ nome_completo: nome }).eq('id', usuarioId);
```

Rollback para 1.4.0: o código 1.4.0 escreve nos dois e lê com fallback (acha o nome das
linhas novas, que só têm `nome_completo`). ✅

**Release 2.0.0: contract.** Destrutiva, portanto MAJOR (seção 4). O gatilho
`criar_perfil_do_usuario` do schema grava em `nome`: atualize-o **no mesmo arquivo**, antes
do `drop`.

```sql
-- supabase/migrations/20261201090000_perfis_nome_contract.sql
-- ⚠️ Destrutiva. Antes: backup do dia ou `supabase db dump` (seção 4).
create or replace function public.criar_perfil_do_usuario() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.perfis (id, nome_completo, papel)
  values (
    new.id,
    nullif(left(trim(new.raw_user_meta_data ->> 'nome'), 120), ''),
    case when new.raw_app_meta_data ->> 'papel' = 'admin' then 'admin' else 'usuario' end
  )
  on conflict (id) do nothing;
  return new;
end;
$$;
alter table public.perfis drop column if exists nome;
```

Rollback para 1.5.0: o código 1.5.0 já não tocava em `nome`. ✅
Rollback para 1.4.0: ❌ quebra, porque 1.4.0 escreve em `nome`. É por isso que o contract
espera o release seguinte ao que parou de usar a coluna, e por isso ele é MAJOR: a janela
de rollback seguro encolhe para uma versão.

Note o `add constraint` sem `if not exists` (o Postgres não tem essa forma para
constraint): o arquivo só é seguro porque o CLI o aplica num lote só, tudo ou nada.

---

## 3. Quando aplicar, em cada ambiente

A ordem é sempre **migração antes do código que depende dela**. Como a migração é
compatível com o código anterior, o intervalo entre as duas não quebra nada.

### Local: `supabase start` e `supabase db reset`

`npx supabase start` sobe o Supabase inteiro em containers (exige Docker);
`npm run db:reset:local` reaplica as migrações do zero e roda `supabase/seed.sql`. É ali
que toda migração nova roda pela primeira vez, duas vezes seguidas (CT-MIG-001).

### Preview: banco próprio, nunca o de produção

**Supabase Branching** ([supabase.com/docs/guides/deployment/branching](https://supabase.com/docs/guides/deployment/branching),
conferido em 2026-10-10): "isolated preview environments for each pull request".

| Fato da documentação | Consequência |
| --- | --- |
| "Preview branches are ephemeral" e "are automatically deleted when a PR is merged or closed" | Nada de valor mora num branch de preview |
| "Each branch is a separate environment with its own Supabase instance and API credentials" | O preview tem URL e chaves próprias, diferentes das de produção |
| As etapas do deploy de um branch incluem "Migrate" (aplica as migrações pendentes) e "Seed" (roda os arquivos de seed) | O schema do preview acompanha o PR; o seed é sintético |
| "By default, new branches do not start with any data or storage objects from your main project" | Dado real de produção não vaza para o preview por padrão. Não ligue "Include data" para um projeto com dado pessoal |

A página não descreve a ligação com a Vercel nem preço ou plano exigido: **confira no
primeiro PR** que as variáveis do Preview Deployment apontam para o branch, comparando o
host de `NEXT_PUBLIC_SUPABASE_URL` e de `POSTGRES_URL` com os de produção (CT-MIG-008).
Sem Branching, a alternativa é um **segundo projeto Supabase** só para Preview, com as
variáveis do ambiente Preview da Vercel apontando para ele.

Preview que usa o banco de produção é proibido: uma migração de teste num ramo
experimental vira alteração de produção sem revisão.

### Produção: backup, migração, promoção

```bash
# 1. Vínculo com o projeto de produção (uma vez por máquina; pede a senha do banco)
npx supabase link --project-ref SEU-PROJETO-REF

# 2. Backup imediatamente antes (seção 4). No Free, este é o ÚNICO backup.
npx supabase db dump --linked -f backups/antes-1.5.0-schema.sql
npx supabase db dump --linked -f backups/antes-1.5.0-dados.sql --use-copy --data-only

# 3. O que vai rodar: Local x Remote, e o ensaio sem aplicar
npx supabase migration list --linked
npx supabase db push --dry-run

# 4. Aplicar
npx supabase db push

# 5. Só agora o código novo vai ao ar
vercel promote https://SEU-DEPLOYMENT-DE-PREVIEW.vercel.app
```

Flags de `link`, `db dump`, `migration list` e `db push` conferidas em
[supabase.com/docs/reference/cli](https://supabase.com/docs/reference/cli/supabase-db-push)
em 2026-10-10. A pasta `backups/` tem dado de produção: **fora do Git** (acrescente ao
`.gitignore`) e fora da máquina assim que possível, num armazenamento com acesso restrito.

Migrar produção dentro do build também funciona, **desde que** a R10 seja respeitada: o
build roda antes de o deployment receber tráfego, então por alguns minutos o código antigo
atende sobre o schema novo, que é exatamente o cenário que a compatibilidade cobre. O que
não pode é migração destrutiva no build: o contract roda à mão, com o backup da etapa 2.

---

## 4. Backup, restauração ensaiada e versão

> Piso **P14**: **o banco tem backup e a restauração já foi ensaiada.** Backup que nunca foi
> restaurado é uma esperança, não um backup.

O backup existe **independente de migração**: o que apaga dados no dia a dia é bug, conta
comprometida e exclusão por engano, não só `DROP`.

| Plano do Supabase | Backup automático | O que fazer |
| --- | --- | --- |
| **Free** | **Nenhum** descrito na documentação, que recomenda: "free tier plan projects regularly export their data using the Supabase CLI `db dump` command" | `supabase db dump` agendado (ao menos semanal e antes de toda migração), guardado **fora** do Supabase e fora do repositório |
| **Pro** | "Pro Plan projects can access the last 7 days of daily backups" | Dump antes de migração destrutiva, porque o diário pode ter até 24 h |
| **Team** | 14 dias de backups diários | Idem |
| **PITR** | Add-on pago, "Pro, Team and Enterprise", que exige "at least a Small compute add-on" | Para quem não pode perder um dia de dados |

Fonte: [supabase.com/docs/guides/platform/backups](https://supabase.com/docs/guides/platform/backups),
conferido em 2026-10-10. Duas ressalvas da mesma página:

- **Storage não entra:** "Database backups do not include objects you store via the
  Storage API". Arquivo do usuário precisa de cópia própria, se a perda dele importar.
- **Restaurar derruba o projeto:** restauração pelo painel em *Database > Backups*, e "The
  project is inaccessible during this process, so plan for downtime beforehand."

### Ensaio de restauração (CT-MIG-011)

Antes do primeiro lançamento e depois **a cada trimestre**: restaure o último backup ou dump
num projeto **descartável** (nunca no de produção) e rode a fumaça contra ele. Comandos da
documentação de backup pelo CLI
([supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore)):

```bash
# Origem: o projeto linkado (produção). Três arquivos: papéis, schema, dados.
npx supabase db dump --linked -f backups/papeis.sql --role-only
npx supabase db dump --linked -f backups/schema.sql
npx supabase db dump --linked -f backups/dados.sql --use-copy --data-only \
  -x "storage.buckets_vectors" -x "storage.vector_indexes"

# Destino: o projeto DESCARTÁVEL. A URL vem de um arquivo fora do Git, nunca digitada
# na linha de comando nem colada na conversa (segredos-e-configuracao.md).
psql \
  --single-transaction \
  --variable ON_ERROR_STOP=1 \
  --file backups/papeis.sql \
  --file backups/schema.sql \
  --command 'SET session_replication_role = replica' \
  --file backups/dados.sql \
  --dbname "$URL_DO_PROJETO_DESCARTAVEL"
```

Anote no registro de execução do roteiro: data, origem do backup, **tempo** da restauração e
o resultado da fumaça. O tempo anotado é a estimativa honesta de quanto o app fica fora do
ar num incidente real. Depois do ensaio, apague o projeto descartável: ele tem dado real.

### Restaurar de verdade

- **Restaurar o banco perde o que foi escrito depois.** Cadastros, pedidos, mensagens. Por
  isso a primeira opção, diante de uma migração problemática, é **corrigir para a frente**
  com uma migração nova; restaurar é o último recurso, e exige avisar quem perdeu dados.
- **Migração destrutiva = versão MAJOR.** `DROP`, `TRUNCATE`, `DELETE` em massa, remoção de
  valor permitido, troca de tipo com perda: o `CHANGELOG.md` registra, na seção do release,
  o que foi removido e qual é o último release para o qual o rollback é seguro.

---

## 5. Lock e tempo em tabela grande

Migração que trava a tabela por um minuto é indisponibilidade de um minuto, com o código
novo ou o antigo.

| Problema | Por quê | Faça assim |
| --- | --- | --- |
| `CREATE INDEX` bloqueia escrita durante a criação | lock que impede `INSERT`/`UPDATE` | `CREATE INDEX CONCURRENTLY`, **sozinho** num arquivo de migração |
| `CONCURRENTLY` dentro de transação | Postgres recusa: `CREATE INDEX CONCURRENTLY cannot run inside a transaction block` (testado em 17.11) | o CLI 2.120.0 já o executa fora do lote (seção 1); o que vem antes dele no arquivo não volta se ele falhar |
| `CONCURRENTLY` falhou no meio | o índice fica `INVALID` | `DROP INDEX CONCURRENTLY IF EXISTS ...` e rode de novo |
| `SET NOT NULL` varre a tabela com lock exclusivo | precisa provar que nenhuma linha é nula | `CHECK (...) NOT VALID` + `VALIDATE CONSTRAINT`, como no exemplo da seção 2 |
| `UPDATE` de backfill em milhões de linhas | uma transação gigante, lock longo, WAL enorme | lotes (`WHERE id BETWEEN ...`) em migrações ou script à parte |
| Migração espera um lock que outra consulta segura | e todas as consultas seguintes esperam atrás dela | `SET LOCAL lock_timeout = '5s';` na primeira linha: falha rápido em vez de enfileirar o app. A página de migrações do Supabase cita o erro de `lock_timeout` e sugere ajustá-lo no próprio arquivo |

```sql
-- supabase/migrations/20261103091500_indice_chamados_prazo.sql
create index concurrently if not exists idx_chamados_prazo_status
  on public.chamados (prazo_em, status);
```

Teste o tempo num projeto descartável com o dump de produção restaurado (seção 4), com o
volume real, antes de aplicar em produção. Migração que leva mais de alguns segundos ali vai
para a janela de menor uso, com aviso.

---

## 6. Casos de teste (R11)

Entram no roteiro de testes do projeto
([roteiro-de-testes-cowork.md](roteiro-de-testes-cowork.md) e
`assets/templates/roteiro-de-testes.template.md`, seção 4.2, com os mesmos IDs) sempre que
um release tiver migração. CT-MIG-010 é de exemplo, no `spec.template.md`.

| ID | Caso | Como verificar | Esperado |
| --- | --- | --- | --- |
| CT-MIG-001 | Banco vazio | `npx supabase db reset` num banco local vazio | todas aplicadas em ordem; cada uma uma vez em `supabase_migrations.schema_migrations` |
| CT-MIG-002 | Banco com dados | restaurar um dump de produção num projeto descartável e aplicar as migrações novas com `npx supabase db push` | aplicadas sem erro; contagem de linhas preservada |
| CT-MIG-003 | Nada pendente | `npx supabase db push --dry-run` depois de aplicar | nenhuma migração pendente; nada falha |
| CT-MIG-004 | Rollback do código | deployment **anterior**, ligado ao banco já migrado: rodar a suíte de fumaça | fumaça inteira passa |
| CT-MIG-005 | Falha no meio | migração com erro proposital, num banco local ou descartável | não registrada; nenhuma alteração pela metade; as seguintes não rodam |
| CT-MIG-006 | Arquivo aplicado editado | `git diff --name-status <tag-do-release-anterior> -- supabase/migrations/` | só linhas `A` (arquivo novo); nenhuma migração já aplicada foi editada (o CLI não acusaria) |
| CT-MIG-007 | Backup existe | antes de migrar produção | backup do dia existe (painel em *Database > Backups*, ou `supabase db dump` guardado fora); caminho de volta escrito |
| CT-MIG-008 | Preview isolado | criar registro no preview, procurar em produção (só leitura) | não aparece; produção não tem a migração nova em `supabase_migrations.schema_migrations` |
| CT-MIG-009 | Compatível com o release anterior | ler as migrações do release | nenhum `DROP`/`RENAME` de algo que a versão anterior usa |
| CT-MIG-011 | Restauração ensaiada (P14) | restaurar o último backup (ou o `supabase db dump`) num projeto descartável e rodar a suíte de fumaça contra ele | restaura sem erro, a fumaça passa, e o tempo da restauração fica anotado no registro de execução |

---

## 7. Checklist antes de promover para produção

```bash
npm run db:status                              # supabase migration list: Local x Remote
npm run db:migrate:check                       # supabase db push --dry-run
bash skills/development-pattern-for-web-apps/assets/scripts/scan-sql-injection.sh
```

- [ ] Cada mudança de schema é um arquivo novo em `supabase/migrations/`, criado por
      `supabase migration new`; nenhum arquivo já aplicado foi editado (CT-MIG-006).
- [ ] Toda tabela nova em `public` tem RLS ligada, grants explícitos e políticas no mesmo
      arquivo (P13).
- [ ] Cada migração é compatível com o código do release **anterior** (tabela da seção 2).
- [ ] Renomear, trocar tipo ou remover está dividido em expand → migrate → contract, e o
      contract vem num release posterior ao que parou de usar o objeto.
- [ ] Migração destrutiva: versão MAJOR, `CHANGELOG.md` diz até qual release o rollback é seguro.
- [ ] Preview usa Supabase Branching ou projeto separado; nenhum preview aponta para o banco
      de produção (CT-MIG-008).
- [ ] Backup do dia conferido, ou `supabase db dump` feito imediatamente antes, guardado
      fora do Git (CT-MIG-007).
- [ ] A restauração foi ensaiada nos últimos três meses, com o tempo anotado (P14, CT-MIG-011).
- [ ] Migração aplicada **antes** de `vercel promote` (ou no build, se não destrutiva).
- [ ] Índice em tabela grande com `CONCURRENTLY`, sozinho no arquivo.
- [ ] Tempo da migração medido num projeto descartável com volume real.
- [ ] Casos CT-MIG do release executados e registrados no roteiro de testes.
- [ ] Caminho de volta escrito no PR: qual deployment promover e se o banco precisa de algo.
