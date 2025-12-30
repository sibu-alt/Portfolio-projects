# Olist E-commerce Analytics & Customer Segmentation

## Project Overview
A comprehensive SQL-based analytics project analyzing Brazil's largest e-commerce marketplace, Olist. This project transforms raw transactional data into actionable business insights through RFM analysis, customer segmentation, and cohort retention analysis.

## Business Objectives
- **Customer Segmentation**: Identify high-value customers using RFM (Recency, Frequency, Monetary) analysis
- **Geographic Insights**: Understand customer distribution and spending patterns across Brazilian states
- **Product Analysis**: Discover what top customers are buying
- **Retention Analysis**: Calculate customer cohort retention rates
- **Data Quality**: Implement robust data cleaning and validation pipelines

## Dataset Description
The Olist dataset contains ~100k orders from 2016-2018 with 9 key tables:

| Table | Records | Description |
|-------|---------|-------------|
| `olist_customers_dataset` | 99,441 | Customer demographics and location |
| `olist_orders_dataset` | 99,441 | Order details and status timeline |
| `olist_order_items_dataset` | 112,650 | Items purchased in each order |
| `olist_order_payments_dataset` | 103,886 | Payment information |
| `olist_order_reviews_dataset` | 99,441 | Customer reviews and ratings |
| `olist_products_dataset` | 32,951 | Product information and categories |
| `olist_sellers_dataset` | 3,095 | Seller information |
| `olist_geolocation_dataset` | 1,000,163 | Brazilian zip code coordinates |
| `product_category_translation` | 71 | Product category translations |

### Data Cleaning Pipeline
```sql
-- 1. Remove invalid records (null IDs, invalid scores, duplicate IDs)
-- 2. Handle missing values and data type conversions
-- 3. Create cleaned temporary tables for analysis
