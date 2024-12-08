
Use alma_de_cafe;
-------------------------------------------------------------------

CREATE OR ALTER PROCEDURE sp_Crear_Pedido
    @id_empleado INT,
    @id_mesa INT,
	@descuento INT
AS
BEGIN
    DECLARE @id_pedido INT;

    -- Iniciar la transacción
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Verificar si el empleado existe
        IF EXISTS (SELECT 1 FROM empleados WHERE id_empleado = @id_empleado)
        BEGIN
            -- Verificar si el empleado es mesero (único que puede hacer pedidos)
            IF EXISTS (
                SELECT 1 
                FROM empleados e 
                INNER JOIN puestos p ON p.id_puesto = e.id_puesto 
                WHERE e.id_empleado = @id_empleado 
                  AND p.nombre_puesto = 'Mesero'
            )
            BEGIN
                -- Verificar si la mesa existe
                IF EXISTS (SELECT 1 FROM mesas WHERE id_mesa = @id_mesa)
                BEGIN
                    -- Verificar que la mesa no esté ocupada (bloqueo optimista con transacción)
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
                        -- Insertar el nuevo pedido
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
--Comprobar que el procedimiento anterior 
DECLARE @id_pedido INT;

-- Llamada al procedimiento
EXEC @id_pedido = sp_Crear_Pedido @id_empleado = 6, @id_mesa = 18,@descuento = 10;

-- Mostrar el resultado
IF @id_pedido > 0
    PRINT 'El ID del pedido es: ' + CAST(@id_pedido AS VARCHAR);
ELSE
    PRINT 'Error al crear el pedido. Código de error: ' + CAST(@id_pedido AS VARCHAR);
-------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------
--MODIFICAR EL PEDIDO
CREATE OR ALTER PROCEDURE sp_Modificar_Total_Subtotal_Pedido
    @id_pedido INT,
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

        -- Verificar si el pedido existe
        IF EXISTS (SELECT 1 FROM pedidos WHERE id_pedido = @id_pedido)
        BEGIN
            -- Obtener el descuento actual
            SELECT @descuento = descuento
            FROM pedidos
            WHERE id_pedido = @id_pedido;

            -- Modificar el subtotal según el tipo
            IF @tipo = 'AGREGAR'
            BEGIN
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

            -- Recalcular el total después de modificar el subtotal
            SELECT @subtotal = subtotal
            FROM pedidos
            WHERE id_pedido = @id_pedido;

            SET @total = (@subtotal + (@subtotal * @impuesto)) - (@subtotal * (@descuento / 100));

            UPDATE pedidos
            SET total = @total
            WHERE id_pedido = @id_pedido;

            PRINT 'El pedido fue actualizado exitosamente.';
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
select * from pedidos where id_pedido = 49
EXEC sp_Modificar_Total_Subtotal_Pedido @id_pedido = 49,@cantidad =100, @tipo = 'AGREGAR';
---------------------------------------------------------------------------------------------

------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_Agregar_al_Pedido
    @id_pedido INT,
    @id_agregar INT,
    @cantidad INT,
    @tipo VARCHAR(10) -- Se usa VARCHAR en lugar de NVARCHAR si no es necesario
AS
BEGIN
    DECLARE @subtotal DECIMAL(10, 2); -- Declaración de la variable subtotal
    BEGIN TRY
        -- Iniciar la transacción
        BEGIN TRANSACTION;

        -- Verificar si el pedido existe
        IF EXISTS (SELECT 1 FROM pedidos WHERE id_pedido = @id_pedido)
        BEGIN
            -- Verificar si el tipo es 'BEBIDA'
            IF @tipo = 'BEBIDA'
            BEGIN
                IF EXISTS (SELECT 1 FROM bebidas WHERE id_bebida = @id_agregar)
                BEGIN
                    -- Insertar en bebidas_pedidos
                    INSERT INTO bebidas_pedidos (id_bebida, id_pedido, cantidad)
                    VALUES (@id_agregar, @id_pedido, @cantidad);

                    -- Obtener el precio de la bebida y calcular el subtotal
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
            -- Verificar si el tipo es 'POSTRE'
            ELSE IF @tipo = 'POSTRE'
            BEGIN
                IF EXISTS (SELECT 1 FROM postres WHERE id_postre = @id_agregar)
                BEGIN
                    -- Insertar en postres_pedidos
                    INSERT INTO postres_pedidos (id_postre, id_pedido, cantidad)
                    VALUES (@id_agregar, @id_pedido, @cantidad);

                    -- Obtener el precio del postre y calcular el subtotal
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
			--ACTUALIZAR EL TOTAL Y SUBTOTAL 
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
--COMPROBACION DEL PROCEDIMIENTO
select * from bebidas where id_bebida = 1
EXEC sp_Agregar_al_Pedido @id_pedido = 45, @id_agregar = 7, @cantidad = 1, @tipo = 'POSTRE';

SELECT 
    SUM(p.precio_postre * pp.cantidad) +
    SUM(b.precio_bebida * bp.cantidad) AS total
FROM 
    bebidas_pedidos bp
LEFT JOIN postres_pedidos pp ON pp.id_pedido = bp.id_pedido
LEFT JOIN postres p ON p.id_postre = pp.id_postre
LEFT JOIN bebidas b ON b.id_bebida = bp.id_bebida
WHERE 
 pp.id_pedido = 45;
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

        -- Verificar si el pedido existe
        IF EXISTS (SELECT 1 FROM pedidos WHERE id_pedido = @id_pedido)
        BEGIN
            -- Verificar si el tipo es 'BEBIDA'
            IF @tipo = 'BEBIDA'
            BEGIN
                -- Verificar si la bebida está en el pedido
                IF EXISTS (SELECT 1 FROM bebidas_pedidos WHERE id_bebida = @id_eliminar AND id_pedido = @id_pedido)
                BEGIN
                    -- Obtener la cantidad de la bebida
                    SELECT @cantidad = cantidad
                    FROM bebidas_pedidos 
                    WHERE id_bebida = @id_eliminar AND id_pedido = @id_pedido;

                    -- Eliminar la bebida del pedido
                    DELETE FROM bebidas_pedidos
                    WHERE id_bebida = @id_eliminar AND id_pedido = @id_pedido;

                    -- Obtener el precio de la bebida y calcular la cantidad eliminada del subtotal
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
            -- Verificar si el tipo es 'POSTRE'
            ELSE IF @tipo = 'POSTRE'
            BEGIN
                -- Verificar si el postre está en el pedido
                IF EXISTS (SELECT 1 FROM postres_pedidos WHERE id_postre = @id_eliminar AND id_pedido = @id_pedido)
                BEGIN
                    -- Obtener la cantidad del postre
                    SELECT @cantidad = cantidad
                    FROM postres_pedidos 
                    WHERE id_postre = @id_eliminar AND id_pedido = @id_pedido;

                    -- Eliminar el postre del pedido
                    DELETE FROM postres_pedidos
                    WHERE id_postre = @id_eliminar AND id_pedido = @id_pedido;

                    -- Obtener el precio del postre y calcular la cantidad eliminada del subtotal
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

            -- Actualizar el subtotal del pedido, restando lo que se eliminó
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
EXEC sp_Eliminar_del_Pedido @id_pedido = 45, @id_eliminar = 7, @tipo = 'POSTRE';
select * from postres where id_postre = 7
select * from postres_pedidos where id_pedido = 45
select * from pedidos where id_pedido = 45
execute sp_Agregar_al_Pedido 45,7,1,'POSTRE'
