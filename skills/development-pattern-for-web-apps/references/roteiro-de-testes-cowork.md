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
| Repetir o teste sem sujar a base | Procedimento de reset (script de seed, ou "limpar e recriar" do Wizard em ambiente de teste) |
| Testar papéis diferentes | Um usuário de teste por papel, com senha documentada em `qa/dados-de-teste.md` |
| Distinguir erro de validação de erro de sistema | Mensagens de validação em elemento próprio, com `aria-describedby` |

```tsx
<button data-testid="botao-salvar-chamado">Salvar</button>
<tr data-testid="linha-chamado" data-id={chamado.id}>
<p data-testid="erro-titulo" role="alert">{erros.titulo}</p>
```

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
## 5. Suíte de segurança (CT-SEC-nnn)
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

Estas regras são endereçadas a **quem executa**: o Claude Cowork ou uma pessoa:

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
- **Wizard de instalação** (R9): a tabela de casos em [wizard-de-instalacao.md](wizard-de-instalacao.md)
- **Painel de atualização** (R10): a tabela de casos em [pacotes-de-atualizacao.md](pacotes-de-atualizacao.md)

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
| `1 AND SLEEP(5)` | parâmetro numérico | Resposta imediata (sem injeção cega por tempo) |
| `çãé'"\` | qualquer campo de texto | Salvo e exibido corretamente, sem erro de SQL |

**Reprovado imediatamente** se aparecer na tela: mensagem do MySQL, nome de tabela, stack
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
| `POST` sem o token `_csrf` | Recusado (419/403) |
| `POST` com token de outra sessão | Recusado |
| Cookie de sessão inspecionado no DevTools | `HttpOnly`, `Secure`, `SameSite` presentes |
| ID de sessão antes e depois do login | Diferentes (regeneração) |
| 10 tentativas de login erradas | Bloqueio/atraso a partir do limite definido |
| Mensagem para e-mail inexistente vs. senha errada | **Idênticas** |
| Sessão inativa além do tempo definido | Expira |

**Upload, arquivos e cabeçalhos**

| Caso | Aprovado quando |
| --- | --- |
| Enviar `teste.php` renomeado para `teste.jpg` | Recusado pela checagem de tipo real |
| Enviar arquivo acima do limite | Recusado com mensagem clara, sem erro 500 |
| Acessar o arquivo enviado pela URL direta, deslogado | Recusado (se o app exige autorização) |
| Tentar `?arquivo=../../config/app.config.php` | 404; nenhum conteúdo vazado |
| `curl -I` na página inicial | Os cinco cabeçalhos de segurança presentes (R7) |
| Acessar `/config/`, `/storage/`, `/.env`, `/.git/config` | 403 ou 404, nunca conteúdo |
| Acessar `/install/` com o app instalado | 403 (R9) |
| Provocar erro de servidor | Página genérica, sem stack trace |

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

**Falha se**: qualquer erro 500, mensagem do MySQL, ou tela em branco.
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
| Ambiente | https://preview-xyz.vercel.app (preview) |
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
**Causa provável:** a consulta filtra por `id`, sem `AND usuario_id = :sessao`.
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
6. Acrescentar as suítes de fumaça, interface e integração conforme os módulos existentes.
7. Nas aplicações PHP, acrescentar as tabelas de casos do Wizard (R9) e do painel de
   atualização (R10).
8. Trazer a suíte de regressão da versão anterior, inteira.
9. Montar a matriz de rastreabilidade e **declarar os requisitos sem cobertura**.
10. Entregar dizendo: quantos casos, quantos de segurança, quais requisitos ficaram
    descobertos e por quê.

> Roteiro gerado: `qa/roteiro-de-testes.md`, 97 casos (8 fumaça, 34 funcionais,
> 9 de integração, 27 de segurança, 12 de interface, 7 de regressão).
> RF-009 (exportar CSV) está sem cobertura porque a funcionalidade ainda não existe.
> O ambiente de teste precisa do seed `qa/seed.sql` aplicado antes da execução.
