#!/bin/bash
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# ── 1. Packages ────────────────────────────────────────────────────────────────
yum update -y
yum install -y git

# ── 2. k3s ─────────────────────────────────────────────────────────────────────
curl -sfL https://get.k3s.io | sh -
# Attendre que k3s soit prêt
until kubectl get nodes 2>/dev/null | grep -q Ready; do sleep 3; done

# ── 3. Helm ────────────────────────────────────────────────────────────────────
curl -fsSL -o /tmp/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 /tmp/get_helm.sh
/tmp/get_helm.sh

# ── 4. cert-manager ────────────────────────────────────────────────────────────
helm install cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true

# ── 5. ClusterIssuer Let's Encrypt ─────────────────────────────────────────────
kubectl wait deployment --for=condition=Available -n cert-manager --timeout=360s cert-manager-webhook cert-manager
cat <<'EOF' | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: toris.maxime@gmail.com
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
    - http01:
        ingress:
          ingressClassName: traefik
EOF

# ── 6. ArgoCD ──────────────────────────────────────────────────────────────────
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --version 7.8.23 \
  --set server.service.type=ClusterIP
kubectl wait deployment --for=condition=Available -n argocd --timeout=360s argocd-server
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
data:
  password: Z2xwYXQtNXNUYkxhX0w3SElHYjFmWHNSTkgwVzg2TVFwMU9qRTJlREUyQ3cuMDEuMTIxOXh3eTBr
  type: Z2l0
  url: aHR0cHM6Ly9naXRsYWIuY29tL010b3Jpcw==
  username: TXRvcmlz
kind: Secret
metadata:
  name: gitlab-com-repo-creds
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repo-creds
type: Opaque
EOF
# Mode insecure (TLS géré par traefik)
kubectl patch configmap argocd-cmd-params-cm -n argocd \
  --type merge -p '{"data":{"server.insecure":"true"}}'
kubectl rollout restart deployment argocd-server -n argocd

cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - argocd.staging.maxto-platform.cloud
    secretName: argocd-server-tls
  rules:
  - host: argocd.staging.maxto-platform.cloud
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 80
EOF
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: lab-platform
  namespace: argocd
spec:
  clusterResourceWhitelist:
  - group: '*'
    kind: '*'
  description: Projet GitOps - Lab Plateforme DevSecOps - Staging
  destinations:
  - namespace: '*'
    server: https://kubernetes.default.svc
  namespaceResourceWhitelist:
  - group: '*'
    kind: '*'
  orphanedResources:
    warn: true
  sourceRepos:
  - '*'
EOF
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: lab-platform
  source:
    repoURL: https://gitlab.com/Mtoris/platform-config.git
    targetRevision: staging
    path: argocd/apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

# ── 7. App-demo pull secret ─────────────────────────────────────────────────
kubectl create namespace app-demo
kubectl create secret docker-registry regcred -n app-demo \
  --docker-server=registry.gitlab.com \
  --docker-username=gitlab+deploy-token-13197591 \
  --docker-password=gldt-hfus_eiVfGgTYT1VX9s-


# ── 9. Datadog ─────────────────────────────────────────────────────────────────
helm repo add datadog https://helm.datadoghq.com
helm repo update
helm install datadog-agent datadog/datadog \
  --namespace monitoring \
  --create-namespace \
  --set datadog.apiKey=64ae47920b57f576efdd49883f611e33 \
  --set datadog.site=datadoghq.eu

echo "=== Installation terminée ==="
echo "ArgoCD password: $(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)"
echo "DefectDojo password: $(kubectl get secret defectdojo --namespace=defectdojo --output jsonpath='{.data.DD_ADMIN_PASSWORD}' | base64 --decode)"
