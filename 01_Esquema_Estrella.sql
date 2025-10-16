-- ==============================================================
--  ESQUEMA ESTRELLA - CÁRNICOS DEL CARIBE S.A.S.
--  Creado por: Rol B (Ingeniero de Datos) y Rol C (Analista de BI)
--  Fecha: 14 de octubre de 2025
-- ==============================================================

-- DIMENSIONES
CREATE TABLE Dim_Tiempo (
    Fecha DATE PRIMARY KEY,
    Anio INT,
    Mes INT,
    Trimestre INT,
    Dia INT
);

CREATE TABLE Dim_Producto (
    IDProducto INT IDENTITY(1,1) PRIMARY KEY,
    Nombre NVARCHAR(200),
    Categoria NVARCHAR(100),
    Subcategoria NVARCHAR(100)
);

CREATE TABLE Dim_Cliente (
    IDCliente INT IDENTITY(1,1) PRIMARY KEY,
    Nombre NVARCHAR(200),
    TipoCliente NVARCHAR(50),
    Segmento NVARCHAR(50),
    FechaAlta DATE
);

CREATE TABLE Dim_Sucursal (
    IDSucursal INT IDENTITY(1,1) PRIMARY KEY,
    NombreSucursal NVARCHAR(150),
    Ciudad NVARCHAR(100),
    Region NVARCHAR(100),
    TipoSucursal NVARCHAR(50)
);

CREATE TABLE Dim_Empleado (
    IDEmpleado INT IDENTITY(1,1) PRIMARY KEY,
    NombreEmpleado NVARCHAR(200),
    Cargo NVARCHAR(100),
    IDSucursal INT,
    CONSTRAINT FK_Empleado_Sucursal FOREIGN KEY (IDSucursal) REFERENCES Dim_Sucursal(IDSucursal)
);

-- HECHOS
CREATE TABLE Fact_Ventas (
    IDVenta BIGINT IDENTITY(1,1) PRIMARY KEY,
    IDProducto INT NOT NULL,
    IDCliente INT NOT NULL,
    IDSucursal INT NOT NULL,
    IDEmpleado INT NULL,
    Fecha DATE NOT NULL,
    Unidades INT,
    Precio DECIMAL(18,2),
    Costo DECIMAL(18,2),
    CONSTRAINT FK_Ventas_Producto FOREIGN KEY (IDProducto) REFERENCES Dim_Producto(IDProducto),
    CONSTRAINT FK_Ventas_Cliente FOREIGN KEY (IDCliente) REFERENCES Dim_Cliente(IDCliente),
    CONSTRAINT FK_Ventas_Sucursal FOREIGN KEY (IDSucursal) REFERENCES Dim_Sucursal(IDSucursal),
    CONSTRAINT FK_Ventas_Empleado FOREIGN KEY (IDEmpleado) REFERENCES Dim_Empleado(IDEmpleado),
    CONSTRAINT FK_Ventas_Tiempo FOREIGN KEY (Fecha) REFERENCES Dim_Tiempo(Fecha)
);

CREATE TABLE Fact_Pedidos (
    IDPedido BIGINT IDENTITY(1,1) PRIMARY KEY,
    IDVenta BIGINT,
    FechaPedido DATE,
    FechaEntrega DATE,
    Completo BIT,
    CONSTRAINT FK_Pedido_Venta FOREIGN KEY (IDVenta) REFERENCES Fact_Ventas(IDVenta)
);

CREATE TABLE Fact_Finanzas (
    Periodo NVARCHAR(20) PRIMARY KEY,
    Anio INT,
    Trimestre INT,
    VentasTotales DECIMAL(18,2),
    CostosTotales DECIMAL(18,2),
    UtilidadNeta DECIMAL(18,2),
    Depreciaciones DECIMAL(18,2),
    Amortizaciones DECIMAL(18,2)
    -- NOTA: La relación con Dim_Tiempo por 'Anio' se gestiona en Power BI,
    -- ya que 'Anio' no es una clave única en Dim_Tiempo.
);

CREATE TABLE Fact_Encuestas (
    IDEncuesta BIGINT IDENTITY(1,1) PRIMARY KEY,
    IDCliente INT NOT NULL,
    Fecha DATE,
    Puntuacion INT, -- 0-10
    Comentario NVARCHAR(500) NULL,
    CONSTRAINT FK_Encuesta_Cliente FOREIGN KEY (IDCliente) REFERENCES Dim_Cliente(IDCliente),
    CONSTRAINT FK_Encuesta_Tiempo FOREIGN KEY (Fecha) REFERENCES Dim_Tiempo(Fecha)
);

CREATE TABLE Fact_WebTraffic (
    IDVisita BIGINT IDENTITY(1,1) PRIMARY KEY,
    Fecha DATE,
    Sesiones INT,
    Conversiones INT,
    Canal NVARCHAR(100), -- e.g. "Web", "Mobile", "Social"
    CONSTRAINT FK_WebTraffic_Tiempo FOREIGN KEY (Fecha) REFERENCES Dim_Tiempo(Fecha)
);
