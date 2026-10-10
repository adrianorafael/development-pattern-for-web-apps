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
cp .../gitignore.nextjs.template .gitignore   # 1. ignorar ANTES de adicionar
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

Não espere o repositório virar público para ter push protection. Em repositório privado,
a push protection do repositório "requires GitHub Secret Protection to be enabled"
(docs.github.com/en/code-security/secret-scanning/introduction/about-push-protection,
conferido em 2026-10-10): se o plano da conta ou da organização tiver, ligue desde o
primeiro push. Ela bloqueia o push que contém um segredo reconhecido; quem tem permissão
de escrita pode contornar o bloqueio informando um motivo, e cada contorno gera um alerta.
É uma camada a mais, não substitui o `scan-secrets.sh` no hook.

---

## 3. Mensagens de commit

[Conventional Commits](https://www.conventionalcommits.org/), em português, no imperativo:

```
feat(chamados): permitir anexar arquivo ao chamado
fix(login): rejeitar sessão expirada antes de renderizar o painel
fix(sql): parametrizar filtro de busca da listagem de pedidos
chore(deps): atualizar dependências com vulnerabilidade reportada
docs: descrever como subir o app do zero com vercel env pull
refactor(db): concentrar o acesso ao Postgres em lib/db.ts
test(qa): adicionar casos de regressão CT-REG-004 a CT-REG-007
```

O corpo responde **por quê**, não *o quê*: o diff já mostra o quê:

```
fix(sql): parametrizar filtro de busca da listagem de pedidos

O filtro concatenava searchParams.q direto no WHERE, numa consulta com
sql.unsafe(). Com aspa simples no termo, a query quebrava; com ' OR '1'='1,
retornava a base inteira, inclusive pedidos de outros usuários.

Reescrito com a template tag sql`...` e escape dos curingas de LIKE.
Casos CT-SEC-011 e CT-SEC-012 cobrem o cenário no roteiro de QA.
```

**Um commit, um assunto.** "várias correções" é um commit que ninguém consegue reverter.

### Passos pequenos, um commit a cada passo verde

Com um agente escrevendo código, o risco não é só o commit grande: é a sessão longa em que
quarenta arquivos mudam antes de alguém olhar. Quando algo quebra no meio, não existe ponto
de volta, e o diff é grande demais para ser lido de verdade (R12).

- **Fatie a tarefa antes de começar.** Cada fatia cabe num commit que se descreve numa
  linha: a migração, depois a Server Action, depois a tela, depois os casos de teste.
- **Commite a cada passo verde.** Passo verde é `npm run build` e os testes da fatia
  passando. Esse commit é o ponto de volta: se o próximo passo der errado,
  `git restore .` (descarta o que não foi commitado) ou `git revert <hash>` (desfaz um
  commit já feito) devolvem o projeto a um estado que funcionava.
- **Não acumule.** Se o diff não commitado passou de algumas centenas de linhas ou de um
  punhado de arquivos, pare, verifique e commite o que está verde antes de seguir.
- **Ramo de trabalho, não `main`.** Os commits pequenos vivem em `feat/<slug>` e chegam a
  `main` pelo merge, depois da validação (§4).

```
❌ Uma sessão inteira, um commit no fim:
   feat: anexos, ajustes no login, refatoração do db e correções diversas

✅ Fatias, cada uma verde e reversível sozinha:
   feat(db): criar tabela anexos com RLS por dono
   feat(anexos): Server Action que envia ao Storage com tipo e tamanho validados
   feat(anexos): lista de anexos na tela do chamado
   test(qa): casos CT-SEC-033 e CT-REG-012 para anexos
```

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

1. **Desligue na configuração do seu ambiente.** No Claude Code é o bloco `attribution` em
   `settings.json`, com três campos independentes. String vazia esconde o texto; `sessionUrl`
   controla o link de sessão que sessões web e de Remote Control acrescentam por conta
   própria:

   ```json
   {
     "attribution": {
       "commit": "",
       "pr": "",
       "sessionUrl": false
     }
   }
   ```

   Os três precisam estar lá. Zerar só `commit` deixa o corpo do pull request assinado, e
   zerar os dois primeiros ainda deixa passar o trailer `Claude-Session:` quando o commit
   nasce numa sessão web. Existe também `includeCoAuthoredBy: false`, mais antigo e marcado
   como obsoleto no schema: ele cobre commit e pull request de uma vez, mas não o link de
   sessão. Prefira o bloco acima.

   O arquivo vai em `~/.claude/settings.json` para valer em todos os seus projetos, ou em
   `.claude/settings.json` dentro do repositório para valer só nele. Confirme os nomes contra
   o schema da sua versão antes de confiar (R4): esta lista foi conferida em 07/09/2026.

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

Encontrou em histórico já publicado? Limpar exige reescrever o histórico, o que muda todos
os hashes. A ferramenta recomendada é `git filter-repo`, que quase nunca vem instalada
(`pip install git-filter-repo`). O `git filter-branch`, que vem junto com o Git, resolve num
repositório pequeno:

```bash
git filter-branch -f --msg-filter \
  'grep -vE "^(Co-Authored-By|Claude-Session|Assisted-By):" || true' -- --all
git push --force-with-lease origin <ramo>
```

Num repositório pessoal sem forks e sem release publicado o custo é baixo. Ainda assim, o
force-push apaga o histórico antigo para qualquer clone que já exista, então é decisão
consciente: vale mais impedir daqui para a frente do que reescrever o passado.

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
.env, .env.local, .env*.local, .env.production          credenciais
*.sql, *.sql.gz, dumps/, backups/                       dados reais de usuários
node_modules/                                           reprodutível pelo lockfile
.next/, out/, dist/, build/, .vercel/                   artefato de build e vínculo local
uploads/, public/uploads/                               conteúdo enviado por usuários
*.log                                                   pode conter dado sensível
.DS_Store, Thumbs.db                                    lixo de sistema
```

**Versione o lockfile** (`package-lock.json`, ou o do gerenciador que o projeto usa): eles são o que torna a
instalação reproduzível e o que permite auditar dependências.

### O lockfile é contrato

O `package.json` diz "qualquer `^16.4.0`"; o `package-lock.json` diz "exatamente esta
versão, com este hash de integridade". Sem ele, cada instalação pode trazer uma versão
diferente, inclusive uma publicada ontem por quem tomou a conta de um mantenedor.

- **`package-lock.json` sempre versionado**, no mesmo commit que mudou o `package.json`.
- **`npm ci` em CI, em scripts e em clone limpo.** Ele instala exatamente o que está no
  lockfile e falha se o lockfile e o `package.json` não baterem (`npm help ci`). `npm
  install` fica para quando você **quer** mudar dependência.
- **Nunca apague o lockfile para "resolver" um conflito.** Apagar e reinstalar troca
  silenciosamente dezenas de versões transitivas que ninguém revisou.

```bash
# ❌ conflito no lockfile resolvido apagando
rm package-lock.json && npm install

# ✅ resolva o package.json, depois deixe o npm regenerar a partir dele e do lockfile de main
git checkout --theirs package-lock.json   # ou --ours: o lado cujo package.json venceu
npm install                               # reconcilia com o package.json resolvido
git diff --stat package-lock.json         # leia o que mudou antes de commitar
npm ci && npm run build                   # prova que o lockfile resultante instala e compila
```

**Upload não vai para o disco.** Na Vercel o sistema de arquivos da função é efêmero: o
arquivo enviado some no próximo deploy ou na próxima instância. Use o Supabase Storage, em
bucket privado ([entrada-e-saida-seguras.md](entrada-e-saida-seguras.md)). `uploads/` no
`.gitignore` é só proteção contra o teste local que gravou em disco.

---

## 6. Checklist antes de todo push

- [ ] `git status --short` lido, linha por linha: nada inesperado no staging
- [ ] `git diff --cached` lido pelo agente, não só rodado
- [ ] `scan-secrets.sh --stdin` limpo sobre o conteúdo staged
- [ ] `scan-sql-injection.sh` limpo
- [ ] `package-lock.json` no mesmo commit que mudou o `package.json`; nunca apagado e
      regenerado do zero
- [ ] Commits pequenos, um assunto cada, cada um com o build verde
- [ ] Checklist de revisão (R12) executado
- [ ] Versão subida no `package.json`, CHANGELOG e README atualizados no mesmo commit (R13)
- [ ] Visibilidade do repositório confirmada como privada (ou público consciente)
- [ ] ⛔ Aprovação do usuário obtida, com a versão nomeada
