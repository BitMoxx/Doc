Voilà les vrais use cases où Messenger en async apporte une vraie valeur :

---

## La règle de base

> **Async = quand l'utilisateur n'a pas besoin d'attendre le résultat immédiatement**

---

## Use cases concrets pour un logiciel de caisse

### 🔴 Critique — Opérations lentes qui bloqueraient l'UI

```
Envoi d'email / SMS de reçu          → le client attend sa monnaie, pas son email
Génération de PDF (ticket, facture)  → peut prendre 2-3 secondes
Synchronisation stock entre boutiques → appel API externe, latence imprévisible
Notification push application mobile → fire and forget
```

### 🟠 Exports & Reporting

```
Export CSV/Excel comptabilité   → peut durer 30 secondes sur gros volume
Rapport de ventes mensuel       → agrégation de milliers de lignes
Calcul des primes vendeurs      → dépend du volume de commandes
Clôture de caisse journalière   → calculs + archivage + envoi mail
```

### 🟡 Synchronisation & Intégrations

```
Envoi vers logiciel comptable (Sage, EBP...)   → API tierce, peut échouer
Synchro catalogue produits depuis ERP          → gros volume de données
Mise à jour prix en masse                      → 10 boutiques × N produits
Remontée des ventes vers le siège              → agrégation multi-boutiques
```

### 🟢 Tâches planifiées récurrentes

```
Inventaire automatique toutes les nuits
Alertes stock faible toutes les heures
Backup des données de caisse
Génération des tableaux de bord du matin
```

---

## Use cases où async ne sert à RIEN

```
❌ Authentification utilisateur      → doit être immédiat
❌ Calcul du prix d'un article       → synchrone obligatoire
❌ Vérification de stock à la caisse → le vendeur attend la réponse
❌ Paiement CB                       → transactionnel, doit être immédiat
❌ Lecture d'un produit en BDD       → 5ms, inutile d'async
```

---

## Le pattern le plus utile : Async + Feedback

Le vrai apport d'async c'est de **répondre immédiatement** à l'utilisateur et le notifier quand c'est prêt :

```
┌─────────────────────────────────────────────────────┐
│  1. User clique "Exporter la comptabilité"          │
│          ↓                                          │
│  2. Controller dispatch le message (< 5ms)          │
│          ↓                                          │
│  3. Réponse immédiate → "Export en cours..."        │
│          ↓                                          │
│  4. Worker traite en arrière-plan (30 secondes)     │
│          ↓                                          │
│  5. Notification / email → "Votre export est prêt" │
└─────────────────────────────────────────────────────┘
```

---

## Ce que Messenger gère en bonus

Ce qui rend Messenger vraiment puissant vs un simple cron :

### Retry automatique en cas d'échec
```yaml
# messenger.yaml
transports:
  async:
    retry_strategy:
      max_retries: 3
      delay: 1000      # attend 1 seconde avant retry
      multiplier: 2    # puis 2s, puis 4s (backoff exponentiel)
```

```
Tentative 1 → API externe timeout ❌
Tentative 2 (après 1s)  → API externe timeout ❌
Tentative 3 (après 2s)  → Succès ✅
```

### Dead Letter Queue (messages en échec)
```yaml
transports:
  failed:
    dsn: 'doctrine://default?queue_name=failed'

  async:
    failure_transport: failed  # les messages ratés vont ici
```

```bash
# Voir les messages en échec
symfony console messenger:failed:show

# Les rejouer
symfony console messenger:failed:retry
```

### Priorisation
```yaml
transports:
  haute_priorite:
    options:
      queue_name: high    # traité en premier

  basse_priorite:
    options:
      queue_name: low     # traité quand le worker est libre
```

---

## Résumé visuel

```
Opération                    Sync    Async
─────────────────────────────────────────
Paiement CB                   ✅      ❌
Calcul prix                   ✅      ❌
Vérif stock caisse            ✅      ❌
─────────────────────────────────────────
Envoi email reçu              ❌      ✅
Génération PDF facture        ❌      ✅
Export comptabilité           ❌      ✅
Synchro stock boutiques       ❌      ✅
Calcul primes                 ❌      ✅
Clôture de caisse             ❌      ✅
Notification push             ❌      ✅
─────────────────────────────────────────
```

La question à toujours se poser : **"L'utilisateur a-t-il besoin de la réponse maintenant pour continuer son travail ?"** Si non → async.
