select sub_main.months, sub_main.id, sub_main.discount
from
(
    select 
        sub_months.months as months
        , 
        case 
            when sub_months.months::int = 1
            then pd_products.price::numeric - f_new_price_by_disconts(pd_products.id, 31, '2023-01-31'::date)
            when sub_months.months::int = 2
            then pd_products.price::numeric - f_new_price_by_disconts(pd_products.id, 28, '2023-02-28'::date)
            when sub_months.months::int = 3
            then pd_products.price::numeric - f_new_price_by_disconts(pd_products.id, 31, '2023-03-31'::date)
            when sub_months.months::int = 4
            then pd_products.price::numeric - f_new_price_by_disconts(pd_products.id, 30, '2023-04-30'::date)
            when sub_months.months::int = 5
            then pd_products.price::numeric - f_new_price_by_disconts(pd_products.id, 31, '2023-05-31'::date)
            when sub_months.months::int = 6
            then pd_products.price::numeric - f_new_price_by_disconts(pd_products.id, 30, '2023-06-30'::date)
            when sub_months.months::int = 7
            then pd_products.price::numeric - f_new_price_by_disconts(pd_products.id, 31, '2023-07-31'::date)
            when sub_months.months::int = 8
            then pd_products.price::numeric - f_new_price_by_disconts(pd_products.id, 31, '2023-08-31'::date)
            when sub_months.months::int = 9
            then pd_products.price::numeric - f_new_price_by_disconts(pd_products.id, 30, '2023-09-30'::date)
            when sub_months.months::int = 10
            then pd_products.price::numeric - f_new_price_by_disconts(pd_products.id, 31, '2023-10-31'::date)
            when sub_months.months::int = 11
            then pd_products.price::numeric - f_new_price_by_disconts(pd_products.id, 30, '2023-01-30'::date)
            else
            pd_products.price::numeric - f_new_price_by_disconts(pd_products.id, 31, '2023-12-31'::date)
        end as discount
        , pd_products.id as id
        from pd_products
        inner join
        (
            select extract(month from pd_orders.order_date) as months
            from pd_orders
            WHERE pd_orders.order_date BETWEEN '2023-01-01' AND '2023-12-31'
            group by extract(month from pd_orders.order_date)
        ) as sub_months on true
) as sub_main

inner join 
(
    select subquery.months as months, max(-subquery.discount::numeric) as max_discount from
    (
    select 
        sub_months.months as months
        , 
        case 
            when sub_months.months::int = 1
            then pd_products.price::numeric - f_new_price_by_disconts(pd_products.id, 31, '2023-01-31'::date)
            when sub_months.months::int = 2
            then pd_products.price::numeric - f_new_price_by_disconts(pd_products.id, 28, '2023-02-28'::date)
            when sub_months.months::int = 3
            then pd_products.price::numeric - f_new_price_by_disconts(pd_products.id, 31, '2023-03-31'::date)
            when sub_months.months::int = 4
            then pd_products.price::numeric - f_new_price_by_disconts(pd_products.id, 30, '2023-04-30'::date)
            when sub_months.months::int = 5
            then pd_products.price::numeric - f_new_price_by_disconts(pd_products.id, 31, '2023-05-31'::date)
            when sub_months.months::int = 6
            then pd_products.price::numeric - f_new_price_by_disconts(pd_products.id, 30, '2023-06-30'::date)
            when sub_months.months::int = 7
            then pd_products.price::numeric - f_new_price_by_disconts(pd_products.id, 31, '2023-07-31'::date)
            when sub_months.months::int = 8
            then pd_products.price::numeric - f_new_price_by_disconts(pd_products.id, 31, '2023-08-31'::date)
            when sub_months.months::int = 9
            then pd_products.price::numeric - f_new_price_by_disconts(pd_products.id, 30, '2023-09-30'::date)
            when sub_months.months::int = 10
            then pd_products.price::numeric - f_new_price_by_disconts(pd_products.id, 31, '2023-10-31'::date)
            when sub_months.months::int = 11
            then pd_products.price::numeric - f_new_price_by_disconts(pd_products.id, 30, '2023-01-30'::date)
            else
            pd_products.price::numeric - f_new_price_by_disconts(pd_products.id, 31, '2023-12-31'::date)
        end as discount
        from pd_products
        inner join
        (
            select extract(month from pd_orders.order_date) as months
            from pd_orders
            WHERE pd_orders.order_date BETWEEN '2023-01-01' AND '2023-12-31'
            group by extract(month from pd_orders.order_date)
        ) as sub_months on true
    ) as subquery
    group by subquery.months
) as sub_max_discont_month on sub_main.months = sub_max_discont_month.months and -sub_main.discount::numeric = sub_max_discont_month.max_discount
;