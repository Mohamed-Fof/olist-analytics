"""Configuration centrale : lit DB_URL dans le fichier .env (jamais de mot de passe dans le code)."""
import os

from dotenv import load_dotenv

load_dotenv()

DB_URL = os.getenv("DB_URL")
if not DB_URL:
    raise RuntimeError("DB_URL manquant : renseignez-le dans le fichier .env (voir .env.example).")
