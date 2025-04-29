USE gdb023;

/* 1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region. */

SELECT 
	DISTINCT market
FROM
	dim_customer
WHERE
	customer = "Atliq Exclusive"
AND
	region = "APAC";

/* 2. What is the percentage of unique product increase in 2021 vs. 2020? The 
final output contains these fields, 
unique_products_2020 
unique_products_2021 
percentage_chg */


WITH unique_counts AS 
(
  SELECT 
    COUNT(DISTINCT CASE WHEN fiscal_year = 2020 THEN product_code END) AS products_2020,
    COUNT(DISTINCT CASE WHEN fiscal_year = 2021 THEN product_code END) AS products_2021
  FROM 
	fact_sales_monthly
)

SELECT 
  products_2020,
  products_2021,
  ROUND((products_2021 - products_2020) * 100.0 / products_2020, 2) AS percentage_chg
FROM 
	unique_counts;


/*  3. Provide a report with all the unique product counts for each  segment  and 
sort them in descending order of product counts. The final output contains 2 fields, 
segment 
product_count */


SELECT
	DISTINCT segment,
	COUNT(DISTINCT product_code) AS product_count
FROM
	dim_product
GROUP BY
	segment
ORDER BY
	product_count DESC;


/* 4. Follow-up: Which segment had the most increase in unique products in 
2021 vs 2020? The final output contains these fields, 
segment 
product_count_2020 
product_count_2021 
difference */

WITH segment_counts AS 
(
  SELECT
    COUNT(DISTINCT CASE WHEN fsm.fiscal_year = 2020 THEN fsm.product_code END) AS product_count_2020,
    COUNT(DISTINCT CASE WHEN fsm.fiscal_year = 2021 THEN fsm.product_code END) AS product_count_2021,
    dp.segment
  FROM 
	fact_sales_monthly fsm
  JOIN 
	dim_product dp
  ON 
	fsm.product_code = dp.product_code
  GROUP BY 
	dp.segment
)

SELECT
  segment,
  product_count_2020,
  product_count_2021,
  product_count_2021 - product_count_2020 AS difference
FROM 
	segment_counts
ORDER BY 
	difference DESC;

    
    
/* 5. Get the products that have the highest and lowest manufacturing costs. 
The final output should contain these fields, 
product_code 
product 
manufacturing_cost  */

WITH ranked_costs AS 
(
  SELECT 
    mc.product_code,
    dp.product,
    mc.manufacturing_cost,
    RANK() OVER (ORDER BY mc.manufacturing_cost ASC) AS min_rank,
    RANK() OVER (ORDER BY mc.manufacturing_cost DESC) AS max_rank
  FROM 
	fact_manufacturing_cost mc
  JOIN 
	dim_product dp
  ON 
	mc.product_code = dp.product_code
)

SELECT 
  product_code,
  product,
  ROUND(manufacturing_cost, 2) AS manufacturing_cost
FROM 
	ranked_costs
WHERE 
	min_rank = 1 
OR 
	max_rank = 1;
    
    
    
/* 6. Generate a report which contains the top 5 customers who received an 
average high  pre_invoice_discount_pct  for the  fiscal  year 2021  and in the 
Indian  market. The final output contains these fields, 
customer_code 
customer 
average_discount_percentage */

SELECT
	id.customer_code,
    dc.customer,
    ROUND(AVG(pre_invoice_discount_pct), 2) AS avg_high
FROM
	fact_pre_invoice_deductions id
JOIN
	dim_customer dc
  ON
	id.customer_code = dc.customer_code
WHERE
	id.fiscal_year = 2021
AND
	dc.market = "India"
GROUP BY
	id.customer_code,
    dc.customer
ORDER BY
	avg_high DESC
LIMIT 5;



/* 7. Get the complete report of the Gross sales amount for the customer  “Atliq 
Exclusive”  for each month  .  This analysis helps to  get an idea of low and 
high-performing months and take strategic decisions. 
The final report contains these columns: 
Month 
Year 
Gross sales Amount */

SELECT 
    MONTH(sm.date) AS Month,
    YEAR(sm.date) AS Year,
    ROUND(SUM(sm.sold_quantity * gp.gross_price), 2) AS Gross_sales_Amount
FROM
    fact_sales_monthly sm
JOIN
    fact_gross_price gp 
  ON 
	sm.product_code = gp.product_code
  AND 
	sm.fiscal_year = gp.fiscal_year
JOIN
    dim_customer dc 
  ON 
	sm.customer_code = dc.customer_code
WHERE
    dc.customer = "Atliq Exclusive"
GROUP BY 
	Year , Month
ORDER BY 
	Year , Month;





/* 8. In which quarter of 2020, got the maximum total_sold_quantity? The final 
output contains these fields sorted by the total_sold_quantity, 
Quarter 
total_sold_quantity */

SELECT
	CASE
		WHEN MONTH(date) IN (9, 10, 11) THEN "Q1"
        WHEN MONTH(date) IN (12, 1, 2) THEN "Q2"
        WHEN MONTH(date) IN (3, 4, 5) THEN "Q3"
        WHEN MONTH(date) IN (6, 7, 8) THEN "Q4"
	END AS Quater,
    SUM(sold_quantity) AS total_sold_quantity
FROM
	fact_sales_monthly
WHERE
	fiscal_year = 2020
GROUP BY
	Quater;




/* 9. Which channel helped to bring more gross sales in the fiscal year 2021 
and the percentage of contribution?  The final output contains these fields, 
channel 
gross_sales_mln 
percentage */


WITH channel_sales AS
(
	SELECT 
		dc.channel,
		ROUND(SUM(sm.sold_quantity * gp.gross_price) / 1000000, 2) AS gross_sales_mln
	FROM
		fact_sales_monthly sm
	JOIN
		fact_gross_price gp 
	  ON 
		sm.product_code = gp.product_code
	  AND 
		sm.fiscal_year = gp.fiscal_year
	JOIN
		dim_customer dc 
	  ON 
		sm.customer_code = dc.customer_code
	WHERE
		sm.fiscal_year = 2021
	GROUP BY
		dc.channel
)

SELECT 
  cs.channel,
  cs.gross_sales_mln,
  ROUND((cs.gross_sales_mln / SUM(gross_sales_mln) OVER()) * 100, 2) AS percentage
FROM 
	channel_sales cs
ORDER BY 
	cs.gross_sales_mln DESC;




/* 10. Get the Top 3 products in each division that have a high 
total_sold_quantity in the fiscal_year 2021? The final output contains these fields, 
division 
product_code 
product 
total_sold_quantity 
rank_order */

WITH product_sales AS
(
	SELECT
		dp.division,
		sm.product_code,
		dp.product,
		SUM(sm.sold_quantity) AS total_sold_quantity,
		RANK() OVER (PARTITION BY dp.division ORDER BY SUM(sm.sold_quantity) DESC) AS rank_order
	FROM
		fact_sales_monthly sm
	JOIN
		dim_product dp
	  ON 
		sm.product_code = dp.product_code
	WHERE
		sm.fiscal_year = 2021
	GROUP BY 
		dp.division, sm.product_code, dp.product
)

SELECT 
  division,
  product_code,
  product,
  total_sold_quantity,
  rank_order
FROM 
	product_sales
WHERE 
	rank_order <= 3
ORDER BY 
	division, rank_order;







