# Instruções para agentes de IA: este repositório

Este repositório **é** a skill *Development Pattern for Web Apps*. Ele não contém código de
aplicação: só Markdown, templates e quatro scripts de shell.

## Antes de editar qualquer coisa aqui

Leia [`skills/development-pattern-for-web-apps/SKILL.md`](skills/development-pattern-for-web-apps/SKILL.md).
As dezoito regras que ele define valem também para este repositório.

## Regras da casa

- **R17: nada de travessão.** Este repositório segue a própria regra. Os únicos travessões
  que restam estão em `references/linguagem-e-texto-da-interface.md`, dentro de crases, onde
  o caractere é citado para poder ser proibido, e no próprio `scan-linguagem.sh`, que precisa
  contê-lo para procurá-lo. Os dois estão em `.linguagemscanignore`. Ao escrever qualquer
  texto novo aqui, use dois-pontos, vírgula, parênteses ou ponto.

- **R1: nenhum segredo, nenhum dado real.** Todo exemplo usa placeholder obviamente falso e
  obviamente acionável, `SEU-USUARIO`, `SUA-SENHA`, `seu-dominio.com.br`, `usuario@example.com`.
  Nunca um valor que pareça funcionar: o leitor precisa ser incapaz de confundi-lo com algo real.
  Rode os scanners antes de todo commit:

  ```bash
  bash skills/development-pattern-for-web-apps/assets/scripts/scan-secrets.sh
  git diff --cached | bash skills/development-pattern-for-web-apps/assets/scripts/scan-secrets.sh --stdin
  bash skills/development-pattern-for-web-apps/assets/scripts/scan-sql-injection.sh
  bash skills/development-pattern-for-web-apps/assets/scripts/scan-linguagem.sh
  bash skills/development-pattern-for-web-apps/assets/scripts/scan-doc-sync.sh
  ```

- **R4: nada inventado, especialmente aqui.** A credibilidade desta skill depende de cada
  afirmação ser verificável. Antes de mudar uma função, uma constante do PDO, uma classe do
  Tailwind ou uma opção de configuração em qualquer referência, confirme na fonte e anote a
  versão conferida:

  ```bash
  php -v && php -m
  php -r 'var_dump(function_exists("str_contains"));'
  npm view next version && npm view tailwindcss version
  ```

  Inventários são **fotografias, não contratos**. Mantenha a linha "verificado em <versão>,
  <data>" ao lado de cada um.

- **R5: o exemplo errado é sempre rotulado.** Todo trecho vulnerável neste repositório vem
  precedido de `❌` e acompanhado da forma correta com `✅`. Nunca deixe um exemplo inseguro
  sem rótulo: alguém vai copiá-lo.

- **R13. README, página e CHANGELOG andam juntos.** `README.md` e `docs/index.html` afirmam as mesmas
  coisas em profundidades diferentes. Quando um muda, o outro muda no mesmo commit: mesmo
  aviso, mesma contagem de regras, mesmos números. Acrescentar ou renumerar uma regra exige
  editar **os dois**, mais as estatísticas da página, mais o `CHANGELOG.md`, mais a `version`
  em `.claude-plugin/plugin.json`.

- **R18: nenhum commit deste repositório credita uma ferramenta de IA.** Nada de
  `Co-Authored-By`, "Generated with", link de sessão ou "Assisted-By" em mensagem de commit,
  título ou corpo de pull request. Se a sua ferramenta insere o rodapé automaticamente,
  desligue antes do primeiro commit e instale o hook. No Claude Code, em
  `~/.claude/settings.json` ou em `.claude/settings.json` do projeto, os três campos:
  `{"attribution": {"commit": "", "pr": "", "sessionUrl": false}}`. O terceiro é o que
  suprime o trailer `Claude-Session:` das sessões web.

  ```bash
  cp skills/development-pattern-for-web-apps/assets/templates/commit-msg.template \
     .git/hooks/commit-msg && chmod +x .git/hooks/commit-msg
  git log --format='%H %s%n%b' | grep -inE 'co-authored-by:.*(claude|anthropic|copilot|gpt)'
  ```

  A auditoria acima tem que sair vazia. Se não sair, a correção está em
  [`references/git-e-publicacao.md`](skills/development-pattern-for-web-apps/references/git-e-publicacao.md),
  com o aviso de que reescrever histórico já publicado quebra o clone de quem já baixou.

- **Português (pt-BR) em todo o conteúdo.** Nomes de arquivo em minúsculas com hífen. Os
  identificadores dos templates (`RF-001`, `CT-SEC-009`, `R5`) são estáveis: renomear um
  quebra referências cruzadas espalhadas por vários documentos.

## Layout do repositório

```
skills/development-pattern-for-web-apps/
├── SKILL.md              # as 18 regras, o pipeline de 8 fases, o roteamento
├── references/           # 18 documentos, carregados sob demanda
└── assets/
    ├── templates/        # 20 arquivos prontos para copiar em um projeto
    └── scripts/          # scan-secrets.sh, scan-sql-injection.sh,
                          #   scan-linguagem.sh, scan-doc-sync.sh
docs/                     # página do GitHub Pages: index.html + tailwind.css (compilado)
tailwind.input.css        # fonte do CSS da página; compile com npm run build:css
specs/                    # a spec desta própria skill (R3 aplicada a ela mesma)
.github/workflows/        # publica docs/ no ramo gh-pages, gerado
.claude-plugin/           # manifestos de plugin e marketplace do Claude Code
```

`gh-pages` é **gerado e sobrescrito** pelo CI. Nunca edite aquele ramo: edite `docs/`.

⚠️ **Empurrar `gh-pages` não habilita o GitHub Pages sozinho.** Num repositório novo é
preciso um passo manual, uma única vez: *Settings → Pages → Source: "Deploy from a branch"
→ Branch: `gh-pages` → `/ (root)` → Save*. Sem isso a URL responde **404** mesmo com o ramo
publicado corretamente pelo workflow.

## A página do projeto (`docs/`)

A página é **Tailwind compilado**, não Tailwind por CDN: sem centenas de KB de JavaScript,
sem piscar ao carregar, e funciona com JavaScript desligado. `docs/tailwind.css` é gerado e
**versionado de propósito**: o workflow do Pages apenas copia `docs/`, sem etapa de build.

Depois de **qualquer** mudança em `docs/index.html`, recompile e confira:

```bash
npm install          # uma vez
npm run build:css    # regenera docs/tailwind.css a partir de tailwind.input.css
```

Um `docs/index.html` alterado sem `docs/tailwind.css` recompilado no mesmo commit é um
commit incompleto: as classes novas simplesmente não existem no CSS publicado.

### A linguagem visual segue o site do Tailwind

Decisões deliberadas, para manter a coerência ao editar:

- **Coluna emoldurada.** O conteúdo vive em `.moldura` (`max-w-6xl`) com réguas verticais
  de 1px; as margens externas levam a hachura diagonal (`.hachura` no `<body>`).
- **Marcadores em cruz** onde cada `.divisoria` cruza as réguas verticais.
- **Alinhamento à esquerda** em todos os cabeçalhos de seção: rótulo pequeno colorido,
  título `font-semibold tracking-tight` quase preto, parágrafo em cinza.
- **Blocos de código sempre escuros**, nos dois temas, dentro de `.painel-codigo` com a
  `.barra-arquivo` nomeando o arquivo. Não use fundo claro em código.
- **Botão primário sólido quase preto** no claro, invertido para branco no escuro.
- **Inter** como tipografia de interface: a **única requisição externa** da página, via
  Google Fonts com `display=swap` e uma pilha de fallback completa. Se preferir zero
  dependência externa, remova as três tags `<link>` do `<head>`: a página continua
  correta na fonte do sistema.

### Modo claro é o padrão; o escuro é opcional

A variante `dark:` é por **classe**, não por `prefers-color-scheme`, é isso que a linha
`@custom-variant dark` em `tailwind.input.css` faz. Um script mínimo no `<head>` aplica a
classe antes da primeira pintura, lendo `localStorage.tema`. Se você trocar essa lógica,
teste os quatro casos: claro em 1440 px, escuro em 1440 px, claro em 375 px, escuro em 375 px.

### Duas armadilhas de layout já pagas neste repositório

- **Item de grid tem `min-width: auto`**, então um `<pre>` largo estica a coluna inteira e
  cria rolagem horizontal na página. Todo wrapper de grid que contenha bloco de código leva
  `min-w-0`, e `.cartao`/`.bloco` já trazem `min-w-0` embutido.
- **`overflow` no `<body>` é propagado para o viewport** em vez de recortar o próprio box:
  pôr `overflow-x: clip` lá não resolve nada. Os marcadores em cruz ficam 5px fora da
  moldura, e o recorte precisa ir num wrapper intermediário: é o que `.recorte-lateral`
  faz. Use `clip`, nunca `hidden`: `hidden` viraria contêiner de rolagem e quebraria o
  cabeçalho sticky e a rolagem interna dos blocos de código.

## Convenções de escrita

- Cada referência abre com a regra que ela impõe e por que a falha importa, depois dá
  comandos, depois dá o checklist. Concreto antes de abstrato.
- Toda afirmação absoluta carrega a fonte: caminho de arquivo, URL ou versão de pacote.
- Templates usam marcadores `<PLACEHOLDER>` ou `SEU-`/`SUA-`, de modo que um campo não
  preenchido salte aos olhos.
- Tabelas antes de listas quando há mais de duas dimensões.

## Verificando uma mudança

Não há build. Antes do push:

```bash
# scanners limpos
bash skills/development-pattern-for-web-apps/assets/scripts/scan-secrets.sh
bash skills/development-pattern-for-web-apps/assets/scripts/scan-sql-injection.sh
bash skills/development-pattern-for-web-apps/assets/scripts/scan-linguagem.sh

# sintaxe dos scripts e dos templates executáveis
bash -n skills/development-pattern-for-web-apps/assets/scripts/scan-secrets.sh
bash -n skills/development-pattern-for-web-apps/assets/scripts/scan-sql-injection.sh
bash -n skills/development-pattern-for-web-apps/assets/scripts/scan-linguagem.sh
php  -l skills/development-pattern-for-web-apps/assets/templates/install-wizard.php.template
php  -l skills/development-pattern-for-web-apps/assets/templates/updater.php.template
php  -l skills/development-pattern-for-web-apps/assets/templates/Database.php.template

# arquivos estruturados
python3 -c "import yaml;yaml.safe_load(open('.github/workflows/pages.yml'))"
python3 -c "import json;json.load(open('.claude-plugin/plugin.json'))"
python3 -c "import json;json.load(open('skills/development-pattern-for-web-apps/assets/templates/update-manifest.json.template'))"

# a página: recompilar o CSS e conferir os quatro casos
npm run build:css
# claro 1440 · escuro 1440 · claro 375 · escuro 375: nenhum deve ter rolagem horizontal
```

Conferência de consistência: estes números aparecem em vários lugares e desalinham fácil:

```bash
grep -c '^| \*\*R' skills/development-pattern-for-web-apps/SKILL.md    # 18 regras
ls skills/development-pattern-for-web-apps/references/*.md | wc -l      # 18 referências
ls skills/development-pattern-for-web-apps/assets/templates/* | wc -l   # 20 templates
ls skills/development-pattern-for-web-apps/assets/scripts/*.sh | wc -l  # 4 scanners
grep -rn "dezessete\|dezesseis\|quinze" README.md AGENTS.md docs/index.html skills/**/SKILL.md
```
