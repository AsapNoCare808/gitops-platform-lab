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
    server: https://acme-v02.api.letsencrypt.org/directory
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

# ── 7. App js-game ─────────────────────────────────────────────────────────────
kubectl create namespace js-game

cat <<'EOF' | kubectl apply -f - -n js-game
apiVersion: apps/v1
kind: Deployment
metadata:
  name: js-game-app
  labels:
    app: js-game-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: js-game-app
  template:
    metadata:
      labels:
        app: js-game-app
    spec:
      containers:
      - name: js-game-app
        image: internaldev/jsgame:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: js-game-app-service
  labels:
    app: js-game-app
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: js-game-app
  sessionAffinity: None
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: js-game-app-ingress
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - app.staging.maxto-platform.cloud
    secretName: js-game-tls
  rules:
  - host: app.staging.maxto-platform.cloud
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: js-game-app-service
            port:
              number: 80
EOF

# ── 8. DefectDojo ──────────────────────────────────────────────────────────────
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

cat <<'EOF' | kubectl apply -f - -n defectdojo
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: defectdojo-django-ingress
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
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

echo "=== Installation terminée ==="
echo "ArgoCD password: $(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)"
echo "DefectDojo password: $(kubectl get secret defectdojo --namespace=defectdojo --output jsonpath='{.data.DD_ADMIN_PASSWORD}' | base64 --decode)"
