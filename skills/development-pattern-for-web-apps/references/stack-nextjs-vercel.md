# Stack Next.js + Tailwind na Vercel

> Regra **R8**: App Router, Server Components por padrão, Tailwind com tokens do tema, um
> componente por responsabilidade. Este é o único stack desta skill: Next.js na Vercel, com
> Supabase (Postgres, Auth e Storage) contratado pelo Marketplace da Vercel.

| Camada | Escolha |
| --- | --- |
| Framework | Next.js (App Router) + React + TypeScript |
| Estilo | Tailwind CSS v4, tokens em CSS com `@theme` |
| Hospedagem | Vercel: Production, Preview, Development |
| Banco | **Supabase** (Postgres) pelo Marketplace da Vercel, com RLS em toda tabela; cliente `@supabase/ssr` + `@supabase/supabase-js` |
| Autenticação | Supabase Auth: quem guarda e faz hash da senha é o provedor |
| Arquivos | Supabase Storage, bucket privado, URL assinada |
| Migrações | Supabase CLI (`supabase/migrations/`, `supabase db push`) |
| Validação | Zod, inclusive das variáveis de ambiente (`lib/env.ts`, R9) |
| Testes | Vitest + Playwright + roteiro do Cowork (R11) |

*Inventário verificado em next 16.4.0, react 19.3.0, tailwindcss 4.3.3, vercel 63.1.2,
@supabase/supabase-js 2.117.3, @supabase/ssr 0.12.7, supabase (CLI) 2.120.0, zod 4.6.5, 2026-10-10 (`npm view <pacote> version`). É uma
fotografia, não um contrato: confira de novo no seu projeto.*

`@vercel/postgres` está **depreciado** (o próprio `npm view @vercel/postgres` avisa): não
comece projeto novo com ele. `@supabase/auth-helpers-nextjs` também não: o npm o marca como
depreciado (`npm view @supabase/auth-helpers-nextjs deprecated`, 0.15.0, 2026-10-10), e o
pacote do SSR é o `@supabase/ssr`.

**Verifique as versões antes de escrever a primeira linha** (R4). Next.js 15 e 16, e
Tailwind v3 e v4, diferem em coisas que quebram silenciosamente:

```bash
node -v
npx next --version                                   # a versão que o projeto vai usar
grep -E '"(next|react|tailwindcss|typescript)"' package.json
npm ls next react tailwindcss
ls tailwind.config.* 2>/dev/null && echo "Tailwind v3" || echo "provável v4 (config em CSS)"
ls middleware.ts src/middleware.ts 2>/dev/null && echo "convenção antiga: migrar para proxy.ts"
```

### O que mudou no Next 16 e pega quem escreve de memória

| Antes (Next 15) | Agora (Next 16) | Fonte |
| --- | --- | --- |
| `middleware.ts` | **`proxy.ts`** (na raiz ou em `src/`), exportando `proxy` ou `default`. `middleware` ainda é lido, com aviso de depreciação no build. Codemod: `npx @next/codemod@canary middleware-to-proxy .` | `next@16.4.0`: `dist/lib/constants.js` (`PROXY_FILENAME`), `dist/build/index.js` (mensagem de depreciação), `dist/build/templates/middleware.js` |
| `next lint` | **Não existe mais.** O script `lint` chama o ESLint direto: `"lint": "eslint ."` | `next@16.4.0`: não há `dist/cli/next-lint.js` |
| `eslint.ignoreDuringBuilds` em `next.config` | **A chave `eslint` não existe** no tipo `NextConfig`; o build não roda lint | `next@16.4.0`: `dist/server/config-shared.d.ts` |
| `params` e `searchParams` | Continuam `Promise` (desde o 15): `const { id } = await params` | `next@16.4.0`: `dist/build/webpack/plugins/next-types-plugin/index.js` |
| `experimental.typedRoutes` | `typedRoutes` é chave de topo, estável | `next@16.4.0`: `dist/server/config-shared.d.ts` |

---

## 1. Layout do projeto

```
app/                              # o caminho da pasta É a URL (R15)
├── layout.tsx                    # shell raiz: html, body, fontes, providers
├── page.tsx                      # → /
├── not-found.tsx                 # → 404 de verdade
├── globals.css                   # Tailwind + tokens do tema
├── entrar/page.tsx               # → /entrar
├── cadastrar-novo-usuario/page.tsx   # → /cadastrar-novo-usuario
├── recuperar-acesso/page.tsx     # → /recuperar-acesso
├── (painel)/                     # grupo de rota: NÃO aparece na URL
│   ├── layout.tsx                # verifica sessão para todo o grupo
│   ├── chamados/
│   │   ├── page.tsx              # → /chamados
│   │   ├── loading.tsx           # estado de carregamento da rota
│   │   ├── error.tsx             # estado de erro da rota
│   │   └── [id]/page.tsx         # → /chamados/8
│   └── abrir-chamado/page.tsx    # → /abrir-chamado
└── api/
    └── webhooks/pagamento/route.ts

proxy.ts                          # Next 16: o antigo middleware.ts. Renova a sessão do Supabase
                                  #   (getClaims), canonicaliza URL (R15). NÃO é a barreira de autorização
next.config.ts                    # cabeçalhos de segurança, redirects 301, typedRoutes

components/
├── ui/                       # primitivos sem regra de negócio: Botao, Campo, Modal, Tabela
└── chamados/                 # componentes do domínio: ListaChamados, FormChamado, StatusBadge

lib/
├── env.ts                    # valida TODA variável com Zod na carga (R9)
├── supabase/
│   ├── server.ts             # criarClienteServidor() e criarClienteAdmin(): 'server-only'
│   └── browser.ts            # criarClienteNavegador(): só URL e publishable key
├── db.ts                     # acesso a dados: 'server-only'
├── sessao.ts                 # exigirSessao() e exigirPapel(): getClaims(), papel de app_metadata
├── validacoes.ts             # esquemas Zod compartilhados
└── utils.ts                  # cn(), formatarData()

actions/
└── chamados.ts               # Server Actions: 'use server'

types/
└── index.ts                  # tipos de domínio, fonte única

supabase/                     # criado por `supabase init`
├── config.toml               # configuração do stack local (versionado)
├── migrations/               # SQL versionado, aplicado em ordem (R10)
│   ├── 20261010120000_cria_perfis.sql      # supabase migration new cria_perfis
│   └── 20261010120100_cria_chamados.sql
├── seed.sql                  # dado de referência SINTÉTICO; roda no `supabase db reset` local
├── .temp/                    # estado do `supabase link`: ignorado
└── .branches/                # ignorado

scripts/
└── seed.ts                   # npm run db:seed: idempotente, cria o administrador no Auth (R9)

.env.example                  # toda variável, com placeholder (R1, R9)
```

Templates prontos para essas peças: [`env.ts.template`](../assets/templates/env.ts.template),
[`supabase-server.ts.template`](../assets/templates/supabase-server.ts.template),
[`supabase-browser.ts.template`](../assets/templates/supabase-browser.ts.template),
[`proxy.ts.template`](../assets/templates/proxy.ts.template),
[`db.ts.template`](../assets/templates/db.ts.template),
[`migration.sql.template`](../assets/templates/migration.sql.template),
[`politicas-rls.sql.template`](../assets/templates/politicas-rls.sql.template),
[`seed.ts.template`](../assets/templates/seed.ts.template),
[`next.config.ts.template`](../assets/templates/next.config.ts.template),
[`env.example.template`](../assets/templates/env.example.template).

Os scripts do `package.json` que o resto da skill assume:

```json
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "eslint .",
    "test": "vitest run",
    "check:env": "node --conditions=react-server --env-file-if-exists=.env.local lib/env.ts",
    "prebuild": "node --conditions=react-server --env-file-if-exists=.env.local lib/env.ts",
    "db:migrate": "supabase db push",
    "db:migrate:conferir": "supabase db push --dry-run",
    "db:reset:local": "supabase db reset --local",
    "db:seed": "node --env-file-if-exists=.env.local scripts/seed.ts"
  }
}
```

`supabase` é o CLI, instalado como devDependency (`npm i -D supabase`), e o `npm run` o acha
em `node_modules/.bin`. `db:migrate` aplica as migrações pendentes no projeto linkado
(`supabase link`); `db:reset:local` recria só o banco local e roda `supabase/seed.sql`
(referência do CLI em supabase.com/docs/reference/cli, conferida em 2026-10-10). Node 24
executa `.ts` direto, removendo os tipos, sem `tsx` e sem build (conferido em node v24.21.0,
2026-10-10). Os nomes `db:migrate` e `db:seed` são o contrato (R9); o executor pode mudar. Detalhes do `prebuild` em [bootstrap-do-ambiente.md](bootstrap-do-ambiente.md). Um clone limpo sobe com três comandos:

```bash
vercel env pull .env.local     # variáveis do ambiente Development
npm run db:migrate
npm run db:seed
```

→ [bootstrap-do-ambiente.md](bootstrap-do-ambiente.md) (R9) ·
[migracoes-e-rollback.md](migracoes-e-rollback.md) (R10)

**`components/ui/` não conhece o domínio.** `Botao` não sabe o que é um chamado. Isso é o que
torna o componente reutilizável entre projetos.

**O nome da pasta é a URL pública.** Por isso ele segue as convenções de R15: português,
kebab-case, sem acento, ação como verbo no infinitivo. `cadastrar-novo-usuario/`, nunca
`signup/` nem `NewUser/`. Grupos entre parênteses, `(painel)`, compartilham layout e
verificação de sessão sem entrar no caminho. → [rotas-e-urls.md](rotas-e-urls.md)

---

## 2. Server Components por padrão

`'use client'` é a exceção, e cada uso precisa de motivo. Motivos válidos: `useState`,
`useEffect`, `onClick`, `onChange`, API do navegador, biblioteca que exige cliente.

```tsx
// app/(painel)/chamados/page.tsx. Server Component: busca direto, sem endpoint intermediário
import { listarChamadosDoUsuario } from '@/lib/db';
import { exigirSessao } from '@/lib/sessao';
import { ListaChamados } from '@/components/chamados/lista-chamados';

export default async function PaginaChamados({
  searchParams,
}: { searchParams: Promise<{ status?: string }> }) {
  const sessao = await exigirSessao();
  const { status } = await searchParams;                 // Promise desde o Next 15, idem no 16
  const chamados = await listarChamadosDoUsuario(sessao.usuarioId, status);
  return <ListaChamados chamados={chamados} />;
}
```

Empurre o `'use client'` para a folha da árvore. Um `'use client'` no layout raiz manda a
aplicação inteira para o cliente e apaga o benefício.

```tsx
// ✅ o formulário interativo é cliente; a página que o contém continua servidor
'use client';
export function FiltroStatus({ valor }: { valor?: string }) { /* … */ }
```

---

## 3. Acesso a dados, só no servidor

```ts
// lib/db.ts
import 'server-only';                        // import a partir do cliente vira erro de build
import { criarClienteServidor } from '@/lib/supabase/server';

export async function listarChamadosDoUsuario(usuarioId: string, status?: string) {
  // Cliente com o token do usuário: a RLS só devolve as linhas dele.
  const supabase = await criarClienteServidor();

  // ✅ métodos tipados: cada valor vai como parâmetro, nunca concatenado (R5)
  let consulta = supabase
    .from('chamados')
    .select('id, titulo, status, criado_em')
    .eq('usuario_id', usuarioId);
  if (status) consulta = consulta.eq('status', status);

  const { data, error } = await consulta.order('criado_em', { ascending: false }).limit(100);
  if (error) throw new Error('listarChamadosDoUsuario: ' + error.message);
  return data;
}
```

`usuario_id` entra na consulta a partir da **sessão**, nunca de `searchParams`, é a
diferença entre autorização e uma URL editável (R7). O filtro explícito e a RLS são as duas
camadas: se uma falhar, a outra segura.

Os três clientes, e quando usar cada um:

| Função | Arquivo | Chave | Passa pela RLS? | Use em |
| --- | --- | --- | --- | --- |
| `criarClienteServidor()` | `lib/supabase/server.ts` | publishable + cookies do usuário | Sim, como o usuário | Server Components, Server Actions, Route Handlers: **o padrão** |
| `criarClienteNavegador()` | `lib/supabase/browser.ts` | publishable | Sim, como o usuário | Client Components (tempo real, upload direto com URL assinada) |
| `criarClienteAdmin()` | `lib/supabase/server.ts` | secret | **Não** | Seed, exclusão de conta, manutenção; autorização conferida antes, no código |

Detalhes, a armadilha de `.or()`/`.filter()` com string montada e o SQL direto com
`POSTGRES_URL` (que não passa pela RLS): [sql-e-acesso-a-dados.md](sql-e-acesso-a-dados.md).

**Banco pelo Marketplace da Vercel.** A integração do Supabase, instalada pelo Marketplace
no projeto, cria o projeto Supabase e grava as variáveis de ambiente do projeto na Vercel:
`NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SECRET_KEY`,
`SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` e as `POSTGRES_*` (vercel.com/marketplace/supabase,
conferido em 2026-10-10). Confira no painel os nomes exatos que ela criou no **seu** projeto e
declare cada um em `lib/env.ts` e no `.env.example` (R4, R9). Preview usa **um branch do
Supabase** (Supabase Branching) **ou um projeto Supabase separado**, nunca o projeto de
produção: é isso que torna seguro rodar migração e seed num deploy de preview (R10).
→ [migracoes-e-rollback.md](migracoes-e-rollback.md)

---

## 4. Server Actions: endpoints públicos com aparência de função

```ts
// actions/chamados.ts
'use server';
import { z } from 'zod';
import { revalidatePath } from 'next/cache';
import { exigirSessao } from '@/lib/sessao';
import { inserirChamado } from '@/lib/db';

const Esquema = z.object({
  titulo:    z.string().trim().min(1, 'Informe o título').max(200),
  descricao: z.string().trim().max(5000).optional(),
});

export async function criarChamado(_anterior: unknown, formData: FormData) {
  const sessao = await exigirSessao();                       // 1. autorização SEMPRE primeiro
  const r = Esquema.safeParse(Object.fromEntries(formData)); // 2. validação de entrada
  if (!r.success) return { erros: r.error.flatten().fieldErrors };

  try {
    await inserirChamado({ ...r.data, usuarioId: sessao.usuarioId });  // 3. dono da sessão
  } catch (e) {
    console.error('[criarChamado]', e);
    return { erroGeral: 'Não foi possível criar o chamado.' };         // 4. erro genérico
  }

  revalidatePath('/chamados');
  return { ok: true };
}
```

As quatro linhas na ordem: **autorização → validação → operação → erro genérico**. Uma
Server Action sem `exigirSessao()` é uma rota pública, mesmo que só apareça numa tela logada.

---

## 5. Tailwind: componentes, não classes soltas

**Tokens no tema, não hex no JSX.** Cor definida uma vez; usada por nome.

```css
/* app/globals.css. Tailwind v4 */
@import "tailwindcss";

@theme {
  --color-marca-50:  oklch(0.97 0.02 250);
  --color-marca-500: oklch(0.62 0.17 250);
  --color-marca-700: oklch(0.48 0.16 250);
  --color-perigo-500: oklch(0.60 0.20 25);
  --radius-cartao: 0.75rem;
}
```

```js
// tailwind.config.ts. Tailwind v3
export default {
  content: ['./app/**/*.{ts,tsx}', './components/**/*.{ts,tsx}'],
  theme: { extend: { colors: { marca: { 50:'#eff6ff', 500:'#2563eb', 700:'#1d4ed8' } } } },
};
```

```tsx
<button className="bg-marca-500 hover:bg-marca-700">   {/* ✅ token */}
<button className="bg-[#2563eb]">                       {/* ❌ hex solto */}
```

### Variantes com `cva`, não com ternários empilhados

```tsx
// components/ui/botao.tsx
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/utils';

const botao = cva(
  'inline-flex items-center justify-center rounded-md font-medium transition-colors ' +
  'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-marca-500 ' +
  'disabled:pointer-events-none disabled:opacity-50',
  {
    variants: {
      variante: {
        primario:   'bg-marca-500 text-white hover:bg-marca-700',
        secundario: 'bg-slate-100 text-slate-900 hover:bg-slate-200',
        perigo:     'bg-perigo-500 text-white hover:brightness-90',
      },
      tamanho: { sm: 'h-8 px-3 text-sm', md: 'h-10 px-4', lg: 'h-12 px-6 text-lg' },
    },
    defaultVariants: { variante: 'primario', tamanho: 'md' },
  }
);

type Props = React.ButtonHTMLAttributes<HTMLButtonElement> & VariantProps<typeof botao>;

export function Botao({ className, variante, tamanho, ...props }: Props) {
  return <button className={cn(botao({ variante, tamanho }), className)} {...props} />;
}
```

### A armadilha do nome de classe montado em runtime

```tsx
<div className={`text-${cor}-500`} />                        {/* ❌ o Tailwind não gera */}

const CORES = { azul: 'text-blue-500', vermelho: 'text-red-500' } as const;
<div className={CORES[cor]} />                                {/* ✅ classes completas */}
```

O Tailwind faz varredura estática do código-fonte. Classe que só existe depois de concatenar
nunca chega ao CSS, e some da tela sem erro.

### Acessibilidade não é opcional

- Todo `<input>` tem `<label htmlFor>`, `placeholder` não é rótulo.
- Foco visível: nunca `outline-none` sem `focus-visible:ring`.
- Contraste mínimo AA (4.5:1 em texto normal).
- Ícone sozinho em botão exige `aria-label`.
- Ordem de `<h1>`…`<h3>` sem pular nível.
- Modal devolve o foco ao elemento que o abriu e fecha com `Esc`.

O roteiro de QA (R11) tem uma suíte para isso.

---

## 6. Estados de tela: os quatro, sempre

Toda tela que busca dado tem quatro estados, e todos aparecem na spec:

| Estado | Onde vive |
| --- | --- |
| Carregando | `loading.tsx` da rota, ou `<Suspense fallback>` |
| Vazio | Componente com mensagem e ação sugerida, nunca uma tabela em branco |
| Erro | `error.tsx` (client component com `reset`): mensagem genérica, detalhe no log |
| Sucesso | O conteúdo |

"Esqueci o estado vazio" é o defeito mais comum encontrado no QA de interface.

---

## 7. Vercel

```
Ambientes:  Production (main) · Preview (cada PR/branch) · Development (local)
Variáveis:  Project → Settings → Environment Variables, por ambiente
Segredos:   NUNCA com prefixo NEXT_PUBLIC_ (R1)
```

- Cada push num ramo gera um **preview deploy** com URL própria: é o ambiente ideal para o
  Cowork executar o roteiro de QA antes do merge.
- **Preview é público por padrão** enquanto a URL for conhecida. Se o app trata dado real,
  ligue *Deployment Protection* ou use dados de seed sintéticos.
- Route Handlers e Server Actions rodam em ambiente serverless: **não há estado entre
  invocações**, não escreva em disco (só `/tmp`, efêmero), e há teto de tempo de execução.
- Trabalho longo (relatório grande, envio em massa) vai para fila ou cron, não para a
  requisição.
- Variáveis locais vêm do painel, não de cópia manual: `vercel env pull .env.local` (R9).
- Confira o build de produção localmente antes de publicar: `npm run build && npm start`.
- Melhor ainda: **`vercel build`** reproduz o build da Vercel, com a configuração e as
  variáveis do ambiente escolhido: é o que pega a falha que só aparece no deploy.
  Quando um build falha, o ciclo de diagnóstico e correção é a R16.
  → [vercel-build-e-correcao.md](vercel-build-e-correcao.md)
- Voltar atrás é `vercel rollback` ou o Instant Rollback do painel, e **volta o código, não o
  banco**: por isso toda migração é compatível com a versão anterior do código (R10).
  → [release-e-deploy.md](release-e-deploy.md) · [migracoes-e-rollback.md](migracoes-e-rollback.md)

### Nada de depuração em produção

O que ajuda a depurar ajuda também quem ataca: código-fonte legível, rota que despeja
estado, endpoint "só para testar".

- **Source maps do navegador desligados em produção.** A chave é
  `productionBrowserSourceMaps` no `next.config.ts`, e o padrão é `false` (conferido em
  `next@16.4.0`, `dist/server/config-shared.d.ts`: a declaração `productionBrowserSourceMaps?:
  boolean` e o valor padrão `productionBrowserSourceMaps: false`). Não ligue "para achar um
  erro": com ela, qualquer visitante lê o código-fonte original no DevTools.

```ts
// next.config.ts
// ❌ código-fonte original servido a qualquer visitante
const config: NextConfig = { productionBrowserSourceMaps: true };

// ✅ o padrão: omita a chave, ou deixe explícito
const config: NextConfig = { productionBrowserSourceMaps: false };
```

- **Diagnóstico só fora de produção.** Rota, painel ou flag de diagnóstico existe só quando
  `VERCEL_ENV` não é `production` (variável de sistema da Vercel, disponível em build e
  runtime: vercel.com/docs/environment-variables/system-environment-variables). Leia por
  `env.VERCEL_ENV` (`lib/env.ts`) e responda 404 em produção:

```ts
// app/api/diagnostico/route.ts
import { env } from '@/lib/env';

export async function GET() {
  // ✅ em produção, a rota responde como se não existisse
  if (env.VERCEL_ENV === 'production') return new Response(null, { status: 404 });
  return Response.json({ ambiente: env.VERCEL_ENV ?? 'local' });   // nunca valor de segredo
}
```

- **Nenhum endpoint de teste em produção**: `/api/teste`, `/api/seed`, `/debug`, rota que
  cria usuário ou zera tabela. Seed é `npm run db:seed` no terminal, nunca uma URL.
- **Erro genérico para o usuário, detalhe no log** (§4 e §6): stack trace, mensagem do
  Postgres e nome de tabela não aparecem na tela.

---

## 8. Testes

```
tests/
├── unit/           # Vitest: funções puras, validações, formatação
└── integration/    # Server Actions e acesso a dados com banco de teste
e2e/                # Playwright: fluxos de interface
```

```bash
npx tsc --noEmit && npm run lint && npm test && npm run build
```

O E2E do Playwright e o roteiro do Cowork (R11) se complementam: o Playwright trava a
regressão em CI; o roteiro cobre exploração, usabilidade e segurança que um script não
enxerga.

---

## 9. Checklist de um projeto Next.js deste padrão

- [ ] Versões de Next e Tailwind verificadas antes de codar (R4)
- [ ] `proxy.ts`, não `middleware.ts`; script `lint` é `eslint .`, não `next lint` (Next 16)
- [ ] `lib/env.ts` valida toda variável; `.env.example` lista todas (R9)
- [ ] Clone limpo sobe com `vercel env pull .env.local`, `npm run db:migrate`, `npm run db:seed` (R9)
- [ ] `db:migrate` é `supabase db push`, `db:reset:local` é `supabase db reset --local`; `supabase/.temp/` ignorado
- [ ] Migrações em `supabase/migrations/`, registradas em `supabase_migrations.schema_migrations`, compatíveis com o código anterior (R10)
- [ ] Preview com branch do Supabase ou projeto separado, nunca o de produção
- [ ] `lib/supabase/server.ts` com `'server-only'`; `criarClienteAdmin()` só onde a RLS precisa ser ignorada, com autorização antes
- [ ] Pastas de rota em português e kebab-case; `not-found.tsx` devolvendo 404 real (R15)
- [ ] `'use client'` só nas folhas, com motivo
- [ ] `lib/db.ts` com `import 'server-only'`, cliente do usuário e métodos tipados (R5)
- [ ] Toda Server Action começa por autorização e validação Zod (R6/R7)
- [ ] `usuario_id` vem da sessão, nunca de `searchParams`
- [ ] Cores e raios por token do tema; nenhum hex solto no JSX
- [ ] Nenhum nome de classe montado em runtime
- [ ] Os quatro estados de tela implementados
- [ ] Nada sensível em variável `NEXT_PUBLIC_`; do Supabase, só URL e publishable key (R1)
- [ ] Cabeçalhos de segurança em `next.config.ts` (R7)
- [ ] `npm run build` passa antes do push; com acesso à conta, `vercel build` também
- [ ] `.vercel/` no `.gitignore`; `VERCEL_TOKEN` só em `.env` (R1, R16)
- [ ] `productionBrowserSourceMaps` ausente ou `false`; diagnóstico só com `VERCEL_ENV` diferente de `production`; nenhum endpoint de teste em produção
- [ ] `qa/roteiro-de-testes.md` gerado, executável na URL de preview (R11)
