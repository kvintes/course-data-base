-- 6.1. Написать функцию, которая возвращает количество восхождений для заданного альпиниста в указанный период (id_альпиниста и промежуток
-- времени – аргументы функции). Если промежуток времени не указан, считается количество за всё время.

-- № 6.1. Используйте NULL вместо константы для необязательного параметра.
drop function if exists F_countClimbings_climber;
create or replace function F_countClimbings_climber(
    f_ID_Альпиниста integer
    , f_data date default now()::date
    , f_N_days integer default NULL --Используйте NULL вместо константы для необязательного параметра.
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


SELECT 
    Альпинисты.ID_Альпиниста as id,
    F_countClimbings_climber(Альпинисты.ID_Альпиниста) as count_all_climbings,
    F_countClimbings_climber(Альпинисты.ID_Альпиниста, now()::date, 30) as count_30days_climbings
FROM Альпинисты;


-- 6.2. Написать функцию, которая для заданной вершины возвращает среднюю длительность восхождений в днях. Значение может рассчитываться за
-- конкретный сезон и/или для конкретного альпиниста. Принадлежность восхождения сезону определяется по дате начала, если восхождение ещё не
-- завершено, то учитывается число прошедших с его начала дней. Функция имеет три аргумента: id_вершины, сезон (номер от 1 до 4),
-- id_альпиниста. Только первый аргумент является обязательным. Предусмотреть вариант вызова функции без необязательных аргументов.

-- № 6.2. Если сезон не был передан, среднее число должно быть рассчитано за всё время. 
-- Также постарайтесь избавиться от дублирования самих запросов в функции (сделайте case внутренним по отношению к запросу, а не внешним).
---переписываем для season
drop function if exists F_avg_durationClimbings;
create or replace function F_avg_durationClimbings(
    f_ID_Вершины integer
    , f_season integer default -1
    , f_ID_Альпиниста integer default NULL
) returns numeric as $$
declare
    avg_durationClimbings numeric := 0;
    left_data date := date_trunc('year', current_timestamp)::date;
    right_date date := (date_trunc('year', current_timestamp) + interval '1 month'*3 - interval '1 day')::date;
    temp_date interval := (interval '1 month'*3);
begin
    if f_season = -1
    then --Если сезон не был передан, среднее число должно быть рассчитано за всё время. 
        left_data = (select min(Восхождения.Дата_начала::date) from Восхождения);
    end if; -- считаем за весь период

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
    end if; -- здесь мы вычисляем промежуток по датам

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
			and (f_ID_Альпиниста is NULL OR Альпинист_Восхождение.ID_Альпиниста = f_ID_Альпиниста) -- от дублирования самих запросов
    ) as sub
    ;

    return avg_durationClimbings;

end;
$$ language plpgsql;
---проверочный запрос 6.2
select F_avg_durationClimbings(12) as avg_duration;
select F_avg_durationClimbings(12, 3) as avg_duration;
select F_avg_durationClimbings(12, 2) as avg_duration;
select F_avg_durationClimbings(12, 2, 0) as avg_duration;
select F_avg_durationClimbings(12, 2, 6) as avg_duration;
select * 
from Вершины
inner join Восхождения on Восхождения.id_Вершины = Вершины.id_Вершины
where Восхождения.id_Вершины = 12
;






-- 7.1. Написать триггер, который активизируются при изменении содержимого таблицы “Восхождения” и проверяет, чтобы возраст альпинистов,
-- совершающих восхождения на вершины высотой более 1500 м был более 21 года. Предельную высоту и возраст оформить как константы.

-- № 7.1. Перепутано значение параметра lim_age: должно быть 21, а не 1000.
DROP TRIGGER IF EXISTS T_Восхождения_check_age ON Восхождения;
CREATE or replace FUNCTION T_Восхождения_check_age() RETURNS trigger AS $T_Восхождения_check_age$
declare
    lim_age integer = 21; -- lim_age: должно быть 21, а не 1000.
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


-- 7.3. Написать триггер, который при вставке в таблицу “Вершины” проверяет наличие вершины с таким же названием в указанной стране и если
-- такая вершина есть, вместо вставки обновляет высоту и регион.
DROP TRIGGER IF EXISTS T_check_hills ON Вершины;
CREATE or replace FUNCTION T_check_hills() RETURNS trigger AS $T_check_hills$
declare
    t_id_Вершины integer := (select id_Вершины from Вершины 
							where Вершины.Страна = new.Страна and Вершины.Название ILIKE new.Название);
BEGIN
    if t_id_Вершины is null -- Проверка "not TG_OP ilike 'insert'" по идее лишняя, т.к. сам триггер подвязан только на команду INSERT.
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

