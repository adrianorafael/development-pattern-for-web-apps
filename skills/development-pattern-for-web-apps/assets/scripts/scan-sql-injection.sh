#!/usr/bin/env bash
# scan-sql-injection.sh: procura SQL montado por concatenação.
#
# Parte de "Development Pattern for Web Apps".
# Impõe a regra R5: dado de usuário nunca entra no TEXTO de um comando SQL.
#
# USO
#   bash scan-sql-injection.sh                  # varre a árvore de trabalho
#   bash scan-sql-injection.sh lib/db.ts ...    # varre caminhos específicos
#
# SAÍDA
#   0  limpo
#   1  achados, NÃO FAÇA COMMIT
#
# FALSO POSITIVO
#   Marcador  scan-sql:allow  como comentário NA LINHA ou NA LINHA IMEDIATAMENTE ACIMA
#   (onde cabe explicar por quê), ou caminho em .sqlscanignore.
#   Antes de suprimir, pergunte: esse valor vem de allowlist do seu código, ou do usuário?
#   Só o primeiro caso justifica a supressão.
#
# LIMITE CONHECIDO
#   A varredura é por linha. Uma consulta montada em várias linhas, ou por uma função
#   auxiliar, pode escapar. Uma varredura limpa é necessária, não suficiente: leia o
#   seu próprio diff.

set -uo pipefail

RED=$'\033[0;31m'; YEL=$'\033[0;33m'; GRN=$'\033[0;32m'; DIM=$'\033[2m'; NC=$'\033[0m'
[ -t 1 ] || { RED=""; YEL=""; GRN=""; DIM=""; NC=""; }

MARCADOR='scan-sql:allow'
ACHADOS=0
SQLKW='SELECT|INSERT|UPDATE|DELETE|REPLACE|WHERE|FROM|INTO|VALUES|ORDER[[:space:]]+BY|GROUP[[:space:]]+BY|HAVING|LIMIT|JOIN|SET|DROP|TRUNCATE|ALTER'

# nome|severidade|regex|linguagens
PADROES=(
  # ── JavaScript / TypeScript ───────────────────────────────────────────────────
  "Método 'unsafe'/'raw' de acesso a banco|ALTA|(\\\$queryRawUnsafe|\\\$executeRawUnsafe|sql\.raw|knex\.raw|sequelize\.query)[[:space:]]*\(|js"
  # sql.unsafe('… $1', [v]) com texto LITERAL é a forma parametrizada do driver `postgres`.
  # Com o texto numa variável, o scanner não enxerga como ele foi montado: exige o marcador.
  "sql.unsafe() com o texto numa variável: declare a allowlist com o marcador|ALTA|\.unsafe[[:space:]]*\([[:space:]]*[a-zA-Z_\$][a-zA-Z0-9_\$.]*[[:space:]]*[,)]|js"
  "sql.unsafe() com template literal interpolado|ALTA|\.unsafe[[:space:]]*\([[:space:]]*\`[^\`]*\\\$\{|js"
  "Template literal com SQL e \${} fora de tag parametrizada|ALTA|[^a-zA-Z0-9_\$]\`[^\`]*($SQLKW)[^\`]*\\\$\{|js"
  "Query montada por concatenação de string|ALTA|['\"][^'\"]*($SQLKW)[^'\"]*['\"][[:space:]]*\+[[:space:]]*[a-zA-Z_\$]|js"
  # sql.query(`... ${x} ...`) e pool.query(`... ${x} ...`): o template literal é
  # resolvido ANTES da chamada, então o ${} vira texto, não parâmetro. É
  # concatenação disfarçada, mesmo sem palavra-chave SQL na mesma linha.
  "Template literal interpolado passado a .query()/.execute()|ALTA|\.(query|execute)[[:space:]]*(<[^>]*>)?[[:space:]]*\([[:space:]]*\`[^\`]*\\\$\{|js"
  # Mesma armadilha em várias linhas: a varredura é por linha e não vê o ${}
  # das linhas seguintes. Peça a leitura humana.
  "Template literal multilinha passado a .query()/.unsafe(): confira se há \${}|MEDIA|\.(query|unsafe)[[:space:]]*(<[^>]*>)?[[:space:]]*\([[:space:]]*\`[^\`]*$|js"
  # ── Cliente do Supabase (@supabase/postgrest-js) ──────────────────────────────
  # .or() recebe uma STRING de filtro do PostgREST, usada como está
  # (dist/index.d.cts, linha 3180 na 2.117.3). Uma vírgula ou um parêntese no
  # dado vira condição nova: é injeção de filtro. Use .eq/.ilike/.in, ou .rpc().
  "Template literal interpolado passado a .or() do Supabase|ALTA|\.or[[:space:]]*\([[:space:]]*\`[^\`]*\\\$\{|js"
  # .filter(coluna, operador, valor) e .not(...) usam operador e valor "as-is"
  # (linhas 3161 e 3339). Exige as três partes para não acusar Array.filter().
  "Template literal interpolado passado a .filter()/.not() do Supabase|ALTA|\.(filter|not)[[:space:]]*\([[:space:]]*['\"\`][^'\"\`]*['\"\`][[:space:]]*,[^,]*,[[:space:]]*\`[^\`]*\\\$\{|js"
  "String concatenada passada a .or() do Supabase|ALTA|\.or[[:space:]]*\([[:space:]]*['\"][^'\"]*['\"][[:space:]]*\+|js"
  "Template literal multilinha passado a .or(): confira se há \${}|MEDIA|\.or[[:space:]]*\([[:space:]]*\`[^\`]*$|js"
)

caminho_ignorado() {
  local f="$1" raiz ignore
  raiz="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
  ignore="$raiz/.sqlscanignore"
  [ -f "$ignore" ] || return 1
  while IFS= read -r linha; do
    [ -z "$linha" ] && continue
    case "$linha" in \#*) continue ;; esac
    case "$f" in *"$linha"*) return 0 ;; esac
  done < "$ignore"
  return 1
}

reportar() { # arquivo linha severidade nome texto
  local sev="$3" cor="$YEL"
  [ "$sev" = ALTA ] && cor="$RED"
  printf '%s[%s]%s %s\n      %s:%s\n      %s%s%s\n\n' \
    "$cor" "$sev" "$NC" "$4" "$1" "$2" "$DIM" "${5:0:170}" "$NC"
  ACHADOS=$((ACHADOS + 1))
}

lingua_do_arquivo() {
  case "$1" in
    *.js|*.jsx|*.ts|*.tsx|*.mjs|*.cjs|*.mts|*.ts.template) echo js ;;
    *) echo outro ;;
  esac
}

varrer_arquivo() {
  local f="$1" lang entrada nome resto sev re alvo linha num texto sem_recuo anterior
  [ -f "$f" ] || return 0
  caminho_ignorado "$f" && return 0
  case "$f" in */node_modules/*|*/.next/*|*/.git/*) return 0 ;; esac

  lang="$(lingua_do_arquivo "$f")"
  [ "$lang" = outro ] && return 0

  for entrada in "${PADROES[@]}"; do
    nome="${entrada%%|*}";  resto="${entrada#*|}"
    sev="${resto%%|*}";     resto="${resto#*|}"
    re="${resto%|*}";       alvo="${resto##*|}"
    [ "$alvo" = "$lang" ] || continue

    while IFS= read -r linha; do
      [ -z "$linha" ] && continue
      num="${linha%%:*}"; texto="${linha#*:}"
      # Sem o recuo, para reconhecer comentário em qualquer coluna (inclusive a 1).
      sem_recuo="${texto#"${texto%%[![:space:]]*}"}"
      case "$texto" in *"$MARCADOR"*) continue ;; esac
      case "$sem_recuo" in
        # Linhas de comentário costumam ser exemplo do que NÃO fazer.
        "//"*|"#"*|"*"*|"/*"*|"--"*) continue ;;
      esac
      # O marcador também vale como comentário na linha imediatamente acima: é onde
      # cabe escrever POR QUE a interpolação é segura, que é o ponto do mecanismo.
      if [ "$num" -gt 1 ]; then
        anterior="$(sed -n "$((num - 1))p" "$f" 2>/dev/null || true)"
        case "$anterior" in *"$MARCADOR"*) continue ;; esac
      fi
      reportar "$f" "$num" "$sev" "$nome" "$texto"
    done < <(grep -nE -- "$re" "$f" 2>/dev/null || true)
  done
}

echo "💉 Procurando SQL montado por concatenação…"
echo

if [ "$#" -gt 0 ]; then
  for f in "$@"; do varrer_arquivo "$f"; done
elif git rev-parse --git-dir >/dev/null 2>&1; then
  while IFS= read -r f; do varrer_arquivo "$f"; done \
    < <(git ls-files --cached --others --exclude-standard)
else
  while IFS= read -r f; do varrer_arquivo "$f"; done \
    < <(find . -type f \( -name '*.js' -o -name '*.ts' -o -name '*.tsx' -o -name '*.jsx' -o -name '*.mjs' -o -name '*.cjs' -o -name '*.mts' \) \
        -not -path '*/node_modules/*' -not -path '*/.next/*' -not -path '*/.git/*')
fi

if [ "$ACHADOS" -eq 0 ]; then
  echo "${GRN}✅ Limpo: nenhum SQL concatenado detectado.${NC}"
  echo "${DIM}   A varredura é por linha: consulta montada em várias linhas pode escapar."
  echo "   Leia o seu próprio diff.${NC}"
  exit 0
fi

echo "${RED}❌ $ACHADOS achado(s). NÃO FAÇA COMMIT.${NC}"
echo
echo "Como corrigir:"
echo "  • Dado do usuário → parâmetro vinculado: sql\`… = \${v}\` (template tag) ou"
echo "    sql.unsafe('… = \$1', [v]). Nunca sql.unsafe(\`… \${v} …\`) nem pool.query(\`… \${v} …\`): isso é concatenação."
echo "  • Nome de coluna/tabela/direção → allowlist (mapa no seu código), nunca a entrada crua."
echo "    Identificador NÃO pode ser parametrizado: resolva por allowlist e declare a exceção"
echo "    na própria linha com '${MARCADOR}: <nome da allowlist>'. Sem marcador, o commit para."
echo "  • Supabase → métodos tipados (.eq, .ilike com escaparLike, .in) ou .rpc() com"
echo "    argumentos. Nunca .or(\`… \${v} …\`) nem .filter(col, op, \`… \${v} …\`): a string"
echo "    de filtro do PostgREST é usada como está, e uma vírgula no dado vira condição."
echo "  • LIMIT/OFFSET → Math.trunc com teto, e ainda assim por parâmetro."
echo "  • Prisma → \$queryRaw\`…\` (tag), nunca \$queryRawUnsafe com interpolação."
echo "    Drizzle → sql\`…\` do drizzle-orm, nunca sql.raw() com entrada."
echo "  • Detalhes: references/sql-e-acesso-a-dados.md"
echo
echo "${DIM}Falso positivo? Marcador '${MARCADOR}' na linha, ou caminho em .sqlscanignore.${NC}"
exit 1
