package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	_ "github.com/denisenkom/go-mssqldb"
	"github.com/joho/godotenv"
)

// ================== CONFIGURACIÓN DE TESTING ==================
type TestConfig struct {
	Mode             string // "local" o "staging"
	ScaleFactor      float64 // 0.01 = 1% de datos reales
	EnableValidation bool
	EnableProfiling  bool
	MaxExecutionTime time.Duration
}

var testConfig = TestConfig{
	Mode:             "local",
	ScaleFactor:      0.01, // 10,000 registros en lugar de 1M
	EnableValidation: true,
	EnableProfiling:  true,
	MaxExecutionTime: 10 * time.Minute,
}

// ================== SISTEMA DE VALIDACIÓN ==================
type ValidationResult struct {
	TestName    string
	Status      string // PASS, FAIL, WARNING
	Expected    interface{}
	Actual      interface{}
	Message     string
	ExecutionMS int64
}

type TestSuite struct {
	db      *sql.DB
	results []ValidationResult
	startTime time.Time
}

func NewTestSuite(db *sql.DB) *TestSuite {
	return &TestSuite{
		db:        db,
		results:   []ValidationResult{},
		startTime: time.Now(),
	}
}

// ================== TESTS DE INTEGRIDAD REFERENCIAL ==================
func (ts *TestSuite) ValidateReferentialIntegrity(ctx context.Context) {
	log.Println("\n🔍 VALIDANDO INTEGRIDAD REFERENCIAL...")

	tests := []struct {
		name      string
		query     string
		expectZero bool
	}{
		{
			name: "FK Ventas -> Productos",
			query: `SELECT COUNT(*) FROM Fact_Ventas fv 
					LEFT JOIN Dim_Producto dp ON fv.IDProducto = dp.IDProducto 
					WHERE dp.IDProducto IS NULL`,
			expectZero: true,
		},
		{
			name: "FK Ventas -> Clientes",
			query: `SELECT COUNT(*) FROM Fact_Ventas fv 
					LEFT JOIN Dim_Cliente dc ON fv.IDCliente = dc.IDCliente 
					WHERE dc.IDCliente IS NULL`,
			expectZero: true,
		},
		{
			name: "FK Ventas -> Sucursales",
			query: `SELECT COUNT(*) FROM Fact_Ventas fv 
					LEFT JOIN Dim_Sucursal ds ON fv.IDSucursal = ds.IDSucursal 
					WHERE ds.IDSucursal IS NULL`,
			expectZero: true,
		},
		{
			name: "FK Ventas -> Empleados",
			query: `SELECT COUNT(*) FROM Fact_Ventas fv 
					LEFT JOIN Dim_Empleado de ON fv.IDEmpleado = de.IDEmpleado 
					WHERE de.IDEmpleado IS NULL`,
			expectZero: true,
		},
		{
			name: "FK Empleados -> Sucursales",
			query: `SELECT COUNT(*) FROM Dim_Empleado de 
					LEFT JOIN Dim_Sucursal ds ON de.IDSucursal = ds.IDSucursal 
					WHERE ds.IDSucursal IS NULL`,
			expectZero: true,
		},
		{
			name: "FK Ventas -> Tiempo (Venta)",
			query: `SELECT COUNT(*) FROM Fact_Ventas fv 
					LEFT JOIN Dim_Tiempo dt ON fv.IDTiempoVenta = dt.IDTiempo 
					WHERE dt.IDTiempo IS NULL`,
			expectZero: true,
		},
	}

	for _, test := range tests {
		start := time.Now()
		var count int
		err := ts.db.QueryRowContext(ctx, test.query).Scan(&count)
		elapsed := time.Since(start).Milliseconds()

		result := ValidationResult{
			TestName:    test.name,
			Expected:    0,
			Actual:      count,
			ExecutionMS: elapsed,
		}

		if err != nil {
			result.Status = "FAIL"
			result.Message = fmt.Sprintf("Error en query: %v", err)
		} else if test.expectZero && count > 0 {
			result.Status = "FAIL"
			result.Message = fmt.Sprintf("Encontradas %d referencias huérfanas", count)
		} else {
			result.Status = "PASS"
			result.Message = "Integridad referencial OK"
		}

		ts.results = append(ts.results, result)
		ts.printResult(result)
	}
}

// ================== TESTS DE CALIDAD DE DATOS ==================
func (ts *TestSuite) ValidateDataQuality(ctx context.Context) {
	log.Println("\n🔍 VALIDANDO CALIDAD DE DATOS...")

	tests := []struct {
		name      string
		query     string
		threshold float64
		message   string
	}{
		{
			name: "Ventas sin NULLs en campos críticos",
			query: `SELECT COUNT(*) FROM Fact_Ventas 
					WHERE PrecioUnitarioVenta IS NULL 
					   OR CantidadUnidades IS NULL 
					   OR IDProducto IS NULL`,
			threshold: 0,
			message: "NULLs encontrados en campos obligatorios",
		},
		{
			name: "Precios coherentes (Precio > Costo)",
			query: `SELECT COUNT(*) FROM Fact_Ventas 
					WHERE PrecioUnitarioVenta < CostoUnitario`,
			threshold: 0,
			message: "Ventas con precio menor al costo",
		},
		{
			name: "Descuentos razonables (<50%)",
			query: `SELECT COUNT(*) FROM Fact_Ventas 
					WHERE DescuentoUnitario > (PrecioUnitarioVenta * 0.5)`,
			threshold: 0,
			message: "Descuentos mayores al 50%",
		},
		{
			name: "Fechas coherentes (Pedido <= Venta <= Entrega)",
			query: `SELECT COUNT(*) FROM Fact_Ventas fv
					INNER JOIN Dim_Tiempo t1 ON fv.IDTiempoPedido = t1.IDTiempo
					INNER JOIN Dim_Tiempo t2 ON fv.IDTiempoVenta = t2.IDTiempo
					INNER JOIN Dim_Tiempo t3 ON fv.IDTiempoEntrega = t3.IDTiempo
					WHERE t1.Fecha > t2.Fecha OR t2.Fecha > t3.Fecha`,
			threshold: 0,
			message: "Fechas en orden incorrecto",
		},
		{
			name: "Clientes activos representan >80%",
			query: `SELECT 
					(SELECT COUNT(*) FROM Dim_Cliente WHERE ClienteActivo = 0) * 100.0 / 
					(SELECT COUNT(*) FROM Dim_Cliente)`,
			threshold: 20,
			message: "Demasiados clientes inactivos",
		},
		{
			name: "Productos activos representan >70%",
			query: `SELECT 
					(SELECT COUNT(*) FROM Dim_Producto WHERE Activo = 0) * 100.0 / 
					(SELECT COUNT(*) FROM Dim_Producto)`,
			threshold: 30,
			message: "Demasiados productos inactivos",
		},
		{
			name: "Satisfacción promedio entre 6-9",
			query: `SELECT AVG(CAST(PuntuacionGeneral AS FLOAT)) 
					FROM Fact_SatisfaccionCliente`,
			threshold: 0, // Validación especial
			message: "Promedio fuera de rango esperado",
		},
	}

	for _, test := range tests {
		start := time.Now()
		var value float64
		err := ts.db.QueryRowContext(ctx, test.query).Scan(&value)
		elapsed := time.Since(start).Milliseconds()

		result := ValidationResult{
			TestName:    test.name,
			Expected:    test.threshold,
			Actual:      value,
			ExecutionMS: elapsed,
		}

		if err != nil {
			result.Status = "FAIL"
			result.Message = fmt.Sprintf("Error: %v", err)
		} else if test.name == "Satisfacción promedio entre 6-9" {
			if value >= 6.0 && value <= 9.0 {
				result.Status = "PASS"
				result.Message = fmt.Sprintf("Promedio OK: %.2f", value)
			} else {
				result.Status = "WARNING"
				result.Message = fmt.Sprintf("Promedio fuera de rango: %.2f", value)
			}
		} else if value > test.threshold {
			result.Status = "WARNING"
			result.Message = fmt.Sprintf("%s (%.0f registros/porcentaje)", test.message, value)
		} else {
			result.Status = "PASS"
			result.Message = "Calidad OK"
		}

		ts.results = append(ts.results, result)
		ts.printResult(result)
	}
}

// ================== TESTS DE VOLUMEN Y DISTRIBUCIÓN ==================
func (ts *TestSuite) ValidateDataDistribution(ctx context.Context) {
	log.Println("\n📊 VALIDANDO DISTRIBUCIÓN DE DATOS...")

	queries := []struct {
		name  string
		query string
	}{
		{
			name:  "Distribución de Ventas por Categoría",
			query: `SELECT dp.Categoria, COUNT(*) as Total, 
					AVG(fv.PrecioUnitarioVenta) as PrecioPromedio
					FROM Fact_Ventas fv
					INNER JOIN Dim_Producto dp ON fv.IDProducto = dp.IDProducto
					GROUP BY dp.Categoria
					ORDER BY Total DESC`,
		},
		{
			name:  "Top 5 Clientes por Volumen",
			query: `SELECT TOP 5 dc.NombreCliente, COUNT(*) as Compras,
					SUM(fv.PrecioUnitarioVenta * fv.CantidadUnidades) as TotalGastado
					FROM Fact_Ventas fv
					INNER JOIN Dim_Cliente dc ON fv.IDCliente = dc.IDCliente
					GROUP BY dc.NombreCliente
					ORDER BY TotalGastado DESC`,
		},
		{
			name:  "Ventas por Canal",
			query: `SELECT cv.NombreCanal, COUNT(*) as Transacciones
					FROM Fact_Ventas fv
					INNER JOIN Dim_CanalVenta cv ON fv.IDCanal = cv.IDCanal
					GROUP BY cv.NombreCanal
					ORDER BY Transacciones DESC`,
		},
		{
			name:  "Resumen de Tablas",
			query: `SELECT 
					'Dim_Producto' as Tabla, COUNT(*) as Registros FROM Dim_Producto
					UNION ALL SELECT 'Dim_Cliente', COUNT(*) FROM Dim_Cliente
					UNION ALL SELECT 'Dim_Sucursal', COUNT(*) FROM Dim_Sucursal
					UNION ALL SELECT 'Dim_Empleado', COUNT(*) FROM Dim_Empleado
					UNION ALL SELECT 'Dim_Tiempo', COUNT(*) FROM Dim_Tiempo
					UNION ALL SELECT 'Fact_Ventas', COUNT(*) FROM Fact_Ventas
					UNION ALL SELECT 'Fact_Finanzas', COUNT(*) FROM Fact_Finanzas
					UNION ALL SELECT 'Fact_SatisfaccionCliente', COUNT(*) FROM Fact_SatisfaccionCliente
					UNION ALL SELECT 'Fact_MetricasWeb', COUNT(*) FROM Fact_MetricasWeb`,
		},
	}

	for _, q := range queries {
		start := time.Now()
		rows, err := ts.db.QueryContext(ctx, q.query)
		elapsed := time.Since(start).Milliseconds()

		result := ValidationResult{
			TestName:    q.name,
			ExecutionMS: elapsed,
		}

		if err != nil {
			result.Status = "FAIL"
			result.Message = fmt.Sprintf("Error: %v", err)
		} else {
			result.Status = "PASS"
			result.Message = "Distribución calculada correctamente"
			
			log.Printf("\n  📋 %s:", q.name)
			cols, _ := rows.Columns()
			
			for rows.Next() {
				values := make([]interface{}, len(cols))
				valuePtrs := make([]interface{}, len(cols))
				for i := range values {
					valuePtrs[i] = &values[i]
				}
				rows.Scan(valuePtrs...)
				
				line := "     "
				for i, col := range cols {
					val := values[i]
					switch v := val.(type) {
					case []byte:
						line += fmt.Sprintf("%s: %s  ", col, string(v))
					case int64:
						line += fmt.Sprintf("%s: %d  ", col, v)
					case float64:
						line += fmt.Sprintf("%s: %.2f  ", col, v)
					default:
						line += fmt.Sprintf("%s: %v  ", col, v)
					}
				}
				log.Println(line)
			}
			rows.Close()
		}

		ts.results = append(ts.results, result)
	}
}

// ================== TESTS DE RENDIMIENTO ==================
func (ts *TestSuite) ValidatePerformance(ctx context.Context) {
	log.Println("\n⚡ VALIDANDO RENDIMIENTO DE QUERIES...")

	queries := []struct {
		name          string
		query         string
		maxTimeMS     int64
		expectedRows  int
	}{
		{
			name: "Query Ventas Mensuales",
			query: `SELECT dt.Anio, dt.Mes, 
					COUNT(*) as Ventas,
					SUM(fv.PrecioUnitarioVenta * fv.CantidadUnidades) as Total
					FROM Fact_Ventas fv
					INNER JOIN Dim_Tiempo dt ON fv.IDTiempoVenta = dt.IDTiempo
					GROUP BY dt.Anio, dt.Mes
					ORDER BY dt.Anio, dt.Mes`,
			maxTimeMS: 5000,
			expectedRows: 36, // 3 años
		},
		{
			name: "Query Top Productos",
			query: `SELECT TOP 10 dp.NombreProducto, 
					COUNT(*) as Ventas,
					SUM(fv.CantidadUnidades) as UnidadesVendidas
					FROM Fact_Ventas fv
					INNER JOIN Dim_Producto dp ON fv.IDProducto = dp.IDProducto
					GROUP BY dp.NombreProducto
					ORDER BY Ventas DESC`,
			maxTimeMS: 3000,
			expectedRows: 10,
		},
		{
			name: "Query Métricas por Sucursal",
			query: `SELECT ds.NombreSucursal, ds.Ciudad,
					COUNT(fv.IDVenta) as TotalVentas,
					AVG(fv.PrecioUnitarioVenta) as PrecioPromedio,
					SUM(fv.CantidadUnidades) as UnidadesTotales
					FROM Dim_Sucursal ds
					LEFT JOIN Fact_Ventas fv ON ds.IDSucursal = fv.IDSucursal
					GROUP BY ds.NombreSucursal, ds.Ciudad
					ORDER BY TotalVentas DESC`,
			maxTimeMS: 4000,
			expectedRows: 20,
		},
	}

	for _, q := range queries {
		start := time.Now()
		rows, err := ts.db.QueryContext(ctx, q.query)
		elapsed := time.Since(start).Milliseconds()

		result := ValidationResult{
			TestName:    q.name,
			Expected:    q.maxTimeMS,
			Actual:      elapsed,
			ExecutionMS: elapsed,
		}

		if err != nil {
			result.Status = "FAIL"
			result.Message = fmt.Sprintf("Error: %v", err)
		} else {
			rowCount := 0
			for rows.Next() {
				rowCount++
			}
			rows.Close()

			if elapsed > q.maxTimeMS {
				result.Status = "WARNING"
				result.Message = fmt.Sprintf("Query lento: %dms (límite: %dms)", elapsed, q.maxTimeMS)
			} else {
				result.Status = "PASS"
				result.Message = fmt.Sprintf("Performance OK: %dms (%d filas)", elapsed, rowCount)
			}
		}

		ts.results = append(ts.results, result)
		ts.printResult(result)
	}
}

// ================== GENERADOR DE REPORTES ==================
func (ts *TestSuite) GenerateReport() {
	duration := time.Since(ts.startTime)
	
	passed := 0
	failed := 0
	warnings := 0
	
	for _, r := range ts.results {
		switch r.Status {
		case "PASS":
			passed++
		case "FAIL":
			failed++
		case "WARNING":
			warnings++
		}
	}
	
	log.Println("\n" + strings.Repeat("=", 80))
	log.Println("📊 REPORTE FINAL DE TESTING")
	log.Println(strings.Repeat("=", 80))
	log.Printf("⏱️  Duración total: %s\n", duration.Round(time.Second))
	log.Printf("📈 Tests ejecutados: %d\n", len(ts.results))
	log.Printf("✅ PASS: %d\n", passed)
	log.Printf("⚠️  WARNING: %d\n", warnings)
	log.Printf("❌ FAIL: %d\n", failed)
	
	if failed > 0 {
		log.Println("\n❌ TESTS FALLIDOS:")
		for _, r := range ts.results {
			if r.Status == "FAIL" {
				log.Printf("   • %s: %s\n", r.TestName, r.Message)
			}
		}
	}
	
	if warnings > 0 {
		log.Println("\n⚠️  WARNINGS:")
		for _, r := range ts.results {
			if r.Status == "WARNING" {
				log.Printf("   • %s: %s\n", r.TestName, r.Message)
			}
		}
	}
	
	log.Println(strings.Repeat("=", 80))
	
	if failed == 0 && warnings == 0 {
		log.Println("🎉 ¡TODOS LOS TESTS PASARON! Sistema listo para producción.")
	} else if failed == 0 {
		log.Println("✅ Tests completados con warnings menores. Revisar antes de producción.")
	} else {
		log.Println("❌ TESTS FALLIDOS. NO PROCEDER A PRODUCCIÓN.")
	}
	
	// Guardar reporte en archivo
	ts.saveReportToFile()
}

func (ts *TestSuite) saveReportToFile() {
	filename := fmt.Sprintf("test_report_%s.txt", time.Now().Format("20060102_150405"))
	file, err := os.Create(filename)
	if err != nil {
		log.Printf("⚠️  No se pudo crear archivo de reporte: %v\n", err)
		return
	}
	defer file.Close()
	
	fmt.Fprintf(file, "REPORTE DE TESTING - DATA WAREHOUSE\n")
	fmt.Fprintf(file, "Generado: %s\n\n", time.Now().Format("2006-01-02 15:04:05"))
	
	for _, r := range ts.results {
		fmt.Fprintf(file, "[%s] %s\n", r.Status, r.TestName)
		fmt.Fprintf(file, "  Mensaje: %s\n", r.Message)
		fmt.Fprintf(file, "  Tiempo: %dms\n\n", r.ExecutionMS)
	}
	
	log.Printf("📄 Reporte guardado en: %s\n", filename)
}

func (ts *TestSuite) printResult(r ValidationResult) {
	icon := "❓"
	switch r.Status {
	case "PASS":
		icon = "✅"
	case "FAIL":
		icon = "❌"
	case "WARNING":
		icon = "⚠️"
	}
	log.Printf("%s %s (%dms) - %s\n", icon, r.TestName, r.ExecutionMS, r.Message)
}

// ================== MAIN DE TESTING ==================
func main() {
	if err := godotenv.Load(".env.test"); err != nil {
		log.Println("⚠️  No se cargó .env.test, usando .env principal")
		godotenv.Load()
	}

	server := os.Getenv("AZURE_SQL_SERVER")
	port := os.Getenv("AZURE_SQL_PORT")
	user := os.Getenv("AZURE_SQL_USER")
	password := os.Getenv("AZURE_SQL_PASSWORD")
	database := os.Getenv("AZURE_SQL_DATABASE")

	connString := fmt.Sprintf("server=%s;port=%s;user id=%s;password=%s;database=%s;encrypt=true",
		server, port, user, password, database)

	db, err := sql.Open("sqlserver", connString)
	if err != nil {
		log.Fatalf("❌ Error de conexión: %v", err)
	}
	defer db.Close()

	ctx, cancel := context.WithTimeout(context.Background(), testConfig.MaxExecutionTime)
	defer cancel()

	if err := db.PingContext(ctx); err != nil {
		log.Fatalf("❌ No se pudo conectar: %v", err)
	}

	log.Println("🧪 INICIANDO SUITE DE TESTING")
	log.Printf("📊 Modo: %s | Factor de escala: %.2f%%\n", 
		testConfig.Mode, testConfig.ScaleFactor*100)

	suite := NewTestSuite(db)
	
	// Ejecutar todas las validaciones
	suite.ValidateReferentialIntegrity(ctx)
	suite.ValidateDataQuality(ctx)
	suite.ValidateDataDistribution(ctx)
	suite.ValidatePerformance(ctx)
	
	// Generar reporte final
	suite.GenerateReport()
}