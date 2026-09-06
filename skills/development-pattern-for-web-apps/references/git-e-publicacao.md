# Git e publicação: privado por padrão

> Regra **R2**. Todo projeto nasce privado. Tornar público é uma decisão consciente,
> tomada projeto a projeto, e só depois de varrer **o histórico inteiro**, não apenas o
> estado atual dos arquivos.

---

## 1. Criando o repositório

```bash
gh repo create meu-projeto --private --source=. --remote=origin
```

Sem `gh` disponível, crie pelo site com a opção **Private** marcada antes do primeiro push.

**Sempre confirme depois de criar**, não confie na intenção:

```bash
gh repo view --json name,visibility,isPrivate
# isPrivate deve ser true
```

Se o agente criou o repositório e não consegue confirmar a visibilidade, ele **diz isso**
antes de dar push, em vez de assumir.

### Ordem que evita o acidente clássico

O erro mais comum não é escolher "público": é dar o primeiro `git add .` antes de existir
`.gitignore`. Faça nesta ordem, sempre:

```bash
git init
cp .../gitignore.php.template .gitignore      # 1. ignorar ANTES de adicionar
cp .../env.example.template   .env.example    # 2. o par de configuração
bash .../scan-secrets.sh                      # 3. varrer o que existe em disco
git add -A && git status --short              # 4. LER a lista antes de commitar
git commit -m "chore: estrutura inicial do projeto"
gh repo create meu-projeto --private --source=. --remote=origin --push
```

---

## 2. De privado para público: a lista curta

Antes de mudar a visibilidade de qualquer repositório:

1. **Varra o histórico completo, não o working tree:**

   ```bash
   git log --all --full-history --patch | \
     bash skills/development-pattern-for-web-apps/assets/scripts/scan-secrets.sh --stdin
   ```

2. **Procure arquivos que já existiram e foram removidos:**

   ```bash
   git log --all --diff-filter=D --name-only --pretty=format: | sort -u | \
     grep -Ei '\.env|config\.local|\.sql$|\.pem$|backup'
   ```

   Um `.env` deletado há dez commits continua no histórico e continua legível.

3. **Se houver qualquer achado: rotacione a credencial primeiro**, depois decida entre
   limpar o histórico ou começar um repositório novo (`git checkout --orphan`).
4. **Reveja README, issues e capturas de tela**: nome de cliente, domínio interno,
   e-mail real, URL com token.
5. **Confirme com o usuário, explicitamente**, que ele quer aquele repositório específico
   público. Nunca por inferência.
6. Depois de público: ligue *Settings → Code security → Secret scanning* e *Push protection*
   (gratuitos em repositório público).

---

## 3. Mensagens de commit

[Conventional Commits](https://www.conventionalcommits.org/), em português, no imperativo:

```
feat(chamados): permitir anexar arquivo ao chamado
fix(login): rejeitar sessão expirada antes de renderizar o painel
fix(sql): parametrizar filtro de busca da listagem de pedidos
chore(deps): atualizar dependências com vulnerabilidade reportada
docs: descrever a instalação na Hostinger passo a passo
refactor(db): extrair a fábrica de conexão PDO para src/Database.php
test(qa): adicionar casos de regressão CT-REG-004 a CT-REG-007
```

O corpo responde **por quê**, não *o quê*: o diff já mostra o quê:

```
fix(sql): parametrizar filtro de busca da listagem de pedidos

O filtro concatenava $_GET['q'] direto no WHERE. Com aspa simples no termo,
a query quebrava; com ' OR '1'='1, retornava a base inteira, inclusive
pedidos de outros usuários.

Reescrito com prepared statement e escape dos curingas de LIKE.
Casos CT-SEC-011 e CT-SEC-012 cobrem o cenário no roteiro de QA.
```

**Um commit, um assunto.** "várias correções" é um commit que ninguém consegue reverter.

### Atribuição de IA: nenhuma

> Regra **R18**. O histórico do projeto não menciona a ferramenta que ajudou a escrever,
> do mesmo jeito que não menciona o editor de texto.

Nada disto entra em commit, pull request, README, página, `CHANGELOG` ou comentário de código:

```
Co-Authored-By: Claude <noreply@anthropic.com>     ❌
🤖 Generated with Claude Code                       ❌
Claude-Session: https://claude.ai/code/...          ❌
Assisted-By: Copilot                                ❌
// gerado automaticamente por IA                    ❌
```

O projeto é de quem o assina. Creditar a ferramenta no histórico é ruído que não ajuda
ninguém a entender a mudança, aparece em toda listagem de commits e, num repositório que um
dia vira público, vira a primeira coisa que alguém repara.

**Não basta o agente lembrar.** Alguns ambientes acrescentam o trailer **automaticamente**,
depois que a mensagem foi escrita. Por isso a defesa é mecânica, e são duas camadas:

1. **Desligue na configuração do seu ambiente**, se ele tiver essa opção. No Claude Code a
   chave fica em `settings.json`; confirme o nome exato na documentação da sua versão (R4).
2. **Instale o hook**, que pega o que passar da configuração:

```bash
cp skills/development-pattern-for-web-apps/assets/templates/commit-msg.template \
   .git/hooks/commit-msg
chmod +x .git/hooks/commit-msg
```

O hook roda depois de a mensagem estar pronta, que é exatamente onde o trailer automático
aparece. Ele recusa o commit e mostra a linha ofensora.

### Auditar o que já foi commitado

```bash
git log --format='%h %s' --grep='Co-Authored-By' --grep='Generated with' --grep='Claude-Session'
git log --all --format='%b' | grep -inE 'co-authored-by|generated with|claude\.ai/code'
```

Encontrou em histórico já publicado? Limpar exige reescrever o histórico
(`git filter-repo --message-callback`), o que muda todos os hashes. Num repositório pessoal
sem forks o custo é baixo; ainda assim é decisão sua, e vale mais impedir daqui para a frente
do que reescrever o passado.

---

## 4. Ramos

Projeto pessoal não precisa de GitFlow. Precisa de uma linha estável.

```
main            sempre implantável, o que está (ou pode estar) em produção
feat/<slug>     uma funcionalidade, aberta a partir de main
fix/<slug>      uma correção
```

- Nunca faça commit direto em `main` de algo que não passou pela Fase 4 (validação).
- Só faça merge com o `scan-secrets.sh` limpo e o roteiro de QA verde para os casos que
  cobrem a mudança.
- `git push --force` em `main`: nunca. Em ramo de trabalho seu: use `--force-with-lease`.

---

## 5. O que nunca é versionado

```
.env, .env.local, .env.production, config.local.php     credenciais
*.sql, *.sql.gz, dumps/, backups/                       dados reais de usuários
node_modules/, vendor/                                  reprodutível pelo lockfile
.next/, out/, dist/, build/                             artefato de build
uploads/, storage/, public/uploads/                     conteúdo enviado por usuários
*.log, error_log                                        pode conter dado sensível
.ftpconfig, sftp.json, .vscode/sftp.json                credencial de FTP
.DS_Store, Thumbs.db                                    lixo de sistema
```

**Versione os lockfiles** (`composer.lock`, `package-lock.json`): eles são o que torna a
instalação reproduzível e o que permite auditar dependências.

**`uploads/` ignorado, mas a pasta precisa existir** no servidor. Versione um
`uploads/.gitkeep` e documente as permissões no README.

---

## 6. Checklist antes de todo push

- [ ] `git status --short` lido, linha por linha: nada inesperado no staging
- [ ] `git diff --cached` lido pelo agente, não só rodado
- [ ] `scan-secrets.sh --stdin` limpo sobre o conteúdo staged
- [ ] `scan-sql-injection.sh` limpo
- [ ] Checklist de revisão (R12) executado
- [ ] Versão subida, CHANGELOG e README atualizados no mesmo commit (R13)
- [ ] Visibilidade do repositório confirmada como privada (ou público consciente)
- [ ] ⛔ Aprovação do usuário obtida, com a versão nomeada
