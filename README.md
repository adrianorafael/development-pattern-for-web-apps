# Development Pattern for Web Apps

🌐 **Página do projeto:** https://adrianorafael.github.io/development-pattern-for-web-apps/

**Development Pattern for Web Apps** é uma [Agent Skill](https://agentskills.io) criada e
mantida por [@adrianorafael](https://github.com/adrianorafael).

É um **guarda-corpo** para construir aplicações web pessoais com um agente de IA, em dois
stacks: **HTML5 + PHP 8 + MySQL** hospedado na **Hostinger**, e **Next.js + Tailwind**
publicado na **Vercel**.

Vibecodar um app pessoal é rápido e agradável até o momento em que o agente concatena um
`$_GET` dentro de um `WHERE`, versiona a senha do MySQL, entrega um sistema que ninguém sabe
instalar no servidor, ou diz "testei, está tudo funcionando" sem nunca ter escrito o que
deveria acontecer. Esta skill existe para tornar essas quatro coisas **estruturalmente
difíceis**, e não apenas desaconselhadas.

> ⚠️ **Aviso**
>
> Skill fornecida pelo desenvolvedor, **sem garantia** e **sem responsabilidade** por falhas,
> incidentes, perda de dados ou custos. É uma **versão de estudo, sem suporte oficial**.
>
> Baixar, usar, e publicar ou implantar os aplicativos que ela ajuda a construir é **por
> conta e risco de quem usa**. Você é igualmente livre para melhorá-la e expandi-la.

## Visão geral

A skill é um `SKILL.md`, **15 documentos de referência**, **18 templates** prontos para
copiar e **2 scanners** executáveis. Carrega em qualquer agente compatível com o formato
aberto [Agent Skills](https://agentskills.io) — Claude Code, Cursor, GitHub Copilot,
OpenCode, Gemini CLI e outros — e entra em ação no momento em que o agente começa a
trabalhar em um app web.

Ela codifica **quinze regras inegociáveis** e um **pipeline de oito fases** com três
portões duros: nada de spec sem pesquisa, nada de push sem varredura, nada de deploy sem
alvo nomeado e caminho de volta.

Não traz cópia da documentação de ninguém. php.net, nextjs.org, tailwindcss.com, a
documentação da Hostinger e da Vercel e as OWASP Cheat Sheets são referenciadas por URL e
lidas no momento em que fazem falta — uma cópia congelada envelhece parecendo autoritativa.

## Índice

1. [Pré-requisitos](#pré-requisitos)
2. [Instalação](#instalação)
3. [Como usar](#como-usar)
4. [As quinze regras](#as-quinze-regras)
5. [O pipeline](#o-pipeline)
6. [SQL injection: a regra que mais importa](#sql-injection-a-regra-que-mais-importa)
7. [Wizard de instalação](#wizard-de-instalação)
8. [Painel de atualização por pacote ZIP](#painel-de-atualização-por-pacote-zip)
9. [Roteiro de testes para o Claude Cowork](#roteiro-de-testes-para-o-claude-cowork)
10. [URLs como rotas semânticas](#urls-como-rotas-semânticas)
11. [Segurança proporcional ao porte](#segurança-proporcional-ao-porte)
12. [O que ela previne](#o-que-ela-previne)
13. [Comportamentos importantes](#comportamentos-importantes)
14. [Estrutura do repositório](#estrutura-do-repositório)
15. [Templates e ferramentas](#templates-e-ferramentas)
16. [Versionamento](#versionamento)

## Pré-requisitos

- Um agente de IA compatível com [Agent Skills](https://agentskills.io)
- Para a trilha PHP: PHP 8.1+, MySQL/MariaDB, uma conta de hospedagem (Hostinger ou similar)
- Para a trilha Next.js: Node.js 20+, uma conta na Vercel, um banco (Neon, Supabase, …)
- `git` e, de preferência, o [`gh` CLI](https://cli.github.com/) — é ele que cria o
  repositório já privado (R2)
- Acesso de rede a php.net, nextjs.org, tailwindcss.com e GitHub — a skill lê as fontes ao
  vivo em vez de citar uma cópia

## Instalação

### Pacote de skills (recomendado)

```bash
npx skills add adrianorafael/development-pattern-for-web-apps
```

### Plugin do Claude Code

```bash
claude plugin marketplace add adrianorafael/development-pattern-for-web-apps
claude plugin install development-pattern-for-web-apps@development-pattern-for-web-apps
```

### Manual

```bash
git clone https://github.com/adrianorafael/development-pattern-for-web-apps.git
cp -r development-pattern-for-web-apps/skills/development-pattern-for-web-apps \
      .claude/skills/development-pattern-for-web-apps
```

Troque `.claude/skills/` pelo caminho que o seu agente lê (`.agents/skills/`,
`.cursor/skills/`, …).

## Como usar

**Carregue com o primeiro prompt sobre o app, e depois só construa.** A skill dispara
sozinha quando você menciona PHP, MySQL, Hostinger, Next.js, Vercel, Tailwind, SQL injection,
wizard de instalação ou roteiro de testes — ou chame-a pelo nome.

```
"Faz um sistema de controle de chamados em PHP e MySQL pra eu subir na Hostinger."
```

Essa frase inicia o pipeline inteiro. Você não precisa pedir a especificação, não precisa
lembrar de pedir a revisão de segurança, e não precisa pedir o roteiro de testes no fim.

### Rígido nas pontas, livre no meio

Esta é a parte que importa, e é o oposto do que "quinze regras" costuma sugerir:

| | O que acontece | Quem conduz |
| --- | --- | --- |
| **Início** | Seis perguntas em um lote → documentação lida **ao vivo** → `specs/<slug>.md` com requisitos e casos de teste → ⛔ sua aprovação | A skill. Nenhuma linha de implementação existe ainda. |
| **Meio** | Construa. Itere, mude de ideia, jogue trabalho fora. | **Você.** É aqui que o vibecoding acontece, e a skill sai da frente — ela só segura três invariantes: SQL parametrizado, nenhum segredo versionado, nenhuma API inventada. |
| **Fim** | O código que existe é verificado: lint, testes, varredura de segredos e de SQL injection, revisão de segurança, roteiro de QA gerado e executado, versão e documentação atualizadas → ⛔ aprovação → push → ⛔ aprovação → deploy | A skill. Item por item, contra o código real. |

O objetivo não é deixar a construção lenta. É tornar o **começo deliberado** e o **fim
verificado**, para que a parte rápida do meio continue rápida sem acumular dívida em
silêncio.

### Como é uma sessão de verdade

**1 — Você pede.**

> Faz um sistema de controle de chamados em PHP e MySQL pra eu subir na Hostinger.

**2 — Seis perguntas, em um lote.** Trilha? Repositório (novo já nasce privado)? Versão do
PHP e acesso da hospedagem? Tem login, dado pessoal, pagamento, upload? Nome e versão
inicial? Quem executa o QA — você, o Cowork, ou os dois? Toda decisão posterior se refere a
essas respostas, em vez de repetir a pergunta.

**3 — A documentação é lida, não lembrada.** php.net para as funções que serão usadas, a
documentação da Hostinger para os limites do plano, MySQL para tipos e índices, OWASP para
as defesas de cada categoria. Tudo vira um registro de evidências: afirmação → fonte →
verificado, com data.

**4 — Uma spec, depois uma parada.** `specs/0001-controle-de-chamados.md`: objetivo, o que
fica de fora, requisitos `RF-001`…`RF-012`, modelo de dados com índices e chaves
estrangeiras, telas com os quatro estados, regras de negócio, seção de segurança com o nível
(N1–N4), critérios de aceite no formato *dado/quando/então*, e os casos de teste que vão
alimentar o roteiro de QA.

> Aqui está a spec. Três decisões que preciso de você: `<A>`, `<B>` e `<C>`.
> São 12 requisitos e 31 casos de teste. Aprova e eu construo?

Se você responder *"pode fazer"*, é uma resposta válida — fica registrado como aprovado sem
revisão e o trabalho segue. O portão é sobre consentimento, não cerimônia.

**5 — Agora o vibecoding.** Construa, itere, mude de ideia. A skill não fica recitando regra
aqui. Ela segura três linhas: nenhuma variável dentro de uma string SQL, nenhuma credencial
em arquivo versionado, nenhuma função ou prop usada sem ter sido verificada.

**6 — O código pronto é verificado.** `php -l` em todos os arquivos, `composer audit`,
`scan-secrets.sh`, `scan-sql-injection.sh`, e o checklist de revisão lido contra o diff — com
as sete perguntas adversariais no fim ("se eu fosse o invasor, qual linha deste diff eu
atacaria primeiro?").

**7 — O roteiro de testes é gerado e executado.** Um caso por critério de aceite, mais um
caso de SQL injection para **cada** campo que chega ao banco, mais XSS, IDOR, CSRF, upload e
cabeçalhos. Entregue com números: quantos casos, quantos de segurança, quais requisitos
ficaram sem cobertura.

**8 — Versão, documentação, push, deploy.** Versão em SemVer, CHANGELOG datado, README
atualizado, tudo no mesmo commit. Depois a skill nomeia a versão e pergunta antes do push; e
nomeia o domínio, a migração pendente e o backup antes do deploy.

### Configure uma vez por repositório

Copie [`AGENTS.template.md`](skills/development-pattern-for-web-apps/assets/templates/AGENTS.template.md)
para o repositório do app como `AGENTS.md`. Assim a próxima sessão herda o padrão — incluindo
as armadilhas que você já encontrou — em vez de começar do zero.

## As quinze regras

| # | Regra |
| --- | --- |
| **R1** | **Nenhum segredo entra no repositório.** Credenciais de banco, chaves de API, `.env`, dumps, dados pessoais: nunca. Placeholder no arquivo versionado; valor real só em variável de ambiente ou arquivo ignorado. |
| **R2** | **Repositório privado por padrão.** Todo projeto nasce `--private`. Publicar é decisão explícita, projeto a projeto, e só depois de varrer o **histórico inteiro**. |
| **R3** | **Especificação antes do código**, com requisitos numerados, critérios de aceite, casos de teste e portão de aprovação. |
| **R4** | **Nunca invente uma API.** Função, extensão, prop, hook, classe do Tailwind, flag de CLI: só depois de verificada em `vendor/`, `node_modules/` ou na doc oficial lida na sessão. |
| **R5** | **Todo SQL é parametrizado.** Zero concatenação. `ATTR_EMULATE_PREPARES => false`. Identificadores só por allowlist, com a exceção declarada na própria linha. |
| **R6** | **Validar na entrada, escapar na saída**, no contexto correto de cada uma. Validação no cliente é usabilidade, nunca segurança. |
| **R7** | **A linha de base de segurança é inegociável; acima dela, proporcional ao porte.** Doze itens de piso valem até no projeto de fim de semana. |
| **R8** | **Interface por componentes.** Next.js: App Router, Server Components, Tailwind com tokens. PHP: front controller + partials, zero HTML concatenado. |
| **R9** | **Todo app PHP+MySQL entrega um Wizard de instalação** que verifica dependências e cria — ou limpa e recria — o banco. |
| **R10** | **Todo app PHP entrega um painel administrativo** que instala pacotes ZIP com arquivos e migrações SQL, com backup e rollback. |
| **R11** | **Toda aplicação entrega um roteiro de testes** em Markdown, executável pelo Claude Cowork: unitário → integração → interface → segurança → regressão. |
| **R12** | **Revise código de IA como código hostil**, contra um checklist, antes de todo push. |
| **R13** | **Versão, documentação e schema andam juntos**, no mesmo commit. |
| **R14** | **Deploy é explícito, nomeado e reversível**, com backup antes e rollback documentado. |
| **R15** | **A URL é interface, não caminho de arquivo.** `/cadastrar-novo-usuario`, nunca `/usuarios/cadastro.php`. Rota em português, kebab-case, sem extensão; navegação jamais por query string. |

## O pipeline

```
0 BOOTSTRAP   trilha? repo? hospedagem? dados? identidade? QA?
              → .gitignore armado, repo privado, primeira varredura limpa

1 PESQUISA    documentação oficial do stack, lida ao vivo
              → registro de evidências: afirmação → URL/arquivo → verificado

2 SPEC        specs/<slug>.md: RF-nnn, critérios de aceite, casos CT-nnn,
              modelo de dados, superfície de ataque, nível de segurança
              → ⛔ PORTÃO DE APROVAÇÃO

3 BUILD       componentes, SQL parametrizado, segredos fora, wizard e updater no PHP

4 VALIDAÇÃO   lint + tipos + testes + scan-secrets + scan-sql-injection + revisão
              → resultados reais, reportados honestamente

5 QA/COWORK   gerar qa/roteiro-de-testes.md e executá-lo
              → evidências, defeitos, suíte de regressão atualizada

6 RELEASE     versão + CHANGELOG + README + versão do schema
              → ⛔ PORTÃO DE APROVAÇÃO antes do push

7 DEPLOY      Hostinger ou Vercel, alvo nomeado, backup, migração, rollback
              → ⛔ PORTÃO DE APROVAÇÃO antes do deploy
```

## SQL injection: a regra que mais importa

É a única falha desta lista que transforma um projeto pessoal em um incidente com dados de
outras pessoas. Tem uma causa única e uma cura única.

```php
// ❌ NUNCA. Nem "só nesse caso". Nem "o campo é numérico". Nem "é área logada".
$sql = "SELECT * FROM pedidos WHERE cliente_id = " . $_GET['id'];

// ✅ SEMPRE. O dado viaja por um parâmetro, nunca pelo texto do comando.
$stmt = $pdo->prepare('SELECT * FROM pedidos WHERE cliente_id = :id AND usuario_id = :u');
$stmt->execute([':id' => $id, ':u' => $_SESSION['usuario_id']]);
```

O caso difícil, e onde quase todo mundo escorrega, é o que **não pode** ser parametrizado:
nome de coluna, nome de tabela, `ASC`/`DESC`. A resposta nunca é "concatena com cuidado" —
é **allowlist**, com a exceção declarada na linha:

```php
$colunas = ['nome' => 'p.nome', 'data' => 'p.criado_em'];
$coluna  = $colunas[$_GET['ordenar'] ?? ''] ?? 'p.criado_em';
$sql = "SELECT * FROM pedidos p ORDER BY $coluna";   // scan-sql:allow — $colunas
```

O scanner acusa **toda** interpolação em SQL. Para silenciá-la é preciso escrever o
marcador citando a allowlist — na própria linha ou na linha imediatamente acima, onde cabe a
justificativa por extenso. Isso transforma a exceção em algo visível na revisão, em vez de
uma concatenação silenciosa.

```bash
bash skills/development-pattern-for-web-apps/assets/scripts/scan-sql-injection.sh
```

Ele também acusa `mysql_query`, `mysqli_real_escape_string` usado como defesa,
`$queryRawUnsafe`, `sql.unsafe`, template literal com SQL e `${}` fora de tag parametrizada,
e a existência de `new PDO(` no projeto sem nenhum `ATTR_EMULATE_PREPARES => false`.

## Wizard de instalação

Todo app PHP+MySQL sai com um instalador em cinco passos, porque "publicar na Hostinger" sem
ele vira uma sessão de arqueologia — qual extensão falta, qual permissão está errada, qual
SQL rodar em que ordem, por que a página está em branco.

| Passo | O que faz |
| --- | --- |
| **1 · Requisitos** | Versão do PHP, extensões, permissões de escrita, `mod_rewrite`, HTTPS — cada item com o valor encontrado, o exigido e **a instrução de correção no hPanel** |
| **2 · Banco** | Host, porta, banco, usuário, senha. Testa a conexão na hora e **traduz o erro do MySQL** ("1045" vira "usuário ou senha incorretos, confira em hPanel → Bancos de dados") |
| **3 · Estrutura** | Detecta o estado da base: cria do zero, mantém os dados, ou **limpa e recria** — este último exigindo digitar `APAGAR`, com a lista das tabelas e a contagem de linhas na tela |
| **4 · Administrador** | Primeiro admin, com `password_hash`. Nunca um `admin/admin` "para facilitar" |
| **5 · Conclusão** | Grava a configuração fora do webroot, registra a versão do schema, **se tranca**, e manda apagar a pasta `install/` |

Nada é gravado antes do passo 5: desistir no meio não deixa resíduo. Esqueleto executável em
[`install-wizard.php.template`](skills/development-pattern-for-web-apps/assets/templates/install-wizard.php.template).

## Painel de atualização por pacote ZIP

Atualizar por FTP é onde os projetos pessoais morrem: um arquivo esquecido, um SQL que
ninguém rodou, e o app fica meio atualizado — o pior estado possível.

```
meu-app-1.3.0.zip
├── manifest.json      # app, versão, versão mínima, PHP mínimo, extensões, sha256 por arquivo
├── files/             # árvore espelhando a raiz do app
├── migrations/        # SQL ordenado por nome e idempotente
└── remove.txt         # arquivos a apagar
```

O painel valida antes de escrever um único byte: é deste app? a sequência de versões faz
sentido? o servidor atende? o `sha256` de cada arquivo confere? há entrada não declarada no
manifesto? algum caminho tenta sair das pastas permitidas (*zip slip*)?

Só então mostra a prévia — arquivos que mudam, migrações a executar, **as destrutivas em
destaque** — e espera a confirmação. Aplica com backup do banco e dos arquivos, modo
manutenção com expiração automática, migrações em ordem registradas em `schema_migrations`,
e **rollback automático** se qualquer etapa falhar.

## Roteiro de testes para o Claude Cowork

Toda aplicação entregue vem com `qa/roteiro-de-testes.md`: um documento que outro agente
consegue **executar** navegando pela aplicação, sem ter participado do desenvolvimento e sem
poder fazer perguntas.

A diferença aparece na frase que cada passo produz. "Verificar se a listagem funciona" não é
testável. Isto é:

```markdown
### CT-014 — Filtrar chamados por status
| **Requisito** | RF-004 |
| **Pré-condição** | Logado como usuario.a@example.com. Seed: 3 abertos, 2 fechados. |

**Passos**
1. Acessar /chamados.
2. Conferir que [data-testid="tabela-chamados"] exibe 5 linhas.
3. Em [data-testid="filtro-status"], escolher Fechado.
4. Clicar em [data-testid="botao-filtrar"].

**Resultado esperado**
- A tabela exibe exatamente 2 linhas, ambas com status Fechado.
- [data-testid="contador-resultados"] exibe "2 chamados".
- A URL passa a conter ?status=fechado. Nenhum erro no console.

**Falha se** — a contagem diverge, aparece chamado com outro status, ou o filtro se perde.
```

Seis suítes, executadas nesta ordem:

| Suíte | O que cobre |
| --- | --- |
| **Fumaça** | 5 a 10 casos. Se falhar, o resto não roda: o ambiente ou o build estão errados |
| **Funcional** | Um caso por critério de aceite, mais validação, fronteira, os quatro estados de tela, persistência, concorrência e formatos |
| **Integração** | Formulário → banco → tela, upload → download, e-mail, webhook idempotente, o Wizard e o painel de atualização |
| **Segurança** | Payloads de SQL injection em **cada** campo que chega ao banco; XSS refletido e armazenado; IDOR; CSRF; sessão; upload; cabeçalhos; acesso a `/config/`, `/.env`, `/.git/config`, `/install/` |
| **Interface** | 375/768/1440 px, só teclado, rótulos, contraste AA, zoom 200%, estado vazio, duplo clique |
| **Regressão** | Cresce a cada defeito corrigido. Roda inteira antes de todo release — é a memória do projeto |

Fecha com a **matriz de rastreabilidade** requisito × caso, que **declara por nome** os
requisitos sem cobertura em vez de omiti-los, e com o registro de execução em números:
aprovados, reprovados, bloqueados. Qualquer defeito 🔴 em aberto bloqueia o release.

E com nove regras endereçadas a quem executa — entre elas: *não conserte a aplicação durante
o teste*, *relate o que observou, não o que deveria acontecer*, e *caso não executado é
BLOQUEADO, nunca FALHOU*.

## URLs como rotas semânticas

A URL é a única parte da interface que sai da aplicação: vai para o histórico, os favoritos,
o WhatsApp de quem compartilha, o índice do Google e o log do servidor. Por isso ela não pode
ser um detalhe de implementação.

```
❌ https://seu-dominio.com.br/usuarios/cadastro.php
✅ https://seu-dominio.com.br/cadastrar-novo-usuario

❌ https://seu-dominio.com.br/app/views/chamados/detalhe.php?id=8
✅ https://seu-dominio.com.br/chamados/8/impressora-nao-imprime
```

`/usuarios/cadastro.php` entrega de graça a linguagem do servidor, a árvore de pastas e o
nome do arquivo — e quebra todo link publicado no dia em que você mover o arquivo.

As sete convenções: português, minúsculas, kebab-case · sem acento e sem cedilha · sem
extensão · sem estrutura de pastas · ação é verbo no infinitivo (`/redefinir-senha`) ·
coleção é substantivo plural com identificador (`/chamados/8`) · **navegação nunca depende de
query string**.

A query string não some — muda de papel. Ela carrega **estado da visualização**, e é por isso
que `/chamados?status=fechado&pagina=2` é compartilhável e favoritável, enquanto
`/index.php?p=chamados` não significa nada fora da sua sessão.

Na trilha PHP, um front controller e um mapa de rotas escrito à mão — com canonicalização
(barra final e caixa respondem 301), tabela de redirecionamentos para rotas renomeadas e 404
de verdade. Na trilha Next.js, o nome da pasta **é** a URL, então a convenção de nomes de
pasta é a convenção de URLs: `app/cadastrar-novo-usuario/page.tsx`.

A referência traz o roteador completo, o helper `rota()` que evita escrever a mesma URL duas
vezes, a geração de slug, os redirecionamentos em `next.config.ts`, uma tabela de tradução de
URLs antigas, e os treze casos de teste que entram no roteiro de QA.

## Segurança proporcional ao porte

O piso vale para todo projeto, inclusive o de fim de semana com três usuários:

| | Piso obrigatório |
| --- | --- |
| P1–P3 | SQL parametrizado · nenhum segredo versionado · senha com `password_hash` |
| P4–P6 | CSRF em toda ação de estado · saída escapada · cookie `HttpOnly`/`Secure`/`SameSite` |
| P7–P9 | HTTPS forçado · cabeçalhos de segurança · autorização conferida por registro |
| P10–P12 | Erros logados e nunca exibidos · upload restrito e sem execução · dependências auditadas |

Acima dele, quatro níveis que só acrescentam:

| Nível | Quando | Acrescenta |
| --- | --- | --- |
| **N1** Vitrine | Sem login, sem dado pessoal | Captcha/honeypot, rate limit simples |
| **N2** App com login | Dados dos próprios usuários | Bloqueio progressivo, recuperação com token de uso único, auditoria, sessão regenerada |
| **N3** Dados de terceiros | CPF, endereço, saúde, financeiro | Criptografia em repouso, retenção, exportação do titular, backup criptografado e testado |
| **N4** Pagamento | Checkout, assinatura, saldo | Cartão nunca no seu servidor, webhook assinado, idempotência, conciliação, MFA no admin |

Você pode subir de nível. Nunca descer.

## O que ela previne

| Sintoma | Causa raiz | Regra |
| --- | --- | --- |
| Banco vazado, login burlado com `' OR '1'='1` | Dado do usuário concatenado em SQL | R5 |
| Credencial do MySQL no histórico do GitHub | Config versionada em vez de ignorada | R1 |
| Projeto virou público por engano, com `.env` dentro | Repositório criado sem `--private` | R2 |
| `<script>` do usuário executando no painel admin | Saída impressa sem escapar | R6 |
| Usuário A abre `/pedido?id=8` e vê o pedido do B | Sem autorização por registro | R7 |
| Senhas em MD5 | `password_hash` não usado | R7 |
| Deploy quebra porque falta a extensão `intl` | Sem verificação de dependências na instalação | R9 |
| Atualização subiu arquivos e não rodou o SQL | Migração fora do pacote, ou fora de ordem | R10 |
| Bug corrigido volta três versões depois | Sem suíte de regressão que cresce | R11 |
| "Testei, está tudo funcionando" — e não estava | Teste sem roteiro e sem resultado esperado escrito | R11 |
| Três deploys, todos reportando `1.0.0` | Versão não subiu por publicação | R13 |
| Ninguém sabe qual migração já rodou naquele banco | Versão do schema não gravada na base | R13 |
| Deploy derrubou o site e não há caminho de volta | Sem backup e sem rollback documentado | R14 |
| A URL entrega a linguagem, a pasta e o nome do arquivo do servidor | Caminho de arquivo servido como rota | R15 |
| Todo link publicado quebrou ao reorganizar as pastas | URL acoplada à estrutura em disco | R15 |

## Comportamentos importantes

### É opinativa de propósito
As regras são absolutas porque "prefira prepared statements quando razoável" vira, na
prática, "use prepared statements até dar um pouco de trabalho". Se você discorda de uma
regra, edite o `SKILL.md` — é Markdown, e é seu.

### Ela se recusa a chutar
Quando o pacote não está instalado e a documentação está inacessível, a instrução é dizer
*"não consigo verificar isso"* e oferecer os dois passos que destravariam — em vez de emitir
uma chamada plausível que falha em produção às duas da manhã. Espere mais perguntas e menos
falhas silenciosas.

### Ela trata a versão e a documentação como parte da mudança
Não como trabalho posterior. Um commit que muda comportamento sem subir a versão e sem
atualizar o README é, sob este padrão, um commit incompleto.

### Os scanners são rede, não garantia
Eles pegam padrões conhecidos. Um segredo que pareça texto comum passa. Uma consulta montada
em várias linhas pode escapar da varredura por linha. **Varredura limpa é necessária, não
suficiente — leia o seu próprio diff.** A skill diz isso na saída de cada execução.

### Ela assume que o repositório é privado
Todo projeto nasce `--private`, e tornar público exige varrer o histórico completo, não o
estado atual dos arquivos. Um `.env` deletado há dez commits continua legível no histórico.

### Nada é vendorizado
A skill não carrega cópia de php.net, nextjs.org, tailwindcss.com, da documentação da
Hostinger ou da Vercel, nem das OWASP Cheat Sheets. Carrega as **URLs**, e manda o agente
abri-las durante a sessão.

## Estrutura do repositório

```
skills/development-pattern-for-web-apps/
├── SKILL.md                          # 15 regras, 8 fases, 3 portões, roteamento
├── references/
│   ├── segredos-e-configuracao.md    # R1 — .env, config fora do webroot, Vercel, rotação
│   ├── git-e-publicacao.md           # R2 — privado por padrão, commits, ramos, publicação
│   ├── fluxo-spec-driven.md          # R3 — fases, portões, anatomia da spec
│   ├── protocolo-de-verificacao.md   # R4 — hierarquia de fontes, comandos, armadilhas
│   ├── sql-e-acesso-a-dados.md       # R5 — PDO, LIKE, IN, ORDER BY, transações, Next.js
│   ├── entrada-e-saida-seguras.md    # R6 — validação, escape, CSRF, upload, traversal, SSRF
│   ├── linha-de-base-de-seguranca.md # R7 — o piso de 12 itens e os níveis N1–N4
│   ├── stack-php-mysql.md            # R8 — layout, front controller, partials, Hostinger
│   ├── stack-nextjs-vercel.md        # R8 — App Router, Server Actions, Tailwind, Vercel
│   ├── wizard-de-instalacao.md       # R9 — os cinco passos e o que testar
│   ├── pacotes-de-atualizacao.md     # R10 — manifesto, zip slip, migrações, rollback
│   ├── roteiro-de-testes-cowork.md   # R11 — as seis suítes, payloads, rastreabilidade
│   ├── checklist-de-revisao.md       # R12 — o checklist e as sete perguntas adversariais
│   ├── release-e-deploy.md           # R13, R14 — SemVer, CHANGELOG, deploy, rollback
│   └── rotas-e-urls.md               # R15 — convenções, roteador, 301, 404, tradução
└── assets/
    ├── templates/                    # 18 arquivos prontos para copiar
    └── scripts/
        ├── scan-secrets.sh
        └── scan-sql-injection.sh
docs/index.html                       # fonte da página deste projeto
specs/                                # a spec desta própria skill (R3 aplicada a ela mesma)
.github/workflows/pages.yml           # publica docs/ no ramo gh-pages, gerado
```

`gh-pages` é gerado e sobrescrito pelo CI — edite `docs/`, nunca aquele ramo.

## Templates e ferramentas

| Arquivo | Para que serve |
| --- | --- |
| [`spec.template.md`](skills/development-pattern-for-web-apps/assets/templates/spec.template.md) | Spec com requisitos numerados, critérios de aceite, casos de teste, segurança e evidências |
| [`roteiro-de-testes.template.md`](skills/development-pattern-for-web-apps/assets/templates/roteiro-de-testes.template.md) | O roteiro de QA para o Cowork: seis suítes, matriz, registro de execução, defeitos |
| [`install-wizard.php.template`](skills/development-pattern-for-web-apps/assets/templates/install-wizard.php.template) | Wizard de instalação em arquivo único, executável |
| [`updater.php.template`](skills/development-pattern-for-web-apps/assets/templates/updater.php.template) | Instalador de pacotes ZIP com validação, backup e rollback |
| [`Database.php.template`](skills/development-pattern-for-web-apps/assets/templates/Database.php.template) | Fábrica PDO segura + auxiliares para `IN`, `LIKE`, allowlist e paginação |
| [`db.ts.template`](skills/development-pattern-for-web-apps/assets/templates/db.ts.template) | Acesso a dados no Next.js, `server-only`, consultas parametrizadas |
| [`schema.sql.template`](skills/development-pattern-for-web-apps/assets/templates/schema.sql.template) | Schema base idempotente: usuários, migrações, auditoria, rate limit |
| [`migration.sql.template`](skills/development-pattern-for-web-apps/assets/templates/migration.sql.template) | Migração idempotente, incluindo `ADD COLUMN` condicional no MySQL |
| [`update-manifest.json.template`](skills/development-pattern-for-web-apps/assets/templates/update-manifest.json.template) | Formato do `manifest.json` do pacote de atualização |
| [`htaccess.template`](skills/development-pattern-for-web-apps/assets/templates/htaccess.template) | Apache endurecido: HTTPS, cabeçalhos, bloqueios, front controller |
| [`gitignore.php.template`](skills/development-pattern-for-web-apps/assets/templates/gitignore.php.template) · [`gitignore.nextjs.template`](skills/development-pattern-for-web-apps/assets/templates/gitignore.nextjs.template) | Armados antes do primeiro `git add` |
| [`env.example.template`](skills/development-pattern-for-web-apps/assets/templates/env.example.template) · [`config.example.php.template`](skills/development-pattern-for-web-apps/assets/templates/config.example.php.template) | A metade versionada do par de configuração |
| [`README.template.md`](skills/development-pattern-for-web-apps/assets/templates/README.template.md) · [`CHANGELOG.template.md`](skills/development-pattern-for-web-apps/assets/templates/CHANGELOG.template.md) | O padrão de documentação do app |
| [`AGENTS.template.md`](skills/development-pattern-for-web-apps/assets/templates/AGENTS.template.md) | Para a próxima sessão herdar o padrão e as armadilhas já encontradas |
| [`pre-commit.template`](skills/development-pattern-for-web-apps/assets/templates/pre-commit.template) | Hook que roda os dois scanners e `php -l` antes de cada commit |

Rode os scanners a qualquer momento:

```bash
bash skills/development-pattern-for-web-apps/assets/scripts/scan-secrets.sh
git diff --cached | bash skills/development-pattern-for-web-apps/assets/scripts/scan-secrets.sh --stdin
bash skills/development-pattern-for-web-apps/assets/scripts/scan-sql-injection.sh
```

## Versionamento

Esta skill segue [SemVer](https://semver.org/lang/pt-BR/) — o mesmo padrão que a R13 exige
dos apps que ela ajuda a construir. "Quebrar" significa quebrar para quem **usa** a skill:
uma regra renumerada, uma referência removida, um contrato de template alterado.

- `.claude-plugin/plugin.json` → `version` é a fonte da verdade — um arquivo de configuração,
  do mesmo jeito que `app/version.php` ou `package.json` é para um app.
- Toda publicação é registrada em [CHANGELOG.md](CHANGELOG.md).

**Versão atual: 1.0.0.**

Correções e adições são bem-vindas — abra uma issue ou um pull request.

---

Projeto irmão: [Development Pattern for Dynatrace](https://github.com/adrianorafael/development-pattern-for-Dynatrace) —
o mesmo formato de guarda-corpo, aplicado à construção de Apps nativos do Dynatrace.
