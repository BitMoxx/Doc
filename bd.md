Si, tu peux ! Avec Symfony 7 la commande qui marche est :

```bash
php bin/console doctrine:mapping:import "App\Billing\Domain\Entity" attribute \
  --path=src/Billing/Domain/Entity \
  --filter=Invoice
```

Mais attention, `--filter` prend le **nom de la table** en base, pas le nom de la classe. Donc si ta table s'appelle `invoices` ou `billing_invoice` :

```bash
php bin/console doctrine:mapping:import "App\Billing\Domain\Entity" attribute \
  --path=src/Billing/Domain/Entity \
  --filter=invoices
```

---

**Si ça ne génère rien ou plante**, les causes fréquentes :

**1. Le fichier `Invoice.php` existe déjà** → Doctrine refuse d'écraser, supprime-le ou ajoute `--force`

```bash
... --force
```

**2. Le namespace dans `doctrine.yaml` ne matche pas exactement** → vérifie que le `prefix` correspond pile à ce que tu passes en premier argument

**3. Plusieurs connexions Doctrine** → précise laquelle :

```bash
... --em=default
```

---

Lance d'abord ça pour voir ce que Doctrine détecte :

```bash
php bin/console doctrine:mapping:info
```

Tu devrais voir ta table listée. Quel résultat tu obtiens ?
