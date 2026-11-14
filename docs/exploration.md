# Journal d'exploration

## Phase 3 : première observation de `olist_orders_dataset.csv`

Fichier : 99 441 commandes, 8 colonnes (dont 5 dates : achat, validation, remise au transporteur,
livraison client, livraison estimée).
Les numéros de ligne ci-dessous sont ceux du fichier ouvert dans VS Code (la ligne 1 est l'en-tête).

### Commandes non livrées repérées à la main

| Ligne | Statut | Dates présentes | Dates vides |
|---|---|---|---|
| 8 | invoiced | achat, validation, estimée | transporteur, livraison client |
| 46 | shipped | achat, validation, transporteur, estimée | livraison client |
| 105 | invoiced | achat, validation, estimée | transporteur, livraison client |
| 130 | processing | achat, validation, estimée | transporteur, livraison client |
| 156 | shipped | achat, validation, transporteur, estimée | livraison client |
| 164 | shipped | achat, validation, transporteur, estimée | livraison client |
| 233 | shipped | achat, validation, transporteur, estimée | livraison client |
| 268 | unavailable | achat, validation, estimée | transporteur, livraison client |
| 301 | shipped | achat, validation, transporteur, estimée | livraison client |
| 307 | shipped | achat, validation, transporteur, estimée | livraison client |
| 326 | processing | achat, validation, estimée | transporteur, livraison client |

### Ce que je constate
Les dates se remplissent dans l'ordre du cycle de vie de la commande :
achat → validation → remise au transporteur → livraison au client.
Une commande non livrée s'arrête à une étape, et **toutes les dates suivantes sont vides**.
Les valeurs vides sont donc normales : elles signifient « cette étape n'a pas eu lieu ».
La date estimée de livraison est, elle, toujours renseignée.

Trois profils se distinguent selon la dernière étape atteinte :
- `invoiced` / `processing` / `unavailable` : validée mais jamais remise au transporteur (2 dates vides).
- `shipped` : remise au transporteur mais jamais livrée (1 date vide).
- Cas suspect : la ligne 164 est `shipped` depuis mai 2017 avec une livraison estimée au 2017-06-08.
  Les données s'arrêtent en 2018 : cette commande n'est probablement jamais arrivée (colis perdu) ou le statut
  n'a jamais été mis à jour. Un `shipped` ancien n'est donc pas « en cours », c'est un problème de livraison.
  La ligne 326 (`processing` depuis octobre 2016) est dans le même cas.
  Mesure : la dernière commande du fichier date du 2018-10-17, et pourtant 1 013 des 1 107 `shipped`,
  300 des 301 `processing` et 280 des 314 `invoiced` avaient une livraison estimée avant août 2018.
  La grande majorité de ces commandes « non livrées » sont donc bloquées, pas en cours.

### Mesure sur tout le fichier (dates vides par statut)

| Statut | Commandes | Sans date transporteur | Sans date livraison client |
|---|---|---|---|
| delivered | 96 478 | 2 | 8 |
| shipped | 1 107 | 0 | 1 107 |
| canceled | 625 | 550 | 619 |
| unavailable | 609 | 609 | 609 |
| invoiced | 314 | 314 | 314 |
| processing | 301 | 301 | 301 |
| created | 5 | 5 | 5 |
| approved | 2 | 2 | 2 |

### Anomalies à garder en tête pour la phase 6
- 8 commandes `delivered` n'ont pas de date de livraison client, et 2 n'ont pas de date de transporteur.
  Une commande livrée sans date de livraison est incohérente.
  Conséquence : leur retard de livraison ne peut pas être calculé (valeur vide).
- 14 commandes `delivered` n'ont pas de date de validation.
- Seules les commandes avec une date de livraison client permettent de calculer un retard.

### Décision provisoire
On garde tous les statuts dans l'entrepôt. Les dates vides restent `NULL` (on ne les remplace pas).
Les retards sont calculés uniquement quand la date de livraison existe.

## Phase 6 : profilage SQL (à compléter)

| Constat | Mesure (mes chiffres) | Décision |
|---|---|---|
| Dates d'achat vides ou invalides | ... | Rejeter la commande → quarantaine |
| Commande dont le client n'existe pas | ... | Rejeter → quarantaine |
| Articles à prix ≤ 0 | ... | Rejeter → quarantaine |
| review_id en double | ... | Garder 1 avis par commande (le plus récent) |
| Produits sans catégorie / sans traduction | ... | Conserver, catégorie « unknown » |
| Commandes sans article | ... | Conserver, marquer « vente non valide » |
| Clients : 1 ligne par commande | ... | Dimension client = personne (customer_unique_id) |
