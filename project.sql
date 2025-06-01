use brazillian_ecommerce;

-- Customer Analysis
-- 1 How many unique customers are there in the dataset?
select distinct(customer_id) from customers;

-- Which cities have the highest number of customers?
select count(customer_id) as total_customers, customer_city from customers group by customer_city order by total_customers desc;

-- What is the average order value per customer?
select customers.customer_id as customers, avg(order_items.price) as average_order_price from customers inner join 
orders on customers.customer_id = orders.customer_id
inner join order_items on order_items.order_id = orders.order_id
 group by customers order by average_order_price desc;


-- How many orders were placed each month?
select monthname(order_purchase_timestamp) as months, count(order_id) as total_orders from orders
group by months order by total_orders desc;

-- What is the average delivery time?
select avg(datediff(order_delivered_customer_date,order_purchase_timestamp)) from orders;

-- Which payment type (credit card, boleto, etc.) is most popular?

select payment_type, count(order_id) as orders from payments group by payment_type
order by orders desc;

-- What are the top 10 best-selling product categories?
-- which product category has the highest sales volume
select products.product_category_name as categories, sum(order_items.price) as total_sales from products
inner join order_items on
products.product_id = order_items.product_id
group by categories 
order by total_sales desc
limit 10;

-- What is the average price of products per category?
select products.product_category_name as categories, avg(order_items.price) as avg_price
from products inner join order_items on
products.product_id = order_items.product_id
group by categories
order by avg_price desc;

-- Which customers have placed the most orders?
select customers.customer_id as customers, count(orders.order_id) as total_orders
from customers inner join orders on 
customers.customer_id = orders.customer_id
group by customers
order by total_orders desc;

-- What percentage of customers make repeat purchases?
WITH customer_order_counts AS (
    SELECT 
        customer_id,
        COUNT(DISTINCT order_id) AS order_count
    FROM 
        orders
    GROUP BY 
        customer_id
)

SELECT 
    ROUND(
        (COUNT(CASE WHEN order_count > 1 THEN customer_id END) * 100.0 / 
        COUNT(customer_id)),
        2
    ) AS repeat_customer_percentage
FROM 
    customer_order_counts;
    
-- What is the total revenue generated per customer?
select customers.customer_id as customers,
sum(order_items.price) as total_spendings from customers
inner join orders on
customers.customer_id = orders.customer_id
inner join order_items on
orders.order_id = order_items.order_id
group by customers
order by total_spendings desc;

-- Which sellers have the highest sales volume?

-- select sellers.seller_id as seller,

select seller_id as seller,
round(sum(price)) as total from order_items
group by seller
order by total desc;

select payment_value from payments;
select price from order_items;

-- What is the average seller rating?
select order_items.seller_id as seller,
avg(reviews.review_score) as ratings
from order_items
inner join reviews on
reviews.order_id = order_items.order_id
group by seller;

-- Which sellers have the highest number of late shipments?

select distinct order_items.seller_id as seller,
count(distinct orders.order_id) as late_shipments,
avg(datediff(orders.order_delivered_customer_date,orders.order_estimated_delivery_date)) as avg_days_required_to_shipped
from order_items
inner join orders
on orders.order_id = order_items.order_id
where orders.order_delivered_customer_date > orders.order_estimated_delivery_date and orders.order_status='delivered'
group by seller
order by late_shipments desc;

-- What is the total revenue per payment method?

select payments.payment_type as PaymentMethod,
sum(order_items.price) as total_revenue
from payments
inner join order_items on 
payments.order_id = order_items.order_id
group by PaymentMethod
order by total_revenue desc
;






-- How does the average order value change over time?


-- Are there any trends in installment payments (e.g., more people using installments in certain months)?

WITH payment_trends AS (
    SELECT
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS month_year,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(CASE WHEN p.payment_installments > 1 THEN 1 ELSE 0 END) AS installment_orders,
        ROUND(SUM(CASE WHEN p.payment_installments > 1 THEN 1 ELSE 0 END) * 100.0 / 
              COUNT(DISTINCT o.order_id), 2) AS installment_percentage,
        AVG(CASE WHEN p.payment_installments > 1 THEN p.payment_installments END) AS avg_installments,
        SUM(CASE WHEN p.payment_installments > 1 THEN p.payment_value ELSE 0 END) AS installment_revenue,
        LAG(ROUND(SUM(CASE WHEN p.payment_installments > 1 THEN 1 ELSE 0 END) * 100.0 / 
                  COUNT(DISTINCT o.order_id), 2)) 
            OVER (ORDER BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')) AS prev_month_percentage
    FROM
        orders o
    JOIN
        payments p ON o.order_id = p.order_id
    WHERE
        o.order_status = 'delivered'
        AND p.payment_type = 'credit_card' -- Focusing on credit card installments
    GROUP BY
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
)

SELECT
    month_year,
    total_orders,
    installment_orders,
    installment_percentage,
    avg_installments,
    installment_revenue,
    prev_month_percentage,
    ROUND(installment_percentage - prev_month_percentage, 2) AS percentage_point_change,
    CASE
        WHEN installment_percentage > prev_month_percentage THEN '↑ Increasing'
        WHEN installment_percentage < prev_month_percentage THEN '↓ Decreasing'
        ELSE '→ Stable'
    END AS trend_direction,
    ROUND((installment_percentage - prev_month_percentage) / 
          NULLIF(prev_month_percentage, 0) * 100, 2) AS percentage_change
FROM
    payment_trends
ORDER BY
    month_year;


-- Segment customers into High-Value (top 10% by spending), Medium-Value, and Low-Value using NTILE()
WITH customer_spending AS (
    SELECT
        c.customer_id,
        c.customer_city,
        c.customer_state,
        SUM(p.payment_value) AS total_spending,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM
        customers c
    JOIN
        orders o ON c.customer_id = o.customer_id
    JOIN
       payments p ON o.order_id = p.order_id
    WHERE
        o.order_status = 'delivered'
    GROUP BY
        c.customer_id, c.customer_city, c.customer_state
),

customer_segments AS (
    SELECT
        customer_id,
        customer_city,
        customer_state,
        total_spending,
        order_count,
        NTILE(10) OVER (ORDER BY total_spending DESC) AS spending_percentile
    FROM
        customer_spending
)

SELECT
    CASE
        WHEN spending_percentile = 1 THEN 'High-Value (Top 10%)'
        WHEN spending_percentile BETWEEN 2 AND 4 THEN 'Medium-Value (20-40%)'
        ELSE 'Low-Value (Bottom 50%)'
    END AS customer_segment,
    COUNT(customer_id) AS customer_count,
    ROUND(SUM(total_spending), 2) AS segment_revenue,
    ROUND(SUM(total_spending) * 100.0 / (SELECT SUM(total_spending) FROM customer_segments), 2) AS revenue_percentage,
    ROUND(AVG(total_spending), 2) AS avg_spending,
    ROUND(AVG(order_count), 2) AS avg_orders
FROM
    customer_segments
GROUP BY
    customer_segment
ORDER BY
    CASE
        WHEN customer_segment = 'High-Value (Top 10%)' THEN 1
        WHEN customer_segment = 'Medium-Value (20-40%)' THEN 2
        ELSE 3
    END;


















