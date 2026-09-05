# Wizard de instalação — todo app PHP+MySQL tem um

> Regra **R9**. Nenhum app PHP+MySQL é entregue sem instalador. Instalar deve ser: subir os
> arquivos, abrir `/install/`, informar host, banco, usuário e senha, e clicar em avançar.

Sem instalador, "publicar na Hostinger" vira uma sessão de arqueologia: qual extensão falta,
qual permissão está errada, qual arquivo SQL rodar em que ordem, por que a página está em
branco. O Wizard transforma isso em um diagnóstico com nome e solução na tela.

Esqueleto pronto e executável:
[`../assets/templates/install-wizard.php.template`](../assets/templates/install-wizard.php.template).

---

## Os cinco passos

```
1 REQUISITOS   PHP, extensões, permissões de escrita, mod_rewrite   → aprovado / reprovado por item
2 BANCO        host, porta, banco, usuário, senha                   → testa a conexão AGORA
3 ESTRATÉGIA   base vazia → criar | base existente → limpar e recriar | cancelar
4 ADMIN        nome, e-mail, senha do primeiro administrador        → grava com password_hash
5 CONCLUSÃO    grava config, registra a versão do schema, se tranca → link para o app
```

Cada passo só libera o seguinte se o anterior passou. Nenhum passo grava qualquer coisa
antes do passo 5 — se o usuário desistir no 3, nada mudou.

---

## Passo 1 — Requisitos

Cada item aparece com **estado, valor encontrado, valor exigido e o que fazer**. Um X
vermelho sem instrução é inútil.

| Item | Como verificar | Ação sugerida quando falha |
| --- | --- | --- |
| Versão do PHP | `PHP_VERSION_ID >= 80100` | "hPanel → Avançado → Versão do PHP → selecione 8.1+" |
| `pdo_mysql` | `extension_loaded('pdo_mysql')` | "hPanel → Configuração PHP → ative pdo_mysql" |
| `mbstring` | `extension_loaded('mbstring')` | idem |
| `json` | `extension_loaded('json')` | idem |
| `zip` | `extension_loaded('zip')` | "necessária para o painel de atualização (R10)" |
| `openssl` | `extension_loaded('openssl')` | "necessária para tokens seguros" |
| `fileinfo` | `extension_loaded('fileinfo')` | "necessária para validar uploads" |
| `gd` ou `imagick` | `extension_loaded(...)` | opcional — só se o app manipula imagem |
| Escrita em `config/` | `is_writable()` | "chmod 755 na pasta config" |
| Escrita em `storage/` | `is_writable()` | "crie storage/uploads, storage/logs, storage/backups" |
| `mod_rewrite` | requisição de teste a uma URL amigável | "confirme que o .htaccess foi enviado" — sem ele as rotas semânticas (R15) não funcionam |
| Limite de upload | `upload_max_filesize` | "afeta o tamanho máximo do pacote de atualização" |
| Tempo de execução | `max_execution_time` | "migrações longas rodarão em lotes" |
| HTTPS ativo | `$_SERVER['HTTPS']` | "ative o SSL grátis no hPanel antes de continuar" |

Separe **obrigatório** de **recomendado**. Só o obrigatório bloqueia o botão "Continuar";
o recomendado exibe aviso e segue.

Ofereça um botão "Verificar novamente" — o usuário vai ajustar o PHP no painel e voltar.

---

## Passo 2 — Conexão com o banco

Cinco campos: host (padrão `localhost`), porta (`3306`), nome do banco, usuário, senha.
Opcional: prefixo de tabelas, para o caso de compartilhar a base com outro app.

**Testar a conexão de verdade, ali, antes de avançar.** E traduzir o erro:

| Erro do MySQL | Mensagem para o usuário |
| --- | --- |
| `SQLSTATE[HY000] [1045]` | "Usuário ou senha incorretos. Confira em hPanel → Bancos de dados MySQL." |
| `SQLSTATE[HY000] [2002]` | "Não foi possível alcançar o servidor. Na Hostinger o host costuma ser `localhost`." |
| `SQLSTATE[HY000] [1049]` | "O banco `X` não existe. Crie-o no hPanel — o instalador não cria a base, só as tabelas." |
| `SQLSTATE[HY000] [1044]` | "O usuário não tem permissão neste banco. Associe o usuário ao banco no hPanel." |

Na Hostinger o usuário **não tem permissão para `CREATE DATABASE`**. O Wizard cria as
**tabelas** dentro de uma base que já existe. Diga isso na tela, não deixe descobrir pelo
erro.

Após conectar, verifique também:

```php
$versao = $pdo->query('SELECT VERSION()')->fetchColumn();       // 5.7? 8.0? MariaDB?
$charset = $pdo->query("SHOW VARIABLES LIKE 'character_set_database'")->fetch();
// Se não for utf8mb4, avise: acentos e emoji vão quebrar.
```

Nunca grave a senha em log, nem em campo `hidden`, nem na sessão em texto claro além do
necessário para concluir a instalação.

---

## Passo 3 — Estratégia de schema

O Wizard detecta o estado da base e oferece o que faz sentido:

| Estado detectado | Opções apresentadas |
| --- | --- |
| Nenhuma tabela do app | **Criar estrutura** (única opção) |
| Tabelas do app, mesma versão | **Manter dados** (recomendado) · **Limpar e recriar** · Cancelar |
| Tabelas do app, versão anterior | **Atualizar via migrações** (recomendado) · **Limpar e recriar** · Cancelar |
| Tabelas com nomes conflitantes, de outro app | **Cancelar** — sugerir prefixo de tabelas ou outra base |

**"Limpar e recriar" apaga dados.** A tela precisa deixar isso impossível de não ver:

- Liste **as tabelas que serão removidas** e a contagem de linhas de cada uma.
- Exija digitar a palavra `APAGAR` num campo de confirmação — não um checkbox.
- Ofereça baixar um dump antes, se `mysqldump` não estiver disponível gere o SQL em PHP.
- Remova apenas as tabelas **do app** (pelo prefixo ou por uma lista explícita), nunca um
  `DROP DATABASE`, nunca "todas as tabelas que existirem".

```php
// Desligar a checagem de FK só durante o drop, e religar sempre — inclusive em erro
$pdo->exec('SET FOREIGN_KEY_CHECKS = 0');
try {
    foreach ($tabelasDoApp as $t) {
        $pdo->exec('DROP TABLE IF EXISTS `' . str_replace('`', '``', $prefixo . $t) . '`');
    }
} finally {
    $pdo->exec('SET FOREIGN_KEY_CHECKS = 1');
}
```

O nome da tabela vem da **lista do app** (allowlist), nunca de entrada do usuário (R5).

### Idempotência

O schema é escrito para poder rodar duas vezes sem estragar nada:

```sql
CREATE TABLE IF NOT EXISTS `usuarios` ( … ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT IGNORE INTO `configuracoes` (chave, valor) VALUES ('tema', 'claro');
```

Rodar o instalador duas vezes por engano — coisa que acontece quando a página recarrega —
não pode deixar o banco pela metade. Cada passo de criação roda em transação quando o MySQL
permite (DDL não é transacional no MySQL: por isso a ordem importa e o log de progresso é
gravado a cada tabela).

---

## Passo 4 — Administrador

- Nome, e-mail (validado), senha e confirmação.
- **Mínimo de 10 caracteres**, com medidor de força; rejeite as óbvias (`admin`, `123456`,
  o próprio e-mail).
- Grave com `password_hash($senha, PASSWORD_DEFAULT)` — nunca com `md5`.
- Marque `deve_trocar_senha = 0` (o usuário acabou de escolher) e `papel = 'admin'`.
- Nunca crie um usuário padrão `admin/admin` "para facilitar". É o alvo número um dos
  scanners automáticos.

---

## Passo 5 — Conclusão e trancamento

Nesta ordem exata:

1. **Gravar a configuração** fora do repositório:

```php
$conteudo = "<?php\n// Gerado pelo instalador em " . date('c') . ". NÃO versionar.\nreturn " .
            var_export([
                'db' => ['host'=>$host,'porta'=>$porta,'banco'=>$banco,
                         'usuario'=>$usuario,'senha'=>$senha,'prefixo'=>$prefixo],
                'app_key'  => bin2hex(random_bytes(32)),
                'url_base' => $urlBase,
                'timezone' => 'America/Sao_Paulo',
                'debug'    => false,
            ], true) . ";\n";

file_put_contents($caminhoConfig, $conteudo, LOCK_EX);
chmod($caminhoConfig, 0640);
```

Se `config/` estiver dentro do webroot, gere junto o `.htaccess` que nega o acesso — e
**mostre ao usuário o resultado do teste**, não só a intenção.

2. **Registrar a versão do schema** (R13):

```sql
CREATE TABLE IF NOT EXISTS schema_migrations (
  versao      VARCHAR(50)  NOT NULL,
  aplicada_em DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (versao)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

Insira **todas** as migrações que o schema base já contempla — senão o painel de atualização
vai tentar reaplicá-las.

3. **Trancar o instalador.** Sem isso, qualquer visitante reinstala o app e apaga a base.
   Três camadas, todas:

```php
file_put_contents(BASE_PATH . '/config/instalado.lock', date('c'));
```

```php
// primeira linha de install/index.php
if (is_file(BASE_PATH . '/config/instalado.lock')) {
    http_response_code(403);
    exit('Este aplicativo já está instalado. Para reinstalar, remova config/instalado.lock via FTP.');
}
```

E a tela final instrui: **"apague a pasta `install/` do servidor"**, com o caminho exato.
O painel administrativo exibe um alerta permanente enquanto `install/` existir.

4. **Resumo final:** o que foi criado (tabelas e contagem), onde ficou a configuração, o
   e-mail do administrador, a versão instalada, e os avisos pendentes (extensão recomendada
   ausente, `install/` ainda presente).

---

## Segurança do próprio instalador

O Wizard é a parte mais exposta do app: ele roda **antes** de existir autenticação.

- [ ] Recusa executar se `instalado.lock` existe
- [ ] Token CSRF em todos os passos (gerado na primeira requisição)
- [ ] Nenhuma credencial em log, em `hidden`, em URL ou em mensagem de erro
- [ ] Erros do MySQL traduzidos — sem stack trace, sem nome de arquivo do servidor
- [ ] `DROP` restrito à allowlist de tabelas do app
- [ ] Confirmação escrita (`APAGAR`) para o caminho destrutivo
- [ ] Nenhum caminho de arquivo vindo da entrada do usuário
- [ ] Config gravada com `0640` e fora do webroot (ou negada e testada)
- [ ] Instrução clara para remover `install/` ao final
- [ ] Alerta permanente no painel enquanto `install/` existir
- [ ] Rate limit simples nas tentativas do passo 2 (evita usar o Wizard como oráculo de
      credenciais do MySQL)

---

## O que testar (entra no roteiro de QA, R11)

| Caso | Resultado esperado |
| --- | --- |
| Instalação limpa, base vazia | Todas as tabelas criadas; admin criado; login funciona |
| Extensão obrigatória ausente | Passo 1 bloqueia e mostra a instrução do hPanel |
| Senha do banco errada | Mensagem traduzida, sem stack trace; permanece no passo 2 |
| Banco inexistente | Mensagem explicando que a base precisa ser criada no hPanel |
| Base já instalada, opção "manter" | Nenhum dado perdido; app segue funcionando |
| Base já instalada, opção "limpar e recriar" | Exige digitar `APAGAR`; só então recria |
| Recarregar a página no meio do passo 3 | Nada gravado pela metade |
| Rodar o instalador duas vezes | Segunda vez recusa com 403 pelo `instalado.lock` |
| Acessar `/install/` depois de instalado | 403 |
| Acessar `config/app.config.php` pelo navegador | 403, nunca o código-fonte |
| POST direto no passo 5 sem passar pelos anteriores | Recusado (CSRF + estado da sessão) |
