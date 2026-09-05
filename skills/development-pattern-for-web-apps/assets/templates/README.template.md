# <Nome do App>

> Modelo de `README.md` para um aplicativo construído sob o
> **[Development Pattern for Web Apps](https://github.com/adrianorafael/development-pattern-for-web-apps)**.
> Regra **R13**: este arquivo muda no mesmo commit que muda o comportamento.

<Uma frase dizendo o que o aplicativo faz e para quem.>

**Versão:** 1.3.0 · **Repositório:** privado (R2)

---

## Índice

1. [O que é](#o-que-é)
2. [Requisitos](#requisitos)
3. [Instalação](#instalação)
4. [Configuração](#configuração)
5. [Como usar](#como-usar)
6. [Atualização](#atualização)
7. [Backup e restauração](#backup-e-restauração)
8. [Estrutura do projeto](#estrutura-do-projeto)
9. [Desenvolvimento](#desenvolvimento)
10. [Testes](#testes)
11. [Segurança](#segurança)
12. [Solução de problemas](#solução-de-problemas)

---

## O que é

<Dois ou três parágrafos: o problema que resolve, quem usa, o que ele deliberadamente não faz.>

**Não faz:** <lista curta — evita expectativa errada e defeito falso no QA.>

---

## Requisitos

### Trilha PHP + MySQL (Hostinger)

| Item | Mínimo | Observação |
| --- | --- | --- |
| PHP | 8.1 | Verificado pelo instalador |
| Extensões | `pdo_mysql`, `mbstring`, `json`, `openssl`, `fileinfo`, `zip` | `zip` é do painel de atualização |
| MySQL / MariaDB | 5.7 / 10.4 | `utf8mb4` obrigatório |
| Apache | com `mod_rewrite` | Front controller |
| Escrita | `config/`, `storage/uploads/`, `storage/logs/`, `storage/backups/` | |
| HTTPS | obrigatório | SSL gratuito no hPanel |

### Trilha Next.js (Vercel)

| Item | Mínimo |
| --- | --- |
| Node.js | 20 |
| Banco | PostgreSQL (Neon/Supabase) ou MySQL gerenciado |
| Conta | Vercel (plano gratuito serve) |

---

## Instalação

### PHP na Hostinger

1. **Crie o banco** — hPanel → Bancos de dados → MySQL. Anote nome, usuário e senha.
2. **Envie os arquivos** para `public_html/` (Git, FTP ou upload de ZIP).
   Não envie: `.git/`, `.env`, `tests/`, `specs/`, `qa/`, `node_modules/`.
3. **Confira as permissões:** `config/` e `storage/` graváveis (755).
4. **Abra `https://seu-dominio.com.br/install/`** e siga os cinco passos:

   | Passo | O que faz |
   | --- | --- |
   | 1 · Requisitos | Verifica PHP, extensões, permissões e HTTPS, com instrução por item |
   | 2 · Banco | Testa a conexão na hora e traduz o erro do MySQL |
   | 3 · Estrutura | Cria as tabelas, ou limpa e recria se a base já tiver dados |
   | 4 · Administrador | Cria o primeiro usuário admin |
   | 5 · Conclusão | Grava a configuração, registra o schema e tranca o instalador |

5. **Apague a pasta `install/`** do servidor. O painel avisa enquanto ela existir.

> O instalador cria as **tabelas** dentro de uma base que já existe. Ele não cria a base:
> em hospedagem compartilhada o usuário não tem permissão de `CREATE DATABASE`.

### Next.js na Vercel

```bash
git clone git@github.com:<usuario>/<repo>.git && cd <repo>
npm install
cp .env.example .env.local     # preencha os valores
npm run db:migrate
npm run dev
```

Publicação: importe o repositório na Vercel, defina as variáveis em
**Settings → Environment Variables** (por ambiente) e faça deploy.

---

## Configuração

| Chave | Onde | O que colocar |
| --- | --- | --- |
| `DB_HOST` | `config/app.config.php` (gerado pelo instalador) | `localhost` na Hostinger |
| `DB_NAME` / `DB_USER` / `DB_PASSWORD` | idem | hPanel → Bancos de dados → MySQL |
| `APP_KEY` | idem | Gerado automaticamente pelo instalador |
| `DATABASE_URL` | Painel da Vercel | String de conexão do provedor, com `sslmode=require` |
| `AUTH_SECRET` | Painel da Vercel | `openssl rand -base64 32` |

> ⚠️ Nenhum desses valores fica no repositório (R1). `config/app.config.php` está no
> `.gitignore` e, quando possível, fica fora do `public_html`.

---

## Como usar

<Fluxos principais, com o caminho de tela. Uma seção por módulo.>

### Rotas

| URL | O que é |
| --- | --- |
| `/` | Início |
| `/entrar` | Login |
| `/cadastrar-novo-usuario` | Cadastro |
| `/chamados` | Lista de chamados (aceita `?status=`, `?ordenar=`, `?pagina=`) |
| `/abrir-chamado` | Formulário de novo chamado |
| `/chamados/{id}` | Detalhe |
| `/administracao` | Painel administrativo |
| `/administracao/atualizacoes` | Instalação de pacotes de atualização |

<Quando uma rota for renomeada, mantenha a antiga respondendo 301 e registre no CHANGELOG.>

---

## Atualização

Pelo **painel administrativo** (forma preferida — faz backup, valida e sabe voltar atrás):

1. **Administração → Atualizações**.
2. Envie o arquivo `<app>-<versão>.zip`.
3. Revise a prévia: versão atual → nova, arquivos que mudam, migrações a executar.
   Migrações destrutivas aparecem destacadas.
4. Confirme. O sistema entra em manutenção, faz backup, aplica arquivos e migrações, e sai.
5. Confira a nova versão no rodapé.

Se algo falhar, o sistema restaura o backup automaticamente e informa o caminho dele.

Na Vercel: `git push` no ramo → preview → QA → merge em `main`.

---

## Backup e restauração

**Antes de toda atualização** o painel gera:

```
storage/backups/<AAAA-MM-DD-HHMMSS>-v<versão>/
├── banco.sql
├── arquivos.zip
└── manifesto-anterior.json
```

Restaurar manualmente:

1. Ligar o modo manutenção (Administração → Manutenção).
2. Restaurar `arquivos.zip` sobre a raiz do aplicativo.
3. Importar `banco.sql` pelo phpMyAdmin.
4. Conferir a última linha de `schema_migrations`.
5. Desligar a manutenção e rodar a suíte de fumaça do roteiro de QA.

> Um backup nunca restaurado não é um backup. Teste a restauração ao menos uma vez.

---

## Estrutura do projeto

```
<cole aqui a árvore real do projeto>
```

---

## Desenvolvimento

Este projeto segue o
[Development Pattern for Web Apps](https://github.com/adrianorafael/development-pattern-for-web-apps).
Antes de qualquer mudança, leia `AGENTS.md` — ele traz as convenções e as armadilhas já
encontradas aqui.

```bash
# PHP
find . -name '*.php' -not -path './vendor/*' -print0 | xargs -0 -n1 php -l
composer audit

# Next.js
npx tsc --noEmit && npm run lint && npm test && npm run build

# Sempre, antes de qualquer push
bash skills/development-pattern-for-web-apps/assets/scripts/scan-secrets.sh
bash skills/development-pattern-for-web-apps/assets/scripts/scan-sql-injection.sh
```

---

## Testes

O roteiro completo está em [`qa/roteiro-de-testes.md`](qa/roteiro-de-testes.md) — escrito
para ser executado pelo **Claude Cowork** ou por uma pessoa, sem conhecimento prévio do
código.

| Suíte | Casos | Roda quando |
| --- | --- | --- |
| Fumaça | 6 | Toda execução, primeiro |
| Funcional | 34 | Antes de todo release |
| Integração | 9 | Antes de todo release |
| Segurança | 30 | Antes de todo release |
| Interface | 12 | Antes de todo release |
| Regressão | 7 | Antes de todo release, inteira |

Credenciais e seed: [`qa/dados-de-teste.md`](qa/dados-de-teste.md).
**Nunca execute a suíte de segurança contra produção.**

---

## Segurança

Nível **N2** (área logada, dados dos próprios usuários) — ver R7 do padrão.

- Todas as consultas SQL são parametrizadas (prepared statements).
- Senhas com `password_hash()`; nunca `md5`/`sha1`.
- Token CSRF em toda ação que muda estado.
- Autorização verificada por registro: o dono entra na cláusula `WHERE`.
- Uploads validados por tipo real, com nome gerado, fora do webroot, sem execução.
- Cabeçalhos de segurança configurados no `.htaccess` / `next.config.ts`.
- Nenhuma credencial no repositório.

**Encontrou uma falha?** Abra uma issue privada ou escreva para `<contato>`. Não publique
detalhes antes da correção.

---

## Solução de problemas

| Sintoma | Causa provável | O que fazer |
| --- | --- | --- |
| Página em branco | Erro de PHP com `display_errors` desligado | Ver `storage/logs/php-error.log` |
| "Não foi possível conectar ao banco" | Credencial errada, ou base não criada | Conferir no hPanel → Bancos de dados |
| Redireciona para `/install/` | `config/app.config.php` ausente | Refazer a instalação, ou restaurar a config |
| "Este aplicativo já está instalado" | `config/instalado.lock` existe | Apagar o arquivo via FTP para reinstalar |
| URLs amigáveis dão 404 | `.htaccess` não enviado, ou sem `mod_rewrite` | Reenviar o `.htaccess`; conferir o plano |
| Upload falha em arquivo grande | `upload_max_filesize` do servidor | hPanel → Configuração PHP |
| Acentos aparecem errados | Base não é `utf8mb4` | Converter a base e as colunas |
| Site preso em manutenção | Atualização interrompida | Administração → Sair da manutenção, ou apagar `storage/manutencao.flag` |

---

## Licença

<MIT / proprietária / uso pessoal>
