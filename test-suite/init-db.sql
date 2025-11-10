-- =============================================================================
-- SCRIPT DE INICIALIZACIÓN - DATA WAREHOUSE DE PRUEBA
-- =============================================================================

USE master;
GO

-- Crear base de datos de testing si no existe
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'DataWarehouseTest')
BEGIN
    CREATE DATABASE DataWarehouseTest;
    PRINT '✅ Base de datos DataWarehouseTest creada';
END
GO

USE DataWarehouseTest;
GO

-- =============================================================================
-- LIMPIAR TABLAS EXISTENTES (en orden correcto por FK)
-- =============================================================================
PRINT '🗑️  Limpiando tablas existentes...';

IF OBJECT_ID('Fact_MetricasWeb', 'U') IS NOT NULL DROP TABLE Fact_MetricasWeb;
IF OBJECT_ID('Fact_SatisfaccionCliente', 'U') IS NOT NULL DROP TABLE Fact_SatisfaccionCliente;
IF OBJECT_ID('Fact_Finanzas', 'U') IS NOT NULL DROP TABLE Fact_Finanzas;
IF OBJECT_ID('Fact_Ventas', 'U') IS NOT NULL DROP TABLE Fact_Ventas;

IF OBJECT_ID('Dim_EstadoPedido', 'U') IS NOT NULL DROP TABLE Dim_EstadoPedido;
IF OBJECT_ID('Dim_CanalVenta', 'U') IS NOT NULL DROP TABLE Dim_CanalVenta;
IF OBJECT_ID('Dim_Empleado', 'U') IS NOT NULL DROP TABLE Dim_Empleado;
IF OBJECT_ID('Dim_Sucursal', 'U') IS NOT NULL DROP TABLE Dim_Sucursal;
IF OBJECT_ID('Dim_Cliente', 'U') IS NOT NULL DROP TABLE Dim_Cliente;
IF OBJECT_ID('Dim_Producto', 'U') IS NOT NULL DROP TABLE Dim_Producto;
IF OBJECT_ID('Dim_Tiempo', 'U') IS NOT NULL DROP TABLE Dim_Tiempo;

PRINT '✅ Tablas limpiadas';
GO

-- =============================================================================
-- DIMENSIONES INDEPENDIENTES
-- =============================================================================

-- Dim_Tiempo
CREATE TABLE Dim_Tiempo (
    IDTiempo INT PRIMARY KEY,
    Fecha DATE NOT NULL UNIQUE,
    Anio INT NOT NULL,
    Semestre INT NOT NULL,
    Trimestre INT NOT NULL,
    Mes INT NOT NULL,
    NombreMes VARCHAR(20) NOT NULL,
    Dia INT NOT NULL,
    DiaSemana INT NOT NULL,
    NombreDiaSemana VARCHAR(20) NOT NULL,
    NumeroSemana INT NOT NULL,
    EsFinDeSemana BIT NOT NULL,
    EsFeriado BIT NOT NULL,
    TrimestreAnio VARCHAR(10) NOT NULL
);

CREATE INDEX idx_tiempo_fecha ON Dim_Tiempo(Fecha);
CREATE INDEX idx_tiempo_anio_mes ON Dim_Tiempo(Anio, Mes);
PRINT '✅ Dim_Tiempo creada';
GO

-- Dim_Producto
CREATE TABLE Dim_Producto (
    IDProducto INT IDENTITY(1,1) PRIMARY KEY,
    SKU VARCHAR(50) NOT NULL UNIQUE,
    NombreProducto VARCHAR(200) NOT NULL,
    Categoria VARCHAR(100) NOT NULL,
    Subcategoria VARCHAR(100) NOT NULL,
    Marca VARCHAR(100) NOT NULL,
    LineaProducto VARCHAR(100) NOT NULL,
    Activo BIT NOT NULL DEFAULT 1,
    FechaCreacion DATETIME DEFAULT GETDATE(),
    FechaModificacion DATETIME DEFAULT GETDATE()
);

CREATE INDEX idx_producto_categoria ON Dim_Producto(Categoria);
CREATE INDEX idx_producto_sku ON Dim_Producto(SKU);
PRINT '✅ Dim_Producto creada';
GO

-- Dim_Cliente
CREATE TABLE Dim_Cliente (
    IDCliente INT IDENTITY(1,1) PRIMARY KEY,
    CodigoCliente VARCHAR(50) NOT NULL UNIQUE,
    NombreCliente VARCHAR(200) NOT NULL,
    TipoCliente VARCHAR(50) NOT NULL,
    Segmento VARCHAR(10) NOT NULL,
    Ciudad VARCHAR(100) NOT NULL,
    Region VARCHAR(100) NOT NULL,
    FechaRegistro DATE NOT NULL,
    ClienteActivo BIT NOT NULL DEFAULT 1,
    FechaCreacion DATETIME DEFAULT GETDATE(),
    FechaModificacion DATETIME DEFAULT GETDATE()
);

CREATE INDEX idx_cliente_segmento ON Dim_Cliente(Segmento);
CREATE INDEX idx_cliente_ciudad ON Dim_Cliente(Ciudad);
PRINT '✅ Dim_Cliente creada';
GO

-- Dim_Sucursal
CREATE TABLE Dim_Sucursal (
    IDSucursal INT IDENTITY(1,1) PRIMARY KEY,
    CodigoSucursal VARCHAR(50) NOT NULL UNIQUE,
    NombreSucursal VARCHAR(200) NOT NULL,
    Direccion VARCHAR(300) NOT NULL,
    Ciudad VARCHAR(100) NOT NULL,
    Region VARCHAR(100) NOT NULL,
    TipoSucursal VARCHAR(50) NOT NULL,
    SucursalActiva BIT NOT NULL DEFAULT 1,
    FechaCreacion DATETIME DEFAULT GETDATE(),
    FechaModificacion DATETIME DEFAULT GETDATE()
);

CREATE INDEX idx_sucursal_ciudad ON Dim_Sucursal(Ciudad);
PRINT '✅ Dim_Sucursal creada';
GO

-- =============================================================================
-- DIMENSIONES DEPENDIENTES
-- =============================================================================

-- Dim_Empleado (depende de Sucursal)
CREATE TABLE Dim_Empleado (
    IDEmpleado INT IDENTITY(1,1) PRIMARY KEY,
    CodigoEmpleado VARCHAR(50) NOT NULL UNIQUE,
    NombreEmpleado VARCHAR(200) NOT NULL,
    Cargo VARCHAR(100) NOT NULL,
    Departamento VARCHAR(100) NOT NULL,
    IDSucursal INT NOT NULL,
    FechaContratacion DATE NOT NULL,
    EmpleadoActivo BIT NOT NULL DEFAULT 1,
    FechaCreacion DATETIME DEFAULT GETDATE(),
    FechaModificacion DATETIME DEFAULT GETDATE(),
    
    CONSTRAINT FK_Empleado_Sucursal FOREIGN KEY (IDSucursal) 
        REFERENCES Dim_Sucursal(IDSucursal)
);

CREATE INDEX idx_empleado_sucursal ON Dim_Empleado(IDSucursal);
CREATE INDEX idx_empleado_cargo ON Dim_Empleado(Cargo);
PRINT '✅ Dim_Empleado creada';
GO

-- Dim_CanalVenta
CREATE TABLE Dim_CanalVenta (
    IDCanal INT IDENTITY(1,1) PRIMARY KEY,
    CodigoCanal VARCHAR(50) NOT NULL UNIQUE,
    NombreCanal VARCHAR(100) NOT NULL,
    TipoCanal VARCHAR(50) NOT NULL,
    FechaCreacion DATETIME DEFAULT GETDATE(),
    FechaModificacion DATETIME DEFAULT GETDATE()
);

PRINT '✅ Dim_CanalVenta creada';
GO

-- Dim_EstadoPedido
CREATE TABLE Dim_EstadoPedido (
    IDEstadoPedido INT IDENTITY(1,1) PRIMARY KEY,
    CodigoEstado VARCHAR(50) NOT NULL UNIQUE,
    DescripcionEstado VARCHAR(100) NOT NULL,
    EsEstadoFinal BIT NOT NULL DEFAULT 0,
    FechaCreacion DATETIME DEFAULT GETDATE(),
    FechaModificacion DATETIME DEFAULT GETDATE()
);

PRINT '✅ Dim_EstadoPedido creada';
GO

-- =============================================================================
-- TABLAS DE HECHOS
-- =============================================================================

-- Fact_Ventas
CREATE TABLE Fact_Ventas (
    IDVenta INT IDENTITY(1,1) PRIMARY KEY,
    NumeroPedido VARCHAR(50) NOT NULL UNIQUE,
    IDTiempoVenta INT NOT NULL,
    IDTiempoPedido INT NOT NULL,
    IDTiempoEntrega INT NOT NULL,
    IDProducto INT NOT NULL,
    IDCliente INT NOT NULL,
    IDSucursal INT NOT NULL,
    IDEmpleado INT NOT NULL,
    IDCanal INT NOT NULL,
    IDEstadoPedido INT NOT NULL,
    CantidadUnidades INT NOT NULL,
    PrecioUnitarioVenta DECIMAL(18,2) NOT NULL,
    CostoUnitario DECIMAL(18,2) NOT NULL,
    DescuentoUnitario DECIMAL(18,2) NOT NULL DEFAULT 0,
    FechaCreacion DATETIME DEFAULT GETDATE(),
    
    -- Columnas calculadas para análisis rápido
    MontoTotal AS (CantidadUnidades * (PrecioUnitarioVenta - DescuentoUnitario)) PERSISTED,
    MontoDescuento AS (CantidadUnidades * DescuentoUnitario) PERSISTED,
    MontoCosto AS (CantidadUnidades * CostoUnitario) PERSISTED,
    Margen AS (CantidadUnidades * (PrecioUnitarioVenta - DescuentoUnitario - CostoUnitario)) PERSISTED,
    
    -- Foreign Keys
    CONSTRAINT FK_Ventas_TiempoVenta FOREIGN KEY (IDTiempoVenta) 
        REFERENCES Dim_Tiempo(IDTiempo),
    CONSTRAINT FK_Ventas_TiempoPedido FOREIGN KEY (IDTiempoPedido) 
        REFERENCES Dim_Tiempo(IDTiempo),
    CONSTRAINT FK_Ventas_TiempoEntrega FOREIGN KEY (IDTiempoEntrega) 
        REFERENCES Dim_Tiempo(IDTiempo),
    CONSTRAINT FK_Ventas_Producto FOREIGN KEY (IDProducto) 
        REFERENCES Dim_Producto(IDProducto),
    CONSTRAINT FK_Ventas_Cliente FOREIGN KEY (IDCliente) 
        REFERENCES Dim_Cliente(IDCliente),
    CONSTRAINT FK_Ventas_Sucursal FOREIGN KEY (IDSucursal) 
        REFERENCES Dim_Sucursal(IDSucursal),
    CONSTRAINT FK_Ventas_Empleado FOREIGN KEY (IDEmpleado) 
        REFERENCES Dim_Empleado(IDEmpleado),
    CONSTRAINT FK_Ventas_Canal FOREIGN KEY (IDCanal) 
        REFERENCES Dim_CanalVenta(IDCanal),
    CONSTRAINT FK_Ventas_Estado FOREIGN KEY (IDEstadoPedido) 
        REFERENCES Dim_EstadoPedido(IDEstadoPedido)
);

-- Índices para optimizar queries analíticas
CREATE INDEX idx_ventas_tiempo ON Fact_Ventas(IDTiempoVenta);
CREATE INDEX idx_ventas_producto ON Fact_Ventas(IDProducto);
CREATE INDEX idx_ventas_cliente ON Fact_Ventas(IDCliente);
CREATE INDEX idx_ventas_sucursal ON Fact_Ventas(IDSucursal);
CREATE INDEX idx_ventas_fecha_producto ON Fact_Ventas(IDTiempoVenta, IDProducto);
PRINT '✅ Fact_Ventas creada';
GO

-- Fact_Finanzas
CREATE TABLE Fact_Finanzas (
    IDFinanzas INT IDENTITY(1,1) PRIMARY KEY,
    IDTiempo INT NOT NULL,
    IDSucursal INT NOT NULL,
    VentasTotales DECIMAL(18,2) NOT NULL,
    CostosTotales DECIMAL(18,2) NOT NULL,
    GastosOperativos DECIMAL(18,2) NOT NULL,
    UtilidadBruta DECIMAL(18,2) NOT NULL,
    UtilidadNeta DECIMAL(18,2) NOT NULL,
    MargenBrutoPorcentaje DECIMAL(5,2) NOT NULL,
    FechaCreacion DATETIME DEFAULT GETDATE(),
    
    CONSTRAINT FK_Finanzas_Tiempo FOREIGN KEY (IDTiempo) 
        REFERENCES Dim_Tiempo(IDTiempo),
    CONSTRAINT FK_Finanzas_Sucursal FOREIGN KEY (IDSucursal) 
        REFERENCES Dim_Sucursal(IDSucursal),
        
    -- Constraint de unicidad: un registro por mes por sucursal
    CONSTRAINT UQ_Finanzas_Periodo UNIQUE (IDTiempo, IDSucursal)
);

CREATE INDEX idx_finanzas_tiempo ON Fact_Finanzas(IDTiempo);
CREATE INDEX idx_finanzas_sucursal ON Fact_Finanzas(IDSucursal);
PRINT '✅ Fact_Finanzas creada';
GO

-- Fact_SatisfaccionCliente
CREATE TABLE Fact_SatisfaccionCliente (
    IDSatisfaccion INT IDENTITY(1,1) PRIMARY KEY,
    IDTiempo INT NOT NULL,
    IDSucursal INT NOT NULL,
    IDCliente INT NOT NULL,
    IDProducto INT NOT NULL,
    PuntuacionServicio INT NOT NULL CHECK (PuntuacionServicio BETWEEN 1 AND 10),
    PuntuacionProducto INT NOT NULL CHECK (PuntuacionProducto BETWEEN 1 AND 10),
    PuntuacionGeneral INT NOT NULL CHECK (PuntuacionGeneral BETWEEN 1 AND 10),
    Recomendaria BIT NOT NULL,
    FechaCreacion DATETIME DEFAULT GETDATE(),
    
    CONSTRAINT FK_Satisfaccion_Tiempo FOREIGN KEY (IDTiempo) 
        REFERENCES Dim_Tiempo(IDTiempo),
    CONSTRAINT FK_Satisfaccion_Sucursal FOREIGN KEY (IDSucursal) 
        REFERENCES Dim_Sucursal(IDSucursal),
    CONSTRAINT FK_Satisfaccion_Cliente FOREIGN KEY (IDCliente) 
        REFERENCES Dim_Cliente(IDCliente),
    CONSTRAINT FK_Satisfaccion_Producto FOREIGN KEY (IDProducto) 
        REFERENCES Dim_Producto(IDProducto)
);

CREATE INDEX idx_satisfaccion_tiempo ON Fact_SatisfaccionCliente(IDTiempo);
CREATE INDEX idx_satisfaccion_cliente ON Fact_SatisfaccionCliente(IDCliente);
PRINT '✅ Fact_SatisfaccionCliente creada';
GO

-- Fact_MetricasWeb
CREATE TABLE Fact_MetricasWeb (
    IDMetricaWeb INT IDENTITY(1,1) PRIMARY KEY,
    IDTiempo INT NOT NULL,
    IDCanal INT NOT NULL,
    SesionesTotales INT NOT NULL,
    UsuariosUnicos INT NOT NULL,
    Conversiones INT NOT NULL,
    TasaConversion DECIMAL(5,2) NOT NULL,
    IngresosDigitales DECIMAL(18,2) NOT NULL,
    FechaCreacion DATETIME DEFAULT GETDATE(),
    
    CONSTRAINT FK_MetricasWeb_Tiempo FOREIGN KEY (IDTiempo) 
        REFERENCES Dim_Tiempo(IDTiempo),
    CONSTRAINT FK_MetricasWeb_Canal FOREIGN KEY (IDCanal) 
        REFERENCES Dim_CanalVenta(IDCanal),
        
    -- Constraint de unicidad: un registro por mes por canal
    CONSTRAINT UQ_MetricasWeb_Periodo UNIQUE (IDTiempo, IDCanal)
);

CREATE INDEX idx_metricasweb_tiempo ON Fact_MetricasWeb(IDTiempo);
CREATE INDEX idx_metricasweb_canal ON Fact_MetricasWeb(IDCanal);
PRINT '✅ Fact_MetricasWeb creada';
GO

-- =============================================================================
-- VISTAS ANALÍTICAS PARA TESTING
-- =============================================================================

-- Vista: Resumen de ventas por categoría
CREATE VIEW vw_VentasPorCategoria AS
SELECT 
    p.Categoria,
    COUNT(*) AS TotalVentas,
    SUM(v.CantidadUnidades) AS UnidadesVendidas,
    SUM(v.MontoTotal) AS VentasTotales,
    AVG(v.PrecioUnitarioVenta) AS PrecioPromedio
FROM Fact_Ventas v
INNER JOIN Dim_Producto p ON v.IDProducto = p.IDProducto
GROUP BY p.Categoria;
GO

-- Vista: Métricas por sucursal
CREATE VIEW vw_MetricasSucursal AS
SELECT 
    s.NombreSucursal,
    s.Ciudad,
    COUNT(v.IDVenta) AS TotalVentas,
    SUM(v.MontoTotal) AS VentasTotales,
    AVG(v.Margen) AS MargenPromedio,
    COUNT(DISTINCT v.IDCliente) AS ClientesUnicos
FROM Dim_Sucursal s
LEFT JOIN Fact_Ventas v ON s.IDSucursal = v.IDSucursal
GROUP BY s.NombreSucursal, s.Ciudad;
GO

PRINT '✅ Vistas analíticas creadas';
GO

-- =============================================================================
-- PROCEDIMIENTOS ALMACENADOS DE UTILIDAD
-- =============================================================================

-- SP: Contar registros en todas las tablas
CREATE PROCEDURE sp_ContarRegistros
AS
BEGIN
    SELECT 'Dim_Tiempo' AS Tabla, COUNT(*) AS Registros FROM Dim_Tiempo
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
    ORDER BY Tabla;
END;
GO

PRINT '✅ Procedimientos almacenados creados';
GO

-- =============================================================================
-- FINALIZACIÓN
-- =============================================================================
PRINT '';
PRINT '🎉 ¡INICIALIZACIÓN COMPLETA!';
PRINT '📊 Base de datos DataWarehouseTest lista para testing';
PRINT '';
PRINT 'Tablas creadas:';
PRINT '  • 7 Dimensiones';
PRINT '  • 4 Tablas de Hechos';
PRINT '  • 2 Vistas Analíticas';
PRINT '  • 1 Procedimiento Almacenado';
PRINT '';
PRINT 'Próximos pasos:';
PRINT '  1. Ejecutar: go run main.go';
PRINT '  2. Validar: go run test_suite.go';
PRINT '';
GO