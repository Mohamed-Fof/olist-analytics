"""Phase 10 : contrôles qualité sur l'entrepôt. Chaque contrôle est une requête qui compte les
anomalies : le résultat attendu est 0. Usage :  python -m src.controle_qualite
"""
import sys

from sqlalchemy import text

from src.config import get_engine

CONTROLES = {
    "Commandes : aucun id_commande en double":
        "SELECT count(*) - count(DISTINCT id_commande) FROM dw.faits_commandes",
    "Commandes : aucune date d'achat vide":
        "SELECT count(*) FROM dw.faits_commandes WHERE date_achat IS NULL",
    "Ventes : aucun prix <= 0":
        "SELECT count(*) FROM dw.faits_ventes WHERE prix <= 0",
    "Ventes : aucun frais de port négatif":
        "SELECT count(*) FROM dw.faits_ventes WHERE frais_port < 0",
    "Ventes : aucune vente sans commande":
        "SELECT count(*) FROM dw.faits_ventes v LEFT JOIN dw.faits_commandes c USING (id_commande) "
        "WHERE c.id_commande IS NULL",
    "Ventes : aucun produit inconnu":
        "SELECT count(*) FROM dw.faits_ventes v LEFT JOIN dw.dim_produit p USING (cle_produit) "
        "WHERE p.cle_produit IS NULL",
    "Clients : 1 ligne par personne":
        "SELECT count(*) - count(DISTINCT id_client) FROM dw.dim_client",
    "Avis : note comprise entre 1 et 5":
        "SELECT count(*) FROM dw.faits_commandes WHERE note IS NOT NULL AND note NOT BETWEEN 1 AND 5",
    "Livraison : pas de livraison avant l'achat":
        "SELECT count(*) FROM dw.faits_commandes "
        "WHERE date_livraison_client IS NOT NULL AND date_livraison_client < date_achat",
    "Retard : calculé seulement si la commande est livrée":
        "SELECT count(*) FROM dw.faits_commandes WHERE jours_retard IS NOT NULL AND date_livraison_client IS NULL",
    "Cohérence : CA entrepôt = CA mensuel du mart":
        "SELECT abs((SELECT sum(prix) FROM dw.faits_ventes WHERE vente_valide) "
        "- (SELECT sum(chiffre_affaires) FROM mart.ventes_mensuelles))::int",
    "Cohérence : CA catégories = CA mensuel":
        "SELECT abs((SELECT sum(chiffre_affaires) FROM mart.ventes_categories) "
        "- (SELECT sum(chiffre_affaires) FROM mart.ventes_mensuelles))::int",
    "Rétention : taux entre 0 et 100":
        "SELECT count(*) FROM mart.retention_cohortes WHERE taux_retention_pct NOT BETWEEN 0 AND 100",
    "Staging : aucune ligne en quarantaine":
        "SELECT count(*) FROM staging.rejetees",
}


def lancer() -> dict:
    """Retourne {nom du contrôle: nombre d'anomalies}."""
    resultats = {}
    with get_engine().connect() as conn:
        for nom, sql in CONTROLES.items():
            resultats[nom] = conn.execute(text(sql)).scalar() or 0
    return resultats


if __name__ == "__main__":
    echecs = 0
    for nom, anomalies in lancer().items():
        ok = anomalies == 0
        echecs += not ok
        print(f"  {'✔' if ok else '✘'} {nom}" + ("" if ok else f"  -> {anomalies} anomalie(s)"))
    print(f"\n{len(CONTROLES) - echecs}/{len(CONTROLES)} contrôles réussis")
    sys.exit(1 if echecs else 0)
