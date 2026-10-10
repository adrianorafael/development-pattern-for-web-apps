# API: <Nome do App>

> Modelo de `docs/api.md` para um aplicativo construído sob o
> **[Development Pattern for Web Apps](https://github.com/adrianorafael/development-pattern-for-web-apps)**.
> Regras **R6**, **R7** e **R13**. Este arquivo muda no mesmo commit que a rota ou a action.
>
> **Quando NÃO criar:** app sem Route Handler, sem webhook e sem Server Action que mude
> estado (uma vitrine que só lê). Se existe uma única action que grava, este documento
> existe: ela é um endpoint HTTP público, mesmo que pareça uma função.
>
> Os exemplos abaixo são do app de chamados (`stack-nextjs-vercel.md` §4,
> `entrada-e-saida-seguras.md` §2, `linha-de-base-de-seguranca.md` §4). Troque pelo que o
> **seu** app expõe, e apague o que ele não tem.

**Base:** `https://seu-dominio.com.br` · **Preview:** URL do deploy de cada ramo ·
**Conferido contra o código em:** `<AAAA-MM-DD>`

---

## Índice

| Tipo | Nome | Autenticação | Quem pode |
| --- | --- | --- | --- |
| Route Handler | `POST /api/chamados` | cookie de sessão + `Origin` | qualquer usuário logado, para si |
| Server Action | `criarChamado` (`actions/chamados.ts`) | cookie de sessão | qualquer usuário logado, para si |
| Server Action | `fecharChamado` (`actions/chamados.ts`) | cookie de sessão | o dono do chamado |
| Webhook | `POST /api/webhooks/<provedor>` | assinatura do provedor | só o provedor |

## Convenções

- **Autenticação.** Sessão do Supabase Auth, no cookie que o `@supabase/ssr` grava. No
  servidor, o usuário vem de `getClaims()`, nunca de `getSession()` nem de campo do corpo.
- **Dono.** Sempre o `usuarioId` da sessão. Nenhuma rota aceita `usuario_id` na entrada.
- **Validação.** Zod no servidor, por allowlist. Validação no navegador é usabilidade.
- **Erros.** Mensagem genérica em português, sem detalhe técnico; o detalhe vai para o log
  (`vercel logs`). Recurso de outra pessoa responde como inexistente (404), para não
  confirmar que existe.
- **CSRF.** Server Actions conferem `Origin` contra `Host` pelo próprio Next; Route Handler
  que muda estado confere com `origemConfiavel()` (`lib/origem.ts`).

---

## Route Handlers

### `POST /api/chamados`

Cria um chamado em nome do usuário logado. Existe para `<quem chama por JSON: automação,
app móvel, outro sistema seu>`; a tela do app usa a action `criarChamado`.

| | |
| --- | --- |
| **Arquivo** | `app/api/chamados/route.ts` |
| **Autenticação** | Cookie de sessão. Sem sessão: 401 |
| **Origem** | `Origin` igual ao `Host`. Diferente ou ausente: 403 |
| **Permissão** | Qualquer usuário logado; o chamado nasce com `usuario_id` da sessão |
| **Limite** | `<n>` por `<janela>`, chave `chamado:<usuarioId>` em `eventos_limite` (se houver) |

**Corpo** (`Content-Type: application/json`):

| Campo | Tipo | Obrigatório | Regra |
| --- | --- | --- | --- |
| `titulo` | texto | sim | 1 a 200 caracteres, sem espaço nas pontas |
| `descricao` | texto | não | até 5000 caracteres |

Qualquer outro campo é ignorado. `usuario_id` e `status` **não** são aceitos.

**Respostas:**

| Código | Quando | Corpo |
| --- | --- | --- |
| 201 | Criado | `{ "id": 42 }` |
| 400 | Corpo não é JSON | `{ "erro": "JSON inválido." }` |
| 401 | Sem sessão | `{ "erro": "Não autenticado." }` |
| 403 | `Origin` ausente ou de outro site | `Origem recusada.` (texto) |
| 422 | Campo inválido | `{ "erros": { "titulo": ["Informe o título"] } }` |
| 429 | Limite excedido (se houver) | `{ "erro": "Muitas requisições. Tente de novo em alguns minutos." }` |
| 500 | Falha inesperada | `{ "erro": "Não foi possível criar o chamado." }` |

**Exemplo** (contra o **preview**, com um usuário de teste de `qa/dados-de-teste.md`):

```bash
curl -i -X POST "https://SEU-PREVIEW.vercel.app/api/chamados" \
  -H "Origin: https://SEU-PREVIEW.vercel.app" \
  -H "Content-Type: application/json" \
  -H "Cookie: <cookie de sessão do usuário de teste>" \
  -d '{"titulo":"Impressora do 3º andar sem toner"}'
```

> ⚠️ O cookie de sessão é credencial. Use só o de um usuário de teste, nunca o de uma conta
> real, e nunca o cole neste documento nem na conversa com o agente (R1).

---

## Server Actions que mudam estado

Uma Server Action é chamada por POST na URL da página que a usa. O contrato documentado é
o da função: entrada, autorização, retorno e efeito. O formato da requisição é interno do
Next e não é contrato.

### `criarChamado(_anterior, formData)`

| | |
| --- | --- |
| **Arquivo** | `actions/chamados.ts` |
| **Usada em** | `/abrir-chamado` (`useActionState`) |
| **Autorização** | `exigirSessao()` primeiro; sem sessão, redireciona para `/entrar` |
| **Entrada** | `FormData` com `titulo` (1 a 200) e `descricao` (até 5000, opcional) |
| **Efeito** | Insere em `chamados` com o `usuarioId` da sessão; `revalidatePath('/chamados')` |

| Retorno | Quando |
| --- | --- |
| `{ ok: true }` | Criado |
| `{ erros: { campo: [mensagens] } }` | Validação falhou; a tela mostra junto de cada campo |
| `{ erroGeral: 'Não foi possível criar o chamado.' }` | Falha no banco; o detalhe vai para o log |

### `fecharChamado(id)`

| | |
| --- | --- |
| **Arquivo** | `actions/chamados.ts` |
| **Usada em** | `/chamados/[id]` |
| **Autorização** | `exigirSessao()`; o dono é conferido de novo dentro da função SQL `fechar_chamado` (`auth.uid()`) |
| **Entrada** | `id` do chamado, convertido para inteiro e validado |
| **Efeito** | `supabase.rpc('fechar_chamado', { p_chamado_id: id })`: muda `status` para `fechado` e grava em `auditoria`, tudo ou nada |

| Retorno | Quando |
| --- | --- |
| `{ ok: true }` | Fechado |
| `{ erro: 'Chamado não encontrado.' }` | Não existe **ou** é de outra pessoa: a mesma resposta para os dois |

---

## Webhooks

### `POST /api/webhooks/<provedor>`

| | |
| --- | --- |
| **Arquivo** | `app/api/webhooks/<provedor>/route.ts` |
| **Autenticação** | Assinatura do provedor, conferida antes de ler o corpo como confiável. **Não** usa cookie |
| **Segredo** | `<NOME_DA_VARIAVEL>` no painel da Vercel; nunca no repositório |
| **Idempotência** | `<como o mesmo evento recebido duas vezes não duplica o efeito>` |
| **Eventos tratados** | `<lista>`; os demais respondem 200 e são ignorados |
| **Documentação do provedor** | `<URL>` |

---

## OpenAPI

`<Só se há consumidor externo da API: aponte para docs/openapi.yaml. Sem consumidor externo,
apague esta seção.>`
