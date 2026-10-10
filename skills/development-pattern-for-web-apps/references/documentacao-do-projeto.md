# Documentação do projeto: o que atualizar a cada mudança

> Regra **R13**. Toda mudança atualiza os documentos que ela afeta, **no mesmo commit**.
> A matriz da seção 2 diz quais. Documentação que ficou para depois é documentação que
> não vai acontecer. **Código sem documentação adequada e atualizada não está concluído.**

Documentação desatualizada é pior que documentação ausente. A ausente você percebe e vai
ler o código; a desatualizada você acredita, e ela te leva ao lugar errado com confiança.
Um README que descreve o app de duas versões atrás faz alguém tentar instalar do jeito que
não funciona mais e concluir que o projeto está quebrado.

Por isso a regra é "no mesmo commit", e não "antes do release". Se o commit que muda o
comportamento não muda o texto que descreve o comportamento, o par nunca mais se encontra.

Esta referência vale **sempre que o agente produz ou altera código**, do primeiro arquivo
ao último ajuste. A ordem dela: os princípios (§0), o que existe e o que muda (§1 a §3), as
práticas por assunto (§4 a §10), a verificação depois de cada mudança (§11 a §13) e o
relatório que fecha a entrega (§14).

---

## 0. Princípios

Oito princípios valem para todo documento e todo comentário deste padrão:

1. **Escreva para quem nunca viu o projeto**, inclusive quem está começando. Quem clona não
   sabe o que é RLS, Server Action ou `vercel env pull`: o documento diz o que fazer e onde
   aprender o resto, com o link.
2. **Explique o porquê, não só o quê.** O código já mostra o quê. "A busca escapa `%` e `_`"
   o leitor lê no código; "porque sem isso `100%` casa qualquer título" ele só lê no texto.
3. **Exemplos concretos.** Um comando copiável vale mais que um parágrafo sobre o comando.
   Um par de entrada e saída vale mais que a descrição do formato.
4. **Desatualizada é pior que nenhuma** (o parágrafo do topo). Se não dá para manter um
   documento, apague-o e diga onde a informação passou a viver.
5. **Um idioma só, o do usuário.** Neste padrão, português (pt-BR) em README, docs,
   comentários e mensagens. Nome de API de terceiro fica como está (`getClaims()`,
   `revalidatePath`); o texto em volta, não.
6. **Nenhum segredo real em documento.** Placeholder obviamente falso, sempre:
   `SUA-SENHA`, `sb_secret_SUA-CHAVE-SECRETA`, `usuario@example.com`,
   `seguranca@seu-dominio.com.br` (R1). Vale para exemplo de `curl`, print de tela e log
   colado.
7. **Profundidade proporcional ao projeto.** A tabela abaixo diz o mínimo por porte.
8. **Não crie documento vazio só para cumprir lista.** Um `docs/api.md` com o título e mais
   nada mente: diz que a API foi documentada. Se o documento não se aplica, ele não existe,
   e o relatório de entrega (§14) diz por quê.

### Profundidade por porte

| Porte | Exemplo | O mínimo que existe |
| --- | --- | --- |
| **Script ou ferramenta avulsa** | `scripts/importar-csv.ts`, rodado à mão uma vez por mês | README curto (o que faz, como rodar, um exemplo) e comentários no código onde a decisão não é óbvia (§4) |
| **App sem login (N1)** | Vitrine com formulário de contato | O inventário da §1 (README, CHANGELOG, `AGENTS.md`, `.env.example`, spec, roteiro de QA); TSDoc no que `lib/` e `actions/` exportam (§5); `docs/seguranca.md` curto, com as ações manuais e o canal de reporte (§10) |
| **App com login e banco (N2)** | O sistema de chamados dos exemplos | Tudo acima, mais `docs/banco-de-dados.md` (§8), `docs/api.md` com as Server Actions que mudam estado e os Route Handlers (§7) e `docs/arquitetura.md` (§9) |
| **Dado de terceiros, pagamento, ou API usada por outro sistema (N3, N4)** | Cadastro de clientes, checkout, app consumido por um parceiro | Tudo acima, mais OpenAPI quando há consumidor externo (§7) e o nome do revisor humano em `docs/seguranca.md` |

`docs/decisoes/` (§9) não depende de porte: nasce na primeira decisão que atravessa o
projeto. Os níveis N1 a N4 são os da R7
([linha-de-base-de-seguranca.md](linha-de-base-de-seguranca.md) §2). A tabela nunca
dispensa o que outra regra exige: spec (R3) e roteiro de QA (R11) existem em todo app.

---

## 1. O inventário: o que um projeto deste padrão documenta

| Artefato | O que carrega | Quem lê, e quando |
| --- | --- | --- |
| `README.md` | O que o app faz, tecnologias, como subir do zero, variáveis por ambiente, uso, rotas, testes, deploy, rollback, estrutura, onde está a documentação complementar, solução de problemas | Você daqui a seis meses, e quem clonar |
| `CHANGELOG.md` | O que mudou em cada versão, escrito para quem **usa** o app, com as dependências adicionadas e removidas | Quem vai atualizar e precisa saber o que muda |
| `AGENTS.md` | Convenções do projeto e as armadilhas já encontradas | A próxima sessão do agente, que começa sem memória |
| `specs/<nnnn>-<slug>.md` | O desenho: requisitos numerados, critérios de aceite, casos, decisões | Você, quando for mudar aquela funcionalidade |
| `qa/roteiro-de-testes.md` | O procedimento de QA, caso a caso | O Claude Cowork, ou quem testar |
| `qa/dados-de-teste.md` | Usuários, seed determinístico, como restaurar o estado | Idem |
| `.env.example` | Todas as chaves de configuração, com placeholder e comentário dizendo o que é, onde obter e se é secreta | Quem clona, e o `lib/env.ts` que as valida (R9) |
| `lib/env.ts` | O esquema Zod de cada variável: o que falta quebra o build com mensagem clara | O build, e quem configura o projeto na Vercel (R9) |
| `supabase/migrations/<timestamp>_<nome>.sql` | A evolução do schema, ordenada e compatível com a versão anterior do código, cada arquivo abrindo com o que muda e se é aditivo ou destrutivo | O Supabase CLI (`supabase db push`), antes de promover para produção (R10) |
| `scripts/seed.ts` | O estado inicial idempotente, incluindo o administrador | `npm run db:seed` (R9) |
| `package.json` (campo `version`) e `package-lock.json` | A fonte da verdade da versão em SemVer; o lockfile, a das dependências instaladas | Todo o resto; `npm ci` |
| Comentários e TSDoc no código | O porquê do que não é óbvio; o contrato do que é exportado | Quem vai mexer naquele arquivo, e o editor, que mostra o TSDoc ao passar o mouse |
| `docs/arquitetura.md` | Visão geral, diagrama, onde cada parte vive no código | Quem chega ao projeto e precisa do mapa antes do código |
| `docs/decisoes/<nnnn>-<slug>.md` | Cada decisão que atravessa o projeto: contexto, decisão, alternativas, consequências | Quem vai questionar a escolha daqui a um ano |
| `docs/seguranca.md` | Autenticação e autorização, proteções ativas, **ações manuais fora do código**, como reportar falha | Quem configura um ambiente novo, e quem encontrou uma falha |
| `docs/banco-de-dados.md` | Tabelas, relacionamentos, quem lê e quem altera cada dado, buckets, lista de migrações | Quem escreve a próxima migração ou política |
| `docs/api.md` | Route Handlers, webhooks e Server Actions que mudam estado: método, rota, autenticação, entrada, respostas | Quem integra, e quem testa com outra conta (R11) |
| Página do projeto (se houver) | A vitrine pública | Visitante que nunca viu o projeto |

A tabela `supabase_migrations.schema_migrations` no banco não é documento, mas cumpre o mesmo papel: ela diz
até onde aquele banco está. Mantê-la correta é parte da R13.

Os cinco documentos de `docs/` têm modelo em `assets/templates/`:
[`arquitetura.template.md`](../assets/templates/arquitetura.template.md),
[`decisao.template.md`](../assets/templates/decisao.template.md),
[`seguranca.template.md`](../assets/templates/seguranca.template.md),
[`banco-de-dados.template.md`](../assets/templates/banco-de-dados.template.md) e
[`api.template.md`](../assets/templates/api.template.md). Cada modelo diz no topo quando
**não** criá-lo.

---

## 2. A matriz: mudei isso, atualizo o quê

Leia a linha da sua mudança. Tudo marcado é obrigatório no **mesmo commit**. São duas
tabelas: a primeira cobre os documentos da raiz; a segunda, os comentários do código e os
documentos de `docs/`. Uma mudança pode aparecer nas duas.

### 2a. Documentos da raiz

| Mudei… | README | CHANGELOG | spec | QA | AGENTS | `.env.example` | Versão | Página |
| --- | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: |
| Comportamento visível ao usuário | ✅ | ✅ | ✅ | ✅ | | | ✅ | ✅ |
| Funcionalidade nova | ✅ | ✅ | ✅ | ✅ | | | ✅ | ✅ |
| Rota nova ou renomeada (R15) | ✅ | ✅ | ✅ | ✅ | | | ✅ | ✅ |
| Campo novo em formulário | | ✅ | ✅ | ✅ | | | ✅ | |
| Tabela ou coluna nova | | ✅ | ✅ | ✅ | | | ✅ | |
| Migração destrutiva | ✅ | ✅ | ✅ | ✅ | | | ✅ | |
| Variável de ambiente nova | ✅ | ✅ | | | | ✅ | ✅ | |
| Dependência nova ou removida | ✅ | ✅ | | | | | ✅ | |
| Passo para subir do zero mudou (R9) | ✅ | ✅ | | ✅ | | | ✅ | ✅ |
| Correção de bug | | ✅ | | ✅ | | | ✅ | |
| Correção de segurança | ✅ | ✅ | ✅ | ✅ | | | ✅ | |
| Dado pessoal novo (campo, finalidade ou retenção) | | ✅ | ✅ | ✅ | | | ✅ | |
| Texto de interface (R17) | | | ✅ | ✅ | | | ✅ | |
| Convenção nova, ou armadilha descoberta | | | | | ✅ | | | |
| Refatoração sem mudança visível | | | | | | | | |

### 2b. Código e `docs/`

Cada coluna de `docs/` vale **se o documento existir** (a tabela de porte da §0 diz quando
ele deve existir).

| Mudei… | Comentários e TSDoc | `arquitetura` | `decisoes/` | `seguranca` | `banco-de-dados` | `api` |
| --- | :-: | :-: | :-: | :-: | :-: | :-: |
| Função, componente ou módulo exportado (novo, renomeado, assinatura) | ✅ | | | | | |
| Regra de negócio, contorno de bug, trecho sensível de segurança | ✅ | | | | | |
| Route Handler, webhook ou Server Action que muda estado | ✅ | | | | | ✅ |
| Migração (tabela, coluna, função, gatilho) | | | | | ✅ | |
| Política RLS, grant ou bucket do Storage | | | | ✅ | ✅ | |
| Autenticação, `proxy.ts`, `next.config.ts` (cabeçalhos), `lib/supabase/` | ✅ | | | ✅ | | |
| Configuração manual em painel (Supabase, Vercel, GitHub) | | | | ✅ | | |
| Serviço externo novo, camada nova, fluxo entre partes mudou | | ✅ | | | | |
| Escolha que atravessa o projeto (biblioteca central, padrão de acesso, troca de provedor) | | ✅ | ✅ | | | |
| Refatoração sem mudança visível | ✅ | | | | | |

A última linha não é contradição com a da 2a: refatorar não muda README nem CHANGELOG, mas
muda os comentários do código refatorado **e dos que o chamam**, e um TSDoc que descrevia a
função antiga passa a mentir.

Três linhas da 2a merecem explicação:

- **Correção de bug atualiza o roteiro de QA**, sempre. O defeito corrigido vira um caso
  `CT-REG-nnn`, senão ele volta três versões depois (R11).
- **Correção de segurança atualiza o README**, e o CHANGELOG a nomeia com a urgência de
  atualizar. Esconder isso deixa quem está na versão antiga sem saber que precisa subir.
- **Refatoração sem mudança visível não atualiza nenhum documento da raiz**, e essa linha
  existe justamente para você poder dizer "esta não precisa" com respaldo, em vez de
  inventar uma entrada de CHANGELOG para uma mudança que ninguém percebe.

### A pergunta que resolve os casos duvidosos

> Se alguém instalar o app amanhã seguindo o README, e usar o app seguindo o CHANGELOG,
> algo vai surpreender essa pessoa por causa desta mudança?

Se sim, o documento entra no commit. Se não, não entra. Para os documentos de `docs/`, a
pergunta é a mesma, com outra pessoa: quem vai escrever a próxima migração, a próxima
política ou a próxima integração vai se surpreender?

---

## 3. O que atualizar dentro de cada documento

Marcar o documento na matriz é metade. A outra metade é saber **qual seção** mexer.

**README.** As seções que envelhecem primeiro são, nesta ordem: requisitos (versão do Node),
variáveis de ambiente (chave nova, e em quais ambientes da Vercel ela existe), rotas (R15), solução de problemas (todo defeito recorrente vira
uma linha) e atualização. A árvore de estrutura do projeto é a que mais fica para trás:
confira-a contra o disco, não contra a memória. A seção "Documentação complementar" lista
só o que existe: link para documento que não existe é o documento vazio do princípio 8.

**CHANGELOG.** Escreva para quem **usa** o app, não para quem leu o diff. "Corrige o
tratamento de nulo em `buscarChamados()`" não diz nada; "a busca deixava a listagem
em branco quando o título tinha apóstrofo" diz. Migração vai numa subseção própria, dizendo
se é aditiva ou destrutiva e quanto tempo pode levar em base grande. Dependência vai na
subseção "Dependências" (§6).

**spec.** Quando o comportamento muda, a spec muda **no mesmo commit**. Uma spec que
divergiu do código é pior que nenhuma: ela descreve com autoridade um sistema que não
existe. Se a mudança foi grande, é spec nova; se foi ajuste de regra, é edição com nota.

**Roteiro de QA.** Caso novo para requisito novo; caso `CT-REG-nnn` para todo defeito
corrigido; caso `CT-SEC-nnn` para todo campo novo que chega ao banco (R5) e todo ponto novo
que imprime dado do usuário (R6). E a matriz de rastreabilidade volta a fechar.

**AGENTS.md.** Este é o que quase todo mundo esquece, e é o que mais economiza tempo depois.
Toda vez que você descobre uma armadilha (a variável existe em Production mas não em
Preview, o branch de preview do Supabase não recebeu a migração, a função estoura o tempo
máximo do plano), ela vira uma linha ali. A próxima sessão começa adiantada em vez de repetir a descoberta.

**Dado pessoal novo.** A seção "Dados pessoais" da spec ganha a linha (campo, finalidade,
retenção), a política de privacidade do app (rota `/politica-de-privacidade`) passa a citar
o campo no mesmo commit, e o roteiro ganha o que for preciso dos casos `CT-LGPD`. Campo
pessoal sem finalidade escrita não entra no formulário.

**`.env.example` e `lib/env.ts`.** Chave nova entra nos dois no mesmo commit em que entra no
código, e no painel da Vercel antes do deploy. No `.env.example`, o comentário de cada chave
diz três coisas: o que é, **onde obter** (painel e caminho do menu) e se é **secreta**
(nunca com `NEXT_PUBLIC_`, nunca no navegador). O teste é concreto: alguém que clone o
repositório e rode `vercel env pull .env.local` consegue rodar o app?

**Página do projeto.** Se existir, ela e o README afirmam as mesmas coisas em profundidades
diferentes. Quando um muda, o outro muda junto, com os mesmos números.

---

## 4. Comentários no código

Comentário existe para o que o código **não consegue dizer**: por que esta forma e não a
óbvia. Quatro situações pedem comentário, sempre:

| Situação | O que o comentário diz |
| --- | --- |
| Decisão não óbvia | Por que esta forma, e o que quebra se alguém "simplificar" |
| Regra de negócio | A regra em português, e de onde ela vem (spec, `RF-nnn`) |
| Contorno de bug | Qual defeito, de qual pacote e versão, e quando o contorno pode sair |
| Trecho sensível de segurança | O que não pode mudar de lugar nem de forma, e o que se abre se mudar |

```ts
// ❌ comentário que repete o código: o leitor já leu a linha de baixo
// incrementa o contador
tentativas++;
// busca o chamado
const { data } = await supabase.from('chamados').select('id, titulo').eq('id', id);

// ✅ decisão não óbvia: o porquê que a linha não mostra
// 404, e não 403: um 403 confirmaria que o chamado existe e é de outra pessoa.
if (!chamado) notFound();

// ✅ regra de negócio, com a fonte
// Chamado fechado não aceita anexo novo (spec 0003, RF-005).
if (chamado.status === 'fechado') return { erro: 'Este chamado está fechado.' };

// ✅ contorno de bug, com o caminho para removê-lo
// Contorno de <defeito> em <pacote>@<versão> (<link da issue>). Remova quando o
// projeto passar para a versão que corrige; o caso CT-REG-<nnn> prova a remoção.

// ✅ trecho sensível: o que não pode mudar
// criarClienteAdmin() ignora a RLS. Ele só vem DEPOIS de exigirSessao() e da conferência
// do dono logo acima; subir esta linha entrega o anexo de qualquer pessoa.
const admin = criarClienteAdmin();
```

### Pendência: `TODO` e `FIXME` sempre com descrição

O formato é fixo, para o scanner e para quem lê: `// TODO: <o que falta e por quê>` e
`// FIXME: <o que está errado>`. Nunca a palavra sozinha.

```ts
// ❌ ninguém sabe o que falta, nem se ainda falta
// TODO
// FIXME: arrumar

// ✅ diz o que falta, por quê, e onde a decisão está registrada
// TODO: paginar a lista de anexos; acima de mil linhas a consulta passa de 1 s (spec 0003, débito técnico).
// FIXME: a contagem inclui anexos já apagados do Storage e não da tabela; corrigir junto com a exclusão em lote.
```

Todo `TODO` e `FIXME` deixado numa entrega aparece no relatório (§14). Pendência que não
aparece em lugar nenhum fora do código é pendência esquecida.

### Código comentado: apague

```ts
// ❌ "para o caso de precisar": ninguém sabe se ainda funciona, nem por que saiu
// const { data } = await criarClienteAdmin().from('chamados').select('*');
// return data;
```

✅ Apague. O Git guarda a versão anterior, e `git log -S '<trecho>'` encontra o commit
que a removeu. Código comentado envelhece sem compilar e, como no exemplo acima, às vezes
guarda justamente a forma insegura que alguém vai "reativar".

E um comentário nunca credita uma ferramenta de IA como autora do trecho (R18).

---

## 5. Funções e módulos: TSDoc

Todo elemento **público ou importante** leva um bloco TSDoc: o que `lib/` e `actions/`
exportam, cada Route Handler, os componentes de `components/` com props não óbvias e os
tipos de domínio em `types/`. O bloco diz:

- o que a função faz, numa frase, e o porquê quando não é óbvio;
- cada parâmetro (`@param nome - descrição`) e o retorno (`@returns`);
- os erros que ela lança ou repassa (`@throws`);
- um exemplo de uso (`@example`), quando ele ajuda mais que a descrição;
- `@deprecated` no que está sendo aposentado, com o substituto: é a fase "migrate" do
  expand → migrate → contract (R10) aplicada ao código.

Tags conferidas na referência de tags do TSDoc (https://tsdoc.org/, 2026-10-10): `@param`,
`@returns`, `@throws`, `@example`, `@remarks` e `@deprecated` estão entre as padronizadas, e
o exemplo da página separa o nome do parâmetro da descrição com hífen
(`@param x - The first input number`).

**Em TypeScript os tipos já estão na assinatura.** O TSDoc explica o **significado**: a
unidade, o formato esperado, o que `false` quer dizer. Repetir o tipo é ruído que envelhece
quando o tipo muda.

```ts
/**
 * ❌ repete a assinatura e não diz nada que o tipo já não diga
 * @param chave string - a chave
 * @param max number - o máximo
 * @returns Promise<boolean>
 */
```

```ts
// ✅ lib/limite.ts
import 'server-only';
import { sql } from '@/lib/db';

/**
 * Registra uma tentativa e diz se ela ainda cabe no limite da janela.
 *
 * A contagem vive na tabela `eventos_limite`, e não na memória do processo, porque cada
 * invocação da função pode cair numa instância nova da Vercel.
 *
 * @param chave - O que está sendo limitado, no formato `<ação>:<identificador>`, por
 *   exemplo `login:usuario@example.com`. Normalize antes (e-mail em minúsculas), senão
 *   `Usuario@` e `usuario@` contam separado.
 * @param max - Quantas tentativas a janela admite, contando a atual.
 * @param janelaSeg - Tamanho da janela, em segundos.
 * @returns `true` se a tentativa está dentro do limite; `false` se deve ser recusada.
 * @throws Repassa o erro do driver `postgres` quando o banco não responde. Quem chama
 *   decide se falha fechado (recusa) ou aberto, e escreve a decisão num comentário.
 *
 * @example
 * if (!(await permitir(`login:${email.toLowerCase()}`, 5, 15 * 60))) {
 *   return { erro: 'Muitas tentativas. Aguarde 15 minutos e tente de novo.' };
 * }
 */
export async function permitir(chave: string, max: number, janelaSeg: number): Promise<boolean> {
  // …corpo em linha-de-base-de-seguranca.md, §7
}
```

Um arquivo de `lib/` com mais de uma responsabilidade ganha, no topo, um bloco curto
dizendo o que ele reúne e o que **não** deve entrar nele (por exemplo: "acesso a dados do
servidor; nada aqui roda no navegador, por isso `import 'server-only'`"). Os modelos `.ts`
desta skill (`assets/templates/*.ts.template`) seguem a mesma regra.

---

## 6. Dependências

Cada pacote é código de terceiro rodando no build, no servidor e às vezes no navegador.
Documentá-lo é dizer **por que** ele está ali, para que alguém consiga tirá-lo depois.

| Momento | O que fazer, no mesmo commit |
| --- | --- |
| **Antes de instalar** | Conferir nome, mantenedores e idade ([protocolo-de-verificacao.md](protocolo-de-verificacao.md) §2, "Antes de instalar um pacote") |
| **Ao adicionar** | `package.json` e `package-lock.json` juntos ([git-e-publicacao.md](git-e-publicacao.md) §5, "O lockfile é contrato"); CHANGELOG, subseção "Dependências": pacote, versão e motivo; README, "Requisitos" ou "Tecnologias", se a pessoa precisa saber que ele existe (CLI, serviço, versão mínima) |
| **Ao atualizar de major** | CHANGELOG, "Dependências": de que versão para qual, e o que mudou para o app |
| **Ao remover** | `npm uninstall <pacote>` (tira do `package.json` e do lockfile); CHANGELOG, "Dependências": removido, e por quê |

```markdown
### Dependências
- Adicionado `resend@<versão>`: envio do e-mail de aviso quando o chamado é fechado.
- Removido `date-fns`: as duas datas formatadas passaram a usar `Intl.DateTimeFormat`.
```

**Dependência sem uso sai.** Ela continua recebendo alerta do Dependabot, entrando no
`npm audit` e pesando no build sem dar nada em troca. Para achar candidatas, a busca manual
funciona em qualquer projeto:

```bash
# Para cada dependência de produção, procura o nome entre aspas em algum arquivo versionado
# (import, require, @import do CSS, import 'server-only'). O que sobra é candidato, não veredito.
for p in $(node -p "Object.keys(require('./package.json').dependencies ?? {}).join(' ')"); do
  git grep -qE "['\"]$p(/[^'\"]*)?['\"]" -- ':!package.json' ':!package-lock.json' \
    || echo "sem uso aparente: $p"
done
```

(Testado num repositório descartável em 2026-10-10: acusou o pacote sem import e não acusou
`next`, `server-only`, `tailwindcss` nem `@supabase/ssr`.) Pacote usado só por um script
do `package.json` ou por um arquivo de configuração aparece como falso positivo: confira
antes de remover. Para uma varredura mais completa (dependências, exportações e arquivos sem
uso), existe o `knip` (`npm view knip`: versão 6.41.0, "Find and fix unused dependencies,
exports and files in your TypeScript and JavaScript projects", repositório
`github.com/webpro-nl/knip`, conferido em 2026-10-10). Ele é pacote como outro qualquer:
passa pela conferência de antes de instalar, e entra no projeto só com o sim do usuário.

---

## 7. API

Num app Next.js deste padrão, "a API" é tudo o que responde a uma requisição HTTP sem ser
uma página:

| O que | Onde | Por que documentar |
| --- | --- | --- |
| **Route Handlers** | `app/**/route.ts` | Têm método e URL fixos; alguém vai chamá-los por `curl` |
| **Webhooks** | Route Handler que recebe de terceiro | Autenticam pela assinatura do provedor, não pelo cookie ([linha-de-base-de-seguranca.md](linha-de-base-de-seguranca.md) §4) |
| **Server Actions que mudam estado** | `actions/*.ts`, `'use server'` | São endpoints HTTP públicos, chamados por POST na URL da página, mesmo que pareçam função ([stack-nextjs-vercel.md](stack-nextjs-vercel.md) §4); quem testa com outra conta precisa saber que existem (R11) |

Para cada um, `docs/api.md` diz: método e rota (ou o nome da action e o arquivo),
**autenticação** (cookie de sessão, assinatura, nenhuma), **permissões** (dono, admin),
parâmetros e corpo com as regras de validação, **respostas de sucesso e de erro** com o
código HTTP e o corpo, e um exemplo. Da Server Action documenta-se o contrato da função
(entrada, autorização, retorno, efeito), não o formato da requisição, que é interno do
Next. Modelo: [`../assets/templates/api.template.md`](../assets/templates/api.template.md).

**OpenAPI quando há consumidor externo.** Se outro sistema (um parceiro, um app móvel, uma
automação de terceiro) chama a sua API, `docs/api.md` ganha a companhia de um
`docs/openapi.yaml`, legível por máquina. A versão vigente da especificação é a 3.2.1
(https://spec.openapis.org/oas/latest.html, conferida em 2026-10-10). Sem consumidor externo,
o Markdown basta: OpenAPI que ninguém consome é o documento vazio do princípio 8.

---

## 8. Banco de dados

`docs/banco-de-dados.md` responde, sem abrir o SQL, a três perguntas: quais tabelas existem
e como se ligam; **quem lê e quem altera cada dado**; e qual migração trouxe cada coisa.

- **Tabelas e relacionamentos**: uma linha por tabela e um diagrama Mermaid `erDiagram`. O
  GitHub desenha blocos ` ```mermaid ` em arquivos Markdown
  (https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-diagrams,
  conferido em 2026-10-10).
- **Matriz de acesso por tabela**: `anon`, `authenticated` dono, `authenticated` outro
  usuário, admin (`app_metadata.papel`), `service_role` e conexão direta (`POSTGRES_URL`),
  espelhando as políticas e os grants da migração. É o documento que o caso CT-SEC-032
  confere.
- **Buckets do Storage**: público ou privado, limite de tamanho, tipos aceitos, política.
- **Funções** chamadas por `.rpc()` ou por gatilho, com `security definer` ou `invoker`.
- **Migrações**: uma linha por arquivo, dizendo o que muda e se é aditiva ou destrutiva.

E **cada arquivo de migração abre com um comentário** que diz o mesmo, para quem lê o SQL
sem o documento ao lado:

```sql
-- supabase/migrations/20261010143000_adiciona_comentarios.sql
-- O que muda: cria public.comentarios (RLS ligada, políticas por dono do chamado) e
--   a coluna chamados.prazo_em.
-- Tipo: aditiva. Compatível com a versão anterior do código (R10).
```

O modelo [`../assets/templates/banco-de-dados.template.md`](../assets/templates/banco-de-dados.template.md)
já vem preenchido com o schema e as políticas reais de `schema.sql.template` e
`politicas-rls.sql.template`; ao copiá-lo, mantenha-o igual ao **seu** SQL, não ao do modelo.

---

## 9. Arquitetura e decisões

**`docs/arquitetura.md`** é o mapa: o que o sistema faz em três frases, um diagrama Mermaid
simples (navegador, Vercel, Supabase, serviços externos), onde cada parte vive no código e o
caminho de uma requisição típica. Uma página. Se passar de duas, o detalhe é de outro
documento. Modelo: [`../assets/templates/arquitetura.template.md`](../assets/templates/arquitetura.template.md).

**`docs/decisoes/<nnnn>-<slug>.md`** registra uma decisão por arquivo: contexto, decisão,
alternativas consideradas e consequências. Numeração sequencial e estável, como a das
migrações: decisão aceita não é reescrita, é **substituída** por uma nova que aponta para
ela. Modelo: [`../assets/templates/decisao.template.md`](../assets/templates/decisao.template.md).

A diferença para a spec:

| | Spec (`specs/`) | Decisão (`docs/decisoes/`) |
| --- | --- | --- |
| Escopo | Uma funcionalidade | Atravessa o projeto inteiro |
| Exemplo | "Anexos em chamados: até 5 arquivos de 5 MB" | "Supabase em vez de outro Postgres"; "RLS e conferência no servidor, as duas" |
| Vida | Muda quando a funcionalidade muda | Fica; uma decisão nova a substitui |

Uma spec pode **gerar** uma decisão (a funcionalidade de anexos levou a escolher o Supabase
Storage para todo arquivo do app); nesse caso a seção de decisões da spec aponta para o
arquivo em `docs/decisoes/`, em vez de repetir o texto.

---

## 10. Segurança

`docs/seguranca.md` reúne o que, espalhado, ninguém encontra: como a autenticação e a
autorização funcionam, quais proteções estão ativas e onde, **o que foi configurado fora do
código** e como reportar uma falha. O README do app resume em poucas linhas e remete a ele.
Modelo: [`../assets/templates/seguranca.template.md`](../assets/templates/seguranca.template.md).

A seção que mais importa é **"Ações manuais fora do código"**. Ela é o que um clone não
traz: Site URL e Redirect URLs do Supabase Auth, chaves e a data da última rotação, teto de
gasto na Vercel, no Supabase e em cada API paga, Deployment Protection, Dependabot e push
protection no GitHub, backup do plano Free. Cada linha diz onde fica no painel, o estado e
a fonte ([linha-de-base-de-seguranca.md](linha-de-base-de-seguranca.md),
[segredos-e-configuracao.md](segredos-e-configuracao.md)). Projeto novo, ambiente novo ou
troca de dono começa por essa lista.

**Como reportar.** Um contato (`seguranca@seu-dominio.com.br` no modelo) e o pedido de não
publicar antes da correção. O GitHub trata um arquivo `SECURITY.md` como arquivo de saúde da
comunidade, com "instructions on how to report a security vulnerability in your project", e
o procura em `.github/`, na raiz e em `docs/`, nessa ordem
(https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file
e https://docs.github.com/en/code-security/getting-started/adding-a-security-policy-to-your-repository,
conferidos em 2026-10-10). Se quiser esse reconhecimento, crie um `SECURITY.md` curto com a
seção "Como reportar" e um link para `docs/seguranca.md`, em vez de duplicar o resto.

---

## 11. Verificação obrigatória depois de qualquer mudança

Depois de **toda** mudança de código, inclusive a "minúscula", percorra a lista inteira. Item
que não se aplica é marcado como tal no relatório (§14), não pulado em silêncio.

1. **Comentários do código alterado e dos que o chamam.** Um comentário que descrevia o
   comportamento antigo, em outro arquivo, mente agora.
2. **TSDoc** das exportações novas ou alteradas: parâmetros, retorno, erros e exemplo batem
   com a assinatura e com o comportamento.
3. **README**: requisitos, tecnologias, variáveis, rotas, estrutura, documentação
   complementar.
4. **`.env.example` contra o código**: toda variável lida no código está nele, e toda chave
   dele ainda é lida (comando abaixo).
5. **Dependências e lockfile**: pacote novo ou removido registrado no CHANGELOG;
   `package-lock.json` no mesmo commit que o `package.json`.
6. **API** (`docs/api.md`): rota, action, entrada ou resposta mudou.
7. **Banco** (`docs/banco-de-dados.md`): tabela, coluna, política, grant, bucket ou função
   mudou; a migração abre com o comentário de o que muda e tipo.
8. **Segurança** (`docs/seguranca.md`): autenticação, `proxy.ts`, políticas,
   `next.config.ts`, `lib/supabase/` ou configuração de painel mudou.
9. **Arquitetura e decisões**: parte nova, fluxo novo, escolha que atravessa o projeto.
10. **CHANGELOG**: entrada em `[Não publicado]`, na categoria certa.

### A busca no projeto inteiro

A lista acima pega o que você lembra. A busca pega o que você esqueceu. Para **cada** nome
que a mudança tocou (função, variável, rota, comando, pacote, tabela, coluna):

```bash
git grep -n "<nome-antigo>"     # tudo o que ainda cita o nome velho: código, docs, comentários, testes
git grep -n "<nome-novo>"       # onde o nome novo já aparece, e onde ainda deveria aparecer
```

Sem `--untracked`, `git grep` procura só nos arquivos que o Git rastreia, o que deixa de
fora `node_modules/` e `.env.local`; arquivo novo ainda não adicionado também fica de fora,
então rode a busca depois do `git add`. Zero ocorrência do nome antigo é o resultado esperado de uma
renomeação; qualquer ocorrência é um documento, comentário ou teste a corrigir, ou uma
menção histórica deliberada (CHANGELOG, decisão substituída), dita no relatório.

O `.env.example` contra o código, nos dois sentidos:

```bash
exemplo=$(grep -oE '^#? ?[A-Z][A-Z0-9_]*=' .env.example | tr -d '# =' | sort -u)
codigo=$(git grep -ohE '\benv\.[A-Z][A-Z0-9_]*' -- '*.ts' '*.tsx' '*.mjs' | sed 's/.*env\.//' | sort -u)
echo "Lidas no código e ausentes do .env.example:"; comm -13 <(echo "$exemplo") <(echo "$codigo")
echo "No .env.example e não lidas no código:";      comm -23 <(echo "$exemplo") <(echo "$codigo")
```

(Testado em 2026-10-10 num repositório descartável: pega `env.X` e `process.env.X`.) A
primeira lista tem de sair vazia. A segunda pode trazer, de propósito, as cópias que a
integração do Supabase cria e o código não lê (`POSTGRES_USER`, `SUPABASE_URL`): o
`.env.example` as lista para quem clona entender o que chegou pelo `vercel env pull`. Fora
essas, chave sem leitor sai do `.env.example`, do `lib/env.ts` e do painel da Vercel.

---

## 12. Verificação mecânica

```bash
bash skills/development-pattern-for-web-apps/assets/scripts/scan-doc-sync.sh
```

O scanner lê o que está no *staging* e aponta o que a matriz pede e você não tocou. Ele é
consultivo por natureza: acusa `CHANGELOG.md` intocado quando há código novo, `.env.example`
intocado quando apareceu uma variável de ambiente nova, `version` do `package.json` parado quando há
mudança de comportamento, roteiro de QA parado quando há migração.

Ele não sabe se a mudança é visível ao usuário. Isso é julgamento seu, e por isso os achados
dele são avisos com uma pergunta, não veredicto. Ele também não substitui a busca da §11:
o scanner olha o diff, e o comentário desatualizado mora fora dele.

---

## 13. Checklist antes do commit

- [ ] Localizei a linha da minha mudança na matriz da seção 2 (2a e 2b)
- [ ] Todo documento marcado foi atualizado **neste commit**, não no próximo
- [ ] Percorri os dez itens da verificação obrigatória (§11) e rodei `git grep` para cada nome alterado
- [ ] README: a seção certa, não só o topo. A árvore de estrutura conferida contra o disco; "Documentação complementar" só com o que existe
- [ ] CHANGELOG: escrito para quem usa, com a migração declarada como aditiva ou destrutiva e a dependência nova ou removida em "Dependências"
- [ ] spec: atualizada se o comportamento mudou, ou spec nova se a mudança foi grande
- [ ] Roteiro de QA: caso novo, caso de regressão do defeito corrigido, casos de segurança
- [ ] AGENTS.md: armadilha descoberta virou linha
- [ ] Dado pessoal novo: spec ("Dados pessoais") e política de privacidade atualizadas juntas
- [ ] `.env.example` e `lib/env.ts`: chave nova presente, com placeholder e comentário (o que é, onde obter, se é secreta); as duas listas da §11 conferidas
- [ ] Comentários: decisão não óbvia explicada, nada óbvio comentado, nenhum código comentado, `TODO`/`FIXME` só com descrição (§4)
- [ ] TSDoc em toda exportação pública nova ou alterada, explicando o significado e não repetindo o tipo (§5)
- [ ] `docs/` (se existir): `api`, `banco-de-dados`, `seguranca`, `arquitetura` e `decisoes/` conforme a matriz 2b
- [ ] Migração nova abre com o comentário de o que muda e se é aditiva ou destrutiva (§8)
- [ ] Versão subida no `package.json`, com o nível SemVer justificado (R13, [release-e-deploy.md](release-e-deploy.md))
- [ ] Página do projeto, se existir, afirmando os mesmos números que o README
- [ ] `scan-doc-sync.sh` sem aviso que eu não saiba explicar

---

## 14. Relatório de entrega

Toda entrega termina com um relatório curto da documentação, junto do resumo do diff que a
pessoa lê antes do portão ([checklist-de-revisao.md](checklist-de-revisao.md) §9). Ele diz
o que foi feito **e o que não foi**, com o motivo: é o que separa "documentei" de "achei que
tinha documentado".

```markdown
## Documentação desta entrega

**Criados:** `docs/api.md` (Route Handler `POST /api/chamados` e as actions `criarChamado`
e `fecharChamado`).
**Atualizados:** README (Variáveis de ambiente: `RESEND_API_KEY`; Documentação
complementar: link para `docs/api.md`) · CHANGELOG (`[Não publicado]`: Adicionado e
Dependências) · `.env.example` (`RESEND_API_KEY`, com onde obter e "secreta") ·
`docs/banco-de-dados.md` (tabela `comentarios` e a migração `20261010143000_adiciona_comentarios.sql`).
**Removidos:** comentário em `lib/db.ts` que descrevia o filtro antigo da busca.
**Comentários e TSDoc:** TSDoc novo em `permitir()` e `criarComentario()`; comentário de
segurança em `app/chamados/[id]/anexos/actions.ts` (ordem de `criarClienteAdmin()`).
**Dependências:** adicionado `resend@<versão>`, para o e-mail de aviso; registrado no
CHANGELOG ("Dependências") e no README ("Tecnologias").
**Não se aplicava:** `docs/seguranca.md` (nenhuma mudança de autenticação, política,
cabeçalho ou painel) · `docs/arquitetura.md` (nenhuma parte nova; o Resend já constava).
**Sem documentação, e por quê:** o limite de envio do Resend no plano gratuito; não consegui
conferir o valor na documentação do provedor nesta sessão. Fica como pergunta em aberto na spec.
**TODOs registrados:** `lib/anexos.ts` l. 52: `TODO: paginar a lista de anexos; acima de mil
linhas a consulta passa de 1 s (spec 0003, débito técnico).`
**Busca global:** `git grep -n "buscarChamados"` sem ocorrência fora do CHANGELOG.
```

Nunca "documentação atualizada" sem a lista. Um relatório que não tem a linha "Não se
aplicava" ou "Sem documentação" quase sempre esqueceu alguma coisa.
