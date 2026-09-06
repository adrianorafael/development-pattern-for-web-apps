# Documentação do projeto: o que atualizar a cada mudança

> Regra **R13**. Toda mudança atualiza os documentos que ela afeta, **no mesmo commit**.
> A matriz da seção 2 diz quais. Documentação que ficou para depois é documentação que
> não vai acontecer.

Documentação desatualizada é pior que documentação ausente. A ausente você percebe e vai
ler o código; a desatualizada você acredita, e ela te leva ao lugar errado com confiança.
Um README que descreve o app de duas versões atrás faz alguém tentar instalar do jeito que
não funciona mais e concluir que o projeto está quebrado.

Por isso a regra é "no mesmo commit", e não "antes do release". Se o commit que muda o
comportamento não muda o texto que descreve o comportamento, o par nunca mais se encontra.

---

## 1. O inventário: o que um projeto deste padrão documenta

| Artefato | O que carrega | Quem lê, e quando |
| --- | --- | --- |
| `README.md` | Instalação, configuração, uso, rotas, atualização, backup, solução de problemas | Você daqui a seis meses, e quem for instalar |
| `CHANGELOG.md` | O que mudou em cada versão, escrito para quem **usa** o app | Quem vai atualizar e precisa saber o que muda |
| `AGENTS.md` | Convenções do projeto e as armadilhas já encontradas | A próxima sessão do agente, que começa sem memória |
| `specs/<nnnn>-<slug>.md` | O desenho: requisitos numerados, critérios de aceite, casos, decisões | Você, quando for mudar aquela funcionalidade |
| `qa/roteiro-de-testes.md` | O procedimento de QA, caso a caso | O Claude Cowork, ou quem testar |
| `qa/dados-de-teste.md` | Usuários, seed determinístico, como restaurar o estado | Idem |
| `.env.example` | Todas as chaves de configuração, com placeholder e comentário | Quem clona ou instala |
| `config.example.php` | O mesmo, na trilha PHP | Idem |
| `database/schema.sql` | A estrutura base, idempotente | O Wizard de instalação (R9) |
| `database/migrations/*.sql` | A evolução do schema, ordenada | O painel de atualização (R10) |
| `manifest.json` do pacote | O plano de uma atualização específica | O painel, ao validar o pacote |
| Arquivo de versão | A fonte da verdade da versão em SemVer | Todo o resto |
| Página do projeto (se houver) | A vitrine pública | Visitante que nunca viu o projeto |

A tabela `schema_migrations` no banco não é documento, mas cumpre o mesmo papel: ela diz
até onde aquele banco está. Mantê-la correta é parte da R13.

---

## 2. A matriz: mudei isso, atualizo o quê

Leia a linha da sua mudança. Tudo marcado é obrigatório no **mesmo commit**.

| Mudei… | README | CHANGELOG | spec | QA | AGENTS | `.env.example` | Versão | Página |
| --- | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: |
| Comportamento visível ao usuário | ✅ | ✅ | ✅ | ✅ | | | ✅ | ✅ |
| Funcionalidade nova | ✅ | ✅ | ✅ | ✅ | | | ✅ | ✅ |
| Rota nova ou renomeada (R15) | ✅ | ✅ | ✅ | ✅ | | | ✅ | ✅ |
| Campo novo em formulário | | ✅ | ✅ | ✅ | | | ✅ | |
| Tabela ou coluna nova | | ✅ | ✅ | ✅ | | | ✅ | |
| Migração destrutiva | ✅ | ✅ | ✅ | ✅ | | | ✅ | |
| Variável de ambiente nova | ✅ | ✅ | | | | ✅ | ✅ | |
| Dependência ou extensão nova | ✅ | ✅ | | | | | ✅ | |
| Passo de instalação mudou | ✅ | ✅ | | ✅ | | | ✅ | ✅ |
| Correção de bug | | ✅ | | ✅ | | | ✅ | |
| Correção de segurança | ✅ | ✅ | ✅ | ✅ | | | ✅ | |
| Texto de interface (R17) | | | ✅ | ✅ | | | ✅ | |
| Convenção nova, ou armadilha descoberta | | | | | ✅ | | | |
| Refatoração sem mudança visível | | | | | | | | |

Três linhas merecem explicação:

- **Correção de bug atualiza o roteiro de QA**, sempre. O defeito corrigido vira um caso
  `CT-REG-nnn`, senão ele volta três versões depois (R11).
- **Correção de segurança atualiza o README**, e o CHANGELOG a nomeia com a urgência de
  atualizar. Esconder isso deixa quem está na versão antiga sem saber que precisa subir.
- **Refatoração sem mudança visível não atualiza nada**, e essa linha existe justamente para
  você poder dizer "esta não precisa" com respaldo, em vez de inventar uma entrada de
  CHANGELOG para uma mudança que ninguém percebe.

### A pergunta que resolve os casos duvidosos

> Se alguém instalar o app amanhã seguindo o README, e usar o app seguindo o CHANGELOG,
> algo vai surpreender essa pessoa por causa desta mudança?

Se sim, o documento entra no commit. Se não, não entra.

---

## 3. O que atualizar dentro de cada documento

Marcar o documento na matriz é metade. A outra metade é saber **qual seção** mexer.

**README.** As seções que envelhecem primeiro são, nesta ordem: requisitos (extensão nova),
configuração (chave nova), rotas (R15), solução de problemas (todo defeito recorrente vira
uma linha) e atualização. A árvore de estrutura do projeto é a que mais fica para trás:
confira-a contra o disco, não contra a memória.

**CHANGELOG.** Escreva para quem **usa** o app, não para quem leu o diff. "Corrige o
tratamento de nulo em `ChamadoRepository::buscar`" não diz nada; "a busca deixava a listagem
em branco quando o título tinha apóstrofo" diz. Migração vai numa subseção própria, dizendo
se é aditiva ou destrutiva e quanto tempo pode levar em base grande.

**spec.** Quando o comportamento muda, a spec muda **no mesmo commit**. Uma spec que
divergiu do código é pior que nenhuma: ela descreve com autoridade um sistema que não
existe. Se a mudança foi grande, é spec nova; se foi ajuste de regra, é edição com nota.

**Roteiro de QA.** Caso novo para requisito novo; caso `CT-REG-nnn` para todo defeito
corrigido; caso `CT-SEC-nnn` para todo campo novo que chega ao banco (R5) e todo ponto novo
que imprime dado do usuário (R6). E a matriz de rastreabilidade volta a fechar.

**AGENTS.md.** Este é o que quase todo mundo esquece, e é o que mais economiza tempo depois.
Toda vez que você descobre uma armadilha (a Hostinger serve PHP 8.2 mas o SSH reporta 8.0,
`exec()` está em `disable_functions`, o plano tem `max_execution_time` de 30 s), ela vira uma
linha ali. A próxima sessão começa adiantada em vez de repetir a descoberta.

**`.env.example`.** Chave nova entra aqui no mesmo commit em que entra no código. O teste é
concreto: alguém que clone o repositório e copie este arquivo consegue rodar o app?

**Página do projeto.** Se existir, ela e o README afirmam as mesmas coisas em profundidades
diferentes. Quando um muda, o outro muda junto, com os mesmos números.

---

## 4. Verificação mecânica

```bash
bash skills/development-pattern-for-web-apps/assets/scripts/scan-doc-sync.sh
```

O scanner lê o que está no *staging* e aponta o que a matriz pede e você não tocou. Ele é
consultivo por natureza: acusa `CHANGELOG.md` intocado quando há código novo, `.env.example`
intocado quando apareceu uma variável de ambiente nova, arquivo de versão parado quando há
mudança de comportamento, roteiro de QA parado quando há migração.

Ele não sabe se a mudança é visível ao usuário. Isso é julgamento seu, e por isso os achados
dele são avisos com uma pergunta, não veredicto.

---

## 5. Checklist antes do commit

- [ ] Localizei a linha da minha mudança na matriz da seção 2
- [ ] Todo documento marcado foi atualizado **neste commit**, não no próximo
- [ ] README: a seção certa, não só o topo. A árvore de estrutura conferida contra o disco
- [ ] CHANGELOG: escrito para quem usa, com a migração declarada como aditiva ou destrutiva
- [ ] spec: atualizada se o comportamento mudou, ou spec nova se a mudança foi grande
- [ ] Roteiro de QA: caso novo, caso de regressão do defeito corrigido, casos de segurança
- [ ] AGENTS.md: armadilha descoberta virou linha
- [ ] `.env.example`: chave nova presente, com placeholder e comentário
- [ ] Versão subida, com o nível SemVer justificado (R13, [release-e-deploy.md](release-e-deploy.md))
- [ ] Página do projeto, se existir, afirmando os mesmos números que o README
- [ ] `scan-doc-sync.sh` sem aviso que eu não saiba explicar
