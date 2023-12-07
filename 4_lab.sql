--drop function f_count_orders_product;
-- Для каждой процедуры не менее 3-х примеров работы с различными значениями аргументов.
-- Комментарии для каждого сценария описывающие суть примера и результат.

--      1задание        --
-- 1. Написать функцию, возвращающую число доставленных заказов по номеру сотрудника за месяц. 
-- Заказы должны быть отмеченные как доставленные и оплаченные. Все аргументы функции должны принимать определенной значение.
--date_trunc('month', month)month DATE
CREATE OR REPLACE FUNCTION f_delivered_orders(
    employee_id INT,
    month DATE
) RETURNS INTEGER AS
$$
DECLARE
    orders_cursor CURSOR IS SELECT * FROM pd_orders WHERE emp_id = employee_id;
    order_count INT; 
BEGIN
    order_count := 0;
  	FOR row IN orders_cursor LOOP
        IF(row.order_state ilike 'end' and row.paid_up and date_trunc('month', month) = date_trunc('month', row.delivery_date))
	        THEN
                order_count := order_count + 1;
	        END IF;
    END LOOP;
    RETURN order_count;
END;    
$$ LANGUAGE plpgsql;

-- а. Написать запрос для проверки полученных результатов:  
-- Количество доставленных заказов  для каждого курьера в текущем месяце рассчитанное с использованием и 
-- без использования написанной функции.  
-- Запрос должен содержать следующие атрибуты: номер месяца, фамилия курьера, количество доставленных заказов, 
-- рассчитанное при помощи функции,  количество доставленных заказов,  рассчитанное без использования функции, 
-- результат сравнения  полученных значений.

-- 1 запрос к 1й функции
select
    sub_default.ex_month, sub_default.name_emp, sub_func.count_orders as func_count_orders
    , sub_default.count_orders as default_count_orders
    , sub_func.count_orders - sub_default.count_orders as difference_func_default
from
(
    select date_part('month', current_timestamp)-3 as ex_month
        , pd_employees.name as name_emp, count(*) as count_orders
        , pd_employees.id as id
    from pd_employees
    inner join pd_orders on pd_orders.emp_id = pd_employees.id
    where date_part('month', current_timestamp)-3 = date_part('month', pd_orders.exec_date)
    group by pd_employees.name, date_part('month', current_timestamp)-3, pd_employees.id
) as sub_default
inner join
(
    select pd_employees.id as id, f_delivered_orders(pd_employees.id, '2023-09-16'::date) as count_orders
    from pd_employees
) as sub_func on sub_func.id = sub_default.id
;

-- б. Написать запрос с использованием написанной функции: 
-- Составить рейтинг  сотрудников по количеству доставленных заказов. 
-- Для каждого осеннего месяца  вывести имена сотрудников занявших первые три места. 
-- Если в течение месяца не было выполнено ни одного заказа, то итоги по этому месяцу не должны попасть в итоговую выборку.  
-- Запрос должен содержать следующие атрибуты:  ФИО сотрудника, количество выполненных заказов,  место в рейтинге, номер месяца. 
-- Сортировка по месяцу,  номеру в рейтинге потом по фамилии.
--------вспомогательные функции-------------
--1 вспомогательная функция
CREATE OR REPLACE FUNCTION f_nameEmployee_byId( -- вспомогательная функция
    employee_id INT
) RETURNS text AS
$$
DECLARE
    orders_cursor CURSOR IS SELECT * FROM pd_employees ;
    name text; 
BEGIN
    FOR row IN orders_cursor LOOP
        IF(row.id = employee_id)
	        THEN
                name := row.name;
	    END IF;
    END LOOP;
    RETURN name;
END;    
$$ LANGUAGE plpgsql;
--------вспомогательные функции-------------
-- для осенних месяцев 2 запрос к 1й функции
select
    sub.id, sub.ord_month, sub.count_ord_month, sub.order_rank, f_nameEmployee_byId(sub.id) as name_emp
from
(
    select 
	pd_employees.id as id
	, sub_months.month_summer::int as ord_month
	, f_delivered_orders(pd_employees.id, make_date(2023, sub_months.month_summer::int, 1)) as count_ord_month
	,  ROW_NUMBER() OVER(PARTITION BY sub_months.month_summer::int 
	ORDER BY 
	f_delivered_orders(pd_employees.id, make_date(2023, sub_months.month_summer::int, 1)) DESC) AS order_rank
    from pd_employees
    inner join
    (
    	select extract(month from pd_orders.order_date) as month_summer
    	from pd_orders
    	WHERE pd_orders.order_date BETWEEN '2023-09-01' AND '2023-11-30'
    	group by extract(month from pd_orders.order_date)
    ) as sub_months on true
) as sub
where sub.order_rank <=3 and  sub.count_ord_month > 0
order by sub.ord_month, sub.order_rank, f_nameEmployee_byId(sub.id)
;
-- для летних месяцев 3 запрос к 1й функции
select
    sub.id, sub.ord_month, sub.count_ord_month, sub.order_rank, f_nameEmployee_byId(sub.id) as name_emp
from
(
    select 
	pd_employees.id as id
	, sub_months.month_summer::int as ord_month
	, f_delivered_orders(pd_employees.id, make_date(2023, sub_months.month_summer::int, 1)) as count_ord_month
	,  ROW_NUMBER() OVER(PARTITION BY sub_months.month_summer::int 
	ORDER BY 
	f_delivered_orders(pd_employees.id, make_date(2023, sub_months.month_summer::int, 1)) DESC) AS order_rank
    from pd_employees
    inner join
    (
    	select extract(month from pd_orders.order_date) as month_summer
    	from pd_orders
    	WHERE pd_orders.order_date BETWEEN '2023-06-01' AND '2023-08-31'
    	group by extract(month from pd_orders.order_date)
    ) as sub_months on true
) as sub
where sub.order_rank <=3
order by sub.ord_month, sub.order_rank, f_nameEmployee_byId(sub.id)
;

-- 2. Написать функцию,  формирующую скидку по итогам последних N дней. 
-- Количество  дней считается от введенной даты, если дата не указана то от текущей.  
-- Условия: скидка 10% на самую часто заказываемую пиццу; скидка 5% на пиццу, которую заказывали на самую большую сумму. 
-- Скидки суммируются.

-- функция принимает product_id count_days desired_date и возвращает количество заказов у товара по product_id за период
--------вспомогательные функции-------------
--1 вспомогательная функция
--drop function f_count_orders_product;
CREATE OR REPLACE FUNCTION f_count_orders_product( -- считает количество заказов продукта за промежуток
    f_product_id INT
    , count_days INT
    , desired_date DATE default now()::date
) RETURNS INTEGER AS
$$
DECLARE
    order_count INT; 
BEGIN
    order_count := 0;
    select count(*) into order_count from (   
        select * from pd_orders
        inner join pd_order_details on pd_order_details.order_id = pd_orders.id
        inner join pd_products on pd_products.id = pd_order_details.product_id
        where 
		pd_products.id = f_product_id 
		and pd_orders.order_date::date <= desired_date
		and pd_orders.order_date::date >= desired_date::date - interval '1 day' * count_days
    )as sub;
    RETURN order_count;
END;    
$$ LANGUAGE plpgsql;
--2 вспомогательная функция
--drop function f_count_orders_product;
CREATE OR REPLACE FUNCTION f_count_costs_product( -- считает стоиимость продукта за промежуток
    f_product_id INT
    , count_days INT
    , desired_date DATE default now()::date
) RETURNS money AS
$$
DECLARE
    costs_count money; 
BEGIN
    costs_count := 0;
    select sub.product_cost into costs_count from (   
        select sum(pd_order_details.quantity * pd_products.price) as product_cost from pd_orders
        inner join pd_order_details on pd_order_details.order_id = pd_orders.id
        inner join pd_products on pd_products.id = pd_order_details.product_id
        where 
		pd_products.id = f_product_id
		and pd_orders.order_date::date <= desired_date::date
		and pd_orders.order_date::date >= desired_date::date - interval '1 day' * count_days
		group by pd_products.id
    )as sub;
    RETURN costs_count;
END;    
$$ LANGUAGE plpgsql;
--------вспомогательные функции-------------
--------вспомогательные запросы-------------
-- select count(*) from pd_orders
-- inner join pd_order_details on pd_order_details.order_id = pd_orders.id
-- inner join pd_products on pd_products.id = pd_order_details.product_id
-- where pd_products.id = 30 and pd_orders.order_date::date <= '2023-10-31'::date
-- ;
-- select * from pd_categories;
-- select 
-- 	max(f_count_orders_product(pd_products.id, 10000, '2023-10-31'::date)) as max_count_orders
-- from pd_products
-- where pd_products.category_id = 3
-- ;
--------вспомогательные запросы-------------
--------основные запросы--------
-- Написать функцию,  формирующую скидку по итогам последних N дней. 
-- Количество  дней считается от введенной даты, если дата не указана то от текущей.  
-- Условия: скидка 10% на самую часто заказываемую пиццу; скидка 5% на пиццу, которую заказывали на самую большую сумму. 
-- Скидки суммируются.
--drop function if exists f_new_price_by_disconts;
CREATE OR REPLACE FUNCTION f_new_price_by_disconts(
    f_product_id INT
    , count_days INT
    , desired_date DATE default now()::date
) RETURNS money AS
$$
DECLARE
    max_orders_period INT;
    old_price money;
    max_costs_period money;
    new_price money;
BEGIN
    ----------1----------
    max_orders_period := 0;
    select max(f_count_orders_product(pd_products.id, count_days, desired_date)) into max_orders_period 
    from pd_products where category_id = 3 -- для пицц
    ; -- узнать максимальное количество заказов за период в целом
    old_price := -1;
    select pd_products.price into old_price
    from pd_products where pd_products.id = f_product_id
    ;
    new_price := -1; -- считаем скидку на самую часто заказываемую
    select sub.price into new_price
    from
    (select 
    case 
        when 
            f_count_orders_product(pd_products.id, count_days, desired_date) = max_orders_period 
            and pd_products.category_id = 3 
        then old_price * 0.9
        else pd_products.price
    end
        as price
    from pd_products
    where pd_products.id = f_product_id) as sub
    ;
    ----------2----------
    max_costs_period := 0::money;
    select max(f_count_costs_product(pd_products.id, count_days, desired_date)) into max_costs_period 
    from pd_products where category_id = 3 -- для пицц
    ; -- узнать максимальную стоимость заказов за период в целом
    select sub.price into new_price
    from
    (select 
    case 
        when 
            f_count_costs_product(pd_products.id, count_days, desired_date) = max_costs_period 
            and pd_products.category_id = 3 
        then new_price - old_price * 0.05
        else new_price
    end
        as price
    from pd_products
    where pd_products.id = f_product_id) as sub
    ;
    RETURN new_price;
END;    
$$ LANGUAGE plpgsql;
-- Написать запросы с использованием написанной функции:  
-- а. Скидка на все пиццы по итогам последних 20 дней.
select 
	pd_products.id
	, pd_products.price
	, f_new_price_by_disconts(pd_products.id, 20+61) as new_price
from pd_products
where pd_products.category_id = 3--пиццы
;

-- б. Пицца с максимальной скидкой за каждый месяц 2023 года.
select sub_main.months, sub_main.id, sub_main.discount
from
(
    select 
        sub_months.months as months
        , 
        case 
            when sub_months.months::int = 1
            then pd_products.price - f_new_price_by_disconts(pd_products.id, 31, '2023-01-31'::date)
            when sub_months.months::int = 2
            then pd_products.price - f_new_price_by_disconts(pd_products.id, 28, '2023-02-28'::date)
            when sub_months.months::int = 3
            then pd_products.price - f_new_price_by_disconts(pd_products.id, 31, '2023-03-31'::date)
            when sub_months.months::int = 4
            then pd_products.price - f_new_price_by_disconts(pd_products.id, 30, '2023-04-30'::date)
            when sub_months.months::int = 5
            then pd_products.price - f_new_price_by_disconts(pd_products.id, 31, '2023-05-31'::date)
            when sub_months.months::int = 6
            then pd_products.price - f_new_price_by_disconts(pd_products.id, 30, '2023-06-30'::date)
            when sub_months.months::int = 7
            then pd_products.price - f_new_price_by_disconts(pd_products.id, 31, '2023-07-31'::date)
            when sub_months.months::int = 8
            then pd_products.price - f_new_price_by_disconts(pd_products.id, 31, '2023-08-31'::date)
            when sub_months.months::int = 9
            then pd_products.price - f_new_price_by_disconts(pd_products.id, 30, '2023-09-30'::date)
            when sub_months.months::int = 10
            then pd_products.price - f_new_price_by_disconts(pd_products.id, 31, '2023-10-31'::date)
            when sub_months.months::int = 11
            then pd_products.price - f_new_price_by_disconts(pd_products.id, 30, '2023-01-30'::date)
            else
            pd_products.price - f_new_price_by_disconts(pd_products.id, 31, '2023-12-31'::date)
        end as discount
        , pd_products.id as id
        from pd_products
        inner join
        (
            select extract(month from pd_orders.order_date) as months
            from pd_orders
            WHERE pd_orders.order_date BETWEEN '2023-01-01' AND '2023-12-31'
            group by extract(month from pd_orders.order_date)
        ) as sub_months on true
) as sub_main

inner join 
(
    select subquery.months as months, max(-subquery.discount::numeric) as max_discount from
    (
    select 
        sub_months.months as months
        , 
        case 
            when sub_months.months::int = 1
            then pd_products.price - f_new_price_by_disconts(pd_products.id, 31, '2023-01-31'::date)
            when sub_months.months::int = 2
            then pd_products.price - f_new_price_by_disconts(pd_products.id, 28, '2023-02-28'::date)
            when sub_months.months::int = 3
            then pd_products.price - f_new_price_by_disconts(pd_products.id, 31, '2023-03-31'::date)
            when sub_months.months::int = 4
            then pd_products.price - f_new_price_by_disconts(pd_products.id, 30, '2023-04-30'::date)
            when sub_months.months::int = 5
            then pd_products.price - f_new_price_by_disconts(pd_products.id, 31, '2023-05-31'::date)
            when sub_months.months::int = 6
            then pd_products.price - f_new_price_by_disconts(pd_products.id, 30, '2023-06-30'::date)
            when sub_months.months::int = 7
            then pd_products.price - f_new_price_by_disconts(pd_products.id, 31, '2023-07-31'::date)
            when sub_months.months::int = 8
            then pd_products.price - f_new_price_by_disconts(pd_products.id, 31, '2023-08-31'::date)
            when sub_months.months::int = 9
            then pd_products.price - f_new_price_by_disconts(pd_products.id, 30, '2023-09-30'::date)
            when sub_months.months::int = 10
            then pd_products.price - f_new_price_by_disconts(pd_products.id, 31, '2023-10-31'::date)
            when sub_months.months::int = 11
            then pd_products.price - f_new_price_by_disconts(pd_products.id, 30, '2023-01-30'::date)
            else
            pd_products.price - f_new_price_by_disconts(pd_products.id, 31, '2023-12-31'::date)
        end as discount
        from pd_products
        inner join
        (
            select extract(month from pd_orders.order_date) as months
            from pd_orders
            WHERE pd_orders.order_date BETWEEN '2023-01-01' AND '2023-12-31'
            group by extract(month from pd_orders.order_date)
        ) as sub_months on true
    ) as subquery
    group by subquery.months
) as sub_max_discont_month on sub_main.months = sub_max_discont_month.months and -sub_main.discount::numeric = sub_max_discont_month.max_discount
;
--в максимальная скидка за продукты за весь период
select pd_products.id, f_new_price_by_disconts(pd_products.id, 100000)
from pd_products
;




 

-- 3. Написать функцию, возвращающую число доставленных и оплаченных заказов под руководством сотрудника по его номеру за месяц. 
-- Все аргументы функции должны принимать определенное значение.

--вспомогательная функция возвращающая все заказы под руководством сотрудника за период по его номеру за месяц
drop function if exists f_count_exec_paid_orders_managedBy_emp;
drop function if exists f_get_orders_managedBy_emp;

drop function if exists f_count_exec_paid_orders_By_emp;
drop function if exists f_get_orders_By_emp;
drop table if exists orders_managedBy_emp;
CREATE TABLE if not exists orders_managedBy_emp (
    id int, emp_id int, cust_id int, paid_up boolean
        , order_date timestamp without time zone, delivery_date timestamp without time zone
        , exec_date timestamp without time zone
        , order_comment text
);
create or replace function f_get_orders_managedBy_emp(
    employee_id INT
    , number_month INT
) RETURNS SETOF orders_managedBy_emp as
$$
    select 
        pd_orders.id, pd_orders.emp_id, pd_orders.cust_id, pd_orders.paid_up
        , pd_orders.order_date, pd_orders.delivery_date, pd_orders.exec_date
        , pd_orders.order_comment
    from pd_employees
    inner join pd_orders on pd_orders.emp_id = pd_employees.id
    where 
        pd_employees.manager_id = employee_id
        and extract(month from pd_orders.order_date)::integer = number_month
    ;
$$ LANGUAGE sql;

create or replace function f_count_exec_paid_orders_managedBy_emp(
    employee_id INT
    , number_month INT
) RETURNS integer as
$$
DECLARE
    order_count int;
BEGIN
	order_count := 0;
    select 
        count(*) into order_count
    from f_get_orders_managedBy_emp(employee_id, number_month)
    where 
        paid_up = true and not exec_date is NULL
    ;
    if (order_count is null) then order_count:=0; 
	end if;
    return order_count;
END;
$$ LANGUAGE plpgsql;
--вспомогательная функция
create or replace function f_get_orders_By_emp(
    employee_id INT
    , number_month INT
) RETURNS SETOF orders_managedBy_emp as
$$
    select 
        pd_orders.id, pd_orders.emp_id, pd_orders.cust_id, pd_orders.paid_up
        , pd_orders.order_date, pd_orders.delivery_date, pd_orders.exec_date
        , pd_orders.order_comment
    from pd_orders
    where 
        pd_orders.emp_id = employee_id
        and extract(month from pd_orders.order_date)::integer = number_month
    ;
$$ LANGUAGE sql;

create or replace function f_count_exec_paid_orders_By_emp(
    employee_id INT
    , number_month INT
) RETURNS integer as
$$
DECLARE
    order_count int;
BEGIN
	order_count := 0;
    select 
        count(*) into order_count
    from f_get_orders_By_emp(employee_id, number_month)
    where 
        paid_up = true and not exec_date is NULL
    ;
    if (order_count is null) then order_count:=0; 
	end if;
    return order_count;
END;
$$ LANGUAGE plpgsql;

-- Написать запросы с использованием написанной функции:  
-- а. Количество доставок для каждого курьера за предыдущий месяц, 
-- для руководителей групп в отдельном атрибуте указать количество доставок в их группах.
select 
	pd_employees.id
	, f_count_exec_paid_orders_By_emp(pd_employees.id, 5)
	, f_count_exec_paid_orders_managedBy_emp(pd_employees.id, 5)
from pd_employees
;
-- б. Имя и должность самого результативного руководителя за каждый месяц 2023 года.
drop function if exists f_get_info_bestmanagers_month;
drop table if exists get_info_bestmanagers_month;
drop table if exists bestmanagers_month;
CREATE TABLE if not exists bestmanagers_month (
    count_ord int
    , month int
    , name_manager text
    , post text
);

create or replace function f_get_info_bestmanagers_month(
    number_month INT
) RETURNS SETOF bestmanagers_month as
$$
    select sub_count_ord.count_ord, number_month, sub_count_ord.name::text, pd_posts.post
    from
    (
    	select 
    	max(f_count_exec_paid_orders_managedBy_emp(pd_employees.id, number_month)) as max_count_ord
    	from pd_employees
    ) as sub_max_ord
    inner join
    (
    	select pd_employees.name as name
    	, f_count_exec_paid_orders_managedBy_emp(pd_employees.id, number_month) as count_ord
        , pd_employees.post_id
    	from pd_employees
        where f_count_exec_paid_orders_managedBy_emp(pd_employees.id, number_month) != 0
    ) as sub_count_ord on sub_count_ord.count_ord = sub_max_ord.max_count_ord
    inner join pd_posts on pd_posts.id = sub_count_ord.post_id
;
$$ LANGUAGE sql;

WITH RECURSIVE months AS (
    SELECT 1 AS month
    UNION ALL
    SELECT month + 1 FROM months WHERE month <= 12
)
SELECT *
FROM months
CROSS JOIN LATERAL f_get_info_bestmanagers_month(month) AS result;


--3запрос для января    
SELECT *
FROM f_get_info_bestmanagers_month(1);
--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
------------------------                СЛЕДУЮЩЕЕ ЗАДАНИЕ              ---------------------------------
--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------

-- 4. Написать функцию, возвращающую общее число заказов за месяц. Все аргументы функции должны принимать определенной значение.
-- Написать проверочный запрос. 
drop function if exists f_count_orders_per_month;
create or replace function f_count_orders_per_month(
    number_month INT
) RETURNS integer as
$$
DECLARE
    order_count int;
BEGIN
	order_count := 0;
    select 
        count(*) into order_count
    from pd_orders
    where 
        extract(month from pd_orders.order_date)::integer = number_month
    ;
    return order_count;
END;
$$ LANGUAGE plpgsql;
select f_count_orders_per_month(1), 1 as month;
select f_count_orders_per_month(2), 2 as month;

select sub.count_sub, sub.month, sub1.count_func
from 
(
	select
	count(*) as count_sub, extract(month from pd_orders.order_date)::integer as month
	from pd_orders
	group by 
	extract(month from pd_orders.order_date)::integer
) as sub
inner join 
(
	select 
	extract(month from pd_orders.order_date)::integer as month
	, f_count_orders_per_month(extract(month from pd_orders.order_date)::integer) as count_func
from pd_orders
group by 
	extract(month from pd_orders.order_date)::integer
) as sub1 on sub1.month = sub.month
;










CREATE OR REPLACE FUNCTION f_orders_(
    employee_id INT,
    month DATE
) RETURNS INTEGER AS
$$
DECLARE
    orders_cursor CURSOR IS SELECT * FROM pd_orders WHERE emp_id = employee_id;
    order_count INT; 
BEGIN
    order_count := 0;
  	FOR row IN orders_cursor LOOP
        IF(row.order_state ilike 'end' and row.paid_up and date_trunc('month', month) = date_trunc('month', row.delivery_date))
	        THEN
                order_count := order_count + 1;
	        END IF;
    END LOOP;
    RETURN order_count;
END;    
$$ LANGUAGE plpgsql;


-- 5. Написать функцию, выводящую насколько цена продукта больше чем средняя цена в категории.
-- Написать проверочный запрос.
--функция получающая category_id и возвращающая среднюю цену в категории
drop function if exists f_avg_price_category;
CREATE OR REPLACE FUNCTION f_avg_price_category(
    f_id_categoty INT
) RETURNS numeric AS
$$
DECLARE
    f_avg_price numeric; 
BEGIN
    f_avg_price := 0;
    select sub.avg_price into f_avg_price 
    from
    (
        select avg(pd_products.price::numeric) as avg_price
        from pd_products
        group by pd_products.category_id 
        having pd_products.category_id = f_id_categoty
    ) as sub
  	;
    RETURN f_avg_price;
END;    
$$ LANGUAGE plpgsql;
-- искомая функция, разница между ценой продукта и средней ценой в его категории
--подаем на вход id продукта и возвращаем разницу в цене
drop function if exists f_dif_price_avgPrice;
CREATE OR REPLACE FUNCTION f_dif_price_avgPrice(
    f_id_product INT
) RETURNS numeric AS
$$
DECLARE
    f_difference_price_avgPrice numeric; 
BEGIN
    f_difference_price_avgPrice := 0;
    select 
        pd_products.price::numeric - f_avg_price_category(pd_products.category_id) into f_difference_price_avgPrice
    from pd_products
    where pd_products.id = f_id_product
  	;
    RETURN f_difference_price_avgPrice;
END;    
$$ LANGUAGE plpgsql;
--разница цены
select 
    pd_products.id, pd_products.product_name, f_dif_price_avgPrice(pd_products.id) 
from pd_products;
-- процент разница цены
select 
    pd_products.id, pd_products.product_name
	, f_dif_price_avgPrice(pd_products.id) / pd_products.price::numeric * 100 as percent_difference_price
from pd_products;
-- максимальный процент разницы цены и средней цены_категории по категориям
select 
    pd_products.category_id
	, max(f_dif_price_avgPrice(pd_products.id) / pd_products.price::numeric * 100) as max_percent_difference_price
from pd_products
group by pd_products.category_id
;  

-- 6. Написать функцию, возвращающую максимальную общую стоимость заказа (не учитывать другие товары в заказе) 
-- для каждого товара за указанный месяц года. 
-- Если месяц не указан, выводить стоимость максимальную стоимость за всё время.
-- Параметры функции: месяц года (даты с точностью до месяца) и номер товара.
-- Написать запрос использованием написанной функции: список товаров с наименованиями и стоимостями за всё время и за сентябрь 2023 года.

drop function if exists f_costs_product_inOrder;
CREATE OR REPLACE FUNCTION f_costs_product_inOrder(
    f_id_product INT
    , number_month date default 'infinity'::date --date_trunc('month', month) --month DATE
) RETURNS numeric AS
$$
DECLARE
    costs_product_inOrder NUMERIC := 0; 
    costs_product_inOrder_2 NUMERIC := 0;
    ffinal NUMERIC := 0;
BEGIN
    if number_month < 'infinity'
    then
        select max(pd_products.price::numeric * pd_order_details.quantity) into costs_product_inOrder
        from pd_orders
        inner join pd_order_details on pd_order_details.order_id = pd_orders.id
        inner join pd_products on pd_products.id = pd_order_details.product_id
        where 
            pd_products.id = f_id_product
            and 
            date_trunc('month', pd_orders.order_date) = date_trunc('month', number_month)
        ;  
    else
        select max(pd_products.price::numeric * pd_order_details.quantity) into costs_product_inOrder_2
        from pd_orders
        inner join pd_order_details on pd_order_details.order_id = pd_orders.id
        inner join pd_products on pd_products.id = pd_order_details.product_id
        where 
            pd_products.id = f_id_product
        ;  
	end if;
    IF number_month < 'infinity' THEN
        ffinal := costs_product_inOrder;
    ELSE
        ffinal := costs_product_inOrder_2;
    END IF;
    RETURN ffinal;
END;    
$$ LANGUAGE plpgsql;

select pd_products.id, f_costs_product_inOrder(pd_products.id) as max_costs_allTime
, f_costs_product_inOrder(pd_products.id, pd_orders.order_date::date) as max_costs_monthDate
from pd_products
inner join pd_order_details on pd_order_details.order_id = pd_products.id
inner join pd_orders on pd_orders.id = pd_order_details.order_id
;
-- Написать запрос использованием написанной функции: список товаров с наименованиями и стоимостями за всё время и за сентябрь 2023 года.
select distinct
    pd_products.id, pd_products.product_name
    , f_costs_product_inOrder(pd_products.id) as max_costs_allTime
    , f_costs_product_inOrder(pd_products.id, pd_orders.order_date::date) as max_costs_September
from pd_products
inner join pd_order_details on pd_order_details.order_id = pd_products.id
inner join pd_orders on pd_orders.id = pd_order_details.order_id
where pd_orders.order_date BETWEEN '2023-10-01' AND '2023-10-30'
;

select distinct
    pd_products.id, pd_products.product_name
    , f_costs_product_inOrder(pd_products.id) as max_costs_allTime
    , sub.max_costs_allTime as max_costs_check
from pd_products
inner join pd_order_details on pd_order_details.order_id = pd_products.id
inner join pd_orders on pd_orders.id = pd_order_details.order_id
inner join
(
	select 
    pd_products.id as id
    , max(f_costs_product_inOrder(pd_products.id, pd_orders.order_date::date)) as max_costs_allTime
	from pd_products
	inner join pd_order_details on pd_order_details.product_id = pd_products.id
	inner join pd_orders on pd_orders.id = pd_order_details.order_id
	group by pd_products.id
) as sub on sub.id = pd_products.id
--where pd_orders.order_date BETWEEN '2023-01-01' AND '2023-12-31'
;

-- 7. Сформировать “открытку” с поздравлением всех именинников заранее заданного месяца:
-- “В <название месяца> мы поздравляем с днём рождения: <имя, имя > и <имя >”. Скобки вида “<>”  выводить не нужно. Написать проверочные запросы.

drop function if exists f_get_birthday_letter;
CREATE OR REPLACE FUNCTION f_get_birthday_letter(
    number_month date default 'infinity'::date --date_trunc('month', month) --month DATE
) RETURNS numeric AS
$$
DECLARE
    costs_product_inOrder NUMERIC := 0; 
    costs_product_inOrder_2 NUMERIC := 0;
    ffinal NUMERIC := 0;
BEGIN
    if number_month < 'infinity'
    then
        select max(pd_products.price::numeric * pd_order_details.quantity) into costs_product_inOrder
        from pd_orders
        inner join pd_order_details on pd_order_details.order_id = pd_orders.id
        inner join pd_products on pd_products.id = pd_order_details.product_id
        where 
            pd_products.id = f_id_product
            and 
            date_trunc('month', pd_orders.order_date) = date_trunc('month', number_month)
        ;  
    else
        select max(pd_products.price::numeric * pd_order_details.quantity) into costs_product_inOrder_2
        from pd_orders
        inner join pd_order_details on pd_order_details.order_id = pd_orders.id
        inner join pd_products on pd_products.id = pd_order_details.product_id
        where 
            pd_products.id = f_id_product
        ;  
	end if;
    IF number_month < 'infinity' THEN
        ffinal := costs_product_inOrder;
    ELSE
        ffinal := costs_product_inOrder_2;
    END IF;
    RETURN ffinal;
END;    
$$ LANGUAGE plpgsql;

8. Написать процедуру, создающую новый заказ как копию существующего заказа, чей номер – аргумент функции. Новый заказ должен иметь соответствующий статус.
Написать проверочные запросы.

 

9. Создать таблицу pd_bonus для расчёта премий сотрудников.
Таблица должна содержать поля:
emp_id – ссылка на сотрудника;
month – первый день месяца;
amount – размер бонуса;
percent – процент.

Премия  рассчитывается по правилам:
10% от оклада (смотри таблицу с должностями) - если в месяц было не более 4% просроченных заказов;
5% -  есть в месяц было не более 8% просроченных заказов;
-5% если в течении месяца было просрочено более 15% заказов.

Предварительно таблица не заполнена.  
Напишите процедуру, заполняющую или обновляющую таблицу бонусов за указанный месяц.  
Напишите проверочные запросы.
--мрак
CREATE OR REPLACE FUNCTION f_count_orders_product( -- считает количество заказов продукта за промежуток
    f_product_id INT
    , count_days INT
    , desired_date DATE default now()::date
) RETURNS INTEGER AS
$$
DECLARE
    order_count INT; 
BEGIN
    order_count := 0;
    select count(*) into order_count from (   
        select * from pd_orders
        inner join pd_order_details on pd_order_details.order_id = pd_orders.id
        inner join pd_products on pd_products.id = pd_order_details.product_id
        where 
		pd_products.id = f_product_id 
		and pd_orders.order_date::date <= desired_date
		and pd_orders.order_date::date >= desired_date::date - interval '1 day' * count_days
    )as sub;
    RETURN order_count;
END;    
$$ LANGUAGE plpgsql;
select max(f_count_orders_product(pd_products.id, 1000)::integer)
from pd_products
;
select * from pd_categories;

CREATE OR REPLACE FUNCTION f_count_orders_product( -- считает количество заказов продукта за промежуток
    f_product_id INT
    , count_days INT
    , desired_date DATE default now()::date
) RETURNS INTEGER AS
$$
DECLARE

    max_orders_period INT;
BEGIN
    max_orders_period := 0;
    select max(f_count_orders_product(pd_products.id, count_days, desired_date)) into max_orders_period 
    from pd_products
    where category_id 
    ;
    select 
        pd_products.id
        , f_count_orders_product(pd_products.id, count_days, desired_date)
    from pd_products
    ;
    RETURN order_count;
END;    
$$ LANGUAGE plpgsql;
