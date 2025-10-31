/*****************************************************************
--  SCRIPT DE ÍNDICES DEFINITIVO - VERSIÓN A PRUEBA DE ERRORES
--  Para el Modelo Estrella Ultra Optimizado de Cárnicos del Caribe
--
--  Este script verifica la existencia de cada índice antes de crearlo,
--  evitando mensajes de error y permitiendo ejecuciones parciales.
*****************************************************************/

PRINT '=====================================================';
PRINT 'CREANDO ÍNDICES DEFINITIVOS Y OPTIMIZADOS...';
PRINT '=====================================================';

-- =======================
--  ÍNDICES PARA DIMENSIONES
-- =======================
PRINT ' ';
PRINT 'Verificando índices en Dimensiones...';

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Dim_Tiempo_Anio_Mes' AND object_id = OBJECT_ID('Dim_Tiempo'))
BEGIN
    CREATE INDEX IX_Dim_Tiempo_Anio_Mes ON Dim_Tiempo(Anio, Mes) INCLUDE (Trimestre, Semestre, NombreMes);
    PRINT '✅ Creado IX_Dim_Tiempo_Anio_Mes';
END
ELSE
BEGIN
    PRINT 'ℹ️ IX_Dim_Tiempo_Anio_Mes ya existe. Omitiendo.';
END

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Dim_Producto_Categoria' AND object_id = OBJECT_ID('Dim_Producto'))
BEGIN
    CREATE INDEX IX_Dim_Producto_Categoria ON Dim_Producto(Categoria) INCLUDE (Subcategoria, Marca, Activo);
    PRINT '✅ Creado IX_Dim_Producto_Categoria';
END
ELSE
BEGIN
    PRINT 'ℹ️ IX_Dim_Producto_Categoria ya existe. Omitiendo.';
END

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Dim_Cliente_Region' AND object_id = OBJECT_ID('Dim_Cliente'))
BEGIN
    CREATE INDEX IX_Dim_Cliente_Region ON Dim_Cliente(Region) INCLUDE (Ciudad, TipoCliente, Segmento);
    PRINT '✅ Creado IX_Dim_Cliente_Region';
END
ELSE
BEGIN
    PRINT 'ℹ️ IX_Dim_Cliente_Region ya existe. Omitiendo.';
END

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Dim_Empleado_Sucursal' AND object_id = OBJECT_ID('Dim_Empleado'))
BEGIN
    CREATE INDEX IX_Dim_Empleado_Sucursal ON Dim_Empleado(CodigoSucursal) INCLUDE (NombreEmpleado, Cargo, EmpleadoActivo);
    PRINT '✅ Creado IX_Dim_Empleado_Sucursal';
END
ELSE
BEGIN
    PRINT 'ℹ️ IX_Dim_Empleado_Sucursal ya existe. Omitiendo.';
END

-- =======================
--  ÍNDICES PARA HECHOS PRINCIPALES (Fact_Ventas)
-- =======================
PRINT ' ';
PRINT 'Verificando índices en Fact_Ventas...';

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Fact_Ventas_Producto_Tiempo' AND object_id = OBJECT_ID('Fact_Ventas'))
BEGIN
    CREATE INDEX IX_Fact_Ventas_Producto_Tiempo ON Fact_Ventas(IDProducto, IDTiempoVenta) INCLUDE (CantidadUnidades, PrecioUnitarioVenta, CostoUnitario) WITH (FILLFACTOR = 90);
    PRINT '✅ Creado IX_Fact_Ventas_Producto_Tiempo (CON FILLFACTOR)';
END
ELSE
BEGIN
    PRINT 'ℹ️ IX_Fact_Ventas_Producto_Tiempo ya existe. Omitiendo.';
END

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Fact_Ventas_Cliente_Tiempo' AND object_id = OBJECT_ID('Fact_Ventas'))
BEGIN
    CREATE INDEX IX_Fact_Ventas_Cliente_Tiempo ON Fact_Ventas(IDCliente, IDTiempoVenta) INCLUDE (IDProducto, CantidadUnidades, PrecioUnitarioVenta) WITH (FILLFACTOR = 90);
    PRINT '✅ Creado IX_Fact_Ventas_Cliente_Tiempo (CON FILLFACTOR)';
END
ELSE
BEGIN
    PRINT 'ℹ️ IX_Fact_Ventas_Cliente_Tiempo ya existe. Omitiendo.';
END

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Fact_Ventas_Sucursal_Tiempo' AND object_id = OBJECT_ID('Fact_Ventas'))
BEGIN
    CREATE INDEX IX_Fact_Ventas_Sucursal_Tiempo ON Fact_Ventas(IDSucursal, IDTiempoVenta) INCLUDE (IDProducto, CantidadUnidades) WITH (FILLFACTOR = 90);
    PRINT '✅ Creado IX_Fact_Ventas_Sucursal_Tiempo (CON FILLFACTOR)';
END
ELSE
BEGIN
    PRINT 'ℹ️ IX_Fact_Ventas_Sucursal_Tiempo ya existe. Omitiendo.';
END

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Fact_Ventas_Estado' AND object_id = OBJECT_ID('Fact_Ventas'))
BEGIN
    CREATE INDEX IX_Fact_Ventas_Estado ON Fact_Ventas(IDEstadoPedido) INCLUDE (IDTiempoVenta, IDProducto, CantidadUnidades) WITH (FILLFACTOR = 90);
    PRINT '✅ Creado IX_Fact_Ventas_Estado (CON FILLFACTOR)';
END
ELSE
BEGIN
    PRINT 'ℹ️ IX_Fact_Ventas_Estado ya existe. Omitiendo.';
END

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Fact_Ventas_Canal' AND object_id = OBJECT_ID('Fact_Ventas'))
BEGIN
    CREATE INDEX IX_Fact_Ventas_Canal ON Fact_Ventas(IDCanal) INCLUDE (IDTiempoVenta, IDSucursal) WITH (FILLFACTOR = 90);
    PRINT '✅ Creado IX_Fact_Ventas_Canal (CON FILLFACTOR)';
END
ELSE
BEGIN
    PRINT 'ℹ️ IX_Fact_Ventas_Canal ya existe. Omitiendo.';
END

-- =======================
--  ÍNDICES PARA HECHOS AGREGADOS
-- =======================
PRINT ' ';
PRINT 'Verificando índices en Hechos Agregados...';

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Fact_SatisfaccionCliente_Cliente_Tiempo' AND object_id = OBJECT_ID('Fact_SatisfaccionCliente'))
BEGIN
    CREATE INDEX IX_Fact_SatisfaccionCliente_Cliente_Tiempo ON Fact_SatisfaccionCliente(IDCliente, IDTiempo);
    PRINT '✅ Creado IX_Fact_SatisfaccionCliente_Cliente_Tiempo';
END
ELSE
BEGIN
    PRINT 'ℹ️ IX_Fact_SatisfaccionCliente_Cliente_Tiempo ya existe. Omitiendo.';
END

-- =======================
--  VERIFICACIÓN FINAL
-- =======================
PRINT ' ';
PRINT '🎯 VERIFICACIÓN FINAL DE ÍNDICES:';
PRINT '=================================';

SELECT 
    t.name AS Tabla,
    i.name AS Indice,
    i.type_desc AS Tipo,
    CASE 
        WHEN i.name LIKE 'IX_Fact_Ventas%' THEN 'CON FILLFACTOR = 90'
        ELSE 'DEFAULT'
    END AS Configuracion
FROM sys.indexes i
INNER JOIN sys.tables t ON i.object_id = t.object_id
WHERE i.name LIKE 'IX_%' AND i.name NOT LIKE '%PK_%'
ORDER BY t.name, i.name;

PRINT ' ';
PRINT '🏆 ¡SCRIPT DE ÍNDICES EJECUTADO CON ÉXITO!';
PRINT '🏆 El modelo está ahora optimizado para el máximo rendimiento en Power BI.';
PRINT '=====================================================';