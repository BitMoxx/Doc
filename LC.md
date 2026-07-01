Voici un POC structuré en DDD/Clean Architecture avec CQS, en utilisant Symfony Messenger comme command bus / query bus (pattern standard en Symfony pour ce genre d'architecture).

## Structure générale

```
src/Ticket/
  Domain/
    Model/Ticket.php
    Model/TicketStatus.php
    Port/TicketGatewayInterface.php
  Application/
    Command/CreateTicket/{CreateTicketCommand,CreateTicketHandler}.php
    Command/UpdateTicketStatus/{...}.php
    Command/AssignTicket/{...}.php
    Query/ListTickets/{ListTicketsQuery,ListTicketsHandler}.php
    Query/GetAvailableStatuses/{...}.php
  Infrastructure/
    Jira/JiraApiTicketGateway.php
  UI/
    Component/TicketListComponent.php
    Component/CreateTicketFormComponent.php
```

---

## 1. Domain

```php
// src/Ticket/Domain/Model/TicketStatus.php
namespace App\Ticket\Domain\Model;

final class TicketStatus
{
    public function __construct(
        public readonly string $id,
        public readonly string $name,
    ) {}
}
```

```php
// src/Ticket/Domain/Model/Ticket.php
namespace App\Ticket\Domain\Model;

final class Ticket
{
    public function __construct(
        public readonly string $id,
        public readonly string $key,
        public readonly string $summary,
        public readonly string $status,
        public readonly ?string $assignee,
    ) {}
}
```

```php
// src/Ticket/Domain/Port/TicketGatewayInterface.php
namespace App\Ticket\Domain\Port;

use App\Ticket\Domain\Model\Ticket;
use App\Ticket\Domain\Model\TicketStatus;

interface TicketGatewayInterface
{
    public function create(string $projectKey, string $summary, string $issueType): string;

    public function updateStatus(string $ticketId, string $transitionId): void;

    public function assign(string $ticketId, string $accountId): void;

    /** @return TicketStatus[] */
    public function getAvailableTransitions(string $ticketId): array;

    /** @return Ticket[] */
    public function search(string $jql, int $maxResults = 25): array;
}
```

Le domaine ne connaît que ce port. Aucune dépendance à Jira ou à HttpClient ici — c'est l'infrastructure qui implémentera l'interface.

---

## 2. Application — Commands

```php
// src/Ticket/Application/Command/CreateTicket/CreateTicketCommand.php
namespace App\Ticket\Application\Command\CreateTicket;

final class CreateTicketCommand
{
    public function __construct(
        public readonly string $projectKey,
        public readonly string $summary,
        public readonly string $issueType,
    ) {}
}
```

```php
// src/Ticket/Application/Command/CreateTicket/CreateTicketHandler.php
namespace App\Ticket\Application\Command\CreateTicket;

use App\Ticket\Domain\Port\TicketGatewayInterface;
use Symfony\Component\Messenger\Attribute\AsMessageHandler;

#[AsMessageHandler(bus: 'command.bus')]
final class CreateTicketHandler
{
    public function __construct(
        private readonly TicketGatewayInterface $gateway,
    ) {}

    public function __invoke(CreateTicketCommand $command): string
    {
        return $this->gateway->create(
            $command->projectKey,
            $command->summary,
            $command->issueType,
        );
    }
}
```

```php
// src/Ticket/Application/Command/UpdateTicketStatus/UpdateTicketStatusCommand.php
namespace App\Ticket\Application\Command\UpdateTicketStatus;

final class UpdateTicketStatusCommand
{
    public function __construct(
        public readonly string $ticketId,
        public readonly string $transitionId,
    ) {}
}
```

```php
// src/Ticket/Application/Command/UpdateTicketStatus/UpdateTicketStatusHandler.php
namespace App\Ticket\Application\Command\UpdateTicketStatus;

use App\Ticket\Domain\Port\TicketGatewayInterface;
use Symfony\Component\Messenger\Attribute\AsMessageHandler;

#[AsMessageHandler(bus: 'command.bus')]
final class UpdateTicketStatusHandler
{
    public function __construct(
        private readonly TicketGatewayInterface $gateway,
    ) {}

    public function __invoke(UpdateTicketStatusCommand $command): void
    {
        $this->gateway->updateStatus($command->ticketId, $command->transitionId);
    }
}
```

```php
// src/Ticket/Application/Command/AssignTicket/AssignTicketCommand.php
namespace App\Ticket\Application\Command\AssignTicket;

final class AssignTicketCommand
{
    public function __construct(
        public readonly string $ticketId,
        public readonly string $accountId,
    ) {}
}
```

```php
// src/Ticket/Application/Command/AssignTicket/AssignTicketHandler.php
namespace App\Ticket\Application\Command\AssignTicket;

use App\Ticket\Domain\Port\TicketGatewayInterface;
use Symfony\Component\Messenger\Attribute\AsMessageHandler;

#[AsMessageHandler(bus: 'command.bus')]
final class AssignTicketHandler
{
    public function __construct(
        private readonly TicketGatewayInterface $gateway,
    ) {}

    public function __invoke(AssignTicketCommand $command): void
    {
        $this->gateway->assign($command->ticketId, $command->accountId);
    }
}
```

---

## 3. Application — Queries

```php
// src/Ticket/Application/Query/ListTickets/ListTicketsQuery.php
namespace App\Ticket\Application\Query\ListTickets;

final class ListTicketsQuery
{
    public function __construct(
        public readonly string $jql = 'ORDER BY updated DESC',
        public readonly int $maxResults = 25,
    ) {}
}
```

```php
// src/Ticket/Application/Query/ListTickets/ListTicketsHandler.php
namespace App\Ticket\Application\Query\ListTickets;

use App\Ticket\Domain\Port\TicketGatewayInterface;
use Symfony\Component\Messenger\Attribute\AsMessageHandler;

#[AsMessageHandler(bus: 'query.bus')]
final class ListTicketsHandler
{
    public function __construct(
        private readonly TicketGatewayInterface $gateway,
    ) {}

    /** @return \App\Ticket\Domain\Model\Ticket[] */
    public function __invoke(ListTicketsQuery $query): array
    {
        return $this->gateway->search($query->jql, $query->maxResults);
    }
}
```

```php
// src/Ticket/Application/Query/GetAvailableStatuses/GetAvailableStatusesQuery.php
namespace App\Ticket\Application\Query\GetAvailableStatuses;

final class GetAvailableStatusesQuery
{
    public function __construct(
        public readonly string $ticketId,
    ) {}
}
```

```php
// src/Ticket/Application/Query/GetAvailableStatuses/GetAvailableStatusesHandler.php
namespace App\Ticket\Application\Query\GetAvailableStatuses;

use App\Ticket\Domain\Port\TicketGatewayInterface;
use Symfony\Component\Messenger\Attribute\AsMessageHandler;

#[AsMessageHandler(bus: 'query.bus')]
final class GetAvailableStatusesHandler
{
    public function __construct(
        private readonly TicketGatewayInterface $gateway,
    ) {}

    /** @return \App\Ticket\Domain\Model\TicketStatus[] */
    public function __invoke(GetAvailableStatusesQuery $query): array
    {
        return $this->gateway->getAvailableTransitions($query->ticketId);
    }
}
```

---

## 4. Infrastructure — Client Jira

```php
// src/Ticket/Infrastructure/Jira/JiraApiTicketGateway.php
namespace App\Ticket\Infrastructure\Jira;

use App\Ticket\Domain\Model\Ticket;
use App\Ticket\Domain\Model\TicketStatus;
use App\Ticket\Domain\Port\TicketGatewayInterface;
use Symfony\Contracts\Cache\CacheInterface;
use Symfony\Contracts\Cache\ItemInterface;
use Symfony\Contracts\HttpClient\HttpClientInterface;

final class JiraApiTicketGateway implements TicketGatewayInterface
{
    public function __construct(
        private readonly HttpClientInterface $jiraClient, // configuré avec base_uri + auth Basic (email + token API)
        private readonly CacheInterface $cache,
    ) {}

    public function create(string $projectKey, string $summary, string $issueType): string
    {
        $response = $this->jiraClient->request('POST', '/rest/api/3/issue', [
            'json' => [
                'fields' => [
                    'project' => ['key' => $projectKey],
                    'summary' => $summary,
                    'issuetype' => ['name' => $issueType],
                ],
            ],
        ]);

        return $response->toArray()['id'];
    }

    public function updateStatus(string $ticketId, string $transitionId): void
    {
        $this->jiraClient->request('POST', "/rest/api/3/issue/{$ticketId}/transitions", [
            'json' => ['transition' => ['id' => $transitionId]],
        ]);
    }

    public function assign(string $ticketId, string $accountId): void
    {
        $this->jiraClient->request('PUT', "/rest/api/3/issue/{$ticketId}/assignee", [
            'json' => ['accountId' => $accountId],
        ]);
    }

    public function getAvailableTransitions(string $ticketId): array
    {
        return $this->cache->get("jira_transitions_{$ticketId}", function (ItemInterface $item) use ($ticketId) {
            $item->expiresAfter(300); // 5 min, les transitions changent peu

            $data = $this->jiraClient
                ->request('GET', "/rest/api/3/issue/{$ticketId}/transitions")
                ->toArray();

            return array_map(
                fn (array $t) => new TicketStatus($t['id'], $t['name']),
                $data['transitions'],
            );
        });
    }

    public function search(string $jql, int $maxResults = 25): array
    {
        $data = $this->jiraClient->request('GET', '/rest/api/3/search', [
            'query' => [
                'jql' => $jql,
                'maxResults' => $maxResults,
                'fields' => 'summary,status,assignee',
            ],
        ])->toArray();

        return array_map(
            fn (array $issue) => new Ticket(
                id: $issue['id'],
                key: $issue['key'],
                summary: $issue['fields']['summary'],
                status: $issue['fields']['status']['name'],
                assignee: $issue['fields']['assignee']['displayName'] ?? null,
            ),
            $data['issues'],
        );
    }
}
```

### Configuration

```yaml
# config/packages/messenger.yaml
framework:
    messenger:
        buses:
            command.bus:
                middleware: ['validation']
            query.bus:
                middleware: ['validation']

# config/packages/framework.yaml (extrait)
framework:
    http_client:
        scoped_clients:
            jira.client:
                base_uri: '%env(JIRA_BASE_URL)%'
                auth_basic: '%env(JIRA_EMAIL)%:%env(JIRA_API_TOKEN)%'
```

```yaml
# config/services.yaml (extrait)
services:
    App\Ticket\Infrastructure\Jira\JiraApiTicketGateway:
        arguments:
            $jiraClient: '@jira.client'

    App\Ticket\Domain\Port\TicketGatewayInterface:
        alias: App\Ticket\Infrastructure\Jira\JiraApiTicketGateway
```

Deux bus séparés (`command.bus` / `query.bus`) matérialisent la séparation CQS au niveau infra, pas juste par convention de nommage.

---

## 5. UI — Live Components

```php
// src/Ticket/UI/Component/TicketListComponent.php
namespace App\Ticket\UI\Component;

use App\Ticket\Application\Command\AssignTicket\AssignTicketCommand;
use App\Ticket\Application\Command\UpdateTicketStatus\UpdateTicketStatusCommand;
use App\Ticket\Application\Query\ListTickets\ListTicketsQuery;
use Symfony\Component\Messenger\HandleTrait;
use Symfony\Component\Messenger\MessageBusInterface;
use Symfony\UX\LiveComponent\Attribute\AsLiveComponent;
use Symfony\UX\LiveComponent\Attribute\LiveAction;
use Symfony\UX\LiveComponent\Attribute\LiveArg;
use Symfony\UX\LiveComponent\Attribute\LiveProp;
use Symfony\UX\LiveComponent\DefaultActionTrait;

#[AsLiveComponent]
final class TicketListComponent
{
    use DefaultActionTrait;
    use HandleTrait;

    #[LiveProp(writable: true)]
    public string $jql = 'ORDER BY updated DESC';

    public function __construct(
        private readonly MessageBusInterface $queryBus,
        private readonly MessageBusInterface $commandBus,
    ) {}

    public function getTickets(): array
    {
        // handle() vient de HandleTrait, dispatche sur le bus et retourne le résultat du handler
        return $this->handle(new ListTicketsQuery($this->jql));
    }

    #[LiveAction]
    public function assign(#[LiveArg] string $ticketId, #[LiveArg] string $accountId): void
    {
        $this->handle(new AssignTicketCommand($ticketId, $accountId));
    }

    #[LiveAction]
    public function updateStatus(#[LiveArg] string $ticketId, #[LiveArg] string $transitionId): void
    {
        $this->handle(new UpdateTicketStatusCommand($ticketId, $transitionId));
    }
}
```

Attention : `HandleTrait` attend un bus unique injecté sous la propriété `$messageBus`. Avec deux bus, écris plutôt deux petites méthodes explicites plutôt que de réutiliser le trait tel quel :

```php
    private function query(object $query): mixed
    {
        $envelope = $this->queryBus->dispatch($query);
        return $envelope->last(\Symfony\Component\Messenger\Stamp\HandledStamp::class)->getResult();
    }

    private function dispatchCommand(object $command): void
    {
        $this->commandBus->dispatch($command);
    }
```

et remplace les appels à `$this->handle(...)` par `$this->query(...)` / `$this->dispatchCommand(...)`.

```twig
{# templates/components/TicketListComponent.html.twig #}
<div{{ attributes }}>
    <table class="table">
        <thead>
            <tr><th>Clé</th><th>Résumé</th><th>Statut</th><th>Assigné</th><th></th></tr>
        </thead>
        <tbody>
            {% for ticket in this.tickets %}
                <tr>
                    <td>{{ ticket.key }}</td>
                    <td>{{ ticket.summary }}</td>
                    <td>{{ ticket.status }}</td>
                    <td>{{ ticket.assignee ?? '—' }}</td>
                    <td>
                        <button data-action="live#action"
                                data-live-action-param="updateStatus"
                                data-live-ticket-id-param="{{ ticket.id }}"
                                data-live-transition-id-param="21">
                            Passer "En cours"
                        </button>
                    </td>
                </tr>
            {% endfor %}
        </tbody>
    </table>
</div>
```

```php
// src/Ticket/UI/Component/CreateTicketFormComponent.php
namespace App\Ticket\UI\Component;

use App\Ticket\Application\Command\CreateTicket\CreateTicketCommand;
use Symfony\Component\Messenger\MessageBusInterface;
use Symfony\UX\LiveComponent\Attribute\AsLiveComponent;
use Symfony\UX\LiveComponent\Attribute\LiveAction;
use Symfony\UX\LiveComponent\Attribute\LiveProp;
use Symfony\UX\LiveComponent\DefaultActionTrait;

#[AsLiveComponent]
final class CreateTicketFormComponent
{
    use DefaultActionTrait;

    #[LiveProp(writable: true)]
    public string $projectKey = '';

    #[LiveProp(writable: true)]
    public string $summary = '';

    #[LiveProp(writable: true)]
    public string $issueType = 'Task';

    public ?string $createdTicketId = null;

    public function __construct(
        private readonly MessageBusInterface $commandBus,
    ) {}

    #[LiveAction]
    public function submit(): void
    {
        $envelope = $this->commandBus->dispatch(
            new CreateTicketCommand($this->projectKey, $this->summary, $this->issueType)
        );

        $this->createdTicketId = $envelope
            ->last(\Symfony\Component\Messenger\Stamp\HandledStamp::class)
            ->getResult();

        $this->summary = ''; // reset du champ
    }
}
```

```twig
{# templates/components/CreateTicketFormComponent.html.twig #}
<div{{ attributes }}>
    {% if this.createdTicketId %}
        <div class="alert alert-success">Ticket créé : {{ this.createdTicketId }}</div>
    {% endif %}

    <input type="text" data-model="projectKey" placeholder="Clé projet (ex: PROJ)">
    <input type="text" data-model="summary" placeholder="Résumé">
    <select data-model="issueType">
        <option value="Task">Task</option>
        <option value="Bug">Bug</option>
    </select>
    <button data-action="live#action" data-live-action-param="submit">Créer</button>
</div>
```

---

## Points d'attention pour la suite

- **Erreurs Jira** : je n'ai pas géré les exceptions (`4xx`/`5xx`, rate limiting 429) — à faire dans `JiraApiTicketGateway` avec une `JiraException` domaine, catchée dans les composants pour afficher un message propre plutôt qu'une 500.
- **Validation** : ajoute des contraintes Symfony Validator sur les Commands (`middleware: validation` déjà branché sur les bus) pour éviter d'envoyer une requête vide à Jira.
- **Tests** : le `TicketGatewayInterface` te permet de tester tous les handlers avec un mock, sans jamais toucher au HTTP.
- **`accountId` pour l'assignation** : il te faudra une query `GetAssignableUsersQuery` similaire à celle des statuts si tu veux peupler un select d'utilisateurs.

Voici l'extension pour ajouter un filtre texte (titre/description), avec debounce côté Live Component pour éviter de spammer Jira à chaque frappe.

## 1. Adapter la Query pour accepter un terme de recherche

```php
// src/Ticket/Application/Query/ListTickets/ListTicketsQuery.php
namespace App\Ticket\Application\Query\ListTickets;

final class ListTicketsQuery
{
    public function __construct(
        public readonly ?string $searchTerm = null,
        public readonly int $maxResults = 25,
    ) {}
}
```

On ne construit plus le JQL côté UI (le composant ne doit pas connaître la syntaxe JQL) — c'est le handler/gateway qui s'en charge, ce qui garde le Live Component ignorant de Jira comme évoqué plus tôt.

```php
// src/Ticket/Application/Query/ListTickets/ListTicketsHandler.php
namespace App\Ticket\Application\Query\ListTickets;

use App\Ticket\Domain\Port\TicketGatewayInterface;
use Symfony\Component\Messenger\Attribute\AsMessageHandler;

#[AsMessageHandler(bus: 'query.bus')]
final class ListTicketsHandler
{
    public function __construct(
        private readonly TicketGatewayInterface $gateway,
    ) {}

    public function __invoke(ListTicketsQuery $query): array
    {
        $jql = $this->buildJql($query->searchTerm);

        return $this->gateway->search($jql, $query->maxResults);
    }

    private function buildJql(?string $searchTerm): string
    {
        if (empty($searchTerm)) {
            return 'ORDER BY updated DESC';
        }

        // échappement basique des guillemets pour éviter une injection JQL
        $escaped = str_replace('"', '\\"', $searchTerm);

        return sprintf(
            'summary ~ "%s" OR description ~ "%s" ORDER BY updated DESC',
            $escaped,
            $escaped
        );
    }
}
```

L'opérateur `~` en JQL fait une recherche "contains" (full-text) sur le champ.

## 2. Le Live Component avec le filtre

```php
// src/Ticket/UI/Component/TicketListComponent.php
namespace App\Ticket\UI\Component;

use App\Ticket\Application\Query\ListTickets\ListTicketsQuery;
use Symfony\Component\Messenger\MessageBusInterface;
use Symfony\Component\Messenger\Stamp\HandledStamp;
use Symfony\UX\LiveComponent\Attribute\AsLiveComponent;
use Symfony\UX\LiveComponent\Attribute\LiveProp;
use Symfony\UX\LiveComponent\DefaultActionTrait;

#[AsLiveComponent]
final class TicketListComponent
{
    use DefaultActionTrait;

    #[LiveProp(writable: true)]
    public ?string $searchTerm = null;

    public function __construct(
        private readonly MessageBusInterface $queryBus,
    ) {}

    public function getTickets(): array
    {
        $envelope = $this->queryBus->dispatch(new ListTicketsQuery($this->searchTerm));

        return $envelope->last(HandledStamp::class)->getResult();
    }
}
```

Le point important : pas de méthode custom pour la recherche. `$searchTerm` est un `LiveProp(writable: true)` — dès qu'il change côté front, le composant se re-render automatiquement et rappelle `getTickets()` avec la nouvelle valeur. C'est le mécanisme `data-model` que tu voulais que je détaille.

## 3. Le template avec debounce

```twig
{# templates/components/TicketListComponent.html.twig #}
<div{{ attributes }}>
    <input
        type="search"
        placeholder="Rechercher par titre ou description..."
        data-model="debounce(400)|searchTerm"
        value="{{ this.searchTerm }}"
    >

    <div data-loading="addClass(opacity-50)">
        <table class="table">
            <thead>
                <tr><th>Clé</th><th>Résumé</th><th>Statut</th><th>Assigné</th></tr>
            </thead>
            <tbody>
                {% for ticket in this.tickets %}
                    <tr>
                        <td>{{ ticket.key }}</td>
                        <td>{{ ticket.summary }}</td>
                        <td>{{ ticket.status }}</td>
                        <td>{{ ticket.assignee ?? '—' }}</td>
                    </tr>
                {% else %}
                    <tr><td colspan="4">Aucun ticket trouvé.</td></tr>
                {% endfor %}
            </tbody>
        </table>
    </div>
</div>
```

## Explication du `data-model`

```
data-model="debounce(400)|searchTerm"
```

- `searchTerm` : lie l'input à la propriété PHP `$searchTerm` — chaque frappe met à jour la valeur.
- `debounce(400)` : attend 400ms sans frappe avant d'envoyer la requête AJAX au serveur. Sans ça, chaque caractère tapé déclencherait un appel réseau vers Jira (très mauvais niveau perf/rate-limit).
- `data-loading="addClass(opacity-50)"` : ajoute une classe CSS pendant que la requête est en cours (feedback visuel simple, sans JS custom).

## Flux complet

```
[Utilisateur tape "bug login"]
   → debounce 400ms (JS géré par le bundle, rien à écrire)
   → POST /_components/TicketListComponent (avec searchTerm=bug login)
   → réhydratation + re-render → getTickets() appelé
   → dispatch ListTicketsQuery('bug login')
   → ListTicketsHandler construit le JQL et interroge Jira
   → réponse HTML re-render
   → morphing DOM (seul le tbody change)
```

## Point d'attention

Pas de cache sur cette query (contrairement aux statuts) : le contenu change à chaque frappe donc le cache n'apporterait rien, sauf si plusieurs utilisateurs tapent souvent les mêmes termes — dans ce cas un cache TTL très court (10-30s) sur le résultat de recherche pourrait avoir du sens si Jira devient un goulot d'étranglement en pratique.

Veux-tu que j'ajoute la pagination (LiveProp `page` + `maxResults`) pour compléter cet exemple ?
