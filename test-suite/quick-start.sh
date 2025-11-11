#!/bin/bash

# =============================================================================
# QUICK START - CONFIGURACIÓN AUTOMÁTICA DE TESTING
# =============================================================================

set -e  # Detener en caso de error

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo -e "${BOLD}🧪 DATA WAREHOUSE - QUICK START TESTING${NC}"
echo "=============================================="
echo ""

# =============================================================================
# VERIFICAR PREREQUISITOS
# =============================================================================

echo -e "${BLUE}📋 Verificando prerequisitos...${NC}"

# Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker no está instalado${NC}"
    echo "   Instalar desde: https://docs.docker.com/get-docker/"
    exit 1
fi
echo -e "${GREEN}✅ Docker encontrado: $(docker --version)${NC}"

# Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose no está instalado${NC}"
    echo "   Instalar desde: https://docs.docker.com/compose/install/"
    exit 1
fi
echo -e "${GREEN}✅ Docker Compose encontrado: $(docker-compose --version)${NC}"

# Go
if ! command -v go &> /dev/null; then
    echo -e "${RED}❌ Go no está instalado${NC}"
    echo "   Instalar desde: https://golang.org/dl/"
    exit 1
fi
echo -e "${GREEN}✅ Go encontrado: $(go version)${NC}"

# Make
if ! command -v make &> /dev/null; then
    echo -e "${YELLOW}⚠️  Make no está instalado (opcional)${NC}"
    echo "   Puedes usar comandos directos en lugar de 'make'"
fi

echo ""

# =============================================================================
# CREAR ESTRUCTURA DE DIRECTORIOS
# =============================================================================

echo -e "${BLUE}📁 Creando estructura de directorios...${NC}"

mkdir -p reports
mkdir -p scripts
mkdir -p .temp

echo -e "${GREEN}✅ Directorios creados${NC}"
echo ""

# =============================================================================
# CREAR ARCHIVOS DE CONFIGURACIÓN
# =============================================================================

echo -e "${BLUE}⚙️  Creando archivos de configuración...${NC}"

# .env.test
cat > .env.test << 'EOF'
# Configuración para Testing Local
AZURE_SQL_SERVER=localhost
AZURE_SQL_PORT=1433
AZURE_SQL_USER=sa
AZURE_SQL_PASSWORD=TestP@ssw0rd123!
AZURE_SQL_DATABASE=DataWarehouseTest

# Configuración de escala
TEST_MODE=true
SCALE_FACTOR=0.01
EOF

echo -e "${GREEN}✅ .env.test creado${NC}"

# .gitignore
cat > .gitignore << 'EOF'
# Archivos de configuración sensibles
.env
.env.test
.env.production

# Reportes y logs
reports/*.txt
reports/*.csv
*.log

# Archivos de profiling
*.prof
cpu.prof
mem.prof

# Temporales
.temp/
*.tmp

# Binarios
*.exe
main
test_suite

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db
EOF

echo -e "${GREEN}✅ .gitignore creado${NC}"

# Dockerfile.test
cat > Dockerfile.test << 'EOF'
FROM golang:1.21-alpine

WORKDIR /app

# Instalar dependencias del sistema
RUN apk add --no-cache git make

# Copiar go.mod y go.sum
COPY go.mod go.sum ./
RUN go mod download

# Copiar código fuente
COPY . .

# Compilar aplicación
RUN go build -o main .
RUN go build -o test_suite test_suite.go

# Exponer puerto para profiling
EXPOSE 8081 8082

CMD ["./main"]
EOF

echo -e "${GREEN}✅ Dockerfile.test creado${NC}"

echo ""

# =============================================================================
# INICIALIZAR GO MODULES (si no existen)
# =============================================================================

if [ ! -f "go.mod" ]; then
    echo -e "${BLUE}📦 Inicializando Go modules...${NC}"
    go mod init datawarehouse-testing
    
    # Agregar dependencias
    go get github.com/denisenkom/go-mssqldb
    go get github.com/joho/godotenv
    go get github.com/go-faker/faker/v4
    
    echo -e "${GREEN}✅ Go modules inicializados${NC}"
else
    echo -e "${YELLOW}⚠️  go.mod ya existe, verificando dependencias...${NC}"
    go mod tidy
    echo -e "${GREEN}✅ Dependencias actualizadas${NC}"
fi

echo ""

# =============================================================================
# VERIFICAR ARCHIVOS NECESARIOS
# =============================================================================

echo -e "${BLUE}🔍 Verificando archivos necesarios...${NC}"

FILES_NEEDED=(
    "test_suite.go"
    "docker-compose.test.yml"
    "scripts/init-db.sql"
    "../02_Generacion_Datos.go"
)

MISSING_FILES=()

for file in "${FILES_NEEDED[@]}"; do
    if [ ! -f "$file" ]; then
        MISSING_FILES+=("$file")
    fi
done

if [ ${#MISSING_FILES[@]} -gt 0 ]; then
    echo -e "${RED}❌ Faltan los siguientes archivos:${NC}"
    for file in "${MISSING_FILES[@]}"; do
        echo "   • $file"
    done
    echo ""
    echo "Por favor, asegúrate de tener todos los archivos necesarios."
    exit 1
fi

echo -e "${GREEN}✅ Todos los archivos necesarios están presentes${NC}"
echo ""

# =============================================================================
# MENÚ INTERACTIVO
# =============================================================================

echo ""
echo -e "${BOLD}🎯 ¿Qué deseas hacer?${NC}"
echo ""
echo "  1) Test Rápido (1,000 registros - ~30 segundos)"
echo "  2) Test Medio (10,000 registros - ~3 minutos)"
echo "  3) Test Completo (1M registros - ~45 minutos)"
echo "  4) Solo iniciar base de datos (para desarrollo)"
echo "  5) Limpiar todo y salir"
echo "  0) Salir sin hacer nada"
echo ""

read -p "Selecciona una opción [1-5, 0]: " option

case $option in
    1)
        echo ""
        echo -e "${BLUE}🚀 Iniciando Test Rápido...${NC}"
        echo ""
        
        # Iniciar SQL Server
        echo -e "${BLUE}📦 Iniciando SQL Server...${NC}"
        docker-compose -f docker-compose.test.yml up -d sqlserver-test
        
        # Esperar a que esté listo con verificación activa
        echo -e "${YELLOW}⏳ Esperando a que SQL Server esté listo...${NC}"
        for i in {1..60}; do
            if docker exec dw-test-sqlserver //opt//mssql-tools//bin//sqlcmd -S localhost -U sa -P 'TestP@ssw0rd123!' -Q "SELECT 1" &> /dev/null; then
                echo -e "${GREEN}✅ SQL Server está listo (${i}s)${NC}"
                break
            fi
            echo -n "."
            sleep 1
        done
        echo ""
        
        # Ejecutar script de inicialización
        echo -e "${BLUE}🗃️  Creando esquema de base de datos...${NC}"
        docker exec -i dw-test-sqlserver //opt//mssql-tools//bin//sqlcmd -S localhost -U sa -P 'TestP@ssw0rd123!' < scripts/init-db.sql
        echo -e "${GREEN}✅ Esquema creado${NC}"
        
        # Ejecutar generación de datos
        echo ""
        echo -e "${BLUE}💾 Generando datos (SCALE_FACTOR=0.001)...${NC}"
        (cd .. && SCALE_FACTOR=0.001 go run 02_Generacion_Datos.go)
        
        # Ejecutar tests
        echo ""
        echo -e "${BLUE}🧪 Ejecutando validaciones...${NC}"
        go run test_suite.go
        
        echo ""
        echo -e "${GREEN}✅ Test rápido completado${NC}"
        echo -e "📄 Revisa el reporte en ./reports/"
        ;;
        
    2)
        echo ""
        echo -e "${BLUE}🚀 Iniciando Test Medio...${NC}"
        echo ""
        
        docker-compose -f docker-compose.test.yml up -d sqlserver-test
        echo -e "${YELLOW}⏳ Esperando a que SQL Server esté listo...${NC}"
        for i in {1..60}; do
            if docker exec dw-test-sqlserver //opt//mssql-tools//bin//sqlcmd -S localhost -U sa -P 'TestP@ssw0rd123!' -Q "SELECT 1" &> /dev/null; then
                echo -e "${GREEN}✅ SQL Server está listo (${i}s)${NC}"
                break
            fi
            echo -n "."
            sleep 1
        done
        echo ""
        
        echo -e "${BLUE}🗃️  Creando esquema de base de datos...${NC}"
        docker exec -i dw-test-sqlserver //opt//mssql-tools//bin//sqlcmd -S localhost -U sa -P 'TestP@ssw0rd123!' < scripts/init-db.sql
        echo -e "${GREEN}✅ Esquema creado${NC}"
        
        echo ""
        echo -e "${BLUE}💾 Generando datos (SCALE_FACTOR=0.01)...${NC}"
        (cd .. && SCALE_FACTOR=0.01 go run 02_Generacion_Datos.go)
        
        echo ""
        echo -e "${BLUE}🧪 Ejecutando validaciones...${NC}"
        go run test_suite.go
        
        echo ""
        echo -e "${GREEN}✅ Test medio completado${NC}"
        ;;
        
    3)
        echo ""
        echo -e "${RED}⚠️  ADVERTENCIA: Este test generará 1,000,000 de registros${NC}"
        echo -e "   Esto puede tardar 45+ minutos y consumir ~4GB RAM"
        echo ""
        read -p "¿Estás seguro? [y/N]: " confirm
        
        if [[ $confirm =~ ^[Yy]$ ]]; then
            echo ""
            echo -e "${BLUE}🚀 Iniciando Test Completo...${NC}"
            
            docker-compose -f docker-compose.test.yml up -d sqlserver-test
            echo -e "${YELLOW}⏳ Esperando a que SQL Server esté listo...${NC}"
            for i in {1..60}; do
                if docker exec dw-test-sqlserver //opt//mssql-tools//bin//sqlcmd -S localhost -U sa -P 'TestP@ssw0rd123!' -Q "SELECT 1" &> /dev/null; then
                    echo -e "${GREEN}✅ SQL Server está listo (${i}s)${NC}"
                    break
                fi
                echo -n "."
                sleep 1
            done
            echo ""
            
            echo -e "${BLUE}🗃️  Creando esquema de base de datos...${NC}"
            docker exec -i dw-test-sqlserver //opt//mssql-tools//bin//sqlcmd -S localhost -U sa -P 'TestP@ssw0rd123!' < scripts/init-db.sql
            echo -e "${GREEN}✅ Esquema creado${NC}"
            
            echo ""
            echo -e "${BLUE}💾 Generando datos (SCALE_FACTOR=1.0)...${NC}"
            (cd .. && SCALE_FACTOR=1.0 go run 02_Generacion_Datos.go)
            
            echo ""
            echo -e "${BLUE}🧪 Ejecutando validaciones...${NC}"
            go run test_suite.go
            
            echo ""
            echo -e "${GREEN}✅ Test completo terminado${NC}"
        else
            echo "❌ Test cancelado"
        fi
        ;;
        
    4)
        echo ""
        echo -e "${BLUE}🚀 Iniciando solo base de datos...${NC}"
        docker-compose -f docker-compose.test.yml up -d sqlserver-test adminer
        
        echo ""
        echo -e "${GREEN}✅ Base de datos iniciada${NC}"
        echo ""
        echo "🔗 Conexiones disponibles:"
        echo "   • SQL Server: localhost:1433"
        echo "   • Adminer: http://localhost:8080"
        echo ""
        echo "Credenciales:"
        echo "   User: sa"
        echo "   Password: TestP@ssw0rd123!"
        echo "   Database: DataWarehouseTest"
        ;;
        
    5)
        echo ""
        echo -e "${BLUE}🧹 Limpiando entorno...${NC}"
        docker-compose -f docker-compose.test.yml down -v
        rm -rf reports/*.txt reports/*.csv
        rm -f *.prof
        echo -e "${GREEN}✅ Entorno limpio${NC}"
        exit 0
        ;;
        
    0)
        echo ""
        echo "👋 ¡Hasta luego!"
        exit 0
        ;;
        
    *)
        echo ""
        echo -e "${RED}❌ Opción inválida${NC}"
        exit 1
        ;;
esac

# =============================================================================
# MOSTRAR INFORMACIÓN ÚTIL
# =============================================================================

echo ""
echo -e "${BOLD}📚 COMANDOS ÚTILES${NC}"
echo "══════════════════════════════════════════"
echo ""
echo "Ver logs de SQL Server:"
echo "  docker-compose -f docker-compose.test.yml logs -f sqlserver-test"
echo ""
echo "Conectarse a SQL Server:"
echo "  docker exec -it dw-test-sqlserver /opt/mssql-tools/bin/sqlcmd \\"
echo "    -S localhost -U sa -P 'TestP@ssw0rd123!'"
echo ""
echo "Ver estadísticas de tablas:"
echo "  make query-stats"
echo ""
echo "Detener todo:"
echo "  docker-compose -f docker-compose.test.yml down"
echo ""
echo "Limpiar todo (incluyendo datos):"
echo "  docker-compose -f docker-compose.test.yml down -v"
echo ""
echo -e "${BOLD}📖 Documentación completa en README_TESTING.md${NC}"
echo ""