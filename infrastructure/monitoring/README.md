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
