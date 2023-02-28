--How many pizzas were ordered?
SELECT
	COUNT(*) AS PIZZAS_ORDERED
FROM
	CUSTOMER_ORDERS;

--How many unique customer orders were made?
SELECT
	COUNT(DISTINCT ORDER_ID) UNIQUE_ORDERS
FROM
	CUSTOMER_ORDERS;

--How many successful orders were delivered by each runner?
SELECT
	RUNNER_ID,
	COUNT(DISTINCT ORDER_ID) DELIVERED_ORDERS
FROM
	RUNNER_ORDERS
WHERE 
	PICKUP_TIME != 'null'
GROUP BY RUNNER_ID;

--How many of each type of pizza was delivered?
SELECT
	PIZZA_NAME,
	COUNT(*) DELIVERED_ORDERS
FROM
	CUSTOMER_ORDERS a
    	INNER JOIN
			RUNNER_ORDERS b
            	ON a.ORDER_ID = b.ORDER_ID
        INNER JOIN
        	PIZZA_NAMES c
            	ON a.PIZZA_ID = c.PIZZA_ID
        	
WHERE 
	PICKUP_TIME != 'null'
GROUP BY PIZZA_NAME;

--How many Vegetarian and Meatlovers were ordered by each customer?
SELECT
	CUSTOMER_ID,
	PIZZA_NAME,
    COUNT(ORDER_ID) PIZZAS_ORDERED
FROM
	CUSTOMER_ORDERS a
    	INNER JOIN
        	PIZZA_NAMES b
            	ON a.PIZZA_ID = b.PIZZA_ID
GROUP BY
	CUSTOMER_ID,
    PIZZA_NAME;

--What was the maximum number of pizzas delivered in a single order?
SELECT
	a.ORDER_ID,
    COUNT(a.ORDER_ID) PIZZAS
FROM 
	CUSTOMER_ORDERS a
    	INNER JOIN
        	RUNNER_ORDERS b
            	ON a.ORDER_ID = b.ORDER_ID
WHERE 
	PICKUP_TIME != 'null'
GROUP BY
	a.ORDER_ID
ORDER BY
	COUNT(a.ORDER_ID) DESC
LIMIT 1;

--For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
SELECT
	a.CUSTOMER_ID,
    SUM(
        CASE
        	WHEN EXCLUSIONS IN ('', 'null') AND (EXTRAS IN ('', 'null') OR EXTRAS IS NULL) THEN 0 
        	ELSE 1
        END
    ) CHANGED_ZZA, --* flag the changed orders
    SUM(
        CASE
            WHEN EXCLUSIONS IN ('', 'null') AND (EXTRAS IN ('', 'null') OR EXTRAS IS NULL) THEN 1
            ELSE 0
        END
    ) UNCHANGED_ZZA --* flag the unchanged orders
FROM 
	CUSTOMER_ORDERS a
		INNER JOIN
        	RUNNER_ORDERS b
            	ON a.ORDER_ID = b.ORDER_ID
WHERE
    b.PICKUP_TIME != 'null'
GROUP BY
	a.CUSTOMER_ID;

--How many pizzas were delivered that had both exclusions and extras?
SELECT
    SUM(
        CASE
        	WHEN EXCLUSIONS NOT IN ('', 'null') AND (EXTRAS NOT IN ('', 'null') AND EXTRAS IS NOT NULL) THEN 1
        	ELSE 0
        END
    ) pizzas_delivered_with_exclusions_and_extras
FROM 
	CUSTOMER_ORDERS a
		INNER JOIN
        	RUNNER_ORDERS b
            	ON a.ORDER_ID = b.ORDER_ID
WHERE
    b.PICKUP_TIME != 'null';

--What was the total volume of pizzas ordered for each hour of the day?
SELECT
	DATE_PART('hour', ORDER_TIME) TIME_HOUR,
    COUNT(ORDER_ID) ORDERED_ZZAS
FROM
	CUSTOMER_ORDERS
GROUP BY
	TIME_HOUR;

--What was the volume of orders for each day of the week?
SELECT
	DAYNAME(ORDER_TIME) TIME_DAY,
    COUNT(ORDER_ID) ORDERED_ZZAS
FROM
	CUSTOMER_ORDERS
GROUP BY
	TIME_DAY;
