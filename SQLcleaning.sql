--Select top 10 * from olist_customers_dataset$
--Select top 10 * from olist_geolocation_dataset$
--Select top 10 * from olist_order_items_dataset$
--Select top 10 * from olist_order_payments_dataset$
--Select top 10 * from olist_order_reviews_dataset$
--Select top 10 * from olist_orders_dataset$
--Select top 10 * from olist_products_dataset$
--Select top 10 * from olist_sellers_dataset$
--Select top 10 * from product_category_name_translati$

SELECT 
    'olist_orders_dataset' as table_name,
    COUNT(*) as record_count,
    COUNT(DISTINCT order_id) as unique_value
FROM olist_orders_dataset$
UNION ALL
SELECT 
    'olist_customers_dataset', 
    COUNT(*),
    COUNT(DISTINCT customer_unique_id)
FROM olist_customers_dataset$
UNION ALL

SELECT 
    'olist_order_items_dataset',
    COUNT(*),
    COUNT(DISTINCT order_id)
FROM olist_order_items_dataset$
UNION ALL
SELECT 
    'olist_order_reviews_dataset' as table_name,
    COUNT(*) as record_count,
    COUNT(DISTINCT order_id) as unique_orders
FROM olist_order_reviews_dataset$
UNION ALL
SELECT 
    'olist_order_reviews_id_dataset' as table_name,
    COUNT(*) as record_count,
    COUNT(DISTINCT review_id) as unique_orders
FROM olist_order_reviews_dataset$
UNION ALL

SELECT 
    'olist_order_payments_dataset', 
    COUNT(*),
    COUNT(DISTINCT order_id)
FROM olist_order_payments_dataset$
UNION ALL
SELECT 
    'olist_products_dataset' as table_name,
    COUNT(*) as record_count,
    COUNT(DISTINCT product_id) as unique_product
FROM olist_products_dataset$;

SELECT 
    review_id,
    order_id,
    review_score,
    review_comment_message
INTO #cleaned_order_reviews
    FROM (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY review_score DESC, review_id) as rn 
    FROM olist_order_reviews_dataset$
    WHERE review_score BETWEEN 0 AND 5
        AND order_id IS NOT NULL
        AND review_id IS NOT NULL
) AS sub
WHERE rn = 1; 

SELECT 
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
INTO #cleaned_customers
FROM (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY customer_unique_id ORDER BY customer_id) as rn
    FROM olist_customers_dataset$
    WHERE customer_id IS NOT NULL         
        AND customer_zip_code_prefix IS NOT NULL 
) AS sub
WHERE rn = 1; 
  
SELECT 
    order_id,
    product_id,
    order_item_id,
    seller_id,
    price,
    shipping_limit_date,
    freight_value
INTO #cleaned_order_items
FROM (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY order_id, product_id ORDER BY order_item_id) as rn
    FROM olist_order_items_dataset$
    WHERE order_id IS NOT NULL
        AND product_id IS NOT NULL
) AS sub
WHERE rn = 1;

SELECT 
    order_id,
    payment_type,
    payment_value,
    payment_installments
INTO #cleaned_order_payments
FROM (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY payment_value DESC) as rn 
    FROM olist_order_payments_dataset$
    WHERE order_id IS NOT NULL
        AND payment_value IS NOT NULL
) AS sub
WHERE rn = 1;

SELECT 
    order_id,
    customer_id,
    order_purchase_timestamp,
    order_status,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
INTO #cleaned_orders
FROM olist_orders_dataset$
WHERE order_id IS NOT NULL
    AND customer_id IS NOT NULL;

SELECT 
    product_category_name,
    product_id
INTO #cleaned_products
FROM olist_products_dataset$
WHERE product_id IS NOT NULL;  

CREATE INDEX idx_orders_order_id ON #cleaned_orders(order_id);
CREATE INDEX idx_orders_customer_id ON #cleaned_orders(customer_id);
CREATE INDEX idx_customers_customer_id ON #cleaned_customers(customer_id);
CREATE INDEX idx_order_items_order_id ON #cleaned_order_items(order_id);
CREATE INDEX idx_order_items_product_id ON #cleaned_order_items(product_id);
CREATE INDEX idx_products_product_id ON #cleaned_products(product_id);
CREATE INDEX idx_payments_order_id ON #cleaned_order_payments(order_id);

SELECT 
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    c.customer_zip_code_prefix,
    o.order_purchase_timestamp,
    o.order_status,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
   
    COUNT(DISTINCT oi.product_id) as distinct_product_count,
    COUNT(oi.order_item_id) as total_items,
    SUM(TRY_CAST(oi.price AS DECIMAL(10,2))) as total_price,
    SUM(TRY_CAST(oi.freight_value AS DECIMAL(10,2))) as total_freight,
    pymt.payment_type,
    SUM(TRY_CAST(pymt.payment_value AS DECIMAL(10,2))) as total_payment_value,
    AVG(TRY_CAST(pymt.payment_installments AS INT)) as avg_payment_installments,
    STRING_AGG(COALESCE(prd.product_category_name, 'Unknown'), ', ') WITHIN GROUP (ORDER BY prd.product_category_name) as product_categories
    
FROM #cleaned_orders o
LEFT JOIN #cleaned_customers c 
    ON o.customer_id = c.customer_id
LEFT JOIN #cleaned_order_items oi 
    ON o.order_id = oi.order_id
LEFT JOIN #cleaned_products prd 
    ON oi.product_id = prd.product_id
LEFT JOIN #cleaned_order_payments pymt 
    ON o.order_id = pymt.order_id
LEFT JOIN #cleaned_order_reviews rev 
    ON o.order_id = rev.order_id
GROUP BY 
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    c.customer_zip_code_prefix,
    o.order_purchase_timestamp,
    o.order_status,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    pymt.payment_type
ORDER BY o.order_purchase_timestamp DESC;

SELECT *
INTO #final_cleaned_data
FROM (
    SELECT 
        o.order_id,
        o.customer_id,
        c.customer_unique_id,
        c.customer_city,
        c.customer_state,
        c.customer_zip_code_prefix,
        o.order_purchase_timestamp,
        o.order_status,
        o.order_approved_at,
        o.order_delivered_carrier_date,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,
        COUNT(DISTINCT oi.product_id) as distinct_product_count,
        COUNT(oi.order_item_id) as total_items,
        SUM(TRY_CAST(oi.price AS DECIMAL(10,2))) as total_price,
        SUM(TRY_CAST(oi.freight_value AS DECIMAL(10,2))) as total_freight,
        pymt.payment_type,
        SUM(TRY_CAST(pymt.payment_value AS DECIMAL(10,2))) as total_payment_value,
        AVG(TRY_CAST(pymt.payment_installments AS INT)) as avg_payment_installments,
        STRING_AGG(COALESCE(prd.product_category_name, 'Unknown'), ', ') WITHIN GROUP (ORDER BY prd.product_category_name) as product_categories
   
    FROM #cleaned_orders o
    LEFT JOIN #cleaned_customers c ON o.customer_id = c.customer_id
    LEFT JOIN #cleaned_order_items oi ON o.order_id = oi.order_id
    LEFT JOIN #cleaned_products prd ON oi.product_id = prd.product_id
    LEFT JOIN #cleaned_order_payments pymt ON o.order_id = pymt.order_id
    LEFT JOIN #cleaned_order_reviews rev ON o.order_id = rev.order_id
    GROUP BY 
        o.order_id, o.customer_id, c.customer_unique_id, c.customer_city,
        c.customer_state, c.customer_zip_code_prefix, o.order_purchase_timestamp,
        o.order_status, o.order_approved_at, o.order_delivered_carrier_date,
        o.order_delivered_customer_date, o.order_estimated_delivery_date, pymt.payment_type
) AS cleaned_data;


DROP TABLE IF EXISTS #cleaned_order_reviews;
DROP TABLE IF EXISTS #cleaned_customers;
DROP TABLE IF EXISTS #cleaned_order_items;
DROP TABLE IF EXISTS #cleaned_order_payments;
DROP TABLE IF EXISTS #cleaned_orders;
DROP TABLE IF EXISTS #cleaned_products;
DROP TABLE IF EXISTS #final_cleaned_data;

--SELECT 
--    COLUMN_NAME AS ColumnName,
--    DATA_TYPE AS DataType,
--    IS_NULLABLE AS Nullable,
--    CHARACTER_MAXIMUM_LENGTH AS MaxLength
--FROM INFORMATION_SCHEMA.COLUMNS
--WHERE TABLE_NAME = 'product_category_name_translati$'
--ORDER BY ORDINAL_POSITION;

CREATE TABLE Olist_Cleaned_Dataset (
    order_id NVARCHAR(255),
    customer_id NVARCHAR(255),
    customer_unique_id NVARCHAR(255),
    customer_city NVARCHAR(255),
    customer_state NVARCHAR(255),
    customer_zip_code_prefix FLOAT,
    order_purchase_timestamp DATETIME,
    order_status NVARCHAR(255),
    order_approved_at DATETIME,
    order_delivered_carrier_date DATETIME,
    order_delivered_customer_date DATETIME,
    order_estimated_delivery_date DATETIME,
    distinct_product_count INT,
    total_items INT,
    total_price DECIMAL(10,2),
    total_freight DECIMAL(10,2),
    payment_type NVARCHAR(255),
    total_payment_value DECIMAL(10,2),
    avg_payment_installments DECIMAL(5,2),
    product_categories NVARCHAR(MAX)
);

INSERT INTO Olist_Cleaned_Dataset
SELECT 
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    c.customer_zip_code_prefix,
    o.order_purchase_timestamp,
    o.order_status,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    COUNT(DISTINCT oi.product_id) as distinct_product_count,
    COUNT(oi.order_item_id) as total_items,
    SUM(TRY_CAST(oi.price AS DECIMAL(10,2))) as total_price,
    SUM(TRY_CAST(oi.freight_value AS DECIMAL(10,2))) as total_freight,
    pymt.payment_type,
    SUM(TRY_CAST(pymt.payment_value AS DECIMAL(10,2))) as total_payment_value,
    AVG(TRY_CAST(pymt.payment_installments AS INT)) as avg_payment_installments,
    STRING_AGG(COALESCE(prd.product_category_name, 'Unknown'), ', ') WITHIN GROUP (ORDER BY prd.product_category_name) as product_categories
FROM #cleaned_orders o
LEFT JOIN #cleaned_customers c ON o.customer_id = c.customer_id
LEFT JOIN #cleaned_order_items oi ON o.order_id = oi.order_id
LEFT JOIN #cleaned_products prd ON oi.product_id = prd.product_id
LEFT JOIN #cleaned_order_payments pymt ON o.order_id = pymt.order_id
LEFT JOIN #cleaned_order_reviews rev ON o.order_id = rev.order_id
GROUP BY 
    o.order_id, o.customer_id, c.customer_unique_id, c.customer_city,
    c.customer_state, c.customer_zip_code_prefix, o.order_purchase_timestamp,
    o.order_status, o.order_approved_at, o.order_delivered_carrier_date,
    o.order_delivered_customer_date, o.order_estimated_delivery_date, pymt.payment_type;

SELECT TOP 10 * FROM Olist_Cleaned_Dataset