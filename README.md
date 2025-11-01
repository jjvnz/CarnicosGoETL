# 🧠 Proyecto CarnicosGoETL

### *Cárnicos del Caribe S.A.S. – Data Warehouse Completo con 20 KPIs Estratégicos*

---

## 📌 **CONTEXTO ACTUALIZADO DEL PROYECTO**

Este proyecto representa la **transformación digital completa** de **Cárnicos del Caribe S.A.S.**, implementando un **Data Warehouse analítico de última generación** que soporta **20 KPIs estratégicos** para la toma de decisiones ejecutivas.

**Nuevo Enfoque:** Hemos evolucionado de un sistema ETL básico a una **plataforma analítica integral** con modelo estrella optimizado, generación de datos sintéticos realistas y conjunto completo de herramientas para Power BI.

---

## 🏗️ **ARQUITECTURA ACTUALIZADA DE LA SOLUCIÓN**

```
+----------------------------+
|   GENERACIÓN DE DATOS      |
|   02_Generacion_Datos.go   |
| • 1M+ registros realistas  |
| • Distribución Pareto      |
| • Datos temporales coherentes|
+------------+---------------+
             |
             v
+----------------------------+
|   AZURE SQL DATABASE       |
|   Modelo Estrella Ultra    |
| • 7 Dimensiones            |
| • 4 Tablas de Hechos       |
| • Índices Optimizados      |
+------------+---------------+
             |
             v
+----------------------------+
|   CAPA ANALÍTICA COMPLETA  |
| 1. 04_Validacion_Datos.sql |
| 2. 03_Consultas_KPIs.sql   |
| 3. Dax_KPIs_Metas.txt      |
| 4. Dashboard Executivo     |
+----------------------------+
```

**Tecnologías Implementadas:**
- **Backend:** Go 1.23 + SQL Server
- **Base de Datos:** Azure SQL Database
- **BI:** Power BI + DAX
- **Patrones:** Star Schema, Batch Processing, Data Validation

---

## 🗂️ **ESTRUCTURA ACTUAL DEL REPOSITORIO**

```
CarnicosGoETL/
├── 01_Esquema_Estrella.sql          # Modelo estrella base
├── 02_Generacion_Datos.go           # Generador de 1M+ registros
├── 03_Consultas_KPIs.sql            # 20 KPIs en SQL
├── 04_Validacion_Datos.sql          # Validación completa de calidad
├── 05_Crear_indices.sql             # Índices optimizados
├── Dax_KPIs_Metas.txt               # Medidas DAX para Power BI
├── go.mod                           # Dependencias Go
├── go.sum                           # Checksums Go
├── .env.example                     # Variables Azure SQL
└── README.md                        # Documentación principal
```

---

## 📊 **MODELO DE DATOS ACTUALIZADO (ESQUEMA ESTRELLA)**

### **🔹 DIMENSIONES PRINCIPALES**
| Tabla | Registros | Descripción |
|-------|-----------|-------------|
| `Dim_Tiempo` | ~1,100 | Calendario completo 3 años |
| `Dim_Producto` | 2,000 | Catálogo con categorías y marcas |
| `Dim_Cliente` | 50,000 | Base clientes segmentada (A/B/C) |
| `Dim_Sucursal` | 20 | Sucursales región Caribe |
| `Dim_Empleado` | 2,000 | Personal con estructura normalizada |
| `Dim_CanalVenta` | 4 | Canales (Tienda/Web/App/Mayorista) |
| `Dim_EstadoPedido` | 6 | Estados del pedido |

### **🔹 TABLAS DE HECHOS**
| Tabla | Registros | Descripción |
|-------|-----------|-------------|
| `Fact_Ventas` | 894,083 | Transacciones detalladas (89.4%) |
| `Fact_Finanzas` | 720 | Métricas financieras mensuales |
| `Fact_SatisfaccionCliente` | 50,000 | Encuestas NPS (5.0%) |
| `Fact_MetricasWeb` | 72 | KPIs digitales mensuales |

**Total:** **~947,000 registros** + dimensiones

---

## 🎯 **20 KPIs ESTRATÉGICOS IMPLEMENTADOS**

### **💰 VENTAS (6 KPIs)**
1. **Crecimiento Ventas vs Presupuesto** - Meta: 100%
2. **Margen Bruto** - Meta: 25-30%
3. **Ticket Promedio** - Meta: +10% vs año anterior
4. **Eficiencia por Canal** - Meta: Web +15%, Tienda +8%
5. **Productos High-Performer** - Meta: 20% productos = 80% ventas
6. **Cumplimiento Entregas** - Meta: 95% a tiempo

### **💳 FINANZAS (4 KPIs)**
7. **EBITDA Sucursal** - Meta: >15%
8. **Control de Gastos** - Meta: <20% ventas
9. **ROI por Sucursal** - Meta: >25%
10. **Liquidez Mensual** - Meta: Flujo positivo

### **👥 CLIENTES (4 KPIs)**
11. **NPS** - Meta: >50
12. **Retención Clientes** - Meta: 80% anual
13. **Satisfacción por Producto** - Meta: >8/10
14. **Valor Vida del Cliente** - Meta: +15% anual

### **🌐 DIGITAL (3 KPIs)**
15. **Tasa Conversión Digital** - Meta: 4-6%
16. **Crecimiento Tráfico Orgánico** - Meta: +20% mensual
17. **ROI Marketing Digital** - Meta: >300%

### **🏪 OPERACIONES (3 KPIs)**
18. **Eficiencia por Sucursal** - Meta: >$5,000/m²
19. **Rotación Inventario** - Meta: >8 veces anual
20. **Productividad Empleados** - Meta: >$50,000/empleado

---

## ⚡ **EJECUCIÓN RÁPIDA - FLUJO ACTUAL**

### **1. Configuración Inicial**
```bash
git clone https://github.com/jjvnz/CarnicosGoETL.git
cd CarnicosGoETL
cp .env.example .env
# Configurar variables Azure SQL en .env
```

### **2. Despliegue Base de Datos**
```sql
-- Ejecutar en secuencia:
:r 01_Esquema_Estrella.sql
:r 05_Crear_indices.sql
```

### **3. Poblamiento Masivo**
```bash
go run 02_Generacion_Datos.go
```

### **4. Validación y KPIs**
```sql
:r 04_Validacion_Datos.sql      -- ✅ Calidad de datos
:r 03_Consultas_KPIs.sql        -- 📊 KPIs ejecutivos
```

### **5. Power BI Ready**
```powerbi
-- Usar medidas de: Dax_KPIs_Metas.txt
-- Conectar a Azure SQL Database
-- Crear relaciones del modelo estrella
```

---

## 📁 **DESCRIPCIÓN DETALLADA DE ARCHIVOS**

### **`01_Esquema_Estrella.sql`**
- **Modelo estrella completo** con 7 dimensiones y 4 hechos
- **Constraints de integridad** referencial
- **Estructura optimizada** para Power BI

### **`02_Generacion_Datos.go`**
- **Generador de datos sintéticos** en Go
- **Distribuciones realistas** (Pareto, segmentación A/B/C)
- **Batch processing** eficiente con transacciones
- **1M+ registros** con coherencia temporal

### **`03_Consultas_KPIs.sql`**
- **20 KPIs estratégicos** en consultas SQL
- **Métricas calculadas** con estado de cumplimiento
- **Agrupaciones** por tiempo, categoría, región

### **`04_Validacion_Datos.sql`**
- **Validación completa** de calidad de datos
- **Integridad referencial** entre tablas
- **Distribución y coherencia** de datos
- **Resumen ejecutivo** de validación

### **`05_Crear_indices.sql`**
- **Índices optimizados** para consultas
- **Columnstore** para análisis rápido
- **Verificación** de existencia previa

### **`Dax_KPIs_Metas.txt`**
- **Medidas DAX** listas para Power BI
- **Metas configurables** por negocio
- **Estructura modular** para fácil implementación

---

## 🚀 **CARACTERÍSTICAS TÉCNICAS DESTACADAS**

### **✅ Generación de Datos Avanzada**
- **Distribución Pareto** para ventas realistas (80-20)
- **Segmentación cliente** A/B/C (20%/30%/50%)
- **Variación estacional** en métricas financieras
- **Datos temporales coherentes** con feriados colombianos

### **✅ Optimizaciones de Rendimiento**
- **Índices Columnstore** para análisis rápido
- **Batch processing** con transacciones
- **Cache de dimensiones temporales**
- **FILLFACTOR 90%** para optimizar INSERTS

### **✅ Validación Completa**
- **Integridad referencial** entre tablas
- **Coherencia temporal** (fechas de entrega)
- **Calidad de datos** (rangos, valores negativos)
- **Distribución realista** por categorías

---

## 📈 **ENTREGABLES FINALES**

1. **✅ Data Warehouse completo** en Azure SQL
2. **✅ 947,000+ registros** con calidad validada
3. **✅ 20 KPIs estratégicos** implementados
4. **✅ Scripts de generación** reproducibles
5. **✅ Medidas DAX** listas para Power BI
6. **✅ Documentación técnica** completa

---

## 🏆 **BENEFICIOS DE LA IMPLEMENTACIÓN**

- **Tiempo real:** Monitoreo continuo de KPIs estratégicos
- **Toma de decisiones:** Datos confiables para dirección
- **Escalabilidad:** Arquitectura preparada para crecimiento
- **Mantenimiento:** Scripts automatizados y documentados

---

## 🧑‍💻 **AUTOR**

**Juan Villalobos**  
*Arquitecto de Datos - Rol B*  
**📧** [jjvnz.dev@outlook.com](mailto:jjvnz.dev@outlook.com)  
**🌐** [github.com/jjvnz](https://github.com/jjvnz)  

*"Transformando datos en decisiones estratégicas para Cárnicos del Caribe S.A.S."* 🚀
