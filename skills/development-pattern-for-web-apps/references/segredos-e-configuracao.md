# Segredos e configuração: nada sensível chega ao repositório

> Regra **R1**. É a única falha que um commit posterior não desfaz.
> Segredo publicado é segredo vazado: o histórico do Git, os forks, a API de eventos do
> GitHub e os caches de busca de código guardam. **Rotacionar é o único remédio; prevenir
> é a única estratégia.** Isso vale mesmo em repositório privado: privado hoje pode virar
> público amanhã, e o histórico vai junto.

---

## 1. O que conta como sensível

| Classe | Exemplos | Por que importa |
| --- | --- | --- |
| **Credenciais de banco** | `POSTGRES_URL`, `POSTGRES_URL_NON_POOLING`, `POSTGRES_PASSWORD` do Supabase, senha do banco | Acesso direto e total aos dados dos usuários, **sem passar pela RLS** |
| **Chave secret do Supabase** | `SUPABASE_SECRET_KEY` (`sb_secret_…`), ou a legada `service_role` (JWT `eyJ…`) | Usa o papel `service_role`, que ignora a RLS: lê e altera toda tabela, todo arquivo do Storage, cria e apaga usuários |
| **Chaves de API** | Stripe, Mercado Pago, Resend, SendGrid, OpenAI, Google Maps, reCAPTCHA *secret* | Cobrança na sua conta, envio em seu nome |
| **Segredos de sessão e token** | JWT secret legado do projeto Supabase, `JWT_SECRET`, chave de assinatura de cookie | Falsificação de sessão de qualquer usuário |
| **Arquivos de ambiente** | `.env`, `.env.local`, `.env.production.local` | Quase sempre contêm os três primeiros |
| **Acesso à plataforma** | `VERCEL_TOKEN`, chave SSH, token do GitHub | Controle da conta de deploy e dos domínios |
| **Pessoas** | e-mails reais, telefones, CPF, endereços em fixtures e dumps | Dado pessoal. LGPD, mesmo em projeto pessoal |
| **Dumps e backups** | `backup.sql`, `dump.sql`, `*.sql.gz` com dados reais | O vazamento mais comum e mais completo |
| **Capturas de tela** | print do painel da Vercel com variável revelada, nome de cliente real | Vaza contexto e às vezes token na URL |

**Um dump de banco no repositório é um vazamento de dados pessoais**, não um arquivo de
apoio. Se precisar de dados para desenvolver, gere um *seed* sintético
([bootstrap-do-ambiente.md](bootstrap-do-ambiente.md)).

---

## 2. Onde cada valor vive

| Lugar | O que guarda | Versionado? |
| --- | --- | --- |
| Painel da Vercel: *Project → Settings → Environment Variables* | Os valores reais, separados por ambiente: **Production**, **Preview**, **Development** | Não: vive na conta |
| `.env.local` | Cópia local dos valores de Development, baixada com `vercel env pull` | **Nunca** |
| `.env.example` | As mesmas chaves, com placeholder e um comentário por chave | **Sempre** |
| `lib/env.ts` | O esquema Zod que valida as variáveis na carga (R9) | Sempre |
| `.vercel/` | O vínculo da pasta com o projeto, criado por `vercel link` | **Nunca** |

`.env.example` não é opcional: é como você (ou outra pessoa) clona o repositório meses
depois e sabe o que precisa configurar. Toda chave nova entra no `.env.example`, no
`lib/env.ts` e no painel da Vercel **no mesmo commit** em que o código passa a lê-la.

### Cadastrar e baixar

```bash
# Uma vez por clone: liga a pasta ao projeto (cria .vercel/, que é ignorado)
vercel link

# Cadastrar uma variável por ambiente. O CLI pergunta o valor: ele não fica no histórico do shell.
vercel env add ADMIN_SENHA_INICIAL production
vercel env add ADMIN_SENHA_INICIAL preview
vercel env add ADMIN_SENHA_INICIAL development

# Trazer os valores de Development para a máquina local
vercel env pull .env.local

# Valores de Preview de um ramo específico, quando precisar reproduzir um preview
vercel env pull .env.preview.local --environment=preview --git-branch=SEU-RAMO
```

Conferido no pacote `vercel@63.1.2` (2026-10-10): `env pull` aceita `--environment`
(`production`, `preview` ou `development`) e `--git-branch`; `env add` aceita `--sensitive`
(ajuda do CLI: *"Store the value as a Secret"*). Use `--sensitive` para toda credencial de
produção.

As variáveis do Supabase (`NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`,
`SUPABASE_SECRET_KEY`, `POSTGRES_URL` e as demais) quem cadastra é a integração do Supabase
no Marketplace da Vercel (vercel.com/marketplace/supabase); você não as digita.

**Valores diferentes por ambiente, sempre.** Preview com a `POSTGRES_URL` ou a
`SUPABASE_SECRET_KEY` de produção é um ramo qualquer, aberto por qualquer colaborador,
escrevendo no banco real. Preview aponta para um **branch do Supabase** próprio (Supabase
Branching) ou para um projeto Supabase separado, nunca para o de produção
([migracoes-e-rollback.md](migracoes-e-rollback.md)). Como cada branch ou projeto tem URL e
chaves próprias, um token de sessão emitido no preview não abre sessão em produção.

### ⚠️ `NEXT_PUBLIC_` é público

Tudo com esse prefixo é embutido no bundle do navegador **no momento do build** e fica
visível para qualquer visitante em *DevTools → Sources*. Use-o só para valores que você
imprimiria na página: URL do site, ID público de analytics, chave *publishable* do Stripe.
**Do Supabase, só duas variáveis levam o prefixo:** `NEXT_PUBLIC_SUPABASE_URL` e
`NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`.

### Publishable x secret: as duas chaves do Supabase

| | Publishable | Secret |
| --- | --- | --- |
| Formato | `sb_publishable_…` (legada: `anon`, JWT `eyJ…`) | `sb_secret_…` (legada: `service_role`, JWT `eyJ…`) |
| Variável | `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | `SUPABASE_SECRET_KEY`, **sem** prefixo |
| Onde roda | Navegador e servidor | Só servidor: `criarClienteAdmin()` em `lib/supabase/server.ts` |
| O que alcança | Só o que a **RLS** permite ao usuário do token | Tudo: o papel `service_role` tem `BYPASSRLS` |
| Se vazar | Nada além do que a RLS já deixa qualquer visitante fazer | Banco inteiro, Storage inteiro, contas de usuário: **rotacione já** (§6) |

Fonte: supabase.com/docs/guides/api/api-keys, conferido em 2026-10-10. A mesma página diz
que a secret key "doesn't work in a browser": a Supabase reconhece o navegador pelo
`User-Agent` e responde 401. Isso não protege nada: quando o 401 acontece, a chave já está
no bundle, e qualquer um a usa de um `curl`. **A publishable key só é segura se a RLS
estiver ligada em toda tabela** ([sql-e-acesso-a-dados.md](sql-e-acesso-a-dados.md)): sem
RLS, a chave pública lê e escreve a tabela inteira.

```bash
# ❌ segredo exposto: vai parar no JavaScript que qualquer visitante baixa
NEXT_PUBLIC_SUPABASE_SECRET_KEY="sb_secret_SUA-CHAVE-SECRETA"                     # scan-secrets:allow
NEXT_PUBLIC_POSTGRES_URL="postgres://SEU-USUARIO:SUA-SENHA@SEU-HOST/SEU-BANCO"     # scan-secrets:allow
NEXT_PUBLIC_STRIPE_SECRET_KEY="sk_test_SUA-CHAVE"                                 # scan-secrets:allow

# ✅ segredo sem prefixo: só o código de servidor enxerga
SUPABASE_SECRET_KEY="sb_secret_SUA-CHAVE-SECRETA"
POSTGRES_URL="postgres://SEU-USUARIO:SUA-SENHA@SEU-HOST/SEU-BANCO?sslmode=require"
STRIPE_SECRET_KEY="sk_test_SUA-CHAVE"
# ✅ público de verdade: pode ter o prefixo
NEXT_PUBLIC_SUPABASE_URL="https://SEU-PROJETO.supabase.co"
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY="sb_publishable_SUA-CHAVE-PUBLICA"
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY="pk_test_SUA-CHAVE-PUBLICA"
```

O cliente do navegador recebe **só** URL e publishable key
([`../assets/templates/supabase-browser.ts.template`](../assets/templates/supabase-browser.ts.template)).
O cliente com a secret key vive num arquivo `server-only`
([`../assets/templates/supabase-server.ts.template`](../assets/templates/supabase-server.ts.template)).

Verificação mecânica antes de publicar:

```bash
grep -rn "NEXT_PUBLIC_" --include="*.ts" --include="*.tsx" --include=".env*" . \
  | grep -iE "secret|service_role|key|token|password|database|postgres" | grep -v PUBLISHABLE
# qualquer resultado é um vazamento em potencial

# a secret key não aparece em Client Component
grep -rlE "^['\"]use client['\"]" app components lib \
  | xargs grep -lE "SUPABASE_SECRET_KEY|SERVICE_ROLE|criarClienteAdmin" 2>/dev/null
# nada
```

### O módulo de servidor não pode ser importado pelo cliente

`import 'server-only'` no topo de `lib/env.ts`, `lib/db.ts` e `lib/supabase/server.ts`
transforma um import acidental a partir de um Client Component em **erro de build**, em vez
de vazar a secret key ou a string de conexão:

```ts
// lib/env.ts
import 'server-only';
```

O modelo completo, com o esquema Zod e a mensagem que diz qual variável falta e onde
configurá-la, está em [`../assets/templates/env.ts.template`](../assets/templates/env.ts.template).
O resto do código lê `env.SUPABASE_SECRET_KEY`, nunca `process.env.SUPABASE_SECRET_KEY`
direto: assim existe um único lugar onde a falta de uma variável é detectada (R9). A única
exceção é `lib/supabase/browser.ts`, que lê as duas `NEXT_PUBLIC_SUPABASE_` por extenso,
porque o Next só embute no bundle a variável pública escrita assim.

### `VERCEL_TOKEN`: só na máquina de quem diagnostica

O token pessoal (Vercel → *Account Settings → Tokens*) serve ao diagnóstico de build (R16) e
ao CLI em CI. A Vercel **não** precisa dele para fazer os próprios deploys a partir do Git.

- Crie com escopo mínimo (só o time necessário) e data de expiração.
- Guarde em `.env.local` ou no cofre de segredos do CI. Nunca em `.env.example` com valor,
  nunca no painel de variáveis do próprio projeto, onde todo deploy o enxergaria.
- Revogue quando não precisar mais.

### Segredo não passa pela conversa

A conversa com um agente de IA não é um lugar seguro para segredo. Ela fica no histórico da
ferramenta, pode ir para os servidores do provedor, aparece em captura de tela e em log, e
o agente pode repeti-la num commit, num arquivo ou numa mensagem de erro. Segredo que
passou pela conversa é segredo vazado.

| Situação | O que o agente faz |
| --- | --- |
| Precisa de um valor para rodar um comando | Lê de `.env.local` **sem ecoar**: carrega na variável de ambiente do processo, nunca `cat .env.local`, `echo $VAR`, `printenv` nem `set -x` |
| Precisa que a pessoa cadastre um valor | Manda rodar `vercel env add NOME ambiente` (o CLI pergunta o valor e ele não fica no histórico do shell) ou cadastrar no painel; **nunca pede para colar** o valor no chat |
| Precisa saber se a variável existe | Confere a presença, não o conteúdo: `grep -c '^SUPABASE_SECRET_KEY=' .env.local` |
| A pessoa colou um segredo na conversa mesmo assim | Avisa na hora que o valor deve ser tratado **como vazado** e segue o roteiro de rotação da §6. Não usa o valor colado, não o grava em arquivo |
| Saída de comando mostra um segredo | Não o repete na resposta; descreve ("a URL de conexão aparece na linha 12") |

```bash
# ❌ o valor vai parar na tela, no histórico e no contexto do agente
cat .env.local
echo "$SUPABASE_SECRET_KEY"

# ✅ carrega sem mostrar; só o comando que precisa enxerga o valor
set -a; . ./.env.local; set +a
npm run db:seed
```

O mesmo vale para o segredo de *bypass* da Deployment Protection usado pelo Cowork
([roteiro-de-testes-cowork.md](roteiro-de-testes-cowork.md)): ele fica configurado no
ambiente de quem testa, nunca colado na conversa.

---

## 3. O padrão de placeholder

Arquivo que **precisa** ser versionado mas referencia credencial vai com placeholder.
Nunca com valor real, nunca com valor real "temporário".

| Arquivo | Campo | Valor versionado |
| --- | --- | --- |
| `.env.example` | `POSTGRES_URL` | `postgres://SEU-USUARIO:SUA-SENHA@SEU-HOST-DO-POOLER/SEU-BANCO?sslmode=require` |
| `.env.example` | `SUPABASE_SECRET_KEY` | `sb_secret_SUA-CHAVE-SECRETA` |
| `.env.example` | `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | `sb_publishable_SUA-CHAVE-PUBLICA` |
| `.env.example` | `NEXT_PUBLIC_SUPABASE_URL` | `https://SEU-PROJETO.supabase.co` |
| `.env.example` | `ADMIN_SENHA_INICIAL` | `SUA-SENHA-INICIAL-COM-12-OU-MAIS` |
| `README.md` | domínio | `https://seu-dominio.com.br` |
| seeds e fixtures | e-mail | `usuario@example.com` |
| seeds e fixtures | CPF/telefone | `000.000.000-00`, `(00) 00000-0000` |

**O placeholder precisa ser obviamente falso e obviamente acionável.** `SUA-SENHA` diz ao
leitor para substituir. `senha123` não diz nada, e passa despercebido na revisão.

Para cada placeholder, uma linha no `.env.example` e no README dizendo exatamente o que
colocar e onde achar o valor ("criada pela integração do Supabase no Marketplace da Vercel;
localmente, venha de `vercel env pull`").

---

## 4. `.gitignore` armado antes do primeiro commit

Copie de [`../assets/templates/gitignore.nextjs.template`](../assets/templates/gitignore.nextjs.template).
Ele cobre `.env*` (com exceção explícita para `.env.example`), `.vercel/`, o estado local
do Supabase CLI (`supabase/.temp/`, `supabase/.branches/`), dumps `*.sql` fora de
`supabase/migrations/` e de `supabase/seed.sql`, e chaves `*.pem`.

Uma entrada no `.gitignore` **não faz nada** por um arquivo que o Git já rastreia. Confira:

```bash
git check-ignore -v .env.local .vercel     # deve imprimir a regra que casou para cada um
git ls-files | grep -Ei '(^|/)\.env($|\.)|\.vercel/|\.pem$|\.sql\.gz$|dumps?/|backups?/' \
  | grep -v '\.env\.example$'               # nada
```

Se um arquivo sensível já está rastreado:

```bash
git rm --cached .env.local     # para de rastrear, mantém em disco
# commit da remoção, e trate o valor como comprometido: ROTACIONE.
```

---

## 5. Varredura antes de cada commit: obrigatória

```bash
bash skills/development-pattern-for-web-apps/assets/scripts/scan-secrets.sh
git diff --cached | bash skills/development-pattern-for-web-apps/assets/scripts/scan-secrets.sh --stdin
```

O que o scanner procura:

| Padrão | Pega |
| --- | --- |
| `SUPABASE_SECRET_KEY=...`, `SUPABASE_SERVICE_ROLE_KEY=...`, `POSTGRES_URL=...`, `password: '...'` | Credencial embutida em código ou config |
| `postgres://`, `postgresql://`, `redis://`, `mongodb+srv://` com credencial | String de conexão completa |
| `sb_secret_` seguido de 20 ou mais caracteres | Chave secret do Supabase |
| `sk_live_`, `rk_live_`, `AKIA…`, `ghp_`, `re_`, `SG.`, `vercel_` | Chaves de Stripe, AWS, GitHub, Resend, SendGrid, Vercel |
| `NEXT_PUBLIC_` seguido de `SECRET`, `SERVICE_ROLE`, `TOKEN`, `PASSWORD`, `PRIVATE`, `DATABASE` | Segredo prestes a ir para o navegador |
| `-----BEGIN … PRIVATE KEY-----` | Chave privada |
| `eyJ…` com três segmentos | JWT com payload legível, inclusive as chaves legadas `anon` e `service_role` |
| `.env*`, `.vercel/`, `*.pem`, dumps rastreados pelo Git | Arquivo que nunca deveria estar lá |
| e-mails e CPFs em massa | Dado pessoal em fixture ou dump |

**Qualquer achado: pare.** Substitua por placeholder, rode de novo, e diga ao usuário o que
foi encontrado e o que foi trocado. O scan limpo é **necessário, não suficiente**: leia o
seu próprio diff.

### O scanner ativo: hook oferecido, instalado com o sim

Rodar o scanner "quando lembrar" é o mesmo que não rodar. Por isso a Fase 0 **oferece** o
hook [`../assets/templates/pre-commit.template`](../assets/templates/pre-commit.template)
(e o `commit-msg.template`, R18) ao dono do projeto, e o agente **instala com o sim dele**,
antes do primeiro commit. Sem o sim, não instala, e registra na spec que os scanners rodam à
mão antes de cada commit. Instalar hook sem perguntar muda o comportamento do Git na máquina
de outra pessoa; não oferecer deixa a regra dependendo de memória.

```bash
cp skills/development-pattern-for-web-apps/assets/templates/pre-commit.template .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

O hook bloqueia o commit quando o scanner acusa algo no conteúdo staged e quando um arquivo
com `'use client'` cita a secret key ou `criarClienteAdmin`.

**A segunda rede fica no GitHub: push protection.** O hook vive na máquina e se desliga com
`--no-verify`; a push protection recusa o push no servidor. Para a conta pessoal, a doc do
GitHub diz que ela "is enabled by default" e barra segredo em push para repositório
**público**. Em repositório **privado** (o padrão desta skill, R2), a push protection do
repositório "requires GitHub Secret Protection to be enabled" (docs.github.com/en/code-security/secret-scanning/introduction/about-push-protection,
conferido em 2026-10-10): ligue em *Settings → Advanced Security* se o plano da conta
permitir. Se não permitir, o hook e o scanner no CI são a rede; diga isso ao usuário em vez
de presumir que o GitHub protege.

---

## 6. Se um segredo já foi enviado

Diga ao usuário imediatamente e com todas as letras. Depois, nesta ordem:

1. **Rotacione primeiro.** Revogue a chave de API no painel do provedor, revogue o
   `VERCEL_TOKEN`, e siga o roteiro do Supabase abaixo. Atualize o valor no painel da Vercel e
   faça **redeploy**: a variável nova só vale para deploys criados depois da troca. Faça
   tudo isso **antes** de mexer no Git: reescrever histórico leva minutos, e a credencial
   fica exposta o tempo inteiro.
2. **Depois limpe o histórico.** `git filter-repo --path .env.local --invert-paths`, ou apague
   e recrie o repositório se ele é novo, sem forks e sem stars. Avise que forks e caches
   podem manter a cópia de qualquer forma.
3. **Depois previna a repetição.** Acrescente o padrão ao scanner, ofereça o hook (e instale
   com o sim do usuário), ligue a push protection do GitHub se o plano permitir.

Não conserte em silêncio. A rotação é uma decisão do dono do projeto e ele precisa saber.

### Roteiro do Supabase: chave secret vazada

A ordem é a da doc (supabase.com/docs/guides/api/api-keys, conferido em 2026-10-10):

1. **Corrija a causa** antes de girar qualquer coisa ("Fix the root cause of the leak
   before you rotate anything"): tire a chave do código, do log, do bundle. Chave nova num
   lugar que vaza vaza de novo.
2. **Crie uma secret key nova** no painel do Supabase, em *Settings → API Keys*.
3. **Troque em todo lugar** que usa a antiga: `SUPABASE_SECRET_KEY` no painel da Vercel, em
   **cada** ambiente (Production, Preview, Development), no cofre do CI, no `.env.local` de
   quem desenvolve (`vercel env pull .env.local` de novo). Faça **redeploy** de Production.
4. **Confirme** que todo componente já usa a nova: deploy novo no ar, seed e scripts
   rodando, nenhum erro de autenticação no log.
5. **Só então apague a vazada.** Apagar uma secret key "can't be undone": se algum
   componente ainda usava a antiga, ele para. As chaves legadas (`anon`, `service_role`) se
   **desativam** na mesma tela, e a desativação é reversível.

Vazou a **senha do banco** (`POSTGRES_PASSWORD`, ou uma `POSTGRES_URL` com ela)? Troque a
senha do banco no painel do Supabase também; as variáveis `POSTGRES_*` da Vercel passam a
precisar do valor novo. Confira na página da integração, no seu projeto, se ela atualiza
essas variáveis sozinha ou se é preciso editá-las; não presuma. Redeploy em seguida.

A publishable key vazada não exige rotação: ela já é pública por desenho. O que precisa de
conferência, nesse caso, é a RLS (CT-SEC-031 e CT-SEC-032).

---

## 7. Checklist de configuração de um projeto novo

- [ ] `.gitignore` copiado **antes** do primeiro commit, com `.env*` e `.vercel/`
- [ ] `vercel link` feito; `.vercel/` confirmado como ignorado com `git check-ignore`
- [ ] Variáveis cadastradas no painel da Vercel **por ambiente**, com valores distintos
      entre Production e Preview; credenciais de produção cadastradas com `--sensitive`
- [ ] `.env.local` baixado com `vercel env pull`; `.env.example` versionado com as mesmas chaves
- [ ] `lib/env.ts` valida toda variável com Zod e começa com `import 'server-only'` (R9)
- [ ] Nada sensível com `NEXT_PUBLIC_`; o `grep` da seção 2 sai vazio
- [ ] Do Supabase, só `NEXT_PUBLIC_SUPABASE_URL` e `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` com o
      prefixo; `SUPABASE_SECRET_KEY` só em `lib/supabase/server.ts` (`criarClienteAdmin`)
- [ ] Preview com branch do Supabase ou projeto separado, nunca as chaves de produção
- [ ] Nenhum segredo pedido, colado ou ecoado na conversa com o agente de IA
- [ ] `VERCEL_TOKEN` só na máquina de quem diagnostica, com escopo mínimo e expiração
- [ ] `scan-secrets.sh` limpo no working tree **e** no conteúdo staged
- [ ] Hook de pre-commit oferecido na Fase 0 e instalado com o sim do usuário (ou a recusa
      registrada na spec); push protection do GitHub ligada, se o plano permitir
- [ ] Repositório remoto confirmado como privado (R2)
- [ ] README diz, chave por chave, o que preencher e onde achar o valor
