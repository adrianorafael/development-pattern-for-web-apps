# Instruções para agentes de IA: <Nome do App>

Coloque este arquivo como `AGENTS.md` na raiz do repositório do aplicativo. Ele é a memória
que a próxima sessão não tem.

## Siga o padrão de desenvolvimento

Este projeto é construído sob o
**[Development Pattern for Web Apps](https://github.com/adrianorafael/development-pattern-for-web-apps)**.
Carregue essa skill antes de escrever, revisar, testar, publicar ou implantar qualquer
código aqui.

As dezessete regras inegociáveis valem para toda mudança neste repositório, inclusive as
"minúsculas":

1. **R1**: Nenhum segredo no repositório. Credencial, chave de API, `.env`, dump: nunca.
2. **R2**: Repositório privado por padrão.
3. **R3**: Especificação antes do código, com portão de aprovação.
4. **R4**, Nunca inventar API: verificar em `vendor/`, `node_modules/` ou na doc oficial.
5. **R5**: Todo SQL parametrizado. Zero concatenação. Identificador só por allowlist.
6. **R6**: Validar na entrada, escapar na saída.
7. **R7**: O piso de segurança vale sempre; acima dele, proporcional ao porte.
8. **R8**: Interface por componentes; nada de HTML copiado e colado.
9. **R9**: Wizard de instalação em todo app PHP+MySQL.
10. **R10**: Painel administrativo que instala pacotes ZIP de atualização.
11. **R11**: Roteiro de testes para o Claude Cowork em toda entrega.
12. **R12**: Revisar código de IA como código hostil, antes de todo push.
13. **R13**: Versão, documentação e schema andam juntos.
14. **R14**: Deploy explícito, nomeado e reversível.
15. **R15**: A URL é interface: rota semântica em português, nunca caminho de arquivo.
16. **R16**: Build quebrado: log na mão, correção provada localmente, teto de três voltas.
17. **R17**: Texto na língua de quem usa. Travessão proibido. Corpo justificado.

## Este projeto especificamente

| | |
| --- | --- |
| **Trilha** | PHP 8.2 + MySQL 8.0 (Hostinger) · Next.js 15 + Tailwind 4 (Vercel) |
| **Repositório** | privado, `github.com/<usuario>/<repo>` |
| **Produção** | `https://seu-dominio.com.br` |
| **Nível de segurança (R7)** | N2: área logada, dados dos próprios usuários |
| **Versão** | `<app/version.php \| package.json>` é a fonte da verdade |
| **Schema** | tabela `schema_migrations` diz até onde o banco está |
| **Configuração** | `config/app.config.php`, fora do webroot, gerado pelo Wizard |
| **Prefixo de tabelas** | `<vazio ou app_>` |
| **Projeto Vercel** | `<nome>`, token em `.env`, nunca versionado |
| **Domínio e público (R17)** | `<banco / ITSM / saúde / interno>`, lendo `<quem>` |
| **Atribuição de IA em commits** | `<sim, com Co-Authored-By \| não>`, seja consistente |

## Convenções deste repositório

- Nomes de tabelas, colunas, classes e variáveis em **português**.
- Toda saída passa por `e()`; nenhum `echo` cru de dado do banco.
- Toda consulta usa `Database::` (`app/Core/Database.php`), nunca `new PDO` avulso.
- Partials em `app/Views/partials/`; se um bloco aparece duas vezes, vira partial.
- Migrações em `database/migrations/NNNN_descricao.sql`, idempotentes.
- URLs em português e kebab-case, sem extensão: `/cadastrar-novo-usuario`. O mapa de
  rotas fica em `<public_html/index.php | app/>`; rota renomeada mantém 301 da antiga.
- Specs em `specs/`; roteiro de QA em `qa/roteiro-de-testes.md`.

## Armadilhas já encontradas aqui

<Registre cada uma quando aparecer, para a próxima sessão começar adiantada.>

- A Hostinger serve o site com PHP 8.2, mas o SSH reporta 8.0: confira sempre por uma
  página real, não pelo terminal.
- `exec()` e `shell_exec()` estão em `disable_functions`: o backup do banco é gerado em
  PHP puro, não com `mysqldump`.
- `max_execution_time` é 30 s: migrações longas precisam rodar em lotes.

## Comandos

```bash
# PHP
find . -name '*.php' -not -path './vendor/*' -print0 | xargs -0 -n1 php -l
composer install --no-dev --optimize-autoloader
composer audit

# Next.js
npx tsc --noEmit && npm run lint && npm test && npm run build
npm audit --omit=dev

# Sempre, antes de qualquer push
bash skills/development-pattern-for-web-apps/assets/scripts/scan-secrets.sh
bash skills/development-pattern-for-web-apps/assets/scripts/scan-sql-injection.sh
bash skills/development-pattern-for-web-apps/assets/scripts/scan-linguagem.sh
```

## O que NUNCA fazer aqui

- Enviar `.env`, `config/app.config.php`, dumps `.sql` ou `storage/uploads/` ao repositório.
- Fazer deploy sem aprovação explícita e sem nomear o alvo.
- Rodar migração em produção sem backup verificado.
- Publicar com defeito de severidade 🔴 em aberto no roteiro de QA.
- Tornar o repositório público sem varrer o histórico completo.
