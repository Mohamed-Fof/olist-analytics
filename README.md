# Olist Analytics

Projet data analyst de bout en bout : de 9 fichiers CSV bruts à un entrepôt PostgreSQL, des indicateurs
métier en SQL avancé, des contrôles qualité et un dashboard Streamlit.

**Données :** [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
(≈ 100 000 commandes, 2016-2018). **Lecteur visé :** le directeur e-commerce, qui n'écrit pas de SQL.

## Architecture (ELT)

```
data/raw/*.csv ──► raw ──► staging ──► dw (étoile) ──► mart ──► dashboard Streamlit
                  brut     nettoyé     faits + dims    indicateurs
                           typé        (français)      par question
                           quarantaine
```

| Schéma | Rôle |
|---|---|
| `raw` | CSV chargés tels quels (texte) |
| `staging` | typage, dédoublonnage des avis, catégorie « inconnue », table `rejetees` (quarantaine) |
| `dw` | étoile : `faits_ventes` (1 ligne par article), `faits_commandes` (1 par commande), `dim_client` (1 par personne), `dim_produit`, `dim_vendeur`, `dim_date` |
| `mart` | une table par question business (SQL avancé : `LAG`, `RANK`, `NTILE`, cohortes) |

## Résultats clés

- **13,49 M R$** de CA valide sur 98 199 commandes (hors annulées et indisponibles), panier moyen ≈ 137 R$.
- **São Paulo** fait ≈ 38 % du CA ; `health_beauty`, `watches_gifts` et `bed_bath_table` dominent.
- **Le retard détruit la satisfaction** : 9 % de mauvaises notes (1-2) à l'heure, plus de 60 % au-delà de 4 jours de retard. 8 % des commandes livrées sont en retard.
- **Fidélisation très faible** : seules 2 997 personnes sur 96 096 ont commandé plus d'une fois ; la rétention à M+1 est inférieure à 1 %.
- Une grande partie des commandes « non livrées » sont en fait **bloquées** depuis des mois (voir [docs/exploration.md](docs/exploration.md)).

## Installation

Prérequis : Python 3.10+, PostgreSQL, les 9 CSV d'Olist dans `data/raw/`.

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env        # puis renseigner DB_URL
createdb olist               # base UTF8, propriétaire olist_user
```

## Utilisation

```bash
python -m src.check_connection   # teste la connexion
python -m src.pipeline           # reconstruit raw → staging → dw → mart + contrôles (≈ 80 s)
python -m src.controle_qualite   # 14 contrôles qualité
python -m pytest -q              # tests
streamlit run app/dashboard.py   # dashboard
```

## Structure

```
sql/        01_schemas, 02_staging, 03_dw, 04_mart
src/        config, load_raw, run_sql, controle_qualite, pipeline, profil_raw
app/        dashboard.py
tests/      tests de structure + un test par contrôle qualité
docs/       cadrage.md (questions et KPI), exploration.md (profilage des données)
```

## Choix de conception

- **ELT** : on charge le brut d'abord, on nettoie en SQL, donc tout est rejouable et traçable.
- **Client = personne** (`customer_unique_id`) : Olist crée un `customer_id` par commande.
- **Vente valide** = ni `canceled` ni `unavailable`, avec au moins un article.
- **Retard** calculé uniquement si la commande est livrée ; les dates vides restent `NULL`.
- **Quarantaine** (`staging.rejetees`) plutôt que suppression silencieuse (vide ici : les données sont propres).

## Limites

Pas de coût produit (donc pas de marge) ; 2016 très peu fourni et fin 2018 incomplète ; le CSV de géolocalisation n'est pas encore exploité dans le dashboard (pas de carte).
