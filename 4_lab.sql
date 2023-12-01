
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
select date_part('month', current_timestamp)-3 as ex_month
	, pd_employees.name, count(*) as count_orders
from pd_employees
inner join pd_orders on pd_orders.emp_id = pd_employees.id
where date_part('month', current_timestamp)-3 = date_part('month', pd_orders.exec_date)
group by pd_employees.name, date_part('month', current_timestamp)-3
;

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
CREATE OR REPLACE FUNCTION f_nameEmployee_byId(
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

SELECT 
	sub.employee_id, sub.month, sub.order_rank
	, f_nameEmployee_byId(sub.employee_id) as name_employee
	, f_delivered_orders(sub.employee_id, '2023-09-16'::date) as count_orders
from
(
	select
	pd_employees.id AS employee_id,
    DATE_part('month', '2023-09-16'::date) AS month,
    ROW_NUMBER() OVER(PARTITION BY DATE_TRUNC('month', '2023-09-16'::date) 
	ORDER BY f_delivered_orders(pd_employees.id, '2023-09-16'::date) DESC) AS order_rank
	FROM pd_employees
) as sub
where sub.order_rank <=3
order by sub.month, sub.order_rank, f_nameEmployee_byId(sub.employee_id)
;
-- в для летних месяцев

SELECT 
	sub.employee_id, sub.month, sub.order_rank
	, f_nameEmployee_byId(sub.employee_id) as name_employee
	, f_delivered_orders(sub.employee_id, '2023-09-16'::date) as count_orders
from
(
	pd_employees.id AS employee_id,
    DATE_part('month', pd_orders.order_date::date) AS month,
    ROW_NUMBER() OVER(PARTITION BY DATE_TRUNC('month', pd_orders.order_date::date) 
	ORDER BY f_delivered_orders(pd_employees.id, pd_orders.order_date::date) DESC) AS order_rank
	FROM pd_employees
	inner join pd_orders on pd_orders.emp_id = pd_employees.id
) as sub
where sub.order_rank <=3
order by sub.month, sub.order_rank, f_nameEmployee_byId(sub.employee_id)
;



select
    sub.employee_id
    , ROW_NUMBER() OVER(PARTITION BY DATE_TRUNC('month', pd_orders.order_date::date) 
    	ORDER BY sub.count_orders desc AS order_rank
from 
(
    select
    pd_employees.id AS employee_id,
    f_delivered_orders(pd_employees.id, pd_orders.order_date::date) as count_orders
    
	FROM pd_employees
	inner join pd_orders on pd_orders.emp_id = pd_employees.id
	where 
	    DATE_part('month', pd_orders.order_date::date)::integer < 9 
	    and DATE_part('month', pd_orders.order_date::date)::integer > 5
    group by 
        pd_employees.id,
        f_delivered_orders(pd_employees.id, pd_orders.order_date::date)
    
) as sub
	

ROW_NUMBER() OVER(PARTITION BY DATE_TRUNC('month', pd_orders.order_date::date) 
	ORDER BY f_delivered_orders(pd_employees.id, pd_orders.order_date::date) DESC) AS order_rank
2. Написать функцию,  формирующую скидку по итогам последних N дней. Количество  дней считается от введенной даты, если дата не указана то от текущей.  Условия: скидка 10% на самую часто заказываемую пиццу; скидка 5% на пиццу, которую заказывали на самую большую сумму. Скидки суммируются.

Написать запросы с использованием написанной функции:  
а. Скидка на все пиццы по итогам последних 20 дней.
б. Пицца с максимальной скидкой за каждый месяц 2023 года.

 

3. Написать функцию, возвращающую число доставленных и оплаченных  заказов под руководством сотрудника по его номеру за месяц. Все аргументы функции должны принимать определенное значение.

Написать запросы с использованием написанной функции:  
а. Количество доставок для каждого курьера за предыдущий месяц, для руководителей групп в отдельном атрибуте указать количество доставок в их группах.
б. Имя и должность самого результативного руководителя за каждый месяц 2023 года.

 

4. Написать функцию, возвращающую общее число заказов за месяц. Все аргументы функции должны принимать определенной значение.
Написать проверочный запрос.

 

5. Написать функцию, выводящую насколько цена продукта больше чем средняя цена в категории.
Написать проверочный запрос.

 

6. Написать функцию, возвращающую максимальную общую стоимость заказа (не учитывать другие товары в заказе) для каждого товара за указанный месяц года. Если месяц не указан, выводить стоимость максимальную стоимость за всё время.
Параметры функции: месяц года (даты с точностью до месяца) и номер товара.
Написать запрос использованием написанной функции: список товаров с наименованиями и стоимостями за всё время и за сентябрь 2023 года.

 

7. Сформировать “открытку” с поздравлением всех именинников заранее заданного месяца:
“В <название месяца> мы поздравляем с днём рождения: <имя, имя > и <имя >”. Скобки вида “<>”  выводить не нужно. Написать проверочные запросы.

 

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

