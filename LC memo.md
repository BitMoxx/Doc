Voici un résumé condensé des attributs Live Component à connaître :

## Attributs PHP

| Attribut | Rôle | Exemple |
|---|---|---|
| `#[AsLiveComponent]` | Déclare la classe comme Live Component | `#[AsLiveComponent] class TicketListComponent` |
| `#[LiveProp]` | Propriété **lue** au render, mais **non modifiable** depuis le front | `#[LiveProp] public array $tickets` |
| `#[LiveProp(writable: true)]` | Propriété modifiable depuis le front via `data-model` | `#[LiveProp(writable: true)] public string $searchTerm` |
| `#[LiveAction]` | Méthode appelable depuis le front via `data-action` | `#[LiveAction] public function assign(...)` |
| `#[LiveArg]` | Paramètre d'une `LiveAction`, mappé depuis `data-live-*-param` | `#[LiveArg] string $ticketId` |
| `DefaultActionTrait` | Trait à utiliser (fournit l'action `__invoke` par défaut pour le re-render) | `use DefaultActionTrait;` |

## Attributs Twig / HTML (data-*)

| Attribut | Rôle | Exemple |
|---|---|---|
| `data-action="live#action"` | Branche un événement (clic...) sur le contrôleur Stimulus `live` | `<button data-action="live#action">` |
| `data-live-action-param` | Nom de la `LiveAction` PHP à appeler | `data-live-action-param="assign"` |
| `data-live-{nom}-param` | Valeur d'un `LiveArg` (kebab-case du nom PHP) | `data-live-ticket-id-param="42"` |
| `data-model` | Lie un input à un `LiveProp(writable: true)`, sync auto au blur/change | `data-model="searchTerm"` |
| `data-model="debounce(400)\|prop"` | Sync avec délai anti-spam (utile sur les inputs texte) | `data-model="debounce(400)\|searchTerm"` |
| `data-loading` | Applique un comportement pendant la requête AJAX (spinner, classe CSS) | `data-loading="addClass(opacity-50)"` |

## Mémo visuel du cycle

```
LiveProp(writable: true)  →  synchronisé par  →  data-model
LiveAction                →  déclenché par     →  data-action + data-live-action-param
LiveArg                   →  rempli par        →  data-live-{nom}-param
```

## Règle simple à retenir

- **Donnée qui doit remonter du front** (input utilisateur) → `LiveProp(writable: true)` + `data-model`.
- **Action ponctuelle avec paramètres** (clic bouton) → `LiveAction` + `LiveArg` + `data-action`/`data-live-*-param`.
- **Donnée en lecture seule côté template** (résultat de query, calcul) → simple méthode PHP publique (comme `getTickets()`), pas besoin d'attribut, appelée via `this.tickets` en Twig.
