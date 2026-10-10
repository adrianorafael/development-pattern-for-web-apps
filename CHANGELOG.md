# Changelog

Todas as mudanças relevantes de **Development Pattern for Web Apps** são registradas aqui.

Formato: [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).
Versionamento: [SemVer](https://semver.org/lang/pt-BR/), aplicado a esta skill do mesmo
jeito que a regra [R13](skills/development-pattern-for-web-apps/references/release-e-deploy.md)
exige dos aplicativos que ela ajuda a construir. "Quebrar" significa quebrar para quem
**usa** a skill: uma regra renumerada, uma referência removida, um contrato de template
alterado.

A versão aqui é a de `.claude-plugin/plugin.json` → `version`, o arquivo de configuração é
a fonte da verdade, do mesmo jeito que o `package.json` é para um app.

## [Não publicado]

## [2.0.0] - 2026-10-10

A skill passa a ser dedicada **só a apps Next.js com Supabase, publicados na Vercel**, e
passa a cobrir uma lista de 42 boas práticas de segurança para vibecoding. Versão MAJOR
porque quem usava a trilha PHP perde as referências, os templates e duas regras que
dependiam dela. Os identificadores das regras (`R1` a `R18`) foram mantidos: R9 e R10
mudaram de conteúdo no mesmo número, para não quebrar referências cruzadas.

### Removido

- **A trilha HTML5 + PHP + MySQL na Hostinger**, inteira: a referência de stack, o Wizard de
  instalação, o painel de atualização por pacote ZIP, os padrões PHP do
  `scan-sql-injection.sh` e todos os exemplos de PHP nas outras referências.
- **Três referências** (`stack-php-mysql.md`, `wizard-de-instalacao.md`,
  `pacotes-de-atualizacao.md`) e **sete templates** (`Database.php`, `config.example.php`,
  `gitignore.php`, `htaccess`, `install-wizard.php`, `updater.php`, `update-manifest.json`).
- **A pergunta "Trilha"** do bootstrap, que passa a ter seis perguntas para todo projeto.
- **Autenticação feita do zero** como caminho recomendado: o hash de senha com `scrypt`, a
  tabela de sessões própria e o seed com hash local saem. Quem guarda a senha é o Supabase
  Auth.

### Alterado

- **Supabase é o banco padrão**, contratado pelo Marketplace da Vercel: Postgres com RLS,
  Supabase Auth para login e Supabase Storage com bucket privado para arquivos.
- **R5** escrita para o cliente do Supabase (métodos tipados; a armadilha de montar string
  em `.or()`/`.filter()`; `.rpc()` e funções `security definer`) e para SQL direto com o
  driver `postgres`. O `scan-sql-injection.sh` passa a acusar `.or(`/`.filter(` com
  interpolação.
- **R7** passa a nomear o piso: login pelo Supabase Auth, RLS em toda tabela, Storage
  privado, CORS restrito, debug desligado em produção, backup com restauração ensaiada,
  teto de gasto em API paga e coleta mínima de dado pessoal.
- **R9 redefinida: o ambiente é validado e o app sobe do zero.** `lib/env.ts` valida as
  variáveis com Zod; `vercel env pull`, as migrações do Supabase CLI e `npm run db:seed`
  deixam um clone limpo funcionando, com o administrador criado pelo Auth Admin API e o
  papel em `app_metadata`. Referência nova: `bootstrap-do-ambiente.md`.
- **R10 redefinida: toda migração é compatível com a versão anterior do código**, porque o
  Instant Rollback da Vercel volta o código e não o banco. Migrações do Supabase CLI em
  `supabase/migrations/`, aplicadas com `supabase db push` antes da promoção, em
  expand → migrate → contract; preview por Supabase Branching; backup periódico e
  restauração ensaiada. Referência nova: `migracoes-e-rollback.md`.
- **R12** passa a cobrir o agente, não só o código: resumo legível do diff para a pessoa
  antes do portão, recusa de solução que desliga proteção, pacote conferido antes de
  instalar, pasta isolada, comandos revisados e prompt injection.
- **R14** passa a descrever só a Vercel, com revisão humana no portão quando o app trata
  pagamento ou dado sensível.
- **R15** troca o exemplo negativo para `/users/new` e `/usuarios?acao=novo`: no App Router a
  pasta é a URL, e a regra vale para o nome dela.
- **R13 passa a tratar documentação como parte da entrega:** código sem documentação
  adequada e atualizada não está concluído. `documentacao-do-projeto.md` ganha os princípios
  (escrever para quem nunca viu o projeto, explicar o porquê, profundidade proporcional ao
  porte, nenhum documento vazio), comentários no código, TSDoc nas funções públicas,
  dependências com motivo registrado, API, banco de dados, arquitetura e decisões,
  segurança, a verificação obrigatória depois de toda mudança (com busca no projeto pelo
  nome do que mudou) e o relatório de documentação ao fim de cada entrega.
- **`scan-doc-sync.sh`** passa a apontar `TODO` sem descrição, código comentado, exportação
  sem TSDoc, variável lida no código e ausente do `.env.example` (e o contrário),
  dependência sem registro no CHANGELOG, e rota, migração ou código de segurança mudados
  sem o documento correspondente em `docs/`.
- **Os templates TypeScript** da skill passam a seguir a própria regra: TSDoc nas
  exportações e comentários só onde explicam o porquê.
- **Hooks de pre-commit** passam a ser oferecidos e instalados com o sim do usuário, nos dois
  lugares que antes se contradiziam.
- **O roteiro do Cowork** deixa de pedir o segredo de bypass da Deployment Protection pela
  conversa.
- **`scan-secrets.sh`** passa a reconhecer as chaves do Supabase (`sb_secret_`) e variáveis
  secretas com prefixo `NEXT_PUBLIC_`.
- Referências atualizadas para **Next.js 16**: `proxy.ts` no lugar de `middleware.ts`, e
  `next lint` e a chave `eslint` do `next.config` que deixaram de existir. Versões conferidas
  em 2026-10-10: next 16.4.0, tailwindcss 4.3.3, vercel 63.1.2, supabase (CLI) 2.120.0,
  @supabase/supabase-js 2.117.3, @supabase/ssr 0.12.7, zod 4.6.5.
- `schema.sql` e `migration.sql` convertidos para Postgres no formato do Supabase CLI.

### Adicionado

- **Referência nova `agentes-e-ferramentas-de-ia.md`**: pasta isolada, revisão de comandos
  antes de aprovar, prompt injection, e segredo que nunca passa pela conversa.
- **Seções novas** nas referências existentes: antes de instalar um pacote, lockfile e
  `npm ci`, commits pequenos a cada passo verde, proteções desligadas, RLS, Storage do
  Supabase, CORS, teto de gasto, debug em produção, dados pessoais e LGPD, mapa do OWASP
  Top 10, revisão humana para nível N3 ou acima, e o teste "como um estranho".
- **Piso de segurança** com dois itens novos: P13 (RLS em toda tabela) e P14 (backup com
  restauração ensaiada).
- **Casos de teste novos:** CT-SEC-031 a 033 (RLS e Storage), CT-MIG-011 (restauração) e
  CT-LGPD-001 a 004.
- **Treze templates:** `env.ts` (validação das variáveis), `seed.ts` (administrador inicial),
  `next.config.ts` (cabeçalhos de segurança e redirects 301), `supabase-server.ts` e
  `supabase-browser.ts` (clientes do Supabase), `proxy.ts` (renovação de sessão),
  `politicas-rls.sql` (RLS e Storage), `dependabot.yml`, e cinco documentos de `docs/`:
  `arquitetura.md` (visão geral com diagrama Mermaid), `decisao.md` (registro de decisão:
  contexto, decisão, alternativas, consequências), `seguranca.md` (autenticação, proteções
  ativas, ações manuais fora do código, como reportar vulnerabilidade),
  `banco-de-dados.md` (tabelas, relacionamentos, quem lê e altera cada dado, migrações) e
  `api.md` (Route Handlers e Server Actions que mudam estado).

## [1.0.0] - 2026-09-06

Primeira versão.

### Adicionado

- **`SKILL.md`** com as dezoito regras inegociáveis e o pipeline de oito fases com três
  portões de aprovação (spec, push, deploy), mais o bootstrap de seis perguntas.
- **Duas trilhas de stack:** HTML5 + PHP 8 + MySQL na Hostinger, e Next.js (App Router) +
  Tailwind na Vercel: cada uma com layout de projeto, convenções e armadilhas verificadas.
- **R5. SQL sempre parametrizado**, com a referência mais longa do conjunto: PDO
  configurado corretamente (`ATTR_EMULATE_PREPARES => false`), `LIKE`, `IN (...)`,
  `ORDER BY` dinâmico por allowlist, paginação, transações, e o equivalente em
  `postgres`/`mysql2`/Prisma/Drizzle.
- **`scan-sql-injection.sh`**: varredura de SQL concatenado em PHP e JS/TS, com verificação
  estrutural de `new PDO(` sem `ATTR_EMULATE_PREPARES => false`. Toda interpolação em SQL
  passa a exigir o marcador `scan-sql:allow` citando a allowlist que a justifica.
- **`scan-secrets.sh`**: credenciais de banco, chaves de API (Stripe, AWS, GitHub, Google,
  SendGrid, Resend, Mercado Pago, OpenAI/Anthropic), JWT, chaves privadas, CPF/CNPJ, e
  verificações estruturais de arquivos sensíveis rastreados pelo Git.
- **R9. Wizard de instalação** para todo app PHP+MySQL, com esqueleto executável em arquivo
  único: verificação de dependências item a item com instrução de correção, teste de conexão
  com tradução dos erros do MySQL, criação idempotente do schema ou limpeza e recriação com
  confirmação escrita, criação do administrador, gravação da configuração fora do webroot e
  autotrancamento.
- **R10: painel de atualização por pacote ZIP**, com `manifest.json` versionado, conferência
  de `sha256` por arquivo, defesa contra *zip slip* em quatro camadas, allowlist de extensões
  e pastas de destino, migrações SQL ordenadas e idempotentes, backup, rollback automático e
  modo manutenção com expiração.
- **R15: a URL é interface, não caminho de arquivo.** Referência dedicada com as sete
  convenções de nomenclatura (`/cadastrar-novo-usuario`, nunca `/usuarios/cadastro.php`), o
  roteador PHP completo com canonicalização e 301, o mapeamento pasta→URL do App Router, o
  helper `rota()`, a geração de slug, os redirects em `next.config.ts`, uma tabela de tradução
  de URLs antigas e treze casos de teste.
- **R16: build quebrado se conserta com o log na mão.** Referência dedicada para conectar
  o agente à conta da Vercel (MCP, CLI ou API REST, com o token fora do repositório),
  obter o log do deploy que falhou, classificar a falha como de **código** ou de
  **ambiente**, reproduzir com `vercel build`, corrigir a causa raiz e empurrar **um**
  commit por volta, com teto de três voltas e escalonamento com hipótese e pedido
  concreto. Traz a taxonomia de falhas de build da Vercel, a lista do que é proibido fazer
  para ficar verde (`ignoreBuildErrors`, `@ts-ignore`, teste apagado, commit vazio) e um
  template de registro do ciclo.
- **R17: o texto é escrito na língua de quem usa, e nunca entrega que foi gerado.**
  Referência dedicada com o protocolo de pesquisa do domínio antes da primeira frase de
  interface (o protocolo e as cinco dimensões a extrair de qualquer setor, sem dossiês
  prontos: um dossiê congelado envelhece parecendo autoritativo e convida a pular a
  pesquisa), a proibição do travessão com tabela de substituição, a lista das muletas, os
  padrões de botão, mensagem de erro, estado vazio e confirmação destrutiva, e as regras de
  justificação com hifenização. Acompanha o `scan-linguagem.sh`, que em Markdown ignora o
  que está entre crases, onde o caractere está sendo citado e não usado.
- **R13: documentação viva, no mesmo commit da mudança.** Referência dedicada com o
  inventário do que um projeto deste padrão documenta (README, CHANGELOG, `AGENTS.md`,
  specs, roteiro e dados de teste, `.env.example`, schema e migrações, manifesto do pacote,
  arquivo de versão, página) e uma matriz de mudança → documento que decide o que cada tipo
  de alteração obriga a atualizar, com a linha "refatoração sem mudança visível" existindo
  de propósito para respaldar o "esta não precisa". Acompanha o `scan-doc-sync.sh`, que lê o
  staging e separa o que a matriz pede (`[PEDE]`) do que depende de julgamento (`[OLHE]`).
- **R18: nenhuma atribuição de IA nos artefatos do projeto.** Nada de `Co-Authored-By`,
  "Generated with", link de sessão ou "Assisted-By" em commit, pull request, README, página
  ou comentário de código, em duas camadas: desligar a inserção automática na configuração
  da ferramenta (no Claude Code, os três campos de `attribution` em `settings.json`, o
  terceiro deles suprimindo o link de sessão que sessões web acrescentam sozinhas) e o hook
  `commit-msg`, que recusa a mensagem e mostra a linha ofensora. A referência traz os
  comandos de auditoria do histórico existente e o de reescrita com `git filter-branch`,
  com o aviso de que reescrever histórico já publicado quebra o clone de quem já baixou.
- **R11: roteiro de testes para o Claude Cowork** em toda entrega: seis suítes (fumaça,
  funcional, integração, segurança, interface, regressão), matriz de rastreabilidade
  requisito × caso, registro de execução, catálogo de payloads de SQL injection, XSS, IDOR,
  CSRF e upload, e a regra de que todo defeito corrigido vira caso de regressão.
- **R7: linha de base de segurança** com doze itens de piso obrigatórios em qualquer
  projeto, e quatro níveis (N1 vitrine → N4 pagamento) que só acrescentam, nunca removem.
- **R2: repositório privado por padrão**, com a lista de verificação do histórico completo
  antes de tornar qualquer repositório público.
- **20 templates** prontos para copiar, entre eles `Database.php`, `db.ts`, o Wizard, o
  instalador de pacotes, `schema.sql`, `migration.sql`, `manifest.json`, `.htaccess`
  endurecido, os hooks `pre-commit` e `commit-msg`, o roteiro de testes, o registro de
  correção de build, a spec e o `AGENTS.md` de projeto.
- Página do projeto em `docs/`, publicada no GitHub Pages pelo CI: **Tailwind compilado**
  (não CDN), com **modo claro como padrão e modo escuro opcional** por classe, persistido em
  `localStorage` e aplicado antes da primeira pintura. A linguagem visual segue o site do
  Tailwind: coluna emoldurada por réguas verticais com hachura diagonal nas margens,
  marcadores em cruz nas divisórias, cabeçalhos alinhados à esquerda, blocos de código
  sempre escuros com barra de nome de arquivo, botão primário sólido quase preto e Inter
  como tipografia. Verificada em 1440 px e 375 px nos dois temas, sem rolagem horizontal e
  sem erro de console.
