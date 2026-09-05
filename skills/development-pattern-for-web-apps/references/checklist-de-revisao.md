# Checklist de revisão — leia o código de IA como código hostil

> Regra **R12**. Antes de todo push, este checklist roda contra o diff que existe — não
> contra a intenção, não contra a lembrança do que foi escrito.

Código gerado por IA falha de um jeito particular: ele é **plausível**. Compila, passa no
lint, tem nomes coerentes e comentários confiantes — e ainda assim concatena um `$_GET` no
`WHERE` porque naquele trecho pareceu mais simples. Revisar código de IA como se fosse de um
estagiário competente é o erro; revise-o como se fosse de alguém tentando passar algo
despercebido.

**Rode contra o diff real:**

```bash
git diff --cached
git diff --cached --stat
```

---

## 1. Segurança — bloqueia o push

### SQL (R5)

- [ ] Nenhuma variável dentro de string SQL, em nenhuma linguagem
- [ ] `prepare` + parâmetros vinculados em 100% das consultas
- [ ] `ATTR_EMULATE_PREPARES => false` na fábrica de conexão
- [ ] Nome de tabela/coluna/direção dinâmicos vêm de allowlist com valor padrão
- [ ] `LIMIT`/`OFFSET` convertidos para inteiro, com teto
- [ ] `LIKE` com `%` e `_` escapados no valor
- [ ] `IN (...)` com placeholders gerados, nunca com valores
- [ ] Nenhum `queryRaw`/`$queryRawUnsafe`/`sql.unsafe`/`sql.raw` com interpolação
- [ ] `bash .../scan-sql-injection.sh` limpo

### Segredos (R1)

- [ ] Nenhuma credencial, chave ou token no diff
- [ ] `.env`, `config.local.php`, `*.sql`, `*.pem` fora do staging
- [ ] Nada sensível em variável `NEXT_PUBLIC_`
- [ ] `bash .../scan-secrets.sh --stdin` limpo sobre o conteúdo staged

### Entrada e saída (R6)

- [ ] Toda entrada validada no servidor: tipo, faixa, tamanho, enum
- [ ] Toda saída escapada no contexto correto
- [ ] Atributos HTML sempre entre aspas
- [ ] Nenhum `dangerouslySetInnerHTML` sem sanitização de allowlist no servidor
- [ ] `href`/`src` de usuário filtrados por protocolo
- [ ] Token CSRF em toda ação que muda estado, conferido com `hash_equals`
- [ ] Nenhum `GET` com efeito colateral
- [ ] Upload: nome gerado, tipo por `finfo`, tamanho limitado, fora do webroot, sem execução
- [ ] Nenhum caminho de arquivo montado com entrada do usuário

### Autenticação e autorização (R7)

- [ ] Toda rota que lê ou grava confere a sessão
- [ ] O **dono do registro** está na cláusula `WHERE`, não num `if` posterior
- [ ] Rota administrativa confere o papel no servidor
- [ ] Server Action começa por `exigirSessao()` antes de qualquer coisa
- [ ] Senha com `password_hash`; nenhum `md5`/`sha1` sobre senha
- [ ] Sessão regenerada no login; expiração por inatividade
- [ ] Mensagem de login idêntica para usuário inexistente e senha errada
- [ ] Erros logados, nunca exibidos com detalhe técnico

---

## 2. Correção — o código faz o que a spec diz

- [ ] Cada requisito `RF-nnn` tocado tem implementação correspondente
- [ ] Nenhum comportamento a mais que a spec não pediu (escopo não cresceu sozinho)
- [ ] Os quatro estados de tela existem: carregando, vazio, erro, sucesso
- [ ] Casos de fronteira tratados: zero registros, um, o máximo, o máximo + 1
- [ ] Nulos tratados — nenhum acesso a propriedade de algo possivelmente ausente
- [ ] Fusos e datas coerentes com o que a spec definiu
- [ ] Dinheiro em `DECIMAL`/inteiro de centavos; nunca `FLOAT`
- [ ] Transação onde duas escritas precisam acontecer juntas, com `rollBack` em `catch`
- [ ] Envio duplo (duplo clique, F5 no POST) não duplica registro
- [ ] Nenhum `TODO`, `FIXME`, `console.log`, `var_dump` ou `dd()` esquecido

---

## 3. Qualidade e manutenção

- [ ] Nenhum bloco duplicado que deveria ser função ou partial (R8)
- [ ] Nomes em português, coerentes com o resto do projeto
- [ ] Funções curtas e com uma responsabilidade
- [ ] Nenhum "número mágico" sem constante nomeada
- [ ] Nenhuma dependência nova sem justificativa na spec
- [ ] `composer audit` / `npm audit --omit=dev` sem vulnerabilidade crítica
- [ ] Índice no banco para toda coluna nova usada em `WHERE`, `JOIN` ou `ORDER BY`
- [ ] Nenhuma consulta dentro de laço (problema N+1)
- [ ] Listagem com paginação e teto — nenhum `SELECT` sem `LIMIT` sobre tabela que cresce
- [ ] Nenhum `SELECT *` em código de produção

---

## 4. Interface (R8)

- [ ] Componentes reutilizados; nada de HTML copiado e colado
- [ ] Cores e espaçamentos por token do tema; nenhum hex solto
- [ ] Nenhum nome de classe Tailwind montado em runtime
- [ ] Todo campo com rótulo associado
- [ ] Foco visível em todo elemento interativo
- [ ] Contraste mínimo AA
- [ ] Layout verificado em 375 px, 768 px e 1440 px
- [ ] Nenhum erro no console do navegador

## 4b. Rotas e URLs (R15)

- [ ] Nenhuma URL nova contém `.php`, `.html` ou nome de pasta do servidor
- [ ] Português, minúsculas, kebab-case, sem acento e sem underscore
- [ ] Ação é verbo no infinitivo; coleção é substantivo plural
- [ ] Nenhuma navegação depende de query string
- [ ] Nenhum `GET` com efeito colateral
- [ ] Rota renomeada mantém 301 da antiga, registrado no CHANGELOG
- [ ] Página inexistente responde 404, não 200
- [ ] URLs geradas por helper (`rota()` / `Link`), nunca escritas à mão duas vezes
- [ ] Nenhuma classe, arquivo ou caminho resolvido a partir da URL

---

## 5. Específico da trilha PHP

- [ ] Ponto de entrada único; rotas em mapa escrito à mão
- [ ] Nenhum `include`/`require` com valor vindo da URL
- [ ] `config/` e `storage/` inacessíveis pelo navegador — **testado**, não presumido
- [ ] Wizard recusa executar com `instalado.lock` presente (R9)
- [ ] Painel de atualização valida caminho, extensão, `sha256` e versão (R10)
- [ ] Nenhuma escrita do pacote de atualização em `config/` ou `storage/`
- [ ] `.htaccess` com HTTPS, cabeçalhos e `Options -Indexes`

## 6. Específico da trilha Next.js

- [ ] `'use client'` só nas folhas, com motivo
- [ ] `lib/db.ts` com `import 'server-only'`
- [ ] `usuario_id` vem da sessão, nunca de `searchParams`
- [ ] Server Actions validam entrada com esquema e conferem autorização
- [ ] `npm run build` passa localmente
- [ ] Nenhum `ignoreBuildErrors`, `ignoreDuringBuilds` ou `@ts-ignore` novo (R16)
- [ ] Cabeçalhos de segurança em `next.config.ts`

---

## 7. Testes e documentação

- [ ] `qa/roteiro-de-testes.md` atualizado no mesmo commit (R11)
- [ ] Casos de segurança criados para todo campo novo que chega ao banco
- [ ] Defeito corrigido virou caso `CT-REG-nnn`
- [ ] Spec atualizada se o comportamento mudou (R3)
- [ ] README atualizado se instalação, configuração ou uso mudaram (R13)
- [ ] CHANGELOG com entrada datada (R13)
- [ ] Versão subida no arquivo de configuração (R13)

---

## 8. As sete perguntas adversariais

Depois do checklist, releia o diff fazendo estas sete perguntas. Elas pegam o que a lista
não pega:

1. **Se eu fosse o invasor, qual linha deste diff eu atacaria primeiro?** Vá até ela e
   prove que ela resiste.
2. **Qual entrada deste diff eu não validei?** Rastreie cada valor da fronteira até o banco.
3. **O que acontece se este código rodar duas vezes ao mesmo tempo?** Duplo clique, duas
   abas, dois deploys.
4. **O que acontece se a rede cair no meio?** Registro pela metade? Arquivo órfão?
5. **Qual consulta aqui fica lenta com 100 mil linhas?** Rode `EXPLAIN` nas novas.
6. **Que informação esta mensagem de erro entrega a quem não deveria vê-la?**
7. **Se este código estiver errado, como eu vou descobrir?** Se a resposta for "o usuário
   reclama", falta log ou falta caso de teste.

---

## 9. Como reportar o resultado

Honestamente e com números:

> Revisão de `feat/anexos-em-chamados` (11 arquivos, +487/−52):
>
> **Corrigido durante a revisão:** o filtro de `anexos` concatenava `$_GET['chamado']` no
> `WHERE` — reescrito com prepared statement; faltava `AND usuario_id = :sessao` na consulta
> de download, o que permitia baixar anexo de outro usuário.
>
> **Pendente, com sua decisão:** a listagem de anexos não tem paginação. Com o volume atual
> (dezenas) não é problema; acima de mil ficará lenta. Registrei como dívida na spec.
>
> **Verificações:** `php -l` limpo em 11 arquivos · `scan-secrets.sh` limpo ·
> `scan-sql-injection.sh` limpo · `composer audit` sem vulnerabilidade ·
> roteiro de QA atualizado com 6 casos novos, sendo 3 de segurança.

Nunca "revisado, está tudo certo". Diga o que encontrou, o que corrigiu e o que ficou.
