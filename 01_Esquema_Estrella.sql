-- ==============================================================
--  MODELO ESTRELLA ULTRA OPTIMIZADO - VERSIÓN CORREGIDA
--  Sin ambigüedades - Power BI Ready
--  Fecha: 31 de Octubre 2025
-- ==============================================================

-- =======================
-- DIMENSIONES MAESTRAS
-- =======================

CREATE TABLE Dim_Tiempo (
    IDTiempo INT PRIMARY KEY,
    Fecha DATE NOT NULL UNIQUE,
    Anio INT NOT NULL,
    Semestre INT NOT NULL,
    Trimestre INT NOT NULL,
    Mes INT NOT NULL,
    NombreMes NVARCHAR(20),
    Dia INT NOT NULL,
    DiaSemana INT NOT NULL,
    NombreDiaSemana NVARCHAR(15),
    NumeroSemana INT,
    EsFinDeSemana BIT,
    EsFeriado BIT DEFAULT 0,
    TrimestreAnio NVARCHAR(10)
);

CREATE TABLE Dim_Producto (
    IDProducto INT PRIMARY KEY,
    SKU NVARCHAR(50) UNIQUE NOT NULL,
    NombreProducto NVARCHAR(200) NOT NULL,
    Categoria NVARCHAR(100) NOT NULL,
    Subcategoria NVARCHAR(100) NOT NULL,
    Marca NVARCHAR(100),
    LineaProducto NVARCHAR(100),
    Activo BIT DEFAULT 1
);

CREATE TABLE Dim_Cliente (
    IDCliente INT PRIMARY KEY,
    CodigoCliente NVARCHAR(20) UNIQUE NOT NULL,
    NombreCliente NVARCHAR(200) NOT NULL,
    TipoCliente NVARCHAR(50) NOT NULL,
    Segmento NVARCHAR(50),
    Ciudad NVARCHAR(100),
    Region NVARCHAR(100),
    FechaRegistro DATE,
    ClienteActivo BIT DEFAULT 1
);

CREATE TABLE Dim_Sucursal (
    IDSucursal INT PRIMARY KEY,
    CodigoSucursal NVARCHAR(10) UNIQUE NOT NULL,
    NombreSucursal NVARCHAR(150) NOT NULL,
    Direccion NVARCHAR(200),
    Ciudad NVARCHAR(100) NOT NULL,
    Region NVARCHAR(100) NOT NULL,
    TipoSucursal NVARCHAR(50) NOT NULL,
    SucursalActiva BIT DEFAULT 1
);

CREATE TABLE Dim_Empleado (
    IDEmpleado INT PRIMARY KEY,
    CodigoEmpleado NVARCHAR(15) UNIQUE NOT NULL,
    NombreEmpleado NVARCHAR(200) NOT NULL,
    Cargo NVARCHAR(100) NOT NULL,
    Departamento NVARCHAR(100),
    -- ✅ CORREGIDO: SOLO IDSucursal como FK (sin datos duplicados)
    IDSucursal INT NOT NULL,
    FechaContratacion DATE,
    EmpleadoActivo BIT DEFAULT 1,
    CONSTRAINT FK_Empleado_Sucursal FOREIGN KEY (IDSucursal) REFERENCES Dim_Sucursal(IDSucursal)
);

CREATE TABLE Dim_CanalVenta (
    IDCanal INT PRIMARY KEY,
    CodigoCanal NVARCHAR(10) UNIQUE NOT NULL,
    NombreCanal NVARCHAR(50) NOT NULL,
    TipoCanal NVARCHAR(30)
);

CREATE TABLE Dim_EstadoPedido (
    IDEstado INT PRIMARY KEY,
    CodigoEstado NVARCHAR(10) UNIQUE NOT NULL,
    DescripcionEstado NVARCHAR(50) NOT NULL,
    EsEstadoFinal BIT DEFAULT 0
);

-- =======================
-- HECHOS PRINCIPALES
-- =======================

CREATE TABLE Fact_Ventas (
    IDVenta BIGINT IDENTITY(1,1) PRIMARY KEY,
    NumeroPedido NVARCHAR(20) UNIQUE NOT NULL,
    
    -- DIMENSIONES DE ROL (Múltiples tiempos)
    IDTiempoVenta INT NOT NULL,
    IDTiempoPedido INT NOT NULL,
    IDTiempoEntrega INT NULL,
    
    -- DIMENSIONES PRINCIPALES
    IDProducto INT NOT NULL,
    IDCliente INT NOT NULL,
    IDSucursal INT NOT NULL,  -- ✅ Sucursal de la venta
    IDEmpleado INT NULL,      -- ✅ Empleado que realizó la venta
    IDCanal INT NOT NULL,
    IDEstadoPedido INT NOT NULL,

    -- MEDIDAS BASE
    CantidadUnidades INT NOT NULL,
    PrecioUnitarioVenta DECIMAL(18,2) NOT NULL,
    CostoUnitario DECIMAL(18,2) NOT NULL,
    DescuentoUnitario DECIMAL(18,2) DEFAULT 0,
    
    -- RESTRICCIONES
    CONSTRAINT FK_Ventas_TiempoVenta FOREIGN KEY (IDTiempoVenta) REFERENCES Dim_Tiempo(IDTiempo),
    CONSTRAINT FK_Ventas_TiempoPedido FOREIGN KEY (IDTiempoPedido) REFERENCES Dim_Tiempo(IDTiempo),
    CONSTRAINT FK_Ventas_TiempoEntrega FOREIGN KEY (IDTiempoEntrega) REFERENCES Dim_Tiempo(IDTiempo),
    CONSTRAINT FK_Ventas_Producto FOREIGN KEY (IDProducto) REFERENCES Dim_Producto(IDProducto),
    CONSTRAINT FK_Ventas_Cliente FOREIGN KEY (IDCliente) REFERENCES Dim_Cliente(IDCliente),
    CONSTRAINT FK_Ventas_Sucursal FOREIGN KEY (IDSucursal) REFERENCES Dim_Sucursal(IDSucursal),
    CONSTRAINT FK_Ventas_Empleado FOREIGN KEY (IDEmpleado) REFERENCES Dim_Empleado(IDEmpleado),
    CONSTRAINT FK_Ventas_Canal FOREIGN KEY (IDCanal) REFERENCES Dim_CanalVenta(IDCanal),
    CONSTRAINT FK_Ventas_Estado FOREIGN KEY (IDEstadoPedido) REFERENCES Dim_EstadoPedido(IDEstado)
);

-- =======================
-- HECHOS AGREGADOS
-- =======================

CREATE TABLE Fact_Finanzas (
    IDTiempo INT NOT NULL,
    IDSucursal INT NOT NULL,
    VentasTotales DECIMAL(18,2) NOT NULL,
    CostosTotales DECIMAL(18,2) NOT NULL,
    GastosOperativos DECIMAL(18,2) NOT NULL,
    UtilidadBruta DECIMAL(18,2) NOT NULL,
    UtilidadNeta DECIMAL(18,2) NOT NULL,
    MargenBrutoPorcentaje DECIMAL(5,2),
    PRIMARY KEY (IDTiempo, IDSucursal),
    CONSTRAINT FK_Finanzas_Tiempo FOREIGN KEY (IDTiempo) REFERENCES Dim_Tiempo(IDTiempo),
    CONSTRAINT FK_Finanzas_Sucursal FOREIGN KEY (IDSucursal) REFERENCES Dim_Sucursal(IDSucursal)
);

CREATE TABLE Fact_SatisfaccionCliente (
    IDEncuesta BIGINT IDENTITY(1,1) PRIMARY KEY,
    IDTiempo INT NOT NULL,
    IDSucursal INT NOT NULL,
    IDCliente INT NOT NULL,
    IDProducto INT NULL,
    PuntuacionServicio INT NOT NULL CHECK (PuntuacionServicio BETWEEN 1 AND 10),
    PuntuacionProducto INT NOT NULL CHECK (PuntuacionProducto BETWEEN 1 AND 10),
    PuntuacionGeneral INT NOT NULL CHECK (PuntuacionGeneral BETWEEN 1 AND 10),
    Recomendaria BIT,
    CONSTRAINT FK_Satisfaccion_Tiempo FOREIGN KEY (IDTiempo) REFERENCES Dim_Tiempo(IDTiempo),
    CONSTRAINT FK_Satisfaccion_Sucursal FOREIGN KEY (IDSucursal) REFERENCES Dim_Sucursal(IDSucursal),
    CONSTRAINT FK_Satisfaccion_Cliente FOREIGN KEY (IDCliente) REFERENCES Dim_Cliente(IDCliente),
    CONSTRAINT FK_Satisfaccion_Producto FOREIGN KEY (IDProducto) REFERENCES Dim_Producto(IDProducto)
);

CREATE TABLE Fact_MetricasWeb (
    IDTiempo INT NOT NULL,
    IDCanal INT NOT NULL,
    SesionesTotales INT NOT NULL,
    UsuariosUnicos INT NOT NULL,
    Conversiones INT NOT NULL,
    TasaConversion DECIMAL(5,2),
    IngresosDigitales DECIMAL(18,2),
    PRIMARY KEY (IDTiempo, IDCanal),
    CONSTRAINT FK_MetricasWeb_Tiempo FOREIGN KEY (IDTiempo) REFERENCES Dim_Tiempo(IDTiempo),
    CONSTRAINT FK_MetricasWeb_Canal FOREIGN KEY (IDCanal) REFERENCES Dim_CanalVenta(IDCanal)
);

-- =======================
-- ÍNDICES OPTIMIZADOS
-- =======================

CREATE INDEX IX_Fact_Ventas_TiempoVenta ON Fact_Ventas(IDTiempoVenta);
CREATE INDEX IX_Fact_Ventas_Producto ON Fact_Ventas(IDProducto);
CREATE INDEX IX_Fact_Ventas_Cliente ON Fact_Ventas(IDCliente);
CREATE INDEX IX_Fact_Ventas_Sucursal ON Fact_Ventas(IDSucursal);
CREATE INDEX IX_Fact_Ventas_Empleado ON Fact_Ventas(IDEmpleado);
CREATE INDEX IX_Fact_Ventas_Estado ON Fact_Ventas(IDEstadoPedido);

-- Índices para dimensiones
CREATE INDEX IX_Dim_Tiempo_Anio_Mes ON Dim_Tiempo(Anio, Mes);
CREATE INDEX IX_Dim_Producto_Categoria ON Dim_Producto(Categoria);
CREATE INDEX IX_Dim_Cliente_Region ON Dim_Cliente(Region);
CREATE INDEX IX_Dim_Empleado_Sucursal ON Dim_Empleado(IDSucursal);

-- Columnstore para mejor rendimiento en Power BI
CREATE CLUSTERED COLUMNSTORE INDEX CCI_Fact_Ventas ON Fact_Ventas;
CREATE CLUSTERED COLUMNSTORE INDEX CCI_Fact_Finanzas ON Fact_Finanzas;

-- =======================
-- CHECKS DE CALIDAD
-- =======================

ALTER TABLE Fact_Ventas 
ADD CONSTRAINT CK_Cantidad_Positiva CHECK (CantidadUnidades > 0),
    CONSTRAINT CK_Precios_No_Negativos CHECK (PrecioUnitarioVenta >= 0 AND CostoUnitario >= 0),
    CONSTRAINT CK_Descuento_Valido CHECK (DescuentoUnitario >= 0 AND DescuentoUnitario <= PrecioUnitarioVenta);

ALTER TABLE Dim_Tiempo
ADD CONSTRAINT CK_Mes_Valido CHECK (Mes BETWEEN 1 AND 12),
    CONSTRAINT CK_Trimestre_Valido CHECK (Trimestre BETWEEN 1 AND 4),
    CONSTRAINT CK_Dia_Valido CHECK (Dia BETWEEN 1 AND 31);