#!/bin/bash
# release.sh — Versionamento automático + Changelog + GitHub Release
# Uso: ./.githooks/scripts/release.sh [--dry-run]
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
DRY_RUN=false; [[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true
log()  { echo -e "${CYAN}[release]${NC} $*"; }
ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
die()  { echo -e "${RED}✗ ERRO:${NC} $*"; exit 1; }

command -v git >/dev/null 2>&1 || die "git não encontrado."
command -v gh  >/dev/null 2>&1 || die "gh não encontrado."
BRANCH=$(git rev-parse --abbrev-ref HEAD)
[[ "$BRANCH" == "main" ]] || die "Execute a partir da branch main. Branch atual: $BRANCH"
git fetch --tags --quiet && git pull origin main --quiet

LAST_TAG=$(git tag --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -n1 || true)
[[ -z "$LAST_TAG" ]] && { LAST_TAG="v0.0.0"; COMMITS=$(git log --pretty=format:"%s||%h||%ad" --date=short); } \
                     || COMMITS=$(git log "${LAST_TAG}..HEAD" --pretty=format:"%s||%h||%ad" --date=short)
[[ -z "$COMMITS" ]] && { warn "Nenhum commit novo desde $LAST_TAG."; exit 0; }

IFS='.' read -r V_MAJOR V_MINOR V_PATCH <<< "${LAST_TAG#v}"; BUMP="patch"
while IFS= read -r line; do
  MSG=$(echo "$line" | cut -d'|' -f1)
  if echo "$MSG" | grep -qiP "BREAKING CHANGE|^(\X{1,3}\s*)?!:"; then BUMP="major"; break
  elif echo "$MSG" | grep -qP "^(\X{1,3}\s*)?feat(\(.+\))?:"; then BUMP="minor"; fi
done <<< "$COMMITS"
case "$BUMP" in major) V_MAJOR=$((V_MAJOR+1)); V_MINOR=0; V_PATCH=0 ;;
                 minor) V_MINOR=$((V_MINOR+1)); V_PATCH=0 ;;
                 patch) V_PATCH=$((V_PATCH+1)) ;; esac
NEW_TAG="v${V_MAJOR}.${V_MINOR}.${V_PATCH}"; TODAY=$(date +%Y-%m-%d)
log "Próxima versão: ${BOLD}${GREEN}$NEW_TAG${NC} (bump: $BUMP)"

feats=""; fixes=""; chores=""; others=""
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  msg=$(echo "$line"|awk -F'\\|\\|' '{print $1}'); hash=$(echo "$line"|awk -F'\\|\\|' '{print $2}'); dt=$(echo "$line"|awk -F'\\|\\|' '{print $3}')
  entry="- ${msg} (\`${hash}\`) _${dt}_"
  if echo "$msg"|grep -qP "^(\X{1,3}\s*)?feat(\(.+\))?:";    then feats="${feats}\n${entry}"
  elif echo "$msg"|grep -qP "^(\X{1,3}\s*)?fix(\(.+\))?:";   then fixes="${fixes}\n${entry}"
  elif echo "$msg"|grep -qP "^(\X{1,3}\s*)?chore(\(.+\))?:"; then chores="${chores}\n${entry}"
  else others="${others}\n${entry}"; fi
done <<< "$COMMITS"

NEW_BLOCK=$(
  echo "## [$NEW_TAG] — $TODAY"; echo ""
  [[ -n "$feats" ]]  && { echo "### Novidades";  echo -e "$feats";  echo ""; }
  [[ -n "$fixes" ]]  && { echo "### Correções";  echo -e "$fixes";  echo ""; }
  [[ -n "$chores" ]] && { echo "### Manutenção"; echo -e "$chores"; echo ""; }
  [[ -n "$others" ]] && { echo "### Outros";     echo -e "$others"; echo ""; }
)

CHANGELOG="CHANGELOG.md"
[[ ! -f "$CHANGELOG" ]] && printf '# Changelog\n\nTodas as mudanças notáveis neste projeto serão documentadas aqui.\n\n---\n\n' > "$CHANGELOG"
HEADER_END=$(grep -n "^---$" "$CHANGELOG" | head -n1 | cut -d: -f1)
if [[ -n "$HEADER_END" ]]; then
  { head -n "$HEADER_END" "$CHANGELOG"; echo ""; echo "$NEW_BLOCK"; tail -n +"$((HEADER_END+1))" "$CHANGELOG"; } > "${CHANGELOG}.tmp" && mv "${CHANGELOG}.tmp" "$CHANGELOG"
else
  { echo ""; echo "$NEW_BLOCK"; } >> "$CHANGELOG"
fi
ok "CHANGELOG.md atualizado."

echo ""; echo -e "${BOLD}====== NOVO BLOCO ======${NC}"; echo "$NEW_BLOCK"; echo -e "${BOLD}========================${NC}"; echo ""
[[ "$DRY_RUN" == true ]] && { warn "Dry-run: nenhuma ação criada."; exit 0; }
read -rp "$(echo -e "${YELLOW}Confirmar release ${BOLD}$NEW_TAG${NC}${YELLOW}? [s/N]: ${NC}")" CONFIRM
[[ "$CONFIRM" =~ ^[sS]$ ]] || { warn "Cancelado."; exit 0; }
git add "$CHANGELOG" && git commit -m "chore(release): $NEW_TAG"
git tag -a "$NEW_TAG" -m "Release $NEW_TAG"
git push origin main && git push origin "$NEW_TAG"
gh release create "$NEW_TAG" --title "Release $NEW_TAG" --notes "$NEW_BLOCK" --latest
ok "GitHub Release ${BOLD}$NEW_TAG${NC} criada!"
