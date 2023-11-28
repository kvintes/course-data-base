
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
select *
from pd_employees
inner join pd_orders on pd_orders.emp_id = pd_employees.id
;

