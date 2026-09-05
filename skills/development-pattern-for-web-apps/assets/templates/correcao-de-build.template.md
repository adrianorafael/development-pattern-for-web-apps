# Correção de build — `<projeto>` `<AAAA-MM-DD>`

> Modelo de `qa/correcoes-de-build/<AAAA-MM-DD>-<slug>.md`.
> Parte de "Development Pattern for Web Apps" — regra R16.
> Um arquivo por incidente. Uma seção "Volta" por tentativa, no máximo três.

| | |
| --- | --- |
| **Projeto Vercel** | `<nome-do-projeto>` |
| **Deploy que falhou** | `<url-do-deploy>` |
| **Ambiente** | Preview · Production |
| **Ramo** | `<fix/slug>` |
| **Commit de origem** | `<sha>` |
| **Detectado por** | pedido do usuário · verificação de rotina · notificação |
| **Situação** | 🔴 falhando · 🟡 em correção · 🟢 verde · ⛔ escalado |

---

## Volta 1

### 1. O log diz

Cite o **trecho exato**, sanitizado. Nunca parafraseie, nunca cole o log inteiro (R1).

```
<as 10–20 linhas que importam, geralmente logo acima de
 "Error: Command \"npm run build\" exited with 1">
```

Obtido com:

```bash
vercel inspect <url> --logs --token "$VERCEL_TOKEN" > /tmp/build.log 2>&1
tail -60 /tmp/build.log
```

### 2. Classificação

| | |
| --- | --- |
| **Categoria** | de **código** · de **ambiente** |
| **Tipo** | `<erro de tipo / módulo não encontrado / caixa de arquivo / lockfile / prerender / variável ausente / …>` |
| **Arquivo e linha** | `<caminho:linha>` |

> Se for **de ambiente**: pare aqui. Nomeie a variável e o ambiente, escreva o pedido ao
> dono da conta na seção "Escalonamento" e não toque no código.

### 3. Reproduzido localmente?

```bash
vercel pull --environment=preview
vercel build
```

| | |
| --- | --- |
| **Reproduziu** | ✅ mesma mensagem · ❌ passou limpo aqui |
| **Saída local** | `<a mensagem que apareceu, ou "build verde">` |

> ❌ **Não reproduziu?** A diferença é de ambiente, não de código. Não altere nada:
> investigue a divergência (variáveis, versão do Node, gerenciador de pacotes, caixa do
> sistema de arquivos) e registre na seção "Escalonamento".

### 4. Causa raiz

<Uma ou duas frases. O que mudou, quando, e por que só o build pegou.>

### 5. Correção aplicada

<A menor mudança que resolve a causa. Sem escopo carona.>

```diff
- <linha antes>
+ <linha depois>
```

**Arquivos tocados:** `<n>` · **Linhas:** `+<n>/-<n>`

Nada de: `ignoreBuildErrors`, `ignoreDuringBuilds`, `@ts-ignore`, teste apagado, dependência
fixada sem justificativa, commit vazio para reprocessar.

### 6. Provado antes do push

| Verificação | Resultado |
| --- | --- |
| `vercel build` | ⬜ |
| `npx tsc --noEmit` | ⬜ |
| `npm run lint` | ⬜ |
| `npm test` | ⬜ |
| `scan-secrets.sh` | ⬜ |
| `scan-sql-injection.sh` | ⬜ |

### 7. Empurrado

| | |
| --- | --- |
| **Commit** | `<sha>` |
| **Ramo** | `<fix/slug>` |
| **Deploy de preview** | `<url>` |
| **Resultado** | 🟢 verde · 🔴 falhou de novo → **Volta 2** |

---

## Volta 2

*(mesma estrutura. Se a mensagem do log for a MESMA da Volta 1, a correção anterior errou a
causa — reabra o passo 4 em vez de tentar outra coisa.)*

---

## Volta 3

*(mesma estrutura. É a última.)*

---

## Escalonamento

> Preencha quando o teto de três voltas foi atingido, quando a falha é de ambiente, ou
> quando a correção correta exigiria uma decisão que não é do agente.

**O que eu sei:** <o que o log diz, o que reproduziu e o que não reproduziu>

**Minha hipótese:** <a leitura mais provável, dita como hipótese>

**O que eu preciso de você:** <um pedido concreto e verificável — não "dá uma olhada">

> Exemplo: confirmar se `DATABASE_URL` existe no ambiente **Preview** em
> Vercel → Settings → Environment Variables. Ela existe em Production; o log da Volta 1
> mostra a variável indefinida só nos deploys de preview.

**Alternativa se você preferir não mexer nisso agora:** <o contorno, e o que ele custa>

---

## Fechamento

| | |
| --- | --- |
| **Voltas gastas** | `<n>` de 3 |
| **Deploy verde** | `<url>` |
| **Produção** | ⛔ aguardando aprovação · 🟢 promovida em `<data>` |
| **CHANGELOG** | entrada adicionada? ⬜ |
| **Regressão criada** | `CT-REG-<nnn>` ⬜ · não se aplica ⬜ |

**Como evitar a repetição:** <a mudança de processo, se houver — um passo novo na validação
local, um caso de teste, uma linha no AGENTS.md do projeto.>
