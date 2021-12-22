# e-Commerece Data Analyst Project
-- In this project I will act as data analyst in an online retailer and helps to understand how each product
-- contributes to business and how product launches impact the overall portfolio.

# Sales Analysis

-- Pull monthly trends to date for number of sales, total revenue,  and total margin generated until 2013-01-04. 

USE mavenfuzzyfactory;

SELECT 
    MIN(DATE(created_at)) AS first_day_of_month,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(price_usd) AS total_revenue,
    SUM(price_usd - cogs_usd) AS margin_generated
FROM
    orders
WHERE
    created_at < '2013-01-01'
GROUP BY MONTH(created_at)
ORDER BY created_at;

-- Pull monthly order volume, overall conversion rates, revenue per session, and breakdown sales by product
-- between 2012-04-01 and 2013-04-05

SELECT 
    MIN(DATE(ws.created_at)) AS month_start_date,
    COUNT(DISTINCT ws.website_session_id) AS sessions,
    COUNT(DISTINCT order_id) AS orders,
    COUNT(DISTINCT o.website_session_id) / COUNT(DISTINCT ws.website_session_id) AS conversion_rate,
    SUM(price_usd) / COUNT(DISTINCT ws.website_session_id) AS revenue_per_session,
    COUNT(CASE
        WHEN primary_product_id = 1 THEN order_id
        ELSE NULL
    END) AS product_one_orders,
    COUNT(CASE
        WHEN primary_product_id = 2 THEN order_id
        ELSE NULL
    END) AS product_two_orders
FROM
    website_sessions AS ws
        LEFT JOIN
    orders o ON o.website_session_id = ws.website_session_id
WHERE
    ws.created_at BETWEEN '2012-04-01' AND '2013-04-05'
GROUP BY MONTH(ws.created_at)
ORDER BY ws.created_at;

-- Product level website pathing before and after new product launch between 2012-10-06 and 2013-04-06. 

 CREATE TEMPORARY TABLE product_table
SELECT 
    CASE
        WHEN created_at < '2013-01-06' THEN 'pre_product_2'
        WHEN created_at >= '2013-01-06' THEN 'post_product_2'
    END AS time_period,
    website_pageview_id,
    website_session_id
FROM
    website_pageviews
WHERE
    created_at BETWEEN '2012-10-06' AND '2013-04-06'
        AND pageview_url = '/products';

CREATE TEMPORARY TABLE sessions_w_nxt_page_view_id 
SELECT 
    time_period,
    p.website_session_id,
    MIN(w.website_pageview_id) AS nxt_page_id
FROM
    product_table p
        LEFT JOIN
    website_pageviews w ON w.website_pageview_id > p.website_pageview_id
        AND w.website_session_id = p.website_session_id
GROUP BY 1 , 2;
 
CREATE TEMPORARY TABLE sessions_w_nxt_page_view_url 
 SELECT 
    time_period, s.website_session_id, pageview_url
FROM
    sessions_w_nxt_page_view_id s
        LEFT JOIN
    website_pageviews w ON w.website_pageview_id = s.nxt_page_id;
 
SELECT 
    time_period,
    COUNT(DISTINCT website_session_id) AS session,
    COUNT(DISTINCT CASE
            WHEN pageview_url IS NOT NULL THEN website_session_id
            ELSE NULL
        END) AS w_nxt_page,
    COUNT(DISTINCT CASE
            WHEN pageview_url IS NOT NULL THEN website_session_id
            ELSE NULL
        END) / COUNT(DISTINCT website_session_id) AS pct_w_nxt_page,
    COUNT(CASE
        WHEN pageview_url = '/the-original-mr-fuzzy' THEN website_session_id
        ELSE NULL
    END) AS to_mr_fuzzy,
    COUNT(CASE
        WHEN pageview_url = '/the-original-mr-fuzzy' THEN website_session_id
        ELSE NULL
    END) / COUNT(DISTINCT website_session_id) AS pct_to_mr_fuzzy,
    COUNT(CASE
        WHEN pageview_url = '/the-forever-love-bear' THEN website_session_id
        ELSE NULL
    END) AS to_love_bear,
    COUNT(CASE
        WHEN pageview_url = '/the-forever-love-bear' THEN website_session_id
        ELSE NULL
    END) / COUNT(DISTINCT website_session_id) AS pct_to_love_bear
FROM
    sessions_w_nxt_page_view_url
GROUP BY 1
ORDER BY 1 DESC;

-- Conversion funnels for two products since 2014-01-06 from each product page to conversion until 2014-04-10. 

CREATE TEMPORARY TABLE product_type_table
SELECT 
    CASE
        WHEN pageview_url = '/the-original-mr-fuzzy' THEN 'mr_fuzzy'
        WHEN pageview_url = '/the-forever-love-bear' THEN 'love_bear'
    END AS product_type,
    website_pageview_id,
    website_session_id
FROM
    website_pageviews
WHERE
    created_at BETWEEN '2014-01-06' AND '2014-04-10'
        AND pageview_url IN ('/the-original-mr-fuzzy' , '/the-forever-love-bear');

CREATE TEMPORARY TABLE session_w_nxt_page_id
SELECT 
    product_type,
    w.website_pageview_id AS nxt_page_id,
    p.website_session_id
FROM
    product_type_table p
        LEFT JOIN
    website_pageviews w ON w.website_pageview_id > p.website_pageview_id
        AND w.website_session_id = p.website_session_id; 

CREATE TEMPORARY TABLE session_w_nxt_page_url 
SELECT 
    product_type,
    s.website_session_id,
    pageview_url AS nxt_page_url
FROM
    session_w_nxt_page_id AS s
        LEFT JOIN
    website_pageviews w ON w.website_pageview_id = s.nxt_page_id;

CREATE TEMPORARY TABLE sessions_w_nxt_page_flags
SELECT 
    product_type,
    website_session_id,
    MAX(cart_flag) AS to_cart,
    MAX(shipping_flag) AS to_shipping,
    MAX(billing_flag) AS to_billing,
    MAX(thank_you_flag) AS to_thank_you
FROM
    (SELECT 
        product_type,
            website_session_id,
            nxt_page_url,
            CASE
                WHEN nxt_page_url = '/cart' THEN 1
                ELSE 0
            END AS cart_flag,
            CASE
                WHEN nxt_page_url = '/shipping' THEN 1
                ELSE 0
            END AS shipping_flag,
            CASE
                WHEN nxt_page_url = '/billing-2' THEN 1
                ELSE 0
            END AS billing_flag,
            CASE
                WHEN nxt_page_url = '/thank-you-for-your-order' THEN 1
                ELSE 0
            END AS thank_you_flag
    FROM
        session_w_nxt_page_url) a
GROUP BY 1 , 2
ORDER BY 2;

SELECT 
    product_type,
    COUNT(CASE
        WHEN to_cart = 1 THEN website_session_id
        ELSE NULL
    END) / COUNT(website_session_id) AS product_page_clk_rate,
    COUNT(CASE
        WHEN to_shipping = 1 THEN website_session_id
        ELSE NULL
    END) / COUNT(CASE
        WHEN to_cart = 1 THEN website_session_id
        ELSE NULL
    END) AS cart_clk_rate,
    COUNT(CASE
        WHEN to_billing = 1 THEN website_session_id
        ELSE NULL
    END) / COUNT(CASE
        WHEN to_shipping = 1 THEN website_session_id
        ELSE NULL
    END) AS shipping_clk_rate,
    COUNT(CASE
        WHEN to_thank_you = 1 THEN website_session_id
        ELSE NULL
    END) / COUNT(CASE
        WHEN to_billing = 1 THEN website_session_id
        ELSE NULL
    END) AS billing_clk_rate
FROM
    sessions_w_nxt_page_flags
GROUP BY 1;

# Cross sell analysis 
-- Cross sell analysis after add new product option on cart page on 2013-09-25.  
-- Compare CTR from cart page, Avg. products per order, AOV, and overall revenue per cart page view
-- until 2013-11-22 and make  2013-09-25 as baseline to compare before and after the change. 

CREATE TEMPORARY TABLE sessions_seing_cart
SELECT 
    CASE
        WHEN created_at < '2013-09-25' THEN 'A.Pre_Cross_Sell'
        WHEN created_at >= '2013-09-25' THEN 'B.Post_Cross_Sell'
        ELSE NULL
    END AS time_period,
    website_session_id AS cart_session_id,
    website_pageview_id AS cart_pageview_id
FROM
    website_pageviews
WHERE
    created_at BETWEEN '2013-08-25' AND '2013-11-22'
        AND pageview_url = '/cart';
        
CREATE TEMPORARY TABLE cart_sessions_seing_another_page       
SELECT 
    time_period,
    cart_session_id,
    MIN(w.website_pageview_id) AS pv_id_after_cart
FROM
    sessions_seing_cart s
        LEFT JOIN
    website_pageviews w ON w.website_pageview_id > s.cart_pageview_id
        AND w.website_session_id = s.cart_session_id
GROUP BY 1 , 2
HAVING MIN(w.website_pageview_id) IS NOT NULL;

CREATE TEMPORARY TABLE sessions_w_orders
SELECT 
    time_period,
    cart_session_id,
    order_id,
    items_purchased,
    price_usd
FROM
    sessions_seing_cart s
        INNER JOIN
    orders o ON o.website_session_id = s.cart_session_id;
    
SELECT 
    time_period,
    COUNT(DISTINCT cart_session_id) AS sessions,
    SUM(clicked_to_onether_page) AS clk_throgh,
    SUM(clicked_to_onether_page) / COUNT(DISTINCT cart_session_id) AS cart_clk_throgh_rate,
    -- SUM(placed_order) AS orders_placed,
    -- SUM(items_purchased) AS items_purchased,
    SUM(items_purchased) / SUM(placed_order) AS products_per_order,
    SUM(price_usd) / SUM(placed_order) AS aov,
    SUM(price_usd) / COUNT(DISTINCT cart_session_id) AS rev_per_cart_session
FROM
    (SELECT 
    s.time_period,
    s.cart_session_id,
    CASE
        WHEN c.cart_session_id IS NULL THEN 0
        ELSE 1
    END AS clicked_to_onether_page,
    CASE
        WHEN sw.order_id IS NULL THEN 0
        ELSE 1
    END AS placed_order,
    sw.items_purchased,
    sw.price_usd
FROM
    sessions_seing_cart s
        LEFT JOIN
    cart_sessions_seing_another_page c ON c.cart_session_id = s.cart_session_id
        LEFT JOIN
    sessions_w_orders sw ON sw.cart_session_id = s.cart_session_id
ORDER BY 2) a
GROUP BY 1;

 



	
        
        
