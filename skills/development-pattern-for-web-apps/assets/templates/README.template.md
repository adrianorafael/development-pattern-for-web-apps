# <Nome do App>

> Modelo de `README.md` para um aplicativo construído sob o
> **[Development Pattern for Web Apps](https://github.com/adrianorafael/development-pattern-for-web-apps)**.
> Regra **R13**: este arquivo muda no mesmo commit que muda o comportamento.

<Uma frase dizendo o que o aplicativo faz e para quem.>

**Versão:** 1.3.0 · **Repositório:** privado (R2)

---

## Índice

1. [O que é](#o-que-é)
2. [Tecnologias](#tecnologias)
3. [Requisitos](#requisitos)
4. [Subir do zero](#subir-do-zero)
5. [Variáveis de ambiente](#variáveis-de-ambiente)
6. [Como usar](#como-usar)
7. [Deploy e atualização](#deploy-e-atualização)
8. [Migrações, backup e rollback](#migrações-backup-e-rollback)
9. [Estrutura do projeto](#estrutura-do-projeto)
10. [Desenvolvimento](#desenvolvimento)
11. [Testes](#testes)
12. [Segurança](#segurança)
13. [Documentação complementar](#documentação-complementar)
14. [Solução de problemas](#solução-de-problemas)

---

## O que é

<Dois ou três parágrafos: o problema que resolve, quem usa, o que ele deliberadamente não faz.>

**Não faz:** <lista curta: evita expectativa errada e defeito falso no QA.>

---

## Tecnologias

| Camada | O que usa | Para quê |
| --- | --- | --- |
| Interface e servidor | Next.js (App Router) + React + TypeScript | Páginas, Server Actions e Route Handlers num projeto só |
| Estilo | Tailwind CSS, com tokens do tema | Cores e espaçamentos definidos uma vez, usados por nome |
| Banco, login e arquivos | Supabase: Postgres com RLS, Auth, Storage | Dados, usuários e anexos, com a regra de acesso no próprio banco |
| Validação | Zod | Entrada de formulário e variáveis de ambiente (`lib/env.ts`) |
| Hospedagem | Vercel | Production, Preview por ramo, Development local |
| Testes | `<Vitest, Playwright>` e o roteiro do Claude Cowork | Unitário, integração, interface e QA manual guiado |
| `<outra: e-mail, pagamento>` | `<pacote ou serviço>` | `<por que está aqui>` |

Cada dependência nova entra nesta tabela (se a pessoa precisa saber que ela existe) e no
CHANGELOG, com versão e motivo.

---

## Requisitos

| Item | Versão | Observação |
| --- | --- | --- |
| Node.js | 20.9 ou mais nova | Mínimo do `next@16.4.0` (campo `engines`); a Vercel usa a versão do projeto |
| Next.js | 16 | App Router |
| Tailwind CSS | 4 | Configuração em CSS, com `@theme` |
| Banco, login e arquivos | Supabase (Postgres, Auth, Storage) | Pelo Marketplace da Vercel |
| CLI do Supabase | `npx supabase` (pacote `supabase` no `devDependencies`) | Migrações, banco local e dump |
| Docker | Atual | Só para o Supabase local (`npx supabase start`) |
| CLI da Vercel | `npm i -g vercel` | Para `vercel link` e `vercel env pull` |
| Conta | Vercel, com acesso ao projeto `<nome-do-projeto>` | |

---

## Subir do zero

Oito comandos, nesta ordem, num clone limpo. Se algum passo extra for necessário, é defeito
deste README (R9): registre e corrija.

```bash
git clone git@github.com:SEU-USUARIO/SEU-REPOSITORIO.git && cd SEU-REPOSITORIO
vercel link                     # liga a pasta ao projeto <nome-do-projeto> na Vercel
vercel env pull .env.local      # baixa as variáveis do ambiente Development
npm ci                          # instala exatamente o que está no package-lock.json
npx supabase start              # Postgres, Auth e Storage locais (exige Docker)
npx supabase db reset           # aplica supabase/migrations/ e supabase/seed.sql no banco LOCAL
npm run db:seed                 # cria o administrador no Auth e os dados iniciais (idempotente)
npm run dev                     # http://localhost:3000
```

- `vercel env pull` grava `.env.local`, que está no `.gitignore`. Nunca o versione (R1).
- Se faltar uma variável, `lib/env.ts` interrompe a execução dizendo qual e onde
  configurá-la. Não invente valor: cadastre-a no painel da Vercel e rode o `pull` de novo.
- O banco de desenvolvimento é o Supabase local, ou um projeto de desenvolvimento separado,
  nunca o de produção. `npx supabase db reset` só roda no banco local: nunca com `--linked`.
- `npm run db:seed` pode rodar quantas vezes for preciso: não duplica nada. A senha do
  administrador vem de variável de ambiente, nunca do código.

---

## Variáveis de ambiente

A lista completa, com placeholder e comentário, está em [`.env.example`](.env.example). O
esquema que as valida está em `lib/env.ts`.

| Chave | Ambientes na Vercel | O que colocar |
| --- | --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL` | Production, Preview, Development | Criada pela integração do Supabase; `https://SEU-PROJETO.supabase.co` |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Production, Preview, Development | Criada pela integração; `sb_publishable_SUA-CHAVE`. Pública por definição: só alcança o que a RLS permite |
| `SUPABASE_SECRET_KEY` | Production, Preview, Development | Criada pela integração; `sb_secret_SUA-CHAVE`. **Só no servidor**: ignora a RLS |
| `POSTGRES_URL` | Production, Preview, Development | Criada pela integração; `postgres://SEU-USUARIO:SUA-SENHA@SEU-HOST/SEU-BANCO`. Conexão direta: não passa pela RLS |
| `ADMIN_EMAIL`, `ADMIN_SENHA_INICIAL` | Onde o seed roda | Lidas por `npm run db:seed`; a senha vale só até o primeiro login |
| `<CHAVE-NOVA>` | `<quais>` | `<de onde vem>` |

> ⚠️ Nenhum desses valores fica no repositório (R1). Tudo com prefixo `NEXT_PUBLIC_` vai
> para o navegador: nunca use esse prefixo em senha, token ou string de conexão.

---

## Como usar

<Fluxos principais, com o caminho de tela. Uma seção por módulo.>

### Rotas

| URL | O que é |
| --- | --- |
| `/` | Início |
| `/entrar` | Login |
| `/cadastrar-novo-usuario` | Cadastro |
| `/chamados` | Lista de chamados (filtros opcionais `?status=`, `?ordenar=`, `?pagina=`) |
| `/abrir-chamado` | Formulário de novo chamado |
| `/chamados/[id]` | Detalhe |
| `/administracao` | Painel administrativo |
| `/politica-de-privacidade` | Política de privacidade, pública, com link no rodapé |

<Quando uma rota for renomeada, mantenha a antiga respondendo 301 (em `next.config.ts`) e
registre no CHANGELOG.>

---

## Deploy e atualização

| Ambiente | Como chega lá | Banco |
| --- | --- | --- |
| Preview | `git push` em qualquer ramo: a Vercel publica uma URL própria | Branch de preview do Supabase (Branching), ou projeto separado; nunca o de produção |
| Produção | Merge em `main`, ou `vercel promote <url-do-preview>` | Banco de produção |

Ordem de um release com migração (R10, R14):

1. Preview publicado, roteiro de QA executado nele (R11).
2. Backup do dia do banco de produção conferido (painel do Supabase, Database > Backups) ou
   gerado com `npx supabase db dump`.
3. `npx supabase db push --dry-run`, depois `npx supabase db push`, com o projeto de
   produção linkado. A migração é compatível com a versão no ar.
4. Promoção do deploy para produção.
5. Suíte de fumaça do roteiro de QA na URL de produção (só leitura).

---

## Migrações, backup e rollback

- Migrações em `supabase/migrations/<timestamp>_<nome>.sql`, criadas com
  `npx supabase migration new <nome>`, aplicadas pelo Supabase CLI e registradas em
  `supabase_migrations.schema_migrations`.
- Toda migração funciona com a versão **anterior** do código: acrescentar antes, remover só
  num release seguinte (expand → migrate → contract).
- Voltar o código: `vercel rollback`, ou Instant Rollback no painel da Vercel. Ele **não**
  volta o banco, e é por isso que a regra acima existe.
- Backup: `<plano Pro: diário, últimos 7 dias, no painel em Database > Backups / plano Free:
  sem backup automático; dump semanal com npx supabase db dump, guardado em <onde, fora do
  repositório>>`.
- Voltar o banco: restaurar o backup pelo painel (o projeto fica indisponível durante a
  restauração) ou o dump. Escreva aqui o procedimento do seu projeto.
- Restauração ensaiada em `<data>`, num projeto descartável, em `<tempo>` (CT-MIG-011).
  Repita a cada trimestre.

> Um backup nunca restaurado não é um backup.

---

## Estrutura do projeto

```
<cole aqui a árvore real do projeto>
```

---

## Desenvolvimento

Este projeto segue o
[Development Pattern for Web Apps](https://github.com/adrianorafael/development-pattern-for-web-apps).
Antes de qualquer mudança, leia `AGENTS.md`, ele traz as convenções e as armadilhas já
encontradas aqui.

```bash
npx tsc --noEmit && npm run lint && npm test && npm run build
vercel build             # reproduz o build da Vercel localmente
npm audit --omit=dev

# Sempre, antes de qualquer push
bash skills/development-pattern-for-web-apps/assets/scripts/scan-secrets.sh
bash skills/development-pattern-for-web-apps/assets/scripts/scan-sql-injection.sh
```

---

## Testes

O roteiro completo está em [`qa/roteiro-de-testes.md`](qa/roteiro-de-testes.md): escrito
para ser executado pelo **Claude Cowork** ou por uma pessoa, sem conhecimento prévio do
código.

| Suíte | Casos | Roda quando |
| --- | --- | --- |
| Fumaça | 6 | Toda execução, primeiro |
| Funcional | 34 | Antes de todo release |
| Integração | 9 | Antes de todo release |
| Bootstrap | 8 | Quando muda variável, seed ou o passo de subir do zero |
| Migração | 7 | Antes de todo release com migração |
| Segurança | 33 | Antes de todo release |
| LGPD | 4 | Antes de todo release, se o app trata dado pessoal |
| Interface | 12 | Antes de todo release |
| Regressão | 7 | Antes de todo release, inteira |

Credenciais e seed: [`qa/dados-de-teste.md`](qa/dados-de-teste.md).
**Nunca execute a suíte de segurança contra produção.**

---

## Segurança

Nível **N2** (área logada, dados dos próprios usuários): ver R7 do padrão. O detalhe, com
as proteções ativas e **o que foi configurado à mão fora do código** (URLs do Supabase Auth,
chaves, teto de gasto, Deployment Protection, Dependabot, backup), está em
[`docs/seguranca.md`](docs/seguranca.md). Em resumo:

- Login pelo Supabase Auth: o app não guarda nem faz hash de senha.
- RLS ligada em toda tabela, com política por dono, **e** autorização conferida no
  servidor. A secret key do Supabase só existe no servidor.
- Consultas parametrizadas; uploads em bucket privado; cabeçalhos de segurança no
  `next.config.ts`; nenhuma credencial no repositório.

**Encontrou uma falha?** Escreva para `seguranca@seu-dominio.com.br` (detalhes em
[`docs/seguranca.md`](docs/seguranca.md)). Não publique detalhes antes da correção.

---

## Documentação complementar

Liste só o que existe neste repositório; apague a linha do que o projeto não tem.

| Documento | O que tem |
| --- | --- |
| [`docs/arquitetura.md`](docs/arquitetura.md) | Visão geral, diagrama e onde cada parte vive no código |
| [`docs/decisoes/`](docs/decisoes/) | As decisões que atravessam o projeto, uma por arquivo |
| [`docs/seguranca.md`](docs/seguranca.md) | Autenticação, autorização, proteções, ações manuais fora do código, como reportar falha |
| [`docs/banco-de-dados.md`](docs/banco-de-dados.md) | Tabelas, relacionamentos, quem lê e altera cada dado, migrações |
| [`docs/api.md`](docs/api.md) | Route Handlers, webhooks e Server Actions que mudam estado |
| [`specs/`](specs/) | Uma spec por funcionalidade: requisitos, critérios de aceite, casos de teste |
| [`qa/roteiro-de-testes.md`](qa/roteiro-de-testes.md) | O roteiro de QA, para o Claude Cowork ou uma pessoa |
| [`CHANGELOG.md`](CHANGELOG.md) | O que mudou em cada versão, inclusive dependências |
| [`AGENTS.md`](AGENTS.md) | Convenções e armadilhas, para quem (pessoa ou agente) for mexer no código |

---

## Solução de problemas

| Sintoma | Causa provável | O que fazer |
| --- | --- | --- |
| Build falha com mensagem de variável ausente | Variável não cadastrada naquele ambiente da Vercel | Cadastrar no painel (Production, Preview ou Development) e refazer o deploy |
| `npm run dev` falha ao iniciar, citando `lib/env.ts` | `.env.local` desatualizado | `vercel env pull .env.local` |
| "relation does not exist" no log | Migração não aplicada naquele banco | `npx supabase migration list` para ver o que falta; `npx supabase db push` contra o projeto certo |
| Preview mostra dados de produção | As variáveis do Supabase no Preview apontam para produção | Corrigir já: o preview precisa de branch ou projeto próprio (R10) |
| Lista vazia para usuário logado, sem erro | RLS ligada sem política para aquela operação | Criar a política por dono na migração; nunca desligar a RLS |
| URL de preview abre a tela de login da Vercel | Deployment Protection ligada | Entrar com conta do time, ou usar o bypass documentado em https://vercel.com/docs/deployment-protection, configurado no ambiente, nunca colado na conversa |
| Depois de `vercel rollback`, erro de coluna inexistente | Migração incompatível com a versão anterior | Restaurar o banco pelo backup; rever a migração (R10) |
| Upload some depois de um tempo | Arquivo gravado em disco da função | Usar o Supabase Storage; o disco da função é efêmero |

---

## Licença

<MIT / proprietária / uso pessoal>
