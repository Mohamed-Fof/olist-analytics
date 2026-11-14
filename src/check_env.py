"""Vérifie quelles bibliothèques sont DÉJÀ installées et affiche la commande pour installer seulement
celles qui manquent.
Usage :  python -m src.check_env
"""
import importlib
import sys

REQUIRED = {  # nom du module à importer -> nom du paquet pip
    "pandas": "pandas",
    "sqlalchemy": "sqlalchemy",
    "psycopg2": "psycopg2-binary",
    "dotenv": "python-dotenv",
    "streamlit": "streamlit",
    "plotly": "plotly",
    "pytest": "pytest",
}

print(f"Python {sys.version.split()[0]}  ({sys.executable})")
if sys.version_info < (3, 10):
    print("⚠ Python 3.10 ou plus récent est recommandé (3.11 ou 3.12 idéal).")
missing = []
for module, package in REQUIRED.items():
    try:
        m = importlib.import_module(module)
        print(f"  ✔ {package:<18} {getattr(m, '__version__', '')}")
    except ImportError:
        print(f"  ✘ {package:<18} MANQUANT")
        missing.append(package)
if missing:
    print("\nPour installer seulement ce qui manque :\n  pip install " + " ".join(missing))
else:
    print("\nTout est installé ✔")
