
# Project on Finance Analytics of AtliQ Hardware (IT solution service provider company)

# Business Problem-

AtliQ hardware is having enormous data of various verticals. They are interested in getting the insights about financial statistics of their customers, platforms, markets, product and its variants, regions and zones etc.

I have performed various sql queries to get insights. I have used stored procedures, views, CTEs, functions in this project etc. 
----------------------------------------------------------------------------------------------------------------------------------------------------


Step 1). Generate the report of individual product sales (aggregated on a monthly basis at the product level) for croma India customer for FY-2021 financial (fiscal year) so that it can track individual product sales and run further product analytics on it in excel. 


I have created a function called 'get_fiscal_year' and 'get_fiscal_quarter' to use it in the query to get the instant fiscal year. 
I have also created a view 'gross_sales'for the same to get the report using simple line of code.

Atliq Financial year (fiscal year 2021) -- (Sept 2020- Aug 2021)

So, 1 Sept 2020 = 1 jan 2021 
    1 Aug  2021 = 1 dec 2021

-Gross Sales Report: Monthly Product Transactions 


SELECT 
    s.date,
    s.product_code,
    s.customer_code,
    s.sold_quantity,
    p.product,
    p.variant,
    g.gross_price, 
	s.sold_quantity *  g.gross_price as gross_price_total
FROM
    gdb0041.fact_sales_monthly s
        JOIN
    dim_product p ON s.product_code = p.product_code
        JOIN
    fact_gross_price g ON g.product_code = s.product_code
        AND g.fiscal_year = GET_FISCAL_YEAR(s.date)
WHERE
    customer_code = 90002002
        AND GET_FISCAL_YEAR(date) = 2021 AND get_fiscal_quarter(date) = "Q4"
ORDER BY date ASC;


Functions- 


1) get_fiscal_year

CREATE DEFINER=`root`@`localhost` FUNCTION `get_fiscal_year`(calendar_date date) RETURNS int
    DETERMINISTIC
BEGIN
declare fiscal_year int;
set fiscal_year= year(date_add(calendar_date, interval 4 month));
RETURN fiscal_year;
END

2) get_fiscal_quarter

CREATE DEFINER=`root`@`localhost` FUNCTION `get_fiscal_quarter`(
calendar_date date) RETURNS char(2) CHARSET utf8mb4
    DETERMINISTIC
BEGIN
    declare fiscal_quarter tinyint;
    declare qtr char(2);
    set fiscal_quarter= month(calendar_date);

     case 
          when fiscal_quarter IN (9,10,11) then set qtr= 'Q1';
		  when fiscal_quarter IN (12,1,2) then set qtr= 'Q2';
		  when fiscal_quarter IN (3,4,5) then set qtr= 'Q3';
          when fiscal_quarter IN (6,7,8) then set qtr= 'Q4';
	 End case;
	
RETURN qtr;
END

----------------------------------------------------------------------------------------------------------------------------------------------------

Step 2) Calculate aggregated monthly gross sales for any given customer with their code. 



SELECT 
    s.date as fiscal_year,
    ROUND(SUM(g.gross_price * s.sold_quantity), 2) AS Gross_price_total
FROM
    gdb0041.fact_sales_monthly s
        JOIN
    fact_gross_price g ON s.product_code = g.product_code
   AND g.fiscal_year = GET_FISCAL_YEAR(s.date)  
WHERE
    s.customer_code=90002002
GROUP BY s.date
ORDER BY s.date ASC;

[Function has used in join so that, in case if we want to retrieve any specific year report then can be possible by using where clause  in query.]
----------------------------------------------------------------------------------------------------------------------------------------------------

Step 3) Created stored procedures to get the monthly gross sales report for any customer.  


CREATE PROCEDURE `get_monthly_gross_sales_for_customers`(
c_code text  )

SELECT 
    s.date,
    ROUND(SUM(g.gross_price * s.sold_quantity), 2) AS Gross_price_total
FROM
    gdb0041.fact_sales_monthly s
        JOIN
    fact_gross_price g ON s.product_code = g.product_code
        AND g.fiscal_year = GET_FISCAL_YEAR(s.date)
WHERE
    find_in_set(customer_code, c_code )>0 
GROUP BY s.date
ORDER BY s.date ASC;

END

----------------------------------------------------------------------------------------------------------------------------------------------------

step 4) Created a view for pre-invoice deductions to find out net invoice sales

CREATE VIEW `sales_preinv_discount` AS
    SELECT 
        `s`.`date` AS `date`,
        `s`.`fiscal_year` AS `fiscal_year`,
        `c`.`market` AS `market`,
        `s`.`product_code` AS `product_code`,
        `s`.`customer_code` AS `customer_code`,
        `s`.`sold_quantity` AS `sold_quantity`,
        `p`.`product` AS `product`,
        `p`.`variant` AS `variant`,
        `g`.`gross_price` AS `gross_price`,
        (`s`.`sold_quantity` * `g`.`gross_price`) AS `gross_price_total`,
        `pre`.`pre_invoice_discount_pct` AS `pre_invoice_discount_pct`
    FROM
         `fact_sales_monthly` `s`
        JOIN `dim_customer` `c` 
              ON `c`.`customer_code` = `s`.`custome/r_code`
        JOIN `dim_product` `p` 
              ON `s`.`product_code` = `p`.`product_code`
        JOIN `fact_gross_price` `g` 
              ON `g`.`product_code` = `s`.`product_code`AND `g`.`fiscal_year` = `s`.`fiscal_year`
        JOIN `fact_pre_invoice_deductions` `pre` 
              ON `pre`.`customer_code` = `s`.`customer_code` AND `pre`.`fiscal_year` = `s`.`fiscal_year`
----------------------------------------------------------------------------------------------------------------------------------------------------

step 5)  To find out net_invoice_sales using the created view 'sales_preinv_discount'


SELECT  *, (gross_price_total - gross_price_total * pre_invoice_discount_pct`) as net_invoice_sales
FROM sales_preinv_discount;

----------------------------------------------------------------------------------------------------------------------------------------------------

step 6)  Created a view for post invoice deductions ie.`sales_postinv_discount`


CREATE VIEW `sales_postinv_discount` AS
    SELECT 
        `s`.`date` AS `date`,
        `s`.`fiscal_year` AS `fiscal_year`,
        `s`.`customer_code` AS `customer_code`,
        `s`.`product_code` AS `product_code`,
        `s`.`market` AS `market`,
        `s`.`product` AS `product`,
        `s`.`variant` AS `variant`,
        `s`.`sold_quantity` AS `sold_quantity`,
        `s`.`gross_price_total` AS `gross_price_total`,
        `s`.`pre_invoice_discount_pct` AS `pre_invoice_discount_pct`,
        (`s`.`gross_price_total` - (`s`.`gross_price_total` * `s`.`pre_invoice_discount_pct`)) AS `net_invoice_sales`,
        (`po`.`discounts_pct` + `po`.`other_deductions_pct`) AS `post_invoice_discount_pct`
    FROM `sales_preinv_discount` `s`
       JOIN `fact_post_invoice_deductions` `po` ON `s`.`date` = `po`.`date` AND `s`.`customer_code` = `po`.`customer_code`
        AND `s`.`product_code` = `po`.`product_code`

----------------------------------------------------------------------------------------------------------------------------------------------------

step 6) Created a report for net sales

SELECT *, net_invoice_sales*(1-post_invoice_discount_pct) as net_sales
FROM sales_postinv_discount;

----------------------------------------------------------------------------------------------------------------------------------------------------

step 7) Created a view for `net_sales`

CREATE VIEW `net_sales` AS
    SELECT 
        `sales_postinv_discount`.`date` AS `date`,
        `sales_postinv_discount`.`fiscal_year` AS `fiscal_year`,
        `sales_postinv_discount`.`customer_code` AS `customer_code`,
        `sales_postinv_discount`.`product_code` AS `product_code`,
        `sales_postinv_discount`.`market` AS `market`,
        `sales_postinv_discount`.`product` AS `product`,
        `sales_postinv_discount`.`variant` AS `variant`,
        `sales_postinv_discount`.`sold_quantity` AS `sold_quantity`,
        `sales_postinv_discount`.`gross_price_total` AS `gross_price_total`,
        `sales_postinv_discount`.`pre_invoice_discount_pct` AS `pre_invoice_discount_pct`,
        `sales_postinv_discount`.`net_invoice_sales` AS `net_invoice_sales`,
        `sales_postinv_discount`.`post_invoice_discount_pct` AS `post_invoice_discount_pct`,
        (1 - `post_invoice_discount_pct`) * `net_invoice_sales` AS `net_sales`
    FROM
        `sales_postinv_discount`

----------------------------------------------------------------------------------------------------------------------------------------------------

step 8) Retrieve top 5 market by net sales in fiscal year 2021

SELECT Market, Round(sum(net_sales)/1000000, 2) as netsales_mln
FROM gdb0041.net_sales
where fiscal_year = 2021
group by Market
order by netsales desc
limit 5;


----------------------------------------------------------------------------------------------------------------------------------------------------

step 9) Find out customer wise net sales percentage contribution 


with cte1 as (
select 
		customer, 
		round(sum(net_sales)/1000000,2) as net_sales_mln
from net_sales s
join dim_customer c
		on s.customer_code=c.customer_code
where s.fiscal_year=2021
group by customer)

select *, net_sales_mln*100/sum(net_sales_mln) over() as pct_net_sales
from cte1
order by net_sales_mln desc;

----------------------------------------------------------------------------------------------------------------------------------------------------

step 10)  Retrieve customer wise net sales distibution per region for FY 2021

with cte1 as (
select 
	c.customer,
	c.region,
	round(sum(net_sales)/1000000,2) as net_sales_mln
	from gdb0041.net_sales n
	join dim_customer c
		on n.customer_code=c.customer_code
where fiscal_year=2021
group by c.customer, c.region)

select *, net_sales_mln*100/sum(net_sales_mln) over (partition by region) as pct_share_region
from cte1
order by region, pct_share_region desc;

----------------------------------------------------------------------------------------------------------------------------------------------------

step 11)  Retrieve top 5 products from each division by total quantity sold in a given fiscal year 2021

with cte1 as 

(SELECT  division, p.product, sum(sold_quantity) as total_quantity

FROM gdb0041.fact_sales_monthly s
join dim_product p
on s.product_code = p.product_code
where fiscal_year = 2021
group by division, p.product), 

cte2 as (select*, dense_rank() over (partition by division order by total_quantity desc) as Top_rank
from cte1 )

select * from cte2
where Top_rank <= 5

----------------------------------------------------------------------------------------------------------------------------------------------------
step 12)  Find out top 5 products by net_sales

SELECT product, round(Sum(net_sales)/1000000, 2) as netsalesmln
FROM  gdb0041.net_sales
where fiscal_year = 2021
group by product
order by netsalesmln desc
limit 5;


----------------------------------------------------------------------------------------------------------------------------------------------------
step 13)  To get the forecast accuracy

with forecast_error_table as (SELECT 
s.customer_code,
sum(sold_quantity) as total_sold_qty, 
sum(forecast_quantity) as total_forecast_qty,
sum((forecast_quantity- sold_quantity)) as net_error,
sum((forecast_quantity- sold_quantity))*100/ sum(forecast_quantity) as Net_error_pct,
sum(abs(forecast_quantity- sold_quantity)) as abs_error,
sum(abs(forecast_quantity- sold_quantity))*100/sum(forecast_quantity) as abs_error_pct
FROM gdb0041.fact_act_est s
where fiscal_year = 2021
group by customer_code
order by abs_error_pct desc)

select e.*, c.customer, c.market, if(abs_error_pct>100, 0, 100-abs_error_pct) as forecast_accuracy
from forecast_error_table e
join dim_customer c
on e.customer_code = c.customer_code
order by forecast_accuracy desc;

----------------------------------------------------------------------------------------------------------------------------------------------------






