#!/usr/bin/env bash
# scan-sql-injection.sh — procura SQL montado por concatenação.
#
# Parte de "Development Pattern for Web Apps".
# Impõe a regra R5: dado de usuário nunca entra no TEXTO de um comando SQL.
#
# USO
#   bash scan-sql-injection.sh                  # varre a árvore de trabalho
#   bash scan-sql-injection.sh arquivo.php ...  # varre caminhos específicos
#
# SAÍDA
#   0  limpo
#   1  achados — NÃO FAÇA COMMIT
#
# FALSO POSITIVO
#   Marcador  scan-sql:allow  como comentário NA LINHA ou NA LINHA IMEDIATAMENTE ACIMA
#   (onde cabe explicar por quê), ou caminho em .sqlscanignore.
#   Antes de suprimir, pergunte: esse valor vem de allowlist do seu código, ou do usuário?
#   Só o primeiro caso justifica a supressão.
#
# LIMITE CONHECIDO
#   A varredura é por linha. Uma consulta montada em várias linhas, ou por uma função
#   auxiliar, pode escapar. Uma varredura limpa é necessária, não suficiente — leia o
#   seu próprio diff.

set -uo pipefail

RED=$'\033[0;31m'; YEL=$'\033[0;33m'; GRN=$'\033[0;32m'; DIM=$'\033[2m'; NC=$'\033[0m'
[ -t 1 ] || { RED=""; YEL=""; GRN=""; DIM=""; NC=""; }

MARCADOR='scan-sql:allow'
ACHADOS=0
SQLKW='SELECT|INSERT|UPDATE|DELETE|REPLACE|WHERE|FROM|INTO|VALUES|ORDER[[:space:]]+BY|GROUP[[:space:]]+BY|HAVING|LIMIT|JOIN|SET|DROP|TRUNCATE|ALTER'

# nome|severidade|regex|linguagens
PADROES=(
  # ── PHP ───────────────────────────────────────────────────────────────────────
  "Variável interpolada em string SQL (aspas duplas)|ALTA|\"[^\"]*($SQLKW)[^\"]*(\\\$[a-zA-Z_]|\{\\\$)|php"
  "SQL concatenado com variável|ALTA|['\"][^'\"]*($SQLKW)[^'\"]*['\"][[:space:]]*\.[[:space:]]*\\\$|php"
  "Variável concatenada antes de SQL|ALTA|\\\$[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\.[[:space:]]*['\"][^'\"]*($SQLKW)|php"
  "Concatenação acumulada em variável de query|ALTA|\\\$(sql|query|consulta|q|where|stmt)[a-zA-Z0-9_]*[[:space:]]*\.=|php"
  "Função de banco removida do PHP|ALTA|\bmysql_(query|connect|real_escape_string)[[:space:]]*\(|php"
  "Escape manual usado como defesa contra injeção|MEDIA|\b(mysqli_real_escape_string|addslashes|real_escape_string)[[:space:]]*\(|php"
  "Emulação de prepared statements LIGADA|ALTA|ATTR_EMULATE_PREPARES[[:space:]]*=>[[:space:]]*true|php"
  "Modo de erro do PDO silencioso|MEDIA|ATTR_ERRMODE[[:space:]]*=>[[:space:]]*PDO::ERRMODE_(SILENT|WARNING)|php"

  # ── JavaScript / TypeScript ───────────────────────────────────────────────────
  "Método 'unsafe'/'raw' de acesso a banco|ALTA|(\\\$queryRawUnsafe|\\\$executeRawUnsafe|sql\.unsafe|sql\.raw|knex\.raw|sequelize\.query)[[:space:]]*\(|js"
  "Template literal com SQL e \${} fora de tag parametrizada|ALTA|[^a-zA-Z0-9_\$]\`[^\`]*($SQLKW)[^\`]*\\\$\{|js"
  "Query montada por concatenação de string|ALTA|['\"][^'\"]*($SQLKW)[^'\"]*['\"][[:space:]]*\+[[:space:]]*[a-zA-Z_\$]|js"
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
    *.php|*.phtml|*.php.template) echo php ;;
    *.js|*.jsx|*.ts|*.tsx|*.mjs|*.cjs|*.ts.template) echo js ;;
    *) echo outro ;;
  esac
}

varrer_arquivo() {
  local f="$1" lang entrada nome resto sev re alvo linha num texto anterior
  [ -f "$f" ] || return 0
  caminho_ignorado "$f" && return 0
  case "$f" in */node_modules/*|*/vendor/*|*/.git/*) return 0 ;; esac

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
      case "$texto" in
        *"$MARCADOR"*) continue ;;
        # Linhas de comentário costumam ser exemplo do que NÃO fazer.
        [[:space:]]*"//"*|[[:space:]]*"#"*|[[:space:]]*"*"*|[[:space:]]*"--"*) continue ;;
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
    < <(find . -type f \( -name '*.php' -o -name '*.js' -o -name '*.ts' -o -name '*.tsx' -o -name '*.jsx' \) \
        -not -path '*/node_modules/*' -not -path '*/vendor/*' -not -path '*/.git/*')
fi

# ── Verificação estrutural: PDO sem EMULATE_PREPARES => false ──────────────────
if ls ./*.php >/dev/null 2>&1 || [ -d app ] || [ -d src ]; then
  usa_pdo="$(grep -rlE 'new[[:space:]]+PDO[[:space:]]*\(' --include='*.php' . 2>/dev/null \
             | grep -v node_modules | grep -v vendor || true)"
  if [ -n "$usa_pdo" ]; then
    if ! grep -rqE 'ATTR_EMULATE_PREPARES[[:space:]]*=>[[:space:]]*false' --include='*.php' . 2>/dev/null; then
      echo "${RED}[ALTA]${NC} Existe 'new PDO(' no projeto, mas nenhum 'ATTR_EMULATE_PREPARES => false'."
      printf '      %s\n' $usa_pdo
      echo "      O padrão do PDO é emulação LIGADA: o PHP monta a query interpolando os"
      echo "      parâmetros e reabre superfície de injeção. Desligue na fábrica de conexão."
      echo
      ACHADOS=$((ACHADOS + 1))
    fi
  fi
fi

if [ "$ACHADOS" -eq 0 ]; then
  echo "${GRN}✅ Limpo — nenhum SQL concatenado detectado.${NC}"
  echo "${DIM}   A varredura é por linha: consulta montada em várias linhas pode escapar."
  echo "   Leia o seu próprio diff.${NC}"
  exit 0
fi

echo "${RED}❌ $ACHADOS achado(s). NÃO FAÇA COMMIT.${NC}"
echo
echo "Como corrigir:"
echo "  • Dado do usuário → parâmetro vinculado:  \$stmt = \$pdo->prepare('… = :x'); \$stmt->execute([':x' => \$v]);"
echo "  • Nome de coluna/tabela/direção → allowlist (mapa no seu código), nunca a entrada crua."
echo "    Identificador NÃO pode ser parametrizado: resolva por allowlist e declare a exceção"
echo "    na própria linha com '${MARCADOR} — <nome da allowlist>'. Sem marcador, o commit para."
echo "  • LIMIT/OFFSET → (int) com teto, vinculados como PDO::PARAM_INT."
echo "  • Em JS/TS → sql\`… \${v} …\` (template tag parametrizada), nunca sql(\`…\${v}…\`)."
echo "  • Detalhes: references/sql-e-acesso-a-dados.md"
echo
echo "${DIM}Falso positivo? Marcador '${MARCADOR}' na linha, ou caminho em .sqlscanignore.${NC}"
exit 1
