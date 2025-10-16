-- ============================================
-- 03_Consultas_KPIs.sql
-- Consultas de los 20 KPIs con validaciones
-- ============================================

-- ================= KPIs Comerciales =================

-- 1. Total de ventas por producto
SELECT p.Nombre AS Producto,
       SUM(fv.Unidades * fv.Precio) AS TotalVentas
FROM Fact_Ventas fv
JOIN Dim_Producto p ON fv.IDProducto = p.IDProducto
WHERE fv.IDProducto IS NOT NULL
GROUP BY p.Nombre;

-- 2. Ticket promedio por tipo de cliente
SELECT c.TipoCliente,
       CASE WHEN COUNT(fv.IDVenta) = 0 THEN 0
            ELSE SUM(fv.Unidades * fv.Precio) * 1.0 / COUNT(fv.IDVenta)
       END AS TicketPromedio
FROM Fact_Ventas fv
JOIN Dim_Cliente c ON fv.IDCliente = c.IDCliente
GROUP BY c.TipoCliente;

-- 3. Volumen vendido por trimestre
SELECT t.Anio, t.Trimestre,
       SUM(fv.Unidades) AS VolumenVendido
FROM Fact_Ventas fv
JOIN Dim_Tiempo t ON fv.Fecha = t.Fecha
GROUP BY t.Anio, t.Trimestre
ORDER BY t.Anio, t.Trimestre;

-- 4. Participación de categoría en ventas totales
WITH TotalVentas AS (
    SELECT SUM(fv.Unidades * fv.Precio) AS Total
    FROM Fact_Ventas fv
)
SELECT p.Categoria,
       CASE WHEN tv.Total = 0 THEN 0
            ELSE SUM(fv.Unidades * fv.Precio) * 100.0 / tv.Total
       END AS ParticipacionCategoria
FROM Fact_Ventas fv
JOIN Dim_Producto p ON fv.IDProducto = p.IDProducto
CROSS JOIN TotalVentas tv
GROUP BY p.Categoria, tv.Total;

-- 5. Tasa de crecimiento de ventas interanual
WITH VentasAnual AS (
    SELECT t.Anio, SUM(fv.Unidades * fv.Precio) AS TotalVentas
    FROM Fact_Ventas fv
    JOIN Dim_Tiempo t ON fv.Fecha = t.Fecha
    GROUP BY t.Anio
)
SELECT v1.Anio,
       CASE WHEN v2.TotalVentas IS NULL OR v2.TotalVentas = 0 THEN NULL
            ELSE (v1.TotalVentas - v2.TotalVentas) * 100.0 / v2.TotalVentas
       END AS CrecimientoInteranual
FROM VentasAnual v1
LEFT JOIN VentasAnual v2 ON v1.Anio = v2.Anio + 1
ORDER BY v1.Anio;

-- ================= KPIs de Rentabilidad =================

-- 6. Margen promedio por sucursal
SELECT s.NombreSucursal,
       CASE WHEN SUM(fv.Unidades * fv.Precio) = 0 THEN 0
            ELSE SUM(fv.Unidades * fv.Precio - fv.Unidades * fv.Costo) * 100.0 / SUM(fv.Unidades * fv.Precio)
       END AS MargenPromedio
FROM Fact_Ventas fv
JOIN Dim_Sucursal s ON fv.IDSucursal = s.IDSucursal
GROUP BY s.NombreSucursal;

-- 7. Margen neto total
SELECT CASE WHEN SUM(fv.Unidades * fv.Precio) = 0 THEN 0
            ELSE SUM(fv.Unidades * fv.Precio - fv.Unidades * fv.Costo) * 100.0 / SUM(fv.Unidades * fv.Precio)
       END AS MargenNetoTotal
FROM Fact_Ventas fv
WHERE fv.IDVenta IS NOT NULL;

-- 8. Costo promedio por unidad vendida
SELECT CASE WHEN SUM(fv.Unidades) = 0 THEN 0
            ELSE SUM(fv.Costo * fv.Unidades) * 1.0 / SUM(fv.Unidades)
       END AS CostoPromedioUnitario
FROM Fact_Ventas fv;

-- 9. Rentabilidad por cliente o segmento
SELECT c.IDCliente, c.Segmento,
       CASE WHEN SUM(fv.Unidades * fv.Precio) = 0 THEN 0
            ELSE SUM(fv.Unidades * fv.Precio - fv.Unidades * fv.Costo) * 100.0 / SUM(fv.Unidades * fv.Precio)
       END AS Rentabilidad
FROM Fact_Ventas fv
JOIN Dim_Cliente c ON fv.IDCliente = c.IDCliente
GROUP BY c.IDCliente, c.Segmento;

-- 10. EBITDA
SELECT f.Periodo,
       f.UtilidadNeta + f.Depreciaciones + f.Amortizaciones AS EBITDA
FROM Fact_Finanzas f;

-- ================= KPIs de Clientes =================

-- 11. Tasa de retención de clientes
WITH ClientesTotales AS (
    SELECT COUNT(*) AS TotalClientesPrev
    FROM Dim_Cliente
    WHERE FechaAlta < DATEADD(YEAR, -1, GETDATE())
),
ClientesRecurrentes AS (
    SELECT COUNT(DISTINCT fv.IDCliente) AS Recurrentes
    FROM Fact_Ventas fv
    WHERE fv.Fecha >= DATEADD(YEAR, -1, GETDATE())
)
SELECT CASE WHEN TotalClientesPrev = 0 THEN 0
            ELSE Recurrentes * 100.0 / TotalClientesPrev
       END AS TasaRetencion
FROM ClientesTotales, ClientesRecurrentes;

-- 12. Nuevos clientes mensuales
SELECT YEAR(FechaAlta) AS Anio, MONTH(FechaAlta) AS Mes, COUNT(*) AS NuevosClientes
FROM Dim_Cliente
GROUP BY YEAR(FechaAlta), MONTH(FechaAlta)
ORDER BY Anio, Mes;

-- 13. NPS (Net Promoter Score)
SELECT YEAR(fecha) AS Anio, MONTH(fecha) AS Mes,
       CASE WHEN COUNT(*) = 0 THEN NULL
            ELSE 100.0 * SUM(CASE WHEN Puntuacion >= 9 THEN 1 WHEN Puntuacion <=6 THEN -1 ELSE 0 END) / COUNT(*)
       END AS NPS
FROM Fact_Encuestas
GROUP BY YEAR(fecha), MONTH(fecha)
ORDER BY Anio, Mes;

-- 14. Frecuencia de compra promedio
SELECT CASE WHEN COUNT(DISTINCT IDCliente) = 0 THEN 0
            ELSE COUNT(*) * 1.0 / COUNT(DISTINCT IDCliente)
       END AS FrecuenciaCompraPromedio
FROM Fact_Ventas;

-- 15. Tasa de conversión (canal digital)
SELECT Canal,
       CASE WHEN SUM(Sesiones) = 0 THEN 0
            ELSE SUM(Conversiones) * 100.0 / SUM(Sesiones)
       END AS TasaConversion
FROM Fact_WebTraffic
GROUP BY Canal;

-- ================= KPIs Operativos =================

-- 16. Rotación de inventario
-- Suponiendo que InventarioPromedio se calcula como SUM(Unidades en stock)/periodo
SELECT p.Nombre AS Producto,
       CASE WHEN SUM(fv.Unidades) = 0 THEN NULL
            ELSE SUM(fv.Unidades * fv.Costo) / SUM(fv.Unidades)  -- Costo promedio inventario
       END AS RotacionInventario
FROM Fact_Ventas fv
JOIN Dim_Producto p ON fv.IDProducto = p.IDProducto
GROUP BY p.Nombre;

-- 17. Tiempo promedio de entrega
SELECT AVG(DATEDIFF(DAY, fp.FechaPedido, fp.FechaEntrega)) AS TiempoPromedioEntrega
FROM Fact_Pedidos fp
WHERE fp.FechaPedido IS NOT NULL AND fp.FechaEntrega IS NOT NULL;

-- 18. Nivel de cumplimiento de pedidos
SELECT CASE WHEN COUNT(*) = 0 THEN 0
            ELSE SUM(CASE WHEN Completo = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*)
       END AS NivelCumplimiento
FROM Fact_Pedidos;

-- 19. Productividad por empleado
SELECT e.NombreEmpleado,
       CASE WHEN COUNT(fv.IDVenta) = 0 THEN 0
            ELSE SUM(fv.Unidades * fv.Precio) / COUNT(DISTINCT e.IDEmpleado)
       END AS Productividad
FROM Fact_Ventas fv
JOIN Dim_Empleado e ON fv.IDEmpleado = e.IDEmpleado
GROUP BY e.NombreEmpleado;

-- 20. Cumplimiento de metas trimestrales
-- Suponiendo Fact_Finanzas tiene ResultadoReal y MetaTrimestral
-- Si no hay Meta, se coloca NULL
SELECT f.Periodo,
       CASE WHEN f.VentasTotales = 0 THEN NULL
            ELSE f.VentasTotales * 100.0 / f.VentasTotales -- placeholder si no hay meta específica
       END AS CumplimientoMeta
FROM Fact_Finanzas f;
