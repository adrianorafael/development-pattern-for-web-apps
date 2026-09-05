# SQL e acesso a dados — o dado nunca vira comando

> Regra **R5**. É a falha mais grave que um projeto pessoal pode cometer, porque as
> consequências não são suas: são dos usuários cujos dados estavam no banco.
> Um XSS afeta uma sessão. Um SQL injection afeta a base inteira.

---

## 1. O modelo mental correto

Um comando SQL tem duas partes que **nunca** devem se misturar:

| Parte | O que é | De onde pode vir |
| --- | --- | --- |
| **Estrutura** | `SELECT`, nomes de tabela e coluna, `JOIN`, `ORDER BY`, `ASC`/`DESC` | Só do seu código, ou de uma **allowlist** que o seu código controla |
| **Dado** | valores comparados, inseridos, atualizados | Do usuário — e sempre por **parâmetro vinculado** |

Toda vulnerabilidade de SQL injection é a mesma história: um dado atravessou para o lado da
estrutura. A defesa não é "escapar melhor". É **nunca deixar atravessar**.

`mysqli_real_escape_string()` e `addslashes()` **não são a defesa**. São remendos que
falham em contexto numérico, em `LIKE`, com charsets multibyte e quando alguém esquece de
chamá-los uma vez. Prepared statements não falham nesses casos porque o dado nunca é
interpretado como SQL.

---

## 2. PHP + MySQL — a configuração obrigatória do PDO

Uma única fábrica de conexão, no projeto inteiro. Copie de
[`../assets/templates/Database.php.template`](../assets/templates/Database.php.template).

```php
$dsn = sprintf('mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4', $host, $port, $nome);

$pdo = new PDO($dsn, $usuario, $senha, [
    // Erro vira exceção. Sem isso, uma query que falha retorna false e o código segue
    // adiante com dados errados — silenciosamente.
    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,

    // Arrays associativos. Evita o hábito de acessar colunas por índice numérico.
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,

    // ⚠️ O ITEM CRÍTICO. Com emulação ligada (padrão do PDO!), o PHP monta a query
    // interpolando os parâmetros ele mesmo, e volta a existir uma superfície de injeção
    // em cenários de charset. Desligado, quem separa estrutura de dado é o MySQL.
    PDO::ATTR_EMULATE_PREPARES   => false,

    // Sem múltiplos comandos em uma chamada. Fecha a porta do `; DROP TABLE`.
    PDO::MYSQL_ATTR_MULTI_STATEMENTS => false,
]);
```

Verifique que ficou como você acha que ficou:

```bash
php -r '$p=require "config/bootstrap.php"; var_dump($p->getAttribute(PDO::ATTR_EMULATE_PREPARES));'
# deve imprimir bool(false)
```

**`mysqli` também serve**, se o projeto já usa. A obrigação é a mesma: `prepare()` +
`bind_param()`, nunca `query()` com string montada. `mysqli_report(MYSQLI_REPORT_ERROR |
MYSQLI_REPORT_STRICT)` é o equivalente do `ERRMODE_EXCEPTION`.

---

## 3. As formas corretas, caso a caso

### Consulta simples

```php
$stmt = $pdo->prepare('SELECT id, nome, email FROM usuarios WHERE id = :id');
$stmt->execute([':id' => $id]);
$usuario = $stmt->fetch();
```

### Inserção

```php
$stmt = $pdo->prepare(
    'INSERT INTO chamados (titulo, descricao, usuario_id, criado_em)
     VALUES (:titulo, :descricao, :usuario_id, NOW())'
);
$stmt->execute([
    ':titulo'     => $titulo,
    ':descricao'  => $descricao,
    ':usuario_id' => $usuarioId,
]);
$novoId = (int) $pdo->lastInsertId();
```

### `LIKE` — o caractere curinga também é entrada

O `%` e o `_` do usuário viram curingas. Isso não derruba o banco, mas transforma
`buscar("a_b")` em uma varredura completa e permite enumeração. Escape-os **no valor**,
depois vincule normalmente:

```php
$termo = str_replace(['\\', '%', '_'], ['\\\\', '\\%', '\\_'], $busca);
$stmt  = $pdo->prepare("SELECT id, nome FROM produtos WHERE nome LIKE :termo LIMIT 50");
$stmt->execute([':termo' => '%' . $termo . '%']);
```

### `IN (...)` — placeholders gerados, valores vinculados

O erro clássico é `implode(',', $ids)`. A forma correta gera **placeholders**, não valores:

```php
$ids = array_values(array_filter(array_map('intval', $idsRecebidos)));
if ($ids === []) { return []; }

$marcadores = implode(',', array_fill(0, count($ids), '?'));
$stmt = $pdo->prepare("SELECT id, nome FROM produtos WHERE id IN ($marcadores)");
$stmt->execute($ids);
```

O `$marcadores` só contém `?,?,?` — nada do usuário chega ao texto da query.

### `ORDER BY` dinâmico e paginação — allowlist, sempre

```php
// O que o usuário manda é uma CHAVE do mapa. Se não estiver no mapa, cai no padrão.
const COLUNAS_ORDENAVEIS = [
    'nome'  => 'p.nome',
    'data'  => 'p.criado_em',
    'valor' => 'p.total',
];
const DIRECOES = ['asc' => 'ASC', 'desc' => 'DESC'];

$coluna = COLUNAS_ORDENAVEIS[$_GET['ordenar'] ?? ''] ?? 'p.criado_em';
$dir    = DIRECOES[strtolower((string)($_GET['dir'] ?? ''))] ?? 'DESC';

// LIMIT/OFFSET: force para inteiro e limite o teto. Com EMULATE_PREPARES=false,
// vincule como PDO::PARAM_INT — MySQL não aceita string aqui.
$porPagina = min(100, max(1, (int)($_GET['por_pagina'] ?? 20)));
$offset    = max(0, ((int)($_GET['pagina'] ?? 1) - 1) * $porPagina);

// scan-sql:allow — $coluna e $dir vêm de COLUNAS_ORDENAVEIS/DIRECOES, não da entrada
$stmt = $pdo->prepare("SELECT * FROM pedidos p ORDER BY $coluna $dir LIMIT :lim OFFSET :off");
$stmt->bindValue(':lim', $porPagina, PDO::PARAM_INT);
$stmt->bindValue(':off', $offset,    PDO::PARAM_INT);
$stmt->execute();
```

### Filtros opcionais — condições e parâmetros crescem juntos

```php
$where  = ['1=1'];
$params = [];

if ($status !== null) { $where[] = 'status = :status';   $params[':status'] = $status; }
if ($de     !== null) { $where[] = 'criado_em >= :de';   $params[':de']     = $de; }
if ($ate    !== null) { $where[] = 'criado_em <= :ate';  $params[':ate']    = $ate; }

$sql  = 'SELECT * FROM chamados WHERE ' . implode(' AND ', $where) . ' ORDER BY criado_em DESC';
$stmt = $pdo->prepare($sql);
$stmt->execute($params);
```

Note: só **fragmentos escritos por você** entram em `$where`. Nada de `$where[] = $filtro`.

### Transações — tudo ou nada

```php
$pdo->beginTransaction();
try {
    $stmt = $pdo->prepare('UPDATE contas SET saldo = saldo - :v WHERE id = :de');
    $stmt->execute([':v' => $valor, ':de' => $de]);

    $stmt = $pdo->prepare('UPDATE contas SET saldo = saldo + :v WHERE id = :para');
    $stmt->execute([':v' => $valor, ':para' => $para]);

    $pdo->commit();
} catch (Throwable $e) {
    $pdo->rollBack();
    throw $e;         // registre no log; NUNCA mostre a mensagem crua ao usuário
}
```

---

## 4. Next.js — o mesmo princípio, sintaxe diferente

Toda consulta roda **no servidor** (Server Component, Route Handler ou Server Action).
Nenhuma credencial de banco, nenhuma query, nenhum resultado bruto atravessa para o cliente.

### `postgres`/`@neondatabase/serverless` — template tag parametrizada

```ts
import { sql } from '@/lib/db';           // ver assets/templates/db.ts.template

// ✅ A template tag transforma ${} em parâmetro vinculado ($1, $2…), não em texto.
const usuarios = await sql`SELECT id, nome FROM usuarios WHERE email = ${email}`;
```

```ts
// ❌ Isto é concatenação disfarçada de template. Vira texto na query.
const q = `SELECT * FROM usuarios WHERE email = '${email}'`;
await sql.unsafe(q);
await pool.query(q);
```

A diferença é sutil e fatal: `sql\`...${x}...\`` parametriza; `sql(\`...${x}...\`)` e
`pool.query(\`...${x}...\`)` concatenam. Qualquer método chamado `unsafe`, `raw` ou
`queryRaw` com string interpolada é uma violação de R5.

### `mysql2` — placeholders `?`

```ts
const [linhas] = await pool.execute(
  'SELECT id, nome FROM usuarios WHERE email = ? AND ativo = ?',
  [email, 1]
);
```

`connection.query()` com string montada é proibido; `execute()` com array de valores é a
forma. Identificadores continuam vindo de allowlist — `pool.escapeId()` só é aceitável
sobre um valor **já validado contra a allowlist**, nunca sobre entrada crua.

### Prisma / Drizzle

O query builder já parametriza. As duas fugas a vigiar:

```ts
await prisma.$queryRawUnsafe(`SELECT * FROM users WHERE id = ${id}`);   // ❌
await prisma.$queryRaw`SELECT * FROM users WHERE id = ${id}`;           // ✅ parametrizado
```

`sql.raw()` do Drizzle tem exatamente a mesma pegadinha.

---

## 5. Menos privilégio no próprio banco

O usuário MySQL da aplicação **não é** o usuário que instalou o app.

| Usuário | Quando é usado | Permissões |
| --- | --- | --- |
| Instalação (wizard/migrações) | Só durante instalar e atualizar | `CREATE`, `ALTER`, `DROP`, `INDEX` no banco do app |
| Aplicação (runtime) | Toda requisição normal | `SELECT`, `INSERT`, `UPDATE`, `DELETE` — e nada mais |

Em shared hosting como a Hostinger nem sempre dá para ter dois usuários. Quando não der,
**diga isso ao usuário** em vez de fingir que o modelo foi seguido, e compense: nenhuma
funcionalidade de runtime pode emitir DDL.

```sql
-- Quando o painel permitir criar dois usuários:
GRANT SELECT, INSERT, UPDATE, DELETE ON `app_db`.* TO 'app_runtime'@'localhost';
```

Nunca use `root`. Nunca reutilize a mesma senha entre projetos.

---

## 6. Convenções de schema deste padrão

```sql
CREATE TABLE chamados (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  titulo       VARCHAR(200)    NOT NULL,
  descricao    TEXT            NULL,
  usuario_id   BIGINT UNSIGNED NOT NULL,
  status       ENUM('aberto','andamento','fechado') NOT NULL DEFAULT 'aberto',
  criado_em    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_chamados_usuario (usuario_id),
  KEY idx_chamados_status_data (status, criado_em),
  CONSTRAINT fk_chamados_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

- **`utf8mb4`, sempre.** `utf8` no MySQL é de três bytes e quebra emoji — e charset
  inconsistente já foi vetor de injeção.
- **InnoDB**, para ter transação e chave estrangeira.
- **Chave estrangeira declarada**, não "garantida pela aplicação".
- **Índice em toda coluna usada em `WHERE`, `JOIN` ou `ORDER BY`.** Sem isso, a listagem
  fica rápida com 200 registros e inutilizável com 200 mil.
- **`DECIMAL(10,2)` para dinheiro**, jamais `FLOAT`.
- **Datas em `DATETIME`** com fuso definido na aplicação, ou `TIMESTAMP` se você quer
  conversão automática — escolha um e documente na spec.
- **Nada de `SELECT *` em código de produção.** Liste as colunas: assim uma coluna nova
  não vaza para uma tela, e o índice de cobertura funciona.

---

## 7. Tratamento de erro que não vaza estrutura

```php
try {
    $stmt->execute($params);
} catch (PDOException $e) {
    error_log('[DB] ' . $e->getMessage());          // detalhe vai para o log
    http_response_code(500);
    exibirErro('Não foi possível concluir a operação.');   // usuário vê isso
    return;
}
```

Mensagem de erro do MySQL na tela entrega nome de tabela, nome de coluna e às vezes o SQL
inteiro — é reconhecimento gratuito para quem está sondando. Em produção:
`display_errors = Off`, `log_errors = On`.

---

## 8. A única interpolação aceita — e como declará-la

Identificador (coluna, tabela, `ASC`/`DESC`) não pode ser parametrizado: é limitação do
protocolo, não escolha de estilo. A allowlist é a defesa, e o scanner **exige que ela seja
declarada na própria linha**:

```php
$coluna = COLUNAS_ORDENAVEIS[$_GET['ordenar'] ?? ''] ?? 'p.criado_em';
$sql = "SELECT * FROM pedidos p ORDER BY $coluna";   // scan-sql:allow — COLUNAS_ORDENAVEIS
```

O marcador vale na própria linha **ou na linha imediatamente acima** — é ali que cabe
escrever a justificativa por extenso:

```php
// $tabela sai de TABELAS_DO_APP (allowlist) e as crases internas são escapadas.
// scan-sql:allow — $prefixo foi sanitizado com preg_replace('/[^a-z0-9_]/i','') na instalação.
$pdo->exec("DROP TABLE IF EXISTS `{$prefixo}{$tabela}`");
```

Sem o marcador, `scan-sql-injection.sh` acusa a linha e o commit para. Isso é intencional:
**toda** interpolação em SQL passa a exigir uma justificativa escrita que o revisor lê ao
lado do código. Uma linha com o marcador e sem allowlist real é uma mentira visível em
revisão — o que é muito melhor do que uma concatenação silenciosa.

Antes de escrever o marcador, responda: *este valor pode ser qualquer coisa que o usuário
digitar?* Se puder, não é allowlist — é injeção, e o marcador não conserta.

### As três interpolações legítimas, e só elas

| Caso | Por que é seguro | Condição |
| --- | --- | --- |
| Coluna / tabela / `ASC`\|`DESC` dinâmicos | O valor do usuário é uma **chave** de um mapa do seu código | O mapa é constante e tem valor padrão |
| **Prefixo de tabelas** (bases compartilhadas) | Vem da configuração, não da requisição | Sanitizado no ponto de entrada: `preg_replace('/[^a-z0-9_]/i', '', $prefixo)` |
| Geração de **dump** de backup | A saída é um arquivo, não um comando executado | Nomes vindos de `SHOW TABLES`, crases escapadas, valores por `PDO::quote()` |

Qualquer outro caso é concatenação, e concatenação é injeção esperando acontecer.

---

## 9. Checklist antes do push

```bash
bash skills/development-pattern-for-web-apps/assets/scripts/scan-sql-injection.sh
```

- [ ] Nenhuma variável dentro de string SQL — nem `"... $x ..."`, nem `'...' . $x . '...'`,
      nem `` `...${x}...` `` fora de template tag parametrizada.
- [ ] `ATTR_EMULATE_PREPARES => false` na fábrica de conexão.
- [ ] `ATTR_ERRMODE => ERRMODE_EXCEPTION`.
- [ ] Toda coluna/tabela/direção dinâmica vem de allowlist, com valor padrão, e a linha
      carrega o marcador `scan-sql:allow` citando de qual allowlist ela veio.
- [ ] `LIMIT`/`OFFSET` convertidos para `int` e com teto.
- [ ] `LIKE` com `%` e `_` escapados no valor.
- [ ] `IN (...)` com placeholders gerados por `array_fill`, não com valores.
- [ ] Nenhum `queryRaw`, `$queryRawUnsafe`, `sql.unsafe`, `sql.raw` com interpolação.
- [ ] Usuário do banco sem `DROP`/`ALTER` em runtime (ou limitação documentada).
- [ ] Erros de banco registrados no log, nunca exibidos.
- [ ] Casos de teste de injeção existem no roteiro de QA (R11) para **cada** campo que
      chega ao banco. → [roteiro-de-testes-cowork.md](roteiro-de-testes-cowork.md)
