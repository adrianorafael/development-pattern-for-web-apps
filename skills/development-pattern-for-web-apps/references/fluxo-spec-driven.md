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
| Wizard de instalação, painel de atualização | Corrigir um typo em comentário |
| Qualquer coisa que trate dado pessoal ou pagamento | |

**Na dúvida, escreva a spec.** Sai mais barato que o retrabalho.
Trabalho de "pode pular" continua sujeito a R1, R4, R5, R6, R7 e R12, não existe isenção
dessas.

---

## Fase 0: Bootstrap

As seis perguntas do `SKILL.md`, **em um único lote**:

1. Trilha. PHP+MySQL na Hostinger, ou Next.js na Vercel?
2. Repositório: existe, ou crio novo (privado)?
3. Hospedagem e ambiente: versão do PHP / projeto Vercel / qual banco?
4. Dados e usuários: login? dado pessoal? pagamento? upload? escala?
5. Identidade: nome, slug, versão inicial (`0.1.0`)
6. QA: quem executa o roteiro: você, o Claude Cowork, ou os dois?

Depois: armar `.gitignore`, criar o par `.env`/`.env.example`, rodar a primeira varredura,
confirmar que o repositório é privado.

---

## Fase 1: Pesquisa

Leia a documentação oficial do que você vai usar, **nesta sessão**, e siga os links da
página. Nunca responda só de memória.

| Assunto | Fonte primária |
| --- | --- |
| Funções, extensões, comportamento do PHP | https://www.php.net/manual/pt_BR/ |
| App Router, Server Actions, cache, rotas | https://nextjs.org/docs |
| Classes, tokens, tema, diferenças v3/v4 | https://tailwindcss.com/docs |
| MySQL: tipos, índices, `ON DUPLICATE KEY`, `EXPLAIN` | https://dev.mysql.com/doc/refman/8.0/en/ |
| Limites da hospedagem, PHP disponível, cron | Documentação e hPanel da Hostinger |
| Variáveis de ambiente, funções, limites | https://vercel.com/docs |
| Riscos e defesas por categoria | https://owasp.org/www-project-top-ten/ e as OWASP Cheat Sheets |
| O que já está instalado neste projeto | `composer show`, `npm ls`, `php -m` |

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
| **Segurança** | Quem pode ver e fazer o quê. Superfície de ataque nova. Nível exigido (R7). |
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
escapada (R6), nenhum segredo em arquivo versionado (R1), nenhuma API inventada (R4).

Estrutura por trilha: [stack-php-mysql.md](stack-php-mysql.md) ·
[stack-nextjs-vercel.md](stack-nextjs-vercel.md).

---

## Fase 4: Validação

Nada aqui é opcional. Nesta ordem: os testes baratos primeiro.

**Next.js**

```bash
npx tsc --noEmit
npm run lint
npm test               # unitários (Vitest/Jest)
npm run build          # tem que construir de verdade
```

**PHP**

```bash
find . -name '*.php' -not -path './vendor/*' -print0 | xargs -0 -n1 php -l   # sintaxe
composer exec phpstan analyse    # se instalado
composer exec phpunit            # unitários
```

**Sempre, nas duas trilhas**

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
3. README atualizado: instalação, configuração, o que mudou.
4. Versão do schema registrada na tabela `schema_migrations` se houve migração.
5. Sanitização + `scan-secrets.sh` sobre o conteúdo staged (R1).
6. Mostrar ao usuário o diff de sanitização, a lista de arquivos e **a versão**.
7. Commit único e coerente. Push para o repositório combinado na Fase 0.

---

## Fase 7: Deploy ⛔ PORTÃO

Nunca por iniciativa própria, sempre nomeando o alvo:

> Pronto para publicar **Controle de Chamados v1.2.0** em
> **`https://seu-dominio.com.br`** (Hostinger, `public_html/`). Há 1 migração pendente
> (`0007_adiciona_anexos.sql`), que altera a tabela `chamados`. Faço backup do banco antes.
> Confirma?

Detalhes e rollback: [release-e-deploy.md](release-e-deploy.md).

---

## Mantendo contexto entre sessões

A próxima sessão começa sem nada disso na memória. Dois arquivos resolvem, e valem o minuto
que custam:

- **`AGENTS.md`** na raiz: regras específicas do projeto: qual stack, qual banco, quais
  convenções, quais armadilhas você já encontrou. Aponte-o para esta skill.
  → [`../assets/templates/AGENTS.template.md`](../assets/templates/AGENTS.template.md)
- **`specs/`**: o registro do projeto. Quando o comportamento muda, a spec muda no mesmo
  commit do código. Uma spec que divergiu do código é pior que nenhuma spec.
- **`qa/roteiro-de-testes.md`**: a memória do que já quebrou uma vez.
