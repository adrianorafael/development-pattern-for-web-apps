# Rotas e URLs — a URL é interface, não caminho de arquivo

> Regra **R15**. Toda URL descreve a ação ou o recurso em linguagem humana. Nunca revela a
> estrutura de pastas do servidor, nunca carrega extensão de arquivo, nunca depende de query
> string para navegar.

```
❌ https://seu-dominio.com.br/usuarios/cadastro.php
✅ https://seu-dominio.com.br/cadastrar-novo-usuario

❌ https://seu-dominio.com.br/app/views/chamados/detalhe.php?id=8
✅ https://seu-dominio.com.br/chamados/8/impressora-nao-imprime
```

A URL é a parte da aplicação que **sai dela**: vai para o histórico do navegador, para os
favoritos, para o WhatsApp de quem compartilha, para o índice do Google, para o log do
servidor. Ela é a única parte da interface que sobrevive a uma reescrita do front-end — e
por isso é a única que não pode ser um detalhe de implementação.

`/usuarios/cadastro.php` entrega três coisas de graça: a linguagem do servidor, a árvore de
pastas e o nome do arquivo. Quem está sondando começa por aí. E no dia em que você mover o
arquivo, todo link publicado quebra.

---

## 1. As sete convenções

| # | Convenção | Sim | Não |
| --- | --- | --- | --- |
| 1 | **Português, minúsculas, kebab-case** | `/redefinir-senha` | `/redefinirSenha`, `/redefinir_senha`, `/ResetPassword` |
| 2 | **Sem acento e sem cedilha** — o percent-encoding torna a URL ilegível ao ser copiada | `/manutencao` | `/manutenção` → `/manuten%C3%A7%C3%A3o` |
| 3 | **Sem extensão de arquivo** | `/contato` | `/contato.php`, `/contato.html` |
| 4 | **Sem estrutura de pastas do servidor** | `/chamados` | `/app/views/chamados/lista.php` |
| 5 | **Ação = verbo no infinitivo** | `/cadastrar-novo-usuario`, `/recuperar-acesso` | `/user-new`, `/form2` |
| 6 | **Coleção = substantivo plural; item = coleção + identificador** | `/chamados`, `/chamados/8` | `/chamado?id=8`, `/listarChamados` |
| 7 | **Navegação nunca depende de query string** | `/chamados/8/anexos` | `/index.php?p=chamados&acao=anexos&id=8` |

### O que a query string pode fazer

Ela não some — ela muda de papel. Serve para **estado da visualização**, não para
roteamento:

```
✅ /chamados?status=fechado&ordenar=data&pagina=2      filtro, ordenação, paginação
✅ /produtos?busca=teclado+mecanico                     busca
❌ /?pagina=chamados                                    roteamento disfarçado
❌ /index.php?acao=excluir&id=8                         roteamento E efeito colateral
```

A vantagem é concreta: `/chamados?status=fechado` é compartilhável e favoritável — o
destinatário vê exatamente a mesma tela. Já `/index.php?p=...` não significa nada fora da
sua sessão.

---

## 2. Regras que evitam dor depois

**Um recurso, uma URL canônica.** Se `/chamados/8` e `/chamados/8/` respondem 200 com o
mesmo conteúdo, você tem duas URLs para uma coisa: histórico dividido, SEO dividido, cache
dividido. Escolha uma forma e responda **301** na outra. O mesmo vale para maiúsculas:
`/Chamados` → 301 → `/chamados`.

**`GET` nunca tem efeito colateral.** `/chamados/8/excluir` como link é um convite ao
desastre — o pré-carregamento do navegador, o robô de indexação ou um antivírus corporativo
abrem links sozinhos. Excluir é `POST` (ou `DELETE`) com token CSRF.
→ [entrada-e-saida-seguras.md](entrada-e-saida-seguras.md)

**Renomear uma rota é uma mudança MAJOR.** Links publicados quebram, e você não controla
quem os publicou. Ao renomear, mantenha a antiga respondendo **301** por pelo menos uma
versão maior, e registre no CHANGELOG. → [release-e-deploy.md](release-e-deploy.md)

```php
// app/rotas-legadas.php — tabela de redirecionamentos permanentes
const REDIRECIONAMENTOS = [
    '/usuarios/cadastro.php' => '/cadastrar-novo-usuario',
    '/novo-chamado'          => '/abrir-chamado',
];
```

**Cuidado com o ID sequencial exposto.** `/chamados/8` diz ao mundo que existem pelo menos 8
chamados, e convida a testar `/chamados/9`. Isso não é uma falha por si só — a defesa contra
IDOR é a autorização, sempre (R7) — mas em recurso público ou sensível prefira um slug ou um
identificador não adivinhável:

```
/chamados/8                                   interno, autorizado por dono — aceitável
/chamados/8/impressora-nao-imprime            legível, e o slug não precisa bater
/relatorios/a7f3c1e9-4b2d-4f8a-9c1e-...       público ou sensível — use UUID
```

O identificador continua sendo validado e a autorização continua entrando na cláusula
`WHERE`. URL bonita não é controle de acesso.

**404 é 404.** Uma página "não encontrado" servida com status 200 confunde navegador, cache,
robô de indexação e o seu próprio roteiro de QA. Devolva o status certo.

---

## 3. PHP — o mapa de rotas

Um único ponto de entrada (`public_html/index.php`) e um mapa escrito à mão. O `.htaccess`
já manda tudo que não é arquivo real para lá — ver
[`../assets/templates/htaccess.template`](../assets/templates/htaccess.template).

```php
// public_html/index.php
$rotas = [
    'GET  /'                          => [PaginaController::class,  'inicio'],
    'GET  /entrar'                    => [SessaoController::class,  'formularioLogin'],
    'POST /entrar'                    => [SessaoController::class,  'autenticar'],
    'POST /sair'                      => [SessaoController::class,  'encerrar'],

    'GET  /cadastrar-novo-usuario'    => [UsuarioController::class, 'formulario'],
    'POST /cadastrar-novo-usuario'    => [UsuarioController::class, 'criar'],
    'GET  /recuperar-acesso'          => [SenhaController::class,   'formulario'],
    'POST /recuperar-acesso'          => [SenhaController::class,   'enviarLink'],
    'GET  /redefinir-senha/{token}'   => [SenhaController::class,   'formularioNova'],
    'POST /redefinir-senha/{token}'   => [SenhaController::class,   'redefinir'],

    'GET  /chamados'                  => [ChamadoController::class, 'listar'],
    'GET  /abrir-chamado'             => [ChamadoController::class, 'formulario'],
    'POST /abrir-chamado'             => [ChamadoController::class, 'criar'],
    'GET  /chamados/{id}'             => [ChamadoController::class, 'detalhe'],
    'GET  /chamados/{id}/{slug}'      => [ChamadoController::class, 'detalhe'],
    'POST /chamados/{id}/fechar'      => [ChamadoController::class, 'fechar'],
    'POST /chamados/{id}/anexos'      => [AnexoController::class,   'enviar'],
    'GET  /anexos/{id}'               => [AnexoController::class,   'baixar'],

    'GET  /administracao'             => [AdminController::class,   'painel'],
    'GET  /administracao/atualizacoes'=> [AdminController::class,   'atualizacoes'],
];
```

O mapa é **escrito por você**. Nunca `include $_GET['pagina'] . '.php'`: isso é inclusão de
arquivo arbitrário com outro nome. → [entrada-e-saida-seguras.md](entrada-e-saida-seguras.md)

### Um roteador que cabe em uma tela

```php
final class Router
{
    public function __construct(private array $rotas) {}

    public function despachar(string $metodo, string $caminho): void
    {
        // Canonicalização: minúsculas e sem barra final, com 301 na forma divergente.
        $canonico = rtrim(strtolower($caminho), '/');
        if ($canonico === '') { $canonico = '/'; }
        if ($canonico !== $caminho) {
            header('Location: ' . $canonico, true, 301);
            return;
        }

        if ($metodo === 'GET' && isset(REDIRECIONAMENTOS[$canonico])) {
            header('Location: ' . REDIRECIONAMENTOS[$canonico], true, 301);
            return;
        }

        foreach ($this->rotas as $chave => [$classe, $acao]) {
            [$metodoRota, $padrao] = preg_split('/\s+/', $chave, 2);
            if ($metodoRota !== $metodo) { continue; }

            // {id} vira um grupo nomeado; a validação real acontece no controller.
            $regex = '#^' . preg_replace('/\{([a-z_]+)\}/', '(?P<$1>[^/]+)', $padrao) . '$#';
            if (preg_match($regex, $canonico, $m)) {
                $params = array_filter($m, 'is_string', ARRAY_FILTER_USE_KEY);
                (new $classe())->$acao($params);
                return;
            }
        }

        http_response_code(404);
        require __DIR__ . '/app/Views/erros/404.php';
    }
}
```

Dois pontos que o roteador **não** faz, de propósito:

- **Não valida o `{id}`.** Ele entrega a string; quem valida é o controller, com
  `filter_var(..., FILTER_VALIDATE_INT)` (R6) — e o dono entra na consulta (R7).
- **Não descobre a classe pela URL.** `new ($_GET['c'])()` é execução de código arbitrário.
  O mapa é literal.

### Gerando URLs no código

Nunca escreva a URL à mão duas vezes. Um helper, e o dia da renomeação tem um lugar só:

```php
function rota(string $nome, array $params = []): string {
    $modelos = [
        'chamados'        => '/chamados',
        'chamado'         => '/chamados/{id}',
        'chamado.slug'    => '/chamados/{id}/{slug}',
        'abrir-chamado'   => '/abrir-chamado',
        'cadastrar'       => '/cadastrar-novo-usuario',
    ];
    $url = $modelos[$nome] ?? '/';
    foreach ($params as $chave => $valor) {
        $url = str_replace('{' . $chave . '}', rawurlencode((string)$valor), $url);
    }
    return $url;
}
```

```php
<a href="<?= e(rota('chamado.slug', ['id' => $c['id'], 'slug' => $c['slug']])) ?>">
  <?= e($c['titulo']) ?>
</a>
```

### Gerando o slug

```php
function slugify(string $texto): string {
    $t = iconv('UTF-8', 'ASCII//TRANSLIT//IGNORE', $texto) ?: $texto;   // remove acentos
    $t = strtolower(preg_replace('/[^a-zA-Z0-9]+/', '-', $t) ?? '');
    return trim($t, '-') ?: 'sem-titulo';
}
```

O slug é **decorativo**: quem identifica o registro é o `{id}`. Assim, mudar o título não
quebra o link antigo — ele apenas redireciona para o slug novo, se você quiser.

---

## 4. Next.js — a pasta é a URL

No App Router, o caminho da pasta **é** a rota. Isso significa que a convenção de nomes de
pasta é a convenção de URLs, e não há um mapa separado para manter em sincronia.

```
app/
├── page.tsx                                  →  /
├── entrar/page.tsx                           →  /entrar
├── cadastrar-novo-usuario/page.tsx           →  /cadastrar-novo-usuario
├── recuperar-acesso/page.tsx                 →  /recuperar-acesso
├── redefinir-senha/[token]/page.tsx          →  /redefinir-senha/abc123
├── (painel)/                                 →  grupo: NÃO entra na URL
│   ├── layout.tsx                            →  verifica a sessão do grupo inteiro
│   ├── chamados/page.tsx                     →  /chamados
│   ├── abrir-chamado/page.tsx                →  /abrir-chamado
│   └── chamados/[id]/page.tsx                →  /chamados/8
└── administracao/atualizacoes/page.tsx       →  /administracao/atualizacoes
```

- **Pastas em português, kebab-case.** `cadastrar-novo-usuario`, nunca `signup` ou `NewUser`.
- **Grupos de rota `(painel)` não aparecem na URL** — use-os para compartilhar layout e
  verificação de sessão sem poluir o caminho.
- **`[id]` é dinâmico**; `[...slug]` captura o resto. No Next 15, `params` é uma `Promise`:
  `const { id } = await params;`
- **Arquivos especiais não viram rota:** `layout.tsx`, `loading.tsx`, `error.tsx`,
  `not-found.tsx`. Use `not-found.tsx` + `notFound()` para devolver **404 de verdade**.

```tsx
// app/(painel)/chamados/[id]/page.tsx
import { notFound } from 'next/navigation';

export default async function Pagina({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const numero = Number(id);
  if (!Number.isInteger(numero) || numero < 1) notFound();      // 404 real

  const sessao = await exigirSessao();
  const chamado = await buscarChamado(numero, sessao.usuarioId); // o dono no WHERE (R7)
  if (!chamado) notFound();                                      // 404, não 403

  return <DetalheChamado chamado={chamado} />;
}
```

Redirecionamentos de rotas antigas ficam em `next.config.ts`, versionados junto com o código:

```ts
export default {
  async redirects() {
    return [
      { source: '/usuarios/cadastro.php', destination: '/cadastrar-novo-usuario', permanent: true },
      { source: '/signup',                destination: '/cadastrar-novo-usuario', permanent: true },
    ];
  },
};
```

`permanent: true` emite 301. Use `false` (307) só enquanto a mudança for reversível.

---

## 5. Tabela de tradução

Use como referência ao converter um projeto antigo:

| Antes | Depois |
| --- | --- |
| `/index.php` | `/` |
| `/usuarios/cadastro.php` | `/cadastrar-novo-usuario` |
| `/usuarios/lista.php` | `/usuarios` |
| `/usuarios/editar.php?id=8` | `/usuarios/8/editar` |
| `/login.php` | `/entrar` |
| `/logout.php` | `POST /sair` |
| `/esqueci.php` | `/recuperar-acesso` |
| `/reset.php?token=abc` | `/redefinir-senha/abc` |
| `/chamados/ver.php?id=8` | `/chamados/8` |
| `/chamados/novo.php` | `/abrir-chamado` |
| `/chamados/excluir.php?id=8` | `POST /chamados/8/excluir` |
| `/admin/index.php` | `/administracao` |
| `/admin/update.php` | `/administracao/atualizacoes` |
| `/api/get_chamados.php` | `GET /api/chamados` |
| `/relatorio.php?tipo=mensal&ano=2026` | `/relatorios/mensal/2026` |

Note o último: o que identifica o recurso vira caminho; o que filtra a visualização continua
em query string.

---

## 6. Checklist

- [ ] Nenhuma URL da aplicação contém `.php`, `.html` ou nome de pasta do servidor
- [ ] Todas em português, minúsculas, kebab-case, sem acento e sem underscore
- [ ] Ações são verbos no infinitivo; coleções são substantivos plurais
- [ ] Nenhuma navegação depende de query string; ela só carrega filtro, ordenação e paginação
- [ ] Nenhum `GET` com efeito colateral
- [ ] Forma canônica definida (barra final, caixa) e a divergente responde 301
- [ ] Rotas renomeadas mantêm 301 da antiga, registrado no CHANGELOG
- [ ] Página inexistente responde **404**, não 200
- [ ] URLs geradas por helper/`rota()`, nunca escritas à mão duas vezes
- [ ] O `{id}` é validado no controller, e o dono entra na cláusula `WHERE` (R6, R7)
- [ ] Nenhuma classe, arquivo ou caminho é resolvido a partir da URL
- [ ] `mod_rewrite` confirmado no servidor (o Wizard verifica — R9)
- [ ] Casos de rota no roteiro de QA (R11), incluindo os 301 e o 404

---

## 7. O que testar (entra no roteiro de QA, R11)

| Caso | Resultado esperado |
| --- | --- |
| Cada rota do mapa, acessada diretamente pela barra de endereço | 200 e a tela correta — nada depende de ter vindo de outra página |
| Recarregar (F5) em qualquer rota interna | A mesma tela, sem perder estado nem reenviar formulário |
| Botão Voltar depois de navegar por três telas | Volta na ordem certa |
| URL com barra final (`/chamados/`) | 301 para `/chamados` |
| URL com maiúsculas (`/Chamados`) | 301 para `/chamados` |
| Rota antiga da tabela de redirecionamentos | 301 para a nova |
| URL inexistente (`/pagina-que-nao-existe`) | **404** com a página de erro do app |
| `/chamados/abc` (id não numérico) | 404, sem erro 500 e sem mensagem do banco |
| `/chamados/999999` (id inexistente) | 404 |
| `/chamados/{id de outro usuário}` | 404 — não 403 (R7) |
| Compartilhar `/chamados?status=fechado&pagina=2` em outra sessão | A mesma visualização filtrada |
| Qualquer URL da aplicação | Não contém `.php`, `.html` nem nome de pasta interna |
| `/app/`, `/config/`, `/storage/`, `/vendor/` | 403 ou 404, nunca listagem ou conteúdo |
