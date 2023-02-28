--What are the standard ingredients for each pizza?
SELECT
	c.PIZZA_NAME,
    d.TOPPING_NAME
FROM 
	PIZZA_RECIPES a
    	LEFT JOIN
        	LATERAL SPLIT_TO_TABLE(a.TOPPINGS, ', ') b --* You can left join the result of SPLIT_TO_TABLE (which splits values into rows); however, if the value being split is null, then the whole row disappears. To avoid this, contain the results of the SPLIT_TO_TABLE in a CTE and then join this back to the main table
        LEFT JOIN
        	PIZZA_NAMES c
            	ON a.PIZZA_ID = c.PIZZA_ID
        LEFT JOIN
        	PIZZA_TOPPINGS d
            	ON b.VALUE = d.TOPPING_ID
ORDER BY
	PIZZA_NAME, TOPPING_NAME;
                
--What was the most commonly added extra?
SELECT
    c.TOPPING_NAME,
    COUNT(c.TOPPING_NAME)
FROM
	CUSTOMER_ORDERS a
    	LEFT JOIN
        	LATERAL SPLIT_TO_TABLE(a.EXTRAS, ', ') b
        JOIN
        	PIZZA_TOPPINGS c
            	ON b.VALUE = c.TOPPING_ID
WHERE
	EXTRAS IS NOT NULL AND
    EXTRAS NOT IN ('', 'null')
GROUP BY
	c.TOPPING_NAME
ORDER BY
	COUNT(c.TOPPING_NAME) DESC
LIMIT 1;

--What was the most common exclusion?
SELECT
    c.TOPPING_NAME,
    COUNT(c.TOPPING_NAME)
FROM
	CUSTOMER_ORDERS a
    	LEFT JOIN
        	LATERAL SPLIT_TO_TABLE(a.EXCLUSIONS, ', ') b
        JOIN
        	PIZZA_TOPPINGS c
             	ON b.VALUE = c.TOPPING_ID
WHERE
	EXCLUSIONS IS NOT NULL AND
    EXCLUSIONS NOT IN ('', 'null')
GROUP BY
	c.TOPPING_NAME
ORDER BY
	COUNT(c.TOPPING_NAME) DESC
LIMIT 1;

--Generate an order item for each record in the customers_orders table in the format of one of the following:
--    Meat Lovers
--    Meat Lovers - Exclude Beef
--    Meat Lovers - Extra Bacon
--    Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers
WITH PARSED AS (
SELECT
	ORDER_ID,
    a.PIZZA_ID,
    PIZZA_NAME,
    d.TOPPING_NAME EXCLUSION_NAME,
    e.TOPPING_NAME EXTRA_NAME
FROM
	(SELECT
    	ORDER_ID,
        PIZZA_ID,
        EXCLUSIONS,
        CASE WHEN EXTRAS IS NULL THEN 'null' ELSE EXTRAS END EXTRAS
    FROM
    	CUSTOMER_ORDERS) a
    	LEFT JOIN
        	LATERAL SPLIT_TO_TABLE(a.EXCLUSIONS, ', ') b
        LEFT JOIN
        	LATERAL SPLIT_TO_TABLE(a.EXTRAS, ', ') c
        LEFT JOIN
        	PIZZA_TOPPINGS d
            	ON b.VALUE = d.TOPPING_ID::STRING
        LEFT JOIN
        	PIZZA_TOPPINGS e
            	ON c.VALUE = e.TOPPING_ID::STRING
        LEFT JOIN
        	PIZZA_NAMES f
            	ON a.PIZZA_ID = f.PIZZA_ID
)

SELECT
	ORDER_ID,
    PIZZA_ID,
    PIZZA_NAME,
    LISTAGG(DISTINCT EXCLUSION_NAME, ', ') EXCLUSIONS,
    LISTAGG(DISTINCT EXTRA_NAME, ', ') EXTRAS,
    CASE
    	WHEN EXCLUSIONS != '' AND EXTRAS != ''
        	THEN PIZZA_NAME || ' - Exlude ' || EXCLUSIONS || ' - Extra ' || EXTRAS
        WHEN EXCLUSIONS != ''
        	THEN PIZZA_NAME || ' - Exlude ' || EXCLUSIONS
        WHEN EXTRAS != ''
        	THEN PIZZA_NAME || ' - Extra ' || EXTRAS
        ELSE PIZZA_NAME
    END CUSTOMER_ORDER
FROM 
	PARSED
GROUP BY 
	ORDER_ID,
	PIZZA_ID,
    PIZZA_NAME
ORDER BY
	ORDER_ID,
    PIZZA_ID;

--Generate an alphabetically ordered comma separated ingredient list for each pizza order from the CUSTOMER_ORDERS_CTE table and add a 2x in front of any relevant ingredients
--    For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"

--list of pizzas with exclusions, a single row per excluded ingredient
WITH CUSTOMER_ORDERS_CTE AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY ORDER_ID, PIZZA_ID) RN, --* this is required for identifying 2 orders of the same exact pizza
        a.*
    FROM CUSTOMER_ORDERS a
),

EXCL AS (
    SELECT
        RN,
    	ORDER_ID,
        PIZZA_ID,
        b.VALUE EXCLUSIONS
    FROM 
    	CUSTOMER_ORDERS_CTE,
    	LATERAL SPLIT_TO_TABLE(EXCLUSIONS, ', ') b
    WHERE
    	LENGTH(EXCLUSIONS) > 0 AND EXCLUSIONS != 'null'
),

--list of pizzas with extras, a single row per extra ingredient
EXT AS (
    SELECT
        RN,
    	ORDER_ID,
        PIZZA_ID,
        b.VALUE EXTRAS
    FROM 
    	CUSTOMER_ORDERS_CTE,
    	LATERAL SPLIT_TO_TABLE(EXTRAS, ', ') b
    WHERE
    	LENGTH(EXTRAS) > 0 AND EXTRAS != 'null'
),

--list of the standard pizza ingredients, a single row per ingredient
STANDARD AS (
    SELECT 
    	PIZZA_ID,
    	b.VALUE STANDARD
    FROM 
    	PIZZA_RECIPES,
    	LATERAL SPLIT_TO_TABLE(TOPPINGS, ', ') b
),

--join all 3 subqueries above to the orders table to gather the standard ingredients, exlucsions and extras for each pizza order
JOIN_ALL AS (
	SELECT
        a.RN,
    	a.ORDER_ID,
        a.PIZZA_ID,
        g.PIZZA_NAME,
        -- b.STANDARD,
        -- c.EXCLUSIONS,
        -- d.EXTRAS
        e.TOPPING_NAME STANDARD_FULL,
        f.TOPPING_NAME EXTRA_FULL,
        CASE --* step to count the extra ingredients
        	WHEN EXTRA_FULL IS NULL THEN STANDARD_FULL
            ELSE '2x ' || STANDARD_FULL
        END INGR
    FROM CUSTOMER_ORDERS_CTE a
    	LEFT JOIN
        	STANDARD b
            	ON a.PIZZA_ID = b.PIZZA_ID
        LEFT JOIN
        	EXCL c
            	ON a.RN = c.RN
                AND a.ORDER_ID = c.ORDER_ID
                AND a.PIZZA_ID = c.PIZZA_ID
                AND b.STANDARD = c.EXCLUSIONS --join standard with exclusion ingredients, to be filtered out
        LEFT JOIN
        	EXT d
            	ON a.RN = d.RN
                AND a.ORDER_ID = d.ORDER_ID
                AND a.PIZZA_ID = d.PIZZA_ID
                AND b.STANDARD = d.EXTRAS --join standard with extra ingredients, to be counted
        LEFT JOIN
        	PIZZA_TOPPINGS e
            	ON b.STANDARD = e.TOPPING_ID
        LEFT JOIN
        	PIZZA_TOPPINGS f
            	ON d.EXTRAS = f.TOPPING_ID
        LEFT JOIN
        	PIZZA_NAMES g
            	ON a.PIZZA_ID = g.PIZZA_ID
                
WHERE
    c.EXCLUSIONS IS NULL --keep ingredients that are not excluded
),

AGG AS (
	SELECT
        RN,
    	ORDER_ID,
        PIZZA_ID,
        PIZZA_NAME || ' - ' || LISTAGG(DISTINCT INGR, ', ') WITHIN GROUP (ORDER BY INGR) ORDER_NAME
    FROM
    	JOIN_ALL
    GROUP BY
        RN,
    	ORDER_ID,
        PIZZA_ID,
        PIZZA_NAME
)

SELECT
	*
FROM 
	AGG 
ORDER BY
	RN,
	ORDER_ID, 
    PIZZA_ID;

--What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?
WITH CUSTOMER_ORDERS_CTE AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY a.ORDER_ID, PIZZA_ID) RN,
        a.ORDER_ID,
        a.PIZZA_ID,
        a.EXCLUSIONS,
        a.EXTRAS
    FROM CUSTOMER_ORDERS a
        INNER JOIN
            RUNNER_ORDERS b
                ON a.ORDER_ID = b.ORDER_ID
    WHERE
    	b.PICKUP_TIME != 'null'
    	
),

EXCL AS (
    SELECT
    	RN,
    	ORDER_ID,
        PIZZA_ID,
        b.VALUE EXCLUSIONS
    FROM 
    	CUSTOMER_ORDERS_CTE,
    	LATERAL SPLIT_TO_TABLE(EXCLUSIONS, ', ') b
    WHERE
    	LENGTH(EXCLUSIONS) > 0 AND EXCLUSIONS != 'null'
),

--list of pizzas with extras, a single row per extra ingredient
EXT AS (
    SELECT
    	RN,
    	ORDER_ID,
        PIZZA_ID,
        b.VALUE EXTRAS
    FROM 
    	CUSTOMER_ORDERS_CTE,
    	LATERAL SPLIT_TO_TABLE(EXTRAS, ', ') b
    WHERE
    	LENGTH(EXTRAS) > 0 AND EXTRAS != 'null'
),

--list of the standard pizza ingredients, a single row per ingredient
STANDARD AS (
    SELECT 
    	PIZZA_ID,
    	b.VALUE STANDARD
    FROM 
    	PIZZA_RECIPES,
    	LATERAL SPLIT_TO_TABLE(TOPPINGS, ', ') b
),

--join all 3 subqueries above to the orders table to gather the standard ingredients, exlucsions and extras for each pizza order
JOIN_ALL AS (
	SELECT
    	a.RN,
    	a.ORDER_ID,
        a.PIZZA_ID,
        b.STANDARD::NUMBER STANDARD
    FROM CUSTOMER_ORDERS_CTE a
    	LEFT JOIN
        	STANDARD b
            	ON a.PIZZA_ID = b.PIZZA_ID
        LEFT JOIN
        	EXCL c
            	ON a.RN = c.RN
                AND a.ORDER_ID = c.ORDER_ID
                AND a.PIZZA_ID = c.PIZZA_ID
                AND b.STANDARD = c.EXCLUSIONS --join standard with exclusion ingredients, to be filtered out
        -- LEFT JOIN
        -- 	PIZZA_TOPPINGS e
        --     	ON b.STANDARD = e.TOPPING_ID
        -- LEFT JOIN
        -- 	PIZZA_TOPPINGS f
        --     	ON d.EXTRAS = f.TOPPING_ID
    WHERE
        c.EXCLUSIONS IS NULL --keep ingredients that are not excluded

    UNION ALL
        
        SELECT
        	RN,
        	ORDER_ID,
            PIZZA_ID,
            EXTRAS::NUMBER
        FROM 
        	EXT
)

SELECT TOPPING_NAME, COUNT(TOPPING_NAME)
FROM JOIN_ALL a
	INNER JOIN
    	PIZZA_TOPPINGS b
        	ON a.STANDARD = b.TOPPING_ID
GROUP BY TOPPING_NAME
ORDER BY COUNT(TOPPING_NAME) DESC;