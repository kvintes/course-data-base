-- 6. Написать процедуры и функции, согласно условиям. Все процедуры и функции при необходимости должны включать обработчики исключений.
-- Названия функций: F_<имя>. Формат названий процедур: P_<имя>. Написать анонимные блоки или запросы для проверки работы процедур и
-- функций.
SET search_path TO it_2;

-- 6.1. Написать функцию, которая возвращает количество восхождений для заданного альпиниста в указанный период (id_альпиниста и промежуток
-- времени – аргументы функции). Если промежуток времени не указан, считается количество за всё время.

drop function if exists F_countClimbings_climber;
create or replace function F_countClimbings_climber(
    f_ID_Альпиниста integer
    , f_data date default now()::date
    , f_N_days integer default NULL
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
        and (f_N_days is NULL OR Восхождения.Дата_начала::date >= f_data - interval '1 day' * f_N_days  )
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

---вспомогательная функция
CREATE OR REPLACE FUNCTION F_get_climbingsPlan_month( --- делаем фунцию, которая получает новый месяц 
    p_id_альпиниста integer ---и возвращает строку вида <Вершина_1>, <дата начала восхождения> – <дата окончания восхождения>;
    , year integer
    , month integer
)RETURNS text as $$
declare
    message_month text := '(без восхождений)';
begin
    select COALESCE(STRING_AGG(all_text_month, '\n'), '(без восхождений)')  into message_month
    from
    (
        select concat(num, '. ', rock, ' ', date_start_climbing, ' - ', date_end_climbing, ' ') as all_text_month
        from
        (
            select 
	        row_number() OVER() as num
	        , Вершины.Название as rock
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
    return message_month;
end;
$$ language plpgsql;

drop function if exists F_get_Climbing_calendar; -- через функцию
CREATE OR REPLACE FUNCTION F_get_Climbing_calendar(
    p_id_альпиниста integer,
    year integer
) 
RETURNS TABLE (
    tex text
)
LANGUAGE SQL
AS $$ 
    select concat('Календарь восхождений для ',(select ФИО from Альпинисты where id_Альпиниста = p_id_альпиниста) ,' на ' ,year ,' год: ' ,STRING_AGG(total_mrak.mrak, E'\t'))
    from
    (
	    select concat(mrak_sub.s_month, ': ', E'\t' , mrak_sub.s_text) as mrak
	    from 
	    (
	    	select
	    		case 
	    			when sub.climbings_plan ILIKE 'восхождения не запланировано'
	    			then concat(sub.month, ' (без восхождений)')
	    			else concat(sub.month, '')
	    		end as s_month
	    		, sub.climbings_plan as s_text
	    	from 
        	(
	    		select 
            		extract('month' from g.m::date)::integer AS month
          			, F_get_climbingsPlan_month(p_id_альпиниста, year, extract('month' from g.m::date)::integer) as climbings_plan
        		FROM generate_series('2022-01-01'::timestamp, '2022-12-01'::timestamp, '1 month') g(m)
        		cross join Альпинисты
        		where 
            		Альпинисты.id_Альпиниста = p_id_альпиниста
	    	) as sub
	    )as mrak_sub
    ) as total_mrak
	
$$;

SELECT * FROM F_get_Climbing_calendar(7, 2023);
SELECT id_Альпиниста, F_get_Climbing_calendar(id_Альпиниста, 2023) FROM Альпинисты;

drop PROCEDURE if exists P_get_Climbing_calendar; -- через процедуру
CREATE OR replace PROCEDURE  P_get_Climbing_calendar(
    p_id_альпиниста integer,
    year integer
) 
LANGUAGE plpgsql
AS $$ 
begin
    RAISE NOTICE '%', 
    (select concat('Календарь восхождений для ',(select ФИО from Альпинисты where id_Альпиниста = p_id_альпиниста) ,' на ' ,year ,' год: ', E'\n' ,STRING_AGG(total_mrak.mrak, ''), E'\n')
    from
    (
	    select concat(mrak_sub.s_month, ': ', E'\t' , mrak_sub.s_text, E'\n') as mrak
	    from 
	    (
	    	select
	    		case 
	    			when sub.climbings_plan ILIKE 'восхождения не запланировано'
	    			then concat(sub.month, ' (без восхождений)')
	    			else concat(sub.month, '')
	    		end as s_month
	    		, sub.climbings_plan as s_text
	    	from 
        	(
	    		select 
            		extract('month' from g.m::date)::integer AS month
          			, F_get_climbingsPlan_month(p_id_альпиниста, year, extract('month' from g.m::date)::integer) as climbings_plan
        		FROM generate_series('2022-01-01'::timestamp, '2022-12-01'::timestamp, '1 month') g(m)
        		cross join Альпинисты
        		where 
            		Альпинисты.id_Альпиниста = p_id_альпиниста
	    	) as sub
	    )as mrak_sub
    ) as total_mrak
	)
    ;
end;	
$$;
CALL P_get_Climbing_calendar(7, 2023);

---ЗАКОНЧИЛИ---


-- 6.4. Написать процедуру, которая выполняете копирование всех данных об указанном альпинисте, включая восхождения. Аргумент процедуры -
-- id_альпиниста. Для скопированной записи ставится отметка “копия” в поле ФИО.
drop PROCEDURE if exists P_copy_info_Альпинист; -- через процедуру
CREATE OR replace PROCEDURE P_copy_info_Альпинист(
    p_id_альпиниста integer
) 
AS $$ 
begin
	INSERT INTO Альпинисты (ФИО, Адрес, Телефон, Дата_рождения)
  	select 
        Альпинисты.ФИО || ' (копия)', Альпинисты.Адрес
        , Альпинисты.Телефон, Альпинисты.Дата_рождения
    from Альпинисты
    where id_Альпиниста = p_id_альпиниста
    ;
    INSERT INTO Восхождения (Дата_начала, Дата_завершения, ID_Вершины)
    select 
        Восхождения.Дата_начала, Восхождения.Дата_завершения, Восхождения.ID_Вершины
    from Альпинист_Восхождение
    inner join Восхождения on Восхождения.ID_Восхождения = Альпинист_Восхождение.ID_Восхождения
    where Альпинист_Восхождение.ID_Альпиниста = p_id_альпиниста
    ;
end;
$$ LANGUAGE plpgsql;

CALL P_copy_info_Альпинист(7);

-- 7. Создать триггеры, включить обработчики исключений. Написать скрипты для проверки. При необходимости снять ограничения (если
-- ограничение мешает проверить работу триггера).
-- 7.1. Написать триггер, который активизируются при изменении содержимого таблицы “Восхождения” и проверяет, чтобы возраст альпинистов,
-- совершающих восхождения на вершины высотой более 1500 м был более 21 года. Предельную высоту и возраст оформить как константы.
DROP TRIGGER IF EXISTS T_Восхождения_check_age ON Восхождения;
CREATE or replace FUNCTION T_Восхождения_check_age() RETURNS trigger AS $T_Восхождения_check_age$
declare
    lim_age integer = 1000;
    lim_height integer = 1500;
    orders_cursor CURSOR for (
    select 
		age(current_date, Дата_рождения) > interval '1 year' * lim_age as CH_flag_height_age
	from Альпинисты
	inner join Альпинист_Восхождение on Альпинист_Восхождение.ID_Альпиниста = Альпинисты.ID_Альпиниста
	inner join Восхождения on Восхождения.ID_Восхождения = Альпинист_Восхождение.ID_Восхождения
	inner join Вершины on Вершины.ID_Вершины = Восхождения.ID_Вершины
	where 
		Вершины.Высота > lim_height
    )
	;
BEGIN
    FOR row IN orders_cursor LOOP
        IF row.CH_flag_height_age::boolean = false
        	then RAISE EXCEPTION 'MY_it_2_EXCEPTION table Восхождения cannot be update';
        end if;
	end loop;
    return NEW;
END;
$T_Восхождения_check_age$ LANGUAGE plpgsql;  


CREATE or replace TRIGGER T_Восхождения_check_age BEFORE INSERT OR UPDATE ON Восхождения
    FOR EACH ROW EXECUTE PROCEDURE T_Восхождения_check_age();


ALTER TABLE Альпинист_Восхождение 
drop constraint if exists FK_Альпинист_Восние__Восхождения;

delete from Восхождения * where Восхождения.id_Восхождения=9;

insert into Восхождения (id_Восхождения, Дата_начала, Дата_завершения, id_Вершины, Дней_восхождения)
values (9, '2023-02-20 00:00:00', '2023-04-20 00:00:00', 9, 59)
;

-- 7.2. Написать триггер, который сохраняет статистику изменений таблицы «Восхождения» в таблице «Восхождения_Статистика». В таблице
-- «Восхождения_Статистика» хранится дата изменения, тип изменения (insert, update, delete). Триггер также выводит на экран сообщение с
-- указанием количества дней, прошедших со дня последнего изменения.
drop table if exists Восхождения_Статистика;
create table if not EXISTS it_2.Восхождения_Статистика
(
    id integer not null
    , date_change date
    , text_change text not null
    , constraint PK_Восхождения_Статистика primary key (id)
)
;
drop SEQUENCE if exists Восхождения_Статистика_seq;
CREATE SEQUENCE IF NOT EXISTS it_2.Восхождения_Статистика_seq MINVALUE 0;
alter TABLE Восхождения_Статистика alter column id set DEFAULT nextval('Восхождения_Статистика_seq');
ALTER SEQUENCE Восхождения_Статистика_seq OWNED BY Восхождения_Статистика.id;

DROP TRIGGER IF EXISTS T_save_statistics ON Восхождения;
CREATE or replace FUNCTION T_save_statistics() RETURNS trigger AS $T_save_statistics$
BEGIN
    INSERT INTO Восхождения_Статистика (date_change, text_change)
    values (current_date, TG_OP);
    RAISE NOTICE '% количество дней от последнего изменения'
    , (
		select current_date - COALESCE(max(Восхождения_Статистика.date_change), current_date)
		from Восхождения_Статистика
		)
	;
    return NEW;
END;
$T_save_statistics$ LANGUAGE plpgsql;  

CREATE or replace TRIGGER T_save_statistics BEFORE INSERT OR UPDATE OR delete ON Восхождения
    FOR EACH ROW EXECUTE PROCEDURE T_save_statistics();

insert into Восхождения(id_Восхождения, Дата_начала, Дата_завершения, id_Вершины, Дней_восхождения)
values(666, '2023-01-24', '2023-03-13', 0, 48);
select * from Восхождения_Статистика;
insert into Восхождения(id_Восхождения, Дата_начала, Дата_завершения, id_Вершины, Дней_восхождения)
values(667, '2023-03-24', '2023-05-13', 0, 50);
select * from Восхождения_Статистика;

-- 7.3. Написать триггер, который при вставке в таблицу “Вершины” проверяет наличие вершины с таким же названием в указанной стране и если
-- такая вершина есть, вместо вставки обновляет высоту и регион.
DROP TRIGGER IF EXISTS T_check_hills ON Вершины;
CREATE or replace FUNCTION T_check_hills() RETURNS trigger AS $T_check_hills$
declare
    t_id_Вершины integer := (select id_Вершины from Вершины 
							where Вершины.Страна = new.Страна and Вершины.Название ILIKE new.Название);
BEGIN
    if t_id_Вершины is null or not TG_OP ilike 'insert'
    then return new;
    else
        UPDATE Вершины SET Высота = new.Высота, region_id = new.region_id
        WHERE id_Вершины = t_id_Вершины;
    end if;
    return NULL;
END;
$T_check_hills$ LANGUAGE plpgsql;  

CREATE or replace TRIGGER T_check_hills BEFORE INSERT ON Вершины
    FOR EACH ROW EXECUTE PROCEDURE T_check_hills();  

select * from Вершины;

insert into Вершины(Название, Высота, Страна, region_id)
	values ('Эльбрус', 9999, 'Россия', 9);

select * from Вершины;

