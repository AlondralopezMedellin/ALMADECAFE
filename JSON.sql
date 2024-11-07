use alma_de_cafe;
--Para la Colleccion Bebidas
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
            FOR JSON PATH
        )
    ) AS puesto
FROM 
    empleados
FOR JSON PATH
--JSON Para la Coleccion Pedidos
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
         FOR JSON PATH)) AS empleado,
    JSON_QUERY(
        (SELECT 
            m.id_mesa,
            m.capacidad
         FROM mesas m
         WHERE m.id_mesa = p.id_mesa
         FOR JSON PATH)) AS mesa,
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


--JSON Para la Coleccion Ingredientes
SELECT 
    i.id_ingrediente,
    JSON_QUERY(
        (SELECT TOP 1 
            r.id_recurso,
            r.cantidad_existente,
            r.fecha_caducidad
         FROM recursos r 
         WHERE i.id_recurso = r.id_recurso 
         FOR JSON PATH)
    ) AS recurso,
    i.tipo_ingrediente,
    i.sabor 
FROM ingredientes i
where i.id_ingrediente = 9
FOR JSON PATH;

--JSON Para la Coleccion Postres
SELECT p.id_postre,p.precio_postre,p.descripcion_postre,
 JSON_QUERY(
        (SELECT TOP 1 
            r.id_recurso,
            r.cantidad_existente,
            r.fecha_caducidad
         FROM recursos r 
         WHERE p.id_recurso = r.id_recurso 
         FOR JSON PATH)
    ) AS recurso,
	p.margen_de_ganancia
FROM postres p
FOR JSON PATH;

--JSON Para la Coleccion Recursos
SELECT * FROM recursos r
FOR JSON PATH;



--JSON Para la Coleccion Puestos
select * from puestos
FOR JSON PATH;


--JSON Para la Coleccion Entregas
SELECT 
    e.id_entrega,
    e.dia_entrega,
    e.mes_entrega,
    e.anio_entrega,
    e.fecha_caducidad,
    e.hora,
    e.cantidad_entregada,
    e.costo,
    JSON_QUERY(
        (SELECT TOP 1 
            p.id_proveedor,
            p.nombre_prov
         FROM proveedores p
         WHERE e.id_proveedor = p.id_proveedor 
         FOR JSON PATH)
    ) AS proveedor,
    JSON_QUERY(
        (SELECT 
            r.id_recurso,
            r.nombre_recurso
         FROM recursos r 
         INNER JOIN recursos_entregas re ON re.id_recurso = r.id_recurso
         WHERE re.id_entrega = e.id_entrega
         FOR JSON PATH)  
		 ) AS recursos
FROM entregas e
FOR JSON PATH;
--JSON Para la Coleccion Proveedores
select * from proveedores
FOR JSON PATH;

--JSON Para la Coleccion Mesaa
select * from mesas
FOR JSON PATH;
--JSON Para la Coleccion Accesos
SELECT ea.id_empleado_acceso,
e.id_empleado as [empleado.id_empleado],
e.nombre_empleado as [empleado.nombre_empleado],
p.nombre_puesto as [empleado.puesto],
a.id_acceso as [tipo_acceso.id_acceso],
a.descripcion as [tipo_acceso.descripcion],
ea.fecha,
ea.hora
FROM empleados_accesos ea
inner join empleados e on e.id_empleado = ea.id_empleado
inner join puestos p on p.id_puesto = e.id_puesto
inner join accesos a on a.id_acceso = ea.id_acceso
FOR JSON PATH;

--JSON Para la Coleccion Tipos de Accesos

SELECT id_acceso, descripcion, nivel_acceso
FROM accesos
FOR JSON PATH;

--JSON Para la Coleccion de Ventas
SELECT V.id_venta,
V.metodo_pago,
C.id_cliente as [cliente.id_cliente],
C.nombre_cliente as [cliente.nombre_cliente],
P.id_pedido as [pedido.id_pedido],
P.total as [pedido.total],
P.subtotal as [pedido.subtotal]
From ventas V
inner join clientes C on C.id_cliente = V.id_cliente
inner join pedidos P on P.id_pedido = V.id_pedido
FOR JSON PATH;


--JSON Para la Coleccion de Clientes
select C.id_cliente,C.nombre_cliente,C.apellidos_cliente,C.nacionalidad 
from clientes C
FOR JSON PATH;
