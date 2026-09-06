# Linguagem e texto da interface

> Regra **R17**. O texto é escrito na língua de quem vai usar o sistema, seguindo as
> convenções do domínio, e nunca entrega que foi gerado por máquina.
> **O travessão é proibido em todo texto visível ao usuário.**

Para quem usa o sistema, o texto **é** o produto. A pessoa não vê a arquitetura, não vê o
schema, não vê o SQL parametrizado. Ela vê "Não foi possível concluir a operação" e decide
ali se confia ou não. Um botão escrito na língua errada custa mais suporte que um bug.

Esta regra tem três partes, e nenhuma delas é decoração:

1. **Nada de travessão**, e nada dos outros vícios que marcam texto de IA.
2. **Pesquisar o domínio** antes de escrever a primeira frase de interface.
3. **Corpo de texto justificado**, com hifenização.

---

## 1. O travessão é proibido

Travessão (`—`) e meia-risca (`–`) não fazem parte da escrita corrente em português
brasileiro fora da literatura e do jornalismo. Em tela de aplicação eles têm dois problemas:
soam empolados, e hoje funcionam como assinatura de texto gerado. O leitor não sabe explicar
por quê, mas percebe.

O teclado ABNT2 não tem tecla de travessão. Se você não digitaria aquilo naturalmente, não
escreva.

### Como substituir

| Em vez de | Escreva | Quando |
| --- | --- | --- |
| `O prazo é curto — três dias.` | `O prazo é curto: três dias.` | O segundo trecho explica o primeiro |
| `Ele confirmou — depois desistiu.` | `Ele confirmou, depois desistiu.` | Encadeamento simples |
| `A conta, — que estava ativa — foi encerrada.` | `A conta, que estava ativa, foi encerrada.` | Aposto: vírgulas bastam |
| `A conta (ativa desde 2020) — foi encerrada.` | `A conta (ativa desde 2020) foi encerrada.` | Aposto longo: parênteses |
| `Tente de novo — se persistir, fale conosco.` | `Tente de novo. Se persistir, fale conosco.` | Duas ideias: dois períodos |
| `Status — Aberto` | `Status: Aberto` | Rótulo e valor |
| `Total — R$ 0,00` | `Total: R$ 0,00` ou `Total` acima de `R$ 0,00` | Tabela ou ficha |
| `| valor | — |` | `| valor | não se aplica |` | Célula vazia de tabela |
| `Enviar — cancelar` | `Enviar` e `Cancelar` como dois botões | Nunca junte ações numa frase |

O hífen (`-`) continua normal em palavras compostas (`bem-vindo`, `pré-pago`) e em intervalos
curtos você pode escrever `de 8h às 18h` em vez de `8h – 18h`.

### Os outros vícios que entregam texto gerado

Nenhum deles é errado isoladamente. Juntos, viram carimbo.

| Evite | Prefira |
| --- | --- |
| `Além disso`, `Vale ressaltar`, `É importante notar que` | Corte a muleta e diga a frase |
| `No mundo de hoje`, `Em um cenário cada vez mais digital` | Comece pelo assunto |
| `Mergulhe`, `desbloqueie`, `revolucione`, `eleve sua experiência` | Diga o que a tela faz |
| `robusto`, `poderoso`, `perfeito`, `sem emenda`, `intuitivo` | Adjetivo que o usuário julga, não que você declara |
| `Não apenas X, mas também Y` | Duas frases, ou uma lista |
| Três itens sempre que se lista algo | Liste quantos existirem |
| Emoji em mensagem de erro ou confirmação séria | Texto |
| Toda tela começando por `Bem-vindo ao…` | Vá direto ao conteúdo |
| Frase de abertura que resume o que vem a seguir | Comece pelo que vem a seguir |

Verificação mecânica antes de todo commit:

```bash
bash skills/development-pattern-for-web-apps/assets/scripts/scan-linguagem.sh
```

---

## 2. Pesquisar o domínio antes de escrever

Cada setor tem vocabulário próprio, expectativa de tom e, às vezes, obrigação legal sobre o
que se pode dizer. Escrever "seu dinheiro sumiu" num app bancário e "chamado encerrado com
sucesso!" num ITSM são erros do mesmo tipo: linguagem que ignora a convenção de quem lê.

**O protocolo, na Fase 1 (pesquisa):**

1. Descubra quem lê: cliente final, colaborador interno, técnico, gestor. Não é o mesmo texto.
2. Abra de três a cinco produtos reais do mesmo domínio e leia as telas equivalentes.
3. Anote o **vocabulário canônico**: os termos que o setor usa e que o usuário reconhece.
4. Anote o **tom**: formal, neutro, próximo. E o que o setor **nunca** faz.
5. Registre no `specs/<slug>.md`, na seção de linguagem, com as fontes lidas (R4).

Sem isso, o agente escreve na única língua que conhece de fábrica, que é a genérica.

### Bancos e produtos financeiros

Fontes lidas nesta redação:
[UX Writing e o Mercado Financeiro](https://medium.com/@uxschwarz/ux-writing-e-o-mercado-financeiro-uma-jornada-complexa-por-uma-comunica%C3%A7%C3%A3o-essencialmente-delicada-3e660f4fb9cb) ·
[Clareza e segurança: a base da confiança](https://uxschwarz.medium.com/clareza-e-seguran%C3%A7a-a-base-da-confian%C3%A7a-da-pessoa-usu%C3%A1ria-em-um-produto-financeiro-e7c57fd434bb) ·
[A comunicação de sistemas e aplicativos financeiros](https://alexhobigomes.medium.com/ux-writing-a-comunica%C3%A7%C3%A3o-de-sistemas-e-aplicativos-financeiros-com-seus-usu%C3%A1rios-a9b22ea2ce0b)

O que a leitura mostra:

- **Clareza e segurança se revezam como protagonistas.** O texto precisa tranquilizar sem
  esconder, e informar sem assustar. Toda tela que mexe com dinheiro é lida em estado de
  alerta.
- **Simplificar sem distorcer.** O jargão financeiro exclui: boa parte do público não é
  bancarizada ou não domina termos econômicos, e falar de dinheiro ainda é tabu. Traduza o
  conceito com analogia e exemplo prático, mas não invente um termo que não existe no
  extrato, no contrato ou no atendimento.
- **Tom casual e respeitoso funciona** (o Nubank consolidou isso no Brasil), desde que a
  informação venha inteira. Simplicidade, transparência e proximidade não autorizam omitir
  taxa, prazo ou risco.
- **O equilíbrio difícil é quanto informar.** Informação demais numa tela de transferência
  paralisa; de menos gera ligação para a central.

Convenções práticas:

| Situação | Escreva assim | Nunca |
| --- | --- | --- |
| Valor negativo | `Saldo: -R$ 120,00` com rótulo claro | `Você está no vermelho` |
| Falha na transferência | `Não conseguimos concluir a transferência. O valor não saiu da sua conta.` | `Erro 500` ou `Ops, algo deu errado` |
| Confirmação de Pix | `Você vai transferir R$ 250,00 para Maria Souza, CPF ***.456.789-**. Confirmar?` | `Deseja continuar?` |
| Taxa | `Tarifa de R$ 3,90, cobrada no dia 10` | `Pequena taxa pode ser aplicada` |
| Prazo | `O valor cai na conta em até 1 dia útil` | `Em breve` |
| Bloqueio de segurança | Diga o que aconteceu e o caminho concreto para resolver | Culpar o usuário |

Regra de ouro do setor: **depois de uma operação com dinheiro, diga sempre o que aconteceu
com o dinheiro.** "Não foi possível" sem dizer se o valor saiu ou não gera pânico e ligação.

### ITSM, service desk e suporte

Fontes lidas nesta redação:
[Glossário de termos de ITSM (ManageEngine)](https://blogs.manageengine.com/pt-br/2024/07/31/conheca-os-principais-termos-de-itsm-um-glossario-completo.html) ·
[Gestão de incidentes, requisições e mudanças (Qualitor)](https://www.qualitor.com.br/blog/interna/gestao-de-incidentes-requisicoes-e-mudancas-como-o-itsm-orquestra-tudo) ·
[Diferença entre incidente, requisição e evento](https://penseemti.com.br/artigos/diferenca-entre-incidente-requisicao-e-evento/) ·
[Incidentes ou requisições (HDI Brasil)](https://hdibrasil.com.br/conteudo/incidentes-ou-requisicoes-como-classificar-problemas-de-desempenho-de-servicos)

O vocabulário canônico, que não é intercambiável:

| Termo | O que é | Não confundir com |
| --- | --- | --- |
| **Chamado** (ou ticket) | O registro que o usuário abre | É o continente, não o conteúdo |
| **Incidente** | Algo quebrou ou parou de funcionar como deveria, causando interrupção | Requisição |
| **Requisição de serviço** | Pedido de algo previsto no catálogo, sem que nada esteja quebrado | Incidente |
| **Problema** | A causa raiz por trás de um ou mais incidentes | Incidente |
| **Evento** | Mudança de estado detectada por monitoramento | Incidente |
| **Mudança** | Alteração planejada em um serviço | Requisição |
| **SLA** | O prazo acordado, com consequência contratual | "prazo estimado" |
| **Service desk** | O ponto único de contato (SPOC) entre usuário e TI | Help desk, que é mais restrito |
| **Catálogo de serviços** | A lista do que pode ser pedido | Menu de telas |

Por que isso importa no texto e não só no banco de dados: a distinção entre incidente e
requisição define priorização, SLA e a comunicação com o usuário. Um formulário que chama
tudo de "problema" empurra pedido de acesso para a fila de urgência.

Convenções práticas:

| Situação | Escreva assim | Nunca |
| --- | --- | --- |
| Abertura | `Abrir chamado` | `Criar novo registro` |
| Escolha do tipo | `Alguma coisa parou de funcionar` / `Preciso solicitar um serviço` | `Incidente` / `Requisição` sem explicação |
| Status | `Aberto`, `Em atendimento`, `Aguardando você`, `Resolvido`, `Fechado` | `Pendente`, que não diz de quem |
| Prazo | `Prazo de atendimento: até 4 horas úteis (SLA Alto)` | `Responderemos em breve` |
| Fechamento | `Resolvido. Se o problema voltar, reabra este chamado em até 7 dias.` | `Chamado encerrado com sucesso!` |
| Aguardando o usuário | `Precisamos de uma informação sua para continuar` | `Pendente de terceiros` |

O usuário de ITSM está com o trabalho parado. Texto animado irrita: ele quer prazo, número
do chamado e o que fazer agora.

### Outros domínios: o que investigar

| Domínio | Vocabulário a respeitar | Tom | Armadilha |
| --- | --- | --- | --- |
| Saúde | paciente, prontuário, agendamento, profissional | Formal e cuidadoso | Nunca sugerir diagnóstico nem minimizar sintoma |
| Educação | aluno, turma, matrícula, avaliação, frequência | Claro e encorajador | Não infantilizar o adulto |
| Jurídico | parte, processo, prazo, protocolo, petição | Formal | Não simplificar a ponto de mudar o sentido legal |
| E-commerce | pedido, carrinho, frete, prazo de entrega, devolução | Direto e objetivo | Prazo e frete sempre explícitos, nunca "grátis*" |
| Governo | cidadão, requerimento, protocolo, órgão | Impessoal e acessível | Linguagem simples é exigência, não estilo |
| Interno corporativo | o jargão da própria empresa | Neutro | Copiar o jargão errado é pior que não usar nenhum |

**Quando não houver referência disponível, diga isso** em vez de inventar um tom.
→ [protocolo-de-verificacao.md](protocolo-de-verificacao.md)

---

## 3. Microcopy: os lugares onde o texto decide

### Botões: verbo no infinitivo, dizendo o que acontece

```
✅ Salvar alterações      ✅ Abrir chamado       ✅ Transferir R$ 250,00
❌ OK                     ❌ Enviar               ❌ Confirmar
```

O botão que confirma exclusão diz `Excluir`, não `Sim`. Quem lê só o botão precisa entender o
que vai acontecer.

### Mensagens de erro: três partes, sempre

1. **O que aconteceu**, na perspectiva do usuário.
2. **Por quê**, se ajudar a resolver.
3. **O que fazer agora**, concreto.

```
❌ Erro ao processar requisição.
❌ Ops! Algo deu errado. Tente novamente mais tarde.

✅ Não conseguimos salvar o chamado porque o anexo passa de 5 MB.
   Envie um arquivo menor ou remova o anexo e salve de novo.
```

Nunca exponha detalhe técnico: nome de tabela, stack trace, código de erro do banco. Isso vai
para o log (R7). O usuário recebe a frase; o suporte recebe o identificador:

```
✅ Não foi possível concluir a operação. Se precisar de ajuda, informe o código FZ-4821.
```

### Estados vazios: diga o que é e o que fazer

```
❌ Nenhum registro encontrado.

✅ Você ainda não tem chamados abertos.
   [Abrir chamado]
```

### Confirmações destrutivas: nomeie o que será perdido

```
❌ Tem certeza?

✅ Excluir o chamado 1042?
   Os 3 anexos e todo o histórico de atendimento serão apagados. Não dá para desfazer.
   [Excluir chamado]  [Cancelar]
```

### Rótulos de formulário: o nome que o usuário usa

`Celular` funciona melhor que `Telefone móvel`. `CPF` nunca vira `Documento`. E o rótulo fica
**acima** do campo, nunca só no `placeholder`, que some quando a pessoa digita.
→ [entrada-e-saida-seguras.md](entrada-e-saida-seguras.md)

---

## 4. Tipografia: justificado, com hifenização

Corpo de texto corrido vai **justificado** por padrão neste padrão:

```css
.texto {
  text-align: justify;
  hyphens: auto;          /* obrigatório: sem isso o justificado abre rios de espaço */
  text-wrap: pretty;
}
```

E o `<html>` precisa declarar o idioma, senão o navegador não sabe qual dicionário de
hifenização usar:

```html
<html lang="pt-BR">
```

**Justificar sem hifenizar é pior que não justificar.** Em coluna estreita, o navegador
estica os espaços entre palavras e abre corredores brancos verticais no meio do parágrafo.

O que **não** se justifica:

| Elemento | Alinhamento | Por quê |
| --- | --- | --- |
| Títulos e subtítulos | À esquerda | Linha curta justificada vira espaçamento grotesco |
| Rótulos, botões, chips | À esquerda ou centro | Não são parágrafo |
| Células de tabela curtas | À esquerda (números à direita) | Justificar duas palavras não faz sentido |
| Código | À esquerda, sempre | Espaçamento é significativo |
| Listas de itens curtos | À esquerda | Idem |
| Coluna abaixo de 40 caracteres | À esquerda | Não há espaço para distribuir |

Medida ideal de linha: de 45 a 75 caracteres. Acima disso o olho perde a linha de volta;
abaixo, o justificado quebra. Use `max-w-prose` ou equivalente.

---

## 5. Checklist

- [ ] Zero travessão (`—`) e zero meia-risca (`–`) em texto visível ao usuário
- [ ] `scan-linguagem.sh` limpo
- [ ] Nenhuma das muletas da tabela de vícios
- [ ] Domínio pesquisado, com as fontes registradas na spec (R3, R4)
- [ ] Vocabulário canônico do setor respeitado e usado com consistência
- [ ] Botões com verbo dizendo o que acontece, nunca `OK` nem `Confirmar` sozinho
- [ ] Toda mensagem de erro tem o que aconteceu, por quê e o que fazer
- [ ] Nenhum detalhe técnico vazando para a tela (R7)
- [ ] Todo estado vazio orienta a próxima ação
- [ ] Confirmação destrutiva nomeia o que será perdido
- [ ] Rótulo acima do campo, com o nome que o usuário usa
- [ ] Corpo de texto justificado com `hyphens: auto` e `lang` declarado
- [ ] Títulos, rótulos, código e listas curtas não justificados
- [ ] Medida de linha entre 45 e 75 caracteres

---

## 6. O que testar (entra no roteiro de QA, R11)

| Caso | Aprovado quando |
| --- | --- |
| Buscar `—` e `–` em todas as telas navegadas | Nenhuma ocorrência |
| Ler todos os botões da aplicação em sequência | Cada um diz o que acontece ao clicar |
| Provocar cada erro tratado | Toda mensagem tem as três partes, sem detalhe técnico |
| Abrir cada listagem sem dados | Todo estado vazio orienta a próxima ação |
| Conferir o vocabulário do domínio tela a tela | Termos consistentes, sem sinônimo improvisado |
| Parágrafo longo em 1440 px | Justificado, sem rios de espaço, com hifenização ativa |
| O mesmo parágrafo em 375 px | Legível: ou hifeniza bem, ou cai para alinhamento à esquerda |
| Ler a interface para alguém do público-alvo | A pessoa entende sem tradução |
