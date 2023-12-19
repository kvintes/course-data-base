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


---основная процедура

drop PROCEDURE if exists P_get_Climbing_calendar;
CREATE PROCEDURE P_get_Climbing_calendar(
    p_id_альпиниста integer
    , year integer
) 
LANGUAGE plpgsql
AS $$-- 6010 - последний id
begin
	RAISE NOTICE '
    select 
        extract(''month'' from g.m::date)::integer AS month
	    , F_get_climbingsPlan_month(p_id_альпиниста, year, extract(''month'' from g.m::date)::integer)
    FROM generate_series(''2022-01-01''::timestamp, ''2022-12-01''::timestamp, ''1 month'') g(m)
    cross join Альпинисты
    where 
        Альпинисты.id_Альпиниста = p_id_альпиниста
	'
	;
end;
$$;

CALL P_get_Climbing_calendar(7, 2023);
--- видим тело процедуры