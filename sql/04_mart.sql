-- Phase 9 : SQL avancé -> schéma mart (tables prêtes pour le dashboard), tout en français.
-- Fonctions de fenêtre utilisées : LAG, RANK, ROW_NUMBER, NTILE, SUM() OVER.
-- Règle : seules les ventes valides (ni canceled ni unavailable, avec article) comptent dans le CA.

DROP TABLE IF EXISTS mart.ventes_mensuelles CASCADE;
DROP TABLE IF EXISTS mart.ventes_categories CASCADE;
DROP TABLE IF EXISTS mart.ventes_regions CASCADE;
DROP TABLE IF EXISTS mart.retard_et_note CASCADE;
DROP TABLE IF EXISTS mart.segments_clients CASCADE;
DROP TABLE IF EXISTS mart.retention_cohortes CASCADE;
DROP TABLE IF EXISTS mart.resume_segments CASCADE;

-- Q1 : évolution des ventes, avec comparaison au mois précédent (LAG)
CREATE TABLE mart.ventes_mensuelles AS
WITH par_mois AS (
    SELECT d.annee_mois,
           count(*)                           AS nb_commandes,
           sum(fc.chiffre_affaires)           AS chiffre_affaires
    FROM dw.faits_commandes fc
    JOIN dw.dim_date d ON d.cle_date = fc.cle_date_achat
    WHERE fc.vente_valide
    GROUP BY d.annee_mois
)
SELECT annee_mois,
       nb_commandes,
       chiffre_affaires,
       round(chiffre_affaires / nb_commandes, 2) AS panier_moyen,
       LAG(chiffre_affaires) OVER (ORDER BY annee_mois) AS ca_mois_precedent,
       round(100.0 * (chiffre_affaires - LAG(chiffre_affaires) OVER (ORDER BY annee_mois))
             / NULLIF(LAG(chiffre_affaires) OVER (ORDER BY annee_mois), 0), 1) AS variation_pct,
       sum(chiffre_affaires) OVER (ORDER BY annee_mois) AS ca_cumule
FROM par_mois;

-- Q2a : catégories qui rapportent le plus (RANK)
CREATE TABLE mart.ventes_categories AS
SELECT p.categorie_en                         AS categorie,
       count(*)                               AS nb_articles,
       sum(fv.prix)                           AS chiffre_affaires,
       round(100.0 * sum(fv.prix) / sum(sum(fv.prix)) OVER (), 2) AS part_ca_pct,
       RANK() OVER (ORDER BY sum(fv.prix) DESC) AS rang
FROM dw.faits_ventes fv
JOIN dw.dim_produit p USING (cle_produit)
WHERE fv.vente_valide
GROUP BY p.categorie_en;

-- Q2b : régions (état du client) qui rapportent le plus
CREATE TABLE mart.ventes_regions AS
SELECT c.etat,
       count(*)                                  AS nb_commandes,
       sum(fc.chiffre_affaires)                  AS chiffre_affaires,
       round(sum(fc.chiffre_affaires) / count(*), 2) AS panier_moyen,
       RANK() OVER (ORDER BY sum(fc.chiffre_affaires) DESC) AS rang
FROM dw.faits_commandes fc
JOIN dw.dim_client c USING (cle_client)
WHERE fc.vente_valide
GROUP BY c.etat;

-- Q3 : les retards pénalisent-ils la note ? (commandes livrées, avec avis)
CREATE TABLE mart.retard_et_note AS
SELECT CASE WHEN jours_retard <= 0  THEN '1. À l''heure ou en avance'
            WHEN jours_retard <= 3  THEN '2. Retard de 1 à 3 jours'
            WHEN jours_retard <= 7  THEN '3. Retard de 4 à 7 jours'
            WHEN jours_retard <= 14 THEN '4. Retard de 8 à 14 jours'
            ELSE '5. Retard de plus de 14 jours' END AS tranche_retard,
       count(*)                      AS nb_commandes,
       round(avg(note), 2)           AS note_moyenne,
       round(100.0 * avg((note <= 2)::int), 1) AS part_mauvaises_notes_pct
FROM dw.faits_commandes
WHERE jours_retard IS NOT NULL AND note IS NOT NULL AND vente_valide
GROUP BY 1;

-- Q4 : valeur et récence des clients (1 ligne par personne)
CREATE TABLE mart.segments_clients AS
WITH achats AS (
    SELECT fc.cle_client,
           count(*)                  AS nb_commandes,
           sum(fc.chiffre_affaires)  AS ca_total,
           max(fc.date_achat)        AS derniere_commande
    FROM dw.faits_commandes fc
    WHERE fc.vente_valide
    GROUP BY fc.cle_client
),
ref AS (SELECT max(date_achat) AS date_reference FROM dw.faits_commandes)
SELECT c.id_client,
       a.nb_commandes,
       a.ca_total,
       a.derniere_commande,
       (ref.date_reference::date - a.derniere_commande::date) AS recence_jours,
       NTILE(4) OVER (ORDER BY a.ca_total DESC) AS quartile_valeur,   -- 1 = les plus précieux
       CASE WHEN a.nb_commandes >= 2 AND ref.date_reference::date - a.derniere_commande::date <= 180 THEN 'Fidèle actif'
            WHEN a.nb_commandes >= 2 THEN 'Fidèle à risque'
            WHEN ref.date_reference::date - a.derniere_commande::date <= 180 THEN 'Nouveau récent'
            ELSE 'Inactif (1 seul achat ancien)' END AS segment
FROM achats a
JOIN dw.dim_client c USING (cle_client)
CROSS JOIN ref;

-- Q5 : rétention par cohorte (mois du 1er achat), à M+0, M+1, M+2...
CREATE TABLE mart.retention_cohortes AS
WITH commandes_mois AS (
    SELECT DISTINCT fc.cle_client, date_trunc('month', fc.date_achat)::date AS mois_achat
    FROM dw.faits_commandes fc
    WHERE fc.vente_valide
),
cohortes AS (
    SELECT cle_client, mois_achat,
           min(mois_achat) OVER (PARTITION BY cle_client) AS mois_cohorte
    FROM commandes_mois
),
activite AS (
    SELECT mois_cohorte,
           ((extract(year FROM mois_achat) - extract(year FROM mois_cohorte)) * 12
            + extract(month FROM mois_achat) - extract(month FROM mois_cohorte))::int AS mois_depuis,
           count(DISTINCT cle_client) AS clients_actifs
    FROM cohortes
    GROUP BY 1, 2
)
SELECT to_char(mois_cohorte, 'YYYY-MM') AS cohorte,
       mois_depuis,
       clients_actifs,
       FIRST_VALUE(clients_actifs) OVER (PARTITION BY mois_cohorte ORDER BY mois_depuis) AS taille_cohorte,
       round(100.0 * clients_actifs
             / FIRST_VALUE(clients_actifs) OVER (PARTITION BY mois_cohorte ORDER BY mois_depuis), 2) AS taux_retention_pct
FROM activite;

-- Résumé par segment (petit : c'est ce que lit le dashboard)
CREATE TABLE mart.resume_segments AS
SELECT segment,
       count(*)                  AS clients,
       sum(ca_total)             AS chiffre_affaires,
       round(avg(nb_commandes), 2) AS commandes_par_client
FROM mart.segments_clients
GROUP BY segment;
