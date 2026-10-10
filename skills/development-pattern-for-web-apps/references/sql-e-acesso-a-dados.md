# SQL e acesso a dados: o dado nunca vira comando

> Regra **R5**. É a falha mais grave que um projeto pessoal pode cometer, porque as
> consequências não são suas: são dos usuários cujos dados estavam no banco.
> Um XSS afeta uma sessão. Um SQL injection afeta a base inteira.

Stack deste padrão: Next.js (App Router) na Vercel, **Supabase** (Postgres) contratado pelo
Marketplace da Vercel. Versões conferidas em 2026-10-10: `@supabase/supabase-js` 2.117.3
(com `@supabase/postgrest-js` 2.117.3), `@supabase/ssr` 0.12.7, `postgres` 3.4.9,
`drizzle-orm` 0.45.4, `@prisma/client` 7.10.0. Os comportamentos de banco foram testados em
Postgres 17.11 e, os da API REST, em PostgREST 16.4 (imagens oficiais do Docker), com um
schema `auth` mínimo no lugar do Supabase real.

---

## 1. O modelo mental correto

Um comando SQL tem duas partes que **nunca** devem se misturar:

| Parte | O que é | De onde pode vir |
| --- | --- | --- |
| **Estrutura** | `SELECT`, nomes de tabela e coluna, `JOIN`, `ORDER BY`, `ASC`/`DESC`, e no Supabase a **string de filtro** do PostgREST | Só do seu código, ou de uma **allowlist** que o seu código controla |
| **Dado** | valores comparados, inseridos, atualizados | Do usuário, e sempre por **parâmetro vinculado** (`$1`, `$2`…) ou **argumento de método tipado** (`.eq(coluna, valor)`) |

Toda vulnerabilidade de SQL injection é a mesma história: um dado atravessou para o lado da
estrutura. A defesa não é "escapar melhor". É **nunca deixar atravessar**.

Escapar aspas à mão (`replace(/'/g, "''")`) **não é a defesa**. É remendo que falha em
contexto numérico, em `LIKE`, em identificador e quando alguém esquece de chamá-lo uma vez.
Parâmetro vinculado não falha nesses casos porque o dado nunca é interpretado como SQL.

---

## 2. As duas vias de acesso, ambas só no servidor

Toda consulta roda **no servidor** (Server Component, Route Handler ou Server Action), e as
duas vias moram em `lib/db.ts`. Copie de
[`../assets/templates/db.ts.template`](../assets/templates/db.ts.template); os clientes do
Supabase vêm de `lib/supabase/server.ts` (`supabase-server.ts.template`).

| Via | Quando usar | Quem autoriza | Variáveis |
| --- | --- | --- | --- |
| **1. Cliente do Supabase**, `criarClienteServidor()` | **Padrão**: toda leitura e escrita feita em nome do usuário logado | A **RLS**, porque o cliente leva o token do usuário, **e** o filtro por dono no seu código | `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` |
| **2. SQL direto**, driver `postgres` | Relatório que cruza usuários, limite de taxa, transação com lógica no meio, scripts | **Só a sua consulta**: a conexão usa o papel dono do banco, que **não passa pela RLS** | `POSTGRES_URL` |
| Cliente admin, `criarClienteAdmin()` | Tarefa administrativa: seed, exclusão de conta | **Ninguém**: a chave secret usa o papel `service_role`, com `BYPASSRLS` | `SUPABASE_SECRET_KEY` |

As variáveis são criadas pela integração Supabase da Vercel
([vercel.com/marketplace/supabase](https://vercel.com/marketplace/supabase)). A via 2 e o
cliente admin ignoram a RLS: a documentação do Supabase diz que uma função criada "by a
migration is owned by postgres, which bypasses Row Level Security"
([supabase.com/docs/guides/database/functions](https://supabase.com/docs/guides/database/functions)),
e que "A secret key authorizes access through the `service_role` Postgres role, which has
the `bypassrls` attribute"
([supabase.com/docs/guides/database/postgres/row-level-security](https://supabase.com/docs/guides/database/postgres/row-level-security)).

```ts
import 'server-only';                       // import a partir de Client Component = erro de build
import postgres from 'postgres';
import { criarClienteServidor } from '@/lib/supabase/server';

// Via 2. prepare: false porque o pooler em modo transação não aceita prepared statements.
export const sql = postgres(process.env.POSTGRES_URL!, { prepare: false });   // lib/env.ts validou (R9)
```

Fatos da conexão direta
([supabase.com/docs/guides/database/connecting-to-postgres](https://supabase.com/docs/guides/database/connecting-to-postgres)
e [/postgres-js](https://supabase.com/docs/guides/database/postgres-js), conferidos em
2026-10-10): o pooler em modo transação é o indicado "for serverless and edge functions";
"Transaction mode does not support prepared statements", daí o `prepare: false`; e o
`postgres.js` faz pipelining por padrão, o que, no pooler em modo transação, "can hang
queries or return mismatched rows". Por precaução, não dispare várias consultas em paralelo
(`Promise.all`) por esta via.

`@vercel/postgres` está **depreciado** (o próprio `npm view` avisa): não use em projeto novo.

---

## 3. Via 1: o cliente do Supabase

Os métodos tipados do `@supabase/postgrest-js` levam o valor **separado** da coluna. O
`.eq()` grava `coluna=eq.<valor>` num parâmetro próprio da URL (`dist/index.mjs`, linha
1541): uma vírgula no valor continua sendo valor.

```ts
// ✅ Métodos tipados: cada valor é argumento, não texto de filtro.
const { data, error } = await supabase
  .from('chamados')
  .select('id, titulo, status')
  .eq('usuario_id', usuarioId)                       // da sessão, nunca da URL (R7)
  .eq('status', status)
  .ilike('titulo', `%${escaparLike(busca)}%`)        // o padrão é UM valor
  .in('id', ids)                                     // array como valor
  .order(coluna, { ascending: false })               // coluna da allowlist (seção 5)
  .range(inicio, inicio + 19);
```

Testado contra PostgREST 16.4: `.eq('status', 'aberto,fechado')` devolve `[]` (procura o
status literal "aberto,fechado"), e não "aberto ou fechado".

### A armadilha: `.or()`, `.filter()` e `.not()` recebem texto

A própria documentação do pacote avisa, em `dist/index.d.cts`: em `.or()` (linha 3180),
"Unlike most filters, `filters` is used as-is and needs to follow PostgREST syntax. You also
need to make sure it's properly sanitized."; em `.filter()` e `.not()` (linhas 3339 e 3161),
o mesmo para `operator` e `value`. A implementação é uma linha: `` `(${filters})` `` vai
para a URL (`dist/index.mjs`, linha 2002). Vírgula separa condições e parêntese agrupa
([sintaxe do PostgREST](https://docs.postgrest.org/en/stable/references/api/tables_views.html)).

```ts
// ❌ A busca do usuário vira estrutura do filtro.
await supabase.from('chamados').select('titulo')
  .or(`titulo.ilike.%${busca}%,descricao.ilike.%${busca}%`);
// busca = "zzz%,id.gt.0,titulo.ilike.%zzz"  →  or=(titulo.ilike.%zzz%,id.gt.0,...)
```

Testado em 2026-10-10 contra PostgREST 16.4: com o token do usuário A, essa busca devolveu
**todos** os chamados de A, não os que tinham "zzz"; com o papel `service_role`, devolveu
também o chamado de B. A RLS limitou o estrago ao que A já podia ver. Com a chave secret,
não há limite nenhum.

```ts
// ✅ A mesma busca com métodos tipados. Dois campos? Duas consultas, ou uma função SQL.
await supabase.from('chamados').select('titulo')
  .ilike('titulo', `%${escaparLike(busca)}%`);

// ✅ .or() só com texto fixo do seu código: nenhum dado do usuário dentro.
await supabase.from('chamados').select('titulo').or('status.eq.aberto,status.eq.andamento');
```

Um `.eq()` antes do `.or()` continua valendo (os filtros se somam com E), mas não conte com
isso como defesa: a próxima pessoa a mexer no código tira o `.eq()`.

### `escaparLike`: o curinga também é entrada

O valor de `.ilike()` é um **padrão**: `%` e `_` do usuário viram curingas, e o PostgREST
ainda troca **todo** `*` por `%` (código-fonte, `src/library/PostgREST/Query/SqlFragment.hs`,
função `star`: `if c == '*' then '%'`). Isso não derruba o banco, mas transforma
`buscar("%")` numa listagem de tudo e permite enumeração. O SKILL.md usa este helper; ele
mora em `lib/db.ts`:

```ts
/** Escapa \, % e _ para busca literal. O `*` não tem como ser literal no PostgREST: vira `_`. */
export function escaparLike(termo: string): string {
  return termo.replace(/[\\%_]/g, (c) => `\\${c}`).replace(/\*/g, '_');
}
```

O padrão chega ao Postgres como parâmetro, e o `LIKE` do Postgres usa `\` como escape por
padrão. Testado contra PostgREST 16.4:

| Termo | `.ilike` cru | `.ilike` com `escaparLike` |
| --- | --- | --- |
| `100%` | "100% pronto" e "100 pronto" | só "100% pronto" |
| `a_b` | "a_b", "axb", "a*b" | só "a_b" |
| `a*b` | "a_b", "axb", "a*b" | os três (o `*` virou `_`, um caractere qualquer) |

Busca que precisa tratar `*` como texto vai por função SQL (abaixo), onde o `*` não tem
significado especial.

### `.textSearch()`: use `type: 'websearch'` com entrada crua

O `.d.ts` (linha 3086) diz que o tipo `websearch` usa `websearch_to_tsquery`, que "will
never raise syntax errors, which makes it possible to use raw user-supplied input". Os
outros tipos esperam sintaxe de `tsquery`: entrada crua gera erro, e erro devolvido ao
usuário vaza estrutura (seção 9).

```ts
// ✅
await supabase.from('chamados').select('id, titulo')
  .textSearch('titulo', busca, { type: 'websearch', config: 'portuguese' });
```

### `.rpc()`: a função SQL é onde a concatenação se esconde

`supabase.rpc('nome', { argumento })` chama uma função do schema `public`. Os argumentos
vão como JSON, separados do comando: a chamada é segura. O risco está **dentro** da função.

```sql
-- ❌ EXECUTE com texto montado: o argumento vira comando.
create or replace function public.buscar_ruim(termo text) returns setof public.chamados
language plpgsql as $$
begin
  return query execute 'select * from public.chamados where titulo ilike ''%' || termo || '%''';
end $$;
```

```sql
-- ✅ Sem EXECUTE: o argumento é parâmetro da consulta (schema.sql.template, buscar_chamados).
create or replace function public.buscar_chamados(termo text)
returns table (id bigint, titulo text, status text, prioridade smallint,
               usuario_id uuid, criado_em timestamptz)
language sql stable set search_path = ''
as $$
  select c.id, c.titulo, c.status, c.prioridade, c.usuario_id, c.criado_em
  from public.chamados as c
  where c.titulo ilike
        '%' || replace(replace(replace(termo, '\', '\\'), '%', '\%'), '_', '\_') || '%'
        escape '\'
  order by c.criado_em desc
  limit 50;
$$;

-- ✅ Se EXECUTE for inevitável: format() com %I (identificador) e %L (literal), ou USING.
return query execute format('select id from public.chamados where %I = $1', coluna_da_allowlist)
  using valor;
```

Testado via `.rpc('buscar_chamados', { termo: '100%' })`: só "100% pronto"; com `a_b`, só
"a_b"; chamada sem login: `permission denied for function buscar_chamados`.

**`security invoker` (o padrão) ou `security definer`.** "Postgres runs a function either
as the user calling it (invoker) or as its creator (definer)", e a recomendação é "Prefer
security invoker, which is also the default"
([supabase.com/docs/guides/database/functions](https://supabase.com/docs/guides/database/functions)).
Invoker respeita a RLS de quem chama. Definer roda como o dono e **ignora a RLS**; use só
quando a função precisa fazer algo que o usuário não pode fazer direto (gravar auditoria,
por exemplo), e então três obrigações:

| Obrigação | Por quê | Fonte |
| --- | --- | --- |
| `set search_path = ''` e todo nome qualificado (`public.chamados`) | Sem isso, quem controla o `search_path` troca o que `chamados` significa dentro de uma função que roda com privilégio de dono | "When you use security definer, you must set the search_path." (página de funções) |
| Conferir `auth.uid()` **dentro** da função | O grant decide quem chama, não quais linhas a pessoa recebe | "Grants don't limit which rows a permitted role receives, so the function body should check ownership" (mesma página) |
| `revoke execute ... from public, anon` e `grant execute ... to authenticated` | Por padrão, "any role can run a database function"; e "A `security definer` function in an exposed schema is callable over the Data API with the creator's privileges" | páginas de funções e de RLS |

```sql
-- ✅ schema.sql.template, fechar_chamado: definer, search_path vazio, dono conferido.
create or replace function public.fechar_chamado(p_chamado_id bigint)
returns void language plpgsql security definer set search_path = ''
as $$
declare v_usuario uuid := auth.uid();
begin
  if v_usuario is null then raise exception 'não autenticado' using errcode = '42501'; end if;
  update public.chamados set status = 'fechado'
   where id = p_chamado_id and usuario_id = v_usuario;
  if not found then raise exception 'chamado não encontrado' using errcode = 'P0002'; end if;
  insert into public.auditoria (usuario_id, acao, alvo)
  values (v_usuario, 'chamado.fechar', p_chamado_id::text);
end;
$$;
```

Testado: A tentando fechar o chamado de B recebe "chamado não encontrado" e nada muda; sem
login, `permission denied`; A fechando o próprio grava o status e a linha de auditoria na
mesma transação.

### Erros que o cliente devolve

O cliente devolve `{ data, error }` em vez de lançar. `error.message` traz o texto do
Postgres ("new row violates row-level security policy for table \"chamados\""): registre
no log e devolva mensagem genérica (seção 9). E confira `error` **sempre**: um `.select()`
bloqueado pela RLS devolve `[]` sem erro, e um `.update()` em linha alheia também. Para a
tela, "nenhuma linha" e "não é sua" têm de parecer a mesma coisa.

---

## 4. Via 2: SQL direto com o driver `postgres`

```ts
// ✅ Template tag: cada ${} vira parâmetro vinculado ($1, $2…), não texto.
const pedidos = await sql`SELECT id, total FROM public.pedidos WHERE cliente_id = ${id}`;

// ✅ unsafe() com placeholders: o texto é fixo, os dados vão no segundo argumento
//    (types/index.d.ts, linha 691: unsafe(query, parameters?)).
const outros = await sql.unsafe('SELECT id, total FROM public.pedidos WHERE cliente_id = $1', [id]);
```

```ts
// ❌ Concatenação disfarçada de template. O `${}` é resolvido pelo JavaScript ANTES
//    da chamada: a função recebe uma string pronta, com o dado dentro do comando.
await sql.unsafe(`SELECT id FROM public.pedidos WHERE cliente_id = '${id}'`);
```

A diferença é fatal: `` sql`...${x}...` `` (tag, sem parênteses) parametriza;
`` sql.unsafe(`...${x}...`) `` (template literal **dentro** de parênteses) concatena. O
mesmo vale para `pool.query`, `client.query` e qualquer `raw`. O README do pacote diz do
`unsafe`: "this can lead to SQL injection if you're not careful".

**Esta via não passa pela RLS.** Conecta como o dono do banco. Toda consulta que serve a um
usuário filtra pelo dono **no texto da consulta**, com o id vindo da sessão; toda consulta
que cruza usuários só roda depois de o servidor conferir que a sessão é de admin
(`app_metadata.papel`, lido de `getClaims()`). Testado: a mesma tabela que devolve 6 linhas
ao usuário A pela API devolve 7 por esta conexão.

`bigint` chega como **string** por esta via: "Postgres.js will return it as a string"
(README, seção "Numbers, bigint, numeric"). Pela API do Supabase, chega como número no JSON.
`timestamptz` chega como `Date` aqui e como texto ISO pela API.

---

## 5. As formas corretas, caso a caso

Cada exemplo tem a versão das duas vias. Os de SQL direto foram executados contra Postgres
17.11 com o `postgres` 3.4.9; os do cliente, contra PostgREST 16.4 com o
`@supabase/postgrest-js` 2.117.3.

### Inserção, com o id de volta

```ts
// ✅ Via 1. usuario_id NÃO vai no insert: o default auth.uid() preenche, e a política
//    de INSERT recusa outro dono (testado: "new row violates row-level security policy").
const { data, error } = await supabase
  .from('chamados').insert({ titulo, descricao: descricao ?? null }).select('id').single();

// ✅ Via 2. Aqui não há auth.uid(): o dono vai explícito, vindo da sessão.
const [{ id: novoId }] = await sql`
  INSERT INTO public.chamados (titulo, descricao, usuario_id)
  VALUES (${titulo}, ${descricao ?? null}, ${usuarioId})
  RETURNING id
`;
```

### `LIKE`/`ILIKE`

```ts
// ❌ O termo do usuário vira padrão: "%" lista tudo, "a_b" casa "axb".
await sql`SELECT id, titulo FROM public.chamados WHERE titulo ILIKE ${'%' + termo + '%'}`;
```

```ts
// ✅ Via 2: escaparLike no valor; ESCAPE '\' diz ao Postgres qual é o escape.
const padrao = `%${escaparLike(termo)}%`;
await sql`
  SELECT id, titulo FROM public.chamados
  WHERE usuario_id = ${usuarioId} AND titulo ILIKE ${padrao} ESCAPE '\\'
  LIMIT 50
`;
```

O `'\\'` dentro do template vira `'\'` no SQL (o driver usa as strings já interpretadas).
Testado: `buscar("100%")` acha só "100% pronto", não "100 pronto". Pela via 1, é o
`.ilike()` com `escaparLike` da seção 3.

### `IN (...)`, o array inteiro como um parâmetro

```ts
// ❌ O erro clássico: os valores entram no texto.
await sql.unsafe(`SELECT id, titulo FROM public.chamados WHERE id IN (${ids.join(',')})`);
```

```ts
// ✅ Via 1: .in() leva o array como valor.
await supabase.from('chamados').select('id, titulo').in('id', validos);

// ✅ Via 2: um único parâmetro do tipo array.
const validos = ids.filter((id) => /^\d{1,18}$/.test(id));
if (validos.length === 0) return [];
await sql`
  SELECT id, titulo FROM public.chamados
  WHERE usuario_id = ${usuarioId} AND id = ANY(${validos}::bigint[])
`;
```

O texto da query fica `id = ANY($2::bigint[])` com qualquer quantidade de ids: nada do
usuário chega ao comando, e o plano da consulta não muda com o tamanho da lista.

### `ORDER BY` dinâmico e paginação: allowlist, sempre

```ts
// ❌ A coluna vem direto da URL.
await sql.unsafe(`SELECT id, titulo FROM public.chamados ORDER BY ${searchParams.ordenar}`);
await supabase.from('chamados').select('id, titulo').order(searchParams.ordenar);
```

O `.order()` também põe o nome como está na URL (`dist/index.mjs`, linha 905): com a
coluna crua, o usuário ordena por qualquer coluna que o `select` alcance, ou acrescenta
critérios com vírgula.

```ts
// ✅ O que o usuário manda é uma CHAVE do mapa. Fora do mapa, cai no padrão.
const COLUNAS_ORDENAVEIS = {
  titulo: 'titulo',
  data: 'criado_em',
  prioridade: 'prioridade',
} as const;

const coluna = COLUNAS_ORDENAVEIS[ordenar as keyof typeof COLUNAS_ORDENAVEIS] ?? 'criado_em';
const ascendente = direcao === 'asc';
const porPagina = 20;
const inicio = (Math.max(1, Math.min(500, Math.trunc(pagina) || 1)) - 1) * porPagina;

// Via 1
await supabase.from('chamados').select('id, titulo, status, criado_em')
  .eq('usuario_id', usuarioId)
  .order(coluna, { ascending: ascendente })
  .order('id', { ascending: ascendente })            // desempate: paginação estável
  .range(inicio, inicio + porPagina - 1);

// Via 2: sql(coluna) cita o identificador; a direção é um fragmento escrito por você.
await sql`
  SELECT id, titulo, status, criado_em FROM public.chamados
  WHERE usuario_id = ${usuarioId}
  ORDER BY ${sql(coluna)} ${ascendente ? sql`ASC` : sql`DESC`}, id
  LIMIT ${porPagina} OFFSET ${inicio}
`;
```

O `sql(coluna)` e os fragmentos `` sql`ASC` `` são do README do `postgres` ("Dynamic
ordering"): nada de `unsafe`. O helper impede injeção, não impede ordenar por uma coluna
que você não queria expor: por isso `coluna` sai da allowlist mesmo assim.

### Filtros opcionais

```ts
// ❌ Montar o WHERE colando strings.
let where = 'WHERE 1=1';
if (status) where += ` AND status = '${status}'`;
await sql.unsafe(`SELECT id, titulo FROM public.chamados ${where}`);
```

```ts
// ✅ Via 1: o filtro só entra se o valor estiver na allowlist.
let consulta = supabase.from('chamados').select('id, titulo').eq('usuario_id', usuarioId);
if (STATUS_VALIDOS.includes(status as Status)) consulta = consulta.eq('status', status as Status);

// ✅ Via 2: texto fixo; o valor nulo faz a condição sempre verdadeira.
const filtro = STATUS_VALIDOS.includes(status as Status) ? status : null;
await sql`
  SELECT id, titulo FROM public.chamados
  WHERE usuario_id = ${usuarioId}
    AND (${filtro}::text IS NULL OR status = ${filtro})
  ORDER BY criado_em DESC
`;
```

O `postgres` também compõe fragmentos: um `` sql`AND status = ${x}` `` dentro de outro
`` sql`...` `` continua parametrizado. Fragmento **escrito por você**, nunca string vinda da
requisição.

### Transações: tudo ou nada

Pela via 1, cada chamada é uma requisição HTTP: duas escritas que precisam ser atômicas vão
para **uma função SQL** chamada por `.rpc()` (o corpo de uma função roda numa transação só),
como `fechar_chamado` acima.

Pela via 2, `sql.begin()` reserva uma conexão e faz `COMMIT` ou `ROLLBACK` sozinho
(`types/index.d.ts`, linha 717):

```ts
// ✅ Interativa: ler, decidir, escrever, na mesma transação.
await sql.begin(async (tx) => {
  const [conta] = await tx`SELECT saldo FROM public.contas WHERE id = ${de} FOR UPDATE`;
  if (Number(conta.saldo) < valor) throw new Error('saldo insuficiente'); // vira ROLLBACK
  await tx`UPDATE public.contas SET saldo = saldo - ${valor} WHERE id = ${de}`;
  await tx`UPDATE public.contas SET saldo = saldo + ${valor} WHERE id = ${para}`;
});
```

A documentação do Supabase avisa que `max_pipeline: 0`, uma tentativa comum de desligar o
pipelining, "breaks `sql.begin()` transactions": não use.

---

## 6. Query builders e ORMs: as duas fugas

O query builder já parametriza. O risco está nas portas de saída para SQL cru. Ambos
conectam pela via 2 (`POSTGRES_URL` ou `POSTGRES_PRISMA_URL`), portanto **fora da RLS**.

### Prisma (`@prisma/client` 7.10.0, `runtime/client.d.ts`, linhas 212 a 216)

```ts
// ❌ "Unsafe" no nome: o template literal vira texto antes de chegar ao Prisma.
await prisma.$queryRawUnsafe(`SELECT * FROM chamados WHERE id = ${id}`);
```

```ts
// ✅ Tag: parametrizado.
await prisma.$queryRaw`SELECT id, titulo FROM chamados WHERE id = ${id}`;
// ✅ Unsafe só com placeholders e valores separados, se for inevitável.
await prisma.$queryRawUnsafe('SELECT id, titulo FROM chamados WHERE id = $1', id);
```

O mesmo par vale para `$executeRaw` / `$executeRawUnsafe`. Em modo transação do pooler, a
documentação do Supabase manda o Prisma usar `pgbouncer=true` na URL.

### Drizzle (`drizzle-orm` 0.45.4, `sql/sql.d.ts`, linhas 142 a 178)

```ts
import { sql } from 'drizzle-orm';

// ❌ sql.raw() injeta o texto como está.
await db.execute(sql.raw(`SELECT * FROM chamados WHERE titulo = '${titulo}'`));
```

```ts
// ✅ A tag do Drizzle parametriza; sql.identifier() cita nome de coluna/tabela.
await db.execute(sql`SELECT id, titulo FROM chamados WHERE titulo = ${titulo}`);
await db.execute(sql`SELECT id FROM chamados ORDER BY ${sql.identifier(coluna)}`); // coluna da allowlist
```

---

## 7. Row Level Security: a camada que segura o que escapar

> Piso **P13**: **RLS ligada em toda tabela do schema `public`, com política por dono.**

A chave publishable (`sb_publishable_…`) vai para o navegador de propósito. Com ela,
qualquer pessoa chama a API REST do Supabase direto, sem passar pelo seu app, e a única
coisa entre ela e a tabela inteira é a RLS: "A table in an exposed schema without RLS is
readable and writable by any role with a grant on it"
([supabase.com/docs/guides/database/postgres/row-level-security](https://supabase.com/docs/guides/database/postgres/row-level-security),
conferido em 2026-10-10). E os grants existem: em projetos existentes, "tables created in
`public` receive `SELECT`, `INSERT`, `UPDATE`, and `DELETE` privileges" para `anon`,
`authenticated` e `service_role`
([supabase.com/docs/guides/api/securing-your-api](https://supabase.com/docs/guides/api/securing-your-api)).

O arquivo completo está em
[`../assets/templates/politicas-rls.sql.template`](../assets/templates/politicas-rls.sql.template).
As regras dele:

| Regra | Por quê | Fonte |
| --- | --- | --- |
| `alter table ... enable row level security` **na mesma migração** que cria a tabela | Sem política, a RLS nega tudo: não existe instante em que a tabela fica aberta. "RLS with no policies denies every request" | connecting-to-postgres |
| Grants explícitos: `revoke all ... from anon, authenticated`, depois `grant` só do necessário | Não depender do padrão do projeto, que o próprio Supabase planeja mudar | securing-your-api |
| Toda política com `to authenticated` | "Always name the role a policy applies to, using the `to` clause." | página de RLS |
| `(select auth.uid()) = usuario_id`, nunca `auth.uid() = usuario_id` | "Wrapping the function causes an `initPlan` to be run by the Postgres optimizer, which allows it to "cache" the results per-statement" | página de RLS |
| Índice com a coluna da política em primeiro | "Add an index on every column your policies filter on." | página de RLS |
| `UPDATE` com `using` **e** `with check` | `using` "decides which existing rows can be updated"; `with check` "decides what the resulting row is allowed to look like". Sem o segundo, o dono troca o `usuario_id` e "doa" a linha | página de RLS |
| Papel de admin em `app_metadata`, nunca em `user_metadata` | "creating an RLS policy that relies on the `user_metadata` claim can create security issues", porque o próprio usuário edita | página de RLS |
| View com `security_invoker = true` | "Views bypass RLS by default because they are usually created with the `postgres` user." | página de RLS |

```sql
-- ✅ Trecho de politicas-rls.sql.template
alter table public.chamados enable row level security;

drop policy if exists chamados_update_dono on public.chamados;
create policy chamados_update_dono on public.chamados
  for update to authenticated
  using ((select auth.uid()) = usuario_id)
  with check ((select auth.uid()) = usuario_id);

drop policy if exists chamados_select_admin on public.chamados;
create policy chamados_select_admin on public.chamados
  for select to authenticated
  using (((select auth.jwt()) -> 'app_metadata' ->> 'papel') = 'admin');
```

```sql
-- ❌ Três erros comuns numa política só.
create policy ruim on public.chamados
  for update                                                  -- sem "to": vale para anon também
  using (auth.uid() = usuario_id                              -- sem (select ...): avaliado por linha
         or (auth.jwt() -> 'user_metadata' ->> 'papel') = 'admin');  -- o usuário se promove
                                                              -- sem "with check": doa a linha
```

**O que foi testado** (Postgres 17.11 + PostgREST 16.4, `schema.sql.template` e
`politicas-rls.sql.template` aplicados duas vezes, 2026-10-10):

| Tentativa | Resultado |
| --- | --- |
| Sem login, `GET` em cada uma das seis tabelas (CT-SEC-031) | `401 permission denied` em todas, nenhuma linha |
| A lê, altera (`PATCH`) e apaga (`DELETE`) o chamado de B pelo id (CT-SEC-032) | `200 []` nas três; a linha de B continua igual |
| A troca o `usuario_id` do próprio chamado para o de B | `403 new row violates row-level security policy` |
| A insere chamado em nome de B | `403`, mesma mensagem |
| A insere sem mandar `usuario_id` | `201`, dono preenchido com o id de A |
| A registra anexo no chamado de B | `403` |
| B com `user_metadata.papel = 'admin'` | vê só os próprios chamados; auditoria vazia |
| Admin com `app_metadata.papel = 'admin'` | vê todos os chamados |
| A muda a própria coluna `papel` | `403 permission denied` (o grant libera só `nome`) |
| A lê `eventos_limite` (RLS sem política) | `403` |
| Storage: A lê, grava e renomeia na pasta de B | 0 objetos visíveis; gravação recusada pela política; nada alterado |
| Excluir o usuário A em `auth.users` | perfil, chamados e anexos de A apagados em cascata; auditoria de A fica com `usuario_id` nulo |

Os testes usaram um schema `auth` mínimo, que imita `auth.uid()` e `auth.jwt()` lendo
`request.jwt.claims` como o Supabase faz. Repita CT-SEC-031 e CT-SEC-032 contra o projeto
real, com `curl` (comandos no fim de `politicas-rls.sql.template`), antes do primeiro
lançamento.

**A RLS não substitui a checagem no servidor, e vice-versa (R7).** O servidor confere a
sessão e filtra pelo dono; a RLS segura quando o servidor erra, e segura quem nem passa
pelo servidor.

---

## 8. Menos privilégio no próprio banco

No Supabase, os papéis já vêm separados. O trabalho é **usar cada um para o que é**.

| Papel | Como o app chega nele | Pode | Onde fica a credencial |
| --- | --- | --- | --- |
| `anon` | Chave publishable, sem login | Nada, neste padrão: nenhum grant, nenhuma política | Navegador (é pública) |
| `authenticated` | Chave publishable + token do usuário logado | O que os grants e as políticas da seção 7 deixam | Navegador e servidor |
| `service_role` | Chave secret (`sb_secret_…`) | Tudo, com `BYPASSRLS` | Só no servidor, `SUPABASE_SECRET_KEY`, nunca com `NEXT_PUBLIC_` |
| `postgres` (dono) | `POSTGRES_URL` | Tudo, inclusive DDL; dono das tabelas, fora da RLS | Só no servidor e no CLI de migração |

- **Runtime não emite DDL.** Nenhuma rota, action ou função cria, altera ou apaga tabela;
  estrutura muda só por migração ([migracoes-e-rollback.md](migracoes-e-rollback.md)).
- **A chave secret é exceção, não atalho.** "A secret key bypasses RLS only when the request
  carries no user access token" (página de RLS): ela existe para seed e exclusão de conta.
  Usar a secret para "fazer a consulta funcionar" é desligar a RLS
  ([checklist-de-revisao.md](checklist-de-revisao.md), "Proteções desligadas").
- **Tabela ou função nova nasce fechada.** O `politicas-rls.sql.template` revoga os
  privilégios padrão (`alter default privileges ... revoke`), como recomenda a página
  securing-your-api: o que for criado depois só fica acessível com `grant` explícito na
  mesma migração.
- **Um papel próprio com menos poder que `postgres` para a via 2** é possível
  (`create role ... login`, `grant select, insert ...`), mas a documentação conferida não
  descreve como o pooler do Supabase autentica papéis criados por SQL. Se precisar disso,
  confira no painel e na documentação do seu plano antes de prometer ao usuário; se não
  der, **diga isso** em vez de fingir que o modelo foi seguido, e compense mantendo a via 2
  mínima e revisada linha a linha.

---

## 9. Convenções de schema deste padrão

Arquivo completo em [`../assets/templates/schema.sql.template`](../assets/templates/schema.sql.template).

```sql
create table if not exists public.chamados (
  id            bigint      generated always as identity primary key,
  titulo        text        not null check (char_length(titulo) between 1 and 200),
  descricao     text,
  status        text        not null default 'aberto'
                            check (status in ('aberto', 'andamento', 'fechado')),
  prioridade    smallint    not null default 3 check (prioridade between 1 and 5),
  usuario_id    uuid        not null default auth.uid()
                            references public.perfis (id) on delete cascade,
  criado_em     timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
alter table public.chamados enable row level security;
create index if not exists idx_chamados_usuario_data on public.chamados (usuario_id, criado_em);
```

- **Usuário é `auth.users`.** O app não guarda senha nem token de recuperação: quem guarda
  é o Supabase Auth. O que o app sabe da pessoa fica em `public.perfis`, com o mesmo `uuid`,
  criado por um gatilho em `auth.users`. Cascata `auth.users → perfis → chamados → anexos`:
  excluir a conta no Auth apaga o que é do titular no banco.
- **`generated always as identity`**, não `serial`: o id não aceita valor manual por engano.
- **`text` + `check`** para tamanho e domínio fechado. Acrescentar um status depois é trocar
  a constraint, sem `alter type` de enum.
- **`timestamptz`, sempre.** Guarda o instante; o fuso de exibição é decisão da interface.
- **Chave estrangeira declarada**, não "garantida pela aplicação".
- **Índice em toda coluna usada em `where`, `join`, `order by` ou política RLS.** Sem isso,
  a listagem fica rápida com 200 registros e inutilizável com 200 mil. Postgres **não** cria
  índice sozinho na coluna da chave estrangeira.
- **`numeric(12,2)` para dinheiro**, jamais `real`/`double precision`. Chega ao JavaScript
  como string pelo driver; converta com cuidado ou some no banco.
- **`atualizado_em` por gatilho**: Postgres não tem `ON UPDATE CURRENT_TIMESTAMP`.
- **Função com `set search_path = ''`**, inclusive as de gatilho.
- **Nada de `select *` nem `.select()` sem colunas em código de produção.** Liste as
  colunas: assim uma coluna nova não vaza para uma tela.

Toda mudança de schema depois da primeira é uma migração versionada, compatível com o
código anterior: [migracoes-e-rollback.md](migracoes-e-rollback.md) (R10).

---

## 10. Tratamento de erro que não vaza estrutura

```ts
// ❌ A mensagem do Postgres vai para a tela.
const { error } = await supabase.from('chamados').insert(dados);
if (error) return { erro: error.message };   // "new row violates row-level security policy for table \"chamados\""
```

```ts
// ✅ Detalhe no log (Vercel Logs), mensagem genérica para o usuário.
if (error) {
  console.error('[db] inserirChamado', error);
  return { erro: 'Não foi possível concluir a operação.' };
}
```

Mensagem de erro do banco na tela entrega nome de tabela, nome de coluna, nome de política
e às vezes o SQL inteiro: é reconhecimento gratuito para quem está sondando. Em produção, o
Next.js já substitui a mensagem de erro de Server Component por uma genérica com `digest`;
o que **você** devolve de uma Server Action ou de um Route Handler não passa por esse filtro.

---

## 11. A única interpolação aceita, e como declará-la

Identificador (coluna, tabela, `ASC`/`DESC`) não pode ser parametrizado: é limitação do
protocolo, não escolha de estilo. A allowlist é a defesa. Com `sql(coluna)` do `postgres`
e `.order(coluna)` do Supabase, a interpolação nem aparece no texto. Quando aparecer (um
`unsafe` inevitável), o scanner **exige que ela seja declarada**:

```ts
// scan-sql:allow: coluna e dir saem de COLUNAS_ORDENAVEIS e de um ternário deste arquivo
const linhas = await sql.unsafe(`SELECT id, titulo FROM public.chamados ORDER BY ${coluna} ${dir} LIMIT $1`, [porPagina]);
```

O marcador vale na própria linha **ou na linha imediatamente acima**: é ali que cabe
escrever a justificativa por extenso.

Sem o marcador, `scan-sql-injection.sh` acusa a linha e o commit para. Isso é intencional:
**toda** interpolação em SQL passa a exigir uma justificativa escrita que o revisor lê ao
lado do código. Uma linha com o marcador e sem allowlist real é uma mentira visível em
revisão, o que é muito melhor do que uma concatenação silenciosa.

Antes de escrever o marcador, responda: *este valor pode ser qualquer coisa que o usuário
digitar?* Se puder, não é allowlist: é injeção, e o marcador não conserta.

### As interpolações legítimas, e só elas

| Caso | Por que é seguro | Condição |
| --- | --- | --- |
| Coluna / tabela / `ASC`\|`DESC` dinâmicos | O valor do usuário é uma **chave** de um mapa do seu código | O mapa é constante e tem valor padrão |
| Texto de `.or()` montado só com constantes do código | Nenhum dado do usuário entra na string de filtro | Sem `${}` com valor da requisição; se houver, é o caso ❌ da seção 3 |

Qualquer outro caso é concatenação, e concatenação é injeção esperando acontecer.

---

## 12. Checklist antes do push

```bash
bash skills/development-pattern-for-web-apps/assets/scripts/scan-sql-injection.sh
```

- [ ] Nenhum `${}` dentro de template literal passado a `.or(`, `.filter(`, `.not(`,
      `sql.unsafe(`, `pool.query(`, `client.query(`, `$queryRawUnsafe(` ou `sql.raw(`.
      Dentro de template **tag** (`` sql`...` ``, `` prisma.$queryRaw`...` ``) pode.
- [ ] Busca de texto pelo cliente com ``.ilike(coluna, `%${escaparLike(termo)}%`)``, ou por
      `.rpc()`; `.textSearch()` com `type: 'websearch'`.
- [ ] `.order()` e qualquer identificador dinâmico vêm de allowlist, com valor padrão.
- [ ] Funções SQL sem `EXECUTE` montado por concatenação; `security definer` só quando
      preciso, com `set search_path = ''`, `auth.uid()` conferido dentro e `execute`
      revogado de `public` e `anon`.
- [ ] RLS ligada em **toda** tabela de `public`, na mesma migração que a cria; políticas
      `to authenticated` com `(select auth.uid())`; `update` com `using` e `with check`;
      admin por `app_metadata` (P13).
- [ ] CT-SEC-031 e CT-SEC-032 executados contra o projeto real.
- [ ] `lib/db.ts` e `lib/supabase/server.ts` começam com `import 'server-only'`, e nenhum
      arquivo `'use client'` importa banco ou o cliente admin.
- [ ] Toda consulta da via 2 (`POSTGRES_URL`) filtra pelo dono no próprio texto, ou roda só
      depois da checagem de admin.
- [ ] A chave secret só aparece em `criarClienteAdmin()`, usado para seed e exclusão de conta.
- [ ] `LIMIT`/`OFFSET` e `.range()` com inteiros, com teto.
- [ ] Ids `bigint` tratados como `string` na via 2 e como `number` na via 1.
- [ ] Operações que precisam ser atômicas usam função SQL via `.rpc()` ou `sql.begin()`.
- [ ] Erros de banco registrados no log, nunca devolvidos ao usuário.
- [ ] Casos de teste de injeção existem no roteiro de QA (R11) para **cada** campo que
      chega ao banco. → [roteiro-de-testes-cowork.md](roteiro-de-testes-cowork.md)
