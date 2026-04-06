CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    customer_name TEXT,
    city TEXT,
    segment TEXT,
    signup_date DATE,
    age_group TEXT,
    last_purchase_date DATE
);

CREATE TABLE products (
    product_id INT PRIMARY KEY,
    product_name TEXT,
    category TEXT,
    sub_category TEXT,
    brand TEXT,
    cost_price NUMERIC(10,2),
    selling_price NUMERIC(10,2),
    rating NUMERIC(3,2),
    stock_quantity INT
);

CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    order_date DATE,
    customer_id INT,
    product_id INT,
    quantity INT,
    price NUMERIC(10,2),
    order_status TEXT,
    payment_method TEXT,
    shipping_cost NUMERIC(10,2),
    delivery_date DATE,
    rating NUMERIC(3,2),

    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- ===================
-- Data Quality Check
-- ===================

-- Checking for Missing Values
SELECT * FROM orders
WHERE order_id IS NULL
   OR customer_id IS NULL
   OR product_id IS NULL;

SELECT *
FROM products
WHERE product_id IS NULL;

SELECT *
FROM customers
WHERE customer_id IS NULL;

-- Checking Dublicates
SELECT order_id, COUNT(*)
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;

SELECT customer_id, COUNT(*)
FROM customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

SELECT product_id, COUNT(*)
FROM products
GROUP BY product_id
HAVING COUNT(*) > 1;

-- Mapping
SELECT *
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

SELECT *
FROM orders o
LEFT JOIN products p ON o.product_id = p.product_id
WHERE p.product_id IS NULL;

--Data types/Values check
SELECT *
FROM orders
WHERE quantity <= 0
   OR price <= 0
   OR shipping_cost < 0;

SELECT *
FROM orders
WHERE delivery_date < order_date;

-- product logic check
SELECT *
FROM products
WHERE selling_price < cost_price;

--- ===========================
--- View Table and Clalulations
--- ===========================
CREATE OR REPLACE VIEW final_sales_view AS
WITH base AS (
    SELECT 
        o.order_id,
        o.order_date,
        o.customer_id,
        c.customer_name,
        c.city,
        c.segment,
        o.product_id,
        p.product_name,
        p.category,
        p.sub_category,
        p.cost_price,
        o.quantity,
        o.price,
        o.order_status,
        o.payment_method,
        o.shipping_cost,
        o.delivery_date,
        o.rating
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    JOIN products p ON o.product_id = p.product_id
),

calc AS (
    SELECT *,
        CASE 
            WHEN category = 'Electronics' THEN 0.10
            WHEN category = 'Furniture' THEN 0.20
            WHEN category = 'Clothing' THEN 0.30
            ELSE 0
        END AS discount_pct
    FROM base
),

final AS (
    SELECT *,
        price * quantity * discount_pct AS discount,
        CASE 
            WHEN order_status = 'Cancelled' THEN 0
            WHEN order_status = 'Returned' THEN (price*quantity - (price*quantity*discount_pct)) * 0.5
            ELSE (price*quantity - (price*quantity*discount_pct))
        END AS revenue,
        cost_price * quantity AS cost
    FROM calc
)

SELECT *,
    revenue - cost AS profit,
    CASE WHEN revenue = 0 THEN 0 ELSE (revenue - cost)/revenue END AS profit_margin,
    CASE 
        WHEN discount_pct <= 0.1 THEN 'Low'
        WHEN discount_pct <= 0.2 THEN 'Medium'
        ELSE 'High'
    END AS discount_band,
    CASE WHEN (revenue - cost) > 0 THEN 1 ELSE 0 END AS is_profitable,
    CASE 
        WHEN (revenue - cost) < 0 THEN 'Loss'
        WHEN (revenue - cost) <= 30000 THEN 'Low'
        WHEN (revenue - cost) <= 80000 THEN 'Medium'
        ELSE 'High'
    END AS profit_band,
    (delivery_date - order_date) AS delivery_time
FROM final;

select * from final_sales_view;


