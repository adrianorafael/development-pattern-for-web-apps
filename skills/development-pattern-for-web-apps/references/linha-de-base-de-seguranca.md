# Linha de base de segurança: o piso não negocia, o teto sim

> Regra **R7**. Existe um conjunto de defesas que vale para **todo** projeto, inclusive o
> de fim de semana com três usuários. O que varia com o porte é o que se **acrescenta**
> acima desse piso, nunca o que se remove dele.

"É só um projeto pessoal" é o raciocínio que precede a maioria dos vazamentos de projeto
pessoal. O invasor não sabe que é pessoal: ele varre faixas inteiras de IP procurando
`/wp-admin`, `/install.php` e formulários de login. O custo do piso é de horas; o custo de
não tê-lo é o dado de outras pessoas.

---

## 1. O piso: obrigatório em qualquer projeto

| # | Defesa | Verificação |
| --- | --- | --- |
| **P1** | SQL parametrizado em 100% das consultas | `scan-sql-injection.sh` limpo (R5) |
| **P2** | Nenhum segredo em arquivo versionado | `scan-secrets.sh` limpo (R1) |
| **P3** | Senha com `password_hash()` / bcrypt ou Argon2id | Nenhum `md5`/`sha1` sobre senha no código |
| **P4** | Token CSRF em toda ação que muda estado | Toda rota `POST` confere token (R6) |
| **P5** | Toda saída escapada no contexto certo | Nenhum eco sem `e()` (R6) |
| **P6** | Cookie de sessão `HttpOnly`, `Secure`, `SameSite=Lax` | `session_set_cookie_params` conferido |
| **P7** | HTTPS obrigatório, com redirecionamento de HTTP | `curl -I http://…` responde 301 |
| **P8** | Cabeçalhos de segurança enviados | `curl -I https://…` mostra os cinco |
| **P9** | Autorização conferida em **toda** requisição, por registro | Nenhuma rota confia só no ID da URL |
| **P10** | Erros logados, nunca exibidos | `display_errors=Off` em produção |
| **P11** | Upload restrito e sem execução | Regras de [entrada-e-saida-seguras.md](entrada-e-saida-seguras.md) §5 |
| **P12** | Dependências auditadas antes de publicar | `composer audit` / `npm audit` sem crítico |

Doze itens. Se algum não puder ser cumprido, **diga qual e por quê**, não entregue como se
estivesse.

---

## 2. Acima do piso: proporcional ao porte

Determine o nível na Fase 0, pelas respostas sobre dados e usuários, e registre-o na spec.

| Nível | Quando | Acrescenta ao piso |
| --- | --- | --- |
| **N1. Vitrine** | Site estático, formulário de contato, sem login, sem dado pessoal | reCAPTCHA/honeypot no formulário; rate limit simples; e-mail sem injeção de cabeçalho |
| **N2. App com login** | Área logada, dados dos próprios usuários | Bloqueio progressivo por tentativas; recuperação de senha com token de uso único e expiração; log de auditoria de ações sensíveis; sessão regenerada no login; expiração por inatividade |
| **N3. Dados de terceiros / LGPD** | Cadastro de clientes, CPF, endereço, saúde, financeiro | Tudo de N2 + criptografia de campos sensíveis em repouso; política de retenção e exclusão; exportação de dados do titular; backup criptografado e testado; registro de acesso a dado pessoal; segunda pessoa revisa mudanças na autenticação |
| **N4. Pagamento / dinheiro** | Checkout, assinatura, saldo | Tudo de N3 + nenhum dado de cartão tocando seu servidor (redirect/iframe do provedor); webhooks com assinatura verificada; idempotência em toda operação financeira; conciliação; MFA no painel administrativo |

Regra de escada: **você pode subir de nível, nunca descer.** Um app que começou N2 e passou
a guardar CPF virou N3 no mesmo commit em que a coluna foi criada.

---

## 3. Autenticação: as formas corretas

### Senha

```php
// Cadastro / troca: o custo padrão é reavaliado a cada versão do PHP; não fixe um valor baixo
$hash = password_hash($senha, PASSWORD_DEFAULT);

// Login
$stmt = $pdo->prepare('SELECT id, senha_hash, ativo FROM usuarios WHERE email = :e');
$stmt->execute([':e' => $email]);
$u = $stmt->fetch();

// Compare SEMPRE, mesmo sem usuário: sem isso, o tempo de resposta revela quem existe
$hashRef = $u['senha_hash'] ?? '$2y$12$invalidoinvalidoinvalidoinvalidoinvalidoinvalidoinvalid';
$ok = password_verify($senha, $hashRef) && $u && $u['ativo'];

if (!$ok) {
    registrarTentativa($email, $ip);
    dormirAleatorio();                       // 100 a 300 ms
    erro('E-mail ou senha inválidos.');      // MESMA mensagem para os dois casos
}

// Rehash quando o custo padrão mudar
if (password_needs_rehash($u['senha_hash'], PASSWORD_DEFAULT)) {
    $stmt = $pdo->prepare('UPDATE usuarios SET senha_hash = :h WHERE id = :id');
    $stmt->execute([':h' => password_hash($senha, PASSWORD_DEFAULT), ':id' => $u['id']]);
}
```

Nunca diga "e-mail não cadastrado" nem "senha incorreta": as duas mensagens juntas são um
enumerador de usuários. Uma mensagem só, para os dois casos.

Política mínima: 10 caracteres, sem regra de "um símbolo e uma maiúscula" (empurra para
`Senha@123`), e rejeição de senhas notoriamente vazadas se houver como checar.

### Sessão em PHP

```php
session_set_cookie_params([
    'lifetime' => 0,
    'path'     => '/',
    'domain'   => '',
    'secure'   => true,        // só HTTPS
    'httponly' => true,        // JavaScript não lê
    'samesite' => 'Lax',       // reduz CSRF
]);
session_name('APPSESS');       // não anuncie "PHPSESSID"
session_start();

// No login bem-sucedido: impede fixação de sessão
session_regenerate_id(true);
$_SESSION['usuario_id'] = $u['id'];
$_SESSION['criada_em']  = time();

// Expiração por inatividade
if (isset($_SESSION['ultimo_acesso']) && time() - $_SESSION['ultimo_acesso'] > 1800) {
    session_unset(); session_destroy(); redirecionarLogin('Sessão expirada.');
}
$_SESSION['ultimo_acesso'] = time();
```

### Recuperação de senha

Token aleatório de 32 bytes, **guardado com hash** (o banco não guarda o token em claro),
uso único, expiração de 30 a 60 minutos, invalidação de todas as sessões ao trocar a senha.
A resposta ao pedido é sempre a mesma: "se o e-mail existir, enviamos o link", para não
enumerar usuários.

### Bloqueio progressivo

```sql
CREATE TABLE tentativas_login (
  id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  email      VARCHAR(190) NOT NULL,
  ip         VARBINARY(16) NOT NULL,
  sucesso    TINYINT(1) NOT NULL DEFAULT 0,
  criado_em  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_tentativas (email, criado_em),
  KEY idx_tentativas_ip (ip, criado_em)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

5 falhas em 15 minutos para o mesmo e-mail → atraso crescente ou captcha.
20 falhas do mesmo IP → bloqueio temporário. Conte por e-mail **e** por IP: só por e-mail
permite *password spraying*; só por IP, botnet.

---

## 4. Autorização: o erro mais comum de todos

Autenticação responde "quem é você". Autorização responde "você pode ver **este** registro".
Confundir as duas é o defeito mais frequente em app pessoal:

```php
// ❌ O usuário está logado. E daí? O pedido pode ser de outra pessoa.
$stmt = $pdo->prepare('SELECT * FROM pedidos WHERE id = :id');
$stmt->execute([':id' => $_GET['id']]);

// ✅ O dono faz parte da consulta, não de um if depois
$stmt = $pdo->prepare('SELECT * FROM pedidos WHERE id = :id AND usuario_id = :u');
$stmt->execute([':id' => $id, ':u' => $_SESSION['usuario_id']]);
$pedido = $stmt->fetch();
if (!$pedido) { http_response_code(404); exit; }   // 404, não 403: não confirme que existe
```

Regra: **o dono entra na cláusula `WHERE`**, não num `if` posterior. E toda rota
administrativa confere o papel antes de qualquer efeito:

```php
function exigirPapel(string ...$papeis): void {
    $atual = $_SESSION['papel'] ?? null;
    if ($atual === null || !in_array($atual, $papeis, true)) {
        http_response_code(403); exit('Acesso negado.');
    }
}
```

No Next.js, a verificação vive **dentro** de cada Server Action e Route Handler. Middleware
é conveniência de roteamento, não fronteira de segurança: ele pode ser contornado por
chamada direta ao endpoint da action.

---

## 5. Cabeçalhos de segurança

```apache
# .htaccess para Hostinger/Apache
<IfModule mod_headers.c>
  Header always set X-Content-Type-Options "nosniff"
  Header always set X-Frame-Options "SAMEORIGIN"
  Header always set Referrer-Policy "strict-origin-when-cross-origin"
  Header always set Permissions-Policy "geolocation=(), microphone=(), camera=()"
  Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
  Header always set Content-Security-Policy "default-src 'self'; img-src 'self' data:; style-src 'self'; script-src 'self'; form-action 'self'; frame-ancestors 'self'; base-uri 'self'"
</IfModule>
```

```ts
// next.config.ts
const headers = [
  { key: 'X-Content-Type-Options',   value: 'nosniff' },
  { key: 'X-Frame-Options',          value: 'SAMEORIGIN' },
  { key: 'Referrer-Policy',          value: 'strict-origin-when-cross-origin' },
  { key: 'Permissions-Policy',       value: 'geolocation=(), microphone=(), camera=()' },
  { key: 'Strict-Transport-Security',value: 'max-age=31536000; includeSubDomains' },
];
export default { async headers() { return [{ source: '/:path*', headers }]; } };
```

**CSP quebra as coisas antes de proteger.** Suba primeiro em `Content-Security-Policy-Report-Only`,
veja o que reclama no console, ajuste, e só então torne obrigatória. `'unsafe-inline'` em
`script-src` anula a maior parte do benefício: se o projeto precisa dele, registre isso na
spec como débito técnico consciente.

Confira o resultado real, não a intenção:

```bash
curl -sI https://seu-dominio.com.br | grep -iE 'content-security|x-frame|x-content|strict-transport|referrer'
```

---

## 6. Rate limiting

Toda rota que envia e-mail, autentica, registra usuário ou consulta API paga precisa de
limite. Em PHP sem Redis, uma tabela resolve:

```php
function permitir(PDO $pdo, string $chave, int $max, int $janelaSeg): bool {
    $stmt = $pdo->prepare(
        'SELECT COUNT(*) FROM eventos_limite
         WHERE chave = :c AND criado_em > (NOW() - INTERVAL :j SECOND)'
    );
    $stmt->bindValue(':c', $chave);
    $stmt->bindValue(':j', $janelaSeg, PDO::PARAM_INT);
    $stmt->execute();
    if ((int)$stmt->fetchColumn() >= $max) { return false; }

    $pdo->prepare('INSERT INTO eventos_limite (chave, criado_em) VALUES (:c, NOW())')
        ->execute([':c' => $chave]);
    return true;
}
```

Limpe a tabela por cron. Na Vercel, use o rate limit do provedor ou um KV: o modelo
serverless não guarda estado entre invocações.

---

## 7. Dependências

```bash
composer audit                 # PHP
npm audit --omit=dev           # Next.js
npm outdated
```

Antes de **toda** publicação. Vulnerabilidade crítica em dependência direta bloqueia o
release; em dependência transitiva, registre no CHANGELOG se não houver correção.

Menos dependência é menos superfície. Uma biblioteca de 40 KB para formatar data não vale o
risco de cadeia de suprimentos em um projeto pessoal.

---

## 8. Registro e observabilidade mínima

Registre, com data, IP e usuário: login (sucesso e falha), troca de senha, mudança de
permissão, exclusão de registro, instalação de pacote de atualização, execução de migração.

Nunca registre: senha, token de sessão, número de cartão, corpo inteiro de requisição com
dado pessoal.

Em produção: `display_errors=Off`, `log_errors=On`, `error_log` fora do webroot. Uma página
de erro 500 que mostra stack trace entrega caminho de arquivo, versão de framework e às
vezes a query: reconhecimento gratuito.

---

## 9. Checklist de segurança antes de publicar

- [ ] Os doze itens do piso, verificados um a um
- [ ] Nível (N1 a N4) declarado na spec e os itens dele implementados
- [ ] `composer audit` / `npm audit` sem vulnerabilidade crítica
- [ ] Cabeçalhos conferidos com `curl -I` no ambiente real
- [ ] HTTPS forçado; certificado válido
- [ ] Página de erro genérica; `display_errors` desligado
- [ ] Rate limit nas rotas de login, cadastro e envio de e-mail
- [ ] Autorização por registro conferida em cada rota que lê ou grava
- [ ] Wizard de instalação trancado após o uso (R9)
- [ ] Painel administrativo exige autenticação e papel (R10)
- [ ] Casos de teste de segurança presentes no roteiro de QA (R11)
