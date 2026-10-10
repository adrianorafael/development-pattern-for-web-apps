# Bootstrap do ambiente: do clone limpo ao app rodando, sem passo escondido

> Regra **R9**. O ambiente é validado e o app sobe do zero com três comandos.
> `lib/env.ts` valida toda variável com Zod na carga: falta de variável quebra o build, com
> mensagem que diz qual e onde configurar. `.env.example` lista todas. `vercel env pull`,
> `npm run db:migrate` e `npm run db:seed` deixam um clone limpo funcionando. O seed cria o
> administrador de forma idempotente, com senha vinda de variável, nunca fixa.

Por que a falha importa: um projeto que só sobe na máquina de quem o escreveu já está
quebrado, só não foi descoberto. Os três sintomas aparecem juntos:

- **Variável faltando em produção.** O build passa, o deploy é promovido, e a primeira
  requisição que toca o banco devolve 500 com `Cannot read properties of undefined`. Ninguém
  sabe qual variável é, nem em qual ambiente.
- **Administrador criado à mão.** Alguém criou o usuário no painel do Supabase com uma senha
  que "depois troca", e marcou o papel editando `user_metadata`, que o próprio usuário altera.
  A senha não é trocada, e vive em algum histórico de terminal ou de conversa.
- **Senha padrão no código.** Um par como `admin` / `admin123` no seed versionado é a primeira
  coisa que um robô tenta. Com o repositório público, nem precisa tentar.

Versões conferidas em 2026-10-10: `next@16.4.0`, `vercel@63.1.2` (CLI), `supabase@2.120.0`
(CLI), `@supabase/supabase-js@2.117.3`, `@supabase/ssr@0.12.7`, `zod@4.6.5`,
`server-only@0.0.1`, Node `v24.21.0`.

---

## 1. Os comandos

Num clone limpo, com o projeto já criado na Vercel e o Supabase ligado pela integração do
Marketplace (ela cadastra `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`,
`SUPABASE_SECRET_KEY` e as `POSTGRES_*` em cada ambiente):

```bash
npm install                     # inclui o CLI do Supabase como devDependency (npm i -D supabase)
vercel link                     # liga a pasta ao projeto; cria .vercel/ (ignorado)
npx supabase link --project-ref SEU-PROJECT-REF   # uma vez: o projeto Supabase de Development

vercel env pull .env.local      # traz as variáveis de Development
npm run db:migrate              # supabase db push: aplica supabase/migrations/ pendentes (R10)
npm run db:seed                 # cria o administrador no Supabase Auth, se não existir
npm run dev                     # http://localhost:3000
```

`npm install`, `vercel link` e `supabase link` são preparação; os **três comandos** da regra
são `vercel env pull`, `db:migrate` e `db:seed`. Se o README pede qualquer passo além destes
(rodar SQL no painel, criar usuário à mão, copiar arquivo de alguém), a R9 não está cumprida.

`supabase link` grava o vínculo em `supabase/.temp/`, que o
[`gitignore.nextjs.template`](../assets/templates/gitignore.nextjs.template) ignora. O
`--project-ref` é o do projeto Supabase de **Development**, nunca o de produção: quem aplica
migração em produção é o fluxo de release ([migracoes-e-rollback.md](migracoes-e-rollback.md)).
Antes do primeiro `db:migrate`, confira na página da integração, no seu projeto, para qual
projeto Supabase apontam as variáveis do ambiente Development. Se for o de produção, não
rode nada contra ele: use o stack local abaixo ou crie um projeto separado para
desenvolvimento.

### Alternativa: o Supabase inteiro na sua máquina

Com Docker, o CLI sobe Postgres, Auth e Storage locais. Nada sai da máquina e o banco pode
ser apagado à vontade:

```bash
npx supabase start              # sobe o stack local (Docker); na primeira vez, roda o seed.sql
npm run db:reset:local          # supabase db reset --local: recria o banco, reaplica
                                # supabase/migrations/ e roda supabase/seed.sql
npx supabase status             # mostra a URL e as chaves do stack local
npm run db:seed                 # o administrador, agora no Auth local
```

Para o app e o seed falarem com o stack local, `NEXT_PUBLIC_SUPABASE_URL`,
`NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` e `SUPABASE_SECRET_KEY` em `.env.local` recebem os
valores que `supabase status` mostra. Lembre que um `vercel env pull .env.local` posterior
sobrescreve o arquivo. Fonte: supabase.com/docs/guides/local-development/seeding-your-database
("Seed files are executed the first time you run `supabase start` and every time you run
`supabase db reset`"), e a referência do CLI em supabase.com/docs/reference/cli (`db reset`
com `--local` ou `--linked`; `db push` com `--linked`, `--dry-run` e `--include-seed`),
conferidas em 2026-10-10. A doc de `supabase status` mostra, no exemplo, as chaves no formato
legado (`anon key`, `service_role key`, JWT `eyJ…`): por isso `lib/env.ts` e o seed aceitam
`sb_…` ou `eyJ…`.

⚠️ `supabase db reset --linked` **apaga o banco remoto** do projeto linkado. O script
`db:reset:local` leva `--local` escrito por extenso justamente para não depender do padrão.

### `supabase/seed.sql` e `scripts/seed.ts`: cada um no seu lugar

| Arquivo | Roda em | Guarda |
| --- | --- | --- |
| `supabase/seed.sql` | `supabase start` (1ª vez) e `supabase db reset`, locais; branch de preview do Supabase Branching | Dados **de referência sintéticos**: categorias, status, configurações. Nenhum usuário, nenhuma senha, nenhum dado pessoal |
| `scripts/seed.ts` (`npm run db:seed`) | Qualquer ambiente, contra o projeto das variáveis carregadas | O **administrador**, criado pela Auth Admin API, e, com `--com-exemplos`, chamados sintéticos |

O administrador não vai no `seed.sql`: criar usuário com `INSERT` direto em `auth.users`
contorna o Supabase Auth (hash, confirmação, identidades), e a senha ficaria escrita num
arquivo versionado. `supabase db push` não roda o `seed.sql` a menos que receba
`--include-seed`; o `db:migrate` desta skill **não** passa essa flag.

Os scripts do `package.json`:

```json
{
  "scripts": {
    "dev": "next dev",
    "prebuild": "node --conditions=react-server --env-file-if-exists=.env.local lib/env.ts",
    "build": "next build",
    "check:env": "node --conditions=react-server --env-file-if-exists=.env.local lib/env.ts",
    "db:migrate": "supabase db push",
    "db:migrate:conferir": "supabase db push --dry-run",
    "db:reset:local": "supabase db reset --local",
    "db:seed": "node --env-file-if-exists=.env.local scripts/seed.ts",
    "db:seed:exemplos": "node --env-file-if-exists=.env.local scripts/seed.ts --com-exemplos",
    "lint": "eslint ."
  }
}
```

Node 24 executa `.ts` direto por remoção de tipos, sem `tsx` e sem build (conferido no
`v24.21.0`: `process.features.typescript` vale `'strip'`). Os scripts só usam sintaxe
apagável: anotação de tipo, `import type`; nada de `enum` nem `namespace`.

| Comando | Modelo | Detalhe |
| --- | --- | --- |
| `lib/env.ts` | [`env.ts.template`](../assets/templates/env.ts.template) | §2 abaixo |
| `supabase/migrations/` | [`migration.sql.template`](../assets/templates/migration.sql.template) | [migracoes-e-rollback.md](migracoes-e-rollback.md) (R10) |
| `scripts/seed.ts` | [`seed.ts.template`](../assets/templates/seed.ts.template) | §3 abaixo |
| `lib/supabase/server.ts` | [`supabase-server.ts.template`](../assets/templates/supabase-server.ts.template) | [segredos-e-configuracao.md](segredos-e-configuracao.md) (R1) |
| `lib/supabase/browser.ts` | [`supabase-browser.ts.template`](../assets/templates/supabase-browser.ts.template) | [segredos-e-configuracao.md](segredos-e-configuracao.md) (R1) |
| `.env.example` | [`env.example.template`](../assets/templates/env.example.template) | [segredos-e-configuracao.md](segredos-e-configuracao.md) (R1) |

---

## 2. Validar o ambiente na carga

`lib/env.ts` descreve toda variável do servidor num esquema Zod e valida `process.env`
**uma vez**, no import. O resto do código lê `env.SUPABASE_SECRET_KEY`, nunca
`process.env.SUPABASE_SECRET_KEY` direto. A exceção única é `lib/supabase/browser.ts`, que
lê as duas variáveis `NEXT_PUBLIC_SUPABASE_` por extenso (o comentário do modelo diz por quê).

```ts
// ❌ cada arquivo lê do seu jeito; a falta aparece como 500 numa página qualquer
const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.SUPABASE_SECRET_KEY!);

// ✅ um lugar só, validado, tipado, e o cliente certo para o caso
import { criarClienteServidor } from '@/lib/supabase/server';
const supabase = await criarClienteServidor();
```

A mensagem de falha diz **qual** variável e **onde** configurar, e nunca imprime o valor
(o log de build é lido por mais gente que o painel). Saída real do modelo, rodado sem
variáveis:

```
Error: Variáveis de ambiente inválidas:
  - NEXT_PUBLIC_SUPABASE_URL: não definida
  - NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: não definida
  - SUPABASE_SECRET_KEY: não definida
  - ADMIN_EMAIL: não definida
  - NEXT_PUBLIC_SITE_URL: não definida

Configure no painel da Vercel (Project → Settings → Environment Variables), no ambiente
certo (Production, Preview ou Development), e rode `vercel env pull .env.local` para
trazer os valores de Development para a sua máquina.
```

### Por que o build quebra

`next build` não importa necessariamente todo módulo de servidor: uma rota dinâmica só
executa `lib/env.ts` na primeira requisição, depois do deploy. Por isso o `prebuild` roda o
arquivo direto no Node, **antes** do `next build`. O npm executa `prebuild` automaticamente
antes de `build`, inclusive no build da Vercel, onde as variáveis do ambiente já estão em
`process.env`.

A flag `--conditions=react-server` existe por causa do `server-only`: o `package.json` desse
pacote aponta a condição `react-server` para um arquivo vazio e a condição padrão para um
`index.js` que **lança erro** (conferido em `server-only@0.0.1`). Sem a flag, o Node puro
cai na condição padrão e o `prebuild` falha pelo motivo errado.

### `.env.example` e `lib/env.ts` têm as mesmas chaves

`lib/env.ts` exporta `CHAVES_DO_AMBIENTE`. Um teste compara com o `.env.example`:

```ts
// tests/env.test.ts (Vitest)
import { readFileSync } from 'node:fs';
import { expect, test, vi } from 'vitest';
vi.mock('server-only', () => ({}));

test('.env.example e lib/env.ts listam as mesmas chaves', async () => {
  vi.stubEnv('NEXT_PUBLIC_SUPABASE_URL', 'https://SEU-PROJETO.supabase.co');
  vi.stubEnv('NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY', 'sb_publishable_SUA-CHAVE-PUBLICA');
  vi.stubEnv('SUPABASE_SECRET_KEY', 'sb_secret_SUA-CHAVE-SECRETA');
  vi.stubEnv('ADMIN_EMAIL', 'usuario@example.com');
  vi.stubEnv('NEXT_PUBLIC_SITE_URL', 'https://seu-dominio.com.br');
  const { CHAVES_DO_AMBIENTE } = await import('@/lib/env');
  const exemplo = readFileSync('.env.example', 'utf8')
    .split('\n').map((l) => l.match(/^([A-Z0-9_]+)=/)?.[1]).filter(Boolean);
  expect(new Set(exemplo)).toEqual(new Set(CHAVES_DO_AMBIENTE));
});
```

---

## 3. O administrador inicial

### O seed

`scripts/seed.ts` lê `ADMIN_EMAIL` e `ADMIN_SENHA_INICIAL`, procura o e-mail no Supabase Auth
e, se não achar, cria o usuário pela Auth Admin API, com a secret key. Quem guarda e faz o
hash da senha é o Supabase Auth: o app nunca vê nem grava hash nenhum.

```ts
const { data, error } = await supabase.auth.admin.createUser({
  email,
  password: cfg.ADMIN_SENHA_INICIAL,
  email_confirm: true,
  user_metadata: { nome: cfg.ADMIN_NOME },
  app_metadata: { papel: 'admin', deve_trocar_senha: true },
});
```

Depois garante a linha em `public.perfis` (`id`, `nome`, `papel`) com
`upsert(..., { onConflict: 'id', ignoreDuplicates: true })`: cria se falta, não mexe se já
existe (por gatilho ou por seed anterior). `createUser`, `listUsers` e os campos
`app_metadata`, `user_metadata` e `email_confirm` conferidos em `@supabase/auth-js@2.117.3`
(`GoTrueAdminApi.d.ts` l.330 e l.356, `lib/types.d.ts` l.465-491), 2026-10-10.

**O papel vai em `app_metadata`, nunca em `user_metadata`.** O próprio usuário altera o
`user_metadata` com `supabase.auth.updateUser({ data })`; o `app_metadata` só muda com a
secret key. Política de RLS ou verificação de servidor que confia em `user_metadata` deixa
qualquer usuário se promover a administrador (supabase.com/docs/guides/database/postgres/row-level-security).

As quatro decisões do modelo, e o que cada uma evita:

| Decisão | Evita |
| --- | --- |
| Senha **só** de `ADMIN_SENHA_INICIAL`; ausente ou com menos de 12 caracteres, o seed recusa e sai com código 1 | Senha padrão no código. Não existe *fallback* |
| Procura o e-mail antes; se existe, não chama `createUser` nem `updateUserById` | Rodar o seed de novo apagar a senha que o administrador já trocou |
| `app_metadata.deve_trocar_senha = true` na criação | A variável continuar valendo como credencial depois do primeiro uso |
| O seed não importa `lib/env.ts` nem `lib/supabase/server.ts` | O erro do `server-only` fora do Next; o seed valida só as variáveis de que precisa |

```ts
// ❌ senha fixa no código: está no histórico do Git para sempre
const senha = process.env.ADMIN_SENHA_INICIAL ?? 'admin123';

// ✅ sem variável, sem administrador
if (!r.success) { /* lista o que falta */ process.exit(1); }
```

`ADMIN_SENHA_INICIAL` se cadastra com `vercel env add ADMIN_SENHA_INICIAL <ambiente>` (o CLI
pergunta o valor) ou no painel, **nunca colada na conversa com o agente**
([segredos-e-configuracao.md](segredos-e-configuracao.md), "Segredo não passa pela conversa").

### Troca obrigatória no primeiro login

Depois do login, se `app_metadata.deve_trocar_senha` é verdadeiro, o app redireciona para
`/trocar-senha` e não deixa abrir outra página até a troca. A conferência fica no layout da
área logada **e** em cada Server Action sensível, por `exigirSessao()` de `lib/sessao.ts`
(que usa `getClaims()`, nunca `getSession()`, e lê o papel de `app_metadata`), não só no
`proxy.ts`
([linha-de-base-de-seguranca.md](linha-de-base-de-seguranca.md) §5). A troca grava a senha
nova com `supabase.auth.updateUser({ password })`, zera a marca com
`criarClienteAdmin().auth.admin.updateUserById(id, { app_metadata: { deve_trocar_senha: false } })`
(o usuário não altera o próprio `app_metadata`), chama `supabase.auth.refreshSession()` para
o token novo já trazer a marca zerada (o `getClaims()` lê o `app_metadata` gravado no token,
não o do banco) e encerra as outras sessões com
`supabase.auth.signOut({ scope: 'others' })` (escopos `global`, `local` e `others`
conferidos em `@supabase/auth-js@2.117.3`, `lib/types.d.ts` l.2052).

Depois do primeiro login em produção, **apague `ADMIN_SENHA_INICIAL` do painel de
Production**: ela já não abre nada, e variável que não serve é só superfície.

### Alternativa: convite por e-mail

Quando o projeto já envia e-mail pelo Supabase Auth, o seed pode convidar o administrador em
vez de criá-lo com senha: `supabase.auth.admin.inviteUserByEmail(email)` (conferido em `@supabase/auth-js@2.117.3`,
`GoTrueAdminApi.d.ts`), seguido de `updateUserById` para gravar
`app_metadata: { papel: 'admin' }`. O link vai para `ADMIN_EMAIL` e a pessoa define a senha.
Nenhuma senha passa por variável. Escolha um dos dois caminhos e registre na spec.

---

## 4. Preview: banco próprio, dado sintético

Todo deploy de Preview é um ramo qualquer, aberto por qualquer colaborador. Ele **nunca**
aponta para o projeto Supabase de produção.

- **Banco:** um branch do Supabase por pull request (Supabase Branching), ou um projeto
  Supabase separado para Preview. O branch aplica as migrações de `supabase/migrations/` e o
  `supabase/seed.sql`, e **não copia os dados de produção**; é apagado no merge. Confira na
  página da integração, no seu projeto, que as variáveis do ambiente Preview apontam para o
  branch (ou para o projeto de Preview), e não para produção
  ([migracoes-e-rollback.md](migracoes-e-rollback.md)).
- **Administrador:** `ADMIN_EMAIL` e `ADMIN_SENHA_INICIAL` de Preview são **outros valores**,
  cadastrados no ambiente Preview do painel. Uma senha de preview que vaza não abre produção.
- **Dados:** `npm run db:seed:exemplos` acrescenta chamados **sintéticos**, idempotentes
  (só insere se o administrador não tem nenhum). O modelo recusa `--com-exemplos` quando
  `VERCEL_ENV=production`.
- **Chaves:** cada branch ou projeto tem URL, publishable key e secret key próprias. Um
  token de sessão emitido no preview não vale em produção, e a secret key de preview que
  vaza não alcança o banco real.

```
Production   projeto Supabase de produção        ADMIN_* de produção   sem exemplos
Preview      branch do Supabase por PR           ADMIN_* de preview    seed.sql + db:seed:exemplos
             (ou projeto separado de Preview)
Development  projeto de dev separado, ou o stack local (supabase start)    db:seed:exemplos
```

---

## 5. Casos de teste `CT-BOOT-nnn`

Os mesmos identificadores do [`roteiro-de-testes.template.md`](../assets/templates/roteiro-de-testes.template.md)
§4.1. 🖥 roda num terminal, por quem desenvolve; 🌐 o Cowork executa na URL de preview.

| Caso | Aprovado quando |
| --- | --- |
| CT-BOOT-001 🖥 · Clone limpo + `npm install`, `vercel link`, `supabase link`, `vercel env pull .env.local`, `npm run db:migrate`, `npm run db:seed`, `npm run dev` | 200 em `http://localhost:3000`, sem passo fora do README |
| CT-BOOT-002 🖥 · Remover uma variável obrigatória de `.env.local` e rodar `npm run build` | Falha no `prebuild`, nomeando a variável e onde configurá-la |
| CT-BOOT-003 🖥 · Variável com formato inválido (`SUPABASE_SECRET_KEY` que não começa com `sb_secret_` nem `eyJ`, ou `NEXT_PUBLIC_SUPABASE_URL` sem `https://`) | Falha com mensagem clara, sem imprimir o valor |
| CT-BOOT-004 🖥 · Chaves de `.env.example` contra as de `lib/env.ts` | Conjuntos idênticos |
| CT-BOOT-005 🖥 · `npm run db:seed` duas vezes | Um único usuário com aquele e-mail no Auth, um único perfil; a segunda execução diz "Nada alterado" |
| CT-BOOT-006 🖥 · Seed sem `ADMIN_SENHA_INICIAL`, e com ela de 8 caracteres | Recusa nos dois; nenhum administrador criado |
| CT-BOOT-007 🌐 · Login com o administrador do seed | Entra com a senha da variável e cai em `/trocar-senha` |
| CT-BOOT-008 🌐 · Procurar segredos no JavaScript servido (aba de rede): `sb_secret_`, `service_role`, `POSTGRES_` | Nenhuma ocorrência; só a URL e a publishable key do Supabase aparecem |
| CT-BOOT-009 🌐 · Depois de trocar a senha, rodar o seed de novo e entrar com a senha **inicial** | Recusado; a senha nova continua valendo |
| CT-BOOT-010 🖥 · `npm run db:seed:exemplos` com `VERCEL_ENV=production` | Recusa; nenhum chamado sintético |

---

## 6. Checklist

- [ ] `lib/env.ts` com `import 'server-only'` e esquema Zod de **toda** variável do servidor
- [ ] Nenhum `process.env.X` fora de `lib/env.ts` e dos scripts (`grep -rn "process.env" app lib`)
- [ ] `prebuild` roda `lib/env.ts` com `--conditions=react-server`; build falha sem variável
- [ ] `.env.example` com as mesmas chaves de `lib/env.ts`, um comentário por chave (CT-BOOT-004)
- [ ] `db:migrate` (`supabase db push`), `db:reset:local` (`supabase db reset --local`) e
      `db:seed` no `package.json`; README com os comandos da §1 e nada além
- [ ] `supabase/seed.sql` só com dado de referência sintético; nenhum usuário nem senha nele
- [ ] Seed idempotente, pela Auth Admin API, sem senha padrão, com
      `app_metadata: { papel: 'admin', deve_trocar_senha: true }`
- [ ] Papel lido de `app_metadata`, nunca de `user_metadata`
- [ ] Troca de senha obrigatória no primeiro login, conferida no layout e nas actions
- [ ] `ADMIN_SENHA_INICIAL` apagada do painel de Production depois do primeiro login
- [ ] Preview com branch do Supabase (ou projeto separado), `ADMIN_*` próprios, dado sintético
- [ ] CT-BOOT-001 a CT-BOOT-010 no roteiro de QA (R11)
