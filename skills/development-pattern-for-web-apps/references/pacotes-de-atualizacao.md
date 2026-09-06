# Pacotes de atualização: o painel que instala um ZIP

> Regra **R10**. Todo app PHP entrega um painel administrativo capaz de receber um pacote
> ZIP de atualização contendo **arquivos a publicar** e **scripts SQL que ajustam o banco**,
> aplicá-los na ordem certa, e voltar atrás quando algo der errado.

Atualizar por FTP é onde os projetos pessoais morrem: um arquivo esquecido, um SQL que
ninguém rodou, e o app fica meio atualizado: o pior estado possível. O painel torna a
atualização uma operação única, verificável e reversível.

---

## 1. Anatomia do pacote

```
meu-app-1.3.0.zip
├── manifest.json           # obrigatório: a identidade e o plano da atualização
├── files/                  # árvore espelhando a raiz do app
│   ├── app/Controllers/ChamadoController.php
│   ├── app/Views/chamados/lista.php
│   └── assets/css/app.css
├── migrations/             # SQL, ordenado por nome
│   ├── 0007_adiciona_anexos.sql
│   └── 0008_indice_status_data.sql
├── remove.txt              # opcional: um caminho por linha, arquivos a apagar
└── CHANGELOG.md            # opcional: exibido ao usuário antes de confirmar
```

### `manifest.json`

```json
{
  "app":            "controle-de-chamados",
  "versao":         "1.3.0",
  "versao_minima":  "1.2.0",
  "php_minimo":     "8.1",
  "extensoes":      ["pdo_mysql", "mbstring", "zip"],
  "gerado_em":      "2026-09-05T14:20:00-03:00",
  "migracoes":      ["0007_adiciona_anexos.sql", "0008_indice_status_data.sql"],
  "arquivos": [
    { "caminho": "app/Controllers/ChamadoController.php", "sha256": "a1b2…" },
    { "caminho": "app/Views/chamados/lista.php",          "sha256": "c3d4…" }
  ],
  "remover":        ["app/Views/chamados/antigo.php"],
  "notas":          "Adiciona anexos aos chamados. Requer 5 MB livres em storage/uploads."
}
```

- **`versao_minima`** impede pular versões: se o app está em 1.1.0 e o pacote exige 1.2.0,
  o painel recusa e diz qual pacote instalar antes.
- **`sha256` por arquivo** é a integridade: um ZIP truncado no upload é detectado antes de
  qualquer arquivo ser escrito.
- **`extensoes`/`php_minimo`** são revalidados no destino: o servidor pode ter mudado.

Modelo: [`../assets/templates/update-manifest.json.template`](../assets/templates/update-manifest.json.template).

---

## 2. O fluxo de instalação: nove etapas

```
1 UPLOAD       recebe o ZIP (autenticado, papel admin, CSRF, limite de tamanho)
2 VALIDAÇÃO    abre, lê manifest.json, confere sha256, versões, extensões
3 PRÉVIA       mostra: versão atual → nova, arquivos a alterar/criar/remover, migrações
               → ⛔ CONFIRMAÇÃO DO ADMINISTRADOR
4 BACKUP       dump do banco + cópia dos arquivos que serão sobrescritos
5 MANUTENÇÃO   liga o modo manutenção (visitante vê aviso, admin continua)
6 ARQUIVOS     grava em área temporária, depois move para o destino
7 MIGRAÇÕES    executa em ordem as que ainda não constam em schema_migrations
8 FINALIZAÇÃO  grava a nova versão, limpa temporários, desliga manutenção
9 RELATÓRIO    o que foi alterado, o que falhou, onde está o backup
```

Falha em qualquer etapa a partir da 6 dispara **rollback** (§5).

---

## 3. Validação: antes de escrever qualquer byte

```php
$zip = new ZipArchive();
if ($zip->open($caminhoTemp) !== true) { erro('Arquivo ZIP inválido ou corrompido.'); }

$manifestoBruto = $zip->getFromName('manifest.json');
if ($manifestoBruto === false) { erro('Pacote sem manifest.json, não é um pacote de atualização.'); }

$m = json_decode($manifestoBruto, true, 512, JSON_THROW_ON_ERROR);

// 1. É deste app?
if (($m['app'] ?? '') !== APP_SLUG) { erro('Este pacote é de outro aplicativo.'); }

// 2. A sequência de versões faz sentido?
if (version_compare($m['versao'], VERSAO_ATUAL, '<=')) { erro('Versão igual ou anterior à instalada.'); }
if (version_compare(VERSAO_ATUAL, $m['versao_minima'], '<')) {
    erro("Instale antes a versão {$m['versao_minima']}.");
}

// 3. O ambiente aguenta?
if (version_compare(PHP_VERSION, $m['php_minimo'], '<')) { erro('PHP insuficiente.'); }
foreach ($m['extensoes'] ?? [] as $ext) {
    if (!extension_loaded($ext)) { erro("Extensão obrigatória ausente: {$ext}"); }
}

// 4. Todo arquivo do pacote está declarado E íntegro?
foreach ($m['arquivos'] as $arq) {
    $conteudo = $zip->getFromName('files/' . $arq['caminho']);
    if ($conteudo === false)                          { erro("Faltando no ZIP: {$arq['caminho']}"); }
    if (hash('sha256', $conteudo) !== $arq['sha256']) { erro("Integridade falhou: {$arq['caminho']}"); }
}
```

### O caminho de cada arquivo é validado, sempre

O ataque clássico contra instaladores de ZIP é o *zip slip*: uma entrada chamada
`../../../../home/usuario/.ssh/authorized_keys`. A validação é obrigatória e tem quatro
partes:

```php
function caminhoDestinoSeguro(string $relativo, string $raiz): string {
    // 1. Nada de caminho absoluto, traversal, byte nulo ou separador do Windows
    if ($relativo === '' || str_contains($relativo, "\0")
        || str_contains($relativo, '..') || str_contains($relativo, '\\')
        || str_starts_with($relativo, '/')) {
        throw new RuntimeException("Caminho inválido no pacote: {$relativo}");
    }

    // 2. Extensão em allowlist: um .htaccess ou .sh no pacote é recusado
    $ext = strtolower(pathinfo($relativo, PATHINFO_EXTENSION));
    if (!in_array($ext, ['php','html','css','js','svg','png','jpg','webp','json','md'], true)) {
        throw new RuntimeException("Extensão não permitida: {$relativo}");
    }

    // 3. Primeiro segmento em allowlist: o pacote não escreve onde quiser
    $primeiro = explode('/', $relativo)[0];
    if (!in_array($primeiro, ['app','assets','admin','install'], true)) {
        throw new RuntimeException("Destino fora das pastas permitidas: {$relativo}");
    }

    // 4. Depois de normalizar, o resultado tem que continuar dentro da raiz
    $destino = $raiz . '/' . $relativo;
    $pai     = realpath(dirname($destino)) ?: dirname($destino);
    if (!str_starts_with($pai, realpath($raiz))) {
        throw new RuntimeException("Escape de diretório: {$relativo}");
    }
    return $destino;
}
```

**Nunca** use `$zip->extractTo($destino)` direto sobre o pacote inteiro: ele extrai o que
estiver lá, inclusive `../`. Extraia entrada por entrada, validando cada uma.

O pacote **nunca** pode escrever em `config/`, `storage/` ou na raiz. Essas pastas não estão
na allowlist do primeiro segmento, e é assim que uma atualização não sobrescreve a
configuração do usuário.

---

## 4. Migrações SQL

Uma tabela de controle, populada pelo Wizard na instalação e atualizada aqui:

```sql
CREATE TABLE IF NOT EXISTS schema_migrations (
  versao      VARCHAR(50) NOT NULL,
  aplicada_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  duracao_ms  INT UNSIGNED NULL,
  PRIMARY KEY (versao)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

Regras de uma migração deste padrão:

1. **Nome ordenável:** `0007_adiciona_anexos.sql`. A ordem de execução é a ordem do nome.
2. **Idempotente:** roda duas vezes sem quebrar.

```sql
-- 0007_adiciona_anexos.sql
CREATE TABLE IF NOT EXISTS anexos (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  chamado_id  BIGINT UNSIGNED NOT NULL,
  nome_original    VARCHAR(255) NOT NULL,
  nome_armazenado  VARCHAR(64)  NOT NULL,
  tamanho     INT UNSIGNED NOT NULL,
  criado_em   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_anexos_chamado (chamado_id),
  CONSTRAINT fk_anexos_chamado FOREIGN KEY (chamado_id) REFERENCES chamados (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

MySQL não tem `ADD COLUMN IF NOT EXISTS` em todas as versões. Quando precisar, consulte
antes:

```sql
SET @existe := (SELECT COUNT(*) FROM information_schema.COLUMNS
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'chamados'
                  AND COLUMN_NAME  = 'prioridade');
SET @sql := IF(@existe = 0,
  'ALTER TABLE chamados ADD COLUMN prioridade TINYINT UNSIGNED NOT NULL DEFAULT 3',
  'DO 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
```

3. **Sem dado destrutivo sem aviso.** `DROP COLUMN` e `DELETE` aparecem na prévia (etapa 3)
   destacados em vermelho, com o número de linhas afetadas.
4. **Migração de dados separada da de estrutura.** Duas migrações são mais fáceis de
   diagnosticar que uma que faz as duas coisas.
5. **DDL não é transacional no MySQL.** Um `ALTER` no meio do arquivo não volta com
   `ROLLBACK`, por isso o backup da etapa 4 é obrigatório, e por isso cada migração é
   registrada assim que termina.

```php
foreach ($migracoesPendentes as $arquivo) {
    $sql = $zip->getFromName('migrations/' . $arquivo);
    $inicio = microtime(true);
    try {
        $pdo->exec($sql);                                  // arquivo do pacote, não entrada de usuário
        $stmt = $pdo->prepare('INSERT INTO schema_migrations (versao, duracao_ms) VALUES (:v, :d)');
        $stmt->execute([':v' => $arquivo, ':d' => (int)((microtime(true) - $inicio) * 1000)]);
        $log[] = "OK  {$arquivo}";
    } catch (PDOException $e) {
        error_log("[migracao] {$arquivo}: " . $e->getMessage());
        $log[] = "FALHA {$arquivo}: " . $e->getMessage();
        throw new FalhaNaAtualizacao("A migração {$arquivo} falhou. Restaurando backup.");
    }
}
```

---

## 5. Backup e rollback

**Antes** de tocar em qualquer arquivo:

```
storage/backups/2026-09-05-142031-v1.2.0/
├── banco.sql            # dump completo
├── arquivos.zip         # só os arquivos que serão sobrescritos ou removidos
└── manifest-anterior.json
```

Sem `mysqldump` disponível (comum em shared hosting), gere o dump em PHP: `SHOW TABLES`,
`SHOW CREATE TABLE`, e os `INSERT` em lotes, com `mysqli_real_escape` **de valores**:
aqui é geração de dump, não consulta, e a saída é um arquivo, não uma query executada.

O rollback automático cobre o que é reversível:

| Etapa que falhou | Ação automática |
| --- | --- |
| Validação (1 a 3) | Nada foi tocado. Descarta o ZIP temporário. |
| Arquivos (6) | Restaura `arquivos.zip` sobre o destino; desliga manutenção. |
| Migrações (7) | Restaura arquivos **e** `banco.sql`; desliga manutenção. |

E o que não é automático é dito com todas as letras: *"o banco foi restaurado a partir de
`storage/backups/2026-09-05-142031-v1.2.0/banco.sql`; se houve escrita de usuários entre o
backup e a falha, ela se perdeu, por isso o modo manutenção é ligado antes."*

Guarde os últimos N backups (3 é um bom padrão) e apague os mais antigos, senão a cota do
plano estoura em silêncio.

---

## 6. Modo manutenção

```php
// Liga: um arquivo, lido pelo bootstrap
file_put_contents(STORAGE_PATH . '/manutencao.flag', json_encode([
    'iniciado_em' => date('c'),
    'por'         => $_SESSION['usuario_id'],
    'token'       => bin2hex(random_bytes(16)),      // permite ao admin continuar navegando
]));
```

```php
// bootstrap.php
if (is_file(STORAGE_PATH . '/manutencao.flag') && !ehAdminComToken()) {
    http_response_code(503);
    header('Retry-After: 120');
    require __DIR__ . '/Views/manutencao.php';
    exit;
}
```

Se a atualização morrer no meio (timeout do PHP), o flag fica para trás e o site permanece
fora do ar. Duas defesas: **carimbo de tempo com expiração automática** (ex.: 15 minutos) e
um botão "Sair do modo manutenção" no painel.

---

## 7. Segurança do painel de atualização

Este é o recurso mais perigoso do app: ele grava arquivos PHP no servidor. Um invasor com
acesso aqui tem execução remota de código.

- [ ] Rota exige autenticação **e** papel `admin`, verificado no servidor, em toda requisição
- [ ] Token CSRF no formulário de upload e na confirmação
- [ ] Reautenticação (pedir a senha novamente) antes de aplicar, como um `sudo`
- [ ] Limite de tamanho do ZIP, conferido no PHP e no servidor
- [ ] `manifest.json` obrigatório; pacote sem ele é recusado
- [ ] `sha256` conferido para todo arquivo antes de qualquer escrita
- [ ] Allowlist de extensões e de pastas de destino
- [ ] Proteção contra *zip slip* em cada entrada, uma a uma
- [ ] ZIP temporário fora do webroot, apagado ao final (inclusive em erro)
- [ ] Nenhuma escrita permitida em `config/` ou `storage/`
- [ ] Registro de auditoria: quem, quando, qual versão, qual resultado
- [ ] Falha restaura o backup e informa o caminho dele
- [ ] Modo manutenção ligado antes e desligado depois, com expiração automática
- [ ] MFA no painel administrativo quando o app é N3/N4 (R7)

---

## 8. O que testar (entra no roteiro de QA, R11)

| Caso | Resultado esperado |
| --- | --- |
| Pacote válido, versão seguinte | Arquivos atualizados, migrações aplicadas, versão nova exibida |
| Mesmo pacote instalado duas vezes | Recusa: "versão igual ou anterior à instalada" |
| Pacote de outro app | Recusa antes de qualquer escrita |
| Pacote pulando versão (1.1.0 → 1.3.0 com mínima 1.2.0) | Recusa com instrução do que instalar antes |
| ZIP corrompido / truncado | Recusa na validação; nenhum arquivo tocado |
| `sha256` divergente em um arquivo | Recusa; nenhum arquivo tocado |
| Entrada `../../config/app.config.php` no ZIP | Recusa com "caminho inválido"; nada escrito |
| Entrada `shell.php.jpg` ou `.htaccess` | Recusa por extensão/pasta não permitida |
| Migração com erro de SQL no meio | Rollback de arquivos e banco; relatório aponta o arquivo |
| Upload por usuário não-admin | 403, e a tentativa registrada no log de auditoria |
| Upload sem token CSRF | 419/403 |
| Timeout durante a aplicação | Modo manutenção expira; painel oferece sair dele |
| Espaço em disco insuficiente | Falha detectada antes da escrita, com mensagem clara |
