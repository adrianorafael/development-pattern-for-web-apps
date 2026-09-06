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
# SAÍDA
#   0  nada a apontar
#   1  há documento que a matriz pede e o commit não toca
#
# NATUREZA CONSULTIVA
#   Ele não sabe se a sua mudança é visível ao usuário: isso é julgamento seu. Os achados
#   são perguntas, não veredicto. Se a resposta for "esta mudança não muda nada para quem
#   usa", siga em frente. A matriz completa está em
#   references/documentacao-do-projeto.md
#
# LIMITE CONHECIDO
#   Ele confere se o arquivo FOI TOCADO, não se foi bem atualizado. Um CHANGELOG com uma
#   linha vazia passa. Leia o que você escreveu.

set -uo pipefail

RED=$'\033[0;31m'; YEL=$'\033[0;33m'; GRN=$'\033[0;32m'; DIM=$'\033[2m'; NC=$'\033[0m'
[ -t 1 ] || { RED=""; YEL=""; GRN=""; DIM=""; NC=""; }

ACHADOS=0

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Fora de um repositório git, nada a comparar."
  exit 0
fi

if [ "${1:-}" = "--head" ]; then
  ALVO="HEAD~1 HEAD"; ROTULO="o último commit"
  # shellcheck disable=SC2086
  MUDADOS="$(git diff --name-only $ALVO 2>/dev/null || true)"
  DIFF="$(git diff $ALVO 2>/dev/null || true)"
else
  ROTULO="o conteúdo staged"
  MUDADOS="$(git diff --cached --name-only 2>/dev/null || true)"
  DIFF="$(git diff --cached 2>/dev/null || true)"
fi

if [ -z "$MUDADOS" ]; then
  echo "Nada em $ROTULO."
  exit 0
fi

tocou() { printf '%s\n' "$MUDADOS" | grep -qE "$1"; }
existe() { [ -e "$1" ]; }

# Descobre onde vive a versão deste projeto.
ARQ_VERSAO=""
for cand in app/version.php src/version.php package.json composer.json .claude-plugin/plugin.json; do
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
CODIGO='\.(php|phtml|ts|tsx|js|jsx|vue|svelte)$'
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

# Variável de ambiente nova no código, mas o exemplo não mudou?
if printf '%s' "$DIFF" | grep -qE '^\+.*(process\.env\.[A-Z_]{3,}|getenv\(|\$_ENV\[)'; then
  for exemplo in .env.example config/config.example.php config.example.php; do
    if existe "$exemplo" && ! tocou "^${exemplo//./\\.}$"; then
      apontar PEDE "$exemplo intocado" \
        "Apareceu leitura de variável de ambiente no diff. Chave nova entra aqui no mesmo commit (R1)."
      break
    fi
  done
fi

# Migração nova?
if tocou 'migrations?/.*\.sql$'; then
  existe CHANGELOG.md && ! tocou '^CHANGELOG\.md$' && \
    apontar PEDE "CHANGELOG.md sem a migração" \
      "Toda migração é declarada, dizendo se é aditiva ou destrutiva e quanto pode levar."
  if printf '%s' "$DIFF" | grep -qiE '^\+.*(DROP (TABLE|COLUMN)|TRUNCATE|DELETE FROM)'; then
    apontar PEDE "migração destrutiva" \
      "README e spec precisam registrar a perda de dados, e a versão sobe como MAJOR (R13)."
  fi
fi

# Dependência nova?
if printf '%s' "$DIFF" | grep -qE '^\+\s*"[a-z0-9@/_.-]+":\s*"\^?[0-9~*]' ; then
  existe README.md && ! tocou '^README\.md$' && \
    apontar OLHE "README.md sem os requisitos" \
      "Dependência ou extensão nova costuma virar linha na seção de pré-requisitos."
fi

# Rota nova ou renomeada?
if printf '%s' "$DIFF" | grep -qE "^\+.*(('|\")(GET|POST|PUT|DELETE)\s+/|app/[a-z0-9-]+/page\.(tsx|jsx))"; then
  existe README.md && ! tocou '^README\.md$' && \
    apontar PEDE "README.md sem a rota" \
      "Rota nova ou renomeada entra na tabela de rotas. Renomeada mantém 301 da antiga (R15)."
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
