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
sucesso!" num sistema de suporte são erros do mesmo tipo: linguagem que ignora a convenção de
quem lê.

> ⚠️ **Este documento não carrega respostas de domínio, de propósito.**
>
> Seria fácil listar aqui o vocabulário de banco, de ITSM, de saúde. Seria também um erro,
> pelo mesmo motivo que esta skill não vendoriza documentação de terceiros: um dossiê
> congelado envelhece parecendo autoritativo, e a existência dele convida o agente a pular a
> pesquisa, que é justamente a regra. Convenção de setor muda, e o que vale é o produto real
> que o usuário do seu app já usa hoje.
>
> **Pesquise o domínio do projeto que está na sua frente, nesta sessão.** Um dossiê pronto
> nunca substitui isso.

### O protocolo, na Fase 1 (pesquisa)

1. **Descubra quem lê.** Cliente final, colaborador interno, técnico, gestor. Não é o mesmo
   texto, e a diferença entre eles costuma ser maior que a diferença entre setores.
2. **Abra de três a cinco produtos reais do mesmo domínio** e leia as telas equivalentes às
   que você vai construir: login, listagem, formulário, erro, confirmação, estado vazio.
   Produto real vale mais que artigo sobre o setor.
3. **Extraia as cinco dimensões** da tabela abaixo.
4. **Confirme com quem conhece o domínio**, se houver alguém. Uma frase de quem atende o
   cliente vale mais que uma hora de leitura.
5. **Registre em `specs/<slug>.md`**, na seção de linguagem, com as fontes lidas e a data (R4).

### As cinco dimensões a extrair de qualquer domínio

O que muda entre setores são as respostas. As perguntas são sempre estas:

| Dimensão | O que apurar | Como reconhecer que você achou |
| --- | --- | --- |
| **Vocabulário canônico** | Os termos que o setor usa e que o usuário reconhece, e quais deles **não** são sinônimos entre si | Você consegue listar dois termos que parecem iguais e explicar por que o setor os separa |
| **Tom** | Formal, neutro, próximo. E o quanto de emoção o setor tolera | Você consegue dizer uma frase que soaria natural num produto do setor e outra que soaria falsa |
| **O que nunca se diz** | A frase que o setor evita, e por quê. Costuma ter origem legal, regulatória ou em incidente antigo | Você consegue nomear pelo menos uma proibição e a razão dela |
| **O que sempre se diz** | A informação que o usuário espera encontrar e cuja ausência gera contato com o suporte | Você consegue dizer o que precisa estar em toda tela de um certo tipo |
| **Estado emocional de quem lê** | A pessoa chega àquela tela tranquila, com pressa, com medo, com o trabalho parado | Você consegue justificar por que texto animado ajuda ou atrapalha ali |

A quinta é a que mais muda a escrita e a que menos gente investiga. Quem está com o trabalho
parado não quer entusiasmo; quem está com medo de perder dinheiro não quer ambiguidade.

### Como fica o registro

Exemplo do **formato** da saída, não de conteúdo para reaproveitar:

```markdown
## Linguagem (R17)

| Quem lê | Analista de suporte interno, e o colaborador que abre o pedido |
| Domínio | Suporte de TI interno |
| Tom | Neutro e objetivo. Sem exclamação, sem emoji |
| Vocabulário | <os termos apurados, e os pares que o setor separa> |
| Nunca dizer | <o que a pesquisa mostrou que o setor evita, e por quê> |
| Sempre dizer | <a informação cuja ausência gera contato com o suporte> |
| Estado de quem lê | <tranquilo / com pressa / com o trabalho parado> |

**Fontes** (lidas em <data>): <produto 1, tela X> · <produto 2, tela Y> · <produto 3, tela Z>
```

Se a pesquisa não foi possível, isso vai escrito na spec, em vez de ser preenchido de
memória: *"não consegui abrir produtos do domínio; a linguagem abaixo é uma proposta neutra,
a revisar com quem conhece o setor."*
→ [protocolo-de-verificacao.md](protocolo-de-verificacao.md)


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
