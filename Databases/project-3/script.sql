-- Задание 1
CREATE OR REPLACE PROCEDURE update_employees_rate(
    p_changes json
)
LANGUAGE plpgsql
AS $$
DECLARE
    rec record;
    new_rate integer;
BEGIN
    FOR rec IN
        SELECT
            (item ->> 'employee_id')::uuid AS employee_id,
            (item ->> 'rate_change')::numeric AS rate_change
        FROM json_array_elements(p_changes) AS item
    LOOP
        SELECT GREATEST(
                   ROUND(rate * (1 + rec.rate_change / 100))::integer,
                   500
               )
        INTO new_rate
        FROM employees
        WHERE id = rec.employee_id;

        IF FOUND THEN
            UPDATE employees
            SET rate = new_rate
            WHERE id = rec.employee_id;
        END IF;
    END LOOP;
END;
$$;

-- Задание 2
CREATE OR REPLACE PROCEDURE indexing_salary(p integer)
LANGUAGE plpgsql
AS $$
DECLARE
    avg_rate numeric;
BEGIN
    SELECT AVG(rate) INTO avg_rate FROM employees;

    UPDATE employees
    SET rate = ROUND(
        rate * (1 + (CASE
                        WHEN rate < avg_rate THEN (p + 2)
                        ELSE p
                     END)::numeric / 100)
    )::integer;
END;
$$;

-- Задание 3
CREATE OR REPLACE PROCEDURE close_project(p_project_id uuid)
LANGUAGE plpgsql
AS $$
DECLARE
    v_estimated_time  integer;
    v_is_active       boolean;
    v_total_hours     integer;
    v_saved_hours     integer;
    v_bonus_per_dev   integer;
    v_members_count   integer;
BEGIN
    SELECT estimated_time, is_active
    INTO v_estimated_time, v_is_active
    FROM projects
    WHERE id = p_project_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Проект с id=% не найден', p_project_id;
    END IF;

    IF v_is_active = false THEN
        RAISE EXCEPTION 'Проект с id=% уже закрыт', p_project_id;
    END IF;

    SELECT COALESCE(SUM(work_hours), 0)
    INTO v_total_hours
    FROM logs
    WHERE project_id = p_project_id;

    UPDATE projects
    SET is_active = false
    WHERE id = p_project_id;

    IF v_estimated_time IS NOT NULL
       AND v_total_hours > 0
       AND v_estimated_time > v_total_hours
    THEN
        v_saved_hours := v_estimated_time - v_total_hours;

        SELECT COUNT(DISTINCT employee_id)
        INTO v_members_count
        FROM logs
        WHERE project_id = p_project_id;

        IF v_members_count > 0 THEN
            v_bonus_per_dev := LEAST(
                FLOOR((v_saved_hours * 0.75) / v_members_count),
                16
            );

            IF v_bonus_per_dev > 0 THEN
                INSERT INTO logs (
                    created_at,
                    employee_id,
                    project_id,
                    work_date,
                    work_hours,
                    required_review,
                    is_paid
                )
                SELECT
                    CURRENT_TIMESTAMP,
                    employee_id,
                    p_project_id,
                    CURRENT_DATE,
                    v_bonus_per_dev,
                    false,
                    false
                FROM (
                    SELECT DISTINCT employee_id
                    FROM logs
                    WHERE project_id = p_project_id
                ) AS members;
            END IF;
        END IF;
    END IF;
END;
$$;

-- Задание 4
CREATE OR REPLACE PROCEDURE log_work(
    p_employee_uuid uuid,
    p_project_uuid  uuid,
    p_work_date     date,
    p_worked_hours  integer
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_hours_logged_today integer;
    v_is_active          boolean;
    v_required_review    boolean;
BEGIN
    IF p_work_date IS NULL THEN
        RAISE EXCEPTION 'Дата работы не может быть NULL';
    END IF;

    IF p_worked_hours IS NULL
       OR p_worked_hours < 1
       OR p_worked_hours > 24
    THEN
        RAISE WARNING 'Некорректное количество часов: %. Диапазон 1..24', p_worked_hours;
        RETURN;
    END IF;

    SELECT is_active INTO v_is_active
    FROM projects
    WHERE id = p_project_uuid;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Проект с id=% не найден', p_project_uuid;
    END IF;

    IF v_is_active = false THEN
        RAISE EXCEPTION 'Project closed';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM employees WHERE id = p_employee_uuid) THEN
        RAISE EXCEPTION 'Сотрудник с id=% не найден', p_employee_uuid;
    END IF;

    PERFORM pg_advisory_xact_lock(
        hashtext(p_employee_uuid::text || '|' || p_work_date::text)
    );

    SELECT COALESCE(SUM(work_hours), 0)
    INTO v_hours_logged_today
    FROM logs
    WHERE employee_id = p_employee_uuid
      AND work_date   = p_work_date;

    v_required_review :=
           (v_hours_logged_today + p_worked_hours > 16)
        OR (p_work_date > CURRENT_DATE)
        OR (p_work_date < CURRENT_DATE - 7);

    INSERT INTO logs (employee_id, project_id, work_date, work_hours, required_review)
    VALUES (p_employee_uuid, p_project_uuid, p_work_date, p_worked_hours, v_required_review);
END;
$$;

-- ЗАДАНИЕ 5
CREATE TABLE employee_rate_history(
	id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
	employee_id uuid NOT NULL REFERENCES employees(id),
	rate integer NOT NULL,
	from_date date NOT NULL DEFAULT CURRENT_DATE
);
CREATE INDEX ON employee_rate_history (employee_id, from_date);
INSERT INTO employee_rate_history (id, employee_id, rate, from_date)
SELECT gen_random_uuid(), id, rate, DATE '2020-12-26'
FROM employees;

CREATE OR REPLACE FUNCTION save_employee_rate_history()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO employee_rate_history (employee_id, rate, from_date)
        VALUES (NEW.id, NEW.rate, CURRENT_DATE);
    ELSIF NEW.rate IS DISTINCT FROM OLD.rate THEN
        INSERT INTO employee_rate_history (employee_id, rate, from_date)
        VALUES (NEW.id, NEW.rate, CURRENT_DATE);
    END IF;

    RETURN NULL;
END;
$$;

CREATE TRIGGER change_employee_rate
AFTER INSERT OR UPDATE ON employees
FOR EACH ROW
EXECUTE FUNCTION save_employee_rate_history();

-- Задание 6
CREATE OR REPLACE FUNCTION best_project_workers(p_project_id uuid)
RETURNS TABLE (
    employee   text,
    work_hours integer
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        e.name                         AS employee,
        SUM(l.work_hours)::integer     AS work_hours
    FROM logs l
    JOIN employees e ON e.id = l.employee_id
    WHERE l.project_id = p_project_id
    GROUP BY e.id, e.name
    ORDER BY work_hours DESC
    LIMIT 3;
$$;

-- Задание 6*
CREATE OR REPLACE FUNCTION best_project_workers_improved(p_project_id uuid)
RETURNS TABLE (
    employee   text,
    work_hours integer
)
LANGUAGE sql
AS $$
	SELECT
		e.name                         AS employee,
		SUM(l.work_hours)::integer     AS work_hours
	FROM logs l
	JOIN employees e ON e.id = l.employee_id
	WHERE l.project_id = p_project_id
	GROUP BY e.id, e.name
	ORDER BY 
		work_hours DESC,
		COUNT(DISTINCT l.work_date) DESC,
		random()
	LIMIT 3;
$$;

-- Задание 7
CREATE OR REPLACE FUNCTION calculate_month_salary(
    p_start_date date,
    p_end_date   date
)
RETURNS TABLE (
    id           uuid,
    employee     text,
    worked_hours integer,
    salary       numeric
)
LANGUAGE sql
STABLE
AS $$
    WITH hours AS (
		SELECT
            l.employee_id,
            SUM(l.work_hours)::integer AS total_hours
        FROM logs l
        WHERE l.work_date BETWEEN p_start_date AND p_end_date
			AND l.required_review = false
          	AND l.is_paid = false
        GROUP BY l.employee_id
    )
    SELECT
        e.id,
        e.name AS employee,
        h.total_hours AS worked_hours,
        ROUND(
            (LEAST(h.total_hours, 160) * e.rate
             + GREATEST(h.total_hours - 160, 0) * e.rate * 1.25
            )::numeric,
            2
        ) AS salary
    FROM hours h
    JOIN employees e ON e.id = h.employee_id;
$$;

-- Задание 7*
CREATE OR REPLACE FUNCTION calculate_month_salary_improved(
    p_start_date date,
    p_end_date   date
)
RETURNS TABLE (
    id           uuid,
    employee     text,
    worked_hours integer,
    salary       numeric
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_rec record;
BEGIN
	FOR v_rec IN
        SELECT DISTINCT e.name
        FROM logs l
        JOIN employees e ON e.id = l.employee_id
        WHERE l.work_date BETWEEN p_start_date AND p_end_date
          AND l.required_review = true
    LOOP
        RAISE WARNING 'Warning! Employee % hours must be reviewed!', v_rec.name;
    END LOOP;

	RETURN QUERY
    WITH hours AS (
        SELECT
            l.employee_id,
            SUM(l.work_hours)::integer AS total_hours
        FROM logs l
        WHERE l.work_date BETWEEN p_start_date AND p_end_date
          	AND l.is_paid = false
        GROUP BY l.employee_id
    )
    SELECT
        e.id,
        e.name AS employee,
        h.total_hours AS worked_hours,
        ROUND(
            (LEAST(h.total_hours, 160) * e.rate
             + GREATEST(h.total_hours - 160, 0) * e.rate * 1.25
            )::numeric,
            2
        ) AS salary
    FROM hours h
    JOIN employees e ON e.id = h.employee_id;
END;
$$;

