# 🧠 Proyecto CarnicosGoETL

### *Cárnicos del Caribe S.A.S. – Generación, Validación y Análisis de Datos para KPIs Estratégicos*

---

## 📌 **Contexto del Proyecto**

Este proyecto forma parte de la transformación digital de **Cárnicos del Caribe S.A.S.**, una empresa dedicada a la distribución de productos cárnicos en la región Caribe.
El objetivo general es **diseñar y poblar un sistema de información analítico (Data Warehouse)** que soporte los **20 KPIs estratégicos definidos por el Rol A (Dirección de Análisis)**, permitiendo obtener visibilidad integral sobre:

* Desempeño comercial y rentabilidad.
* Comportamiento y retención de clientes.
* Eficiencia operativa y logística.
* Rendimiento financiero y digital.

Como Ingeniero de Datos (Rol B), mi responsabilidad fue **diseñar el modelo estrella, generar datos sintéticos realistas, asegurar su calidad y entregar scripts reproducibles en Go y SQL listos para Azure SQL Database.**

---

## 🧩 **Arquitectura de la Solución**

```
+---------------------------+
| Generación de Datos (Go)  |
| Faker + Azure SQL Driver  |
+------------+--------------+
             |
             v
+---------------------------+
| Azure SQL Database        |
| Modelo Estrella (9+ Tablas)|
+------------+--------------+
             |
             v
+---------------------------+
| Validación y KPIs (SQL)   |
| Consultas + Control Calidad|
+---------------------------+
```

**Componentes principales:**

* **Lenguaje:** Go 1.23 + SQL Server Dialect
* **Bibliotecas:**

  * `github.com/bxcodec/faker/v4` → generación de datos sintéticos
  * `github.com/joho/godotenv` → manejo de credenciales
  * `_ "github.com/denisenkom/go-mssqldb"` → driver para Azure SQL
* **Almacenamiento:** Azure SQL Database
* **Modelo:** Esquema Estrella con 4 dimensiones y 5 hechos

---

## 🗂️ **Estructura del Repositorio**

```
.
├── 01_Esquema_Estrella.sql      # Definición de tablas y relaciones
├── 02_Generacion_Datos.go       # Generador de datos sintéticos (~1M registros)
├── 03_Consultas_KPIs.sql        # Consultas para KPIs estratégicos
├── 04_Validacion_Datos.sql      # Validaciones de volumen, coherencia y distribución
├── .env.example                 # Variables de entorno (conexión Azure)
└── README.md                    # Documentación del proyecto
```

---

## 📊 **Modelo de Datos y Distribución**

| Tabla                | Tipo      | Descripción                          |      Registros |
| :------------------- | :-------- | :----------------------------------- | -------------: |
| `Dim_Producto`       | Dimensión | Catálogo de productos                |            200 |
| `Dim_Cliente`        | Dimensión | Clientes activos                     |          5 000 |
| `Dim_Sucursal`       | Dimensión | Tiendas Caribe                       |             20 |
| `Dim_Empleado`       | Dimensión | Personal operativo                   |            200 |
| `Fact_Ventas`        | Hecho     | Transacciones históricas             |        850 000 |
| `Fact_Pedidos`       | Hecho     | Pedidos y entregas                   |        100 000 |
| `Fact_Finanzas`      | Hecho     | Indicadores financieros trimestrales |             24 |
| `Fact_Encuestas`     | Hecho     | Puntuaciones NPS de clientes         |          5 000 |
| `Fact_WebTraffic`    | Hecho     | Tráfico y conversiones digitales     |          1 000 |
| **Total aproximado** |           |                                      | **~1 000 000** |

---

## ⚙️ **Ejecución**

### 1. Configurar entorno

```bash
git clone https://github.com/jjvnz/rolb-ingenierodatos-go.git
cd rolb-ingenierodatos-go
cp .env.example .env
# Editar credenciales Azure SQL
```

### 2. Crear modelo en Azure SQL

Ejecutar en Azure Data Studio o portal:

```sql
:r 01_Esquema_Estrella.sql
```

### 3. Generar datos sintéticos

```bash
go mod init entregables_rolb
go get github.com/bxcodec/faker/v4 github.com/joho/godotenv github.com/denisenkom/go-mssqldb
go run 02_Generacion_Datos.go
```

### 4. Validar calidad de datos

```sql
:r 04_Validacion_Datos.sql
```

### 5. Calcular KPIs

```sql
:r 03_Consultas_KPIs.sql
```

---

## 🚀 **KPIs Cubiertos (Rol A – Toro)**

**Comerciales:** Ventas totales, ticket promedio, volumen por trimestre, crecimiento interanual.
**Rentabilidad:** Margen por sucursal, utilidad neta, EBITDA.
**Clientes:** Retención, nuevos clientes, NPS.
**Operativos:** Cumplimiento de pedidos, tiempo de entrega, productividad por empleado.
**Digitales:** Tasa de conversión digital, sesiones por canal.

> ✅ Los datos generados soportan los 20 KPIs del Rol A con coherencia temporal, financiera y de clientes.

---

## 📈 **Resultados Esperados**

* Dataset de ~1 M registros con consistencia referencial validada.
* Distribución realista por año, categoría, tipo de cliente y ciudad.
* Datos suficientes para dashboards y análisis avanzados de BI.

---

## 🧑‍💻 **Autor**

**Juan Villalobos**
Ingeniero de Datos – Rol B
Proyecto Formativo “Cárnicos del Caribe S.A.S.”
📧 [[jjvnz.dev@outlook.com](mailto:jjvnz.dev@outlook.com)] | 🌐 **github.com/jjvnz**
