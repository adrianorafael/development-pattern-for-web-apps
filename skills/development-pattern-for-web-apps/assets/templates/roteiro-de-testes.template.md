# Roteiro de testes — <Nome do App> v<versão>

> Modelo de `qa/roteiro-de-testes.md`.
> Parte de "Development Pattern for Web Apps" — regra R11.
> Escrito para ser **executado** por outro agente (Claude Cowork) ou por uma pessoa que
> não participou do desenvolvimento e não pode fazer perguntas.

---

## 0. Contexto para quem vai executar

**O que é o aplicativo, em uma frase**
> Sistema de chamados internos: usuários abrem chamados, acompanham o status e anexam
> arquivos; administradores atendem e fecham.

**O que ele NÃO faz** (para não gerar defeito falso)
> Não envia notificação por e-mail. Não tem app móvel. Não integra com nenhum sistema externo.

### Ambiente

| | |
| --- | --- |
| **URL** | `https://<url-do-ambiente-de-teste>` |
| **⚠️ Isto é** | **AMBIENTE DE TESTE** — não é produção. Dados podem ser apagados. |
| **Versão testada** | `<1.3.0>` — confira no rodapé antes de começar |
| **Navegador** | Chromium atual, 1440×900 (e 375×812 na suíte de interface) |
| **Console** | Mantenha aberto. Erro em vermelho é resultado de teste. |
| **Rede** | Mantenha aberta. Resposta 4xx/5xx inesperada é resultado de teste. |

### Credenciais

> ⚠️ Usuários de um ambiente de teste descartável. Nunca credenciais reais (R1).

| Papel | E-mail | Senha | Usar para |
| --- | --- | --- | --- |
| Usuário comum A | `usuario.a@example.com` | `<senha-de-teste-a>` | Fluxos do usuário |
| Usuário comum B | `usuario.b@example.com` | `<senha-de-teste-b>` | Testes de isolamento (IDOR) |
| Administrador | `admin@example.com` | `<senha-de-teste-admin>` | Painel administrativo |

### Estado inicial (seed determinístico)

Sempre os mesmos registros, os mesmos IDs, as mesmas datas.

| Entidade | Quantidade | Detalhe |
| --- | --- | --- |
| Usuários | 3 | A (id 1), B (id 2), admin (id 3) |
| Chamados do usuário A | 5 | ids 1–5: três `aberto`, dois `fechado` |
| Chamados do usuário B | 2 | ids 6–7, ambos `aberto` |
| Anexos | 1 | id 1, pertencente ao chamado 6 (do usuário B) |

**Como restaurar:** `<comando ou passo — ex.: aplicar qa/seed.sql, ou usar "limpar e recriar" do Wizard>`
Restaure **antes de cada suíte**.

### Regras de execução — leia antes de começar

1. **Não conserte a aplicação durante o teste.** Encontrou defeito? Registre na seção 9 e siga.
2. **Não pule passo**, mesmo que pareça óbvio. É onde a regressão se esconde.
3. **Relate o que observou, não o que deveria acontecer.** "O contador exibiu 5" é útil;
   "o filtro não funcionou" não é.
4. **Caso não executado é `BLOQUEADO`, nunca `FALHOU`.** Registre o que bloqueou.
5. **Não invente dado.** Se o usuário pedido não existe, o caso está bloqueado.
6. **Capture evidência de toda falha**, e da tela imediatamente anterior.
7. **Console e rede fazem parte do resultado.**
8. **Restaure o estado inicial** antes de cada suíte.
9. **Preencha a seção 8** ao terminar, com números reais, sem arredondar e sem omitir.

---

## 1. Matriz de rastreabilidade

| Requisito | Casos | Suítes | Cobertura |
| --- | --- | --- | --- |
| RF-001 Cadastro | CT-001, CT-002, CT-SEC-001 | Funcional, Segurança | ✅ |
| RF-002 Login | CT-SMK-002, CT-004…CT-007, CT-SEC-002 | Fumaça, Segurança | ✅ |
| RF-003 Criar chamado | CT-010…CT-013, CT-SEC-005 | Funcional, Segurança | ✅ |
| RF-004 Filtrar chamados | CT-014, CT-015, CT-016, CT-SEC-009 | Funcional, Segurança | ✅ |
| RF-00n <...> | — | — | ⚠️ **sem cobertura — motivo:** `<...>` |

> Requisito sem cobertura é **declarado**, nunca omitido.

---

## 2. Suíte de fumaça — `CT-SMK-nnn`

Roda primeiro. Se qualquer caso aqui falhar, **pare**: o ambiente ou o build estão errados,
e o resto do roteiro produziria ruído.

### CT-SMK-001 — A aplicação carrega

| **Pré-condição** | Nenhuma. Navegador sem sessão. |

**Passos**
1. Acessar `https://<url>/`.

**Resultado esperado**
- Resposta 200; a página renderiza.
- O rodapé exibe a versão `<1.3.0>`.
- Nenhum erro no console.

**Falha se** — 4xx/5xx, página em branco, ou versão diferente da esperada.

### CT-SMK-002 — Login com credencial válida
### CT-SMK-003 — Login com credencial inválida é recusado
### CT-SMK-004 — Cada módulo abre sem erro no console
### CT-SMK-005 — Criar, listar e abrir um registro
### CT-SMK-006 — Logout encerra a sessão; o botão Voltar não reexibe a área logada

---

## 3. Suíte funcional — `CT-nnn`

Um caso por critério de aceite da spec, mais os limites.

### CT-014 — Filtrar chamados por status

| | |
| --- | --- |
| **Requisito** | RF-004 |
| **Prioridade** | Alta |
| **Pré-condição** | Logado como `usuario.a@example.com`. Seed padrão: 3 abertos, 2 fechados. |

**Passos**
1. Acessar `/chamados`.
2. Conferir que `[data-testid="tabela-chamados"]` exibe **5 linhas**.
3. Em `[data-testid="filtro-status"]`, escolher **Fechado**.
4. Clicar em `[data-testid="botao-filtrar"]`.

**Resultado esperado**
- A tabela exibe **exatamente 2 linhas**.
- As duas linhas mostram status `Fechado`.
- `[data-testid="contador-resultados"]` exibe `2 chamados`.
- A URL passa a conter `?status=fechado`.
- Nenhum erro no console.

**Evidência** — `CT-014-resultado.png`

**Falha se** — a contagem diverge, aparece chamado com outro status, o contador não
atualiza, ou a página recarrega perdendo o filtro.

### Casos a cobrir em cada módulo

| Dimensão | Casos |
| --- | --- |
| Caminho feliz | O fluxo que o requisito descreve |
| Validação | Campo vazio · muito longo · formato errado · fora da faixa · acento · emoji |
| Fronteira | Zero registros · um · o máximo permitido · o máximo + 1 |
| Estados | Carregando · vazio · erro · sucesso — os quatro, em cada tela que busca dado |
| Persistência | Recarregar mantém o resultado · Voltar não duplica o envio |
| Concorrência | Duas abas no mesmo registro · duplo clique no botão de envio |
| Formato | Data · moeda · maiúsculas · número grande · valor negativo |

---

## 4. Suíte de integração — `CT-INT-nnn`

### CT-INT-001 — O que o formulário grava é o que o banco tem

**Passos**
1. Criar um chamado com título `Teste ÇÃO "aspas" <tag> 'apóstrofo'`.
2. Consultar no banco: `SELECT titulo FROM chamados ORDER BY id DESC LIMIT 1`.

**Resultado esperado**
- O valor no banco é **exatamente** o digitado — sem `&amp;lt;`, sem barras, sem truncar.
- A tela exibe o mesmo texto, sem tag interpretada.

**Falha se** — o texto foi escapado na gravação (erro clássico: escapar na entrada em vez
da saída), truncado, ou interpretado como HTML na exibição.

### Demais casos
- Upload → armazenamento → download: o arquivo baixado é idêntico ao enviado (compare hash).
- Ação que dispara e-mail (com captura em ambiente de teste; **nunca envio real**).
- Webhook: assinatura válida aceita · inválida recusada · entrega duplicada não duplica efeito.
- Tarefa agendada produz o efeito esperado.
- **Wizard de instalação** (R9) — a tabela de casos da referência `wizard-de-instalacao.md`.
- **Painel de atualização** (R10) — a tabela de casos da referência `pacotes-de-atualizacao.md`.

---

## 5. Suíte de segurança — `CT-SEC-nnn`

> Obrigatória, nunca "se der tempo". Executada **apenas contra o ambiente de teste**.

### 5.1 SQL injection — em todo campo que chega ao banco (R5)

Para **cada** campo de entrada da aplicação, executar a tabela abaixo. Liste os campos aqui:

`login.email` · `login.senha` · `busca.q` · `chamados.filtro_status` · `chamados.titulo` ·
`chamados.descricao` · `/chamados/{id}` · `?ordenar` · `?pagina` · `<...>`

| # | Payload | Aprovado quando |
| --- | --- | --- |
| a | `' OR '1'='1` | Recusado / tratado como texto literal |
| b | `admin'--` | Recusado |
| c | `1' UNION SELECT NULL,NULL,NULL--` | Erro tratado ou 404; nunca dado extra na tela |
| d | `1; DROP TABLE usuarios--` | Nenhum efeito; a tabela continua existindo |
| e | `%' OR 1=1 --` | Retorna 0 ou o literal; nunca a base inteira |
| f | `1 AND SLEEP(5)` | Resposta imediata (sem injeção cega por tempo) |
| g | `çãé'"\` | Salvo e exibido corretamente, sem erro |

**Reprovado imediatamente** se aparecer na tela: mensagem do MySQL, nome de tabela, stack
trace, ou dado que o usuário não deveria ver.

**Depois de cada rodada:** conferir no banco que nenhuma tabela sumiu e nenhum registro
extra foi criado.

### 5.2 XSS (R6)

Para cada campo cujo valor é exibido em alguma tela:

| # | Payload | Aprovado quando |
| --- | --- | --- |
| a | `<script>alert(1)</script>` | Exibido como texto literal; nenhum alerta |
| b | `"><img src=x onerror=alert(1)>` | Idem, inclusive em atributos |
| c | `javascript:alert(1)` (campo de URL) | Link neutralizado |
| d | `<svg onload=alert(1)>` | Sanitizado |
| e | Salvo por A, aberto por B ou pelo admin | Nenhuma execução (XSS armazenado) |

### 5.3 Autorização e IDOR (R7) — os que mais pegam defeito real

| Caso | Aprovado quando |
| --- | --- |
| CT-SEC-009 · Logado como A, acessar `/chamados/6` (do B) | **404** — não 403: não confirme que existe |
| CT-SEC-010 · Logado como A, acessar `/anexos/1` (do B) | 404; nenhum byte entregue |
| CT-SEC-011 · Usuário comum acessa `/admin` | 403 ou redirecionamento; nunca a tela |
| CT-SEC-012 · `POST` direto em rota administrativa, sem passar pela interface | 403 |
| CT-SEC-013 · Alterar um `id` em campo `hidden` antes de enviar | Recusado no servidor |
| CT-SEC-014 · Botão Voltar após logout | Não exibe conteúdo em cache |
| CT-SEC-015 · Sessão em outro navegador após troca de senha | **Invalidada** |

### 5.4 CSRF, sessão e autenticação

| Caso | Aprovado quando |
| --- | --- |
| CT-SEC-016 · `POST` sem o token `_csrf` | Recusado (419/403) |
| CT-SEC-017 · `POST` com token de outra sessão | Recusado |
| CT-SEC-018 · Inspecionar o cookie de sessão | `HttpOnly`, `Secure`, `SameSite` presentes |
| CT-SEC-019 · ID de sessão antes e depois do login | Diferentes (regeneração) |
| CT-SEC-020 · 10 tentativas de login erradas | Bloqueio ou atraso a partir do limite |
| CT-SEC-021 · Mensagem: e-mail inexistente vs. senha errada | **Idênticas** |
| CT-SEC-022 · Sessão inativa além do tempo configurado | Expira |

### 5.5 Upload, arquivos e cabeçalhos

| Caso | Aprovado quando |
| --- | --- |
| CT-SEC-023 · `teste.php` renomeado para `teste.jpg` | Recusado pela checagem de tipo real |
| CT-SEC-024 · Arquivo acima do limite | Recusado com mensagem clara, sem erro 500 |
| CT-SEC-025 · Acessar o arquivo enviado pela URL direta, deslogado | Recusado |
| CT-SEC-026 · `?arquivo=../../config/app.config.php` | 404; nada vazado |
| CT-SEC-027 · `curl -sI https://<url>` | Os cinco cabeçalhos de segurança presentes |
| CT-SEC-028 · Acessar `/config/`, `/storage/`, `/.env`, `/.git/config` | 403 ou 404 |
| CT-SEC-029 · Acessar `/install/` com o app instalado | 403 (R9) |
| CT-SEC-030 · Provocar erro de servidor | Página genérica, sem stack trace |

---

## 6. Suíte de interface, responsividade e acessibilidade — `CT-UI-nnn`

| Caso | Aprovado quando |
| --- | --- |
| CT-UI-001 · 375 px | Sem rolagem horizontal; menu acessível; botões alcançáveis |
| CT-UI-002 · 768 px e 1440 px | Layout coerente, sem sobreposição |
| CT-UI-003 · Só teclado (Tab/Shift+Tab/Enter/Esc) | Todos os controles alcançáveis; foco sempre visível |
| CT-UI-004 · Rótulos | Todo campo com `label`; `placeholder` não conta |
| CT-UI-005 · Contraste | Mínimo AA (4.5:1) em texto e botões |
| CT-UI-006 · Zoom 200% | Conteúdo legível, nada cortado |
| CT-UI-007 · Texto longo (200 caracteres no título) | Layout não quebra |
| CT-UI-008 · Modal | `Esc` fecha; foco volta ao elemento que abriu |
| CT-UI-009 · Estado vazio de cada listagem | Mensagem orientando, não tabela em branco |
| CT-UI-010 · Duplo clique no botão de envio | Não cria registro duplicado |
| CT-UI-011 · Estado de carregamento | Visível em toda tela que busca dado |
| CT-UI-012 · Estado de erro | Mensagem amigável + ação de tentar de novo |

### 6.1 Rotas e URLs (R15)

| Caso | Aprovado quando |
| --- | --- |
| CT-UI-020 · Cada rota do mapa, colada direto na barra de endereço | 200 e a tela correta — nada depende de ter vindo de outra página |
| CT-UI-021 · F5 em qualquer rota interna | A mesma tela, sem perder estado nem reenviar formulário |
| CT-UI-022 · Botão Voltar depois de três telas | Volta na ordem certa |
| CT-UI-023 · `/chamados/` (barra final) e `/Chamados` (maiúscula) | 301 para a forma canônica |
| CT-UI-024 · Rota antiga da tabela de redirecionamentos | 301 para a nova |
| CT-UI-025 · `/pagina-que-nao-existe` | **404** com a página de erro do app, não 200 |
| CT-UI-026 · `/chamados/abc` (id não numérico) | 404, sem erro 500 e sem mensagem do banco |
| CT-UI-027 · Compartilhar `/chamados?status=fechado&pagina=2` em outra sessão | A mesma visualização filtrada |
| CT-UI-028 · Inspecionar todas as URLs navegadas | Nenhuma contém `.php`, `.html` ou nome de pasta interna |

---

## 7. Suíte de regressão — `CT-REG-nnn`

> **Todo defeito corrigido vira um caso aqui.** Esta suíte roda inteira antes de todo release.
> É a memória do projeto.

### CT-REG-001 — Busca com aspa simples não quebra a listagem

| | |
| --- | --- |
| **Origem** | DEF-011, corrigido em v1.2.1 |
| **Requisito** | RF-004 |

**Passos**
1. Acessar `/chamados`.
2. Digitar `O'Brien` em `[data-testid="campo-busca"]` e enviar.

**Resultado esperado**
- Resposta 200; a tabela renderiza (com 0 ou mais linhas).
- Nenhuma mensagem de erro de SQL na tela.
- Nenhum 500 na aba de rede.

**Falha se** — qualquer 500, mensagem do MySQL, ou tela em branco.

---

## 8. Registro de execução

| Campo | Valor |
| --- | --- |
| Data | `<AAAA-MM-DD>` |
| Versão testada | `<1.3.0>` |
| Ambiente | `<URL>` |
| Executado por | `<Claude Cowork / nome>` |
| Navegador | `<Chromium 129, 1440×900>` |
| Seed restaurado antes de cada suíte | `<sim/não>` |

| Suíte | Total | Aprovados | Reprovados | Bloqueados |
| --- | --- | --- | --- | --- |
| Fumaça | | | | |
| Funcional | | | | |
| Integração | | | | |
| Segurança | | | | |
| Interface | | | | |
| Regressão | | | | |
| **Total** | | | | |

**Veredito:** `✅ liberado` · `❌ não liberado — <motivo>`

> Qualquer defeito 🔴 em aberto bloqueia o release.

### Resultado caso a caso

| Caso | Resultado | Observação / defeito |
| --- | --- | --- |
| CT-SMK-001 | ✅ | |
| CT-014 | ❌ | DEF-013 — contador exibiu `5 chamados` |
| CT-SEC-009 | ❌ | DEF-014 — 🔴 crítico |
| CT-INT-004 | ⛔ bloqueado | serviço de e-mail de teste indisponível |

---

## 9. Defeitos encontrados

### DEF-014 — Usuário comum acessa chamado de outro usuário

| | |
| --- | --- |
| **Caso** | CT-SEC-009 |
| **Severidade** | 🔴 Crítica — vazamento de dados entre contas |
| **Requisito** | RF-004 |
| **Versão** | 1.3.0 |

**Passos para reproduzir**
1. Login como `usuario.a@example.com`.
2. Acessar `/chamados/6` (pertence a `usuario.b@example.com`).

**Esperado:** 404.
**Obtido:** o chamado é exibido, com título e descrição.
**Evidência:** `CT-SEC-009-falha.png`
**Causa provável:** a consulta filtra por `id`, sem `AND usuario_id = :sessao`.
**Correção sugerida:** incluir o dono na cláusula `WHERE` (R7).
**Regressão a criar após corrigir:** CT-REG-008.

---

### Severidades

| | Significado | Efeito no release |
| --- | --- | --- |
| 🔴 Crítica | Segurança, vazamento ou perda de dados | **Bloqueia** |
| 🟠 Alta | Funcionalidade principal quebrada | Bloqueia, salvo decisão explícita |
| 🟡 Média | Existe contorno | Pode ir para a próxima versão |
| 🔵 Baixa | Cosmético | Backlog |
