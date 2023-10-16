--create a new customer_orders table
-- DROP TABLE IF EXISTS customer_orders1; --to avoid duplicate table
-- CREATE TABLE customer_orders1 AS
-- (
-- 	SELECT order_id,
-- 			customer_id,
--  			pizza_id,
--  			CASE WHEN exclusions ~ E'^\\d+$' THEN CAST(exclusions AS INT) ELSE 0 END exclusions,
-- 			CASE WHEN extras = '' OR extras = 'null' THEN NULL ELSE extras END extras,
-- 			order_time
-- 	FROM pizza_runner.customer_orders
-- );

DROP TABLE IF EXISTS customer_orders1; --to avoid duplicate table
CREATE TABLE customer_orders1 AS
(
	SELECT order_id,
			customer_id,
 			pizza_id,
 			CASE WHEN exclusions = '' OR exclusions = 'null' THEN NULL ELSE exclusions END exclusions,
			CASE WHEN extras = '' OR extras = 'null' THEN NULL ELSE extras END extras,
			order_time
	FROM pizza_runner.customer_orders
);

--create a new 'runner_orders' table
/*RUNNER ORDER*/
DROP TABLE IF EXISTS runner_orders1;
CREATE TABLE runner_orders1 AS
  (SELECT order_id,
    runner_id,
    CASE WHEN pickup_time = 'null' THEN NULL ELSE CAST(pickup_time AS TIMESTAMP) END AS pickup_time,
    CASE WHEN distance = 'null' THEN NULL ELSE CAST(TRIM(' ' FROM TRIM('km' FROM distance)) AS FLOAT) END distance_km, --removes the 'km' and ' km' from all rows including converting 'null' string to empty cells
    CASE WHEN duration = 'null' THEN NULL ELSE LEFT(duration, 2)::INT END AS duration_mins, --only returns the first 2 values
    CASE WHEN cancellation = 'null' OR cancellation = '' THEN NULL ELSE cancellation END AS cancellation
  FROM pizza_runner.runner_orders)

/*PIZZA METRICS*/

-- 1. How many pizzas were ordered?
SELECT COUNT(order_id)
FROM public.customer_orders1;

-- 2. How many unique customer orders were made?
SELECT COUNT(DISTINCT order_id)
FROM public.customer_orders1;


-- 3. How many successful orders were delivered by each runner?
SELECT COUNT(c.order_id)
FROM public.customer_orders1 c
FULL OUTER JOIN public.runner_orders1 r
ON c.order_id = r.order_id
WHERE r.cancellation IS NULL;

-- 4. How many of each type of pizza was delivered?
SELECT pizza_id, COUNT(c.pizza_id) amt_delivered
FROM public.customer_orders1 c
FULL OUTER JOIN public.runner_orders1 r
ON c.order_id = r.order_id
WHERE r.cancellation IS NULL
GROUP BY 1;

-- 5. How many Vegetarian and Meatlovers were ordered by each customer?
SELECT c. customer_id, p.pizza_name, COUNT(p.pizza_name) amt_pizza
FROM public.customer_orders1 c
JOIN pizza_runner.pizza_names p
ON p.pizza_id = c.pizza_id
GROUP BY 1,2
ORDER BY 1;

-- 6. What was the maximum number of pizzas delivered in a single order?
SELECT r.order_id, COUNT(r.order_id) amt_order
FROM public.customer_orders1 c
JOIN pizza_runner.pizza_names p
ON p.pizza_id = c.pizza_id
FULL OUTER JOIN public.runner_orders1 r
ON c.order_id = r.order_id
GROUP BY 1
ORDER BY 2 DESC
LIMIT 1;

/* 7. For each customer, how many delivered pizzas had at least 1 change 
and how many had no changes? */
SELECT c.customer_id, COUNT(c.exclusions) del_pizza
FROM public.customer_orders1 c
FULL OUTER JOIN public.runner_orders1 r
ON c.order_id = r.order_id
WHERE r.cancellation IS NULL AND c.exclusions IS NOT NULL
GROUP BY 1;

-- 8. How many pizzas were delivered that had both exclusions and extras?
SELECT COUNT(*)
FROM public.customer_orders1 c
FULL OUTER JOIN public.runner_orders1 r
ON c.order_id = r.order_id
WHERE r.cancellation IS NULL AND c.exclusions IS NOT NULL AND c.extras IS NOT NULL;

-- 9. What was the total volume of pizzas ordered for each hour of the day?
SELECT order_id, DATE_TRUNC('hour', order_time), COUNT(order_id) num_orders
FROM public.customer_orders1
GROUP BY 1,2
ORDER BY 1;

-- 10. What was the volume of orders for each day of the week?
-- SELECT CASE WHEN week_rank == 1 THEN week_rank = 
SELECT DATE_PART('day', order_time) day_of_week, 
		COUNT(order_id) num_orders
FROM public.customer_orders1
GROUP BY 1
ORDER BY 1





-- B. Runner and Customer Experience
DROP TABLE IF EXISTS pizza_names1; --create pizza_names table
CREATE TABLE pizza_names1 AS
(
	SELECT *
	FROM pizza_runner.pizza_names
);

DROP TABLE IF EXISTS pizza_recipes1; --create pizza_recipes table
CREATE TABLE pizza_recipes1 AS
(
	SELECT *
	FROM pizza_runner.pizza_recipes
);

DROP TABLE IF EXISTS pizza_toppings1; --create pizza_toppings table
CREATE TABLE pizza_toppings1 AS
(
	SELECT *
	FROM pizza_runner.pizza_toppings
);

DROP TABLE IF EXISTS runners1; --create runners table
CREATE TABLE runners1 AS
(
	SELECT *
	FROM pizza_runner.runners
);

-- B. Runner and Customer Experience

/* 1. How many runners signed up for each 1 week period? 
	(i.e. week starts 2021-01-01)? */
SELECT ROW_NUMBER() OVER(ORDER BY week_trunc) week,
		runners
FROM
(
	SELECT DATE_TRUNC('week', registration_date) week_trunc,
			COUNT(runner_id) runners
	FROM public.runners1
	WHERE registration_date >= '2021-01-01'
	GROUP BY 1);



/* 2. What was the average time in minutes it took for each runner 
	to arrive at the Pizza Runner HQ to pickup the order? */
SELECT r.runner_id, 
		ROUND(AVG(DATE_PART('minutes', r.pickup_time - c.order_time))::NUMERIC, 2) avg_pickup_minutes 
FROM public.runner_orders1 r
JOIN public.customer_orders1 c
ON r.order_id = c.order_id
GROUP BY 1;

/* 3. Is there any relationship between the number of pizzas and 
	how long the order takes to prepare? */

SELECT num_pizza,
		AVG(time_diff)
FROM
(
	SELECT 
		r.order_id, 
		COUNT(r.order_id) num_pizza,
		AVG(AGE(r.pickup_time, c.order_time)) time_diff
	FROM public.runner_orders1 r
	INNER JOIN public.customer_orders1 c
	ON r.order_id = c.order_id
	WHERE r.pickup_time IS NOT NULL
	GROUP BY 1)
GROUP BY 1;


-- 4. What was the average distance travelled for each customer?
SELECT c.customer_id, ROUND(AVG(r.distance_km)::NUMERIC, 2) avg_del_dist
FROM public.runner_orders1 r
JOIN public.customer_orders1 c
ON r.order_id = c.order_id
WHERE r.distance_km != 0
GROUP BY 1;

/* 5. What was the difference between the longest and shortest 
	delivery times for all orders? */
SELECT MAX(duration_mins) - MIN(duration_mins) del_range
FROM public.runner_orders1 r
WHERE r.distance_km != 0;

/* 6. What was the average speed for each runner for each delivery 
	and do you notice any trend for these values? */
SELECT runner_id,
		order_id,
		ROUND(AVG(runner_speed)::NUMERIC, 2) avg_del_speed
FROM 
(
	SELECT c.order_id,
			r.runner_id,
			(r.distance_km*1000/(r.duration_mins*60)) runner_speed
	FROM public.runner_orders1 r
	JOIN public.customer_orders1 c
	ON r.order_id = c.order_id
	WHERE distance_km != 0
)
GROUP BY 1,2
ORDER BY 3;
-- runner with id number 3 runs fastest

-- 7. What is the successful delivery percentage for each runner?
WITH total_runner AS
(
	SELECT runner_id,
			COUNT(runner_id) each_runner_del_count
	FROM public.runner_orders1
	GROUP BY 1
	
)


SELECT sub.runner_id,
		((SUM(no_cancellation)/t.each_runner_del_count)*100) :: INT AS pecentage_del_success
FROM
(
	SELECT runner_id, 
			cancellation,
			SUM(CASE WHEN cancellation IS NULL THEN 1 ELSE 0 END) no_cancellation
	FROM public.runner_orders1
	GROUP BY 1,2
) sub
JOIN total_runner t
ON t.runner_id = sub.runner_id
GROUP BY 1, t.each_runner_del_count
ORDER BY 1

-- C. Ingredient Optimisation

UPDATE public.pizza_recipes1
SET toppings = REPLACE(
    REPLACE(
        REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(
                                REPLACE(
									REPLACE(
										REPLACE(
											REPLACE(toppings,'12', 'Tomato Sauce'),
											'11', 'Tomatoes'),
                                        '10', 'Salami'),
                                    '9', 'Peppers'),
                                '8', 'Pepperoni'),
                            '7', 'Onions'),
                        '6', 'Mushrooms'),
                    '5', 'Chicken'),
                '4', 'Cheese'),
            '3', 'Beef'),
        '2', 'BBQ Sauce'),
    '1', 'Bacon');



-- 1. What are the standard ingredients for each pizza?
SELECT a.pizza_name, b.toppings
FROM public.pizza_names1 a
JOIN public.pizza_recipes1 b
ON b.pizza_id=a.pizza_id;

-- 2. What was the most commonly added extra?
SELECT *
FROM public.customer_orders1;

-- 3. What was the most common exclusion?
WITH customer_orders1_extras AS
(
	SELECT *, 
				LEFT(extras, 1)::INT AS first_extra, 
				CASE 
					WHEN SUBSTRING(extras FROM 4 FOR 1) = '' THEN NULL 
					ELSE SUBSTRING(extras FROM 4 FOR 1) 
				END::INT AS second_extra
		FROM public.customer_orders1
)

SELECT extras, topping_name
FROM
(
	SELECT first_extra AS extras FROM customer_orders1_extras
	UNION ALL
	SELECT second_extra AS extras FROM customer_orders1_extras
) a
JOIN public.pizza_toppings1 b
ON a.extras = b.topping_id
GROUP BY 1,2, b.topping_id
ORDER BY COUNT(extras) DESC
LIMIT 1;

-- 4. Generate an order item for each record in the customers_orders table in the format of one of the following:
-- a. Meat Lovers
-- b. Meat Lovers - Exclude Beef
-- c. Meat Lovers - Extra Bacon
-- d. Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers
SELECT *,
		CASE 
			WHEN pizza_name = 'Meatlovers' AND exclusions IS NULL AND extras IS NULL THEN NULL 
			WHEN pizza_name = 'Meatlovers' AND exclusions LIKE '%3%' THEN 'Meat Lovers - Exclude Beef'
			WHEN pizza_name = 'Meatlovers' AND extras LIKE '1, 4' AND exclusions LIKE '2, 6' THEN 'Meat Lovers - Exclude BBQ Sauce, Mushrooms - Extra Bacon, Cheese'
			WHEN pizza_name = 'Meatlovers' AND exclusions LIKE '4' AND extras LIKE '1, 5' THEN 'Meat Lovers - Exclude Cheese - Extra Bacon, Chicken'
			WHEN pizza_name = 'Meatlovers' AND exclusions LIKE '4' AND extras IS NULL THEN 'Meat Lovers - Exclude Cheese'
			WHEN pizza_name = 'Meatlovers' AND exclusions IS NULL AND extras = '1' THEN 'Meat Lovers - Extra Bacon'
			WHEN pizza_name = 'Vegetarian' AND exclusions IS NULL AND extras = '1' THEN 'Vegie Lovers - Extra Bacon'
			WHEN pizza_name = 'Vegetarian' AND exclusions = '4' AND extras IS NULL THEN 'Vegie Lovers - Exclude Cheese'
			ELSE 'Vegie Lovers' 
		END AS order_item
FROM public.pizza_names1 p
JOIN public.customer_orders1 c
ON c.pizza_id=p.pizza_id;


/* 5. Generate an alphabetically ordered comma separated ingredient list for 
each pizza order from the customer_orders table and add a 2x in front of any 
relevant ingredients. For example: "Meat Lovers: 2xBacon, Beef, ... , Salami" */
WITH t1 AS
(SELECT order_id,
 		customer_id,
 		pizza_id,
 		exclusions,
 		extras,
 		order_time,
		CASE 
			WHEN exclusions LIKE '4' AND extras LIKE '1, 5' 
					THEN REPLACE
							(REPLACE(
								REPLACE(new_toppings, 'Bacon', 'Bacon x2'),
							'Cheese', ''),
						'Chicken', 'Chicken x2')  ELSE new_toppings
			END AS new_toppings
FROM(
	SELECT order_id,
 		customer_id,
 		c.pizza_id,
 		exclusions,
 		extras,
 		order_time,
			CASE 
				WHEN exclusions IN ('4') THEN REPLACE(toppings, ', Cheese', '') 
				WHEN exclusions IN ('2, 6') AND extras IN ('1, 4') 
					THEN REGEXP_REPLACE
							(REGEXP_REPLACE(
								REGEXP_REPLACE(toppings, ', BBQ Sauce|, Mushrooms', ''),
							'Bacon', 'Bacon x2'),
						'Cheese', 'Cheese x2') 
				ELSE toppings
			END AS new_toppings
	FROM public.customer_orders1 c
	JOIN public.pizza_recipes1 p
	ON c.pizza_id=p.pizza_id))


/* 6. What is the total quantity of each ingredient used in all delivered pizzas 
sorted by most frequent first? */
SELECT *, ARRAY_LENGTH(string_to_array(new_toppings, ', '), 1) ingredient_qty
FROM t1

-- D. Pricing and Ratings

/* --1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were 
no charges for changes - how much money has Pizza Runner made so far if there 
are no delivery fees? */
SELECT runner_id, SUM(cost_$) dollars_made
FROM(
	SELECT *, 
			CASE 
				WHEN p.pizza_id = 1  THEN 12
				WHEN p.pizza_id = 2  THEN 10 ELSE 0
			END cost_$
	FROM public.pizza_names1 p
	NATURAL JOIN public.customer_orders1 c 
	NATURAL JOIN public.runner_orders1 r 
	WHERE cancellation IS NULL)
GROUP BY 1;



-- 2. What if there was an additional $1 charge for any pizza extras?
-- Add cheese is $1 extra
SELECT *,
		CASE 
			WHEN extras IS NOT NULL AND extras LIKE '%4%' THEN cost_$+2
			WHEN extras IS NOT NULL THEN cost_$ + 1 ELSE cost_$ END AS extra_cost
FROM(
		SELECT *, 
				CASE 
					WHEN p.pizza_id = 1 THEN 12
					WHEN p.pizza_id = 2 THEN 10 ELSE 0
				END cost_$
		FROM public.pizza_names1 p
		NATURAL JOIN public.customer_orders1 c 
		NATURAL JOIN public.runner_orders1 r 
		WHERE cancellation IS NULL
);
/* 3. The Pizza Runner team now wants to add an additional ratings system 
that allows customers to rate their runner, how would you design an additional 
table for this new dataset - generate a schema for this new table and insert your 
own data for ratings for each successful customer order between 1 to 5.*/
DROP TABLE IF EXISTS customer_ratings;
CREATE TABLE customer_ratings (
	"customer_id" INT,
	"order_id" INT,
	"rating" INT NOT NULL,
	"comment" TEXT,
	"rate_time" TIMESTAMP
);
INSERT INTO public.customer_ratings (customer_id, order_id, rating, comment)
VALUES
    (101, 2, 5, 'Great delivery!'),
    (102, 3, 4, 'Good service'),
    (103, 4, 3, 'Average delivery'),
    (104, 5, 5, 'Excellent runner'),
    (105, 7, 1, 'Needs improvement');

SELECT *
FROM public.customer_ratings;


/* 4. Using your newly generated table - can you join all of the information 
together to form a table which has the following information for successful 
deliveries? */
-- customer_id
-- order_id
-- runner_id
-- rating
-- order_time
-- pickup_time
-- Time between order and pickup
-- Delivery duration
-- Average speed
-- Total number of pizzas
SELECT customer_id,
		order_id,
		runner_id,
		rating,
		order_time,
		pickup_time,
		DATE_PART('minutes', pickup_time - order_time) AS time_btw_order_and_pickup_mins,
		duration_mins,
		ROUND(AVG(distance_km)::NUMERIC,2) avg_km_distance,
		COUNT(order_id) num_of_pizza
		
FROM public.customer_orders1 r
NATURAL JOIN public.customer_ratings cr
NATURAL JOIN public.runner_orders1
GROUP BY 1,2,3,4,5,6,7,8
ORDER BY 1;

/* 5. If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost 
for extras and each runner is paid $0.30 per kilometre traveled - how much money 
does Pizza Runner have left over after these deliveries? */
SELECT runner_id, 
		SUM(money_made) money_made
FROM(
	SELECT runner_id,
			CASE 
					WHEN pizza_id = 1  THEN ROUND(12 + SUM(distance_km * 0.30)::NUMERIC, 2)
					WHEN pizza_id = 2  THEN 10 + ROUND(SUM(distance_km * 0.30)::NUMERIC, 2) ELSE 0
				END money_made
	FROM public.customer_orders1
	NATURAL JOIN public.runner_orders1
	WHERE cancellation IS NULL
	GROUP BY 1, customer_orders1.pizza_id
	ORDER BY 1
)
GROUP BY 1
