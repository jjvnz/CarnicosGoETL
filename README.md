# CarnicosGoETL

Analytical Data Warehouse for Cárnicos del Caribe S.A.S. with star schema, automated data generation, and testing system.

## Description

Complete Data Warehouse system including:
- Star schema with 7 dimensions and 4 fact tables
- 1M+ realistic synthetic records generator
- 20 strategic KPIs for business analysis
- Pre-production automated testing suite
- DAX measures for Power BI

## Technologies

- **Backend**: Go 1.25.2
- **Database**: Azure SQL Database / SQL Server 2022
- **Testing**: Docker + Go Test Suite
- **BI**: Power BI + DAX

## Project Structure

```
entregable-v2/
├── 01_Esquema_Estrella.sql       # Star schema DDL
├── 02_Generacion_Datos.go        # Data generator (Go)
├── 03_Consultas_KPIs.sql         # 20 strategic KPIs
├── 04_Validacion_Datos.sql       # Quality validations
├── 05_Crear_Indices.sql          # Optimized indexes
├── Dax_KPIs_Metas.txt            # DAX measures for Power BI
├── go.mod
└── test-suite/                   # Testing system
    ├── test_suite.go
    ├── docker-compose.test.yml
    ├── quick-start.sh
    └── RESUMEN_EJECUTIVO.md
```

## Data Model

### Dimensions (7)
- **Dim_Tiempo**: 1,100 records (3 years, Colombian holidays)
- **Dim_Producto**: 2,000 records (categories, brands)
- **Dim_Cliente**: 50,000 records (A/B/C segmentation)
- **Dim_Sucursal**: 20 records (Caribbean region)
- **Dim_Empleado**: 2,000 records (FK to Branch)
- **Dim_CanalVenta**: 4 records (Store, Web, App, Wholesale)
- **Dim_EstadoPedido**: 6 records (order lifecycle)

### Fact Tables (4)
- **Fact_Ventas**: 894,083 records (89.4%)
- **Fact_Finanzas**: 720 records (monthly per branch)
- **Fact_SatisfaccionCliente**: 50,000 records (NPS surveys)
- **Fact_MetricasWeb**: 72 records (monthly digital metrics)

**Total: ~1,002,000 records**

## Implemented KPIs (20)

**Sales**: Growth vs Budget, Gross Margin, Average Ticket, Channel Efficiency, High-Performers, Delivery Compliance

**Finance**: Branch EBITDA, Expense Control, ROI, Liquidity

**Customers**: NPS, Retention, Product Satisfaction, Customer Lifetime Value

**Digital**: Conversion Rate, Traffic Growth, Marketing ROI

**Operations**: Branch Efficiency, Inventory Turnover, Employee Productivity

## Installation & Usage

### Prerequisites
- Go 1.25+
- Azure SQL Database or SQL Server 2022
- Docker (for testing)

### Configuration
```bash
# Clone repository
git clone https://github.com/jjvnz/CarnicosGoETL.git
cd CarnicosGoETL/entregable-v2

# Configure environment variables
cp .env.example .env
# Edit .env with Azure SQL credentials
```

### Production Deployment
```bash
# 1. Create schema
sqlcmd -i 01_Esquema_Estrella.sql
sqlcmd -i 05_Crear_Indices.sql

# 2. Generate data
go run 02_Generacion_Datos.go

# 3. Validate
sqlcmd -i 04_Validacion_Datos.sql
sqlcmd -i 03_Consultas_KPIs.sql
```

### Testing (Recommended before production)
```bash
cd test-suite

# Quick test (1K records, 30s)
SCALE_FACTOR=0.001 go test -v

# Full test (1M records, 45min)
SCALE_FACTOR=1.0 go test -v
```

See `test-suite/RESUMEN_EJECUTIVO.md` for complete testing system documentation.

## Technical Features

- **Pareto distribution (80-20)** in sales
- **Customer segmentation** (A: 20%, B: 30%, C: 50%)
- **Seasonal variation** in financials
- **Optimized batch processing** (100 records/batch)
- **Columnstore indexes** for analytics
- **Automated testing** (17+ validations)

## Author

**Juan Villalobos**  
jjvnz.dev@outlook.com  
[github.com/jjvnz](https://github.com/jjvnz)
