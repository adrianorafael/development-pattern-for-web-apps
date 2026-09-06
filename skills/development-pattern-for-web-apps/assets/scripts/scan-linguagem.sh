#!/usr/bin/env bash
# scan-linguagem.sh: procura travessão e outros vícios que entregam texto gerado por IA.
#
# Parte de "Development Pattern for Web Apps".
# Impõe a regra R17: o texto é escrito na língua de quem usa e nunca entrega que foi gerado.
#
# USO
#   bash scan-linguagem.sh                  # varre a árvore de trabalho
#   bash scan-linguagem.sh arquivo.tsx ...  # varre caminhos específicos
#
# SAÍDA
#   0  limpo
#   1  achados
#
# FALSO POSITIVO
#   Marcador  scan-linguagem:allow  na linha ou na linha imediatamente acima,
#   ou caminho em .linguagemscanignore.
#
#   Em arquivos .md, travessão DENTRO de crases é ignorado automaticamente: ali ele está
#   sendo citado, não usado. É o que permite documentar a própria proibição.
#
# LIMITE CONHECIDO
#   Os vícios de linguagem são heurística, não gramática. A lista pega as muletas mais
#   comuns; ela não julga se o texto está bom. Leia o que você escreveu.

set -uo pipefail

RED=$'\033[0;31m'; YEL=$'\033[0;33m'; GRN=$'\033[0;32m'; DIM=$'\033[2m'; NC=$'\033[0m'
[ -t 1 ] || { RED=""; YEL=""; GRN=""; DIM=""; NC=""; }

MARCADOR='scan-linguagem:allow'
ACHADOS=0

# Muletas que, juntas, viram carimbo de texto gerado. Comparação sem diferenciar caixa.
VICIOS=(
  "Além disso,"
  "Vale ressaltar"
  "Vale a pena ressaltar"
  "Vale destacar"
  "É importante notar"
  "É importante ressaltar"
  "Cabe ressaltar"
  "No mundo de hoje"
  "No cenário atual"
  "cada vez mais digital"
  "Em um mundo"
  "Mergulhe"
  "Desbloqueie"
  "Revolucione"
  "Eleve sua experiência"
  "Eleve o seu"
  "sem emenda"
  "solução robusta"
  "poderosa ferramenta"
  "ferramenta poderosa"
  "experiência perfeita"
  "Não apenas X"
  "não apenas isso"
  "Prepare-se para"
  "Descubra o poder"
  "leve o seu"
  "de forma intuitiva"
  "totalmente intuitiva"
)

caminho_ignorado() {
  local f="$1" raiz ignore linha
  raiz="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
  ignore="$raiz/.linguagemscanignore"
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

# O marcador vale na própria linha ou na linha imediatamente acima, onde cabe a justificativa.
liberado() { # arquivo numero texto
  case "$3" in *"$MARCADOR"*) return 0 ;; esac
  if [ "$2" -gt 1 ]; then
    local anterior
    anterior="$(sed -n "$(($2 - 1))p" "$1" 2>/dev/null || true)"
    case "$anterior" in *"$MARCADOR"*) return 0 ;; esac
  fi
  return 1
}

varrer_arquivo() {
  local f="$1" ehmd=0 linha num texto texto_limpo vicio
  [ -f "$f" ] || return 0
  caminho_ignorado "$f" && return 0
  case "$f" in
    */node_modules/*|*/vendor/*|*/.git/*|*/dist/*|*/.next/*) return 0 ;;
    *.md|*.markdown|*.html|*.htm|*.php|*.phtml|*.js|*.jsx|*.ts|*.tsx|*.txt|*.template) ;;
    *) return 0 ;;
  esac
  case "$f" in *.md|*.markdown|*.md.template) ehmd=1 ;; esac

  # ── Travessão e meia-risca ────────────────────────────────────────────────
  # grep -F casa a sequência UTF-8 inteira. Uma classe [—–] casaria BYTES isolados
  # e daria dezenas de falsos positivos em qualquer acento.
  while IFS= read -r linha; do
    [ -z "$linha" ] && continue
    num="${linha%%:*}"; texto="${linha#*:}"
    liberado "$f" "$num" "$texto" && continue

    texto_limpo="$texto"
    # Em Markdown, o que está entre crases está sendo CITADO, não usado.
    [ "$ehmd" -eq 1 ] && texto_limpo="$(printf '%s' "$texto" | sed 's/`[^`]*`//g')"
    printf '%s' "$texto_limpo" | grep -qF -e '—' -e '–' || continue

    reportar "$f" "$num" ALTA "Travessão em texto (R17: use vírgula, dois-pontos, parênteses ou ponto)" "$texto"
  done < <(grep -nF -e '—' -e '–' "$f" 2>/dev/null || true)

  # Em HTML o travessão também entra como entidade, e aí escapa da busca literal acima.
  while IFS= read -r linha; do
    [ -z "$linha" ] && continue
    num="${linha%%:*}"; texto="${linha#*:}"
    liberado "$f" "$num" "$texto" && continue
    reportar "$f" "$num" ALTA "Travessão como entidade HTML (R17)" "$texto"
  done < <(grep -niF -e '&mdash;' -e '&ndash;' -e '&#8212;' -e '&#8211;' -e '&#x2014;' -e '&#x2013;' "$f" 2>/dev/null || true)

  # ── Muletas de texto gerado ───────────────────────────────────────────────
  for vicio in "${VICIOS[@]}"; do
    while IFS= read -r linha; do
      [ -z "$linha" ] && continue
      num="${linha%%:*}"; texto="${linha#*:}"
      liberado "$f" "$num" "$texto" && continue

      # Mesma regra do travessão: em Markdown, o que está entre crases está sendo
      # CITADO como exemplo do que não fazer, não usado.
      texto_limpo="$texto"
      [ "$ehmd" -eq 1 ] && texto_limpo="$(printf '%s' "$texto" | sed 's/`[^`]*`//g')"
      printf '%s' "$texto_limpo" | grep -qiF -e "$vicio" || continue

      reportar "$f" "$num" MEDIA "Muleta de texto gerado: \"$vicio\"" "$texto"
    done < <(grep -niF -e "$vicio" "$f" 2>/dev/null || true)
  done
}

echo "✍️  Procurando travessões e vícios de texto gerado…"
echo

if [ "$#" -gt 0 ]; then
  for f in "$@"; do varrer_arquivo "$f"; done
elif git rev-parse --git-dir >/dev/null 2>&1; then
  while IFS= read -r f; do varrer_arquivo "$f"; done \
    < <(git ls-files --cached --others --exclude-standard)
else
  while IFS= read -r f; do varrer_arquivo "$f"; done \
    < <(find . -type f -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/vendor/*')
fi

if [ "$ACHADOS" -eq 0 ]; then
  echo "${GRN}✅ Limpo: nenhum travessão nem muleta detectada.${NC}"
  echo "${DIM}   O scanner pega padrões, não julga se o texto está bom. Leia o que escreveu.${NC}"
  exit 0
fi

echo "${RED}❌ $ACHADOS achado(s).${NC}"
echo
echo "Como corrigir o travessão:"
echo "  • Explica o que veio antes  → dois-pontos:  'O prazo é curto: três dias.'"
echo "  • Aposto no meio da frase   → vírgulas:     'A conta, que estava ativa, foi encerrada.'"
echo "  • Duas ideias independentes → dois períodos: 'Tente de novo. Se persistir, fale conosco.'"
echo "  • Rótulo e valor            → dois-pontos:  'Status: Aberto'"
echo "  • Célula de tabela vazia    → 'não se aplica'"
echo "  • Detalhes: references/linguagem-e-texto-da-interface.md"
echo
echo "${DIM}Falso positivo? Marcador '${MARCADOR}' na linha ou na anterior, ou caminho em .linguagemscanignore.${NC}"
exit 1
