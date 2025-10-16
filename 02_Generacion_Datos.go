package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"math/rand"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/bxcodec/faker/v4"
	_ "github.com/denisenkom/go-mssqldb"
	"github.com/joho/godotenv"
)

const (
	ventasRecords    = 850000
	pedidosRecords   = 100000
	finanzasYears    = 3
	encuestasRecords = 5000
	webMonths        = 36

	dimProductos   = 200
	dimClientes    = 5000
	dimSucursales  = 20
	dimEmpleados   = 200
	dimTiempoAnios = 3

	batchSize = 200 // Reduced from 500 to avoid the 2100 parameter limit
)

func mustEnv(k string) string {
	v := os.Getenv(k)
	if v == "" {
		log.Fatalf("Falta variable de entorno: %s", k)
	}
	return v
}

func main() {
	rand.Seed(time.Now().UnixNano())
	if err := godotenv.Load(); err != nil {
		log.Println("No se cargó .env, se usarán variables del sistema")
	}

	server := mustEnv("AZURE_SQL_SERVER")
	port := mustEnv("AZURE_SQL_PORT")
	user := mustEnv("AZURE_SQL_USER")
	password := mustEnv("AZURE_SQL_PASSWORD")
	database := mustEnv("AZURE_SQL_DATABASE")

	connString := fmt.Sprintf("server=%s;port=%s;user id=%s;password=%s;database=%s;encrypt=true",
		server, port, user, password, database)

	db, err := sql.Open("sqlserver", connString)
	if err != nil {
		log.Fatalf("Error de conexión: %v", err)
	}
	defer db.Close()

	ctx := context.Background()
	if err := db.PingContext(ctx); err != nil {
		log.Fatalf("No se pudo conectar a Azure SQL: %v", err)
	}
	log.Println("✅ Conectado a Azure SQL correctamente")

	// ================= Dimensiones - Etapa 1 (Independientes) =================
	// populateDimEmpleados depends on populateDimSucursales, so we must wait.
	var wg sync.WaitGroup
	wg.Add(3) // Solo 3 dimensiones se pueden poblar en paralelo

	var productoIDs, clienteIDs, sucursalIDs []int

	go func() { defer wg.Done(); productoIDs = populateDimProductos(ctx, db, dimProductos) }()
	go func() { defer wg.Done(); clienteIDs = populateDimClientes(ctx, db, dimClientes) }()
	go func() { defer wg.Done(); sucursalIDs = populateDimSucursales(ctx, db, dimSucursales) }()

	wg.Wait() // Esperar a que las 3 dimensiones independientes terminen.
	// En este punto, `sucursalIDs` está garantizado que está poblado.

	// ================= Dimensiones - Etapa 2 (Con Dependencias) =================
	// Ahora que `sucursalIDs` está listo, podemos poblar los empleados.
	empleadoIDs := populateDimEmpleados(ctx, db, sucursalIDs, dimEmpleados)
	populateDimTiempo(ctx, db) // Dim_Tiempo no tiene dependencias, se puede ejecutar aquí.

	// ================= Hechos =================
	ventaIDs := populateFactVentas(ctx, db, productoIDs, clienteIDs, sucursalIDs, empleadoIDs, ventasRecords)
	populateFactPedidos(ctx, db, ventaIDs, pedidosRecords)
	populateFactFinanzas(ctx, db, finanzasYears)
	populateFactEncuestas(ctx, db, clienteIDs, encuestasRecords)
	populateFactWebTraffic(ctx, db, webMonths)

	log.Println("🎉 Generación completa (~1M registros totales)")
}

// ================== Función genérica batch insert ==================
func insertBatch(ctx context.Context, db *sql.DB, table string, columns []string, rows [][]interface{}) error {
	if len(rows) == 0 {
		return nil
	}
	valueStrings := make([]string, len(rows))
	valueArgs := make([]interface{}, 0, len(rows)*len(columns))
	for i, row := range rows {
		placeholders := make([]string, len(row))
		for j := range row {
			placeholders[j] = fmt.Sprintf("@p%d", i*len(row)+j+1)
		}
		valueStrings[i] = "(" + strings.Join(placeholders, ",") + ")"
		valueArgs = append(valueArgs, row...)
	}
	query := fmt.Sprintf("INSERT INTO %s (%s) VALUES %s",
		table, strings.Join(columns, ","), strings.Join(valueStrings, ","))
	_, err := db.ExecContext(ctx, query, valueArgs...)
	return err
}

// ================== Dimensiones ==================
func populateDimTiempo(ctx context.Context, db *sql.DB) {
	log.Println("Poblando Dim_Tiempo...")
	start := time.Now().AddDate(-dimTiempoAnios, 0, 0)
	end := time.Now()
	rows := [][]interface{}{}
	for d := start; !d.After(end); d = d.AddDate(0, 0, 1) {
		rows = append(rows, []interface{}{d, d.Year(), int(d.Month()), (int(d.Month())-1)/3 + 1, d.Day()})
		if len(rows) == batchSize {
			if err := insertBatch(ctx, db, "Dim_Tiempo", []string{"Fecha", "Anio", "Mes", "Trimestre", "Dia"}, rows); err != nil {
				log.Fatalf("Error insertando Dim_Tiempo: %v", err)
			}
			rows = [][]interface{}{}
		}
	}
	if len(rows) > 0 {
		insertBatch(ctx, db, "Dim_Tiempo", []string{"Fecha", "Anio", "Mes", "Trimestre", "Dia"}, rows)
	}
	log.Println("✔ Dim_Tiempo completada")
}

func populateDimProductos(ctx context.Context, db *sql.DB, n int) []int {
	log.Println("Poblando Dim_Producto...")
	ids := make([]int, 0, n)
	categorias := []string{"Frescos", "Procesados", "Marinos", "Embutidos"}
	rows := [][]interface{}{}
	for i := 0; i < n; i++ {
		rows = append(rows, []interface{}{fmt.Sprintf("Producto %d", i+1), categorias[rand.Intn(len(categorias))], "General"})
		ids = append(ids, i+1)
		if len(rows) == batchSize || i == n-1 {
			if err := insertBatch(ctx, db, "Dim_Producto", []string{"Nombre", "Categoria", "Subcategoria"}, rows); err != nil {
				log.Fatalf("Error insertando producto: %v", err)
			}
			rows = [][]interface{}{}
		}
	}
	log.Println("✔ Dim_Producto completada")
	return ids
}

func populateDimClientes(ctx context.Context, db *sql.DB, n int) []int {
	log.Println("Poblando Dim_Cliente...")
	ids := make([]int, 0, n)
	tipos := []string{"Minorista", "Mayorista", "Corporativo"}
	rows := [][]interface{}{}
	for i := 0; i < n; i++ {
		rows = append(rows, []interface{}{faker.Name(), tipos[rand.Intn(len(tipos))], "SegmentoA", time.Now().AddDate(-rand.Intn(5), -rand.Intn(12), -rand.Intn(28))})
		ids = append(ids, i+1)
		if len(rows) == batchSize || i == n-1 {
			if err := insertBatch(ctx, db, "Dim_Cliente", []string{"Nombre", "TipoCliente", "Segmento", "FechaAlta"}, rows); err != nil {
				log.Fatalf("Error insertando cliente: %v", err)
			}
			rows = [][]interface{}{}
		}
	}
	log.Println("✔ Dim_Cliente completada")
	return ids
}

func populateDimSucursales(ctx context.Context, db *sql.DB, n int) []int {
	log.Println("Poblando Dim_Sucursal...")
	ids := make([]int, 0, n)
	ciudades := []string{"Cartagena", "Barranquilla", "Santa Marta", "Sincelejo"}
	rows := [][]interface{}{}
	for i := 0; i < n; i++ {
		rows = append(rows, []interface{}{fmt.Sprintf("Sucursal %d", i+1), ciudades[i%len(ciudades)], "Caribe", "Tienda"})
		ids = append(ids, i+1)
		if len(rows) == batchSize || i == n-1 {
			if err := insertBatch(ctx, db, "Dim_Sucursal", []string{"NombreSucursal", "Ciudad", "Region", "TipoSucursal"}, rows); err != nil {
				log.Fatalf("Error insertando sucursal: %v", err)
			}
			rows = [][]interface{}{}
		}
	}
	log.Println("✔ Dim_Sucursal completada")
	return ids
}

func populateDimEmpleados(ctx context.Context, db *sql.DB, sucursalIDs []int, n int) []int {
	log.Println("Poblando Dim_Empleado...")
	ids := make([]int, 0, n)
	cargos := []string{"Vendedor", "Cajero", "Repartidor", "Gerente"}
	rows := [][]interface{}{}
	for i := 0; i < n; i++ {
		rows = append(rows, []interface{}{fmt.Sprintf("Empleado %d", i+1), cargos[rand.Intn(len(cargos))], sucursalIDs[rand.Intn(len(sucursalIDs))]})
		ids = append(ids, i+1)
		if len(rows) == batchSize || i == n-1 {
			if err := insertBatch(ctx, db, "Dim_Empleado", []string{"NombreEmpleado", "Cargo", "IDSucursal"}, rows); err != nil {
				log.Fatalf("Error insertando empleado: %v", err)
			}
			rows = [][]interface{}{}
		}
	}
	log.Println("✔ Dim_Empleado completada")
	return ids
}

// ================== Hechos ==================
func populateFactVentas(ctx context.Context, db *sql.DB, productoIDs, clienteIDs, sucursalIDs, empleadoIDs []int, n int) []int {
	log.Printf("Iniciando carga de %d ventas...", n)
	ventaIDs := make([]int, 0, n)
	start := time.Now().AddDate(-dimTiempoAnios, 0, 0)
	rows := [][]interface{}{}
	for i := 0; i < n; i++ {
		fecha := start.AddDate(0, 0, rand.Intn(dimTiempoAnios*365))
		costo := float64(rand.Intn(8000)+300) / 100.0
		precio := costo + float64(rand.Intn(7000)+500)/100.0
		rows = append(rows, []interface{}{
			productoIDs[rand.Intn(len(productoIDs))],
			clienteIDs[rand.Intn(len(clienteIDs))],
			sucursalIDs[rand.Intn(len(sucursalIDs))],
			empleadoIDs[rand.Intn(len(empleadoIDs))],
			fecha, rand.Intn(20) + 1, precio, costo,
		})
		ventaIDs = append(ventaIDs, i+1)
		if len(rows) == batchSize || i == n-1 {
			if err := insertBatch(ctx, db, "Fact_Ventas", []string{"IDProducto", "IDCliente", "IDSucursal", "IDEmpleado", "Fecha", "Unidades", "Precio", "Costo"}, rows); err != nil {
				log.Fatalf("Error insertando venta: %v", err)
			}
			rows = [][]interface{}{}
			if (i+1)%50000 == 0 {
				log.Printf("%d ventas insertadas...", i+1)
			}
		}
	}
	log.Println("✔ Fact_Ventas completado")
	return ventaIDs
}

func populateFactPedidos(ctx context.Context, db *sql.DB, ventaIDs []int, maxPedidos int) {
	log.Printf("Cargando %d pedidos...", maxPedidos)
	rows := [][]interface{}{}
	count := 0
	for _, ventaID := range ventaIDs {
		if count >= maxPedidos {
			break
		}
		if rand.Intn(100) < 90 {
			fechaPedido := time.Now().AddDate(0, -rand.Intn(24), -rand.Intn(28))
			fechaEntrega := fechaPedido.AddDate(0, 0, rand.Intn(10))
			completo := rand.Intn(100) > 5
			rows = append(rows, []interface{}{ventaID, fechaPedido, fechaEntrega, completo})
			count++
			if len(rows) == batchSize || count == maxPedidos {
				if err := insertBatch(ctx, db, "Fact_Pedidos", []string{"IDVenta", "FechaPedido", "FechaEntrega", "Completo"}, rows); err != nil {
					log.Fatalf("Error insertando pedidos: %v", err)
				}
				rows = [][]interface{}{}
			}
		}
	}
	log.Println("✔ Fact_Pedidos completado")
}

func populateFactFinanzas(ctx context.Context, db *sql.DB, years int) {
	log.Printf("Cargando registros financieros por trimestre...")
	currentYear := time.Now().Year()
	rows := [][]interface{}{}
	for y := currentYear - years + 1; y <= currentYear; y++ {
		for q := 1; q <= 4; q++ {
			ventas := float64(rand.Intn(1000000) + 500000)
			costos := ventas * (0.6 + rand.Float64()*0.2)
			utilidad := ventas - costos
			periodo := fmt.Sprintf("%d-Q%d", y, q)
			rows = append(rows, []interface{}{periodo, y, q, ventas, costos, utilidad, utilidad * 0.05, utilidad * 0.03})
			if len(rows) == batchSize || (y == currentYear && q == 4) {
				if err := insertBatch(ctx, db, "Fact_Finanzas", []string{"Periodo", "Anio", "Trimestre", "VentasTotales", "CostosTotales", "UtilidadNeta", "Depreciaciones", "Amortizaciones"}, rows); err != nil {
					log.Fatalf("Error insertando finanzas: %v", err)
				}
				rows = [][]interface{}{}
			}
		}
	}
	log.Println("✔ Fact_Finanzas completado")
}

func populateFactEncuestas(ctx context.Context, db *sql.DB, clienteIDs []int, n int) {
	log.Printf("Generando %d encuestas...", n)
	rows := [][]interface{}{}
	start := time.Now().AddDate(-dimTiempoAnios, 0, 0)
	for i := 0; i < n; i++ {
		fecha := start.AddDate(0, 0, rand.Intn(dimTiempoAnios*365))
		puntuacion := rand.Intn(11)
		comentario := ""
		if rand.Intn(2) == 0 {
			comentario = faker.Sentence()
		}
		rows = append(rows, []interface{}{clienteIDs[rand.Intn(len(clienteIDs))], fecha, puntuacion, comentario})
		if len(rows) == batchSize || i == n-1 {
			if err := insertBatch(ctx, db, "Fact_Encuestas", []string{"IDCliente", "Fecha", "Puntuacion", "Comentario"}, rows); err != nil {
				log.Fatalf("Error insertando encuestas: %v", err)
			}
			rows = [][]interface{}{}
		}
	}
	log.Println("✔ Fact_Encuestas completado")
}

func populateFactWebTraffic(ctx context.Context, db *sql.DB, months int) {
	log.Printf("Generando %d registros de tráfico web...", months)
	start := time.Now().AddDate(-dimTiempoAnios, 0, 0)
	canales := []string{"Web", "Mobile", "Social", "Email"}
	rows := [][]interface{}{}
	for i := 0; i < months; i++ {
		fecha := start.AddDate(0, i, 0)
		sesiones := rand.Intn(10000) + 500
		conversiones := rand.Intn(sesiones/5 + 1)
		canal := canales[rand.Intn(len(canales))]
		rows = append(rows, []interface{}{fecha, sesiones, conversiones, canal})
		if len(rows) == batchSize || i == months-1 {
			if err := insertBatch(ctx, db, "Fact_WebTraffic", []string{"Fecha", "Sesiones", "Conversiones", "Canal"}, rows); err != nil {
				log.Fatalf("Error insertando web traffic: %v", err)
			}
			rows = [][]interface{}{}
		}
	}
	log.Println("✔ Fact_WebTraffic completado")
}
