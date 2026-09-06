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
| **Credenciais de banco** | host, usuário, senha, nome do banco na Hostinger; `DATABASE_URL` do Neon/Supabase | Acesso direto e total aos dados dos usuários |
| **Chaves de API** | Stripe, Mercado Pago, SendGrid, Resend, OpenAI, Google Maps, reCAPTCHA *secret* | Cobrança na sua conta, envio em seu nome |
| **Segredos de sessão e token** | `APP_KEY`, `JWT_SECRET`, `NEXTAUTH_SECRET`, chave de assinatura de cookie | Falsificação de sessão de qualquer usuário |
| **Arquivos de ambiente** | `.env`, `.env.local`, `.env.production`, `config.local.php` | Quase sempre contêm os três acima |
| **Acesso à hospedagem** | senha de FTP, chave SSH, `VERCEL_TOKEN`, `.ftpconfig`, `sftp.json` do VS Code | Controle do servidor e da conta de deploy |
| **Pessoas** | e-mails reais, telefones, CPF, endereços em fixtures e dumps | Dado pessoal. LGPD, mesmo em projeto pessoal |
| **Dumps e backups** | `backup.sql`, `dump.sql`, `*.sql.gz` com dados reais | O vazamento mais comum e mais completo |
| **Capturas de tela** | print do painel com nome de cliente real | Vaza contexto e às vezes token na URL |

**Um dump de banco no repositório é um vazamento de dados pessoais**, não um arquivo de
apoio. Se precisar de dados para desenvolver, gere um *seed* sintético.

---

## 2. O par obrigatório: valor real fora, chaves dentro

```
.env            # IGNORADO: os valores reais vivem aqui, e só aqui
.env.example    # VERSIONADO: as mesmas chaves, valores placeholder, um comentário por chave
```

`.env.example` não é opcional: é como você (ou outra pessoa) clona o repositório meses
depois e sabe o que precisa configurar. Toda chave nova entra nos dois arquivos no mesmo
commit.

### PHP na Hostinger

Shared hosting não tem variáveis de ambiente de verdade. As duas formas aceitas, nesta
ordem de preferência:

**a) Arquivo de configuração fora do webroot**: o mais seguro em hospedagem compartilhada:

```
/home/usuario/
├── config/
│   └── app.config.php        ← fora do public_html: o Apache nunca serve este caminho
└── public_html/
    ├── index.php
    └── ...
```

```php
// public_html/bootstrap.php
$config = require dirname(__DIR__) . '/config/app.config.php';
```

**b) Arquivo dentro do projeto, ignorado e protegido**: quando não há acesso acima do
`public_html`:

```
config/config.local.php     ← no .gitignore, e protegido por .htaccess
```

```apache
# config/.htaccess: se o arquivo for movido para dentro do webroot por engano,
# o servidor ainda recusa servi-lo.
<FilesMatch "\.(php|ini|env|sql|log)$">
  Require all denied
</FilesMatch>
```

Confirme com o navegador, não com a intenção: `https://seu-dominio.com.br/config/config.local.php`
deve responder **403**, nunca 200 nem o código-fonte.

### Next.js na Vercel

Variáveis de ambiente reais ficam **no painel da Vercel** (Project → Settings → Environment
Variables), separadas por ambiente (Production / Preview / Development). Localmente, em
`.env.local` (ignorado por padrão pelo `create-next-app`).

```bash
# .env.example: versionado, só placeholders
DATABASE_URL="postgres://SEU-USUARIO:SUA-SENHA@SEU-HOST/SEU-BANCO?sslmode=require"
AUTH_SECRET="GERE-COM-openssl-rand-base64-32"
RESEND_API_KEY="re_SUA-CHAVE-AQUI"
NEXT_PUBLIC_SITE_URL="https://seu-dominio.com.br"

# Diagnóstico de build (R16). Crie em Vercel → Settings → Tokens, com escopo
# mínimo, só o projeto necessário. Revogue quando não precisar mais.
VERCEL_TOKEN="SEU-TOKEN-DA-VERCEL"
```

`.vercel/` também entra no `.gitignore`: ele guarda o vínculo com o projeto e, dependendo
da versão do CLI, credenciais em cache.

⚠️ **`NEXT_PUBLIC_` é público.** Tudo com esse prefixo é embutido no bundle do navegador e
visível para qualquer visitante. Use-o só para valores que você imprimiria na página:
URL do site, ID público de analytics, chave *publishable* do Stripe. **Nunca** para
`DATABASE_URL`, chave secreta ou token.

Verificação mecânica antes de publicar:

```bash
grep -rn "NEXT_PUBLIC_" --include="*.ts" --include="*.tsx" . | grep -iE "secret|key|token|password|database"
# qualquer resultado é um vazamento em potencial
```

Acesso ao banco só em código de servidor. `import 'server-only'` no topo do módulo de
acesso a dados transforma um import acidental do cliente em erro de build:

```ts
// lib/db.ts
import 'server-only';
```

---

## 3. O padrão de placeholder

Arquivo que **precisa** ser versionado mas referencia credencial vai com placeholder.
Nunca com valor real, nunca com valor real "temporário".

| Arquivo | Campo | Valor versionado |
| --- | --- | --- |
| `.env.example` | `DB_HOST` | `SEU-HOST-MYSQL` |
| `.env.example` | `DB_USER` / `DB_PASSWORD` | `SEU-USUARIO` / `SUA-SENHA` |
| `.env.example` | `DATABASE_URL` | `postgres://SEU-USUARIO:SUA-SENHA@SEU-HOST/SEU-BANCO` |
| `config.example.php` | qualquer credencial | `'SUA-SENHA'` |
| `README.md` | domínio | `https://seu-dominio.com.br` |
| seeds e fixtures | e-mail | `usuario@example.com` |
| seeds e fixtures | CPF/telefone | `000.000.000-00`, `(00) 00000-0000` |

**O placeholder precisa ser obviamente falso e obviamente acionável.** `SUA-SENHA` diz ao
leitor para substituir. `senha123` não diz nada, e passa despercebido na revisão.

Para cada placeholder, uma linha no README dizendo exatamente o que colocar e onde achar o
valor ("copie do painel hPanel → Bancos de dados MySQL").

---

## 4. `.gitignore` armado antes do primeiro commit

Copie de [`../assets/templates/gitignore.php.template`](../assets/templates/gitignore.php.template)
ou [`../assets/templates/gitignore.nextjs.template`](../assets/templates/gitignore.nextjs.template).

Uma entrada no `.gitignore` **não faz nada** por um arquivo que o Git já rastreia. Confira:

```bash
git check-ignore -v .env config/config.local.php     # deve imprimir a regra que casou
git ls-files | grep -Ei '\.env|config\.local|\.sql$|\.pem$|ftpconfig|sftp\.json'   # nada
```

Se um arquivo sensível já está rastreado:

```bash
git rm --cached config/config.local.php     # para de rastrear, mantém em disco
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
| `DB_PASSWORD=...`, `'password' => '...'` | Credencial embutida em código ou config |
| `mysql://`, `postgres://`, `mongodb+srv://` com credencial | String de conexão completa |
| `sk_live_`, `rk_live_`, `AKIA…`, `ghp_`, `re_`, `SG.` | Chaves de Stripe, AWS, GitHub, Resend, SendGrid |
| `-----BEGIN … PRIVATE KEY-----` | Chave privada |
| `eyJ…` com três segmentos | JWT com payload legível |
| `.env` / `*.sql` / `*.pem` rastreados pelo Git | Arquivo que nunca deveria estar lá |
| e-mails e CPFs em massa | Dado pessoal em fixture ou dump |

**Qualquer achado: pare.** Substitua por placeholder, rode de novo, e diga ao usuário o que
foi encontrado e o que foi trocado. O scan limpo é **necessário, não suficiente**: leia o
seu próprio diff.

Automatize com o hook: [`../assets/templates/pre-commit.template`](../assets/templates/pre-commit.template).
Ofereça instalá-lo; nunca instale sem perguntar.

---

## 6. Se um segredo já foi enviado

Diga ao usuário imediatamente e com todas as letras. Depois, nesta ordem:

1. **Rotacione primeiro.** Troque a senha do MySQL no hPanel, revogue a chave de API no
   painel do provedor, gere um novo `AUTH_SECRET`. Faça isso **antes** de mexer no Git:
   reescrever histórico leva minutos, e a credencial fica exposta o tempo inteiro.
2. **Depois limpe o histórico.** `git filter-repo --path config/config.local.php --invert-paths`,
   ou apague e recrie o repositório se ele é novo, sem forks e sem stars. Avise que forks e
   caches podem manter a cópia de qualquer forma.
3. **Depois previna a repetição.** Acrescente o padrão ao scanner, instale o hook, ligue a
   proteção de push do GitHub.

Não conserte em silêncio. A rotação é uma decisão do dono do projeto e ele precisa saber.

---

## 7. Checklist de configuração de um projeto novo

- [ ] `.gitignore` da trilha copiado **antes** do primeiro commit
- [ ] `.env` criado localmente; `.env.example` versionado com as mesmas chaves
- [ ] PHP: config fora do `public_html`, ou dentro, ignorada e com `.htaccess` negando
- [ ] PHP: `https://.../config/...` testado no navegador e respondendo 403
- [ ] Next.js: variáveis no painel da Vercel, por ambiente; nada sensível com `NEXT_PUBLIC_`
- [ ] Next.js: `import 'server-only'` no módulo de acesso a dados
- [ ] `scan-secrets.sh` limpo no working tree **e** no conteúdo staged
- [ ] Repositório remoto confirmado como privado (R2)
- [ ] README diz, chave por chave, o que preencher e onde achar o valor
