# Gestion des Clés Datadog (API & APP)

## Contexte
L'Agent Datadog et les intégrations CI ont besoin d'une **API key** (ingestion de données) et d'une **APP key** (interaction avec l'API Datadog, ex: dashboards as code). 
Ces clés sont sensibles et ne doivent **jamais** être commitées en clair dans le dépôt Git.

Nous utilisons **Sealed Secrets** pour chiffrer ces clés avant de les committer.

## Procédure de Création et de Chiffrement

### 1. Génération des Clés
- **API Key** : Générée dans Datadog (`Organization Settings` > `API Keys`). 
  - *Nom recommandé :* `k8s-agent`
- **APP Key** : Générée dans Datadog (`Organization Settings` > `Application Keys`). *Nécessaire uniquement si vous prévoyez d'automatiser (dashboards as code, etc).*

### 2. Création du Secret Kubernetes en local (Ne pas committer !)
Créez un fichier temporaire `datadog-secret.yaml` contenant le secret Kubernetes en clair, ou utilisez la ligne de commande pour le générer.
Assurez-vous d'être connecté à votre cluster Kubernetes.

```bash
kubectl create secret generic datadog-keys \
  --namespace datadog \
  --from-literal=api-key="VOTRE_API_KEY" \
  --from-literal=app-key="VOTRE_APP_KEY" \
  --dry-run=client -o yaml > datadog-secret.yaml
```
*(Si vous n'avez pas d'APP key pour le moment, vous pouvez l'omettre).*

### 3. Chiffrement avec Sealed Secrets
Utilisez l'utilitaire `kubeseal` (qui communique avec le contrôleur Sealed Secrets de votre cluster) pour chiffrer ce secret.

```bash
kubeseal --controller-name=sealed-secrets --controller-namespace=kube-system --format=yaml < datadog-secret.yaml > datadog-keys-sealed.yaml
```

### 4. Nettoyage
Supprimez immédiatement le fichier temporaire contenant les clés en clair :
```bash
rm datadog-secret.yaml
```

### 5. Déploiement et Stockage
Le fichier résultant `datadog-keys-sealed.yaml` contient le `SealedSecret`. Il ne contient que des valeurs chiffrées qui ne peuvent être déchiffrées que par le contrôleur Sealed Secrets du cluster.

- **Où le stocker :** Assurez-vous que le fichier est présent dans `deploy/infrastructure/security/sealed-secrets/` et déclaré dans le `kustomization.yaml`.
- ArgoCD se chargera de le déployer, et le contrôleur Sealed Secrets le transformera en véritable `Secret` Kubernetes utilisable par l'Agent Datadog.
