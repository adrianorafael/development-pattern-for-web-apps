# Segurança: <Nome do App>

> Modelo de `docs/seguranca.md` para um aplicativo construído sob o
> **[Development Pattern for Web Apps](https://github.com/adrianorafael/development-pattern-for-web-apps)**.
> Regras **R1**, **R7** e **R13**. Este arquivo muda no mesmo commit que muda autenticação,
> `proxy.ts`, políticas, `next.config.ts`, `lib/supabase/` ou uma configuração de painel.
>
> **Quando NÃO criar:** script avulso sem deploy. Todo app publicado tem ao menos a seção 4
> (o que foi configurado fora do código) e a seção 6 (como reportar).
>
> O README do app resume a segurança em poucas linhas e remete para cá. Nada aqui contém
> segredo: só **onde** ele vive e **quando** foi trocado.

**Nível de segurança (R7):** `<N1 / N2 / N3 / N4>`: `<uma frase do porquê>` ·
**Revisor humano (N3, N4):** `<nome, ou "não se aplica">` · **Revisado em:** `<AAAA-MM-DD>`

---

## 1. Autenticação

- **Supabase Auth**, e-mail e senha. O app não guarda senha nem calcula hash: quem guarda é
  o Supabase Auth (bcrypt, https://supabase.com/docs/guides/auth/password-security).
- No servidor, o usuário vem de `getClaims()` (assinatura conferida), nunca de
  `getSession()`.
- Mensagem de login única para e-mail inexistente e senha errada; a recuperação de senha
  responde sempre "se o e-mail existir, enviamos o link".
- `proxy.ts` renova a sessão a cada requisição. Ele **não** é a barreira de autorização.

## 2. Autorização

Duas camadas, sempre as duas:

1. **RLS ligada em toda tabela de `public`**, com política por dono
   (`(select auth.uid()) = usuario_id`). A matriz completa de quem lê e quem altera cada
   dado está em [`banco-de-dados.md`](banco-de-dados.md), seção 3.
2. **Conferência no servidor**: toda Server Action, Route Handler e página começa por
   `exigirSessao()` (ou `exigirPapel('admin')`) e põe o dono na consulta.

Papel de administrador vem de `app_metadata.papel`, que só a secret key altera; nunca de
`user_metadata`, que o próprio usuário edita. A `SUPABASE_SECRET_KEY` só existe em
`criarClienteAdmin()` (`lib/supabase/server.ts`, com `import 'server-only'`), chamada depois
da autorização.

## 3. Proteções ativas

| Proteção | Onde está | Como conferir |
| --- | --- | --- |
| SQL parametrizado (P1) | `lib/supabase/server.ts`, `lib/db.ts` | `scan-sql-injection.sh` limpo |
| Nenhum segredo no repositório nem em `NEXT_PUBLIC_` (P2) | `.gitignore`, `lib/env.ts`, hook `pre-commit` | `scan-secrets.sh` limpo |
| CSRF (P4) | Server Actions (Next); `lib/origem.ts` nos Route Handlers que mudam estado | `curl` com `Origin` de outro site recebe 403 |
| Saída escapada (P5) | JSX; nenhum `dangerouslySetInnerHTML` sem sanitização | revisão do diff |
| Cabeçalhos e CSP (P8) | `headers()` em `next.config.ts` | `curl -sI https://seu-dominio.com.br` |
| Erro sem detalhe; nada de depuração em produção (P10) | `app/error.tsx`; `productionBrowserSourceMaps` desligado | página de erro genérica em produção |
| Upload privado e conferido pelos bytes (P11) | bucket `anexos` privado, 5 MB, PNG, JPEG e PDF | CT-SEC-033 |
| Dependências vigiadas (P12) | `.github/dependabot.yml`, alertas do Dependabot | pull requests do Dependabot e alertas nas configurações de segurança do repositório |
| RLS em toda tabela (P13) | migração `politicas_rls` | CT-SEC-031, CT-SEC-032 |
| Backup com restauração ensaiada (P14) | seção 4 abaixo | CT-MIG-011 |
| Rate limit | limites do Supabase Auth + `eventos_limite` (`lib/limite.ts`) | `<rotas protegidas>` |
| `<proteção acima do piso, do seu nível>` | `<onde>` | `<como>` |

## 4. Ações manuais fora do código

**A seção mais importante deste documento.** Nada disto vem num clone: foi feito à mão, num
painel, e precisa ser refeito em todo projeto ou ambiente novo. Marque cada linha com a data
em que foi conferida.

| Onde | O que configurar | Estado | Fonte |
| --- | --- | --- | --- |
| Supabase → Authentication → URL Configuration | **Site URL** = `https://seu-dominio.com.br`, nunca `localhost`. **Redirect URLs** com caminho exato em produção; previews da Vercel com `https://*-<slug-do-seu-time>.vercel.app/**`, nunca `https://*.vercel.app/**` | `<✅ AAAA-MM-DD / ⬜>` | https://supabase.com/docs/guides/auth/redirect-urls |
| Supabase → Authentication (provedor de e-mail) | Senha mínima de **12** caracteres; proteção contra senha vazada (plano Pro ou acima) | `<✅ / ⬜>` | https://supabase.com/docs/guides/auth/password-security |
| Supabase → Authentication → Rate Limits | Limites revistos; SMTP próprio configurado (o servidor embutido manda 2 e-mails por hora) | `<✅ / ⬜>` | https://supabase.com/docs/guides/auth/rate-limits |
| Supabase → Settings → API Keys | Secret key só nas variáveis da Vercel. Última rotação: `<AAAA-MM-DD>`. Chave vazada segue o roteiro de `segredos-e-configuracao.md` §6 | `<✅ / ⬜>` | https://supabase.com/docs/guides/api/api-keys |
| Vercel → Project → Settings → Environment Variables | Cada variável nos ambientes certos; **Preview aponta para um branch do Supabase ou projeto separado**, nunca para produção | `<✅ / ⬜>` | `README.md`, "Variáveis de ambiente" |
| Vercel, no projeto: Deployment Protection | Ligada nos previews se eles têm dado real; o segredo de bypass do QA fica no ambiente, nunca na conversa | `<✅ / ⬜ / não se aplica>` | https://vercel.com/docs/deployment-protection |
| Vercel → Settings → Billing → Spend Management | Valor por ciclo, avisos em 50%, 75% e 100%, pausa de produção se for teto (planos Pro e Enterprise). Não cobre integrações do Marketplace | `<✅ / ⬜>` | https://vercel.com/docs/spend-management |
| Supabase → organização → Billing (Cost Control) | Spend Cap ligado no plano Pro | `<✅ / ⬜ / Free>` | https://supabase.com/docs/guides/platform/cost-control |
| Painel de cada API paga (`<e-mail, IA, SMS, mapas>`) | Teto de gasto e alerta | `<✅ / ⬜>` | painel do provedor |
| GitHub → Settings | Repositório **privado**; alertas do Dependabot ligados; push protection ligada se o plano permitir (em repositório privado ela exige GitHub Secret Protection) | `<✅ / ⬜>` | https://docs.github.com/en/code-security/secret-scanning/introduction/about-push-protection |
| Supabase → Database → Backups | Pro: diário, 7 dias. Free: **sem backup automático**: `npx supabase db dump` agendado, guardado em `<onde, fora do repositório>`. Último ensaio de restauração: `<AAAA-MM-DD>` | `<✅ / ⬜>` | https://supabase.com/docs/guides/platform/backups |
| Contas da Vercel, do Supabase e do GitHub | MFA ligado (obrigatório em N4) | `<✅ / ⬜>` | painel de cada conta |
| Máquina de quem desenvolve | Hooks `pre-commit` e `commit-msg` instalados em `.git/hooks/` | `<✅ / ⬜>` | `AGENTS.md` |

## 5. Dados pessoais

Campos, finalidade e retenção: spec, seção "Dados pessoais". Política pública em
`/politica-de-privacidade`. Exclusão de conta apaga arquivos, linhas e o usuário do Auth;
exportação devolve só os dados do titular (CT-LGPD-001 a 004). O que fica em backup, e por
quanto tempo: `<prazo do plano e dos dumps>`.

## 6. Como reportar uma vulnerabilidade

Escreva para **`seguranca@seu-dominio.com.br`**, com o passo a passo para reproduzir. Não
abra issue pública e não publique detalhes antes da correção. Resposta em até
`<n> dias úteis`.

> Se quiser que o GitHub reconheça a política, crie um `SECURITY.md` curto (em `.github/`,
> na raiz ou em `docs/`) com esta seção e um link para este documento
> (https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file).

## 7. Histórico

Incidentes, rotações de chave e mudanças de configuração de segurança, do mais novo para o
mais antigo. Sem segredo, sem dado de pessoa.

| Data | O que aconteceu | O que foi feito | Versão |
| --- | --- | --- | --- |
| `<AAAA-MM-DD>` | `<ex.: secret key exposta num log de build>` | `<causa corrigida, chave nova, antiga apagada, redeploy>` | `<x.y.z>` |
