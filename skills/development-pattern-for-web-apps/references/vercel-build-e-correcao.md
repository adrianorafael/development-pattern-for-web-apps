# Vercel: diagnosticar build quebrado e fechar o ciclo até o verde

> Regra **R16**. Build quebrado se conserta com **o log na mão** e a correção **provada
> localmente** antes do push. Nunca às cegas, nunca com `ignoreBuildErrors`, nunca em ciclo
> sem teto.

O modo de falha que esta regra existe para matar é o *empurra e reza*: o build falha, o
agente altera algo plausível, dá push, espera três minutos, falha de novo, altera outra
coisa. Cinco commits depois o histórico está poluído, ninguém sabe qual mudança resolveu o
quê, e metade delas era desnecessária.

O ciclo correto é: **ler o log → reproduzir localmente → corrigir → provar localmente →
um push → confirmar o deploy.** Uma volta, não cinco.

---

## 1. Conectar à conta da Vercel

Três caminhos, nesta ordem de preferência. **Detecte antes de perguntar.**

### a) Servidor MCP da Vercel: preferido quando disponível

Se a sessão tiver um servidor MCP da Vercel conectado, use-o: a autenticação já está
resolvida e as ferramentas são tipadas. Detecte listando as ferramentas disponíveis antes de
propor qualquer outro caminho.

### b) Vercel CLI com token: o caminho padrão

```bash
npm i -g vercel            # ou use npx vercel, sem instalar
vercel link                # associa esta pasta a um projeto da conta
```

O token vai por variável de ambiente, **nunca em arquivo versionado** (R1):

```bash
# .env: gitignored. Crie o token em Vercel → Settings → Tokens.
VERCEL_TOKEN="SEU-TOKEN-DA-VERCEL"
VERCEL_ORG_ID="SEU-ORG-ID"          # aparece em .vercel/project.json após o link
VERCEL_PROJECT_ID="SEU-PROJECT-ID"
```

```bash
export VERCEL_TOKEN="$(grep -m1 '^VERCEL_TOKEN=' .env | cut -d= -f2- | tr -d '"')"
vercel ls --token "$VERCEL_TOKEN"
```

`.vercel/` entra no `.gitignore`, ele guarda o vínculo com o projeto e, dependendo da
versão, credenciais em cache.

**Escopo mínimo:** crie o token com acesso apenas ao projeto (ou ao time) em questão, nunca
um token de conta inteira para diagnosticar um build. Revogue quando terminar, se foi criado
só para isso.

### c) API REST: quando o CLI não está disponível

```bash
curl -sS -H "Authorization: Bearer $VERCEL_TOKEN" \
  "https://api.vercel.com/v6/deployments?projectId=$VERCEL_PROJECT_ID&limit=5"
```

> ⚠️ **Os números de versão dos endpoints mudam** (`v6`, `v13`, `v3`…) e não foram
> verificados nesta redação. Antes de usar, confirme em `vercel.com/docs/rest-api` e anote a
> data no registro de evidências (R4). O mesmo vale para os subcomandos do CLI: rode
> `vercel --help` e `vercel <comando> --help` **nesta sessão** antes de afirmar que existem.

---

## 2. O comando que mais importa: `vercel build`

Antes de qualquer teoria sobre a falha, saiba disto: **`vercel build` reproduz o build da
Vercel na sua máquina.** Ele não é o mesmo que `npm run build`, ele aplica a configuração do
projeto, o mesmo runtime e a mesma sequência que o servidor usa.

```bash
vercel pull --environment=preview   # traz a configuração e as variáveis daquele ambiente
vercel build                        # reproduz o build exatamente como a Vercel faria
```

`vercel pull` é o que resolve a categoria de falha mais comum: **a variável de ambiente que
existe na sua máquina e não existe no ambiente da Vercel**, ou o contrário.

Se `vercel build` passa e o deploy falha, a diferença está no ambiente, não no código: vá
para a seção 5.

---

## 3. O ciclo de correção

```
1 OBTER      identificar o deploy que falhou e baixar o LOG COMPLETO
2 LER        classificar a falha pela taxonomia (§4), nunca adivinhar pelo título
3 REPRODUZIR vercel pull && vercel build   → a MESMA mensagem tem que aparecer
4 CORRIGIR   a menor mudança que resolve a causa raiz
5 PROVAR     vercel build limpo + tsc + lint + testes + os scanners
6 EMPURRAR   UM push, no ramo de trabalho → deploy de preview
7 CONFIRMAR  o preview ficou verde? Se não, volte ao passo 1 com o NOVO log
8 PORTÃO     ⛔ merge em main (produção) só com aprovação. R14
```

**O passo 3 não é opcional.** Uma falha que você não conseguiu reproduzir localmente é uma
falha que você não entendeu, e a correção é um chute. Se não reproduzir, diga isso e
investigue a diferença de ambiente antes de tocar no código.

### Teto de tentativas

**Três voltas.** Se depois de três pushes validados o build ainda falha, **pare e escale**:

> Três tentativas no build do preview `<url>`, ainda falhando.
> O log agora aponta `<mensagem>`, diferente das anteriores.
> Minha leitura é `<hipótese>`, mas não consigo reproduzir localmente, `vercel build`
> passa limpo aqui. Isso sugere diferença de ambiente, não de código.
> O que eu preciso de você: confirmar se `DATABASE_URL` existe no ambiente **Preview**
> (ela existe no Production), em Vercel → Settings → Environment Variables.

Continuar além disso é queimar minutos de CI e poluir o histórico. Um agente que não sabe
parar é pior que um que não sabe começar.

---

## 4. Taxonomia de falhas de build

O log da Vercel é longo; a linha que importa quase sempre está **no fim, antes do
`Error: Command "npm run build" exited with 1`**. Leia de baixo para cima.

### Falhas de código

| No log | Causa raiz | Correção |
| --- | --- | --- |
| `Type error: ...` | `next dev` não faz checagem de tipos do projeto inteiro; o build faz | `npx tsc --noEmit` local e corrigir. **Nunca** `ignoreBuildErrors` |
| `Module not found: Can't resolve './Botao'` | Sistema de arquivos: macOS e Windows são *case-insensitive*, o build da Vercel roda em Linux e não é | Acertar a caixa do import para bater com o nome real do arquivo |
| `Cannot find module 'X'` | Dependência em `devDependencies` mas necessária no build, ou ausente do `package.json` | Mover para `dependencies`, ou instalar e **commitar o lockfile** |
| `npm ci` falha / `lockfile does not match` | Lockfile desatualizado ou não versionado | `npm install`, commitar `package-lock.json` |
| Dois lockfiles no repositório | `package-lock.json` **e** `pnpm-lock.yaml` juntos | Apagar o que não se usa; o gerenciador é detectado pelo lockfile |
| Erros de ESLint derrubando o build | Configuração que trata lint como erro de build | Corrigir os erros. **Nunca** `eslint.ignoreDuringBuilds` |
| `Error occurred prerendering page "/x"` | Server Component acessando banco, `fetch` ou variável de ambiente em tempo de build | Marcar a rota como dinâmica, ou mover o acesso para dentro do request |
| `useSearchParams() should be wrapped in a suspense boundary` | Hook de cliente lido durante a pré-renderização | Envolver o componente em `<Suspense>` |
| `Dynamic server usage: couldn't be rendered statically` | `cookies()`/`headers()` numa rota que o Next tentou tornar estática | `export const dynamic = 'force-dynamic'` na rota, se for mesmo dinâmica |
| `The Edge Function "..." size exceeded` | API do Node ou dependência pesada num runtime edge | Mover para runtime Node, ou enxugar a dependência |
| Build excedeu memória ou tempo | Geração estática grande demais, ou import em cascata | Reduzir `generateStaticParams`, revisar imports do topo da árvore |

### Falhas de ambiente: o agente **não** conserta sozinho

| No log | Causa raiz | O que fazer |
| --- | --- | --- |
| `Environment variable "X" is not defined` | A variável existe em Production e **não em Preview**: são ambientes separados | **Nomear a variável e o ambiente e parar.** É segredo; quem cria é o dono da conta (R1) |
| Erro de conexão com o banco no build | Provedor bloqueando o IP do build, ou `sslmode` ausente | Diagnosticar e reportar; a correção costuma ser no painel do provedor |
| `Node.js version "18.x" is deprecated` | Versão fixada no projeto ou em `engines` | Propor a subida de versão: é mudança de ambiente, vai com aviso |
| Domínio, integração ou billing | Nada a ver com o código | Reportar com o texto exato do log |

**Esta separação é o coração da regra.** Um agente que "corrige" uma variável de ambiente
ausente inventando um valor padrão no código transformou uma falha visível numa falha
silenciosa em produção.

---

## 5. Obter o log, na prática

```bash
# 1. Qual foi o último deploy, e qual falhou?
vercel ls --token "$VERCEL_TOKEN"

# 2. Detalhes e log de build de um deploy específico
vercel inspect <url-do-deploy> --logs --token "$VERCEL_TOKEN"
```

> ⚠️ Ponto que confunde: em versões recentes do CLI, **`vercel logs` mostra log de execução
> (runtime), não de build**. O log de build sai por `vercel inspect --logs` ou pelo painel.
> Confirme com `vercel inspect --help` antes de concluir que "não há log".

Guarde o log num arquivo e **cite no relatório o trecho exato** que fundamentou o
diagnóstico, não parafraseie:

```bash
vercel inspect <url> --logs --token "$VERCEL_TOKEN" > /tmp/build.log 2>&1
tail -60 /tmp/build.log
```

O log de build pode conter valores de variáveis, nomes internos e caminhos. **Não cole o log
inteiro em lugar nenhum**: nem em commit, nem em issue, nem em README (R1). Cite as linhas
relevantes, sanitizadas.

---

## 6. O que nunca fazer: a "amputação"

Ficar verde apagando o que reclama não é corrigir; é esconder.

```ts
// ❌ next.config.ts: todas proibidas por esta regra
export default {
  typescript: { ignoreBuildErrors: true },      // o erro de tipo continua lá, agora invisível
  eslint:     { ignoreDuringBuilds: true },     // idem
};
```

Também proibidos:

- Apagar ou pular o teste que falha, em vez de entender por que ele falha.
- `// @ts-ignore` / `@ts-expect-error` para calar um erro real de tipo.
- `any` para atravessar uma incompatibilidade que a tipagem estava certa em apontar.
- Fixar uma dependência numa versão antiga só para o build passar, sem registrar o porquê.
- Commit vazio ou re-deploy para "tentar de novo" sem mudança nenhuma.
- Inventar valor padrão para variável de ambiente ausente.

Se a única saída viável for uma dessas, isso é uma **decisão do dono do projeto**, não do
agente: apresente o trade-off, proponha a alternativa correta, e espere.

---

## 7. Preview, produção e volta atrás

| Ambiente | Origem | Papel no ciclo |
| --- | --- | --- |
| **Preview** | cada push num ramo de trabalho | Onde o ciclo de correção acontece, livremente |
| **Production** | merge em `main` | ⛔ Portão: só depois do preview verde e da aprovação (R14) |

O ciclo dos passos 1 a 7 roda **sozinho no preview**. A promoção para produção é o único ponto
que exige um "sim": é o que separa "consertar" de "publicar".

```bash
vercel promote <url-do-deploy>    # promove um deploy existente a produção
vercel rollback <url-do-deploy>   # volta produção para um deploy anterior
```

**O rollback do código não desfaz a migração do banco.** Se o deploy quebrado veio junto com
uma migração destrutiva, o caminho de volta é o backup, não o `rollback`.
→ [release-e-deploy.md § migrações destrutivas](release-e-deploy.md)

---

## 8. Relatar o resultado

Cada volta do ciclo é registrada: use
[`../assets/templates/correcao-de-build.template.md`](../assets/templates/correcao-de-build.template.md).
O relatório ao usuário nomeia o que foi lido, não o que foi suposto:

> **Build do preview `dpfwa-git-fix-anexos.vercel.app`, corrigido na primeira volta.**
>
> **O log dizia:** `Type error: Property 'usuarioId' does not exist on type 'Sessao'`
> em `actions/chamados.ts:24`.
>
> **Causa:** `exigirSessao()` passou a devolver `{ usuario: { id } }` no commit `a1b2c3d`,
> e esta action não acompanhou. `next dev` não pega porque não checa tipos do projeto todo.
>
> **Reproduzido localmente:** `vercel build` falhou com a mesma mensagem. ✅
>
> **Correção:** dois usos de `sessao.usuarioId` → `sessao.usuario.id`. Nada além disso.
>
> **Provado:** `tsc --noEmit` limpo · `npm run lint` limpo · `vercel build` verde ·
> `scan-secrets.sh` e `scan-sql-injection.sh` limpos.
>
> **Empurrado:** commit `e4f5a6b` no ramo `fix/tipo-da-sessao`. Preview reconstruindo.
>
> ⛔ Produção depende de você: aprovo o merge em `main`?

Nunca "corrigi o build". Diga qual linha do log, qual causa, e o que provou a correção.

---

## 9. Checklist

- [ ] `VERCEL_TOKEN` fora do repositório, com escopo mínimo (R1)
- [ ] `.vercel/` no `.gitignore`
- [ ] Log de build **completo obtido e lido**, não o título da falha
- [ ] Falha classificada como **de código** ou **de ambiente**
- [ ] Falha de ambiente: variável e ambiente nomeados, e o agente **parou** ali
- [ ] Falha reproduzida com `vercel build` antes de qualquer correção
- [ ] Correção é a menor que resolve a causa raiz: nada de escopo carona
- [ ] Nenhum `ignoreBuildErrors`, `ignoreDuringBuilds`, `@ts-ignore` ou teste apagado
- [ ] `tsc --noEmit`, lint, testes e os scanners limpos antes do push
- [ ] **Um** push por volta do ciclo
- [ ] Teto de três voltas respeitado; escalonamento com hipótese e pedido concreto
- [ ] Trechos do log citados sanitizados, nunca colados inteiros (R1)
- [ ] Produção só após o preview verde e a aprovação (R14)
- [ ] Registro da correção em `qa/correcoes-de-build/` e caso `CT-REG-nnn` se cabível (R11)

---

## 10. E na trilha PHP?

A Hostinger não tem build nem CI/CD: o equivalente é o **painel de atualização** (R10), que
valida o pacote antes de escrever, aplica migrações em ordem e faz rollback automático. O
ciclo desta regra (log, reprodução, correção mínima, teto de tentativas) vale igual para
diagnosticar uma atualização que falhou: o log está em `storage/logs/php-error.log` e no
relatório que o próprio painel gera.
→ [pacotes-de-atualizacao.md](pacotes-de-atualizacao.md)
