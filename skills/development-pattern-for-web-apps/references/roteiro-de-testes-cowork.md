# Roteiro de testes para o Claude Cowork

> Regra **R11**. Toda aplicação entregue vem com `qa/roteiro-de-testes.md`: um documento
> que outro agente consegue **executar** navegando pela aplicação, sem ter participado do
> desenvolvimento e sem fazer perguntas.

O roteiro não é um resumo do que foi feito. É um **procedimento**. A diferença aparece na
frase que cada passo produz: "verificar se a listagem funciona" não é testável; "clicar em
`Filtrar` e conferir que a tabela exibe exatamente 2 linhas, ambas com status `Fechado`" é.

Ele é derivado dos requisitos numerados da spec (R3). Se um requisito não gerou caso de
teste, ou o requisito é decorativo, ou o roteiro está incompleto, e o roteiro diz qual dos
dois.

Modelo completo:
[`../assets/templates/roteiro-de-testes.template.md`](../assets/templates/roteiro-de-testes.template.md).

---

## 1. Onde ele vive

```
qa/
├── roteiro-de-testes.md          # o roteiro, versionado junto com o código
├── dados-de-teste.md             # usuários, seeds e como restaurar o estado inicial
├── evidencias/                   # capturas geradas na execução: geralmente ignorado no git
└── execucoes/
    └── 2026-09-05-v1.3.0.md      # resultado de uma execução: o que passou, o que falhou
```

O roteiro é atualizado **no mesmo commit** que muda o comportamento. Um roteiro que descreve
a tela de duas versões atrás é pior que nenhum: ele produz falsos negativos e treina quem
executa a ignorá-lo.

---

## 2. Preparar a aplicação para ser testável

Um agente navegando a interface precisa de âncoras estáveis. Isso é trabalho da Fase 3
(build), não do QA.

| Necessidade | Como atender |
| --- | --- |
| Localizar elementos sem depender de texto ou posição | `data-testid` em campos, botões, linhas de tabela e mensagens |
| Saber que a operação terminou | Um elemento de resultado observável (`[data-testid="alerta-sucesso"]`), não só um redirecionamento |
| Estado inicial idêntico a cada execução | Seed determinístico documentado, sempre os mesmos registros, os mesmos IDs, as mesmas datas |
| Repetir o teste sem sujar a base | Procedimento de reset: no Supabase local, `npx supabase db reset` (reaplica migrações e `supabase/seed.sql`) e `npm run db:seed`; no preview, apagar e recriar o branch de preview do Supabase (`npx supabase branches delete` e `create`, ou pelo painel), que nasce aplicando as migrações e o seed |
| Testar papéis diferentes | Um usuário de teste por papel, com senha documentada em `qa/dados-de-teste.md` |
| Distinguir erro de validação de erro de sistema | Mensagens de validação em elemento próprio, com `aria-describedby` |

```tsx
<button data-testid="botao-salvar-chamado">Salvar</button>
<tr data-testid="linha-chamado" data-id={chamado.id}>
<p data-testid="erro-titulo" role="alert">{erros.titulo}</p>
```

### Onde o Cowork testa: a URL de preview da Vercel

O roteiro roda contra o **deployment de preview** do ramo (cada push gera um), ligado a um
branch de banco próprio, nunca ao banco de produção (R10). A URL exata vai no cabeçalho do
roteiro, junto com a versão que ela deve exibir.

Se o projeto tem **Deployment Protection** ligada, o Cowork encontra a tela de login da
Vercel em vez do app. Não desligue a proteção para testar. Há dois caminhos:

- O navegador que o Cowork usa já está logado na Vercel com uma conta do time que tem
  acesso ao projeto.
- O bypass de proteção para automação, documentado em
  https://vercel.com/docs/deployment-protection: siga a forma de envio que a documentação
  descreve na data do teste. O segredo do bypass é credencial (R1): fica **configurado no
  ambiente do Cowork** (variável ou cofre de segredos da própria ferramenta), por quem
  administra esse ambiente. Ele **nunca é colado na conversa**, nem escrito em `qa/` nem em
  arquivo versionado. Segredo que passou pela conversa é segredo vazado: gere outro no painel
  da Vercel e descarte o antigo. Detalhes em
  [segredos-e-configuracao.md](segredos-e-configuracao.md), seção "Segredo não passa pela
  conversa".

Se nenhum dos dois estiver disponível, a execução inteira é `BLOQUEADO`, com o motivo.

⚠️ **Credenciais de teste nunca são credenciais reais**, e `qa/dados-de-teste.md` só contém
usuários de um ambiente de teste descartável (R1). Se o roteiro precisa rodar em produção,
ele roda **somente a suíte de leitura**, e isso é dito no cabeçalho em letras garrafais.

---

## 3. Estrutura do roteiro

```markdown
# Roteiro de testes: <Nome do App> v<versão>

## 0. Contexto para quem vai executar
   O que é o app, em uma frase. O que ele NÃO faz.
   Ambiente: URL, navegador, resolução. Ambiente de teste, NÃO é produção.
   Credenciais por papel. Estado inicial esperado. Como restaurar o estado.
   Regras de execução (§5).

## 1. Matriz de rastreabilidade
   Requisito → casos que o cobrem → suíte

## 2. Suíte de fumaça (CT-SMK-nnn)
## 3. Suíte funcional, por módulo (CT-nnn)
## 4. Suíte de integração (CT-INT-nnn)
##    4.1 Bootstrap do ambiente (CT-BOOT-nnn)
##    4.2 Migração e rollback (CT-MIG-nnn)
## 5. Suíte de segurança (CT-SEC-nnn)
##    5.1 Varredura de estranho, rota por rota
##    5.2 Dados pessoais e LGPD (CT-LGPD-nnn)
## 6. Suíte de interface, responsividade e acessibilidade (CT-UI-nnn)
## 7. Suíte de regressão (CT-REG-nnn)
## 8. Registro de execução
## 9. Defeitos encontrados
```

---

## 4. Anatomia de um caso

Cada caso é autocontido. Quem executa não deve precisar ler o caso anterior para entender
este.

```markdown
### CT-014: Filtrar chamados por status

| | |
| --- | --- |
| **Requisito** | RF-004 |
| **Suíte** | Funcional · Chamados |
| **Prioridade** | Alta |
| **Pré-condição** | Logado como `usuario.teste@example.com`. Seed padrão: 3 chamados abertos, 2 fechados. |

**Passos**
1. Acessar `/chamados`.
2. Conferir que a tabela `[data-testid="tabela-chamados"]` exibe **5 linhas**.
3. No seletor `[data-testid="filtro-status"]`, escolher **Fechado**.
4. Clicar em `[data-testid="botao-filtrar"]`.

**Resultado esperado**
- A tabela exibe **exatamente 2 linhas**.
- As duas linhas mostram o status `Fechado`.
- O contador `[data-testid="contador-resultados"]` exibe `2 chamados`.
- A URL passa a conter `?status=fechado`.
- Nenhum erro no console do navegador.

**Evidência**: captura `CT-014-resultado.png` mostrando a tabela filtrada.

**Falha se**: a contagem diverge, aparece chamado com outro status, o contador não
atualiza, ou a página recarrega perdendo o filtro.
```

Os cinco elementos que tornam um caso executável por um agente:

1. **Pré-condição explícita**: inclusive quem está logado e qual o estado do seed.
2. **Passos numerados e atômicos**: um clique, uma digitação, uma navegação por passo.
3. **Resultado esperado observável e quantificado**: "exatamente 2 linhas", não "os
   registros corretos".
4. **Evidência nomeada**: o arquivo tem nome previsível, para conferência posterior.
5. **Critério de falha escrito**, para o executor não precisar julgar.

---

## 5. Regras de execução (vão no cabeçalho do roteiro)

Estas regras são voltadas a **quem executa**: o Claude Cowork ou uma pessoa:

1. **Não conserte a aplicação durante o teste.** Encontrou defeito? Registre e siga. Corrigir
   no meio invalida a execução inteira.
2. **Não pule passo**, mesmo que pareça óbvio. O passo óbvio é onde a regressão se esconde.
3. **Relate o que observou, não o que deveria acontecer.** "O contador exibiu `5 chamados`"
   é útil; "o filtro não funcionou" não é.
4. **Um caso não executado é `BLOQUEADO`, nunca `FALHOU`.** Registre o que bloqueou.
5. **Não invente dado.** Se o roteiro pede o usuário `usuario.teste@example.com` e ele não
   existe, o caso está bloqueado, não crie outro usuário.
6. **Capture evidência de toda falha**, e do estado da tela imediatamente antes.
7. **Console e rede fazem parte do resultado.** Erro em vermelho no console é falha, mesmo
   que a tela pareça certa. Requisição 500 é falha, mesmo que a interface esconda.
8. **Restaure o estado inicial** antes de começar cada suíte, conforme `qa/dados-de-teste.md`.
9. **Ao terminar, preencha o registro de execução** com o total, os aprovados, os reprovados
   e os bloqueados. Sem arredondar, sem omitir.

---

## 6. As seis suítes

### 6.1 Fumaça (`CT-SMK-nnn`): 5 a 10 casos, roda primeiro

Se a fumaça falha, o resto não é executado: o ambiente está errado ou o build está quebrado.

- A aplicação carrega e responde 200 na rota inicial
- Login com credencial válida entra
- Login com credencial inválida é recusado com a mensagem correta
- A tela principal de cada módulo abre sem erro no console
- Um registro é criado, aparece na listagem e é aberto
- Logout encerra a sessão, e voltar no navegador não reexibe a área logada

### 6.2 Funcional, por módulo (`CT-nnn`): o corpo do roteiro

Um caso por critério de aceite da spec, mais os limites:

| Dimensão | O que cobrir |
| --- | --- |
| Caminho feliz | O fluxo que o requisito descreve |
| Validação | Campo vazio, muito longo, formato errado, valor fora da faixa, caractere acentuado, emoji |
| Fronteira | Zero registros, um registro, o máximo permitido, o máximo + 1 |
| Estados | Carregando, vazio, erro, sucesso: todos os quatro, em cada tela que busca dado |
| Persistência | Recarregar a página mantém o resultado; voltar no navegador não duplica o envio |
| Concorrência | Duas abas editando o mesmo registro; envio duplo por duplo clique |
| Formato | Data, moeda, acento, maiúsculas, número grande, valor negativo |

### 6.3 Integração (`CT-INT-nnn`)

Onde dois pedaços se encontram: o lugar em que testes unitários passam e o sistema falha:

- Formulário → banco: o registro gravado tem exatamente os valores enviados (confira no banco)
- Upload → armazenamento → download: o arquivo baixado é idêntico ao enviado
- E-mail disparado por uma ação (com serviço de captura em ambiente de teste, nunca envio real)
- Webhook de terceiro: assinatura válida aceita, assinatura inválida recusada, entrega
  duplicada não duplica o efeito (idempotência)
- Cron/tarefa agendada produz o efeito esperado

#### Bootstrap do ambiente (`CT-BOOT-nnn`, R9)

A pergunta é uma só: um clone limpo sobe com o que o README diz, e nada mais? Estes casos
rodam num terminal, por você ou pelo agente de desenvolvimento; o Cowork executa só os
marcados como observáveis na URL de preview. Base: [bootstrap-do-ambiente.md](bootstrap-do-ambiente.md).

| Caso | Aprovado quando |
| --- | --- |
| Clone limpo + `vercel link`, `vercel env pull .env.local`, `npm ci`, `npx supabase start`, `npx supabase db reset`, `npm run db:seed`, `npm run dev` | O app responde 200 em `http://localhost:3000`, sem nenhum passo fora do README |
| Remover uma variável obrigatória de `.env.local` e rodar `npm run build` | O build falha com mensagem que nomeia a variável e diz onde configurá-la; nunca sobe com valor inventado |
| Variável com formato inválido (URL de banco malformada) | Falha com mensagem clara, **sem imprimir o valor** |
| Comparar as chaves de `.env.example` com as exigidas por `lib/env.ts` | Os dois conjuntos são idênticos |
| `npm run db:seed` executado duas vezes seguidas | A contagem de registros não muda; um único administrador |
| Seed sem a variável da senha inicial do administrador | Recusa com mensagem clara; nenhum administrador criado com senha padrão |
| Login com o administrador do seed, na URL de preview (Cowork) | Entra; a senha é a da variável, não uma escrita no código |
| Procurar o valor de qualquer segredo no JavaScript servido ao navegador (Cowork, aba de rede) | Nenhuma ocorrência; nenhum segredo em variável `NEXT_PUBLIC_` |

#### Migração e rollback (`CT-MIG-nnn`, R10)

O Instant Rollback da Vercel volta o código, não o banco. Estes casos provam que a versão
anterior do código continua funcionando com o banco já migrado. Sempre num branch
descartável (Supabase local ou branch de preview), nunca no banco de produção. Base:
[migracoes-e-rollback.md](migracoes-e-rollback.md).

| Caso | Aprovado quando |
| --- | --- |
| `npx supabase db reset` num banco local vazio | Todas as migrações de `supabase/migrations/` aplicadas em ordem; `supabase_migrations.schema_migrations` lista cada uma exatamente uma vez |
| `npx supabase migration list` depois de aplicar | As colunas local e remota batem; nada pendente |
| Com a migração nova aplicada, abrir a URL do deployment **anterior** ligado ao mesmo branch e rodar a suíte de fumaça (Cowork) | A fumaça passa inteira: a migração é compatível com o código de antes |
| Migração com erro proposital, num banco descartável | O CLI para, não registra a migração em `supabase_migrations.schema_migrations` e não deixa alteração pela metade |
| Ler as migrações do release | Nenhum `DROP` ou `RENAME` de coluna que a versão anterior ainda usa; destrutiva só num release seguinte |
| Criar um registro no preview e procurá-lo em produção (Cowork, só leitura em produção) | O registro não aparece: o preview não usa o banco de produção |
| Antes da migração de produção | Existe backup do dia (Database > Backups no painel do Supabase, ou `supabase db dump` guardado fora), e o caminho de volta está escrito |
| CT-MIG-011 🖥 · Restaurar o último backup (ou o `supabase db dump`) num projeto descartável e rodar a suíte de fumaça contra ele | Restaura sem erro, a fumaça passa, e o tempo da restauração fica anotado no registro de execução |

### 6.4 Segurança (`CT-SEC-nnn`): obrigatória, nunca "se der tempo"

Executada **contra o ambiente de teste**, nunca contra produção nem contra sistema de
terceiros. Cada caso descreve o payload, onde aplicá-lo e o que constitui aprovação.

**SQL injection: em todo campo que chega ao banco** (R5)

| Payload | Onde | Aprovado quando |
| --- | --- | --- |
| `' OR '1'='1` | login, busca, filtros | Login recusado; busca retorna 0 ou trata como texto literal |
| `admin'--` | campo de usuário | Recusado |
| `1' UNION SELECT NULL,NULL,NULL--` | parâmetro de ID na URL | Erro tratado ou 404; nunca dado extra na tela |
| `1; DROP TABLE usuarios--` | parâmetro numérico | Nenhum efeito; a tabela continua existindo |
| `%' OR 1=1 --` | campo de busca com `LIKE` | Retorna 0 ou o literal; nunca a base inteira |
| `1 AND (SELECT 1 FROM pg_sleep(5)) = 1` | parâmetro numérico | Resposta imediata (sem injeção cega por tempo) |
| `çãé'"\` | qualquer campo de texto | Salvo e exibido corretamente, sem erro de SQL |

**Reprovado imediatamente** se aparecer na tela: mensagem do Postgres, nome de tabela, stack
trace, ou qualquer dado que o usuário não deveria ver.

**XSS** (R6)

| Payload | Onde | Aprovado quando |
| --- | --- | --- |
| `<script>alert(1)</script>` | todo campo de texto | Exibido como texto literal; nenhum alerta |
| `"><img src=x onerror=alert(1)>` | campos exibidos em atributo | Idem |
| `javascript:alert(1)` | campo de URL/link | Link neutralizado |
| `<svg onload=alert(1)>` | campo com HTML rico | Sanitizado |
| Payload salvo e reaberto por **outro** usuário | XSS armazenado | Nenhuma execução |

**Autorização e IDOR** (R7): os que mais pegam defeito real

| Caso | Aprovado quando |
| --- | --- |
| Logado como A, acessar `/chamado/{id-do-B}` | 404 (não 403, não confirme que existe) |
| Logado como usuário comum, acessar `/admin` | 403 ou redirecionamento; nunca a tela |
| `POST` direto na rota administrativa, sem interface | 403 |
| Trocar um `id` em campo `hidden` antes de enviar | Recusado no servidor |
| Acessar rota logada após logout, usando o botão Voltar | Não exibe conteúdo em cache |
| Sessão de outro navegador continua válida após troca de senha | **Deve ser invalidada** |

**CSRF, sessão e autenticação**

| Caso | Aprovado quando |
| --- | --- |
| `POST` num Route Handler que muda estado, com `Origin` de outro domínio | Recusado (403) |
| Server Action disparada de outra origem | Recusada |
| Cookie de sessão inspecionado no DevTools | `HttpOnly`, `Secure`, `SameSite` presentes |
| ID de sessão antes e depois do login | Diferentes (regeneração) |
| 10 tentativas de login erradas | Bloqueio/atraso a partir do limite definido |
| Mensagem para e-mail inexistente vs. senha errada | **Idênticas** |
| Sessão inativa além do tempo definido | Expira |

**Upload, arquivos e cabeçalhos**

| Caso | Aprovado quando |
| --- | --- |
| Enviar `teste.html` renomeado para `teste.jpg` | Recusado pela checagem de tipo real |
| Enviar arquivo acima do limite | Recusado com mensagem clara, sem erro 500 |
| Acessar o arquivo enviado pela URL direta, deslogado | Recusado (se o app exige autorização) |
| Tentar `?arquivo=../../.env.local` | 404; nenhum conteúdo vazado |
| `curl -I` na página inicial | Os cinco cabeçalhos de segurança presentes (R7) |
| Acessar `/.env`, `/.env.local`, `/.git/config` | 404, nunca conteúdo |
| Procurar rota HTTP que rode seed ou migração (`/api/seed`, `/api/migrar`) | 404: seed e migração rodam por script, nunca por URL (R9, R10) |
| Provocar erro de servidor | Página genérica, sem stack trace |

**Supabase: RLS e Storage vistos de fora** (R7)

A interface pode estar certa e o banco aberto: a API REST do Supabase responde a qualquer um
que tenha a URL do projeto e a publishable key, e as duas estão no JavaScript servido ao
navegador. Estes casos chamam a API diretamente, sem passar pelo app. Base:
[sql-e-acesso-a-dados.md](sql-e-acesso-a-dados.md) e
[entrada-e-saida-seguras.md](entrada-e-saida-seguras.md).

| Caso | Aprovado quando |
| --- | --- |
| CT-SEC-031 🌐 · Chamar a API REST do Supabase (`https://<ref>.supabase.co/rest/v1/<tabela>?select=*`) só com a publishable key no cabeçalho `apikey`, sem login, para **cada** tabela do schema `public` | Nenhuma linha devolvida (`[]`) ou erro de permissão; nunca dado |
| CT-SEC-032 🌐 · Com o token de sessão do usuário A, ler e alterar pela API REST uma linha do usuário B (`GET` e `PATCH` com `?id=eq.<id-do-B>`) | Nenhuma linha devolvida, nenhuma linha afetada; a linha de B continua igual |
| CT-SEC-033 🌐 · Abrir a URL pública (`/storage/v1/object/public/<bucket>/<caminho>`) de um arquivo do bucket privado; abrir uma URL assinada depois de expirada | As duas recusadas; nenhum byte do arquivo entregue |

```bash
# CT-SEC-031, uma linha por tabela. A publishable key é pública por definição,
# mas vem do .env.local, não é colada aqui (R1).
curl -s "$NEXT_PUBLIC_SUPABASE_URL/rest/v1/chamados?select=*" \
  -H "apikey: $NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY"
# aprovado: []
```

#### Varredura de estranho, rota por rota

Os casos acima testam o que alguém lembrou de testar. O atacante não tem essa lista: ele
tenta **tudo**. Então o roteiro também tenta tudo, de forma sistemática, a partir do mapa
de rotas ([rotas-e-urls.md](rotas-e-urls.md)) e de uma busca no código:

```bash
# o inventário: toda página, todo Route Handler, toda Server Action
find app -name 'page.tsx' -o -name 'route.ts' | sort
grep -rlE "^['\"]use server['\"]" app lib | sort
```

Para **cada** item do inventário, três tentativas, numa tabela com uma linha por item:

| Tentativa | Como | Aprovado quando |
| --- | --- | --- |
| Deslogado | Abrir a página, ou `curl -i` no Route Handler, sem cookie | Página pública: abre. Página logada: redireciona para `/entrar`. Route Handler que lê ou muda dado: 401 ou 404, nunca dado |
| Com outra conta | Logado como B, a URL ou o `id` que pertence a A | 404, nunca o dado de A |
| Chamada direta | `curl` no Route Handler, ou o `POST` da Server Action copiado da aba de rede e reenviado com outro cookie ou sem cookie | A mesma resposta que a interface daria a esse usuário; nenhuma ação executada que a interface não permitiria |

Mais a API REST do Supabase com a publishable key (CT-SEC-031 e CT-SEC-032), para cada
tabela. Item do inventário sem as três linhas preenchidas é cobertura faltando, declarada
na matriz (§7), nunca omitida.

#### Dados pessoais e LGPD (`CT-LGPD-nnn`)

O piso técnico de [linha-de-base-de-seguranca.md](linha-de-base-de-seguranca.md), seção
"Dados pessoais e LGPD". Estes casos não são parecer jurídico: provam que o app faz o que a
spec diz que faz com o dado pessoal.

| Caso | Aprovado quando |
| --- | --- |
| CT-LGPD-001 🌐 · Deslogado, abrir a política de privacidade pelo link do rodapé | Abre em rota própria (ex.: `/politica-de-privacidade`), sem pedir login |
| CT-LGPD-002 🌐 · Excluir a conta do usuário de teste e tentar entrar de novo | Perfil, arquivos no Storage e usuário do Auth removidos; o login posterior falha |
| CT-LGPD-003 🌐 · Logado como A, exportar os dados do titular | O arquivo contém só os dados de A; nenhum dado de B |
| CT-LGPD-004 🖥 · Comparar cada campo pessoal dos formulários com a seção "Dados pessoais" da spec | Nenhum formulário pede campo pessoal sem finalidade registrada na spec |

### 6.5 Interface, responsividade e acessibilidade (`CT-UI-nnn`)

| Caso | Aprovado quando |
| --- | --- |
| 375 px (celular) | Sem rolagem horizontal; menu acessível; botões alcançáveis |
| 768 px (tablet) e 1440 px (desktop) | Layout coerente, sem sobreposição |
| Navegação só por teclado (Tab/Shift+Tab/Enter/Esc) | Todos os controles alcançáveis, foco sempre visível |
| Todo campo tem rótulo associado | `label for` presente; `placeholder` não conta |
| Contraste de texto e botões | Mínimo AA (4.5:1) |
| Zoom em 200% | Conteúdo legível, nada cortado |
| Textos longos e nomes grandes | Layout não quebra |
| Modal aberto | `Esc` fecha; foco volta ao gatilho |
| Estado vazio de cada listagem | Mensagem orientando, não tabela em branco |
| Duplo clique em botão de envio | Não cria registro duplicado |

### 6.6 Regressão (`CT-REG-nnn`): a suíte que cresce

**Toda vez que um defeito é corrigido, um caso de regressão nasce.** É a única forma de o
mesmo bug não voltar em três versões.

```markdown
### CT-REG-004: Busca com aspa simples não quebra a listagem

| **Origem** | DEF-011, corrigido em v1.2.1 |
| **Requisito** | RF-004 |

**Passos**
1. Acessar `/chamados`.
2. Digitar `O'Brien` em `[data-testid="campo-busca"]` e enviar.

**Resultado esperado**
- A página responde 200 e a tabela renderiza (com 0 ou mais linhas).
- Nenhuma mensagem de erro de SQL na tela.
- Nenhum erro 500 na aba de rede.

**Falha se**: qualquer erro 500, mensagem do Postgres, ou tela em branco.
```

A suíte de regressão roda **inteira** antes de todo release. Ela é a memória do projeto.

---

## 7. Matriz de rastreabilidade

Fecha o ciclo entre spec e teste. Um requisito sem caso é um buraco declarado, não um
esquecimento silencioso.

| Requisito | Casos | Suítes | Cobertura |
| --- | --- | --- | --- |
| RF-001 Cadastro de usuário | CT-001, CT-002, CT-003, CT-SEC-001, CT-SEC-014 | Funcional, Segurança | ✅ |
| RF-002 Login | CT-004…CT-007, CT-SEC-002, CT-SEC-015 | Fumaça, Segurança | ✅ |
| RF-004 Filtro de chamados | CT-014, CT-015, CT-016, CT-SEC-009 | Funcional, Segurança | ✅ |
| RF-009 Exportar CSV | nenhum | nenhuma | ⚠️ **sem cobertura** |

O relatório final **nomeia** os requisitos sem cobertura. Nunca os omite.

---

## 8. Registro de execução e defeitos

```markdown
## Registro de execução

| Campo | Valor |
| --- | --- |
| Data | 2026-09-05 |
| Versão testada | 1.3.0 |
| Ambiente | `https://SEU-PROJETO-git-SEU-RAMO.vercel.app` (preview, branch de banco próprio) |
| Executado por | Claude Cowork |
| Navegador | Chromium 129, 1440×900 |

| Suíte | Total | Aprovados | Reprovados | Bloqueados |
| --- | --- | --- | --- | --- |
| Fumaça | 8 | 8 | 0 | 0 |
| Funcional | 34 | 31 | 3 | 0 |
| Integração | 9 | 9 | 0 | 0 |
| Segurança | 27 | 25 | 1 | 1 |
| Interface | 12 | 11 | 1 | 0 |
| Regressão | 7 | 7 | 0 | 0 |
| **Total** | **97** | **91** | **5** | **1** |

**Veredito:** ❌ Não liberado. DEF-014 é bloqueante (falha de autorização).
```

```markdown
### DEF-014: Usuário comum acessa chamado de outro usuário

| **Caso** | CT-SEC-009 |
| **Severidade** | 🔴 Crítica: vazamento de dados entre contas |
| **Requisito** | RF-004 |

**Passos para reproduzir**
1. Login como `usuario.teste@example.com`.
2. Acessar `/chamados/7` (chamado pertencente a `outro.teste@example.com`).

**Esperado:** 404. **Obtido:** o chamado é exibido, com título e descrição.
**Evidência:** `CT-SEC-009-falha.png`
**Causa provável:** a consulta filtra por `id`, sem `AND usuario_id = ${sessao}`.
**Correção sugerida:** incluir o dono na cláusula `WHERE` (R7, §4).
**Regressão a criar após a correção:** CT-REG-008.
```

Severidades: 🔴 crítica (dado, segurança, perda) · 🟠 alta (função principal quebrada) ·
🟡 média (contorno existe) · 🔵 baixa (cosmético). **Qualquer 🔴 bloqueia o release.**

---

## 9. Como o agente gera o roteiro

Na Fase 5, a partir da spec e do código que existe:

1. Ler os requisitos `RF-nnn` e os critérios de aceite da spec.
2. Gerar um caso por critério de aceite, mais os casos de limite da tabela §6.2.
3. Percorrer o código em busca de **todo campo que chega ao banco** e gerar um caso
   `CT-SEC` de SQL injection para cada um, sem exceção (R5).
4. Percorrer todo ponto que **imprime dado do usuário** e gerar um caso de XSS.
5. Percorrer toda rota que lê ou grava registro com dono e gerar um caso de IDOR.
   Montar o inventário de páginas, Route Handlers e Server Actions e preencher a varredura
   de estranho (§6.4, "Varredura de estranho") para cada item, mais CT-SEC-031 e CT-SEC-032
   para cada tabela do schema `public`.
   Se o app trata dado pessoal, acrescentar os casos `CT-LGPD`.
6. Acrescentar as suítes de fumaça, interface e integração conforme os módulos existentes.
7. Acrescentar os casos de bootstrap (`CT-BOOT`, R9) e, se o release tem migração, os de
   migração e rollback (`CT-MIG`, R10). CT-MIG-011 (restauração ensaiada) roda antes do
   primeiro lançamento e a cada trimestre.
8. Trazer a suíte de regressão da versão anterior, inteira.
9. Montar a matriz de rastreabilidade e **declarar os requisitos sem cobertura**.
10. Entregar dizendo: quantos casos, quantos de segurança, quais requisitos ficaram
    descobertos e por quê.

> Roteiro gerado: `qa/roteiro-de-testes.md`, 97 casos (8 fumaça, 34 funcionais,
> 9 de integração, 27 de segurança, 12 de interface, 7 de regressão).
> RF-009 (exportar CSV) está sem cobertura porque a funcionalidade ainda não existe.
> O branch de preview do Supabase aplica as migrações e o `supabase/seed.sql` sozinho; o
> administrador de teste precisa de `npm run db:seed` contra esse branch antes da execução.
