package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"math"
	"math/rand"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/go-faker/faker/v4"
	_ "github.com/denisenkom/go-mssqldb"
	"github.com/joho/godotenv"
)

// ================== CONFIGURACIÓN ==================
type Config struct {
	VentasRecords       int
	FinanzasYears       int
	SatisfaccionRecords int
	MetricasWebMonths   int
	DimProductos        int
	DimClientes         int
	DimSucursales       int
	DimEmpleados        int
	DimTiempoAnios      int
	BatchSize           int
}

// ================== CONFIGURACIÓN 1M EXACTO ==================
var config = Config{
	VentasRecords:       894_083, // 89.4% - Ajustado para 1M exacto
	FinanzasYears:       3,
	SatisfaccionRecords: 50_000, // 5.0%
	MetricasWebMonths:   36,

	DimProductos:   2_000,  // 0.2%
	DimClientes:    50_000, // 5.0%
	DimSucursales:  20,
	DimEmpleados:   2_000, // 0.2%
	DimTiempoAnios: 3,

	BatchSize: 100, // Reducido de 200 a 100 para evitar límite de 2100 parámetros
}

// ================== CACHE DE TIEMPO ==================
type TiempoCache struct {
	mu    sync.RWMutex
	cache map[string]int // fecha formato "2006-01-02" -> IDTiempo
}

func newTiempoCache() *TiempoCache {
	return &TiempoCache{cache: make(map[string]int)}
}

func (tc *TiempoCache) Get(fecha time.Time) (int, bool) {
	tc.mu.RLock()
	defer tc.mu.RUnlock()
	id, ok := tc.cache[fecha.Format("2006-01-02")]
	return id, ok
}

func (tc *TiempoCache) Set(fecha time.Time, id int) {
	tc.mu.Lock()
	defer tc.mu.Unlock()
	tc.cache[fecha.Format("2006-01-02")] = id
}

// ================== UTILIDADES ==================
func mustEnv(k string) string {
	v := os.Getenv(k)
	if v == "" {
		log.Fatalf("❌ Falta variable de entorno: %s", k)
	}
	return v
}

func validarReferencias(nombre string, ids []int) {
	if len(ids) == 0 {
		log.Fatalf("❌ No hay registros en %s para referenciar", nombre)
	}
	log.Printf("✓ %s: %d registros disponibles", nombre, len(ids))
}

// Distribución Pareto (80-20) para datos realistas
func generarVentaPareto(min, max float64) float64 {
	u := rand.Float64()
	// Transformación inversa de Pareto con alpha=1.16 (aprox 80-20)
	return min + (max-min)*math.Pow(u, 2.5)
}

// ================== FUNCIÓN BATCH INSERT CON TX ==================
func insertBatchTx(ctx context.Context, tx *sql.Tx, table string, columns []string, rows [][]interface{}) error {
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

	_, err := tx.ExecContext(ctx, query, valueArgs...)
	return err
}

// ================== MAIN ==================
func main() {
	rand.Seed(time.Now().UnixNano())

	if err := godotenv.Load(); err != nil {
		log.Println("⚠️  No se cargó .env, usando variables del sistema")
	}

	server := mustEnv("AZURE_SQL_SERVER")
	port := mustEnv("AZURE_SQL_PORT")
	user := mustEnv("AZURE_SQL_USER")
	password := mustEnv("AZURE_SQL_PASSWORD")
	database := mustEnv("AZURE_SQL_DATABASE")

	connString := fmt.Sprintf("server=%s;port=%s;user id=%s;password=%s;database=%s;encrypt=disable",
		server, port, user, password, database)

	db, err := sql.Open("sqlserver", connString)
	if err != nil {
		log.Fatalf("❌ Error de conexión: %v", err)
	}
	defer db.Close()

	ctx := context.Background()
	if err := db.PingContext(ctx); err != nil {
		log.Fatalf("❌ No se pudo conectar a Azure SQL: %v", err)
	}
	log.Println("✅ Conectado a Azure SQL Database")
	log.Printf("📊 Configuración: %d ventas, %d productos, %d clientes\n",
		config.VentasRecords, config.DimProductos, config.DimClientes)

	// ========== FASE 1: DIMENSIONES INDEPENDIENTES ==========
	log.Println("\n🔷 FASE 1: Poblando dimensiones independientes...")
	var wg sync.WaitGroup
	wg.Add(4)

	var productoIDs, clienteIDs, sucursalIDs []int
	tiempoCache := newTiempoCache()

	go func() {
		defer wg.Done()
		productoIDs = populateDimProductos(ctx, db)
	}()
	go func() {
		defer wg.Done()
		clienteIDs = populateDimClientes(ctx, db)
	}()
	go func() {
		defer wg.Done()
		sucursalIDs = populateDimSucursales(ctx, db)
	}()
	go func() {
		defer wg.Done()
		populateDimTiempo(ctx, db, tiempoCache)
	}()

	wg.Wait()

	// Validaciones
	validarReferencias("Dim_Producto", productoIDs)
	validarReferencias("Dim_Cliente", clienteIDs)
	validarReferencias("Dim_Sucursal", sucursalIDs)
	log.Printf("✓ Dim_Tiempo: %d registros en cache\n", len(tiempoCache.cache))

	// ========== FASE 2: DIMENSIONES DEPENDIENTES ==========
	log.Println("\n🔶 FASE 2: Poblando dimensiones dependientes...")
	canalIDs := populateDimCanales(ctx, db)
	estadoIDs := populateDimEstados(ctx, db)
	empleadoIDs := populateDimEmpleados(ctx, db, sucursalIDs) // <-- Usará la función corregida

	validarReferencias("Dim_CanalVenta", canalIDs)
	validarReferencias("Dim_EstadoPedido", estadoIDs)
	validarReferencias("Dim_Empleado", empleadoIDs)

	// ========== FASE 3: TABLAS DE HECHOS ==========
	log.Println("\n🔴 FASE 3: Poblando tablas de hechos...")
	populateFactVentas(ctx, db, productoIDs, clienteIDs, sucursalIDs, empleadoIDs,
		canalIDs, estadoIDs, tiempoCache)
	populateFactFinanzas(ctx, db, sucursalIDs, tiempoCache)
	populateFactSatisfaccion(ctx, db, clienteIDs, productoIDs, sucursalIDs, tiempoCache)
	populateFactMetricasWeb(ctx, db, canalIDs, tiempoCache)

	log.Println("\n🎉 ¡GENERACIÓN COMPLETA DEL DATA WAREHOUSE!")
	log.Printf("📈 Total aproximado: %d registros en todas las tablas\n",
		config.VentasRecords+len(tiempoCache.cache)*config.DimSucursales+
			config.SatisfaccionRecords+config.MetricasWebMonths*len(canalIDs))
}

// ================== DIM_TIEMPO CON CACHE ==================
func populateDimTiempo(ctx context.Context, db *sql.DB, cache *TiempoCache) {
	log.Println("⏳ Poblando Dim_Tiempo...")

	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		log.Fatalf("❌ Error iniciando transacción: %v", err)
	}
	defer tx.Rollback()

	start := time.Now().AddDate(-config.DimTiempoAnios, 0, 0)
	end := time.Now()

	nombresMeses := []string{"Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
		"Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"}
	nombresDias := []string{"Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"}

	// Feriados colombianos fijos (simplificado)
	feriados := map[string]bool{
		"01-01": true, // Año Nuevo
		"05-01": true, // Día del Trabajo
		"07-20": true, // Día de la Independencia
		"08-07": true, // Batalla de Boyacá
		"12-08": true, // Inmaculada Concepción
		"12-25": true, // Navidad
	}

	rows := [][]interface{}{}
	idCounter := 1

	for d := start; !d.After(end); d = d.AddDate(0, 0, 1) {
		esFinDeSemana := d.Weekday() == time.Sunday || d.Weekday() == time.Saturday
		esFeriado := feriados[d.Format("01-02")]
		_, semana := d.ISOWeek()
		semestre := 1
		if int(d.Month()) > 6 {
			semestre = 2
		}

		rows = append(rows, []interface{}{
			idCounter, d, d.Year(), semestre,
			(int(d.Month())-1)/3 + 1, // Trimestre
			int(d.Month()),
			nombresMeses[int(d.Month())-1],
			d.Day(),
			int(d.Weekday()) + 1, // 1=Domingo, 7=Sábado
			nombresDias[d.Weekday()],
			semana,
			esFinDeSemana,
			esFeriado,
			fmt.Sprintf("Q%d-%d", (int(d.Month())-1)/3+1, d.Year()),
		})

		// Guardar en cache
		cache.Set(d, idCounter)
		idCounter++

		if len(rows) == config.BatchSize {
			if err := insertBatchTx(ctx, tx, "Dim_Tiempo", []string{
				"IDTiempo", "Fecha", "Anio", "Semestre", "Trimestre", "Mes", "NombreMes",
				"Dia", "DiaSemana", "NombreDiaSemana", "NumeroSemana", "EsFinDeSemana",
				"EsFeriado", "TrimestreAnio",
			}, rows); err != nil {
				log.Fatalf("❌ Error insertando Dim_Tiempo: %v", err)
			}
			rows = [][]interface{}{}
		}
	}

	if len(rows) > 0 {
		insertBatchTx(ctx, tx, "Dim_Tiempo", []string{
			"IDTiempo", "Fecha", "Anio", "Semestre", "Trimestre", "Mes", "NombreMes",
			"Dia", "DiaSemana", "NombreDiaSemana", "NumeroSemana", "EsFinDeSemana",
			"EsFeriado", "TrimestreAnio",
		}, rows)
	}

	if err := tx.Commit(); err != nil {
		log.Fatalf("❌ Error confirmando transacción: %v", err)
	}

	log.Printf("✔ Dim_Tiempo completada (%d días)\n", idCounter-1)
}

// ================== DIM_PRODUCTO CON DISTRIBUCIÓN REALISTA ==================
func populateDimProductos(ctx context.Context, db *sql.DB) []int {
	log.Println("📦 Poblando Dim_Producto...")

	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		log.Fatalf("❌ Error iniciando transacción: %v", err)
	}
	defer tx.Rollback()

	ids := make([]int, 0, config.DimProductos)
	categorias := []string{"Frescos", "Procesados", "Marinos", "Embutidos"}
	subcategorias := []string{"Premium", "Estándar", "Económico"}
	marcas := []string{"DelCaribe", "FrescoMar", "CarnesSelectas", "Tradición"}

	rows := [][]interface{}{}

	for i := 0; i < config.DimProductos; i++ {
		// 80% de productos activos (Pareto)
		activo := rand.Float64() < 0.8

		rows = append(rows, []interface{}{
			fmt.Sprintf("SKU-%06d", i+1),
			fmt.Sprintf("Producto %s %d", categorias[i%len(categorias)], i+1),
			categorias[i%len(categorias)], // Distribución equitativa
			subcategorias[rand.Intn(len(subcategorias))],
			marcas[rand.Intn(len(marcas))],
			"Línea Principal",
			activo,
		})
		ids = append(ids, i+1)

		if len(rows) == config.BatchSize || i == config.DimProductos-1 {
			if err := insertBatchTx(ctx, tx, "Dim_Producto", []string{
				"SKU", "NombreProducto", "Categoria", "Subcategoria", "Marca", "LineaProducto", "Activo",
			}, rows); err != nil {
				log.Fatalf("❌ Error insertando producto: %v", err)
			}
			rows = [][]interface{}{}
		}
	}

	tx.Commit()
	log.Printf("✔ Dim_Producto completada (%d registros)\n", config.DimProductos)
	return ids
}

// ================== DIM_CLIENTE CON SEGMENTACIÓN ==================
func populateDimClientes(ctx context.Context, db *sql.DB) []int {
	log.Println("👥 Poblando Dim_Cliente...")

	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		log.Fatalf("❌ Error iniciando transacción: %v", err)
	}
	defer tx.Rollback()

	ids := make([]int, 0, config.DimClientes)
	tipos := []string{"Minorista", "Mayorista", "Corporativo"}
	ciudades := []string{"Cartagena", "Barranquilla", "Santa Marta", "Sincelejo", "Montería"}

	rows := [][]interface{}{}

	for i := 0; i < config.DimClientes; i++ {
		// Segmento A: 20%, B: 30%, C: 50%
		var segmento string
		prob := rand.Float64()
		if prob < 0.2 {
			segmento = "A"
		} else if prob < 0.5 {
			segmento = "B"
		} else {
			segmento = "C"
		}

		rows = append(rows, []interface{}{
			fmt.Sprintf("CLI-%06d", i+1),
			faker.Name(),
			tipos[rand.Intn(len(tipos))],
			segmento,
			ciudades[rand.Intn(len(ciudades))],
			"Caribe",
			time.Now().AddDate(-rand.Intn(5), -rand.Intn(12), -rand.Intn(28)),
			rand.Float64() < 0.95, // 95% activos
		})
		ids = append(ids, i+1)

		if len(rows) == config.BatchSize || i == config.DimClientes-1 {
			if err := insertBatchTx(ctx, tx, "Dim_Cliente", []string{
				"CodigoCliente", "NombreCliente", "TipoCliente", "Segmento", "Ciudad",
				"Region", "FechaRegistro", "ClienteActivo",
			}, rows); err != nil {
				log.Fatalf("❌ Error insertando cliente: %v", err)
			}
			rows = [][]interface{}{}
		}
	}

	tx.Commit()
	log.Printf("✔ Dim_Cliente completada (%d registros)\n", config.DimClientes)
	return ids
}

// ================== DIM_SUCURSAL ==================
func populateDimSucursales(ctx context.Context, db *sql.DB) []int {
	log.Println("🏪 Poblando Dim_Sucursal...")

	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		log.Fatalf("❌ Error iniciando transacción: %v", err)
	}
	defer tx.Rollback()

	ids := make([]int, 0, config.DimSucursales)
	ciudades := []string{"Cartagena", "Barranquilla", "Santa Marta", "Sincelejo", "Montería"}
	tipos := []string{"Tienda", "Supermercado", "Mayorista"}

	rows := [][]interface{}{}

	for i := 0; i < config.DimSucursales; i++ {
		ciudad := ciudades[i%len(ciudades)] // Distribución equitativa

		rows = append(rows, []interface{}{
			fmt.Sprintf("SUC-%03d", i+1),
			fmt.Sprintf("Sucursal %s %d", ciudad, (i/len(ciudades))+1),
			fmt.Sprintf("Calle %d #%d-%d", rand.Intn(100)+1, rand.Intn(50)+1, rand.Intn(100)+1),
			ciudad,
			"Caribe",
			tipos[rand.Intn(len(tipos))],
			true,
		})
		ids = append(ids, i+1)
	}

	if err := insertBatchTx(ctx, tx, "Dim_Sucursal", []string{
		"CodigoSucursal", "NombreSucursal", "Direccion", "Ciudad", "Region",
		"TipoSucursal", "SucursalActiva",
	}, rows); err != nil {
		log.Fatalf("❌ Error insertando sucursal: %v", err)
	}

	tx.Commit()
	log.Printf("✔ Dim_Sucursal completada (%d registros)\n", config.DimSucursales)
	return ids
}

// ================== DIM_EMPLEADO NORMALIZADO (v3.1 - CORREGIDO) ==================
func populateDimEmpleados(ctx context.Context, db *sql.DB, sucursalIDs []int) []int {
	log.Println("👨‍💼 Poblando Dim_Empleado (estructura normalizada)...")

	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		log.Fatalf("❌ Error iniciando transacción: %v", err)
	}
	defer tx.Rollback()

	ids := make([]int, 0, config.DimEmpleados)
	cargos := []string{"Vendedor", "Cajero", "Repartidor", "Gerente", "Supervisor"}
	departamentos := []string{"Ventas", "Operaciones", "Administración", "Logística"}

	rows := [][]interface{}{}

	for i := 0; i < config.DimEmpleados; i++ {
		// ✅ ESTRUCTURA CORREGIDA - Solo campos que existen en el modelo normalizado
		rows = append(rows, []interface{}{
			// IDEmpleado se auto-genera (IDENTITY), NO se incluye aquí
			fmt.Sprintf("EMP-%05d", i+1),
			faker.Name(),
			cargos[rand.Intn(len(cargos))],
			departamentos[rand.Intn(len(departamentos))],
			sucursalIDs[rand.Intn(len(sucursalIDs))], // IDSucursal (FK)
			time.Now().AddDate(-rand.Intn(10), -rand.Intn(12), -rand.Intn(28)),
			rand.Float64() < 0.92, // EmpleadoActivo
		})

		if len(rows) == config.BatchSize || i == config.DimEmpleados-1 {
			// ✅ COLUMNAS ACTUALIZADAS al modelo normalizado (sin IDEmpleado)
			if err := insertBatchTx(ctx, tx, "Dim_Empleado", []string{
				// "IDEmpleado" se omite porque es IDENTITY
				"CodigoEmpleado",
				"NombreEmpleado",
				"Cargo",
				"Departamento",
				"IDSucursal", // ✅ SOLO FK, no campos duplicados
				"FechaContratacion",
				"EmpleadoActivo",
			}, rows); err != nil {
				log.Fatalf("❌ Error insertando empleado: %v", err)
			}
			rows = [][]interface{}{}
		}
	}

	tx.Commit()
	
	// Recuperar IDs generados
	rows2, err := db.QueryContext(ctx, "SELECT IDEmpleado FROM Dim_Empleado ORDER BY IDEmpleado")
	if err != nil {
		log.Fatalf("❌ Error recuperando IDs de empleados: %v", err)
	}
	defer rows2.Close()
	
	for rows2.Next() {
		var id int
		rows2.Scan(&id)
		ids = append(ids, id)
	}

	log.Printf("✔ Dim_Empleado completada (%d registros) - ESTRUCTURA NORMALIZADA\n", len(ids))
	return ids
}

// ================== DIM_CANALVENTA ==================
func populateDimCanales(ctx context.Context, db *sql.DB) []int {
	log.Println("📱 Poblando Dim_CanalVenta...")

	canales := []struct {
		codigo string
		nombre string
		tipo   string
	}{
		{"TIENDA", "Venta en Tienda", "Físico"},
		{"WEB", "Sitio Web", "Digital"},
		{"MOVIL", "App Móvil", "Digital"},
		{"MAYOR", "Venta Mayorista", "Físico"},
	}

	rows := [][]interface{}{}
	ids := make([]int, len(canales))

	for i, canal := range canales {
		rows = append(rows, []interface{}{canal.codigo, canal.nombre, canal.tipo})
		ids[i] = i + 1
	}

	tx, _ := db.BeginTx(ctx, nil)
	defer tx.Rollback()

	if err := insertBatchTx(ctx, tx, "Dim_CanalVenta", []string{
		"CodigoCanal", "NombreCanal", "TipoCanal",
	}, rows); err != nil {
		log.Fatalf("❌ Error insertando canales: %v", err)
	}

	tx.Commit()
	log.Printf("✔ Dim_CanalVenta completada (%d registros)\n", len(canales))
	return ids
}

// ================== DIM_ESTADOPEDIDO ==================
func populateDimEstados(ctx context.Context, db *sql.DB) []int {
	log.Println("📋 Poblando Dim_EstadoPedido...")

	estados := []struct {
		codigo string
		desc   string
		final  bool
	}{
		{"PEND", "Pendiente", false},
		{"CONF", "Confirmado", false},
		{"PREP", "En Preparación", false},
		{"ENVI", "Enviado", false},
		{"ENTR", "Entregado", true},
		{"CANC", "Cancelado", true},
	}

	rows := [][]interface{}{}
	ids := make([]int, len(estados))

	for i, estado := range estados {
		rows = append(rows, []interface{}{estado.codigo, estado.desc, estado.final})
		ids[i] = i + 1
	}

	tx, _ := db.BeginTx(ctx, nil)
	defer tx.Rollback()

	if err := insertBatchTx(ctx, tx, "Dim_EstadoPedido", []string{
		"CodigoEstado", "DescripcionEstado", "EsEstadoFinal",
	}, rows); err != nil {
		log.Fatalf("❌ Error insertando estados: %v", err)
	}

	tx.Commit()
	log.Printf("✔ Dim_EstadoPedido completada (%d registros)\n", len(estados))
	return ids
}

// ================== FACT_VENTAS CON LOOKUP REAL ==================
func populateFactVentas(ctx context.Context, db *sql.DB, productoIDs, clienteIDs,
	sucursalIDs, empleadoIDs, canalIDs, estadoIDs []int, tiempoCache *TiempoCache) {

	log.Printf("💰 Iniciando carga de %d ventas...\n", config.VentasRecords)

	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		log.Fatalf("❌ Error iniciando transacción: %v", err)
	}
	defer tx.Rollback()

	start := time.Now().AddDate(-config.DimTiempoAnios, 0, 0)
	rows := [][]interface{}{}
	totalVentas := 0.0

	for i := 0; i < config.VentasRecords; i++ {
		// Generar fechas coherentes
		fechaVenta := start.AddDate(0, 0, rand.Intn(config.DimTiempoAnios*365))
		fechaPedido := fechaVenta.AddDate(0, 0, -rand.Intn(3))   // 0-2 días antes
		fechaEntrega := fechaVenta.AddDate(0, 0, rand.Intn(5)+1) // 1-5 días después

		// Buscar IDs desde cache - si no existen, usar la fecha de venta
		idTiempoVenta, ok := tiempoCache.Get(fechaVenta)
		if !ok {
			continue // Saltar si la fecha no está en cache
		}
		
		idTiempoPedido, ok := tiempoCache.Get(fechaPedido)
		if !ok {
			idTiempoPedido = idTiempoVenta // Usar fecha de venta si pedido no está
		}
		
		idTiempoEntrega, ok := tiempoCache.Get(fechaEntrega)
		if !ok {
			idTiempoEntrega = idTiempoVenta // Usar fecha de venta si entrega no está
		}

		// Generar precios con distribución Pareto
		costo := generarVentaPareto(30, 150)
		margen := 1.2 + rand.Float64()*0.8 // Margen 20%-100%
		precio := costo * margen
		descuento := precio * (rand.Float64() * 0.15) // Hasta 15% descuento
		cantidad := rand.Intn(20) + 1

		totalVentas += (precio - descuento) * float64(cantidad)

		rows = append(rows, []interface{}{
			fmt.Sprintf("PED-%08d", i+1),
			idTiempoVenta, idTiempoPedido, idTiempoEntrega,
			productoIDs[rand.Intn(len(productoIDs))],
			clienteIDs[rand.Intn(len(clienteIDs))],
			sucursalIDs[rand.Intn(len(sucursalIDs))],
			empleadoIDs[rand.Intn(len(empleadoIDs))],
			canalIDs[rand.Intn(len(canalIDs))],
			estadoIDs[rand.Intn(len(estadoIDs))],
			cantidad, precio, costo, descuento,
		})

		if len(rows) == config.BatchSize || i == config.VentasRecords-1 {
			if err := insertBatchTx(ctx, tx, "Fact_Ventas", []string{
				"NumeroPedido", "IDTiempoVenta", "IDTiempoPedido", "IDTiempoEntrega",
				"IDProducto", "IDCliente", "IDSucursal", "IDEmpleado", "IDCanal", "IDEstadoPedido",
				"CantidadUnidades", "PrecioUnitarioVenta", "CostoUnitario", "DescuentoUnitario",
			}, rows); err != nil {
				log.Fatalf("❌ Error insertando venta: %v", err)
			}
			rows = [][]interface{}{}
		}

		if (i+1)%100000 == 0 {
			log.Printf("  ⏳ %d ventas insertadas (%.1f%%)...", i+1, float64(i+1)/float64(config.VentasRecords)*100)
		}
	}

	tx.Commit()
	log.Printf("✔ Fact_Ventas completado - Total facturado: $%.2f M\n", totalVentas/1000000)
}

// ================== FACT_FINANZAS MENSUAL ==================
func populateFactFinanzas(ctx context.Context, db *sql.DB, sucursalIDs []int, tiempoCache *TiempoCache) {
	log.Println("💵 Cargando registros financieros mensuales...")

	tx, _ := db.BeginTx(ctx, nil)
	defer tx.Rollback()

	rows := [][]interface{}{}
	start := time.Now().AddDate(-config.FinanzasYears, 0, 0)

	// Generar un registro financiero por mes por sucursal
	for mes := 0; mes < config.FinanzasYears*12; mes++ {
		fechaMes := start.AddDate(0, mes, 0)
		idTiempo, ok := tiempoCache.Get(fechaMes)

		if !ok {
			// Si no existe esa fecha exacta, buscar el primer día del mes
			primerDia := time.Date(fechaMes.Year(), fechaMes.Month(), 1, 0, 0, 0, 0, time.UTC)
			idTiempo, _ = tiempoCache.Get(primerDia)
		}

		for _, idSucursal := range sucursalIDs {
			// Generar métricas financieras realistas
			ventasBase := float64(500000 + rand.Intn(500000))

			// Variación estacional (más ventas en Diciembre, menos en Enero)
			factorEstacional := 1.0
			switch fechaMes.Month() {
			case 12: // Diciembre
				factorEstacional = 1.5
			case 1: // Enero
				factorEstacional = 0.7
			case 6, 7: // Mitad de año
				factorEstacional = 1.2
			}

			ventas := ventasBase * factorEstacional
			costos := ventas * (0.60 + rand.Float64()*0.15) // 60-75% de costos
			gastos := ventas * 0.15                         // 15% gastos operativos
			utilidadBruta := ventas - costos
			utilidadNeta := utilidadBruta - gastos
			margen := (utilidadBruta / ventas) * 100

			rows = append(rows, []interface{}{
				idTiempo, idSucursal, ventas, costos, gastos,
				utilidadBruta, utilidadNeta, margen,
			})

			if len(rows) == config.BatchSize {
				if err := insertBatchTx(ctx, tx, "Fact_Finanzas", []string{
					"IDTiempo", "IDSucursal", "VentasTotales", "CostosTotales",
					"GastosOperativos", "UtilidadBruta", "UtilidadNeta", "MargenBrutoPorcentaje",
				}, rows); err != nil {
					log.Fatalf("❌ Error insertando finanzas: %v", err)
				}
				rows = [][]interface{}{}
			}
		}
	}

	if len(rows) > 0 {
		insertBatchTx(ctx, tx, "Fact_Finanzas", []string{
			"IDTiempo", "IDSucursal", "VentasTotales", "CostosTotales",
			"GastosOperativos", "UtilidadBruta", "UtilidadNeta", "MargenBrutoPorcentaje",
		}, rows)
	}

	tx.Commit()
	totalRegistros := config.FinanzasYears * 12 * len(sucursalIDs)
	log.Printf("✔ Fact_Finanzas completado (%d registros mensuales)\n", totalRegistros)
}

// ================== FACT_SATISFACCION CON DISTRIBUCIÓN NORMAL ==================
func populateFactSatisfaccion(ctx context.Context, db *sql.DB, clienteIDs, productoIDs,
	sucursalIDs []int, tiempoCache *TiempoCache) {

	log.Printf("⭐ Generando %d encuestas de satisfacción...\n", config.SatisfaccionRecords)

	tx, _ := db.BeginTx(ctx, nil)
	defer tx.Rollback()

	rows := [][]interface{}{}
	start := time.Now().AddDate(-2, 0, 0) // Últimos 2 años

	for i := 0; i < config.SatisfaccionRecords; i++ {
		fecha := start.AddDate(0, 0, rand.Intn(730)) // 730 días = 2 años
		idTiempo, ok := tiempoCache.Get(fecha)

		if !ok {
			continue // Saltar si no hay fecha en cache
		}

		// Generar puntuaciones con sesgo positivo (distribución normal centrada en 8)
		puntuacionServicio := generarPuntuacionNPS(8.0, 1.5)
		puntuacionProducto := generarPuntuacionNPS(7.5, 1.8)
		puntuacionGeneral := (puntuacionServicio + puntuacionProducto) / 2

		// Probabilidad de recomendar correlacionada con puntuación general
		recomendaria := puntuacionGeneral >= 7.0

		rows = append(rows, []interface{}{
			idTiempo,
			sucursalIDs[rand.Intn(len(sucursalIDs))],
			clienteIDs[rand.Intn(len(clienteIDs))],
			productoIDs[rand.Intn(len(productoIDs))],
			puntuacionServicio,
			puntuacionProducto,
			int(puntuacionGeneral),
			recomendaria,
		})

		if len(rows) == config.BatchSize || i == config.SatisfaccionRecords-1 {
			if err := insertBatchTx(ctx, tx, "Fact_SatisfaccionCliente", []string{
				"IDTiempo", "IDSucursal", "IDCliente", "IDProducto",
				"PuntuacionServicio", "PuntuacionProducto", "PuntuacionGeneral", "Recomendaria",
			}, rows); err != nil {
				log.Fatalf("❌ Error insertando satisfacción: %v", err)
			}
			rows = [][]interface{}{}
		}
	}

	tx.Commit()
	log.Printf("✔ Fact_SatisfaccionCliente completado (%d registros)\n", config.SatisfaccionRecords)
}

// Función auxiliar para generar puntuaciones NPS realistas
func generarPuntuacionNPS(media, desviacion float64) int {
	// Box-Muller transform para distribución normal
	u1 := rand.Float64()
	u2 := rand.Float64()
	z := math.Sqrt(-2*math.Log(u1)) * math.Cos(2*math.Pi*u2)
	puntuacion := media + z*desviacion

	// Limitar entre 1 y 10
	if puntuacion < 1 {
		return 1
	}
	if puntuacion > 10 {
		return 10
	}
	return int(puntuacion)
}

// ================== FACT_METRICAS_WEB CON TENDENCIAS ==================
func populateFactMetricasWeb(ctx context.Context, db *sql.DB, _ []int, tiempoCache *TiempoCache) {
	log.Printf("🌐 Generando métricas web para %d meses...\n", config.MetricasWebMonths)

	tx, _ := db.BeginTx(ctx, nil)
	defer tx.Rollback()

	rows := [][]interface{}{}
	start := time.Now().AddDate(0, -config.MetricasWebMonths, 0)

	// Solo canales digitales
	canalesDigitales := []int{2, 3} // WEB y MOVIL

	for mes := 0; mes < config.MetricasWebMonths; mes++ {
		fechaMes := start.AddDate(0, mes, 0)
		primerDia := time.Date(fechaMes.Year(), fechaMes.Month(), 1, 0, 0, 0, 0, time.UTC)
		idTiempo, ok := tiempoCache.Get(primerDia)

		if !ok {
			continue
		}

		for _, idCanal := range canalesDigitales {
			// Tendencia creciente: más tráfico en meses recientes
			factorCrecimiento := 1.0 + (float64(mes) / float64(config.MetricasWebMonths) * 0.5)

			sesionesBase := rand.Intn(5000) + 2000
			sesiones := int(float64(sesionesBase) * factorCrecimiento)

			// Usuarios únicos: 60-80% de sesiones
			usuarios := int(float64(sesiones) * (0.6 + rand.Float64()*0.2))

			// Tasa de conversión: 2-8%
			tasaConversionBase := 0.02 + rand.Float64()*0.06
			conversiones := int(float64(sesiones) * tasaConversionBase)

			// Ingresos por conversión: $20-$200
			ticketPromedio := float64(rand.Intn(180) + 20)
			ingresos := float64(conversiones) * ticketPromedio

			tasaConversion := (float64(conversiones) / float64(sesiones)) * 100

			rows = append(rows, []interface{}{
				idTiempo, idCanal, sesiones, usuarios, conversiones,
				tasaConversion, ingresos,
			})

			if len(rows) == config.BatchSize {
				if err := insertBatchTx(ctx, tx, "Fact_MetricasWeb", []string{
					"IDTiempo", "IDCanal", "SesionesTotales", "UsuariosUnicos",
					"Conversiones", "TasaConversion", "IngresosDigitales",
				}, rows); err != nil {
					log.Fatalf("❌ Error insertando métricas web: %v", err)
				}
				rows = [][]interface{}{}
			}
		}
	}

	if len(rows) > 0 {
		insertBatchTx(ctx, tx, "Fact_MetricasWeb", []string{
			"IDTiempo", "IDCanal", "SesionesTotales", "UsuariosUnicos",
			"Conversiones", "TasaConversion", "IngresosDigitales",
		}, rows)
	}

	tx.Commit()
	totalRegistros := config.MetricasWebMonths * len(canalesDigitales)
	log.Printf("✔ Fact_MetricasWeb completado (%d registros mensuales)\n", totalRegistros)
}
