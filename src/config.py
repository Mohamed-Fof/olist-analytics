"""Configuration centrale : lit DB_URL dans le fichier .env (jamais de mot de passe dans le code)."""
import os
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy import create_engine

ROOT = Path(__file__).resolve().parent.parent
load_dotenv(ROOT / ".env")

DB_URL = os.getenv("DB_URL")


def get_engine():
    if not DB_URL:
        raise RuntimeError("DB_URL manquant : renseignez-le dans le fichier .env (voir .env.example).")
    return create_engine(DB_URL)
