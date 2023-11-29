
-- Для каждой процедуры не менее 3-х примеров работы с различными значениями аргументов.
-- Комментарии для каждого сценария описывающие суть примера и результат.

--      1задание        --
-- 1. Написать функцию, возвращающую число доставленных заказов по номеру сотрудника за месяц. 
-- Заказы должны быть отмеченные как доставленные и оплаченные. Все аргументы функции должны принимать определенной значение.
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
select date_part('month', current_timestamp)-2 as ex_month
	, pd_employees.name, count(*) as count_orders
from pd_employees
inner join pd_orders on pd_orders.emp_id = pd_employees.id
where date_part('month', current_timestamp)-2 = date_part('month', pd_orders.exec_date)
group by pd_employees.name, date_part('month', current_timestamp)-2
;

select
    sub_default.ex_month, sub_default.name_emp, sub_func.count_orders as func_count_orders
    , sub_default.count_orders as default_count_orders
    , sub_func.count_orders - sub_default.count_orders as difference_func_default
from
(
    select date_part('month', current_timestamp)-2 as ex_month
        , pd_employees.name as name_emp, count(*) as count_orders
        , pd_employees.id as id
    from pd_employees
    inner join pd_orders on pd_orders.emp_id = pd_employees.id
    where date_part('month', current_timestamp)-2 = date_part('month', pd_orders.exec_date)
    group by pd_employees.name, date_part('month', current_timestamp)-2, pd_employees.id
) as sub_default
inner join
(
    select pd_employees.id as id, f_delivered_orders(pd_employees.id, '2023-09-16'::date) as count_orders
    from pd_employees
) as sub_func on sub_func.id = sub_default.id
;

