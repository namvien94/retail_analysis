-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Retail Customer and Revenue Analysis (SQL)
-- MAGIC
-- MAGIC This notebook uses SQL to dig into retail customer and transaction data, uncovering who shops with us, how much they spend, and what drives our sales. We will look at customer demographics, revenue trends, top-performing brands, and how different customer segments behave.
-- MAGIC
-- MAGIC Here are the main business questions we will answer:
-- MAGIC - Who are our main customers?
-- MAGIC - Which brands bring in the most revenue?
-- MAGIC - How does revenue change from month to month?
-- MAGIC - Do drops in revenue match up with changes in customer count?
-- MAGIC - Which customer segments contribute the most to our overall revenue?
-- MAGIC
-- MAGIC By turning raw data into actionable insights, this analysis will help guide decisions on **customer targeting, brand strategy, and sales planning**.

-- COMMAND ----------

-- Display the first 100 rows from the customer table
SELECT * FROM `workspace`.`default`.`retail_customers`
LIMIT 100;

-- COMMAND ----------

-- Display the first 100 rows from the transaction table
SELECT * FROM `workspace`.`default`.`retail_transactions`
LIMIT 100;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Summary statistics for the business
-- MAGIC This query gives a high-level overview of the retail business. It counts unique customers, calculates total revenue, finds the average transaction amount, and shows the smallest and largest transaction amounts. These metrics help establish the scale of the dataset before doing deeper analysis.

-- COMMAND ----------

SELECT COUNT(DISTINCT CUSTOMER_ID) AS TOTAL_CUSTOMERS,
       SUM(TOTAL_AMOUNT) AS TOTAL_REVENUE,
       AVG(TOTAL_AMOUNT) AS AVG_TRANSACTION_AMT,
       MIN(TOTAL_AMOUNT) AS MIN_TRANSACTION_AMT,
       MAX(TOTAL_AMOUNT) AS MAX_TRANSACTION_AMT
  FROM `workspace`.`default`.`retail_transactions`; 

-- COMMAND ----------

-- MAGIC %md
-- MAGIC - There are **26,303** customers who made purchases in the transaction data.
-- MAGIC - Total revenue comes to around **$36M**.
-- MAGIC - The average transaction is about **$1,370**, with amounts ranging from roughly **$10 up to $5,000**.
-- MAGIC - The big difference between the smallest and largest transactions shows that order values can vary a lot.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Customer demographic analysis
-- MAGIC This query joins the customer table with the transaction table so we only analyze customers who actually made purchases. It groups customers into age ranges using a `CASE` statement, then breaks them down by gender and income level. The final count shows how many unique purchasing customers belong to each demographic group.

-- COMMAND ----------

SELECT CASE WHEN customer.AGE BETWEEN 18 AND 24 THEN '18 - 24'
            WHEN AGE BETWEEN 25 AND 34 THEN '25 - 34'
            WHEN AGE BETWEEN 35 AND 44 THEN '35 - 44'
            WHEN AGE BETWEEN 45 AND 54 THEN '45 - 54'
            WHEN AGE BETWEEN 55 AND 64 THEN '55 - 64'
            WHEN AGE > 65 THEN '65+'
            ELSE 'UNKNOWN' 
        END AS AGE_GROUP,
        customer.GENDER AS GENDER,
        customer.INCOME AS INCOME_LEVEL,
        COUNT(DISTINCT customer.CUSTOMER_ID) AS CUSTOMER_COUNT
   FROM `workspace`.`default`.`retail_customers` customer
   JOIN `workspace`.`default`.`retail_transactions` transactions 
     ON customer.CUSTOMER_ID = transactions.CUSTOMER_ID
  GROUP BY AGE_GROUP, GENDER, INCOME_LEVEL;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC - Most purchasing customers are in the **25–34** and **18–24** age groups, making these the largest segments.
-- MAGIC - **Male customers are more common** than female customers in the main age groups.
-- MAGIC - The **medium income group has the most customers**, followed by the low income group, with high income being the smallest.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Brand revenue and rating analysis
-- MAGIC This query identifies which product brands generate the most revenue. It groups transactions by brand, calculates total revenue, calculates average product rating, and ranks brands from highest to lowest revenue. This helps compare financial performance with customer satisfaction.

-- COMMAND ----------

SELECT PRODUCT_BRAND,
       ROUND(SUM(TOTAL_AMOUNT), 2) AS TOTAL_REVENUE,
       ROUND(AVG(RATINGS), 2) AS AVG_RATING,
       RANK() OVER (ORDER BY SUM(TOTAL_AMOUNT) DESC) AS REVENUE_RANK
  FROM `workspace`.`default`.`retail_transactions`
 GROUP BY PRODUCT_BRAND
 ORDER BY REVENUE_RANK;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC - **Pepsi** stands out as the top brand by revenue, bringing in about **$10.33M**, which is much higher than the next brand, **Nike**, at around **$1.91M**.
-- MAGIC - Most of the other leading brands earn revenue in a similar range, typically between **$1.7M** and **$1.9M**.
-- MAGIC - Average ratings are fairly similar for all brands, mostly between **3.0** and **3.4**, so higher revenue is not necessarily linked to higher ratings.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Monthly revenue trend
-- MAGIC This query analyzes revenue by month. It extracts the month number from the transaction date, creates a readable month name, sums revenue for each month, and orders the result chronologically. This helps identify whether revenue is steady or whether some months have noticeable dips.

-- COMMAND ----------

SELECT EXTRACT(MONTH FROM TRANSACTION_DATE) AS TRANSACTION_MONTH,
       TO_CHAR(TRANSACTION_DATE, 'MMMM') AS TRANSACTION_MONTHNAME,
       ROUND(SUM(TOTAL_AMOUNT), 2) AS TOTAL_REVENUE
  FROM `workspace`.`default`.`retail_transactions`
 WHERE TRANSACTION_DATE IS NOT NULL
 GROUP BY TRANSACTION_MONTH, TRANSACTION_MONTHNAME
 ORDER BY TRANSACTION_MONTH;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC - **Monthly revenue stays pretty consistent**, usually landing between **$2.8M and $3.2M**.
-- MAGIC - **July stands out as the top month**, bringing in about **$3.24M** in revenue.
-- MAGIC - **September is the slowest month**, with revenue dipping to around **$2.83M**.
-- MAGIC - Overall, there are some ups and downs, but **no month experiences a major drop in sales**.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Month-over-month revenue and customer changes
-- MAGIC This query uses a CTE to first calculate monthly revenue and monthly customer count. Then it uses the `LAG()` window function to compare each month with the previous month. The result shows whether revenue changes are connected to changes in customer traffic.

-- COMMAND ----------

-- DBTITLE 1,Optimized query
WITH MONTHLY_REVENUE_CUSTOMERS AS (
	SELECT EXTRACT(MONTH FROM TRANSACTION_DATE) AS TRANSACTION_MONTH,
	       TO_CHAR(TRANSACTION_DATE, 'MMMM') AS TRANSACTION_MONTHNAME,
	       ROUND(SUM(TOTAL_AMOUNT), 2) AS TOTAL_REVENUE,
	       COUNT(DISTINCT CUSTOMER_ID) AS CUSTOMER_COUNT
	  FROM `workspace`.`default`.`retail_transactions`
	 WHERE TRANSACTION_DATE IS NOT NULL
	 GROUP BY TRANSACTION_MONTH, TRANSACTION_MONTHNAME
	 ORDER BY TRANSACTION_MONTH
)
SELECT TRANSACTION_MONTH,
       TRANSACTION_MONTHNAME,
       TOTAL_REVENUE,
       CUSTOMER_COUNT,
       ROUND(TOTAL_REVENUE - LAG(TOTAL_REVENUE) OVER (ORDER BY TRANSACTION_MONTH), 2) AS CHANGE_IN_REVENUE,
       CUSTOMER_COUNT - LAG(CUSTOMER_COUNT) OVER (ORDER BY TRANSACTION_MONTH) AS CHANGE_IN_CUSTOMER_COUNT
  FROM MONTHLY_REVENUE_CUSTOMERS
 ORDER BY TRANSACTION_MONTH;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC - **Revenue dips** are noticeable in several months, especially **February, May, August, September, November, and December**.
-- MAGIC - The **biggest month-over-month drop** happens in **August**, with revenue falling by about **$293K** compared to July.
-- MAGIC - The **second largest decline** is in **May**, where revenue drops by around **$232K** from April.
-- MAGIC - Most of these revenue declines line up with a **decrease in customer count**, suggesting that **lower store traffic** is a major reason for the drop in those months.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Customer segment revenue analysis
-- MAGIC This query compares revenue across customer segments such as new, regular, and premium customers. The CTE calculates total revenue, average rating, and customer count for each segment. The final query adds revenue per customer, revenue share percentage, and revenue rank, which helps identify both the largest and most valuable customer segments.

-- COMMAND ----------

WITH SEGMENT_REVENUE AS (
  SELECT CUSTOMER_SEGMENT,
         ROUND(SUM(TOTAL_AMOUNT), 2) AS TOTAL_REVENUE,
         ROUND(AVG(RATINGS), 2) AS AVG_RATING,
         COUNT(DISTINCT customer.CUSTOMER_ID) AS CUSTOMER_COUNT
    FROM `workspace`.`default`.`retail_customers` customer
    JOIN `workspace`.`default`.`retail_transactions` transactions 
      ON customer.CUSTOMER_ID = transactions.CUSTOMER_ID
   GROUP BY CUSTOMER_SEGMENT
)
SELECT COALESCE(CUSTOMER_SEGMENT, 'Unknown')AS CUSTOMER_SEGMENT,
       TOTAL_REVENUE,
       AVG_RATING,
       ROUND(TOTAL_REVENUE/CUSTOMER_COUNT, 2) AS REVENUE_PER_CUSTOMER,
       ROUND(100*TOTAL_REVENUE/SUM(TOTAL_REVENUE) OVER (), 2) AS REVENUE_SHARE_PCT,
       RANK() OVER (ORDER BY TOTAL_REVENUE DESC) AS REVENUE_RANK
  FROM SEGMENT_REVENUE
 ORDER BY REVENUE_RANK;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC - **New customers** bring in the most revenue, totaling about **$14.90M**, that’s **41.28%** of all sales.
-- MAGIC - **Regular customers** come next, generating around **$12.34M** or **34.17%** of the total.
-- MAGIC - **Premium customers** contribute less overall revenue than the other groups, but they stand out with the **highest average rating** at **3.31**.
-- MAGIC - **Revenue per customer** is pretty consistent across all segments, about **$1,367–$1,379**, so the main difference in total revenue comes from the **number of customers in each group**, not from higher spending per person.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Recommendations
-- MAGIC
-- MAGIC ### Customer Targeting  
-- MAGIC   The majority of buyers are young men.   
-- MAGIC   Consider expanding product offerings tailored to this demographic, or implement targeted marketing campaigns to attract more female customers and achieve a balanced customer base.
-- MAGIC
-- MAGIC ### Brand Performance  
-- MAGIC   Top-selling brands do not always receive the highest ratings.   
-- MAGIC   Investigate potential reasons why well-rated brands are not generating higher sales, such as limited visibility, pricing strategies, or inventory constraints.
-- MAGIC
-- MAGIC ### Monthly Sales Drops  
-- MAGIC   Sales decline in February, May, August, September, November, and December, typically coinciding with reduced customer traffic.   
-- MAGIC   Implementing promotions or special offers during these months may help increase both traffic and revenue.
-- MAGIC
-- MAGIC ### Customer Segment Strategy  
-- MAGIC   While new customers contribute the highest total revenue, regular customers lead in revenue per person.   
-- MAGIC   Prioritize strategies to retain regular customers and motivate others to move into higher-value segments.
