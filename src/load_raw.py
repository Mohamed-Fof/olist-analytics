"""Phase 5 : charge les CSV bruts dans le schéma raw (tout en texte, aucun nettoyage).
Usage :  python -m src.load_raw
"""
import sys
import time
from pathlib import Path

import pandas as pd

from src.config import ROOT, get_engine

FILES = {
    "customers": "olist_customers_dataset.csv",
    "orders": "olist_orders_dataset.csv",
    "order_items": "olist_order_items_dataset.csv",
    "payments": "olist_order_payments_dataset.csv",
    "reviews": "olist_order_reviews_dataset.csv",
    "products": "olist_products_dataset.csv",
    "sellers": "olist_sellers_dataset.csv",
    "geolocation": "olist_geolocation_dataset.csv",
    "category_translation": "product_category_name_translation.csv",
}


def ingest(raw_dir: Path = ROOT / "data" / "raw") -> dict:
    missing = [f for f in FILES.values() if not (raw_dir / f).exists()]
    if missing:
        sys.exit(f"Fichiers CSV manquants dans {raw_dir} : {missing}")

    engine = get_engine()
    with engine.begin() as conn:
        conn.exec_driver_sql((ROOT / "sql" / "01_schemas.sql").read_text())

    counts = {}
    for table, filename in FILES.items():
        start = time.time()
        # dtype=str : on garde les valeurs brutes, le typage se fera en staging
        df = pd.read_csv(raw_dir / filename, dtype=str, keep_default_na=False, na_values=[""])
        df.to_sql(table, engine, schema="raw", if_exists="replace", index=False,
                  chunksize=10_000, method="multi")
        counts[table] = len(df)
        print(f"  raw.{table:<22} {len(df):>9,} lignes  ({time.time() - start:.1f}s)".replace(",", " "))
    return counts


if __name__ == "__main__":
    print("Chargement des CSV dans le schéma raw :")
    ingest()
    print("Terminé ✔")
