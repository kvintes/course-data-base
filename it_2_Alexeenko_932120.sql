-- 6. Написать процедуры и функции, согласно условиям. Все процедуры и функции при необходимости должны включать обработчики исключений.
-- Названия функций: F_<имя>. Формат названий процедур: P_<имя>. Написать анонимные блоки или запросы для проверки работы процедур и
-- функций.

SET search_path TO it;
-- 6.1. Написать функцию, которая возвращает количество восхождений для заданного альпиниста в указанный период (id_альпиниста и промежуток
-- времени – аргументы функции). Если промежуток времени не указан, считается количество за всё время.

drop function if exists F_countClimbings_climber;
create or replace function F_countClimbings_climber(
    f_ID_Альпиниста integer
    , f_data date default now()::date
    , f_N_days integer default 100000
) returns integer as $$
declare
    count_climbings integer := 0
;
begin
    select 
    count(*) into count_climbings
    from Альпинист_Восхождение
    inner join Восхождения on Восхождения.ID_Восхождения = Альпинист_Восхождение.ID_Восхождения
    where 
        Восхождения.Дата_начала::date <= f_data
        and Восхождения.Дата_начала::date >= f_data - interval '1 day' * f_N_days
		and Альпинист_Восхождение.ID_Альпиниста = f_ID_Альпиниста
    ;
    return count_climbings;
end;
$$ language plpgsql;

--анонимный запрос для проверки
-- DO $$
-- BEGIN
    SELECT 
        Альпинисты.ID_Альпиниста as id,
        F_countClimbings_climber(Альпинисты.ID_Альпиниста) as count_all_climbings,
        F_countClimbings_climber(Альпинисты.ID_Альпиниста, now()::date, 30) as count_30days_climbings
    FROM Альпинисты;
-- END;
-- $$LANGUAGE plpgsql;
----------------------------------------------------------------
-- 6.2. Написать функцию, которая для заданной вершины возвращает среднюю длительность восхождений в днях. Значение может рассчитываться за
-- конкретный сезон и/или для конкретного альпиниста. Принадлежность восхождения сезону определяется по дате начала, если восхождение ещё не
-- завершено, то учитывается число прошедших с его начала дней. Функция имеет три аргумента: id_вершины, сезон (номер от 1 до 4),
-- id_альпиниста. Только первый аргумент является обязательным. Предусмотреть вариант вызова функции без необязательных аргументов.

---переписываем для season
drop function if exists F_avg_durationClimbings;
create or replace function F_avg_durationClimbings(
    f_ID_Вершины integer
    , f_season integer default -1
    , f_ID_Альпиниста integer default -1
) returns numeric as $$
declare
    avg_durationClimbings numeric := 0;
    left_data date := date_trunc('year', current_timestamp)::date;
    right_date date := (date_trunc('year', current_timestamp) + interval '1 month'*3 - interval '1 day')::date;
    temp_date interval := (interval '1 month'*3);
begin
    if f_season > 4 or f_season < 1
    then 
        right_date := right_date + temp_date*3;
    end if; -- защита от дурака

    if f_season = 2 
    then 
        left_data :=  left_data + temp_date;
        right_date := right_date + temp_date;
    elsif f_season = 3
    then 
        left_data :=  left_data + temp_date*2;
        right_date := right_date + temp_date*2;
    else
        left_data :=  left_data + temp_date*3;
        right_date := right_date + temp_date*3;
    end if;-- определяем защиту от дурака


    if f_ID_Альпиниста != -1
	then
        select COALESCE(sub_avg, 0) into avg_durationClimbings
        from
        (
            select avg(COALESCE(Восхождения.Дата_завершения::date, current_date::date) - Восхождения.Дата_начала::date) as sub_avg
            from Вершины 
            inner join Восхождения on Восхождения.ID_Вершины = Вершины.ID_Вершины
            inner join Альпинист_Восхождение on Альпинист_Восхождение.ID_Восхождения = Восхождения.ID_Восхождения
            where 
				Вершины.ID_Вершины = f_ID_Вершины
                and Восхождения.Дата_начала::date >= left_data
                and Восхождения.Дата_начала::date <= right_date
				and Альпинист_Восхождение.ID_Альпиниста = f_ID_Альпиниста
        ) as sub
        ;
    else
        select COALESCE(sub_avg, 0) into avg_durationClimbings
        from
        (
            select avg(COALESCE(Восхождения.Дата_завершения::date, current_date::date) - Восхождения.Дата_начала::date) as sub_avg
            from Вершины 
            inner join Восхождения on Восхождения.ID_Вершины = Вершины.ID_Вершины
            inner join Альпинист_Восхождение on Альпинист_Восхождение.ID_Восхождения = Восхождения.ID_Восхождения
            where 
				Вершины.ID_Вершины = f_ID_Вершины
                and Восхождения.Дата_начала::date >= left_data
                and Восхождения.Дата_начала::date <= right_date
        ) as sub
    ; 
    end if;
    return avg_durationClimbings;

end;
$$ language plpgsql;
---проверочный запрос 6.2
select F_avg_durationClimbings(12) as avg_duration;
select F_avg_durationClimbings(12, 3) as avg_duration;
select F_avg_durationClimbings(12, 2) as avg_duration;
select F_avg_durationClimbings(12, 2, 0) as avg_duration;
select F_avg_durationClimbings(12, 2, 1) as avg_duration;
select * 
from Вершины
inner join Восхождения on Восхождения.id_Вершины = Вершины.id_Вершины
where Восхождения.id_Вершины = 12
;
-------------------------------------------------------------------------
-- 6.3. Написать процедуру, которая формирует календарь восхождений для заданного альпиниста. (id_альпиниста и год – параметры функции).
-- Формат вывода:
-- ------------------------------------------------------
-- Календарь восхождений для <ФИО> на <год> год:
-- <месяц_1>:
--  1. <Вершина_1>, <дата начала восхождения> – <дата окончания восхождения>;
--  2. <Вершина_2>, <дата начала восхождения> – <дата окончания восхождения>;
--  <и т. д.> ….
-- <месяц_2 (без восхождений)>: восхождения не запланировано
-- <и т. д.> ….


drop function if exists P_get_Climbing_calendar;
drop table if exists Climbing_calendar;
CREATE TABLE if not exists Climbing_calendar (
    text_field text
);
CREATE OR REPLACE FUNCTION F_get_climbingsPlan_month( --- делаем фунцию, которая получает новый месяц 
    p_id_альпиниста date ---и возвращает строку вида <Вершина_1>, <дата начала восхождения> – <дата окончания восхождения>;
    , year integer
    , month integer
)RETURNS text as
$$
    select
    from concat(all_names)::text
    (
        select concat(rock, ' ', date_start_climbing, ' - ', date_end_climbing, ' ') as all_text_month
        from
        (
            select 
	        Вершины.Название as rock
	        , Альпинисты.ФИО, Восхождения.Дата_начала as date_start_climbing
            , Восхождения.Дата_завершения as date_end_climbing
        from Восхождения
        inner join Альпинист_Восхождение on Альпинист_Восхождение.ID_Восхождения = Восхождения.ID_Восхождения
        inner join Альпинисты on Альпинисты.ID_Альпиниста = Альпинист_Восхождение.ID_Альпиниста
        inner join Вершины on Вершины.ID_Вершины = Восхождения.ID_Вершины
        where 
            Альпинист_Восхождение.ID_Альпиниста = p_id_альпиниста
            and date_trunc('year', Восхождения.Дата_начала) = make_date(year, 1, 1)
            and date_trunc('month', Восхождения.Дата_начала) = make_date(year, month, 1)
        ) as sub_month
    ) as sub
    
;
-----------------------------------------------------------------работает с месяцом---пробуем обьединять
$$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION P_get_Climbing_calendar(
    p_id_альпиниста date
    , year integer
) 
RETURNS SETOF Climbing_calendar as
$$

    select
    from concat(to_char(sub.month, 'Month'),' :\n', all_names)::text
    <месяц_1>:
--  1. <Вершина_1>, <дата начала восхождения> – <дата окончания восхождения>;
--  2. <Вершина_2>, <дата начала восхождения> – <дата окончания восхождения>;
--  <и т. д.> ….
    (
        select 
            date_trunc('month', Восхождения.Дата_начала) as month
	        , Вершины.Название
	        , Альпинисты.ФИО, Восхождения.Дата_начала, Восхождения.Дата_завершения
        from Восхождения
        inner join Альпинист_Восхождение on Альпинист_Восхождение.ID_Восхождения = Восхождения.ID_Восхождения
        inner join Альпинисты on Альпинисты.ID_Альпиниста = Альпинист_Восхождение.ID_Альпиниста
        inner join Вершины on Вершины.ID_Вершины = Восхождения.ID_Вершины
        where 
            date_trunc('year', Восхождения.Дата_начала) = make_date(year, 1, 1)
    ) as sub
    
;
;
$$ LANGUAGE sql;

-- 6.4. Написать процедуру, которая выполняете копирование всех данных об указанном альпинисте, включая восхождения. Аргумент процедуры -
-- id_альпиниста. Для скопированной записи ставится отметка “копия” в поле ФИО.
-- 6.5. Написать один или несколько сценариев (анонимных блока) демонстрирующий работу процедур и функций из п. 1-4.
-- Требование:
-- - Включение в запрос (для функций)
-- - Для каждой процедуры не менее 3-х примеров работы с различными значениями аргументов.
-- - Комментарии для каждого сценария, описывающие суть примера и результат.



--------------------------
select (date_trunc('year', current_timestamp) + interval '1 month'*2 - interval '1 day')::date
;

    if f_ID_Альпиниста != -1
        select COALESCE(sub_avg, 0) into avg_durationClimbings
        from
        (
            select avg(COALESCE(Восхождения.Дата_завершения::date, f_data::date) - Восхождения.Дата_начала::date) as sub_avg
            from Вершины 
            inner join Восхождения on Восхождения.ID_Вершины = Вершины.ID_Вершины
            inner join Альпинист_Восхождение on Альпинист_Восхождение.ID_Восхождения = Восхождения.ID_Восхождения
            where 
                Восхождения.Дата_начала::date >= f_data - interval '1 days' * f_N_days
                and Альпинист_Восхождение.ID_Альпиниста = f_ID_Альпиниста
        ) as sub
        ;
    else
        select COALESCE(sub_avg, 0) into avg_durationClimbings
        from
        (
            select avg(COALESCE(Восхождения.Дата_завершения::date, f_data::date) - Восхождения.Дата_начала::date) as sub_avg
            from Вершины 
            inner join Восхождения on Восхождения.ID_Вершины = Вершины.ID_Вершины
            inner join Альпинист_Восхождение on Альпинист_Восхождение.ID_Восхождения = Восхождения.ID_Восхождения
            where 
                Восхождения.Дата_начала::date >= f_data - interval '1 days' * f_N_days
        ) as sub
    ; 
    end if;
    return avg_durationClimbings;
end;
$$ language plpgsql;





-----------------------------------

drop function if exists F_avg_durationClimbings;
create or replace function F_avg_durationClimbings(
    f_ID_Вершины integer
    , f_ID_Альпиниста integer default -1
    , f_data date default now()::date
    , f_N_days integer default 100000
) returns integer as $$
declare
    avg_durationClimbings integer := 0
;
begin
    if f_ID_Альпиниста != -1
        select COALESCE(sub_avg, 0) into avg_durationClimbings
        from
        (
            select avg(COALESCE(Восхождения.Дата_завершения::date, f_data::date) - Восхождения.Дата_начала::date) as sub_avg
            from Вершины 
            inner join Восхождения on Восхождения.ID_Вершины = Вершины.ID_Вершины
            inner join Альпинист_Восхождение on Альпинист_Восхождение.ID_Восхождения = Восхождения.ID_Восхождения
            where 
                Восхождения.Дата_начала::date >= f_data - interval '1 days' * f_N_days
                and Альпинист_Восхождение.ID_Альпиниста = f_ID_Альпиниста
        ) as sub
        ;
    else
        select COALESCE(sub_avg, 0) into avg_durationClimbings
        from
        (
            select avg(COALESCE(Восхождения.Дата_завершения::date, f_data::date) - Восхождения.Дата_начала::date) as sub_avg
            from Вершины 
            inner join Восхождения on Восхождения.ID_Вершины = Вершины.ID_Вершины
            inner join Альпинист_Восхождение on Альпинист_Восхождение.ID_Восхождения = Восхождения.ID_Восхождения
            where 
                Восхождения.Дата_начала::date >= f_data - interval '1 days' * f_N_days
        ) as sub
    ; 
    end if;
    return avg_durationClimbings;
end;
$$ language plpgsql;

--анонимный запрос для проверки
-- DO $$
-- BEGIN
    SELECT 
        Альпинисты.ID_Альпиниста as id,
        F_countClimbings_climber(Альпинисты.ID_Альпиниста) as count_all_climbings,
        F_countClimbings_climber(Альпинисты.ID_Альпиниста, now()::date, 30) as count_30days_climbings
    FROM Альпинисты;
-----------------------
--разобраться с функцией и ее тестированием
drop function if exists F_avg_durationClimbings;
create or replace function F_avg_durationClimbings(
    f_ID_Вершины integer
    , f_ID_Альпиниста integer default -1
    , f_data date default now()::date
    , f_N_days integer default 100000
) returns integer as $$
declare
    avg_durationClimbings integer := 0
;
begin
    if f_ID_Альпиниста != -1
	then
        select COALESCE(sub_avg, 0) into avg_durationClimbings
        from
        (
            select avg(COALESCE(Восхождения.Дата_завершения::date, f_data::date) - Восхождения.Дата_начала::date) as sub_avg
            from Вершины 
            inner join Восхождения on Восхождения.ID_Вершины = f_ID_Вершины
            inner join Альпинист_Восхождение on Альпинист_Восхождение.ID_Восхождения = Восхождения.ID_Восхождения
            where 
                Восхождения.Дата_начала::date >= f_data - interval '1 days' * f_N_days
                and Альпинист_Восхождение.ID_Альпиниста = f_ID_Альпиниста
        ) as sub
        ;
    else
        select COALESCE(sub_avg, 0) into avg_durationClimbings
        from
        (
            select avg(COALESCE(Восхождения.Дата_завершения::date, f_data::date) - Восхождения.Дата_начала::date) as sub_avg
            from Вершины 
            inner join Восхождения on Восхождения.ID_Вершины = f_ID_Вершины
            inner join Альпинист_Восхождение on Альпинист_Восхождение.ID_Восхождения = Восхождения.ID_Восхождения
            where 
                Восхождения.Дата_начала::date >= f_data - interval '1 days' * f_N_days
        ) as sub
    ; 
    end if;
    return avg_durationClimbings;
end;
$$ language plpgsql;
SELECT 
        Альпинисты.ID_Альпиниста as id,
        F_avg_durationClimbings(Альпинисты.ID_Альпиниста, 1, now()::date, 200) as count_all_climbings
        --F_avg_durationClimbings(Альпинисты.ID_Альпиниста, Альпинисты.ID_Альпиниста, now()::date, 10) as count_15days_climbings
    FROM Альпинисты;

select * 
from Восхождения
inner join Альпинист_Восхождение 
where ID_Альпиниста = 0;
-- END;
-- $$LANGUAGE plpgsql;
-- 6.3. Написать процедуру, которая формирует календарь восхождений для заданного альпиниста. (id_альпиниста и год – параметры функции).
-- Формат вывода:
-- ------------------------------------------------------
-- Календарь восхождений для <ФИО> на <год> год:
-- <месяц_1>:
--  1. <Вершина_1>, <дата начала восхождения> – <дата окончания восхождения>;
--  2. <Вершина_2>, <дата начала восхождения> – <дата окончания восхождения>;
--  <и т. д.> ….
-- <месяц_2 (без восхождений)>: восхождения не запланировано
-- <и т. д.> ….
-- ------------------------------------------------------
-- 6.4. Написать процедуру, которая выполняете копирование всех данных об указанном альпинисте, включая восхождения. Аргумент процедуры -
-- id_альпиниста. Для скопированной записи ставится отметка “копия” в поле ФИО.
-- 6.5. Написать один или несколько сценариев (анонимных блока) демонстрирующий работу процедур и функций из п. 1-4.
-- Требование:
-- - Включение в запрос (для функций)
-- - Для каждой процедуры не менее 3-х примеров работы с различными значениями аргументов.
-- - Комментарии для каждого сценария, описывающие суть примера и результат.