USE bike_store_database;

/* I've been working with the "Bike Store Relational Database SQL" dataset, which I found on Kaggle. 
This dataset contains information related to a fictional bike store and includes various tables 
like orders, customers, products, staff members, and stores. I've been using SQL queries to 
extract insights from this dataset. For instance, I've crafted queries to spot 
duplicate products, count late orders by staff members, analyze rejected sales by salespeople and their respective bike shops, 
and assess product sales within specific timeframes. 
These queries have allowed me to demonstrate how SQL can be used to query, 
analyze, and gain insights from relational databases, 
providing valuable information for decision-making and enhancing business operations 
within the context of a bike store or a similar retail setting. */

-- Select all columns and count the occurrences of each product name
SELECT
    *,
    COUNT(*) -- Count how many times each product name appears
FROM 
    products
GROUP BY 
    product_name
HAVING 
    COUNT(*) > 1; -- Only return rows where the count is greater than 1 (i.e., duplicates)

    
    
-- Delete duplicate products based on product name, keeping the one with the higher product_id
DELETE t1 FROM products t1
INNER JOIN products t2
WHERE
    t1.product_id < t2.product_id
    AND t1.product_name = t2.product_name;
    
    
-- Create a new column 'status_order' in the orders table that assigns a descriptive status label based on the 'order_status' value:
-- - 1 is labeled as 'Pending'
-- - 2 is labeled as 'Processing'
-- - 3 is labeled as 'Rejected'
-- All other 'order_status' values are labeled as 'Shipped'
SELECT 
    *,
    CASE
        WHEN order_status = 1 THEN 'Pending'
        WHEN order_status = 2 THEN 'Processing'
        WHEN order_status = 3 THEN 'Rejected'
        ELSE 'Shipped'
    END status_order
FROM
    orders;



    
    



-- Select all customer information for the customer who placed an order with order_id = 1
SELECT 
    *
FROM
    bike_store_database.customers
WHERE
    customer_id = (SELECT 
            customer_id
        FROM
            orders
        WHERE
            order_id = 1);

            
            
-- Retrieve a recursive list of staff members and their managers
WITH Recursive EmployeeHierarchy AS (
    SELECT  s.staff_id, s.first_name, s.last_name, s.manager_id
    FROM bike_store_database.staffs s
    UNION ALL
    SELECT e.staff_id, e.first_name, e.last_name, e.manager_id
    FROM bike_store_database.staffs e
    INNER JOIN EmployeeHierarchy eh ON e.manager_id = eh.staff_id
)
SELECT DISTINCT 
	*
FROM EmployeeHierarchy;



-- Set the phone field to a space (' ') if it is NULL
UPDATE customers 
SET 
    phone = IFNULL(phone, ' ');



-- Calculate total sales and number of sales for each store
WITH stores_sales AS (   
SELECT
	s.store_name,
    ((oi.quantity*oi.list_price)-oi.discount) sales
FROM 
	stores s
JOIN orders o 
	ON s.store_id = o.store_id
JOIN order_items oi
	ON o.order_id = oi.order_id)
    
SELECT DISTINCT 
	store_name,
    ROUND(SUM(sales) OVER (PARTITION BY store_name), 2) sales,
    COUNT(sales) OVER (PARTITION BY store_name) number_of_sales
FROM
	stores_sales
ORDER BY 
	sales DESC;


            
            
            
            

-- Calculate product sales ranking based on total quantity sold
WITH pro_sold AS (
SELECT  DISTINCT 
	p.product_name,
    SUM(oi.quantity) OVER (PARTITION BY oi.product_id) num_sold
FROM
	order_items oi
JOIN products p
	ON oi.product_id = p.product_id
ORDER BY
	num_sold DESC)
SELECT
	product_name,
	DENSE_RANK() OVER (ORDER BY num_sold DESC) rank_sold
FROM
	pro_sold
ORDER BY
	rank_sold;

        
        
        


-- Count the total number of late orders for each staff member
SELECT
	s.last_name,
    COUNT(*) total_late_orders
FROM
	orders o
JOIN staffs s 
	ON o.store_id = s.store_id
WHERE
	required_date < shipped_date
GROUP BY
	s.staff_id,
    s.last_name
ORDER BY
	total_late_orders DESC;

    
    



    
    
-- Calculate total sales for each staff member
WITH staff_sales AS (
SELECT
	s.last_name,
    (oi.quantity * oi.list_price) - oi.discount AS sales
FROM 
	staffs s
JOIN orders o
ON s.staff_id = o.staff_id
JOIN order_items oi 
	ON o.order_id = oi.order_id)

SELECT DISTINCT
	last_name,
    ROUND(SUM(sales) OVER (PARTITION BY last_name), 2) sales
FROM
	staff_sales
ORDER BY
	sales DESC;


            
  
-- Calculate product sales for 2016, including total sales and number of sales
WITH product_sales AS(  
SELECT
	p.product_id,
    b.brand_name,
    p.product_name,
    p.model_year,
    oi.list_price,
	(oi.quantity*oi.list_price) - oi.discount AS sales,
    o.order_date
FROM
	products p 
JOIN order_items oi
	ON p.product_id = oi.product_id
JOIN orders o
	ON oi.order_id = o.order_id
JOIN brands b 
	ON b.brand_id = p.brand_id)
    
SELECT DISTINCT 
	product_id,
    brand_name,
    product_name,
    list_price,
    ROUND(SUM(sales) OVER (PARTITION BY product_name), 2) sales,
    COUNT(sales) OVER (PARTITION BY product_name) num_sales
FROM
	product_sales
WHERE
	order_date BETWEEN '2016-01-01' AND '2016-12-31'
ORDER BY
	sales DESC;

	


-- Create a report on rejected sales per salesperson and their respective bike shop.
-- This query retrieves information about rejected sales orders and counts them per salesperson,
-- while also identifying the associated bike shop (store).

-- Common Table Expression (CTE) 'rejected_sales' is used to gather data on rejected sales:
-- - It selects customer last names, product names, order dates, salesperson last names, order statuses,
--   and the store names for orders with an 'order_status' of 3 (which indicates 'Rejected').
-- - The CTE helps organize and filter the relevant data.

-- In the main query:
-- - We select distinct salesperson last names, store names (bike shops), and count the number of 'order_status' values
--   for each salesperson. The COUNT() function operates as a window function, partitioning the count by salesperson.
-- - The results are ordered in descending order of rejected sales.

WITH rejected_sales AS (    
    SELECT
        c.last_name AS customer,
        p.product_name,
        o.order_date,
        s.last_name AS sales_men,
        o.order_status,
        st.store_name
        
    FROM
        orders o
    JOIN customers c 
        ON 	o.customer_id = c.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    JOIN products p
        ON oi.product_id = p.product_id
    JOIN staffs s 
        ON s.staff_id = o.staff_id
	JOIN stores st 
		ON s.store_id = st.store_id
    WHERE
        order_status = 3
)
SELECT DISTINCT 
    sales_men,
    store_name AS bike_shop,
    COUNT(order_status) OVER(PARTITION BY sales_men) rejected_sales
FROM
    rejected_sales
ORDER BY
    rejected_sales DESC;


