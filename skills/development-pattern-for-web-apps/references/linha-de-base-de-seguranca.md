# Linha de base de segurança: o piso não negocia, o teto sim

> Regra **R7**. Existe um conjunto de defesas que vale para **todo** projeto, inclusive o
> de fim de semana com três usuários. O que varia com o porte é o que se **acrescenta**
> acima desse piso, nunca o que se remove dele.

"É só um projeto pessoal" é o raciocínio que precede a maioria dos vazamentos de projeto
pessoal. O invasor não sabe que é pessoal: ele varre domínios `*.vercel.app` e faixas
inteiras de IP procurando `/api/`, `/admin` e formulários de login. Com Supabase ele tem um
alvo a mais: a URL do projeto e a publishable key estão no JavaScript que qualquer visitante
baixa, e com elas ele chama a API REST direto, sem passar pelo seu app. O custo do piso é de
horas; o custo de não tê-lo é o dado de outras pessoas.

Verificado em `next@16.4.0`, `react@19.3.0`, `zod@4.6.5`, `@supabase/ssr@0.12.7`,
`@supabase/supabase-js@2.117.3` (com `auth-js`, `storage-js` e `postgrest-js` 2.117.3) e
Node `v24.21.0`, 2026-10-10. Cada afirmação sobre o comportamento do Next ou do Supabase cita
o arquivo do pacote ou a página da documentação onde foi conferida.

---

## 1. O piso: obrigatório em qualquer projeto

| # | Defesa | Verificação |
| --- | --- | --- |
| **P1** | SQL parametrizado em 100% das consultas | `scan-sql-injection.sh` limpo (R5) |
| **P2** | Nenhum segredo em arquivo versionado nem em `NEXT_PUBLIC_` | `scan-secrets.sh` limpo (R1); a secret key do Supabase (`sb_secret_…`) só em variável sem prefixo |
| **P3** | Senha nunca guardada pelo app: quem guarda é o Supabase Auth | Nenhuma coluna de senha nas tabelas do app; nenhum `md5`/`sha1`/`sha256` sobre senha no código (§3) |
| **P4** | Toda mudança de estado protegida contra CSRF | Server Actions com a conferência de origem intacta; Route Handler que muda estado confere `Origin` (§4) |
| **P5** | Toda saída escapada no contexto certo | Nenhum `dangerouslySetInnerHTML` sem sanitização (R6) |
| **P6** | Cookie de sessão `SameSite=Lax`, servido só por HTTPS, e XSS tratado como roubo de sessão | DevTools → Application → Cookies mostra `sb-…-auth-token` com `SameSite=Lax`; P5 e CSP valem em dobro (§3) |
| **P7** | HTTPS obrigatório | A Vercel serve HTTPS e redireciona HTTP; `curl -I http://seu-dominio.com.br` responde 3xx para `https://` |
| **P8** | Cabeçalhos de segurança enviados | `curl -sI https://…` mostra os cinco do §6 |
| **P9** | Autorização conferida em **toda** Server Action, Route Handler e página, por registro | Nenhuma consulta confia só no id da URL (§5) |
| **P10** | Erros logados, nunca exibidos; nada de depuração em produção | Página `error.tsx` genérica; nada de `error.message` cru na tela; `productionBrowserSourceMaps` desligado; rota e flag de diagnóstico só com `VERCEL_ENV !== 'production'`; nenhum endpoint de teste publicado (§9) |
| **P11** | Upload restrito, privado e conferido pelos bytes | Regras de [entrada-e-saida-seguras.md](entrada-e-saida-seguras.md) §5 |
| **P12** | Dependências auditadas antes de publicar e vigiadas depois | `npm audit --omit=dev` sem crítico; `.github/dependabot.yml` presente (npm e github-actions, semanal) e alertas do Dependabot ligados no repositório (§8) |
| **P13** | RLS ligada em toda tabela do schema `public`, com política por dono | A consulta do §5 não lista nenhuma tabela com `rowsecurity = false`; CT-SEC-031 e CT-SEC-032 passam |
| **P14** | Backup do banco existe e a restauração já foi ensaiada | Data do último ensaio anotada; CT-MIG-011 passa ([migracoes-e-rollback.md](migracoes-e-rollback.md)) |

Catorze itens. Se algum não puder ser cumprido, **diga qual e por quê**, não entregue como se
estivesse.

---

## 2. Acima do piso: proporcional ao porte

Determine o nível na Fase 0, pelas respostas sobre dados e usuários, e registre-o na spec.

| Nível | Quando | Acrescenta ao piso |
| --- | --- | --- |
| **N1. Vitrine** | Site estático, formulário de contato, sem login, sem dado pessoal | Captcha ou honeypot no formulário; rate limit simples; e-mail sem injeção de cabeçalho |
| **N2. App com login** | Área logada, dados dos próprios usuários | Bloqueio progressivo por tentativas; recuperação de senha pelo fluxo do Supabase Auth; log de auditoria de ações sensíveis; sessão nova a cada login; expiração por inatividade |
| **N3. Dados de terceiros / LGPD** | Cadastro de clientes, CPF, endereço, saúde, financeiro | Tudo de N2 + criptografia de campos sensíveis em repouso; política de retenção e exclusão; exportação de dados do titular (§10); restauração do backup ensaiada a cada trimestre, não só uma vez (P14); registro de acesso a dado pessoal; **revisão humana obrigatória** de todo código de autenticação e de dado sensível, com o nome do revisor na spec |
| **N4. Pagamento / dinheiro** | Checkout, assinatura, saldo | Tudo de N3 + nenhum dado de cartão tocando seu servidor (redirect/iframe do provedor); webhooks com assinatura verificada; idempotência em toda operação financeira; conciliação; MFA no painel administrativo, na conta da Vercel e na do Supabase; **revisão humana obrigatória** também de todo código de pagamento e de webhook, com o nome do revisor na spec |

Regra de escada: **você pode subir de nível, nunca descer.** Um app que começou N2 e passou
a guardar CPF virou N3 no mesmo commit em que a coluna foi criada.

A revisão humana de N3 e N4 é de uma pessoa que lê o diff, não de outra IA: o ⛔ do portão de
publicação cita o nome dela ([fluxo-spec-driven.md](fluxo-spec-driven.md), Fase 6). Se não há
segunda pessoa no projeto, a spec diz isso, e o nível de risco aceito fica escrito.

---

## 3. Autenticação: provedor sempre

### A decisão já está tomada: Supabase Auth

| Caminho | Quando | O que você ainda deve fazer |
| --- | --- | --- |
| **Provedor: Supabase Auth** (padrão desta skill) | Sempre | Conferir autorização por registro (§5) e ligar a RLS (P13): o provedor diz **quem** é, não **o que** pode |
| **Próprio** | Só como exceção justificada na spec, com o motivo pelo qual o provedor não serve e quem revisou | Não há código de exemplo nesta skill de propósito: guardar senha, sessão, recuperação e bloqueio é trabalho de meses e é onde moram as falhas de autenticação (A07 do OWASP, §11) |

O Supabase Auth guarda a senha com bcrypt ("Supabase Auth uses bcrypt, a strong password
hashing function", https://supabase.com/docs/guides/auth/password-security). O app não tem
coluna de senha, não calcula hash e não compara senha: por isso P3 diz "nunca guardada pelo
app". Se um dia uma exceção exigir guardar senha própria, a regra é a de sempre: nunca MD5,
SHA-1 ou SHA-256 puro (são rápidos, e rápido é o que quem quebra um vazamento quer), e sim um
KDF lento e com sal, comparado em tempo constante, com a decisão revisada por uma segunda
pessoa.

Na mesma página da doc, nas configurações do provedor de e-mail do Auth: comprimento mínimo
de senha ("Anything less than 8 characters is not recommended": configure **12**, sem regra
de "um símbolo e uma maiúscula", que empurra para `Senha@123`) e a proteção contra senhas
vazadas, que consulta o Pwned Passwords e está disponível no plano Pro ou acima.

### Quem está logado: `getClaims()` ou `getUser()`, nunca `getSession()`

O cookie de sessão é entrada do usuário. `getSession()` o lê sem validar
(`auth-js@2.117.3`, `GoTrueClient.d.ts` l. 1411, o aviso diz que o resultado "must not be
trusted" em código de servidor). `getClaims()` (l. 2563) confere a assinatura do JWT;
`getUser()` (l. 1596) consulta o servidor de Auth a cada chamada.

```ts
// lib/sessao.ts
import 'server-only';
import { redirect } from 'next/navigation';
import { criarClienteServidor } from '@/lib/supabase/server';

export type Papel = 'admin' | 'usuario';

export async function exigirSessao() {
  const supabase = await criarClienteServidor();
  const { data } = await supabase.auth.getClaims();
  if (!data?.claims) redirect('/entrar');
  // Papel vem de app_metadata, que só a secret key altera. NUNCA de user_metadata,
  // que o próprio usuário edita pelo navegador (auth-js, lib/types.d.ts l. 466 a 485).
  const papel: Papel = data.claims.app_metadata?.papel === 'admin' ? 'admin' : 'usuario';
  return { supabase, usuarioId: data.claims.sub, papel };
}
```

```ts
// ❌ cookie lido sem validação: qualquer um forja
const { data: { session } } = await supabase.auth.getSession();
// ❌ papel que o próprio usuário define com supabase.auth.updateUser({ data: { papel: 'admin' } })
if (claims.user_metadata?.papel === 'admin') { /* … */ }
// ✅ assinatura conferida, papel de app_metadata
const { data } = await supabase.auth.getClaims();
if (data?.claims.app_metadata?.papel === 'admin') { /* … */ }
```

O JWT não é atualizado no instante em que `app_metadata` muda: a doc de RLS avisa que "a JWT
is not always up-to-date" (https://supabase.com/docs/guides/database/postgres/row-level-security).
Para revogar um administrador já, além de mudar o papel, encerre as sessões dele.

### Login sem enumerar usuários

```ts
// app/entrar/actions.ts
'use server';
import { redirect } from 'next/navigation';
import { criarClienteServidor } from '@/lib/supabase/server';
import { EsquemaLogin } from '@/lib/esquemas';
import { permitir } from '@/lib/limite';

export async function entrar(_estado: unknown, formData: FormData) {
  const r = EsquemaLogin.safeParse(Object.fromEntries(formData));
  if (!r.success) return { erro: 'E-mail ou senha inválidos.' };
  if (!(await permitir(`login:${r.data.email.toLowerCase()}`, 5, 15 * 60))) {
    return { erro: 'Muitas tentativas. Aguarde 15 minutos e tente de novo.' };
  }

  const supabase = await criarClienteServidor();
  const { error } = await supabase.auth.signInWithPassword({
    email: r.data.email,
    password: r.data.senha,
  });
  // Qualquer falha vira a MESMA mensagem: nunca repasse error.message para a tela.
  if (error) return { erro: 'E-mail ou senha inválidos.' };
  redirect('/painel');
}
```

Nunca diga "e-mail não cadastrado" nem "senha incorreta": as duas mensagens juntas são um
enumerador de usuários. Uma mensagem só, para os dois casos. Registre o `error` no log, sem a
senha (§9).

### Sessão em cookie

Quem cria, renova e apaga o cookie é o `@supabase/ssr`: o app não grava cookie de sessão à
mão. O `proxy.ts` renova o token a cada requisição
([`../assets/templates/proxy.ts.template`](../assets/templates/proxy.ts.template)) e
`lib/supabase/server.ts` lê os cookies nas Server Actions e páginas.

O que o pacote grava, conferido em `@supabase/ssr@0.12.7`, `dist/main/utils/constants.js`:
`path: "/"`, `sameSite: "lax"`, **`httpOnly: false`** e `maxAge` de 400 dias. O `HttpOnly`
desligado é de projeto: "The browser-based side of your application needs access to the
refresh token", e a doc responde à pergunta "How do I make the cookies `HttpOnly`?" com "This
is not necessary" (https://supabase.com/docs/guides/auth/server-side/advanced-guide).
Consequência prática: **um XSS no seu app lê o token e leva a sessão**. Por isso P6 cita P5,
e a CSP do §6 deixa de ser enfeite.

O transporte só por HTTPS vem de P7 e do `Strict-Transport-Security` do §6: depois da primeira
visita, o navegador não fala HTTP com o domínio, e o cookie não viaja em claro.

**Sessão nova a cada login**: `signInWithPassword` emite uma sessão nova. No logout,
`supabase.auth.signOut()`; na troca de senha, encerre as outras sessões com
`signOut({ scope: 'others' })` (o tipo `SignOut` aceita `'global' | 'local' | 'others'`,
`auth-js`, `lib/types.d.ts` l. 1942).

### Recuperação de senha

`supabase.auth.resetPasswordForEmail(email, { redirectTo })` envia o link; o token de uso
único, a expiração e o envio são do provedor. Duas coisas ficam com você: o `redirectTo`
precisa estar nas Redirect URLs permitidas do Auth (§4, CORS e URLs do Auth), e a resposta ao
pedido é sempre a mesma, "se o e-mail existir, enviamos o link", para não enumerar usuários.

### Bloqueio progressivo

Duas camadas, porque cada uma cobre o que a outra não vê. Os limites nativos do Supabase Auth
contam por IP (§7). A tabela `eventos_limite` do §7 conta por **e-mail**, com a chave
`login:<email>` usada acima: 5 falhas em 15 minutos para o mesmo e-mail → espera. Só por
e-mail permite *password spraying*; só por IP, botnet.

---

## 4. CSRF: o que o Next já faz e o que fica com você

### Server Actions

Toda Server Action compara o cabeçalho `Origin` com o `Host` (ou `X-Forwarded-Host`) e
aborta com *"Invalid Server Actions request."* quando não batem
(`next@16.4.0`, `dist/server/app-render/action-handler.js` l. 434 a 456). Duas ressalvas
lidas no mesmo trecho:

- **Requisição sem `Origin` passa**, só com aviso no log (l. 436 a 440). Navegadores atuais
  enviam `Origin` em POST, então a defesa vale para o ataque pelo navegador da vítima; o
  cookie `SameSite=Lax` cobre o resto.
- Domínios extras (proxy reverso, domínio alternativo) entram em
  `experimental.serverActions.allowedOrigins` (`dist/server/config-shared.d.ts` l. 1088 a
  1099; a chave fica **dentro de `experimental`** no 16.4.0). Aceita curinga
  (`*.seu-dominio.com.br`, conferido em `csrf-protection.js`). Não acrescente domínio que
  você não controla.

```ts
// next.config.ts
// ❌ abre a conferência para qualquer subdomínio de um domínio que não é seu
experimental: { serverActions: { allowedOrigins: ['*.vercel.app'] } },
// ✅ só o que é seu, e só se houver proxy na frente
experimental: { serverActions: { allowedOrigins: ['app.seu-dominio.com.br'] } },
```

### Route Handlers

Um `POST`, `PUT`, `PATCH` ou `DELETE` em `app/api/**/route.ts` **não** tem essa conferência.
Se ele usa o cookie de sessão, confira a origem você mesmo:

```ts
// lib/origem.ts
import 'server-only';
export function origemConfiavel(request: Request): boolean {
  const origem = request.headers.get('origin');
  const host = request.headers.get('x-forwarded-host') ?? request.headers.get('host');
  if (!origem || !host) return false;          // aqui, sem Origin é recusa
  try { return new URL(origem).host === host; } catch { return false; }
}

// app/api/chamados/route.ts
export async function POST(request: Request) {
  if (!origemConfiavel(request)) return new Response('Origem recusada.', { status: 403 });
  // …
}
```

Webhook de terceiro é a exceção: ele não tem sua origem, e por isso **não** usa o cookie;
autentica pela assinatura do provedor. Um `GET` nunca altera dados.

### CORS e URLs do Auth

CORS diz a **outro site** se o navegador pode ler a resposta do seu. O padrão seguro é não
dizer nada: sem `Access-Control-Allow-Origin` na resposta, o navegador não entrega o conteúdo
a uma página de outra origem. O app deste padrão é servido pela mesma origem que o chama, e
não precisa emitir esse cabeçalho em lugar nenhum.

Se uma rota precisa mesmo ser lida por outro domínio seu, use uma allowlist escrita no código
e devolva a origem só quando ela estiver na lista:

```ts
// ❌ qualquer site lê; e refletir a Origin com credenciais entrega a sessão do visitante
headers.set('Access-Control-Allow-Origin', request.headers.get('origin') ?? '*');
headers.set('Access-Control-Allow-Credentials', 'true');

// ✅ só origens suas, uma a uma, e Vary para o cache não misturar respostas
const PERMITIDAS = new Set(['https://painel.seu-dominio.com.br']);
const origem = request.headers.get('origin');
if (origem && PERMITIDAS.has(origem)) {
  headers.set('Access-Control-Allow-Origin', origem);
  headers.set('Vary', 'Origin');
}
```

Nunca `*` numa rota que lê cookie ou cabeçalho `Authorization`, e nunca a `Origin` refletida
sem conferir.

No Supabase, o equivalente são as **URLs do Auth** (painel do projeto, Authentication → URL
Configuration): a **Site URL** é o redirecionamento padrão dos e-mails de confirmação e de
recuperação, e as **Redirect URLs** são a allowlist que todo `redirectTo` precisa casar
(https://supabase.com/docs/guides/auth/redirect-urls). Regras:

- Site URL é o domínio de produção (`https://seu-dominio.com.br`), nunca `localhost`.
- Em produção, Redirect URL com o caminho exato. A doc recomenda "setting the exact redirect
  URL path for your site URL in production"; o curinga `**` serve para desenvolvimento local
  e preview.
- Para os previews da Vercel, a doc sugere `https://*-<team-or-account-slug>.vercel.app/**`,
  com o slug do **seu** time. Nunca `https://*.vercel.app/**`: casaria o projeto de qualquer
  pessoa, e o link de recuperação de senha poderia ser desviado para lá.

---

## 5. Autorização: o erro mais comum de todos

Autenticação responde "quem é você". Autorização responde "você pode ver **este** registro".
Confundir as duas é o defeito mais frequente em app pessoal. Com Supabase, a resposta mora em
**duas camadas, sempre as duas**: a RLS no banco e a conferência no servidor.

### Camada 1: RLS ligada em toda tabela (P13)

A publishable key está no navegador de propósito, e com ela qualquer pessoa chama a API REST
do projeto sem passar pelo seu app. O que a segura é a RLS. A doc é direta: "A table in an
exposed schema without RLS is readable and writable by any role with a grant on it"
(https://supabase.com/docs/guides/database/postgres/row-level-security).

```sql
-- ❌ tabela criada e esquecida: a API REST lê e grava tudo, com a chave pública
create table public.chamados ( /* … */ );

-- ✅ RLS ligada no mesmo arquivo de migração, com política por dono
alter table public.chamados enable row level security;
create policy "dono lê os próprios chamados" on public.chamados
  for select to authenticated
  using ( (select auth.uid()) = usuario_id );
```

O `(select auth.uid())` entre parênteses é o padrão de desempenho da doc: o valor é avaliado
uma vez por consulta, não uma vez por linha. Tabela com RLS e **sem** política fica fechada
para a API: é o certo para tabela interna (como `eventos_limite`, §7). As políticas completas
de `perfis`, `chamados` e Storage estão em
[`../assets/templates/politicas-rls.sql.template`](../assets/templates/politicas-rls.sql.template),
e o porquê de cada uma em [sql-e-acesso-a-dados.md](sql-e-acesso-a-dados.md).

Conferência antes de todo deploy (vale como evidência de P13):

```sql
-- toda linha que aparecer aqui é uma tabela aberta na API REST
select tablename from pg_tables
where schemaname = 'public' and rowsecurity = false;
```

`rowsecurity` é a coluna de `pg_tables` que diz se a RLS está ligada
(https://www.postgresql.org/docs/current/view-pg-tables.html). Política que lê
`user_metadata` é falha: a doc lembra que esse campo o próprio usuário altera. Papel de
administrador numa política vem de `auth.jwt() -> 'app_metadata'`.

### Camada 2: o dono na consulta, no servidor

A RLS não dispensa a conferência no código, por três motivos: a `criarClienteAdmin()` (secret
key) **ignora** a RLS, porque vai como o papel `service_role`, que tem `bypassrls`; a conexão
SQL direta por `POSTGRES_URL` usa um papel que também não passa pela RLS do usuário; e uma
política errada num release vira vazamento silencioso se nada mais conferir.

```ts
// ❌ cliente administrativo numa action comum: devolve o chamado de qualquer pessoa
const { data } = await criarClienteAdmin().from('chamados').select('*').eq('id', id).single();

// ✅ cliente do usuário (a RLS filtra) E o dono na consulta (o código também filtra)
const { supabase, usuarioId } = await exigirSessao();
const { data: chamado } = await supabase
  .from('chamados')
  .select('id, titulo, status')
  .eq('id', id)
  .eq('usuario_id', usuarioId)
  .maybeSingle();
if (!chamado) notFound();   // 404, não 403: não confirme que existe
```

Na conexão direta, a mesma regra em SQL:

```ts
// ❌ O usuário está logado. E daí? O pedido pode ser de outra pessoa.
const [pedido] = await sql`SELECT * FROM pedidos WHERE id = ${id}`;

// ✅ O dono faz parte da consulta, não de um if depois
const [pedido] = await sql`
  SELECT id, total, status FROM pedidos WHERE id = ${id} AND usuario_id = ${usuarioId}
`;
```

Regra: **o dono entra na cláusula `WHERE` (ou no `.eq`)**, não num `if` posterior. E toda ação
administrativa confere o papel antes de qualquer efeito:

```ts
// lib/sessao.ts
export async function exigirPapel(...papeis: Papel[]) {
  const sessao = await exigirSessao();                 // redireciona para /entrar se não houver
  if (!papeis.includes(sessao.papel)) forbidden();     // ou notFound(), para não revelar a rota
  return sessao;
}
```

`forbidden()` de `next/navigation` depende de `experimental.authInterrupts`; sem ele, use
`notFound()`.

### `proxy.ts` não é a barreira de autorização

No Next 16 a convenção `middleware.ts` está depreciada e virou **`proxy.ts`**
(`dist/lib/constants.d.ts`: `PROXY_FILENAME = "proxy"`). Com Supabase ele tem um papel real,
renovar o token a cada requisição com `getClaims()` e mandar quem está deslogado de `/painel`
e `/admin` para `/entrar`
([`../assets/templates/proxy.ts.template`](../assets/templates/proxy.ts.template)), e mesmo
assim é conveniência de roteamento, **não fronteira de segurança**:

- O `matcher` é uma lista de caminhos; uma rota nova fora dela fica descoberta sem aviso.
- A Server Action é chamada por POST na URL da página; o que vale é a conferência **dentro**
  da action.
- Em março de 2025 a CVE-2025-29927 mostrou um cabeçalho que fazia o middleware ser pulado
  por inteiro. Quem conferia autorização também na página e na action não foi afetado.

```ts
// ❌ só o proxy decide; a action confia que ninguém chegou sem passar por ele
export async function excluirChamado(id: number) {
  await criarClienteAdmin().from('chamados').delete().eq('id', id);
}
// ✅ a action confere sessão e dono, haja proxy ou não; a RLS confere de novo no banco
export async function excluirChamado(id: number) {
  const { supabase, usuarioId } = await exigirSessao();
  await supabase.from('chamados').delete().eq('id', id).eq('usuario_id', usuarioId);
}
```

---

## 6. Cabeçalhos de segurança

Vão em `headers()` no `next.config.ts`. O modelo completo, com CSP de partida comentada que
já inclui o domínio do projeto do Supabase em `connect-src` e `img-src`, está em
[`../assets/templates/next.config.ts.template`](../assets/templates/next.config.ts.template).
As chaves `headers`, `redirects` e `poweredByHeader` existem no tipo `NextConfig`
(`dist/server/config-shared.d.ts` l. 1421, 1441, 1528).

```ts
// next.config.ts (trecho)
const cabecalhos = [
  { key: 'X-Content-Type-Options',    value: 'nosniff' },
  { key: 'Referrer-Policy',           value: 'strict-origin-when-cross-origin' },
  { key: 'Permissions-Policy',        value: 'camera=(), microphone=(), geolocation=()' },
  { key: 'Strict-Transport-Security', value: 'max-age=63072000; includeSubDomains' },
  { key: 'Content-Security-Policy',   value: "frame-ancestors 'none'" },   // anti-clickjacking
];
```

**CSP quebra as coisas antes de proteger.** Suba primeiro em
`Content-Security-Policy-Report-Only`, veja o que reclama no console, ajuste, e só então torne
obrigatória. `'unsafe-inline'` em `script-src` anula a maior parte do benefício: se o
projeto precisa dele, registre isso na spec como débito técnico consciente. Como o token do
Supabase é legível por JavaScript (§3), a CSP é a segunda linha contra o XSS que levaria a
sessão.

Confira o resultado real, não a intenção, no preview **e** em produção:

```bash
curl -sI https://seu-dominio.com.br | grep -iE 'content-security|x-content|strict-transport|referrer|permissions|x-powered-by|access-control'
# x-powered-by não deve aparecer: poweredByHeader: false
# access-control-allow-origin não deve aparecer, salvo rota com allowlist (§4)
```

---

## 7. Rate limiting e teto de gasto

Toda rota que envia e-mail, autentica, registra usuário ou consulta API paga precisa de
limite. **Memória do processo não serve**: cada invocação de função pode cair numa instância
diferente, e um `Map` em módulo conta só o que aquela instância viu.

```ts
// ❌ some a cada cold start e não é compartilhado entre instâncias
const tentativas = new Map<string, number>();
```

### Camada 1: os limites nativos do Supabase Auth

O Auth já limita os próprios endpoints. Valores padrão conferidos em
https://supabase.com/docs/guides/auth/rate-limits, 2026-10-10 (inventário, não contrato:
confira a página antes de depender de um número):

| O que | Padrão | Conta por |
| --- | --- | --- |
| E-mails enviados pelo Auth com o provedor embutido | 2 por hora | projeto |
| Cadastros e logins (`/signup`, `/recover`, `/resend`, `/magiclink`, `/otp`, `/user`) | 30 a cada 5 minutos, rajada de até 30 | IP |
| Requisições ao endpoint de token (senha, refresh, PKCE) | 150 a cada 5 minutos, rajada de até 30 | IP |
| Verificação (`/verify`) | 30 a cada 5 minutos, rajada de até 30 | IP |
| Novo OTP, link mágico, confirmação de cadastro, recuperação de senha | 1 a cada 60 segundos | usuário |
| Desafio e verificação de MFA | 15 por minuto, rajada de até 30 (não ajustável) | IP |

Os ajustáveis ficam no painel do projeto, em Authentication → Rate Limits. O limite de 2
e-mails por hora existe para o servidor de e-mail embutido, que não é para produção: com SMTP
próprio configurado, o limite passa a ser ajustável.

**A armadilha do IP.** A doc diz que "Supabase Auth uses the IP address of the client for rate
limiting". Quando o login roda numa Server Action, o cliente do Auth é a **função da Vercel**,
não a pessoa: o limite por IP passa a contar o tráfego de todo mundo que caiu naquela saída.
A doc descreve o repasse do IP real pelo cabeçalho `Sb-Forwarded-For`, que exige a secret key
e precisa ser ligado no projeto; enquanto isso não for feito e testado, não conte com o limite
por IP como bloqueio por pessoa. Por isso existe a camada 2.

### Camada 2: tabela no Postgres, para o que o Auth não vê

Limite por e-mail no login, por usuário no envio de formulário, por chave em qualquer API
paga. O contador vive numa tabela do próprio banco, sem serviço novo.

```ts
// lib/limite.ts
import 'server-only';
import { sql } from '@/lib/db';   // conexão direta (POSTGRES_URL): não passa pela RLS

export async function permitir(chave: string, max: number, janelaSeg: number): Promise<boolean> {
  await sql`INSERT INTO eventos_limite (chave) VALUES (${chave})`;
  const [{ total }] = await sql`
    SELECT count(*)::int AS total FROM eventos_limite
    WHERE chave = ${chave} AND criado_em > now() - make_interval(secs => ${janelaSeg})
  `;
  return total <= max;
}
```

Consulta conferida em Postgres 18.3 (PGlite 0.5.8), 2026-10-10. A tabela
(`eventos_limite(id, chave, criado_em)` com índice em `(chave, criado_em)`) entra por
migração com **RLS ligada e nenhuma política**: só a conexão direta do servidor a alcança, a
API REST não (P13). Apague as linhas antigas por um Cron Job da Vercel.

### Teto de gasto: o limite que protege a conta, não o app

Uma rota sem limite que chama API paga, ou um robô que descobre o cadastro, vira fatura. Rate
limit reduz a chance; teto e alerta de gasto limitam o estrago. A Fase 0 pergunta se há API
paga, e cada uma ganha uma linha na spec com o teto configurado.

| Onde | O que configurar | Fonte |
| --- | --- | --- |
| **Vercel** | Spend Management: valor por ciclo, notificações em 50%, 75% e 100%, e **Pause Production Deployments** se o valor for um teto de verdade. Disponível nos planos Pro e Enterprise (Flexible Commitment), em Settings → Billing. A conferência roda a cada poucos minutos: o valor pode ser ultrapassado antes da pausa. **Não inclui integrações do Marketplace**, o Supabase contratado por lá inclusive. | https://vercel.com/docs/spend-management |
| **Supabase** | Plano Free não cobra. No Pro, o Spend Cap decide se a organização pode passar da cota do plano; fica na seção Cost Control da página de cobrança da organização. | https://supabase.com/docs/guides/platform/cost-control |
| **Toda API paga** (e-mail, SMS, IA, mapas, pagamento) | Teto de gasto e alerta no painel do próprio provedor, além do limite da camada 2 na rota que a chama. | painel de cada provedor |

---

## 8. Dependências

```bash
npm audit --omit=dev
npm outdated
```

Antes de **toda** publicação. Vulnerabilidade crítica em dependência direta bloqueia o
release; em dependência transitiva, registre no CHANGELOG se não houver correção.
Mantenha o `next` na última versão do major em uso: correções de segurança chegam como patch.

`npm audit` só vê o que existe no dia em que roda. Para o que aparece depois, P12 pede
vigilância contínua: `.github/dependabot.yml` com os ecossistemas `npm` e `github-actions`,
verificação semanal (modelo em
[`../assets/templates/dependabot.yml.template`](../assets/templates/dependabot.yml.template)),
e os alertas do Dependabot ligados nas configurações de segurança do repositório. Pull
request do Dependabot passa pelo mesmo checklist e pelo mesmo preview que qualquer outro.

Menos dependência é menos superfície. Uma biblioteca de 40 KB para formatar data não vale o
risco de cadeia de suprimentos em um projeto pessoal. Antes de instalar um pacote novo, a
conferência de nome, mantenedor e idade está em
[protocolo-de-verificacao.md](protocolo-de-verificacao.md).

---

## 9. Registro, erros e depuração

Registre, com data, IP e usuário (tabela `auditoria`): login (sucesso e falha), troca de
senha, mudança de permissão, exclusão de registro, exclusão de conta, execução de migração.

Nunca registre: senha, token de sessão, número de cartão, corpo inteiro de requisição com
dado pessoal. `console.log(formData)` numa action de login grava a senha nos logs da Vercel.

Em produção, a tela de erro é um `app/error.tsx` genérico, com um código para o suporte e
nenhum detalhe técnico. Mensagem de exceção, stack trace e texto da query ficam no log
(`vercel logs`), nunca na resposta: eles entregam caminho de arquivo, versão de biblioteca e
às vezes a estrutura do banco. O `error.message` do Supabase entra na mesma regra.

### Depuração desligada em produção (P10)

- **Source map do navegador**: `productionBrowserSourceMaps` existe no tipo `NextConfig`
  (`dist/server/config-shared.d.ts` l. 1576) e o padrão é `false` (l. 1842). O modelo de
  `next.config.ts` o deixa `false` por escrito, para ninguém ligar "só para depurar".
- **Rota ou flag de diagnóstico** só existe fora de produção. `VERCEL_ENV` vale
  `production`, `preview` ou `development`
  (https://vercel.com/docs/environment-variables/system-environment-variables).

```ts
// app/api/diagnostico/route.ts
import { notFound } from 'next/navigation';

export async function GET() {
  // ❌ sem esta linha, qualquer pessoa vê variáveis e versões em produção
  // ✅ fora de produção, ou 404
  if (process.env.VERCEL_ENV === 'production') notFound();
  return Response.json({ ambiente: process.env.VERCEL_ENV, commit: process.env.VERCEL_GIT_COMMIT_SHA });
}
```

- **Endpoint de teste** (`/api/teste`, `/api/seed`, `/api/debug`, página `/teste`) não vai a
  produção. Se precisa existir no preview, condicione como acima e liste na spec.

---

## 10. Dados pessoais e LGPD

O piso técnico para quem guarda dado de pessoa. Isto **não é parecer jurídico**: a skill diz o
que o app precisa fazer para cumprir o que a política de privacidade promete; o texto da
política e a base legal de cada tratamento são decisão de quem responde pelo app, com quem
entende de direito.

| Item | O que o app faz | Caso de teste |
| --- | --- | --- |
| **Minimização** | Cada campo pessoal tem finalidade escrita na seção "Dados pessoais" da spec (campo, finalidade, retenção). Campo sem finalidade não é pedido. | CT-LGPD-004 |
| **Política de privacidade** | Rota própria, `/politica-de-privacidade`, acessível sem login e linkada no rodapé de toda página. | CT-LGPD-001 |
| **Exclusão de conta** | Apaga arquivos no Storage, linhas nas tabelas e o usuário do Auth, nessa ordem, e diz na tela o que fica em backup e por quanto tempo. | CT-LGPD-002 |
| **Exportação** | O titular baixa os próprios dados em JSON. A consulta filtra pelo `usuarioId` da sessão, nunca por parâmetro. | CT-LGPD-003 |
| **Canal de contato** | Um e-mail ou formulário para pedidos do titular, citado na política. | (conferido no CT-LGPD-001) |

### Exclusão de conta que alcança tudo

A ordem importa: a doc avisa que "You cannot delete a user if they are the owner of any
objects in Supabase Storage", e recomenda que tabelas do app referenciem `auth.users` com
`on delete cascade` (https://supabase.com/docs/guides/auth/managing-user-data).

```ts
// app/conta/excluir/actions.ts
'use server';
import { redirect } from 'next/navigation';
import { exigirSessao } from '@/lib/sessao';
import { criarClienteAdmin } from '@/lib/supabase/server';

export async function excluirMinhaConta() {
  const { supabase, usuarioId } = await exigirSessao();   // só a própria conta, nunca um id do formulário
  const admin = criarClienteAdmin();                       // secret key: autorização conferida na linha acima

  // 1. Storage: os arquivos ficam em anexos/<usuarioId>/... (politicas-rls.sql.template).
  //    list() devolve até 100 por padrão (SearchOptions.limit): repita até esvaziar.
  for (;;) {
    const { data: arquivos } = await admin.storage.from('anexos').list(usuarioId, { limit: 100 });
    if (!arquivos?.length) break;
    await admin.storage.from('anexos').remove(arquivos.map((a) => `${usuarioId}/${a.name}`));
  }
  // 2. Auth: apaga o usuário; perfis e chamados saem pelo on delete cascade do schema.
  const { error } = await admin.auth.admin.deleteUser(usuarioId);
  if (error) throw error;                                  // vai para o log e para o error.tsx
  await supabase.auth.signOut();
  redirect('/conta-excluida');
}
```

APIs conferidas em 2026-10-10: `deleteUser(id, shouldSoftDelete?)` em `auth-js`,
`GoTrueAdminApi.d.ts` l. 608; `list(path?, options?)` com `limit` padrão 100 e
`remove(paths)` em `storage-js`, `dist/index.d.cts` l. 1811, 373 e 1663. Se a pasta do usuário
tiver subpastas (`anexos/<usuario>/<chamado>/…`), o `list` devolve as pastas como entradas:
percorra cada uma.

**O que fica em backup.** O backup diário do plano Pro guarda 7 dias, o do Team 14
([migracoes-e-rollback.md](migracoes-e-rollback.md)): a tela de exclusão e a política dizem
que o dado some do app na hora e dos backups no fim desse prazo. Se o projeto guarda dumps
próprios (`supabase db dump`), o prazo deles entra na mesma frase.

---

## 11. OWASP Top 10: onde cada categoria é tratada

Edição vigente: **OWASP Top 10:2025** (https://owasp.org/Top10/2025/, conferido em
2026-10-10). Nos níveis N2 ou acima, a Fase 1 lê as categorias que a funcionalidade toca
([fluxo-spec-driven.md](fluxo-spec-driven.md)).

| Categoria | Onde a skill trata | Regra |
| --- | --- | --- |
| **A01:2025** Broken Access Control | P9 e P13; §5 (RLS e dono na consulta); Storage privado com política por pasta, caminho vindo do banco e redirecionamento só interno ([entrada-e-saida-seguras.md](entrada-e-saida-seguras.md) §5 a §7) | R7, R6 |
| **A02:2025** Security Misconfiguration | P8 e P10; §4 (CORS e URLs do Auth); §6; bloco "Proteções desligadas" do [checklist-de-revisao.md](checklist-de-revisao.md) | R7, R12 |
| **A03:2025** Software Supply Chain Failures | P12; §8; "Antes de instalar um pacote" em [protocolo-de-verificacao.md](protocolo-de-verificacao.md); lockfile e `npm ci` em [git-e-publicacao.md](git-e-publicacao.md) | R4, R7 |
| **A04:2025** Cryptographic Failures | P2, P3 e P7; criptografia de campo sensível em N3; segredos em [segredos-e-configuracao.md](segredos-e-configuracao.md) | R1, R7 |
| **A05:2025** Injection | P1 ([sql-e-acesso-a-dados.md](sql-e-acesso-a-dados.md), inclusive `.or()`/`.filter()` com string montada); P5 ([entrada-e-saida-seguras.md](entrada-e-saida-seguras.md)); saída de LLM tratada como entrada | R5, R6 |
| **A06:2025** Insecure Design | Spec antes do código, níveis N1 a N4 (§2), roteiro de testes com casos de segurança | R3, R7, R11 |
| **A07:2025** Authentication Failures | P3 e P6; §3 (Supabase Auth, `getClaims()`, mensagem única); §7 (limites) | R7 |
| **A08:2025** Software or Data Integrity Failures | Webhook com assinatura (N4); migração versionada e compatível ([migracoes-e-rollback.md](migracoes-e-rollback.md)); backup ensaiado (P14) | R7, R10 |
| **A09:2025** Security Logging and Alerting Failures | §9 (o que registrar e o que nunca registrar); alertas de gasto (§7) e do Dependabot (§8) | R7 |
| **A10:2025** Mishandling of Exceptional Conditions | P10; `error.tsx` genérico; as perguntas adversariais 3 e 4 do [checklist-de-revisao.md](checklist-de-revisao.md) | R7, R12 |

Se o app usa um modelo de linguagem, o OWASP mantém uma lista própria, o Top 10 for LLM
Applications 2025 (https://genai.owasp.org/llm-top-10/): LLM01 Prompt Injection, LLM05
Improper Output Handling e LLM06 Excessive Agency são os que este padrão trata, em
[entrada-e-saida-seguras.md](entrada-e-saida-seguras.md) §9.

---

## 12. Checklist de segurança antes de publicar

- [ ] Os catorze itens do piso, verificados um a um
- [ ] Nível (N1 a N4) declarado na spec e os itens dele implementados
- [ ] Em N3 ou N4: nome do revisor humano na spec, para autenticação, dado sensível, pagamento e webhook
- [ ] `npm audit --omit=dev` sem vulnerabilidade crítica; `.github/dependabot.yml` presente e alertas ligados
- [ ] Cabeçalhos conferidos com `curl -sI` no preview e em produção; sem `x-powered-by`; sem `access-control-allow-origin` fora de allowlist
- [ ] Login pelo Supabase Auth; nenhuma coluna de senha no app; mensagem única de erro no login
- [ ] Servidor identifica o usuário com `getClaims()` ou `getUser()`, nunca `getSession()`; papel lido de `app_metadata`
- [ ] RLS ligada em toda tabela de `public` (consulta do §5 sem linhas) e políticas por dono
- [ ] Secret key só em `criarClienteAdmin()`, chamada depois de conferir a autorização
- [ ] Site URL e Redirect URLs do Auth restritas ao seu domínio e ao slug do seu time na Vercel
- [ ] Route Handlers que mudam estado conferem `Origin`; `allowedOrigins` só com domínios seus
- [ ] Rate limit: limites do Auth revistos no painel; tabela `eventos_limite` nas rotas de login, cadastro, envio de e-mail e API paga
- [ ] Teto e alerta de gasto na Vercel, no Supabase e em toda API paga
- [ ] Autorização por registro dentro de cada action, handler e página; `proxy.ts` não é a única barreira
- [ ] `app/error.tsx` genérico; `productionBrowserSourceMaps` desligado; nenhuma rota de diagnóstico ou teste em produção
- [ ] Backup existe e a restauração foi ensaiada (P14, CT-MIG-011)
- [ ] Se há dado pessoal: política em `/politica-de-privacidade`, exclusão e exportação de conta funcionando (CT-LGPD-001 a 004)
- [ ] Administrador inicial criado pelo seed, com troca de senha obrigatória (R9)
- [ ] Migrações compatíveis com a versão anterior do código (R10)
- [ ] Casos de teste de segurança presentes no roteiro de QA (R11)
