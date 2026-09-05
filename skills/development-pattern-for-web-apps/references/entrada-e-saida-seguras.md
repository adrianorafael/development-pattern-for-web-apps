# Entrada e saída — validar na porta, escapar na pia

> Regra **R6**. Toda entrada é validada por allowlist na fronteira da aplicação.
> Toda saída é escapada no contexto exato em que vai parar.

Duas metades que resolvem problemas diferentes e não se substituem:

- **Validar na entrada** decide se o dado *entra*. Protege regra de negócio e integridade.
- **Escapar na saída** decide como o dado *sai*. Protege o interpretador do outro lado —
  o navegador, o SQL, o shell, o cabeçalho HTTP.

Escapar na entrada é um erro clássico: você grava `&amp;lt;` no banco, e o dado fica errado
para sempre. **Guarde o dado como o usuário digitou; escape na hora de renderizar.**

---

## 1. Toda entrada é entrada

| Fonte | Confiança |
| --- | --- |
| `$_GET`, `$_POST`, `$_COOKIE`, `$_FILES`, corpo JSON, `searchParams`, `formData` | Zero |
| Cabeçalhos HTTP — `User-Agent`, `Referer`, `X-Forwarded-For`, `Accept-Language` | Zero |
| Campo `hidden`, `select`, `radio`, `checkbox`, campo `disabled` | Zero — o DevTools edita tudo |
| Valor que passou pela validação do JavaScript | Zero — o cliente pode não executar o JS |
| Parâmetro de rota (`/pedido/[id]`) | Zero |
| Webhook de terceiro (Stripe, Mercado Pago) | Zero até a assinatura ser conferida |
| Dado vindo do seu próprio banco | Baixa — alguém o inseriu antes; escape na saída mesmo assim |

Validação no cliente é **usabilidade**: feedback rápido. Nunca é segurança. Toda regra
validada no navegador é revalidada no servidor, sem exceção.

---

## 2. Validar por allowlist

Descreva o que é **aceito**, não o que é rejeitado. Lista de proibidos sempre tem um furo.

### PHP

```php
// Inteiro com faixa
$id = filter_var($_GET['id'] ?? null, FILTER_VALIDATE_INT, [
    'options' => ['min_range' => 1, 'max_range' => PHP_INT_MAX],
]);
if ($id === false || $id === null) { responder400('Identificador inválido.'); }

// E-mail (formato — não prova existência)
$email = filter_var(trim($_POST['email'] ?? ''), FILTER_VALIDATE_EMAIL);
if ($email === false) { $erros['email'] = 'E-mail inválido.'; }

// Enum: a entrada é uma CHAVE de um conjunto que você controla
$statusValidos = ['aberto', 'andamento', 'fechado'];
$status = in_array($_POST['status'] ?? '', $statusValidos, true) ? $_POST['status'] : null;
if ($status === null) { $erros['status'] = 'Status inválido.'; }

// Texto: limite de tamanho SEMPRE, e normalização de espaços
$titulo = trim((string)($_POST['titulo'] ?? ''));
if ($titulo === '' || mb_strlen($titulo) > 200) { $erros['titulo'] = 'Título de 1 a 200 caracteres.'; }

// Data: parse estrito, não regex
$d = DateTimeImmutable::createFromFormat('!Y-m-d', $_POST['data'] ?? '');
if ($d === false || $d->format('Y-m-d') !== $_POST['data']) { $erros['data'] = 'Data inválida.'; }

// Decimal monetário
$valor = filter_var($_POST['valor'] ?? '', FILTER_VALIDATE_FLOAT);
if ($valor === false || $valor < 0 || $valor > 9999999.99) { $erros['valor'] = 'Valor inválido.'; }
```

Regra prática: **todo campo de texto tem tamanho máximo**, e ele bate com o `VARCHAR` da
coluna. Sem isso, o MySQL trunca em silêncio (ou explode, em modo estrito) e o dado fica
errado sem ninguém perceber.

### Next.js — validação em esquema, no servidor

```ts
'use server';
import { z } from 'zod';

const EsquemaChamado = z.object({
  titulo:    z.string().trim().min(1).max(200),
  descricao: z.string().trim().max(5000).optional(),
  status:    z.enum(['aberto', 'andamento', 'fechado']),
  prioridade: z.coerce.number().int().min(1).max(5),
});

export async function criarChamado(_estado: unknown, formData: FormData) {
  const sessao = await exigirSessao();                      // autorização ANTES de tudo
  const r = EsquemaChamado.safeParse(Object.fromEntries(formData));
  if (!r.success) return { erros: r.error.flatten().fieldErrors };
  // …r.data está tipado e validado
}
```

**Server Action é um endpoint HTTP público.** Qualquer pessoa pode chamá-la com o corpo que
quiser. Validar a entrada e conferir a autorização **dentro** dela não é opcional.

---

## 3. Escapar na saída — o contexto decide a função

Não existe "escapar" genérico. Existe escapar *para* HTML, *para* atributo, *para* JS,
*para* URL, *para* `LIKE`.

### HTML (o caso comum)

```php
<?= htmlspecialchars($chamado['titulo'], ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8') ?>
```

`ENT_QUOTES` escapa aspas simples também (necessário em atributos com aspas simples);
`ENT_SUBSTITUTE` troca bytes inválidos em vez de devolver string vazia — sem ele, um byte
malformado faz o campo sumir da tela sem erro.

Crie um atalho e use-o em **todo** eco:

```php
function e(?string $v): string {
    return htmlspecialchars($v ?? '', ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}
```

```php
<h1><?= e($titulo) ?></h1>
<input name="titulo" value="<?= e($titulo) ?>">     <!-- atributo SEMPRE com aspas -->
<a href="/chamado?id=<?= urlencode((string)$id) ?>">abrir</a>   <!-- URL: urlencode -->
```

### Atributo sem aspas — não faça

```php
<div data-id=<?= e($id) ?>>      <!-- ❌ um espaço no valor injeta um atributo novo -->
<div data-id="<?= e($id) ?>">    <!-- ✅ -->
```

### JavaScript embutido

`htmlspecialchars` **não** é suficiente dentro de `<script>`. Serialize como JSON:

```php
<script>
  const chamado = <?= json_encode($chamado, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_THROW_ON_ERROR) ?>;
</script>
```

Melhor ainda: não embuta. Coloque em `data-*` escapado e leia com `dataset`.

### React / Next.js

JSX escapa por padrão — `{valor}` é seguro. O buraco tem nome:

```tsx
<div dangerouslySetInnerHTML={{ __html: conteudo }} />   // ❌ a menos que sanitizado
```

Se HTML rico for requisito, sanitize no **servidor** com uma biblioteca de allowlist
(`sanitize-html`, `DOMPurify` em ambiente de servidor) e guarde o resultado sanitizado.
Nunca sanitize só no cliente.

Outros vetores em React que o JSX não cobre:

```tsx
<a href={urlDoUsuario}>            // ❌ javascript:alert(1) funciona
<a href={urlSegura(urlDoUsuario)}> // ✅ aceite apenas http:, https:, mailto:
```

```ts
function urlSegura(u: string): string {
  try {
    const url = new URL(u, 'https://exemplo.invalid');
    return ['http:', 'https:', 'mailto:'].includes(url.protocol) ? u : '#';
  } catch { return '#'; }
}
```

---

## 4. CSRF — toda ação que muda estado

Um `GET` nunca altera dados. Todo `POST`/`PUT`/`DELETE` carrega token, conferido no
servidor com comparação de tempo constante.

```php
// Gerar (uma vez por sessão) e embutir no formulário
if (empty($_SESSION['csrf'])) { $_SESSION['csrf'] = bin2hex(random_bytes(32)); }
?>
<input type="hidden" name="_csrf" value="<?= e($_SESSION['csrf']) ?>">
<?php
// Conferir, antes de qualquer efeito colateral
if (!hash_equals($_SESSION['csrf'] ?? '', $_POST['_csrf'] ?? '')) {
    http_response_code(419);
    exit('Sessão expirada. Recarregue a página.');
}
```

`hash_equals`, não `===`: comparação de tempo constante evita vazamento por temporização.

Reforce com o cookie de sessão em `SameSite=Lax` (ou `Strict`) — defesa em profundidade,
não substituição.

No Next.js, Server Actions já trazem proteção contra CSRF por origem; ainda assim, a
autorização dentro da action é obrigatória, e requisições de Route Handlers que mudam estado
precisam de token próprio.

---

## 5. Upload de arquivo — a porta mais larga

Um upload mal tratado é execução remota de código. As sete regras, todas obrigatórias:

1. **Fora do webroot**, ou em diretório onde o PHP não executa.
2. **Nome gerado por você** — nunca o nome enviado. `bin2hex(random_bytes(16)) . '.' . $ext`.
3. **Extensão por allowlist**, derivada do tipo real, não do nome.
4. **Tipo real conferido** com `finfo`, não com `$_FILES['x']['type']` (que o cliente manda).
5. **Tamanho limitado** na aplicação e no `php.ini`/servidor.
6. **Execução desligada** no diretório de uploads.
7. **Servido por script controlado**, que confere autorização antes de entregar o byte.

```php
$permitidos = ['image/jpeg' => 'jpg', 'image/png' => 'png', 'application/pdf' => 'pdf'];

if ($_FILES['arquivo']['error'] !== UPLOAD_ERR_OK) { erro('Falha no envio.'); }
if ($_FILES['arquivo']['size'] > 5 * 1024 * 1024)  { erro('Máximo de 5 MB.'); }

$mime = (new finfo(FILEINFO_MIME_TYPE))->file($_FILES['arquivo']['tmp_name']);
if (!isset($permitidos[$mime])) { erro('Tipo de arquivo não permitido.'); }

$nome    = bin2hex(random_bytes(16)) . '.' . $permitidos[$mime];
$destino = STORAGE_PATH . '/uploads/' . $nome;      // STORAGE_PATH fora do public_html
if (!move_uploaded_file($_FILES['arquivo']['tmp_name'], $destino)) { erro('Falha ao salvar.'); }
chmod($destino, 0644);
// grave $nome no banco; o nome original, se precisar exibir, vai escapado
```

```apache
# uploads/.htaccess — se o diretório acabar dentro do webroot mesmo assim
php_flag engine off
<FilesMatch "\.(php|phtml|phar|cgi|pl|py|sh|htaccess)$">
  Require all denied
</FilesMatch>
```

**SVG é um vetor de XSS** (contém `<script>`). Ou proíba, ou sanitize, ou sirva sempre com
`Content-Disposition: attachment`.

---

## 6. Path traversal — nunca monte caminho com entrada

```php
// ❌ ?arquivo=../../../../etc/passwd
readfile(STORAGE_PATH . '/uploads/' . $_GET['arquivo']);

// ✅ o identificador vem do banco; o caminho é montado pelo servidor
$stmt = $pdo->prepare('SELECT nome_armazenado, nome_original, chamado_id FROM anexos WHERE id = :id');
$stmt->execute([':id' => $id]);
$anexo = $stmt->fetch();
if (!$anexo || !podeVer($usuario, $anexo['chamado_id'])) { http_response_code(404); exit; }

$caminho = STORAGE_PATH . '/uploads/' . basename($anexo['nome_armazenado']);
$real    = realpath($caminho);
if ($real === false || !str_starts_with($real, realpath(STORAGE_PATH . '/uploads'))) {
    http_response_code(404); exit;      // saiu da pasta: recusa
}
```

Mesma regra para `include`/`require`: nunca com valor da URL. Rotas vêm de um mapa que você
escreveu.

---

## 7. Redirecionamento aberto

```php
// ❌ ?voltar=https://site-malicioso.example
header('Location: ' . $_GET['voltar']);

// ✅ só caminhos internos
$destino = (string)($_GET['voltar'] ?? '/');
if (!str_starts_with($destino, '/') || str_starts_with($destino, '//')) { $destino = '/'; }
header('Location: ' . $destino);
```

---

## 8. SSRF — quando o servidor busca uma URL do usuário

Ao consumir URL fornecida pelo usuário (importar imagem, webhook, preview de link):

- Aceite só `http:`/`https:`.
- Resolva o DNS e **rejeite IP privado ou loopback** (`10.0.0.0/8`, `172.16.0.0/12`,
  `192.168.0.0/16`, `127.0.0.0/8`, `169.254.169.254`).
- Desligue o seguimento de redirecionamento, ou revalide o destino a cada salto.
- Coloque timeout e limite de tamanho de resposta.

`169.254.169.254` é o endpoint de metadados das nuvens — o alvo clássico de SSRF.

---

## 9. Checklist

- [ ] Todo campo tem tipo, faixa e tamanho máximo validados no servidor
- [ ] Enums validados por `in_array(..., true)` ou `z.enum`
- [ ] Toda saída HTML passa por `e()` / escape do framework
- [ ] Atributos HTML sempre entre aspas
- [ ] Nenhum `dangerouslySetInnerHTML` sem sanitização de allowlist no servidor
- [ ] `href`/`src` vindos do usuário filtrados por protocolo
- [ ] Token CSRF em toda ação que muda estado, conferido com `hash_equals`
- [ ] Nenhum `GET` com efeito colateral
- [ ] Upload: nome gerado, tipo por `finfo`, tamanho limitado, fora do webroot, sem execução
- [ ] Nenhum caminho de arquivo montado com entrada do usuário
- [ ] Redirecionamentos limitados a caminhos internos
- [ ] Casos de teste de XSS, CSRF e traversal existem no roteiro de QA (R11)
