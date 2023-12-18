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

-- 6.2. Написать функцию, которая для заданной вершины возвращает среднюю длительность восхождений в днях. Значение может рассчитываться за
-- конкретный сезон и/или для конкретного альпиниста. Принадлежность восхождения сезону определяется по дате начала, если восхождение ещё не
-- завершено, то учитывается число прошедших с его начала дней. Функция имеет три аргумента: id_вершины, сезон (номер от 1 до 4),
-- id_альпиниста. Только первый аргумент является обязательным. Предусмотреть вариант вызова функции без необязательных аргументов.

---переписываем для season
drop function if exists F_avg_durationClimbings;
create or replace function F_avg_durationClimbings(
    f_ID_Вершины integer
    , f_season integer
    , f_ID_Альпиниста integer default -1
) returns integer as $$
declare
    avg_durationClimbings integer := 0
    left_data timestamp := date_trunc('year', current_timestamp)
    right_date timestamp := (date_trunc('year', current_timestamp) + interval '1 month'*4 - interval '1 day')
;
begin
    if f_season > 4 or f_season < 1
    then f_season := 1
    ;
    end if;
    
    if
    if f_ID_Альпиниста != -1
    then
    ;
    else
    ;
    end if;
    return avg_durationClimbings;










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