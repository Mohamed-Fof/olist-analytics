"""Tests pytest : un test par contrôle qualité. Ignorés si la base n'est pas disponible (ex. en CI)."""
import pytest

from src.controle_qualite import CONTROLES, lancer


@pytest.fixture(scope="module")
def resultats():
    try:
        return lancer()
    except Exception as erreur:  # base absente ou non remplie
        pytest.skip(f"base de données indisponible : {type(erreur).__name__}")


@pytest.mark.parametrize("nom", list(CONTROLES))
def test_controle(resultats, nom):
    assert resultats[nom] == 0, f"{resultats[nom]} anomalie(s) : {nom}"
