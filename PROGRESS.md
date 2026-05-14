# 🧠 Project Progress & Context (PROGRESS.md)

> [!IMPORTANT]
> Ce document sert de mémoire partagée pour Antigravity, Claude et tout autre agent IA travaillant sur ce projet. Consultez-le avant chaque tâche et mettez-le à jour après chaque modification majeure.

## 📌 Vue d'ensemble
- **Dépôt** : `deploy` (ArgoCD GitOps)
- **Cible** : K3s sur Ubuntu Server (Multi-Environnements)
- **Environnements** : `dev`, `prod`
- **Infrastructure** : ArgoCD, Kustomize (Pattern Base/Overlays).

## ✅ Tâches Complétées
1.  **Structure du Dépôt (Refactorisée)** :
    - `/infrastructure/databases/base/` : Configuration commune des bases.
    - `/infrastructure/databases/overlays/{dev,prod}/` : Spécificités par environnement.
    - `/infrastructure/argocd/projects/` : Définition des `AppProject` (dev-project, prod-project).
    - `/infrastructure/argocd/bootstrap/` : Applications-maîtresses (`bootstrap-dev`, `bootstrap-prod`).
    - `/infrastructure/argocd/apps/{dev,prod}/` : Dossiers contenant les applications de chaque environnement.
    - `/apps/base/` & `/apps/overlays/{dev,prod}/` : Manifestes pour les microservices.
2.  **Configuration des Bases de Données** (`infrastructure/databases/kustomization.yaml`) :
    - 4 instances PostgreSQL (`ms-user-db`, `ms-post-db`, `ms-event-db`, `ms-social-db`).
    - 1 instance Redis.
    - 1 instance Neo4j.
    - **Images utilisées** (alignées sur `docker-compose.yml`) :
        - Postgres : `postgres:16-alpine` (Standard)
        - PostGIS : `postgis/postgis:16-3.4` (Pour `ms-event-db`)
        - Redis : `redis:7-alpine`
        - Neo4j : `neo4j:5.20-community`
    - **Contraintes respectées** : 256Mi RAM pour Postgres, storageClass `local-path`.
3.  **Bootstrap ArgoCD (App-of-Apps)** :
    - Mise en place de `dev-project` et `prod-project` pour l'isolation.
    - Création des root-apps : `bootstrap-dev` et `bootstrap-prod`.

## 🛠️ État Actuel & Prochaines Étapes
- **CI/CD** : ✅ GitHub Actions opérationnelle (Lint, Kustomize Build, Kube-score).
- **GitOps Auth** : ✅ Clé SSH (Submodules en relatifs) & Dépôt connecté (Successful).
- **Neo4j Security** : ✅ Decoupling Helm/Kustomize pour éviter les secrets en clair dans Git.
- **Isolation Réseau** : ✅ NetworkPolicies (Default-Deny) appliquées et validées.
- **Ingress Hardening** : ✅ Middlewares (HSTS, Headers) et TLSOptions (1.2+) configurés.
- **SSL Automation** : ✅ ClusterIssuer Cloudflare et Certificate Wildcard (*.cyrus-ag.com) configurés.
- **Security Stack** : ✅ Root-app `security-stack` créée pour un déploiement unifié.
- **Resource Hardening** : ✅ ResourceQuotas implémentés pour protéger la RAM du mini-PC.
- **DNS Security** : ✅ Egress DNS restreint au seul kube-dns pour éviter l'exfiltration.
- **Microservices Deployment** : ✅ Dossier `/apps` structuré avec Overlays Dev/Prod pour les 4 services.
    - **Secrets** : Bitnami Sealed Secrets (GitOps-friendly, léger).

## 🛡️ Roadmap Sécurité & Résilience (Validée)
| Priorité | Action | État |
| :--- | :--- | :--- |
| **P0** | **Cloudflare Proxy** (WAF/DDoS) | 🔄 À activer côté DNS |
| **P1** | **Gitleaks** (Scan secrets CI) | ✅ Implémenté |
| **P1** | **Rate-Limiting** (Traefik) | ✅ Implémenté |
| **P1** | **VictoriaMetrics** (Observabilité) | 🔄 À ajouter |
| **P1** | **Pluto / Checkov** (Audit CI) | 🔄 À ajouter |
| **P2** | **Pod Security Admission** (PSA) | ✅ Mode `restricted` actif |

## ⚠️ Contraintes & Règles
- **Sécurité** : JAMAIS de mots de passe en clair. Utiliser `Sealed Secrets`.
- **Ressources** : RAM limitée sur les DB (i7 Mini-PC).
- **Persistence** : local-path (No S3 Backups).
