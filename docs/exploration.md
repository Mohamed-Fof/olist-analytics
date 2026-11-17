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

## Phase 6 : profilage SQL (requêtes dans `olist.session.sql`, graphiques via `python -m src.profil_raw`)

| Constat | Mesure (mes chiffres) | Décision |
|---|---|---|
| Doublons de commandes | 99 441 lignes, 99 441 `order_id` distincts : 0 doublon | Aucune action |
| Dates d'achat vides ou invalides | 0 vide, 0 au mauvais format | Rien à rejeter, mais on garde la règle en staging |
| Commande dont le client n'existe pas | 0 | Rien à rejeter, on garde la règle en staging |
| Articles à prix ≤ 0 | 0 | Rien à rejeter, on garde la règle en staging |
| review_id en double | 814 en trop (1 603 lignes concernées) | Garder 1 avis par commande (le plus récent) |
| Produits sans catégorie | 610 | Conserver, catégorie « unknown » |
| Catégories sans traduction | 2 catégories (13 produits) : `portateis_cozinha_e_preparadores_de_alimentos`, `pc_gamer` | Conserver, utiliser le nom portugais |
| Commandes sans article | 775 (603 unavailable, 164 canceled, 5 created, 2 invoiced, 1 shipped) | Conserver, marquer « vente non valide » |
| Clients : 1 ligne par commande | 99 441 `customer_id` pour 96 096 personnes ; 2 997 personnes ont plus d'une commande | Dimension client = personne (`customer_unique_id`) |
| Dates de livraison client vides | 2 965 (dont ~2 957 non livrées, 8 `delivered`) | Garder NULL, retard calculé seulement si la date existe |
| Dates de remise transporteur vides | 1 783 | Garder NULL |
| Période couverte | achats du 2016-09-04 au 2018-10-17 ; 2016 quasi vide (4 commandes en sept., 1 en déc.) | Analyser surtout 2017-2018 |

### Lecture
- Les données sont **plutôt propres** : aucune commande orpheline, aucun prix ≤ 0, aucun doublon de commande.
  Les vrais problèmes sont les avis en double, les produits sans catégorie et les commandes sans article.
- Les 775 commandes sans article sont presque toutes `unavailable` ou `canceled` : elles ne comptent pas dans le CA.
- Seuls 3 % des `customer_id` sont des clients qui reviennent (2 997 personnes sur 96 096) : la rétention sera faible.

### Graphiques (générés dans `reports/`, non versionnés)
`statuts.html`, `problemes_qualite.html`, `commandes_par_mois.html`.
