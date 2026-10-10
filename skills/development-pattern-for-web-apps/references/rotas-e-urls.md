# Rotas e URLs: a URL é interface, não detalhe de implementação

> Regra **R15**. Toda URL descreve a ação ou o recurso em linguagem humana, em português:
> `/cadastrar-novo-usuario`, nunca `/users/new` nem `/usuarios?acao=novo`. Detalhe técnico
> (`/api/`, id interno sem necessidade, inglês, camelCase) não aparece em URL de página, e a
> navegação nunca depende de query string.

```
❌ https://seu-dominio.com.br/users/new
❌ https://seu-dominio.com.br/usuarios?acao=novo
✅ https://seu-dominio.com.br/cadastrar-novo-usuario

❌ https://seu-dominio.com.br/tickets/detail?id=8
✅ https://seu-dominio.com.br/chamados/8/impressora-nao-imprime
```

A URL é a parte da aplicação que **sai dela**: vai para o histórico do navegador, para os
favoritos, para o WhatsApp de quem compartilha, para o índice do Google, para o log da
Vercel. Ela é a única parte da interface que sobrevive a uma reescrita do front-end: e por
isso é a única que não pode ser um detalhe de implementação.

**No App Router a pasta é a URL.** `app/users/new/page.tsx` publica `/users/new`. Não existe
um mapa de rotas separado onde corrigir isso depois: **a regra de URL é a regra de nome de
pasta**. Quem cria a pasta decide a URL pública, e renomear a pasta mais tarde quebra todo
link publicado.

---

## 1. As sete convenções

Valem para o nome de cada pasta dentro de `app/` que vira segmento de URL.

| # | Convenção | Sim | Não |
| --- | --- | --- | --- |
| 1 | **Português, minúsculas, kebab-case** | `app/redefinir-senha/` | `app/redefinirSenha/`, `app/redefinir_senha/`, `app/reset-password/` |
| 2 | **Sem acento e sem cedilha**: o percent-encoding torna a URL ilegível ao ser copiada | `app/manutencao/` | `app/manutenção/` → `/manuten%C3%A7%C3%A3o` |
| 3 | **Sem extensão e sem detalhe técnico** em URL de página | `/contato` | `/contato.html`, `/api/contato` como página, `/pages/contato` |
| 4 | **Sem estrutura interna do projeto** | `/chamados` | `/app/chamados`, `/components/lista-chamados` |
| 5 | **Ação = verbo no infinitivo** | `app/cadastrar-novo-usuario/`, `app/recuperar-acesso/` | `app/users/new/`, `app/signup/`, `app/form2/` |
| 6 | **Coleção = substantivo plural; item = coleção + identificador** | `app/chamados/`, `app/chamados/[id]/` | `/chamado?id=8`, `/listarChamados` |
| 7 | **Navegação nunca depende de query string** | `app/chamados/[id]/anexos/` | `/chamados?acao=anexos&id=8`, `/usuarios?acao=novo` |

### O que a query string pode fazer

Ela não some: ela muda de papel. Serve para **estado da visualização**, não para
roteamento:

```
✅ /chamados?status=fechado&ordenar=data&pagina=2      filtro, ordenação, paginação
✅ /produtos?busca=teclado+mecanico                     busca
❌ /?pagina=chamados                                    roteamento disfarçado
❌ /chamados?acao=excluir&id=8                          roteamento E efeito colateral
```

A vantagem é concreta: `/chamados?status=fechado` é compartilhável e favoritável: o
destinatário vê exatamente a mesma tela. Já `/?pagina=chamados` não significa nada que a
própria pasta não pudesse dizer melhor.

### `/api/` é para máquina, não para gente

Route Handlers (`app/api/**/route.ts`) servem webhook, integração e chamada de cliente. Eles
podem ficar em inglês se o contrato externo exigir. Mas **nenhuma tela** mora sob `/api/`, e
nenhum link que o usuário vê aponta para lá. Formulário de tela chama Server Action, não
`fetch('/api/...')`. → [stack-nextjs-vercel.md](stack-nextjs-vercel.md)

---

## 2. Regras que evitam dor depois

**Um recurso, uma URL canônica.** Se `/chamados/8` e `/chamados/8/` respondem 200 com o
mesmo conteúdo, você tem duas URLs para uma coisa: histórico dividido, SEO dividido, cache
dividido. Escolha uma forma e responda com **redirecionamento permanente** na outra. O Next
já faz isso com a barra final: com `trailingSlash` no padrão (`false`), `/chamados/` recebe
308 para `/chamados` (`next@16.4.0`, `dist/lib/load-custom-routes.js`). Maiúsculas não são
tratadas sozinhas: `/Chamados` → permanente → `/chamados` fica a cargo do `proxy.ts` (§4).

**`GET` nunca tem efeito colateral.** `/chamados/8/excluir` como link é um convite ao
desastre: o pré-carregamento do navegador (e o prefetch do `<Link>`), o robô de indexação
ou um antivírus corporativo abrem links sozinhos. Excluir é Server Action (que é `POST`) ou
Route Handler `DELETE`, nunca uma página. → [entrada-e-saida-seguras.md](entrada-e-saida-seguras.md)

**Renomear uma pasta de rota é uma mudança MAJOR.** Links publicados quebram, e você não
controla quem os publicou. Ao renomear, mantenha a antiga respondendo **301** por pelo menos
uma versão maior, em `redirects()` do `next.config.ts`, e registre no CHANGELOG.
→ [release-e-deploy.md](release-e-deploy.md)

**Cuidado com o ID sequencial exposto.** `/chamados/8` diz ao mundo que existem pelo menos 8
chamados, e convida a testar `/chamados/9`. Isso não é uma falha por si só: a defesa contra
IDOR é a autorização, sempre (R7), mas em recurso público ou sensível prefira um slug ou um
identificador não adivinhável:

```
/chamados/8                                   interno, autorizado por dono: aceitável
/chamados/8/impressora-nao-imprime            legível, e o slug não precisa bater
/relatorios/a7f3c1e9-4b2d-4f8a-9c1e-...       público ou sensível: use UUID
```

O identificador continua sendo validado e a autorização continua entrando na cláusula
`WHERE`. URL bonita não é controle de acesso.

**404 é 404.** Uma página "não encontrado" servida com status 200 confunde navegador, cache,
robô de indexação e o seu próprio roteiro de QA. Devolva o status certo: `notFound()`.

---

## 3. A pasta é a URL

No App Router, o caminho da pasta **é** a rota. A convenção de nomes de pasta é a convenção
de URLs, e não há um mapa separado para manter em sincronia.

```
app/
├── page.tsx                                  →  /
├── not-found.tsx                             →  404 de verdade, com a cara do app
├── entrar/page.tsx                           →  /entrar
├── cadastrar-novo-usuario/page.tsx           →  /cadastrar-novo-usuario
├── recuperar-acesso/page.tsx                 →  /recuperar-acesso
├── redefinir-senha/[token]/page.tsx          →  /redefinir-senha/SEU-TOKEN
├── politica-de-privacidade/page.tsx          →  /politica-de-privacidade (pública, link no rodapé)
├── (painel)/                                 →  grupo: NÃO entra na URL
│   ├── layout.tsx                            →  verifica a sessão do grupo inteiro
│   ├── chamados/page.tsx                     →  /chamados
│   ├── chamados/[id]/page.tsx                →  /chamados/8
│   ├── chamados/[id]/[slug]/page.tsx         →  /chamados/8/impressora-nao-imprime
│   ├── abrir-chamado/page.tsx                →  /abrir-chamado
│   └── administracao/page.tsx                →  /administracao
└── api/webhooks/pagamento/route.ts           →  POST /api/webhooks/pagamento (máquina)
```

- **Pastas em português, kebab-case.** `cadastrar-novo-usuario`, nunca `signup`, `users/new`
  ou `NewUser`.
- **Grupos de rota `(painel)` não aparecem na URL**: use-os para compartilhar layout e
  verificação de sessão sem poluir o caminho.
- **`[id]` é dinâmico**; `[...slug]` captura o resto. `params` é uma `Promise` (desde o
  Next 15, e continua no 16): `const { id } = await params;`
- **Arquivos especiais não viram rota:** `layout.tsx`, `loading.tsx`, `error.tsx`,
  `not-found.tsx`. Use `not-found.tsx` + `notFound()` para devolver **404 de verdade**.
- **Pasta com `_` na frente é privada** (`_componentes/`) e não vira rota: útil para colocar
  código ao lado da página sem criar URL acidental.

```tsx
// app/(painel)/chamados/[id]/page.tsx
import { notFound } from 'next/navigation';
import { exigirSessao } from '@/lib/auth';
import { buscarChamado } from '@/lib/db';
import { DetalheChamado } from '@/components/chamados/detalhe-chamado';

export default async function Pagina({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const numero = Number(id);
  if (!Number.isInteger(numero) || numero < 1) notFound();      // 404 real (R6)

  const sessao = await exigirSessao();
  const chamado = await buscarChamado(numero, sessao.usuarioId); // o dono no WHERE (R7)
  if (!chamado) notFound();                                      // 404, não 403

  return <DetalheChamado chamado={chamado} />;
}
```

O `[id]` chega como **texto**: a página valida antes de usar (R6), e o dono entra na consulta
(R7). A pasta dinâmica não valida nada por você.

### Canonicalização de caixa no `proxy.ts`

No Next 16 a convenção `middleware.ts` virou **`proxy.ts`** (`next@16.4.0`,
`dist/lib/constants.js`: `PROXY_FILENAME = 'proxy'`). O arquivo exporta uma função `proxy`
(ou `default`):

```ts
// proxy.ts (na raiz, ou em src/)
import { NextResponse, type NextRequest } from 'next/server';

export function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const minusculo = pathname.toLowerCase();
  if (pathname !== minusculo) {
    const url = request.nextUrl.clone();
    url.pathname = minusculo;
    return NextResponse.redirect(url, 308);   // permanente, preserva o método
  }
  return NextResponse.next();
}

export const config = {
  // páginas apenas: fora _next/, api/ e arquivos com extensão
  matcher: ['/((?!_next/|api/|.*\\..*).*)'],
};
```

Se a rota tiver segmento que precisa de maiúscula (um token, por exemplo), exclua-o do
`matcher` em vez de deixar o redirect estragar o valor.

### Gerando URLs no código: o helper `rota()`

Nunca escreva a URL à mão duas vezes. Um helper, e o dia da renomeação tem um lugar só:

```ts
// lib/rotas.ts
const MODELOS = {
  'chamados':      '/chamados',
  'chamado':       '/chamados/[id]',
  'chamado.slug':  '/chamados/[id]/[slug]',
  'abrir-chamado': '/abrir-chamado',
  'cadastrar':     '/cadastrar-novo-usuario',
} as const;

export function rota(
  nome: keyof typeof MODELOS,
  params: Record<string, string | number> = {},
): string {
  return MODELOS[nome].replace(/\[(\w+)\]/g, (_, chave: string) => {
    const valor = params[chave];
    if (valor === undefined) throw new Error(`rota('${nome}'): falta o parâmetro ${chave}`);
    return encodeURIComponent(String(valor));
  });
}
```

```tsx
import Link from 'next/link';
import { rota } from '@/lib/rotas';

<Link href={rota('chamado.slug', { id: c.id, slug: c.slug })}>{c.titulo}</Link>
```

Com `typedRoutes: true` no `next.config.ts` (chave de topo e estável no Next 16,
`dist/server/config-shared.d.ts`), o TypeScript também recusa `href` para rota que não
existe. As duas coisas se somam: o tipo pega o erro, o helper concentra a mudança.

### Gerando o slug

```ts
// lib/slug.ts
export function slugify(texto: string): string {
  const s = texto
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')      // remove acentos: "ção" → "cao"
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
  return s || 'sem-titulo';
}
```

O slug é **decorativo**: quem identifica o registro é o `[id]`. Assim, mudar o título não
quebra o link antigo: a página compara o slug recebido com o atual e, se divergir,
`permanentRedirect(rota('chamado.slug', { id, slug: atual }))` (de `next/navigation`).

### Redirecionamentos de rotas antigas

Ficam em `next.config.ts`, versionados junto com o código. Ponto de partida pronto em
[`next.config.ts.template`](../assets/templates/next.config.ts.template).

```ts
// next.config.ts
import type { NextConfig } from 'next';

const config: NextConfig = {
  async redirects() {
    return [
      { source: '/signup',        destination: '/cadastrar-novo-usuario', statusCode: 301 },
      { source: '/users/new',     destination: '/cadastrar-novo-usuario', statusCode: 301 },
      { source: '/novo-chamado',  destination: '/abrir-chamado',          permanent: true },
    ];
  },
};

export default config;
```

Atenção ao número (`next@16.4.0`, `dist/lib/redirect-status.js`): `permanent: true` emite
**308**, não 301; `permanent: false` emite 307. Para 301 literal use `statusCode: 301` (as
duas chaves são mutuamente exclusivas no tipo `Redirect`). Navegadores e buscadores tratam
301 e 308 como permanentes; o 308 também preserva o método. Escolha um e use sempre o mesmo.
Use 307 só enquanto a mudança for reversível.

A query string **não** casa no `source`: para redirecionar `/usuarios?acao=novo`, use `has`
com `type: 'query'` no mesmo objeto.

---

## 4. Tabela de tradução

Use como referência ao renomear pastas de um projeto que nasceu com nomes técnicos:

| Antes | Depois |
| --- | --- |
| `/home` | `/` |
| `/signup`, `/users/new`, `/usuarios?acao=novo` | `/cadastrar-novo-usuario` |
| `/users` | `/usuarios` |
| `/users/8/edit` | `/usuarios/8/editar` |
| `/login` | `/entrar` |
| `/logout` | Server Action `sair()`, nunca um `GET` |
| `/forgot-password` | `/recuperar-acesso` |
| `/privacy`, `/privacy-policy` | `/politica-de-privacidade` |
| `/reset-password?token=SEU-TOKEN` | `/redefinir-senha/SEU-TOKEN` |
| `/tickets/detail?id=8` | `/chamados/8` |
| `/tickets/new` | `/abrir-chamado` |
| `/tickets/delete?id=8` | Server Action `excluirChamado(8)`, nunca um `GET` |
| `/admin` | `/administracao` |
| `/api/tickets` usado como página | página `/chamados`; `/api/` fica só para máquina |
| `/report?type=monthly&year=2026` | `/relatorios/mensal/2026` |

Note o último: o que identifica o recurso vira caminho; o que filtra a visualização continua
em query string.

---

## 5. Checklist

- [ ] Toda pasta de rota em `app/` em português, minúsculas, kebab-case, sem acento e sem underscore
- [ ] Ações são verbos no infinitivo; coleções são substantivos plurais
- [ ] Nenhuma tela sob `/api/`; nenhuma URL de página com extensão ou nome de pasta interna
- [ ] Nenhuma navegação depende de query string; ela só carrega filtro, ordenação e paginação
- [ ] Nenhum `GET` com efeito colateral: excluir, fechar e sair são Server Actions
- [ ] Forma canônica definida (barra final pelo Next, caixa pelo `proxy.ts`) e a divergente redireciona de forma permanente
- [ ] Pastas renomeadas mantêm 301 da antiga em `next.config.ts`, registrado no CHANGELOG
- [ ] Página inexistente responde **404** (`not-found.tsx` + `notFound()`), não 200
- [ ] URLs geradas por `rota()`, nunca escritas à mão duas vezes; `typedRoutes` ligado
- [ ] O `[id]` é validado na página (`await params`), e o dono entra na cláusula `WHERE` (R6, R7)
- [ ] `proxy.ts`, não `middleware.ts` (Next 16)
- [ ] Casos de rota no roteiro de QA (R11), incluindo os redirecionamentos e o 404

---

## 6. O que testar (entra no roteiro de QA, R11)

Os identificadores são os do [`roteiro-de-testes.template.md`](../assets/templates/roteiro-de-testes.template.md),
seção 6.1, mais dois da suíte de segurança.

| ID | Caso | Resultado esperado |
| --- | --- | --- |
| CT-UI-020 | Cada pasta de rota, acessada diretamente pela barra de endereço | 200 e a tela correta: nada depende de ter vindo de outra página |
| CT-UI-021 | Recarregar (F5) em qualquer rota interna | A mesma tela, sem perder estado nem reenviar formulário |
| CT-UI-022 | Botão Voltar depois de navegar por três telas | Volta na ordem certa |
| CT-UI-023 | URL com barra final (`/chamados/`) e com maiúsculas (`/Chamados`) | Redirecionamento permanente (308 pelo Next e pelo `proxy.ts`) para `/chamados` |
| CT-UI-024 | Rota antiga da tabela de redirecionamentos (`/signup`) | 301 para a nova |
| CT-UI-025 | URL inexistente (`/pagina-que-nao-existe`) | **404** com a página de erro do app, não 200 |
| CT-UI-026 | `/chamados/abc` (id não numérico) e `/chamados/999999` (inexistente) | 404, sem erro 500 e sem mensagem do banco |
| CT-SEC-009 | `/chamados/{id de outro usuário}` | 404, não 403 (R7) |
| CT-UI-027 | Compartilhar `/chamados?status=fechado&pagina=2` em outra sessão | A mesma visualização filtrada |
| CT-UI-028 | Qualquer URL de página da aplicação | Em português, sem `/api/`, sem extensão, sem nome de pasta interna |
| CT-SEC-028 | `/.env`, `/.env.local`, `/.git/config` | 404, nunca conteúdo |
