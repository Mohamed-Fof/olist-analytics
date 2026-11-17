"""Exporte les petites tables du mart en CSV (data/mart/) pour héberger le dashboard sans base de données.
Usage :  python -m src.exporter_mart
"""
import pandas as pd

from src.config import ROOT, get_engine

TABLES = ["ventes_mensuelles", "ventes_categories", "ventes_regions",
          "retard_et_note", "resume_segments", "retention_cohortes"]

if __name__ == "__main__":
    sortie = ROOT / "data" / "mart"
    sortie.mkdir(parents=True, exist_ok=True)
    engine = get_engine()
    for table in TABLES:
        df = pd.read_sql(f"SELECT * FROM mart.{table}", engine)
        df.to_csv(sortie / f"{table}.csv", index=False)
        print(f"  {table:<22} {len(df):>5} lignes")
    print(f"Exporté dans {sortie}")
