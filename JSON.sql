use alma_de_cafe;
/*--Para la Colleccion Bebidas
SELECT 
    b.id_bebida,
    b.nombre_bebida,
    b.tipo_bebida,
    b.precio_bebida,
    b.descripcion_bebida,
    b.forma_de_preparacion,
    (
        SELECT 
            i.id_ingrediente,
            r.nombre_recurso AS nombre,
            i.sabor,
            bi.cantidad_ingrediente as cantidad,
            bi.especificaciones
        FROM bebidas_ingredientes bi
        INNER JOIN ingredientes i ON i.id_ingrediente = bi.id_ingrediente
        INNER JOIN recursos r ON r.id_recurso = i.id_recurso
        WHERE bi.id_bebida = b.id_bebida
        FOR JSON PATH
    ) AS ingredientes
FROM bebidas b
FOR JSON PATH
--JSON Para la Coleccion Empleados
SELECT 
    id_empleado,
    nombre_empleado,
    apellido_paterno_emp,
    apellido_materno_emp,
    JSON_QUERY(
        (
            SELECT 
                p.id_puesto, 
                p.nombre_puesto
            FROM puestos p 
            WHERE p.id_puesto = empleados.id_puesto
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )
    ) AS puesto
FROM 
    empleados
FOR JSON PATH
*/
SELECT 
    p.id_pedido,
    CAST(p.total AS DECIMAL(18, 2)) AS total,
    CAST(p.subtotal AS DECIMAL(18, 2)) AS subtotal,
    p.dia_pedido,
    p.mes_pedido,
    p.anio_pedido,
    p.estatus,
    JSON_QUERY(
        (SELECT 
            e.id_empleado,
            e.nombre_empleado AS nombre,
            pu.nombre_puesto AS puesto
         FROM empleados e 
         INNER JOIN puestos pu ON pu.id_puesto = e.id_puesto
         WHERE e.id_empleado = p.id_empleado
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) AS empleado,
    JSON_QUERY(
        (SELECT 
            m.id_mesa,
            m.capacidad
         FROM mesas m
         WHERE m.id_mesa = p.id_mesa
         FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)) AS mesa,
    JSON_QUERY(
        (SELECT 
            pos.id_postre,
            pos.descripcion_postre AS nombre_postre,
            posped.cantidad,
            CAST(pos.precio_postre AS DECIMAL(18, 2)) AS precio -- Convertir a DECIMAL aquí
         FROM postres pos 
         INNER JOIN postres_pedidos posped ON posped.id_postre = pos.id_postre
         WHERE posped.id_pedido = p.id_pedido
         FOR JSON PATH)) AS postres,
    JSON_QUERY(
        (SELECT 
            b.id_bebida,
            b.nombre_bebida,
            bped.cantidad,
            CAST(b.precio_bebida AS DECIMAL(18, 2)) AS precio -- Convertir a DECIMAL aquí
         FROM bebidas b 
         INNER JOIN bebidas_pedidos bped ON bped.id_bebida = b.id_bebida
         WHERE bped.id_pedido = p.id_pedido
         FOR JSON PATH)) AS bebidas
FROM pedidos p
WHERE id_pedido = 5
FOR JSON PATH;

--JSON_ARRAY(Phone) as Phone --para transformar a array :3