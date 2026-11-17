"""Phase 6 : profilage de raw avec pandas + graphiques Plotly (fichiers HTML dans reports/).
Usage :  python -m src.profil_raw
"""
import pandas as pd
import plotly.express as px

from src.config import ROOT, get_engine

OUT = ROOT / "reports"
OUT.mkdir(exist_ok=True)
engine = get_engine()


def q(sql: str) -> pd.DataFrame:
    return pd.read_sql(sql, engine)


# 1. Statuts des commandes
statuts = q("SELECT order_status, COUNT(*) AS n FROM raw.orders GROUP BY 1 ORDER BY n DESC")
px.bar(statuts, x="order_status", y="n", text="n", log_y=True,
       title="Commandes par statut (échelle log)").write_html(OUT / "statuts.html")

# 2. Problèmes de qualité mesurés
problemes = q("""
SELECT 'Avis en double (review_id)' AS probleme, COUNT(*) - COUNT(DISTINCT review_id) AS n FROM raw.reviews
UNION ALL SELECT 'Commandes sans article', COUNT(*) FROM raw.orders o
          WHERE NOT EXISTS (SELECT 1 FROM raw.order_items i WHERE i.order_id = o.order_id)
UNION ALL SELECT 'Produits sans catégorie', COUNT(*) FROM raw.products WHERE product_category_name IS NULL
UNION ALL SELECT 'Produits sans traduction de catégorie', COUNT(*) FROM raw.products p
          LEFT JOIN raw.category_translation t USING (product_category_name)
          WHERE t.product_category_name IS NULL AND p.product_category_name IS NOT NULL
UNION ALL SELECT 'Commandes sans date de livraison client', COUNT(*) FROM raw.orders
          WHERE order_delivered_customer_date IS NULL
UNION ALL SELECT 'Commandes sans date de remise transporteur', COUNT(*) FROM raw.orders
          WHERE order_delivered_carrier_date IS NULL
""").sort_values("n")
px.bar(problemes, x="n", y="probleme", orientation="h", text="n",
       title="Problèmes de qualité dans raw").write_html(OUT / "problemes_qualite.html")

# 3. Clients : commandes vs personnes réelles
clients = q("SELECT COUNT(*) AS commandes_customer_id, COUNT(DISTINCT customer_unique_id) AS personnes FROM raw.customers")
print(clients.T)

# 4. Commandes par mois (la période réellement couverte)
mois = q("""SELECT to_char(order_purchase_timestamp::timestamp, 'YYYY-MM') AS mois, COUNT(*) AS n
            FROM raw.orders GROUP BY 1 ORDER BY 1""")
px.bar(mois, x="mois", y="n", title="Commandes par mois d'achat").write_html(OUT / "commandes_par_mois.html")

print(problemes.to_string(index=False))
print(f"Graphiques enregistrés dans {OUT}")
