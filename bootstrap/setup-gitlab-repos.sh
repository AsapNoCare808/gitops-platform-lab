#!/bin/bash
# =============================================================================
# Création des groupes et repos GitLab via API
# À lancer APRÈS que GitLab soit accessible
# Usage : GITLAB_TOKEN=glpat-xxx bash setup-gitlab-repos.sh
# =============================================================================
set -euo pipefail

GITLAB_URL="https://gitlab.maxto-platform.cloud"
TOKEN="${GITLAB_TOKEN:?'Variable GITLAB_TOKEN manquante. Ex: export GITLAB_TOKEN=glpat-xxx'}"
GROUP_NAME="platform"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

api() {
  curl -sf --header "PRIVATE-TOKEN: ${TOKEN}" \
    --header "Content-Type: application/json" \
    "${GITLAB_URL}/api/v4/$1" "${@:2}"
}

# =============================================================================
# 1. Créer le groupe "platform"
# =============================================================================
info "Création du groupe '${GROUP_NAME}'..."
GROUP_ID=$(api "groups" \
  --data "{\"name\":\"${GROUP_NAME}\",\"path\":\"${GROUP_NAME}\",\"visibility\":\"private\"}" \
  2>/dev/null | jq -r '.id' || true)

if [[ -z "$GROUP_ID" || "$GROUP_ID" == "null" ]]; then
  warn "Groupe déjà existant, récupération de l'ID..."
  GROUP_ID=$(api "groups?search=${GROUP_NAME}" | jq -r '.[0].id')
fi
info "Groupe ID : ${GROUP_ID}"

# =============================================================================
# 2. Créer les 3 projets
# =============================================================================
for REPO in platform-config infra-k8s app-demo; do
  info "Création du projet '${REPO}'..."
  PROJECT_ID=$(api "projects" \
    --data "{\"name\":\"${REPO}\",\"path\":\"${REPO}\",\"namespace_id\":${GROUP_ID},\"visibility\":\"private\",\"initialize_with_readme\":false,\"default_branch\":\"main\"}" \
    2>/dev/null | jq -r '.id' || true)

  if [[ -z "$PROJECT_ID" || "$PROJECT_ID" == "null" ]]; then
    warn "Projet ${REPO} déjà existant, skip."
  else
    info "Projet '${REPO}' créé (ID: ${PROJECT_ID})"
  fi
done

# =============================================================================
# 3. Créer le token de déploiement pour le pipeline CI (infra-k8s)
# =============================================================================
info "Création du token de déploiement 'ci-bot' pour infra-k8s..."
INFRA_PROJECT_ID=$(api "groups/${GROUP_ID}/projects?search=infra-k8s" | jq -r '.[0].id')
DEPLOY_TOKEN=$(api "projects/${INFRA_PROJECT_ID}/deploy_tokens" \
  --data '{"name":"ci-bot","scopes":["read_repository","write_repository"]}' \
  2>/dev/null | jq -r '.token' || echo "ALREADY_EXISTS")

if [[ "$DEPLOY_TOKEN" != "ALREADY_EXISTS" && -n "$DEPLOY_TOKEN" ]]; then
  echo ""
  echo "============================================================"
  echo " IMPORTANT — Token CI à sauvegarder maintenant !"
  echo " Variable GitLab CI à créer : INFRA_DEPLOY_TOKEN"
  echo " Valeur : ${DEPLOY_TOKEN}"
  echo "============================================================"
  echo ""
fi

# =============================================================================
# 4. Push du code local vers GitLab
# =============================================================================
info "Push des repos locaux vers GitLab..."
REPO_BASE="/Users/maxto/aws-banking-platform"

for REPO in platform-config infra-k8s app-demo; do
  LOCAL_PATH="${REPO_BASE}/${REPO}"
  REMOTE_URL="https://oauth2:${TOKEN}@gitlab.maxto-platform.cloud/platform/${REPO}.git"

  if [[ ! -d "${LOCAL_PATH}/.git" ]]; then
    info "Init git pour ${REPO}..."
    git -C "${LOCAL_PATH}" init
    git -C "${LOCAL_PATH}" checkout -b main
  fi

  git -C "${LOCAL_PATH}" add -A
  git -C "${LOCAL_PATH}" diff --cached --quiet || \
    git -C "${LOCAL_PATH}" commit -m "feat: initialisation du repo ${REPO}"

  git -C "${LOCAL_PATH}" remote remove origin 2>/dev/null || true
  git -C "${LOCAL_PATH}" remote add origin "${REMOTE_URL}"
  git -C "${LOCAL_PATH}" push -u origin main --force

  info "✓ ${REPO} poussé sur GitLab"
done

echo ""
echo "============================================================"
echo " Setup terminé !"
echo " GitLab  : ${GITLAB_URL}/platform"
echo " Repos   : platform-config | infra-k8s | app-demo"
echo "============================================================"
