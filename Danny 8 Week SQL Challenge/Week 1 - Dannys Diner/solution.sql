-- What is the total amount each customer spent at the restaurant?
SELECT 
	a.CUSTOMER_ID,
    SUM(b.PRICE) TOTAL_SPENT
FROM SALES a
	JOIN
    	MENU b
        ON a.PRODUCT_ID = b.PRODUCT_ID
GROUP BY
	a.CUSTOMER_ID;

-- How many days has each customer visited the restaurant?
SELECT 
    CUSTOMER_ID,
    COUNT(DISTINCT ORDER_DATE) NO_DAYS_VISITED
FROM
	SALES
GROUP BY CUSTOMER_ID;
    
-- What was the first item from the menu purchased by each customer?
WITH RANKS AS (
SELECT
	s.CUSTOMER_ID,
    s.ORDER_DATE,
    s.PRODUCT_ID,
    m.PRODUCT_NAME,
    RANK() OVER (PARTITION BY s.CUSTOMER_ID ORDER BY s.ORDER_DATE ASC) RANK,
    DENSE_RANK() OVER (PARTITION BY s.CUSTOMER_ID ORDER BY s.ORDER_DATE ASC) DENSE_RANK,
    ROW_NUMBER() OVER (PARTITION BY s.CUSTOMER_ID ORDER BY s.ORDER_DATE ASC) UNIQUE_RANK
FROM
	SALES s
    	JOIN
        	MENU m
            ON s.PRODUCT_ID = m.PRODUCT_ID
ORDER BY
	1, 2
)
SELECT CUSTOMER_ID,
	PRODUCT_NAME
FROM RANKS
WHERE RANK = 1;

-- What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT
	s.CUSTOMER_ID,
    m.PRODUCT_NAME,
    COUNT(m.PRODUCT_NAME) ORDERS
FROM
	SALES s
    	INNER JOIN
        	MENU m
            ON s.PRODUCT_ID = m.PRODUCT_ID
WHERE 
	s.PRODUCT_ID = (
        SELECT
        	PRODUCT_ID
        FROM
        	SALES
        GROUP BY
        	PRODUCT_ID
        ORDER BY
        	COUNT(PRODUCT_ID) DESC
        LIMIT 1
	)
GROUP BY
	CUSTOMER_ID,
    PRODUCT_NAME;

-- Which item was the most popular for each customer?
--* I didn't know you could use both Group By and Window Functions in the same Select query
WITH ORDER_COUNT AS (
SELECT
	s.CUSTOMER_ID,
    m.PRODUCT_NAME,
    COUNT(m.PRODUCT_NAME) ORDERS,
    RANK() OVER (PARTITION BY s.CUSTOMER_ID ORDER BY COUNT(m.PRODUCT_NAME) DESC) RNK 
FROM 
	SALES s
		INNER JOIN
    		MENU m
            ON s.PRODUCT_ID = m.PRODUCT_ID
GROUP BY
	s.CUSTOMER_ID,
    m.PRODUCT_NAME
)
SELECT
	CUSTOMER_ID,
    PRODUCT_NAME
FROM ORDER_COUNT
WHERE RNK = 1;

-- Which item was purchased first by the customer after they became a member?
WITH RNK AS (
SELECT
	s.CUSTOMER_ID,
    s.ORDER_DATE,
    men.PRODUCT_NAME,
    RANK() OVER (PARTITION BY s.CUSTOMER_ID ORDER BY ORDER_DATE ASC) RNK
FROM
	SALES s
    	INNER JOIN
        	MENU men
            ON s.PRODUCT_ID = men.PRODUCT_ID
        INNER JOIN
        	MEMBERS mem
            ON s.CUSTOMER_ID = mem.CUSTOMER_ID
            AND s.ORDER_DATE >= mem.JOIN_DATE
)

SELECT
	CUSTOMER_ID,
    ORDER_DATE,
	PRODUCT_NAME
FROM RNK
WHERE RNK = 1;

-- Which item was purchased just before the customer became a member?
WITH RNK AS (
SELECT
	s.CUSTOMER_ID,
    s.ORDER_DATE,
    men.PRODUCT_NAME,
    RANK() OVER (PARTITION BY s.CUSTOMER_ID ORDER BY ORDER_DATE DESC) RNK
FROM
	SALES s
    	INNER JOIN
        	MENU men
            ON s.PRODUCT_ID = men.PRODUCT_ID
        INNER JOIN
        	MEMBERS mem
            ON s.CUSTOMER_ID = mem.CUSTOMER_ID
            AND s.ORDER_DATE < mem.JOIN_DATE
)

SELECT
	CUSTOMER_ID,
    ORDER_DATE,
	PRODUCT_NAME
FROM RNK
WHERE RNK = 1;

-- What is the total items and amount spent for each member before they became a member?
SELECT
	s.CUSTOMER_ID,
	COUNT(men.PRODUCT_NAME) NO_ITEMS,
    SUM(men.PRICE) TOTAL_AMOUNT
FROM
	SALES s
    	INNER JOIN
        	MENU men
            ON s.PRODUCT_ID = men.PRODUCT_ID
        INNER JOIN
        	MEMBERS mem
            ON s.CUSTOMER_ID = mem.CUSTOMER_ID
            AND s.ORDER_DATE < mem.JOIN_DATE
GROUP BY
	s.CUSTOMER_ID;


-- If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
SELECT
	s.CUSTOMER_ID,
    SUM(
    	CASE men.PRODUCT_NAME
    		WHEN 'sushi' THEN men.PRICE * 10 * 2
        	ELSE men.PRICE * 10
        END
    ) TOTAL_POINTS
FROM
	SALES s
    	INNER JOIN
        	MENU men
            ON s.PRODUCT_ID = men.PRODUCT_ID
GROUP BY
	s.CUSTOMER_ID;

-- In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
SELECT
	s.CUSTOMER_ID,
    SUM(
    	CASE 
    		WHEN (men.PRODUCT_NAME = 'sushi' OR s.ORDER_DATE BETWEEN mem.JOIN_DATE AND DATEADD('day', 6, mem.JOIN_DATE)) THEN men.PRICE * 10 * 2
        	ELSE men.PRICE * 10
        END
    ) TOTAL_POINTS
FROM 
	SALES s
    	INNER JOIN
        	MENU men
            ON s.PRODUCT_ID = men.PRODUCT_ID
        INNER JOIN
        	MEMBERS mem
            ON s.CUSTOMER_ID = mem.CUSTOMER_ID
WHERE
    s.ORDER_DATE < '2021-02-01'
GROUP BY
	s.CUSTOMER_ID;