# Stack Next.js + Tailwind na Vercel

> Regra **R8** (metade Next.js): App Router, Server Components por padrão, Tailwind com
> tokens do tema, um componente por responsabilidade.

**Verifique as versões antes de escrever a primeira linha** (R4). Next.js 14 e 15 e
Tailwind v3 e v4 diferem em coisas que quebram silenciosamente:

```bash
grep -E '"(next|react|tailwindcss|typescript)"' package.json
npm ls next react tailwindcss
ls tailwind.config.* 2>/dev/null && echo "Tailwind v3" || echo "provável v4 (config em CSS)"
```

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

components/
├── ui/                       # primitivos sem regra de negócio: Botao, Campo, Modal, Tabela
└── chamados/                 # componentes do domínio: ListaChamados, FormChamado, StatusBadge

lib/
├── db.ts                     # acesso a dados: 'server-only'
├── auth.ts                   # sessão, exigirSessao()
├── validacoes.ts             # esquemas Zod compartilhados
└── utils.ts                  # cn(), formatarData()

actions/
└── chamados.ts               # Server Actions: 'use server'

types/
└── index.ts                  # tipos de domínio, fonte única
```

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
import { exigirSessao } from '@/lib/auth';
import { ListaChamados } from '@/components/chamados/lista-chamados';

export default async function PaginaChamados({
  searchParams,
}: { searchParams: Promise<{ status?: string }> }) {
  const sessao = await exigirSessao();
  const { status } = await searchParams;                 // Next 15: searchParams é Promise
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
import { neon } from '@neondatabase/serverless';

const sql = neon(process.env.DATABASE_URL!);

export async function listarChamadosDoUsuario(usuarioId: number, status?: string) {
  // ✅ template tag: cada ${} vira parâmetro vinculado (R5)
  if (status) {
    return sql`SELECT id, titulo, status, criado_em
               FROM chamados
               WHERE usuario_id = ${usuarioId} AND status = ${status}
               ORDER BY criado_em DESC LIMIT 100`;
  }
  return sql`SELECT id, titulo, status, criado_em
             FROM chamados
             WHERE usuario_id = ${usuarioId}
             ORDER BY criado_em DESC LIMIT 100`;
}
```

`usuario_id` entra na consulta a partir da **sessão**, nunca de `searchParams`, é a
diferença entre autorização e uma URL editável (R7).

Detalhes e as armadilhas de `unsafe`/`raw`: [sql-e-acesso-a-dados.md](sql-e-acesso-a-dados.md).

---

## 4. Server Actions: endpoints públicos com aparência de função

```ts
// actions/chamados.ts
'use server';
import { z } from 'zod';
import { revalidatePath } from 'next/cache';
import { exigirSessao } from '@/lib/auth';
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
- Confira o build de produção localmente antes de publicar: `npm run build && npm start`.
- Melhor ainda: **`vercel build`** reproduz o build da Vercel, com a configuração e as
  variáveis do ambiente escolhido: é o que pega a falha que só aparece no deploy.
  Quando um build falha, o ciclo de diagnóstico e correção é a R16.
  → [vercel-build-e-correcao.md](vercel-build-e-correcao.md)

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
- [ ] Pastas de rota em português e kebab-case; `not-found.tsx` devolvendo 404 real (R15)
- [ ] `'use client'` só nas folhas, com motivo
- [ ] `lib/db.ts` com `import 'server-only'` e consultas parametrizadas (R5)
- [ ] Toda Server Action começa por autorização e validação Zod (R6/R7)
- [ ] `usuario_id` vem da sessão, nunca de `searchParams`
- [ ] Cores e raios por token do tema; nenhum hex solto no JSX
- [ ] Nenhum nome de classe montado em runtime
- [ ] Os quatro estados de tela implementados
- [ ] Nada sensível em variável `NEXT_PUBLIC_` (R1)
- [ ] Cabeçalhos de segurança em `next.config.ts` (R7)
- [ ] `npm run build` passa antes do push; com acesso à conta, `vercel build` também
- [ ] `.vercel/` no `.gitignore`; `VERCEL_TOKEN` só em `.env` (R1, R16)
- [ ] `qa/roteiro-de-testes.md` gerado, executável na URL de preview (R11)
