# Présentation Stack GitOps — Maxto Platform

## Le pitch en une phrase

> "Un pipeline de livraison logicielle complet et autonome, du commit au déploiement en production, avec sécurité et observabilité intégrées — sur une infrastructure à 9€/mois."

---

## Structure de présentation (20-30 min)

### 1. Le problème qu'on résout *(2 min)*

Les équipes livrent trop lentement parce que les déploiements sont manuels, risqués, et non traçables. On veut montrer qu'il existe mieux.

### 2. La philosophie GitOps *(3 min)*

Git est la source de vérité unique. Tout changement passe par une PR. L'infrastructure se réconcilie automatiquement avec ce qui est décrit dans le repo. Plus de `kubectl apply` à la main.

### 3. Le parcours d'un commit *(10 min — la démo live)*

```
Developer push
    → GitLab CI
        → Tests unitaires
        → Build image Docker
        → Scan CVE (Trivy)
        → Rapport de vulnérabilités (DefectDojo)
        → Bump image tag dans infra-k8s
    → ArgoCD détecte le changement
        → Déploie automatiquement sur k3s
    → App live sur https://app.maxto-platform.cloud
    → Métriques visibles dans Grafana
```

Montrer chaque étape en live sur les vrais outils.

### 4. La sécurité by design *(5 min)*

- Chaque image scannée avant déploiement (Trivy)
- Les CVE centralisées et traçables (DefectDojo)
- Aucun accès direct au cluster — tout passe par ArgoCD
- Secrets gérés par Kubernetes, jamais dans le code

### 5. L'observabilité *(5 min)*

- Métriques infrastructure + applicatives dans Grafana
- Alerting possible via Alertmanager
- Tout est corrélable : un incident → un commit → un pipeline

### 6. Le ROI pour le client *(3 min)*

- **Time-to-deploy** : de quelques heures à quelques minutes
- **Rollback** : une ligne de `git revert`
- **Reproductible** : même stack déployable chez eux en moins d'une journée
- **Coût infra lab** : 9€/mois — scalable selon les besoins

---

## Questions DSI probables

| Question | Réponse |
|----------|---------|
| "C'est quoi la différence avec ce qu'on fait déjà ?" | Traçabilité totale, pas de snowflake servers, rollback instantané |
| "Est-ce que ça scale ?" | k3s → EKS/GKE, mêmes manifests, même pipeline |
| "C'est sécurisé ?" | Scan CVE systématique, pas d'accès direct cluster, secrets chiffrés |
| "Combien ça coûte en prod ?" | Dépend de la charge, mais l'outillage est 100% open source |

---

## URLs de démo

| Service | URL | Credentials |
|---------|-----|-------------|
| App démo | https://app.maxto-platform.cloud | public |
| ArgoCD | http://argocd.maxto-platform.cloud | admin / voir credentials.md |
| Grafana | http://grafana.maxto-platform.cloud | admin / voir credentials.md |
| DefectDojo | https://defectdojo.maxto-platform.cloud | admin / voir credentials.md |
