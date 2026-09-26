---
name: clean-architecture
description: Apply and review Clean Architecture, Domain-Driven Design (DDD), and CQRS principles in PHP (framework-agnostic, with Symfony notes). Use this skill whenever the user asks to design, generate, structure, or scaffold code following Clean Architecture / hexagonal architecture / DDD / CQRS, or whenever they ask you to review, audit, or critique existing code against these principles (layering violations, entity leakage, anemic domain models, misplaced business logic, Command/Query mixing). Trigger even if the user doesn't say "clean architecture" explicitly but describes symptoms like "my controller does everything", "how do I separate my business logic from my framework", "where should this validation live", "is this a good domain model", or mentions Value Objects, Aggregates, Repositories, Bounded Contexts, Use Cases, Handlers, or Ports/Adapters.
---

# Clean Architecture / DDD / CQRS

A skill for two jobs: **generating** new code that follows Clean Architecture, DDD and CQRS,
and **reviewing** existing code against those same principles. Figure out which job the user
needs (or both) before doing anything else.

This skill is deliberately **generic / standards-based** — it does not assume any one
project's personal conventions. If the user has their own established conventions in a
given codebase, prefer consistency with that codebase over the generic recommendations here,
and say so explicitly when the two diverge.

---

## 1. The core mental model

Four concentric layers, dependencies only point **inward** (toward the Domain):

```
┌─────────────────────────────────────────────┐
│ Infrastructure (DB, HTTP clients, framework) │
│  ┌─────────────────────────────────────┐    │
│  │ Presentation (Controllers, CLI, API)  │    │
│  │  ┌─────────────────────────────┐     │    │
│  │  │ Application (Use Cases /    │     │    │
│  │  │ Commands, Queries, Handlers)│     │    │
│  │  │  ┌───────────────────┐     │     │    │
│  │  │  │ Domain (Entities,  │     │     │    │
│  │  │  │ Value Objects,     │     │     │    │
│  │  │  │ Aggregates,        │     │     │    │
│  │  │  │ Domain Services,   │     │     │    │
│  │  │  │ Repository interfaces)│  │     │    │
│  │  │  └───────────────────┘     │     │    │
│  │  └─────────────────────────────┘     │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

**The Dependency Rule**: source code dependencies only point inward. The Domain knows
nothing about Application, Presentation, or Infrastructure. Application knows the Domain
but not Presentation or Infrastructure. This is enforced through **interfaces defined in
the inner layer, implemented in the outer layer** (Dependency Inversion).

| Layer | Contains | Depends on | Knows about frameworks? |
|---|---|---|---|
| Domain | Entities, Value Objects, Aggregates, Domain Events, Domain Services, Repository *interfaces* | Nothing | No |
| Application | Commands, Queries, Handlers/Use Cases, Application Services, DTOs | Domain only | No (or minimally — e.g. plain PHP attributes) |
| Presentation | Controllers, CLI commands, API resources, Presenters/ViewModels | Application | Yes (routing, request/response) |
| Infrastructure | Repository implementations, ORM mappings, HTTP clients, mailers, framework wiring | Application + Domain (implements their interfaces) | Yes, fully |

If in doubt about where something belongs, ask: **"Would this code change if I swapped
Symfony for Laravel, or MySQL for MongoDB?"** If yes → Infrastructure/Presentation. If
no → Domain/Application.

---

## 2. DDD building blocks (Domain layer)

- **Entity**: has identity (an ID) that persists across state changes. Two entities with
  identical attributes but different IDs are different entities. Behavior lives on the
  entity, not in a service that mutates its public properties.
- **Value Object (VO)**: no identity, defined entirely by its attributes, **immutable**.
  Two VOs with the same attributes are equal. Use VOs for anything with validation rules
  or intrinsic meaning: `Email`, `Money`, `Siren`, `DateRange` — not just primitives.
  Validate in the constructor; an invalid VO should be impossible to construct.
- **Aggregate**: a cluster of entities/VOs treated as one consistency boundary, with a
  single **Aggregate Root** as the only entry point for external access. Invariants that
  must always hold true are enforced inside the aggregate, not by callers.
- **Domain Service**: stateless logic that doesn't naturally belong to one entity (e.g.
  logic spanning two aggregates). Last resort — prefer putting behavior on the entity/VO
  first.
- **Domain Event**: something that happened in the domain (`OrderPlaced`, `UserRegistered`).
  Raised by aggregates, handled by listeners in Application/Infrastructure. Keeps the
  Domain from having to know who reacts to what.
- **Repository interface**: defined in the Domain (or Application, depending on the
  variant), expressed in domain language (`findActiveCustomerByEmail`, not
  `findOneBy(['status' => 1])`). The implementation (Doctrine, raw SQL, HTTP...) lives in
  Infrastructure.

**Anti-pattern to flag on review — the Anemic Domain Model**: entities that are just
public getters/setters with all logic living in "Service" classes. This isn't OOP, it's
procedural code wearing a class costume. Push behavior onto the entity/VO wherever the
data and the logic naturally belong together.

---

## 3. CQRS (Application layer)

Separate **writes** (Commands) from **reads** (Queries). They have different needs and
shouldn't share a model.

- **Command**: expresses intent to change state (`RegisterUserCommand`,
  `PlaceOrderCommand`). Named as an imperative verb + noun. Carries only the data needed
  to perform the action. Has **one** handler. Typically returns nothing or just an ID —
  never a fat DTO with everything the UI might want.
- **Command Handler**: loads the aggregate (via repository), calls domain methods,
  persists, dispatches domain events. Contains orchestration, not business rules —
  business rules live in the Domain.
- **Query**: expresses a request for data (`GetUserProfileQuery`,
  `SearchProductsQuery`). Read-only, no side effects.
- **Query Handler**: can bypass the domain model entirely and read straight from a
  read-optimized source (a dedicated read model, a view, a projection, raw SQL) — this is
  legitimate and often preferable to reusing write-side aggregates for reads.
- **Result / ReadModel**: a plain DTO returned by a query handler. Not a domain entity —
  don't leak Doctrine entities or aggregates out of the Application layer.

**Anti-pattern to flag on review**: a single "Service" class with a `create()`,
`update()`, `find()`, `search()` grab-bag of methods — this defeats the purpose of CQRS
and tends to grow unmanageably. Each use case gets its own Command/Query + Handler.

**When CQRS might be overkill**: a genuinely small CRUD-only project might not need full
Command/Query separation with buses. It's fine to say so — Clean Architecture and DDD are
tools for managing complexity, not a checklist to apply regardless of the project's size.

---

## 4. Presentation layer

- Controllers/CLI commands are **thin**: parse input → build a Command/Query → dispatch
  → format the response. No business logic, no direct ORM/repository calls.
- A **Presenter** (if used) takes the Application layer's Result/ReadModel and turns it
  into a ViewModel (formatted strings, translated labels, CSS classes) — this is display
  logic, not business logic, and it belongs here, not in the Domain or Application.
- Validation of *input shape* (is this a valid email string?) can live in the
  Presentation layer (form/request validation). Validation of *business rules* (is this
  email already taken? is this order allowed given the customer's status?) belongs in the
  Domain/Application.

---

## 5. Infrastructure layer

- Repository implementations, ORM entity mappings, external API clients (payment
  gateways, mail providers), file storage, caching.
- Framework-specific code lives here and only here, as much as practical.
- An Infrastructure adapter that calls an external API should: translate the API's error
  codes into **domain exceptions** (not leak the API's raw exception type upward), and
  log the raw response separately from throwing a clean, domain-meaningful error to the
  caller.

---

## 6. Generating code — workflow

1. Identify the use case in one sentence ("register a customer", "search products in
   stock").
2. Decide: is this a write (→ Command) or a read (→ Query)?
3. Sketch the Domain first: what Entity/VO/Aggregate does this touch? What invariant
   does it protect? Does a new VO make sense for any primitive being passed around
   (an ID, an amount, a code)?
4. Write the Command/Query + its Handler in Application. The handler should read like
   a short paragraph: load → decide (delegate to domain) → persist → (dispatch events).
5. Write the Repository interface in Domain/Application if it doesn't exist yet; the
   implementation goes in Infrastructure.
6. Write the thin Controller/CLI entry point in Presentation.
7. If returning data to a UI, define an explicit Result/ReadModel — never return the
   Entity/Aggregate directly across the Application boundary.

Ask the user for the target language/framework if not stated (PHP is the default given
context, but confirm Symfony vs. framework-agnostic before assuming Symfony-specific
syntax like attributes, autowiring, or Doctrine).

---

## 7. Reviewing code — checklist

Walk the code against these questions, in order, and report violations with the specific
line/class and a one-line fix suggestion. Don't just say "this violates Clean
Architecture" — name which layer, which rule, and what to change.

1. **Dependency direction**: does anything in Domain import Infrastructure/Presentation
   code, a framework class, an ORM annotation, or an HTTP-layer type? → violation.
2. **Entity leakage**: does a Controller, a Twig/Blade template, or an API response
   receive a raw Doctrine/Eloquent entity instead of a DTO/ReadModel? → violation.
3. **Anemic domain**: are there "Service" classes doing what should be entity/VO
   methods, with entities reduced to getters/setters? → flag, not always a hard
   violation, but worth raising.
4. **Fat controllers**: does the controller contain conditionals, loops, calculations,
   or direct repository/ORM calls beyond wiring? → violation.
5. **Command/Query mixing**: does one "handler" or "service" both mutate state and
   return a rich read model? → violation, suggest splitting.
6. **Validation placement**: is business-rule validation (uniqueness, cross-entity
   invariants) sitting in a framework-level annotation/constraint instead of the
   Domain? → flag as a design smell even if it "works".
7. **Repository interface location**: is the interface defined in Infrastructure
   instead of Domain/Application, or referenced by concrete implementation type
   instead of interface? → violation (breaks Dependency Inversion).

End every review with: (a) a short list of the most important 1–3 issues to fix first
(not an exhaustive nitpick list), and (b) an explicit note on anything that's a
judgment call rather than a hard rule, since Clean Architecture has legitimate variants.

---

## 8. Things to actively avoid

- Don't cargo-cult layers onto a trivial script or a 3-endpoint prototype — say so if
  the ask doesn't warrant the ceremony.
- Don't invent framework-specific magic (bundle names, annotations) unless the user
  confirmed the framework.
- Don't present one "true" Clean Architecture — DDD/CQRS/Hexagonal have real variants
  (e.g. repository interface in Domain vs. Application, Ports & Adapters vs. classic
  4-layer). Say which variant you're using if it matters to the answer.
