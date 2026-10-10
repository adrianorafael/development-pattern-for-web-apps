# Checklist de revisão: leia o código de IA como código hostil

> Regra **R12**. Antes de todo push, este checklist roda contra o diff que existe, não
> contra a intenção, não contra a lembrança do que foi escrito.

Código gerado por IA falha de um jeito particular: ele é **plausível**. Compila, passa no
lint, tem nomes coerentes e comentários confiantes, e ainda assim interpola um `searchParams` no
`WHERE` porque naquele trecho pareceu mais simples. Revisar código de IA como se fosse de um
estagiário competente é o erro; revise-o como se fosse de alguém tentando passar algo
despercebido.

**Rode contra o diff real:**

```bash
git diff --cached
git diff --cached --stat
```

**Exceção: o primeiro lançamento revisa o repositório inteiro, não o diff.** Antes da primeira
publicação em produção, o checklist roda contra todos os arquivos versionados, porque nenhum
deles passou por revisão de lançamento ainda e o diff do último commit mostra só uma fatia:

```bash
git ls-files                                   # o que vai ser revisado, arquivo por arquivo
git diff --stat "$(git hash-object -t tree /dev/null)" HEAD   # tudo, como se fosse um diff só
```

O mesmo vale depois de uma troca grande de mãos (outro agente, outra pessoa, meses parado).

---

## 1. Segurança: bloqueia o push

### SQL (R5)

- [ ] Nenhuma variável dentro de string SQL, em nenhuma linguagem
- [ ] Na conexão direta: template tag `` sql`...` `` do driver, ou `sql.unsafe(texto, [params])` com `$1`, em 100% das consultas
- [ ] Toda consulta passa por `lib/supabase/server.ts` ou `lib/db.ts`; nenhum cliente nem driver instanciado solto pelo código
- [ ] Nome de tabela/coluna/direção dinâmicos vêm de allowlist com valor padrão
- [ ] `LIMIT`/`OFFSET` convertidos para inteiro, com teto
- [ ] `LIKE` com `%` e `_` escapados no valor
- [ ] Lista de valores como parâmetro (`= ANY($1)`), nunca colada no texto
- [ ] Nenhum `queryRaw`/`$queryRawUnsafe`/`sql.unsafe`/`sql.raw` com interpolação
- [ ] Cliente do Supabase só com métodos tipados (`.eq`, `.in`, `.ilike`); nenhum `.or(`/`.filter(` com template literal que contenha `${`: a string é um filtro do PostgREST, e entrada do usuário nela é injeção de filtro
- [ ] Função SQL chamada por `.rpc()` não concatena texto (`EXECUTE format(...)` só com `%L`/`%I`); `security definer` com `set search_path = ''` e conferência de `auth.uid()` dentro
- [ ] Consulta pela conexão direta (`POSTGRES_URL`) leva o dono no `WHERE`: esse caminho não passa pela RLS
- [ ] `bash .../scan-sql-injection.sh` limpo

### Segredos (R1)

- [ ] Nenhuma credencial, chave ou token no diff
- [ ] `.env`, `.env.local`, `.env*.local`, dumps de banco, `*.pem` fora do staging
- [ ] Nada sensível em variável `NEXT_PUBLIC_`; nenhum `NEXT_PUBLIC_` com `SECRET`, `SERVICE_ROLE`, `PASSWORD`, `TOKEN` ou `PRIVATE` no nome
- [ ] Secret key do Supabase (`sb_secret_…`) lida só em `criarClienteAdmin()` de `lib/supabase/server.ts`, arquivo com `import 'server-only'`
- [ ] `bash .../scan-secrets.sh --stdin` limpo sobre o conteúdo staged

### Entrada e saída (R6)

- [ ] Toda entrada validada no servidor: tipo, faixa, tamanho, enum
- [ ] Toda saída passa pelo JSX (React escapa); nenhum HTML montado em string
- [ ] Nenhum `dangerouslySetInnerHTML` sem sanitização de allowlist no servidor
- [ ] `href`/`src` de usuário filtrados por protocolo
- [ ] Route Handler que muda estado confere `Origin` contra `Host` ou exige token (Server Actions já conferem)
- [ ] Cookie de sessão com `HttpOnly`, `Secure` e `SameSite=Lax`
- [ ] Nenhum `GET` com efeito colateral
- [ ] Upload: Supabase Storage em bucket privado com `fileSizeLimit` e `allowedMimeTypes`, caminho gerado começando pelo id do usuário, tipo conferido pelos bytes no servidor, nunca disco local
- [ ] Arquivo entregue por `createSignedUrl` de vida curta depois de conferir o dono; nenhum `getPublicUrl` para arquivo de pessoa
- [ ] Se há LLM: saída do modelo validada como entrada; nenhuma ferramenta com efeito sem confirmação da pessoa
- [ ] Nenhum caminho de arquivo montado com entrada do usuário

### Autenticação e autorização (R7)

- [ ] Toda rota que lê ou grava confere a sessão
- [ ] O **dono do registro** está na cláusula `WHERE` (ou no `.eq('usuario_id', …)`), não num `if` posterior
- [ ] Rota administrativa confere o papel no servidor, lido de `app_metadata.papel`, nunca de `user_metadata`
- [ ] Server Action começa por `exigirSessao()` antes de qualquer coisa
- [ ] No servidor, usuário identificado por `getClaims()` ou `getUser()`; nenhum `getSession()` em código de servidor nem no `proxy.ts`
- [ ] Login pelo Supabase Auth; nenhuma coluna de senha, nenhum hash de senha feito pelo app, nenhum `md5`/`sha1` sobre senha
- [ ] Toda tabela nova em `public` nasce com `enable row level security` e política por dono `(select auth.uid()) = usuario_id`, na mesma migração (P13)
- [ ] Política nova não lê `user_metadata`; política de Storage confere a pasta do usuário
- [ ] `criarClienteAdmin()` só depois de conferir a autorização no código, e nunca em rota que entrega dado ou arquivo ao usuário
- [ ] Sessão regenerada no login; expiração por inatividade
- [ ] Mensagem de login idêntica para usuário inexistente e senha errada
- [ ] Erros logados, nunca exibidos com detalhe técnico

### Proteções desligadas: recuse e explique

Código de IA desliga proteção para "fazer funcionar": o erro some, a falha fica. Toda sugestão
do agente que desliga uma das proteções abaixo é **recusada**, e a resposta explica o que a
proteção evita e qual é a correção de verdade. Se uma delas aparecer no diff, o push para.

| Sinal no diff | O que deixa de existir | A correção de verdade |
| --- | --- | --- |
| `disable row level security`, tabela nova sem `enable row level security`, política `using (true)` para `anon` | A RLS: a API REST, com a chave pública, lê e grava a tabela inteira | Política por dono (P13) |
| `criarClienteAdmin()` ou `SUPABASE_SECRET_KEY` em Client Component, `lib/supabase/browser.ts` ou `NEXT_PUBLIC_` | A RLS de todo o projeto, para qualquer visitante | Cliente do usuário; admin só no servidor, depois da autorização |
| `Access-Control-Allow-Origin: *`, ou a `Origin` refletida com `Allow-Credentials` | A barreira entre o seu site e qualquer outro | Allowlist ([linha-de-base-de-seguranca.md](linha-de-base-de-seguranca.md) §4) |
| `git commit --no-verify`, `git push --no-verify` | O hook que roda os scanners | Corrigir o que o scanner apontou |
| `rejectUnauthorized: false`, `NODE_TLS_REJECT_UNAUTHORIZED=0` | A conferência do certificado TLS: qualquer intermediário lê e altera o tráfego | Certificado correto; CA do provedor, se for o caso |
| `typescript.ignoreBuildErrors: true`, `@ts-ignore`, `@ts-nocheck` | O tipo como prova de que o código bate com a API (R16) | Corrigir o tipo |
| `'unsafe-eval'` (ou `'unsafe-inline'` novo) em `script-src` | A CSP contra XSS, que aqui protege o token de sessão legível por JavaScript | Trocar o código ou a biblioteca que precisa de `eval` |
| `experimental.serverActions.allowedOrigins` com domínio que não é seu, Route Handler sem `origemConfiavel` | A conferência de origem contra CSRF | Só domínios seus; conferir `Origin` |
| Bucket com `public: true` para arquivo de pessoa, `createSignedUrl` com dias de validade | O acesso privado ao arquivo | Bucket privado, URL assinada curta |
| `productionBrowserSourceMaps: true`, rota de diagnóstico sem condição de `VERCEL_ENV` | O código-fonte e os detalhes internos fora do alcance do visitante (P10) | Desligar; condicionar a `VERCEL_ENV !== 'production'` |

---

## 2. Correção: o código faz o que a spec diz

- [ ] Cada requisito `RF-nnn` tocado tem implementação correspondente
- [ ] Nenhum comportamento a mais que a spec não pediu (escopo não cresceu sozinho)
- [ ] Os quatro estados de tela existem: carregando, vazio, erro, sucesso
- [ ] Casos de fronteira tratados: zero registros, um, o máximo, o máximo + 1
- [ ] Nulos tratados: nenhum acesso a propriedade de algo possivelmente ausente
- [ ] Fusos e datas coerentes com o que a spec definiu
- [ ] Dinheiro em `DECIMAL`/inteiro de centavos; nunca `FLOAT`
- [ ] Transação onde duas escritas precisam acontecer juntas, desfeita por inteiro se uma falhar
- [ ] Envio duplo (duplo clique, F5 no POST) não duplica registro
- [ ] Nenhum `console.log` ou `debugger` esquecido; `TODO` e `FIXME` só no formato `// TODO: <o que falta e por quê>`, nunca a palavra sozinha, e cada um listado no relatório de entrega

---

## 3. Qualidade e manutenção

- [ ] Nenhum bloco duplicado que deveria ser função ou componente (R8)
- [ ] Nomes em português, coerentes com o resto do projeto
- [ ] Funções curtas e com uma responsabilidade
- [ ] Nenhum "número mágico" sem constante nomeada
- [ ] Nenhuma dependência nova sem justificativa na spec
- [ ] `npm audit --omit=dev` sem vulnerabilidade crítica
- [ ] Índice no banco para toda coluna nova usada em `WHERE`, `JOIN` ou `ORDER BY`
- [ ] Nenhuma consulta dentro de laço (problema N+1)
- [ ] Listagem com paginação e teto: nenhum `SELECT` sem `LIMIT` sobre tabela que cresce
- [ ] Nenhum `SELECT *` em código de produção

### Comentários e TSDoc ([documentacao-do-projeto.md](documentacao-do-projeto.md) §4 e §5)

- [ ] Toda decisão não óbvia, regra de negócio, contorno de bug e trecho sensível de segurança do diff tem comentário dizendo **por quê**
- [ ] Nenhum comentário que só repete o código (`// incrementa o contador`)
- [ ] Nenhum código comentado morto: apagado, o Git guarda
- [ ] Comentários do código alterado **e dos que o chamam** ainda dizem a verdade (`git grep -n "<nome>"`)
- [ ] Toda exportação pública nova ou alterada (`lib/`, `actions/`, Route Handler, props de componente) tem TSDoc com o que faz, `@param`, `@returns`, `@throws` quando lança, e `@example` quando ajuda
- [ ] O TSDoc explica o significado (unidade, formato, o que `false` quer dizer), sem repetir o tipo da assinatura
- [ ] Nenhum comentário credita ferramenta de IA (R18)

---

## 4. Interface (R8)

- [ ] Componentes reutilizados; nada de HTML copiado e colado
- [ ] Cores e espaçamentos por token do tema; nenhum hex solto
- [ ] Nenhum nome de classe Tailwind montado em runtime
- [ ] Todo campo com rótulo associado
- [ ] Foco visível em todo elemento interativo
- [ ] Contraste mínimo AA
- [ ] Layout verificado em 375 px, 768 px e 1440 px
- [ ] Nenhum erro no console do navegador

## 4a: Linguagem do texto (R17)

- [ ] Zero travessão em texto visível ao usuário; `scan-linguagem.sh` limpo
- [ ] Nenhuma muleta de texto gerado (`Além disso`, `Mergulhe`, `solução robusta`)
- [ ] Vocabulário do domínio respeitado e consistente entre telas
- [ ] Botões com verbo dizendo o que acontece, nunca `OK` sozinho
- [ ] Erros com as três partes: o que houve, por quê, o que fazer
- [ ] Estado vazio orientando a próxima ação
- [ ] Corpo de texto justificado com `hyphens: auto`; títulos e listas curtas não

## 4b: Rotas e URLs (R15)

- [ ] Nenhuma URL de página contém extensão de arquivo, `/api/` ou inglês (`/users/new`)
- [ ] Português, minúsculas, kebab-case, sem acento e sem underscore
- [ ] Ação é verbo no infinitivo; coleção é substantivo plural
- [ ] Nenhuma navegação depende de query string
- [ ] Nenhum `GET` com efeito colateral
- [ ] Rota renomeada mantém 301 da antiga, registrado no CHANGELOG
- [ ] Página inexistente responde 404, não 200
- [ ] URLs geradas por constante ou `Link` com `typedRoutes`, nunca escritas à mão duas vezes
- [ ] Nenhuma classe, arquivo ou caminho resolvido a partir da URL

---

## 5. Ambiente e banco (R9, R10)

- [ ] Toda variável nova está em `lib/env.ts` (esquema Zod) **e** em `.env.example`
- [ ] Nenhum `process.env.X` lido fora de `lib/env.ts` (a exceção documentada é
  `lib/supabase/browser.ts`, com as duas variáveis `NEXT_PUBLIC_` do Supabase)
- [ ] A variável nova foi cadastrada no painel da Vercel nos ambientes certos
  (Production, Preview, Development), e o README diz onde
- [ ] Um clone limpo sobe com `vercel env pull .env.local`, `supabase start` e
  `supabase db reset` (migrações mais `supabase/seed.sql`), mais o seed do administrador, sem
  passo manual não documentado
- [ ] Seed idempotente: rodar duas vezes não duplica nada; senha do administrador vem de
  variável, nunca fixa no código; o papel vai em `app_metadata`
- [ ] Migração nova criada por `supabase migration new <nome>`, em
  `supabase/migrations/<timestamp>_<nome>.sql`; nenhum arquivo renomeado nem editado depois de aplicado
- [ ] A migração funciona com o código **anterior** ainda no ar (expand → migrate → contract);
  nada de `DROP`/`RENAME` no mesmo release que deixa de usar a coluna
- [ ] Migração destrutiva só num release seguinte, com o caminho de volta escrito
- [ ] Toda tabela criada pela migração tem RLS ligada e política na mesma migração
- [ ] Preview aponta para um branch do Supabase (Branching) ou projeto separado, nunca para o
  banco de produção
- [ ] Backup existe e a restauração foi ensaiada (P14); a data do último ensaio está anotada

## 6. Next.js e Vercel

- [ ] `'use client'` só nas folhas, com motivo
- [ ] `lib/db.ts` e `lib/supabase/server.ts` com `import 'server-only'`
- [ ] `usuario_id` vem da sessão, nunca de `searchParams`
- [ ] Server Actions validam entrada com esquema e conferem autorização
- [ ] `npm run build` passa localmente
- [ ] Nenhum `typescript.ignoreBuildErrors` ou `@ts-ignore` novo (R16)
- [ ] Cabeçalhos de segurança em `headers()` do `next.config.ts`
- [ ] Lógica de interceptação em `proxy.ts`, não no antigo `middleware.ts` (depreciado no Next 16)
- [ ] `proxy.ts` renova a sessão com `getClaims()` e devolve a resposta montada pelo `setAll`; a autorização continua na página e na action
- [ ] CSP com o domínio do projeto do Supabase em `connect-src` e `img-src`, sem `'unsafe-eval'`
- [ ] `productionBrowserSourceMaps` desligado; rota de diagnóstico ou de teste só com `VERCEL_ENV !== 'production'`

---

## 7. Testes e documentação

- [ ] `qa/roteiro-de-testes.md` atualizado no mesmo commit (R11)
- [ ] Casos de segurança criados para todo campo novo que chega ao banco
- [ ] Defeito corrigido virou caso `CT-REG-nnn`
- [ ] Spec atualizada se o comportamento mudou (R3)
- [ ] README atualizado se o passo de subir do zero, as variáveis ou o uso mudaram (R13)
- [ ] CHANGELOG com entrada datada (R13), e dependência nova ou removida em "Dependências", com versão e motivo
- [ ] `docs/` atualizado conforme a matriz 2b de [documentacao-do-projeto.md](documentacao-do-projeto.md): `api`, `banco-de-dados`, `seguranca`, `arquitetura`, `decisoes/`, os que existirem
- [ ] Verificação obrigatória (§11 da mesma referência) percorrida e relatório de entrega (§14) pronto para a pessoa
- [ ] Versão subida no `package.json` (R13)
- [ ] `scan-doc-sync.sh` rodado, e cada aviso dele respondido (R13)
- [ ] Nenhuma atribuição de IA na mensagem de commit nem nos arquivos (R18)

---

## 8. As sete perguntas adversariais

Depois do checklist, releia o diff fazendo estas sete perguntas. Elas pegam o que a lista
não pega:

1. **Se eu fosse o invasor, qual linha deste diff eu atacaria primeiro?** Vá até ela e
   prove que ela resiste.
2. **Qual entrada deste diff eu não validei?** Rastreie cada valor da fronteira até o banco.
3. **O que acontece se este código rodar duas vezes ao mesmo tempo?** Duplo clique, duas
   abas, dois deploys.
4. **O que acontece se a rede cair no meio?** Registro pela metade? Arquivo órfão?
5. **Qual consulta aqui fica lenta com 100 mil linhas?** Rode `EXPLAIN` nas novas.
6. **Que informação esta mensagem de erro entrega a quem não deveria vê-la?**
7. **Se este código estiver errado, como eu vou descobrir?** Se a resposta for "o usuário
   reclama", falta log ou falta caso de teste.

---

## 9. Como reportar o resultado

### Antes do ⛔: a pessoa lê o código, não só aprova

O portão de publicação é de uma pessoa, e aprovar sem ler é o mesmo que não ter portão. Antes
de pedir o ⛔, o agente entrega **à pessoa** um resumo por arquivo do diff, com os trechos de
risco citados (linha e motivo), para que ela leia o código onde importa:

> | Arquivo | O que mudou | Leia com atenção |
> | --- | --- | --- |
> | `app/chamados/[id]/anexos/actions.ts` | novo envio de anexo | l. 14 a 22: conferência do dono e dos bytes; l. 27: `upload` com o cliente do usuário |
> | `supabase/migrations/<timestamp>_anexos.sql` | tabela `anexos` e bucket | l. 8: RLS ligada; l. 12 a 18: política por pasta |
> | `components/lista-anexos.tsx` | lista na tela | nada de risco: só exibe, pelo JSX |
>
> Abra o diff com `git diff --cached -- <arquivo>` e confira as linhas marcadas.

Nos níveis N3 e N4 a leitura é obrigatória e o ⛔ cita o nome de quem leu
([linha-de-base-de-seguranca.md](linha-de-base-de-seguranca.md) §2).

### O relatório

Honestamente e com números:

> Revisão de `feat/anexos-em-chamados` (11 arquivos, +487/−52):
>
> **Corrigido durante a revisão:** o filtro de `anexos` interpolava `searchParams.chamado`
> num `.or()` do cliente do Supabase, reescrito com `.eq`; a rota de download usava
> `criarClienteAdmin()` sem conferir o dono, o que permitia baixar anexo de outro usuário,
> agora usa o cliente do usuário com `.eq('usuario_id', …)` e a política de Storage por pasta.
>
> **Pendente, com sua decisão:** a listagem de anexos não tem paginação. Com o volume atual
> (dezenas) não é problema; acima de mil ficará lenta. Registrei como débito técnico na spec.
>
> **Verificações:** `tsc --noEmit` e `npm run build` limpos · `scan-secrets.sh` limpo ·
> `scan-sql-injection.sh` limpo · `npm audit --omit=dev` sem vulnerabilidade ·
> nenhuma tabela de `public` com RLS desligada ·
> roteiro de QA atualizado com 6 casos novos, sendo 3 de segurança.

Nunca "revisado, está tudo certo". Diga o que encontrou, o que corrigiu e o que ficou.
