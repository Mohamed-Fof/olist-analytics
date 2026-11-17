"""Tests sans base de données : structure du projet."""
from src.controle_qualite import CONTROLES
from src.load_raw import FILES
from src.pipeline import ETAPES


def test_neuf_fichiers_sources():
    assert len(FILES) == 9


def test_controles_sont_des_selections():
    assert all(sql.lstrip().upper().startswith("SELECT") for sql in CONTROLES.values())


def test_ordre_pipeline():
    noms = [nom for nom, _ in ETAPES]
    assert noms[0].startswith("Chargement") and noms[-1].startswith("Mart")
