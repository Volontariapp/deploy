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
- **GitOps Auth** : ✅ Clé SSH ajoutée à GitHub et ArgoCD (Successful).
- **Submodules** : ✅ URLs converties en chemins relatifs pour ArgoCD.
- **Secrets** : 🔄 Migration vers **Sealed Secrets** en cours.
    - **Contrôleur** : ✅ Installé.
    - **Workflow** : `kubeseal` installé sur Mac.
- **Isolation Réseau** : ✅ NetworkPolicies (Default-Deny) créées pour Dev et Prod.
- **Prochaine étape** : Implémentation de la stack sécurité (Traefik Hardening, cert-manager, Sealed Secrets).
- **Architecture Sécurité validée** :
    - **Ingress** : Traefik "Hardened" + Cert-manager (Wildcard via Cloudflare DNS-01).
    - **Secrets** : Bitnami Sealed Secrets (GitOps-friendly, léger).
    - **Isolation** : NetworkPolicies (Default-Deny) par microservice.
    - **Hardening** : Pod Security Admissions (PSA) en mode `restricted`.
    - **Audit** : Falco (DaemonSet light).

## ⚠️ Contraintes & Règles
- **Sécurité** : JAMAIS de mots de passe en clair dans ce repo. Utiliser des références à `db-secrets`.
- **Ressources** : Limiter la RAM des bases de données en dev pour préserver les ressources du mini-PC (20Go RAM total).
