# Protocolo de verificação: provar, não lembrar

> Regra **R4**. Uma função, prop, classe ou opção só entra no código depois de verificada
> contra o que está realmente instalado ou contra a documentação oficial lida nesta sessão.

O modelo tem memória de treinamento. A memória de treinamento é uma média de versões, e a
média não compila. `next lint` não existe no Next 16. `middleware.ts` virou `proxy.ts`.
`bg-opacity-50` foi removido no Tailwind v4. `next/router` não funciona no App Router. Cada
um desses erros parece código correto até o momento em que não é.

---

## 1. A hierarquia de fontes

Do mais confiável para o menos. **Sempre desça o mínimo possível.**

| Nível | Fonte | Quando usar |
| --- | --- | --- |
| 1 | O código instalado no projeto: `node_modules/<pacote>/**/*.d.ts`, `package-lock.json` | Sempre que o pacote estiver instalado. É a verdade absoluta para **este** projeto. |
| 2 | O runtime e o registro: `node -v`, `npm ls`, `npm view`, `npm pack` | Para saber o que existe no ambiente e no registro, não o que deveria existir |
| 3 | Documentação oficial da versão instalada: nextjs.org/docs, vercel.com/docs, tailwindcss.com/docs | Quando o pacote não está instalado, ou para semântica que o `.d.ts` não expressa |
| 4 | Changelog / guia de upgrade do projeto upstream (o da versão, em nextjs.org/docs) | Quando a dúvida é "mudou entre versões?" |
| 5 | Memória do modelo | **Nunca sozinha.** Serve para levantar a hipótese que os níveis 1 a 4 confirmam. |

---

## 2. Comandos de verificação por situação

### Node, Next.js, React

```bash
node -v && npm -v                                                # runtime local
grep -E '"(next|react|tailwindcss|typescript)"' package.json    # versões declaradas
npm ls next react tailwindcss                                    # versões resolvidas
npx next --version                                               # a que o projeto executa
grep -m1 '"node"' package.json                                   # engines, se declarado
```

A API que existe **aqui**, lida no `.d.ts` instalado:

```bash
# a chave existe no next.config desta versão?
grep -n "ignoreBuildErrors\|typedRoutes" node_modules/next/dist/server/config-shared.d.ts
# a função existe e com que assinatura?
grep -rn "export declare function notFound" node_modules/next/dist/client/components/*.d.ts
# o subcomando do CLI existe?
ls node_modules/next/dist/cli/                 # no 16 não há next-lint.js
```

### Conferir uma versão sem instalar

Para afirmar algo sobre uma versão que o projeto ainda não usa, baixe o pacote publicado e
leia, sem `npm install` e sem executar nada dele:

```bash
mkdir -p /tmp/conferencia && cd /tmp/conferencia
npm view next version                          # a mais recente publicada
npm view next@16 version                       # as versões de uma linha maior
npm pack next@16.4.0                           # baixa o .tgz exato, não instala
tar -xzf next-16.4.0.tgz                       # extrai para ./package
grep -n "PROXY_FILENAME" package/dist/lib/constants.js
```

`npm view <pacote> deprecated` também mostra se o pacote foi depreciado: foi assim que
`@vercel/postgres` saiu desta skill.

### Tailwind

```bash
npm ls tailwindcss
ls tailwind.config.* 2>/dev/null || head -30 app/globals.css     # v3 vs v4
grep -rn -- "--color-" app/globals.css                           # tokens definidos no @theme
```

**Tailwind v3 vs v4 é a armadilha recorrente:** v3 usa `tailwind.config.js` e diretivas
`@tailwind`; v4 usa `@import "tailwindcss"` e configuração em CSS com `@theme`. Descubra
qual antes de escrever a primeira classe.

### Vercel CLI

```bash
npx vercel --version
npx vercel --help                              # a lista de subcomandos DESTA versão
npx vercel inspect --help                      # as opções de um subcomando
```

### Postgres (Supabase)

```bash
npx supabase --version                                            # o CLI que o projeto usa
npx supabase migration list                                       # local x remoto, lado a lado
psql "$POSTGRES_URL" -c "SELECT version();"                       # versão real do servidor
psql "$POSTGRES_URL" -c "\d public.chamados"                      # o schema real, não o da spec
psql "$POSTGRES_URL" -c "SELECT version, name FROM supabase_migrations.schema_migrations ORDER BY version DESC LIMIT 5;"
npm ls @supabase/supabase-js @supabase/ssr
```

`POSTGRES_URL` vem de `vercel env pull .env.local` (a integração do Supabase pelo Marketplace
da Vercel cria a variável), nunca colada no terminal nem no chat (R1). Rode contra o banco
local (`npx supabase start`) ou um branch de preview do Supabase, não o de produção.

### Antes de instalar um pacote

Todo `npm install <pacote>` é código de um estranho rodando na sua máquina, no build da
Vercel e no navegador do usuário. Dois riscos aparecem justamente quando a IA escreve o
código:

- **Nome inventado.** O modelo sugere um pacote que não existe, mas cujo nome é plausível.
  Alguém pode registrar esse nome depois e publicar código malicioso nele: quem instala o
  que a IA sugeriu, sem conferir, instala o pacote do atacante.
- **Nome parecido (typosquatting).** `reacct`, `zod-validator-js`, `next-auth-helper`: um
  caractere ou um sufixo de diferença de um pacote popular, publicado para pegar quem digita
  com pressa.

Antes de instalar, confira:

```bash
# 1. O nome exato, copiado da documentação oficial da biblioteca, não da sugestão do modelo.
# 2. Quem publica, de onde vem, desde quando e qual versão está marcada como latest:
npm view <pacote> repository.url maintainers time.created time.modified dist-tags
# 3. Se está depreciado:
npm view <pacote> deprecated
# 4. Licença e versão:
npm view <pacote> license version
```

(Flags conferidas com `npm view zod repository.url maintainers time.modified dist-tags`,
npm 11, 2026-10-10.)

| Sinal | O que fazer |
| --- | --- |
| `npm view` responde `404` | O pacote não existe. **Não** procure um nome parecido que exista: volte à documentação oficial da biblioteca. |
| `time.created` de poucos dias ou semanas | Desconfie. Pacote legítimo e útil quase sempre tem histórico. |
| Poucos downloads semanais (página do pacote em npmjs.com) | Desconfie, sobretudo se o nome lembra um pacote popular. |
| `repository.url` ausente, ou repositório que não é o da documentação | Não instale. |
| Último release muito antigo, issues de segurança abertas sem resposta | Prefira uma alternativa mantida, ou registre o risco na spec. |
| Licença incompatível com o projeto, ou ausente | Pare e pergunte à pessoa. |
| O pacote só existe porque o modelo sugeriu | Pergunte se a funcionalidade não sai com o que o projeto já tem (Next, Zod, Supabase). Cada dependência é superfície de ataque. |

Instalou? A linha vai para o registro de evidências da spec (§3), com o comando que provou:

| Afirmação | Fonte | Verificado |
| --- | --- | --- |
| `zod` é o pacote oficial, publicado por `colinhacks`, repositório `github.com/colinhacks/zod` | `npm view zod repository.url maintainers` | ✅ 2026-10-10 |

O lockfile versionado e o `npm ci` fecham a outra metade (a versão instalada é a mesma em
todo lugar): [git-e-publicacao.md](git-e-publicacao.md). Alertas e atualizações de
segurança das dependências: Dependabot, em
[linha-de-base-de-seguranca.md](linha-de-base-de-seguranca.md) (P12).

---

## 3. O registro de evidências

Toda spec carrega uma tabela assim. Uma afirmação sem linha aqui não entra na spec:

| Afirmação | Fonte | Verificado |
| --- | --- | --- |
| Next 16 neste projeto | `npm ls next` → `next@16.4.0` | ✅ 2026-10-10 |
| `middleware.ts` virou `proxy.ts` | `node_modules/next/dist/lib/constants.js` → `PROXY_FILENAME = 'proxy'` | ✅ 2026-10-10 |
| `typescript.ignoreBuildErrors` existe; `eslint` não existe no `NextConfig` | `node_modules/next/dist/server/config-shared.d.ts` | ✅ 2026-10-10 |
| Tailwind v4 neste projeto | `package.json` → `"tailwindcss": "^4.3.3"` | ✅ 2026-10-10 |
| Server Actions exigem `'use server'` no topo | nextjs.org/docs/app/api-reference/directives/use-server | ✅ 2026-10-10 |
| `vercel inspect --logs` imprime o log de build | `vercel inspect --help` (CLI 63.1.2) | ✅ 2026-10-10 |
| `@vercel/postgres` está depreciado | `npm view @vercel/postgres deprecated` | ✅ 2026-10-10 |
| `supabase migration list` e `supabase db push` existem | `npx supabase migration --help`, `npx supabase db --help` (CLI 2.120.0) | ✅ 2026-10-10 |

Data importa: a documentação muda. Uma evidência de três meses atrás merece nova checagem
quando o comportamento surpreende.

---

## 4. Diga "não sei" em voz alta

Quando o pacote não está instalado e a documentação está inacessível, a saída correta é:

> Não consigo verificar se `after()` de `next/server` está disponível nesta versão: o
> projeto ainda não tem `node_modules/` e não tenho acesso à doc agora.
> Duas formas de destravar: rodar `npm install` e eu leio o `.d.ts`, ou eu baixo o pacote
> com `npm pack next@<versão>` numa pasta temporária e confiro sem instalar. Enquanto isso,
> o envio de e-mail continua dentro da requisição, sem depender dessa função.

Isso é mais útil que uma chamada plausível que falha em produção às duas da manhã.

---

## 5. Armadilhas conhecidas por stack

| Afirmação comum | Realidade a verificar |
| --- | --- |
| "Template string resolve o SQL" | Só como **template tag** (`` sql`...${x}` ``). Com parênteses, `` sql(`...${x}`) ``, é concatenação. → R5 |
| "`z.string().email()` garante que o e-mail existe" | Valida formato, não existência nem entrega. |
| "SHA-256 serve para senha" | **Não.** Quem guarda a senha é o provedor de autenticação (Supabase Auth). Se um dia for preciso guardar senha própria, só KDF lento com sal, nunca hash rápido. |
| "`x-forwarded-for` é o IP do cliente" | É cabeçalho; atrás da Vercel, confira na doc qual cabeçalho a plataforma garante antes de confiar. |
| "React escapa tudo" | Escapa texto. `dangerouslySetInnerHTML` e `href` com `javascript:` continuam abertos. |
| "Server Components podem usar `useState`" | Não. Precisa de `'use client'`. |
| "`process.env.X` funciona no navegador" | Só com prefixo `NEXT_PUBLIC_`, e aí é público. |
| "Server Action é privada porque não aparece no bundle" | É um endpoint HTTP público. Valide entrada e autorização dentro dela. |
| "Tailwind aceita classe montada em runtime" | Não: `text-${cor}-500` não é gerado. Use mapa de classes completas. |
| "`revalidatePath` atualiza na hora em qualquer caso" | Depende de cache, runtime e rota. Verifique na doc da sua versão. |
| "`next lint` roda o lint" | Não no Next 16: o subcomando foi removido. O script é `eslint .`. |
| "Escrevo o upload em disco" | Função serverless não tem disco persistente; só `/tmp`, efêmero. Use o Supabase Storage, em bucket privado. |
| "Esse pacote que o modelo sugeriu existe" | Confira com `npm view <pacote>` antes de instalar: nome inventado pode ter sido registrado por um atacante. → §2, "Antes de instalar um pacote" |
| "Guardo o contador do rate limit em memória" | Cada invocação pode ser outra instância. Use armazenamento externo. |
| "`vercel rollback` desfaz a migração" | Volta o código, não o banco. → R10 |

---

## 6. Quando duas formas parecem plausíveis

Use a que o código instalado prova, mesmo que a outra pareça mais elegante. E registre a
escolha:

```
Considerei `proxy.ts` para canonicalizar a caixa das URLs. O `package.json` declara
"next": "^15.5.0" e `npm ls next` resolve 15.5.x, onde a convenção ainda é `middleware.ts`
(`proxy` só aparece no 16): então escrevo `middleware.ts`. Quando o projeto subir para o
16, rodo `npx @next/codemod@canary middleware-to-proxy .` e esta escolha é revista.
```
