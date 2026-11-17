"""Tests pytest : un test par contrôle qualité (nécessite la base remplie)."""
import pytest

from src.controle_qualite import CONTROLES, lancer


@pytest.fixture(scope="module")
def resultats():
    return lancer()


@pytest.mark.parametrize("nom", list(CONTROLES))
def test_controle(resultats, nom):
    assert resultats[nom] == 0, f"{resultats[nom]} anomalie(s) : {nom}"
