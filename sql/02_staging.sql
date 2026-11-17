-- Phase 7 : staging = données nettoyées et typées, noms de tables et colonnes en français.
-- Rejouable : on supprime et on recrée à chaque exécution.

DROP TABLE IF EXISTS staging.rejetees CASCADE;
DROP TABLE IF EXISTS staging.avis CASCADE;
DROP TABLE IF EXISTS staging.paiements CASCADE;
DROP TABLE IF EXISTS staging.articles_commande CASCADE;
DROP TABLE IF EXISTS staging.commandes CASCADE;
DROP TABLE IF EXISTS staging.clients CASCADE;
DROP TABLE IF EXISTS staging.produits CASCADE;
DROP TABLE IF EXISTS staging.vendeurs CASCADE;
DROP TABLE IF EXISTS staging.geolocalisation CASCADE;
DROP TABLE IF EXISTS staging.traduction_categories CASCADE;

-- Quarantaine : lignes rejetées avec le motif du rejet
CREATE TABLE staging.rejetees (
    table_source TEXT,
    cle          TEXT,
    motif        TEXT,
    ligne        JSONB,
    date_rejet   TIMESTAMP DEFAULT now()
);

-- Clients (1 ligne par customer_id, comme dans la source)
CREATE TABLE staging.clients AS
SELECT customer_id              AS id_client_commande,
       customer_unique_id       AS id_client,          -- la vraie personne
       customer_zip_code_prefix AS code_postal,
       initcap(customer_city)   AS ville,
       customer_state           AS etat
FROM raw.customers;

-- Commandes : rejet si date d'achat vide/invalide ou client inconnu
INSERT INTO staging.rejetees (table_source, cle, motif, ligne)
SELECT 'commandes', o.order_id,
       CASE WHEN o.order_purchase_timestamp IS NULL
                 OR o.order_purchase_timestamp !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2} '
            THEN 'date d''achat vide ou invalide' ELSE 'client inexistant' END,
       to_jsonb(o)
FROM raw.orders o
LEFT JOIN raw.customers c USING (customer_id)
WHERE o.order_purchase_timestamp IS NULL
   OR o.order_purchase_timestamp !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2} '
   OR c.customer_id IS NULL;

CREATE TABLE staging.commandes AS
SELECT o.order_id                                   AS id_commande,
       o.customer_id                                AS id_client_commande,
       o.order_status                               AS statut,
       o.order_purchase_timestamp::timestamp        AS date_achat,
       o.order_approved_at::timestamp               AS date_validation,
       o.order_delivered_carrier_date::timestamp    AS date_remise_transporteur,
       o.order_delivered_customer_date::timestamp   AS date_livraison_client,
       o.order_estimated_delivery_date::timestamp   AS date_livraison_estimee
FROM raw.orders o
WHERE o.order_id NOT IN (SELECT cle FROM staging.rejetees WHERE table_source = 'commandes');

-- Articles : rejet si prix <= 0 ou vide, ou commande rejetée
INSERT INTO staging.rejetees (table_source, cle, motif, ligne)
SELECT 'articles_commande', i.order_id || '-' || i.order_item_id, 'prix nul, négatif ou vide', to_jsonb(i)
FROM raw.order_items i
WHERE i.price IS NULL OR i.price::numeric <= 0;

CREATE TABLE staging.articles_commande AS
SELECT i.order_id                    AS id_commande,
       i.order_item_id::int          AS numero_article,
       i.product_id                  AS id_produit,
       i.seller_id                   AS id_vendeur,
       i.shipping_limit_date::timestamp AS date_limite_expedition,
       i.price::numeric(10,2)        AS prix,
       i.freight_value::numeric(10,2) AS frais_port
FROM raw.order_items i
WHERE i.price IS NOT NULL AND i.price::numeric > 0
  AND i.order_id IN (SELECT id_commande FROM staging.commandes);

CREATE TABLE staging.paiements AS
SELECT order_id                       AS id_commande,
       payment_sequential::int        AS numero_paiement,
       payment_type                   AS type_paiement,
       payment_installments::int      AS nb_echeances,
       payment_value::numeric(10,2)   AS montant
FROM raw.payments
WHERE order_id IN (SELECT id_commande FROM staging.commandes);

-- Avis : 1 seul avis par commande (le plus récent), et review_id unique
CREATE TABLE staging.avis AS
SELECT id_avis, id_commande, note, titre, commentaire, date_creation, date_reponse
FROM (
    SELECT review_id                          AS id_avis,
           order_id                           AS id_commande,
           review_score::int                  AS note,
           review_comment_title               AS titre,
           review_comment_message             AS commentaire,
           review_creation_date::timestamp    AS date_creation,
           review_answer_timestamp::timestamp AS date_reponse,
           row_number() OVER (PARTITION BY review_id
                              ORDER BY review_answer_timestamp DESC, order_id) AS rang_avis,
           row_number() OVER (PARTITION BY order_id
                              ORDER BY review_answer_timestamp DESC, review_id) AS rang_commande
    FROM raw.reviews
    WHERE order_id IN (SELECT id_commande FROM staging.commandes)
) t
WHERE rang_avis = 1 AND rang_commande = 1;

CREATE TABLE staging.traduction_categories AS
SELECT product_category_name         AS categorie_pt,
       product_category_name_english AS categorie_en
FROM raw.category_translation;

-- Produits : catégorie « inconnue » si vide, traduction anglaise si elle existe
CREATE TABLE staging.produits AS
SELECT p.product_id                                    AS id_produit,
       COALESCE(p.product_category_name, 'inconnue')   AS categorie_pt,
       COALESCE(t.categorie_en, p.product_category_name, 'unknown') AS categorie_en,
       p.product_name_lenght::int                      AS longueur_nom,
       p.product_description_lenght::int               AS longueur_description,
       p.product_photos_qty::int                       AS nb_photos,
       p.product_weight_g::numeric                     AS poids_g,
       p.product_length_cm::numeric                    AS longueur_cm,
       p.product_height_cm::numeric                    AS hauteur_cm,
       p.product_width_cm::numeric                     AS largeur_cm
FROM raw.products p
LEFT JOIN staging.traduction_categories t ON t.categorie_pt = p.product_category_name;

CREATE TABLE staging.vendeurs AS
SELECT seller_id                AS id_vendeur,
       seller_zip_code_prefix   AS code_postal,
       initcap(seller_city)     AS ville,
       seller_state             AS etat
FROM raw.sellers;

CREATE TABLE staging.geolocalisation AS
SELECT geolocation_zip_code_prefix      AS code_postal,
       geolocation_lat::double precision AS latitude,
       geolocation_lng::double precision AS longitude,
       initcap(geolocation_city)         AS ville,
       geolocation_state                 AS etat
FROM raw.geolocation;

-- Clés primaires (garantissent l'unicité)
ALTER TABLE staging.clients  ADD PRIMARY KEY (id_client_commande);
ALTER TABLE staging.commandes ADD PRIMARY KEY (id_commande);
ALTER TABLE staging.articles_commande ADD PRIMARY KEY (id_commande, numero_article);
ALTER TABLE staging.avis ADD PRIMARY KEY (id_avis);
ALTER TABLE staging.produits ADD PRIMARY KEY (id_produit);
ALTER TABLE staging.vendeurs ADD PRIMARY KEY (id_vendeur);
