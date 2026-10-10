# Spec. Development Pattern for Web Apps (a própria skill)

> A regra R3 exige especificação antes do código. Ela vale também para esta skill.
> Este documento é a spec que a originou, mantida como registro do desenho, e como
> exemplo trabalhado do formato que `assets/templates/spec.template.md` define.

| | |
| --- | --- |
| **Spec** | `0001-agente-de-padrao-para-apps-web` |
| **Status** | 🔵 implementada |
| **Data** | 2026-09-05 · revisada em 2026-10-10 |
| **Versão alvo** | 2.0.0 (escopo reduzido a Next.js com Supabase na Vercel; R9 e R10 redefinidas) |
| **Natureza** | conteúdo (Markdown, templates, shell), não é uma aplicação |

---

## 1. Objetivo

Um agente de IA passa a construir os aplicativos web pessoais do autor em Next.js +
Tailwind + Supabase (Postgres, Auth, Storage), publicados na Vercel, sem que ele precise, a cada sessão, relembrar as
mesmas exigências de segurança, ambiente, migração, deploy e teste.

## 2. Fora de escopo

- Outros stacks e linguagens de servidor (Laravel, WordPress, Python, mobile).
- Outras hospedagens além da Vercel. A trilha de hospedagem compartilhada da versão 1.0.0
  foi removida na 2.0.0 (ver `CHANGELOG.md`).
- Executar os testes: a skill **gera** o roteiro; quem executa é o Claude Cowork ou o autor.
- Substituir revisão humana. A skill reduz a chance de erro; não elimina a leitura do diff.
- **Carregar conhecimento de domínio pronto.** A R17 manda pesquisar o setor do projeto; ela
  não traz dossiês de banco, ITSM ou saúde. Um dossiê congelado envelhece parecendo
  autoritativo e convida o agente a pular a pesquisa, que é a regra. Vale aqui o mesmo
  princípio que impede vendorizar documentação de terceiros.

## 3. Requisitos funcionais

| # | Requisito |
| --- | --- |
| RF-001 | A skill carrega sozinha ao primeiro prompt sobre um app Next.js na Vercel. |
| RF-002 | Impede SQL montado por concatenação, com regra, referência dedicada e scanner. |
| RF-003 | Impede que credenciais de banco e chaves de API cheguem ao repositório. |
| RF-004 | Faz todo repositório novo nascer privado, e exige varredura do histórico para publicar. |
| RF-005 | Exige especificação com requisitos numerados e casos de teste antes do código. |
| RF-006 | Aplica segurança proporcional ao porte, sobre um piso que nenhum projeto dispensa. |
| RF-007 | Gera, em toda entrega, um roteiro de testes em Markdown executável pelo Claude Cowork. |
| RF-008 | Exige ambiente validado na carga (`lib/env.ts` com Zod) e um app que sobe do zero com `vercel env pull`, as migrações do Supabase CLI e `npm run db:seed`, com seed idempotente que cria o administrador pelo Auth. |
| RF-009 | Exige migrações do Supabase CLI em `supabase/migrations/`, registradas em `supabase_migrations.schema_migrations` e compatíveis com a versão anterior do código, para o Instant Rollback da Vercel continuar seguro; backup periódico e restauração ensaiada. |
| RF-010 | Impõe interface por componentes: Server Components por padrão, Tailwind por tokens. |
| RF-011 | Mantém versão, CHANGELOG, README e versão do schema em sincronia. |
| RF-012 | Exige alvo nomeado, preview antes (Supabase Branching ou projeto separado), backup do banco conferido e `vercel rollback` documentado antes de qualquer deploy em produção. |
| RF-013 | Faz os apps expor URLs como rotas semânticas, nunca caminhos de arquivo. |
| RF-014 | Publica uma página do projeto em Tailwind, com modo claro padrão e escuro opcional. |
| RF-015 | Conecta-se à conta Vercel do autor para diagnosticar e corrigir build quebrado, em ciclo com teto. |
| RF-016 | Faz o texto de interface seguir as convenções do domínio, sem travessão e com corpo justificado. |
| RF-017 | Decide, a cada modificação de um app, quais documentos precisam ser atualizados no mesmo commit. |
| RF-018 | Impede que qualquer artefato do projeto credite uma ferramenta de IA como autora. |
| RF-019 | Abre toda sessão com as seis perguntas de bootstrap, num único lote: repositório, projeto Vercel e banco, dados e usuários (incluindo "há API paga?"), identidade do app, quem testa, acesso à Vercel. |
| RF-020 | Cobre os 42 itens da lista de segurança para vibecoding sem regra nova: cada item tem um lugar nomeado (regra, referência, seção, template, piso `P1` a `P14` ou caso de teste), entre eles RLS em toda tabela, Storage privado, Supabase Auth, conferência de pacote antes de instalar, lockfile e `npm ci`, Dependabot, ambiente isolado do agente, prompt injection, OWASP Top 10 a partir de N2, revisor humano a partir de N3, LGPD (campo, finalidade, retenção, exclusão e exportação), teto de gasto, backup com restauração ensaiada e varredura de estranho rota por rota. |
| RF-021 | Trata documentação como parte da entrega (R13): sempre que o agente produz ou altera código, ele documenta para quem nunca viu o projeto, explicando o porquê, na profundidade do porte; comenta decisão não óbvia, regra de negócio, contorno de bug e trecho de segurança; escreve TSDoc nas exportações públicas; registra dependência com motivo; mantém `.env.example`, README e, quando aplicáveis, `docs/arquitetura.md`, `docs/decisoes/`, `docs/seguranca.md`, `docs/banco-de-dados.md` e `docs/api.md`; roda a verificação obrigatória com busca global pelo nome do que mudou; e encerra com o relatório de documentação. |

## 4. Requisitos não funcionais

- Formato aberto [Agent Skills](https://agentskills.io): funciona em Claude Code, Cursor,
  Copilot, OpenCode e outros.
- `SKILL.md` legível de ponta a ponta em poucos minutos; profundidade nas referências,
  carregadas sob demanda.
- Nenhuma documentação de terceiros vendorizada: nextjs.org, tailwindcss.com, vercel.com,
  supabase.com, postgresql.org, docs.github.com e OWASP são referenciados por URL e lidos
  na sessão.
- Português (pt-BR) em todo o conteúdo.

## 5. Modelo de conteúdo

```
SKILL.md            18 regras · 8 fases (0 a 7) · 3 portões · 6 perguntas de bootstrap
references/         18 documentos, um por área de risco
assets/templates/   26 arquivos copiáveis
assets/scripts/     4 scanners executáveis
docs/               página do projeto (Tailwind compilado, claro/escuro)
```

Cada regra `Rn` tem uma referência responsável por ela (a R12 tem duas:
`checklist-de-revisao.md` para o código, `agentes-e-ferramentas-de-ia.md` para o agente).
Cada referência abre declarando qual regra impõe.

## 6. Regras de negócio

- Uma regra que não pode ser cumprida faz o agente **parar e dizer**, nunca entregar uma
  versão degradada em silêncio.
- Os três portões (spec, push, deploy) são paradas duras.
- O meio do trabalho é livre: a skill segura invariantes, não policia cada edição.
- Todo exemplo inseguro é rotulado com ❌ e acompanhado da forma correta com ✅.

## 7. Segurança

O risco desta skill é **ensinar errado**. Um trecho vulnerável sem rótulo será copiado para
um projeto real. Mitigações:

- Todo exemplo perigoso vem marcado e emparelhado com a versão correta.
- Os scanners são testados contra fixtures bons e ruins antes de cada publicação.
- Os placeholders são obviamente falsos, para não serem confundidos com valores reais.
- A skill declara explicitamente que varredura limpa é necessária, não suficiente.

## 8. Critérios de aceite

```
RF-002
  DADO um arquivo TypeScript com sql.query(`SELECT * FROM t WHERE id = ${id}`)   ❌ o exemplo ruim
  QUANDO scan-sql-injection.sh roda sobre ele
  ENTÃO ele reporta achado de severidade ALTA e sai com código 1

  DADO um arquivo TypeScript que usa a template tag sql`... ${id}` e resolve ORDER BY   ✅
    por allowlist com o marcador scan-sql:allow
  QUANDO o mesmo scanner roda
  ENTÃO ele sai limpo, com código 0

RF-003
  DADO um arquivo com const password = 'ValorRealQualquer'   // scan-secrets:allow (é o exemplo)
  QUANDO scan-secrets.sh roda
  ENTÃO ele reporta achado de severidade ALTA

  DADO os 26 templates deste repositório
  QUANDO scan-secrets.sh roda sobre eles
  ENTÃO ele sai limpo: todos os placeholders são reconhecidos como tais

RF-007
  DADO um app entregue
  QUANDO a Fase 5 conclui
  ENTÃO existe qa/roteiro-de-testes.md com as seis suítes, os casos de bootstrap
    (CT-BOOT) e, havendo migração, os de migração e rollback (CT-MIG), a matriz de
    rastreabilidade, e os requisitos sem cobertura declarados por nome

RF-008
  DADO um clone limpo de um app gerado sob a skill
  QUANDO se roda vercel link, vercel env pull .env.local, npm ci,
    npx supabase start, npx supabase db reset, npm run db:seed e npm run dev
  ENTÃO o app responde em http://localhost:3000 sem passo fora do README
  E sem uma variável obrigatória, o build falha nomeando a variável

RF-009
  DADO uma migração nova aplicada a um branch de preview do Supabase
  QUANDO o deployment anterior, ligado a esse branch, roda a suíte de fumaça
  ENTÃO a fumaça passa inteira

RF-020
  DADO a lista de 42 itens de segurança para vibecoding
  QUANDO cada item é procurado na skill
  ENTÃO cada um aponta para um arquivo e uma seção que existem, e os IDs novos
    (P13, P14, CT-SEC-031 a 033, CT-MIG-011, CT-LGPD-001 a 004) aparecem com o mesmo
    texto na referência e no template do roteiro

RF-021
  DADO uma entrega que muda a assinatura de uma função exportada, acrescenta uma variável
    de ambiente e um pacote
  QUANDO o agente fecha a entrega
  ENTÃO o TSDoc da função, o `.env.example` (com onde obter e se é secreta), o CHANGELOG
    (pacote, versão e motivo) e o README estão atualizados no mesmo commit, a busca global
    pelo nome antigo não acha documentação desatualizada, e a resposta termina com o
    relatório de documentação, incluindo a linha "Não se aplicava"

RF-017
  DADO um commit que acrescenta uma rota nova a um app
  QUANDO a Fase 6 conclui
  ENTÃO o mesmo commit traz README, CHANGELOG, spec, roteiro de QA, versão e página
    atualizados, porque é o que a matriz de mudança para documento exige dessa linha

  DADO um commit que só renomeia variáveis internas
  QUANDO a matriz é consultada
  ENTÃO nenhum documento é exigido, e a decisão de não escrever nada fica registrada

RF-018
  DADO uma mensagem de commit contendo "Co-Authored-By: Claude"
  QUANDO o hook commit-msg roda
  ENTÃO o commit é recusado, com a linha ofensora e o número dela na tela
```

## 9. Casos de teste

| Caso | Cobre | Verificação |
| --- | --- | --- |
| CT-001 | RF-002 | Fixture ruim (TS) → achados ALTA, código de saída 1 |
| CT-002 | RF-002 | Fixture bom (TS) → limpo |
| CT-003 | RF-003 | Fixture com credencial → achado ALTA |
| CT-004 | RF-003 | Os 26 templates → limpo |
| CT-005 | RF-008 | `env.ts.template` e `seed.ts.template`, copiados para um projeto Next 16 de teste, passam em `npx tsc --noEmit` |
| CT-006 | RF-009 | Num Supabase local, `npx supabase db reset` aplica `migration.sql.template` e `politicas-rls.sql.template` sem erro; `npx supabase migration list` mostra cada uma uma vez |
| CT-007 | RF-010 | `next.config.ts.template` passa em `npx tsc --noEmit` e só usa chaves que existem em `NextConfig` do `next@16.4.0` |
| CT-008 | não se aplica | `pages.yml` é YAML válido |
| CT-009 | não se aplica | Contagens (18 regras, 18 referências, 26 templates, 4 scanners, 6 perguntas de bootstrap) batem entre SKILL, README e página |
| CT-013 | RF-016 | `scan-linguagem.sh` acusa travessão e muleta em fixture ruim, e passa limpo no bom |
| CT-014 | RF-016 | Repositório inteiro sem travessão fora das citações em crases |
| CT-015 | RF-016 | Página justificada com hifenização em 1440 px, à esquerda em 375 px |
| CT-010 | RF-014 | Página sem rolagem horizontal e sem erro de console em 1440 px e 375 px, nos dois temas |
| CT-011 | RF-014 | Modo claro é o padrão; o botão alterna, persiste em `localStorage` e sobrevive ao reload |
| CT-012 | RF-014 | Toda classe usada em `docs/index.html` existe em `docs/tailwind.css` |
| CT-016 | RF-017 | `scan-doc-sync.sh` acusa CHANGELOG, `.env.example` e versão parados num staging com código novo, e sai limpo quando eles acompanham |
| CT-017 | RF-018 | `commit-msg.template` recusa mensagem com `Co-Authored-By` de IA, "Generated with" ou link de sessão, e aceita mensagem limpa |
| CT-018 | RF-018 | O histórico deste repositório não tem nenhum trailer de atribuição de IA |
| CT-019 | não se aplica | Busca pelos termos da trilha removida na 2.0.0 e do banco e armazenamento substituídos pelo Supabase (listados na entrada [2.0.0] do `CHANGELOG.md`, que é histórico) em `skills/`, `README.md`, `docs/` e `specs/` não acha nada |
| CT-020 | RF-019 | A Fase 0 do `SKILL.md`, a de `fluxo-spec-driven.md` e o README listam as mesmas seis perguntas |
| CT-021 | RF-020 | Para cada um dos 42 itens, `grep` acha o arquivo e a seção indicados; os casos CT-SEC-031 a 033, CT-MIG-011 e CT-LGPD-001 a 004 têm texto idêntico em `roteiro-de-testes-cowork.md` e `roteiro-de-testes.template.md` |
| CT-022 | RF-020 | `dependabot.yml.template` é YAML válido e só usa chaves da referência de opções do Dependabot |
| CT-023 | RF-021 | `scan-doc-sync.sh` acusa, num repositório descartável, `TODO` sem descrição, exportação de `lib/` sem TSDoc, `process.env` ausente do `.env.example`, pacote novo sem registro no CHANGELOG, e `route.ts`, migração ou `proxy.ts` mudados sem o documento de `docs/` correspondente; e sai limpo quando a documentação acompanha |
| CT-024 | RF-021 | Os templates `.ts` da skill passam em `tsc --strict --noEmit` e toda exportação deles tem TSDoc |
| CT-025 | RF-021 | `documentacao-do-projeto.md` cobre as doze práticas (princípios, README, variáveis, comentários, TSDoc, dependências, API, banco, arquitetura e decisões, segurança, CHANGELOG e commits, verificação obrigatória, relatório de entrega), cada uma numa seção nomeada |

## 10. Evidências

| Afirmação | Fonte | Verificado |
| --- | --- | --- |
| Tailwind não gera classe montada em runtime | tailwindcss.com/docs/detecting-classes-in-source-files | ✅ 2026-09-05 |
| Server Action é endpoint HTTP público | nextjs.org/docs/app/guides/authentication | ✅ 2026-09-05 |
| Formato Agent Skills | agentskills.io | ✅ 2026-09-05 |
| Tailwind v4 usa `prefers-color-scheme` por padrão; classe exige `@custom-variant` | tailwindcss.com/docs/dark-mode | ✅ 2026-09-05 |
| Item de grid tem `min-width: auto` e estica a coluna | medido no Chromium 141, 375 px | ✅ 2026-09-05 |
| `overflow` no `<body>` é propagado para o viewport | medido no Chromium 141 | ✅ 2026-09-05 |
| Empurrar `gh-pages` **não** habilita o Pages sozinho | 404 observado no repositório novo | ✅ 2026-09-05 |
| Justificar sem hifenizar abre rios de espaço | medido no Chromium 141 a 375 px | ✅ 2026-09-05 |
| Versões publicadas: next 16.4.0 · react 19.3.0 · tailwindcss 4.3.3 · vercel (CLI) 63.1.2 · supabase (CLI) 2.120.0 · @supabase/supabase-js 2.117.3 · @supabase/ssr 0.12.7 · zod 4.6.5 · postgres 3.4.9 | `npm view <pacote> version` | ✅ 2026-10-10 |
| `@supabase/ssr` exporta `createServerClient` e `createBrowserClient`; a opção `cookies` usa `getAll`/`setAll` | `@supabase/ssr@0.12.7`, `dist/main/types.d.ts` l.76-85 | ✅ 2026-10-10 |
| `getSession()` não é confiável no servidor; `getClaims()` e `getUser()` validam | `@supabase/auth-js@2.117.3`, `GoTrueClient.d.ts` l.1411, l.1477, l.1596, l.2563 | ✅ 2026-10-10 |
| `auth.admin.createUser`, `updateUserById`, `deleteUser` existem | `@supabase/auth-js@2.117.3`, `GoTrueAdminApi.d.ts` l.330, l.575, l.608 | ✅ 2026-10-10 |
| `user_metadata` é editável pelo usuário; papel vai em `app_metadata` | `@supabase/auth-js@2.117.3`, `types.d.ts` l.470-482; doc de RLS | ✅ 2026-10-10 |
| `createSignedUrl(path, expiresIn)`, `createSignedUploadUrl`; `createBucket` aceita `fileSizeLimit` e `allowedMimeTypes` | `@supabase/storage-js@2.117.3`, `dist/index.d.cts` l.1121, l.1348, l.1986-1989 | ✅ 2026-10-10 |
| `.or(filters: string)` recebe string de filtro do PostgREST: interpolar entrada é injeção de filtro | `@supabase/postgrest-js@2.117.3`, `dist/index.d.cts` l.3328 | ✅ 2026-10-10 |
| "A table in an exposed schema without RLS is readable and writable by any role with a grant on it."; padrão `(select auth.uid()) = usuario_id` | supabase.com/docs/guides/database/postgres/row-level-security | ✅ 2026-10-10 |
| Chaves `sb_publishable_…` (navegador, sujeita à RLS) e `sb_secret_…` (só servidor, `BYPASSRLS`); rotação em Settings > API Keys | supabase.com/docs/guides/api/api-keys | ✅ 2026-10-10 |
| Variáveis criadas pela integração da Vercel: `POSTGRES_URL`, `SUPABASE_SECRET_KEY`, `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` e outras | vercel.com/marketplace/supabase | ✅ 2026-10-10 |
| Branching: um branch de preview por PR, apagado no merge ou no fechamento, aplica migrações e seed, sem dados de produção por padrão | supabase.com/docs/guides/deployment/branching | ✅ 2026-10-10 |
| Backup: Free sem backup automático (exportar com `db dump`); Pro 7 dias; Team 14; PITR add-on com compute Small ou maior; projeto indisponível durante a restauração | supabase.com/docs/guides/platform/backups | ✅ 2026-10-10 |
| CLI: `migration new/list`, `db push --dry-run`, `db reset --linked/--local`, `db dump` (só schema sem flag; `--data-only`, `--role-only`), `branches` | `supabase <comando> --help` e `db dump --dry-run`, CLI 2.120.0 | ✅ 2026-10-10 |
| `dependabot.yml`: `version: 2`, `package-ecosystem` `npm` e `github-actions`, `schedule.interval` `weekly`, `open-pull-requests-limit` padrão 5, `commit-message.prefix` | docs.github.com/en/code-security/dependabot/working-with-dependabot/dependabot-options-reference | ✅ 2026-10-10 |
| Push protection de repositório exige GitHub Secret Protection; o contorno gera alerta | docs.github.com/en/code-security/secret-scanning/introduction/about-push-protection | ✅ 2026-10-10 |
| A edição vigente do OWASP Top 10 é a de 2025 (A01:2025 Broken Access Control a A10:2025 Mishandling of Exceptional Conditions) | owasp.org/Top10/2025/ | ✅ 2026-10-10 |
| Sandbox do Claude Code desligado por padrão; permissões avaliadas em deny, ask, allow; regra de Bash casa com o texto e não é barreira de segurança | code.claude.com/docs/en/sandboxing e code.claude.com/docs/en/permissions | ✅ 2026-10-10 |
| Node local usado na conferência: v24.21.0; `next@16.4.0` exige Node `>=20.9.0` | `node -v`; campo `engines` do `package.json` do `next@16.4.0` | ✅ 2026-10-10 |
| `@vercel/postgres` está depreciado | aviso de depreciação no `npm view @vercel/postgres` | ✅ 2026-10-10 |
| A convenção `middleware` está depreciada; o nome novo é `proxy` | `next@16.4.0`, `dist/lib/constants.js` e `dist/build/index.js` | ✅ 2026-10-10 |
| `next lint` não existe mais; a chave `eslint` não existe em `NextConfig` | `next@16.4.0`: sem `dist/cli/next-lint.js`; `dist/server/config-shared.d.ts` | ✅ 2026-10-10 |
| `typescript.ignoreBuildErrors` e `typedRoutes` (estável, chave de topo) existem | `next@16.4.0`, `dist/server/config-shared.d.ts` | ✅ 2026-10-10 |
| `params` e `searchParams` são `Promise` | `next@16.4.0` (desde o 15) | ✅ 2026-10-10 |
| Subcomandos `build`, `inspect`, `logs`, `promote`, `redeploy`, `rollback`, `env pull` existem | pacote `vercel@63.1.2` | ✅ 2026-10-10 |
| Corpo de Server Action tem limite padrão de 1 MB, ajustável em `serverActions.bodySizeLimit` | `next@16.4.0`, `dist/server/app-render/action-handler.js` e `config-shared.d.ts` | ✅ 2026-10-10 |
| Superfície da API REST da Vercel e o mecanismo exato do bypass de Deployment Protection | ⚠️ **não verificada** no pacote; as referências mandam ler vercel.com/docs na sessão | ⚠️ pendente |

## 11. Questões em aberto

1. Oferecer Drizzle como caminho alternativo de migração (hoje o padrão é o Supabase CLI,
   com arquivos SQL em `supabase/migrations/`), quando houver projeto que peça.
2. Publicar um app de demonstração construído sob este padrão, para a skill ter uma
   referência viva do que ela produz.

---

## Aprovação

| | |
| --- | --- |
| **Aprovada em** | 2026-09-05 |
| **Por** | @adrianorafael |
| **Forma** | escopo definido no pedido inicial; nome e idioma decididos em um lote de perguntas |
