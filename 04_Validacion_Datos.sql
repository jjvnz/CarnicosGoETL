-- ==============================================================
--  VALIDACIÓN DE DATOS - ROL B (Cárnicos del Caribe S.A.S.)
--  Objetivo: Validar volumen, distribución y consistencia básica
--  Creado por: Consultoría Rol B (Ingeniero de Datos)
--  Fecha: GETDATE()
-- ==============================================================

PRINT '=== VALIDACIÓN INICIAL ===';

-- 1️⃣ Conteo total por tabla
SELECT 
    'Dim_Producto' AS Tabla, COUNT(*) AS Registros FROM Dim_Producto
UNION ALL SELECT 'Dim_Cliente', COUNT(*) FROM Dim_Cliente
UNION ALL SELECT 'Dim_Sucursal', COUNT(*) FROM Dim_Sucursal
UNION ALL SELECT 'Dim_Empleado', COUNT(*) FROM Dim_Empleado
UNION ALL SELECT 'Fact_Ventas', COUNT(*) FROM Fact_Ventas
UNION ALL SELECT 'Fact_Pedidos', COUNT(*) FROM Fact_Pedidos
UNION ALL SELECT 'Fact_Finanzas', COUNT(*) FROM Fact_Finanzas
UNION ALL SELECT 'Fact_Encuestas', COUNT(*) FROM Fact_Encuestas
UNION ALL SELECT 'Fact_WebTraffic', COUNT(*) FROM Fact_WebTraffic
ORDER BY Registros DESC;

PRINT '=== VALIDACIÓN DE DISTRIBUCIÓN ===';

-- 2️⃣ Distribución de ventas por año
SELECT 
    YEAR(Fecha) AS Anio, COUNT(*) AS Ventas, 
    SUM(Unidades) AS TotalUnidades, 
    SUM(Precio * Unidades) AS TotalVentas
FROM Fact_Ventas
GROUP BY YEAR(Fecha)
ORDER BY Anio;

-- 3️⃣ Distribución por categoría de producto
SELECT 
    p.Categoria, COUNT(v.IDVenta) AS NumVentas, 
    ROUND(SUM(v.Precio * v.Unidades),2) AS TotalVentas
FROM Fact_Ventas v
JOIN Dim_Producto p ON v.IDProducto = p.IDProducto
GROUP BY p.Categoria
ORDER BY TotalVentas DESC;

-- 4️⃣ Distribución por tipo de cliente
SELECT 
    c.TipoCliente, COUNT(v.IDVenta) AS NumVentas,
    ROUND(SUM(v.Precio * v.Unidades),2) AS TotalVentas,
    ROUND(AVG(v.Precio * v.Unidades),2) AS TicketPromedio
FROM Fact_Ventas v
JOIN Dim_Cliente c ON v.IDCliente = c.IDCliente
GROUP BY c.TipoCliente;

-- 5️⃣ Distribución geográfica
SELECT 
    s.Ciudad, COUNT(v.IDVenta) AS NumVentas,
    SUM(v.Unidades) AS TotalUnidades,
    ROUND(SUM(v.Precio * v.Unidades),2) AS TotalVentas
FROM Fact_Ventas v
JOIN Dim_Sucursal s ON v.IDSucursal = s.IDSucursal
GROUP BY s.Ciudad
ORDER BY TotalVentas DESC;

PRINT '=== VALIDACIÓN DE PEDIDOS Y FINANZAS ===';

-- 6️⃣ Estado de pedidos
SELECT Completo, COUNT(*) AS TotalPedidos
FROM Fact_Pedidos
GROUP BY Completo;

-- 7️⃣ Validar coherencia temporal pedidos (Entrega > Pedido)
SELECT TOP 10 *
FROM Fact_Pedidos
WHERE FechaEntrega < FechaPedido;

-- 8️⃣ Validación de registros financieros
SELECT COUNT(*) AS TotalRegistros, MIN(Periodo) AS PrimerPeriodo, MAX(Periodo) AS UltimoPeriodo,
       SUM(VentasTotales) AS TotalVentasFinanzas
FROM Fact_Finanzas;

PRINT '=== VALIDACIÓN DE KPI NUEVOS (DIGITALES Y NPS) ===';

-- 9️⃣ Distribución de puntuaciones NPS
SELECT 
    Puntuacion, COUNT(*) AS Frecuencia,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) AS Porcentaje
FROM Fact_Encuestas
GROUP BY Puntuacion
ORDER BY Puntuacion;

-- 10️⃣ Distribución de canales digitales
SELECT 
    Canal, COUNT(*) AS Periodos,
    SUM(Sesiones) AS TotalSesiones,
    SUM(Conversiones) AS TotalConversiones,
    ROUND(100.0 * SUM(Conversiones) / NULLIF(SUM(Sesiones),0),2) AS TasaConversionPct
FROM Fact_WebTraffic
GROUP BY Canal
ORDER BY TasaConversionPct DESC;

PRINT '=== VALIDACIÓN FINAL DE INTEGRIDAD ===';

-- 11️⃣ Validar que claves foráneas referencian correctamente
SELECT TOP 10 v.*
FROM Fact_Ventas v
LEFT JOIN Dim_Cliente c ON v.IDCliente = c.IDCliente
WHERE c.IDCliente IS NULL;

-- 12️⃣ Validar que no hay duplicados de producto
SELECT Nombre, COUNT(*) AS Repeticiones
FROM Dim_Producto
GROUP BY Nombre
HAVING COUNT(*) > 1;

PRINT '✅ VALIDACIÓN COMPLETADA CORRECTAMENTE SI NO HAY ERRORES ARRIBA.';
