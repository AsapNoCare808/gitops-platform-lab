#!/bin/bash
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# ── 1. Packages ────────────────────────────────────────────────────────────────
yum update -y
yum install -y git jq

# ── 2. k3s ─────────────────────────────────────────────────────────────────────
curl -sfL https://get.k3s.io | sh -
# Attendre que k3s soit prêt
until kubectl get nodes 2>/dev/null | grep -q Ready; do sleep 3; done

# ── 3. Helm ────────────────────────────────────────────────────────────────────
curl -fsSL -o /tmp/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 /tmp/get_helm.sh
/tmp/get_helm.sh

# ── 3b. Traefik redirect HTTP → HTTPS ──────────────────────────────────────────
until kubectl get crd middlewares.traefik.io 2>/dev/null; do sleep 5; done
cat <<'EOF' | kubectl apply -f -
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: redirect-https
  namespace: default
spec:
  redirectScheme:
    scheme: https
    permanent: true
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: http-catchall
  namespace: default
spec:
  entryPoints:
    - web
  routes:
    - match: PathPrefix(`/`)
      kind: Rule
      middlewares:
        - name: redirect-https
      services:
        - name: noop@internal
          kind: TraefikService
EOF

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

# ── 7. App-demo namespace ───────────────────────────────────────────────────
kubectl create namespace app-demo


# ── 8. Vault ───────────────────────────────────────────────────────────────────
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
helm install vault hashicorp/vault \
  --namespace vault \
  --create-namespace \
  --set injector.enabled=false \
  --set server.dataStorage.enabled=true \
  --set server.dataStorage.size=2Gi \
  --set server.ha.enabled=false \
  --set server.resources.limits.memory=256Mi \
  --set server.resources.requests.cpu=100m \
  --set server.resources.requests.memory=128Mi \
  --set server.ingress.enabled=true \
  --set server.ingress.ingressClassName=traefik \
  --set 'server.ingress.annotations.cert-manager\.io/cluster-issuer=letsencrypt-prod' \
  --set 'server.ingress.annotations.traefik\.ingress\.kubernetes\.io/router\.entrypoints=websecure' \
  --set 'server.ingress.hosts[0].host=vault.staging.maxto-platform.cloud' \
  --set 'server.ingress.hosts[0].paths[0]=/' \
  --set 'server.ingress.tls[0].hosts[0]=vault.staging.maxto-platform.cloud' \
  --set 'server.ingress.tls[0].secretName=vault-tls' \
  --set 'server.standalone.config=ui = true
listener "tcp" {
  tls_disable = 1
  address     = "[::]:8200"
  cluster_address = "[::]:8201"
}
storage "raft" {
  path    = "/vault/data"
  node_id = "vault-0"
}
service_registration "kubernetes" {}'

until kubectl get pod vault-0 -n vault 2>/dev/null | grep -q Running; do sleep 5; done

# Init Vault et unseal automatique
VAULT_INIT=$(kubectl exec -n vault vault-0 -- vault operator init -key-shares=1 -key-threshold=1 -format=json)
UNSEAL_KEY=$(echo "$VAULT_INIT" | jq -r '.unseal_keys_b64[0]')
ROOT_TOKEN=$(echo "$VAULT_INIT" | jq -r '.root_token')
kubectl exec -n vault vault-0 -- vault operator unseal -tls-skip-verify "$UNSEAL_KEY"

# Config Vault
kubectl exec -n vault vault-0 -- sh -c "VAULT_TOKEN=$ROOT_TOKEN vault auth enable kubernetes"
kubectl exec -n vault vault-0 -- sh -c "VAULT_TOKEN=$ROOT_TOKEN vault secrets enable -path=secret kv-v2"
kubectl exec -n vault vault-0 -- sh -c "VAULT_TOKEN=$ROOT_TOKEN vault write auth/kubernetes/config kubernetes_host=https://kubernetes.default.svc"
kubectl exec -n vault vault-0 -- sh -c "echo 'path \"secret/data/*\" { capabilities = [\"read\"] }' > /tmp/eso-policy.hcl && VAULT_TOKEN=$ROOT_TOKEN vault policy write eso-policy /tmp/eso-policy.hcl"
kubectl exec -n vault vault-0 -- sh -c "VAULT_TOKEN=$ROOT_TOKEN vault write auth/kubernetes/role/eso-role \
  bound_service_account_names=external-secrets \
  bound_service_account_namespaces=external-secrets \
  policies=eso-policy \
  ttl=1h"
kubectl exec -n vault vault-0 -- sh -c "VAULT_TOKEN=$ROOT_TOKEN vault kv put secret/gitlab-registry \
  username=gitlab+deploy-token-13197591 \
  password=gldt-hfus_eiVfGgTYT1VX9s-"

# ── 8b. ESO ─────────────────────────────────────────────────────────────────
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace

kubectl wait deployment --for=condition=Available -n external-secrets --timeout=120s \
  external-secrets external-secrets-webhook

cat <<'EOF' | kubectl apply -f -
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "http://vault.vault.svc.cluster.local:8200"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "eso-role"
          serviceAccountRef:
            name: "external-secrets"
            namespace: "external-secrets"
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: regcred
  namespace: app-demo
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: regcred
    template:
      type: kubernetes.io/dockerconfigjson
      data:
        .dockerconfigjson: |
          {"auths":{"registry.gitlab.com":{"username":"{{ .username }}","password":"{{ .password }}","auth":"{{ printf "%s:%s" .username .password | b64enc }}"}}}
  data:
  - secretKey: username
    remoteRef:
      key: secret/gitlab-registry
      property: username
  - secretKey: password
    remoteRef:
      key: secret/gitlab-registry
      property: password
EOF

# ── 9. DefectDojo ─────────────────────────────────────────────────────────────
git clone https://github.com/DefectDojo/django-DefectDojo /opt/django-DefectDojo
cd /opt/django-DefectDojo
helm dependency update ./helm/defectdojo
helm install defectdojo ./helm/defectdojo \
  --namespace defectdojo \
  --create-namespace \
  --set django.ingress.enabled=false \
  --set createSecret=true \
  --set createValkeySecret=true \
  --set createPostgresqlSecret=true \
  --set "host=defectdojo.staging.maxto-platform.cloud"

cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: defectdojo-django-ingress
  namespace: defectdojo
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - defectdojo.staging.maxto-platform.cloud
    secretName: defectdojo-django-tls
  rules:
  - host: defectdojo.staging.maxto-platform.cloud
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: defectdojo-django
            port:
              number: 80
EOF

# Attendre que DefectDojo soit prêt avant de récupérer le password
kubectl wait deployment -n defectdojo --for=condition=Available --timeout=600s defectdojo-django

DEFECTDOJO_PASSWORD=$(kubectl get secret defectdojo --namespace=defectdojo --output jsonpath='{.data.DD_ADMIN_PASSWORD}' | base64 --decode)
DEFECTDOJO_URL="https://defectdojo.staging.maxto-platform.cloud"

# Stocker dans SSM Parameter Store
aws ssm put-parameter --region eu-west-3 --name "/staging/defectdojo/password" --value "$DEFECTDOJO_PASSWORD" --type SecureString --overwrite
aws ssm put-parameter --region eu-west-3 --name "/staging/defectdojo/url" --value "$DEFECTDOJO_URL" --type String --overwrite
aws ssm put-parameter --region eu-west-3 --name "/staging/argocd/password" --value "$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)" --type SecureString --overwrite
aws ssm put-parameter --region eu-west-3 --name "/staging/vault/unseal_key" --value "$UNSEAL_KEY" --type SecureString --overwrite
aws ssm put-parameter --region eu-west-3 --name "/staging/vault/root_token" --value "$ROOT_TOKEN" --type SecureString --overwrite

# ── 10. Datadog ─────────────────────────────────────────────────────────────────
helm repo add datadog https://helm.datadoghq.com
helm repo update
helm install datadog-agent datadog/datadog \
  --namespace monitoring \
  --create-namespace \
  --set datadog.apiKey=${datadog_api_key} \
  --set datadog.site=datadoghq.eu

echo "=== Installation terminée ==="
echo "ArgoCD password: $(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)"
echo "Vault unseal key: $UNSEAL_KEY"
echo "Vault root token: $ROOT_TOKEN"
