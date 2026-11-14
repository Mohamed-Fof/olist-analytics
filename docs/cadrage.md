# Cadrage du projet Olist Analytics

## Contexte
Olist est une place de marché brésilienne qui met en relation de petits vendeurs et des clients.
Le lecteur du dashboard est le directeur e-commerce, qui n'écrit pas de SQL.
Il veut savoir où investir pour augmenter le chiffre d'affaires et améliorer la satisfaction client.
Les décisions concernent le budget marketing, la logistique et la fidélisation.
Les données couvrent environ 100 000 commandes réelles (anonymisées) passées entre 2016 et 2018.

## Questions business
| # | Question | Décision éclairée |
|---|---|---|
| 1 | Comment évoluent les ventes (CA, commandes, panier moyen) ? | Prévisions, budget marketing |
| 2 | Quelles catégories et quelles régions rapportent le plus ? | Où concentrer l'offre et la logistique |
| 3 | Les retards de livraison pénalisent-ils la note client ? | Priorité d'investissement logistique |
| 4 | Quels clients sont les plus précieux ou en train de partir ? | Campagnes CRM ciblées |
| 5 | Quelle part des clients rachète, et après combien de temps ? | Stratégie de fidélisation |

## Définition des indicateurs
| Indicateur | Définition |
|---|---|
| Chiffre d'affaires (CA) | Somme des prix des articles des commandes valides, hors frais de port. Valide = ni `canceled` ni `unavailable`, avec au moins un article. |
| Panier moyen | CA / nombre de commandes valides. |
| Client | Une personne (`customer_unique_id`), pas un `customer_id` (Olist en crée un nouveau à chaque commande). |
| Retard de livraison | Date de livraison réelle − date de livraison estimée, en jours. Plus de 0 = en retard. |
| Taux de retard | Part des commandes livrées avec un retard supérieur à 0. |
| Client fidèle | A passé au moins 2 commandes valides. |
| Rétention à M+n | % des clients d'une cohorte (même mois de 1er achat) qui achètent à nouveau n mois après leur 1er achat. |

## Limites connues
- Pas de coût produit : pas de calcul de marge.
- Données 2016-2018 : 2016 très peu fourni, fin 2018 incomplète.

## Livrables
Pipeline rejouable, entrepôt PostgreSQL, dashboard, tests, README.
