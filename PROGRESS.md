# 🧠 Project Progress & Context (PROGRESS.md)

> [!IMPORTANT]
> Ce document sert de mémoire partagée pour Antigravity, Claude et tout autre agent IA travaillant sur ce projet. Consultez-le avant chaque tâche et mettez-le à jour après chaque modification majeure.

## 📌 Vue d'ensemble

- **Dépôt** : `deploy` (ArgoCD GitOps)
- **Cible** : K3s sur Ubuntu Server (Multi-Environnements)
- **Environnements** : `dev`, `prod`
- **Infrastructure** : ArgoCD, Kustomize (Pattern Base/Overlays).

## ✅ Tâches Complétées & Stabilisation (Session 15/05/2026)

### 1. 🚀 GitOps & ArgoCD Stabilization

- **Migration HTTPS** : Abandon total du SSH pour les dépôts et submodules. Utilisation de `GIT_CONFIG_PARAMETERS` pour gérer les submodules sans credentials Git. ✅
- **Helm Integration** : Activation forcée de `--enable-helm` via `ARGOCD_KUSTOMIZE_BUILD_OPTIONS` sur le `repo-server`. ✅
- **Bootstrap Restoration** : Reconstruction propre des root-apps `bootstrap-dev` et `bootstrap-prod` après refactorisation. ✅

### 2. 🗄️ Database Hardening & Fixes

- **PostgreSQL (PSA Restricted)** : Résolution du blocage `Read-only file system` en injectant des volumes `emptyDir` pour les dossiers de lock (`/var/run/postgresql`). ✅
- **Redis Compatibility** : Passage sur l'image officielle `library/redis:7.2` (Debian) pour garantir la présence de `/bin/bash` requis par les scripts d'initialisation Bitnami. ✅
- **Neo4j ClusterIP Patch** : Utilisation d'un **JSON Patch (RFC 6902)** pour forcer le service Neo4j en `ClusterIP` et supprimer l'attribut `externalTrafficPolicy: Local` (incompatible), résolvant ainsi le Sync-Loop d'ArgoCD. ✅

### 3. 🛡️ Security & Automation

- **Namespaces masters** : Centralisation de la création des namespaces (`dev`, `prod`, `traefik`, `cert-manager`) avec labels PSA `restricted` actifs. ✅
- **Secret Management** : Intégration de **Bitnami Sealed Secrets**. Le Token Cloudflare est désormais scellé dans le repo. ✅
- **Cert-Manager / Cloudflare** :
  - `ClusterIssuer` stabilisé (résolution du bug de cache ACME via rotation de clé de compte). ✅
  - Challenge DNS-01 fonctionnel pour les domaines `cyrus-ag.com` et `*.cyrus-ag.com`. ✅
- **Network Isolation** : Validation du modèle Zero-Trust (`default-deny-all`) avec politiques d'accès explicites pour les microservices. ✅

## 🛠️ État Actuel & Prochaines Étapes

- **Databases** : 🟢 **Healthy** (Dev & Prod).
- **Security App** : 🟢 **Healthy** (Sync via `dev-security` et `prod-security`).
- **Certificats** : 🔄 **En cours d'émission** (Challenge DNS propagé).
- **Microservices** : 🔄 **En attente d'images** (`ImagePullBackOff`).
  - _Action_ : Configurer les `ImagePullSecrets` pour GHCR dans chaque namespace.

## 🛡️ Roadmap Sécurité & Résilience

| Priorité | Action                              | État         |
| :------- | :---------------------------------- | :----------- |
| **P0**   | **ImagePullSecrets** (GHCR)         | 🔄 À faire   |
| **P1**   | **Cloudflare Proxy** (WAF)          | 🔄 À activer |
| **P1**   | **Observabilité** (VictoriaMetrics) | 🔄 À ajouter |
| **P1**   | **Audit CI** (Pluto / Checkov)      | 🔄 À ajouter |

## ⚠️ Contraintes Techniques

- **PSA Restricted** : Interdiction d'écriture sur le root filesystem (utiliser des volumes pour les locks/logs).
- **K3s Local** : Pas de LoadBalancer externe (utiliser Traefik Ingress ou ClusterIP).
- **GitOps** : Tout changement doit passer par un commit/push pour être effectif.
