---
name: development-pattern-for-web-apps
description: "Padrão de desenvolvimento para apps web pessoais em dois stacks. HTML5 + PHP + MySQL hospedado na Hostinger, e Next.js + Tailwind publicado na Vercel. Carregue ANTES de escrever, revisar, testar, publicar ou implantar qualquer código destes projetos. Impõe: SQL sempre parametrizado (zero concatenação, prepared statements, allowlist de identificadores); segredos e credenciais de banco fora do repositório; repositório GitHub privado por padrão; desenvolvimento guiado por especificação com portão de aprovação; interface por componentes (Server Components + Tailwind no Next.js, front controller + partials no PHP); URLs como rotas semânticas em português (/cadastrar-novo-usuario, nunca /usuarios/cadastro.php); Wizard de instalação que verifica dependências e cria ou recria o banco em todo app PHP+MySQL; painel administrativo que instala pacotes ZIP de atualização com arquivos e migrações SQL; um roteiro de testes em Markdown para o Claude Cowork navegar e executar QA e regressão em toda aplicação entregue; revisão de segurança do código escrito por IA; diagnóstico e correção de build quebrado na Vercel, com o log em mãos e a correção provada localmente; texto de interface escrito na língua do domínio do usuário, sem travessão e sem as muletas que entregam texto de IA, com corpo justificado; documentação atualizada no mesmo commit da mudança, por matriz (README, CHANGELOG, spec, roteiro de QA, AGENTS.md, .env.example, página); e nenhuma atribuição de IA em commit, pull request ou código. Dispare em: 'app PHP', 'PHP e MySQL', 'Hostinger', 'Next.js', 'Vercel', 'Tailwind', 'SQL injection', 'wizard de instalação', 'painel administrativo', 'roteiro de testes', 'Cowork', 'rotas amigáveis', 'URL amigável', 'build quebrado', 'deploy falhou', 'texto da interface', 'UX writing', 'microcopy', 'travessão', 'mensagem de erro', 'atualizar documentação', 'co-authored-by', 'projeto pessoal', 'vibecoding de app web'."
license: MIT
---

# Development Pattern for Web Apps

Guarda-corpo para construir **aplicações web pessoais** com um agente de IA, em dois stacks:

| Trilha | Stack | Hospedagem |
| --- | --- | --- |
| **PHP** | HTML5 + CSS + PHP 8 + MySQL/MariaDB | Hostinger (Apache, shared hosting) |
| **Next.js** | Next.js (App Router) + React + Tailwind CSS | Vercel |

O trabalho dele não é te deixar mais rápido a chutar. É tornar o chute **estruturalmente
difícil**: toda função, prop, classe, opção de configuração e comando que o agente emitir
precisa ser rastreável a uma fonte que ele leu nesta sessão, e todo dado que chega ao banco
precisa passar por um parâmetro vinculado, nunca por uma string concatenada.

---

## Como esta skill é usada

**Ela carrega no primeiro prompt sobre o app e permanece carregada até a entrega.**

> "Faz um sistema de controle de chamados em PHP e MySQL pra eu subir na Hostinger."

Essa frase inicia o pipeline inteiro. Não espere pedirem a especificação. Não espere pedirem
a revisão de segurança. Não espere pedirem o roteiro de testes. Os três são parte do trabalho
desde a primeira mensagem.

O formato é **rígido nas pontas, livre no meio**:

| | O que acontece | Quem conduz |
| --- | --- | --- |
| **Início** | Seis perguntas de bootstrap → ler a documentação oficial **ao vivo** → escrever `specs/<slug>.md` com requisitos e casos de teste → ⛔ aprovação | **A skill.** Nenhuma linha de implementação existe ainda. |
| **Meio** | Construir. Iterar, mudar de ideia, jogar trabalho fora. | **O desenvolvedor.** É aqui que o vibecoding acontece, e a skill sai da frente: ela só segura as invariantes: SQL parametrizado, nenhum segredo em arquivo versionado, nenhuma API inventada. |
| **Fim** | Verificar o código que existe: lint, testes, varredura de segredos e de SQL injection, revisão de segurança, roteiro de testes gerado, Cowork executa o QA, versão e documentação atualizadas → ⛔ aprovação → push → ⛔ aprovação → deploy | **A skill.** Item por item, contra o código real. |

Duas consequências disso, fáceis de errar:

- **Não policie cada tecla no meio.** Interromper cada edição para recitar uma regra destrói
  exatamente o que torna o vibecoding útil. Segure as invariantes; deixe o resto correr.
- **Não pule o fechamento porque o meio correu bem.** "Parece certo" é precisamente o estado
  em que uma query concatenada, uma senha em texto plano ou uma credencial versionada
  sobrevivem até a produção.

---

## As dezoito regras inegociáveis

Elas passam por cima de qualquer outro instinto, inclusive "mas essa mudança é minúscula".

| # | Regra | Detalhada em |
| --- | --- | --- |
| **R1** | **Nenhum segredo entra no repositório.** Credenciais de banco, chaves de API, tokens, `.env`, hostnames reais, e-mails e dados de cliente nunca chegam a um commit. Placeholder no arquivo versionado, valor real só em variável de ambiente ou arquivo ignorado. | [segredos-e-configuracao.md](references/segredos-e-configuracao.md) |
| **R2** | **Repositório privado por padrão.** Todo projeto nasce `--private`. Torná-lo público é uma decisão explícita, projeto a projeto, e só depois de varrer **o histórico inteiro** em busca de segredos. | [git-e-publicacao.md](references/git-e-publicacao.md) |
| **R3** | **Especificação antes do código.** Trabalho não trivial recebe `specs/<slug>.md` com requisitos funcionais numerados, critérios de aceite e casos de teste, e um portão de aprovação explícito. | [fluxo-spec-driven.md](references/fluxo-spec-driven.md) |
| **R4** | **Nunca invente uma API.** Função PHP, extensão, prop de componente, hook, classe do Tailwind, opção de configuração ou flag de CLI só entram no código depois de verificadas em `vendor/`, `node_modules/**/*.d.ts`, `composer.json`, `php.net` ou na documentação oficial lida nesta sessão. | [protocolo-de-verificacao.md](references/protocolo-de-verificacao.md) |
| **R5** | **Todo SQL é parametrizado.** Zero interpolação de dado em SQL, em qualquer linguagem. PDO com `ERRMODE_EXCEPTION` e `ATTR_EMULATE_PREPARES => false`. Identificadores (tabela, coluna, direção de `ORDER BY`) vêm de allowlist, jamais da entrada, e a exceção é declarada com `scan-sql:allow` na linha ou logo acima dela. Uma query que "não dá para parametrizar" é uma query a reescrever. | [sql-e-acesso-a-dados.md](references/sql-e-acesso-a-dados.md) |
| **R6** | **Validar na entrada, escapar na saída.** Toda entrada validada por allowlist na fronteira; toda saída escapada no contexto correto (HTML, atributo, JS, URL, `LIKE`, shell). Validação no cliente é usabilidade, nunca segurança. | [entrada-e-saida-seguras.md](references/entrada-e-saida-seguras.md) |
| **R7** | **A linha de base de segurança é inegociável; acima dela, proporcional ao porte.** O piso vale até para o projetinho de fim de semana. O que muda com o porte é o que se acrescenta, nunca o que se remove. | [linha-de-base-de-seguranca.md](references/linha-de-base-de-seguranca.md) |
| **R8** | **Interface por componentes.** Next.js: App Router, Server Components por padrão, Tailwind com tokens do tema, um componente por responsabilidade. PHP: front controller + partials, zero cabeçalho copiado e colado, zero HTML montado por concatenação. | [stack-nextjs-vercel.md](references/stack-nextjs-vercel.md) · [stack-php-mysql.md](references/stack-php-mysql.md) |
| **R9** | **Todo app PHP+MySQL entrega um Wizard de instalação.** Verifica dependências, recebe host/banco/usuário/senha, testa a conexão, cria o schema de forma idempotente **ou** limpa e recria quando a instância já existe, cria o administrador, grava a configuração fora do repositório e se tranca ao terminar. | [wizard-de-instalacao.md](references/wizard-de-instalacao.md) |
| **R10** | **Todo app PHP entrega um painel administrativo que instala pacotes ZIP de atualização.** Manifesto versionado, arquivos publicados só em caminhos permitidos, migrações SQL ordenadas e idempotentes, backup antes, rollback depois, recusa de pacote que não confere com o manifesto. | [pacotes-de-atualizacao.md](references/pacotes-de-atualizacao.md) |
| **R11** | **Toda aplicação entregue vem com um roteiro de testes para o Claude Cowork.** `qa/roteiro-de-testes.md`: navegável passo a passo, determinístico, rastreado aos requisitos da spec, cobrindo unitário → integração → interface (E2E) → segurança → regressão. Cresce a cada defeito corrigido. | [roteiro-de-testes-cowork.md](references/roteiro-de-testes-cowork.md) |
| **R12** | **Revise código escrito por IA como código hostil.** O checklist de segurança e qualidade roda antes de todo push, contra o diff real. | [checklist-de-revisao.md](references/checklist-de-revisao.md) |
| **R13** | **Versão, documentação e schema andam juntos.** Toda mudança atualiza, **no mesmo commit**, os documentos que ela afeta: README, CHANGELOG, spec, roteiro de QA, `AGENTS.md`, `.env.example`, página. A matriz diz quais. Toda publicação sobe a versão em SemVer e registra a versão do schema no próprio banco. | [documentacao-do-projeto.md](references/documentacao-do-projeto.md) · [release-e-deploy.md](references/release-e-deploy.md) |
| **R14** | **Deploy é explícito, nomeado e reversível.** Nenhum envio para Hostinger ou Vercel sem alvo nomeado e um "sim". Migração em ordem conhecida, backup antes, caminho de volta documentado. | [release-e-deploy.md](references/release-e-deploy.md) |
| **R15** | **A URL é interface, não caminho de arquivo.** Toda rota descreve a ação ou o recurso em português, em kebab-case, sem extensão e sem revelar a estrutura de pastas: `/cadastrar-novo-usuario`, nunca `/usuarios/cadastro.php`. Navegação jamais depende de query string. | [rotas-e-urls.md](references/rotas-e-urls.md) |
| **R16** | **Build quebrado se conserta com o log na mão e a correção provada localmente.** Ler o log completo, classificar como falha de código ou de ambiente, reproduzir com `vercel build`, corrigir a causa raiz, provar, e **um** push por volta, com teto de três voltas. Nunca `ignoreBuildErrors`, nunca inventar valor para variável ausente. | [vercel-build-e-correcao.md](references/vercel-build-e-correcao.md) |
| **R17** | **O texto é escrito na língua de quem usa, e nunca entrega que foi gerado.** Pesquisar as convenções do domínio antes da primeira frase de interface. **Travessão é proibido** em texto visível, junto das muletas que marcam texto de IA. Corpo de texto justificado, com `hyphens: auto`. | [linguagem-e-texto-da-interface.md](references/linguagem-e-texto-da-interface.md) |
| **R18** | **Nenhuma atribuição de IA nos artefatos do projeto.** Nada de `Co-Authored-By`, "Generated with", link de sessão ou menção à ferramenta em commit, pull request, README, página ou comentário de código. O projeto é de quem o assina. | [git-e-publicacao.md](references/git-e-publicacao.md) |

Se uma regra não puder ser cumprida, **pare e diga**. Não entregue silenciosamente uma versão
degradada.

---

## Fase 0: Bootstrap da sessão (uma vez, antes de qualquer coisa)

Não comece a codar sem estas respostas. Pergunte **em um único lote**, nunca uma por vez.
São seis na trilha PHP e sete na trilha Next.js.

1. **Trilha**: "PHP + MySQL na Hostinger, ou Next.js na Vercel?"
   → Define stack, layout de projeto, forma de deploy e quais regras específicas entram
   (R9 e R10 valem só para PHP).
2. **Repositório**: "Existe repositório? URL, ou crio um novo?"
   → Novo nasce **privado** (R2). Guarde a resposta: todo momento de "posso dar push?"
   depois se refere a ela.
3. **Hospedagem e ambiente**. Hostinger: versão do PHP, se há acesso SSH, se o `public_html`
   é a raiz do domínio. Vercel: nome do projeto, banco (Neon/Supabase/PlanetScale/outro).
   → Nada disso entra em arquivo versionado (R1).
4. **Dados e usuários**. Há login? Há dado pessoal (LGPD)? Há pagamento? Há upload de
   arquivo? Quantos usuários simultâneos, na ordem de grandeza?
   → Isso define o **nível de segurança** acima do piso (R7).
5. **Identidade do app**: nome de exibição, slug do repositório, versão inicial
   (`0.1.0` para projeto novo).
6. **Testes**: "Quem executa o QA: você, o Claude Cowork, ou os dois?"
   → O roteiro é gerado de qualquer forma (R11); a resposta define o nível de detalhe
   de navegação e as credenciais de teste necessárias.
7. **Acesso à Vercel** (só na trilha Next.js): "Posso me conectar à sua conta para
   diagnosticar build quebrado? Há servidor MCP da Vercel, ou uso o CLI com token?"
   → **Detecte primeiro, pergunte depois.** Sem isso, a R16 só funciona com o log que
   você colar manualmente. O token vive em `.env`, nunca versionado (R1).

Ainda na mesma fase, **antes do primeiro commit**:

- Armar o `.gitignore` da trilha escolhida e criar o par `.env` / `.env.example`.
- Rodar a primeira varredura: `scan-secrets.sh`.
- Instalar os hooks `pre-commit` e `commit-msg` em `.git/hooks/` (R18).
- Confirmar que o repositório remoto é privado.

→ [segredos-e-configuracao.md](references/segredos-e-configuracao.md)

---

## Fases 1 → 7. O pipeline

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

Três portões são paradas duras. Nunca os atravesse por iniciativa própria.

Definições completas: [fluxo-spec-driven.md](references/fluxo-spec-driven.md).

---

## Roteamento de referências

Carregue a referência **antes** de fazer o trabalho, não depois que ele falhar.

| Você está prestes a… | Leia primeiro |
| --- | --- |
| Escrever qualquer `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `ORDER BY` dinâmico ou filtro de busca | [sql-e-acesso-a-dados.md](references/sql-e-acesso-a-dados.md) |
| Tocar em `.env`, arquivo de configuração, credencial, chave de API, `.gitignore` | [segredos-e-configuracao.md](references/segredos-e-configuracao.md) |
| Receber dado de formulário, query string, JSON, cabeçalho, cookie ou upload | [entrada-e-saida-seguras.md](references/entrada-e-saida-seguras.md) |
| Imprimir qualquer coisa na tela que veio do banco ou do usuário | [entrada-e-saida-seguras.md](references/entrada-e-saida-seguras.md) |
| Implementar login, sessão, permissão, recuperação de senha, rate limiting | [linha-de-base-de-seguranca.md](references/linha-de-base-de-seguranca.md) |
| Decidir "quanta segurança este projeto precisa" | [linha-de-base-de-seguranca.md](references/linha-de-base-de-seguranca.md) |
| Criar a estrutura de um projeto PHP, front controller, `.htaccess`, partials | [stack-php-mysql.md](references/stack-php-mysql.md) |
| Criar a estrutura de um projeto Next.js, componente, Server Action, Tailwind | [stack-nextjs-vercel.md](references/stack-nextjs-vercel.md) |
| Definir uma rota, nomear uma URL, renomear uma existente, tratar 404 e redirecionamento | [rotas-e-urls.md](references/rotas-e-urls.md) |
| Investigar um build que falhou na Vercel, ler log de deploy, conectar-se à conta | [vercel-build-e-correcao.md](references/vercel-build-e-correcao.md) |
| Escrever qualquer texto que o usuário vai ler: botão, erro, rótulo, estado vazio, e-mail | [linguagem-e-texto-da-interface.md](references/linguagem-e-texto-da-interface.md) |
| Decidir qual documentação a sua mudança obriga a atualizar | [documentacao-do-projeto.md](references/documentacao-do-projeto.md) |
| Construir ou alterar o instalador do app PHP | [wizard-de-instalacao.md](references/wizard-de-instalacao.md) |
| Construir o painel administrativo, o formato do pacote ZIP ou uma migração | [pacotes-de-atualizacao.md](references/pacotes-de-atualizacao.md) |
| Escrever ou atualizar o roteiro de testes, ou preparar o app para o Cowork | [roteiro-de-testes-cowork.md](references/roteiro-de-testes-cowork.md) |
| Escrever uma spec, ou decidir se o trabalho precisa de uma | [fluxo-spec-driven.md](references/fluxo-spec-driven.md) |
| Afirmar que uma API, função ou classe existe | [protocolo-de-verificacao.md](references/protocolo-de-verificacao.md) |
| Fazer commit, criar repositório, escrever mensagem de commit, tornar algo público | [git-e-publicacao.md](references/git-e-publicacao.md) |
| Revisar o código antes de um push | [checklist-de-revisao.md](references/checklist-de-revisao.md) |
| Subir a versão, escrever o CHANGELOG, implantar, reverter | [release-e-deploy.md](references/release-e-deploy.md) |

Modelos prontos para copiar: [`assets/templates/`](assets/templates/).
Scanners: [`assets/scripts/`](assets/scripts/): segredos, SQL injection e linguagem.

---

## A regra que mais importa: R5, na prática

SQL injection é a única falha desta lista que transforma um projeto pessoal em um incidente
de dados de terceiros. Ela tem uma causa única e uma cura única.

**A causa:** dado do usuário virando parte do texto do comando SQL.

```php
// ❌ NUNCA. Nem "só nesse caso". Nem "o campo é numérico". Nem "é área logada".
$sql = "SELECT * FROM pedidos WHERE cliente_id = " . $_GET['id'];
$sql = "SELECT * FROM users WHERE email = '{$email}'";
$pdo->query("DELETE FROM logs WHERE dia < '$dia'");
```

**A cura:** o dado nunca toca o texto. Ele viaja por um parâmetro vinculado.

```php
// ✅ Sempre.
$stmt = $pdo->prepare('SELECT * FROM pedidos WHERE cliente_id = :id');
$stmt->execute([':id' => $id]);
$pedidos = $stmt->fetchAll();
```

**O caso difícil**, e onde quase todo mundo escorrega: o que *não pode* ser parametrizado:
nome de tabela, nome de coluna, `ASC`/`DESC`, `LIMIT` em algumas versões. Para esses, a
resposta nunca é "então concatena com cuidado". É **allowlist**:

```php
// ✅ O valor que chega do usuário é uma CHAVE, não um fragmento de SQL.
$colunas  = ['nome' => 'p.nome', 'data' => 'p.criado_em', 'valor' => 'p.total'];
$ordens   = ['asc' => 'ASC', 'desc' => 'DESC'];

$coluna = $colunas[$_GET['ordenar_por'] ?? 'data'] ?? 'p.criado_em';
$ordem  = $ordens[strtolower($_GET['ordem'] ?? 'desc')] ?? 'DESC';

// O marcador declara a exceção. O scanner exige que TODA interpolação em SQL seja
// justificada por escrito: na própria linha ou na linha imediatamente acima, e o
// revisor lê a allowlist citada ao lado do código.
$sql = "SELECT * FROM pedidos p ORDER BY {$coluna} {$ordem} LIMIT :limite";  // scan-sql:allow: $colunas/$ordens
```

Se um valor do usuário aparece dentro de aspas duplas em uma string SQL, o código está
errado: mesmo que "funcione". Detalhes, casos de `LIKE`, `IN (...)`, transações, e o
equivalente em Next.js: [sql-e-acesso-a-dados.md](references/sql-e-acesso-a-dados.md).

Verificação mecânica, antes de cada push:

```bash
bash skills/development-pattern-for-web-apps/assets/scripts/scan-sql-injection.sh
```

---

## Antialucinação: os quatro movimentos

**1. Verifique, não lembre.** Antes de escrever `str_contains()`, confirme a versão mínima
de PHP do projeto. Antes de escrever uma classe do Tailwind, confirme que ela existe na
versão instalada. Tailwind v3 e v4 diferem.

```bash
php -v && php -m                                   # versão e extensões realmente disponíveis
grep -m1 '"tailwindcss"' package.json              # versão instalada, não a que você lembra
ls node_modules/next/dist/                          # a API que existe neste projeto
composer show                                       # o que está de fato no vendor/
```

**2. Diga "não sei" em voz alta.** Se a documentação está inacessível e o pacote não está
instalado, a saída honesta é: *"não consigo verificar `X`, instale o pacote ou me passe a
página da doc, e eu verifico."* Uma prop inventada que falha em silêncio é pior que uma
pergunta.

**3. Cite o que leu.** Cada spec carrega um registro de evidências: URL ou caminho de
arquivo, e a linha que ele justifica. Afirmação sem fonte no registro não entra na spec.

**4. Prefira a menor API confirmada.** Entre duas formas plausíveis, use a que o código
instalado prova, mesmo que a outra pareça mais elegante.

---

## Modos de falha que esta skill existe para evitar

| Sintoma | Causa raiz | Regra |
| --- | --- | --- |
| Banco vazado, registros apagados, login burlado com `' OR '1'='1` | Dado do usuário concatenado em SQL | R5 |
| Credencial do MySQL da Hostinger no histórico do GitHub | Config versionada em vez de ignorada | R1 |
| Projeto pessoal virou público por engano, com `.env` dentro | Repositório criado sem `--private` | R2 |
| `<script>` do usuário executando no painel admin | Saída impressa sem escapar | R6 |
| Formulário de exclusão disparado por um site de terceiros | Sem token CSRF | R7 |
| Usuário A abre `/pedido?id=8` e vê o pedido do usuário B | Sem verificação de autorização por registro | R7 |
| Senhas em MD5, ou em texto plano | `password_hash` não usado | R7 |
| Deploy na Hostinger quebra porque falta a extensão `intl` | Sem verificação de dependências na instalação | R9 |
| Atualização subiu os arquivos mas não rodou o SQL: telas em branco | Migração fora do pacote, ou executada fora de ordem | R10 |
| Bug corrigido volta três versões depois | Sem suíte de regressão que cresce | R11 |
| "Testei e está tudo funcionando", e não estava | Teste manual sem roteiro, sem resultado esperado escrito | R11 |
| Três deploys e todos reportando `1.0.0` | Versão não subiu por publicação | R13 |
| Ninguém sabe qual migração já rodou naquele banco | Versão do schema não gravada na base | R13 |
| Deploy derrubou o site e não há caminho de volta | Sem backup e sem rollback documentado | R14 |
| Cinco commits de "tenta assim" até o build passar | Correção sem reprodução local | R16 |
| Build verde com `ignoreBuildErrors`, e o erro de tipo estourando em produção | Amputação em vez de correção | R16 |
| Funciona em produção e quebra no preview | Variável de ambiente que só existe num dos dois | R16 |
| O texto da tela parece gerado por IA e o usuário desconfia do produto | Travessão e muletas genéricas | R17 |
| O histórico do seu projeto pessoal credita uma ferramenta como coautora | Trailer automático não desligado | R18 |
| README descreve o app de duas versões atrás, e alguém acredita nele | Documentação deixada para depois do commit | R13 |
| App bancário dizendo "Ops, algo deu errado" depois de uma transferência | Linguagem sem pesquisa do domínio | R17 |
| Formulário de ITSM chamando pedido de acesso de "problema" | Vocabulário canônico do setor ignorado | R17 |
| A URL entrega a linguagem, a pasta e o nome do arquivo do servidor | Caminho de arquivo servido como rota | R15 |
| Todo link publicado quebrou ao reorganizar as pastas | URL acoplada à estrutura em disco | R15 |
| `Property 'xyz' does not exist` depois de "deveria funcionar" | Prop inventada de memória | R4 |

---

## Falando com o usuário

- Reporte o que **verificou**, não o que assumiu. "Confirmado em `composer.json`: PHP ^8.2"
  vale mais que "deve funcionar".
- Antes de qualquer push, mostre o **diff de sanitização**: o que virou placeholder.
- Antes de qualquer push, diga a **versão** e quais documentos foram atualizados com ela.
- Antes de qualquer deploy, **nomeie o alvo** (domínio, projeto Vercel, banco) e espere o sim.
- Ao entregar uma aplicação, entregue junto o **roteiro de testes** e diga quantos casos ele
  cobre e quais requisitos ficaram sem cobertura.
- Quando recusar um chute, ofereça o passo concreto que destravaria.
- Resultados de teste são reportados como aconteceram. "12 passaram, 2 falharam, aqui estão"
  , nunca "está tudo funcionando".
