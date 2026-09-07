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

A skill é um `SKILL.md`, **18 documentos de referência**, **20 templates** prontos para
copiar e **4 scanners** executáveis. Carrega em qualquer agente compatível com o formato
aberto [Agent Skills](https://agentskills.io), como Claude Code, Cursor, GitHub Copilot,
OpenCode e Gemini CLI, e entra em ação no momento em que o agente começa a trabalhar em um
app web.

Ela codifica **dezoito regras inegociáveis** e um **pipeline de oito fases** com três
portões duros: nada de código sem spec aprovada, nada de push sem a versão e a documentação
no mesmo commit, nada de produção sem alvo nomeado e caminho de volta.

Não traz cópia da documentação de ninguém. php.net, nextjs.org, tailwindcss.com, a
documentação da Hostinger e da Vercel e as OWASP Cheat Sheets são referenciadas por URL e
lidas no momento em que fazem falta: uma cópia congelada envelhece parecendo autoritativa.

## Índice

1. [Pré-requisitos](#pré-requisitos)
2. [Instalação](#instalação)
3. [Como usar](#como-usar)
4. [As dezoito regras](#as-dezoito-regras)
5. [O pipeline](#o-pipeline)
6. [SQL injection: a regra que mais importa](#sql-injection-a-regra-que-mais-importa)
7. [Wizard de instalação](#wizard-de-instalação)
8. [Painel de atualização por pacote ZIP](#painel-de-atualização-por-pacote-zip)
9. [Roteiro de testes para o Claude Cowork](#roteiro-de-testes-para-o-claude-cowork)
10. [URLs como rotas semânticas](#urls-como-rotas-semânticas)
11. [Build quebrado na Vercel](#build-quebrado-na-vercel)
12. [A linguagem do texto](#a-linguagem-do-texto)
13. [Documentação viva](#documentação-viva)
14. [Segurança proporcional ao porte](#segurança-proporcional-ao-porte)
15. [O que ela previne](#o-que-ela-previne)
16. [Comportamentos importantes](#comportamentos-importantes)
17. [Estrutura do repositório](#estrutura-do-repositório)
18. [Templates e ferramentas](#templates-e-ferramentas)
19. [Versionamento](#versionamento)

## Pré-requisitos

- Um agente de IA compatível com [Agent Skills](https://agentskills.io)
- Para a trilha PHP: PHP 8.1+, MySQL/MariaDB, uma conta de hospedagem (Hostinger ou similar)
- Para a trilha Next.js: Node.js 20+, uma conta na Vercel, um banco (Neon, Supabase, …)
- `git` e, de preferência, o [`gh` CLI](https://cli.github.com/): é ele que cria o
  repositório já privado (R2)
- Acesso de rede a php.net, nextjs.org, tailwindcss.com e GitHub: a skill lê as fontes ao
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
wizard de instalação, painel administrativo, rotas amigáveis, roteiro de testes ou Cowork.
Também dá para chamá-la pelo nome.

```
"Faz um sistema de controle de chamados em PHP e MySQL pra eu subir na Hostinger."
```

Essa frase inicia o pipeline inteiro. Você não precisa pedir a especificação, não precisa
lembrar de pedir a revisão de segurança, e não precisa pedir o roteiro de testes no fim.

### Rígido nas pontas, livre no meio

Esta é a parte que importa, e é o oposto do que "dezoito regras" costuma sugerir:

| | O que acontece | Quem conduz |
| --- | --- | --- |
| **Início** | As perguntas de bootstrap em um lote (seis na trilha PHP, sete na Next.js) → documentação lida **ao vivo** → `specs/<slug>.md` com requisitos e casos de teste → ⛔ sua aprovação | A skill. Nenhuma linha de implementação existe ainda. |
| **Meio** | Construa. Itere, mude de ideia, jogue trabalho fora. | **Você.** É aqui que o vibecoding acontece, e a skill sai da frente: ela só segura três invariantes: SQL parametrizado, nenhum segredo versionado, nenhuma API inventada. |
| **Fim** | O código que existe é verificado: lint, testes, as três varreduras (segredos, SQL injection e linguagem), revisão de segurança, roteiro de QA gerado e executado, versão e documentação atualizadas → ⛔ aprovação → push → ⛔ aprovação → deploy | A skill. Item por item, contra o código real. |

O objetivo não é deixar a construção lenta. É tornar o **começo deliberado** e o **fim
verificado**, para que a parte rápida do meio continue rápida sem acumular débito técnico em
silêncio.

### Como é uma sessão de verdade

**1. Você pede.**

> Faz um sistema de controle de chamados em PHP e MySQL pra eu subir na Hostinger.

**2. As perguntas de bootstrap, em um lote.** Trilha? Repositório (novo já nasce privado)?
Versão do PHP e acesso da hospedagem? Tem login, dado pessoal, pagamento, upload? Nome e
versão inicial? Quem executa o QA: você, o Cowork, ou os dois? Na trilha Next.js entra ainda
uma sétima: posso me conectar à sua conta da Vercel para diagnosticar build quebrado? Toda
decisão posterior se refere a essas respostas, em vez de repetir a pergunta.

**3. A documentação é lida, não lembrada.** php.net para as funções que serão usadas, a
documentação da Hostinger para os limites do plano, MySQL para tipos e índices, OWASP para
as defesas de cada categoria. Tudo vira um registro de evidências: afirmação → fonte →
verificado, com data.

**4. Uma spec, depois uma parada.** `specs/0001-controle-de-chamados.md`: objetivo, o que
fica de fora, requisitos `RF-001`…`RF-012`, modelo de dados com índices e chaves
estrangeiras, telas com os quatro estados, regras de negócio, seção de segurança com o nível
(N1 a N4), critérios de aceite no formato *dado/quando/então*, e os casos de teste que vão
alimentar o roteiro de QA.

> Aqui está a spec. Três decisões que preciso de você: `<A>`, `<B>` e `<C>`.
> São 12 requisitos e 31 casos de teste. Aprova e eu construo?

Se você responder *"pode fazer"*, é uma resposta válida: fica registrado como aprovado sem
revisão e o trabalho segue. O portão é sobre consentimento, não cerimônia.

**5. Agora o vibecoding.** Construa, itere, mude de ideia. A skill não fica recitando regra
aqui. Ela segura três linhas: nenhuma variável dentro de uma string SQL, nenhuma credencial
em arquivo versionado, nenhuma função ou prop usada sem ter sido verificada.

**6. O código pronto é verificado.** `php -l` em todos os arquivos, `composer audit`,
`scan-secrets.sh`, `scan-sql-injection.sh`, `scan-linguagem.sh`, e o checklist de revisão
lido contra o diff, com as sete perguntas adversariais no fim ("se eu fosse o invasor, qual linha deste diff eu
atacaria primeiro?").

**7. O roteiro de testes é gerado e executado.** Um caso por critério de aceite, mais um
caso de SQL injection para **cada** campo que chega ao banco, mais XSS, IDOR, CSRF, upload,
rotas e cabeçalhos. Entregue com números: quantos casos, quantos de segurança, quais requisitos
ficaram sem cobertura.

**8. Versão, documentação, push, deploy.** Versão em SemVer, CHANGELOG datado, README
atualizado, tudo no mesmo commit. Depois a skill nomeia a versão e pergunta antes do push; e
nomeia o domínio, a migração pendente e o backup antes do deploy.

### Configure uma vez por repositório

Copie [`AGENTS.template.md`](skills/development-pattern-for-web-apps/assets/templates/AGENTS.template.md)
para o repositório do app como `AGENTS.md`. Assim a próxima sessão herda o padrão, incluindo
as armadilhas que você já encontrou, em vez de começar do zero.

## As dezoito regras

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
| **R9** | **Todo app PHP+MySQL entrega um Wizard de instalação** que verifica dependências e cria, ou limpa e recria, o banco. |
| **R10** | **Todo app PHP entrega um painel administrativo** que instala pacotes ZIP com arquivos e migrações SQL, com backup e rollback. |
| **R11** | **Toda aplicação entrega um roteiro de testes** em Markdown, executável pelo Claude Cowork: unitário → integração → interface → segurança → regressão. |
| **R12** | **Revise código de IA como código hostil**, contra um checklist, antes de todo push. |
| **R13** | **Versão, documentação e schema andam juntos.** Toda mudança atualiza, no mesmo commit, os documentos que ela afeta. Uma matriz diz quais: README, CHANGELOG, spec, roteiro de QA, `AGENTS.md`, `.env.example`, página. |
| **R14** | **Deploy é explícito, nomeado e reversível**, com backup antes e rollback documentado. |
| **R15** | **A URL é interface, não caminho de arquivo.** `/cadastrar-novo-usuario`, nunca `/usuarios/cadastro.php`. Rota em português, kebab-case, sem extensão; navegação jamais por query string. |
| **R16** | **Build quebrado se conserta com o log na mão e a correção provada localmente.** Reproduzir com `vercel build`, corrigir a causa raiz, um push por volta, teto de três voltas. Nunca `ignoreBuildErrors`. |
| **R17** | **O texto é escrito na língua de quem usa, e nunca entrega que foi gerado.** Pesquisar as convenções do domínio antes da primeira frase de interface. Travessão proibido. Corpo de texto justificado, com hifenização. |
| **R18** | **Nenhuma atribuição de IA nos artefatos do projeto.** Nada de `Co-Authored-By`, "Generated with" ou link de sessão em commit, pull request, README, página ou comentário de código. |

## O pipeline

```
0 BOOTSTRAP   trilha? repo? hospedagem? dados? identidade? QA?
              → .gitignore armado, repo privado, hooks instalados, varredura limpa

1 PESQUISA    documentação oficial do stack, lida ao vivo
              → registro de evidências: afirmação → URL/arquivo → verificado

2 SPEC        specs/<slug>.md: requisitos RF-nnn, critérios de aceite, casos CT-nnn,
              modelo de dados, superfície de ataque, nível de segurança
              → ⛔ PORTÃO DE APROVAÇÃO

3 BUILD       componentes, rotas semânticas, SQL parametrizado, segredos fora,
              wizard e updater no PHP        → cada símbolo rastreado a uma fonte

4 VALIDAÇÃO   lint + tipos + testes unitários + testes de integração
              + scan-secrets.sh + scan-sql-injection.sh + scan-linguagem.sh
              + scan-doc-sync.sh + checklist de revisão
              → resultados reais, reportados honestamente

5 QA/COWORK   gerar qa/roteiro-de-testes.md e executá-lo (ou entregá-lo ao Cowork)
              → evidências, defeitos registrados, suíte de regressão atualizada

6 RELEASE     versão SemVer + a documentação que a matriz pede (scan-doc-sync.sh)
              → ⛔ PORTÃO DE APROVAÇÃO antes do push

7 DEPLOY      Hostinger (FTP/SSH/Git) ou Vercel, alvo nomeado, backup, migração, rollback
              build quebrado: log → reproduzir → corrigir → provar → 1 push (teto de 3)
              → ⛔ PORTÃO DE APROVAÇÃO antes de promover para produção
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
nome de coluna, nome de tabela, `ASC`/`DESC`. A resposta nunca é "concatena com cuidado":
é **allowlist**, com a exceção declarada na linha:

```php
$colunas = ['nome' => 'p.nome', 'data' => 'p.criado_em'];
$coluna  = $colunas[$_GET['ordenar'] ?? ''] ?? 'p.criado_em';
$sql = "SELECT * FROM pedidos p ORDER BY $coluna";   // scan-sql:allow: $colunas
```

O scanner acusa **toda** interpolação em SQL. Para silenciá-la é preciso escrever o
marcador citando a allowlist: na própria linha ou na linha imediatamente acima, onde cabe a
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
ele vira uma sessão de arqueologia: qual extensão falta, qual permissão está errada, qual
SQL rodar em que ordem, por que a página está em branco.

| Passo | O que faz |
| --- | --- |
| **1 · Requisitos** | Versão do PHP, extensões, permissões de escrita, `mod_rewrite`, HTTPS: cada item com o valor encontrado, o exigido e **a instrução de correção no hPanel** |
| **2 · Banco** | Host, porta, banco, usuário, senha. Testa a conexão na hora e **traduz o erro do MySQL** ("1045" vira "usuário ou senha incorretos, confira em hPanel → Bancos de dados") |
| **3 · Estrutura** | Detecta o estado da base: cria do zero, mantém os dados, ou **limpa e recria**. O último exige digitar `APAGAR`, com a lista das tabelas e a contagem de linhas na tela |
| **4 · Administrador** | Primeiro admin, com `password_hash`. Nunca um `admin/admin` "para facilitar" |
| **5 · Conclusão** | Grava a configuração fora do webroot, registra a versão do schema, **se tranca**, e manda apagar a pasta `install/` |

Nada é gravado antes do passo 5: desistir no meio não deixa resíduo. Esqueleto executável em
[`install-wizard.php.template`](skills/development-pattern-for-web-apps/assets/templates/install-wizard.php.template).

## Painel de atualização por pacote ZIP

Atualizar por FTP é onde os projetos pessoais morrem: um arquivo esquecido, um SQL que
ninguém rodou, e o app fica meio atualizado: o pior estado possível.

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

Só então mostra a prévia: arquivos que mudam, migrações a executar, **as destrutivas em
destaque**, e espera a confirmação. Aplica com backup do banco e dos arquivos, modo
manutenção com expiração automática, migrações em ordem registradas em `schema_migrations`,
e **rollback automático** se qualquer etapa falhar.

## Roteiro de testes para o Claude Cowork

Toda aplicação entregue vem com `qa/roteiro-de-testes.md`: um documento que outro agente
consegue **executar** navegando pela aplicação, sem ter participado do desenvolvimento e sem
poder fazer perguntas.

A diferença aparece na frase que cada passo produz. "Verificar se a listagem funciona" não é
testável. Isto é:

```markdown
### CT-014: Filtrar chamados por status
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

**Falha se**: a contagem diverge, aparece chamado com outro status, ou o filtro se perde.
```

Seis suítes, executadas nesta ordem:

| Suíte | O que cobre |
| --- | --- |
| **Fumaça** | 5 a 10 casos. Se falhar, o resto não roda: o ambiente ou o build estão errados |
| **Funcional** | Um caso por critério de aceite, mais validação, fronteira, os quatro estados de tela, persistência, concorrência e formatos |
| **Integração** | Formulário → banco → tela, upload → download, e-mail, webhook idempotente, o Wizard e o painel de atualização |
| **Segurança** | Payloads de SQL injection em **cada** campo que chega ao banco; XSS refletido e armazenado; IDOR; CSRF; sessão; upload; cabeçalhos; acesso a `/config/`, `/.env`, `/.git/config`, `/install/` |
| **Interface** | 375/768/1440 px, só teclado, rótulos, contraste AA, zoom 200%, estado vazio, duplo clique |
| **Regressão** | Cresce a cada defeito corrigido. Roda inteira antes de todo release: é a memória do projeto |

Fecha com a **matriz de rastreabilidade** requisito × caso, que **declara por nome** os
requisitos sem cobertura em vez de omiti-los, e com o registro de execução em números:
aprovados, reprovados, bloqueados. Qualquer defeito 🔴 em aberto bloqueia o release.

E com nove regras voltadas a quem executa: entre elas: *não conserte a aplicação durante
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
nome do arquivo, e quebra todo link publicado no dia em que você mover o arquivo.

As sete convenções: português, minúsculas, kebab-case · sem acento e sem cedilha · sem
extensão · sem estrutura de pastas · ação é verbo no infinitivo (`/redefinir-senha`) ·
coleção é substantivo plural com identificador (`/chamados/8`) · **navegação nunca depende de
query string**.

A query string não some: muda de papel. Ela carrega **estado da visualização**, e é por isso
que `/chamados?status=fechado&pagina=2` é compartilhável e favoritável, enquanto
`/index.php?p=chamados` não significa nada fora da sua sessão.

Na trilha PHP, um front controller e um mapa de rotas escrito à mão, com canonicalização
(barra final e caixa respondem 301), tabela de redirecionamentos para rotas renomeadas e 404
de verdade. Na trilha Next.js, o nome da pasta **é** a URL, então a convenção de nomes de
pasta é a convenção de URLs: `app/cadastrar-novo-usuario/page.tsx`.

A referência traz o roteador completo, o helper `rota()` que evita escrever a mesma URL duas
vezes, a geração de slug, os redirecionamentos em `next.config.ts`, uma tabela de tradução de
URLs antigas, e os treze casos de teste que entram no roteiro de QA.

## Build quebrado na Vercel

Você pede, o agente se conecta à sua conta, encontra o deploy que falhou, lê o log, corrige e
empurra, e o CI/CD da Vercel publica a versão nova. O ciclo repete até o preview ficar verde.

O que impede isso de virar *empurra e reza*:

```
1 OBTER      identificar o deploy que falhou e baixar o LOG COMPLETO
2 LER        classificar: falha de CÓDIGO ou de AMBIENTE
3 REPRODUZIR vercel pull && vercel build   → a MESMA mensagem tem que aparecer
4 CORRIGIR   a menor mudança que resolve a causa raiz
5 PROVAR     vercel build + tsc + lint + testes + os scanners
6 EMPURRAR   UM push, no ramo de trabalho → deploy de preview
7 CONFIRMAR  verde? Se não, volta ao passo 1 com o NOVO log
8 PORTÃO     ⛔ merge em main (produção) só com aprovação
```

**O passo 3 não é opcional.** Falha que não foi reproduzida localmente é falha que não foi
entendida, e a correção é chute. `vercel build` reproduz o build da Vercel com a
configuração e as variáveis do ambiente escolhido, que é o que pega a falha que só aparece no
deploy.

**Teto de três voltas.** Depois disso o agente para e escala com uma hipótese e um pedido
concreto, em vez de queimar minutos de CI.

**A separação que mais importa é código × ambiente.** A causa não-código mais comum é uma
variável que existe em Production e não em Preview: são ambientes separados. O agente
**não conserta isso**: ele nomeia a variável e o ambiente e para. Inventar um valor padrão no
código transformaria uma falha visível numa falha silenciosa em produção.

E o que ele nunca faz para ficar verde:

```ts
// ❌ next.config.ts: proibidos pela regra
export default {
  typescript: { ignoreBuildErrors: true },   // o erro continua lá, agora invisível
  eslint:     { ignoreDuringBuilds: true },
};
```

Também proibidos: apagar o teste que falha, `@ts-ignore` num erro real, `any` para atravessar
uma incompatibilidade, e commit vazio para reprocessar. Se a única saída for uma dessas, é
decisão sua: o agente apresenta o trade-off e espera.

O acesso é por servidor MCP da Vercel (preferido, detectado antes de perguntar), CLI com
`VERCEL_TOKEN`, ou API REST. O token vive em `.env`, com escopo mínimo, nunca versionado (R1),
e `.vercel/` entra no `.gitignore`.

## A linguagem do texto

Para quem usa o sistema, o texto **é** o produto. A pessoa não vê a arquitetura, não vê o
schema, não vê o SQL parametrizado. Ela vê "Não foi possível concluir a operação" e decide
ali se confia ou não. Um botão escrito na língua errada custa mais suporte que um bug.

**O travessão é proibido em texto visível ao usuário.** Ele não faz parte da escrita corrente
em português brasileiro fora da literatura, soa empolado em tela de aplicação e hoje funciona
como assinatura de texto gerado. O teclado ABNT2 nem tem a tecla. Junto dele caem as muletas
que marcam texto de IA: `Além disso`, `Vale ressaltar`, `Mergulhe`, `solução robusta`,
`experiência perfeita`, e o hábito de listar sempre três itens.

| Em vez de | Escreva |
| --- | --- |
| `O prazo é curto — três dias.` | `O prazo é curto: três dias.` |
| `A conta — que estava ativa — foi encerrada.` | `A conta, que estava ativa, foi encerrada.` |
| `Tente de novo — se persistir, avise.` | `Tente de novo. Se persistir, avise.` |
| `Status — Aberto` | `Status: Aberto` |

`scan-linguagem.sh` pega os dois casos. Em Markdown ele ignora o que está entre crases, onde
o travessão está sendo citado e não usado.

**A segunda metade da regra é pesquisar o domínio** antes de escrever a primeira frase de
interface. Escrever "seu dinheiro sumiu" num app bancário e "chamado encerrado com sucesso!"
num sistema de suporte são erros do mesmo tipo: linguagem que ignora a convenção de quem lê.

**A skill não carrega dossiês de domínio, de propósito.** Seria fácil listar aqui o
vocabulário de banco, de saúde, de suporte. Seria também um erro, pelo mesmo motivo que ela
não vendoriza documentação de terceiros: um dossiê congelado envelhece parecendo autoritativo,
e a existência dele convida o agente a pular a pesquisa, que é justamente a regra. O que a
referência traz é o protocolo e as perguntas, não as respostas.

O protocolo: descobrir quem lê, abrir de três a cinco produtos reais do domínio e ler as
telas equivalentes, extrair as cinco dimensões abaixo, confirmar com quem conhece o setor, e
registrar na spec com as fontes e a data. Produto real que o usuário já usa vale mais que
artigo sobre o setor.

| Dimensão | O que apurar |
| --- | --- |
| **Vocabulário canônico** | Os termos que o setor usa, e quais deles **não** são sinônimos entre si |
| **Tom** | Formal, neutro ou próximo, e quanta emoção o setor tolera |
| **O que nunca se diz** | A frase que o setor evita, e a razão legal, regulatória ou histórica |
| **O que sempre se diz** | A informação cuja ausência gera contato com o suporte |
| **Estado emocional de quem lê** | Chega tranquilo, com pressa, com medo, ou com o trabalho parado |

A quinta é a que mais muda a escrita e a que menos gente investiga. Quem está com o trabalho
parado não quer entusiasmo; quem teme perder dinheiro não quer ambiguidade. Se a pesquisa não
foi possível, isso vai escrito na spec, em vez de preenchido de memória.

A terceira parte é tipográfica: corpo de texto **justificado**, com `hyphens: auto` e o idioma
declarado no `<html>`. Justificar sem hifenizar é pior que não justificar, porque o navegador
estica os espaços e abre corredores brancos no meio do parágrafo. Títulos, rótulos, código,
listas curtas e colunas abaixo de 40 caracteres continuam à esquerda.

A referência traz ainda a anatomia das mensagens de erro (o que houve, por quê, o que fazer),
os padrões de botão, estado vazio e confirmação destrutiva, e os casos de teste que entram no
roteiro de QA.

## Documentação viva

Documentação desatualizada é pior que documentação ausente. A ausente você percebe e vai
ler o código; a desatualizada você acredita, e ela te leva ao lugar errado com confiança.
Um README que descreve o app de duas versões atrás faz alguém tentar instalar do jeito que
não funciona mais e concluir que o projeto está quebrado.

Por isso a regra é **no mesmo commit**, e não "antes do release". Se o commit que muda o
comportamento não muda o texto que descreve o comportamento, o par nunca mais se encontra.

A skill mantém o inventário do que um projeto deste padrão documenta (README, CHANGELOG,
`AGENTS.md`, specs, roteiro e dados de teste, `.env.example`, schema e migrações, manifesto
do pacote, arquivo de versão, página) e uma **matriz de mudança → documento**. Esta é a
versão curta; a referência traz as catorze linhas e a coluna do `AGENTS.md`:

| Mudei… | README | CHANGELOG | spec | QA | `.env.example` | Versão | Página |
| --- | :-: | :-: | :-: | :-: | :-: | :-: | :-: |
| Comportamento visível ao usuário | ✅ | ✅ | ✅ | ✅ | | ✅ | ✅ |
| Rota nova ou renomeada | ✅ | ✅ | ✅ | ✅ | | ✅ | ✅ |
| Tabela ou coluna nova | | ✅ | ✅ | ✅ | | ✅ | |
| Variável de ambiente nova | ✅ | ✅ | | | ✅ | ✅ | |
| Correção de bug | | ✅ | | ✅ | | ✅ | |
| Correção de segurança | ✅ | ✅ | ✅ | ✅ | | ✅ | |
| Refatoração sem mudança visível | | | | | | | |

A última linha existe de propósito: é o respaldo para dizer "esta não precisa", em vez de
inventar uma entrada de CHANGELOG para uma mudança que ninguém percebe.

E a pergunta que resolve os casos duvidosos: *se alguém instalar o app amanhã seguindo o
README, e usar o app seguindo o CHANGELOG, algo vai surpreender essa pessoa por causa desta
mudança?* Se sim, o documento entra no commit.

O `scan-doc-sync.sh` lê o que está no staging e aponta o que a matriz pede e você não tocou:
CHANGELOG intocado com código novo, `.env.example` intocado quando apareceu uma variável de
ambiente no diff, versão parada, roteiro de QA parado com migração nova. Ele marca `[PEDE]`
quando a matriz é clara e `[OLHE]` quando depende de julgamento, porque ele não sabe se a
sua mudança é visível ao usuário. Essa parte é sua.

## Segurança proporcional ao porte

O piso vale para todo projeto, inclusive o de fim de semana com três usuários:

| | Piso obrigatório |
| --- | --- |
| P1 a P3 | SQL parametrizado · nenhum segredo versionado · senha com `password_hash` |
| P4 a P6 | CSRF em toda ação de estado · saída escapada · cookie `HttpOnly`/`Secure`/`SameSite` |
| P7 a P9 | HTTPS forçado · cabeçalhos de segurança · autorização conferida por registro |
| P10 a P12 | Erros logados e nunca exibidos · upload restrito e sem execução · dependências auditadas |

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
| "Testei, está tudo funcionando", e não estava | Teste sem roteiro e sem resultado esperado escrito | R11 |
| Três deploys, todos reportando `1.0.0` | Versão não subiu por publicação | R13 |
| Ninguém sabe qual migração já rodou naquele banco | Versão do schema não gravada na base | R13 |
| Deploy derrubou o site e não há caminho de volta | Sem backup e sem rollback documentado | R14 |
| Cinco commits de "tenta assim" até o build passar | Correção sem reprodução local | R16 |
| Build verde com `ignoreBuildErrors`, e o erro estourando em produção | Amputação em vez de correção | R16 |
| Funciona em produção e quebra no preview | Variável de ambiente que só existe num dos dois | R16 |
| O texto da tela parece gerado por IA e o usuário desconfia do produto | Travessão e muletas genéricas | R17 |
| O histórico do seu projeto pessoal credita uma ferramenta como coautora | Trailer automático não desligado | R18 |
| README descreve o app de duas versões atrás, e alguém acredita nele | Documentação deixada para depois do commit | R13 |
| App bancário dizendo "Ops, algo deu errado" depois de uma transferência | Linguagem sem pesquisa do domínio | R17 |
| Formulário de ITSM chamando pedido de acesso de "problema" | Vocabulário canônico do setor ignorado | R17 |
| A URL entrega a linguagem, a pasta e o nome do arquivo do servidor | Caminho de arquivo servido como rota | R15 |
| Todo link publicado quebrou ao reorganizar as pastas | URL acoplada à estrutura em disco | R15 |

## Comportamentos importantes

### É opinativa de propósito
As regras são absolutas porque "prefira prepared statements quando razoável" vira, na
prática, "use prepared statements até dar um pouco de trabalho". Se você discorda de uma
regra, edite o `SKILL.md`, é Markdown, e é seu.

### Ela se recusa a chutar
Quando o pacote não está instalado e a documentação está inacessível, a instrução é dizer
*"não consigo verificar isso"* e oferecer os dois passos que destravariam: em vez de emitir
uma chamada plausível que falha em produção às duas da manhã. Espere mais perguntas e menos
falhas silenciosas.

### Ela trata a versão e a documentação como parte da mudança
Não como trabalho posterior. Um commit que muda comportamento sem subir a versão e sem
atualizar o README é, sob este padrão, um commit incompleto.

### Os scanners são rede, não garantia
Eles pegam padrões conhecidos. Um segredo que pareça texto comum passa. Uma consulta montada
em várias linhas pode escapar da varredura por linha. **Varredura limpa é necessária, não
suficiente: leia o seu próprio diff.** A skill diz isso na saída de cada execução.

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
├── SKILL.md                          # 18 regras, 8 fases, 3 portões, roteamento
├── references/
│   ├── segredos-e-configuracao.md    # R1: .env, config fora do webroot, Vercel, rotação
│   ├── git-e-publicacao.md           # R2: privado por padrão, commits, ramos, publicação
│   ├── fluxo-spec-driven.md          # R3: fases, portões, anatomia da spec
│   ├── protocolo-de-verificacao.md   # R4: hierarquia de fontes, comandos, armadilhas
│   ├── sql-e-acesso-a-dados.md       # R5. PDO, LIKE, IN, ORDER BY, transações, Next.js
│   ├── entrada-e-saida-seguras.md    # R6: validação, escape, CSRF, upload, traversal, SSRF
│   ├── linha-de-base-de-seguranca.md # R7: o piso de 12 itens e os níveis N1 a N4
│   ├── stack-php-mysql.md            # R8: layout, front controller, partials, Hostinger
│   ├── stack-nextjs-vercel.md        # R8. App Router, Server Actions, Tailwind, Vercel
│   ├── wizard-de-instalacao.md       # R9: os cinco passos e o que testar
│   ├── pacotes-de-atualizacao.md     # R10: manifesto, zip slip, migrações, rollback
│   ├── roteiro-de-testes-cowork.md   # R11: as seis suítes, payloads, rastreabilidade
│   ├── checklist-de-revisao.md       # R12: o checklist e as sete perguntas adversariais
│   ├── release-e-deploy.md           # R13, R14. SemVer, CHANGELOG, deploy, rollback
│   ├── rotas-e-urls.md               # R15: convenções, roteador, 301, 404, tradução
│   ├── vercel-build-e-correcao.md    # R16: conectar, ler log, reproduzir, corrigir
│   ├── linguagem-e-texto-da-interface.md  # R17: domínio, travessão, microcopy, tipografia
│   └── documentacao-do-projeto.md    # R13: inventário e matriz de mudança → documento
└── assets/
    ├── templates/                    # 18 arquivos prontos para copiar
    └── scripts/
        ├── scan-secrets.sh
        ├── scan-sql-injection.sh
        ├── scan-linguagem.sh
        └── scan-doc-sync.sh
docs/index.html                       # fonte da página deste projeto
specs/                                # a spec desta própria skill (R3 aplicada a ela mesma)
.github/workflows/pages.yml           # publica docs/ no ramo gh-pages, gerado
```

`gh-pages` é gerado e sobrescrito pelo CI: edite `docs/`, nunca aquele ramo.

## Templates e ferramentas

| Arquivo | Para que serve |
| --- | --- |
| [`spec.template.md`](skills/development-pattern-for-web-apps/assets/templates/spec.template.md) | Spec com requisitos numerados, critérios de aceite, casos de teste, segurança e evidências |
| [`correcao-de-build.template.md`](skills/development-pattern-for-web-apps/assets/templates/correcao-de-build.template.md) | Registro de um ciclo de correção de build: log citado, classificação, reprodução, correção, prova e escalonamento |
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
| [`pre-commit.template`](skills/development-pattern-for-web-apps/assets/templates/pre-commit.template) | Hook que roda os scanners e `php -l` antes de cada commit |
| [`commit-msg.template`](skills/development-pattern-for-web-apps/assets/templates/commit-msg.template) | Hook que recusa o commit se a mensagem trouxer atribuição de IA (R18) |

Instale os dois hooks no repositório do app, uma vez, logo no bootstrap:

```bash
T=skills/development-pattern-for-web-apps/assets/templates
cp $T/pre-commit.template  .git/hooks/pre-commit
cp $T/commit-msg.template  .git/hooks/commit-msg
chmod +x .git/hooks/pre-commit .git/hooks/commit-msg
```

E desligue a atribuição automática na origem (R18). No Claude Code, em
`~/.claude/settings.json` para valer em todos os projetos, ou em `.claude/settings.json`
para valer só neste:

```json
{
  "attribution": {
    "commit": "",
    "pr": "",
    "sessionUrl": false
  }
}
```

Os três campos importam: `commit` zera o rodapé do commit, `pr` zera o do pull request, e
`sessionUrl: false` suprime o trailer `Claude-Session:` que sessões web e de Remote Control
acrescentam por conta própria. O hook é a rede que pega o que passar da configuração,
inclusive na máquina onde ninguém lembrou de mexer nela.

Rode os scanners a qualquer momento:

```bash
bash skills/development-pattern-for-web-apps/assets/scripts/scan-secrets.sh
git diff --cached | bash skills/development-pattern-for-web-apps/assets/scripts/scan-secrets.sh --stdin
bash skills/development-pattern-for-web-apps/assets/scripts/scan-sql-injection.sh
bash skills/development-pattern-for-web-apps/assets/scripts/scan-linguagem.sh
bash skills/development-pattern-for-web-apps/assets/scripts/scan-doc-sync.sh
```

## Versionamento

Esta skill segue [SemVer](https://semver.org/lang/pt-BR/): o mesmo padrão que a R13 exige
dos apps que ela ajuda a construir. "Quebrar" significa quebrar para quem **usa** a skill:
uma regra renumerada, uma referência removida, um contrato de template alterado.

- `.claude-plugin/plugin.json` → `version` é a fonte da verdade: um arquivo de configuração,
  do mesmo jeito que `app/version.php` ou `package.json` é para um app.
- Toda publicação é registrada em [CHANGELOG.md](CHANGELOG.md).

**Versão atual: 1.0.0.**

Correções e adições são bem-vindas: abra uma issue ou um pull request.
