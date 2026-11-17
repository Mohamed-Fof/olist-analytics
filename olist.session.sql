--- Les 10 requêtes de profilage
--- Requête 1 : y a-t-il des doublons de commandes ?

SELECT COUNT(*) AS Nombre_commandes, COUNT(DISTINCT order_id) AS Nombre_commandes_uniques
FROM raw.orders;

--- Requête 2 : quels statuts, en quelles proportions ?

SELECT order_status, COUNT(*) AS Nombre_commandes, 
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS Pourcentage
FROM raw.orders
GROUP BY order_status;

--- Lecture : on garde tous les statuts dans l'entrepôt, mais seules les ventes non annulées et non indisponibles compteront dans le chiffre d'affaires 

--- Requête 3 : combien de valeurs vides sur les colonnes clés ?
SELECT COUNT(*) FILTER (WHERE order_purchase_timestamp IS NULL) AS Valeurs_vides_order_purchase_timestamp,
       COUNT(*) FILTER (WHERE order_purchase_timestamp !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2} ') AS achats_timestamp_non_conformes,
       COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NULL) AS Valeurs_vides_order_delivered_carrier_date,
       COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS Valeurs_vides_order_delivered_customer_date,
       COUNT(*) FILTER (WHERE order_estimated_delivery_date IS NULL) AS Valeurs_vides_order_estimated_delivery_date
FROM raw.orders;
--- valeur vide de order_delivered_carrier_date est 1783, valeur vide de order_delivered_customer_date est 2965, valeur vide de order_estimated_delivery_date est 0, idem le reste

--- Requête 4 : SUR quel periode portes ses données 

SELECT MIN(order_purchase_timestamp) AS Date_min_achat, 
       MAX(order_purchase_timestamp) AS Date_max_achat,
       MIN(order_delivered_customer_date) AS Date_min_livraison, 
       MAX(order_delivered_customer_date) AS Date_max_livraison
FROM raw.orders;

---  en ordre 2016-09-04 21:15:19, 2018-10-17 17:30:18, 2016-10-11 13:46:32, 2018-10-17 13:22:46

--- Requête 5 : combien de clients réels ?

SELECT COUNT(*) AS Nombre_commandes, COUNT(DISTINCT customer_unique_id) AS Clients_Unique
FROM raw.customers;

-- 99441, 96096
--- Requête 6 : commandes sans aucun article

SELECT COUNT(*) AS Nombre_commande_sans_article 
FROM raw.orders o 
LEFT JOIN raw.order_items i USING (order_id)
WHERE i.order_id IS NULL; 

--775

---- Requête 7 : avis en double

SELECT COUNT(*) - COUNT(DISTINCT review_id) AS review_id_en_doublon 
FROM raw.reviews

-- 814

---- Requête 8 : produits sans catégorie, catégories sans traduction

SELECT COUNT (*) AS Produits_sans_categorie

FROM raw.products WHERE product_category_name IS NULL;

SELECT DISTINCT p.product_category_name AS categorie_sans_traduction
FROM raw.products p
LEFT JOIN raw.category_translation t USING (product_category_name)
WHERE t.product_category_name IS NULL AND p.product_category_name IS NOT NULL;

-- 610 produits sans catégorie

-- portateis_cozinha_e_preparadores_de_alimentos, pc_gamer

------ Requête 9 : les prix sont-ils plausibles ?

