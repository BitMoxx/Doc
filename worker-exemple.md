Voici un exemple complet et concret, en reprenant ton cas de calcul de primes :

## 1. La Command (déclencheur manuel optionnel)

```php
// src/Command/CalculPrimeCommand.php
namespace App\Command;

use App\Message\CalculPrimeMessage;
use Symfony\Component\Console\Attribute\AsCommand;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\Messenger\MessageBusInterface;

#[AsCommand(name: 'app:calcul-prime')]
class CalculPrimeCommand extends Command
{
    public function __construct(
        private MessageBusInterface $bus,
    ) {
        parent::__construct();
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        // Envoie le message dans le bus → le worker le consommera
        $this->bus->dispatch(new CalculPrimeMessage(new \DateTimeImmutable()));

        $output->writeln('Message envoyé !');
        return Command::SUCCESS;
    }
}
```

---

## 2. Le Message (l'objet qui transite)

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

## 3. Le Scheduler (planification automatique)

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
            // Crée et envoie automatiquement le message tous les 1er du mois à 2h
            RecurringMessage::cron(
                '0 2 1 * *',
                new CalculPrimeMessage(new \DateTimeImmutable())
            )
        );
    }
}
```

---

## 4. Le Handler (la logique métier)

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

        $this->logger->info("Début calcul primes pour {$debut->format('Y-m')}");

        // 1. Récupération des commandes
        $commandes = $this->commandeApi->getCommandesByPeriode($debut, $fin);

        // 2. Calcul des primes
        $primes = [];
        foreach ($commandes as $commande) {
            $vendeurId = $commande['vendeur_id'];
            $montant   = $commande['montant'];
            $primes[$vendeurId] = ($primes[$vendeurId] ?? 0) + ($montant * 0.05);
        }

        // 3. Sauvegarde
        foreach ($primes as $vendeurId => $prime) {
            $this->logger->info("Vendeur $vendeurId → prime : {$prime}€");
        }
    }
}
```

---

## Ce qui se passe au runtime

```
1er du mois à 2h
        │
        ▼
  [Scheduler]
  crée CalculPrimeMessage
  l'envoie dans le bus
        │
        ▼
  [Transport BDD/Redis]
  le message attend
        │
        ▼
  [Worker - messenger:consume]
  détecte le message
  appelle CalculPrimeHandler::__invoke()
        │
        ▼
  Appel API → calcul → log
```

Le point clé : **le scheduler et le handler ne se connaissent pas**. Le message est le seul lien entre les deux. Tu peux déclencher le handler de trois façons différentes sans changer une ligne du handler :
- Via le scheduler automatiquement
- Via la command manuellement : `php bin/console app:calcul-prime`
- Via un controller HTTP si besoin en urgence
