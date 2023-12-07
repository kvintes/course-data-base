
pd_orders
id, emp_id, cust_id, paid_up
        , order_date, delivery_date
        , exec_date
        , order_comment
id, emp_id, cust_id, paid_up, order_date, delivery_date, exec_date, order_comment

DROP FUNCTION IF EXISTS f_costs_product_inOrder;

CREATE OR REPLACE FUNCTION f_costs_product_inOrder(
    f_id_product INT
    , number_month INT DEFAULT 0
) RETURNS NUMERIC AS
$$
DECLARE
    costs_product_inOrder NUMERIC := 0; 
    costs_product_inOrder_2 NUMERIC := 0;
    ffinal NUMERIC := 0;
BEGIN
    IF number_month > 0 THEN
        SELECT pd_products.price::NUMERIC * pd_order_details.quantity
        INTO costs_product_inOrder
        FROM pd_orders
        INNER JOIN pd_order_details ON pd_order_details.order_id = pd_orders.id
        INNER JOIN pd_products ON pd_products.id = pd_order_details.product_id
        WHERE pd_products.id = f_id_product
        AND EXTRACT(MONTH FROM pd_orders.order_date)::INTEGER = number_month;
    ELSE
        SELECT pd_products.price::NUMERIC * pd_order_details.quantity
        INTO costs_product_inOrder_2
        FROM pd_orders
        INNER JOIN pd_order_details ON pd_order_details.order_id = pd_orders.id
        INNER JOIN pd_products ON pd_products.id = pd_order_details.product_id
        WHERE pd_products.id = f_id_product;
    END IF;

    IF number_month > 0 THEN
        ffinal := costs_product_inOrder;
    ELSE
        ffinal := costs_product_inOrder_2;
    END IF;
    
    RETURN ffinal;
END;
$$ LANGUAGE plpgsql;

SELECT pd_product.id, f_costs_product_inOrder(pd_product.id), f_costs_product_inOrder(pd_product.id, 5)
FROM pd_products;