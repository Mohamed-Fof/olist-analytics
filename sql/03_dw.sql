-- Phase 8 : entrepôt en étoile (schéma dw), tout en français.
-- Grain de faits_ventes    : 1 ligne = 1 article vendu dans une commande.
-- Grain de faits_commandes : 1 ligne = 1 commande (même sans article).
-- Rejouable : on supprime et on recrée à chaque exécution.

DROP TABLE IF EXISTS dw.faits_ventes CASCADE;
DROP TABLE IF EXISTS dw.faits_commandes CASCADE;
DROP TABLE IF EXISTS dw.dim_date CASCADE;
DROP TABLE IF EXISTS dw.dim_client CASCADE;
DROP TABLE IF EXISTS dw.dim_produit CASCADE;
DROP TABLE IF EXISTS dw.dim_vendeur CASCADE;

-- Dimension date : 1 ligne par jour
CREATE TABLE dw.dim_date AS
SELECT to_char(d, 'YYYYMMDD')::int AS cle_date,
       d::date                      AS date,
       extract(year FROM d)::int    AS annee,
       extract(quarter FROM d)::int AS trimestre,
       extract(month FROM d)::int   AS mois,
       to_char(d, 'YYYY-MM')        AS annee_mois,
       extract(isodow FROM d)::int  AS jour_semaine,   -- 1 = lundi ... 7 = dimanche
       extract(isodow FROM d) >= 6  AS est_weekend
FROM generate_series('2016-01-01'::date, '2018-12-31'::date, interval '1 day') AS d;
ALTER TABLE dw.dim_date ADD PRIMARY KEY (cle_date);

-- Dimension client : 1 ligne par PERSONNE (id_client), pas par commande.
-- La ville et l'état retenus sont ceux de sa commande la plus récente.
CREATE TABLE dw.dim_client AS
SELECT row_number() OVER (ORDER BY id_client) AS cle_client,
       id_client, code_postal, ville, etat
FROM (
    SELECT DISTINCT ON (c.id_client)
           c.id_client, c.code_postal, c.ville, c.etat
    FROM staging.clients c
    JOIN staging.commandes o USING (id_client_commande)
    ORDER BY c.id_client, o.date_achat DESC
) t;
ALTER TABLE dw.dim_client ADD PRIMARY KEY (cle_client);
CREATE UNIQUE INDEX ON dw.dim_client (id_client);

CREATE TABLE dw.dim_produit AS
SELECT row_number() OVER (ORDER BY id_produit) AS cle_produit,
       id_produit, categorie_pt, categorie_en, poids_g, longueur_cm, hauteur_cm, largeur_cm
FROM staging.produits;
ALTER TABLE dw.dim_produit ADD PRIMARY KEY (cle_produit);
CREATE UNIQUE INDEX ON dw.dim_produit (id_produit);

CREATE TABLE dw.dim_vendeur AS
SELECT row_number() OVER (ORDER BY id_vendeur) AS cle_vendeur,
       id_vendeur, code_postal, ville, etat
FROM staging.vendeurs;
ALTER TABLE dw.dim_vendeur ADD PRIMARY KEY (cle_vendeur);
CREATE UNIQUE INDEX ON dw.dim_vendeur (id_vendeur);

-- Faits par commande : retard et note (1 ligne par commande)
-- Vente valide = ni canceled ni unavailable, avec au moins un article.
CREATE TABLE dw.faits_commandes AS
SELECT o.id_commande,
       cl.cle_client,
       to_char(o.date_achat, 'YYYYMMDD')::int AS cle_date_achat,
       o.statut,
       COALESCE(a.nb_articles, 0)              AS nb_articles,
       COALESCE(a.chiffre_affaires, 0)         AS chiffre_affaires,
       COALESCE(a.frais_port, 0)               AS frais_port,
       (o.statut NOT IN ('canceled', 'unavailable') AND COALESCE(a.nb_articles, 0) > 0)
                                               AS vente_valide,
       o.date_achat, o.date_livraison_client, o.date_livraison_estimee,
       -- retard en jours : positif = en retard ; vide si la commande n'est pas livrée
       CASE WHEN o.date_livraison_client IS NOT NULL
            THEN round((extract(epoch FROM o.date_livraison_client - o.date_livraison_estimee) / 86400)::numeric, 2)
       END                                     AS jours_retard,
       v.note
FROM staging.commandes o
JOIN staging.clients sc USING (id_client_commande)
JOIN dw.dim_client cl ON cl.id_client = sc.id_client
LEFT JOIN (
    SELECT id_commande, count(*) AS nb_articles, sum(prix) AS chiffre_affaires, sum(frais_port) AS frais_port
    FROM staging.articles_commande GROUP BY id_commande
) a USING (id_commande)
LEFT JOIN staging.avis v USING (id_commande);
ALTER TABLE dw.faits_commandes ADD PRIMARY KEY (id_commande);
ALTER TABLE dw.faits_commandes ADD COLUMN en_retard BOOLEAN;
UPDATE dw.faits_commandes SET en_retard = (jours_retard > 0) WHERE jours_retard IS NOT NULL;

-- Faits par article vendu (table centrale de l'étoile)
CREATE TABLE dw.faits_ventes AS
SELECT row_number() OVER (ORDER BY ar.id_commande, ar.numero_article) AS cle_vente,
       ar.id_commande,
       ar.numero_article,
       fc.cle_client,
       p.cle_produit,
       ve.cle_vendeur,
       fc.cle_date_achat,
       ar.prix,
       ar.frais_port,
       ar.prix + ar.frais_port AS montant_total,
       fc.statut,
       fc.vente_valide
FROM staging.articles_commande ar
JOIN dw.faits_commandes fc USING (id_commande)
JOIN dw.dim_produit p ON p.id_produit = ar.id_produit
JOIN dw.dim_vendeur ve ON ve.id_vendeur = ar.id_vendeur;
ALTER TABLE dw.faits_ventes ADD PRIMARY KEY (cle_vente);

-- Clés étrangères : l'étoile est vérifiée par la base elle-même
ALTER TABLE dw.faits_commandes ADD FOREIGN KEY (cle_client) REFERENCES dw.dim_client (cle_client);
ALTER TABLE dw.faits_commandes ADD FOREIGN KEY (cle_date_achat) REFERENCES dw.dim_date (cle_date);
ALTER TABLE dw.faits_ventes ADD FOREIGN KEY (id_commande) REFERENCES dw.faits_commandes (id_commande);
ALTER TABLE dw.faits_ventes ADD FOREIGN KEY (cle_client) REFERENCES dw.dim_client (cle_client);
ALTER TABLE dw.faits_ventes ADD FOREIGN KEY (cle_produit) REFERENCES dw.dim_produit (cle_produit);
ALTER TABLE dw.faits_ventes ADD FOREIGN KEY (cle_vendeur) REFERENCES dw.dim_vendeur (cle_vendeur);
ALTER TABLE dw.faits_ventes ADD FOREIGN KEY (cle_date_achat) REFERENCES dw.dim_date (cle_date);
