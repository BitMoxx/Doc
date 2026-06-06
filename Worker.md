Voilà un exemple complet et concret :

## Structure du projet

```
mon-projet/
├── src/
│   ├── Command/
│   │   └── CalculPrimeCommand.php
│   ├── Message/
│   │   └── CalculPrimeMessage.php
│   ├── MessageHandler/
│   │   └── CalculPrimeHandler.php
│   ├── Schedule/
│   │   └── AppSchedule.php
│   └── Service/
│       └── CommandeApiService.php
├── docker-compose.yml
└── Dockerfile
```

---

## 1. Le Message (l'objet qui transite)

```php
// src/Message/CalculPrimeMessage.php
namespace App\Message;

class CalculPrimeMessage
{
    public function __construct(
        public readonly \DateTimeImmutable $periode,
    ) {}
}
```

---

## 2. Le Service qui appelle l'API

```php
// src/Service/CommandeApiService.php
namespace App\Service;

use Symfony\Contracts\HttpClient\HttpClientInterface;

class CommandeApiService
{
    public function __construct(
        private HttpClientInterface $client,
        private string $apiUrl,  // injecté via services.yaml
    ) {}

    public function getCommandesByPeriode(\DateTimeImmutable $debut, \DateTimeImmutable $fin): array
    {
        $response = $this->client->request('GET', "$this->apiUrl/commandes", [
            'query' => [
                'debut' => $debut->format('Y-m-d'),
                'fin'   => $fin->format('Y-m-d'),
            ],
            'headers' => [
                'Authorization' => 'Bearer ' . $_ENV['API_TOKEN'],
            ]
        ]);

        return $response->toArray(); // retourne un tableau de commandes
    }
}
```

---

## 3. Le Handler (la logique métier)

```php
// src/MessageHandler/CalculPrimeHandler.php
namespace App\MessageHandler;

use App\Message\CalculPrimeMessage;
use App\Service\CommandeApiService;
use Psr\Log\LoggerInterface;
use Symfony\Component\Messenger\Attribute\AsMessageHandler;

#[AsMessageHandler]
class CalculPrimeHandler
{
    public function __construct(
        private CommandeApiService $commandeApi,
        private LoggerInterface $logger,
    ) {}

    public function __invoke(CalculPrimeMessage $message): void
    {
        $debut = $message->periode->modify('first day of this month');
        $fin   = $message->periode->modify('last day of this month');

        $this->logger->info("Calcul des primes pour la période {$debut->format('Y-m')}");

        // 1. Récupération des commandes via API
        $commandes = $this->commandeApi->getCommandesByPeriode($debut, $fin);

        // 2. Calcul des primes par vendeur
        $primes = [];
        foreach ($commandes as $commande) {
            $vendeurId = $commande['vendeur_id'];
            $montant   = $commande['montant'];

            $primes[$vendeurId] = ($primes[$vendeurId] ?? 0) + ($montant * 0.05); // 5% de prime
        }

        // 3. Log ou sauvegarde en BDD
        foreach ($primes as $vendeurId => $prime) {
            $this->logger->info("Vendeur $vendeurId → prime : $prime €");
            // $this->primeRepository->save(new Prime($vendeurId, $prime, $message->periode));
        }
    }
}
```

---

## 4. Le Scheduler (la planification)

```php
// src/Schedule/AppSchedule.php
namespace App\Schedule;

use App\Message\CalculPrimeMessage;
use Symfony\Component\Scheduler\Attribute\AsSchedule;
use Symfony\Component\Scheduler\RecurringMessage;
use Symfony\Component\Scheduler\Schedule;
use Symfony\Component\Scheduler\ScheduleProviderInterface;

#[AsSchedule('default')]
class AppSchedule implements ScheduleProviderInterface
{
    public function getSchedule(): Schedule
    {
        return (new Schedule())->add(
            // Tous les 1er du mois à 2h du matin
            RecurringMessage::cron(
                '0 2 1 * *',
                new CalculPrimeMessage(new \DateTimeImmutable())
            )
        );
    }
}
```

---

## 5. docker-compose.yml

```yaml
services:

  app:
    build: .
    ports:
      - "8080:80"
    environment:
      - DATABASE_URL=${DATABASE_URL}
      - API_TOKEN=${API_TOKEN}
    depends_on:
      - db

  # 👇 Le worker séparé — même image, commande différente
  worker:
    build: .
    command: php bin/console messenger:consume scheduler_default --time-limit=3600 -vv
    restart: unless-stopped
    environment:
      - DATABASE_URL=${DATABASE_URL}
      - API_TOKEN=${API_TOKEN}
    depends_on:
      - db
      - app

  db:
    image: postgres:16
    environment:
      POSTGRES_DB: caisse
      POSTGRES_USER: user
      POSTGRES_PASSWORD: secret
```

---

## Ce que ça donne au runtime

```
┌─────────────────┐        ┌──────────────────────────┐
│  Container app  │        │   Container worker        │
│                 │        │                           │
│  Logiciel caisse│        │  messenger:consume        │
│  API REST       │        │  scheduler_default        │
│  Interface web  │        │                           │
│                 │        │  Chaque 1er du mois :     │
│                 │        │  → appel API commandes    │
│                 │        │  → calcul primes          │
│                 │        │  → sauvegarde BDD         │
└────────┬────────┘        └────────────┬─────────────┘
         │                              │
         └──────────────────────────────┘
                    Même BDD
                    Même code source
                    Zéro duplication
```

---

Le point clé : `build: .` est **identique** pour les deux services. C'est la même image Docker, juste le `command` qui change. Ton équipe obtient la scalabilité voulue (tu peux scaler le worker indépendamment) sans dupliquer une seule ligne de code métier.
