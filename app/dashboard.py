"""Phase 12 : dashboard Streamlit pour le directeur e-commerce (lit uniquement le schéma mart).
Usage :  streamlit run app/dashboard.py
"""
import sys
from pathlib import Path

import pandas as pd
import plotly.express as px
import streamlit as st

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from src.config import DB_URL, get_engine  # noqa: E402

DOSSIER_MART = Path(__file__).resolve().parent.parent / "data" / "mart"

st.set_page_config(page_title="Olist Analytics", page_icon="📊", layout="wide")


@st.cache_data(ttl=600)
def charger(table: str) -> pd.DataFrame:
    """Lit la base si DB_URL est défini (usage local), sinon les CSV exportés (version en ligne)."""
    if DB_URL:
        try:
            return pd.read_sql(f"SELECT * FROM mart.{table}", get_engine())
        except Exception:
            pass
    return pd.read_csv(DOSSIER_MART / f"{table}.csv")


def euros(x: float) -> str:
    return f"{x:,.0f}".replace(",", " ") + " R$"


st.title("📊 Olist Analytics")
st.caption("Ventes d'une place de marché brésilienne, 2016-2018. Ventes valides : hors commandes annulées ou indisponibles.")

try:
    mensuel = charger("ventes_mensuelles")
except Exception:
    st.error("Données indisponibles. Lancez d'abord : `python -m src.pipeline` puis `python -m src.exporter_mart`.")
    st.stop()

# Le début (2016) et la fin (fin 2018) sont incomplets : on propose de les exclure
complet = st.sidebar.checkbox("Exclure les mois incomplets (2016 et après août 2018)", value=True)
if complet:
    mensuel = mensuel[(mensuel.annee_mois >= "2017-01") & (mensuel.annee_mois <= "2018-08")]

c1, c2, c3 = st.columns(3)
c1.metric("Chiffre d'affaires", euros(mensuel.chiffre_affaires.sum()))
c2.metric("Commandes", f"{int(mensuel.nb_commandes.sum()):,}".replace(",", " "))
c3.metric("Panier moyen", f"{mensuel.chiffre_affaires.sum() / mensuel.nb_commandes.sum():.0f} R$")

onglets = st.tabs(["Ventes", "Catégories et régions", "Retards et satisfaction", "Clients", "Fidélisation"])

with onglets[0]:
    st.subheader("Comment évoluent les ventes ?")
    st.plotly_chart(px.bar(mensuel, x="annee_mois", y="chiffre_affaires",
                           labels={"annee_mois": "Mois", "chiffre_affaires": "CA (R$)"}), width="stretch")
    st.plotly_chart(px.line(mensuel, x="annee_mois", y="panier_moyen", markers=True,
                            labels={"annee_mois": "Mois", "panier_moyen": "Panier moyen (R$)"}), width="stretch")

with onglets[1]:
    gauche, droite = st.columns(2)
    cat = charger("ventes_categories").sort_values("rang").head(10)
    reg = charger("ventes_regions").sort_values("rang").head(10)
    gauche.subheader("Top 10 catégories")
    gauche.plotly_chart(px.bar(cat.iloc[::-1], x="chiffre_affaires", y="categorie", orientation="h",
                               labels={"chiffre_affaires": "CA (R$)", "categorie": ""}), width="stretch")
    droite.subheader("Top 10 états")
    droite.plotly_chart(px.bar(reg.iloc[::-1], x="chiffre_affaires", y="etat", orientation="h",
                               labels={"chiffre_affaires": "CA (R$)", "etat": ""}), width="stretch")

with onglets[2]:
    st.subheader("Les retards pénalisent-ils la note ?")
    rn = charger("retard_et_note").sort_values("tranche_retard")
    a, b = st.columns(2)
    a.plotly_chart(px.bar(rn, x="tranche_retard", y="note_moyenne", range_y=[1, 5],
                          labels={"tranche_retard": "", "note_moyenne": "Note moyenne"}), width="stretch")
    b.plotly_chart(px.bar(rn, x="tranche_retard", y="part_mauvaises_notes_pct",
                          labels={"tranche_retard": "", "part_mauvaises_notes_pct": "% de notes 1 ou 2"}), width="stretch")
    st.info("Au-delà de 4 jours de retard, la grande majorité des clients donnent une mauvaise note.")

with onglets[3]:
    st.subheader("Segments de clients")
    resume = charger("resume_segments").rename(columns={"chiffre_affaires": "ca"})
    a, b = st.columns(2)
    a.plotly_chart(px.pie(resume, names="segment", values="clients", hole=0.4), width="stretch")
    b.dataframe(resume.rename(columns={"segment": "Segment", "clients": "Clients", "ca": "CA (R$)"}),
                hide_index=True, width="stretch")

with onglets[4]:
    st.subheader("Rétention par cohorte (part des clients qui rachètent n mois après)")
    ret = charger("retention_cohortes")
    ret = ret[(ret.taille_cohorte >= 300) & (ret.mois_depuis <= 12)]
    matrice = ret.pivot(index="cohorte", columns="mois_depuis", values="taux_retention_pct")
    st.plotly_chart(px.imshow(matrice, aspect="auto", color_continuous_scale="Blues",
                              labels={"x": "Mois après le 1er achat", "y": "Cohorte", "color": "%"}),
                    width="stretch")
    st.caption("Seules les cohortes d'au moins 300 clients sont affichées. La rétention est très faible : "
               "moins de 1 % rachètent le mois suivant.")
