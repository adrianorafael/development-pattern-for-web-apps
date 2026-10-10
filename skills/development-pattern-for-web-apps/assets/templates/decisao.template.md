# <NNNN>. <A decisão, numa frase afirmativa>

> Modelo de `docs/decisoes/<NNNN>-<slug>.md` para um aplicativo construído sob o
> **[Development Pattern for Web Apps](https://github.com/adrianorafael/development-pattern-for-web-apps)**.
> Regra **R13**. Um arquivo por decisão, numerado em sequência: `0001`, `0002`…
>
> **Quando NÃO criar:** a escolha vale para uma funcionalidade só. Isso é da spec
> (`specs/<nnnn>-<slug>.md`, seção de decisões). Aqui entra o que **atravessa o projeto**:
> banco, provedor de login, padrão de acesso a dados, biblioteca central, forma de deploy.
>
> Decisão aceita não é reescrita. Se ela mudar, crie uma nova que a substitui e marque esta
> como substituída, com o link. Assim se sabe o que valia em cada época.
>
> Preenchido abaixo com um exemplo do app de chamados. Troque pelo seu.

| | |
| --- | --- |
| **Status** | 🟡 proposta · 🟢 aceita · ⚪ descartada · 🔁 substituída por [`<NNNN>`](<NNNN>-<slug>.md) |
| **Data** | `<AAAA-MM-DD>` |
| **Quem decidiu** | `<nome>` |
| **Relacionada a** | `<specs/0003-anexos-em-chamados.md, regra R7, decisão 0002>` |

---

## Contexto

<O problema, as forças em jogo e as restrições, sem ainda dizer a resposta. Quem ler daqui a
um ano precisa entender por que a pergunta existia. Exemplo:>

A publishable key do Supabase vai para o navegador de propósito, e com ela qualquer pessoa
chama a API REST do projeto sem passar pelo app. Ao mesmo tempo, o servidor usa a secret key
em tarefas administrativas e uma conexão SQL direta em relatórios, e esses dois caminhos não
passam pela RLS.

## Decisão

<O que foi decidido, na voz ativa, e o que passa a ser obrigatório. Exemplo:>

Toda tabela de `public` tem RLS ligada com política por dono, **e** toda Server Action,
Route Handler e página confere a sessão e põe o dono na consulta. As duas camadas, sempre.

## Alternativas consideradas

| Alternativa | A favor | Contra | Por que não |
| --- | --- | --- | --- |
| Só RLS | Uma regra só, no banco | A secret key e a conexão direta a ignoram | Um caminho administrativo esquecido vira vazamento |
| Só conferência no servidor | Toda a regra em TypeScript | A API REST com a publishable key não passa pelo servidor | A tabela inteira fica legível com a chave pública |

## Consequências

- **Melhora:** uma política frouxa é segurada pelo servidor, e um servidor que esquece o dono
  é segurado pela política.
- **Custa:** toda tabela nova leva política na mesma migração, e toda action repete a
  conferência do dono.
- **Passa a ser obrigatório:** casos CT-SEC-031 e CT-SEC-032 no roteiro de QA; item de RLS no
  checklist de revisão.

## Evidências

| Afirmação | Fonte | Conferido em |
| --- | --- | --- |
| "A table in an exposed schema without RLS is readable and writable by any role with a grant on it." | https://supabase.com/docs/guides/database/postgres/row-level-security | `<AAAA-MM-DD>` |
