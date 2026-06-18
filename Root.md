Voici un exemple concret d’Aggregate Root Order en Symfony avec DDD :

L’Aggregate Root

// src/Domain/Order/Order.php

namespace App\Domain\Order;

use App\Domain\Order\Event\OrderPlaced;
use App\Domain\Order\Event\OrderLineAdded;
use App\Domain\Order\ValueObject\OrderId;
use App\Domain\Order\ValueObject\CustomerId;
use App\Domain\Order\ValueObject\Money;

final class Order
{
    private OrderId $id;
    private CustomerId $customerId;
    private OrderStatus $status;
    private array $orderLines = [];
    private Money $total;
    private array $domainEvents = [];

    private function __construct(OrderId $id, CustomerId $customerId)
    {
        $this->id = $id;
        $this->customerId = $customerId;
        $this->status = OrderStatus::DRAFT;
        $this->total = Money::zero();
    }

    public static function place(OrderId $id, CustomerId $customerId): self
    {
        $order = new self($id, $customerId);
        $order->recordEvent(new OrderPlaced($id, $customerId));

        return $order;
    }

    public function addLine(ProductId $productId, int $quantity, Money $unitPrice): void
    {
        if ($this->status !== OrderStatus::DRAFT) {
            throw new \DomainException('Cannot modify a non-draft order.');
        }

        $line = OrderLine::create($productId, $quantity, $unitPrice);
        $this->orderLines[] = $line;
        $this->total = $this->total->add($line->subtotal());

        $this->recordEvent(new OrderLineAdded($this->id, $productId, $quantity));
    }

    public function confirm(): void
    {
        if (empty($this->orderLines)) {
            throw new \DomainException('Cannot confirm an empty order.');
        }

        $this->status = OrderStatus::CONFIRMED;
        $this->recordEvent(new OrderConfirmed($this->id));
    }

    // --- Domain Events ---

    private function recordEvent(object $event): void
    {
        $this->domainEvents[] = $event;
    }

    public function pullDomainEvents(): array
    {
        $events = $this->domainEvents;
        $this->domainEvents = [];

        return $events;
    }

    // --- Getters ---

    public function id(): OrderId { return $this->id; }
    public function status(): OrderStatus { return $this->status; }
    public function total(): Money { return $this->total; }
}


Les entités enfants (dans l’agrégat)

// src/Domain/Order/OrderLine.php

namespace App\Domain\Order;

final class OrderLine
{
    private ProductId $productId;
    private int $quantity;
    private Money $unitPrice;

    private function __construct(ProductId $productId, int $quantity, Money $unitPrice)
    {
        if ($quantity <= 0) {
            throw new \DomainException('Quantity must be positive.');
        }

        $this->productId = $productId;
        $this->quantity = $quantity;
        $this->unitPrice = $unitPrice;
    }

    public static function create(ProductId $productId, int $quantity, Money $unitPrice): self
    {
        return new self($productId, $quantity, $unitPrice);
    }

    public function subtotal(): Money
    {
        return $this->unitPrice->multiply($this->quantity);
    }
}


Value Objects

// src/Domain/Order/ValueObject/Money.php

namespace App\Domain\Order\ValueObject;

final class Money
{
    private function __construct(
        private readonly int $amount,   // en centimes
        private readonly string $currency
    ) {}

    public static function of(int $amount, string $currency): self
    {
        return new self($amount, $currency);
    }

    public static function zero(): self
    {
        return new self(0, 'EUR');
    }

    public function add(self $other): self
    {
        if ($this->currency !== $other->currency) {
            throw new \DomainException('Currency mismatch.');
        }

        return new self($this->amount + $other->amount, $this->currency);
    }

    public function multiply(int $factor): self
    {
        return new self($this->amount * $factor, $this->currency);
    }

    public function amount(): int { return $this->amount; }
    public function currency(): string { return $this->currency; }
}


Le Command + Handler (Application Layer)

// src/Application/Order/Command/PlaceOrderCommand.php

final class PlaceOrderCommand
{
    public function __construct(
        public readonly string $orderId,
        public readonly string $customerId,
        public readonly array $lines   // [['productId' => ..., 'qty' => ..., 'price' => ...]]
    ) {}
}


// src/Application/Order/Command/PlaceOrderCommandHandler.php

final class PlaceOrderCommandHandler
{
    public function __construct(
        private OrderRepository $orderRepository,
        private EventBus $eventBus
    ) {}

    public function __invoke(PlaceOrderCommand $command): void
    {
        $order = Order::place(
            OrderId::fromString($command->orderId),
            CustomerId::fromString($command->customerId)
        );

        foreach ($command->lines as $line) {
            $order->addLine(
                ProductId::fromString($line['productId']),
                $line['qty'],
                Money::of($line['price'], 'EUR')
            );
        }

        $order->confirm();

        $this->orderRepository->save($order);

        // Dispatch des domain events
        foreach ($order->pullDomainEvents() as $event) {
            $this->eventBus->dispatch($event);
        }
    }
}


Points clés

|Concept             |Rôle                                                                     |
|--------------------|-------------------------------------------------------------------------|
|`Order`             |Aggregate Root — seul point d’entrée pour modifier l’agrégat             |
|`OrderLine`         |Entité enfant — jamais accédée directement depuis l’extérieur            |
|`Money`             |Value Object — immutable, sans identité                                  |
|`OrderStatus`       |Enum — protège les transitions d’état                                    |
|`pullDomainEvents()`|Pattern pour collecter les événements et les dispatcher après le `save()`|

L’invariant clé : tout passe par Order. On ne manipule jamais OrderLine directement depuis le handler.
