/*****************************************************************
--  VALIDACIÓN DE DATOS - DATA WAREHOUSE CÁRNICOS DEL CARIBE
--  Objetivo: Validar volumen, distribución y consistencia básica
--  Esquema: Modelo Estrella Ultra Optimizado
--  Fecha: $(Get-Date -Format "yyyy-MM-dd")
--  Nota: Ejecutar después del poblamiento completo
*****************************************************************/

PRINT '=====================================================';
PRINT 'VALIDACIÓN COMPLETA - DATA WAREHOUSE CÁRNICOS CARIBE';
PRINT '=====================================================';
PRINT '';

-- =========================================================
-- 1️⃣ VALIDACIÓN DE VOLUMEN DE DATOS POR TABLA
-- =========================================================
PRINT '=== 1. VALIDACIÓN DE VOLUMEN DE DATOS ===';

SELECT 
    'Dim_Tiempo' AS Tabla, COUNT(*) AS Registros FROM Dim_Tiempo
UNION ALL SELECT 'Dim_Producto', COUNT(*) FROM Dim_Producto
UNION ALL SELECT 'Dim_Cliente', COUNT(*) FROM Dim_Cliente
UNION ALL SELECT 'Dim_Sucursal', COUNT(*) FROM Dim_Sucursal
UNION ALL SELECT 'Dim_Empleado', COUNT(*) FROM Dim_Empleado
UNION ALL SELECT 'Dim_CanalVenta', COUNT(*) FROM Dim_CanalVenta
UNION ALL SELECT 'Dim_EstadoPedido', COUNT(*) FROM Dim_EstadoPedido
UNION ALL SELECT 'Fact_Ventas', COUNT(*) FROM Fact_Ventas
UNION ALL SELECT 'Fact_Finanzas', COUNT(*) FROM Fact_Finanzas
UNION ALL SELECT 'Fact_SatisfaccionCliente', COUNT(*) FROM Fact_SatisfaccionCliente
UNION ALL SELECT 'Fact_MetricasWeb', COUNT(*) FROM Fact_MetricasWeb
ORDER BY Registros DESC;

PRINT '';

-- =========================================================
-- 2️⃣ VALIDACIÓN DE DIMENSIONES TEMPORALES
-- =========================================================
PRINT '=== 2. VALIDACIÓN DIMENSIONES TEMPORALES ===';

-- Rango de fechas en Dim_Tiempo
PRINT '-- Rango de fechas en Dim_Tiempo:';
SELECT 
    MIN(Fecha) AS Fecha_Minima,
    MAX(Fecha) AS Fecha_Maxima,
    DATEDIFF(day, MIN(Fecha), MAX(Fecha)) AS Dias_Totales,
    COUNT(DISTINCT Anio) AS Total_Anios,
    COUNT(DISTINCT Mes) AS Total_Meses
FROM Dim_Tiempo;

-- Distribución por año y mes
PRINT '-- Distribución por año y mes:';
SELECT 
    Anio,
    COUNT(*) AS Dias,
    COUNT(DISTINCT Mes) AS Meses_Con_Datos
FROM Dim_Tiempo
GROUP BY Anio
ORDER BY Anio;

PRINT '';

-- =========================================================
-- 3️⃣ VALIDACIÓN DE DIMENSIONES DE NEGOCIO
-- =========================================================
PRINT '=== 3. VALIDACIÓN DIMENSIONES DE NEGOCIO ===';

-- Distribución de productos por categoría
PRINT '-- Productos por categoría y estado:';
SELECT 
    Categoria,
    Subcategoria,
    COUNT(*) AS Total_Productos,
    SUM(CASE WHEN Activo = 1 THEN 1 ELSE 0 END) AS Productos_Activos,
    SUM(CASE WHEN Activo = 0 THEN 1 ELSE 0 END) AS Productos_Inactivos
FROM Dim_Producto
GROUP BY Categoria, Subcategoria
ORDER BY Total_Productos DESC;

-- Distribución de clientes por segmento y región
PRINT '-- Clientes por segmento y región:';
SELECT 
    Segmento,
    Region,
    TipoCliente,
    COUNT(*) AS Total_Clientes,
    SUM(CASE WHEN ClienteActivo = 1 THEN 1 ELSE 0 END) AS Clientes_Activos
FROM Dim_Cliente
GROUP BY Segmento, Region, TipoCliente
ORDER BY Total_Clientes DESC;

-- Sucursales por ciudad y tipo
PRINT '-- Sucursales por ciudad y tipo:';
SELECT 
    Ciudad,
    TipoSucursal,
    COUNT(*) AS Total_Sucursales,
    SUM(CASE WHEN SucursalActiva = 1 THEN 1 ELSE 0 END) AS Sucursales_Activas
FROM Dim_Sucursal
GROUP BY Ciudad, TipoSucursal
ORDER BY Total_Sucursales DESC;

-- Empleados por sucursal y departamento
PRINT '-- Empleados por sucursal y departamento:';
SELECT 
    ds.NombreSucursal,
    de.Departamento,
    de.Cargo,
    COUNT(*) AS Total_Empleados,
    SUM(CASE WHEN de.EmpleadoActivo = 1 THEN 1 ELSE 0 END) AS Empleados_Activos
FROM Dim_Empleado de
JOIN Dim_Sucursal ds ON de.IDSucursal = ds.IDSucursal
GROUP BY ds.NombreSucursal, de.Departamento, de.Cargo
ORDER BY Total_Empleados DESC;

PRINT '';

-- =========================================================
-- 4️⃣ VALIDACIÓN DE FACT_VENTAS - DISTRIBUCIÓN Y COHERENCIA
-- =========================================================
PRINT '=== 4. VALIDACIÓN FACT_VENTAS ===';

-- Distribución temporal de ventas
PRINT '-- Ventas por año y mes:';
SELECT 
    dt.Anio,
    dt.Mes,
    dt.NombreMes,
    COUNT(*) AS Total_Ventas,
    SUM(fv.CantidadUnidades) AS Total_Unidades,
    SUM(fv.PrecioUnitarioVenta * fv.CantidadUnidades - fv.DescuentoUnitario) AS Ventas_Netas,
    AVG(fv.PrecioUnitarioVenta) AS Precio_Promedio
FROM Fact_Ventas fv
JOIN Dim_Tiempo dt ON fv.IDTiempoVenta = dt.IDTiempo
GROUP BY dt.Anio, dt.Mes, dt.NombreMes
ORDER BY dt.Anio, dt.Mes;

-- Ventas por categoría de producto
PRINT '-- Ventas por categoría de producto:';
SELECT 
    dp.Categoria,
    COUNT(*) AS Total_Ventas,
    SUM(fv.CantidadUnidades) AS Total_Unidades,
    SUM(fv.PrecioUnitarioVenta * fv.CantidadUnidades - fv.DescuentoUnitario) AS Ventas_Netas,
    SUM(fv.CostoUnitario * fv.CantidadUnidades) AS Costo_Total,
    (SUM(fv.PrecioUnitarioVenta * fv.CantidadUnidades - fv.DescuentoUnitario) - 
     SUM(fv.CostoUnitario * fv.CantidadUnidades)) AS Utilidad_Bruta
FROM Fact_Ventas fv
JOIN Dim_Producto dp ON fv.IDProducto = dp.IDProducto
GROUP BY dp.Categoria
ORDER BY Ventas_Netas DESC;

-- Ventas por canal
PRINT '-- Ventas por canal:';
SELECT 
    dc.NombreCanal,
    dc.TipoCanal,
    COUNT(*) AS Total_Ventas,
    SUM(fv.CantidadUnidades) AS Total_Unidades,
    SUM(fv.PrecioUnitarioVenta * fv.CantidadUnidades - fv.DescuentoUnitario) AS Ventas_Netas
FROM Fact_Ventas fv
JOIN Dim_CanalVenta dc ON fv.IDCanal = dc.IDCanal
GROUP BY dc.NombreCanal, dc.TipoCanal
ORDER BY Ventas_Netas DESC;

-- Ventas por estado de pedido
PRINT '-- Ventas por estado de pedido:';
SELECT 
    de.DescripcionEstado,
    COUNT(*) AS Total_Ventas,
    SUM(fv.CantidadUnidades) AS Total_Unidades,
    SUM(fv.PrecioUnitarioVenta * fv.CantidadUnidades - fv.DescuentoUnitario) AS Ventas_Netas
FROM Fact_Ventas fv
JOIN Dim_EstadoPedido de ON fv.IDEstadoPedido = de.IDEstado
GROUP BY de.DescripcionEstado
ORDER BY Total_Ventas DESC;

PRINT '';

-- =========================================================
-- 5️⃣ VALIDACIÓN DE COHERENCIA TEMPORAL EN VENTAS
-- =========================================================
PRINT '=== 5. VALIDACIÓN COHERENCIA TEMPORAL ===';

-- Validar que fecha de entrega no sea anterior a fecha de pedido
PRINT '-- Validación fechas pedido vs entrega:';
SELECT 
    COUNT(*) AS Total_Registros,
    SUM(CASE WHEN dt_entrega.Fecha < dt_pedido.Fecha THEN 1 ELSE 0 END) AS Entregas_Antes_Pedido,
    SUM(CASE WHEN dt_entrega.Fecha IS NULL THEN 1 ELSE 0 END) AS Sin_Fecha_Entrega
FROM Fact_Ventas fv
JOIN Dim_Tiempo dt_pedido ON fv.IDTiempoPedido = dt_pedido.IDTiempo
LEFT JOIN Dim_Tiempo dt_entrega ON fv.IDTiempoEntrega = dt_entrega.IDTiempo;

-- Tiempo promedio entre pedido y entrega
PRINT '-- Tiempo promedio entre pedido y entrega:';
SELECT 
    AVG(DATEDIFF(day, dt_pedido.Fecha, dt_entrega.Fecha)) AS Dias_Promedio_Entrega,
    MIN(DATEDIFF(day, dt_pedido.Fecha, dt_entrega.Fecha)) AS Min_Dias_Entrega,
    MAX(DATEDIFF(day, dt_pedido.Fecha, dt_entrega.Fecha)) AS Max_Dias_Entrega
FROM Fact_Ventas fv
JOIN Dim_Tiempo dt_pedido ON fv.IDTiempoPedido = dt_pedido.IDTiempo
JOIN Dim_Tiempo dt_entrega ON fv.IDTiempoEntrega = dt_entrega.IDTiempo
WHERE dt_entrega.Fecha IS NOT NULL;

PRINT '';

-- =========================================================
-- 6️⃣ VALIDACIÓN DE FACT_FINANZAS
-- =========================================================
PRINT '=== 6. VALIDACIÓN FACT_FINANZAS ===';

-- Resumen financiero por año y mes
PRINT '-- Resumen financiero por año y mes:';
SELECT 
    dt.Anio,
    dt.Mes,
    COUNT(*) AS Total_Registros,
    SUM(ff.VentasTotales) AS Ventas_Totales,
    SUM(ff.CostosTotales) AS Costos_Totales,
    SUM(ff.UtilidadBruta) AS Utilidad_Bruta,
    AVG(ff.MargenBrutoPorcentaje) AS Margen_Promedio
FROM Fact_Finanzas ff
JOIN Dim_Tiempo dt ON ff.IDTiempo = dt.IDTiempo
GROUP BY dt.Anio, dt.Mes
ORDER BY dt.Anio, dt.Mes;

-- Finanzas por sucursal
PRINT '-- Finanzas por sucursal:';
SELECT 
    ds.NombreSucursal,
    ds.Ciudad,
    COUNT(*) AS Total_Meses,
    AVG(ff.VentasTotales) AS Ventas_Promedio_Mensual,
    AVG(ff.UtilidadNeta) AS Utilidad_Promedio_Mensual,
    AVG(ff.MargenBrutoPorcentaje) AS Margen_Promedio
FROM Fact_Finanzas ff
JOIN Dim_Sucursal ds ON ff.IDSucursal = ds.IDSucursal
GROUP BY ds.NombreSucursal, ds.Ciudad
ORDER BY Ventas_Promedio_Mensual DESC;

PRINT '';

-- =========================================================
-- 7️⃣ VALIDACIÓN DE FACT_SATISFACCIONCLIENTE
-- =========================================================
PRINT '=== 7. VALIDACIÓN FACT_SATISFACCIONCLIENTE ===';

-- Distribución de puntuaciones
PRINT '-- Distribución de puntuaciones:';
SELECT 
    PuntuacionServicio,
    PuntuacionProducto,
    PuntuacionGeneral,
    COUNT(*) AS Total_Encuestas,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) AS Porcentaje
FROM Fact_SatisfaccionCliente
GROUP BY PuntuacionServicio, PuntuacionProducto, PuntuacionGeneral
ORDER BY PuntuacionGeneral DESC, Total_Encuestas DESC;

-- Satisfacción por sucursal
PRINT '-- Satisfacción por sucursal:';
SELECT 
    ds.NombreSucursal,
    COUNT(*) AS Total_Encuestas,
    AVG(fsc.PuntuacionServicio * 1.0) AS Servicio_Promedio,
    AVG(fsc.PuntuacionProducto * 1.0) AS Producto_Promedio,
    AVG(fsc.PuntuacionGeneral * 1.0) AS General_Promedio,
    CAST(100.0 * SUM(CASE WHEN fsc.Recomendaria = 1 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS Porcentaje_Recomienda
FROM Fact_SatisfaccionCliente fsc
JOIN Dim_Sucursal ds ON fsc.IDSucursal = ds.IDSucursal
GROUP BY ds.NombreSucursal
ORDER BY General_Promedio DESC;

PRINT '';

-- =========================================================
-- 8️⃣ VALIDACIÓN DE FACT_METRICASWEB
-- =========================================================
PRINT '=== 8. VALIDACIÓN FACT_METRICASWEB ===';

-- Métricas web por canal y mes
PRINT '-- Métricas web por canal y mes:';
SELECT 
    dc.NombreCanal,
    dt.Anio,
    dt.Mes,
    COUNT(*) AS Total_Registros,
    SUM(fmw.SesionesTotales) AS Sesiones_Totales,
    SUM(fmw.UsuariosUnicos) AS Usuarios_Unicos,
    SUM(fmw.Conversiones) AS Conversiones_Total,
    CAST(100.0 * SUM(fmw.Conversiones) / SUM(fmw.SesionesTotales) AS DECIMAL(5,2)) AS Tasa_Conversion,
    SUM(fmw.IngresosDigitales) AS Ingresos_Digitales
FROM Fact_MetricasWeb fmw
JOIN Dim_CanalVenta dc ON fmw.IDCanal = dc.IDCanal
JOIN Dim_Tiempo dt ON fmw.IDTiempo = dt.IDTiempo
GROUP BY dc.NombreCanal, dt.Anio, dt.Mes
ORDER BY dc.NombreCanal, dt.Anio, dt.Mes;

-- Tendencias de conversión
PRINT '-- Tendencias de conversión por canal:';
SELECT 
    dc.NombreCanal,
    AVG(CAST(fmw.Conversiones AS FLOAT) / NULLIF(fmw.SesionesTotales, 0)) * 100 AS Tasa_Conversion_Promedio,
    MIN(CAST(fmw.Conversiones AS FLOAT) / NULLIF(fmw.SesionesTotales, 0)) * 100 AS Tasa_Conversion_Min,
    MAX(CAST(fmw.Conversiones AS FLOAT) / NULLIF(fmw.SesionesTotales, 0)) * 100 AS Tasa_Conversion_Max
FROM Fact_MetricasWeb fmw
JOIN Dim_CanalVenta dc ON fmw.IDCanal = dc.IDCanal
GROUP BY dc.NombreCanal
ORDER BY Tasa_Conversion_Promedio DESC;

PRINT '';

-- =========================================================
-- 9️⃣ VALIDACIÓN DE INTEGRIDAD REFERENCIAL
-- =========================================================
PRINT '=== 9. VALIDACIÓN INTEGRIDAD REFERENCIAL ===';

-- Verificar claves foráneas huérfanas en Fact_Ventas
PRINT '-- Claves foráneas huérfanas en Fact_Ventas:';
SELECT 
    'Producto' AS Tipo, COUNT(*) AS Huérfanos
FROM Fact_Ventas fv
LEFT JOIN Dim_Producto dp ON fv.IDProducto = dp.IDProducto
WHERE dp.IDProducto IS NULL
UNION ALL
SELECT 'Cliente', COUNT(*)
FROM Fact_Ventas fv
LEFT JOIN Dim_Cliente dc ON fv.IDCliente = dc.IDCliente
WHERE dc.IDCliente IS NULL
UNION ALL
SELECT 'Sucursal', COUNT(*)
FROM Fact_Ventas fv
LEFT JOIN Dim_Sucursal ds ON fv.IDSucursal = ds.IDSucursal
WHERE ds.IDSucursal IS NULL
UNION ALL
SELECT 'Empleado', COUNT(*)
FROM Fact_Ventas fv
LEFT JOIN Dim_Empleado de ON fv.IDEmpleado = de.IDEmpleado
WHERE de.IDEmpleado IS NULL
UNION ALL
SELECT 'Canal', COUNT(*)
FROM Fact_Ventas fv
LEFT JOIN Dim_CanalVenta dc ON fv.IDCanal = dc.IDCanal
WHERE dc.IDCanal IS NULL
UNION ALL
SELECT 'Estado', COUNT(*)
FROM Fact_Ventas fv
LEFT JOIN Dim_EstadoPedido de ON fv.IDEstadoPedido = de.IDEstado
WHERE de.IDEstado IS NULL;

-- Verificar duplicados en dimensiones
PRINT '-- Verificación de duplicados en dimensiones:';
SELECT 
    'Dim_Producto' AS Tabla, COUNT(*) AS Total, COUNT(DISTINCT SKU) AS SKU_Unicos
FROM Dim_Producto
UNION ALL
SELECT 'Dim_Cliente', COUNT(*), COUNT(DISTINCT CodigoCliente)
FROM Dim_Cliente
UNION ALL
SELECT 'Dim_Sucursal', COUNT(*), COUNT(DISTINCT CodigoSucursal)
FROM Dim_Sucursal
UNION ALL
SELECT 'Dim_Empleado', COUNT(*), COUNT(DISTINCT CodigoEmpleado)
FROM Dim_Empleado;

PRINT '';

-- =========================================================
-- 🔟 VALIDACIÓN DE CALIDAD DE DATOS
-- =========================================================
PRINT '=== 10. VALIDACIÓN CALIDAD DE DATOS ===';

-- Validar rangos de precios y cantidades
PRINT '-- Validación de rangos en Fact_Ventas:';
SELECT 
    MIN(PrecioUnitarioVenta) AS Precio_Minimo,
    MAX(PrecioUnitarioVenta) AS Precio_Maximo,
    AVG(PrecioUnitarioVenta) AS Precio_Promedio,
    MIN(CostoUnitario) AS Costo_Minimo,
    MAX(CostoUnitario) AS Costo_Maximo,
    AVG(CostoUnitario) AS Costo_Promedio,
    MIN(CantidadUnidades) AS Cantidad_Minima,
    MAX(CantidadUnidades) AS Cantidad_Maxima,
    AVG(CantidadUnidades) AS Cantidad_Promedio
FROM Fact_Ventas;

-- Validar que no hay precios o costos negativos
PRINT '-- Registros con valores negativos:';
SELECT 
    COUNT(*) AS Total_Registros,
    SUM(CASE WHEN PrecioUnitarioVenta < 0 THEN 1 ELSE 0 END) AS Precios_Negativos,
    SUM(CASE WHEN CostoUnitario < 0 THEN 1 ELSE 0 END) AS Costos_Negativos,
    SUM(CASE WHEN CantidadUnidades < 0 THEN 1 ELSE 0 END) AS Cantidades_Negativas
FROM Fact_Ventas;

-- Validar consistencia en descuentos
PRINT '-- Validación de descuentos:';
SELECT 
    COUNT(*) AS Total_Registros,
    SUM(CASE WHEN DescuentoUnitario > PrecioUnitarioVenta THEN 1 ELSE 0 END) AS Descuentos_Excesivos,
    SUM(CASE WHEN DescuentoUnitario < 0 THEN 1 ELSE 0 END) AS Descuentos_Negativos
FROM Fact_Ventas;

PRINT '';

-- =========================================================
-- 🎯 RESUMEN EJECUTIVO DE VALIDACIÓN
-- =========================================================
PRINT '=== RESUMEN EJECUTIVO DE VALIDACIÓN ===';

-- Resumen general de calidad
SELECT 
    'TOTAL_REGISTROS' AS Metric,
    (SELECT COUNT(*) FROM Dim_Tiempo) +
    (SELECT COUNT(*) FROM Dim_Producto) +
    (SELECT COUNT(*) FROM Dim_Cliente) +
    (SELECT COUNT(*) FROM Dim_Sucursal) +
    (SELECT COUNT(*) FROM Dim_Empleado) +
    (SELECT COUNT(*) FROM Fact_Ventas) +
    (SELECT COUNT(*) FROM Fact_Finanzas) +
    (SELECT COUNT(*) FROM Fact_SatisfaccionCliente) +
    (SELECT COUNT(*) FROM Fact_MetricasWeb) AS Valor

UNION ALL
SELECT 'TABLAS_CON_DATOS', 
    (SELECT COUNT(*) FROM (VALUES 
        (SELECT COUNT(*) FROM Dim_Tiempo),
        (SELECT COUNT(*) FROM Dim_Producto),
        (SELECT COUNT(*) FROM Dim_Cliente),
        (SELECT COUNT(*) FROM Dim_Sucursal),
        (SELECT COUNT(*) FROM Dim_Empleado),
        (SELECT COUNT(*) FROM Fact_Ventas),
        (SELECT COUNT(*) FROM Fact_Finanzas),
        (SELECT COUNT(*) FROM Fact_SatisfaccionCliente),
        (SELECT COUNT(*) FROM Fact_MetricasWeb)
    ) AS t(contador) WHERE contador > 0)

UNION ALL
SELECT 'VENTAS_TOTALES', (SELECT SUM(PrecioUnitarioVenta * CantidadUnidades - DescuentoUnitario) FROM Fact_Ventas)

UNION ALL
SELECT 'CLIENTES_ACTIVOS', (SELECT COUNT(*) FROM Dim_Cliente WHERE ClienteActivo = 1)

UNION ALL
SELECT 'PRODUCTOS_ACTIVOS', (SELECT COUNT(*) FROM Dim_Producto WHERE Activo = 1)

UNION ALL
SELECT 'EMPLEADOS_ACTIVOS', (SELECT COUNT(*) FROM Dim_Empleado WHERE EmpleadoActivo = 1)

UNION ALL
SELECT 'SUCURSALES_ACTIVAS', (SELECT COUNT(*) FROM Dim_Sucursal WHERE SucursalActiva = 1);

PRINT '';
PRINT '=====================================================';
PRINT '✅ VALIDACIÓN COMPLETADA EXITOSAMENTE';
PRINT '📊 Revisar resultados arriba para identificar posibles issues';
PRINT '🎯 Data Warehouse listo para análisis y reporting';
PRINT '=====================================================';