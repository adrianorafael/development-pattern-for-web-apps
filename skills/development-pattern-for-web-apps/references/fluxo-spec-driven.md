# Fluxo guiado por especificação: decida antes de digitar

> Regra **R3**. Trabalho não trivial recebe uma especificação escrita e um portão de
> aprovação explícito.

Vibecoding falha de um jeito específico e previsível: o agente começa a escrever antes de a
forma da coisa estar decidida, o usuário corrige os sintomas visíveis um a um, e depois de
seis rodadas o app é uma pilha de remendos sem projeto. Uma spec custa dez minutos e
substitui essas seis rodadas por uma.

Neste padrão a spec tem uma segunda função, tão importante quanto: **ela é a fonte dos casos
de teste**. O roteiro de QA (R11) não é inventado no fim; ele é derivado dos requisitos
numerados que a spec definiu antes de existir código.

---

## Precisa de spec?

| Precisa | Pode pular |
| --- | --- |
| App novo, módulo novo, tela nova | Ajuste de texto, troca de rótulo |
| Nova tabela, nova coluna, nova migração | Correção de espaçamento ou cor |
| Rota nova, ou renomear uma existente | Ajuste de texto de um link |
| Qualquer coisa que grave no banco | Renomear variável local |
| Login, permissão, recuperação de senha | Adicionar um estado de carregamento óbvio |
| Upload de arquivo, integração com API externa | Atualização de patch de dependência |
| Variável de ambiente nova, seed, migração destrutiva | Corrigir um typo em comentário |
| Qualquer coisa que trate dado pessoal ou pagamento | |

**Na dúvida, escreva a spec.** Sai mais barato que o retrabalho.
Trabalho de "pode pular" continua sujeito a R1, R4, R5, R6, R7 e R12, não existe isenção
dessas.

---

## Fase 0: Bootstrap

As seis perguntas do `SKILL.md`, **em um único lote**:

1. Repositório: existe, ou crio novo (privado)?
2. Projeto Vercel e banco: nome do projeto, projeto Supabase (pelo Marketplace da Vercel), domínio.
3. Dados e usuários: login? dado pessoal (LGPD)? pagamento? upload? há API paga? escala?
4. Identidade do app: nome, slug, versão inicial (`0.1.0`).
5. Testes: quem executa o roteiro: você, o Claude Cowork, ou os dois?
6. Acesso à Vercel: MCP da Vercel, ou CLI com token?

Depois: armar `.gitignore`, criar `.env.example` e `lib/env.ts` (R9), rodar `vercel link` e
`vercel env pull .env.local`, rodar a primeira varredura, confirmar que o repositório é
privado. Detalhes: [bootstrap-do-ambiente.md](bootstrap-do-ambiente.md).

"Há API paga?" não é curiosidade: toda API cobrada por uso (modelo de linguagem, envio de
e-mail ou SMS, mapas) ganha teto e alerta de gasto no painel do provedor antes do primeiro
deploy, e entra no rate limiting. Detalhes em
[linha-de-base-de-seguranca.md](linha-de-base-de-seguranca.md).

Antes de abrir o agente, isole o ambiente de trabalho: uma pasta ou um `git worktree` por
tarefa, nunca a pasta home. Detalhes em
[agentes-e-ferramentas-de-ia.md](agentes-e-ferramentas-de-ia.md).

---

## Fase 1: Pesquisa

Leia a documentação oficial do que você vai usar, **nesta sessão**, e siga os links da
página. Nunca responda só de memória.

| Assunto | Fonte primária |
| --- | --- |
| App Router, Server Actions, cache, rotas | https://nextjs.org/docs |
| Classes, tokens, tema, diferenças v3/v4 | https://tailwindcss.com/docs |
| Postgres: tipos, índices, `ON CONFLICT`, `EXPLAIN` | https://www.postgresql.org/docs/current/ |
| Auth, RLS, Storage, CLI, Branching, chaves de API | https://supabase.com/docs |
| Variáveis de ambiente, funções, limites, rollback | https://vercel.com/docs |
| Riscos e defesas por categoria | https://owasp.org/Top10/2025/ e as OWASP Cheat Sheets (https://cheatsheetseries.owasp.org/) |
| O que já está instalado neste projeto | `npm ls`, `npm view <pacote> version`, `node -v` |

**Nível N2 ou acima (R7): leia as categorias do OWASP Top 10 que se aplicam.** A edição
vigente é a de 2025 (https://owasp.org/Top10/2025/, conferido em 2026-10-10). A tabela que
liga cada categoria a uma regra e a uma referência desta skill está em
[linha-de-base-de-seguranca.md](linha-de-base-de-seguranca.md). Para cada categoria que a
funcionalidade toca (login toca A07, Authentication Failures; listagem por dono toca A01,
Broken Access Control; dependência nova toca A03, Software Supply Chain Failures), anote na
seção **Segurança** da spec qual é o risco e qual requisito o cobre. Categoria que não se
aplica recebe uma linha dizendo por quê.

Saída da fase: um **registro de evidências** no formato afirmação → fonte → verificado. Ele vai
inteiro para a spec.

Não comece a spec com uma pergunta estrutural em aberto. "Eu decido o modelo de dados
enquanto codo" é como o schema vira um remendo.

---

## Fase 2: Spec ⛔ PORTÃO

Escreva `specs/<nnnn>-<slug>.md` a partir de
[`../assets/templates/spec.template.md`](../assets/templates/spec.template.md).
É curta: uma a três páginas. Suas seções:

| Seção | A pergunta que ela responde |
| --- | --- |
| **Objetivo** | O que o usuário passa a conseguir fazer que não conseguia? Uma frase. |
| **Fora de escopo** | O que explicitamente não entra? Impede o escopo de crescer sozinho. |
| **Requisitos funcionais** | `RF-001`, `RF-002`… Cada um verificável, na voz do usuário. |
| **Requisitos não funcionais** | Desempenho, acessibilidade, navegador alvo, volume esperado. |
| **Modelo de dados** | Tabelas, colunas, tipos, índices, chaves estrangeiras, migração necessária. |
| **Telas e rotas** | As URLs exatas (R15), os componentes, e os estados (carregando/vazio/erro/sucesso) de cada tela. |
| **Linguagem** | Quem lê, o vocabulário canônico do domínio, o tom, e as fontes consultadas (R17). |
| **Regras de negócio** | O que é válido, o que é proibido, o que acontece no limite. |
| **Segurança** | Quem pode ver e fazer o quê. Superfície de ataque nova. Nível exigido (R7). Categorias do OWASP Top 10 aplicáveis (N2 ou acima). Revisor humano (N3 ou acima). |
| **Dados pessoais** | Cada campo pessoal, a finalidade e o prazo de retenção. Campo sem finalidade não entra. |
| **Critérios de aceite** | Um por RF, em formato observável: dado / quando / então. |
| **Casos de teste** | `CT-001`… derivados dos critérios. Alimentam o roteiro de QA (R11). |
| **Evidências** | Afirmação → fonte → verificado. (R4) |
| **Questões em aberto** | O que você precisa do usuário para seguir. |

Um requisito bem escrito parece com isto:

```
RF-004. O usuário autenticado pode filtrar seus chamados por status e por período.
  Critério de aceite:
    DADO um usuário com 3 chamados abertos e 2 fechados
    QUANDO ele seleciona status = "fechado" e aplica o filtro
    ENTÃO a lista exibe exatamente 2 chamados, todos com status "fechado",
      e a contagem no topo mostra "2 chamados"
  Casos: CT-014 (filtro simples), CT-015 (filtro combinado com período),
         CT-016 (filtro sem resultado exibe estado vazio),
         CT-SEC-009 (filtro não retorna chamados de outro usuário)
```

Depois: **pare e apresente**. Não escreva código de implementação antes da resposta.

> Aqui está a spec de `<funcionalidade>`. Três decisões que preciso de você:
> `<A>`, `<B>` e `<C>`. São 11 requisitos e 23 casos de teste. Aprova e eu construo?

Se o usuário disser "pode fazer", isso é uma resposta válida: registre na spec como
*aprovado sem revisão* e siga. O portão é sobre consentimento, não cerimônia.

---

## Fase 3: Build

Implemente a spec, e nada além dela. Descobertas que mudam o desenho voltam para a spec com
uma linha de nota; não são absorvidas silenciosamente pelo código.

Toda linha respeita as invariantes: SQL parametrizado (R5), entrada validada e saída
escapada (R6), nenhum segredo em arquivo versionado (R1), nenhuma API inventada (R4),
ambiente validado e migrações compatíveis com a versão anterior do código (R9, R10).

Estrutura: [stack-nextjs-vercel.md](stack-nextjs-vercel.md) ·
[bootstrap-do-ambiente.md](bootstrap-do-ambiente.md) ·
[migracoes-e-rollback.md](migracoes-e-rollback.md).

---

## Fase 4: Validação

Nada aqui é opcional. Nesta ordem: os testes baratos primeiro.

**Código**

```bash
npx tsc --noEmit
npm run lint           # eslint . (o Next 16 não tem mais `next lint`)
npm test               # unitários (Vitest)
npm run build          # tem que construir de verdade, e falha se faltar variável (R9)
vercel build           # reproduz o build da Vercel localmente (R16)
```

**Banco** (no Supabase local ou num branch de preview, nunca no banco de produção)

```bash
npx supabase start       # Postgres, Auth e Storage locais, em contêiner
npx supabase db reset    # reaplica todas as migrações e o supabase/seed.sql no banco LOCAL
npm run db:seed          # rodar duas vezes não pode duplicar nada (R9)
```

**Sempre**

```bash
bash skills/development-pattern-for-web-apps/assets/scripts/scan-secrets.sh
bash skills/development-pattern-for-web-apps/assets/scripts/scan-sql-injection.sh
bash skills/development-pattern-for-web-apps/assets/scripts/scan-linguagem.sh
```

Mais o [checklist de revisão](checklist-de-revisao.md) (R12), lido contra o diff real.

Reporte com honestidade. Se o lint tem 3 avisos, diga "3 avisos, são estes", nunca
"passou tudo".

---

## Fase 5: QA com o Claude Cowork

Gere (ou atualize) `qa/roteiro-de-testes.md` a partir dos requisitos e casos da spec, e
execute-o, ou entregue-o para o Cowork executar.

Saídas: resultado por caso, evidências, defeitos registrados, e os casos que falharam
promovidos a `CT-REG-nnn` na suíte de regressão.

Detalhes: [roteiro-de-testes-cowork.md](roteiro-de-testes-cowork.md).

---

## Fase 6: Release ⛔ PORTÃO

Versão e documentação são **parte da mudança**, não trabalho posterior (R13):

1. Subir a versão no arquivo de configuração, e justificar o nível SemVer.
2. Entrada datada no `CHANGELOG.md`, escrita para quem usa o app.
3. README atualizado: como subir do zero, variáveis de ambiente, o que mudou.
4. Versão do schema registrada em `supabase_migrations.schema_migrations` se houve migração, e a
   migração conferida contra a versão anterior do código (R10).
5. Sanitização + `scan-secrets.sh` sobre o conteúdo staged (R1).
6. Mostrar ao usuário o diff de sanitização, a lista de arquivos e **a versão**.
7. Commit único e coerente. Push para o repositório combinado na Fase 0.

**Nível N3 ou acima (R7): o ⛔ cita o revisor humano.** Todo código de pagamento, webhook,
autenticação e dado sensível foi lido por uma pessoa, e o nome dela está na seção
**Segurança** da spec. Sem esse nome, o portão não abre:

> Pronto para fechar **v1.3.0**. A mudança toca o webhook de pagamento, então é N4: a
> revisão humana foi feita por `<NOME-DO-REVISOR>` em `<DATA>`, registrada na spec 0012.
> Arquivos: `<lista>`. Aprova o commit?

O agente não preenche o nome por conta própria nem aceita "eu reviso depois".

---

## Fase 7: Deploy ⛔ PORTÃO

Nunca por iniciativa própria, sempre nomeando o alvo:

> Pronto para publicar **Controle de Chamados v1.2.0** em
> **`https://seu-dominio.com.br`** (Vercel, projeto `controle-de-chamados`, Production).
> Há 1 migração pendente (`20261010120000_adiciona_anexos.sql`), que só acrescenta uma
> coluna anulável à tabela `chamados`, então a versão atual continua funcionando com ela
> (R10). Confiro o backup do dia (ou gero um `supabase db dump`), aplico a migração com
> `supabase db push` e só depois promovo o deploy.
> Se algo der errado, `vercel rollback` volta o código. Confirma?

Detalhes e rollback: [release-e-deploy.md](release-e-deploy.md).

---

## Mantendo contexto entre sessões

A próxima sessão começa sem nada disso na memória. Dois arquivos resolvem, e valem o minuto
que custam:

- **`AGENTS.md`** na raiz: regras específicas do projeto: qual projeto Vercel, qual banco, quais
  convenções, quais armadilhas você já encontrou. Aponte-o para esta skill.
  → [`../assets/templates/AGENTS.template.md`](../assets/templates/AGENTS.template.md)
- **`specs/`**: o registro do projeto. Quando o comportamento muda, a spec muda no mesmo
  commit do código. Uma spec que divergiu do código é pior que nenhuma spec.
- **`qa/roteiro-de-testes.md`**: a memória do que já quebrou uma vez.
