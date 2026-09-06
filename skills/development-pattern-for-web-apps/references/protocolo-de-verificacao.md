# Protocolo de verificação: provar, não lembrar

> Regra **R4**. Uma função, prop, classe ou opção só entra no código depois de verificada
> contra o que está realmente instalado ou contra a documentação oficial lida nesta sessão.

O modelo tem memória de treinamento. A memória de treinamento é uma média de versões, e a
média não compila. `str_contains()` não existe em PHP 7. `bg-opacity-50` foi removido no
Tailwind v4. `next/router` não funciona no App Router. Cada um desses erros parece código
correto até o momento em que não é.

---

## 1. A hierarquia de fontes

Do mais confiável para o menos. **Sempre desça o mínimo possível.**

| Nível | Fonte | Quando usar |
| --- | --- | --- |
| 1 | O código instalado no projeto: `vendor/`, `node_modules/**/*.d.ts` | Sempre que o pacote estiver instalado. É a verdade absoluta para **este** projeto. |
| 2 | O runtime local: `php -v`, `php -m`, `node -v`, `composer show`, `npm ls` | Para saber o que existe no ambiente, não o que deveria existir |
| 3 | Documentação oficial da versão instalada | Quando o pacote não está instalado, ou para semântica que o `.d.ts` não expressa |
| 4 | Changelog / notas de migração do projeto upstream | Quando a dúvida é "mudou entre versões?" |
| 5 | Memória do modelo | **Nunca sozinha.** Serve para levantar a hipótese que os níveis 1 a 4 confirmam. |

---

## 2. Comandos de verificação por situação

### PHP

```bash
php -v                                  # versão real: decide o que é sintaxe válida
php -m                                  # extensões: pdo_mysql, mbstring, zip, gd, intl…
php -i | grep -i 'upload_max\|post_max\|memory_limit\|max_execution'
php -r 'var_dump(function_exists("str_contains"));'    # a função existe AQUI?
composer show                           # o que está no vendor/
composer show vendor/pacote             # versão exata e dependências
grep -m1 '"php"' composer.json          # a restrição de versão declarada pelo projeto
```

Na Hostinger, a versão do PHP do hPanel pode diferir da do SSH. Verifique **a que serve o
site**:

```php
<?php echo PHP_VERSION, PHP_EOL; print_r(get_loaded_extensions());
```

### Next.js / React / Tailwind

```bash
node -v && npm -v
grep -E '"(next|react|tailwindcss|typescript)"' package.json    # versões declaradas
npm ls next react tailwindcss                                    # versões resolvidas
ls node_modules/next/dist/                                       # a API que existe aqui
grep -rn "export declare function" node_modules/next/types/*.d.ts | head
cat tailwind.config.* 2>/dev/null || cat app/globals.css | head -30   # v3 vs v4
```

**Tailwind v3 vs v4 é a armadilha recorrente:** v3 usa `tailwind.config.js` e diretivas
`@tailwind`; v4 usa `@import "tailwindcss"` e configuração em CSS com `@theme`. Descubra
qual antes de escrever a primeira classe.

### MySQL

```bash
mysql --version
mysql -e "SELECT VERSION();"
mysql -e "SHOW VARIABLES LIKE 'sql_mode';"      # ONLY_FULL_GROUP_BY muda o que é query válida
mysql -e "SHOW CREATE TABLE chamados\G"          # o schema real, não o que a spec diz
```

MySQL 5.7 e 8.0 diferem em CTEs, funções de janela, `utf8mb4` como padrão e reserva de
palavras. MariaDB não é MySQL: `JSON_TABLE`, alguns aspectos de CTE e a sintaxe de
`RETURNING` divergem. Confirme qual está na Hostinger antes de usar recurso moderno.

---

## 3. O registro de evidências

Toda spec carrega uma tabela assim. Uma afirmação sem linha aqui não entra na spec:

| Afirmação | Fonte | Verificado |
| --- | --- | --- |
| PHP 8.2 disponível na Hostinger | `php -v` no SSH → `PHP 8.2.18` | ✅ 2026-09-05 |
| Extensão `zip` presente (para o instalador de pacotes) | `php -m` lista `zip` | ✅ 2026-09-05 |
| `password_hash` usa bcrypt por padrão em PHP 8.2 | php.net/manual/pt_BR/function.password-hash.php | ✅ 2026-09-05 |
| Tailwind v4 neste projeto | `package.json` → `"tailwindcss": "^4.0.0"` | ✅ 2026-09-05 |
| Server Actions exigem `'use server'` no topo | nextjs.org/docs/app/api-reference/directives/use-server | ✅ 2026-09-05 |
| Neon exige `sslmode=require` | neon.tech/docs/connect/connect-from-any-app | ✅ 2026-09-05 |

Data importa: a documentação muda. Uma evidência de três meses atrás merece nova checagem
quando o comportamento surpreende.

---

## 4. Diga "não sei" em voz alta

Quando o pacote não está instalado e a documentação está inacessível, a saída correta é:

> Não consigo verificar se `ZipArchive::setPassword()` está disponível neste ambiente:
> a extensão `zip` não aparece em `php -m` e não tenho acesso à doc agora.
> Duas formas de destravar: rodar `php -m | grep zip` no servidor da Hostinger, ou me
> confirmar a versão do PHP configurada no hPanel. Enquanto isso, o instalador de pacotes
> não pode assumir suporte a ZIP com senha.

Isso é mais útil que uma chamada plausível que falha em produção às duas da manhã.

---

## 5. Armadilhas conhecidas por stack

| Afirmação comum | Realidade a verificar |
| --- | --- |
| "`mysqli_real_escape_string` protege contra injeção" | **Não.** Falha em contexto numérico, em `LIKE` e com charset. Use prepared statements (R5). |
| "`PDO` já vem seguro" | Só com `ATTR_EMULATE_PREPARES => false`. O padrão é `true`. |
| "`FILTER_VALIDATE_EMAIL` garante que o e-mail existe" | Valida formato, não existência nem entrega. |
| "`md5()`/`sha1()` servem para senha" | **Não.** `password_hash()` / `password_verify()`. |
| "`$_SERVER['HTTP_X_FORWARDED_FOR']` é o IP do cliente" | É cabeçalho, o cliente controla. Só confie atrás de proxy que você configurou. |
| "`htmlspecialchars()` cobre todos os contextos" | Cobre HTML. Atributo sem aspas, JS e URL precisam de tratamento próprio. |
| "Server Components podem usar `useState`" | Não. Precisa de `'use client'`. |
| "`process.env.X` funciona no navegador" | Só com prefixo `NEXT_PUBLIC_`, e aí é público. |
| "Server Action é privada porque não aparece no bundle" | É um endpoint HTTP público. Valide entrada e autorização dentro dela. |
| "Tailwind aceita classe montada em runtime" | Não: `text-${cor}-500` não é gerado. Use mapa de classes completas. |
| "`revalidatePath` atualiza na hora em qualquer caso" | Depende de cache, runtime e rota. Verifique na doc da sua versão. |
| "A Hostinger deixa rodar `exec()`/`shell_exec()`" | Frequentemente desabilitado. Cheque `disable_functions` em `php -i`. |
| "Cron da Hostinger tem resolução de minuto para qualquer plano" | Depende do plano. Confirme no hPanel antes de projetar em cima disso. |

---

## 6. Quando duas formas parecem plausíveis

Use a que o código instalado prova, mesmo que a outra pareça mais elegante. E registre a
escolha:

```
Considerei `readonly` em propriedade promovida (PHP 8.1+). `composer.json` declara
"php": "^8.0", e o SSH da Hostinger reporta 8.0.30: então uso propriedade privada
com getter. Se a versão subir para 8.2 no hPanel, esta escolha pode ser revista.
```
