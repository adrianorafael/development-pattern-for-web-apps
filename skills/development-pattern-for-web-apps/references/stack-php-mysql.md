# Stack PHP + MySQL na Hostinger

> Regra **R8** (metade PHP): front controller e partials. Zero cabeçalho copiado e colado,
> zero HTML montado por concatenação de string.

Hospedagem compartilhada impõe restrições reais, sem root, sem systemd, muitas vezes sem
Composer no servidor, PHP definido pelo painel. O projeto é desenhado **para** essas
restrições, não apesar delas.

---

## 1. Layout do projeto

O ideal, quando há acesso acima do `public_html`:

```
/home/usuario/
├── config/
│   └── app.config.php          # credenciais. FORA do webroot, gerado pelo Wizard
├── storage/
│   ├── uploads/                # arquivos enviados: fora do webroot
│   ├── backups/                # dumps antes de atualizar
│   └── logs/
└── public_html/                # ← a raiz do domínio
    ├── index.php               # front controller: o ÚNICO ponto de entrada
    ├── .htaccess               # rewrite + cabeçalhos + bloqueios
    ├── assets/{css,js,img}/
    ├── install/                # Wizard (R9): removido/trancado após instalar
    ├── admin/                  # painel administrativo (R10)
    └── app/
        ├── bootstrap.php       # carrega config, sessão, autoload, conexão
        ├── Core/               # Database, Router, Request, Response, Csrf, Auth
        ├── Controllers/
        ├── Models/             # uma classe por tabela/agregado
        ├── Views/
        │   ├── layouts/{principal.php,admin.php}
        │   ├── partials/{cabecalho.php,rodape.php,menu.php,alertas.php}
        │   └── chamados/{lista.php,form.php,detalhe.php}
        └── Helpers/            # e(), url(), formatarData()…
```

Quando **não** houver acesso acima do `public_html` (planos mais simples), tudo fica dentro,
e a proteção passa a ser o `.htaccess`: `config/`, `storage/` e `app/` com
`Require all denied`. Teste no navegador que respondem 403: a suposição não basta.

```
projeto/
├── public/            ← aponte o domínio para cá no hPanel, se o painel permitir
└── (o resto fora)     ← preferível sempre que possível
```

---

## 2. Front controller e roteamento

```apache
# public_html/.htaccess
RewriteEngine On

# HTTPS obrigatório
RewriteCond %{HTTPS} !=on
RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]

# Arquivos e diretórios reais são servidos direto; o resto vai para o front controller
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^ index.php [QSA,L]

# Nada de listagem de diretório
Options -Indexes

# Bloqueio de arquivos sensíveis que por acaso caiam aqui
<FilesMatch "\.(env|ini|log|sql|sh|bak|md|lock|json|yml)$">
  Require all denied
</FilesMatch>
```

```php
// public_html/index.php: o único ponto de entrada
declare(strict_types=1);
require __DIR__ . '/app/bootstrap.php';

// URLs em português, kebab-case, sem extensão e sem estrutura de pastas (R15).
$rotas = [
    'GET  /'                          => [PaginaController::class,  'inicio'],
    'GET  /entrar'                    => [SessaoController::class,  'formularioLogin'],
    'POST /entrar'                    => [SessaoController::class,  'autenticar'],
    'GET  /cadastrar-novo-usuario'    => [UsuarioController::class, 'formulario'],
    'POST /cadastrar-novo-usuario'    => [UsuarioController::class, 'criar'],
    'GET  /chamados'                  => [ChamadoController::class, 'listar'],
    'GET  /abrir-chamado'             => [ChamadoController::class, 'formulario'],
    'POST /abrir-chamado'             => [ChamadoController::class, 'criar'],
    'GET  /chamados/{id}/{slug}'      => [ChamadoController::class, 'detalhe'],
    'POST /chamados/{id}/fechar'      => [ChamadoController::class, 'fechar'],
];

(new Router($rotas))->despachar($_SERVER['REQUEST_METHOD'], parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH));
```

**As rotas são um mapa escrito por você.** Nunca `include $_GET['pagina'] . '.php'`, isso é
inclusão remota de arquivo com outro nome.

O roteador completo (com `{id}`, canonicalização, 301 de rotas antigas e 404 de verdade), as
convenções de nomenclatura e a tabela de tradução de URLs antigas estão em
[rotas-e-urls.md](rotas-e-urls.md).

---

## 3. Views e partials: a metade PHP de R8

Nada de HTML dentro de controller. Nada de `echo '<div class="' . $x . '">'`.

```php
// app/Views/layouts/principal.php
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title><?= e($titulo ?? 'Chamados') ?></title>
  <link rel="stylesheet" href="/assets/css/app.css">
</head>
<body>
  <?php require __DIR__ . '/../partials/cabecalho.php'; ?>
  <?php require __DIR__ . '/../partials/alertas.php'; ?>
  <main class="conteudo"><?= $conteudo ?></main>
  <?php require __DIR__ . '/../partials/rodape.php'; ?>
</body>
</html>
```

```php
// app/Core/View.php
final class View {
    public static function render(string $view, array $dados = [], string $layout = 'principal'): string {
        extract($dados, EXTR_SKIP);
        ob_start();
        require __DIR__ . "/../Views/{$view}.php";     // $view vem do controller, nunca da URL
        $conteudo = ob_get_clean();
        ob_start();
        require __DIR__ . "/../Views/layouts/{$layout}.php";
        return ob_get_clean();
    }
}
```

Componentes reutilizáveis viram partials com parâmetros:

```php
// app/Views/partials/campo-texto.php , espera $nome, $rotulo, $valor, $erro
<div class="campo <?= $erro ? 'campo--erro' : '' ?>">
  <label for="<?= e($nome) ?>"><?= e($rotulo) ?></label>
  <input type="text" id="<?= e($nome) ?>" name="<?= e($nome) ?>"
         value="<?= e($valor ?? '') ?>" maxlength="200"
         <?= $erro ? 'aria-invalid="true" aria-describedby="' . e($nome) . '-erro"' : '' ?>>
  <?php if ($erro): ?>
    <p class="campo__erro" id="<?= e($nome) ?>-erro"><?= e($erro) ?></p>
  <?php endif; ?>
</div>
```

```php
<?php incluirParcial('campo-texto', ['nome' => 'titulo', 'rotulo' => 'Título',
                                     'valor' => $dados['titulo'] ?? '', 'erro' => $erros['titulo'] ?? null]); ?>
```

Regra prática: **se o mesmo bloco de HTML aparece duas vezes, ele vira partial.** Cabeçalho,
menu, paginação, alertas e campos de formulário são partials desde o primeiro dia.

---

## 4. Bootstrap

```php
// app/bootstrap.php
declare(strict_types=1);

define('BASE_PATH',    dirname(__DIR__, 2));         // ajuste conforme o layout escolhido
define('STORAGE_PATH', BASE_PATH . '/storage');

// Instalado? Se não, manda para o Wizard (R9)
$configPath = BASE_PATH . '/config/app.config.php';
if (!is_file($configPath)) {
    header('Location: /install/'); exit;
}
$config = require $configPath;

// Erros: log sempre, tela nunca (em produção)
error_reporting(E_ALL);
ini_set('display_errors', $config['debug'] ? '1' : '0');
ini_set('log_errors', '1');
ini_set('error_log', STORAGE_PATH . '/logs/php-error.log');

date_default_timezone_set($config['timezone'] ?? 'America/Sao_Paulo');
mb_internal_encoding('UTF-8');

require __DIR__ . '/Helpers/funcoes.php';
spl_autoload_register(function (string $classe): void {
    $arquivo = __DIR__ . '/' . str_replace('\\', '/', $classe) . '.php';
    if (is_file($arquivo)) { require $arquivo; }
});

session_set_cookie_params([
    'lifetime' => 0, 'path' => '/', 'secure' => true, 'httponly' => true, 'samesite' => 'Lax',
]);
session_name('APPSESS');
session_start();

$pdo = Database::conectar($config['db']);   // ver Database.php.template
```

Com Composer, troque o autoload manual por PSR-4 e `require vendor/autoload.php`. Se o
servidor não tiver Composer, rode `composer install --no-dev --optimize-autoloader`
localmente e **envie o `vendor/`** no pacote de deploy, mas nunca no repositório.

---

## 5. Realidades da Hostinger que mudam o projeto

Verifique cada uma antes de projetar em cima (R4):

| Item | Como verificar | Efeito no projeto |
| --- | --- | --- |
| Versão do PHP que serve o site | `<?php echo PHP_VERSION;` numa página real | Define a sintaxe disponível: o SSH pode reportar outra |
| Extensões | `<?php print_r(get_loaded_extensions());` | `zip` é requisito do updater (R10); `intl`, `gd`, `curl` conforme uso |
| `disable_functions` | `php -i \| grep disable_functions` | `exec`, `shell_exec`, `proc_open` costumam estar bloqueados, não dependa deles para backup |
| Limites de upload | `upload_max_filesize`, `post_max_size` | Teto real do pacote ZIP de atualização |
| `max_execution_time` | `php -i` | Migração longa precisa rodar em lotes |
| Escrita no disco | teste real de `file_put_contents` | O Wizard precisa gravar `config/` e o updater precisa gravar arquivos |
| Cron | hPanel → Cron Jobs | Resolução e disponibilidade variam por plano |
| `mod_rewrite` | testar uma URL amigável | Sem ele, o front controller precisa de `?rota=` |
| Acesso acima do `public_html` | `ls ..` no gerenciador de arquivos | Decide onde ficam config e storage |
| Versão do MySQL/MariaDB | `SELECT VERSION();` | Define CTE, funções de janela, `utf8mb4` padrão |

O Wizard de instalação (R9) checa isso automaticamente e mostra o resultado ao usuário:
essa é justamente a razão de ele existir. → [wizard-de-instalacao.md](wizard-de-instalacao.md)

---

## 6. Deploy

| Forma | Quando usar | Cuidado |
| --- | --- | --- |
| **Git na Hostinger** (hPanel → Git) | Melhor opção: versionado e reversível | O repositório é privado: configure a chave de deploy |
| **FTP/SFTP** | Sem Git no plano | Nunca versione `.ftpconfig`/`sftp.json` (R1) |
| **Upload de ZIP pelo gerenciador** | Envio pontual | Fácil esquecer arquivo; use só para o primeiro envio |
| **Painel de atualização do próprio app** (R10) | Atualizações rotineiras | O caminho preferido depois da primeira instalação |

**Nunca envie:** `.git/`, `.env`, `config/app.config.php`, `node_modules/`, `tests/`,
`specs/`, `qa/`. Sequência e rollback: [release-e-deploy.md](release-e-deploy.md).

---

## 7. Testes em PHP

```
tests/
├── Unit/            # regras de negócio puras, sem banco
├── Integration/     # com banco de teste real, em transação revertida
└── bootstrap.php
```

```php
// PHPUnit: cada teste em transação, revertida no final: a base fica limpa
protected function setUp(): void    { self::$pdo->beginTransaction(); }
protected function tearDown(): void { self::$pdo->rollBack(); }
```

Sem Composer no ambiente, no mínimo: `php -l` em todo arquivo, e um script de fumaça que
sobe as rotas principais com `curl` e confere o código HTTP. O roteiro de QA (R11) cobre o
resto.

---

## 8. Checklist de um projeto PHP deste padrão

- [ ] Um único ponto de entrada (`index.php`); rotas em mapa escrito à mão
- [ ] URLs semânticas em português, sem `.php` e sem estrutura de pastas (R15)
- [ ] `config/` e `storage/` fora do `public_html`, ou negados por `.htaccess` e testados
- [ ] `Database::conectar()` única, com `EMULATE_PREPARES => false` (R5)
- [ ] Nenhum HTML em controller; partials para tudo que repete (R8)
- [ ] `e()` em todo eco (R6)
- [ ] CSRF em todo `POST` (R6/R7)
- [ ] Wizard de instalação presente e trancável (R9)
- [ ] Painel administrativo com instalador de pacotes (R10)
- [ ] `.htaccess` com HTTPS, cabeçalhos, `Options -Indexes` e bloqueios
- [ ] Requisitos de ambiente documentados no README, e verificados pelo Wizard
- [ ] `qa/roteiro-de-testes.md` gerado (R11)
