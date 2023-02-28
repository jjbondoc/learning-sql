--How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
SELECT
    DATEADD('day', 4, DATE_TRUNC('week', REGISTRATION_DATE)) WEEK_START,
	COUNT(RUNNER_ID) NO_RUNNERS
FROM
	RUNNERS
GROUP BY
	WEEK_START;

--What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
SELECT
	RUNNER_ID,
    ROUND(AVG(DATEDIFF('second', ORDER_TIME, PICKUP_TIME))/60, 1) AVG_MIN
FROM
	CUSTOMER_ORDERS a
    	INNER JOIN
        	RUNNER_ORDERS b
            	ON a.ORDER_ID = b.ORDER_ID
WHERE
	PICKUP_TIME != 'null'
GROUP BY
	RUNNER_ID;

--Is there any relationship between the number of pizzas and how long the order takes to prepare?
WITH ORDER_TIME AS (
SELECT
	a.ORDER_ID,
    DATEDIFF('second', ORDER_TIME, PICKUP_TIME) TIME_SEC,
    COUNT(a.ORDER_ID) NO_PIZZAS
FROM
	CUSTOMER_ORDERS a
    	INNER JOIN
        	RUNNER_ORDERS b
            	ON a.ORDER_ID = b.ORDER_ID
WHERE
	PICKUP_TIME != 'null'
GROUP BY
	a.ORDER_ID,
    DATEDIFF('second', ORDER_TIME, PICKUP_TIME)
)

SELECT * FROM ORDER_TIME;

SELECT
	NO_PIZZAS,
    ROUND(AVG(TIME_SEC)/60,1) AVG_MIN
FROM ORDER_TIME
GROUP BY NO_PIZZAS;

--What was the average distance travelled for each customer?
SELECT
	CUSTOMER_ID,
    AVG(
        CASE
        	WHEN DISTANCE != 'null' THEN TRIM(SPLIT_PART(DISTANCE, 'k', 1))
            ELSE NULL
        END
    ) AVG_DISTANCE_KM
FROM
	(SELECT DISTINCT CUSTOMER_ID, ORDER_ID FROM CUSTOMER_ORDERS) a
    	JOIN
        	RUNNER_ORDERS b
            	ON a.ORDER_ID = b.ORDER_ID
GROUP BY
	CUSTOMER_ID;

--What was the difference between the longest and shortest delivery times for all orders?
SELECT
	MAX(REGEXP_REPLACE(DURATION, '[^0-9]', '')::NUMBER) - MIN(REGEXP_REPLACE(DURATION, '[^0-9]', '')::NUMBER) DURATION_RANGE
FROM
	RUNNER_ORDERS
WHERE DURATION != 'null';

--What was the average speed for each runner for each delivery and do you notice any trend for these values?
SELECT
	RUNNER_ID,
    ORDER_ID,
    (REGEXP_REPLACE(DISTANCE, '[^0-9]', '')::NUMBER)/(REGEXP_REPLACE(DURATION, '[^0-9]', '')::NUMBER)SPEED_KM_PER_MIN
FROM
	RUNNER_ORDERS
WHERE 
	PICKUP_TIME != 'null';

--What is the successful delivery percentage for each runner?
SELECT
	RUNNER_ID,
    COUNT(RUNNER_ID) TOTAL_ORDERS,
    SUM(
    	CASE PICKUP_TIME
        	WHEN 'null' THEN 0
            ELSE 1
        END
    ) SUCCESS,
    ROUND(SUCCESS/TOTAL_ORDERS, 2) SUCCESS_PERC
FROM
	RUNNER_ORDERS
GROUP BY
	RUNNER_ID;