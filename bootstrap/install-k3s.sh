#!/bin/bash
# =============================================================================
# Bootstrap k3s sur VPS Ionos (4vCPU / 8Go RAM)
# Stack : k3s + cert-manager + nginx-ingress + ArgoCD + GitLab CE
# =============================================================================
set -euo pipefail

# ---- Variables à adapter ----
DOMAIN="maxto-platform.cloud"
EMAIL="${EMAIL:-admin@maxto-platform.cloud}"      # pour Let's Encrypt
ARGOCD_VERSION="6.7.14"                  # helm chart version
GITLAB_VERSION="9.10.3"                  # helm chart version
CERTMANAGER_VERSION="1.14.4"

# ---- Couleurs ----
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# =============================================================================
# 1. Prérequis système
# =============================================================================
info "Mise à jour système..."
apt-get update -qq && apt-get upgrade -y -qq

info "Installation des dépendances..."
apt-get install -y -qq curl wget git unzip jq

# =============================================================================
# 2. Installation k3s (sans Traefik → on utilise nginx-ingress)
# =============================================================================
info "Installation k3s..."
if ! command -v k3s &>/dev/null; then
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
    --disable traefik \
    --disable servicelb \
    --write-kubeconfig-mode 644" sh -
  systemctl enable k3s
else
  warn "k3s déjà installé, skip."
fi

info "Attente que k3s soit prêt..."
until kubectl get nodes 2>/dev/null | grep -q "Ready"; do sleep 3; done
info "k3s opérationnel."

# Configurer kubeconfig pour l'utilisateur courant
mkdir -p ~/.kube
cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
chmod 600 ~/.kube/config
export KUBECONFIG=~/.kube/config

# =============================================================================
# 3. Installation Helm
# =============================================================================
info "Installation Helm..."
if ! command -v helm &>/dev/null; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
  warn "Helm déjà installé, skip."
fi

# =============================================================================
# 4. Namespaces
# =============================================================================
info "Création des namespaces..."
for ns in argocd gitlab cert-manager ingress-nginx monitoring app-demo; do
  kubectl get namespace "$ns" &>/dev/null || kubectl create namespace "$ns"
done

# =============================================================================
# 5. NGINX Ingress Controller
# =============================================================================
info "Installation nginx-ingress..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx --force-update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --set controller.hostPort.enabled=true \
  --set controller.service.type=ClusterIP \
  --set controller.resources.requests.memory=128Mi \
  --set controller.resources.requests.cpu=100m \
  --wait --timeout 5m

# =============================================================================
# 6. cert-manager (Let's Encrypt)
# =============================================================================
info "Installation cert-manager..."
helm repo add jetstack https://charts.jetstack.io --force-update
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version "v${CERTMANAGER_VERSION}" \
  --set installCRDs=true \
  --set resources.requests.memory=64Mi \
  --wait --timeout 5m

info "Création ClusterIssuer Let's Encrypt..."
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${EMAIL}
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

# =============================================================================
# 7. ArgoCD
# =============================================================================
info "Installation ArgoCD..."
helm repo add argo https://argoproj.github.io/argo-helm --force-update
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --version "${ARGOCD_VERSION}" \
  --set server.ingress.enabled=true \
  --set server.ingress.ingressClassName=nginx \
  --set "server.ingress.hosts[0]=argocd.${DOMAIN}" \
  --set "server.ingress.tls[0].secretName=argocd-tls" \
  --set "server.ingress.tls[0].hosts[0]=argocd.${DOMAIN}" \
  --set "server.ingress.annotations.cert-manager\\.io/cluster-issuer=letsencrypt-prod" \
  --set server.extraArgs[0]="--insecure" \
  --set configs.params."server\.insecure"=true \
  --set redis.resources.requests.memory=64Mi \
  --set server.resources.requests.memory=128Mi \
  --set repoServer.resources.requests.memory=128Mi \
  --set applicationSet.resources.requests.memory=64Mi \
  --wait --timeout 10m

ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
info "ArgoCD admin password : ${ARGOCD_PASSWORD}"
echo "${ARGOCD_PASSWORD}" > ~/argocd-admin-password.txt
chmod 600 ~/argocd-admin-password.txt

# =============================================================================
# 8. GitLab CE (configuration minimaliste pour 8Go RAM)
# =============================================================================
info "Installation GitLab CE (peut prendre 10-15 min)..."
helm repo add gitlab https://charts.gitlab.io --force-update
helm upgrade --install gitlab gitlab/gitlab \
  --namespace gitlab \
  --version "${GITLAB_VERSION}" \
  --timeout 20m \
  -f /root/gitlab-values.yaml \
  --wait

# =============================================================================
# 9. Résumé
# =============================================================================
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
echo ""
echo "============================================================"
echo " Installation terminée !"
echo "============================================================"
echo " ArgoCD  : https://argocd.${DOMAIN}"
echo " GitLab  : https://gitlab.${DOMAIN}"
echo " IP node : ${NODE_IP}"
echo " ArgoCD password : $(cat ~/argocd-admin-password.txt)"
echo "============================================================"
echo ""
warn "Étape suivante : appliquer le App of Apps ArgoCD"
warn "  kubectl apply -f platform-config/argocd/apps/app-of-apps.yaml -n argocd"
