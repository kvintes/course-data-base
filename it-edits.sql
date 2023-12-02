--1. Неверно реализован запрос 3.5: нужно вывести только те вершины, высота которых меньше средней по региону.
select
sub.name_peak, sub.height_peak, sub_avg_height.avg_height as avg_height_region
from
(
    select Вершины.Регион as region, avg(Вершины.Высота) as avg_height
    from Вершины    
    group by Вершины.Регион
) as sub_avg_height
inner join
(
    select Вершины.Регион as region, Вершины.Высота as height_peak, Вершины.id_Вершины as peak
    , Вершины.Название as name_peak
    from Вершины
) as sub on sub.region ILIKE sub_avg_height.region
where sub.height_peak < sub_avg_height.avg_height -- ДОБАВЛЕНО высота которых меньше средней по региону.
;

--2. В разделе №4 нужно добавить вывод таблиц до и после изменения схемы БД.

--      4 задание       --
-- 4.1. В таблицу “Восхождения” добавить атрибут: “Итоговая продолжительность восхождения”. Для атрибута допустимо значение null. Заполнить
-- новое поле значениями для все завершённых восхождений. Продолжительность рассчитывается в днях.


select * from Восхождения; -- ДОБАВЛЕНО проверочный запрос до изменения схемы бд
--1 шаг добавляем новуб колонку в таблицу Восхождения
ALTER TABLE Восхождения add COLUMN Дней_восхождения numeric;

UPDATE Восхождения SET Дней_восхождения = 
(
    select sub.Дней_восхождения
    from
    (
    select Восхождения.id_Восхождения as id_climbing,
    CASE 
        WHEN Восхождения.Дата_завершения is NULL THEN NULL
        ELSE date_part('day', Дата_завершения-Дата_начала)
    END as Дней_восхождения
    from Восхождения
    ) as sub
    where sub.id_climbing = Восхождения.id_Восхождения
)
;
select * from Восхождения; -- проверочный запрос

-- 4.2. Удалить сведенья об альпинистах, не совершивших ни одного восхождения.

select * from Альпинист_Восхождение; -- ДОБАВЛЕНО проверочный запрос до изменения схемы бд

DELETE FROM Альпинист_Восхождение
WHERE id_Альпиниста IN 
(
    SELECT sub_help.id 
    FROM 
    (
        select
        sub.id as id, sub.count_climbings as count
        from 
        (
            select Альпинисты.id_Альпиниста as id, count(Альпинист_Восхождение.id_Восхождения) as count_climbings
            from Альпинисты
            inner join Альпинист_Восхождение on Альпинист_Восхождение.id_Альпиниста = Альпинисты.id_Альпиниста
            group by Альпинисты.id_Альпиниста
        ) as sub
    ) as sub_help 
    WHERE sub_help.count = 0
);

select * from Альпинист_Восхождение; -- ДОБАВЛЕНО проверочный запрос после изменения схемы бд
--4.3. Выделить справочник регионов в отдельную таблицу.
drop table if exists regions;
select * from Вершины; -- ДОБАВЛЕНО проверочный запрос после изменения схемы бд
-- 1шаг создаем новую таблицу regions
create table if not exists it_2.regions
(
    id serial not null
    , name_region text not null
    , constraint PK_regions primary key (id)
);
-- 2шаг заполняем новую таблицу regions
INSERT INTO it_2.regions
  ( name_region )
(
    select Регион
    from Вершины
    group by Регион
); -- про модификацию таблиц не сказано, новая таблица создана

--3 п.4.3: после выноса регионов в справочник нужно убрать их из таблицы вершин и заменить ссылкой на id региона, чтобы убрать дублирование данных.

-- ДОБАВЛЕНО 3 шаг добавляем колонку region_id в таблицу Вершины
ALTER TABLE Вершины ADD COLUMN region_id integer;

-- ДОБАВЛЕНО 4 шаг заполняем колонку region_id в таблице Вершины данными id из regions
UPDATE Вершины SET region_id = 
(
    SELECT id FROM regions
    WHERE Вершины.Регион ILIKE regions.name_region
)
;
select * from Вершины;

-- ДОБАВЛЕНО 5 шаг удаление Регион из таблицы Вершины 
ALTER TABLE Вершины DROP COLUMN Регион;

SELECT * FROM Вершины; -- ДОБАВЛЕНО проверочный запрос после изменения схемы бд
SELECT * FROM regions; -- ДОБАВЛЕНО проверочный запрос после изменения схемы бд
