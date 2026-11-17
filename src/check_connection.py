"""Teste la connexion à PostgreSQL et affiche l'encodage de la base.
Usage :  python -m src.check_connection
"""
from sqlalchemy import create_engine, text

from src.config import DB_URL

engine = create_engine(DB_URL)
with engine.connect() as conn:
    version = conn.execute(text("SELECT version()")).scalar()
    encoding = conn.execute(
        text("SELECT pg_encoding_to_char(encoding) FROM pg_database WHERE datname = current_database()")
    ).scalar()
print("Connexion réussie ✔")
print(version)
print("Encodage de la base :", encoding)
