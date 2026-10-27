# Monitoring & Observabilité

Ce dossier `deploy/infrastructure/monitoring/` centralise les ressources liées au monitoring et à l'observabilité du cluster Kubernetes.

## Datadog Agent

Le déploiement de l'Agent Datadog est géré via ArgoCD grâce au manifeste `datadog-agent-app.yaml`.
Il déploie le chart Helm officiel (`datadog/datadog`) dans le namespace `datadog`.

### Clés et Sécurité (Sealed Secrets)
Les clés API (et potentiellement APP) nécessaires à Datadog sont stockées de manière sécurisée et ne sont **jamais** commitées en clair. 
Elles utilisent le mécanisme des **Sealed Secrets**. 

Le secret chiffré est déployé dans le cluster pour être utilisé par ce chart Helm.
> 📄 **Procédure de génération** : Référez-vous à la documentation dans `deploy/infrastructure/security/sealed-secrets/DATADOG_KEYS.md` pour savoir comment mettre à jour ou recréer les clés de manière sécurisée si nécessaire.

### Installation / Mise à jour
L'installation est gérée automatiquement par ArgoCD en se basant sur le fichier `datadog-agent-app.yaml`.
La version du chart est figée via le paramètre `targetRevision` pour éviter toute mise à jour non planifiée. Pour mettre à jour l'Agent Datadog, incrémentez cette version dans une Pull Request.

## Collecte des Logs (Ticket 3.3)

La collecte des logs est activée au niveau du DaemonSet Datadog (`datadog.logs.enabled: true`) via lecture directe des fichiers journaux K3s / containerd (`containerCollectUsingFiles: true`).

### Périmètre et Filtrage des Conteneurs
Pour maîtriser les quotas d'ingestion et éviter le bruit :
* **Inclusions (`containerIncludeLogs`)** : Seuls les namespaces applicatifs (`prod`, `dev`) sont collectés.
* **Exclusions (`containerExcludeLogs`)** :
  * Namespaces système & infra : `kube-system`, `argocd`, `traefik`, `cert-manager`, `datadog`.
  * Agent Datadog lui-même : `name:datadog-agent`, `image:.*datadog.*`.
  * InitContainers récurrents : `name:wait-for-.*`.
  * Bases de données brutes : `name:.*-postgresql`, `name:.*redis.*`, `name:.*neo4j.*`, `image:.*postgres.*`, `image:.*redis.*`, `image:.*neo4j.*`.

### Corrélation Logs-Traces
Les microservices utilisent `@volontariapp/logger` en format JSON en production (`production.config.json`). Le logger injecte automatiquement :
* `trace_id`
* `dd.trace_id` (64-bit lower decimal)
* `dd.span_id` (64-bit lower decimal)

L'Agent Datadog et les pipelines de parsing corrèlent nativement chaque ligne de log avec sa trace APM distribuée correspondante.

## Dashboards Datadog (Ticket 4.1)

Le dossier `dashboards/` contient les définitions JSON de nos tableaux de bord Datadog versionnés (Dashboard-as-Code) :

* **`dashboards/overview.json`** : Dashboard de santé globale et de performance de la plateforme.
  * **Périmètre** : `api-gateway`, microservices `ms-*`, `ws-service` et runners (`outbox-*`, `worker-*`, `post-processor-*`).
  * **Golden Signals** : Débit (hits/s), latence percentile (p50, p95, p99), et taux d'erreurs (%).
  * **Filtres interactifs** : `$env` (environnement) et `$service` (par service).


