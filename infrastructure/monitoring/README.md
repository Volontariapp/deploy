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

* **`dashboards/async-flows.json`** (Ticket 4.3) : Dashboard dédié aux flux asynchrones, à l'outbox et aux files de messages.
  * **Périmètre** : Outbox transactionnelle SQL (`outbox-*`), workers et jobs BullMQ (`worker-*`), Redis Streams (`shared-infra`), Dead Letter Queues (DLQ), post-processors (`post-processor-*`), et relai WebSocket (`ws-service`).
  * **Métriques clés** :
    * **Indicateurs Clés & Alertes** : Messages en Dead Letter Queue (DLQ), débit global outbox, débit global des workers, débit des post-processors et volume total d'erreurs asynchrones.
    * **Outbox Transactionnelle** : Débit de dépilage par service (req/s), erreurs de dépilage, latence p50/p95 et top des méthodes outbox les plus sollicitées.
    * **Jobs BullMQ** : Débit d'exécution par worker (jobs/s), erreurs et échecs (`job_audit FAILED`), latence p95 et top des handlers de jobs exécutés.
    * **Redis Streams & DLQ** : Débit global de commandes Redis (ops/s), flux des Dead Letter Queues (`*-dlq`), mémoire Redis RSS (MiB) et clients connectés.
    * **Post-Processing & WebSocket** : Débit d'absorption des post-processors (event/s), sagas bloquées / erreurs, latence p50/p95 et diffusion temps réel via `ws-service`.
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
| **Flux des Requêtes** | [`dashboards/request-flow.json`](dashboards/request-flow.json) | **Parcours bout en bout** : Service Map (api-gateway vers ms-* en gRPC, runners, ws-service), débit, latence et erreurs par étage. Pour la cascade d'une `trace_id`, passer par "View related traces" depuis un widget en anomalie. Section asynchrone construite sur les spans `Consumer` et `Producer` : pour chaque type d'événement (`@type`), le service qui l'émet (outbox) et ceux qui le consomment (post-processors, workers, ws-service), avec débit et erreurs. La Service Map ne relie pas ces sauts, car le `traceparent` est capturé à l'écriture de l'événement. | Pour comprendre où passe le trafic et à quel étage une requête échoue. |
| **Flux Asynchrones** | [`dashboards/async-flows.json`](dashboards/async-flows.json) | **Résilience & Event-Driven** : latence et débit de l'Outbox, jobs BullMQ, statut `job_audit`, streams Redis, Dead Letter Queues (DLQ) et notifications WebSocket. | Lors d'un retard de notification WebSocket, d'un blocage d'outbox ou d'un incident asynchrone. |

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

> **Terraform.** Cette réimportation manuelle est remplacée par Terraform dès que l'`apply` automatique est activé (variable de dépôt `TF_APPLY_ENABLED`). Mise en place, import des objets existants et dépannage : [`terraform/README.md`](terraform/README.md). Tant que la variable n'est pas à `true`, la procédure manuelle ci-dessus reste valable.

---

### 4. Monitors (Monitor-as-Code)

Les monitors sont versionnés comme les dashboards, dans `infrastructure/monitoring/monitors/`. Même procédure qu'en section 3 : valider le JSON (`python3 -m json.tool`), PR, puis après merge créer ou mettre à jour le monitor dans Datadog (**Monitors > New Monitor > Import from JSON**). La synchronisation automatique passe par Terraform (voir [`terraform/README.md`](terraform/README.md)) : elle n'est active que lorsque `TF_APPLY_ENABLED` vaut `true`. Le canal de notification Discord (`#monitoring-alerts`, Ticket 5.1) est le webhook Datadog `discord-alerts` : les monitors le mentionnent avec `@webhook-discord-alerts` en fin de champ `message` dans le JSON (un handle ajouté à la main dans l'interface serait écrasé par l'`apply`).

| Monitor | Source | Condition | Pourquoi |
| :--- | :--- | :--- | :--- |
| **DLQ Redis Streams non vide** | [`monitors/redis-streams-dlq.json`](monitors/redis-streams-dlq.json) | `max(last_5m)` de `volontariapp.redis_streams.dlq_length` par `stream` supérieur à 0 | Un message en DLQ a épuisé ses tentatives et a été acquitté : l'événement n'a pas eu son effet. La DLQ n'est jamais purgée automatiquement : l'alerte dure jusqu'à un `XDEL` manuel (voir le runbook) et est renotifiée une fois par jour (24 h). Les messages sont gardés volontairement pour analyser l'échec : une DLQ peut rester non vide plusieurs jours sans urgence. |
| **Messages en attente Redis Streams** | [`monitors/redis-streams-pending.json`](monitors/redis-streams-pending.json) | `min(last_15m)` de `volontariapp.redis_streams.pending` par `stream` et `group` supérieur à 100 (warning) ou 500 (critical) | Un groupe qui garde des messages non acquittés pendant 15 minutes entières est bloqué ou trop lent ; le `min` ignore les pics courts. |
| **Taux d'erreur APM, serveurs gRPC** | [`monitors/apm-error-rate-grpc.json`](monitors/apm-error-rate-grpc.json) | `sum(last_10m)` de `trace.grpc.server.request.errors` divisé par `trace.grpc.server.request.hits` + 100, par `service`, supérieur à 5 % | Couvre les `ms-*`. Une alerte par service. |
| **Taux d'erreur APM, serveurs HTTP** | [`monitors/apm-error-rate-http.json`](monitors/apm-error-rate-http.json) | même requête sur `trace.http.server.request.*` | Couvre `api-gateway` et `ws-service`. |
| **Taux d'erreur APM, consommateurs asynchrones** | [`monitors/apm-error-rate-consumer.json`](monitors/apm-error-rate-consumer.json) | même requête sur `trace.Consumer.*` | Couvre les workers, les post-processors et tout service qui consomme des messages. |
| **Taux d'erreur APM, runners outbox** | [`monitors/apm-error-rate-producer.json`](monitors/apm-error-rate-producer.json) | même requête sur `trace.Producer.*` | Couvre les runners outbox. |

Ces métriques viennent de `@volontariapp/post-processors` 3.5.0 (ticket 6.3) et n'existent dans Datadog qu'une fois les runners mis à jour. Chaque instance d'un runner publie les mêmes jauges : agréger en `max by {stream, group}`, jamais en `sum` (sinon la valeur est multipliée par le nombre de pods). Une jauge absente signifie que la lecture Redis a échoué, pas que la file est vide ; `notify_no_data` est donc désactivé.

> Seuils de départ, non calibrés : le seuil de 500 messages en attente et la fenêtre de 15 minutes sont des valeurs prudentes choisies sans données de production. À ajuster après une semaine de métriques réelles. Le filtre `{*}` n'est pas restreint à un environnement : le tag `env` n'a pas été confirmé dans Datadog.

#### Payload du webhook Discord

Le payload n'est pas dans le dépôt : il se règle dans Datadog, **Integrations > Webhooks > Configuration > `discord-alerts` > Payload**. L'URL du webhook Discord (secret) est un autre champ de la même fiche et ne se copie jamais ici. Payload en place depuis le 2026-11-08 :

```json
{
  "embeds": [
    {
      "title": "$EVENT_TITLE",
      "url": "https://app.datadoghq.com/monitors/$ALERT_ID",
      "color": 15158332,
      "description": "$TEXT_ONLY_MSG",
      "image": {
        "url": "$SNAPSHOT"
      }
    }
  ]
}
```

- **Description** : `$TEXT_ONLY_MSG` reprend le champ `message` du monitor (explication et runbook). Datadog y ajoute à la suite ses propres liens (graphe, statut, édition, logs liés) et la mention `@webhook-discord-alerts` apparaît en clair.
- **Lien du titre** : mène au monitor (`$ALERT_ID`) et non à la page d'événement (`$LINK`), qui n'indique pas d'où vient l'alerte.
- **Pas de champ Date** : `$DATE` est un timestamp en millisecondes, non formatable ; Discord affiche déjà l'heure du message.
- **Couleur** : fixe (rouge), y compris à la résolution (aucune variable Datadog connue pour la faire varier, non vérifié).
- **Graphe** : l'image vient de `$SNAPSHOT`. Elle n'apparaissait pas sur la notification de test du 2026-11-08 ; à confirmer sur une vraie alerte.
- **Tester** : dans un monitor, **Test Notifications** poste un vrai message dans `#monitoring-alerts`.

#### Runbook Redis Streams

1. **Identifier le stream et le groupe** dans le titre de l'alerte (`stream`, `group`).
2. **Alerte DLQ** : inspecter les derniers messages avec `XRANGE <stream>-dlq - + COUNT 10`. Chaque entrée porte `messageId`, `error`, `payload` et `timestamp`. Copier le `payload` avant toute action : ne jamais `XDEL` sans sauvegarde. Une erreur d'infrastructure (base ou Redis indisponible) ne va pas en DLQ ; une entrée en DLQ est donc une erreur métier ou un bug.
3. **Alerte messages en attente** : `XPENDING <stream> <groupe>` pour le total, puis `XPENDING <stream> <groupe> - + 10` pour les identifiants et le consumer. Si un consumer est inactif depuis plus de 5 minutes, réclamer avec `XCLAIM <stream> <groupe> <consumer-sain> 300000 <messageId>`.
4. **Corriger la cause racine** (bug du post-processor ou donnée invalide en base) avant de rejouer.
5. **Rejouer** avec `XADD`, vérifier le traitement dans les logs, puis supprimer l'entrée de la DLQ et nettoyer les clés `retry:post-processor:<groupe>:<messageId>*`, et réconcilier la ligne `event_queue` ou `jobs_outbox` du service émetteur.

Le détail pas à pas, avec les commandes complètes, est dans la skill `volontariapp-async-remediation` du dépôt `meta`. Les responsables des alertes seront définis au ticket 5.11.

#### Monitors du taux d'erreur APM (ticket 5.2)

Quatre monitors, un par famille de spans, car chaque famille a ses propres métriques `hits` et `errors`. Chacun est un monitor multi-alerte (`by {service}`) : le nom du service est dans le titre de l'alerte. Condition commune : `sum(last_10m):` erreurs `.as_count()` divisées par (hits `.as_count()` + 100), supérieur à 0,05, sur `env:prod`.

- **Garde-fou de trafic** : le `+ 100` au dénominateur évite qu'un service quasi inactif sonne pour 1 erreur sur 2 requêtes. Avec ce terme, une alerte exige au moins 6 erreurs en 10 minutes, même sans autre trafic ; pour un service très sollicité, le seuil reste proche de 5 %.
- **Pourquoi un monitor par famille** : un seul monitor devrait additionner des métriques de noms différents groupées par `service`. La documentation Datadog ne décrit pas ce cas (groupe absent d'un terme). Quatre requêtes simples évitent de le deviner.
- **Pas d'alerte sur absence de données** (`notify_no_data: false`) : un service arrêté est un autre sujet (monitor de disponibilité). Un service sans erreur n'a pas de série `errors` et n'apparaît donc pas dans le résultat : c'est le comportement voulu, mais il n'est pas documenté explicitement.
- **Famille et services couverts** : `trace.grpc.server.request.*` pour les `ms-*`, `trace.http.server.request.*` pour `api-gateway` et `ws-service`, `trace.Consumer.*` pour les workers, les post-processors et tout service qui consomme des messages, `trace.Producer.*` pour les runners outbox (noms issus de `dashboards/request-flow.json` et des opérations lues dans l'APM).

> À vérifier, non confirmé : `trace.Producer.errors` est supposé par analogie avec `trace.Consumer.errors` (seul `trace.Producer.hits` a été vu dans l'Explorer). Le seuil de 5 %, la fenêtre de 10 minutes et le terme `+ 100` sont des valeurs de départ : le ticket 5.10, qui devait les fixer, est introuvable. L'ordre d'évaluation est documenté par Datadog pour `sum` avec `.as_count()` (agrégation avant la division, voir [as_count() in Monitor Evaluations](https://docs.datadoghq.com/monitors/guide/as-count-in-monitor-evaluations/)), mais pas combiné à un terme constant et à `by {service}` : à tester sur un service en erreur.

#### Runbook erreurs APM

1. **Lire le titre de l'alerte** : famille (gRPC, HTTP, consommateurs, outbox) et `service`.
2. **Ouvrir l'APM** : Datadog, APM, Services, puis le service concerné. Regarder la courbe d'erreurs et le tableau des ressources triées par taux d'erreur pour trouver la route, le RPC ou le type de message en cause.
3. **Lire une trace en erreur** : ouvrir une trace depuis cette ressource, repérer le span en rouge et son message d'exception.
4. **Corréler avec les logs** : les logs portent `dd.trace_id` (voir « Corrélation Logs-Traces ») ; ouvrir les logs de la trace depuis le panneau de la trace.
5. **Vérifier ce qui a changé** : dernier déploiement du service (ArgoCD), incident sur une dépendance (base de données, Redis, autre service).
6. **Consommateurs et outbox** : si les erreurs viennent d'un post-processor, regarder aussi la DLQ (runbook Redis Streams ci-dessus) ; les erreurs d'infrastructure sont retentées et ne vont pas en DLQ.
