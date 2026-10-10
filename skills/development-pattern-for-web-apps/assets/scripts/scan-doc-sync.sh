#!/usr/bin/env bash
# scan-doc-sync.sh: aponta a documentação que a mudança pede e você não tocou.
#
# Parte de "Development Pattern for Web Apps".
# Apoia a regra R13: toda mudança atualiza os documentos que ela afeta, no MESMO commit.
#
# USO
#   bash scan-doc-sync.sh              # compara o que está no staging
#   bash scan-doc-sync.sh --head       # compara o último commit já feito
#
# O QUE ELE CONFERE
#   No diff: CHANGELOG, versão, README, roteiro de QA e AGENTS.md diante de código novo;
#   .env.example e lib/env.ts diante de process.env novo; migração (supabase/migrations/)
#   destrutiva ou sem registro; rota nova, renomeada ou apagada; dependência adicionada
#   ou removida sem o nome no CHANGELOG; docs/api.md, docs/banco-de-dados.md e
#   docs/seguranca.md (quando existem) diante de Route Handler, migração ou mudança de
#   autenticação; TODO/FIXME sem descrição; bloco de código comentado; função exportada
#   em lib/ ou actions/ sem TSDoc.
#   Na árvore inteira (git ls-files, sem node_modules nem .next): todo process.env.X lido
#   no código contra as chaves do .env.example, nos dois sentidos.
#
# SAÍDA
#   0  nada a apontar (também quando não há nada staged, ou fora de um repositório git)
#   1  há ponto para você decidir: documento que a matriz pede e o commit não toca, ou
#      código que a matriz de comentários e TSDoc pede para olhar
#
# NATUREZA CONSULTIVA
#   Ele não sabe se a sua mudança é visível ao usuário: isso é julgamento seu. Os achados
#   são perguntas, não veredicto. Se a resposta for "esta mudança não muda nada para quem
#   usa", siga em frente. A matriz completa está em
#   references/documentacao-do-projeto.md
#
# LIMITES CONHECIDOS
#   Ele confere se o arquivo FOI TOCADO, não se foi bem atualizado. Um CHANGELOG com uma
#   linha vazia passa. Leia o que você escreveu.
#   As conferências de código são heurísticas de linha, sem entender TypeScript:
#   - TSDoc: olha só a linha imediatamente anterior ao `export` (precisa terminar em */).
#     Um decorador ou comentário de linha no meio vira falso positivo.
#   - Código comentado: 3 ou mais linhas seguidas começando com // e terminando em ;, {
#     ou }. Bloco que termina em vírgula ou parêntese passa sem aviso.
#   - Variáveis: só a leitura literal (process.env.X ou process.env['X']). Leitura
#     dinâmica (process.env[nome]) e chaves lidas pelo esquema Zod em lib/env.ts não
#     aparecem nesse sentido; no sentido contrário, uma chave do .env.example conta como
#     usada se o nome aparece em qualquer arquivo de código ou configuração versionado.
#   - Ignora as variáveis que a própria Vercel ou o Node definem (VERCEL_*, NODE_ENV,
#     NEXT_RUNTIME, CI) e as que o .env.example traz comentadas (# CHAVE=...), que é o
#     jeito de documentar uma variável opcional.

set -uo pipefail

RED=$'\033[0;31m'; YEL=$'\033[0;33m'; GRN=$'\033[0;32m'; DIM=$'\033[2m'; NC=$'\033[0m'
[ -t 1 ] || { RED=""; YEL=""; GRN=""; DIM=""; NC=""; }

ACHADOS=0

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Fora de um repositório git, nada a comparar."
  exit 0
fi

if [ "${1:-}" = "--head" ]; then
  MODO=head; ALVO="HEAD~1 HEAD"; ROTULO="o último commit"
  # shellcheck disable=SC2086
  MUDADOS="$(git diff --name-only $ALVO 2>/dev/null || true)"
  # shellcheck disable=SC2086
  STATUS="$(git diff --name-status $ALVO 2>/dev/null || true)"
  DIFF="$(git diff $ALVO 2>/dev/null || true)"
else
  MODO=staged; ROTULO="o conteúdo staged"
  MUDADOS="$(git diff --cached --name-only 2>/dev/null || true)"
  STATUS="$(git diff --cached --name-status 2>/dev/null || true)"
  DIFF="$(git diff --cached 2>/dev/null || true)"
fi

if [ -z "$MUDADOS" ]; then
  echo "Nada em $ROTULO."
  exit 0
fi

# grep sem -q: com -q ele sai no primeiro acerto, o printf leva SIGPIPE num diff grande
# e o pipefail transforma o acerto em falha.
tocou() { printf '%s\n' "$MUDADOS" | grep -E "$1" >/dev/null; }
no_diff() { printf '%s\n' "$DIFF" | grep -E "$1" >/dev/null; }
existe() { [ -e "$1" ]; }

# Descobre onde vive a versão deste projeto: package.json num app Next.js.
ARQ_VERSAO=""
for cand in package.json .claude-plugin/plugin.json; do
  [ -f "$cand" ] && { ARQ_VERSAO="$cand"; break; }
done

apontar() { # severidade documento pergunta
  local sev="$1" cor="$YEL"
  [ "$sev" = PEDE ] && cor="$RED"
  printf '%s[%s]%s %s\n      %s\n\n' "$cor" "$sev" "$NC" "$2" "$3"
  ACHADOS=$((ACHADOS + 1))
}

echo "📝 Conferindo a documentação contra $ROTULO…"
echo

# Houve mudança de código de aplicação?
CODIGO='\.(ts|tsx|js|jsx|mjs|cjs)$'
if tocou "$CODIGO"; then

  if existe CHANGELOG.md && ! tocou '^CHANGELOG\.md$'; then
    apontar PEDE "CHANGELOG.md intocado" \
      "Há código novo. Alguém que atualize o app vai perceber alguma diferença? Se sim, entra aqui."
  fi

  if [ -n "$ARQ_VERSAO" ] && ! tocou "^${ARQ_VERSAO//./\\.}$"; then
    apontar PEDE "versão parada em $ARQ_VERSAO" \
      "Mudança de comportamento sobe a versão em SemVer, no mesmo commit (R13)."
  fi

  if existe qa/roteiro-de-testes.md && ! tocou '^qa/roteiro-de-testes\.md$'; then
    apontar PEDE "qa/roteiro-de-testes.md intocado" \
      "Corrigiu defeito? Vira caso CT-REG. Campo novo que chega ao banco? Vira caso CT-SEC (R11)."
  fi

  if existe README.md && ! tocou '^README\.md$'; then
    apontar OLHE "README.md intocado" \
      "Instalação, configuração, rotas ou uso mudaram? Se não, tudo bem."
  fi
fi

# Variável de ambiente nova no código, mas o exemplo ou a validação não mudaram?
if no_diff '^\+.*process\.env\.[A-Z_]{3,}' || tocou '^(src/)?lib/env\.ts$'; then
  if existe .env.example && ! tocou '^\.env\.example$'; then
    apontar PEDE ".env.example intocado" \
      "Apareceu variável de ambiente no diff. Chave nova entra aqui no mesmo commit (R1, R9)."
  fi
  for validacao in lib/env.ts src/lib/env.ts; do
    if existe "$validacao" && ! tocou "^${validacao//./\\.}$"; then
      apontar PEDE "$validacao intocado" \
        "Leitura nova de process.env sem passar pela validação Zod. Declare a chave em $validacao (R9)."
      break
    fi
  done
fi

# Migração nova? A Supabase CLI grava em supabase/migrations/<timestamp>_<nome>.sql.
if tocou '^(supabase/)?migrations/[^/]+\.sql$'; then
  existe CHANGELOG.md && ! tocou '^CHANGELOG\.md$' && \
    apontar PEDE "CHANGELOG.md sem a migração" \
      "Toda migração é declarada, dizendo se é aditiva ou destrutiva e quanto pode levar."
  if printf '%s\n' "$DIFF" | grep -iE '^\+.*(DROP (TABLE|COLUMN)|TRUNCATE|DELETE FROM|RENAME (TABLE|COLUMN|TO))' >/dev/null; then
    apontar PEDE "migração destrutiva" \
      "Ela quebra o código anterior, e o Instant Rollback volta para ele. Só cabe na fase contract, num release seguinte, com ponto de restauração; versão MAJOR (R10, R13)."
  fi
  if existe README.md && ! tocou '^README\.md$'; then
    apontar OLHE "README.md intocado" \
      "A migração muda o caminho de volta ou o passo de bootstrap? Se sim, o README diz (R10)."
  fi
fi

# Dependência nova?
if no_diff '^\+[[:space:]]*"[a-z0-9@/_.-]+":[[:space:]]*"\^?[0-9~*]'; then
  existe README.md && ! tocou '^README\.md$' && \
    apontar OLHE "README.md sem os requisitos" \
      "Dependência ou extensão nova costuma virar linha na seção de pré-requisitos."
fi

# Rota nova ou renomeada? No App Router a pasta é a URL: page.tsx ou route.ts
# adicionado (A), renomeado (R) ou apagado (D) significa URL nova, mudada ou sumida.
ROTA_ARQ='(^|[[:space:]/])(src/)?app/(.*/)?(page|route)\.(tsx|ts|jsx|js)$'
if printf '%s\n' "$STATUS" | grep -E '^(A|R[0-9]*|D)[[:space:]]' | grep -E "$ROTA_ARQ" >/dev/null; then
  existe README.md && ! tocou '^README\.md$' && \
    apontar PEDE "README.md sem a rota" \
      "Rota nova, renomeada ou removida entra na tabela de rotas. Pasta em português e kebab-case (R15)."
  if printf '%s\n' "$STATUS" | grep -E '^(R[0-9]*|D)[[:space:]]' | grep -E "$ROTA_ARQ" >/dev/null; then
    if ! tocou '^next\.config\.(ts|js|mjs)$'; then
      apontar PEDE "next.config sem redirect" \
        "Pasta de rota renomeada ou apagada: a URL antiga precisa de 301 em redirects() do next.config.ts (R15)."
    fi
  fi
  if existe qa/roteiro-de-testes.md && ! tocou '^qa/roteiro-de-testes\.md$'; then
    apontar OLHE "roteiro sem a rota" \
      "A rota nova entra nos casos de navegação do roteiro (acesso direto, F5, 404)."
  fi
fi

# Armadilha descoberta merece AGENTS.md, mas isso é julgamento: só lembramos.
if existe AGENTS.md && tocou "$CODIGO" && ! tocou '^AGENTS\.md$'; then
  apontar OLHE "AGENTS.md intocado" \
    "Descobriu alguma armadilha do ambiente nesta mudança? Ela vale uma linha, para a próxima sessão."
fi

# Página do projeto e README afirmam as mesmas coisas.
if existe docs/index.html && tocou '^README\.md$' && ! tocou '^docs/index\.html$'; then
  apontar OLHE "docs/index.html intocado" \
    "O README mudou. A página afirma as mesmas coisas em outra profundidade (R13)."
fi

# ── Documentos de docs/: só cobrados quando o projeto já os tem ─────────────
# Profundidade proporcional: projeto pequeno não precisa deles, e o scanner não
# pede que sejam criados. Existindo, eles andam com o código que descrevem.
if existe docs/api.md && tocou '(^|/)(src/)?app/(.*/)?route\.(ts|js)$' && ! tocou '^docs/api\.md$'; then
  apontar PEDE "docs/api.md intocado" \
    "Um Route Handler mudou. Método, rota, autenticação, corpo ou resposta mudaram? Se sim, docs/api.md diz."
fi

if existe docs/banco-de-dados.md && tocou '^supabase/migrations/' && ! tocou '^docs/banco-de-dados\.md$'; then
  apontar PEDE "docs/banco-de-dados.md intocado" \
    "Há migração nova. A tabela, o relacionamento, a matriz de acesso da RLS ou a lista de migrações mudou? Se sim, entra lá."
fi

SEGURANCA_ARQ='(^|/)(proxy|middleware)\.(ts|js)$|politicas|^(src/)?lib/supabase/|^next\.config\.(ts|js|mjs)$|(^|/)(auth|entrar|sair|sessao|autenticacao)(/|\.|$)'
if existe docs/seguranca.md && tocou "$SEGURANCA_ARQ" && ! tocou '^docs/seguranca\.md$'; then
  apontar OLHE "docs/seguranca.md intocado" \
    "Mudou autenticação, proxy, política de RLS, cabeçalho ou cliente do Supabase. Alguma proteção ativa ou ação manual fora do código mudou?"
fi

# ── Linhas adicionadas, com arquivo, número e linha anterior ────────────────
# Uma linha por linha do diff: tipo (+ ou -), arquivo, número na versão nova,
# linha anterior que sobrevive (contexto ou adicionada) e o conteúdo. O separador
# é o caractere 0x1f, que não aparece em código-fonte.
SEP=$'\x1f'
LINHAS="$(printf '%s\n' "$DIFF" | awk -v S="$SEP" '
  /^diff --git / { cab = 1; arq = ""; arqA = ""; next }
  cab && /^--- / { arqA = substr($0, 5); sub(/^a\//, "", arqA); next }
  cab && /^\+\+\+ / { arq = substr($0, 5); sub(/^b\//, "", arq); if (arq == "/dev/null") arq = arqA; next }
  cab && !/^@@/ { next }
  /^@@/ {
    cab = 0; ant = ""
    n = $0; sub(/^@@ -[0-9,]+ \+/, "", n); sub(/[ ,].*/, "", n); num = n - 1
    next
  }
  /^\+/ { num++; l = substr($0, 2); print "+" S arq S num S ant S l; ant = l; next }
  /^ /  { num++; ant = substr($0, 2); next }
  /^-/  { print "-" S arq S num S ant S substr($0, 2); next }
')"

adicionadas_em() { # regex-de-arquivo → "arquivo:linha<SEP>conteúdo"
  printf '%s\n' "$LINHAS" | awk -F"$SEP" -v S="$SEP" -v re="$1" '$1 == "+" && $2 ~ re { print $2 ":" $3 S $5 }'
}

# TODO/FIXME sem descrição: a pendência que ninguém mais entende daqui a um mês.
PENDENCIA_VAZIA='(^|[^A-Za-z0-9_])(TODO|FIXME)(\([^)]*\))?[[:space:][:punct:]]*$'
while IFS= read -r onde; do
  [ -n "$onde" ] || continue
  apontar PEDE "TODO/FIXME sem descrição em $onde" \
    "O que falta e por quê? Escreva \`// TODO: <o que falta e por quê>\` ou \`// FIXME: <o que está errado>\`."
done < <(adicionadas_em '\.(ts|tsx|js|jsx|mjs|cjs|sql|sh|css)$' \
           | grep -E "$PENDENCIA_VAZIA" | cut -d"$SEP" -f1 | head -n 10)

# Bloco de código comentado: 3 ou mais linhas // seguidas que terminam como código.
while IFS= read -r onde; do
  [ -n "$onde" ] || continue
  apontar OLHE "bloco de código comentado em $onde" \
    "É código morto? O histórico do git já guarda a versão antiga: apague. Se é exemplo, explique em prosa ou num @example do TSDoc."
done < <(printf '%s\n' "$LINHAS" | awk -F"$SEP" '
  function fecha() { if (seq >= 3) print arq ":" ini; seq = 0 }
  $1 == "+" && $2 ~ /\.(ts|tsx|js|jsx|mjs|cjs)$/ && $5 ~ /^[ \t]*\/\/.*[;{}][ \t]*$/ && $5 !~ /^[ \t]*\/\/\// {
    if (seq > 0 && $2 == arq && $3 + 0 == ult + 1) seq++
    else { fecha(); arq = $2; ini = $3; seq = 1 }
    ult = $3 + 0
    next
  }
  { fecha() }
  END { fecha() }
' | head -n 10)

# Função exportada em lib/ ou actions/ sem TSDoc logo acima.
while IFS= read -r onde; do
  [ -n "$onde" ] || continue
  apontar OLHE "export sem TSDoc em $onde" \
    "O que ela faz, o que cada parâmetro significa, o que devolve e que erro lança? Um bloco /** ... */ logo acima responde."
done < <(printf '%s\n' "$LINHAS" | awk -F"$SEP" '
  $1 == "+" && $2 ~ /^(src\/)?(lib|actions)\/.*\.(ts|tsx|js|jsx|mjs)$|(^|\/)actions\.(ts|js)$/ &&
  ($5 ~ /^export (default )?(async )?function[ *]/ ||
   $5 ~ /^export const [A-Za-z0-9_$]+[ \t]*(:[^=]*)?=[ \t]*(async[ \t]*)?\(/) &&
  $4 !~ /\*\/[ \t]*$/ { print $2 ":" $3 }
' | head -n 10)

# Dependência adicionada ou removida sem o nome do pacote no CHANGELOG.
if existe CHANGELOG.md; then
  DEP_RE='^[[:space:]]*"(@?[a-z0-9][a-z0-9._/-]*)"[[:space:]]*:[[:space:]]*"(\^|~|>|<|=|[0-9]|\*|npm:|workspace:|file:|git|github:|link:|latest)'
  deps_do_lado() { # + ou -
    printf '%s\n' "$LINHAS" | awk -F"$SEP" -v t="$1" '$1 == t && $2 ~ /(^|\/)package\.json$/ { print $5 }' \
      | grep -E "$DEP_RE" | sed -E 's/^[[:space:]]*"([^"]+)".*/\1/' \
      | grep -vxE 'name|version|node|npm|pnpm|yarn|bun' | sort -u
  }
  DEP_MAIS="$(deps_do_lado +)"
  DEP_MENOS="$(deps_do_lado -)"
  NO_CHANGELOG="$(printf '%s\n' "$LINHAS" | awk -F"$SEP" '$1 == "+" && $2 == "CHANGELOG.md" { print $5 }')"
  while IFS=' ' read -r acao pacote; do
    [ -n "${pacote:-}" ] || continue
    if ! printf '%s\n' "$NO_CHANGELOG" | grep -F -- "$pacote" >/dev/null; then
      apontar PEDE "CHANGELOG.md sem a dependência $pacote ($acao)" \
        "Por que ela entrou ou saiu? Registre o pacote, a versão e o motivo na subseção Dependências da versão."
    fi
  done < <(
    comm -23 <(printf '%s\n' "$DEP_MAIS") <(printf '%s\n' "$DEP_MENOS") | sed 's/^/adicionada /'
    comm -13 <(printf '%s\n' "$DEP_MAIS") <(printf '%s\n' "$DEP_MENOS") | sed 's/^/removida /'
  )
fi

# ── Árvore inteira: process.env no código contra o .env.example ─────────────
# Roda quando a mudança toca código ou o próprio .env.example. Lê a versão que
# vai para o commit (o índice, ou HEAD com --head), não a cópia de trabalho.
ler_versionado() {
  if [ "$MODO" = head ]; then git show "HEAD:$1" 2>/dev/null
  else git show ":$1" 2>/dev/null || cat "$1" 2>/dev/null; fi
}
git_grep() { # opções e padrão do git grep; os arquivos vêm de ARQS_GREP
  local antes=(--cached) depois=()
  [ "$MODO" = head ] && { antes=(); depois=(HEAD); }
  git grep ${antes[@]+"${antes[@]}"} -h -I "$@" ${depois[@]+"${depois[@]}"} -- "${ARQS_GREP[@]}" \
    ':(exclude,glob)**/node_modules/**' ':(exclude,glob)**/.next/**' 2>/dev/null
}
DO_SISTEMA='^(VERCEL_[A-Z0-9_]*|NODE_ENV|NEXT_RUNTIME|CI)$'

EXEMPLO="$(ler_versionado .env.example || true)"
if [ -n "$EXEMPLO" ] && { tocou "$CODIGO" || tocou '^\.env\.example$'; }; then
  CHAVE_RE='^[[:space:]]*(export[[:space:]]+)?([A-Z_][A-Z0-9_]*)='
  ATIVAS="$(printf '%s\n' "$EXEMPLO" | sed -nE "s/$CHAVE_RE.*/\\2/p" | sort -u)"
  DOCUMENTADAS="$(printf '%s\n' "$EXEMPLO" | sed -nE 's/^[[:space:]]*#?[[:space:]]*(export[[:space:]]+)?([A-Z_][A-Z0-9_]*)=.*/\2/p' | sort -u)"

  ARQS_GREP=('*.ts' '*.tsx' '*.js' '*.jsx' '*.mjs' '*.cjs')
  LIDAS="$(git_grep -o -E "process\.env\.[A-Z_][A-Z0-9_]*|process\.env\[['\"][A-Z_][A-Z0-9_]*['\"]\]" \
    | sed -E "s/^process\.env(\.|\[['\"])([A-Z0-9_]+).*/\2/" | sort -u)"

  while IFS= read -r chave; do
    [ -n "$chave" ] || continue
    printf '%s\n' "$chave" | grep -E "$DO_SISTEMA" >/dev/null && continue
    apontar PEDE ".env.example sem $chave" \
      "O código lê process.env.$chave, e quem clona o projeto não sabe que ela existe. O que ela é, onde obter, é secreta? Entra no .env.example (R9)."
  done < <(comm -23 <(printf '%s\n' "$LIDAS") <(printf '%s\n' "$DOCUMENTADAS") | head -n 20)

  ARQS_GREP=('*.ts' '*.tsx' '*.js' '*.jsx' '*.mjs' '*.cjs' '*.toml' '*.yml' '*.yaml' '*.sh' '*package.json')
  while IFS= read -r chave; do
    [ -n "$chave" ] || continue
    printf '%s\n' "$chave" | grep -E "$DO_SISTEMA" >/dev/null && continue
    git_grep -q -w -F -e "$chave" && continue
    apontar OLHE "$chave no .env.example e em nenhum código" \
      "A variável ainda é usada? Se saiu do código, sai do .env.example, do lib/env.ts e do painel da Vercel no mesmo commit."
  done < <(printf '%s\n' "$ATIVAS" | head -n 40)
fi

if [ "$ACHADOS" -eq 0 ]; then
  echo "${GRN}✅ Nada a apontar: a documentação acompanhou a mudança.${NC}"
  echo "${DIM}   O scanner confere se o arquivo foi TOCADO, não se foi bem atualizado.${NC}"
  exit 0
fi

echo "${RED}❌ $ACHADOS ponto(s) para você decidir.${NC}"
echo
echo "${DIM}[PEDE] a matriz pede este documento para esse tipo de mudança."
echo "[OLHE] costuma ser necessário, mas depende do que mudou."
echo "A matriz completa: references/documentacao-do-projeto.md${NC}"
exit 1
