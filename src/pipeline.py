"""Phase 11 : orchestration. Reconstruit toute la base de zéro : raw -> staging -> dw -> mart -> contrôles.
Usage :  python -m src.pipeline
S'arrête à la première erreur (code de sortie 1), donc utilisable en tâche planifiée ou en CI.
"""
import sys
import time

from src.controle_qualite import lancer
from src.load_raw import ingest
from src.run_sql import run_sql_file

ETAPES = [
    ("Chargement des CSV dans raw", ingest),
    ("Staging (nettoyage et typage)", lambda: run_sql_file("sql/02_staging.sql")),
    ("Entrepôt en étoile (dw)", lambda: run_sql_file("sql/03_dw.sql")),
    ("Mart (indicateurs)", lambda: run_sql_file("sql/04_mart.sql")),
]


def main() -> int:
    debut = time.time()
    for nom, fonction in ETAPES:
        print(f"\n▶ {nom}")
        t = time.time()
        fonction()
        print(f"  terminé en {time.time() - t:.1f}s")

    print("\n▶ Contrôles qualité")
    resultats = lancer()
    echecs = [nom for nom, n in resultats.items() if n != 0]
    for nom, n in resultats.items():
        print(f"  {'✔' if n == 0 else '✘'} {nom}")
    print(f"\n{len(resultats) - len(echecs)}/{len(resultats)} contrôles réussis "
          f"(pipeline en {time.time() - debut:.0f}s)")
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())
