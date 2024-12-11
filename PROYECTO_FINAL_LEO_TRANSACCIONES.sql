Use alma_de_cafe;
-------------------------------------------------------------------
-------------------------------------------------------------------
--ASIGNARLE UN PEDIDO AL CLIENTE EN LA APLICACIÓN------------------
-------------------------------------------------------------------
-------------------------------------------------------------------
--COMENZAMOS EL PROCEDIMIENTO
CREATE OR ALTER PROCEDURE sp_Crear_Pedido
--LAS VARIABLES QUE NECESITAMOS
    @id_empleado INT,
    @id_mesa INT,
	@descuento INT
AS
BEGIN
	--PARA GUARDAR EL ID DE EL PEDIDO GENERADO
    DECLARE @id_pedido INT;
    -- Iniciar el Manejo de Errores
    BEGIN TRY
	--INICIAR LA TRANSACCIÓN
        BEGIN TRANSACTION;

        -- 1.- Verificar si el empleado existe
        IF EXISTS (SELECT 1 FROM empleados WHERE id_empleado = @id_empleado)
        BEGIN
            --2.- Verificar si el empleado es mesero (Es el único que puede hacer pedidos)
            IF EXISTS (
                SELECT 1 
                FROM empleados e 
                INNER JOIN puestos p ON p.id_puesto = e.id_puesto 
                WHERE e.id_empleado = @id_empleado 
                  AND p.nombre_puesto = 'Mesero'
            )
            BEGIN
                --3.- Verificar si la mesa existe
                IF EXISTS (SELECT 1 FROM mesas WHERE id_mesa = @id_mesa)
                BEGIN
                    --4.- Verificar que la mesa no esté ocupada 
                    IF NOT EXISTS (
                        SELECT 1 
                        FROM pedidos 
                        WHERE estatus IN ('ACTIVO', 'PROCESO') 
                            AND dia_pedido = DAY(GETDATE()) 
                            AND mes_pedido = MONTH(GETDATE()) 
                            AND anio_pedido = YEAR(GETDATE()) 
                            AND id_mesa = @id_mesa
                    )
                    BEGIN
                        --5.- Insertar el nuevo pedido
                        INSERT INTO pedidos (
                            total, 
                            subtotal, 
                            dia_pedido, 
                            mes_pedido, 
                            anio_pedido, 
                            estatus, 
                            id_empleado, 
                            id_mesa,
							descuento
                        )
                        VALUES (
                            0, 
                            0, 
                            DAY(GETDATE()), 
                            MONTH(GETDATE()), 
                            YEAR(GETDATE()), 
                            'ACTIVO', 
                            @id_empleado, 
                            @id_mesa,
							@descuento
                        );

                        -- Obtener el ID del pedido recién creado
                        SELECT @id_pedido = id_pedido
                        FROM pedidos
                        WHERE id_empleado = @id_empleado
                          AND id_mesa = @id_mesa
                          AND dia_pedido = DAY(GETDATE()) 
                          AND mes_pedido = MONTH(GETDATE()) 
                          AND anio_pedido = YEAR(GETDATE());

                        -- Confirmar la transacción si todo es exitoso
                        COMMIT TRANSACTION;

                        -- Retornar el ID del pedido
                        RETURN @id_pedido;
                    END
                    ELSE
                    BEGIN
                        -- Si la mesa está ocupada, imprimir un mensaje
                        PRINT 'La mesa con ID ' + CAST(@id_mesa AS VARCHAR) + ' se encuentra ocupada.';
                        ROLLBACK TRANSACTION;

                        -- Retornar un valor indicando que la mesa está ocupada
                        RETURN -1;
                    END
                END
                ELSE
                BEGIN
                    PRINT 'No existe la mesa con ID ' + CAST(@id_mesa AS VARCHAR) + '.';
                    ROLLBACK TRANSACTION;

                    -- Retornar un valor indicando que no existe la mesa
                    RETURN -2;
                END
            END
            ELSE
            BEGIN
                PRINT 'El empleado con ID ' + CAST(@id_empleado AS VARCHAR) + ' no tiene el puesto de Mesero.';
                ROLLBACK TRANSACTION;

                -- Retornar un valor indicando que el empleado no es mesero
                RETURN -4;
            END
        END
        ELSE
        BEGIN
            PRINT 'No existe el empleado con ID ' + CAST(@id_empleado AS VARCHAR) + '.';
            ROLLBACK TRANSACTION;

            -- Retornar un valor indicando que no existe el empleado
            RETURN -3;
        END
    END TRY
    BEGIN CATCH
        -- En caso de error, hacer un rollback de la transacción
        ROLLBACK TRANSACTION;

        -- Retornar un valor indicando que ocurrió un error
        RETURN -99; -- Código de error general
    END CATCH
END;

--------------------------------------------------------------------
--PRUEBA DEL  PROCEDIMIENTO sp_Crear_Pedido

--Comprobamos que el empleado luis sea mesero
select id_empleado,nombre_empleado,nombre_puesto from empleados e inner join puestos p on p.id_puesto = e.id_puesto where id_empleado = 6;

-- Llamada al procedimiento
DECLARE @id_pedido INT;
--@id_empleado, @id_mesa, @descuento
execute @id_pedido = sp_Crear_Pedido 6, 17, 10;
-- Mostrar el resultado
IF @id_pedido > 0
    PRINT 'El ID del pedido es: ' + CAST(@id_pedido AS VARCHAR);
ELSE
    PRINT 'Error al crear el pedido. Código de error: ' + CAST(@id_pedido AS VARCHAR);
-------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------
-------------------------------------------------------------------
--Actualización del total y subtotal del pedido ---------------
-------------------------------------------------------------------
-------------------------------------------------------------------

--COMENZAMOS EL PROCEDIMIENTO
CREATE OR ALTER PROCEDURE sp_Modificar_Total_Subtotal_Pedido
    @id_pedido INT,
	--QUE ES EL SUBTOTAL CALCULADO AL MOFIFICAR EL PEDIDO
    @cantidad DECIMAL(10, 2),
    @tipo VARCHAR(10)
AS
BEGIN
    DECLARE @impuesto DECIMAL(5, 2) = 0.16, -- Impuesto del 16%
            @subtotal DECIMAL(10, 2),
            @descuento DECIMAL(5, 2),
            @total DECIMAL(10, 2);

    BEGIN TRY
        -- Iniciar la transacción
        BEGIN TRANSACTION;

        --1.- Verificar si el pedido existe
        IF EXISTS (SELECT 1 FROM pedidos WHERE id_pedido = @id_pedido)
        BEGIN
            --2,- Obtener el descuento actual
            SELECT @descuento = descuento
            FROM pedidos
            WHERE id_pedido = @id_pedido;

            --3.- Revisar de que tipo de modificacion se trata
            IF @tipo = 'AGREGAR'
            BEGIN
			--4.- Modificar el subtotal según el tipo
                UPDATE pedidos
                SET subtotal = subtotal + @cantidad
                WHERE id_pedido = @id_pedido;
            END
            ELSE IF @tipo = 'RESTAR'
            BEGIN
                UPDATE pedidos
                SET subtotal = subtotal - @cantidad
                WHERE id_pedido = @id_pedido;
            END
            ELSE
            BEGIN
                PRINT 'El tipo debe ser AGREGAR o RESTAR.';
                ROLLBACK TRANSACTION;
                RETURN;
            END

            --5.- Recalcular el total después de modificar el subtotal
            SELECT @subtotal = subtotal
            FROM pedidos
            WHERE id_pedido = @id_pedido;

            SET @total = (@subtotal + (@subtotal * @impuesto)) - (@subtotal * (@descuento / 100));

            UPDATE pedidos
            SET total = @total
            WHERE id_pedido = @id_pedido;

        END
        ELSE
        BEGIN
            PRINT 'El pedido con ID especificado no existe.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Confirmar la transacción
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Capturar errores y revertir la transacción
        PRINT 'Ocurrió un error: ' + ERROR_MESSAGE();
        ROLLBACK TRANSACTION;
    END CATCH
END;
--------------------------------------------------------------------
--COMPROBAR EL PROCEDIMIENTO sp_Modificar_Total_Subtotal_Pedido
-- EL PEDIDO CONTIENE EL 10 % DE DESCUENTO
--(200 + ( 200 * 0.16) - (200 * 0.10))) = 212 
select * from pedidos where id_pedido = 49
EXEC sp_Modificar_Total_Subtotal_Pedido @id_pedido = 49,@cantidad =100, @tipo = 'AGREGAR';
---------------------------------------------------------------------------------------------

-------------------------------------------------------------------
-------------------------------------------------------------------
-- Agregar bebida o postre al pedido ---------------
-------------------------------------------------------------------
-------------------------------------------------------------------
--COMENZAR EL PROCEDIMIENTO
CREATE OR ALTER PROCEDURE sp_Agregar_al_Pedido
    @id_pedido INT,
    @id_agregar INT,
    @cantidad INT,
    @tipo VARCHAR(10) 
AS
BEGIN
    DECLARE @subtotal DECIMAL(10, 2); -- Declaración de la variable subtotal
    BEGIN TRY
        -- Iniciar la transacción
        BEGIN TRANSACTION;

        --1.- Verificar si el pedido existe
        IF EXISTS (SELECT 1 FROM pedidos WHERE id_pedido = @id_pedido)
        BEGIN
            --2.- Verificar si el tipo es 'BEBIDA'
            IF @tipo = 'BEBIDA'
            BEGIN
			--3.- Verificar si la BEBIDA existe
                IF EXISTS (SELECT 1 FROM bebidas WHERE id_bebida = @id_agregar)
                BEGIN
                    --4.- Insertar en bebidas_pedidos
                    INSERT INTO bebidas_pedidos (id_bebida, id_pedido, cantidad)
                    VALUES (@id_agregar, @id_pedido, @cantidad);

                    --5.- Obtener el precio de la bebida y calcular el subtotal
                    SELECT @subtotal = precio_bebida * @cantidad
                    FROM bebidas
                    WHERE id_bebida = @id_agregar;
                END
                ELSE
                BEGIN
                    PRINT 'El ID no coincide con ninguna bebida.';
                    ROLLBACK TRANSACTION; -- Revertir la transacción si la bebida no existe
                    RETURN; -- Terminar el procedimiento si no se encuentra la bebida
                END
            END
            --2.- Verificar si el tipo es 'POSTRE'
            ELSE IF @tipo = 'POSTRE'
            BEGIN
				--3.- Verificar si el postre existe
                IF EXISTS (SELECT 1 FROM postres WHERE id_postre = @id_agregar)
                BEGIN
                    --4.- Insertar en postres_pedidos
                    INSERT INTO postres_pedidos (id_postre, id_pedido, cantidad)
                    VALUES (@id_agregar, @id_pedido, @cantidad);

                    --5.- Obtener el precio del postre y calcular el subtotal
                    SELECT @subtotal = precio_postre * @cantidad
                    FROM postres
                    WHERE id_postre = @id_agregar;
                END
                ELSE
                BEGIN
                    PRINT 'El ID no coincide con ningún postre.';
                    ROLLBACK TRANSACTION; -- Revertir la transacción si el postre no existe
                    RETURN; -- Terminar el procedimiento si no se encuentra el postre
                END
            END
            ELSE
            BEGIN
                PRINT 'El tipo especificado no es válido. Debe ser BEBIDA o POSTRE.';
                ROLLBACK TRANSACTION; -- Revertir la transacción si el tipo es inválido
                RETURN; -- Terminar el procedimiento si el tipo es inválido
            END
			--6.- ACTUALIZAR EL TOTAL Y SUBTOTAL 
			execute sp_Modificar_Total_Subtotal_Pedido @id_pedido,@subtotal, 'AGREGAR' 
            -- Confirmar la transacción
            COMMIT TRANSACTION;

            PRINT 'El pedido ha sido actualizado exitosamente.';
        END
        ELSE
        BEGIN
            PRINT 'El pedido con ID ' + CAST(@id_pedido AS NVARCHAR) + ' no existe.';
            ROLLBACK TRANSACTION; -- Revertir la transacción si el pedido no existe
        END
    END TRY
    BEGIN CATCH
        -- Capturar errores y hacer rollback en caso de error
        PRINT 'Error: ' + ERROR_MESSAGE();
        ROLLBACK TRANSACTION; -- Revertir la transacción en caso de error
    END CATCH
END;

-------------------------------------------------------------------------
--COMPROBACION DEL PROCEDIMIENTO sp_Agregar_al_Pedido
--Vamos a agregar un Americano
select * from bebidas where id_bebida = 1
--Vemos el estado actual del pedido
select * from pedidos where id_pedido = 53
--EJECUTAMOS EL PROCEDIMIENTO
EXEC sp_Agregar_al_Pedido @id_pedido = 53, @id_agregar = 1, @cantidad = 1, @tipo = 'BEBIDA';
--Vemos el estado modificado del pedido
select * from pedidos where id_pedido = 53
--Agregamos un Postre
select * from postres where id_postre = 7
--EJECUTAMOS EL PROCEDIMIENTO
EXEC sp_Agregar_al_Pedido @id_pedido = 53, @id_agregar = 7, @cantidad = 2, @tipo = 'POSTRE';
--Vemos el estado modificado del pedido
select * from pedidos where id_pedido = 53
-----------------------------------------------------
--COMPROBACION DEL SUBTOTAL MEDIANTE UNA CONSULTA 
SELECT 
    SUM(p.precio_postre * pp.cantidad) +
    SUM(b.precio_bebida * bp.cantidad) AS subtotal
FROM 
    bebidas_pedidos bp
LEFT JOIN postres_pedidos pp ON pp.id_pedido = bp.id_pedido
LEFT JOIN postres p ON p.id_postre = pp.id_postre
LEFT JOIN bebidas b ON b.id_bebida = bp.id_bebida
WHERE 
 pp.id_pedido = 51;
---------------------------------------------------------------------------------
---------------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE sp_Eliminar_del_Pedido
    @id_pedido INT,
    @id_eliminar INT,
    @tipo VARCHAR(10)
AS
BEGIN
    DECLARE @subtotal DECIMAL(10, 2), -- Declaración de la variable subtotal
            @cantidad INT; -- Declaración de la variable cantidad

    BEGIN TRY
        -- Iniciar la transacción
        BEGIN TRANSACTION;

        --1.- Verificar si el pedido existe
        IF EXISTS (SELECT 1 FROM pedidos WHERE id_pedido = @id_pedido)
        BEGIN
            --2.- Verificar si el tipo es 'BEBIDA'
            IF @tipo = 'BEBIDA'
            BEGIN
                --3.- Verificar si la bebida está en el pedido
                IF EXISTS (SELECT 1 FROM bebidas_pedidos WHERE id_bebida = @id_eliminar AND id_pedido = @id_pedido)
                BEGIN
                    --4.- Obtener la cantidad de la bebida
                    SELECT @cantidad = cantidad
                    FROM bebidas_pedidos 
                    WHERE id_bebida = @id_eliminar AND id_pedido = @id_pedido;

                    --5.- Eliminar la bebida del pedido
                    DELETE FROM bebidas_pedidos
                    WHERE id_bebida = @id_eliminar AND id_pedido = @id_pedido;

                    --6.- Obtener el precio de la bebida y calcular la cantidad eliminada del subtotal
                    SELECT @subtotal = precio_bebida * @cantidad
                    FROM bebidas
                    WHERE id_bebida = @id_eliminar;
                END
                ELSE
                BEGIN
                    PRINT 'La bebida no está en el pedido.';
                    ROLLBACK TRANSACTION; -- Revertir la transacción si no se encuentra la bebida en el pedido
                    RETURN; -- Terminar el procedimiento si no se encuentra la bebida en el pedido
                END
            END
            --2.- Verificar si el tipo es 'POSTRE'
            ELSE IF @tipo = 'POSTRE'
            BEGIN
                --3.- Verificar si el postre está en el pedido
                IF EXISTS (SELECT 1 FROM postres_pedidos WHERE id_postre = @id_eliminar AND id_pedido = @id_pedido)
                BEGIN
                    --4.- Obtener la cantidad del postre
                    SELECT @cantidad = cantidad
                    FROM postres_pedidos 
                    WHERE id_postre = @id_eliminar AND id_pedido = @id_pedido;

                    --5.- Eliminar el postre del pedido
                    DELETE FROM postres_pedidos
                    WHERE id_postre = @id_eliminar AND id_pedido = @id_pedido;

                    --6.- Obtener el precio del postre y calcular la cantidad eliminada del subtotal
                    SELECT @subtotal = precio_postre * @cantidad
                    FROM postres
                    WHERE id_postre = @id_eliminar;
                END
                ELSE
                BEGIN
                    PRINT 'El postre no está en el pedido.';
                    ROLLBACK TRANSACTION; -- Revertir la transacción si no se encuentra el postre en el pedido
                    RETURN; -- Terminar el procedimiento si no se encuentra el postre en el pedido
                END
            END
            ELSE
            BEGIN
                PRINT 'El tipo especificado no es válido. Debe ser BEBIDA o POSTRE.';
                ROLLBACK TRANSACTION; -- Revertir la transacción si el tipo es inválido
                RETURN; -- Terminar el procedimiento si el tipo es inválido
            END

            --7.- Actualizar el subtotal del pedido, restando lo que se eliminó
            execute sp_Modificar_Total_Subtotal_Pedido @id_pedido, @subtotal, 'RESTAR' 

            -- Confirmar la transacción
            COMMIT TRANSACTION;

            PRINT 'El pedido ha sido actualizado exitosamente.';
        END
        ELSE
        BEGIN
            PRINT 'El pedido con ID ' + CAST(@id_pedido AS NVARCHAR) + ' no existe.';
            ROLLBACK TRANSACTION; -- Revertir la transacción si el pedido no existe
        END
    END TRY
    BEGIN CATCH
        -- Capturar errores y hacer rollback en caso de error
        PRINT 'Error: ' + ERROR_MESSAGE();
        ROLLBACK TRANSACTION; -- Revertir la transacción en caso de error
    END CATCH
END;
-----------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------
-- COMPROBACION DEL PROCEDIMIENTO
--Ver el estado Actual del Pedido
select * from pedidos where id_pedido = 53
--ELIMINAR EL POSTRE
EXEC sp_Eliminar_del_Pedido @id_pedido = 53, @id_eliminar = 7, @tipo = 'POSTRE';
--VER EL PRECIO DEL POSTRE
select * from postres where id_postre = 7
--VER QUE NO APARECE EN LA TABLA 
select * from postres_pedidos where id_pedido = 53
--VER EL ESTADO ACTUAL DEL PEDIDO
select * from pedidos where id_pedido = 53
--SOLO QUEDA EL AMERICANO 
--VOLVER A AGREGAR EL POSTRE
execute sp_Agregar_al_Pedido 53,7,1,'POSTRE'
--ELIMINAR BEBIDA
EXEC sp_Eliminar_del_Pedido @id_pedido = 53, @id_eliminar = 1, @tipo = 'BEBIDA';
--Ver que no aparece en la tabla
select * from bebidas_pedidos where id_pedido = 53
--VER EL ESTADO ACTUAL DEL PEDIDO
select * from pedidos where id_pedido = 53
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------
------------------------------------------
CREATE OR ALTER PROCEDURE sp_Crear_Entrega
    @id_proveedor INT
AS
BEGIN
    DECLARE @id_entrega INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        --1.- Verificar que el ID del proveedor exista
        IF EXISTS (SELECT 1 FROM proveedores WHERE id_proveedor = @id_proveedor)
        BEGIN
            --2.- Obtener el mayor id_entrega y sumarle 1 para generar el siguiente ID
            SELECT @id_entrega = ISNULL(MAX(id_entrega), 0) + 1 FROM entregas;

            -- Insertar la nueva entrega
            INSERT INTO entregas (id_entrega, dia_entrega, mes_entrega, anio_entrega, hora, id_proveedor)
            VALUES 
            (@id_entrega, DAY(GETDATE()), MONTH(GETDATE()), YEAR(GETDATE()), CONVERT(TIME, GETDATE()), @id_proveedor);

            -- Confirmar la transacción
            COMMIT TRANSACTION;

            -- Retornar el ID de la entrega recién insertada
            RETURN @id_entrega;
        END
        ELSE
        BEGIN
            -- Si no se encuentra el proveedor, hacer rollback y devolver un código de error
            PRINT 'El proveedor con ID ' + CAST(@id_proveedor AS VARCHAR) + ' no existe.';
            ROLLBACK TRANSACTION;
            RETURN -1;  -- Código de error cuando el proveedor no existe
        END
    END TRY
    BEGIN CATCH
        -- Manejo de errores y rollback en caso de excepción
        ROLLBACK TRANSACTION;

        -- Capturar el mensaje de error detallado
        PRINT 'Error en el procedimiento: ' + ERROR_MESSAGE();

        -- Retornar un valor de error genérico en caso de excepción
        RETURN -99;  -- Código de error genérico
    END CATCH
END;

--------------------------------------------------------------------
DECLARE @id_entrega INT;

-- Llamada al procedimiento
EXEC @id_entrega = sp_Crear_Entrega @id_proveedor = 10;

-- Mostrar el resultado
IF @id_entrega > 0
    PRINT 'El ID de la entrega es: ' + CAST(@id_entrega AS VARCHAR);
ELSE
    PRINT 'Error al crear la entrega. Código de error: ' + CAST(@id_entrega AS VARCHAR);

--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_Añadir_Recursos_Entrega
    @id_recurso INT,
    @id_entrega INT,
    @descripcion NVARCHAR(255),
    @fecha_caducidad DATE,
    @costo DECIMAL(10, 2),
    @cantidad INT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Verificar si el recurso existe
        IF EXISTS (SELECT 1 FROM recursos WHERE id_recurso = @id_recurso)
        BEGIN
            -- Verificar si la entrega existe
            IF EXISTS (SELECT 1 FROM entregas WHERE id_entrega = @id_entrega)
            BEGIN
                -- Insertar el recurso en la entrega
                INSERT INTO recursos_entregas (id_recurso, id_entrega, descripcion, fecha_caducidad, costo, cantidad)
                VALUES (@id_recurso, @id_entrega, @descripcion, @fecha_caducidad, @costo, @cantidad);

                -- Actualizar la cantidad en el recurso
                UPDATE recursos
                SET cantidad_existente = cantidad_existente + @cantidad
                WHERE id_recurso = @id_recurso;

                -- Confirmar la transacción
                COMMIT TRANSACTION;

                PRINT 'Recurso añadido correctamente a la entrega.';
            END
            ELSE
            BEGIN
                -- Si la entrega no existe
                ROLLBACK TRANSACTION;
                PRINT 'La entrega no existe.';
            END
        END
        ELSE
        BEGIN
            -- Si el recurso no existe
            ROLLBACK TRANSACTION;
            PRINT 'El recurso no existe.';
        END
    END TRY
    BEGIN CATCH
        -- Manejo de errores y rollback en caso de excepción
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- Imprimir el mensaje de error
        PRINT 'Error en el procedimiento: ' + ERROR_MESSAGE();
    END CATCH
END;


----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
-- COMPROBACIÓN DEL MÉTODO sp_Añadir_Recursos_Entrega

-- Llamada al procedimiento almacenado para añadir un recurso a la entrega
EXEC sp_Añadir_Recursos_Entrega
    @id_recurso = 5,          -- ID del recurso
    @id_entrega = 10,         -- ID de la entrega
    @descripcion = 'Café en grano',  -- Descripción del recurso
    @fecha_caducidad = '2025-12-31', -- Fecha de caducidad
    @costo = 500.00,          -- Costo del recurso
    @cantidad = 100;          -- Cantidad del recurso

-- Como el procedimiento ya no devuelve valores, los mensajes de éxito o error serán impresos directamente por el procedimiento.
-- No se requiere lógica adicional para verificar el resultado.
SELECT * FROM recursos_Entregas where id_entrega = 10