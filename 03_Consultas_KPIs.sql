/*****************************************************************
-- SCRIPT COMPLETO DE KPIs - DATA WAREHOUSE CÁRNICOS DEL CARIBE
-- Archivo: KPIs_Completos_Analisis.sql
-- Fecha: 2025
-- Descripción: Consultas para medir 20 KPIs estratégicos del negocio
-- Nota: Ajustar valores de meta según realidad empresarial
*****************************************************************/

PRINT '=====================================================';
PRINT 'ANÁLISIS DE KPIs ESTRATÉGICOS - CÁRNICOS DEL CARIBE';
PRINT '=====================================================';
PRINT '';

-- =========================================================
-- 1. KPI CRECIMIENTO VENTAS VS PRESUPUESTO
-- =========================================================
PRINT '1. KPI CRECIMIENTO VENTAS VS PRESUPUESTO';
PRINT '   Objetivo: Alcanzar objetivos de venta';
PRINT '   Meta: 100% del presupuesto mensual';
PRINT '   Métrica: Ventas Netas / Meta Presupuesto';
PRINT '----------------------------------------';

SELECT 
    YEAR(dt.Fecha) as Año,
    MONTH(dt.Fecha) as Mes,
    SUM(fv.PrecioUnitarioVenta * fv.CantidadUnidades - fv.DescuentoUnitario) as VentasNetas,
    1000000 as MetaPresupuesto,
    (SUM(fv.PrecioUnitarioVenta * fv.CantidadUnidades - fv.DescuentoUnitario) / 1000000.0) * 100 as PorcentajeCumplimiento,
    CASE 
        WHEN (SUM(fv.PrecioUnitarioVenta * fv.CantidadUnidades - fv.DescuentoUnitario) / 1000000.0) * 100 >= 100 
        THEN '✅ CUMPLE' 
        ELSE '❌ NO CUMPLE' 
    END as Estado
FROM Fact_Ventas fv
JOIN Dim_Tiempo dt ON fv.IDTiempoVenta = dt.IDTiempo
WHERE dt.Anio = 2024
GROUP BY YEAR(dt.Fecha), MONTH(dt.Fecha)
ORDER BY Año, Mes;

PRINT '';

-- =========================================================
-- 2. KPI MARGEN BRUTO
-- =========================================================
PRINT '2. KPI MARGEN BRUTO';
PRINT '   Objetivo: Mantener rentabilidad operativa';
PRINT '   Meta: 25-30% margen bruto';
PRINT '   Métrica: Utilidad Bruta / Ventas Netas';
PRINT '----------------------------------------';

SELECT 
    dt.Trimestre,
    dt.Mes,
    dt.Anio,
    SUM((fv.PrecioUnitarioVenta - fv.DescuentoUnitario) * fv.CantidadUnidades) as VentasNetas,
    SUM(fv.CostoUnitario * fv.CantidadUnidades) as CostoTotal,
    SUM(((fv.PrecioUnitarioVenta - fv.DescuentoUnitario) - fv.CostoUnitario) * fv.CantidadUnidades) as UtilidadBruta,
    (SUM(((fv.PrecioUnitarioVenta - fv.DescuentoUnitario) - fv.CostoUnitario) * fv.CantidadUnidades) / 
     SUM((fv.PrecioUnitarioVenta - fv.DescuentoUnitario) * fv.CantidadUnidades)) * 100 as MargenPorcentaje,
    CASE 
        WHEN (SUM(((fv.PrecioUnitarioVenta - fv.DescuentoUnitario) - fv.CostoUnitario) * fv.CantidadUnidades) / 
              SUM((fv.PrecioUnitarioVenta - fv.DescuentoUnitario) * fv.CantidadUnidades)) * 100 BETWEEN 25 AND 30 
        THEN '✅ CUMPLE' 
        ELSE '❌ NO CUMPLE' 
    END as Estado
FROM Fact_Ventas fv
JOIN Dim_Tiempo dt ON fv.IDTiempoVenta = dt.IDTiempo
GROUP BY dt.Trimestre, dt.Mes, dt.Anio
ORDER BY dt.Anio, dt.Trimestre, dt.Mes;

PRINT '';

-- =========================================================
-- 3. KPI TICKET PROMEDIO
-- =========================================================
PRINT '3. KPI TICKET PROMEDIO';
PRINT '   Objetivo: Incrementar valor por transacción';
PRINT '   Meta: Aumentar 10% vs año anterior';
PRINT '   Métrica: Ventas Netas / Total Pedidos';
PRINT '----------------------------------------';

WITH VentasAnioActual AS (
    SELECT 
        MONTH(dt.Fecha) as Mes,
        SUM(fv.PrecioUnitarioVenta * fv.CantidadUnidades - fv.DescuentoUnitario) as VentasNetas,
        COUNT(DISTINCT fv.NumeroPedido) as TotalPedidos,
        SUM(fv.PrecioUnitarioVenta * fv.CantidadUnidades - fv.DescuentoUnitario) / 
        COUNT(DISTINCT fv.NumeroPedido) as TicketPromedio
    FROM Fact_Ventas fv
    JOIN Dim_Tiempo dt ON fv.IDTiempoVenta = dt.IDTiempo
    WHERE dt.Anio = 2024
    GROUP BY MONTH(dt.Fecha)
),
VentasAnioAnterior AS (
    SELECT 
        MONTH(dt.Fecha) as Mes,
        SUM(fv.PrecioUnitarioVenta * fv.CantidadUnidades - fv.DescuentoUnitario) / 
        COUNT(DISTINCT fv.NumeroPedido) as TicketPromedioAnterior
    FROM Fact_Ventas fv
    JOIN Dim_Tiempo dt ON fv.IDTiempoVenta = dt.IDTiempo
    WHERE dt.Anio = 2023
    GROUP BY MONTH(dt.Fecha)
)
SELECT 
    va.Mes,
    va.TicketPromedio,
    vaa.TicketPromedioAnterior,
    ((va.TicketPromedio - vaa.TicketPromedioAnterior) / vaa.TicketPromedioAnterior) * 100 as CrecimientoPorcentaje,
    CASE 
        WHEN ((va.TicketPromedio - vaa.TicketPromedioAnterior) / vaa.TicketPromedioAnterior) * 100 >= 10 
        THEN '✅ CUMPLE' 
        ELSE '❌ NO CUMPLE' 
    END as Estado
FROM VentasAnioActual va
LEFT JOIN VentasAnioAnterior vaa ON va.Mes = vaa.Mes
ORDER BY va.Mes;

PRINT '';

-- =========================================================
-- 4. KPI EFICIENCIA POR CANAL
-- =========================================================
PRINT '4. KPI EFICIENCIA POR CANAL';
PRINT '   Objetivo: Optimizar inversión por canal';
PRINT '   Meta: Web 15% crecimiento, Tienda 8%';
PRINT '   Métrica: Crecimiento Ventas por Canal';
PRINT '----------------------------------------';

SELECT 
    dc.NombreCanal,
    dt.Trimestre,
    dt.Anio,
    SUM(fv.PrecioUnitarioVenta * fv.CantidadUnidades - fv.DescuentoUnitario) as VentasNetas,
    COUNT(DISTINCT fv.NumeroPedido) as TotalPedidos,
    LAG(SUM(fv.PrecioUnitarioVenta * fv.CantidadUnidades - fv.DescuentoUnitario)) 
        OVER (PARTITION BY dc.NombreCanal ORDER BY dt.Anio, dt.Trimestre) as VentasTrimestreAnterior,
    CASE 
        WHEN LAG(SUM(fv.PrecioUnitarioVenta * fv.CantidadUnidades - fv.DescuentoUnitario)) 
             OVER (PARTITION BY dc.NombreCanal ORDER BY dt.Anio, dt.Trimestre) IS NOT NULL
        THEN ((SUM(fv.PrecioUnitarioVenta * fv.CantidadUnidades - fv.DescuentoUnitario) - 
               LAG(SUM(fv.PrecioUnitarioVenta * fv.CantidadUnidades - fv.DescuentoUnitario)) 
               OVER (PARTITION BY dc.NombreCanal ORDER BY dt.Anio, dt.Trimestre)) / 
               LAG(SUM(fv.PrecioUnitarioVenta * fv.CantidadUnidades - fv.DescuentoUnitario)) 
               OVER (PARTITION BY dc.NombreCanal ORDER BY dt.Anio, dt.Trimestre)) * 100
        ELSE NULL
    END as CrecimientoPorcentaje,
    CASE 
        WHEN dc.NombreCanal LIKE '%Web%' AND 
             ((SUM(fv.PrecioUnitarioVenta * fv.CantidadUnidades - fv.DescuentoUnitario) - 
               LAG(SUM(fv.PrecioUnitarioVenta * fv.CantidadUnidades - fv.DescuentoUnitario)) 
               OVER (PARTITION BY dc.NombreCanal ORDER BY dt.Anio, dt.Trimestre)) / 
               LAG(SUM(fv.PrecioUnitarioVenta * fv.CantidadUnidades - fv.DescuentoUnitario)) 
               OVER (PARTITION BY dc.NombreCanal ORDER BY dt.Anio, dt.Trimestre)) * 100 >= 15 
        THEN '✅ CUMPLE'
        WHEN dc.NombreCanal LIKE '%Tienda%' AND 
             ((SUM(fv.PrecioUnitarioVenta * fv.CantidadUnidades - fv.DescuentoUnitario) - 
               LAG(SUM(fv.PrecioUnitarioVenta * fv.CantidadUnidades - fv.DescuentoUnitario)) 
               OVER (PARTITION BY dc.NombreCanal ORDER BY dt.Anio, dt.Trimestre)) / 
               LAG(SUM(fv.PrecioUnitarioVenta * fv.CantidadUnidades - fv.DescuentoUnitario)) 
               OVER (PARTITION BY dc.NombreCanal ORDER BY dt.Anio, dt.Trimestre)) * 100 >= 8 
        THEN '✅ CUMPLE'
        ELSE '❌ NO CUMPLE'
    END as Estado
FROM Fact_Ventas fv
JOIN Dim_CanalVenta dc ON fv.IDCanal = dc.IDCanal
JOIN Dim_Tiempo dt ON fv.IDTiempoVenta = dt.IDTiempo
GROUP BY dc.NombreCanal, dt.Trimestre, dt.Anio
ORDER BY dc.NombreCanal, dt.Anio, dt.Trimestre;

PRINT '';

-- =========================================================
-- 5. KPI PRODUCTOS HIGH-PERFORMER
-- =========================================================
PRINT '5. KPI PRODUCTOS HIGH-PERFORMER';
PRINT '   Objetivo: Focalizar en productos rentables';
PRINT '   Meta: 20% productos generan 80% ventas';
PRINT '   Métrica: % Ventas Top 20% Productos';
PRINT '----------------------------------------';

WITH VentasPorProducto AS (
    SELECT 
        dp.IDProducto,
        dp.NombreProducto,
        dp.Categoria,
        SUM(fv.PrecioUnitarioVenta * fv.CantidadUnidades - fv.DescuentoUnitario) as VentasNetas,
        SUM(fv.CantidadUnidades) as UnidadesVendidas
    FROM Fact_Ventas fv
    JOIN Dim_Producto dp ON fv.IDProducto = dp.IDProducto
    WHERE dp.Activo = 1
    GROUP BY dp.IDProducto, dp.NombreProducto, dp.Categoria
),
RankingProductos AS (
    SELECT *,
        SUM(VentasNetas) OVER (ORDER BY VentasNetas DESC) / SUM(VentasNetas) OVER () as PorcentajeAcumulado,
        ROW_NUMBER() OVER (ORDER BY VentasNetas DESC) as Ranking
    FROM VentasPorProducto
)
SELECT 
    COUNT(*) as TotalProductos,
    COUNT(CASE WHEN PorcentajeAcumulado <= 0.8 THEN 1 END) as ProductosTop80Porciento,
    (COUNT(CASE WHEN PorcentajeAcumulado <= 0.8 THEN 1 END) * 100.0 / COUNT(*)) as PorcentajeProductosTop80,
    CASE 
        WHEN (COUNT(CASE WHEN PorcentajeAcumulado <= 0.8 THEN 1 END) * 100.0 / COUNT(*)) <= 20 
        THEN '✅ CUMPLE' 
        ELSE '❌ NO CUMPLE' 
    END as Estado
FROM RankingProductos;

PRINT '';

-- =========================================================
-- 6. KPI CUMPLIMIENTO ENTREGAS
-- =========================================================
PRINT '6. KPI CUMPLIMIENTO ENTREGAS';
PRINT '   Objetivo: Mejorar servicio al cliente';
PRINT '   Meta: 95% entregas a tiempo';
PRINT '   Métrica: Entregas a Tiempo / Total Entregas';
PRINT '----------------------------------------';

SELECT 
    dt.Anio,
    dt.Mes,
    COUNT(*) as TotalPedidos,
    COUNT(CASE WHEN dt_entrega.Fecha <= dt_pedido.Fecha + 5 THEN 1 END) as EntregasATiempo,
    (COUNT(CASE WHEN dt_entrega.Fecha <= dt_pedido.Fecha + 5 THEN 1 END) * 100.0 / COUNT(*)) as PorcentajeEntregasATiempo,
    CASE 
        WHEN (COUNT(CASE WHEN dt_entrega.Fecha <= dt_pedido.Fecha + 5 THEN 1 END) * 100.0 / COUNT(*)) >= 95 
        THEN '✅ CUMPLE' 
        ELSE '❌ NO CUMPLE' 
    END as Estado
FROM Fact_Ventas fv
JOIN Dim_Tiempo dt ON fv.IDTiempoVenta = dt.IDTiempo
JOIN Dim_Tiempo dt_pedido ON fv.IDTiempoPedido = dt_pedido.IDTiempo
JOIN Dim_Tiempo dt_entrega ON fv.IDTiempoEntrega = dt_entrega.IDTiempo
WHERE fv.IDTiempoEntrega IS NOT NULL
GROUP BY dt.Anio, dt.Mes
ORDER BY dt.Anio, dt.Mes;

PRINT '';

-- =========================================================
-- 7. KPI EBITDA SUCURSAL
-- =========================================================
PRINT '7. KPI EBITDA SUCURSAL';
PRINT '   Objetivo: Maximizar rentabilidad por ubicación';
PRINT '   Meta: >15% por sucursal';
PRINT '   Métrica: Utilidad Neta / Ventas Totales';
PRINT '----------------------------------------';

SELECT 
    ds.NombreSucursal,
    ds.Ciudad,
    dt.Trimestre,
    dt.Anio,
    ff.VentasTotales,
    ff.UtilidadNeta,
    (ff.UtilidadNeta / ff.VentasTotales) * 100 as EBITDAPorcentaje,
    CASE 
        WHEN (ff.UtilidadNeta / ff.VentasTotales) > 0.15 
        THEN '✅ CUMPLE' 
        ELSE '❌ NO CUMPLE' 
    END as Estado
FROM Fact_Finanzas ff
JOIN Dim_Sucursal ds ON ff.IDSucursal = ds.IDSucursal
JOIN Dim_Tiempo dt ON ff.IDTiempo = dt.IDTiempo
WHERE dt.Anio = 2024
ORDER BY ds.NombreSucursal, dt.Anio, dt.Trimestre;

PRINT '';

-- =========================================================
-- 8. KPI CONTROL DE GASTOS
-- =========================================================
PRINT '8. KPI CONTROL DE GASTOS';
PRINT '   Objetivo: Optimizar estructura de costos';
PRINT '   Meta: Gastos < 20% ventas';
PRINT '   Métrica: Gastos Operativos / Ventas Totales';
PRINT '----------------------------------------';

SELECT 
    dt.Trimestre,
    dt.Anio,
    SUM(ff.VentasTotales) as VentasTotales,
    SUM(ff.GastosOperativos) as GastosTotales,
    (SUM(ff.GastosOperativos) / SUM(ff.VentasTotales)) * 100 as PorcentajeGastos,
    CASE 
        WHEN (SUM(ff.GastosOperativos) / SUM(ff.VentasTotales)) < 0.20 
        THEN '✅ CUMPLE' 
        ELSE '❌ NO CUMPLE' 
    END as Estado
FROM Fact_Finanzas ff
JOIN Dim_Tiempo dt ON ff.IDTiempo = dt.IDTiempo
GROUP BY dt.Trimestre, dt.Anio
ORDER BY dt.Anio, dt.Trimestre;

PRINT '';

-- =========================================================
-- 9. KPI ROI POR SUCURSAL
-- =========================================================
PRINT '9. KPI ROI POR SUCURSAL';
PRINT '   Objetivo: Priorizar inversiones';
PRINT '   Meta: ROI > 25%';
PRINT '   Métrica: Utilidad Neta / Inversión Sucursal';
PRINT '----------------------------------------';

SELECT 
    ds.NombreSucursal,
    dt.Anio,
    SUM(ff.UtilidadNeta) as UtilidadNeta,
    500000 as InversionSucursal,
    (SUM(ff.UtilidadNeta) / 500000) * 100 as ROIPorcentaje,
    CASE 
        WHEN (SUM(ff.UtilidadNeta) / 500000) > 0.25 
        THEN '✅ CUMPLE' 
        ELSE '❌ NO CUMPLE' 
    END as Estado
FROM Fact_Finanzas ff
JOIN Dim_Sucursal ds ON ff.IDSucursal = ds.IDSucursal
JOIN Dim_Tiempo dt ON ff.IDTiempo = dt.IDTiempo
GROUP BY ds.NombreSucursal, dt.Anio
ORDER BY ds.NombreSucursal, dt.Anio;

PRINT '';

-- =========================================================
-- 10. KPI LIQUIDEZ MENSUAL
-- =========================================================
PRINT '10. KPI LIQUIDEZ MENSUAL';
PRINT '    Objetivo: Mantener salud financiera';
PRINT '    Meta: Flujo positivo constante';
PRINT '    Métrica: Utilidad Neta > 0';
PRINT '----------------------------------------';

SELECT 
    dt.Mes,
    dt.Anio,
    SUM(ff.UtilidadNeta) as UtilidadNeta,
    SUM(ff.GastosOperativos) as GastosOperativos,
    CASE 
        WHEN SUM(ff.UtilidadNeta) > 0 THEN '✅ POSITIVO'
        WHEN SUM(ff.UtilidadNeta) = 0 THEN '🟡 NEUTRO'
        ELSE '❌ NEGATIVO'
    END as EstadoLiquidez
FROM Fact_Finanzas ff
JOIN Dim_Tiempo dt ON ff.IDTiempo = dt.IDTiempo
GROUP BY dt.Mes, dt.Anio
ORDER BY dt.Anio, dt.Mes;

PRINT '';

-- =========================================================
-- 11. KPI NPS (NET PROMOTER SCORE)
-- =========================================================
PRINT '11. KPI NPS (NET PROMOTER SCORE)';
PRINT '    Objetivo: Mejorar experiencia cliente';
PRINT '    Meta: NPS > 50';
PRINT '    Métrica: % Promotores - % Detractores';
PRINT '----------------------------------------';

SELECT 
    dt.Trimestre,
    dt.Anio,
    COUNT(*) as TotalEncuestas,
    COUNT(CASE WHEN fsc.PuntuacionGeneral >= 9 THEN 1 END) as Promotores,
    COUNT(CASE WHEN fsc.PuntuacionGeneral <= 6 THEN 1 END) as Detractores,
    COUNT(CASE WHEN fsc.PuntuacionGeneral BETWEEN 7 AND 8 THEN 1 END) as Neutros,
    ((COUNT(CASE WHEN fsc.PuntuacionGeneral >= 9 THEN 1 END) - 
      COUNT(CASE WHEN fsc.PuntuacionGeneral <= 6 THEN 1 END)) * 100.0 / COUNT(*)) as NPS,
    CASE 
        WHEN ((COUNT(CASE WHEN fsc.PuntuacionGeneral >= 9 THEN 1 END) - 
               COUNT(CASE WHEN fsc.PuntuacionGeneral <= 6 THEN 1 END)) * 100.0 / COUNT(*)) > 50 
        THEN '✅ CUMPLE' 
        ELSE '❌ NO CUMPLE' 
    END as Estado
FROM Fact_SatisfaccionCliente fsc
JOIN Dim_Tiempo dt ON fsc.IDTiempo = dt.IDTiempo
GROUP BY dt.Trimestre, dt.Anio
ORDER BY dt.Anio, dt.Trimestre;

PRINT '';

-- =========================================================
-- 12. KPI RETENCIÓN CLIENTES
-- =========================================================
PRINT '12. KPI RETENCIÓN CLIENTES';
PRINT '    Objetivo: Fidelizar base clientes';
PRINT '    Meta: 80% retención anual';
PRINT '    Métrica: Clientes Recurrentes / Total Clientes';
PRINT '----------------------------------------';

WITH ClientesActivos AS (
    SELECT DISTINCT 
        dc.IDCliente,
        YEAR(dt.Fecha) as Anio
    FROM Fact_Ventas fv
    JOIN Dim_Cliente dc ON fv.IDCliente = dc.IDCliente
    JOIN Dim_Tiempo dt ON fv.IDTiempoVenta = dt.IDTiempo
    WHERE dc.ClienteActivo = 1
),
Retencion AS (
    SELECT 
        ca1.Anio,
        COUNT(ca1.IDCliente) as ClientesInicio,
        COUNT(ca2.IDCliente) as ClientesRetenidos,
        (COUNT(ca2.IDCliente) * 100.0 / COUNT(ca1.IDCliente)) as PorcentajeRetencion,
        CASE 
            WHEN (COUNT(ca2.IDCliente) * 100.0 / COUNT(ca1.IDCliente)) >= 80 
            THEN '✅ CUMPLE' 
            ELSE '❌ NO CUMPLE' 
        END as Estado
    FROM ClientesActivos ca1
    LEFT JOIN ClientesActivos ca2 ON ca1.IDCliente = ca2.IDCliente AND ca1.Anio = ca2.Anio - 1
    GROUP BY ca1.Anio
)
SELECT * FROM Retencion
WHERE Anio < YEAR(GETDATE())
ORDER BY Anio;

PRINT '';

-- =========================================================
-- 13. KPI SATISFACCIÓN POR PRODUCTO
-- =========================================================
PRINT '13. KPI SATISFACCIÓN POR PRODUCTO';
PRINT '    Objetivo: Identificar productos problema';
PRINT '    Meta: Puntuación > 8 todos productos';
PRINT '    Métrica: AVG(PuntuacionProducto)';
PRINT '----------------------------------------';

SELECT 
    dp.NombreProducto,
    dp.Categoria,
    COUNT(fsc.IDEncuesta) as TotalEncuestas,
    AVG(fsc.PuntuacionProducto * 1.0) as PuntuacionPromedio,
    CASE 
        WHEN AVG(fsc.PuntuacionProducto * 1.0) > 8 
        THEN '✅ CUMPLE' 
        ELSE '❌ NO CUMPLE' 
    END as Estado
FROM Fact_SatisfaccionCliente fsc
JOIN Dim_Producto dp ON fsc.IDProducto = dp.IDProducto
GROUP BY dp.NombreProducto, dp.Categoria
HAVING COUNT(fsc.IDEncuesta) >= 10
ORDER BY PuntuacionPromedio DESC;

PRINT '';

-- =========================================================
-- 14. KPI VALOR VIDA DEL CLIENTE (LTV)
-- =========================================================
PRINT '14. KPI VALOR VIDA DEL CLIENTE (LTV)';
PRINT '    Objetivo: Maximizar valor por cliente';
PRINT '    Meta: Aumentar 15% anual';
PRINT '    Métrica: Ventas Totales / Clientes Únicos';
PRINT '----------------------------------------';

WITH VentasPorCliente AS (
    SELECT 
        dc.IDCliente,
        dc.NombreCliente,
        dc.Segmento,
        YEAR(dt.Fecha) as Anio,
        COUNT(DISTINCT fv.NumeroPedido) as TotalPedidos,
        SUM(fv.PrecioUnitarioVenta * fv.CantidadUnidades - fv.DescuentoUnitario) as VentasTotales
    FROM Fact_Ventas fv
    JOIN Dim_Cliente dc ON fv.IDCliente = dc.IDCliente
    JOIN Dim_Tiempo dt ON fv.IDTiempoVenta = dt.IDTiempo
    GROUP BY dc.IDCliente, dc.NombreCliente, dc.Segmento, YEAR(dt.Fecha)
),
LTVAnual AS (
    SELECT 
        Anio,
        Segmento,
        COUNT(*) as TotalClientes,
        AVG(VentasTotales) as LTVPromedio,
        LAG(AVG(VentasTotales)) OVER (PARTITION BY Segmento ORDER BY Anio) as LTVAnioAnterior,
        CASE 
            WHEN LAG(AVG(VentasTotales)) OVER (PARTITION BY Segmento ORDER BY Anio) IS NOT NULL
            THEN ((AVG(VentasTotales) - LAG(AVG(VentasTotales)) OVER (PARTITION BY Segmento ORDER BY Anio)) / 
                  LAG(AVG(VentasTotales)) OVER (PARTITION BY Segmento ORDER BY Anio)) * 100
            ELSE NULL
        END as CrecimientoPorcentaje,
        CASE 
            WHEN LAG(AVG(VentasTotales)) OVER (PARTITION BY Segmento ORDER BY Anio) IS NOT NULL AND
                 ((AVG(VentasTotales) - LAG(AVG(VentasTotales)) OVER (PARTITION BY Segmento ORDER BY Anio)) / 
                  LAG(AVG(VentasTotales)) OVER (PARTITION BY Segmento ORDER BY Anio)) * 100 >= 15
            THEN '✅ CUMPLE'
            ELSE '❌ NO CUMPLE'
        END as Estado
    FROM VentasPorCliente
    GROUP BY Anio, Segmento
)
SELECT * FROM LTVAnual
ORDER BY Segmento, Anio;

PRINT '';

-- =========================================================
-- 15. KPI TASA CONVERSIÓN DIGITAL
-- =========================================================
PRINT '15. KPI TASA CONVERSIÓN DIGITAL';
PRINT '    Objetivo: Maximizar conversiones online';
PRINT '    Meta: 4-6% conversión';
PRINT '    Métrica: Conversiones / Sesiones Totales';
PRINT '----------------------------------------';

SELECT 
    dc.NombreCanal,
    dt.Mes,
    dt.Anio,
    SUM(fmw.SesionesTotales) as SesionesTotales,
    SUM(fmw.Conversiones) as Conversiones,
    (SUM(fmw.Conversiones) * 100.0 / SUM(fmw.SesionesTotales)) as TasaConversion,
    CASE 
        WHEN (SUM(fmw.Conversiones) * 100.0 / SUM(fmw.SesionesTotales)) BETWEEN 4 AND 6 
        THEN '✅ EN META'
        ELSE '❌ FUERA DE META'
    END as Estado
FROM Fact_MetricasWeb fmw
JOIN Dim_CanalVenta dc ON fmw.IDCanal = dc.IDCanal
JOIN Dim_Tiempo dt ON fmw.IDTiempo = dt.IDTiempo
WHERE dc.TipoCanal = 'Digital'
GROUP BY dc.NombreCanal, dt.Mes, dt.Anio
ORDER BY dc.NombreCanal, dt.Anio, dt.Mes;

PRINT '';

-- =========================================================
-- 16. KPI CRECIMIENTO TRÁFICO ORGÁNICO
-- =========================================================
PRINT '16. KPI CRECIMIENTO TRÁFICO ORGÁNICO';
PRINT '    Objetivo: Aumentar presencia digital';
PRINT '    Meta: 20% crecimiento mensual';
PRINT '    Métrica: (Sesiones Mes Actual / Mes Anterior) - 1';
PRINT '----------------------------------------';

WITH MetricasMensuales AS (
    SELECT 
        dc.NombreCanal,
        dt.Mes,
        dt.Anio,
        SUM(fmw.SesionesTotales) as SesionesTotales,
        SUM(fmw.UsuariosUnicos) as UsuariosUnicos,
        LAG(SUM(fmw.SesionesTotales)) OVER (PARTITION BY dc.NombreCanal ORDER BY dt.Anio, dt.Mes) as SesionesMesAnterior
    FROM Fact_MetricasWeb fmw
    JOIN Dim_CanalVenta dc ON fmw.IDCanal = dc.IDCanal
    JOIN Dim_Tiempo dt ON fmw.IDTiempo = dt.IDTiempo
    WHERE dc.TipoCanal = 'Digital'
    GROUP BY dc.NombreCanal, dt.Mes, dt.Anio
)
SELECT 
    NombreCanal,
    Mes,
    Anio,
    SesionesTotales,
    SesionesMesAnterior,
    CASE 
        WHEN SesionesMesAnterior IS NOT NULL AND SesionesMesAnterior > 0
        THEN ((SesionesTotales - SesionesMesAnterior) * 100.0 / SesionesMesAnterior)
        ELSE NULL
    END as CrecimientoPorcentaje,
    CASE 
        WHEN SesionesMesAnterior IS NOT NULL AND SesionesMesAnterior > 0 AND
             ((SesionesTotales - SesionesMesAnterior) * 100.0 / SesionesMesAnterior) >= 20 
        THEN '✅ CUMPLE' 
        ELSE '❌ NO CUMPLE' 
    END as Estado
FROM MetricasMensuales
ORDER BY NombreCanal, Anio, Mes;

PRINT '';

-- =========================================================
-- 17. KPI ROI MARKETING DIGITAL
-- =========================================================
PRINT '17. KPI ROI MARKETING DIGITAL';
PRINT '    Objetivo: Optimizar gasto marketing';
PRINT '    Meta: ROI > 300%';
PRINT '    Métrica: (Ingresos - Inversión) / Inversión';
PRINT '----------------------------------------';

SELECT 
    dt.Trimestre,
    dt.Anio,
    SUM(fmw.IngresosDigitales) as IngresosDigitales,
    10000 as InversionMarketing,
    (SUM(fmw.IngresosDigitales) - 10000) as UtilidadNeta,
    ((SUM(fmw.IngresosDigitales) - 10000) / 10000) * 100 as ROIPorcentaje,
    CASE 
        WHEN ((SUM(fmw.IngresosDigitales) - 10000) / 10000) * 100 > 300 
        THEN '✅ CUMPLE' 
        ELSE '❌ NO CUMPLE' 
    END as Estado
FROM Fact_MetricasWeb fmw
JOIN Dim_Tiempo dt ON fmw.IDTiempo = dt.IDTiempo
GROUP BY dt.Trimestre, dt.Anio
ORDER BY dt.Anio, dt.Trimestre;

PRINT '';

-- =========================================================
-- 18. KPI EFICIENCIA POR SUCURSAL
-- =========================================================
PRINT '18. KPI EFICIENCIA POR SUCURSAL';
PRINT '    Objetivo: Optimizar operaciones';
PRINT '    Meta: Ventas/m² > $5,000';
PRINT '    Métrica: Ventas Netas / Metros Cuadrados';
PRINT '----------------------------------------';

SELECT 
    ds.NombreSucursal,
    ds.Ciudad,
    dt.Anio,
    dt.Mes,
    SUM(fv.PrecioUnitarioVenta * fv.CantidadUnidades - fv.DescuentoUnitario) as VentasNetas,
    200 as MetrosCuadrados,
    (SUM(fv.PrecioUnitarioVenta * fv.CantidadUnidades - fv.DescuentoUnitario) / 200) as VentasPorM2,
    CASE 
        WHEN (SUM(fv.PrecioUnitarioVenta * fv.CantidadUnidades - fv.DescuentoUnitario) / 200) > 5000 
        THEN '✅ CUMPLE' 
        ELSE '❌ NO CUMPLE' 
    END as Estado
FROM Fact_Ventas fv
JOIN Dim_Sucursal ds ON fv.IDSucursal = ds.IDSucursal
JOIN Dim_Tiempo dt ON fv.IDTiempoVenta = dt.IDTiempo
GROUP BY ds.NombreSucursal, ds.Ciudad, dt.Anio, dt.Mes
ORDER BY ds.NombreSucursal, dt.Anio, dt.Mes;

PRINT '';

-- =========================================================
-- 19. KPI ROTACIÓN INVENTARIO
-- =========================================================
PRINT '19. KPI ROTACIÓN INVENTARIO';
PRINT '    Objetivo: Mejorar gestión inventarios';
PRINT '    Meta: Rotación > 8 veces anual';
PRINT '    Métrica: Costo Ventas / Inventario Promedio';
PRINT '----------------------------------------';

SELECT 
    dp.Categoria,
    YEAR(dt.Fecha) as Anio,
    SUM(fv.CostoUnitario * fv.CantidadUnidades) as CostoVentas,
    100000 as InventarioPromedio,
    (SUM(fv.CostoUnitario * fv.CantidadUnidades) / 100000) as RotacionInventario,
    CASE 
        WHEN (SUM(fv.CostoUnitario * fv.CantidadUnidades) / 100000) > 8 
        THEN '✅ CUMPLE' 
        ELSE '❌ NO CUMPLE' 
    END as Estado
FROM Fact_Ventas fv
JOIN Dim_Producto dp ON fv.IDProducto = dp.IDProducto
JOIN Dim_Tiempo dt ON fv.IDTiempoVenta = dt.IDTiempo
GROUP BY dp.Categoria, YEAR(dt.Fecha)
ORDER BY dp.Categoria, Anio;

PRINT '';

-- =========================================================
-- 20. KPI PRODUCTIVIDAD EMPLEADOS
-- =========================================================
PRINT '20. KPI PRODUCTIVIDAD EMPLEADOS';
PRINT '    Objetivo: Maximizar eficiencia equipo';
PRINT '    Meta: Ventas/empleado > $50,000 mensual';
PRINT '    Métrica: Ventas Netas / Empleados Activos';
PRINT '----------------------------------------';

SELECT 
    ds.NombreSucursal,
    dt.Anio,
    dt.Mes,
    COUNT(DISTINCT de.IDEmpleado) as TotalEmpleadosActivos,
    SUM(fv.PrecioUnitarioVenta * fv.CantidadUnidades - fv.DescuentoUnitario) as VentasNetas,
    (SUM(fv.PrecioUnitarioVenta * fv.CantidadUnidades - fv.DescuentoUnitario) / 
     COUNT(DISTINCT de.IDEmpleado)) as VentasPorEmpleado,
    CASE 
        WHEN (SUM(fv.PrecioUnitarioVenta * fv.CantidadUnidades - fv.DescuentoUnitario) / 
               COUNT(DISTINCT de.IDEmpleado)) > 50000 
        THEN '✅ CUMPLE' 
        ELSE '❌ NO CUMPLE' 
    END as Estado
FROM Fact_Ventas fv
JOIN Dim_Sucursal ds ON fv.IDSucursal = ds.IDSucursal
JOIN Dim_Empleado de ON fv.IDEmpleado = de.IDEmpleado
JOIN Dim_Tiempo dt ON fv.IDTiempoVenta = dt.IDTiempo
WHERE de.EmpleadoActivo = 1
GROUP BY ds.NombreSucursal, dt.Anio, dt.Mes
ORDER BY ds.NombreSucursal, dt.Anio, dt.Mes;

PRINT '';
PRINT '=====================================================';
PRINT '🎯 ANÁLISIS DE KPIs COMPLETADO EXITOSAMENTE';
PRINT '📊 Total: 20 KPIs estratégicos analizados';
PRINT '✅ Estado: Script listo para ejecución';
PRINT '=====================================================';