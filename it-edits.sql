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
where sub.height_peak < sub_avg_height.avg_height
;