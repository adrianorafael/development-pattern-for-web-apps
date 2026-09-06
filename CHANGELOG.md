# Changelog

Todas as mudanças relevantes de **Development Pattern for Web Apps** são registradas aqui.

Formato: [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).
Versionamento: [SemVer](https://semver.org/lang/pt-BR/): aplicado a esta skill do mesmo
jeito que a regra [R13](skills/development-pattern-for-web-apps/references/release-e-deploy.md)
exige dos aplicativos que ela ajuda a construir. "Quebrar" significa quebrar para quem
**usa** a skill: uma regra renumerada, uma referência removida, um contrato de template
alterado.

A versão aqui é a de `.claude-plugin/plugin.json` → `version`, o arquivo de configuração é
a fonte da verdade, do mesmo jeito que `app/version.php` ou `package.json` é para um app.

## [Não publicado]

## [1.0.0] - 2026-09-05

Primeira versão.

### Adicionado

- **`SKILL.md`** com as dezessete regras inegociáveis e o pipeline de oito fases com três
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
- **R11: roteiro de testes para o Claude Cowork** em toda entrega: seis suítes (fumaça,
  funcional, integração, segurança, interface, regressão), matriz de rastreabilidade
  requisito × caso, registro de execução, catálogo de payloads de SQL injection, XSS, IDOR,
  CSRF e upload, e a regra de que todo defeito corrigido vira caso de regressão.
- **R7: linha de base de segurança** com doze itens de piso obrigatórios em qualquer
  projeto, e quatro níveis (N1 vitrine → N4 pagamento) que só acrescentam, nunca removem.
- **R2: repositório privado por padrão**, com a lista de verificação do histórico completo
  antes de tornar qualquer repositório público.
- **19 templates** prontos para copiar, entre eles `Database.php`, `db.ts`, o Wizard, o
  instalador de pacotes, `schema.sql`, `migration.sql`, `manifest.json`, `.htaccess`
  endurecido, o roteiro de testes, o registro de correção de build, a spec e o
  `AGENTS.md` de projeto.
- Página do projeto em `docs/`, publicada no GitHub Pages pelo CI: **Tailwind compilado**
  (não CDN), com **modo claro como padrão e modo escuro opcional** por classe, persistido em
  `localStorage` e aplicado antes da primeira pintura. A linguagem visual segue o site do
  Tailwind: coluna emoldurada por réguas verticais com hachura diagonal nas margens,
  marcadores em cruz nas divisórias, cabeçalhos alinhados à esquerda, blocos de código
  sempre escuros com barra de nome de arquivo, botão primário sólido quase preto e Inter
  como tipografia. Verificada em 1440 px e 375 px nos dois temas, sem rolagem horizontal e
  sem erro de console.
