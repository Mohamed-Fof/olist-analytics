"""Exécute un fichier SQL sur la base.
Usage :  python -m src.run_sql sql/02_staging.sql
"""
import sys
from pathlib import Path

from src.config import ROOT, get_engine


def run_sql_file(path: str | Path) -> None:
    path = Path(path)
    if not path.is_absolute():
        path = ROOT / path
    with get_engine().begin() as conn:       # tout ou rien : une erreur annule tout
        conn.exec_driver_sql(path.read_text())
    print(f"✔ {path.name} exécuté")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Usage : python -m src.run_sql sql/XX_fichier.sql")
    run_sql_file(sys.argv[1])
