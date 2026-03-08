# 🏦 AWS Banking-Grade Platform

> Infrastructure AWS production-ready, sécurisée et conforme aux standards bancaires.  
> Déployable intégralement via IaC en moins de 30 minutes.

---

## 🎯 Objectif

Ce projet implémente une plateforme cloud **enterprise-grade** sur AWS, conçue pour répondre aux exigences de disponibilité, sécurité et traçabilité des environnements bancaires et grands comptes.

Elle sert de **socle réutilisable** pour déployer des workloads containerisés en production, avec :
- Zéro credential hardcodé
- Zéro intervention manuelle hors pipeline
- Traçabilité complète de chaque changement infrastructure

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          AWS Cloud                              │
│                                                                 │
│   ┌──────────────────────────────────────────────────────┐      │
│   │                    VPC (Multi-AZ)                    │      │
│   │                                                      │      │
│   │  ┌─────────────┐   ┌─────────────┐  ┌────────────┐  │      │
│   │  │  Public     │   │  Private    │  │  Private   │  │      │
│   │  │  Subnet AZ1 │   │  Subnet AZ1 │  │  Subnet AZ2│  │      │
│   │  │  (NAT GW)   │   │  (EKS Node) │  │  (EKS Node)│  │      │
│   │  └─────────────┘   └──────┬──────┘  └─────┬──────┘  │      │
│   │                           │               │          │      │
│   │              ┌────────────▼───────────────▼──┐       │      │
│   │              │        EKS Cluster             │       │      │
│   │              │   ┌──────────────────────┐    │       │      │
│   │              │   │  ArgoCD (GitOps)     │    │       │      │
│   │              │   │  Karpenter (Scaling) │    │       │      │
│   │              │   │  ALB Controller      │    │       │      │
│   │              │   │  Prometheus + Grafana│    │       │      │
│   │              │   └──────────────────────┘    │       │      │
│   │              └───────────────────────────────┘       │      │
│   │                                                      │      │
│   │  ┌──────────────────┐     ┌───────────────────────┐  │      │
│   │  │  S3 (TF State)   │     │  KMS (Chiffrement)    │  │      │
│   │  │  DynamoDB (Lock) │     │  IAM / IRSA            │  │      │
│   │  └──────────────────┘     └───────────────────────┘  │      │
│   └──────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────┘

GitLab CI ──► Terraform Plan/Apply ──► EKS
                                        ▲
GitLab Repo ──► ArgoCD Sync ────────────┘
```

---

## 🔐 Sécurité & Conformité (Banking-Grade)

### Réseau
| Principe | Implémentation |
|---|---|
| Isolation des workloads | Nodes EKS en subnets **100% privés** |
| Sortie contrôlée | NAT Gateway — aucune IP publique sur les nodes |
| Segmentation | Security Groups stricts par couche (ALB / Nodes / RDS) |

### Gestion des accès
| Principe | Implémentation |
|---|---|
| Zéro credential hardcodé | **IRSA** (IAM Roles for Service Accounts) |
| Moindre privilège | Un rôle IAM dédié par composant Terraform |
| Chiffrement au repos | **KMS** sur secrets EKS, volumes EBS, buckets S3 |

### Traçabilité & Audit
| Principe | Implémentation |
|---|---|
| État infrastructure versionné | Remote state S3 + verrou **DynamoDB** |
| Zéro apply manuel | Toutes les modifications passent par **GitLab CI** |
| Audit trail complet | Historique Git = historique des changements infra |
| Scan sécurité IaC | **Checkov** intégré dans le pipeline (SAST infra) |

### Résilience
| Principe | Implémentation |
|---|---|
| Haute disponibilité | Multi-AZ (3 zones) par défaut |
| Auto-healing | ArgoCD corrige automatiquement toute dérive |
| Autoscaling intelligent | **Karpenter** — scale nodes en < 60 secondes |

---

## 🔄 Pipeline CI/CD

```
Push GitLab
    │
    ▼
┌─────────────┐
│  validate   │ ← terraform fmt + validate + tflint
└──────┬──────┘
       │
    ▼
┌─────────────┐
│    plan     │ ← terraform plan (output lisible en MR)
└──────┬──────┘
       │
    ▼
┌─────────────┐
│ security-   │ ← Checkov (scan failles IaC)
│   scan      │
└──────┬──────┘
       │
    ▼
┌─────────────┐
│    apply    │ ← Manuel sur branche main uniquement
└──────┬──────┘
       │
    ▼
┌─────────────┐
│ gitops-sync │ ← Trigger ArgoCD sync
└──────┬──────┘
       │
    ▼
┌─────────────┐
│   notify    │ ← Notification Teams / Slack
└─────────────┘
```

---

## 📦 Stack technique

| Catégorie | Outil | Version |
|---|---|---|
| Cloud | AWS | — |
| Orchestration | EKS (Kubernetes) | 1.29+ |
| IaC | Terraform | >= 1.6 |
| GitOps | ArgoCD | 2.x |
| Autoscaling | Karpenter | 0.x |
| CI/CD | GitLab CI | — |
| Packaging | Helm + Kustomize | — |
| Monitoring | Prometheus + Grafana | — |
| Sécurité IaC | Checkov | — |
| Chiffrement | AWS KMS | — |

---

## 📁 Structure du projet

```
aws-banking-platform/
│
├── terraform/
│   ├── 00-bootstrap/       # S3 backend + DynamoDB state lock
│   ├── 01-network/         # VPC, subnets, NAT GW, Security Groups
│   ├── 02-security/        # IAM roles, KMS, IRSA
│   ├── 03-eks/             # Cluster EKS + node groups
│   ├── 04-addons/          # ALB Controller, External DNS, Karpenter
│   └── 05-observability/   # Prometheus, Grafana, AlertManager
│
├── gitops/
│   ├── apps/               # Définition ArgoCD des applications
│   └── infra/              # Helm charts + Kustomize overlays
│
├── .gitlab-ci.yml          # Pipeline CI/CD complet
│
└── docs/
    ├── architecture.png    # Schéma d'architecture
    ├── security.md         # Détail des choix sécurité
    └── runbook.md          # Procédures opérationnelles
```

---

## ⚡ Déploiement rapide

```bash
# 1. Bootstrap — initialiser le backend Terraform
cd terraform/00-bootstrap
terraform init && terraform apply

# 2. Network — déployer le VPC
cd ../01-network
terraform init && terraform apply

# 3. Security — IAM + KMS
cd ../02-security
terraform init && terraform apply

# 4. EKS — déployer le cluster
cd ../03-eks
terraform init && terraform apply

# 5. Addons — Karpenter, ALB, ArgoCD
cd ../04-addons
terraform init && terraform apply

# 6. Observabilité — Grafana + Prometheus
cd ../05-observability
terraform init && terraform apply
```

> ⏱️ Temps de déploiement estimé : **25–30 minutes** sur un environnement vierge.

---

## 📊 Métriques clés

| Indicateur | Valeur |
|---|---|
| Temps de déploiement complet | < 30 min |
| Disponibilité cible | 99.9% (Multi-AZ) |
| Temps de scale-out (nouveau node) | < 60 secondes (Karpenter) |
| Credentials hardcodés | **0** |
| Couverture scan sécurité IaC | 100% des modules Terraform |

---

## 👤 Auteur

**Maxime Toris** — Ingénieur SRE / Platform Engineer Senior  
7 ans d'expérience en environnements critiques (BNP, CNAM)  
📧 flmaxto@gmail.com | 📱 06 26 10 42 51  
🔗 [LinkedIn](#) | AWS SysOps Certified

---

> *Ce projet est un portfolio technique démontrant la mise en place d'une infrastructure AWS production-ready.  
> Il évolue en parallèle des certifications AWS Solutions Architect & DevOps Engineer Professional.*
