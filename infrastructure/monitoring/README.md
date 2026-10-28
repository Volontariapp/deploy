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

## Dashboards Datadog (Tickets 4.1, 4.2 & 4.5)

Le dossier `dashboards/` contient les définitions JSON de nos tableaux de bord Datadog versionnés (Dashboard-as-Code) :

* **`dashboards/overview.json`** (Ticket 4.1) : Dashboard de santé globale et de performance de la plateforme.
  * **Périmètre** : `api-gateway`, microservices `ms-*`, `ws-service` et runners (`outbox-*`, `worker-*`, `post-processor-*`).
  * **Golden Signals** : Débit (hits/s), latence percentile (p50, p95, p99), et taux d'erreurs (%).
  * **Filtres interactifs** : `$service` (par service).

* **`dashboards/infra-db.json`** (Ticket 4.2) : Dashboard d'infrastructure et de persistance des données.
  * **Périmètre** : Cluster Kubernetes (K3s), conteneurs / pods, bases relationnelles PostgreSQL, cache Redis, et volumes persistants (MinIO S3 / Neo4j).
  * **Métriques clés** :
    * **Kubernetes** : Statut des pods (running/pending), redémarrages de conteneurs, utilisation CPU totale et mémoire par pod.
    * **PostgreSQL** : Connexions actives par service (`db`), débit de transactions (commits vs rollbacks), lignes lues/écrites, taille des bases sur disque.
    * **Redis** : Mémoire résidente RSS vs allouée, débit de commandes (ops/s), clients connectés, ratio de cache hit vs miss.
    * **Stockage persistant (PVC)** : Espace disque utilisé et taux d'occupation des volumes persistants par composant.
  * **Filtres interactifs** : `$kube_namespace` (namespace K8s, par défaut `prod`), `$pod_name` (filtrage par pod), et `$db` (base de données).

* **`dashboards/storage.json`** (Ticket 4.5) : Dashboard d'activité métier et du stockage de fichiers.
  * **Périmètre** : Inscriptions (`ms-user`), événements (`ms-event`), publications (`ms-post`), participations (`ms-social`), et cycle de vie complet de `ms-storage`.
  * **Métriques clés** :
    * **Activité Produit (Golden Signals Métier)** : Inscriptions (signups), créations d'événements, publications créées, interactions sociales.
    * **Stockage gRPC (`ms-storage`)** : Débit par RPC (`GetUploadUrl`, `ConfirmUpload`, `DeleteFile`, `GetFileMetadata`), latence p50/p95 et erreurs par méthode.
    * **Sécurité & Pipeline Asynchrone** : Confirmations d'upload (SYNC vs ASYNC), libérations de fichiers, espace disque consommé par le stockage objet MinIO S3, et taille de la base `ms-storage`.
  * **Filtres interactifs** : `$service` et `$kube_namespace`.

## Status Page Interne & Guide Opérationnel de l'Équipe (Ticket 4.4)

Conformément aux décisions d'architecture d'observabilité, la « status page » de la plateforme Volontariapp est centralisée en interne directement sous Datadog sous forme d'une **Dashboard List** épinglée, évitant la dépendance et les coûts d'un service tiers externe.

> 🔗 **Accès direct à la Status Page de l'équipe** : [**Datadog — Dashboard List Volontariapp**](https://us5.datadoghq.com/dashboard/lists/manual/43089)

### 1. Tableau Récapitulatif des Dashboards de la Status Page

| Dashboard | Source (Dashboard-as-Code) | Rôle & Périmètre | Quand le consulter ? |
| :--- | :--- | :--- | :--- |
| **Vue d'ensemble — Plateforme** | [`dashboards/overview.json`](dashboards/overview.json) | **Santé globale & Golden Signals** : débit global HTTP & gRPC, latence médiane (p50) et critique (p95), volume d'erreurs par microservice et runner. | **Au quotidien** et en **première intention** lors de toute alerte. |
| **Infrastructure & Bases de Données** | [`dashboards/infra-db.json`](dashboards/infra-db.json) | **Persistance & Conteneurs** : statut des pods (CrashLoops, redémarrages), CPU/RAM, connexions & transactions PostgreSQL par service, métriques Redis (`shared-infra`), et occupation des volumes PVCs. | En cas de lenteur applicative, de saturation de connexion DB ou de pod instable. |
| **Métier & Stockage de Fichiers** | [`dashboards/storage.json`](dashboards/storage.json) | **Activité Produit & Cycle de Vie S3** : volumétrie métier (signups, events, posts, interactions), suivi des uploads gRPC `ms-storage`, scans antivirus et espace MinIO S3. | Pour suivre l'adoption produit et diagnostiquer les échecs de traitement de médias. |
| **Flux des Requêtes** | [`dashboards/request-flow.json`](dashboards/request-flow.json) | **Parcours bout en bout** : Service Map (api-gateway vers ms-* en gRPC, runners, ws-service), débit, latence et erreurs par étage. Pour la cascade d'une `trace_id`, passer par "View related traces" depuis un widget en anomalie. Les sauts asynchrones (outbox, Redis Streams, BullMQ) n'y apparaissent comme arêtes que si Datadog les relie ; à confirmer sur données réelles. | Pour comprendre où passe le trafic et à quel étage une requête échoue. |
| *(Prévu Sprint 9)* **Flux Asynchrones** | `dashboards/async-flows.json` (Ticket 4.3) | **Résilience & Event-Driven** : latence des Redis Streams, état des Dead Letter Queues (DLQ), files d'attente BullMQ et audit des jobs asynchrones. | Lors d'un retard de notification WebSocket ou d'un blocage d'outbox. |

---

### 2. Matrice d'Aiguillage en Cas d'Alerte (Discord `#monitoring-alerts`)

Dès qu'une alerte est notifiée sur le canal Discord `#monitoring-alerts` (Ticket 5.1) :

1. **Étape 1 — Isolation du service (`Vue d'ensemble`)** :
   * Ouvrir le dashboard **Vue d'ensemble**.
   * Vérifier le widget *Erreurs HTTP par service* et *Erreurs gRPC par service*.
   * Si une dégradation de latence apparaît, identifier si elle est sur la couche HTTP Edge (`api-gateway`) ou inter-services (gRPC).
2. **Étape 2 — Diagnostic approfondi** :
   * **Si l'erreur concerne une base de données ou un pod qui redémarre** : basculer sur le dashboard **Infrastructure & Bases de Données**. Vérifier si une base sature ses connexions (`sum:postgresql.connections`) ou si un pod subit un OOMKilled (`kubernetes.containers.restarts`).
   * **Si l'erreur concerne un upload d'image, un avatar ou une couverture d'événement** : basculer sur le dashboard **Métier & Stockage**. Vérifier les erreurs gRPC sur `ConfirmUpload` ou `GetUploadUrl`.
   * **Si l'action métier a réussi mais que la notification ou l'effet de bord n'arrive pas** : inspecter les flux asynchrones et l'état des runners.
3. **Étape 3 — Corrélation Traces & Logs** :
   * Dans n'importe quel widget en anomalie, cliquer sur la barre ou le point d'erreur et choisir **"View related traces"**.
   * La trace APM donne le détail ligne par ligne et les logs JSON corrélés (`trace_id`, `dd.trace_id`) sans quitter Datadog.

---

### 3. Procédure de Synchronisation (Dashboard-as-Code)

Tous les tableaux de bord sont versionnés dans ce dépôt Git dans le répertoire `infrastructure/monitoring/dashboards/`. Pour mettre à jour un dashboard dans Datadog :

1. Effectuer vos ajustements dans l'interface Datadog ou directement dans le fichier JSON.
2. Exporter ou reporter le JSON dans `infrastructure/monitoring/dashboards/<nom>.json`.
3. Valider la syntaxe JSON :
   ```bash
   python3 -m json.tool infrastructure/monitoring/dashboards/<nom>.json > /dev/null
   ```
4. Ouvrir une Pull Request pour revue d'équipe.
5. Une fois la PR mergée, réimporter le JSON dans Datadog via le menu **`...` > "Import dashboard JSON"**.


