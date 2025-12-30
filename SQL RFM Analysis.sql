WITH customer_orders AS (
    SELECT 
        c.customer_unique_id,
        c.customer_state,
        COUNT(DISTINCT o.order_id) as order_count,
        SUM(TRY_CAST(oi.price AS DECIMAL(10,2)) + TRY_CAST(oi.freight_value AS DECIMAL(10,2))) as total_spent,
        MAX(o.order_purchase_timestamp) as last_order_date,
        MIN(o.order_purchase_timestamp) as first_order_date
    FROM olist_customers_dataset$ c
    INNER JOIN olist_orders_dataset$ o ON c.customer_id = o.customer_id
    INNER JOIN olist_order_items_dataset$ oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
        AND o.order_purchase_timestamp IS NOT NULL
    GROUP BY c.customer_unique_id, c.customer_state
    HAVING COUNT(DISTINCT o.order_id) > 0 
),
rfm_calc AS (
    SELECT 
        customer_unique_id,
        customer_state,
        order_count,
        total_spent,
        last_order_date,
        DATEDIFF(DAY, last_order_date, (SELECT MAX(order_purchase_timestamp) FROM olist_orders_dataset$ WHERE order_status = 'delivered')) as recency_days,
        NTILE(5) OVER (ORDER BY last_order_date) as recency_score,
        NTILE(5) OVER (ORDER BY order_count) as frequency_score,
        NTILE(5) OVER (ORDER BY total_spent) as monetary_score
    FROM customer_orders
),
rfm_segments AS (
    SELECT 
        *,
        CAST(recency_score AS VARCHAR(1)) + 
        CAST(frequency_score AS VARCHAR(1)) + 
        CAST(monetary_score AS VARCHAR(1)) as rfm_cell,
        CASE
            WHEN recency_score >= 4 AND monetary_score >= 4 THEN 'High Value'
            WHEN monetary_score >= 4 THEN 'Big Spenders'
            WHEN frequency_score >= 4 THEN 'Frequent Buyers'
            ELSE 'Regular'
        END as value_segment,
        CASE 
            WHEN recency_score >= 1 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'Champions'
            WHEN recency_score >= 1 AND frequency_score >= 3 AND monetary_score >= 3 THEN 'Loyal Customers'
            WHEN recency_score >= 2 AND frequency_score >= 1 AND monetary_score >= 2 THEN 'Potential Loyalists'
            WHEN recency_score >= 2 AND frequency_score >= 2 AND monetary_score >= 2 THEN 'Recent Customers'
            WHEN recency_score >= 2 AND frequency_score >= 1 AND monetary_score >= 1 THEN 'Promising'
            WHEN recency_score >= 3 AND frequency_score >= 1 AND monetary_score >= 1 THEN 'Customers Needing Attention'
            WHEN recency_score >= 3 AND frequency_score >= 1 AND monetary_score >= 2 THEN 'At Risk'
            WHEN recency_score >= 4 AND frequency_score >= 2 AND monetary_score >= 1 THEN 'Hibernating'
            ELSE 'Lost Customers'
        END as rfm_segment
    FROM rfm_calc
)
SELECT * INTO #rfm_temp FROM rfm_segments;
-- run each analysis separately
SELECT 
    customer_state,
    value_segment,
    COUNT(DISTINCT customer_unique_id) as customer_count,
    AVG(total_spent) as avg_spent_per_customer,
    SUM(total_spent) as total_segment_revenue
FROM #rfm_temp
WHERE value_segment IN ('High Value', 'Big Spenders', 'Frequent Buyers')  -- Fixed filter
GROUP BY customer_state, value_segment
ORDER BY customer_count DESC;

SELECT TOP 10
    COALESCE(p.product_category_name, 'Unknown') as category,
    COUNT(DISTINCT o.order_id) as order_count,
    ROUND(SUM(TRY_CAST(oi.price AS DECIMAL(10,2))), 2) as revenue_from_category
FROM #rfm_temp r
INNER JOIN olist_customers_dataset$ c ON r.customer_unique_id = c.customer_unique_id
INNER JOIN olist_orders_dataset$ o ON c.customer_id = o.customer_id
INNER JOIN olist_order_items_dataset$ oi ON o.order_id = oi.order_id
INNER JOIN olist_products_dataset$ p ON oi.product_id = p.product_id
WHERE r.rfm_segment = 'Champions'  -- Use rfm_segment, not value_segment
GROUP BY COALESCE(p.product_category_name, 'Unknown')
ORDER BY revenue_from_category DESC;

WITH cohort_data AS (
    SELECT 
        c.customer_unique_id,
        DATEADD(MONTH, DATEDIFF(MONTH, 0, MIN(o.order_purchase_timestamp)), 0) as cohort_month,
        DATEADD(MONTH, DATEDIFF(MONTH, 0, o.order_purchase_timestamp), 0) as order_month
    FROM olist_customers_dataset$ c
    INNER JOIN olist_orders_dataset$ o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id, DATEADD(MONTH, DATEDIFF(MONTH, 0, o.order_purchase_timestamp), 0)
)
SELECT 
    FORMAT(cohort_month, 'yyyy-MM') as cohort_month,
    COUNT(DISTINCT customer_unique_id) as cohort_size,
    COUNT(DISTINCT CASE WHEN order_month = cohort_month THEN customer_unique_id END) as month_0,
    COUNT(DISTINCT CASE WHEN order_month = DATEADD(MONTH, 1, cohort_month) THEN customer_unique_id END) as month_1,
    COUNT(DISTINCT CASE WHEN order_month = DATEADD(MONTH, 2, cohort_month) THEN customer_unique_id END) as month_2,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN order_month = DATEADD(MONTH, 1, cohort_month) THEN customer_unique_id END) / 
          NULLIF(COUNT(DISTINCT CASE WHEN order_month = cohort_month THEN customer_unique_id END), 0), 1) as retention_month_1_pct
FROM cohort_data
GROUP BY cohort_month
ORDER BY cohort_month;


DROP TABLE IF EXISTS #rfm_temp;




