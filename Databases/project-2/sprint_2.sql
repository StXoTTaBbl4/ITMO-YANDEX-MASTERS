CREATE TYPE cafe.restaurant_type AS ENUM (
    'coffee_shop',
    'restaurant',
    'bar',
    'pizzeria'
);

CREATE TABLE cafe.restaurants (
    restaurant_uuid uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    restaurant_name varchar(50) NOT NULL,
    location geometry(Point, 4326),
    type cafe.restaurant_type NOT NULL,
    menu jsonb
);

CREATE TABLE cafe.managers (
    manager_uuid uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    manager_name varchar(50) NOT NULL,
    manager_phone varchar(50)
);

CREATE TABLE cafe.restaurant_manager_work_dates (
    restaurant_uuid uuid NOT NULL
        REFERENCES cafe.restaurants(restaurant_uuid),
    manager_uuid uuid NOT NULL
        REFERENCES cafe.managers(manager_uuid),
    work_start_date date NOT NULL,
    work_end_date date,
    PRIMARY KEY (restaurant_uuid, manager_uuid),
    CHECK (work_end_date IS NULL OR work_end_date >= work_start_date)
);

CREATE TABLE cafe.sales (
    date date NOT NULL,
    restaurant_uuid uuid NOT NULL
        REFERENCES cafe.restaurants(restaurant_uuid),
    avg_check numeric(6, 2),
    PRIMARY KEY (date, restaurant_uuid)
);

INSERT INTO cafe.managers (manager_name, manager_phone)
SELECT DISTINCT
    manager,
    manager_phone
FROM raw_data.sales
WHERE manager IS NOT NULL;

INSERT INTO cafe.restaurants (restaurant_name, location, type, menu)
SELECT
    s.cafe_name,
    ST_SetSRID(ST_MakePoint(s.longitude, s.latitude), 4326) AS location,
    s.type::cafe.restaurant_type,
    m.menu
FROM (
    SELECT DISTINCT ON (cafe_name)
        cafe_name,
        type,
        latitude,
        longitude
    FROM raw_data.sales
    WHERE cafe_name IS NOT NULL
    ORDER BY cafe_name, report_date DESC
) AS s
LEFT JOIN raw_data.menu AS m
    ON s.cafe_name = m.cafe_name;

INSERT INTO cafe.restaurant_manager_work_dates (
    restaurant_uuid,
    manager_uuid,
    work_start_date,
    work_end_date
)
SELECT
    r.restaurant_uuid,
    m.manager_uuid,
    MIN(s.report_date) AS work_start_date,
    MAX(s.report_date) AS work_end_date
FROM raw_data.sales AS s
JOIN cafe.restaurants AS r
    ON r.restaurant_name = s.cafe_name
JOIN cafe.managers AS m
    ON m.manager_name  = s.manager
   AND m.manager_phone = s.manager_phone
GROUP BY r.restaurant_uuid, m.manager_uuid;

INSERT INTO cafe.sales (date, restaurant_uuid, avg_check)
SELECT
    s.report_date,
    r.restaurant_uuid,
    s.avg_check
FROM raw_data.sales AS s
JOIN cafe.restaurants AS r
    ON r.restaurant_name = s.cafe_name;

-- ЗАДАНИЕ 1
CREATE OR REPLACE VIEW cafe.top3_restaurants_by_avg_check AS
WITH avg_checks AS (
    SELECT
        restaurant_uuid,
        AVG(avg_check) AS avg_check
    FROM cafe.sales
    GROUP BY restaurant_uuid
),
ranked AS (
    SELECT
        r.restaurant_name,
        r.type,
        ROUND(a.avg_check, 2) AS avg_check,
        ROW_NUMBER() OVER (
            PARTITION BY r.type
            ORDER BY a.avg_check DESC
        ) AS rn
    FROM avg_checks AS a
    JOIN cafe.restaurants AS r
        ON r.restaurant_uuid = a.restaurant_uuid
)
SELECT
    restaurant_name AS "Название заведения",
    type            AS "Тип заведения",
    avg_check       AS "Средний чек"
FROM ranked
WHERE rn <= 3
ORDER BY type, rn;
ПРОВЕРКА
SELECT restaurant_uuid, AVG(avg_check)
FROM cafe.sales
GROUP BY restaurant_uuid

-- ЗАДАНИЕ 2
CREATE MATERIALIZED VIEW cafe.avg_check_yearly_change AS
WITH yearly AS (
    SELECT
        r.restaurant_uuid,
        r.restaurant_name,
        r.type,
        EXTRACT(YEAR FROM s.date)::int AS year,
        ROUND(AVG(s.avg_check), 2)     AS avg_check
    FROM cafe.sales AS s
    JOIN cafe.restaurants AS r
        ON r.restaurant_uuid = s.restaurant_uuid
    WHERE EXTRACT(YEAR FROM s.date) <> EXTRACT(YEAR FROM CURRENT_DATE)
    GROUP BY r.restaurant_uuid, r.restaurant_name, r.type, EXTRACT(YEAR FROM s.date)
),
with_lag AS (
    SELECT
        year,
        restaurant_name,
        type,
        avg_check,
        LAG(avg_check) OVER (
            PARTITION BY restaurant_uuid
            ORDER BY year
        ) AS prev_avg_check
    FROM yearly
)
SELECT
    year                                                   AS "Год",
    restaurant_name                                        AS "Название заведения",
    type                                                   AS "Тип заведения",
    avg_check                                              AS "Средний чек в этом году",
    prev_avg_check                                         AS "Средний чек в предыдущем году",
    ROUND(
        (avg_check - prev_avg_check) / prev_avg_check * 100,
        2
    )                                                      AS "Изменение среднего чека в %"
FROM with_lag
ПРОВЕРКА
SELECT * FROM cafe.avg_check_yearly_change LIMIT 20;
SELECT DISTINCT "Год" FROM cafe.avg_check_yearly_change ORDER BY 1;
SELECT * FROM cafe.avg_check_yearly_change
WHERE "Средний чек в предыдущем году" IS NULL
LIMIT 5;

-- ЗАДАНИЕ 3
SELECT
    r.restaurant_name                AS "Название заведения",
    COUNT(DISTINCT wd.manager_uuid)  AS "Сколько раз менялся менеджер"
FROM cafe.restaurant_manager_work_dates AS wd
JOIN cafe.restaurants AS r
    ON r.restaurant_uuid = wd.restaurant_uuid
GROUP BY r.restaurant_name
ORDER BY COUNT(DISTINCT wd.manager_uuid) DESC, r.restaurant_name
LIMIT 3;

-- ЗАДАНИЕ 4
WITH pizzeria_menu AS (
    SELECT
        restaurant_name,
        menu -> 'Пицца' AS pizzas
    FROM cafe.restaurants
    WHERE type = 'pizzeria'
      AND menu ? 'Пицца'
),
counted AS (
    SELECT
        pm.restaurant_name,
        COUNT(p.value) AS pizza_count
    FROM pizzeria_menu AS pm
    CROSS JOIN LATERAL jsonb_each_text(pm.pizzas) AS p
    GROUP BY pm.restaurant_name
),
ranked AS (
    SELECT
        restaurant_name,
        pizza_count,
        DENSE_RANK() OVER (ORDER BY pizza_count DESC) AS rnk
    FROM counted
)
SELECT
    restaurant_name AS "Название заведения",
    pizza_count     AS "Количество пицц в меню"
FROM ranked
WHERE rnk = 1;

-- ЗАДАНИЕ 5
WITH menu_cte AS (
    SELECT
        r.restaurant_name,
        'Пицца'                     AS dish_type,
        p.key                       AS pizza_name,
        p.value::int                AS price
    FROM cafe.restaurants AS r
    CROSS JOIN LATERAL jsonb_each_text(r.menu -> 'Пицца') AS p
    WHERE r.type = 'pizzeria'
      AND r.menu ? 'Пицца'
),
menu_with_rank AS (
    SELECT
        restaurant_name,
        dish_type,
        pizza_name,
        price,
        ROW_NUMBER() OVER (
            PARTITION BY restaurant_name
            ORDER BY price DESC
        ) AS rn
    FROM menu_cte
)
SELECT
    restaurant_name AS "Название заведения",
    dish_type       AS "Тип блюда",
    pizza_name      AS "Название пиццы",
    price           AS "Цена"
FROM menu_with_rank
WHERE rn = 1
ORDER BY restaurant_name;

-- ЗАДАНИЕ 6
WITH dist AS (
    SELECT
        r1.restaurant_name AS rest1,
        r2.restaurant_name AS rest2,
        r1.type            AS type,
        ST_Distance(
            r1.location::geography,
            r2.location::geography
        ) AS distance
    FROM cafe.restaurants AS r1
    JOIN cafe.restaurants AS r2
        ON r1.type = r2.type
       AND r1.restaurant_name < r2.restaurant_name
    WHERE r1.location IS NOT NULL
      AND r2.location IS NOT NULL
)
SELECT
    rest1    AS "Название Заведения 1",
    rest2    AS "Название Заведения 2",
    type     AS "Тип заведения",
    MIN(distance) AS "Расстояние"
FROM dist
GROUP BY rest1, type, rest2
ORDER BY MIN(distance)
LIMIT 1;

-- ЗАДАНИЕ 7
WITH district_counts AS (
    SELECT
        d.district_name,
        COUNT(r.restaurant_uuid) AS restaurant_count
    FROM cafe.districts AS d
    LEFT JOIN cafe.restaurants AS r
        ON ST_Within(r.location, d.district_geom)
    GROUP BY d.district_name
)
SELECT *
FROM (
    SELECT
        district_name    AS "Название района",
        restaurant_count AS "Количество заведений"
    FROM district_counts
    WHERE restaurant_count = (SELECT MAX(restaurant_count) FROM district_counts)
    UNION ALL
    SELECT
        district_name,
        restaurant_count
    FROM district_counts
    WHERE restaurant_count = (SELECT MIN(restaurant_count) FROM district_counts)
) AS combined
ORDER BY "Количество заведений" DESC;