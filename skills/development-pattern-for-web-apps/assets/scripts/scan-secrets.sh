#!/usr/bin/env bash
# scan-secrets.sh: varredura de segredos e dados sensíveis.
#
# Parte de "Development Pattern for Web Apps".
# Impõe a regra R1: nada sensível chega ao repositório.
#
# USO
#   bash scan-secrets.sh                  # varre a árvore de trabalho (respeita .gitignore)
#   bash scan-secrets.sh caminho/arquivo  # varre caminhos específicos
#   git diff --cached | bash scan-secrets.sh --stdin    # varre o conteúdo STAGED
#
# SAÍDA
#   0  limpo
#   1  achados, NÃO FAÇA COMMIT
#
# FALSO POSITIVO
#   Acrescente o marcador  scan-secrets:allow  como comentário na linha ou na linha
#   imediatamente acima,
#   ou liste o caminho (um por linha, comparação por substring) em .secretscanignore.
#   Suprima com parcimônia: cada supressão é um furo na rede.

set -uo pipefail

RED=$'\033[0;31m'; YEL=$'\033[0;33m'; GRN=$'\033[0;32m'; DIM=$'\033[2m'; NC=$'\033[0m'
[ -t 1 ] || { RED=""; YEL=""; GRN=""; DIM=""; NC=""; }

MARCADOR='scan-secrets:allow'
ACHADOS=0

# ── Padrões ─────────────────────────────────────────────────────────────────────
# nome|severidade|regex-estendida
PADROES=(
  "Chave privada|ALTA|-----BEGIN ([A-Z ]+ )?PRIVATE KEY-----"
  "String de conexão com credencial|ALTA|(mysql|mysqli|postgres|postgresql|mongodb(\+srv)?|redis|amqp|ftp|sftp)://[A-Za-z0-9._%+-]+:[^@[:space:]\"']{4,}@"
  "Credencial embutida no código|ALTA|(senha|password|passwd|pwd|secret|api_?key|apikey|client_secret|access_key|auth_token|private_key|db_pass[a-z]*)[\"']?[[:space:]]*(=>|=|:|,)[[:space:]]*[\"'][^\"']{8,}[\"']"
  "Variável de ambiente com valor|ALTA|^[[:space:]]*(DB_PASSWORD|DB_PASS|DB_USER|DATABASE_URL|AUTH_SECRET|NEXTAUTH_SECRET|JWT_SECRET|APP_KEY|SESSION_SECRET|SMTP_PASSWORD|MAIL_PASSWORD)[[:space:]]*=[[:space:]]*[\"']?[^[:space:]\"'#]{8,}"
  "Chave AWS|ALTA|\b(AKIA|ASIA)[0-9A-Z]{16}\b"
  "Chave Stripe (produção)|ALTA|\b(sk|rk)_live_[0-9A-Za-z]{16,}"
  "Token do GitHub|ALTA|\b(ghp|gho|ghu|ghs|ghr)_[0-9A-Za-z]{30,}|\bgithub_pat_[0-9A-Za-z_]{30,}"
  "Chave OpenAI/Anthropic|ALTA|\bsk-(ant-)?[A-Za-z0-9_-]{24,}"
  "Chave Google API|ALTA|\bAIza[0-9A-Za-z_-]{35}\b"
  "Chave SendGrid|ALTA|\bSG\.[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}"
  "Chave Resend|ALTA|\bre_[A-Za-z0-9_]{20,}"
  "Token Mercado Pago|ALTA|\bAPP_USR-[0-9a-zA-Z-]{20,}"
  "Token Vercel/Netlify|ALTA|\b(vercel|netlify)_[A-Za-z0-9]{24,}"
  "JWT com payload legível|ALTA|\beyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}"
  "Bearer literal|ALTA|[Bb]earer[[:space:]]+[A-Za-z0-9._-]{25,}"
  "Segredo em variável NEXT_PUBLIC_|ALTA|NEXT_PUBLIC_[A-Z0-9_]*(SECRET|PASSWORD|TOKEN|PRIVATE|DATABASE|DB_)"
  "Endereço de e-mail|MEDIA|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"
  "CPF|MEDIA|\b[0-9]{3}\.[0-9]{3}\.[0-9]{3}-[0-9]{2}\b"
  "CNPJ|MEDIA|\b[0-9]{2}\.[0-9]{3}\.[0-9]{3}/[0-9]{4}-[0-9]{2}\b"
  "Telefone brasileiro|BAIXA|\([0-9]{2}\)[[:space:]]?9?[0-9]{4}-[0-9]{4}"
  "IPv4 privado|BAIXA|\b(10\.[0-9]{1,3}|192\.168|172\.(1[6-9]|2[0-9]|3[01]))\.[0-9]{1,3}\.[0-9]{1,3}\b"
)

# Placeholders e valores notoriamente seguros que nunca devem ser reportados.
SEGUROS='SEU-|SUA-|SEUS-|GERE-|GERE_|TROQUE|CHANGEME|COLOQUE|PREENCHA|placeholder|PLACEHOLDER|example\.com|example\.org|example\.net|exemplo\.com|seu-dominio|localhost|127\.0\.0\.1|0\.0\.0\.0|::1|10\.0\.0\.0|172\.16\.0\.0|192\.168\.0\.0|127\.0\.0\.0|169\.254\.169\.254|noreply@|nao-responda@|@example\.|git@github\.com|git@gitlab\.com|senha-de-teste|sk_test_|pk_test_|000\.000\.000-00|00\.000\.000/0000-00|\(00\)|xxxx|XXXX|<[a-z-]+>|\$[a-zA-Z_]|\{\{|process\.env\.|getenv\(|env\(|\.\.\.|abcdef|123456'

# ── Auxiliares ──────────────────────────────────────────────────────────────────
caminho_ignorado() {
  local f="$1" raiz ignore
  raiz="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
  ignore="$raiz/.secretscanignore"
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
  [ "$sev" = ALTA ]  && cor="$RED"
  [ "$sev" = BAIXA ] && cor="$DIM"
  printf '%s[%s]%s %s\n      %s:%s\n      %s%s%s\n\n' \
    "$cor" "$sev" "$NC" "$4" "$1" "$2" "$DIM" "${5:0:160}" "$NC"
  ACHADOS=$((ACHADOS + 1))
}

# Um grep por padrão sobre o arquivo inteiro. A variante por linha cria dezenas de
# milhares de processos e leva minutos mesmo em repositório pequeno.
varrer_buffer() { # caminho rotulo
  local caminho="$1" rotulo="$2" entrada nome resto sev re linha num texto trecho achou anterior
  for entrada in "${PADROES[@]}"; do
    nome="${entrada%%|*}"; resto="${entrada#*|}"
    sev="${resto%%|*}";    re="${resto#*|}"
    while IFS= read -r linha; do
      [ -z "$linha" ] && continue
      num="${linha%%:*}"; texto="${linha#*:}"
      case "$texto" in *"$MARCADOR"*) continue ;; esac
      # O marcador vale também na linha imediatamente acima, onde cabe a justificativa.
      if [ "$num" -gt 1 ]; then
        anterior="$(sed -n "$((num - 1))p" "$caminho" 2>/dev/null || true)"
        case "$anterior" in *"$MARCADOR"*) continue ;; esac
      fi
      # Cada TRECHO casado é conferido contra a allowlist, não a linha inteira:
      # senão um placeholder na linha mascararia um segredo real ao lado dele.
      achou=0
      while IFS= read -r trecho; do
        [ -z "$trecho" ] && continue
        printf '%s' "$trecho" | grep -qiE -- "$SEGUROS" && continue
        achou=1
      done < <(printf '%s' "$texto" | grep -oiE -- "$re" 2>/dev/null || true)
      [ "$achou" -eq 1 ] && reportar "$rotulo" "$num" "$sev" "$nome" "$texto"
    done < <(grep -niE -- "$re" "$caminho" 2>/dev/null || true)
  done
}

varrer_arquivo() {
  local f="$1"
  [ -f "$f" ] || return 0
  caminho_ignorado "$f" && return 0
  case "$f" in
    *.png|*.jpg|*.jpeg|*.gif|*.ico|*.webp|*.woff|*.woff2|*.ttf|*.pdf|*.zip|*.tgz|*.gz) return 0 ;;
    */package-lock.json|package-lock.json|*/composer.lock|composer.lock|*/node_modules/*|*/vendor/*) return 0 ;;
  esac
  grep -Iq . "$f" 2>/dev/null || return 0
  varrer_buffer "$f" "$f"
}

# ── Principal ───────────────────────────────────────────────────────────────────
echo "🔍 Procurando segredos e dados sensíveis…"
echo

if [ "${1:-}" = "--stdin" ]; then
  tmp="$(mktemp)"; cat > "$tmp"; varrer_buffer "$tmp" "(diff staged)"; rm -f "$tmp"
elif [ "$#" -gt 0 ]; then
  for f in "$@"; do varrer_arquivo "$f"; done
elif git rev-parse --git-dir >/dev/null 2>&1; then
  while IFS= read -r f; do varrer_arquivo "$f"; done \
    < <(git ls-files --cached --others --exclude-standard)
else
  while IFS= read -r f; do varrer_arquivo "$f"; done \
    < <(find . -type f -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/vendor/*')
fi

# ── Verificações estruturais (só em repositório git) ────────────────────────────
if git rev-parse --git-dir >/dev/null 2>&1; then
  rastreados="$(git ls-files | grep -Ei \
    '(^|/)\.env($|\.)|config\.local\.php|app\.config\.php|\.pem$|\.key$|\.p12$|\.ppk$|ftpconfig|sftp\.json|(^|/)(dumps?|backups?)/' \
    || true)"
  if [ -n "$rastreados" ]; then
    echo "${RED}[ALTA]${NC} Arquivos sensíveis RASTREADOS pelo git:"
    printf '      %s\n' $rastreados
    echo "      Corrija: git rm --cached <arquivo> , e ROTACIONE toda credencial que ele continha."
    echo
    ACHADOS=$((ACHADOS + 1))
  fi

  dumps="$(git ls-files '*.sql' | grep -vE '(schema|migrations?|seeds?)/' || true)"
  if [ -n "$dumps" ]; then
    echo "${YEL}[MEDIA]${NC} Arquivos .sql rastreados fora de schema/migrations/seeds:"
    printf '      %s\n' $dumps
    echo "      Um dump de banco no repositório é vazamento de dado pessoal, não arquivo de apoio."
    echo
    ACHADOS=$((ACHADOS + 1))
  fi

  for alvo in .env .env.local config/app.config.php config/config.local.php; do
    if [ -e "$alvo" ] && ! git check-ignore -q "$alvo" 2>/dev/null; then
      echo "${YEL}[MEDIA]${NC} '$alvo' existe mas não está no .gitignore."
      echo
      ACHADOS=$((ACHADOS + 1))
    fi
  done

  if [ -e .env ] && [ ! -e .env.example ]; then
    echo "${DIM}[BAIXA]${NC} Existe .env mas não existe .env.example."
    echo "      Sem ele, ninguém (nem você em três meses) sabe quais chaves configurar."
    echo
    ACHADOS=$((ACHADOS + 1))
  fi
fi

# ── Veredito ────────────────────────────────────────────────────────────────────
if [ "$ACHADOS" -eq 0 ]; then
  echo "${GRN}✅ Limpo: nenhum segredo ou dado sensível detectado.${NC}"
  echo "${DIM}   Varredura limpa é necessária, não suficiente. Leia o seu próprio diff.${NC}"
  exit 0
fi

echo "${RED}❌ $ACHADOS achado(s). NÃO FAÇA COMMIT.${NC}"
echo
echo "Próximos passos:"
echo "  1. Troque o valor real por um placeholder óbvio (SEU-USUARIO, SUA-SENHA)."
echo "  2. Mova o valor real para .env (ignorado) ou para o painel da Vercel."
echo "  3. Rode a varredura de novo."
echo "  4. Se a credencial já foi commitada ou enviada: ROTACIONE. Limpar o histórico não basta."
echo
echo "${DIM}Falso positivo? Use o comentário '${MARCADOR}' na linha, ou liste o caminho em .secretscanignore.${NC}"
exit 1
